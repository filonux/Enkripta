#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$ROOT_DIR/script/enkripta-instalador.sh"
TMP="$(mktemp -d)"
trap 'rc=$?; rm -rf "$TMP"; exit $rc' EXIT
chmod 755 "$TMP"

pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
skip() { printf 'SKIP: %s\n' "$1"; }

command -v runuser >/dev/null 2>&1 || fail 'runuser is required for the non-root integration contract'
id nobody >/dev/null 2>&1 || fail 'nobody user is required for the non-root integration contract'
command -v python3 >/dev/null 2>&1 || fail 'python3 is required for the integration contract'

BASE_HOME="$TMP/home"
BASE_DATA="$BASE_HOME/.local/share"
BASE_CONFIG="$BASE_HOME/.config"
mkdir -p "$BASE_HOME" "$BASE_DATA" "$BASE_CONFIG"
chmod 700 "$BASE_HOME"
chown -R nobody:nogroup "$BASE_HOME" 2>/dev/null || chown -R nobody:nobody "$BASE_HOME"

run_user() {
    runuser -u nobody -- env \
        TMPDIR=/tmp \
        HOME="$BASE_HOME" \
        XDG_CONFIG_HOME="$BASE_CONFIG" \
        XDG_DATA_HOME="$BASE_DATA" \
        LC_ALL=C \
        LANG=C \
        "$@"
}

run_user bash "$INSTALLER" >/dev/null

INST="$BASE_HOME/.local/bin/enkripta.sh"
APP="$BASE_DATA/applications/enkripta.desktop"
MIME="$BASE_DATA/mime/packages/enkripta-cvault.xml"
ENC="$BASE_DATA/nemo/actions/enkripta-cifrar.nemo_action"
OPEN="$BASE_DATA/nemo/actions/enkripta-abrir.nemo_action"
DESKTOP="$BASE_HOME/Desktop/enkripta.desktop"
APP_ICON="$BASE_DATA/icons/hicolor/scalable/apps/enkripta.svg"
MIME_ICON="$BASE_DATA/icons/hicolor/scalable/mimetypes/application-x-cvault.svg"
MIMEAPPS="$BASE_CONFIG/mimeapps.list"
for file in "$INST" "$APP" "$MIME" "$ENC" "$OPEN" "$DESKTOP" "$APP_ICON" "$MIME_ICON"; do
    [ -f "$file" ] || fail "missing installed artifact: $file"
done
pass 'installer produced all required integration artifacts under a real non-root HOME'

# Idempotence: a second installation must not duplicate desktop/MIME state.
run_user bash "$INSTALLER" >/dev/null
[ "$(grep -c '^application/x-cvault=enkripta.desktop;*$' "$MIMEAPPS" 2>/dev/null || true)" -eq 1 ] \
    || fail 'MIME association was duplicated by a second installation'
[ -f "$BASE_DATA/mime/mime.cache" ] || fail 'per-user MIME cache was not refreshed'
pass 'installer is idempotent and refreshes the per-user MIME cache'

# Static contract: the generated files must contain only the expected integration values.
cat > "$TMP/check_contract.py" <<'PY'
import configparser
import pathlib
import sys
import xml.etree.ElementTree as ET

app, enc, opn, mime, shortcut_path = map(pathlib.Path, sys.argv[1:])

def keyfile(path, section=None):
    parser = configparser.ConfigParser(interpolation=None, strict=True)
    parser.optionxform = str
    parser.read(path, encoding='utf-8')
    expected = section or ('Desktop Entry' if path.suffix == '.desktop' else 'Nemo Action')
    assert parser.sections() == [expected], (path, parser.sections())
    return parser[expected]

a = keyfile(app)
assert a['Type'] == 'Application'
assert a['Terminal'] == 'false'
assert a['Exec'].endswith(' gui %F') and a['Exec'].startswith('"')
assert a['MimeType'] == 'application/x-cvault;'
assert a['GenericName'] == 'File and folder encryption'
assert a['GenericName[es]'] == 'Cifrado de carpetas y archivos'
assert a['Comment[es]'].startswith('Cifra y descifra')
assert a['Keywords[es]'].startswith('cifrar;cifrado')


