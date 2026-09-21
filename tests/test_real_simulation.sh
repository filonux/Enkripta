#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT_DIR"
INSTALLER="$ROOT_DIR/script/enkripta-instalador.sh"
TMP=$(mktemp -d)
trap 'rc=$?; if [ "$rc" -ne 0 ]; then echo "SIMULATION FAILED; temp=$TMP" >&2; tail -60 "$TMP/log/zenity.log" 2>/dev/null || true; fi; exit $rc' EXIT

export HOME="$TMP/home"
export XDG_CONFIG_HOME="$TMP/config"
export XDG_DATA_HOME="$TMP/data"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$TMP/bin" "$TMP/log"
export PATH="$TMP/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export SIM_LOG="$TMP/log"

cat > "$TMP/bin/id" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "-u" ]; then printf '1000\n'; else /usr/bin/id "$@"; fi
EOF
cat > "$TMP/bin/nemo" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$SIM_LOG/nemo.log"
EOF
cat > "$TMP/bin/xdg-mime" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$SIM_LOG/xdg-mime.log"
EOF
cat > "$TMP/bin/update-mime-database" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$SIM_LOG/mime.log"
EOF
cat > "$TMP/bin/update-desktop-database" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$SIM_LOG/desktop.log"
EOF
cat > "$TMP/bin/gio" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$SIM_LOG/gio.log"
EOF
cat > "$TMP/bin/notify-send" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$SIM_LOG/notify.log"
EOF
cat > "$TMP/bin/xdg-open" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$SIM_LOG/xdg-open.log"
EOF
cat > "$TMP/bin/zenity" <<'EOF'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >> "$SIM_LOG/zenity.log"
queue="${ZENITY_QUEUE:?}"
kind=
for a in "$@"; do
  case "$a" in
    --list) kind=list;;
    --file-selection) kind=file;;
    --password|--entry) kind=password;;
    --question) kind=question;;
    --error) kind=error;;
    --info) kind=info;;
    --text-info) kind=textinfo;;
  esac
done
case "$kind" in
 question)
   read -r ans < "$queue" || exit 1
   tail -n +2 "$queue" > "$queue.tmp"; mv "$queue.tmp" "$queue"
   case "$ans" in y|Y|yes|YES|true|0) exit 0;; *) exit 1;; esac;;
 list|file|password|entry)
   read -r ans < "$queue" || exit 1
   tail -n +2 "$queue" > "$queue.tmp"; mv "$queue.tmp" "$queue"
   [ "$ans" = __CANCEL__ ] && exit 1
   printf '%b' "$ans";;
 error|info|textinfo) exit 0;;
 *) exit 1;;
