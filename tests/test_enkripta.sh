#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$ROOT_DIR/script/enkripta-instalador.sh"
export INSTALLER
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
MAIN="$TMP/enkripta.sh"
python3 - "$INSTALLER" "$MAIN" <<'PY_EXTRACT'
from pathlib import Path
import sys
installer=Path(sys.argv[1]).read_text()
marker = "cat > \"$DEST_SCRIPT\" <<'ENKRIPTA_SH_EOF'\n"
if marker not in installer:
    raise SystemExit('embedded main-script marker not found')
main = installer.split(marker, 1)[1].split('\nENKRIPTA_SH_EOF', 1)[0]
Path(sys.argv[2]).write_text(main + '\n')
PY_EXTRACT
chmod +x "$MAIN"

pass_count=0
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { pass_count=$((pass_count + 1)); printf 'PASS: %s\n' "$1"; }
run() { "$@" || fail "$*"; }
assert_eq() { [ "$1" = "$2" ] || fail "$3 (got: $1)"; }
assert_file() { [ -f "$1" ] || fail "missing file: $1"; }
assert_contains() { grep -Fq -- "$2" "$1" || fail "'$2' not found in $1"; }

run bash -n "$MAIN"
run bash -n "$INSTALLER"
pass 'Bash syntax'

python3 - "$MAIN" <<'PY'
from pathlib import Path
import re, sys
main=Path(sys.argv[1])
s=main.read_text()
en=set(re.findall(r'MSG_EN\[([^\]]+)\]=',s))
es=set(re.findall(r'MSG_ES\[([^\]]+)\]=',s))
if en != es:
    missing_en=sorted(es-en)
    missing_es=sorted(en-es)
    raise SystemExit(f'language key mismatch; missing EN={missing_en}, missing ES={missing_es}')
ins=Path(__import__('os').environ['INSTALLER']).read_text()
main=s.rstrip('\n')
embedded=ins.split('cat > "$DEST_SCRIPT" <<\'ENKRIPTA_SH_EOF\'\n',1)[1].split('\nENKRIPTA_SH_EOF',1)[0]
if embedded != main:
    raise SystemExit('embedded enkripta.sh does not match the reviewed main script')
PY
pass 'Translation key parity and embedded-script integrity'

# Translation strings are part of the runtime contract: placeholders and
# escape sequences must stay equivalent between languages or printf may change
# behaviour, truncate output, or emit malformed dialogs.
python3 - "$MAIN" <<'PYMSGCONTRACT'
from pathlib import Path
import re, sys
s=Path(sys.argv[1]).read_text()
block=s.split('declare -A MSG_EN MSG_ES',1)[1].split('# Contraseña maestra:',1)[0]
en={}; es={}
for line in block.splitlines():
    for m in re.finditer(r"MSG_(EN|ES)\[([^]]+)\]=(.*?)(?=;\s*MSG_(?:EN|ES)\[[^]]+\]|$)", line):
        lang,key,val=m.groups()
        val=val.strip()
        if val.startswith("$'"):
            val=val[2:-1]
        elif val[:1] in "'\"" and val[-1:]==val[:1]:
            val=val[1:-1]
        (en if lang=='EN' else es)[key]=val
if set(en)!=set(es):
    raise SystemExit(f'placeholder-contract key mismatch: EN={len(en)} ES={len(es)}')
placeholder=re.compile(r'%(?:[-+ #0]*\d*(?:\.\d+)?[diouxXfFeEgGcs]|%)')
def sig(v):
    return [x for x in placeholder.findall(v) if x != '%%']
for key in sorted(en):
    if sig(en[key]) != sig(es[key]):
        raise SystemExit(f'{key}: placeholder mismatch EN={sig(en[key])} ES={sig(es[key])}')
    if '\x00' in en[key] or '\x00' in es[key]:
        raise SystemExit(f'{key}: NUL byte found in message template')
print(f'PASS: {len(en)} EN/ES message templates keep identical printf and newline contracts')
PYMSGCONTRACT

