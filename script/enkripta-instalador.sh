#!/usr/bin/env bash
#
# Copyright (C) 2026 Filonux
#
# Licencia:
# Enkripta es software libre distribuido bajo los términos de la
# GNU General Public License versión 3 (GPLv3).
# Consulte el archivo LICENSE.txt para obtener el texto completo de la licencia.
#
# enkripta-instalador.sh — instalador de Enkripta para Cinnamon/Nemo (Linux
# Mint) en un solo archivo: lleva embebidos el programa (enkripta.sh) y su
# icono, así que puedes moverlo o descargarlo suelto y funciona igual.
#
# Instala: el programa en ~/.local/bin, su icono, un acceso en el menú de
# Accesorios, el tipo MIME .cvault (con Enkripta como predeterminado), dos
# acciones de clic derecho en Nemo —🔒 Cifrar / 🔓 Abrir vault, en el idioma
# de Enkripta, no el del sistema, y quitables/añadibles desde su menú— y un
# acceso directo en el Escritorio.
#
# Uso:
#   ./enkripta-instalador.sh                 instala/actualiza
#   ./enkripta-instalador.sh --desinstalar   quita todo, sin dejar rastro
#   ./enkripta-instalador.sh -l              cambia el idioma
#   ./enkripta-instalador.sh --ayuda         muestra la ayuda
#
# No hace falta sudo: se instala solo en tu carpeta personal.

set -euo pipefail

BIN_DIR="$HOME/.local/bin"
APPS_DIR="$HOME/.local/share/applications"
MIME_DIR="$HOME/.local/share/mime/packages"
NEMO_ACTIONS_DIR="$HOME/.local/share/nemo/actions"
ICON_APPS_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"
ICON_MIME_DIR="$HOME/.local/share/icons/hicolor/scalable/mimetypes"

DEST_SCRIPT="$BIN_DIR/enkripta.sh"
DEST_ICON_APP="$ICON_APPS_DIR/enkripta.svg"
DEST_ICON_MIME="$ICON_MIME_DIR/application-x-cvault.svg"
DESKTOP_FILE="$APPS_DIR/enkripta.desktop"
MIME_XML="$MIME_DIR/enkripta-cvault.xml"
ACTION_ENCRYPT="$NEMO_ACTIONS_DIR/enkripta-cifrar.nemo_action"
ACTION_OPEN="$NEMO_ACTIONS_DIR/enkripta-abrir.nemo_action"
DATA_DIR="$HOME/.local/share/enkripta"
MIME_ROOT="${MIME_DIR%/packages}"
ICON_ROOT="${ICON_APPS_DIR%/scalable/apps}"


# ---------- Language ----------
LANG_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/enkripta"
LANG_FILE="$LANG_CONFIG_DIR/language"
detect_language() {
    local locale="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}"
    case "$locale" in
        C|POSIX|C.*|POSIX.*) printf 'en'; return ;;
    esac
    if [ -n "${LANGUAGE:-}" ]; then
        case "${LANGUAGE%%:*}" in
            es*) printf 'es'; return ;;
            en*) printf 'en'; return ;;
        esac
    fi
    case "$locale" in
        es*) printf 'es' ;;
        *) printf 'en' ;;
    esac
}
load_language() {
    local saved="${ENKRIPTA_LANG:-}"
    if [ -z "$saved" ] && [ -f "$LANG_FILE" ]; then IFS= read -r saved < "$LANG_FILE" || true; fi
    case "$saved" in es|en) printf '%s' "$saved" ;; *) detect_language ;; esac
}
LANG_CODE="$(load_language)"
other_language() { [ "$LANG_CODE" = "es" ] && printf 'en' || printf 'es'; }
set_language() {
    local new_lang="$1" tmp
    mkdir -p "$LANG_CONFIG_DIR"
    tmp="$(mktemp "${LANG_FILE}.XXXXXX")"
    if ! printf '%s\n' "$new_lang" > "$tmp" || ! chmod 600 "$tmp" || ! mv -f -- "$tmp" "$LANG_FILE"; then
        rm -f -- "$tmp"
        return 1
    fi
    LANG_CODE="$new_lang"
}
msg() {
    local key="$1" fmt value a; local -a safe=()
    shift
    if [ "$LANG_CODE" = "es" ]; then fmt="${MSG_ES[$key]}"; else fmt="${MSG_EN[$key]}"; fi
    # Igual que en enkripta.sh: los argumentos (rutas, opciones del usuario...)
    # nunca se interpretan como formato ni como escapes de terminal.
    for a in "$@"; do safe+=("${a//[[:cntrl:]]/?}"); done
    printf -v value "$fmt" "${safe[@]}"
    printf '%s' "$value"
}
toggle_language() {
    set_language "$(other_language)"
    printf '%s\n' "$(msg language.changed "$(msg "language.$LANG_CODE")")"
}
declare -A MSG_EN MSG_ES
MSG_EN[language.changed]='Language changed to %s.'
MSG_ES[language.changed]='Idioma cambiado a %s.'
MSG_EN[language.en]='English'; MSG_EN[language.es]='Spanish'
MSG_ES[language.en]='inglés'; MSG_ES[language.es]='español'
MSG_EN[help]='Enkripta — installer for Cinnamon/Nemo (Linux Mint)

Usage:
  %s                 install or update the integration
  %s --uninstall     remove everything Enkripta installed, leaving no trace
  %s --help          show this help
  %s -l, --toggle-language  switch the interface between English and Spanish

No sudo is required: everything is installed in your personal home folder.'
MSG_ES[help]='Enkripta — instalador para Cinnamon/Nemo (Linux Mint)

Uso:
  %s                 instala o actualiza toda la integración
  %s --desinstalar   quita todo lo que Enkripta instaló, sin dejar rastro
  %s --ayuda         muestra esta ayuda
  %s -l, --toggle-language  cambia la interfaz entre español e inglés

No hace falta sudo: todo se instala en tu carpeta personal.'
MSG_EN[remove]='Uninstalling Enkripta…'; MSG_ES[remove]='Desinstalando Enkripta...'
MSG_EN[removed]='Enkripta was completely uninstalled: program, menu and desktop shortcuts, right-click actions, .cvault association, settings and master password data. Your .cvault files were not touched.'; MSG_ES[removed]='Enkripta se ha desinstalado por completo: programa, accesos del menú y del escritorio, clic derecho, asociación .cvault, ajustes y datos de la contraseña maestra. Tus archivos .cvault no se han tocado.'
MSG_EN[remove.partial]='Some Enkripta files could not be removed (see the errors above). Fix the permissions and run the uninstall again.'; MSG_ES[remove.partial]='No se han podido borrar algunos archivos de Enkripta (mira los errores de arriba). Corrige los permisos y vuelve a ejecutar la desinstalación.'
MSG_EN[nemo.refresh]="You may need to log out or run 'nemo -q' for Nemo to pick up the changes."; MSG_ES[nemo.refresh]="Puede que tengas que cerrar sesión, o ejecutar 'nemo -q', para que Nemo lo note."
MSG_EN[root]='Do not run this installer as root or with sudo: it installs into a normal user home directory. Run it again as your regular user.'; MSG_ES[root]='No ejecutes este instalador como root ni con sudo: se instala en la carpeta personal de un usuario normal. Vuelve a lanzarlo como tu usuario habitual.'
MSG_EN[unknown]='Unknown option: "%s". Use "%s --help" to see the available options.'; MSG_ES[unknown]="Opción no reconocida: '%s'. Usa '%s --ayuda' para ver las opciones disponibles."
MSG_EN[zenity.warn]="zenity is not installed: Enkripta's graphical dialogs will not work until you install it with: sudo apt install zenity"; MSG_ES[zenity.warn]="No tienes 'zenity' instalado todavía: los diálogos gráficos de Enkripta no funcionarán hasta que lo instales con: sudo apt install zenity"
MSG_EN[gpg.warn]="gpg is not installed: encryption will not work until you install it with: sudo apt install gnupg"; MSG_ES[gpg.warn]="No tienes 'gpg' instalado todavía: el cifrado no funcionará hasta que lo instales con: sudo apt install gnupg"
MSG_EN[installed.script]='Main script installed at %s.'; MSG_ES[installed.script]='Script principal instalado en %s.'
MSG_EN[path.warn]="%s is not in your PATH. To use 'enkripta.sh' from any terminal, add this line to ~/.bashrc:
    export PATH=\"\$HOME/.local/bin:\$PATH\"
(This does not affect the desktop, menu or right-click integration.)"
MSG_ES[path.warn]="%s no está en tu PATH. Para usar 'enkripta.sh' desde cualquier terminal, añade esta línea a tu ~/.bashrc:
    export PATH=\"\$HOME/.local/bin:\$PATH\"
(Esto no afecta al escritorio, al menú ni al clic derecho, que ya funcionan sin esto.)"
MSG_EN[icon]='Icon installed.'; MSG_ES[icon]='Icono instalado.'
MSG_EN[menu]='Applications menu entry created (look for «Enkripta»).'; MSG_ES[menu]='Acceso creado en el menú de aplicaciones (búscalo como «Enkripta»).'
MSG_EN[mime]='.cvault file type registered.'; MSG_ES[mime]='Tipo de archivo .cvault registrado.'
MSG_EN[default]='Enkripta is now the default application for .cvault files (double-click opens the vault menu).'; MSG_ES[default]='Enkripta está configurado como la aplicación predeterminada para los archivos .cvault (doble clic = abrir el menú del vault).'
MSG_EN[mime.manual]="xdg-mime is not available; associate .cvault files manually in Nemo: right-click > Open With > Other Application."; MSG_ES[mime.manual]="No tienes 'xdg-mime'; asocia manualmente los archivos .cvault con Enkripta desde Nemo: clic derecho > Abrir con > Otra aplicación."
MSG_EN[actions]=$'Nemo right-click actions installed:\n    · «🔒 Encrypt with Enkripta» — for any file or folder\n    · «🔓 Open Enkripta vault» — for .cvault files'
MSG_ES[actions]=$'Acciones de clic derecho instaladas:\n    · «🔒 Cifrar con Enkripta» — sobre cualquier archivo o carpeta\n    · «🔓 Abrir vault Enkripta» — sobre archivos .cvault'
MSG_EN[actions.off]='Nemo right-click actions were not installed because you removed them earlier. Add them back from the Enkripta menu.'; MSG_ES[actions.off]='No se han instalado las acciones de clic derecho de Nemo porque las quitaste antes. Vuelve a añadirlas desde el menú de Enkripta.'
MSG_EN[actions.failed]='The Nemo right-click actions could not be created (see the error above). Everything else is installed; you can add them later from the Enkripta menu.'; MSG_ES[actions.failed]='No se han podido crear las acciones de clic derecho de Nemo (mira el error de arriba). Todo lo demás está instalado; puedes añadirlas después desde el menú de Enkripta.'
MSG_EN[desktop]='Desktop shortcut created (%s).'; MSG_ES[desktop]='Acceso directo creado en el escritorio (%s).'
MSG_EN[nemo]='Nemo was restarted to apply the changes. If you had windows open, open them again.'; MSG_ES[nemo]='Nemo se ha reiniciado para aplicar los cambios (si tenías ventanas abiertas, ábrelas de nuevo).'
MSG_EN[ready]=$'Done! Enkripta is now integrated with Cinnamon:\n    · Desktop → Enkripta icon (double-click opens the graphical assistant)\n    · Applications menu → Enkripta\n    · Right-click a file or folder → Encrypt with Enkripta\n    · Double-click a .cvault → open the decrypt/manage menu\n    · Optional master password → open Enkripta without arguments and choose «🔑 Configure master password»\n'
MSG_ES[ready]=$'¡Listo! Enkripta ya está integrado en Cinnamon:\n    · Escritorio → icono de Enkripta (doble clic abre el asistente gráfico)\n    · Menú de aplicaciones → Enkripta\n    · Clic derecho sobre un archivo/carpeta → Cifrar con Enkripta\n    · Doble clic sobre un .cvault → se abre el menú para descifrar y gestionar el vault\n    · Contraseña maestra opcional → abre Enkripta sin argumentos y elige «🔑 Configurar contraseña maestra»\n'
MSG_EN[zenity.reminder]='Remember to install zenity for graphical dialogs: sudo apt install zenity.'; MSG_ES[zenity.reminder]='Recuerda instalar zenity para que los diálogos gráficos funcionen: sudo apt install zenity'
MSG_EN[desktop.trust]="If the desktop icon shows a lock badge or asks you to mark it as trusted the first time, right-click it > 'Allow Launching' (or double-click it and confirm)."; MSG_ES[desktop.trust]="Si el icono del escritorio aparece con un candado o te pide que lo marques como de confianza la primera vez, haz clic derecho sobre él > 'Permitir lanzamiento' (o pulsa dos veces y confirma)."

