# AMZDesk

AMZDesk is [RustDesk](https://github.com/rustdesk/rustdesk) (AGPL-3.0) for Windows x64 with the
a.m.z computer lab branding and its own server built in. The source of every change is in this
folder; everything else is upstream RustDesk.

- `brand.py` — the changes: program name, server address and key, icons, logos, file properties.
- `assets/` — the pictures it puts in place.
- `make_workflow.py` — writes `.github/workflows/amzdesk.yml` from upstream `flutter-build.yml`
  (Windows x64 only, plus the branding step). Rerun it after syncing with upstream.

A push to the `amzdesk` branch builds it; the program is published under the release tag `amzdesk`.
