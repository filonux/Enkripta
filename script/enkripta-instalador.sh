#!/usr/bin/env bash
#
# Copyright (C) 2026 Filonux
#
# Licencia:
# Enkripta es software libre distribuido bajo los términos de la
# GNU General Public License versión 3 (GPLv3).
# Consulte el archivo LICENSE para obtener el texto completo de la licencia.
#
# enkripta-instalador.sh — Enkripta para Cinnamon/Nemo (Linux Mint) en UN SOLO ARCHIVO
#
# Este script lleva embebidos tanto el programa (enkripta.sh) como su
# icono (SVG). No depende de ningún otro archivo: puedes moverlo, enviarlo
# o descargarlo suelto y funciona igual.
#
# Al ejecutarlo instala:
#   1. El programa en ~/.local/bin/enkripta.sh
#   2. Su icono
#   3. Un acceso directo en el MENÚ de aplicaciones (Accesorios) que abre
#      el asistente gráfico de Enkripta
#   4. Un acceso directo en el ESCRITORIO, listo para hacer doble clic
#   5. El tipo .cvault como tipo MIME propio, con Enkripta como programa
#      predeterminado (doble clic sobre un .cvault = abrir el menú del vault)
#   6. Dos acciones en el clic derecho de Nemo:
#        🔒 Cifrar con Enkripta      (sobre cualquier archivo o carpeta)
#        🔓 Abrir vault Enkripta     (sobre archivos .cvault)
#
# Uso:
#   ./enkripta-instalador.sh                 instala/actualiza todo lo anterior
#   ./enkripta-instalador.sh --desinstalar   quita todo lo anterior
#
# No hace falta sudo: todo se instala en tu carpeta personal, así que no
# afecta a otros usuarios del equipo ni requiere permisos de administrador.

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

if [ -t 1 ]; then
    C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'; C_BLUE=$'\033[34m'; C_RESET=$'\033[0m'
else
    C_GREEN=""; C_YELLOW=""; C_RED=""; C_BLUE=""; C_RESET=""
fi
ok()   { printf '%s✔ %s%s\n' "$C_GREEN" "$1" "$C_RESET"; }
warn() { printf '%s⚠ %s%s\n' "$C_YELLOW" "$1" "$C_RESET"; }
info() { printf '%sℹ %s%s\n' "$C_BLUE" "$1" "$C_RESET"; }
fail() { printf '%s✘ %s%s\n' "$C_RED" "$1" "$C_RESET" >&2; exit 1; }

# Carpeta de Escritorio del usuario: usa xdg-user-dir si existe (la forma
# fiable de saber cómo se llama en el idioma del sistema: "Desktop",
# "Escritorio", etc.), y si no, prueba las rutas más habituales.
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
    if command -v update-mime-database >/dev/null 2>&1; then
        update-mime-database "$HOME/.local/share/mime" >/dev/null 2>&1 || true
    fi
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
    fi
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
    fi
}

do_uninstall() {
    info "Quitando la integración de Enkripta..."
    rm -f "$DESKTOP_FILE" "$DESKTOP_SHORTCUT" "$MIME_XML" "$ACTION_ENCRYPT" "$ACTION_OPEN" \
          "$DEST_ICON_APP" "$DEST_ICON_MIME"
    # Quita también la asociación "application/x-cvault=enkripta.desktop" de
    # mimeapps.list; si no, queda apuntando a un .desktop que ya no existe.
    local mimeapps="${XDG_CONFIG_HOME:-$HOME/.config}/mimeapps.list"
    [ -f "$mimeapps" ] && sed -i -E '/^application\/x-cvault=enkripta\.desktop;?$/d' "$mimeapps" 2>/dev/null || true
    # No borramos ~/.local/bin/enkripta.sh por defecto: puede que el usuario
    # lo esté usando también desde la terminal. Se avisa en vez de borrarlo.
    refresh_caches
    ok "Integración eliminada (menú, escritorio, clic derecho y asociación .cvault)."
    warn "El script $DEST_SCRIPT no se ha borrado. Bórralo a mano si ya no lo necesitas."
    [ -f "$HOME/.local/share/enkripta/master.verify" ] && warn "Tu contraseña maestra tampoco se ha borrado (sigue en ~/.local/share/enkripta/). Quítala a mano, o con 'enkripta.sh quitar-contrasena-maestra' antes de desinstalar, si ya no la quieres."
    info "Puede que tengas que cerrar sesión, o ejecutar 'nemo -q', para que Nemo lo note."
    exit 0
}

case "${1:-}" in
    --ayuda|--help|-h)
        cat <<EOF
Enkripta — instalador para Cinnamon/Nemo (Linux Mint)

Uso:
  $0                 instala o actualiza toda la integración
  $0 --desinstalar   quita del sistema lo instalado (no borra $DEST_SCRIPT)
  $0 --ayuda         muestra esta ayuda

No hace falta sudo: todo se instala en tu carpeta personal.
EOF
        exit 0 ;;
esac

# Esta comprobación va ANTES de --desinstalar y de la instalación normal (pero
# después de --ayuda, que es inofensiva): así "sudo ./enkripta-instalador.sh
# --desinstalar" también se bloquea, en vez de desinstalar usando el $HOME de
# root en lugar del usuario real.
[ "$(id -u)" -eq 0 ] && fail "No ejecutes este instalador con sudo/root: se instala en la carpeta personal de un usuario normal. Vuelve a lanzarlo como tu usuario habitual, sin sudo."

case "${1:-}" in
    --desinstalar|--uninstall) do_uninstall ;;
    "") : ;;
    *) fail "Opción no reconocida: '$1'. Usa '$0 --ayuda' para ver las opciones disponibles." ;;
esac