if [ -t 1 ]; then
    C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'; C_BLUE=$'\033[34m'; C_RESET=$'\033[0m'
else
    C_GREEN=""; C_YELLOW=""; C_RED=""; C_BLUE=""; C_RESET=""
fi
ok()   { printf '%s✔ %s%s\n' "$C_GREEN" "$1" "$C_RESET"; }
warn() { printf '%s⚠ %s%s\n' "$C_YELLOW" "$1" "$C_RESET"; }
info() { printf '%sℹ %s%s\n' "$C_BLUE" "$1" "$C_RESET"; }
fail() { printf '%s✘ %s%s\n' "$C_RED" "$1" "$C_RESET" >&2; exit 1; }

# Carpeta de Escritorio: usa xdg-user-dir (sabe su nombre en el idioma del
# sistema) o, si no está, prueba las rutas habituales.
detect_desktop_dir() {
    local d
    if command -v xdg-user-dir >/dev/null 2>&1; then
        d="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
        [ -n "$d" ] && [ "$d" != "$HOME" ] && { printf '%s' "$d"; return 0; }
    fi
    for d in "$HOME/Desktop" "$HOME/Escritorio"; do
        [ -d "$d" ] && { printf '%s' "$d"; return 0; }
    done
    # Ninguna existe todavía: usamos "Desktop" como valor por defecto y la creamos.
    printf '%s' "$HOME/Desktop"
}
DESKTOP_DIR="$(detect_desktop_dir)"
DESKTOP_SHORTCUT="$DESKTOP_DIR/enkripta.desktop"

refresh_caches() {
    if [ -d "$MIME_ROOT" ] && command -v update-mime-database >/dev/null 2>&1; then
        update-mime-database "$MIME_ROOT" >/dev/null 2>&1 || true
    fi
    if [ -d "$APPS_DIR" ] && command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
    fi
    if [ -d "$ICON_ROOT" ] && command -v gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache -f "$ICON_ROOT" >/dev/null 2>&1 || true
    fi
}

# Quita enkripta.desktop de las listas de asociaciones; borra el archivo si queda vacío.
clean_mimeapps() {
    local f
    for f in "${XDG_CONFIG_HOME:-$HOME/.config}/mimeapps.list" "$APPS_DIR/mimeapps.list" "$APPS_DIR/defaults.list"; do
        [ -f "$f" ] || continue
        sed -i -E --follow-symlinks -e 's/(=|;)enkripta\.desktop;?/\1/g' -e '/^[^=#]+=;*$/d' "$f" 2>/dev/null || true
        grep -Eqv '^[[:space:]]*($|\[.*\])' "$f" 2>/dev/null || rm -f -- "$f"
    done
}

do_uninstall() {
    local d f g failed=0
    info "$(msg remove)"
    # Con "set -e" un solo rm fallido dejaría el resto sin borrar: se sigue y se avisa al final.
    for d in "$DESKTOP_DIR" "$HOME/Desktop" "$HOME/Escritorio"; do   # el acceso puede estar en cualquiera
        f="$d/enkripta.desktop"; [ -e "$f" ] || continue
        command -v gio >/dev/null 2>&1 && gio set -t unset "$f" metadata::trusted >/dev/null 2>&1 || true
        rm -f -- "$f" || failed=1
    done
    rm -f -- "$DESKTOP_FILE" "$MIME_XML" "$ACTION_ENCRYPT" "$ACTION_OPEN" \
          "$DEST_ICON_APP" "$DEST_ICON_MIME" "$DEST_SCRIPT" || failed=1
    rm -rf -- "$DATA_DIR" "$LANG_CONFIG_DIR" || failed=1
    # gpg crea ~/.gnupg en su primer uso: solo se borra si sigue siendo un llavero recién nacido
    # (sin claves ni ajustes). stat -L: un pubring.kbx enlazado mide lo que su ruta, no su contenido.
    g="$HOME/.gnupg"
    if [ -d "$g" ] && [ ! -L "$g" ] \
        && [ -z "$(find "$g" -mindepth 1 ! -name pubring.kbx ! -name trustdb.gpg ! -name random_seed ! -name 'S.*' ! -name private-keys-v1.d -print -quit 2>/dev/null)" ] \
        && [ "$(stat -L -c %s "$g/pubring.kbx" 2>/dev/null || echo 0)" -le 64 ] \
        && [ "$(stat -L -c %s "$g/trustdb.gpg" 2>/dev/null || echo 0)" -le 64 ]; then
        rm -rf -- "$g" || failed=1
    fi
    clean_mimeapps
    # Sin más definiciones en packages/, el resto de ~/.local/share/mime es caché generada.
    if rmdir "$MIME_DIR" 2>/dev/null; then rm -rf -- "$MIME_ROOT"; fi
    rmdir "$ICON_APPS_DIR" "$ICON_MIME_DIR" "$ICON_ROOT/scalable" 2>/dev/null || true
    if [ -z "$(find "$ICON_ROOT" -mindepth 1 ! -name icon-theme.cache -print -quit 2>/dev/null)" ]; then
        rm -f -- "$ICON_ROOT/icon-theme.cache"
    fi
    rmdir "$ICON_ROOT" "${ICON_ROOT%/*}" "$NEMO_ACTIONS_DIR" "${NEMO_ACTIONS_DIR%/*}" "$BIN_DIR" 2>/dev/null || true
    refresh_caches
    if ! compgen -G "$APPS_DIR/*.desktop" >/dev/null; then rm -f -- "$APPS_DIR/mimeinfo.cache"; fi
    rmdir "$APPS_DIR" "${APPS_DIR%/*}" "${APPS_DIR%/*/*}" "${XDG_CONFIG_HOME:-$HOME/.config}" 2>/dev/null || true
    if [ "$failed" = 1 ]; then warn "$(msg remove.partial)"; exit 1; fi
    ok "$(msg removed)"
    info "$(msg nemo.refresh)"
    exit 0
}

case "${1:-}" in
    --ayuda|--help|-h)
        printf '%s\n' "$(msg help "$0" "$0" "$0" "$0")"
        exit 0 ;;
    --toggle-language|-l)
        # El programa instalado también actualiza las acciones de Nemo.
        if [ -x "$DEST_SCRIPT" ]; then "$DEST_SCRIPT" --toggle-language; else toggle_language; fi
        exit 0 ;;
esac

# Antes de --desinstalar y de instalar: con sudo se usaría el $HOME de root.
[ "$(id -u)" -eq 0 ] && fail "$(msg root)"

case "${1:-}" in
    --desinstalar|--uninstall) do_uninstall ;;
    "") : ;;
    *) fail "$(msg unknown "$1" "$0")" ;;
esac

command -v zenity >/dev/null 2>&1 || warn "$(msg zenity.warn)"
command -v gpg >/dev/null 2>&1 || warn "$(msg gpg.warn)"

TMP_ICON=""
# Temporales de install_atomic: si algo interrumpe la instalación, se borran al salir.
declare -a INSTALL_TMP_FILES=()
cleanup_tmp() {
    [ -n "$TMP_ICON" ] && rm -f -- "$TMP_ICON"
    local f
    for f in "${INSTALL_TMP_FILES[@]}"; do
        rm -f -- "$f"
    done
    return 0
}
trap cleanup_tmp EXIT

# stdin -> temporal junto a "$1" (mismo sistema de archivos) -> chmod "$2" -> mv atómico.
install_atomic() {
    local dest="$1" mode="$2" tmp
    tmp="$(mktemp "${dest}.XXXXXX")"
    INSTALL_TMP_FILES+=("$tmp")
    cat > "$tmp"
    chmod "$mode" -- "$tmp"
    mv -f -- "$tmp" "$dest"
}

# ---------- 1. Programa principal (embebido en este mismo archivo) ----------

mkdir -p "$BIN_DIR"
# Escritura atómica a mano: la línea del heredoc debe quedar literal para que
# las pruebas localicen el programa embebido.
_dest_script_tmp="$(mktemp "${DEST_SCRIPT}.XXXXXX")"
INSTALL_TMP_FILES+=("$_dest_script_tmp")
_dest_script_final="$DEST_SCRIPT"
DEST_SCRIPT="$_dest_script_tmp"
cat > "$DEST_SCRIPT" <<'ENKRIPTA_SH_EOF'
#!/usr/bin/env bash
#
# Copyright (C) 2026 Filonux
#
# Licencia:
# Enkripta es software libre distribuido bajo los términos de la
# GNU General Public License versión 3 (GPLv3).
# Consulte el archivo LICENSE.txt para obtener el texto completo de la licencia.
#
# enkripta.sh — Cifra y descifra carpetas o archivos con AES-256 (GPG simétrico)
# Soporta varias contraseñas independientes para el mismo vault (como los "keyslots"
# de LUKS): cualquiera de ellas desbloquea el contenido, y se pueden añadir, cambiar
# o eliminar sin volver a cifrar los datos.
#
# Uso interactivo (terminal):
#   ./enkripta.sh cifrar   /ruta/a/carpeta_o_archivo
#   ./enkripta.sh cifrar_facil /ruta        (detecta automáticamente qué hacer)
#   ./enkripta.sh <archivo.cvault>          (abre el menú: descifrar / gestionar contraseñas)
#
# Uso gráfico (zenity), pensado para acceso directo / menú de aplicaciones / Nemo:
#   ./enkripta.sh gui                       (lanzador sin argumentos: pregunta qué hacer)
#   ./enkripta.sh gui <ruta_o_vault> [...]   (detecta automáticamente qué hacer, en modo gráfico)
#   ./enkripta.sh gui-encrypt <archivo_o_carpeta> [...]
#   ./enkripta.sh gui-menu <vault.cvault> [...]
#
# La integración con Nemo (clic derecho, doble clic en .cvault, icono en el
# menú de aplicaciones) la instala "enkripta-instalador.sh", que genera este
# mismo archivo. Este script (enkripta.sh) también funciona solo, desde la
# terminal, sin esa integración.
#
# Ver ./enkripta.sh --help para todos los subcomandos.
#
# Requisitos: gpg, tar, gzip, shred, base64 (todos vienen de serie en Linux Mint)
# Opcional:   zenity (para los diálogos gráficos), notify-send (avisos de escritorio)

set -euo pipefail

# ---------- Configuración ----------
CIPHER="AES256"
S2K_MODE=3
S2K_COUNT=65011712
DIGEST="SHA512"
EXT="cvault"                 # extensión de los archivos cifrados
MIN_PW_LEN=8                 # longitud mínima exigida a las contraseñas nuevas
APP_TITLE="Enkripta"
APP_ICON="dialog-password"   # icono de tema estándar, presente en Mint/Cinnamon

GUI=0                         # se activa con los subcomandos gui / gui-*
APP_VERSION="1.5.0"

# ---------- Language ----------
LANG_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/enkripta"
LANG_FILE="$LANG_CONFIG_DIR/language"

detect_language() {
    local locale="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}"
    case "$locale" in
        C|POSIX|C.*|POSIX.*) printf 'en'; return ;;
    esac
    if [ -n "${LANGUAGE:-}" ]; then
        case "${LANGUAGE%%:*}" in
            es*) printf 'es'; return ;;
            en*) printf 'en'; return ;;
        esac
    fi
    case "$locale" in
        es*) printf 'es' ;;
        *) printf 'en' ;;
    esac
}

load_language() {
    local saved="${ENKRIPTA_LANG:-}"
    if [ -z "$saved" ] && [ -f "$LANG_FILE" ]; then
        IFS= read -r saved < "$LANG_FILE" || true
    fi
    case "$saved" in
        es|en) printf '%s' "$saved" ;;
        *) detect_language ;;
    esac
}

LANG_CODE="$(load_language)"

other_language() {
    [ "$LANG_CODE" = "es" ] && printf 'en' || printf 'es'
}

set_language() {
    local new_lang="$1" tmp
    mkdir -p "$LANG_CONFIG_DIR"
    tmp="$(mktemp "${LANG_FILE}.XXXXXX")"
    if ! printf '%s\n' "$new_lang" > "$tmp" || ! chmod 600 "$tmp" || ! mv -f -- "$tmp" "$LANG_FILE"; then
        rm -f -- "$tmp"
        return 1
    fi
    LANG_CODE="$new_lang"
}

msg() {
    local key="$1" fmt value a
    local -a safe=()
    shift
    if [ "$LANG_CODE" = "es" ]; then
        fmt="${MSG_ES[$key]}"
    else
        fmt="${MSG_EN[$key]}"
    fi
    # Los argumentos suelen ser nombres de archivo: nunca se interpretan (\n, \033...) y sus
    # caracteres de control se neutralizan, así no pueden inyectar secuencias en la terminal.
    for a in "$@"; do safe+=("${a//[[:cntrl:]]/?}"); done
    printf -v value "$fmt" "${safe[@]}"
    printf '%s' "$value"
}

toggle_language() {
    if [ "$LANG_CODE" = "es" ]; then
        set_language en
    else
        set_language es
    fi
    write_nemo_actions refresh || true
    printf '%s\n' "$(msg language.changed "$(msg "language.$LANG_CODE")")"
}

# Nemo resuelve "Name[xx]" según el idioma del SISTEMA, no el de Enkripta:
# por eso las acciones llevan un único Name/Comment ya traducido, sin [xx].
NEMO_ACT_ENC="$HOME/.local/share/nemo/actions/enkripta-cifrar.nemo_action"
NEMO_ACT_OPEN="$HOME/.local/share/nemo/actions/enkripta-abrir.nemo_action"
INSTALLED_BIN="$HOME/.local/bin/enkripta.sh"
# Existe solo si el usuario quitó las acciones: el instalador no las recrea.
NEMO_OFF_FILE="$LANG_CONFIG_DIR/nemo-actions-off"

atomic_write() {
    local tmp
    tmp="$(mktemp "$1.XXXXXX")" || return 1
    if cat > "$tmp" && chmod 644 "$tmp" && mv -f -- "$tmp" "$1"; then return 0; fi
    rm -f -- "$tmp"
    return 1
}

# Escribe las acciones de clic derecho de Nemo en el idioma actual. Con
# "refresh" solo reescribe las que ya existen (no crea ni resucita ninguna).
write_nemo_actions() {
    local mode="${1:-}"
    local bin="$INSTALLED_BIN"
    local icon="$HOME/.local/share/icons/hicolor/scalable/apps/enkripta.svg"
    [ "$mode" = refresh ] || mkdir -p "${NEMO_ACT_ENC%/*}" || return 1
    if [ "$mode" != refresh ] || [ -f "$NEMO_ACT_ENC" ]; then
        atomic_write "$NEMO_ACT_ENC" <<NEMO_ACTION_EOF || return 1
[Nemo Action]
Active=true
Name=$(msg nemo.encrypt.name)
Comment=$(msg nemo.encrypt.comment)
Exec="$bin" gui-encrypt %F
Icon-Name=$icon
Selection=notnone
Extensions=any;
NEMO_ACTION_EOF
    fi
    if [ "$mode" != refresh ] || [ -f "$NEMO_ACT_OPEN" ]; then
        atomic_write "$NEMO_ACT_OPEN" <<NEMO_ACTION_EOF || return 1
[Nemo Action]
Active=true
Name=$(msg nemo.open.name)
Comment=$(msg nemo.open.comment)
Exec="$bin" gui-menu %F
Icon-Name=$icon
Selection=notnone
Extensions=cvault;
NEMO_ACTION_EOF
    fi
}

# Sin idioma elegido, Enkripta sigue al del sistema: las acciones de Nemo también.
sync_nemo_actions() {
    [ -f "$LANG_FILE" ] || [ -n "${ENKRIPTA_LANG:-}" ] && return 0
    { [ ! -f "$NEMO_ACT_ENC" ] || grep -qxF "Name=$(msg nemo.encrypt.name)" "$NEMO_ACT_ENC"; } \
        && { [ ! -f "$NEMO_ACT_OPEN" ] || grep -qxF "Name=$(msg nemo.open.name)" "$NEMO_ACT_OPEN"; } \
        || write_nemo_actions refresh || true
}

