#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$ROOT_DIR/script/enkripta-instalador.sh"
TMP="$(mktemp -d)"
KEEP_PREVIEWS="${KEEP_PREVIEWS:-0}"
cleanup() { [ "$KEEP_PREVIEWS" = 1 ] || rm -rf "$TMP"; }
trap cleanup EXIT
MAIN="$TMP/enkripta.sh"
python3 - "$INSTALLER" "$MAIN" <<'PY'
from pathlib import Path
import sys
installer=Path(sys.argv[1]).read_text()
marker='cat > "$DEST_SCRIPT" <<\'ENKRIPTA_SH_EOF\'\n'
main=installer.split(marker,1)[1].split('\nENKRIPTA_SH_EOF',1)[0]
Path(sys.argv[2]).write_text(main+'\n')
PY
bash -n "$MAIN"

# Dialog contract: the real program against a zenity stub that records its arguments.
zfail() { printf 'FAIL: zenity dialog contract: %s\n' "$1" >&2; exit 1; }
ZD="$TMP/dialogs"; mkdir -p "$ZD/bin" "$ZD/home" "$ZD/data" "$ZD/config"
cat > "$ZD/bin/zenity" <<'ZEN'
#!/usr/bin/env bash
{ printf 'Z'; for a in "$@"; do printf '\t%s' "${a//$'\n'/ }"; done; printf '\n'; } >> "${ZLOG:?}"
for a in "$@"; do
    case "$a" in
        --entry) printf '%s\n' 'Passw0rd-123'; exit 0 ;;
        --question)
            n=0; [ -f "$ZSTATE" ] && n="$(cat "$ZSTATE")"; n=$((n + 1)); printf '%s' "$n" > "$ZSTATE"
            [ "$n" -eq 1 ] && exit "${ZPREF_RC:-1}"; exit 1 ;;
        --info|--error) exit 0 ;;
    esac
done
exit 1
ZEN
printf '#!/usr/bin/env bash\nexit 0\n' > "$ZD/bin/notify-send"
chmod +x "$ZD/bin/zenity" "$ZD/bin/notify-send"
zenv() { # zenv LANG PREF_RC command...: first question = show/hide preference (rc 0 = show), the rest answer "No"
    local lang="$1" rc="$2"; shift 2
    env HOME="$ZD/home" XDG_CONFIG_HOME="$ZD/config" XDG_DATA_HOME="$ZD/data" TMPDIR="$ZD" \
        PATH="$ZD/bin:/usr/bin:/bin" LC_ALL=C ENKRIPTA_LANG="$lang" \
        ZLOG="$ZD/log" ZSTATE="$ZD/state" ZPREF_RC="$rc" "$@"
}
zrun() { : > "$ZD/log"; rm -f "$ZD/state"; zenv "$@" >/dev/null 2>&1 || true; }
cat > "$ZD/check.py" <<'PYZ'
import sys
from pathlib import Path
log, lang, hidden, name = sys.argv[1:5]
hidden = hidden == '1'
calls = [l.split('\t')[1:] for l in Path(log).read_text().splitlines() if l.startswith('Z\t')]
T = {
    'en': dict(ok='OK', cancel='Cancel', yes='Yes', no='No',
               show='👁️  Show the password while typing', hide='🔒 Keep the password hidden',
               prompt='🆕 Step 1 of 2 — Create the MAIN password for "%s"'),
    'es': dict(ok='Aceptar', cancel='Cancelar', yes='Sí', no='No',
               show='👁️  Mostrarla mientras la escribo', hide='🔒 Mantenerla oculta',
               prompt="🆕 Paso 1 de 2 — Crea la contraseña PRINCIPAL para '%s'"),
}[lang]
def bad(msg):
    raise SystemExit(f'FAIL: zenity dialog contract [{lang}]: {msg}\n' + '\n'.join('  ' + ' '.join(c) for c in calls))
if not calls: bad('no zenity calls were recorded')
if any('--password' in c for c in calls): bad('--password ignores --text; --entry [--hide-text] must be used')
entries = [c for c in calls if '--entry' in c]
if len(entries) < 2: bad('expected the password entry and its confirmation')
for c in entries:
    if ('--hide-text' in c) != hidden: bad('--hide-text does not follow the saved preference')
    for a in ('--no-markup', '--ok-label=' + T['ok'], '--cancel-label=' + T['cancel']):
        if a not in c: bad('entry lacks ' + a)