esac
EOF
chmod +x "$TMP/bin"/*

setq() { printf '%s\n' "$@" > "$TMP/q"; export ZENITY_QUEUE="$TMP/q"; }
run_cli() { "$INST" "$@"; }

bash "$INSTALLER" >/dev/null
INST="$HOME/.local/bin/enkripta.sh"
APP="$HOME/.local/share/applications/enkripta.desktop"
NA="$HOME/.local/share/nemo/actions/enkripta-cifrar.nemo_action"
NO="$HOME/.local/share/nemo/actions/enkripta-abrir.nemo_action"
MIME="$HOME/.local/share/mime/packages/enkripta-cvault.xml"
DESK="$HOME/Desktop/enkripta.desktop"
for f in "$INST" "$APP" "$NA" "$NO" "$MIME" "$DESK"; do test -f "$f"; done
[ -x "$INST" ] && [ -x "$DESK" ]
printf '[1] Install/integration artifacts: PASS\n'

grep -Fx 'Selection=notnone' "$NA" >/dev/null
grep -Fx 'Extensions=any;' "$NA" >/dev/null
grep -Fx 'Selection=notnone' "$NO" >/dev/null
grep -Fx 'Extensions=cvault;' "$NO" >/dev/null
grep -F 'gui-encrypt %F' "$NA" >/dev/null
grep -F 'gui-menu %F' "$NO" >/dev/null
printf '[2] Nemo action contract and exact dispatch: PASS\n'

# CLI file encrypt/decrypt in opposite languages.
printf 'CLI file content áéí\n' > "$TMP/file.txt"
printf 'n\nFilePass123!\nFilePass123!\nn\n' | ENKRIPTA_LANG=en run_cli encrypt "$TMP/file.txt" >/dev/null
rm "$TMP/file.txt"
printf 'n\nFilePass123!\n' | ENKRIPTA_LANG=es run_cli descifrar "$TMP/file.txt.cvault" >/dev/null
cmp -s "$TMP/file.txt" <(printf 'CLI file content áéí\n')
rm -f "$TMP/file.txt" "$TMP/file.txt.cvault"
printf '[3] CLI file encrypt/decrypt EN→ES: PASS\n'

# CLI directory with two passwords.
mkdir -p "$TMP/tree/sub"; printf 'nested data\n' > "$TMP/tree/sub/data.txt"; printf 'second\n' > "$TMP/tree/second.txt"
printf 'n\nDirPass123!\nDirPass123!\ny\nAltPass456!\nAltPass456!\nn\n' | ENKRIPTA_LANG=es run_cli cifrar_facil "$TMP/tree" >/dev/null
V="$TMP/tree.cvault"
rm -rf "$TMP/tree"
printf 'n\nAltPass456!\n' | ENKRIPTA_LANG=en run_cli decrypt "$V" >/dev/null
cmp -s "$TMP/tree/sub/data.txt" <(printf 'nested data\n')
rm -rf "$TMP/tree"
printf '[4] CLI directory + two passwords + cross-language decrypt: PASS\n'

# Easy-encrypt on an existing vault routes to the terminal menu.
rm -rf "$TMP/tree"
printf '1\nn\nAltPass456!\n' | run_cli easy-encrypt "$V" >/dev/null
[ -f "$TMP/tree/sub/data.txt" ]
rm -rf "$TMP/tree"
printf '[5] easy-encrypt vault routing through terminal menu: PASS\n'

# Terminal menu language toggle must use L/l and refresh all translated menu text.
rm -f "$XDG_CONFIG_HOME/enkripta/language"
printf 'l\nL\n6\n' | ENKRIPTA_LANG=en run_cli easy-encrypt "$V" >"$TMP/menu-language.txt"
grep -F 'L) Switch language: English / Spanish' "$TMP/menu-language.txt" >/dev/null
grep -F "L) Cambiar idioma: español / inglés" "$TMP/menu-language.txt" >/dev/null
grep -F "(2 contraseñas configuradas)" "$TMP/menu-language.txt" >/dev/null
grep -F 'Operation cancelled.' "$TMP/menu-language.txt" >/dev/null
[ "$(cat "$XDG_CONFIG_HOME/enkripta/language")" = en ]
rm -f "$XDG_CONFIG_HOME/enkripta/language"
printf '[6] terminal menu L/l language toggle: PASS\n'

# Password lifecycle: add, change, remove while preserving payload.
printf 'n\nAltPass456!\nAddPass789!\nAddPass789!\n' | run_cli add-password "$V" >/dev/null
printf 'n\nAddPass789!\nChanged321!\nChanged321!\n' | run_cli change-password "$V" >/dev/null
printf 'n\nChanged321!\ny\n' | run_cli remove-password "$V" >/dev/null
rm -rf "$TMP/tree"
printf 'n\nAltPass456!\n' | run_cli decrypt "$V" >/dev/null
[ -f "$TMP/tree/sub/data.txt" ]
rm -rf "$TMP/tree"
printf '[7] add/change/remove password lifecycle: PASS\n'

# Update preserves remaining password.
mkdir -p "$TMP/tree/sub"; printf 'UPDATED DATA\n' > "$TMP/tree/sub/data.txt"
printf 'n\nAltPass456!\nn\n' | run_cli update "$TMP/tree" >/dev/null
rm -rf "$TMP/tree"
printf 'n\nAltPass456!\n' | run_cli decrypt "$V" >/dev/null
grep -Fx 'UPDATED DATA' "$TMP/tree/sub/data.txt" >/dev/null
rm -rf "$TMP/tree"
printf '[8] update + decrypt after update: PASS\n'

# Master password lifecycle and vault encrypted through the master key flow.
printf 'n\nMasterPass123!\nMasterPass123!\n' | run_cli master-password >/dev/null
[ -f "$HOME/.local/share/enkripta/master.verify" ]
printf 'master content\n' > "$TMP/master.txt"
printf 'n\nMasterPass123!\nn\n' | run_cli encrypt "$TMP/master.txt" >/dev/null
rm "$TMP/master.txt"
printf 'n\nMasterPass123!\n' | run_cli decrypt "$TMP/master.txt.cvault" >/dev/null
grep -Fx 'master content' "$TMP/master.txt" >/dev/null
printf 'y\nMasterPass123!\n' | run_cli remove-master-password >/dev/null
[ ! -f "$HOME/.local/share/enkripta/master.verify" ]
rm -f "$TMP/master.txt" "$TMP/master.txt.cvault"
printf '[9] master-password set/use/unset: PASS\n'

# GUI: multi-file Nemo encrypt action. Exact action Exec after %F expansion.
printf 'NEMO A\n' > "$TMP/nemo-a.txt"
printf 'NEMO B\n' > "$TMP/nemo-b.txt"
setq N 'NemoA123!' 'NemoA123!' N N 'NemoB456!' 'NemoB456!' N
"$INST" gui-encrypt "$TMP/nemo-a.txt" "$TMP/nemo-b.txt" >/dev/null
[ -f "$TMP/nemo-a.txt.cvault" ] && [ -f "$TMP/nemo-b.txt.cvault" ]
[ -f "$TMP/nemo-a.txt" ] && [ -f "$TMP/nemo-b.txt" ]
printf '[10] Nemo encrypt action with 2 selected files: PASS\n'

# GUI menu: change password.
setq change N 'NemoA123!' 'NemoC789!' 'NemoC789!'
"$INST" gui-menu "$TMP/nemo-a.txt.cvault" >/dev/null
rm "$TMP/nemo-a.txt"
# GUI menu: decrypt using new password, don't open externally.
setq decrypt N 'NemoC789!' N
"$INST" gui-menu "$TMP/nemo-a.txt.cvault" >/dev/null
[ -f "$TMP/nemo-a.txt" ]
rm "$TMP/nemo-a.txt"
# GUI menu: add password.
setq add N 'NemoC789!' 'NemoD321!' 'NemoD321!'
"$INST" gui-menu "$TMP/nemo-a.txt.cvault" >/dev/null
# GUI menu: remove newly-added password, confirming.
setq remove N 'NemoD321!' Y
"$INST" gui-menu "$TMP/nemo-a.txt.cvault" >/dev/null
printf '[11] GUI vault menu: change/add/remove/decrypt: PASS\n'

# GUI menu language toggle, then cancel: saved language must become Spanish.
rm -f "$XDG_CONFIG_HOME/enkripta/language"
setq language __CANCEL__
ENKRIPTA_LANG=en "$INST" gui-menu "$TMP/nemo-a.txt.cvault" >/dev/null || true
[ "$(cat "$XDG_CONFIG_HOME/enkripta/language")" = es ]
printf '[12] GUI vault language toggle: PASS\n'

# GUI launcher picker: file encryption path.
rm -f "$XDG_CONFIG_HOME/enkripta/language"
printf 'picker file\n' > "$TMP/picker.txt"
setq encrypt_file "$TMP/picker.txt" N 'Picker123!' 'Picker123!' N N
ENKRIPTA_LANG=en "$INST" gui >/dev/null
[ -f "$TMP/picker.txt.cvault" ]
printf '[13] GUI launcher picker -> file encryption: PASS\n'

# GUI launcher picker: folder encryption path.
mkdir -p "$TMP/picker-dir/sub"; printf 'picker dir\n' > "$TMP/picker-dir/sub/x.txt"
setq encrypt_dir "$TMP/picker-dir" N 'PickerDir123!' 'PickerDir123!' N N
ENKRIPTA_LANG=es "$INST" gui >/dev/null
[ -f "$TMP/picker-dir.cvault" ]
rm -rf "$TMP/picker-dir"
printf '[14] GUI launcher picker -> folder encryption: PASS\n'

# GUI launcher picker: open a vault and decrypt.
rm -f "$TMP/picker.txt"
setq open_vault "$TMP/picker.txt.cvault" decrypt N 'Picker123!' N
ENKRIPTA_LANG=en "$INST" gui >/dev/null
[ -f "$TMP/picker.txt" ]
printf '[15] GUI launcher picker -> open vault -> decrypt: PASS\n'

# GUI launcher picker: set then unset master password.
rm -f "$XDG_CONFIG_HOME/enkripta/language"
rm -f "$HOME/.local/share/enkripta/master.verify"
setq master_set N 'GuiMaster123!' 'GuiMaster123!'
ENKRIPTA_LANG=en "$INST" gui >/dev/null
[ -f "$HOME/.local/share/enkripta/master.verify" ]
setq master_unset Y
ENKRIPTA_LANG=en "$INST" gui >/dev/null
[ ! -f "$HOME/.local/share/enkripta/master.verify" ]
printf '[16] GUI launcher picker -> master set/unset: PASS\n'

# Desktop direct command: `gui FILE` dispatches encryption; `gui VAULT` dispatches vault menu.
printf 'desktop direct\n' > "$TMP/desktop.txt"
setq N 'Desk123!' 'Desk123!' N N
ENKRIPTA_LANG=en "$INST" gui "$TMP/desktop.txt" >/dev/null
[ -f "$TMP/desktop.txt.cvault" ]
rm "$TMP/desktop.txt"
setq decrypt N 'Desk123!' N
"$INST" gui "$TMP/desktop.txt.cvault" >/dev/null
[ -f "$TMP/desktop.txt" ]
printf '[17] Desktop direct gui dispatch (file/vault): PASS\n'

# MIME-style single-argument launch: the program receives only the vault path.
rm -f "$TMP/desktop.txt"
setq decrypt N 'Desk123!' N
"$INST" "$TMP/desktop.txt.cvault" >/dev/null
[ -f "$TMP/desktop.txt" ]
printf '[18] MIME/default-app single-argument launch: PASS\n'

# Cancellation in GUI password dialog must stop cleanly and create no vault.
printf 'cancel me\n' > "$TMP/cancel.txt"
setq __CANCEL__
if "$INST" gui-encrypt "$TMP/cancel.txt" >/dev/null 2>&1; then
  :
else
  :
fi
[ ! -f "$TMP/cancel.txt.cvault" ] && [ -f "$TMP/cancel.txt" ]
printf '[19] GUI cancellation safety: PASS\n'

# Symlink protection: should refuse to operate on the link itself.
ln -s "$TMP/cancel.txt" "$TMP/link.txt"
if ENKRIPTA_LANG=en run_cli encrypt "$TMP/link.txt" >/dev/null 2>&1; then
  echo 'symlink encryption unexpectedly succeeded' >&2; exit 1
fi
[ ! -f "$TMP/link.txt.cvault" ]
printf '[20] Symlink safety guard: PASS\n'

# Current/parent path safety guard.
if run_cli encrypt . >/dev/null 2>&1; then echo 'dot path unexpectedly succeeded' >&2; exit 1; fi
printf '[21] dot-path safety guard: PASS\n'

# Language/system behavior after actual operations.
rm -f "$XDG_CONFIG_HOME/enkripta/language"
env -u LC_ALL -u LC_MESSAGES -u LANGUAGE PATH="/usr/bin:/bin" LANG=es_ES.UTF-8 "$INST" --help > "$TMP/help-es" 2>&1 || true
env -u LC_ALL -u LC_MESSAGES -u LANGUAGE PATH="/usr/bin:/bin" LANG=de_DE.UTF-8 "$INST" --help > "$TMP/help-de" 2>&1 || true
grep -F 'Uso:' "$TMP/help-es" >/dev/null
grep -F 'Usage:' "$TMP/help-de" >/dev/null
printf '[22] System locale auto-detection: PASS\n'

# Final installer refresh hooks.
grep -F -- 'default enkripta.desktop application/x-cvault' "$SIM_LOG/xdg-mime.log" >/dev/null
grep -F -- '-q' "$SIM_LOG/nemo.log" >/dev/null
printf '[23] MIME association + Nemo refresh invocation: PASS\n'

# Original Spanish command aliases: exercise the same real vault lifecycle, not only dispatch syntax.
printf 'spanish aliases\n' > "$TMP/alias.txt"
printf 'n\nAliasPassA123!\nAliasPassA123!\nn\n' | ENKRIPTA_LANG=es run_cli cifrar "$TMP/alias.txt" >/dev/null
AV="$TMP/alias.txt.cvault"
printf 'updated through alias\n' > "$TMP/alias.txt"
printf 'n\nAliasPassA123!\n' | ENKRIPTA_LANG=es run_cli actualizar "$TMP/alias.txt" >/dev/null
printf 'n\nAliasPassA123!\nAliasPassB456!\nAliasPassB456!\n' | ENKRIPTA_LANG=es run_cli anadir-contrasena "$AV" >/dev/null
printf 'n\nAliasPassB456!\nAliasPassC789!\nAliasPassC789!\n' | ENKRIPTA_LANG=es run_cli cambiar-contrasena "$AV" >/dev/null
printf 'n\nAliasPassC789!\ny\n' | ENKRIPTA_LANG=es run_cli eliminar-contrasena "$AV" >/dev/null
rm -f "$TMP/alias.txt"
printf 'n\nAliasPassA123!\n' | ENKRIPTA_LANG=es run_cli descifrar "$AV" >/dev/null
grep -Fx 'updated through alias' "$TMP/alias.txt" >/dev/null
printf 'n\nAliasMaster123!\nAliasMaster123!\n' | ENKRIPTA_LANG=es run_cli contrasena-maestra >/dev/null
[ -f "$HOME/.local/share/enkripta/master.verify" ]
printf 'y\n' | ENKRIPTA_LANG=es run_cli quitar-contrasena-maestra >/dev/null
[ ! -f "$HOME/.local/share/enkripta/master.verify" ]
rm -f "$TMP/alias.txt" "$AV"
printf '[24] Spanish command aliases: full vault lifecycle + master-password aliases: PASS\n'

# Real PTY: the show/hide choice must be asked once and reused across password fields.
printf 'PTY preference\n' > "$TMP/pty.txt"
printf 'n\nPtyPass123!\nPtyPass123!\ny\nPtyPass456!\nPtyPass456!\nn\n' > "$TMP/pty.answers"
script -q -c "$INST encrypt '$TMP/pty.txt'" "$TMP/pty.transcript" < "$TMP/pty.answers" >/dev/null
python - <<PY
from pathlib import Path
text = Path("$TMP/pty.transcript").read_text(errors='replace')
prompt = 'Do you want to display the password as plain text while typing instead of keeping it hidden? [y/N]: '
assert text.count(prompt) == 1, 'show/hide preference was requested more than once'
assert Path("$TMP/pty.txt.cvault").is_file()
PY
rm -f "$TMP/pty.txt" "$TMP/pty.txt.cvault"
printf '[25] Real PTY show/hide preference reuse: PASS\n'

printf '\nREAL-USE SIMULATION: 25 scenarios passed.\n'