nemo_actions_present() { [ -f "$NEMO_ACT_ENC" ] || [ -f "$NEMO_ACT_OPEN" ]; }

# on: crea las acciones; off: las borra y deja la marca NEMO_OFF_FILE.
cmd_nemo_actions() {
    if [ "$1" = on ]; then
        [ -x "$INSTALLED_BIN" ] || err "$(msg nemo.nobin "${INSTALLED_BIN%/*}")"
        rm -f -- "$NEMO_OFF_FILE"
        if write_nemo_actions && nemo_actions_present; then
            ok_msg "$(msg nemo.added)"
        else
            err "$(msg nemo.failed "${NEMO_ACT_ENC%/*}")"
        fi
    else
        mkdir -p "${NEMO_OFF_FILE%/*}" && : > "$NEMO_OFF_FILE" || err "$(msg nemo.failed "${NEMO_OFF_FILE%/*}")"
        rm -f -- "$NEMO_ACT_ENC" "$NEMO_ACT_OPEN"
        ok_msg "$(msg nemo.removed)"
    fi
}

declare -A MSG_EN MSG_ES

MSG_EN[language.changed]='Language changed to %s.'
MSG_ES[language.changed]='Idioma cambiado a %s.'

MSG_EN[language.en]='English'
MSG_EN[language.es]='Spanish'
MSG_ES[language.en]='inglés'
MSG_ES[language.es]='español'
MSG_EN[language.option]='Switch language: %s / %s'
MSG_ES[language.option]='Cambiar idioma: %s / %s'

MSG_EN[yes]='Yes'
MSG_ES[yes]='Sí'
MSG_EN[no]='No'
MSG_ES[no]='No'
MSG_EN[pw.show]='👁️  Show the password while typing'
MSG_ES[pw.show]='👁️  Mostrarla mientras la escribo'
MSG_EN[pw.hide]='🔒 Keep the password hidden'
MSG_ES[pw.hide]='🔒 Mantenerla oculta'
MSG_EN[pw.choice]='How would you like to enter the password for this operation?\n\n👁️  Show it: the password will be visible as you type.\n🔒 Keep it hidden: dots will be shown instead (recommended if someone can see your screen).'
MSG_ES[pw.choice]='¿Cómo quieres introducir la contraseña en esta operación?\n\n👁️  Mostrarla: verás el texto tal como lo escribes.\n🔒 Ocultarla: aparecerán puntos en su lugar (recomendado si alguien puede ver tu pantalla).'
MSG_EN[pw.show.prompt]='Do you want to display the password as plain text while typing instead of keeping it hidden? [y/N]: '
MSG_ES[pw.show.prompt]='¿Quieres ver la contraseña sin ocultar mientras la escribes? [s/N]: '

MSG_EN[ok]='OK'
MSG_ES[ok]='Aceptar'
MSG_EN[cancel]='Cancel'
MSG_ES[cancel]='Cancelar'
MSG_EN[assistant.open]='Open assistant'
MSG_ES[assistant.open]='Abrir el asistente'
MSG_EN[action]='Action'
MSG_ES[action]='Acción'
MSG_EN[operation.cancelled]='Operation cancelled.'
MSG_ES[operation.cancelled]='Operación cancelada.'

MSG_EN[picker.title]='👋 What do you want to do?\n\n🔑 Master password: %s'
MSG_ES[picker.title]='👋 ¿Qué quieres hacer?\n\n🔑 Contraseña maestra: %s'
MSG_EN[master.status.configured]='configured'
MSG_ES[master.status.configured]='configurada'
MSG_EN[master.status.not_configured]='not configured'
MSG_ES[master.status.not_configured]='no configurada'
MSG_EN[picker.encrypt.file]='🔒 Encrypt a file'
MSG_ES[picker.encrypt.file]='🔒 Cifrar un archivo'
MSG_EN[picker.encrypt.dir]='🔒 Encrypt a folder'
MSG_ES[picker.encrypt.dir]='🔒 Cifrar una carpeta'
MSG_EN[picker.open]='🔓 Open an existing .cvault file'
MSG_ES[picker.open]='🔓 Abrir un vault .cvault existente'
MSG_EN[picker.master.set]='🔑 Configure master password'
MSG_ES[picker.master.set]='🔑 Configurar contraseña maestra'
MSG_EN[picker.master.unset]='🚫 Remove master password'
MSG_ES[picker.master.unset]='🚫 Quitar contraseña maestra'
MSG_EN[picker.nemo.add]='➕ Add the Nemo actions'
MSG_ES[picker.nemo.add]='➕ Añadir las acciones de Nemo'
MSG_EN[picker.nemo.remove]='➖ Remove the Nemo actions'
MSG_ES[picker.nemo.remove]='➖ Quitar las acciones de Nemo'
MSG_EN[picker.file.title]='Choose the file to encrypt'
MSG_ES[picker.file.title]='Elige el archivo a cifrar'
MSG_EN[picker.dir.title]='Choose the folder to encrypt'
MSG_ES[picker.dir.title]='Elige la carpeta a cifrar'
MSG_EN[picker.vault.title]='Choose the .cvault file to open'
MSG_ES[picker.vault.title]='Elige el vault .cvault a abrir'
MSG_EN[picker.vault.filter]='Enkripta vaults | *.cvault'
MSG_ES[picker.vault.filter]='Vaults de Enkripta | *.cvault'

MSG_EN[invalid]='%s is not a valid Enkripta vault file.'
MSG_ES[invalid]='%s no es un archivo vault de Enkripta válido.'
MSG_EN[invalid.name]='%s is not a valid Enkripta vault (invalid internal name).'
MSG_ES[invalid.name]='%s no es un vault de Enkripta válido (nombre interno no permitido).'
MSG_EN[invalid.type]='%s is not a valid Enkripta vault (invalid content type).'
MSG_ES[invalid.type]='%s no es un vault de Enkripta válido (tipo de contenido no permitido).'
MSG_EN[wrong.password]='Incorrect password.'
MSG_ES[wrong.password]='Contraseña incorrecta.'

MSG_EN[password.empty]='The password cannot be empty.'
MSG_ES[password.empty]='La contraseña no puede estar vacía.'
MSG_EN[password.short]='The password must be at least %s characters long.'
MSG_ES[password.short]='La contraseña debe tener al menos %s caracteres.'
MSG_EN[password.empty.abort]='Could not obtain a password (too many empty attempts). Operation cancelled.'
MSG_ES[password.empty.abort]='No se ha podido obtener una contraseña (demasiados intentos vacíos). Operación cancelada.'
MSG_EN[password.invalid.abort]='Could not obtain a valid password (too many attempts). Operation cancelled.'
MSG_ES[password.invalid.abort]='No se ha podido obtener una contraseña válida (demasiados intentos). Operación cancelada.'
MSG_EN[password.mismatch.abort]='The password could not be confirmed (too many attempts). Operation cancelled.'
MSG_ES[password.mismatch.abort]='No se ha podido confirmar la contraseña (demasiados intentos). Operación cancelada.'
MSG_EN[password.mismatch]='The passwords do not match. Start again.'
MSG_ES[password.mismatch]='Las dos contraseñas que has escrito no coinciden. Vuelve a intentarlo desde el principio.'

MSG_EN[slow.notice]='This may take a while (about %s of data)…'
MSG_ES[slow.notice]='Esto puede tardar un poco (aproximadamente %s de datos)…'

MSG_EN[gui.need_zenity]='%s needs "zenity" for graphical dialogs. Install it with: sudo apt install zenity'
MSG_ES[gui.need_zenity]="%s necesita 'zenity' para los diálogos gráficos. Instálalo con: sudo apt install zenity"
MSG_EN[cmd.missing]='The command "%s" is missing. Install it with: sudo apt install %s'
MSG_ES[cmd.missing]="Falta el comando '%s'. Instálalo con: sudo apt install %s"

MSG_EN[path.dot]='Cannot encrypt or update "%s" directly: it points to the entire current directory (or its parent), which could result in deleting it. Use the full path, for example: "%s".'
MSG_ES[path.dot]="No se puede cifrar/actualizar '%s' directamente: apuntaría a todo el directorio actual (o al padre) y podría acabar borrándolo entero. Indica la ruta completa, por ejemplo: '%s'."
MSG_EN[path.exists]='%s does not exist.'
MSG_ES[path.exists]="'%s' no existe."
MSG_EN[path.symlink]='%s is a symbolic link, not the actual file or folder.\nTo avoid surprises (a symbolic link to a directory is not encrypted correctly, and securely deleting the original would affect the actual target, not the link),\npoint directly to the real path: %s'
MSG_ES[path.symlink]="%s es un enlace simbólico, no el archivo o la carpeta reales.\nPara evitar sorpresas (un enlace simbólico a una carpeta no se cifra correctamente, y borrar\nel original de forma segura afectaría al destino real, no al enlace),\nindica directamente la ruta real: %s"
MSG_EN[path.unsupported]='%s contains symbolic links or special files, which Enkripta does not support for safe archiving.'
MSG_ES[path.unsupported]="%s contiene enlaces simbólicos o archivos especiales, que Enkripta no admite para archivado seguro."
MSG_EN[path.is.vault]='%s is already an Enkripta vault. Open it by double-clicking or use "gui-menu" instead of encrypting it again.'
MSG_ES[path.is.vault]="%s ya es un vault de Enkripta. Ábrelo con doble clic o usa 'gui-menu' en lugar de cifrarlo de nuevo."
MSG_EN[vault.exists]='A vault for "%s" already exists ("%s").\n\nDo you want to update it while keeping the same passwords?\n\n(If you choose "No", you can create a new vault from scratch, but the old passwords will be lost)'
MSG_ES[vault.exists]="Ya existe un vault para '%s' ('%s').\n\n¿Quieres ACTUALIZARLO manteniendo las mismas contraseñas?\n\n(Si eliges 'No', se te ofrecerá crear uno nuevo desde cero y se perderán las contraseñas antiguas)"
MSG_EN[vault.overwrite]='Are you sure you want to create a NEW vault and overwrite "%s"?\nThe old passwords will no longer work.'
MSG_ES[vault.overwrite]="¿Seguro que quieres crear un vault NUEVO y sobrescribir '%s'?\nLas contraseñas antiguas dejarán de servir."
MSG_EN[vault.dir]='%s is a folder, not a file. Delete it or rename it manually before continuing.'
MSG_ES[vault.dir]="'%s' es una carpeta, no un archivo; bórrala o renómbrala a mano antes de continuar."
MSG_EN[vault.missing]='No matching vault was found ("%s").'
MSG_ES[vault.missing]="No se encontró un vault correspondiente ('%s')."
MSG_EN[update.is.vault]='%s is already an Enkripta vault; give the ORIGINAL folder or file, not the .cvault.'
MSG_ES[update.is.vault]="'%s' ya es un vault de Enkripta; indica la carpeta o archivo ORIGINAL, no el .cvault."
MSG_EN[update.success]="Vault '%s' was updated%s. The passwords have not changed."
MSG_ES[update.success]="Vault '%s' actualizado%s. Las contraseñas no han cambiado."

MSG_EN[master.prompt]='🔑 Enter your MASTER password to encrypt "%s"'
MSG_ES[master.prompt]="🔑 Escribe tu contraseña MAESTRA para cifrar '%s'"
MSG_EN[master.empty.abort]='Could not obtain the master password (too many empty attempts). Operation cancelled.'
MSG_ES[master.empty.abort]='No se ha podido obtener la contraseña maestra (demasiados intentos vacíos). Operación cancelada.'
MSG_EN[master.wrong.abort]='The master password is incorrect (too many attempts). Operation cancelled.'
MSG_ES[master.wrong.abort]='La contraseña maestra no coincide (demasiados intentos). Operación cancelada.'
MSG_EN[master.wrong]='That is not your master password. Try again.'
MSG_ES[master.wrong]='Esa no es tu contraseña maestra. Vuelve a intentarlo.'

MSG_EN[pw.main.new]='🆕 Step 1 of 2 — Create the MAIN password for "%s"'
MSG_ES[pw.main.new]="🆕 Paso 1 de 2 — Crea la contraseña PRINCIPAL para '%s'"
MSG_EN[pw.main.confirm]='🔁 Step 2 of 2 — Re-enter the MAIN password to confirm it'
MSG_ES[pw.main.confirm]='🔁 Paso 2 de 2 — Repite la contraseña PRINCIPAL para confirmarla'
MSG_EN[pw.second.new]='🆕 Step 1 of 2 — Create the SECOND (alternative) password for "%s"'
MSG_ES[pw.second.new]="🆕 Paso 1 de 2 — Crea la SEGUNDA contraseña (alternativa) para '%s'"
MSG_EN[pw.second.confirm]='🔁 Step 2 of 2 — Re-enter the SECOND password to confirm it'
MSG_ES[pw.second.confirm]='🔁 Paso 2 de 2 — Repite la SEGUNDA contraseña para confirmarla'
MSG_EN[pw.second.ask]='Do you want to add a second alternative password now?\n(Either password can be used to decrypt)'
MSG_ES[pw.second.ask]='¿Quieres añadir ahora una segunda contraseña alternativa?\n(Cualquiera de las dos podrá usarse para descifrar)'
MSG_EN[pw.delete.original]='Do you want to securely delete the original "%s"? This may take some time depending on its size.'
MSG_ES[pw.delete.original]="¿Quieres eliminar de forma segura el original '%s'? Esto puede tardar según el tamaño."
MSG_EN[encrypt.success]="'%s' was successfully encrypted to '%s' (using %s %s)."
MSG_ES[encrypt.success]="'%s' cifrado correctamente en '%s' (con %s %s)."
MSG_EN[original.deleted]='Original deleted securely.'
MSG_ES[original.deleted]='Original eliminado de forma segura.'

MSG_EN[decrypt.prompt]="🔓 Enter the password for '%s' to decrypt it"
MSG_ES[decrypt.prompt]="🔓 Escribe la contraseña de '%s' para descifrarlo"
MSG_EN[path.destination]='Invalid destination path for "%s".'
MSG_ES[path.destination]="Ruta de destino no válida para '%s'."
MSG_EN[path.already.exists]='%s already exists. Move it or delete it before decrypting.'
MSG_ES[path.already.exists]="'%s' ya existe. Muévelo o bórralo antes de descifrar."
MSG_EN[decrypt.success]="'%s' was successfully decrypted%s to:\n%s"
MSG_ES[decrypt.success]="'%s' descifrado correctamente%s en:\n%s"
MSG_EN[open.now]='Open "%s" now?'
MSG_ES[open.now]="¿Abrir '%s' ahora?"

MSG_EN[update.prompt]='🔑 Enter ANY password that is already valid for "%s" to authorize the update'
MSG_ES[update.prompt]="🔑 Escribe CUALQUIERA de las contraseñas ya válidas de '%s' para autorizar la actualización"
MSG_EN[secure.copy]='Securely delete the unencrypted copy "%s"?'
MSG_ES[secure.copy]="¿Eliminar de forma segura la copia sin cifrar '%s'?"

MSG_EN[change.current]='🔑 Step 1 of 3 — Enter the CURRENT password you want to replace'
MSG_ES[change.current]='🔑 Paso 1 de 3 — Escribe la contraseña ACTUAL que quieres cambiar'
MSG_EN[change.new]='🆕 Step 2 of 3 — Enter the NEW password (it will replace the current one)'
MSG_ES[change.new]='🆕 Paso 2 de 3 — Escribe la contraseña NUEVA (sustituirá a la actual)'
MSG_EN[change.confirm]='🔁 Step 3 of 3 — Re-enter the NEW password to confirm it'
MSG_ES[change.confirm]='🔁 Paso 3 de 3 — Repite la contraseña NUEVA para confirmarla'
MSG_EN[password.updated]='Password updated successfully.'
MSG_ES[password.updated]='Contraseña actualizada correctamente.'
MSG_EN[password.word.one]='password'
MSG_ES[password.word.one]='contraseña'
MSG_EN[password.word.many]='passwords'
MSG_ES[password.word.many]='contraseñas'

MSG_EN[add.authorize]='🔑 Step 1 of 3 — Enter an EXISTING valid password for this vault to authorize the change'
MSG_ES[add.authorize]='🔑 Paso 1 de 3 — Escribe una contraseña YA VÁLIDA de este vault para autorizar el cambio'
MSG_EN[add.new]='🆕 Step 2 of 3 — Enter the NEW password you want to add (an alternative to the others)'
MSG_ES[add.new]='🆕 Paso 2 de 3 — Escribe la contraseña NUEVA que quieres añadir (alternativa a las demás)'
MSG_EN[add.confirm]='🔁 Step 3 of 3 — Re-enter the NEW password to confirm it'
MSG_ES[add.confirm]='🔁 Paso 3 de 3 — Repite la contraseña NUEVA para confirmarla'
MSG_EN[password.added]='New password added. There are now %s valid passwords for this vault.'
MSG_ES[password.added]='Nueva contraseña añadida. Ahora hay %s contraseñas válidas para este vault.'

MSG_EN[remove.only]='This vault has only one password, so its sole access method cannot be removed.'
MSG_ES[remove.only]='Este vault solo tiene una contraseña; no se puede eliminar la única forma de acceso.'
MSG_EN[remove.prompt]='🗑️  Enter the password you want to REMOVE from this vault'
MSG_ES[remove.prompt]='🗑️  Escribe la contraseña que quieres ELIMINAR de este vault'
MSG_EN[remove.confirm]='That password will be removed; the other passwords will continue to work. Continue?'
MSG_ES[remove.confirm]='Se eliminará esa contraseña; el resto seguirán funcionando. ¿Continuar?'
MSG_EN[password.removed.one]='Password removed. 1 valid password remains for this vault.'
MSG_ES[password.removed.one]='Contraseña eliminada. Queda 1 contraseña válida para este vault.'
MSG_EN[password.removed.many]='Password removed. %s valid passwords remain for this vault.'
MSG_ES[password.removed.many]='Contraseña eliminada. Quedan %s contraseñas válidas para este vault.'

MSG_EN[master.replace]='A master password is already configured.\nDo you want to replace it with a new one?\n\n(Existing vaults do not change: this only affects what you encrypt from now on)'
MSG_ES[master.replace]='Ya tienes una contraseña maestra configurada.\n¿Quieres reemplazarla por una nueva?\n\n(Los vaults que ya creaste no cambian: esto solo afecta a lo que cifres a partir de ahora)'
MSG_EN[master.new]='🔑 Step 1 of 2 — Enter the new MASTER password'
MSG_ES[master.new]='🔑 Paso 1 de 2 — Escribe la nueva contraseña MAESTRA'
MSG_EN[master.confirm]='🔁 Step 2 of 2 — Re-enter the MASTER password to confirm it'
MSG_ES[master.confirm]='🔁 Paso 2 de 2 — Repite la contraseña MAESTRA para confirmarla'
MSG_EN[master.configured]='Master password configured.\n\nFrom now on, when encrypting a new file or folder, you will only have to enter it once (you no longer need to create and repeat a different password each time).\n'
MSG_ES[master.configured]='Contraseña maestra configurada.\n\nA partir de ahora, al cifrar un archivo o carpeta nuevos, solo tendrás que introducirla una vez (ya no hace falta crear y repetir una contraseña distinta cada vez).\n'
MSG_EN[master.none]='No master password is configured.'
MSG_ES[master.none]='No hay ninguna contraseña maestra configurada.'
MSG_EN[master.remove]='Are you sure you want to remove the master password?\n\nExisting vaults will not change. From now on, when you encrypt something new, you will be asked to create a password for each new vault again.'
MSG_ES[master.remove]='¿Seguro que quieres quitar la contraseña maestra?\n\nLos vaults que ya creaste no cambiarán. A partir de ahora, al cifrar algo nuevo, se te volverá a pedir crear una contraseña para cada vault nuevo.'
MSG_EN[master.removed]='Master password removed.'
MSG_ES[master.removed]='Contraseña maestra eliminada.'

MSG_EN[menu.title]="What do you want to do with '%s'%s?"
MSG_ES[menu.title]="¿Qué quieres hacer con '%s'%s?"
MSG_EN[slots.one]=' (1 password configured)'
MSG_ES[slots.one]=' (1 contraseña configurada)'
MSG_EN[slots.many]=' (%s passwords configured)'
MSG_ES[slots.many]=' (%s contraseñas configuradas)'
MSG_EN[menu.decrypt]='🔓 Decrypt'
MSG_ES[menu.decrypt]='🔓 Descifrar'
MSG_EN[menu.change]='✏️  Change a password'
MSG_ES[menu.change]='✏️  Cambiar una contraseña'
MSG_EN[menu.add]='➕ Add another password'
MSG_ES[menu.add]='➕ Añadir otra contraseña'
MSG_EN[menu.remove]='➖ Remove a password'
MSG_ES[menu.remove]='➖ Eliminar una contraseña'
MSG_EN[menu.language]='L) Switch language: %s / %s'
MSG_ES[menu.language]='L) Cambiar idioma: %s / %s'
MSG_EN[menu.prompt]='Select an option [1-5, L]: '
MSG_ES[menu.prompt]='Selecciona una opción [1-5, L]: '

MSG_EN[usage]="$APP_TITLE — symmetric encryption of folders and files (GPG/AES-256), with
support for multiple independent passwords per vault and an optional master
password so you do not have to create a different one each time.

Usage:
  %s encrypt <folder_or_file>
  %s easy-encrypt <path> [...]          # encrypts or opens the menu as needed
  %s <vault.$EXT>                      # opens the vault menu (decrypt / manage)
  %s decrypt <vault.$EXT>
  %s update <folder_or_file>           # re-encrypts the content, same passwords
  %s change-password <vault.$EXT>
  %s add-password <vault.$EXT>
  %s remove-password <vault.$EXT>
  %s master-password                   # configure/replace the master password
  %s remove-master-password            # remove the master password
  %s add-nemo-actions                  # add the Nemo right-click actions
  %s remove-nemo-actions               # remove them
  %s --version                         # show the installed version
  %s --help                            # show this help
  %s -l, --toggle-language              # switch between English and Spanish

Graphical variants (zenity), used by shortcuts and Nemo:
  %s gui                               # graphical launcher, asks what to do
  %s gui <path_or_vault> [...]
  %s gui-encrypt <path> [...]
  %s gui-menu <vault.$EXT> [...]

Examples:
  %s encrypt ~/Documents/secrets
  %s secrets.$EXT"
MSG_ES[usage]="$APP_TITLE — cifrado simétrico de carpetas y archivos (GPG/AES-256), con
soporte para varias contraseñas independientes por vault y una contraseña
maestra opcional para no tener que crear una distinta cada vez.

Uso:
  %s cifrar <carpeta_o_archivo>
  %s cifrar_facil <ruta> [...]         # cifra o abre el menú según corresponda
  %s <vault.$EXT>                      # abre el menú (descifrar / gestionar)
  %s descifrar <vault.$EXT>
  %s actualizar <carpeta_o_archivo>    # recifra el contenido, mismas contraseñas
  %s cambiar-contrasena <vault.$EXT>
  %s anadir-contrasena <vault.$EXT>
  %s eliminar-contrasena <vault.$EXT>
  %s contrasena-maestra                # configura/reemplaza la contraseña maestra
  %s quitar-contrasena-maestra         # quita la contraseña maestra
  %s anadir-acciones-nemo              # añade las acciones de clic derecho de Nemo
  %s quitar-acciones-nemo              # las quita
  %s --version                         # muestra la versión instalada
  %s --help                            # muestra esta ayuda
  %s -l, --toggle-language              # cambia entre español e inglés

Variantes gráficas (zenity), usadas por accesos directos y por Nemo:
  %s gui                                # lanzador gráfico, pregunta qué hacer
  %s gui <ruta_o_vault> [...]
  %s gui-encrypt <ruta> [...]
  %s gui-menu <vault.$EXT> [...]

Ejemplos:
  %s cifrar ~/Documentos/secretos
  %s secretos.$EXT"

MSG_EN[usage.noarg]="%s was launched without a file or folder.\n\nDo you want to open the assistant to choose what to do?"
MSG_ES[usage.noarg]="%s se ha abierto sin indicarle qué archivo o carpeta usar.\n\n¿Quieres abrir el asistente para elegir qué hacer?"
MSG_EN[usage.notify]='You must specify a file, folder, or .cvault vault. Install "zenity" for the graphical assistant.'
MSG_ES[usage.notify]="Debes indicar un archivo, una carpeta o un vault .cvault. Instala 'zenity' para el asistente gráfico."

MSG_EN[nemo.encrypt.name]='🔒 Encrypt with Enkripta'
MSG_ES[nemo.encrypt.name]='🔒 Cifrar con Enkripta'
MSG_EN[nemo.encrypt.comment]='Encrypt the selected file or folder with a password (AES-256)'
MSG_ES[nemo.encrypt.comment]='Cifra el archivo o carpeta seleccionada con contraseña (AES-256)'
MSG_EN[nemo.open.name]='🔓 Open Enkripta vault'
MSG_ES[nemo.open.name]='🔓 Abrir vault Enkripta'
MSG_EN[nemo.open.comment]="Decrypt or manage this vault's passwords"
MSG_ES[nemo.open.comment]='Descifra o gestiona las contraseñas de este vault'
MSG_EN[nemo.added]='Nemo right-click actions added.'
MSG_ES[nemo.added]='Acciones de clic derecho de Nemo añadidas.'
MSG_EN[nemo.removed]='Nemo right-click actions removed. You can add them back from the Enkripta menu.'
MSG_ES[nemo.removed]='Acciones de clic derecho de Nemo quitadas. Puedes volver a añadirlas desde el menú de Enkripta.'
MSG_EN[nemo.failed]='Could not write the Nemo actions in %s.'
MSG_ES[nemo.failed]='No se han podido escribir las acciones de Nemo en %s.'
MSG_EN[unexpected]='Enkripta stopped because of an unexpected error (code %s), so the operation was not completed. Run it from a terminal to see the details, and do not delete the original until you have checked that the vault exists.'
MSG_ES[unexpected]='Enkripta se detuvo por un error inesperado (código %s) y la operación no se completó. Ejecútalo desde una terminal para ver los detalles y no borres el original hasta comprobar que el vault existe.'
MSG_EN[verify.failed]='The new vault "%s" could not be verified (it does not decrypt correctly), so the original was NOT deleted. Try again.'
MSG_ES[verify.failed]='No se ha podido verificar el vault nuevo "%s" (no se descifra bien), así que NO se ha borrado el original. Inténtalo de nuevo.'
MSG_EN[shred.failed]='Could not securely delete "%s" (check its permissions). The vault is fine, but the original may still be there, at least in part.'
MSG_ES[shred.failed]='No se ha podido eliminar de forma segura "%s" (revisa sus permisos). El vault está bien, pero el original puede seguir ahí, al menos en parte.'
MSG_EN[dir.readonly]='Enkripta cannot write in "%s" (read-only or no permission). Move the item to a folder where you can write and try again.'
MSG_ES[dir.readonly]='Enkripta no puede escribir en "%s" (solo lectura o sin permiso). Mueve el elemento a una carpeta donde puedas escribir e inténtalo de nuevo.'
MSG_EN[nemo.nobin]='Enkripta is not installed in %s, so the Nemo actions would have nothing to launch. Run the installer first.'
MSG_ES[nemo.nobin]='Enkripta no está instalado en %s, así que las acciones de Nemo no tendrían nada que lanzar. Ejecuta antes el instalador.'


# Contraseña maestra: no se guarda la contraseña, solo un "verificador" (un
# texto fijo cifrado con ella) en MASTER_VERIFY_FILE. Así, al cifrar algo
# nuevo, se puede comprobar al momento si lo que el usuario ha escrito es su
# contraseña maestra (sin tener que pedirla dos veces), sin que quede guardada
# en ningún sitio.
ENKRIPTA_DATA_DIR="$HOME/.local/share/enkripta"
MASTER_VERIFY_FILE="$ENKRIPTA_DATA_DIR/master.verify"
MASTER_MAGIC="ENKRIPTA_MASTER_OK_v1"

# Umbral (en bytes) a partir del cual avisamos de que cifrar/actualizar
# puede tardar, antes de lanzar tar+gzip+gpg. 300 MiB por defecto.
WARN_SIZE_BYTES=$((300 * 1024 * 1024))

# Colores para la salida en terminal. Se desactivan solos si stderr no es
# una terminal real (por ejemplo, si se redirige a un archivo o a un log),
# para no meter códigos de escape ANSI donde no pintan nada.
if [ -t 2 ]; then
    C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'; C_RESET=$'\033[0m'
else
    C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_RESET=""
fi

# ---------- Utilidades básicas ----------

# Marca "el usuario ya fue informado" (archivo: err() también corre dentro de $(...)).
mark_reported() { [ -z "${SHOW_PW_FILE:-}" ] || : > "$SHOW_PW_FILE.err" 2>/dev/null || true; }

err() {
    mark_reported
    if [ "$GUI" = "1" ] && command -v zenity >/dev/null 2>&1; then
        zenity --error --title="$APP_TITLE" --width=420 --window-icon="$APP_ICON" --no-markup --ok-label="$(msg ok)" --text="$1" 2>/dev/null || true
    else
        printf '%s❌ %s%s\n' "$C_RED" "$1" "$C_RESET" >&2
    fi
    exit 1
}

info() {
    if [ "$GUI" = "1" ] && command -v zenity >/dev/null 2>&1; then
        zenity --info --title="$APP_TITLE" --width=420 --window-icon="$APP_ICON" --no-markup --ok-label="$(msg ok)" --text="$1" 2>/dev/null || true
    else
        printf '%sℹ️  %s%s\n' "$C_BLUE" "$1" "$C_RESET"
    fi
}

ok_msg() {
    if [ "$GUI" = "1" ] && command -v notify-send >/dev/null 2>&1; then
        local body="$1"
        notify-send -i "$APP_ICON" "$APP_TITLE" "$body" || true
    elif [ "$GUI" = "1" ] && command -v zenity >/dev/null 2>&1; then
        zenity --info --title="$APP_TITLE" --width=420 --window-icon="$APP_ICON" --no-markup --ok-label="$(msg ok)" --text="✅ $1" 2>/dev/null || true
    else
        printf '%s✅ %s%s\n' "$C_GREEN" "$1" "$C_RESET"
    fi
}

ask_yesno() {
    local prompt="$1"
    if [ "$GUI" = "1" ] && command -v zenity >/dev/null 2>&1; then
        zenity --question --title="$APP_TITLE" --width=400 --window-icon="$APP_ICON" --no-markup \
            --ok-label="$(msg yes)" --cancel-label="$(msg no)" --text="$prompt" 2>/dev/null
        return $?
    else
        local confirm rendered="$prompt"
        if [ "$LANG_CODE" = "es" ]; then
            read -rp "$rendered [s/N]: " confirm
        else
            read -rp "$rendered [y/N]: " confirm
        fi
        [[ "$confirm" =~ ^[sSyY]$ ]]
    fi
}

# Una sola preferencia por ejecución; el estado vive fuera de subshells.
SHOW_PW=""
SHOW_PW_FILE="$(mktemp "${TMPDIR:-/tmp}/enkripta-showpw.XXXXXX")"
chmod 600 "$SHOW_PW_FILE"

ensure_show_pw_pref() {
    local saved resp tmp
    if IFS= read -r saved < "$SHOW_PW_FILE" 2>/dev/null; then
        case "$saved" in
            0|1) SHOW_PW="$saved"; return 0 ;;
        esac
    fi
    if [ "$GUI" = "1" ] && command -v zenity >/dev/null 2>&1; then
        if zenity --question --title="$APP_TITLE" --width=440 --window-icon="$APP_ICON" --no-markup \
            --ok-label="$(msg pw.show)" --cancel-label="$(msg pw.hide)" \
            --text="$(msg pw.choice)" 2>/dev/null; then
            SHOW_PW=1
        else
            SHOW_PW=0
        fi
    else
        read -rp "$(msg pw.show.prompt)" resp || true
        [[ "${resp:-}" =~ ^[sSyY]$ ]] && SHOW_PW=1 || SHOW_PW=0
    fi
    tmp="$(mktemp "${SHOW_PW_FILE}.XXXXXX")"
    if ! printf '%s\n' "$SHOW_PW" > "$tmp" || ! chmod 600 "$tmp" || ! mv -f -- "$tmp" "$SHOW_PW_FILE"; then
        rm -f -- "$tmp"
        return 1
    fi
}

# zenity --entry lee --text con mnemónicos ("_" desaparece) y --list como markup
# (con "&" o "<" el título se pierde); ambos aplican además g_strcompress ("\").
zen_entry_text() { local t="${1//\\/"\\\\"}"; printf '%s' "${t//_/__}"; }
zen_list_text() { local t="${1//\\/"\\\\"}"; t="${t//&/"&amp;"}"; t="${t//</"&lt;"}"; printf '%s' "${t//>/"&gt;"}"; }

# Pide una contraseña una vez. Imprime el valor por stdout.
#
# Importante: si el usuario pulsa "Cancelar" en zenity, o el read recibe EOF
# (p.ej. sin terminal real), el comando interno devuelve un código distinto
# de cero. Como esta función casi siempre se invoca así:
#   pass="$(ask_password_once "...")"
# y esa asignación NO es la condición de un if/while, con "set -e" activo
# ese código de salida distinto de cero mataría TODO el script en el acto,
# antes de que el código que comprueba "¿está vacía la contraseña?" llegue
# a ejecutarse. Por eso forzamos que esta función siempre devuelva 0: una
# cancelación se traduce simplemente en una contraseña vacía, que el resto
# del script ya sabe interpretar como "operación cancelada".
ask_password_once() {
    local prompt="$1"
    ensure_show_pw_pref
    if [ "$GUI" = "1" ] && command -v zenity >/dev/null 2>&1; then
        # No se usa "zenity --password": ignora --text y muestra su propio texto.
        local hide=(--hide-text)
        [ "$SHOW_PW" = "1" ] && hide=()
        zenity --entry "${hide[@]}" --title="$APP_TITLE" --window-icon="$APP_ICON" --no-markup \
            --ok-label="$(msg ok)" --cancel-label="$(msg cancel)" --text="$(zen_entry_text "$prompt")" 2>/dev/null || true
    else
        local pw
        if [ "$SHOW_PW" = "1" ]; then
            read -rp "$prompt: " pw >&2 || true
        else
            read -rsp "$prompt: " pw >&2 || true
            echo >&2
        fi
        printf '%s' "$pw"
    fi
}

# Pide una contraseña nueva, la confirma, y falla si no coinciden o está vacía.
#
# A diferencia de ask_password_once, esta función recibe DOS textos ya
# hechos y diferenciados: uno para el paso de "escribir" y otro para el paso
# de "repetir/confirmar" (normalmente indicando el número de paso, p.ej.
# "Paso 2 de 3" y "Paso 3 de 3"). Así queda siempre claro, en cada pantalla,
# qué contraseña se está pidiendo exactamente y en qué punto del proceso
# está el usuario — no se reutiliza un texto genérico de "repite para
# confirmar" que no dijera a cuál de las contraseñas del flujo se refiere.
#
# Límite de intentos: si no hay una terminal real detrás (p.ej. el script se
# invoca con la entrada estándar cerrada o redirigida desde /dev/null, como
# podría pasar desde un cron o desde otro script), cada intento de lectura
# devuelve inmediatamente una contraseña vacía. Sin un límite, eso convertiría
# este bucle en un bucle infinito real (comprobado de forma empírica). Con el
# límite, tras unos intentos fallidos se aborta con un mensaje claro en lugar
# de quedarse colgado para siempre.
ask_new_password() {
    local prompt_write="$1" prompt_confirm="$2"
    local p1 p2
    local intentos=0 max_intentos=5
    while true; do
        p1="$(ask_password_once "$prompt_write")"
        if [ -z "$p1" ]; then
            intentos=$((intentos + 1))
            [ "$intentos" -ge "$max_intentos" ] && err "$(msg password.empty.abort)"
            err_soft "$(msg password.empty)"
            continue
        fi
        if [ "${#p1}" -lt "$MIN_PW_LEN" ]; then
            intentos=$((intentos + 1))
            [ "$intentos" -ge "$max_intentos" ] && err "$(msg password.invalid.abort)"
            err_soft "$(msg password.short "$MIN_PW_LEN")"
            continue
        fi
        p2="$(ask_password_once "$prompt_confirm")"
        if [ "$p1" = "$p2" ]; then
            printf '%s' "$p1"
            return 0
        fi
        intentos=$((intentos + 1))
        [ "$intentos" -ge "$max_intentos" ] && err "$(msg password.mismatch.abort)"
        err_soft "$(msg password.mismatch)"
    done
}

err_soft() {
    if [ "$GUI" = "1" ] && command -v zenity >/dev/null 2>&1; then
        zenity --error --title="$APP_TITLE" --width=400 --window-icon="$APP_ICON" --no-markup --ok-label="$(msg ok)" --text="$1" 2>/dev/null || true
    else
        printf '%s⚠️  %s%s\n' "$C_YELLOW" "$1" "$C_RESET" >&2
    fi
}

# Aviso de "esto puede tardar" antes de una operación pesada (tar+gzip+gpg)
# sobre una ruta grande. No bloquea nunca: en terminal es un printf normal;
# en modo gráfico usa notify-send (si está disponible), NUNCA zenity --info
# (que sí bloquearía la ejecución hasta que el usuario cierre el diálogo).
notice_slow() {
    local msg="$1"
    if [ "$GUI" = "1" ]; then
        command -v notify-send >/dev/null 2>&1 && notify-send -i dialog-information "$APP_TITLE" "$msg" || true
    else
        printf '%sℹ️  %s%s\n' "$C_BLUE" "$msg" "$C_RESET"
    fi
}

# Si "$1" (archivo o carpeta) pesa más que WARN_SIZE_BYTES, avisa de que la
# operación puede tardar. Es un best-effort: si du falla por lo que sea, no
# se avisa y ya está (nunca debe bloquear ni abortar la operación real).
maybe_warn_slow() {
    local path="$1" bytes human
    bytes="$(du -sb -- "$path" 2>/dev/null | cut -f1)" || return 0
    [ -n "$bytes" ] && [ "$bytes" -ge "$WARN_SIZE_BYTES" ] 2>/dev/null || return 0
    human="$(du -sh -- "$path" 2>/dev/null | cut -f1)" && [ -n "$human" ] || return 0
    notice_slow "$(msg slow.notice "$human")"
}

# Tamaño legible de un archivo (pensado para mostrar el peso del .cvault en
# los mensajes de éxito). Devuelve cadena vacía si no se puede calcular.
vault_size() {
    du -h -- "$1" 2>/dev/null | cut -f1
}

check_deps() {
    local bin
    for bin in gpg tar gzip gunzip shred base64 realpath find; do
        command -v "$bin" >/dev/null 2>&1 || err "$(msg cmd.missing "$bin" "$bin")"
    done
}

# Cuando se invoca en modo gráfico (gui-encrypt / gui-menu, típicamente desde
# Nemo) pero falta zenity, los diálogos de contraseña quedarían esperando una
# entrada que nunca llega (no hay terminal), lo que puede colgar el proceso o
# hacerlo girar en un bucle rechazando contraseñas vacías sin parar. Si no hay
# zenity, avisamos como podamos y salimos limpiamente en vez de continuar.
require_gui_zenity() {
    if [ "$GUI" = "1" ] && ! command -v zenity >/dev/null 2>&1; then
        local text
        text="$(msg gui.need_zenity "$APP_TITLE")"
        if command -v notify-send >/dev/null 2>&1; then
            notify-send -i dialog-error "$APP_TITLE" "$text" || true
        fi
        printf '❌ %s\n' "$text" >&2
        mark_reported; exit 1
    fi
}

# Decide qué hacer con una ruta en modo gráfico: si es un vault .cvault abre
# el menú de gestión, si no, lo cifra. La usan tanto "gui <ruta> [...]" como,
# indirectamente, el selector de archivos del lanzador sin argumentos.
gui_dispatch_path() {
    local p="$1"
    if [[ "$p" == *.$EXT ]]; then
        cmd_menu "$p"
    else
        cmd_encrypt "$p"
    fi
}

# Lanzador gráfico SIN argumentos: pensado para un acceso directo en el menú
# de aplicaciones o el escritorio. Pregunta qué se quiere hacer y abre el
# selector de archivos de zenity que corresponda. Nunca debe morir en
# silencio: si el usuario cancela cualquier paso, simplemente no hace nada.
cmd_gui_picker() {
    local choice master_hint nemo_id=nemo_on nemo_label
    master_is_configured && master_hint="$(msg master.status.configured)" || master_hint="$(msg master.status.not_configured)"
    if nemo_actions_present; then nemo_id=nemo_off; nemo_label="$(msg picker.nemo.remove)"; else nemo_label="$(msg picker.nemo.add)"; fi
    choice="$(zenity --list --title="$APP_TITLE" --width=460 --height=390 \
        --window-icon="$APP_ICON" --no-markup --ok-label="$(msg ok)" --cancel-label="$(msg cancel)" \
        --text="$(msg picker.title "$master_hint")" \
        --radiolist --hide-header \
        --column="" --column="$(msg action)" --column="id" \
        TRUE  "$(msg picker.encrypt.file)" encrypt_file \
        FALSE "$(msg picker.encrypt.dir)" encrypt_dir \
        FALSE "$(msg picker.open)" open_vault \
        FALSE "$(msg picker.master.set)" master_set \
        FALSE "$(msg picker.master.unset)" master_unset \
        FALSE "$nemo_label" "$nemo_id" \
        FALSE "$(msg language.option "$(msg "language.$LANG_CODE")" "$(msg "language.$(other_language)")")" language \
        --hide-column=3 --print-column=3 \
        2>/dev/null)" || { info "$(msg operation.cancelled)"; return 0; }

    case "$choice" in
        encrypt_file)
            local sel
            sel="$(zenity --file-selection --title="$(msg picker.file.title)" \
                --window-icon="$APP_ICON" --filename="$HOME/" 2>/dev/null)" \
                || { info "$(msg operation.cancelled)"; return 0; }
            cmd_encrypt "$sel"
            ;;
        encrypt_dir)
            local sel
            sel="$(zenity --file-selection --directory --title="$(msg picker.dir.title)" \
                --window-icon="$APP_ICON" --filename="$HOME/" 2>/dev/null)" \
                || { info "$(msg operation.cancelled)"; return 0; }
            cmd_encrypt "$sel"
            ;;
        open_vault)
            local sel
            sel="$(zenity --file-selection --title="$(msg picker.vault.title)" \
                --window-icon="$APP_ICON" --file-filter="$(msg picker.vault.filter)" \
                --filename="$HOME/" 2>/dev/null)" \
                || { info "$(msg operation.cancelled)"; return 0; }
            cmd_menu "$sel"
            ;;
        master_set)
            cmd_master_set
            ;;
        master_unset)
            cmd_master_unset
            ;;
        nemo_on|nemo_off)
            cmd_nemo_actions "${choice#nemo_}"
            ;;
        language)
            toggle_language
            cmd_gui_picker
            ;;
        *)
            info "$(msg operation.cancelled)" ;;
    esac
}

# ---------- Núcleo criptográfico ----------

# Genera una clave maestra aleatoria de 256 bits, codificada en base64 (una línea).
gen_master_key() {
    head -c 32 /dev/urandom | base64 -w0
}

# Cifra el stdin con la contraseña dada, escribe el resultado en $2.
gpg_enc() {
    local pass="$1" outfile="$2" tmp_out
    tmp_out="$(mktemp "${outfile}.XXXXXX")"
    if ! gpg --batch --yes --no-tty --pinentry-mode loopback \
        --symmetric --cipher-algo "$CIPHER" --digest-algo "$DIGEST" \
        --s2k-mode "$S2K_MODE" --s2k-count "$S2K_COUNT" --s2k-digest-algo "$DIGEST" \
        --no-symkey-cache --compress-algo none \
        --passphrase-fd 3 -o "$tmp_out" 3<<<"$pass"; then
        rm -f -- "$tmp_out"
        return 1
    fi
    if ! mv -f -- "$tmp_out" "$outfile"; then
        rm -f -- "$tmp_out"
        return 1
    fi
}

# Descifra el archivo $2 con la contraseña $1, escribe el resultado a stdout.
gpg_dec() {
    local pass="$1" infile="$2"
    gpg --batch --yes --no-tty --pinentry-mode loopback \
        --no-symkey-cache \
        --passphrase-fd 3 -d "$infile" 3<<<"$pass" 2>/dev/null
}

# ¿Hay una contraseña maestra configurada?
master_is_configured() {
    [ -f "$MASTER_VERIFY_FILE" ]
}

# Comprueba si "$1" es la contraseña maestra ya configurada, descifrando el
# verificador con ella. Devuelve 0 si coincide, 1 si no (contraseña
# incorrecta o no hay ninguna configurada todavía).
master_check() {
    local pass="$1" got
    got="$(gpg_dec "$pass" "$MASTER_VERIFY_FILE")" || return 1
    [ "$got" = "$MASTER_MAGIC" ]
}

# Intenta desbloquear con $2 alguno de los slotN.gpg dentro del directorio $1.
# Si tiene éxito: devuelve 0, y deja el índice en FOUND_SLOT y la clave maestra en FOUND_KEY.
try_unlock() {
    local dir="$1" pass="$2" i=1 key
    while [ -f "$dir/slot${i}.gpg" ]; do
        if key="$(gpg_dec "$pass" "$dir/slot${i}.gpg")"; then
            FOUND_SLOT="$i"
            FOUND_KEY="$key"
            return 0
        fi
        i=$((i + 1))
    done
    return 1
}

# Pide una contraseña (texto $2), la comprueba con try_unlock contra los
# slots de $1. Cancelada -> limpia $1, avisa y devuelve 1. Incorrecta ->
# limpia $1 y aborta con err(). Correcta -> deja FOUND_SLOT/FOUND_KEY y
# devuelve 0. Reúne el patrón que repetían cmd_decrypt/update/change/add/
# remove_password.
unlock_or_cancel() {
    local workdir="$1" prompt="$2" pass
    pass="$(ask_password_once "$prompt")"
    if [ -z "$pass" ]; then
        cleanup_workdir "$workdir"
        info "$(msg operation.cancelled)"
        mark_reported
        return 1
    fi
    if ! try_unlock "$workdir" "$pass"; then
        cleanup_workdir "$workdir"
        err "$(msg wrong.password)"
    fi
    unset pass
    return 0
}

count_slots() {
    local dir="$1" i=1
    while [ -f "$dir/slot${i}.gpg" ]; do i=$((i + 1)); done
    echo $((i - 1))
}

# Cuenta cuántas contraseñas tiene un .cvault SIN extraerlo a disco: basta con
# leer el índice del tar (tar -tf es prácticamente gratis, no descomprime ni
# descifra nada). Si el archivo no es un tar válido, devuelve 0 en silencio;
# la validación "de verdad" ya la hace extract_container cuando corresponda.
count_slots_in_vault() {
    local vault="$1" n
    n="$(tar -tf "$vault" 2>/dev/null | grep -c '^slot[0-9]\+\.gpg$')" || true
    printf '%s' "${n:-0}"
}

# Reconstruye el archivo .cvault a partir del contenido de un directorio de trabajo
# (meta, data.gpg, slotN.gpg...) de forma atómica.
assemble_container() {
    local workdir="$1" vault="$2"
    local tmp_out
    tmp_out="$(mktemp "${vault}.XXXXXX")"
    local slots=() i=1
    while [ -f "$workdir/slot${i}.gpg" ]; do
        slots+=("slot${i}.gpg")
        i=$((i + 1))
    done
    tar -cf "$tmp_out" -C "$workdir" meta data.gpg "${slots[@]}" && mv -f -- "$tmp_out" "$vault" \
        || { rm -f -- "$tmp_out"; return 1; }
}

# Extrae un .cvault a un directorio temporal y valida que tenga la forma esperada.
extract_container() {
    local vault="$1" workdir="$2"
    local members listing count unique slots extracted_slots
    [ -w "$(dirname -- "$vault")" ] || err "$(msg dir.readonly "$(dirname -- "$vault")")"
    members="$(tar -tf "$vault" 2>/dev/null)" || err "$(msg invalid "$vault")"
    printf '%s\n' "$members" | grep -qvE '^(meta|data\.gpg|slot[0-9]+\.gpg)$' \
        && err "$(msg invalid "$vault")"
    listing="$(LC_ALL=C tar -tvf "$vault" 2>/dev/null)" || err "$(msg invalid "$vault")"
    printf '%s\n' "$listing" | grep -qv '^-' && err "$(msg invalid "$vault")"
    count="$(printf '%s\n' "$members" | wc -l)"
    unique="$(printf '%s\n' "$members" | sort -u | wc -l)"
    [ "$count" = "$unique" ] || err "$(msg invalid "$vault")"
    slots="$(printf '%s\n' "$members" | grep -cE '^slot[0-9]+\.gpg$')" || true
    [ "$slots" -ge 1 ] || err "$(msg invalid "$vault")"
    tar -xf "$vault" -C "$workdir" 2>/dev/null || err "$(msg invalid "$vault")"
    [ -f "$workdir/meta" ] && [ -f "$workdir/data.gpg" ] && [ -f "$workdir/slot1.gpg" ] \
        || err "$(msg invalid "$vault")"
    extracted_slots="$(count_slots "$workdir")"
    [ "$extracted_slots" = "$slots" ] || err "$(msg invalid "$vault")"
}

read_meta() {
    local workdir="$1" vault="${2:-vault}"
    # El "|| true" es necesario: si el archivo 'meta' viniera corrupto o
    # manipulado y no trajera línea TYPE=/NAME=, grep no encuentra nada y
    # devuelve código de salida 1. Sin el "|| true", con set -e + pipefail
    # activos eso mataría el script ahí mismo, sin mensaje de error y sin
    # limpiar el workdir. Con "|| true" seguimos adelante con la variable
    # vacía, y son los case de más abajo los que ya saben convertir un
    # META_NAME o META_TYPE vacío en un error claro para el usuario.
    META_TYPE="$(grep '^TYPE=' "$workdir/meta" 2>/dev/null | head -1 | cut -d= -f2-)" || true
    META_NAME="$(grep '^NAME=' "$workdir/meta" 2>/dev/null | head -1 | cut -d= -f2-)" || true

    # Los metadatos vienen DENTRO del .cvault, así que hay que tratarlos como
    # datos no confiables: un vault manipulado a mano podría traer un NAME=
    # con "../" o una ruta absoluta para intentar escribir fuera de la carpeta
    # de destino al descifrar (path traversal). Se rechaza cualquier NAME que
    # no sea un simple nombre de archivo/carpeta.
    case "$META_NAME" in
        ''|*/*|.|..)
            err "$(msg invalid.name "$vault")"
            ;;
    esac
    case "$META_TYPE" in
        file|dir) : ;;
        *)
            err "$(msg invalid.type "$vault")"
            ;;
    esac
}