# Exercise every message template through Bash's actual printf path. This
# catches syntax/escape regressions that a textual regex cannot prove.
MSG_CONTRACT="$TMP/msg_contract.sh"
{
  sed -n '/^declare -A MSG_EN MSG_ES$/,/^# Contraseña maestra:/p' "$MAIN" | sed '$d'
  cat <<'__CONTRACT__'
msg() {
    local key="$1"; shift
    local fmt value
    if [ "$LANG_CODE" = es ]; then fmt="${MSG_ES[$key]}"; else fmt="${MSG_EN[$key]}"; fi
    printf -v value "$fmt" "$@"
    printf '%b' "$value"
}
LANG_CODE=en
args=(a b c d e f g h i j k l m n o p q r s t)
for k in "${!MSG_EN[@]}"; do msg "$k" "${args[@]}" >/dev/null; done
LANG_CODE=es
for k in "${!MSG_ES[@]}"; do msg "$k" "${args[@]}" >/dev/null; done
__CONTRACT__
} > "$MSG_CONTRACT"
bash -n "$MSG_CONTRACT"
bash "$MSG_CONTRACT"
pass 'Translation printf/escape contract is executable in Bash for all messages'

TMP_HOME="$TMP/home"
mkdir -p "$TMP_HOME"
export HOME="$TMP_HOME"
export XDG_CONFIG_HOME="$TMP_HOME/config"
export PATH="$TMP/bin:$PATH"
mkdir -p "$TMP/bin"
cat > "$TMP/bin/id" <<'ID_EARLY'
#!/usr/bin/env bash
if [ "${1:-}" = "-u" ]; then printf "1000\n"; else /usr/bin/id "$@"; fi
ID_EARLY
chmod +x "$TMP/bin/id"

help_en="$TMP/help-en.txt"
help_es="$TMP/help-es.txt"
env -u LC_ALL -u LC_MESSAGES -u LANGUAGE LANG=en_US.UTF-8 "$MAIN" --help >"$help_en" 2>&1 || true
env -u LC_ALL -u LC_MESSAGES -u LANGUAGE LANG=es_ES.UTF-8 "$MAIN" --help >"$help_es" 2>&1 || true
assert_contains "$help_en" 'Usage:'
assert_contains "$help_en" 'easy-encrypt'
assert_contains "$help_en" 'switch between English and Spanish'
! grep -Fq -- 'Uso:' "$help_en" || fail 'English help contains Spanish heading'
assert_contains "$help_es" 'Uso:'
assert_contains "$help_es" 'cifrar_facil'
assert_contains "$help_es" 'cambia entre español e inglés'
! grep -Fq -- 'Usage:' "$help_es" || fail 'Spanish help contains English heading'
pass 'Locale-based English/Spanish detection'

env -u LC_ALL -u LANGUAGE LANG=en_US.UTF-8 LC_MESSAGES=es_ES.UTF-8 "$MAIN" --help >"$TMP/help-lc-messages.txt" 2>&1 || true
assert_contains "$TMP/help-lc-messages.txt" 'Uso:'
env -u LANGUAGE LANG=es_ES.UTF-8 LC_ALL=C LC_MESSAGES=C "$MAIN" --help >"$TMP/help-lc-all.txt" 2>&1 || true
assert_contains "$TMP/help-lc-all.txt" 'Usage:'
env LC_ALL=en_US.UTF-8 LC_MESSAGES=en_US.UTF-8 LANGUAGE=es:en LANG=en_US.UTF-8 "$MAIN" --help >"$TMP/help-language-es.txt" 2>&1 || true
assert_contains "$TMP/help-language-es.txt" 'Uso:'
env LC_ALL=en_US.UTF-8 LC_MESSAGES=en_US.UTF-8 LANGUAGE=en:es LANG=es_ES.UTF-8 "$MAIN" --help >"$TMP/help-language-en.txt" 2>&1 || true
assert_contains "$TMP/help-language-en.txt" 'Usage:'
rm -f "$XDG_CONFIG_HOME/enkripta/language"
mkdir -p "$XDG_CONFIG_HOME/enkripta"
printf '%s\n' es > "$XDG_CONFIG_HOME/enkripta/language"
env -u LC_ALL -u LC_MESSAGES -u LANGUAGE LANG=en_US.UTF-8 "$MAIN" --help >"$TMP/help-saved-es.txt" 2>&1 || true
assert_contains "$TMP/help-saved-es.txt" 'Uso:'
printf '%s\n' en > "$XDG_CONFIG_HOME/enkripta/language"
env -u LC_ALL -u LC_MESSAGES -u LANGUAGE LANG=es_ES.UTF-8 "$MAIN" --help >"$TMP/help-saved-en.txt" 2>&1 || true
assert_contains "$TMP/help-saved-en.txt" 'Usage:'
pass 'Locale precedence and saved-language override'