command -v zenity >/dev/null 2>&1 || warn "No tienes 'zenity' instalado todavía: los diálogos gráficos de Enkripta no funcionarán hasta que ejecutes: sudo apt install zenity"
command -v gpg >/dev/null 2>&1 || warn "No tienes 'gpg' instalado todavía: el cifrado no funcionará hasta que ejecutes: sudo apt install gnupg"

TMP_ICON=""
cleanup_tmp() {
    [ -n "$TMP_ICON" ] && rm -f "$TMP_ICON"
    return 0
}
trap cleanup_tmp EXIT

# ---------- 1. Programa principal (embebido en este mismo archivo) ----------

mkdir -p "$BIN_DIR"
cat > "$DEST_SCRIPT" <<'ENKRIPTA_SH_EOF'
#!/usr/bin/env bash
#
# Copyright (C) 2026 Filonux
#
# Licencia:
# Enkripta es software libre distribuido bajo los términos de la
# GNU General Public License versión 3 (GPLv3).
# Consulte el archivo LICENSE para obtener el texto completo de la licencia.
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

err() {
    if [ "$GUI" = "1" ] && command -v zenity >/dev/null 2>&1; then
        zenity --error --title="$APP_TITLE" --width=420 --window-icon="$APP_ICON" --no-markup --text="$1" 2>/dev/null || true
    else
        printf '%s❌ %b%s\n' "$C_RED" "$1" "$C_RESET" >&2
    fi
    exit 1
}

info() {
    if [ "$GUI" = "1" ] && command -v zenity >/dev/null 2>&1; then
        zenity --info --title="$APP_TITLE" --width=420 --window-icon="$APP_ICON" --no-markup --text="$1" 2>/dev/null || true
    else
        printf '%sℹ️  %b%s\n' "$C_BLUE" "$1" "$C_RESET"
    fi
}

ok_msg() {
    if [ "$GUI" = "1" ] && command -v notify-send >/dev/null 2>&1; then
        local body; printf -v body '%b' "$1"
        notify-send -i "$APP_ICON" "$APP_TITLE" "$body" || true
    elif [ "$GUI" = "1" ] && command -v zenity >/dev/null 2>&1; then
        zenity --info --title="$APP_TITLE" --width=420 --window-icon="$APP_ICON" --no-markup --text="✅ $1" 2>/dev/null || true
    else
        printf '%s✅ %b%s\n' "$C_GREEN" "$1" "$C_RESET"
    fi
}

ask_yesno() {
    local prompt="$1"
    if [ "$GUI" = "1" ] && command -v zenity >/dev/null 2>&1; then
        zenity --question --title="$APP_TITLE" --width=400 --window-icon="$APP_ICON" --no-markup \
            --ok-label="Sí" --cancel-label="No" --text="$prompt" 2>/dev/null
        return $?
    else
        local confirm rendered
        printf -v rendered '%b' "$prompt"
        read -rp "$rendered [s/N]: " confirm
        [[ "$confirm" =~ ^[sS]$ ]]
    fi
}

# Pregunta UNA SOLA VEZ por cada ejecución del script si el usuario quiere
# escribir las contraseñas EN TEXTO VISIBLE (para poder comprobar que no hay
# erratas) o de forma OCULTA con puntos/asteriscos (más seguro si alguien
# puede ver la pantalla, que es el comportamiento de siempre). La respuesta
# se guarda en SHOW_PW y se reutiliza para todos los campos de contraseña
# que se pidan durante esta misma operación (por ejemplo, tanto la actual
# como la nueva y su confirmación, en un cambio de contraseña), para no
# preguntar lo mismo una y otra vez.
#
# IMPORTANTE: cada cmd_* debe llamar a "ensure_show_pw_pref" ELLA MISMA, como
# sentencia normal (nunca dentro de "$(...)"), justo antes de pedir la
# primera contraseña. Igual que con mk_workdir/register_workdir más abajo:
# ask_password_once se invoca casi siempre como pass="$(ask_password_once ..)",
# y esa sustitución de comandos corre en una subshell, así que si SHOW_PW se
# fijara por primera vez ahí dentro, el valor se perdería al salir de la
# subshell y en el siguiente campo se volvería a preguntar (comprobado de
# forma empírica: sin esta llamada explícita previa, la pregunta reaparece en
# cada contraseña y descuadra la lectura). Fijarlo antes, en el shell
# principal, hace que las subshells posteriores ya lo hereden por el fork.
SHOW_PW=""
ensure_show_pw_pref() {
    [ -n "$SHOW_PW" ] && return 0
    if [ "$GUI" = "1" ] && command -v zenity >/dev/null 2>&1; then
        if zenity --question --title="$APP_TITLE" --width=440 --window-icon="$APP_ICON" --no-markup \
            --ok-label="👁️  Mostrarla mientras la escribo" --cancel-label="🔒 Mantenerla oculta" \
            --text="¿Cómo quieres escribir la contraseña en esta operación?\n\n👁️  Mostrarla: verás el texto tal cual lo escribes.\n🔒 Ocultarla: aparecerán puntos en su lugar (recomendado si alguien puede ver tu pantalla)." \
            2>/dev/null; then
            SHOW_PW=1
        else
            SHOW_PW=0
        fi
    else
        local resp
        read -rp "¿Quieres ver la contraseña en texto mientras la escribes, en vez de que quede oculta? [s/N]: " resp || true
        [[ "${resp:-}" =~ ^[sS]$ ]] && SHOW_PW=1 || SHOW_PW=0
    fi
}

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
        if [ "$SHOW_PW" = "1" ]; then
            zenity --entry --title="$APP_TITLE" --window-icon="$APP_ICON" --no-markup --text="$prompt" 2>/dev/null || true
        else
            zenity --password --title="$APP_TITLE" --window-icon="$APP_ICON" --no-markup --text="$prompt" 2>/dev/null || true
        fi
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
            [ "$intentos" -ge "$max_intentos" ] && err "No se ha podido obtener una contraseña (demasiados intentos vacíos). Operación cancelada."
            err_soft "La contraseña no puede estar vacía."
            continue
        fi
        if [ "${#p1}" -lt "$MIN_PW_LEN" ]; then
            intentos=$((intentos + 1))
            [ "$intentos" -ge "$max_intentos" ] && err "No se ha podido obtener una contraseña válida (demasiados intentos). Operación cancelada."
            err_soft "La contraseña debe tener al menos $MIN_PW_LEN caracteres."
            continue
        fi
        p2="$(ask_password_once "$prompt_confirm")"
        if [ "$p1" = "$p2" ]; then
            printf '%s' "$p1"
            return 0
        fi
        intentos=$((intentos + 1))
        [ "$intentos" -ge "$max_intentos" ] && err "No se ha podido confirmar la contraseña (demasiados intentos). Operación cancelada."
        err_soft "Las dos contraseñas que has escrito no coinciden. Vuelve a intentarlo desde el principio."
    done
}