def action(path, expected_ext, tail, name):
    s = keyfile(path)
    assert s['Active'] == 'true'
    assert s['Selection'] == 'notnone'
    assert s['Extensions'] == expected_ext
    assert s['Exec'].startswith('"') and s['Exec'].endswith(tail + ' %F')
    assert not s['Exec'].endswith('%F"')
    assert s['Name'] == name
    assert s['Comment']
    # Nemo resolves Name[xx] by the SYSTEM locale: the actions are written already
    # translated into Enkripta's language, so no [xx] key may exist.
    assert not [k for k in s if '[' in k], list(s)


action(enc, 'any;', 'gui-encrypt', '🔒 Encrypt with Enkripta')
action(opn, 'cvault;', 'gui-menu', '🔓 Open Enkripta vault')

shortcut = keyfile(shortcut_path, 'Desktop Entry')
assert shortcut['Exec'] == a['Exec']
assert shortcut['GenericName'] == a['GenericName']
assert shortcut['GenericName[es]'] == a['GenericName[es]']
assert shortcut['Comment'] == a['Comment']
assert shortcut['Comment[es]'] == a['Comment[es]']
assert shortcut['MimeType'] == 'application/x-cvault;'
assert shortcut['Icon'] == a['Icon']

root = ET.parse(mime).getroot()
ns = {'m': 'http://www.freedesktop.org/standards/shared-mime-info'}
mt = root.find('m:mime-type', ns)
assert mt is not None and mt.attrib.get('type') == 'application/x-cvault'
glob_node = mt.find('m:glob', ns)
assert glob_node is not None and glob_node.attrib.get('pattern') == '*.cvault'
comments = mt.findall('m:comment', ns)
xml_lang = '{http://www.w3.org/XML/1998/namespace}lang'
assert any(c.get(xml_lang) == 'es' and (c.text or '') == 'Vault cifrado de Enkripta' for c in comments)
assert any(c.get(xml_lang) is None and (c.text or '') == 'Encrypted Enkripta vault' for c in comments)
print('Desktop/Nemo/MIME static contract: PASS')
PY
python3 "$TMP/check_contract.py" "$APP" "$ENC" "$OPEN" "$MIME" "$DESKTOP"
pass 'Desktop Entry, Nemo Actions and MIME XML satisfy the expected integration contract'

# Real GIO MIME resolution, including a content-shaped .cvault that is also a valid tar file.
mkdir -p "$TMP/mime-check"
printf 'payload' > "$TMP/mime-check/inside.txt"
tar -cf "$TMP/mime-check/sample.tar" -C "$TMP/mime-check" inside.txt
cp "$TMP/mime-check/sample.tar" "$BASE_HOME/sample.cvault"
cat > "$TMP/check_gio.py" <<'PY'
import ctypes
import os
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
gio = ctypes.CDLL('libgio-2.0.so.0')
glib = ctypes.CDLL('libglib-2.0.so.0')
gio.g_content_type_guess.argtypes = [ctypes.c_char_p, ctypes.c_void_p, ctypes.c_size_t, ctypes.POINTER(ctypes.c_int)]
gio.g_content_type_guess.restype = ctypes.c_void_p
glib.g_free.argtypes = [ctypes.c_void_p]
uncertain = ctypes.c_int()
ptr = gio.g_content_type_guess(os.fsencode(str(path)), None, 0, ctypes.byref(uncertain))
assert ptr, 'g_content_type_guess returned NULL'
ctype = ctypes.string_at(ptr).decode('utf-8')
glib.g_free(ptr)
assert ctype == 'application/x-cvault', ctype
assert uncertain.value == 0, uncertain.value
print('GIO content type:', ctype)
PY
run_user env XDG_DATA_HOME="$BASE_DATA" XDG_CONFIG_HOME="$BASE_CONFIG" python3 "$TMP/check_gio.py" "$BASE_HOME/sample.cvault"
pass 'real GLib/GIO resolves tar-shaped .cvault files as application/x-cvault'

