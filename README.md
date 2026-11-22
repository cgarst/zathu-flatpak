# zathu-flatpak

Flatpak repository for Zathu Software, served at <https://flatpak.zathu.net/> and listed in KDE Discover / GNOME
Software once a user adds `https://flatpak.zathu.net/zathu.flatpakrepo`. Install instructions live in MajesticTab's README and landing page.

The OSTree repo is **not stored in git**. Each publish run mirrors the live Pages site, imports the new bundles, signs,
prunes (keeps 3 commits per ref), and redeploys. The git repo holds only this tooling.

## One-time setup

1. Create the signing key (no passphrase, CI needs it unattended) and keep the private half out of git:
   ```
   gpg --quick-generate-key "Zathu Software Flatpak <flatpak@zathu.net>" ed25519 sign never
   gpg --list-secret-keys --keyid-format long      # note the key id
   gpg --armor --export-secret-keys <KEYID>        # -> secret FLATPAK_GPG_PRIVATE_KEY
   ```
   Back the private key up somewhere safe. Losing it means every user has to re-add the remote.
2. Create the GitHub repo `cgarst/zathu-flatpak`, push this directory.
3. Repo settings: Pages source = **GitHub Actions**; custom domain `flatpak.zathu.net`; enforce HTTPS.
   Secret `FLATPAK_GPG_PRIVATE_KEY`; variable `FLATPAK_GPG_KEY_ID`.
4. DNS: `CNAME flatpak -> cgarst.github.io`.
5. Add a fine-grained token that can run `repository_dispatch` on this repo (Contents: read/write on
   `cgarst/zathu-flatpak`) to each publishing project as secret `FLATPAK_REPO_TOKEN`.

## Publishing from a project's CI

After the project's release job has uploaded its `*.flatpak` files to a GitHub release:

```yaml
- name: Publish to the Zathu Flatpak repo
  env:
    GH_TOKEN: ${{ secrets.FLATPAK_REPO_TOKEN }}
  run: |
    gh api repos/cgarst/zathu-flatpak/dispatches -f event_type=publish-flatpak \
      -f 'client_payload[source_repo]=${{ github.repository }}' \
      -f 'client_payload[tag]=${{ github.ref_name }}'
```

Or run the workflow by hand from the Actions tab. New projects must be added to the allowlist in `publish.yml`.

## Notes

- Every project's Flatpak must ship a valid metainfo file and a stable app id; Discover builds its listing from the
  appstream data in the commits.
- Bundles are imported onto whatever branch they were built with (MajesticTab: `master`, the flatpak-builder default).
  The `.flatpakref` templates assume that.
- Runtimes (GNOME) come from Flathub: `RuntimeRepo` in the `.flatpakrepo` makes Flatpak add it if missing.
- Pages limits: 1 GB site, 100 GB/month soft bandwidth. If the repo outgrows that, move the data to a bucket and keep
  the same URL.