err_soft() {
    if [ "$GUI" = "1" ] && command -v zenity >/dev/null 2>&1; then
        zenity --error --title="$APP_TITLE" --width=400 --window-icon="$APP_ICON" --no-markup --text="$1" 2>/dev/null || true
    else
        printf '%s⚠️  %b%s\n' "$C_YELLOW" "$1" "$C_RESET" >&2
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
        printf '%sℹ️  %b%s\n' "$C_BLUE" "$msg" "$C_RESET"
    fi
}

# Si "$1" (archivo o carpeta) pesa más que WARN_SIZE_BYTES, avisa de que la
# operación puede tardar. Es un best-effort: si du falla por lo que sea, no
# se avisa y ya está (nunca debe bloquear ni abortar la operación real).
maybe_warn_slow() {
    local path="$1" bytes human
    bytes="$(du -sb -- "$path" 2>/dev/null | cut -f1)" || return 0
    [ -n "$bytes" ] && [ "$bytes" -ge "$WARN_SIZE_BYTES" ] 2>/dev/null || return 0
    human="$(du -sh -- "$path" 2>/dev/null | cut -f1)"
    notice_slow "Esto puede tardar un poco (son unos ${human:-varios} de datos)…"
}

# Tamaño legible de un archivo (pensado para mostrar el peso del .cvault en
# los mensajes de éxito). Devuelve cadena vacía si no se puede calcular.
vault_size() {
    du -h -- "$1" 2>/dev/null | cut -f1
}

check_deps() {
    local bin
    for bin in gpg tar gzip gunzip shred base64 realpath; do
        command -v "$bin" >/dev/null 2>&1 || err "Falta el comando '$bin'. Instálalo con: sudo apt install $bin"
    done
}

# Cuando se invoca en modo gráfico (gui-encrypt / gui-menu, típicamente desde
# Nemo) pero falta zenity, los diálogos de contraseña quedarían esperando una
# entrada que nunca llega (no hay terminal), lo que puede colgar el proceso o
# hacerlo girar en un bucle rechazando contraseñas vacías sin parar. Si no hay
# zenity, avisamos como podamos y salimos limpiamente en vez de continuar.
require_gui_zenity() {
    if [ "$GUI" = "1" ] && ! command -v zenity >/dev/null 2>&1; then
        local msg="$APP_TITLE necesita 'zenity' para los diálogos gráficos. Instálalo con: sudo apt install zenity"
        if command -v notify-send >/dev/null 2>&1; then
            notify-send -i dialog-error "$APP_TITLE" "$msg" || true
        fi
        printf '❌ %s\n' "$msg" >&2
        exit 1
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
    local choice master_hint="no configurada"
    master_is_configured && master_hint="configurada"
    choice="$(zenity --list --title="$APP_TITLE" --width=460 --height=340 \
        --window-icon="$APP_ICON" --no-markup \
        --text="👋 ¿Qué quieres hacer?\n\n🔑 Contraseña maestra: $master_hint" \
        --radiolist --hide-header \
        --column="" --column="Acción" \
        TRUE  "🔒 Cifrar un archivo" \
        FALSE "🔒 Cifrar una carpeta" \
        FALSE "🔓 Abrir un vault .$EXT existente" \
        FALSE "🔑 Configurar contraseña maestra" \
        FALSE "🚫 Quitar contraseña maestra" \
        2>/dev/null)" || { info "Operación cancelada."; return 0; }

    case "$choice" in
        "🔒 Cifrar un archivo")
            local sel
            sel="$(zenity --file-selection --title="Elige el archivo a cifrar" \
                --window-icon="$APP_ICON" --filename="$HOME/" 2>/dev/null)" \
                || { info "Operación cancelada."; return 0; }
            cmd_encrypt "$sel"
            ;;
        "🔒 Cifrar una carpeta")
            local sel
            sel="$(zenity --file-selection --directory --title="Elige la carpeta a cifrar" \
                --window-icon="$APP_ICON" --filename="$HOME/" 2>/dev/null)" \
                || { info "Operación cancelada."; return 0; }
            cmd_encrypt "$sel"
            ;;
        "🔓 Abrir un vault .$EXT existente")
            local sel
            sel="$(zenity --file-selection --title="Elige el vault .$EXT a abrir" \
                --window-icon="$APP_ICON" --file-filter="Vaults de $APP_TITLE | *.$EXT" \
                --filename="$HOME/" 2>/dev/null)" \
                || { info "Operación cancelada."; return 0; }
            cmd_menu "$sel"
            ;;
        "🔑 Configurar contraseña maestra")
            cmd_master_set
            ;;
        "🚫 Quitar contraseña maestra")
            cmd_master_unset
            ;;
        *)
            info "Operación cancelada." ;;
    esac
}