# Real xdg-mime association query: validate the consumer-facing default, not file(1) heuristics.
DEFAULT_APP="$(run_user xdg-mime query default application/x-cvault 2>/dev/null || true)"
[ "$DEFAULT_APP" = 'enkripta.desktop' ] || fail "xdg-mime default is '$DEFAULT_APP', expected enkripta.desktop"
pass 'xdg-mime reports enkripta.desktop as the default handler for application/x-cvault'
cat > "$TMP/check_gio_default.py" <<'PY2'
import ctypes

gio = ctypes.CDLL('libgio-2.0.so.0')
gio.g_app_info_get_default_for_type.argtypes = [ctypes.c_char_p, ctypes.c_int]
gio.g_app_info_get_default_for_type.restype = ctypes.c_void_p
gio.g_app_info_get_id.argtypes = [ctypes.c_void_p]
gio.g_app_info_get_id.restype = ctypes.c_char_p
gobject = ctypes.CDLL('libgobject-2.0.so.0')
gobject.g_object_unref.argtypes = [ctypes.c_void_p]
app = gio.g_app_info_get_default_for_type(b'application/x-cvault', 0)
assert app, 'GLib found no default application for application/x-cvault'
app_id = gio.g_app_info_get_id(app).decode('utf-8')
gobject.g_object_unref(app)
assert app_id == 'enkripta.desktop', app_id
print('GIO default application:', app_id)
PY2
run_user python3 "$TMP/check_gio_default.py"
pass 'real GLib/GIO resolves enkripta.desktop as the default application'

# Mirror Nemo's selection contract with edge cases relevant to the generated actions.
cat > "$TMP/check_nemo_matrix.py" <<'PY'
import pathlib
import sys

enc = pathlib.Path(sys.argv[1]).read_text(encoding='utf-8')
opn = pathlib.Path(sys.argv[2]).read_text(encoding='utf-8')

def value(text, key):
    for line in text.splitlines():
        if line.startswith(key + '='):
            return line.split('=', 1)[1]
    raise AssertionError(key)

def visible(text, names):
    if not names:
        return False
    ext = value(text, 'Extensions')
    parts = [p.lower() for p in ext.split(';') if p]
    if parts == ['any']:
        return True
    return all(any(name.lower().endswith('.' + e) or name.lower().endswith(e) for e in parts) for name in names)

assert not visible(enc, [])
assert visible(enc, ['plain.txt'])
assert visible(enc, ['plain.txt', 'directory'])
assert not visible(opn, ['plain.txt'])
assert not visible(opn, ['vault.cvault', 'plain.txt'])
assert visible(opn, ['vault.cvault'])
assert visible(opn, ['VAULT.CVAULT'])
assert visible(opn, ['one.cvault', 'two.CvAuLt'])
print('Nemo selection matrix: PASS')
PY
python3 "$TMP/check_nemo_matrix.py" "$ENC" "$OPEN"
pass 'Nemo action visibility contract covers empty, single, multiple, mixed and case-insensitive selections'

# GLib's real shell parser is used because Nemo ultimately spawns the action through GLib.
cat > "$TMP/check_shell.py" <<'PY'
import ctypes
import os

lib = ctypes.CDLL('libglib-2.0.so.0')
lib.g_shell_parse_argv.argtypes = [ctypes.c_char_p, ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.POINTER(ctypes.c_char_p)), ctypes.POINTER(ctypes.c_void_p)]
lib.g_shell_parse_argv.restype = ctypes.c_int
lib.g_strfreev.argtypes = [ctypes.POINTER(ctypes.c_char_p)]
lib.g_shell_quote.argtypes = [ctypes.c_char_p]
lib.g_shell_quote.restype = ctypes.c_void_p
lib.g_free.argtypes = [ctypes.c_void_p]