export ENKRIPTA_LANG=en
out="$($MAIN -l)"
assert_eq "$out" 'Idioma cambiado a español.' 'English-to-Spanish toggle output'
unset ENKRIPTA_LANG
assert_eq "$(cat "$XDG_CONFIG_HOME/enkripta/language")" 'es' 'Spanish language persistence'
assert_eq "$(stat -c '%a' "$XDG_CONFIG_HOME/enkripta/language")" '600' 'Language preference permissions'
out="$($MAIN -l)"
assert_eq "$out" 'Language changed to English.' 'Spanish-to-English toggle output'
assert_eq "$(cat "$XDG_CONFIG_HOME/enkripta/language")" 'en' 'English language persistence'
pass 'Persistent one-letter language switch'

# Atomic language preference update: a failed replacement must leave the old value intact.
ATOMIC_BIN="$TMP/atomic-bin"
mkdir -p "$ATOMIC_BIN"
cat > "$ATOMIC_BIN/mv" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$ATOMIC_BIN/mv"
if PATH="$ATOMIC_BIN:$PATH" ENKRIPTA_LANG=es bash "$MAIN" -l >"$TMP/atomic-language.txt" 2>&1; then
    fail 'atomic language replacement unexpectedly succeeded'
fi
assert_eq "$(cat "$XDG_CONFIG_HOME/enkripta/language")" 'en' 'Atomic language replacement changed the saved language'
! find "$XDG_CONFIG_HOME/enkripta" -maxdepth 1 -name 'language.*' -print -quit | grep -q . || fail 'atomic language replacement left a temporary file'
pass 'Language preference replacement is atomic'

export ENKRIPTA_LANG=en
version_en="$("$MAIN" --version)"
export ENKRIPTA_LANG=es
version_es="$("$MAIN" --version)"
assert_eq "$version_en" "Enkripta 1.5.0" 'English version output'
assert_eq "$version_es" "Enkripta 1.5.0" 'Spanish version output remains language-neutral'
unset ENKRIPTA_LANG

export ENKRIPTA_LANG=en
if bash "$INSTALLER" --definitely-not-an-option >"$TMP/unknown-en.txt" 2>&1; then fail 'Unknown installer option should return non-zero'; fi
assert_contains "$TMP/unknown-en.txt" 'Unknown option:'
export ENKRIPTA_LANG=es
if bash "$INSTALLER" --definitely-not-an-option >"$TMP/unknown-es.txt" 2>&1; then fail 'Unknown installer option should return non-zero in Spanish'; fi
assert_contains "$TMP/unknown-es.txt" 'Opción no reconocida:'
unset ENKRIPTA_LANG
pass 'Language-independent version output and localized errors'

python3 - "$MAIN" <<'PY_ALIAS'
from pathlib import Path
import re, sys
s=Path(sys.argv[1]).read_text()
required={
    'cifrar|encrypt','cifrar_facil|easy-encrypt','descifrar|decrypt','actualizar|update',
    'cambiar-contrasena|change-password','anadir-contrasena|add-password',
    'eliminar-contrasena|remove-password','contrasena-maestra|master-password',
    'quitar-contrasena-maestra|remove-master-password'
}
for pair in required:
    a,b=pair.split('|')
    if not re.search(r'\b'+re.escape(a)+r'\|'+re.escape(b)+r'\)',s):
        raise SystemExit(f'missing command alias pair: {a}|{b}')