# ---------- Núcleo criptográfico ----------

# Genera una clave maestra aleatoria de 256 bits, codificada en base64 (una línea).
gen_master_key() {
    head -c 32 /dev/urandom | base64 -w0
}

# Cifra el stdin con la contraseña dada, escribe el resultado en $2.
gpg_enc() {
    local pass="$1" outfile="$2"
    gpg --batch --yes --no-tty --pinentry-mode loopback \
        --symmetric --cipher-algo "$CIPHER" --digest-algo "$DIGEST" \
        --s2k-mode "$S2K_MODE" --s2k-count "$S2K_COUNT" --s2k-digest-algo "$DIGEST" \
        --no-symkey-cache \
        --passphrase-fd 3 -o "$outfile" 3<<<"$pass"
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
        info "Operación cancelada."
        return 1
    fi
    if ! try_unlock "$workdir" "$pass"; then
        cleanup_workdir "$workdir"
        err "Contraseña incorrecta."
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
    tar -cf "$tmp_out" -C "$workdir" meta data.gpg "${slots[@]}"
    mv -f "$tmp_out" "$vault"
}

# Extrae un .cvault a un directorio temporal y valida que tenga la forma esperada.
extract_container() {
    local vault="$1" workdir="$2"
    # Se valida la lista de miembros ANTES de extraer: solo se permiten
    # "meta", "data.gpg" y "slotN.gpg" sueltos (sin rutas). Así, un .cvault
    # manipulado a mano no puede usar '../', rutas absolutas o symlinks en
    # el propio contenedor para escribir fuera de $workdir al abrirlo.
    local members
    members="$(tar -tf "$vault" 2>/dev/null)" || err "'$vault' no es un vault de $APP_TITLE válido."
    printf '%s\n' "$members" | grep -qvE '^(meta|data\.gpg|slot[0-9]+\.gpg)$' \
        && err "'$vault' no es un vault de $APP_TITLE válido."
    tar -xf "$vault" -C "$workdir" 2>/dev/null || err "'$vault' no es un vault de $APP_TITLE válido."
    [ -f "$workdir/meta" ] && [ -f "$workdir/data.gpg" ] && [ -f "$workdir/slot1.gpg" ] \
        || err "'$vault' no es un vault de $APP_TITLE válido."
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
            err "'$vault' no es un vault de $APP_TITLE válido (nombre interno no permitido)."
            ;;
    esac
    case "$META_TYPE" in
        file|dir) : ;;
        *)
            err "'$vault' no es un vault de $APP_TITLE válido (tipo de contenido no permitido)."
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
    local d
    for d in "${_ACTIVE_WORKDIRS[@]}"; do
        [ -d "$d" ] && rm -rf "$d"
    done
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
            err "No se puede cifrar/actualizar '$path' directamente: apuntaría a todo el directorio actual (o al padre) y podría acabar borrándolo entero. Indica la ruta completa, por ejemplo: '$(realpath -- "$path")'."
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
        pass="$(ask_password_once "🔑 Escribe tu contraseña MAESTRA para cifrar '$base'")"
        if [ -z "$pass" ]; then
            intentos=$((intentos + 1))
            [ "$intentos" -ge "$max_intentos" ] && err "No se ha podido obtener la contraseña maestra (demasiados intentos vacíos). Operación cancelada."
            err_soft "La contraseña no puede estar vacía."
            continue
        fi
        if master_check "$pass"; then
            printf '%s' "$pass"
            return 0
        fi
        intentos=$((intentos + 1))
        [ "$intentos" -ge "$max_intentos" ] && err "La contraseña maestra no coincide (demasiados intentos). Operación cancelada."
        err_soft "Esa no es tu contraseña maestra. Vuelve a intentarlo."
    done
}

cmd_encrypt() {
    local path; path="$(normalize_path "${1%/}")"
    [ -e "$path" ] || err "'$path' no existe."
    reject_dot_path "$path"
    if [ -L "$path" ]; then
        err "'$path' es un enlace simbólico, no el archivo/carpeta real.\nPara evitar sorpresas (un enlace a carpeta no se cifra correctamente, y borrar\nel original de forma segura afectaría al archivo real, no al enlace),\nseñala directamente la ruta real: '$(readlink -f -- "$path")'"
    fi
    case "$path" in
        *.$EXT) err "'$path' ya es un vault de $APP_TITLE. Ábrelo con doble clic o usa 'gui-menu' en lugar de cifrarlo de nuevo." ;;
    esac

    local parent base type vault
    base="$(basename "$path")"
    parent="$(dirname "$path")"
    vault="${parent}/${base}.${EXT}"
    [ -d "$path" ] && type="dir" || type="file"

    if [ -e "$vault" ]; then
        if ask_yesno "Ya existe un vault para '$base' ('$base.$EXT').\n\n¿Quieres ACTUALIZARLO manteniendo las mismas contraseñas?\n\n(Si eliges 'No' se te ofrecerá crear uno nuevo desde cero, perdiendo las contraseñas antiguas)"; then
            cmd_update "$path"
            return
        fi
        if ! ask_yesno "¿Seguro que quieres crear un vault NUEVO y sobrescribir '$base.$EXT'?\nLas contraseñas antiguas dejarán de servir."; then
            info "Operación cancelada."
            return
        fi
        [ -d "$vault" ] && err "'$vault' es una carpeta, no un archivo; bórrala o renómbrala a mano antes de continuar."
        rm -f "$vault"
    fi

    ensure_show_pw_pref
    local pw1
    if master_is_configured; then
        pw1="$(ask_master_password_for_new_vault "$base")"
    else
        pw1="$(ask_new_password \
            "🆕 Paso 1 de 2 — Crea la contraseña PRINCIPAL para '$base'" \
            "🔁 Paso 2 de 2 — Repite la contraseña PRINCIPAL para confirmarla")"
    fi

    local passwords=("$pw1")
    if ask_yesno "¿Quieres añadir ahora una segunda contraseña alternativa?\n(Cualquiera de las dos podrá usarse para descifrar)"; then
        local pw2
        pw2="$(ask_new_password \
            "🆕 Paso 1 de 2 — Crea la SEGUNDA contraseña (alternativa) para '$base'" \
            "🔁 Paso 2 de 2 — Repite la SEGUNDA contraseña para confirmarla")"
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
    unset master_key pw1 pw2 pw passwords

    assemble_container "$workdir" "$vault"
    cleanup_workdir "$workdir"
    local size; size="$(vault_size "$vault")"
    ok_msg "'$base' cifrado correctamente en '$base.$EXT' (${size:+$size, }$pwcount contraseña(s))."

    if ask_yesno "¿Quieres eliminar de forma segura el original '$base'? Esto puede tardar según el tamaño."; then
        if [ "$type" = "dir" ]; then
            find "$path" -type f -exec shred -u -z -n 3 -- {} \;
            rm -rf "$path"
        else
            shred -u -z -n 3 -- "$path"
        fi
        info "Original eliminado de forma segura."
    fi
}