paths = [
    '/tmp/plain.txt',
    '/tmp/space name.txt',
    "/tmp/apostrophe's.txt",
    '/tmp/semi;colon$cash.txt',
    '/tmp/unicode-áé.txt',
    '/tmp/glob[1]*.txt',
]
quoted = []
for path in paths:
    ptr = lib.g_shell_quote(os.fsencode(path))
    assert ptr
    quoted.append(ctypes.string_at(ptr).decode('utf-8'))
    lib.g_free(ptr)
command = '/usr/bin/true ' + ' '.join(quoted)
argc = ctypes.c_int()
argv = ctypes.POINTER(ctypes.c_char_p)()
err = ctypes.c_void_p()
assert lib.g_shell_parse_argv(command.encode(), ctypes.byref(argc), ctypes.byref(argv), ctypes.byref(err))
parsed = [argv[i].decode('utf-8') for i in range(argc.value)]
assert parsed == ['/usr/bin/true', *paths], parsed
lib.g_strfreev(argv)
print('GLib shell parsing: PASS')
PY
python3 "$TMP/check_shell.py"
pass 'Nemo %F paths remain safe for spaces, quotes, shell metacharacters and Unicode'

# A path with spaces in HOME must be safely quoted in the generated launcher and actions.
SPACE_HOME="$TMP/home with spaces"
SPACE_DATA="$SPACE_HOME/.local/share"
SPACE_CONFIG="$SPACE_HOME/.config"
mkdir -p "$SPACE_HOME" "$SPACE_DATA" "$SPACE_CONFIG"
chown -R nobody:nogroup "$SPACE_HOME" 2>/dev/null || chown -R nobody:nobody "$SPACE_HOME"
runuser -u nobody -- env TMPDIR=/tmp HOME="$SPACE_HOME" XDG_DATA_HOME="$SPACE_DATA" XDG_CONFIG_HOME="$SPACE_CONFIG" LC_ALL=C LANG=C \
    bash "$INSTALLER" >/dev/null
cat > "$TMP/check_space_home.py" <<'PY'
import configparser
import ctypes
import pathlib
import sys

paths = [pathlib.Path(x) for x in sys.argv[1:]]
lib = ctypes.CDLL('libglib-2.0.so.0')
lib.g_shell_parse_argv.argtypes = [ctypes.c_char_p, ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.POINTER(ctypes.c_char_p)), ctypes.POINTER(ctypes.c_void_p)]
lib.g_shell_parse_argv.restype = ctypes.c_int
lib.g_strfreev.argtypes = [ctypes.POINTER(ctypes.c_char_p)]

def parse(path, section, key):
    c = configparser.ConfigParser(interpolation=None)
    c.optionxform = str
    c.read(path, encoding='utf-8')
    cmd = c[section][key]
    expanded = cmd.replace('%F', "'/tmp/odd name; $cash.txt'")
    argc = ctypes.c_int(); argv = ctypes.POINTER(ctypes.c_char_p)(); err = ctypes.c_void_p()
    assert lib.g_shell_parse_argv(expanded.encode(), ctypes.byref(argc), ctypes.byref(argv), ctypes.byref(err)), (path, cmd)
    assert argc.value == 3, (path, cmd, argc.value)
    parsed = [argv[i].decode('utf-8') for i in range(argc.value)]
    assert parsed[1] in ('gui', 'gui-encrypt', 'gui-menu'), parsed
    assert parsed[2] == '/tmp/odd name; $cash.txt', parsed
    lib.g_strfreev(argv)
    assert cmd.startswith('"') and not cmd.endswith('%F"'), (path, cmd)

parse(paths[0], 'Desktop Entry', 'Exec')
parse(paths[1], 'Nemo Action', 'Exec')
parse(paths[2], 'Nemo Action', 'Exec')
print('space-containing HOME command parsing: PASS')
PY
python3 "$TMP/check_space_home.py" \
    "$SPACE_DATA/applications/enkripta.desktop" \
    "$SPACE_DATA/nemo/actions/enkripta-cifrar.nemo_action" \
    "$SPACE_DATA/nemo/actions/enkripta-abrir.nemo_action"