declare -a _ACTIVE_WORKDIRS=()

# mk_workdir se sigue usando siempre como "workdir=\"$(mk_workdir)\"", y esa
# sustitución de comandos se ejecuta en una subshell: si mk_workdir intentara
# registrar el directorio en _ACTIVE_WORKDIRS ella misma, el cambio se
# perdería al salir de la subshell y el array global nunca se enteraría. Por
# eso el registro se hace aparte, con register_workdir, ya en el shell
# principal, justo después de cada "workdir=\"$(mk_workdir)\"".
mk_workdir() {
    mktemp -d
}

register_workdir() {
    _ACTIVE_WORKDIRS+=("$1")
}

cleanup_workdir() {
    local target="${1:-}" d
    local -a kept_dirs=()
    [ -n "$target" ] && [ -d "$target" ] && rm -rf "$target"
    for d in "${_ACTIVE_WORKDIRS[@]}"; do
        [ "$d" = "$target" ] || kept_dirs+=("$d")
    done
    _ACTIVE_WORKDIRS=("${kept_dirs[@]}")
}

# Red de seguridad: borra cualquier workdir que se quedara a medias, tanto si
# el script termina normalmente como si sale por error (err() hace exit 1
# directamente, sin pasar por cleanup_workdir) o lo interrumpen (Ctrl+C).
cleanup_all_workdirs() {
    local rc=$? d
    if [ "$rc" -gt 0 ] && [ "$rc" -lt 128 ] && [ "$GUI" = "1" ] && [ ! -e "${SHOW_PW_FILE:-/}.err" ]; then
        err_soft "$(msg unexpected "$rc")"   # p. ej. tar/gpg falló bajo set -e: Nemo no muestra stderr
    fi
    for d in "${_ACTIVE_WORKDIRS[@]}"; do
        [ -d "$d" ] && rm -rf "$d"
    done
    [ -n "${SHOW_PW_FILE:-}" ] && rm -f -- "$SHOW_PW_FILE" "$SHOW_PW_FILE.err"
    return 0
}
trap cleanup_all_workdirs EXIT