cmd_decrypt() {
    local vault out_parent target_path
    vault="$(normalize_path "$1")"
    [ -f "$vault" ] || err "'$vault' no existe."
    out_parent="$(dirname "$vault")"

    local workdir
    workdir="$(mk_workdir)"
    register_workdir "$workdir"
    extract_container "$vault" "$workdir"
    read_meta "$workdir" "$vault"

    ensure_show_pw_pref
    unlock_or_cancel "$workdir" "🔓 Escribe la contraseña de '$(basename "$vault")' para descifrarlo" || return

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
            err "Ruta de destino no válida para '$vault'."
            ;;
    esac

    if [ -e "$target_path" ]; then
        cleanup_workdir "$workdir"
        err "Ya existe '$target_path'. Muévelo o bórralo antes de descifrar."
    fi

    local size; size="$(vault_size "$vault")"
    maybe_warn_slow "$vault"
    if [ "$META_TYPE" = "dir" ]; then
        # --one-top-level fuerza a que TODO el contenido del tar quede dentro
        # de una única carpeta con el nombre esperado (META_NAME, ya validado),
        # sin importar qué nombres de miembro traiga el archivo tar interno.
        gpg_dec "$FOUND_KEY" "$workdir/data.gpg" | gunzip -c \
            | tar -x --one-top-level="$META_NAME" -C "$out_parent"
    else
        gpg_dec "$FOUND_KEY" "$workdir/data.gpg" | gunzip -c > "$target_path"
    fi
    unset FOUND_KEY
    cleanup_workdir "$workdir"

    ok_msg "'$META_NAME' descifrado correctamente${size:+ ($size)} en:\n$target_path"

    if [ "$GUI" = "1" ] && command -v xdg-open >/dev/null 2>&1; then
        if ask_yesno "¿Abrir '$META_NAME' ahora?"; then
            xdg-open "$target_path" >/dev/null 2>&1 &
        fi
    fi
}

cmd_update() {
    local path; path="$(normalize_path "${1%/}")"
    [ -e "$path" ] || err "'$path' no existe."
    case "$path" in
        *.$EXT) err "'$path' ya es un vault de $APP_TITLE; indica la carpeta o archivo ORIGINAL, no el .$EXT." ;;
    esac
    reject_dot_path "$path"
    if [ -L "$path" ]; then
        err "'$path' es un enlace simbólico, no el archivo/carpeta real.\nSeñala directamente la ruta real: '$(readlink -f -- "$path")'"
    fi
    local base parent vault
    base="$(basename "$path")"
    parent="$(dirname "$path")"
    vault="${parent}/${base}.${EXT}"
    [ -f "$vault" ] || err "No se encontró un vault correspondiente ('$base.$EXT')."

    local workdir
    workdir="$(mk_workdir)"
    register_workdir "$workdir"
    extract_container "$vault" "$workdir"

    ensure_show_pw_pref
    unlock_or_cancel "$workdir" "🔑 Escribe CUALQUIERA de las contraseñas ya válidas de '$base.$EXT' para autorizar la actualización" || return

    local type
    [ -d "$path" ] && type="dir" || type="file"
    printf 'TYPE=%s\nNAME=%s\n' "$type" "$base" > "$workdir/meta"
    rm -f "$workdir/data.gpg"
    maybe_warn_slow "$path"
    if [ "$type" = "dir" ]; then
        tar -cf - -C "$parent" "$base" | gzip -c | gpg_enc "$FOUND_KEY" "$workdir/data.gpg"
    else
        gzip -c "$path" | gpg_enc "$FOUND_KEY" "$workdir/data.gpg"
    fi
    unset FOUND_KEY

    assemble_container "$workdir" "$vault"
    cleanup_workdir "$workdir"
    local size; size="$(vault_size "$vault")"
    ok_msg "Vault '$base.$EXT' actualizado${size:+ ($size)}. Las contraseñas no han cambiado."

    if ask_yesno "¿Eliminar de forma segura la copia sin cifrar '$base'?"; then
        if [ "$type" = "dir" ]; then
            find "$path" -type f -exec shred -u -z -n 3 -- {} \;
            rm -rf "$path"
        else
            shred -u -z -n 3 -- "$path"
        fi
    fi
}