pass 'Desktop Entry and Nemo Actions remain executable when HOME contains spaces'

# Nemo actions follow Enkripta's language, not the system's: -l rewrites them.
mkdir -p "$TMP/nemo-en" "$TMP/nemo-es"
cp "$ENC" "$OPEN" "$TMP/nemo-en/"
run_user "$INST" --toggle-language >/dev/null
cp "$ENC" "$OPEN" "$TMP/nemo-es/"
run_user "$INST" --toggle-language >/dev/null
rm -f "$BASE_CONFIG/enkripta/language"

# Real GLib key-file locale resolution: Desktop Entry keys follow the system locale;
# Nemo actions return Enkripta's language whatever the system locale is.
cat > "$TMP/check_locales.py" <<'PY'
import ctypes
import os
import pathlib
import sys

app, enc, opn, enc_es, opn_es = map(pathlib.Path, sys.argv[1:])
lib = ctypes.CDLL('libglib-2.0.so.0')
lib.g_key_file_new.restype = ctypes.c_void_p
lib.g_key_file_load_from_file.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int, ctypes.POINTER(ctypes.c_void_p)]
lib.g_key_file_load_from_file.restype = ctypes.c_int
lib.g_key_file_get_locale_string.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p, ctypes.POINTER(ctypes.c_void_p)]
lib.g_key_file_get_locale_string.restype = ctypes.c_void_p
lib.g_key_file_free.argtypes = [ctypes.c_void_p]
lib.g_free.argtypes = [ctypes.c_void_p]

def get(path, section, key, locale):
    keyfile = lib.g_key_file_new(); err = ctypes.c_void_p()
    assert lib.g_key_file_load_from_file(keyfile, str(path).encode(), 0, ctypes.byref(err))
    ptr = lib.g_key_file_get_locale_string(keyfile, section.encode(), key.encode(), locale.encode(), ctypes.byref(err))
    assert ptr, (path, key, locale)
    value = ctypes.string_at(ptr).decode('utf-8')
    lib.g_free(ptr); lib.g_key_file_free(keyfile)
    return value

os.environ['LANGUAGE'] = 'en:es'
assert get(app, 'Desktop Entry', 'GenericName', 'en_US').startswith('File and folder encryption')
os.environ['LANGUAGE'] = 'es:en'
assert get(app, 'Desktop Entry', 'GenericName', 'es_ES').startswith('Cifrado de carpetas y archivos')
for lang, locale in (('en:es', 'en_US'), ('es:en', 'es_ES')):
    os.environ['LANGUAGE'] = lang
    assert get(enc, 'Nemo Action', 'Name', locale).endswith('Encrypt with Enkripta')
    assert get(opn, 'Nemo Action', 'Name', locale).endswith('Open Enkripta vault')
    assert get(enc_es, 'Nemo Action', 'Name', locale).endswith('Cifrar con Enkripta')
    assert get(opn_es, 'Nemo Action', 'Name', locale).endswith('Abrir vault Enkripta')
    assert get(enc_es, 'Nemo Action', 'Comment', locale).startswith('Cifra el archivo')
print('GLib localized key resolution: PASS')
PY
python3 "$TMP/check_locales.py" "$APP" "$ENC" "$OPEN" \
    "$TMP/nemo-es/enkripta-cifrar.nemo_action" "$TMP/nemo-es/enkripta-abrir.nemo_action"
pass 'real GLib locale resolution: Desktop Entry follows the system, Nemo actions follow Enkripta'