# IMPORTANTE: EXIT por sí solo no basta para Ctrl+C / cierre de sesión. Si
# INT/TERM comparten el mismo handler que EXIT y ese handler no llama a
# "exit" explícitamente, bash no restaura el comportamiento por defecto de la
# señal: el trap se ejecuta (limpia los workdirs) pero el script puede
# quedarse colgado sin terminar ni seguir, sobre todo si la señal llega
# mientras se está esperando una contraseña (el builtin "read" bloqueado).
# Comprobado de forma empírica con una pty real: sin el "exit" explícito de
# abajo, Ctrl+C durante un "read" deja el proceso vivo y hay que matarlo con
# SIGKILL. Por eso aquí SÍ forzamos la salida (con el código de convención
# 128+señal), lo que además dispara igualmente el trap EXIT de arriba para
# que la limpieza se haga en los dos casos.
trap 'exit 130' INT
trap 'exit 143' TERM

# ---------- Comandos ----------

# Rechaza cifrar/actualizar apuntando directamente a '.', '..' o cualquier
# ruta cuyo último componente sea uno de esos dos (p.ej. 'carpeta/..'). Si no
# se hiciera esta comprobación, "cifrar ." seguido de aceptar "eliminar el
# original de forma segura" acabaría en un `find . -type f -exec shred ...`
# seguido de `rm -rf .` sobre TODO el directorio de trabajo actual (o su
# padre, con ".."): rm se niega a borrar '.'/'..' por seguridad, pero el
# shred de todos los archivos ya se habría ejecutado igualmente para
# entonces. Comprobado de forma empírica: sin esta guarda, el bug es real.
reject_dot_path() {
    local path="$1"
    case "$(basename -- "$path")" in
        .|..)
            err "$(msg path.dot "$path" "$(realpath -- "$path")")"
            ;;
    esac
}