PY_ALIAS
pass 'Spanish/English command alias dispatch preserved'

# Invalid saved preference must fall back to the system locale.
printf '%s\n' invalid > "$XDG_CONFIG_HOME/enkripta/language"
env -u LC_ALL -u LC_MESSAGES -u LANGUAGE LANG=es_ES.UTF-8 "$MAIN" --help >"$TMP/help-invalid-saved.txt" 2>&1 || true
assert_contains "$TMP/help-invalid-saved.txt" 'Uso:'
rm -f "$XDG_CONFIG_HOME/enkripta/language"
pass 'Invalid saved language safely falls back to locale'

export ENKRIPTA_LANG=en
installer_help_en="$TMP/installer-help-en.txt"
installer_help_es="$TMP/installer-help-es.txt"
bash "$INSTALLER" --help >"$installer_help_en"
rm -f "$XDG_CONFIG_HOME/enkripta/language"
unset ENKRIPTA_LANG
env -u LC_ALL -u LC_MESSAGES -u LANGUAGE LANG=es_ES.UTF-8 bash "$INSTALLER" --help >"$installer_help_es"
assert_contains "$installer_help_en" 'Usage:'
assert_contains "$installer_help_en" '--toggle-language'
assert_contains "$installer_help_es" 'Uso:'
assert_contains "$installer_help_es" '--toggle-language'
pass 'Installer help localization'

rm -f "$XDG_CONFIG_HOME/enkripta/language"
ENKRIPTA_LANG=en bash "$INSTALLER" -l >"$TMP/installer-toggle.txt"
assert_contains "$TMP/installer-toggle.txt" 'Idioma cambiado a español.'
assert_eq "$(cat "$XDG_CONFIG_HOME/enkripta/language")" 'es' 'Installer one-letter toggle'
rm -f "$XDG_CONFIG_HOME/enkripta/language"

zenlog="$TMP/zenity.log"
zen_state="$TMP/zenity.state"
cat > "$TMP/bin/zenity" <<'ZEN'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >> "${ZENITY_LOG:?}"
if printf '%s\n' "$*" | grep -q -- '--list'; then
    n=0
    [ -f "${ZENITY_STATE:?}" ] && n=$(cat "$ZENITY_STATE")
    n=$((n+1))
    printf '%s\n' "$n" > "$ZENITY_STATE"
    if [ "$n" -eq 1 ]; then printf '%s\n' 'language'; exit 0; fi
    exit 1
fi
exit 1
ZEN
chmod +x "$TMP/bin/zenity"
export ZENITY_LOG="$zenlog" ZENITY_STATE="$zen_state"
rm -f "$XDG_CONFIG_HOME/enkripta/language" "$zenlog" "$zen_state"
export ENKRIPTA_LANG=en
"$MAIN" gui >/dev/null 2>&1 || true
assert_contains "$zenlog" 'Switch language: English / Spanish'
assert_eq "$(cat "$XDG_CONFIG_HOME/enkripta/language")" 'es' 'GUI English-to-Spanish toggle'
unset ENKRIPTA_LANG
rm -f "$zenlog" "$zen_state"
"$MAIN" gui >/dev/null 2>&1 || true
assert_contains "$zenlog" 'Cambiar idioma: español / inglés'
assert_eq "$(cat "$XDG_CONFIG_HOME/enkripta/language")" 'en' 'GUI Spanish-to-English toggle'
python3 - "$zenlog" <<'PY_VISUAL'
from pathlib import Path
import sys
text=Path(sys.argv[1]).read_text()
for token in ['encrypt_file','encrypt_dir','open_vault','master_set','master_unset','language']:
    if token not in text:
        raise SystemExit(f'missing stable GUI id: {token}')
rows=['Switch language: English / Spanish','Cambiar idioma: español / inglés']
if max(map(len, rows)) > 50:
    raise SystemExit('language selector label is too long for the designed dialog width')
PY_VISUAL
pass 'GUI language selector uses translated labels with stable ID'

unset ENKRIPTA_LANG
rm -f "$TMP/bin/zenity" "$zenlog" "$zen_state"

