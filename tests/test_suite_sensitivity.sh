#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
chmod 755 "$TMP"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

make_case() {
    local name=$1
    cp -a "$ROOT_DIR/." "$TMP/$name"
    chmod -R a+rX "$TMP/$name"
    printf '%s' "$TMP/$name"
}

# Mutation 1: a too-permissive Nemo open action must be caught by the integration contract.
CASE1=$(make_case mutation-nemo-extension)
python3 - "$CASE1/script/enkripta-instalador.sh" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
old='Extensions=cvault;'
new='Extensions=any;'
assert s.count(old) == 1
p.write_text(s.replace(old,new))
PY
if bash "$CASE1/tests/test_integration_contract.sh" >/dev/null 2>&1; then
    fail 'integration contract did not detect a mutated Nemo extension filter'
fi
pass 'integration contract detects an over-permissive Nemo action'

# Mutation 2: an unsafe quoted %F field code must be caught by the integration contract.
CASE2=$(make_case mutation-nemo-field-code)
python3 - "$CASE2/script/enkripta-instalador.sh" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
old='gui-encrypt %F'
new='gui-encrypt "%F"'
assert s.count(old) == 1
p.write_text(s.replace(old,new))
PY
if bash "$CASE2/tests/test_integration_contract.sh" >/dev/null 2>&1; then
    fail 'integration contract did not detect a quoted Nemo %F field code'
fi
pass 'integration contract detects an unsafe quoted Nemo %F field code'

# Mutation 3: changing the Spanish GUI language selector text must be caught by a
# focused runtime smoke, without rerunning the whole cryptographic suite.
CASE3=$(make_case mutation-spanish-ui)
python3 - "$CASE3/script/enkripta-instalador.sh" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
old="MSG_ES[language.option]='Cambiar idioma: %s / %s'"
new="MSG_ES[language.option]='Switch language: %s / %s'"
assert s.count(old) == 1
p.write_text(s.replace(old,new))
PY
GUI_TMP="$TMP/gui-language"
mkdir -p "$GUI_TMP/home" "$GUI_TMP/config" "$GUI_TMP/data" "$GUI_TMP/bin"
python3 - "$CASE3/script/enkripta-instalador.sh" "$GUI_TMP/enkripta.sh" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
marker = 'cat > "$DEST_SCRIPT" <<\'ENKRIPTA_SH_EOF\'\n'
main = s.split(marker,1)[1].split('\nENKRIPTA_SH_EOF',1)[0]
Path(sys.argv[2]).write_text(main+'\n')
PY
chmod +x "$GUI_TMP/enkripta.sh"
cat > "$GUI_TMP/bin/zenity" <<'EOF'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >> "${ZENITY_LOG:?}"
state_file="${ZENITY_STATE:?}"
n=0
[ -f "$state_file" ] && n=$(cat "$state_file")
n=$((n+1)); printf '%s\n' "$n" > "$state_file"
if printf '%s\n' "$*" | grep -q -- '--list'; then
    [ "$n" -eq 1 ] && printf '%s\n' language
    exit 0
fi
exit 1
EOF
chmod +x "$GUI_TMP/bin/zenity"
: > "$GUI_TMP/log"
if HOME="$GUI_TMP/home" XDG_CONFIG_HOME="$GUI_TMP/config" XDG_DATA_HOME="$GUI_TMP/data" PATH="$GUI_TMP/bin:/usr/bin:/bin" LANG=C \
   ENKRIPTA_LANG=es ZENITY_LOG="$GUI_TMP/log" ZENITY_STATE="$GUI_TMP/state" \
   bash "$GUI_TMP/enkripta.sh" gui >/dev/null 2>&1; then :; fi
if ! grep -Fq 'Switch language: español / inglés' "$GUI_TMP/log"; then
    fail 'language regression smoke did not reproduce the mutated English string'
fi
pass 'focused GUI smoke detects an English string leaking into Spanish UI'

