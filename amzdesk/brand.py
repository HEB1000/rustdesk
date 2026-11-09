"""AMZDesk branding for the RustDesk source tree (run from the repository root, before the build).

What it changes, and nothing else:
  - the program name (APP_NAME), the rendezvous server and its public key, in hbb_common's config.rs;
  - the icons and logos (res/, the Windows runner icon, flutter/assets);
  - the names in the Windows file properties (Runner.rc, Cargo.toml winres).
Every text replacement must match exactly once, or the script stops: a changed upstream file
fails the build loudly instead of producing a half-branded program.

AMZDesk is RustDesk (https://github.com/rustdesk/rustdesk, AGPL-3.0) with these changes.
"""
import re
import shutil
import sys
from pathlib import Path

APP_NAME = "AMZDesk"
SERVER = "64.176.174.232"
SERVER_KEY = "vE0E77BjfekoChLKzFeY+cwM0hCzyv4zSLUDDQtYrsU="
COMPANY = "AMZ Computer Lab"

ROOT = Path.cwd()
ASSETS = Path(__file__).resolve().parent / "assets"


def replace_once(path: str, pattern: str, replacement: str, flags: int = 0) -> None:
    file = ROOT / path
    text = file.read_text(encoding="utf-8")
    new, count = re.subn(pattern, replacement, text, flags=flags)
    if count != 1:
        sys.exit(f"brand.py: expected 1 match in {path} for {pattern!r}, found {count}")
    file.write_text(new, encoding="utf-8")
    print(f"patched {path}: {pattern}")


def copy(asset: str, *targets: str) -> None:
    for target in targets:
        dst = ROOT / target
        if not dst.parent.is_dir():
            sys.exit(f"brand.py: missing folder for {target}")
        shutil.copyfile(ASSETS / asset, dst)
        print(f"copied {asset} -> {target}")


def main() -> None:
    config = "libs/hbb_common/src/config.rs"
    replace_once(config, r'(APP_NAME: RwLock<String> = RwLock::new\(")RustDesk("\.to_owned\(\)\))',
                 rf"\g<1>{APP_NAME}\g<2>")
    replace_once(config, r'pub const RENDEZVOUS_SERVERS: &\[&str\] = &\[[^\]]*\];',
                 f'pub const RENDEZVOUS_SERVERS: &[&str] = &["{SERVER}"];')
    replace_once(config, r'pub const RS_PUB_KEY: &str = "[^"]*";',
                 f'pub const RS_PUB_KEY: &str = "{SERVER_KEY}";')

    rc = "flutter/windows/runner/Runner.rc"
    replace_once(rc, r'VALUE "CompanyName", "[^"]*"', f'VALUE "CompanyName", "{COMPANY}"')
    replace_once(rc, r'VALUE "FileDescription", "[^"]*"', f'VALUE "FileDescription", "{APP_NAME}"')
    replace_once(rc, r'VALUE "InternalName", "[^"]*"', f'VALUE "InternalName", "{APP_NAME.lower()}"')
    replace_once(rc, r'VALUE "OriginalFilename", "[^"]*"', f'VALUE "OriginalFilename", "{APP_NAME}.exe"')
    replace_once(rc, r'VALUE "ProductName", "[^"]*"', f'VALUE "ProductName", "{APP_NAME}"')

    cargo = "Cargo.toml"
    replace_once(cargo, r'(\[package\.metadata\.winres\][^\[]*?)ProductName = "[^"]*"',
                 rf'\g<1>ProductName = "{APP_NAME}"', re.S)
    replace_once(cargo, r'(\[package\.metadata\.winres\][^\[]*?)FileDescription = "[^"]*"',
                 rf'\g<1>FileDescription = "{APP_NAME}"', re.S)

    copy("icon.ico", "res/icon.ico", "res/tray-icon.ico",
         "flutter/windows/runner/resources/app_icon.ico", "flutter/assets/icon.ico")
    copy("icon.png", "res/icon.png", "flutter/assets/icon.png")
    for size in ("32x32.png", "64x64.png", "128x128.png", "128x128@2x.png"):
        copy(size, f"res/{size}")
    for logo in ("logo.png", "logo_light.png", "logo_dark.png"):
        copy(logo, f"flutter/assets/{logo}")

    print(f"brand.py: {APP_NAME} -> {SERVER}")


if __name__ == "__main__":
    main()
