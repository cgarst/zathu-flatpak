#!/usr/bin/env bash
# Adds the given .flatpak bundles to the OSTree repo and builds the static site in ./site.
#
# The repo is not stored in git. It lives only in the deployed GitHub Pages site: each run mirrors the live site into
# ./repo, imports the new bundles, signs, prunes old commits, and republishes. That keeps this git repo tiny.
#
# Usage: scripts/publish.sh bundle.flatpak [more.flatpak ...]
# Env:   FLATPAK_GPG_KEY_ID        key to sign with (required)
#        GNUPGHOME                 homedir that holds the secret key (required)
#        PRUNE_DEPTH               commits kept per ref (default 3)
#        LIVE_URL                  where the current repo is served (default https://flatpak.zathu.net)
set -euo pipefail
cd "$(dirname "$0")/.."

: "${FLATPAK_GPG_KEY_ID:?}" "${GNUPGHOME:?}"
LIVE_URL=${LIVE_URL:-https://flatpak.zathu.net}
PRUNE_DEPTH=${PRUNE_DEPTH:-3}
[ "$#" -gt 0 ] || { echo "no bundles given" >&2; exit 2; }

rm -rf repo site
ostree init --repo=repo --mode=archive

# Mirror what is live now (first run: nothing is live yet, so start empty).
if curl -fsSo /dev/null "$LIVE_URL/config"; then
  ostree remote add --repo=repo --no-gpg-verify live "$LIVE_URL"
  ostree pull --repo=repo --mirror live
  ostree remote delete --repo=repo live
else
  echo "nothing live at $LIVE_URL yet, starting an empty repo"
fi

for bundle in "$@"; do
  echo "importing $bundle"
  flatpak build-import-bundle --gpg-sign="$FLATPAK_GPG_KEY_ID" --gpg-homedir="$GNUPGHOME" repo "$bundle"
done

# Rebuilds the appstream branches (what KDE Discover lists), the signed summary, and static deltas.
flatpak build-update-repo \
  --gpg-sign="$FLATPAK_GPG_KEY_ID" --gpg-homedir="$GNUPGHOME" \
  --title="Zathu Software" --comment="Apps from Zathu Software" \
  --homepage="https://majestictab.zathu.net/#download" \
  --generate-static-deltas --prune --prune-depth="$PRUNE_DEPTH" \
  repo

mkdir site
cp -a repo/. site/
rm -rf site/tmp site/.lock
cp CNAME site/CNAME
touch site/.nojekyll

# .flatpakrepo / .flatpakref embed the public key as one-line base64.
gpg --homedir "$GNUPGHOME" --export "$FLATPAK_GPG_KEY_ID" | base64 | tr -d '\n' > "$GNUPGHOME/key.b64"
for tpl in templates/*; do
  python3 - "$tpl" "site/$(basename "$tpl")" "$GNUPGHOME/key.b64" <<'PY'
import sys
src, dst, key = sys.argv[1:]
open(dst, "w").write(open(src).read().replace("@GPGKEY@", open(key).read()))
PY
done

cat > site/index.html <<'HTML'
<!doctype html><meta charset="utf-8"><title>Zathu Software Flatpak repository</title>
<meta http-equiv="refresh" content="0; url=https://majestictab.zathu.net/#download">
<p>This is the Flatpak repository for Zathu Software. Install instructions: <a href="https://majestictab.zathu.net/#download">majestictab.zathu.net</a>.</p>
HTML

du -sh site