cmd_change_password() {
    local vault; vault="$(normalize_path "$1")"
    [ -f "$vault" ] || err "'$vault' no existe."
    local workdir
    workdir="$(mk_workdir)"
    register_workdir "$workdir"
    extract_container "$vault" "$workdir"

    ensure_show_pw_pref
    unlock_or_cancel "$workdir" "🔑 Paso 1 de 3 — Escribe la contraseña ACTUAL que quieres cambiar" || return
    local slot="$FOUND_SLOT" key="$FOUND_KEY"
    unset FOUND_KEY

    local newpw
    newpw="$(ask_new_password \
        "🆕 Paso 2 de 3 — Escribe la contraseña NUEVA (sustituirá a la actual)" \
        "🔁 Paso 3 de 3 — Repite la contraseña NUEVA para confirmarla")"
    printf '%s' "$key" | gpg_enc "$newpw" "$workdir/slot${slot}.gpg"
    unset key newpw

    assemble_container "$workdir" "$vault"
    cleanup_workdir "$workdir"
    ok_msg "Contraseña actualizada correctamente."
}

cmd_add_password() {
    local vault; vault="$(normalize_path "$1")"
    [ -f "$vault" ] || err "'$vault' no existe."
    local workdir
    workdir="$(mk_workdir)"
    register_workdir "$workdir"
    extract_container "$vault" "$workdir"

    ensure_show_pw_pref
    unlock_or_cancel "$workdir" "🔑 Paso 1 de 3 — Escribe una contraseña YA VÁLIDA de este vault, para autorizar el cambio" || return
    local key="$FOUND_KEY"
    unset FOUND_KEY

    local n newpw
    n=$(( $(count_slots "$workdir") + 1 ))
    newpw="$(ask_new_password \
        "🆕 Paso 2 de 3 — Escribe la contraseña NUEVA que quieres añadir (alternativa a las demás)" \
        "🔁 Paso 3 de 3 — Repite la contraseña NUEVA para confirmarla")"
    printf '%s' "$key" | gpg_enc "$newpw" "$workdir/slot${n}.gpg"
    unset key newpw

    assemble_container "$workdir" "$vault"
    cleanup_workdir "$workdir"
    ok_msg "Nueva contraseña añadida. Ahora hay $n contraseña(s) válidas para este vault."
}

cmd_remove_password() {
    local vault; vault="$(normalize_path "$1")"
    [ -f "$vault" ] || err "'$vault' no existe."
    local workdir
    workdir="$(mk_workdir)"
    register_workdir "$workdir"
    extract_container "$vault" "$workdir"

    local total
    total="$(count_slots "$workdir")"
    if [ "$total" -le 1 ]; then
        cleanup_workdir "$workdir"
        err "Este vault solo tiene una contraseña; no se puede eliminar la única forma de acceso."
    fi

    ensure_show_pw_pref
    unlock_or_cancel "$workdir" "🗑️  Escribe la contraseña que quieres ELIMINAR de este vault" || return
    local remove_slot="$FOUND_SLOT"
    unset FOUND_KEY

    if ! ask_yesno "Se eliminará esa contraseña; el resto seguirán funcionando. ¿Continuar?"; then
        cleanup_workdir "$workdir"
        info "Operación cancelada."
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

    ok_msg "Contraseña eliminada. Quedan $kept contraseña(s) válida(s) para este vault."
}

# Configura (o reemplaza) la contraseña maestra: a partir de ahora, cifrar
# algo nuevo con cmd_encrypt la pedirá una sola vez en vez de obligar a crear
# y repetir una contraseña distinta para cada vault. No afecta a los vaults
# que ya existen (sus contraseñas no cambian).
cmd_master_set() {
    if master_is_configured; then
        ask_yesno "Ya tienes una contraseña maestra configurada.\n¿Quieres reemplazarla por una nueva?\n\n(Los vaults que ya creaste no cambian: esto solo afecta a lo que cifres a partir de ahora)" \
            || { info "Operación cancelada."; return; }
    fi
    ensure_show_pw_pref
    local p1
    p1="$(ask_new_password \
        "🔑 Paso 1 de 2 — Escribe la nueva contraseña MAESTRA" \
        "🔁 Paso 2 de 2 — Repite la contraseña MAESTRA para confirmarla")"
    mkdir -p "$ENKRIPTA_DATA_DIR"
    chmod 700 "$ENKRIPTA_DATA_DIR"
    printf '%s' "$MASTER_MAGIC" | gpg_enc "$p1" "$MASTER_VERIFY_FILE"
    chmod 600 "$MASTER_VERIFY_FILE"
    unset p1
    ok_msg "Contraseña maestra configurada.\n\nA partir de ahora, al cifrar un archivo o carpeta nuevos solo se te pedirá escribirla una vez (no hace falta inventar ni repetir una distinta cada vez)."
}

# Quita la contraseña maestra configurada. Los vaults ya creados no se ven
# afectados: vuelven a poder abrirse con la contraseña que tuvieran, igual
# que siempre. Solo cambia lo que se cifre a partir de ahora.
cmd_master_unset() {
    if ! master_is_configured; then
        info "No tienes ninguna contraseña maestra configurada."
        return
    fi
    ask_yesno "¿Seguro que quieres quitar la contraseña maestra?\n\nLos vaults que ya creaste no cambian. Al cifrar algo nuevo a partir de ahora, se te volverá a pedir crear una contraseña para cada vault." \
        || { info "Operación cancelada."; return; }
    rm -f "$MASTER_VERIFY_FILE"
    ok_msg "Contraseña maestra eliminada."
}