prompt = T['prompt'] % name.replace('_', '__')   # --entry treats "_" as a mnemonic marker
if '--text=' + prompt not in entries[0]: bad('entry text is not the expected escaped prompt: ' + prompt)
questions = [c for c in calls if '--question' in c]
if len(questions) < 3: bad('expected the preference, second-password and delete-original questions')
if '--ok-label=' + T['show'] not in questions[0] or '--cancel-label=' + T['hide'] not in questions[0]:
    bad('preference dialog labels are not translated')
for c in questions[1:]:
    if '--ok-label=' + T['yes'] not in c or '--cancel-label=' + T['no'] not in c: bad('yes/no labels are not translated')
for c in calls:
    if not any(a.startswith('--ok-label=') for a in c): bad('dialog without --ok-label')
PYZ
NAME_UGLY='my_file_v2 & co.txt'
printf 'x\n' > "$ZD/$NAME_UGLY"
rm -f "$ZD"/*.cvault
zrun en 1 bash "$MAIN" gui-encrypt "$ZD/$NAME_UGLY"
python3 "$ZD/check.py" "$ZD/log" en 1 "$NAME_UGLY"
rm -f "$ZD"/*.cvault
zrun es 0 bash "$MAIN" gui-encrypt "$ZD/$NAME_UGLY"
python3 "$ZD/check.py" "$ZD/log" es 0 "$NAME_UGLY"
# --list parses its text as markup even with --no-markup: "&" and "<" must be escaped.
printf 'x\n' > "$ZD/R&D <x>.txt"
rm -f "$ZD"/*.cvault
printf 'n\nPassw0rd-123\nPassw0rd-123\nn\nn\n' | zenv en 1 bash "$MAIN" encrypt "$ZD/R&D <x>.txt" >/dev/null 2>&1
zrun en 1 bash "$MAIN" gui-menu "$ZD/R&D <x>.txt.cvault"
grep -Fq -- "--text=What do you want to do with 'R&amp;D &lt;x&gt;.txt.cvault' (1 password configured)?" "$ZD/log" \
    || zfail 'list title with "&" and "<" is not markup-escaped'
printf '%s\n' 'PASS: zenity dialogs use --entry, translated labels and escaped prompts/titles'

MSG_DEFS="$TMP/msg_defs.sh"
sed -n '/^declare -A MSG_EN MSG_ES$/,/^# Contraseña maestra:/p' "$MAIN" > "$MSG_DEFS"
{
  printf '%s\n' 'APP_TITLE="Enkripta"'
  printf '%s\n' 'LANG_CODE=en'
  cat <<'__MSG_HELPER__'
msg() {
    local key="$1"
    shift
    local fmt value
    if [ "$LANG_CODE" = es ]; then fmt="${MSG_ES[$key]}"; else fmt="${MSG_EN[$key]}"; fi
    printf -v value "$fmt" "$@"
    printf '%b' "$value"
}
__MSG_HELPER__
  cat "$MSG_DEFS"
  printf '%s\n' 'printf "%s\\n" "##PICKER_TITLE_EN##"; printf "%s\\n" "$(msg picker.title configured)"'
  printf '%s\n' 'printf "%s\\n" "##PICKER_ROWS_EN##"; for k in picker.encrypt.file picker.encrypt.dir picker.open picker.master.set picker.master.unset; do msg "$k"; printf "\\n"; done'
  printf '%s\n' 'printf "%s\\n" "##LANG_EN##"; msg language.option "English" "Spanish"; printf "\\n"; printf "%s\\n" "##MENU_ROWS_EN##"; for k in menu.decrypt menu.change menu.add menu.remove; do msg "$k"; printf "\\n"; done'
} > "$TMP/gen_en.sh"
{
  printf '%s\n' 'APP_TITLE="Enkripta"'
  printf '%s\n' 'LANG_CODE=es'
  cat <<'__MSG_HELPER__'
msg() {
    local key="$1"
    shift
    local fmt value
    if [ "$LANG_CODE" = es ]; then fmt="${MSG_ES[$key]}"; else fmt="${MSG_EN[$key]}"; fi
    printf -v value "$fmt" "$@"
    printf '%b' "$value"
}
__MSG_HELPER__
  cat "$MSG_DEFS"
  printf '%s\n' 'printf "%s\\n" "##PICKER_TITLE_ES##"; printf "%s\\n" "$(msg picker.title configurada)"'
  printf '%s\n' 'printf "%s\\n" "##PICKER_ROWS_ES##"; for k in picker.encrypt.file picker.encrypt.dir picker.open picker.master.set picker.master.unset; do msg "$k"; printf "\\n"; done'
  printf '%s\n' 'printf "%s\\n" "##LANG_ES##"; msg language.option "español" "inglés"; printf "\\n"; printf "%s\\n" "##MENU_ROWS_ES##"; for k in menu.decrypt menu.change menu.add menu.remove; do msg "$k"; printf "\\n"; done'
} > "$TMP/gen_es.sh"

bash "$TMP/gen_en.sh" > "$TMP/en.txt"
bash "$TMP/gen_es.sh" > "$TMP/es.txt"
FONT="$(fc-match -f '%{file}' 'Noto Sans' 2>/dev/null)"
[ -f "$FONT" ] || FONT="$(fc-match -f '%{file}' sans 2>/dev/null)"
[ -f "$FONT" ] || { echo 'SKIP: no usable font found for visual rendering'; exit 0; }
python3 - "$TMP/en.txt" "$TMP/es.txt" "$FONT" "$TMP" "$MAIN" <<'PY'
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import sys, textwrap

en=Path(sys.argv[1]).read_text().splitlines()
es=Path(sys.argv[2]).read_text().splitlines()
font_path=sys.argv[3]
out=Path(sys.argv[4])

def get(lines, marker):
    i=lines.index(marker)
    vals=[]
    for x in lines[i+1:]:
        if x.startswith('##'): break
        if x: vals.append(x)
    return vals

def get_one(lines, marker):
    i=lines.index(marker)
    return lines[i+1]

title_en=get_one(en,'##PICKER_TITLE_EN##')
title_es=get_one(es,'##PICKER_TITLE_ES##')
rows_en=get(en,'##PICKER_ROWS_EN##')
rows_es=get(es,'##PICKER_ROWS_ES##')
lang_en=get_one(en,'##LANG_EN##')
lang_es=get_one(es,'##LANG_ES##')
menu_en=get(en,'##MENU_ROWS_EN##')
menu_es=get(es,'##MENU_ROWS_ES##')

# Use the same nominal content widths as the Zenity dialogs in the program,
# with conservative margins for the actual text area.
font=ImageFont.truetype(font_path, 15)
small=ImageFont.truetype(font_path, 13)
title_font=ImageFont.truetype(font_path, 17)

def wrap(draw, text, width, f):
    words=text.replace('\n',' \n ').split(' ')
    lines=[]; cur=''
    for w in words:
        if w=='\\n' or w=='':
            continue
        cand=w if not cur else cur+' '+w
        if draw.textlength(cand,font=f) <= width:
            cur=cand
        else:
            if cur: lines.append(cur)
            cur=w
    if cur: lines.append(cur)
    return lines

def preview(name, title, rows, lang_option, width, height):
    img=Image.new('RGB',(width,height),'white')
    d=ImageDraw.Draw(img)
    d.rectangle((0,0,width-1,height-1),outline=(150,150,150),width=1)
    d.text((22,18),'Enkripta',font=title_font,fill='black')
    y=52
    for line in wrap(d,title,width-44,font):
        d.text((22,y),line,font=font,fill='black'); y += 21
    y += 10
    for row in rows+[lang_option]:
        d.text((34,y),'○',font=font,fill='black')
        d.text((60,y),row,font=font,fill='black')
        y += 34
    if y > height-15:
        raise SystemExit(f'{name}: content exceeds {width}x{height}: y={y}')
    img.save(out/name)
    return img

for label, title, rows, lang, W, H in [
    ('picker-en.png', title_en, rows_en, lang_en, 460, 340),
    ('picker-es.png', title_es, rows_es, lang_es, 460, 340),
    ('menu-en.png', "What do you want to do with 'secrets.cvault'?", menu_en, lang_en, 500, 330),
    ('menu-es.png', "¿Qué quieres hacer con 'secrets.cvault'?", menu_es, lang_es, 500, 330),
]:
    preview(label,title,rows,lang,W,H)

# Long-message metrics: make sure the two most constrained fixed-width
# dialogs can render without an unbounded one-line overflow.
for label, lines, W, H in [
    ('pw-choice-en', ['How would you like to enter the password for this operation?','👁️ Show it: the password will be visible as you type.','🔒 Keep it hidden: dots will be shown instead (recommended if someone can see your screen).'],420,260),
    ('pw-choice-es', ['¿Cómo quieres introducir la contraseña en esta operación?','👁️ Mostrarla: verás el texto tal como lo escribes.','🔒 Ocultarla: aparecerán puntos en su lugar (recomendado si alguien puede ver tu pantalla).'],420,260),
]:
    rendered=sum(max(1,len(wrap(ImageDraw.Draw(Image.new('RGB',(W,H))), t, W-48, small))) for t in lines)*18 + 80
    if rendered > H:
        raise SystemExit(f'{label}: estimated wrapped height {rendered}px exceeds {H}px')

# Aesthetic parity: Spanish should not force a substantially wider main-menu
# row than English. The menu is a shared 460px dialog.
for a,b,name in zip(rows_en,rows_es,['file','folder','vault','master-set','master-unset']):
    wa=ImageDraw.Draw(Image.new('RGB',(1,1))).textlength(a,font=font)
    wb=ImageDraw.Draw(Image.new('RGB',(1,1))).textlength(b,font=font)
    if max(wa,wb) > 400:
        raise SystemExit(f'{name}: row too wide ({wa:.0f}px EN / {wb:.0f}px ES)')

# --help is a CLI contract: it must stay textual even when Zenity is installed,
# so redirection/pipelines never unexpectedly launch a GUI.
source=Path(sys.argv[5]).read_text()
assert '--help|-h)' in source
assert 'usage 0 1' in source
print('PASS: explicit --help remains a deterministic textual CLI output')

# Validate the same strings with the real Pango text engine available on the host,
# rather than relying only on Pillow's font rasterizer.
import ctypes
from ctypes import c_void_p, c_char_p, c_int, POINTER, Structure
class PangoRect(Structure):
    _fields_=[('x',c_int),('y',c_int),('width',c_int),('height',c_int)]
pango=ctypes.CDLL('libpango-1.0.so.0')
pangocairo=ctypes.CDLL('libpangocairo-1.0.so.0')
pangocairo.pango_cairo_font_map_get_default.restype=c_void_p
pango.pango_font_map_create_context.argtypes=[c_void_p]; pango.pango_font_map_create_context.restype=c_void_p
pango.pango_font_description_from_string.argtypes=[c_char_p]; pango.pango_font_description_from_string.restype=c_void_p
pango.pango_layout_new.argtypes=[c_void_p]; pango.pango_layout_new.restype=c_void_p
pango.pango_layout_set_font_description.argtypes=[c_void_p,c_void_p]
pango.pango_layout_set_text.argtypes=[c_void_p,c_char_p,c_int]
pango.pango_layout_set_width.argtypes=[c_void_p,c_int]
pango.pango_layout_set_wrap.argtypes=[c_void_p,c_int]
pango.pango_layout_get_pixel_size.argtypes=[c_void_p,POINTER(c_int),POINTER(c_int)]
pango.pango_font_description_free.argtypes=[c_void_p]
font_map=pangocairo.pango_cairo_font_map_get_default()
context=pango.pango_font_map_create_context(font_map)
desc=pango.pango_font_description_from_string(b'Sans 11')
layout=pango.pango_layout_new(context)
pango.pango_layout_set_font_description(layout,desc)
for label, text, max_width in [
    ('EN picker title', title_en, 416),
    ('ES picker title', title_es, 416),
    ('EN language option', lang_en, 400),
    ('ES language option', lang_es, 400),
    ('EN menu rows', '\n'.join(menu_en), 456),
    ('ES menu rows', '\n'.join(menu_es), 456),
]:
    pango.pango_layout_set_text(layout,text.encode('utf-8'),-1)
    w=c_int(); h=c_int(); pango.pango_layout_get_pixel_size(layout,ctypes.byref(w),ctypes.byref(h))
    if w.value > max_width:
        raise SystemExit(f'{label}: Pango width {w.value}px exceeds {max_width}px')
pango.pango_font_description_free(desc)
print('PASS: real Pango metrics fit the constrained UI text areas')

# Ensure rendered previews contain actual glyph pixels; an all-background image
# would make a false-positive layout test.
from PIL import ImageChops
for filename in ('picker-en.png','picker-es.png','menu-en.png','menu-es.png'):
    img=Image.open(out/filename).convert('RGB')
    diff=ImageChops.difference(img,Image.new('RGB',img.size,'white'))
    if diff.getbbox() is None:
        raise SystemExit(f'{filename}: rendered preview is empty')
print('PASS: rendered EN/ES previews contain visible text pixels')

print('PASS: fixed-width dialog text fits the designed layouts')
print('PASS: EN/ES main-menu rows remain within shared width budget')
print(f'RENDERED: {out}/picker-en.png')
print(f'RENDERED: {out}/picker-es.png')
print(f'RENDERED: {out}/menu-en.png')
print(f'RENDERED: {out}/menu-es.png')
PY