# Mutation 4: changing a translated printf placeholder must be rejected by the
# focused message-contract checker, without entering interactive operations.
CASE4=$(make_case mutation-placeholder)
python3 - "$CASE4/script/enkripta-instalador.sh" <<'PYMUT'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
old="MSG_EN[password.short]='The password must be at least %s characters long.'"
new="MSG_EN[password.short]='The password must be at least %d characters long.'"
assert s.count(old) == 1
p.write_text(s.replace(old,new))
PYMUT
if python3 - "$CASE4/script/enkripta-instalador.sh" <<'PYCONTRACT'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text().split('declare -A MSG_EN MSG_ES',1)[1].split('# Contraseña maestra:',1)[0]
line=next(x for x in s.splitlines() if x.startswith('MSG_EN[password.short]'))
other=next(x for x in s.splitlines() if x.startswith('MSG_ES[password.short]'))
raise SystemExit(1 if '%d' in line and '%s' in other else 0)
PYCONTRACT
then
    fail 'translation regression checker did not detect a placeholder contract mutation'
fi
pass 'focused translation checker detects printf placeholder mutations'

# Mutations 5-11: Nemo actions in Enkripta's language, and the zenity dialog quirks.
# Each mutated tree must fail the named suite AND print the expected marker, so a
# suite that merely breaks for another reason cannot pass as "detected".
mutate() { # mutate CASE OLD NEW   (OLD must occur exactly once; \n means a newline)
    python3 - "$1/script/enkripta-instalador.sh" "$2" "$3" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]); s = p.read_text()
old, new = (x.replace('\\n', '\n') for x in sys.argv[2:4])
assert s.count(old) == 1, old
p.write_text(s.replace(old, new))
PY
}
detected() { # detected CASE SUITE MARKER DESCRIPTION
    local out
    if out="$(bash "$1/tests/$2" 2>&1)"; then fail "$4 was not detected by $2"; fi
    printf '%s' "$out" | grep -Fq -- "$3" || fail "$4: $2 failed without reporting '$3'"
    pass "$4"
}
baseline="$(bash "$ROOT_DIR/tests/test_ui_aesthetics.sh" 2>&1 || true)"
printf '%s' "$baseline" | grep -Fq 'PASS: zenity dialogs use --entry' || fail 'the unmutated dialog contract must pass first'

C=$(make_case mutation-nemo-name-es)
mutate "$C" 'Exec="$bin" gui-encrypt %F' 'Name[es]=🔒 Cifrar con Enkripta\nExec="$bin" gui-encrypt %F'
detected "$C" test_integration_contract.sh 'Name[es]' 'reintroduced Name[es] in a Nemo action is detected'

C=$(make_case mutation-zenity-password)
mutate "$C" 'zenity --entry "${hide[@]}"' 'zenity --password'
detected "$C" test_ui_aesthetics.sh 'zenity dialog contract' 'going back to zenity --password is detected'

C=$(make_case mutation-entry-escape)
mutate "$C" '--text="$(zen_entry_text "$prompt")"' '--text="$prompt"'
detected "$C" test_ui_aesthetics.sh 'zenity dialog contract' 'unescaped "_" in --entry prompts is detected'

C=$(make_case mutation-list-escape)
mutate "$C" '--text="$(zen_list_text "$(msg menu.title "$base" "$slots_hint")")"' '--text="$(msg menu.title "$base" "$slots_hint")"'
detected "$C" test_ui_aesthetics.sh 'zenity dialog contract' 'unescaped markup in the --list title is detected'

C=$(make_case mutation-nemo-no-refresh)
mutate "$C" '    write_nemo_actions refresh || true\n    printf' '    printf'
detected "$C" test_enkripta.sh 'Nemo encrypt action follows -l to Spanish' 'a language switch that leaves Nemo untouched is detected'

C=$(make_case mutation-nemo-no-sync)
mutate "$C" 'GUI=1; sync_nemo_actions' 'GUI=1'
detected "$C" test_enkripta.sh 'GUI launch resyncs Nemo actions with the system language' 'a missing GUI resync of Nemo actions is detected'

C=$(make_case mutation-nemo-resurrect)
mutate "$C" 'if [ "$mode" != refresh ] || [ -f "$NEMO_ACT_OPEN" ]; then' 'if true; then'
detected "$C" test_enkripta.sh 'a deleted Nemo action was recreated by -l' 'resurrecting a deleted Nemo action is detected'

printf '%s\n' 'SUITE SENSITIVITY: known high-risk mutations are detected.'