# Menú interactivo para un vault ya existente (usado al hacer doble clic o desde Nemo).
cmd_menu() {
    local vault; vault="$(normalize_path "$1")"
    [ -f "$vault" ] || err "'$vault' no existe."
    local base
    base="$(basename "$vault")"

    local nslots slots_hint=""
    nslots="$(count_slots_in_vault "$vault")"
    case "$nslots" in
        ''|0) : ;;
        1) slots_hint=" (1 contraseña configurada)" ;;
        *) slots_hint=" ($nslots contraseñas configuradas)" ;;
    esac

    local choice
    if [ "$GUI" = "1" ] && command -v zenity >/dev/null 2>&1; then
        choice="$(zenity --list --title="$APP_TITLE" --width=460 --height=280 \
            --window-icon="$APP_ICON" --no-markup \
            --text="¿Qué quieres hacer con '$base'?$slots_hint" \
            --radiolist --hide-header \
            --column="" --column="Acción" \
            TRUE  "🔓 Descifrar" \
            FALSE "✏️  Cambiar una contraseña" \
            FALSE "➕ Añadir otra contraseña" \
            FALSE "➖ Eliminar una contraseña" \
            2>/dev/null)" || { info "Operación cancelada."; return; }
    else
        echo "¿Qué quieres hacer con '$base'?$slots_hint"
        select choice in "🔓 Descifrar" "✏️  Cambiar una contraseña" "➕ Añadir otra contraseña" "➖ Eliminar una contraseña" "Cancelar"; do
            break
        done
        if [ "$choice" = "Cancelar" ] || [ -z "${choice:-}" ]; then
            info "Operación cancelada."
            return
        fi
    fi

    case "$choice" in
        "🔓 Descifrar") cmd_decrypt "$vault" ;;
        "✏️  Cambiar una contraseña") cmd_change_password "$vault" ;;
        "➕ Añadir otra contraseña") cmd_add_password "$vault" ;;
        "➖ Eliminar una contraseña") cmd_remove_password "$vault" ;;
        *) info "Operación cancelada." ;;
    esac
}

usage() {
    local code="${1:-1}"
    local is_help="${2:-0}"
    local body
    body="$(cat <<EOF
$APP_TITLE — cifrado simétrico de carpetas y archivos (GPG/AES-256), con
soporte para varias contraseñas independientes por vault y una contraseña
maestra opcional para no tener que crear una distinta cada vez.

Uso:
  $0 cifrar <carpeta_o_archivo>
  $0 cifrar_facil <ruta> [...]         # cifra o abre el menú según corresponda
  $0 <vault.$EXT>                      # abre el menú (descifrar / gestionar)
  $0 descifrar <vault.$EXT>
  $0 actualizar <carpeta_o_archivo>    # recifra el contenido, mismas contraseñas
  $0 cambiar-contrasena <vault.$EXT>
  $0 anadir-contrasena <vault.$EXT>
  $0 eliminar-contrasena <vault.$EXT>
  $0 contrasena-maestra                # configura/reemplaza la contraseña maestra
  $0 quitar-contrasena-maestra         # quita la contraseña maestra
  $0 --version                         # muestra la versión instalada
  $0 --help                            # muestra esta ayuda

Variantes gráficas (zenity), usadas por accesos directos y por Nemo:
  $0 gui                                # lanzador gráfico, pregunta qué hacer
  $0 gui <ruta_o_vault> [...]
  $0 gui-encrypt <ruta> [...]
  $0 gui-menu <vault.$EXT> [...]

Ejemplos:
  $0 cifrar ~/Documentos/secretos
  $0 secretos.$EXT
EOF
)"
    # Si esto se ha invocado sin argumentos desde un lanzador gráfico o desde
    # Nemo (no hay terminal visible detrás), un simple "print + exit 1" es
    # invisible para quien lo usa: solo vería "el script falló" sin más
    # explicación. En ese caso mostramos un diálogo en vez de morir en
    # silencio. Para un "--help" explícito no ofrecemos el asistente (el
    # usuario ya sabe lo que quiere: ver la ayuda), solo se la mostramos.
    if [ ! -t 1 ] || [ "$GUI" = "1" ]; then
        if command -v zenity >/dev/null 2>&1; then
            GUI=1
            if [ "$is_help" = "1" ]; then
                zenity --text-info --title="$APP_TITLE — Ayuda" --width=560 --height=420 \
                    --window-icon="$APP_ICON" --font="Monospace" 2>/dev/null <<<"$body" || true
                exit "$code"
            fi
            if zenity --question --title="$APP_TITLE" --width=420 --window-icon="$APP_ICON" --no-markup \
                --ok-label="Abrir el asistente" --cancel-label="Cerrar" \
                --text="$APP_TITLE se ha abierto sin indicarle qué archivo o carpeta usar.\n\n¿Quieres abrir el asistente para elegir qué hacer?" 2>/dev/null; then
                cmd_gui_picker
                exit 0
            fi
            exit "$code"
        elif command -v notify-send >/dev/null 2>&1; then
            notify-send -i dialog-error "$APP_TITLE" "Se necesita indicar un archivo, carpeta o vault .$EXT. Instala 'zenity' para el asistente gráfico." || true
        fi
    fi
    printf '%s\n' "$body"
    exit "$code"
}

# ---------- Main ----------

# Adelanto de GUI: si el subcomando es gráfico, check_deps debe poder avisar
# con un diálogo (o notify-send) en vez de un stderr que nadie va a ver al
# lanzarse desde Nemo/menú/escritorio, sin terminal detrás.
case "${1:-}" in gui|gui-*) GUI=1 ;; esac
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
chmod +x "$DEST_SCRIPT"
ok "Script principal instalado en $DEST_SCRIPT"