# Antepone "./" a una ruta relativa que empiece por "-", para que basename,
# dirname, find o shred no la confundan con una opción de línea de comandos.
normalize_path() {
    case "$1" in
        -*) printf './%s' "$1" ;;
        *)  printf '%s' "$1" ;;
    esac
}

# Cuando hay contraseña maestra configurada, sustituye al paso de "crear la
# contraseña principal" en cmd_encrypt: se pide UNA sola vez (sin repetirla)
# y se comprueba al momento contra el verificador guardado, así un error de
# tecleo se detecta igual que si se pidiera dos veces. Sigue el mismo patrón
# de reintentos que ask_new_password (vacía o incorrecta cuenta como intento
# fallido; se aborta con err() tras max_intentos).
ask_master_password_for_new_vault() {
    local base="$1" pass intentos=0 max_intentos=5
    while true; do
        pass="$(ask_password_once "$(msg master.prompt "$base")")"
        if [ -z "$pass" ]; then
            intentos=$((intentos + 1))
            [ "$intentos" -ge "$max_intentos" ] && err "$(msg master.empty.abort)"
            err_soft "$(msg password.empty)"
            continue
        fi
        if master_check "$pass"; then
            printf '%s' "$pass"
            return 0
        fi
        intentos=$((intentos + 1))
        [ "$intentos" -ge "$max_intentos" ] && err "$(msg master.wrong.abort)"
        err_soft "$(msg master.wrong)"
    done
}

reject_unsafe_tree() {
    local path="$1" found
    found="$(find -P -- "$path" -mindepth 1 ! \( -type f -o -type d \) -print -quit 2>/dev/null)"
    [ -z "$found" ] || err "$(msg path.unsupported "$path")"
}