# Installer-generated integration in an isolated HOME.
ENKRIPTA_LANG=en bash "$INSTALLER" >"$TMP/install.txt"
INST="$HOME/.local/bin/enkripta.sh"
APP="$HOME/.local/share/applications/enkripta.desktop"
MIME="$HOME/.local/share/mime/packages/enkripta-cvault.xml"
NA="$HOME/.local/share/nemo/actions/enkripta-cifrar.nemo_action"
NO="$HOME/.local/share/nemo/actions/enkripta-abrir.nemo_action"
DESK="$HOME/Desktop/enkripta.desktop"
for f in "$INST" "$APP" "$MIME" "$NA" "$NO" "$DESK"; do assert_file "$f"; done
cmp -s "$INST" "$MAIN" || fail 'installed script differs from reviewed main script'
assert_contains "$APP" 'GenericName[es]=Cifrado de carpetas y archivos'
assert_contains "$APP" 'Comment[es]=Cifra y descifra carpetas o archivos con contraseña (AES-256)'
assert_contains "$MIME" '<comment>Encrypted Enkripta vault</comment>'
assert_contains "$MIME" '<comment xml:lang="es">Vault cifrado de Enkripta</comment>'
assert_contains "$NA" 'Name=🔒 Encrypt with Enkripta'
assert_contains "$NO" 'Name=🔓 Open Enkripta vault'
# Nemo picks Name[xx] by the SYSTEM locale, so its actions must carry no [xx] keys.
! grep -Eq '^(Name|Comment)\[' "$NA" "$NO" || fail 'Nemo actions must not carry [xx] locale keys'
assert_contains "$TMP/install.txt" 'Done! Enkripta is now integrated with Cinnamon:'
pass 'Installer integration and localized desktop/Nemo metadata'

# Nemo actions follow Enkripta's language (not the system's); -l rewrites them.
LANGF="$XDG_CONFIG_HOME/enkripta/language"
nemo_name() { grep -m1 '^Name=' "$1" | cut -d= -f2-; }
rm -f "$LANGF"
env -u ENKRIPTA_LANG LC_ALL=C "$INST" -l >/dev/null
assert_eq "$(nemo_name "$NA")" '🔒 Cifrar con Enkripta' 'Nemo encrypt action follows -l to Spanish'
assert_eq "$(nemo_name "$NO")" '🔓 Abrir vault Enkripta' 'Nemo open action follows -l to Spanish'
assert_contains "$NA" 'Comment=Cifra el archivo o carpeta seleccionada con contraseña (AES-256)'
env -u ENKRIPTA_LANG LC_ALL=C "$INST" -l >/dev/null
assert_eq "$(nemo_name "$NA")" '🔒 Encrypt with Enkripta' 'Nemo encrypt action follows -l back to English'
assert_contains "$NO" 'Comment=Decrypt or manage'
pass 'Nemo actions alternate language with -l (Name and Comment)'

# A deleted action is not resurrected, the others are refreshed, and the
# installer's -l delegates to the installed program so Nemo is refreshed too.
rm -f "$NO"
env -u ENKRIPTA_LANG LC_ALL=C "$INST" -l >/dev/null
[ ! -e "$NO" ] || fail 'a deleted Nemo action was recreated by -l'
assert_eq "$(nemo_name "$NA")" '🔒 Cifrar con Enkripta' 'remaining Nemo action is still refreshed'
env -u ENKRIPTA_LANG LC_ALL=C bash "$INSTALLER" -l >/dev/null
assert_eq "$(nemo_name "$NA")" '🔒 Encrypt with Enkripta' 'installer -l refreshes the Nemo actions'
assert_eq "$(cat "$LANGF")" 'en' 'installer -l stored the language'
[ ! -e "$NO" ] || fail 'installer -l recreated a deleted Nemo action'
FRESH="$TMP/fresh-home"; mkdir -p "$FRESH"
env -u ENKRIPTA_LANG HOME="$FRESH" XDG_CONFIG_HOME="$FRESH/config" LC_ALL=C "$MAIN" -l >/dev/null
assert_eq "$(cat "$FRESH/config/enkripta/language")" 'es' 'language stored without integration'
[ ! -e "$FRESH/.local" ] || fail '-l created Nemo integration in a home that had none'
pass 'Nemo refresh never resurrects deleted actions nor creates integration'