case ":$PATH:" in
    *":$BIN_DIR:"*) : ;;
    *) warn "$BIN_DIR no está en tu PATH. Para usar 'enkripta.sh' desde cualquier terminal, añade esta línea a tu ~/.bashrc:
    export PATH=\"\$HOME/.local/bin:\$PATH\"
    (Esto no afecta al escritorio, al menú ni al clic derecho, que ya funcionan sin esto.)" ;;
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
cp -f "$TMP_ICON" "$DEST_ICON_APP"
cp -f "$TMP_ICON" "$DEST_ICON_MIME"
rm -f "$TMP_ICON"; TMP_ICON=""
ok "Icono instalado."

# ---------- 3. Lanzador de menú (.desktop) ----------

mkdir -p "$APPS_DIR"
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Enkripta
GenericName=Cifrado de carpetas y archivos
Comment=Cifra y descifra carpetas o archivos con contraseña (AES-256)
Exec="$DEST_SCRIPT" gui %F
Icon=$DEST_ICON_APP
Terminal=false
Categories=Utility;Security;
MimeType=application/x-cvault;
Keywords=cifrar;cifrado;encriptar;contraseña;seguridad;vault;
StartupNotify=false
EOF
chmod +x "$DESKTOP_FILE"
ok "Acceso creado en el menú de aplicaciones (búscalo como «Enkripta»)."

# ---------- 4. Tipo MIME .cvault + asociación por defecto ----------

mkdir -p "$MIME_DIR"
cat > "$MIME_XML" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="application/x-cvault">
    <comment>Vault cifrado de Enkripta</comment>
    <comment xml:lang="es">Vault cifrado de Enkripta</comment>
    <glob pattern="*.cvault"/>
    <icon name="application-x-cvault"/>
  </mime-type>
</mime-info>
EOF
ok "Tipo de archivo .cvault registrado."

refresh_caches

if command -v xdg-mime >/dev/null 2>&1; then
    xdg-mime default enkripta.desktop application/x-cvault 2>/dev/null || true
    ok "Enkripta establecido como programa predeterminado para archivos .cvault (doble clic = abrir el vault)."
else
    warn "No tienes 'xdg-mime'; asocia manualmente los .cvault con Enkripta desde Nemo: clic derecho > Abrir con > Otra aplicación."
fi

# ---------- 5. Acciones de clic derecho en Nemo ----------

mkdir -p "$NEMO_ACTIONS_DIR"

cat > "$ACTION_ENCRYPT" <<EOF
[Nemo Action]
Active=true
Name=🔒 Cifrar con Enkripta
Comment=Cifra el archivo o carpeta seleccionada con contraseña (AES-256)
Exec=$DEST_SCRIPT gui-encrypt %F
Icon-Name=$DEST_ICON_APP
Selection=notnone
Extensions=any;
EOF

cat > "$ACTION_OPEN" <<EOF
[Nemo Action]
Active=true
Name=🔓 Abrir vault Enkripta
Comment=Descifra o gestiona las contraseñas de este vault
Exec=$DEST_SCRIPT gui-menu %F
Icon-Name=$DEST_ICON_APP
Selection=notnone
Extensions=cvault;
EOF

ok "Acciones de clic derecho instaladas:
    · «🔒 Cifrar con Enkripta» — sobre cualquier archivo o carpeta
    · «🔓 Abrir vault Enkripta» — sobre archivos .cvault"

# ---------- 6. Acceso directo en el Escritorio ----------

mkdir -p "$DESKTOP_DIR"
cat > "$DESKTOP_SHORTCUT" <<EOF
[Desktop Entry]
Type=Application
Name=Enkripta
GenericName=Cifrado de carpetas y archivos
Comment=Cifra y descifra carpetas o archivos con contraseña (AES-256)
Exec="$DEST_SCRIPT" gui %F
Icon=$DEST_ICON_APP
Terminal=false
Categories=Utility;Security;
MimeType=application/x-cvault;
StartupNotify=false
EOF
chmod +x "$DESKTOP_SHORTCUT"
# Nemo/Nautilus marcan como "no confiable" cualquier .desktop nuevo en el
# Escritorio hasta que se autoriza explícitamente. Lo autorizamos aquí para
# que el icono funcione con un doble clic desde el primer momento.
if command -v gio >/dev/null 2>&1; then
    gio set "$DESKTOP_SHORTCUT" "metadata::trusted" true 2>/dev/null || true
fi
ok "Acceso directo creado en el escritorio ($DESKTOP_DIR)."

# ---------- Reiniciar Nemo para que lo note ya mismo ----------

if command -v nemo >/dev/null 2>&1; then
    nemo -q >/dev/null 2>&1 || true
    info "Nemo se ha reiniciado para aplicar los cambios (si tenías ventanas abiertas, ábrelas de nuevo)."
fi

echo
ok "¡Listo! Enkripta ya está integrado en Cinnamon:"
echo "    · Escritorio → icono de Enkripta (doble clic abre el asistente gráfico)"
echo "    · Menú de aplicaciones → Enkripta"
echo "    · Clic derecho sobre un archivo/carpeta → Cifrar con Enkripta"
echo "    · Doble clic sobre un .cvault → se abre el menú de descifrar/gestionar"
echo "    · Contraseña maestra opcional → abre Enkripta sin argumentos y elige «🔑 Configurar contraseña maestra»"
echo
if ! command -v zenity >/dev/null 2>&1; then
    warn "Recuerda instalar zenity para que los diálogos gráficos funcionen: sudo apt install zenity"
fi
warn "Si el icono del escritorio aparece con un candado o pide 'confiar' la primera vez, haz clic derecho sobre él > 'Permitir lanzamiento' (o pulsa dos veces y confirma)."
