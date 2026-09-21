<img src="assets/icon/enkripta.svg" width="140" align="right" alt="Enkripta icon">

# Enkripta

Enkripta encrypts folders and files on Linux Mint (Cinnamon/Nemo) with AES-256, and makes it feel like a native part of the system: double-click from the desktop, right-click actions in Nemo, and its own icon for encrypted files. Everything is installed with a single script, without unusual dependencies and without touching anything outside your personal home folder (`sudo` is not required).

> English is now the main language of the project. Spanish documentation is available in [Español](README.es.md).

## What's new

**🌐 English interface, Spanish included**

- The whole program is available in English and Spanish: installer, dialogs, menus, terminal output and the Nemo right-click actions. It follows your system language (`es*` → Spanish, anything else → English) and remembers your choice.
- Switch any time with `enkripta.sh -l`, `L)` in the terminal menu, or **Switch language** in the graphical menu.
- Commands now have English names (`encrypt`, `decrypt`, `change-password`...). The original Spanish ones (`cifrar`, `descifrar`...) keep working, so existing scripts are unaffected.
- Language only changes the text you see: switching it never modifies a vault, and a vault created in one language opens in the other.

**🛡️ More robust**

- **Failures don't cost you data.** A wrong password is harmless, and a corrupted vault can't leave a half-written file behind.
- **Hostile vaults are rejected.** Unexpected or symlinked members, malformed password slots and path traversal in the metadata are refused, and unsafe source folders are refused before encrypting.
- **Password changes are safe.** Changing or removing a password replaces only its slot (atomically) and never touches the encrypted data.
- **Awkward paths just work.** Spaces, quotes, shell characters and Unicode in names, even when your `$HOME` contains spaces.
- **Cleaner install and uninstall.** The installer refuses `sudo`, can be run again safely, and uninstalling leaves your own GPG keyring and Desktop folder alone.
- **Tested against abuse.** Six automated suites, one of which reintroduces known bugs to prove the tests catch them. See [Tests](#tests).

## Screenshots

<img width="460" height="413" alt="Enkripta-menu-en" src="https://github.com/user-attachments/assets/86a12882-8f8b-4ff6-8401-2a1e0ff55d9d" />
<img width="522" height="315" alt="confi-pass-en" src="https://github.com/user-attachments/assets/a812c4c2-8e4d-4218-8778-aa7e95511ecb" />
<img width="331" height="280" alt="confi-pass2-en" src="https://github.com/user-attachments/assets/5705aa13-43d8-4905-948f-4204f89f445b" />

<img width="481" height="336" alt="nemo-options-en" src="https://github.com/user-attachments/assets/bee767d9-a97b-4aeb-830c-d7674c1f5c1a" />

## Install from the terminal or ZIP

```bash
git clone https://github.com/filonux/Enkripta.git
cd Enkripta
chmod +x script/enkripta-instalador.sh
./script/enkripta-instalador.sh
```

The integration is installed in your personal home folder (`~/.local/...`):

- The program, at `~/.local/bin/enkripta.sh`.
- Its icon.
- A shortcut in the **Applications menu** (opens the graphical assistant).
- A shortcut on the **desktop**, ready to open with a double-click.
- The `.cvault` file type, with Enkripta set as the default application for opening it.
- Two **Nemo right-click** actions: `🔒 Encrypt with Enkripta` and `🔓 Open Enkripta vault` (shown in Enkripta's language, see [Language](#language)).

### Optional: install with Scriptya

[Scriptya](https://github.com/filonux/Scriptya), a menu for your scripts, can launch the installer for you: copy `script/enkripta-instalador.sh` (it is self-contained) into your scripts folder and run it from Scriptya's menu. Launched this way it only installs (or updates) Enkripta; to uninstall, see [Uninstall](#uninstall).

Scriptya's **Change Icon** option can also swap Enkripta's icon for any of the alternatives in [`assets/icon/`](assets/icon/), which is why there are several. Re-running the installer restores the default icon.

### Uninstall

```bash
./script/enkripta-instalador.sh --uninstall
```

This removes everything Enkripta installed: shortcuts, Applications menu entry, `.cvault` association, Nemo actions and the `~/.local/bin/enkripta.sh` script itself, leaving no trace. Your `.cvault` files are never touched.

Two things are deliberately treated with care because they are not Enkripta's: `~/.gnupg` (kept if it already existed or holds your own keys or settings; removed only when it is still the fresh, empty keyring GPG created on its first use) and your Desktop folder (only the `enkripta.desktop` shortcut inside is deleted, never the folder). The GTK/Nemo "recent files" history is not cleaned either and may keep paths to `.cvault` files you opened; clear it from Nemo or delete `~/.local/share/recently-used.xbel`.

### Requirements

To install and use Enkripta: `gpg`, `tar`, `gzip`, `shred`, `base64` and `realpath`. They are all included by default in Linux Mint. Optional but recommended: `zenity` (graphical dialogs) and `notify-send` (desktop notifications). If `zenity` is missing, the installer warns you and gives you the exact command to install it.

## Usage

### From the desktop or Nemo

- Right-click a file or folder → **🔒 Encrypt with Enkripta**.
- Double-click a `.cvault` file → a menu opens: decrypt, change password, add password or remove password.
- The **Applications menu** icon → opens an assistant that asks what you want to do (encrypt a file, a folder, or open an existing vault).

### From the terminal

If you add `~/.local/bin` to your `PATH` (the installer warns you if it is not already there), you can use:

| Command | What it does |
|---|---|
| `enkripta.sh encrypt <path>` | Encrypts a file or folder and creates the `.cvault` file |
| `enkripta.sh easy-encrypt <path>` | Automatically decides whether to encrypt or open the vault |
| `enkripta.sh <vault.cvault>` | Opens the vault menu (decrypt / manage passwords) |
| `enkripta.sh decrypt <vault.cvault>` | Decrypts a vault |
| `enkripta.sh update <path>` | Re-encrypts the content while keeping the same passwords |
| `enkripta.sh change-password <vault.cvault>` | Replaces an existing password |
| `enkripta.sh add-password <vault.cvault>` | Adds an alternative password |
| `enkripta.sh remove-password <vault.cvault>` | Removes a password (when more than one exists) |
| `enkripta.sh --version` | Shows the installed version |
| `enkripta.sh -l` | Switches the saved interface language between English and Spanish |

The original Spanish command aliases are still available (`cifrar`, `descifrar`, `actualizar`, `cambiar-contrasena`, `anadir-contrasena`, `eliminar-contrasena`, etc.), so existing workflows are unchanged. Graphical variants are also available from the terminal: `gui`, `gui-encrypt <path>` and `gui-menu <vault.cvault>`, which are the commands used internally by the application menu, desktop shortcut and Nemo.

### Language

Enkripta detects the system language and uses Spanish when the active locale starts with `es`; otherwise, it defaults to English. The selected language is stored per user in `~/.config/enkripta/language`, so it persists between launches.

For a quick switch, run:

```bash
enkripta.sh -l
```

In the terminal vault menu, `L)` (or `l)`) switches between English and Spanish without leaving the menu. The graphical menus also include a `Switch language: English / Spanish` option for the same quick toggle. Switching language changes interface text only; vault format, file names, commands, password handling and encryption data are not changed.

The Nemo right-click actions follow Enkripta's language, not the system's: Nemo would pick a `Name[xx]` translation by the system locale, so the actions are written already translated. `enkripta.sh -l` (or the language option of the graphical menus) rewrites them; an action you deleted is not recreated, and nothing is created if the integration is not installed. While you have not chosen a language, Enkripta follows the system's and resyncs the actions the next time it is opened from Nemo, the Applications menu or the desktop.

## Tests

Run any suite from the project root; each one works in a temporary directory:

```bash
./tests/test_enkripta.sh
./tests/test_ui_aesthetics.sh
./tests/test_real_simulation.sh
./tests/test_integration_contract.sh
./tests/test_adversarial_regression.sh
./tests/test_suite_sensitivity.sh
```

| Suite | What it protects |
|---|---|
| `test_enkripta.sh` | Core behavior: encryption and password lifecycle, English/Spanish parity of every message, language detection and switching, install and uninstall |
| `test_ui_aesthetics.sh` | Graphical dialogs, checked against a zenity stub: correct arguments (`--entry`, not `--password`), translated buttons, escaped `_`, `&` and `<`, and text that fits in both languages |
| `test_real_simulation.sh` | End-to-end use: real terminal (PTY) prompts, graphical menus, Nemo actions and the master password |
| `test_integration_contract.sh` | Desktop Entry, MIME type and Nemo actions (including safe `%F` path parsing), resolved through the real GLib/GIO stack; documentation links |
| `test_adversarial_regression.sh` | Hostile or broken input: tampered vaults, path traversal, symlinks, special characters in paths, and failures that must not destroy data |
| `test_suite_sensitivity.sh` | Tests the tests: reintroduces known bugs on purpose and checks that the suites catch them |

Native Nemo/Zenity checks are reported as `SKIP`, never as a false `PASS`, when those programs are not available.

## Independent passwords per vault

Most password-based encryption tools tie the data to a single password: if you want to share access with someone else, or change it, you have to encrypt everything again from scratch.

Enkripta works differently, in a way similar to LUKS *keyslots*: the data is encrypted only once with a random master key, and that master key is stored encrypted separately for each password you add. The result:

- You can have several valid passwords for the same vault (for example, yours and someone else's), and any of them unlocks it.
- Adding, changing or removing a password is a small and fast operation: **it does not re-encrypt the content**, only the key wrapped in that slot.
- You can revoke someone's access (by removing their password) without touching the rest or re-uploading/moving the entire encrypted file.

**Design limitation:** removing a password deletes its slot, but does not generate a new master key or re-encrypt the data. If that password was ever used to decrypt the vault, or that person keeps a copy of the `.cvault` from before it was removed, they could still open those old copies. To truly revoke access from someone who already saw the content, re-encrypt the original from scratch (a new master key) instead of just removing their password.

## Security

- Symmetric **AES-256** encryption via GPG.
- Strengthened key derivation: `S2K` mode 3, more than 65 million iterations, `SHA-512`.
- Each `.cvault` validates its own content before decrypting (rejecting tampered files or suspicious internal names).
- When encrypting, you are offered the option to overwrite and remove the original with `shred` (multiple passes). The effectiveness of overwriting depends on the filesystem and storage device.

## Compatibility

Enkripta is designed and tested for **Linux Mint 22.3 with Cinnamon** (Nemo file manager), which is where the right-click actions, desktop icon and `.cvault` association come from. It should work in the same way on other Mint versions or Cinnamon-based distributions, since it only uses standard folders in your user account (`~/.local/share/applications`, `~/.local/share/mime`, `~/.local/share/nemo/actions`, etc.).

### Compatibility layers

Enkripta is built in three layers, and only the last one depends on Mint/Nemo:

| Layer | What it provides | Where it works |
|---|---|---|
| **Core** | Encrypt and decrypt from the terminal | Any Linux with GNU tools, the [requirements](#requirements) and GnuPG 2.2.7 or newer |
| **Desktop integration** | Applications menu entry, desktop shortcut, `.cvault` file type and double-click | Should work on any desktop that follows the freedesktop.org standards (GNOME, KDE, XFCE, MATE...) |
| **Nemo actions** | Right-click entries | Nemo (Cinnamon) only |

The desktop layer is just standard files in your home folder, and it does not need `~/.local/bin` in your `PATH`. Helper tools (`xdg-open`, `xdg-user-dir`, `notify-send`, the MIME and icon cache updaters) are optional: they are used when present and skipped when not. Only the graphical dialogs strictly need `zenity`.

### Other Linux distributions

The installer's install hints mention `apt`; on other families use the equivalent (`zenity` and the notification tool are optional but recommended):

| Family | Command |
|---|---|
| Debian, Ubuntu and derivatives | `sudo apt install gnupg zenity libnotify-bin` |
| Fedora, RHEL and derivatives | `sudo dnf install gnupg2 zenity libnotify` |
| Arch and derivatives | `sudo pacman -S gnupg zenity libnotify` |
| openSUSE | `sudo zypper install gpg2 zenity libnotify-tools` |

Then run the installer as usual. On desktops other than Cinnamon:

- The menu entry, desktop shortcut and `.cvault` double-click should work as they do on Mint. If double-click does not open Enkripta, set `enkripta.desktop` as the default application for `.cvault` files in your file manager.
- The Nemo actions are only used by Nemo; if you do not use it, remove them with `enkripta.sh remove-nemo-actions`.
- Right-click in other file managers is not included (see [Roadmap](#roadmap)), but most of them let you add a custom action that runs `enkripta.sh gui-encrypt <path>` or `enkripta.sh gui-menu <vault.cvault>`, the same commands the Nemo actions use.

## Roadmap

- [x] English version of the program and documentation.
- [ ] Explore support for other file managers (Nautilus, Dolphin) if there is demand.
- [ ] `.deb` package for one-click installation without going through `git clone`.

## License

Enkripta is free software distributed under the terms of the **GNU General Public License version 3 (GPLv3)**. See the [LICENSE.txt](LICENSE.txt) file for the full text.

---

Made by **[Filonux](https://github.com/filonux)**.
