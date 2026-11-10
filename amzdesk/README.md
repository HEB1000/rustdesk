# R-TECH DESK

R-TECH DESK is [RustDesk](https://github.com/rustdesk/rustdesk) (AGPL-3.0) for Windows x64 with the
א.מ.ז computer lab branding, its own server built in, and its own main screen. Everything else is
upstream RustDesk.

## The generator

`Actions → R-TECH DESK build (generator) → Run workflow` builds a branded program from a form:
technical name, display name, subtitle, logo, company, server, key, the lines under "About" and the
main color. Empty fields keep the defaults. A push to the `amzdesk` branch builds the defaults.
The program is published under a release named after the technical name.

- `brand.py` — the branding: program name, server address and key, icons, logos, file properties
  (also of the self-extracting wrapper), the texts of the R-TECH screens and the main color.
- `assets/` — the pictures it starts from.
- `make_workflow.py` — writes `.github/workflows/amzdesk.yml` from upstream `flutter-build.yml`
  (Windows x64 only, the branding step, and a quick Dart check before the long Windows build).
  Rerun it after syncing with upstream.

## Changes to the RustDesk source

- `flutter/lib/rtech/` — the main screen: tiles of the computers connected to before, with a picture
  of their screen, online state, last connection, groups and technician notes; three designs
  (ע1 technician board, ע4 job cards, נ2 dark soft-shadow), a simple screen for relatives, and
  RustDesk's original screen, chosen from the "design" menu.
- `flutter/lib/desktop/pages/desktop_home_page.dart` — shows that screen instead of RustDesk's.
- `flutter/lib/common/widgets/dialog.dart` — "remember the code" is on by default.
- `src/rtech_thumb.rs`, `src/client/io_loop.rs`, `src/flutter_ffi.rs`, `src/lib.rs` — during a
  session, a small picture of the remote screen is saved every 20 seconds for its tile.