# With no language chosen Enkripta follows the system's, so a graphical launch
# resyncs the actions; once a language is chosen, only the switch rewrites them.
ENKRIPTA_LANG=en "$INST" --nemo-actions
printf '#!/usr/bin/env bash\nexit 1\n' > "$TMP/bin/zenity"; chmod +x "$TMP/bin/zenity"
rm -f "$LANGF"
env -u ENKRIPTA_LANG LC_ALL=es_ES.UTF-8 "$INST" gui >/dev/null 2>&1 || true
assert_eq "$(nemo_name "$NA")" '🔒 Cifrar con Enkripta' 'GUI launch resyncs Nemo actions with the system language'
ENKRIPTA_LANG=en LC_ALL=es_ES.UTF-8 "$INST" gui >/dev/null 2>&1 || true
assert_eq "$(nemo_name "$NA")" '🔒 Cifrar con Enkripta' 'ENKRIPTA_LANG overrides the resync'
printf 'en\n' > "$LANGF"
env -u ENKRIPTA_LANG LC_ALL=es_ES.UTF-8 "$INST" gui >/dev/null 2>&1 || true
assert_eq "$(nemo_name "$NA")" '🔒 Cifrar con Enkripta' 'a chosen language is never resynced by a plain launch'
ENKRIPTA_LANG=en "$INST" --nemo-actions
rm -f "$TMP/bin/zenity"
pass 'GUI launch resyncs Nemo actions only while following the system language'

TEST="$TMP/test-data"
mkdir -p "$TEST/input/sub"
printf 'spanish alias regression\n' > "$TEST/spanish.txt"
export ENKRIPTA_LANG=es
printf 'n\nSpanishPass123!\nSpanishPass123!\nn\n' | "$INST" cifrar "$TEST/spanish.txt" >/dev/null
rm -f "$TEST/spanish.txt"
printf 'n\nSpanishPass123!\n' | "$INST" descifrar "$TEST/spanish.txt.cvault" >/dev/null
assert_contains "$TEST/spanish.txt" 'spanish alias regression'
rm -f "$TEST/spanish.txt" "$TEST/spanish.txt.cvault"
unset ENKRIPTA_LANG
mkdir -p "$TEST/input/sub"
printf 'áéíóú — Enkripta regression\n' > "$TEST/input/sub/data.txt"
printf 'second file\n' > "$TEST/input/second.txt"
printf '%s' 'PrimaryPass123!' > "$TMP/p1"
printf '%s' 'SecondPass456!' > "$TMP/p2"
printf '%s' 'NewPass789!' > "$TMP/p3"

printf 'n\nPrimaryPass123!\nPrimaryPass123!\ny\nSecondPass456!\nSecondPass456!\nn\n' | "$INST" encrypt "$TEST/input" >/dev/null
VAULT="$TEST/input.cvault"
assert_file "$VAULT"
orig_members="$TMP/members-before"
tar -tf "$VAULT" > "$orig_members"
expected_members=$'meta\ndata.gpg\nslot1.gpg\nslot2.gpg'
assert_eq "$(cat "$orig_members")" "$expected_members" 'Vault member layout'
sha_before="$(tar -xOf "$VAULT" data.gpg | sha256sum | cut -d' ' -f1)"

rm -rf "$TEST/input"
printf 'y\nSecondPass456!\n' | "$INST" decrypt "$VAULT" >/dev/null
cmp -s "$TEST/input/sub/data.txt" <(printf 'áéíóú — Enkripta regression\n') || fail 'decrypted directory content mismatch'
assert_file "$TEST/input/second.txt"
rm -rf "$TEST/input"
pass 'Directory encryption/decryption with Unicode content'