validate_payload() {
    local key="$1" data="$2" listing
    listing="$(gpg_dec "$key" "$data" | gunzip -c | tar -tvf - 2>/dev/null)" || return 1
    ! printf '%s\n' "$listing" | grep -qvE '^[-dh]'
}

# Destruye el original solo si el vault recién escrito descifra entero, y sin mentir: si shred falla
# (p. ej. un archivo de solo lectura) no se sigue con rm -rf ni se afirma un borrado seguro.
secure_delete() {
    local path="$1" type="$2" vault="$3" key="$4" ok=1
    tar -xOf "$vault" data.gpg | gpg_dec "$key" - | gunzip -t 2>/dev/null || err "$(msg verify.failed "$vault")"
    if [ "$type" = dir ]; then
        find "$path" -type f -exec shred -f -u -z -n 3 -- {} + && rm -rf -- "$path" || ok=0
    else
        shred -f -u -z -n 3 -- "$path" || ok=0
    fi
    [ "$ok" = 1 ] || err "$(msg shred.failed "$path")"
}

cmd_encrypt() {
    local path; path="$(normalize_path "${1%/}")"
    [ -e "$path" ] || err "$(msg path.exists "$path")"
    reject_dot_path "$path"
    if [ -L "$path" ]; then
        err "$(msg path.symlink "$path" "$(readlink -f -- "$path")")"
    fi
    case "$path" in
        *.$EXT) err "$(msg path.is.vault "$path")" ;;
    esac

    local parent base type vault
    base="$(basename "$path")"
    parent="$(dirname "$path")"
    vault="${parent}/${base}.${EXT}"
    [ -w "$parent" ] || err "$(msg dir.readonly "$parent")"
    [ -d "$path" ] && type="dir" || type="file"
    [ "$type" = dir ] && reject_unsafe_tree "$path"

    if [ -e "$vault" ]; then
        if ask_yesno "$(msg vault.exists "$base" "$base.$EXT")"; then
            cmd_update "$path"
            return
        fi
        if ! ask_yesno "$(msg vault.overwrite "$base.$EXT")"; then
            info "$(msg operation.cancelled)"
            return
        fi
        if [ -d "$vault" ]; then err "$(msg vault.dir "$vault")"; fi
    fi   # el vault viejo se reemplaza de forma atómica al final, nunca antes

    ensure_show_pw_pref
    local pw1
    if master_is_configured; then
        pw1="$(ask_master_password_for_new_vault "$base")"
    else
        pw1="$(ask_new_password \
            "$(msg pw.main.new "$base")" \
            "$(msg pw.main.confirm)")"
    fi

    local passwords=("$pw1")
    if ask_yesno "$(msg pw.second.ask)"; then
        local pw2
        pw2="$(ask_new_password \
            "$(msg pw.second.new "$base")" \
            "$(msg pw.second.confirm)")"
        passwords+=("$pw2")
    fi

    local workdir master_key pwcount
    workdir="$(mk_workdir)"
    register_workdir "$workdir"
    master_key="$(gen_master_key)"
    pwcount=${#passwords[@]}

    printf 'TYPE=%s\nNAME=%s\n' "$type" "$base" > "$workdir/meta"

    maybe_warn_slow "$path"
    if [ "$type" = "dir" ]; then
        tar -cf - -C "$parent" "$base" | gzip -c | gpg_enc "$master_key" "$workdir/data.gpg"
    else
        gzip -c "$path" | gpg_enc "$master_key" "$workdir/data.gpg"
    fi

    local i=1 pw
    for pw in "${passwords[@]}"; do
        printf '%s' "$master_key" | gpg_enc "$pw" "$workdir/slot${i}.gpg"
        i=$((i + 1))
    done
    unset pw1 pw2 pw passwords   # master_key se conserva hasta verificar el vault (secure_delete)

    assemble_container "$workdir" "$vault"
    cleanup_workdir "$workdir"
    local pw_word
    if [ "$pwcount" -eq 1 ]; then
        pw_word="$(msg password.word.one)"
    else
        pw_word="$(msg password.word.many)"
    fi
    ok_msg "$(msg encrypt.success "$base" "$base.$EXT" "$pwcount" "$pw_word")"

    if ask_yesno "$(msg pw.delete.original "$base")"; then
        secure_delete "$path" "$type" "$vault" "$master_key"
        info "$(msg original.deleted)"
    fi
    unset master_key
}

