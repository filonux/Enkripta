<img src="assets/icon/enkripta.svg" width="140" align="right" alt="Icono de Enkripta">

# Enkripta

Enkripta cifra carpetas y archivos en Linux Mint (Cinnamon/Nemo) con AES-256, y hace que parezca parte del propio sistema: doble clic en el escritorio, botón derecho en Nemo, icono propio para los archivos cifrados. Todo se instala con un único script, sin dependencias raras y sin tocar nada fuera de tu carpeta personal (no hace falta `sudo`).

> 🇪🇸 La documentación principal está ahora en inglés: [English](README.md).

## Novedades

**🌐 Interfaz en inglés, con el español incluido**

- Todo el programa está disponible en inglés y en español: instalador, diálogos, menús, salida de terminal y las acciones de clic derecho de Nemo. Sigue el idioma de tu sistema (`es*` → español, cualquier otro → inglés) y recuerda tu elección.
- Cámbialo cuando quieras con `enkripta.sh -l`, con `L)` en el menú de terminal o con **Cambiar idioma** en el menú gráfico.
- Los comandos tienen ahora nombres en inglés (`encrypt`, `decrypt`, `change-password`...). Los de siempre en español (`cifrar`, `descifrar`...) siguen funcionando, así que tus scripts no se rompen.
- El idioma solo cambia el texto que ves: cambiarlo nunca modifica un vault, y un vault creado en un idioma se abre en el otro.

**🛡️ Más robusto**