# UI language must not affect vault compatibility.
export ENKRIPTA_LANG=es
rm -rf "$TEST/input"
printf 'n\nSecondPass456!\n' | "$INST" decrypt "$VAULT" >/dev/null
assert_file "$TEST/input/sub/data.txt"
rm -rf "$TEST/input"
unset ENKRIPTA_LANG
pass 'Cross-language vault compatibility'

printf 'n\nPrimaryPass123!\nNewPass789!\nNewPass789!\n' | "$INST" change-password "$VAULT" >/dev/null
sha_after="$(tar -xOf "$VAULT" data.gpg | sha256sum | cut -d' ' -f1)"
assert_eq "$sha_after" "$sha_before" 'change-password altered encrypted data'
rm -rf "$TEST/input"
printf 'n\nNewPass789!\n' | "$INST" decrypt "$VAULT" >/dev/null
assert_file "$TEST/input/sub/data.txt"
rm -rf "$TEST/input"
pass 'Password change preserves encrypted payload'

# Atomic encrypted-output update: a partial gpg write must not corrupt the live slot.
FAIL_GPG_BIN="$TMP/fail-gpg-bin"
mkdir -p "$FAIL_GPG_BIN"
REAL_GPG="$(command -v gpg)"
cat > "$FAIL_GPG_BIN/gpg" <<EOF
#!/usr/bin/env bash
out=""; prev=""
for arg in "\$@"; do
    [ "\$prev" = -o ] && out="\$arg"
    prev="\$arg"
done
case " \${*} " in
    *' --symmetric '*) [ -n "\$out" ] && : > "\$out"; exit 1 ;;
    *) exec "$REAL_GPG" "\$@" ;;
esac
EOF
chmod +x "$FAIL_GPG_BIN/gpg"
VAULT_BEFORE="$(sha256sum "$VAULT" | cut -d' ' -f1)"
if printf 'n\nNewPass789!\nAtomicFail123!\nAtomicFail123!\n' | PATH="$FAIL_GPG_BIN:$PATH" "$MAIN" change-password "$VAULT" >"$TMP/atomic-gpg.txt" 2>&1; then
    fail 'atomic gpg failure unexpectedly succeeded'
fi
assert_eq "$(sha256sum "$VAULT" | cut -d' ' -f1)" "$VAULT_BEFORE" 'Atomic gpg failure changed the vault'
rm -rf "$TEST/input"
printf 'n\nNewPass789!\n' | "$INST" decrypt "$VAULT" >/dev/null
assert_file "$TEST/input/sub/data.txt"
rm -rf "$TEST/input"
pass 'Encrypted slot replacement is atomic'

printf 'n\nNewPass789!\ny\n' | "$INST" remove-password "$VAULT" >/dev/null
sha_removed="$(tar -xOf "$VAULT" data.gpg | sha256sum | cut -d' ' -f1)"
assert_eq "$sha_removed" "$sha_before" 'remove-password altered encrypted data'
assert_eq "$(tar -tf "$VAULT" | wc -l | tr -d ' ')" '3' 'Vault member count after password removal'
rm -rf "$TEST/input"
printf 'n\nSecondPass456!\n' | "$INST" decrypt "$VAULT" >/dev/null
assert_file "$TEST/input/sub/data.txt"
rm -rf "$TEST/input"
if printf 'n\nNewPass789!\n' | "$INST" decrypt "$VAULT" >"$TMP/removed-pass.txt" 2>&1; then
    fail 'removed password still unlocked the vault'
fi
pass 'Password removal invalidates only the removed slot'

# Update must keep the vault passwords while replacing content.
printf 'updated content\n' > "$TEST/input.tmp"
mkdir -p "$TEST/input/sub"
cp "$TEST/input.tmp" "$TEST/input/sub/data.txt"
printf 'PrimaryPass123!\nupdated content\n' >> "$TEST/input/second.txt"
printf 'n\nSecondPass456!\n' | "$INST" update "$TEST/input" >/dev/null
rm -rf "$TEST/input"
printf 'n\nSecondPass456!\n' | "$INST" decrypt "$VAULT" >/dev/null
assert_contains "$TEST/input/sub/data.txt" 'updated content'
rm -rf "$TEST/input"
pass 'Vault update preserves password access and updates content'