cmd_decrypt() {
    local vault out_parent target_path
    vault="$(normalize_path "$1")"
    [ -f "$vault" ] || err "$(msg path.exists "$vault")"
    out_parent="$(dirname "$vault")"

    local workdir
    workdir="$(mk_workdir)"
    register_workdir "$workdir"
    extract_container "$vault" "$workdir"
    read_meta "$workdir" "$vault"

    ensure_show_pw_pref
    unlock_or_cancel "$workdir" "$(msg decrypt.prompt "$(basename "$vault")")" || return

    target_path="${out_parent}/${META_NAME}"

    # Defensa adicional: aunque META_NAME ya se valida en read_meta, nos
    # aseguramos también de que la ruta resuelta siga estando dentro de
    # out_parent antes de escribir nada en disco.
    local resolved_parent resolved_target
    resolved_parent="$(realpath -m -- "$out_parent")"
    resolved_target="$(realpath -m -- "$target_path")"
    case "$resolved_target" in
        "$resolved_parent"/*) : ;;
        *)
            cleanup_workdir "$workdir"
            err "$(msg path.destination "$vault")"
            ;;
    esac

    if [ -e "$target_path" ]; then
        cleanup_workdir "$workdir"
        err "$(msg path.already.exists "$target_path")"
    fi

    local size; size="$(vault_size "$vault")"
    maybe_warn_slow "$vault"
    local staged
    if [ "$META_TYPE" = "dir" ]; then
        validate_payload "$FOUND_KEY" "$workdir/data.gpg" || {
            unset FOUND_KEY
            cleanup_workdir "$workdir"
            err "$(msg invalid "$vault")"
        }
        staged="$(mktemp -d "$out_parent/.enkripta-decrypt.XXXXXX")"
        register_workdir "$staged"
        gpg_dec "$FOUND_KEY" "$workdir/data.gpg" | gunzip -c \
            | tar -x --one-top-level="$META_NAME" -C "$staged"
        [ -d "$staged/$META_NAME" ] || { cleanup_workdir "$staged"; cleanup_workdir "$workdir"; err "$(msg invalid "$vault")"; }
        # -n -T: ni sobrescribe nada que ya exista en destino (incluido un
        # symlink colgante que "-e" no detecta) ni, si target_path resultara
        # ser un directorio real, mueve el contenido DENTRO de él.
        if ! mv -n -T -- "$staged/$META_NAME" "$target_path"; then
            cleanup_workdir "$staged"; cleanup_workdir "$workdir"; unset FOUND_KEY
            err "$(msg path.already.exists "$target_path")"
        fi
        cleanup_workdir "$staged"
    else
        staged="$(mktemp "$out_parent/.enkripta-decrypt.XXXXXX")"
        register_workdir "$staged"
        if ! gpg_dec "$FOUND_KEY" "$workdir/data.gpg" | gunzip -c > "$staged"; then
            cleanup_workdir "$staged"
            cleanup_workdir "$workdir"
            unset FOUND_KEY
            err "$(msg invalid "$vault")"
        fi
        if ! mv -n -T -- "$staged" "$target_path"; then
            cleanup_workdir "$staged"; cleanup_workdir "$workdir"; unset FOUND_KEY
            err "$(msg path.already.exists "$target_path")"
        fi
        cleanup_workdir "$staged"
    fi
    unset FOUND_KEY
    cleanup_workdir "$workdir"

    ok_msg "$(msg decrypt.success "$META_NAME" "${size:+ ($size)}" "$target_path")"

    if [ "$GUI" = "1" ] && command -v xdg-open >/dev/null 2>&1; then
        if ask_yesno "$(msg open.now "$META_NAME")"; then
            xdg-open "$target_path" >/dev/null 2>&1 &
        fi
    fi
}

cmd_update() {
    local path; path="$(normalize_path "${1%/}")"
    [ -e "$path" ] || err "$(msg path.exists "$path")"
    case "$path" in
        *.$EXT) err "$(msg update.is.vault "$path")" ;;
    esac
    reject_dot_path "$path"
    if [ -L "$path" ]; then
        err "$(msg path.symlink "$path" "$(readlink -f -- "$path")")"
    fi
    local base parent vault
    base="$(basename "$path")"
    parent="$(dirname "$path")"
    vault="${parent}/${base}.${EXT}"
    [ -f "$vault" ] || err "$(msg vault.missing "$base.$EXT")"

    local workdir
    workdir="$(mk_workdir)"
    register_workdir "$workdir"
    extract_container "$vault" "$workdir"

    ensure_show_pw_pref
    unlock_or_cancel "$workdir" "$(msg update.prompt "$base.$EXT")" || return

    local type
    [ -d "$path" ] && type="dir" || type="file"
    [ "$type" = dir ] && reject_unsafe_tree "$path"
    printf 'TYPE=%s\nNAME=%s\n' "$type" "$base" > "$workdir/meta"
    rm -f "$workdir/data.gpg"
    maybe_warn_slow "$path"
    if [ "$type" = "dir" ]; then
        tar -cf - -C "$parent" "$base" | gzip -c | gpg_enc "$FOUND_KEY" "$workdir/data.gpg"
    else
        gzip -c "$path" | gpg_enc "$FOUND_KEY" "$workdir/data.gpg"
    fi

    assemble_container "$workdir" "$vault"
    cleanup_workdir "$workdir"
    local size; size="$(vault_size "$vault")"
    ok_msg "$(msg update.success "$base.$EXT" "${size:+ ($size)}")"

    if ask_yesno "$(msg secure.copy "$base")"; then
        secure_delete "$path" "$type" "$vault" "$FOUND_KEY"
    fi
    unset FOUND_KEY
}

cmd_change_password() {
    local vault; vault="$(normalize_path "$1")"
    [ -f "$vault" ] || err "$(msg path.exists "$vault")"
    local workdir
    workdir="$(mk_workdir)"
    register_workdir "$workdir"
    extract_container "$vault" "$workdir"

    ensure_show_pw_pref
    unlock_or_cancel "$workdir" "$(msg change.current)" || return
    local slot="$FOUND_SLOT" key="$FOUND_KEY"
    unset FOUND_KEY

    local newpw
    newpw="$(ask_new_password \
        "$(msg change.new)" \
        "$(msg change.confirm)")"
    printf '%s' "$key" | gpg_enc "$newpw" "$workdir/slot${slot}.gpg"
    unset key newpw

    assemble_container "$workdir" "$vault"
    cleanup_workdir "$workdir"
    ok_msg "$(msg password.updated)"
}

cmd_add_password() {
    local vault; vault="$(normalize_path "$1")"
    [ -f "$vault" ] || err "$(msg path.exists "$vault")"
    local workdir
    workdir="$(mk_workdir)"
    register_workdir "$workdir"
    extract_container "$vault" "$workdir"

    ensure_show_pw_pref
    unlock_or_cancel "$workdir" "$(msg add.authorize)" || return
    local key="$FOUND_KEY"
    unset FOUND_KEY

    local n newpw
    n=$(( $(count_slots "$workdir") + 1 ))
    newpw="$(ask_new_password \
        "$(msg add.new)" \
        "$(msg add.confirm)")"
    printf '%s' "$key" | gpg_enc "$newpw" "$workdir/slot${n}.gpg"
    unset key newpw

    assemble_container "$workdir" "$vault"
    cleanup_workdir "$workdir"
    ok_msg "$(msg password.added "$n")"
}

cmd_remove_password() {
    local vault; vault="$(normalize_path "$1")"
    [ -f "$vault" ] || err "$(msg path.exists "$vault")"
    local workdir
    workdir="$(mk_workdir)"
    register_workdir "$workdir"
    extract_container "$vault" "$workdir"

    local total
    total="$(count_slots "$workdir")"
    if [ "$total" -le 1 ]; then
        cleanup_workdir "$workdir"
        err "$(msg remove.only)"
    fi

    ensure_show_pw_pref
    unlock_or_cancel "$workdir" "$(msg remove.prompt)" || return
    local remove_slot="$FOUND_SLOT"
    unset FOUND_KEY

    if ! ask_yesno "$(msg remove.confirm)"; then
        cleanup_workdir "$workdir"
        info "$(msg operation.cancelled)"
        return
    fi

    local newdir i kept=0
    newdir="$(mk_workdir)"
    register_workdir "$newdir"
    cp "$workdir/meta" "$newdir/meta"
    cp "$workdir/data.gpg" "$newdir/data.gpg"
    i=1
    while [ -f "$workdir/slot${i}.gpg" ]; do
        if [ "$i" -ne "$remove_slot" ]; then
            kept=$((kept + 1))
            cp "$workdir/slot${i}.gpg" "$newdir/slot${kept}.gpg"
        fi
        i=$((i + 1))
    done
    assemble_container "$newdir" "$vault"
    cleanup_workdir "$newdir"
    cleanup_workdir "$workdir"

    if [ "$kept" -eq 1 ]; then
        ok_msg "$(msg password.removed.one)"
    else
        ok_msg "$(msg password.removed.many "$kept")"
    fi
}

# Configura (o reemplaza) la contraseña maestra: a partir de ahora, cifrar
# algo nuevo con cmd_encrypt la pedirá una sola vez en vez de obligar a crear
# y repetir una contraseña distinta para cada vault. No afecta a los vaults
# que ya existen (sus contraseñas no cambian).
cmd_master_set() {
    if master_is_configured; then
        ask_yesno "$(msg master.replace)" \
            || { info "$(msg operation.cancelled)"; return; }
    fi
    ensure_show_pw_pref
    local p1
    p1="$(ask_new_password \
        "$(msg master.new)" \
        "$(msg master.confirm)")"
    mkdir -p "$ENKRIPTA_DATA_DIR"
    chmod 700 "$ENKRIPTA_DATA_DIR"
    printf '%s' "$MASTER_MAGIC" | gpg_enc "$p1" "$MASTER_VERIFY_FILE"
    chmod 600 "$MASTER_VERIFY_FILE"
    unset p1
    ok_msg "$(msg master.configured)"
}

# Quita la contraseña maestra configurada. Los vaults ya creados no se ven
# afectados: vuelven a poder abrirse con la contraseña que tuvieran, igual
# que siempre. Solo cambia lo que se cifre a partir de ahora.
cmd_master_unset() {
    if ! master_is_configured; then
        info "$(msg master.none)"
        return
    fi
    ask_yesno "$(msg master.remove)" \
        || { info "$(msg operation.cancelled)"; return; }
    rm -f "$MASTER_VERIFY_FILE"
    ok_msg "$(msg master.removed)"
}

# Menú interactivo para un vault ya existente (usado al hacer doble clic o desde Nemo).
cmd_menu() {
    local vault; vault="$(normalize_path "$1")"
    [ -f "$vault" ] || err "$(msg path.exists "$vault")"
    local base
    base="$(basename "$vault")"

    local nslots slots_hint=""
    nslots="$(count_slots_in_vault "$vault")"
    case "$nslots" in
        ''|0) : ;;
        1) slots_hint="$(msg slots.one)" ;;
        *) slots_hint="$(msg slots.many "$nslots")" ;;
    esac

    local choice
    if [ "$GUI" = "1" ] && command -v zenity >/dev/null 2>&1; then
        choice="$(zenity --list --title="$APP_TITLE" --width=500 --height=330 \
            --window-icon="$APP_ICON" --no-markup --ok-label="$(msg ok)" --cancel-label="$(msg cancel)" \
            --text="$(zen_list_text "$(msg menu.title "$base" "$slots_hint")")" \
            --radiolist --hide-header \
            --column="" --column="$(msg action)" --column="id" \
            TRUE  "$(msg menu.decrypt)" decrypt \
            FALSE "$(msg menu.change)" change \
            FALSE "$(msg menu.add)" add \
            FALSE "$(msg menu.remove)" remove \
            FALSE "$(msg language.option "$(msg "language.$LANG_CODE")" "$(msg "language.$(other_language)")")" language \
            --hide-column=3 --print-column=3 \
            2>/dev/null)" || { info "$(msg operation.cancelled)"; return; }
        case "$choice" in
            decrypt) cmd_decrypt "$vault" ;;
            change) cmd_change_password "$vault" ;;
            add) cmd_add_password "$vault" ;;
            remove) cmd_remove_password "$vault" ;;
            language) toggle_language; cmd_menu "$vault" ;;
            *) info "$(msg operation.cancelled)" ;;
        esac
    else
        while :; do
            case "$nslots" in
                ''|0) slots_hint="" ;;
                1) slots_hint="$(msg slots.one)" ;;
                *) slots_hint="$(msg slots.many "$nslots")" ;;
            esac
            echo "$(msg menu.title "$base" "$slots_hint")"
            printf '1) %s\n' "$(msg menu.decrypt)"
            printf '2) %s\n' "$(msg menu.change)"
            printf '3) %s\n' "$(msg menu.add)"
            printf '4) %s\n' "$(msg menu.remove)"
            printf '5) %s\n' "$(msg cancel)"
            printf '%s\n' "$(msg menu.language "$(msg "language.$LANG_CODE")" "$(msg "language.$(other_language)")")"
            printf '%s' "$(msg menu.prompt)"
            IFS= read -r choice || { info "$(msg operation.cancelled)"; break; }
            case "$choice" in
                1) cmd_decrypt "$vault"; break ;;
                2) cmd_change_password "$vault"; break ;;
                3) cmd_add_password "$vault"; break ;;
                4) cmd_remove_password "$vault"; break ;;
                5|"") info "$(msg operation.cancelled)"; break ;;
                [Ll]) toggle_language; continue ;;
                *) ;;
            esac
        done
    fi
}

usage() {
    local code="${1:-1}"
    local is_help="${2:-0}"
    local body
    body="$(msg usage "$0" "$0" "$0" "$0" "$0" "$0" "$0" "$0" "$0" "$0" "$0" "$0" "$0" "$0" "$0" "$0" "$0" "$0" "$0" "$0" "$0")"
    if [ "$is_help" = "1" ]; then
        printf '%s\n' "$body"
        exit "$code"
    fi
    if [ ! -t 1 ] || [ "$GUI" = "1" ]; then
        if command -v zenity >/dev/null 2>&1; then
            GUI=1
            if zenity --question --title="$APP_TITLE" --width=440 --window-icon="$APP_ICON" --no-markup \
                --ok-label="$(msg assistant.open)" --cancel-label="$(msg cancel)" \
                --text="$(msg usage.noarg "$APP_TITLE")" 2>/dev/null; then
                cmd_gui_picker
                exit 0
            fi
            mark_reported; exit "$code"
        elif command -v notify-send >/dev/null 2>&1; then
            notify-send -i dialog-error "$APP_TITLE" "$(msg usage.notify)" || true
        fi
    fi
    printf '%s\n' "$body"
    mark_reported; exit "$code"
}

# ---------- Main ----------

# Adelanto de GUI: si el subcomando es gráfico, check_deps debe poder avisar
# con un diálogo (o notify-send) en vez de un stderr que nadie va a ver al
# lanzarse desde Nemo/menú/escritorio, sin terminal detrás.
case "${1:-}" in
    gui|gui-*) GUI=1; sync_nemo_actions ;;
esac

case "${1:-}" in
    -l|--toggle-language)
        toggle_language
        exit 0
        ;;
    --nemo-actions)    # uso interno del instalador
        [ -e "$NEMO_OFF_FILE" ] || write_nemo_actions
        exit 0
        ;;
esac

check_deps
[ $# -ge 1 ] || usage

cmd="$1"; shift || true

case "$cmd" in
    cifrar|encrypt)
        [ $# -ge 1 ] || usage
        GUI=0; for p in "$@"; do cmd_encrypt "$p"; done ;;
    cifrar_facil|easy-encrypt)
        [ $# -ge 1 ] || usage
        GUI=0
        for p in "$@"; do
            if [[ "$p" == *.$EXT ]]; then
                cmd_menu "$p"
            else
                cmd_encrypt "$p"
            fi
        done ;;
    descifrar|decrypt)
        [ $# -ge 1 ] || usage
        GUI=0; for v in "$@"; do cmd_decrypt "$v"; done ;;
    actualizar|update)
        [ $# -ge 1 ] || usage
        GUI=0; for p in "$@"; do cmd_update "$p"; done ;;
    cambiar-contrasena|change-password)
        [ $# -ge 1 ] || usage
        GUI=0; for v in "$@"; do cmd_change_password "$v"; done ;;
    anadir-contrasena|add-password)
        [ $# -ge 1 ] || usage
        GUI=0; for v in "$@"; do cmd_add_password "$v"; done ;;
    eliminar-contrasena|remove-password)
        [ $# -ge 1 ] || usage
        GUI=0; for v in "$@"; do cmd_remove_password "$v"; done ;;
    contrasena-maestra|master-password)
        GUI=0; cmd_master_set ;;
    quitar-contrasena-maestra|remove-master-password)
        GUI=0; cmd_master_unset ;;
    anadir-acciones-nemo|add-nemo-actions)
        GUI=0; cmd_nemo_actions on ;;
    quitar-acciones-nemo|remove-nemo-actions)
        GUI=0; cmd_nemo_actions off ;;
    gui-encrypt)
        [ $# -ge 1 ] || usage
        GUI=1; require_gui_zenity
        for p in "$@"; do cmd_encrypt "$p"; done ;;
    gui-menu)
        [ $# -ge 1 ] || usage
        GUI=1; require_gui_zenity
        for v in "$@"; do cmd_menu "$v"; done ;;
    gui)
        GUI=1; require_gui_zenity
        if [ $# -eq 0 ]; then
            cmd_gui_picker
        else
            for p in "$@"; do gui_dispatch_path "$p"; done
        fi ;;
    --help|-h)
        usage 0 1 ;;
    --version|-v)
        echo "$APP_TITLE $APP_VERSION"
        exit 0 ;;
    *)
        # Modo "inteligente" de un solo argumento: enkripta.sh <ruta>
        # Si no hay terminal detrás (p. ej. un acceso directo mal configurado
        # que pase la ruta directamente, sin "gui"), pasamos a modo gráfico en
        # vez de quedarnos esperando una contraseña por teclado que nunca va
        # a llegar.
        if [ $# -eq 0 ]; then
            path="$cmd"
            if [ ! -t 0 ] || [ ! -t 1 ]; then
                GUI=1
                require_gui_zenity
            fi
            if [[ "$path" == *.$EXT ]]; then
                cmd_menu "$path"
            elif [ -e "$path" ]; then
                cmd_encrypt "$path"
            else
                usage
            fi
        else
            usage
        fi
        ;;
esac
ENKRIPTA_SH_EOF
DEST_SCRIPT="$_dest_script_final"
chmod 755 -- "$_dest_script_tmp"
mv -f -- "$_dest_script_tmp" "$DEST_SCRIPT"
unset _dest_script_tmp _dest_script_final
ok "$(msg installed.script "$DEST_SCRIPT")"

# En "Exec=" de un .desktop, "%" introduce un código de campo (%f, %F...);
# si $HOME (y por tanto $DEST_SCRIPT) contuviera un "%" literal, hay que
# duplicarlo para que se muestre tal cual en vez de romper el parseo.
EXEC_SCRIPT="${DEST_SCRIPT//%/%%}"

case ":$PATH:" in
    *":$BIN_DIR:"*) : ;;
    *) warn "$(msg path.warn "$BIN_DIR")" ;;
esac

# ---------- 2. Icono (embebido en este mismo archivo) ----------

TMP_ICON="$(mktemp)"
cat > "$TMP_ICON" <<'ENKRIPTA_SVG_EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#2E7D6B"/>
      <stop offset="1" stop-color="#1B4B6B"/>
    </linearGradient>
  </defs>
  <rect x="4" y="4" width="120" height="120" rx="26" fill="url(#bg)"/>
  <path d="M28 46 h34 l10 10 h28 a6 6 0 0 1 6 6 v46 a6 6 0 0 1 -6 6 H28 a6 6 0 0 1 -6 -6 V52 a6 6 0 0 1 6 -6 z"
        fill="#EAF3F1" opacity="0.18"/>
  <g>
    <rect x="44" y="66" width="46" height="36" rx="8" fill="#F4F7F6"/>
    <path d="M52 66 v-12 a15 15 0 0 1 30 0 v12" fill="none" stroke="#F4F7F6" stroke-width="7" stroke-linecap="round"/>
    <circle cx="67" cy="82" r="6" fill="#1B4B6B"/>
    <rect x="64" y="82" width="6" height="12" rx="3" fill="#1B4B6B"/>
  </g>
</svg>
ENKRIPTA_SVG_EOF
mkdir -p "$ICON_APPS_DIR" "$ICON_MIME_DIR"
install_atomic "$DEST_ICON_APP" 644 < "$TMP_ICON"
install_atomic "$DEST_ICON_MIME" 644 < "$TMP_ICON"
rm -f "$TMP_ICON"; TMP_ICON=""
ok "$(msg icon)"

# ---------- 3. Lanzador de menú (.desktop) ----------

mkdir -p "$APPS_DIR"
install_atomic "$DESKTOP_FILE" 755 <<EOF
[Desktop Entry]
Type=Application
Name=Enkripta
GenericName=File and folder encryption
GenericName[es]=Cifrado de carpetas y archivos
Comment=Encrypts and decrypts files or folders with a password (AES-256)
Comment[es]=Cifra y descifra carpetas o archivos con contraseña (AES-256)
Exec="$EXEC_SCRIPT" gui %F
Icon=$DEST_ICON_APP
Terminal=false
Categories=Utility;Security;
MimeType=application/x-cvault;
Keywords=encrypt;encryption;password;security;vault;
Keywords[es]=cifrar;cifrado;encriptar;contraseña;seguridad;vault;
StartupNotify=false
EOF
ok "$(msg menu)"

# ---------- 4. Tipo MIME .cvault + asociación por defecto ----------

mkdir -p "$MIME_DIR"
install_atomic "$MIME_XML" 644 <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="application/x-cvault">
    <comment>Encrypted Enkripta vault</comment>
    <comment xml:lang="es">Vault cifrado de Enkripta</comment>
    <glob pattern="*.cvault"/>
    <icon name="application-x-cvault"/>
  </mime-type>
</mime-info>
EOF
ok "$(msg mime)"

refresh_caches

if command -v xdg-mime >/dev/null 2>&1; then
    xdg-mime default enkripta.desktop application/x-cvault 2>/dev/null || true
    ok "$(msg default)"
else
    warn "$(msg mime.manual)"
fi

# ---------- 5. Acciones de clic derecho en Nemo ----------

if ! ENKRIPTA_LANG="$LANG_CODE" "$DEST_SCRIPT" --nemo-actions; then warn "$(msg actions.failed)"
elif [ -f "$ACTION_ENCRYPT" ]; then ok "$(msg actions)"
else info "$(msg actions.off)"; fi

# ---------- 6. Acceso directo en el Escritorio ----------

mkdir -p "$DESKTOP_DIR"
install_atomic "$DESKTOP_SHORTCUT" 755 <<EOF
[Desktop Entry]
Type=Application
Name=Enkripta
GenericName=File and folder encryption
GenericName[es]=Cifrado de carpetas y archivos
Comment=Encrypts and decrypts files or folders with a password (AES-256)
Comment[es]=Cifra y descifra carpetas o archivos con contraseña (AES-256)
Exec="$EXEC_SCRIPT" gui %F
Icon=$DEST_ICON_APP
Terminal=false
Categories=Utility;Security;
MimeType=application/x-cvault;
StartupNotify=false
EOF
# Nemo/Nautilus marcan como "no confiable" un .desktop nuevo hasta que se
# autoriza a mano; lo autorizamos aquí para que funcione con un doble clic.
if command -v gio >/dev/null 2>&1; then
    gio set "$DESKTOP_SHORTCUT" "metadata::trusted" true 2>/dev/null || true
fi
ok "$(msg desktop "$DESKTOP_DIR")"

# ---------- Reiniciar Nemo para que lo note ya mismo ----------

if command -v nemo >/dev/null 2>&1; then
    nemo -q >/dev/null 2>&1 || true
    info "$(msg nemo)"
fi

echo
ok "$(msg ready)"
echo
if ! command -v zenity >/dev/null 2>&1; then
    warn "$(msg zenity.reminder)"
fi
warn "$(msg desktop.trust)"
