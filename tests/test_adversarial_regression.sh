#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$ROOT_DIR/script/enkripta-instalador.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
chmod 755 "$TMP"

HOME_T="$TMP/home with spaces"
mkdir -p "$HOME_T/.config" "$HOME_T/.local/share"
chown -R nobody:nogroup "$HOME_T" 2>/dev/null || chown -R nobody:nobody "$HOME_T"
RUN=(runuser -u nobody -- env TMPDIR=/tmp HOME="$HOME_T" XDG_CONFIG_HOME="$HOME_T/.config" XDG_DATA_HOME="$HOME_T/.local/share")
run_as_user() { "${RUN[@]}" "$@"; }
fail(){ printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass(){ printf 'PASS: %s\n' "$*"; }

"${RUN[@]}" bash "$INSTALLER" >/dev/null
APP="$HOME_T/.local/bin/enkripta.sh"
[ -x "$APP" ] || fail 'installed script missing'

# Special characters in the path must survive the full CLI + vault round trip.
ODD="$HOME_T/quote ' dollar \$ semi; brackets [x] áé.txt"
printf 'adversarial content\n' > "$ODD"
printf 'n\nKnownPass123!\nKnownPass123!\nn\n' | run_as_user env ENKRIPTA_LANG=en "$APP" encrypt "$ODD" >/dev/null
ODD_VAULT="$ODD.cvault"
[ -f "$ODD_VAULT" ] || fail 'special-character path did not produce a vault'
rm "$ODD"
printf 'n\nKnownPass123!\n' | run_as_user env ENKRIPTA_LANG=en "$APP" decrypt "$ODD_VAULT" >/dev/null
[ -f "$ODD" ] || fail 'special-character path did not decrypt back to the original name'
grep -Fx 'adversarial content' "$ODD" >/dev/null || fail 'special-character round trip changed content'
pass 'path edge cases survive encryption/decryption'

# Wrong password: no output and no mutation of the vault.
sha_before=$(sha256sum "$ODD_VAULT" | cut -d' ' -f1)
if printf 'n\nWrongPass123!\n' | run_as_user env ENKRIPTA_LANG=en "$APP" decrypt "$ODD_VAULT" >/dev/null 2>&1; then
    fail 'wrong password unexpectedly succeeded'
fi
[ "$(sha256sum "$ODD_VAULT" | cut -d' ' -f1)" = "$sha_before" ] || fail 'wrong password modified the vault'
pass 'wrong password is non-destructive'

# A corrupted payload must not leave a truncated destination behind.
TRUNC="$TMP/truncated-data.cvault"; mkdir -p "$TMP/trunc"; tar -xf "$ODD_VAULT" -C "$TMP/trunc"
truncate -s -1 "$TMP/trunc/data.gpg"; tar -cf "$TRUNC" -C "$TMP/trunc" meta data.gpg slot1.gpg
printf 'DO NOT OVERWRITE\n' > "$ODD"
if printf 'n\nNewPass123!\n' | run_as_user env ENKRIPTA_LANG=en "$APP" decrypt "$TRUNC" >/dev/null 2>&1; then
    fail 'truncated payload unexpectedly decrypted'
fi
printf 'DO NOT OVERWRITE\n' > "$ODD"
grep -Fx 'DO NOT OVERWRITE' "$ODD" >/dev/null || fail 'failed decryption overwrote the destination'
rm -f "$ODD"
pass 'corrupted payload cannot leave a partial output file'

# Language state is external to the vault bytes.
rm -f "$HOME_T/.config/enkripta/language"
sha_before=$(sha256sum "$ODD_VAULT" | cut -d' ' -f1)
run_as_user "$APP" -l >/dev/null
run_as_user "$APP" -l >/dev/null
[ "$(sha256sum "$ODD_VAULT" | cut -d' ' -f1)" = "$sha_before" ] || fail 'language toggle changed vault bytes'
pass 'language switching is byte-inert for vaults'

# Password rotation/addition/removal must leave data.gpg unchanged.
WORK="$TMP/work"; mkdir -p "$WORK"; tar -xf "$ODD_VAULT" -C "$WORK"
DATA_HASH=$(sha256sum "$WORK/data.gpg" | cut -d' ' -f1)
printf 'n\nKnownPass123!\nNewPass123!\nNewPass123!\n' | run_as_user env ENKRIPTA_LANG=en "$APP" change-password "$ODD_VAULT" >/dev/null
rm -rf "$WORK"; mkdir -p "$WORK"; tar -xf "$ODD_VAULT" -C "$WORK"
[ "$DATA_HASH" = "$(sha256sum "$WORK/data.gpg" | cut -d' ' -f1)" ] || fail 'change-password rewrote data.gpg'
if printf 'n\nKnownPass123!\n' | run_as_user env ENKRIPTA_LANG=en "$APP" decrypt "$ODD_VAULT" >/dev/null 2>&1; then
    fail 'old password still unlocked after change-password'
fi
# Remove any output from the failed old-password attempt before continuing.
rm -f "$ODD"
printf 'n\nNewPass123!\nAddedPass456!\nAddedPass456!\n' | run_as_user env ENKRIPTA_LANG=en "$APP" add-password "$ODD_VAULT" >/dev/null
rm -rf "$WORK"; mkdir -p "$WORK"; tar -xf "$ODD_VAULT" -C "$WORK"
[ "$DATA_HASH" = "$(sha256sum "$WORK/data.gpg" | cut -d' ' -f1)" ] || fail 'add-password rewrote data.gpg'
printf 'n\nAddedPass456!\ny\n' | run_as_user env ENKRIPTA_LANG=en "$APP" remove-password "$ODD_VAULT" >/dev/null
rm -rf "$WORK"; mkdir -p "$WORK"; tar -xf "$ODD_VAULT" -C "$WORK"
[ "$DATA_HASH" = "$(sha256sum "$WORK/data.gpg" | cut -d' ' -f1)" ] || fail 'remove-password rewrote data.gpg'
rm -f "$ODD"
printf 'n\nNewPass123!\n' | run_as_user env ENKRIPTA_LANG=en "$APP" decrypt "$ODD_VAULT" >/dev/null
[ -f "$ODD" ] || fail 'remaining password stopped working after removal'
pass 'password lifecycle preserves the encrypted payload and remaining access'
rm -f "$ODD"

# Regression for the dangling-symlink destination fix: a pre-existing broken
# symlink at the output path must stop the decrypt, not be silently replaced.
# The dangling target must resolve *inside* out_parent, or the unrelated
# realpath containment check would catch it first and the test would not
# actually exercise the mv fix.
ln -s "$HOME_T/ghost-target-does-not-exist" "$ODD"
DANGLING_HASH=$(sha256sum "$ODD_VAULT" | cut -d' ' -f1)
if printf 'n\nNewPass123!\n' | run_as_user env ENKRIPTA_LANG=en "$APP" decrypt "$ODD_VAULT" >/dev/null 2>&1; then
    fail 'decrypt overwrote a dangling symlink at the destination'
fi
[ -L "$ODD" ] || fail 'dangling symlink at the destination was removed or replaced'
[ "$(readlink -- "$ODD")" = "$HOME_T/ghost-target-does-not-exist" ] || fail 'dangling symlink target changed'
[ "$(sha256sum "$ODD_VAULT" | cut -d' ' -f1)" = "$DANGLING_HASH" ] || fail 'vault changed while its destination was a dangling symlink'
rm -f "$ODD"
pass 'decrypt refuses to replace a dangling symlink at the destination'

# Unexpected outer members must be rejected; original vault stays untouched.
CORR="$TMP/corrupt.cvault"; cp "$ODD_VAULT" "$CORR"; ORIGINAL_HASH=$(sha256sum "$ODD_VAULT" | cut -d' ' -f1); printf 'evil\n' > "$TMP/evil"
tar -rf "$CORR" -C "$TMP" evil >/dev/null 2>&1 || fail 'failed to build unexpected-member fixture'
if printf 'n\nNewPass123!\n' | run_as_user env ENKRIPTA_LANG=en "$APP" decrypt "$CORR" >/dev/null 2>&1; then
    fail 'unexpected outer member was accepted'
fi
[ "$(sha256sum "$ODD_VAULT" | cut -d' ' -f1)" = "$ORIGINAL_HASH" ] || fail 'original vault changed while testing a corrupted copy'
pass 'unexpected outer-vault members are rejected'

# Removing the mandatory first slot must make the vault unusable.
MISSING="$TMP/missing-slot.cvault"; mkdir -p "$TMP/missing"; tar -xf "$ODD_VAULT" -C "$TMP/missing"; rm "$TMP/missing/slot1.gpg"; tar -cf "$MISSING" -C "$TMP/missing" .
if printf 'n\nNewPass123!\n' | run_as_user env ENKRIPTA_LANG=en "$APP" decrypt "$MISSING" >/dev/null 2>&1; then
    fail 'vault with missing slot1 was accepted'
fi
pass 'missing mandatory password slot is rejected'

# Outer-vault members must be regular files: links could otherwise redirect GPG
# to data outside the .cvault container.
LINK="$TMP/linked-slot.cvault"; mkdir -p "$TMP/link-src"; tar -xf "$ODD_VAULT" -C "$TMP/link-src"
cp "$TMP/link-src/slot1.gpg" "$TMP/outside-slot.gpg"; rm "$TMP/link-src/slot1.gpg"
ln -s "$TMP/outside-slot.gpg" "$TMP/link-src/slot1.gpg"
tar -cf "$LINK" -C "$TMP/link-src" meta data.gpg slot1.gpg
if printf 'n\nNewPass123!\n' | run_as_user env ENKRIPTA_LANG=en "$APP" decrypt "$LINK" >/dev/null 2>&1; then
    fail 'vault with a symlink member was accepted'
fi
pass 'outer-vault symlink members are rejected'

# Slot numbering must be contiguous so malformed archives cannot silently lose a slot.
GAP="$TMP/gap-slot.cvault"; mkdir -p "$TMP/gap"; tar -xf "$ODD_VAULT" -C "$TMP/gap"; mv "$TMP/gap/slot1.gpg" "$TMP/gap/slot2.gpg"
tar -cf "$GAP" -C "$TMP/gap" meta data.gpg slot2.gpg
if printf 'n\nNewPass123!\n' | run_as_user env ENKRIPTA_LANG=en "$APP" decrypt "$GAP" >/dev/null 2>&1; then
    fail 'vault with a non-contiguous slot sequence was accepted'
fi
pass 'outer-vault slot gaps are rejected'

# Metadata traversal must be rejected before any file is written.
TRAV="$TMP/traversal.cvault"; mkdir -p "$TMP/trav"; tar -xf "$ODD_VAULT" -C "$TMP/trav"
printf 'TYPE=file\nNAME=../escaped\n' > "$TMP/trav/meta"; tar -cf "$TRAV" -C "$TMP/trav" .
rm -f "$TMP/escaped"
if printf 'n\nNewPass123!\n' | run_as_user env ENKRIPTA_LANG=en "$APP" decrypt "$TRAV" >/dev/null 2>&1; then
    fail 'metadata traversal was accepted'
fi
[ ! -e "$TMP/escaped" ] || fail 'metadata traversal escaped its intended parent'
pass 'metadata path traversal is rejected'

# Inner directory payloads must not restore symbolic links or special files.
MASTER_SLOT="$TMP/master-slot.gpg"; tar -xOf "$ODD_VAULT" slot1.gpg > "$MASTER_SLOT"
MASTER_KEY=$(run_as_user gpg --batch --yes --no-tty --pinentry-mode loopback --passphrase 'NewPass123!' -d "$MASTER_SLOT" 2>/dev/null)
INNER_SRC="$TMP/inner-src"; mkdir -p "$INNER_SRC/inner-safe"; printf 'safe\n' > "$INNER_SRC/inner-safe/normal.txt"; ln -s /etc/passwd "$INNER_SRC/inner-safe/leak"
( cd "$INNER_SRC" && tar -cf "$TMP/malicious.tar" inner-safe )
run_as_user gpg --batch --yes --no-tty --pinentry-mode loopback --symmetric --cipher-algo AES256 --digest-algo SHA512 --s2k-mode 3 --s2k-count 65011712 --s2k-digest-algo SHA512 --no-symkey-cache --passphrase-fd 3 -o "$HOME_T/malicious-data.gpg" 3<<<"$MASTER_KEY" < "$TMP/malicious.tar"
printf 'TYPE=dir\nNAME=inner-safe\n' > "$TMP/inner-meta"
tar -cf "$TMP/inner-link.cvault" -C "$TMP" inner-meta -C "$HOME_T" malicious-data.gpg -C "$TMP" master-slot.gpg
mkdir -p "$TMP/inner-final"; tar -xf "$TMP/inner-link.cvault" -C "$TMP/inner-final"; mv "$TMP/inner-final/inner-meta" "$TMP/inner-final/meta"; mv "$TMP/inner-final/malicious-data.gpg" "$TMP/inner-final/data.gpg"; mv "$TMP/inner-final/master-slot.gpg" "$TMP/inner-final/slot1.gpg"; tar -cf "$TMP/inner-link.cvault" -C "$TMP/inner-final" meta data.gpg slot1.gpg
rm -rf "$HOME_T/inner-safe"
if printf 'n\nNewPass123!\n' | run_as_user env ENKRIPTA_LANG=en "$APP" decrypt "$TMP/inner-link.cvault" >/dev/null 2>&1; then
    fail 'inner payload containing a symlink was accepted'
fi
[ ! -e "$HOME_T/inner-safe" ] || fail 'rejected inner symlink payload created output'
pass 'inner payload symlinks are rejected'

# Source trees with symlinks are rejected before creating a new vault.
UNSAFE_DIR="$TMP/unsafe-source"; mkdir -p "$UNSAFE_DIR"; printf data > "$UNSAFE_DIR/file"; ln -s /etc/passwd "$UNSAFE_DIR/link"
UNSAFE_VAULT="$UNSAFE_DIR.cvault"
if printf 'n\nNewPass123!\nNewPass123!\n' | run_as_user env ENKRIPTA_LANG=en "$APP" encrypt "$UNSAFE_DIR" >/dev/null 2>&1; then
    fail 'source directory containing a symlink was encrypted'
fi
[ ! -e "$UNSAFE_VAULT" ] || fail 'unsafe source created a vault'
pass 'unsafe source trees are rejected before encryption'

# Help is a deterministic CLI stream in both supported languages.
HELP=$(run_as_user env ENKRIPTA_LANG=en "$APP" --help)
printf '%s\n' "$HELP" | grep -F 'Usage:' >/dev/null || fail 'English --help missing Usage'
HELP_ES=$(run_as_user env ENKRIPTA_LANG=es "$APP" --help)
printf '%s\n' "$HELP_ES" | grep -F 'Uso:' >/dev/null || fail 'Spanish --help missing Uso'
HELP_H=$(run_as_user env ENKRIPTA_LANG=en "$APP" -h)
[ "$HELP" = "$HELP_H" ] || fail '-h and --help differ in English'
HELP_H_ES=$(run_as_user env ENKRIPTA_LANG=es "$APP" -h)
[ "$HELP_ES" = "$HELP_H_ES" ] || fail '-h and --help differ in Spanish'
pass 'explicit --help remains stable under redirected/non-interactive execution'

printf '\nADVERSARIAL REGRESSION: all high-value invariants passed.\n'