# Native smoke tests are opportunistic and explicitly reported as SKIP when the host lacks the GUI stack.
if command -v nemo >/dev/null 2>&1 && command -v xvfb-run >/dev/null 2>&1 && command -v dbus-run-session >/dev/null 2>&1; then
    NEMO_LOG="$TMP/nemo-native.log"
    set +e
    timeout 8s runuser -u nobody -- env HOME="$BASE_HOME" XDG_DATA_HOME="$BASE_DATA" XDG_CONFIG_HOME="$BASE_CONFIG" NEMO_DEBUG=Actions \
        xvfb-run -a dbus-run-session -- nemo --debug >"$NEMO_LOG" 2>&1
    nemo_rc=$?
    set -e
    if grep -Eq 'Nemo|nemo' "$NEMO_LOG"; then
        pass "native Nemo startup under Xvfb produced diagnostics (exit $nemo_rc)"
    else
        fail 'native Nemo smoke ran but produced no diagnostic output'
    fi
else
    skip 'native Nemo smoke unavailable in this execution image; the GIO/GLib contract is still exercised for real'
fi

if command -v zenity >/dev/null 2>&1 && command -v xvfb-run >/dev/null 2>&1; then
    if zenity --help-all 2>&1 | grep -q -- '--timeout'; then
        set +e
        timeout 5s xvfb-run -a zenity --list --timeout=1 --radiolist \
            --column='' --column='Text' --column='id' TRUE Encrypt encrypt \
            --hide-column=3 --print-column=3 >/dev/null 2>&1
        zenity_rc=$?
        set -e
        [ "$zenity_rc" -eq 0 ] || [ "$zenity_rc" -eq 124 ] || fail "native Zenity list smoke returned $zenity_rc"
        pass "native Zenity list/parser smoke under Xvfb (exit $zenity_rc)"
    else
        skip 'native Zenity installed but this build has no timeout option for noninteractive smoke'
    fi
else
    skip 'native Zenity smoke unavailable in this execution image'
fi

# Documentation contract: relative Markdown/HTML links and documented CLI surface.
python3 - "$ROOT_DIR" "$INSTALLER" <<'PY'
from pathlib import Path
import re, sys
root=Path(sys.argv[1]); script=Path(sys.argv[2]).read_text(encoding='utf-8')
files=list(root.rglob('*.md'))+[root/'.github'/'pull_request_template']
link_pat=re.compile(r'\[[^\]]+\]\(([^)]+)\)')
html_pat=re.compile(r'(?:src|href)=["\']([^"\']+)["\']')
errors=[]
for f in files:
    text=f.read_text(encoding='utf-8')
    for target in link_pat.findall(text)+html_pat.findall(text):
        target=target.strip()
        if not target or target.startswith('#') or re.match(r'^[a-zA-Z][a-zA-Z0-9+.-]*:', target):
            continue
        path=(f.parent/target.split('#',1)[0]).resolve()
        if not path.is_file() and not path.is_dir():
            errors.append(f'{f.relative_to(root)} -> {target}')
for f in files:
    text=f.read_text(encoding='utf-8')
    if '[tu-email-o-usuario-de-contacto]' in text or 'LICENSE)' in text:
        errors.append(f'{f.relative_to(root)} contains stale placeholder/reference')
for name in ('README.md','README.es.md'):
    text=(root/name).read_text(encoding='utf-8')
    if '](' + ('LICENSE.txt') + ')' not in text:
        errors.append(f'{name} does not link directly to LICENSE.txt')
text=(root/'README.md').read_text(encoding='utf-8')
cmds=re.findall(r'`enkripta\.sh ([a-z][a-z0-9-]*)(?: [^`]*)?`', text)
case_arms=re.findall(r'^    ([^\n]+)\)', script, re.M)
flat=set()
for arm in case_arms:
    for token in arm.split('|'):
        token=token.strip()
        if re.fullmatch(r'[a-z][a-z0-9-]*', token): flat.add(token)
errors.extend(f'README documents absent CLI command: {c}' for c in sorted(set(cmds)-flat-{'--version'}))
if errors:
    print('\n'.join(errors), file=sys.stderr)
    raise SystemExit(1)
print('Documentation links, local assets, placeholders, LICENSE targets and README CLI examples: PASS')
PY
pass 'Documentation and README contract is valid'
printf '%s\n' 'INTEGRATION CONTRACT: completed'