- **Un fallo no te cuesta datos.** Una contraseña incorrecta es inofensiva, y un vault corrupto no puede dejar un archivo a medias.
- **Se rechazan los vaults hostiles.** Miembros inesperados o enlaces simbólicos, huecos de contraseña mal formados y path traversal en los metadatos; y se rechazan las carpetas de origen inseguras antes de cifrar.
- **Cambiar contraseñas es seguro.** Cambiar o eliminar una contraseña sustituye solo su hueco (de forma atómica) y nunca toca los datos cifrados.
- **Las rutas raras funcionan.** Espacios, comillas, caracteres de shell y Unicode en los nombres, incluso si tu `$HOME` tiene espacios.
- **Instalación y desinstalación más limpias.** El instalador se niega a ejecutarse con `sudo`, puedes volver a lanzarlo sin riesgo, y al desinstalar respeta tu llavero GPG y tu carpeta de Escritorio.
- **Probado contra el abuso.** Seis baterías automáticas, una de las cuales reintroduce fallos conocidos para demostrar que las pruebas los detectan. Ver [Pruebas](#pruebas).

## Capturas

<img width="459" height="421" alt="Enkripta-menu-es" src="https://github.com/user-attachments/assets/9890ab04-2f46-4a1f-8af7-759f2a0aefb4" />
<img width="364" height="276" alt="confi-pass-es" src="https://github.com/user-attachments/assets/395f5aa1-eed3-4aaa-a3ad-3b06b8fc1de4" />
<img width="364" height="276" alt="confi-pass-es" src="https://github.com/user-attachments/assets/e0ff06c8-2a68-46bd-83b2-5733edc7181b" />
<img width="471" height="342" alt="nemo-options-es" src="https://github.com/user-attachments/assets/2c857eff-08f3-4207-81fe-a748b500cb46" />

## Instalación por terminal o descarga del ZIP

```bash
git clone https://github.com/filonux/Enkripta.git
cd Enkripta
chmod +x script/enkripta-instalador.sh
./script/enkripta-instalador.sh
```

Eso instala en tu carpeta personal (`~/.local/...`):

- El programa, en `~/.local/bin/enkripta.sh`.
- Su icono.
- Un acceso directo en el **menú de aplicaciones** (abre el asistente gráfico).
- Un acceso directo en el **escritorio**, listo para doble clic.
- El tipo de archivo `.cvault`, con Enkripta como aplicación predeterminada para abrirlo.
- Dos acciones en el **clic derecho de Nemo**: `🔒 Cifrar con Enkripta` y `🔓 Abrir vault Enkripta` (en el idioma de Enkripta, ver [Idioma](#idioma)).

### Opcional: instalar con Scriptya

[Scriptya](https://github.com/filonux/Scriptya), un menú para tus scripts, puede lanzar el instalador por ti: copia `script/enkripta-instalador.sh` (es autosuficiente) a tu carpeta de scripts y ejecútalo desde el menú de Scriptya. Lanzado así, solo instala (o actualiza) Enkripta; para desinstalar, mira [Desinstalar](#desinstalar).

La opción **Cambiar Icono** de Scriptya también permite sustituir el icono de Enkripta por cualquiera de los alternativos de [`assets/icon/`](assets/icon/); por eso hay varios. Si vuelves a ejecutar el instalador, se restaura el icono por defecto.

### Desinstalar

```bash
./script/enkripta-instalador.sh --desinstalar
```

Esto quita todo lo que Enkripta instaló: los accesos, el menú, la asociación `.cvault`, las acciones de Nemo y el propio script `~/.local/bin/enkripta.sh`, sin dejar rastro. Tus archivos `.cvault` nunca se tocan.

Dos cosas se tratan con cuidado a propósito, porque no son de Enkripta: `~/.gnupg` (se conserva si ya existía o contiene claves o ajustes tuyos; solo se borra si sigue siendo el llavero recién creado y vacío que GPG generó en su primer uso) y tu carpeta de Escritorio (se borra el acceso directo `enkripta.desktop` de dentro, nunca la carpeta). Tampoco se limpia el historial de "archivos recientes" de GTK/Nemo, que puede conservar rutas a `.cvault` que hayas abierto; para borrarlo, hazlo desde Nemo o elimina `~/.local/share/recently-used.xbel`.

### Requisitos

Para instalar y usar Enkripta: `gpg`, `tar`, `gzip`, `shred`, `base64` y `realpath`. Todos vienen de serie en Linux Mint. Opcional pero recomendado: `zenity` (los diálogos gráficos) y `notify-send` (avisos de escritorio). Si te falta `zenity`, el instalador te avisa y te da el comando exacto para instalarlo.

## Uso

### Desde el escritorio o Nemo

- Clic derecho sobre cualquier archivo o carpeta → **🔒 Cifrar con Enkripta**.
- Doble clic sobre un `.cvault` → se abre un menú: descifrar, cambiar contraseña, añadir contraseña o eliminar contraseña.
- Icono en el menú de aplicaciones → abre un asistente que pregunta qué quieres hacer (cifrar un archivo, una carpeta, o abrir un vault existente).

### Desde la terminal

Si añades `~/.local/bin` a tu `PATH` (el instalador te avisa si no lo está), puedes usar:

| Comando | Qué hace |
|---|---|
| `enkripta.sh cifrar <ruta>` | Cifra un archivo o carpeta y crea el `.cvault` |
| `enkripta.sh cifrar_facil <ruta>` | Detecta automáticamente si hay que cifrar o abrir el vault |
| `enkripta.sh <vault.cvault>` | Abre el menú del vault (descifrar / gestionar contraseñas) |
| `enkripta.sh descifrar <vault.cvault>` | Descifra un vault |
| `enkripta.sh actualizar <ruta>` | Vuelve a cifrar el contenido con las mismas contraseñas |
| `enkripta.sh cambiar-contrasena <vault.cvault>` | Sustituye una contraseña existente |
| `enkripta.sh anadir-contrasena <vault.cvault>` | Añade una contraseña alternativa |
| `enkripta.sh eliminar-contrasena <vault.cvault>` | Quita una contraseña (si hay más de una) |
| `enkripta.sh --version` | Muestra la versión instalada |
| `enkripta.sh -l` | Cambia el idioma guardado de la interfaz entre español e inglés |

Todos estos comandos tienen también su alias en inglés (`encrypt`, `decrypt`, `update`, `change-password`, `add-password`, `remove-password`...), por si prefieres usarlos así. Y si prefieres los diálogos gráficos desde la terminal, están las variantes `gui`, `gui-encrypt <ruta>` y `gui-menu <vault.cvault>`, que son justo las que usan internamente el menú de aplicaciones, el escritorio y Nemo.

### Idioma

Enkripta detecta el idioma del sistema y usa español cuando el locale activo empieza por `es`; en cualquier otro caso se pone en inglés por defecto. El idioma seleccionado se guarda por usuario en `~/.config/enkripta/language`, así que se mantiene entre ejecuciones.

Para cambiarlo rápidamente:

```bash
enkripta.sh -l
```

En el menú de un vault desde terminal, `L)` (o `l)`) cambia entre español e inglés sin salir del menú. Los menús gráficos también incluyen una opción `Cambiar idioma: español / inglés`. Cambiar el idioma solo modifica los textos de la interfaz; no cambia el formato del vault, los nombres de archivos, los comandos, las contraseñas ni los datos cifrados.

Las acciones del clic derecho de Nemo siguen el idioma de Enkripta, no el del sistema: Nemo elegiría una traducción `Name[xx]` según el locale del sistema, así que las acciones se escriben ya traducidas. `enkripta.sh -l` (o la opción de idioma de los menús gráficos) las reescribe; una acción que hayas borrado no se recrea, y si la integración no está instalada no se crea nada. Mientras no hayas elegido idioma, Enkripta sigue el del sistema y resincroniza las acciones la próxima vez que se abre desde Nemo, el menú de aplicaciones o el escritorio.

## Pruebas

Cada batería se ejecuta desde la raíz del proyecto y trabaja en un directorio temporal:

```bash
./tests/test_enkripta.sh
./tests/test_ui_aesthetics.sh
./tests/test_real_simulation.sh
./tests/test_integration_contract.sh
./tests/test_adversarial_regression.sh
./tests/test_suite_sensitivity.sh
```

| Batería | Qué protege |
|---|---|
| `test_enkripta.sh` | Comportamiento base: cifrado y ciclo de vida de contraseñas, paridad inglés/español de cada mensaje, detección y cambio de idioma, instalación y desinstalación |
| `test_ui_aesthetics.sh` | Diálogos gráficos, contra un stub de zenity: argumentos correctos (`--entry`, no `--password`), botones traducidos, `_`, `&` y `<` escapados, y textos que caben en ambos idiomas |
| `test_real_simulation.sh` | Uso real de principio a fin: prompts de terminal con PTY real, menús gráficos, acciones de Nemo y contraseña maestra |
| `test_integration_contract.sh` | Desktop Entry, tipo MIME y acciones de Nemo (incluido el parseo seguro de rutas `%F`), resueltos con la pila real de GLib/GIO; enlaces de la documentación |
| `test_adversarial_regression.sh` | Entradas hostiles o rotas: vaults manipulados, path traversal, enlaces simbólicos, caracteres especiales en rutas y fallos que no deben destruir datos |
| `test_suite_sensitivity.sh` | Prueba las pruebas: reintroduce fallos conocidos a propósito y comprueba que las baterías los detectan |

Las comprobaciones nativas de Nemo/Zenity se marcan como `SKIP`, nunca como un falso `PASS`, cuando esos programas no están disponibles.

## Contraseñas independientes por vault

La mayoría de herramientas de "cifrado con contraseña" atan los datos a una única contraseña: si quieres compartir el acceso con alguien más, o cambiarla, tienes que volver a cifrarlo todo desde cero.

Enkripta funciona distinto, de forma parecida a los *keyslots* de LUKS: los datos se cifran una sola vez con una clave maestra aleatoria, y esa clave maestra se guarda cifrada por separado para cada contraseña que añadas. El resultado:

- Puedes tener varias contraseñas válidas para el mismo vault (por ejemplo, la tuya y la de otra persona), y cualquiera de ellas lo desbloquea.
- Añadir, cambiar o eliminar una contraseña es una operación pequeña y rápida: **no vuelve a cifrar el contenido**, solo la clave maestra cifrada dentro de ese hueco.
- Puedes quitarle el acceso a alguien (eliminando su contraseña) sin tocar el resto ni volver a subir/mover el archivo cifrado entero.

**Limitación de diseño:** eliminar una contraseña borra su hueco (keyslot), pero no genera una clave maestra nueva ni vuelve a cifrar los datos. Si esa contraseña llegó a usarse para descifrar el vault en algún momento (o si esa persona conserva una copia del archivo `.cvault` de antes de eliminarla), quien la conocía podría seguir abriendo esas copias antiguas. Para revocar el acceso de verdad frente a alguien que ya vio el contenido, cifra el original de nuevo desde cero (nueva clave maestra) en vez de solo eliminar su contraseña.

## Seguridad

- Cifrado simétrico **AES-256** vía GPG.
- Derivación de clave reforzada: `S2K` modo 3, más de 65 millones de iteraciones, `SHA-512`.
- Cada `.cvault` valida su propio contenido antes de descifrar (rechaza archivos manipulados o con nombres internos sospechosos).
- Al cifrar, se te ofrece sobrescribir y eliminar el original con `shred` (varias pasadas). La eficacia de la sobrescritura depende del sistema de archivos y del dispositivo de almacenamiento.

## Compatibilidad

Enkripta está pensado y probado para **Linux Mint 22.3 con Cinnamon** (gestor de archivos Nemo), que es de donde vienen las acciones de botón derecho, el icono de escritorio y la asociación de `.cvault`. Debería funcionar igual en cualquier otra versión de Mint o distribución basada en Cinnamon, ya que solo usa carpetas estándar de tu usuario (`~/.local/share/applications`, `~/.local/share/mime`, `~/.local/share/nemo/actions`, etc.).

### Capas de compatibilidad

Enkripta está construido en tres capas, y solo la última depende de Mint/Nemo:

| Capa | Qué aporta | Dónde funciona |
|---|---|---|
| **Núcleo** | Cifrar y descifrar desde la terminal | Cualquier Linux con herramientas GNU, los [requisitos](#requisitos) y GnuPG 2.2.7 o superior |
| **Integración de escritorio** | Entrada en el menú de aplicaciones, acceso directo en el escritorio, tipo de archivo `.cvault` y doble clic | Debería funcionar en cualquier escritorio que siga los estándares de freedesktop.org (GNOME, KDE, XFCE, MATE...) |
| **Acciones de Nemo** | Entradas del clic derecho | Solo Nemo (Cinnamon) |

La capa de escritorio son simples archivos estándar en tu carpeta personal, y no necesita que `~/.local/bin` esté en tu `PATH`. Las herramientas auxiliares (`xdg-open`, `xdg-user-dir`, `notify-send`, los actualizadores de caché de MIME e iconos) son opcionales: se usan si están y se omiten si no. Solo los diálogos gráficos necesitan `zenity` sí o sí.

### Otras distribuciones de Linux

Los avisos del instalador mencionan `apt`; en otras familias usa el equivalente (`zenity` y la herramienta de notificaciones son opcionales pero recomendadas):

| Familia | Comando |
|---|---|
| Debian, Ubuntu y derivadas | `sudo apt install gnupg zenity libnotify-bin` |
| Fedora, RHEL y derivadas | `sudo dnf install gnupg2 zenity libnotify` |
| Arch y derivadas | `sudo pacman -S gnupg zenity libnotify` |
| openSUSE | `sudo zypper install gpg2 zenity libnotify-tools` |

Después ejecuta el instalador como siempre. En escritorios que no sean Cinnamon:

- La entrada del menú, el acceso directo del escritorio y el doble clic en `.cvault` deberían funcionar igual que en Mint. Si el doble clic no abre Enkripta, asigna `enkripta.desktop` como aplicación predeterminada de los archivos `.cvault` desde tu gestor de archivos.
- Las acciones de Nemo solo las usa Nemo; si no lo usas, quítalas con `enkripta.sh quitar-acciones-nemo`.
- El clic derecho en otros gestores de archivos no está incluido (ver [Hoja de ruta](#hoja-de-ruta)), pero la mayoría permite añadir una acción personalizada que ejecute `enkripta.sh gui-encrypt <ruta>` o `enkripta.sh gui-menu <vault.cvault>`, los mismos comandos que usan las acciones de Nemo.

## Hoja de ruta

- [x] Versión en inglés del programa y de esta documentación.
- [ ] Explorar soporte para otros gestores de archivos (Nautilus, Dolphin) si hay demanda.
- [ ] Paquete `.deb` para instalar con un doble clic, sin pasar por `git clone`.

## Licencia

Enkripta es software libre distribuido bajo los términos de la **GNU General Public License versión 3 (GPLv3)**. Consulta el archivo [LICENSE.txt](LICENSE.txt) para el texto completo.

---

Hecho por **[Filonux](https://github.com/filonux)**.