# Master password workflow.
printf 'n\nMasterPass123!\nMasterPass123!\n' | "$INST" master-password >/dev/null
assert_file "$HOME/.local/share/enkripta/master.verify"
printf 'n\n' > "$TMP/new-password-choice"
printf 'n\nMasterPass123!\n' | "$INST" easy-encrypt "$TEST/input.tmp" >/dev/null
MASTER_VAULT="$TEST/input.tmp.cvault"
rm -f "$TEST/input.tmp"
assert_file "$MASTER_VAULT"
printf 'n\nMasterPass123!\n' | "$INST" decrypt "$MASTER_VAULT" >/dev/null
assert_contains "$TEST/input.tmp" 'updated content'
printf 'y\nMasterPass123!\n' | "$INST" remove-master-password >/dev/null
[ ! -f "$HOME/.local/share/enkripta/master.verify" ] || fail 'master verifier was not removed'
pass 'Master password workflow'

# GUI Nemo selector: the picker label follows whether the actions are
# currently installed, and picking it actually adds/removes them.
cat > "$TMP/bin/zenity" <<'ZEN'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >> "${ZENITY_LOG:?}"
printf '%s\n' "$*" | grep -q -- '--list' && { printf '%s\n' "${ZENITY_ANSWER:?}"; exit 0; }
exit 1
ZEN
chmod +x "$TMP/bin/zenity"
export ZENITY_LOG="$zenlog" ENKRIPTA_LANG=en
assert_file "$NA"; assert_file "$NO"
ZENITY_ANSWER=nemo_off "$MAIN" gui >/dev/null 2>&1
assert_contains "$zenlog" '➖ Remove the Nemo actions'
[ ! -f "$NA" ] && [ ! -f "$NO" ] || fail 'picker nemo_off did not remove the Nemo actions'
rm -f "$zenlog"
ZENITY_ANSWER=nemo_on "$MAIN" gui >/dev/null 2>&1
assert_contains "$zenlog" '➕ Add the Nemo actions'
assert_file "$NA"; assert_file "$NO"
unset ENKRIPTA_LANG ZENITY_ANSWER
rm -f "$TMP/bin/zenity" "$zenlog"
pass 'GUI Nemo selector label follows state and add/remove takes effect'

# Uninstall removes everything, including the program itself.
export ENKRIPTA_LANG=en
bash "$INSTALLER" --uninstall >"$TMP/uninstall.txt" 2>&1
[ ! -f "$INST" ] || fail 'enkripta.sh was not removed by --uninstall'
[ ! -f "$APP" ] || fail 'desktop application entry was not removed'
[ ! -f "$MIME" ] || fail 'MIME definition was not removed'
[ ! -f "$NA" ] || fail 'Nemo encrypt action was not removed'
[ ! -f "$NO" ] || fail 'Nemo open action was not removed'
[ ! -f "$DESK" ] || fail 'desktop shortcut was not removed'
assert_contains "$TMP/uninstall.txt" 'was completely uninstalled'
pass 'Installer uninstall removes the program and every trace of the integration'

# Nothing Enkripta-related should remain anywhere under $HOME: the only
# thing left must be the pre-existing (now empty) Desktop folder.
leftover="$(find "$HOME" -mindepth 1 | sort)"
assert_eq "$leftover" "$(dirname "$DESK")" 'uninstall left files behind: not truly "no trace"'
pass 'Uninstall leaves no trace under $HOME'

# User-visible English/Spanish strings must not be accidentally hard-coded in the opposite layer.
python3 - "$MAIN" <<'PY'
from pathlib import Path
import re, sys
p=Path(sys.argv[1]); s=p.read_text()
for key in re.findall(r'^MSG_EN\[([^\]]+)\]=(["\x27])', s, re.M):
    pass
if re.search(r'--text="[^"]*(?:Selecciona|¿|contraseña|Cifra|Descifra)', s):
    raise SystemExit('possible Spanish user-facing hard-coded GUI text found')
PY
pass 'Static guard against untranslated GUI literals'

printf '\n%s high-value tests passed.\n' "$pass_count"
