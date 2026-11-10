"""Branding for the RustDesk source tree: the "generator" of R-TECH DESK and of gift versions.

Run from the repository root, before the build. Everything comes from environment variables
(the form of the GitHub workflow fills them; empty means the default):
  BRAND_APP_NAME      technical name: program file, service, folders (letters, digits, - and _)
  BRAND_DISPLAY_NAME  the name written on the logo and in the file properties (spaces allowed)
  BRAND_SUBTITLE      a second line under the name on the logo ("-": none)
  BRAND_COMPANY       "company" in the file properties
  BRAND_LOGO          a square picture (PNG/JPG): a path in this repository or an https address
  BRAND_SERVER        the rendezvous server address
  BRAND_KEY           that server's public key
  BRAND_ABOUT         the lines under "About", separated by | ("-": none)
  BRAND_ACCENT        the main color, 6 hex digits like A9622B
  BRAND_SOURCE        the address of this source code, shown in "About" (AGPL-3.0)
From the one square picture it makes every icon size, the in-app icon and the wide logo.
Every text replacement must match exactly once, or the script stops: a changed upstream file
fails the build loudly instead of producing a half-branded program.

This is RustDesk (https://github.com/rustdesk/rustdesk, AGPL-3.0) with these changes.
"""
import io
import json
import os
import re
import shutil
import sys
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = Path.cwd()

DEFAULTS = {
    "BRAND_APP_NAME": "R-TECH-DESK",
    "BRAND_DISPLAY_NAME": "R-TECH DESK",
    "BRAND_SUBTITLE": "א.מ.ז · מעבדת מחשבים",
    "BRAND_COMPANY": "AMZ Computer Lab",
    "BRAND_LOGO": "amzdesk/assets/logo-source.png",
    "BRAND_SERVER": "64.176.174.232",
    "BRAND_KEY": "vE0E77BjfekoChLKzFeY+cwM0hCzyv4zSLUDDQtYrsU=",
    "BRAND_ABOUT": "פיתוח: א.מ.ז|053-3157965|a0533157965@gmail.com",
    "BRAND_ACCENT": "A9622B",
    "BRAND_SOURCE": "https://github.com/HEB1000/rustdesk",
}


def setting(name: str) -> str:
    value = os.environ.get(name, "").strip()
    return value if value else DEFAULTS[name]


def fail(message: str) -> None:
    sys.exit(f"brand.py: {message}")


# ------------------------------------------------------------------ text changes

def replace_once(path: str, pattern: str, replacement: str, flags: int = 0) -> None:
    file = ROOT / path
    text = file.read_text(encoding="utf-8")
    new, count = re.subn(pattern, lambda m: m.expand(replacement), text, flags=flags)
    if count != 1:
        fail(f"expected 1 match in {path} for {pattern!r}, found {count}")
    file.write_text(new, encoding="utf-8")
    print(f"patched {path}: {pattern}")


def rc_text(value: str) -> str:
    """A value for a .rc string: plain ASCII, no quotes or backslashes."""
    clean = "".join(c for c in value if 32 <= ord(c) < 127 and c not in '"\\')
    return clean.strip() or "R-TECH DESK"


def toml_text(value: str) -> str:
    return value.replace("\\", "").replace('"', "")


def dart_text(value: str) -> str:
    """A Dart string literal: JSON escapes are valid Dart, and $ must not start interpolation."""
    return json.dumps(value, ensure_ascii=False).replace("$", "\\$")


def write_dart_brand(display_name: str, subtitle: str, about: list, source: str, accent: str) -> None:
    """The texts of the R-TECH screens (flutter/lib/rtech/rtech_brand.dart)."""
    path = ROOT / "flutter/lib/rtech/rtech_brand.dart"
    if not path.is_file():
        fail("missing flutter/lib/rtech/rtech_brand.dart")
    lines = "".join(f"  {dart_text(line)},\n" for line in about)
    path.write_text(
        "// R-TECH DESK brand texts, written by amzdesk/brand.py from the generator form.\n"
        "import 'package:flutter/material.dart';\n\n"
        f"const String kRtechDisplayName = {dart_text(display_name)};\n"
        f"const String kRtechSubtitle = {dart_text(subtitle)};\n"
        f"const List<String> kRtechAbout = [\n{lines}];\n"
        f"const String kRtechSource = {dart_text(source)};\n"
        f"const Color kRtechAccent = Color(0xFF{accent});\n",
        encoding="utf-8")
    print(f"wrote flutter/lib/rtech/rtech_brand.dart ({len(about)} About lines, accent {accent})")


# ------------------------------------------------------------------ pictures

def load_logo(source: str):
    from PIL import Image
    if source.startswith("https://"):
        request = urllib.request.Request(source, headers={"User-Agent": "brand.py"})
        with urllib.request.urlopen(request, timeout=60) as response:
            data = response.read()
    elif source.startswith("http://"):
        fail("the logo address must start with https://")
    else:
        path = (ROOT / source).resolve()
        if ROOT.resolve() not in path.parents:
            fail(f"the logo must be inside the repository: {source}")
        data = path.read_bytes()
    image = Image.open(io.BytesIO(data)).convert("RGBA")
    # Not square: centre it on a transparent square, so nothing is stretched.
    side = max(image.size)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.alpha_composite(image, ((side - image.width) // 2, (side - image.height) // 2))
    print(f"logo: {source} ({image.width}x{image.height})")
    return square


def visual_order(text: str) -> str:
    """Right-to-left text for a renderer without a shaping engine: the runs are reversed, and the
    letters inside right-to-left runs too; Latin letters and digits keep their own order."""
    if not any("\u0590" <= c <= "\u05FF" for c in text):
        return text
    runs, current, current_ltr = [], "", None
    for c in text:
        ltr = c.isascii() and c.isalnum()
        neutral = not c.isalnum()
        if neutral or current_ltr is None or ltr == current_ltr:
            current += c
            if not neutral:
                current_ltr = ltr
        else:
            runs.append((current, current_ltr))
            current, current_ltr = c, ltr
    runs.append((current, current_ltr))
    return "".join(run if ltr else run[::-1] for run, ltr in reversed(runs))


def font(size: int, bold: bool):
    from PIL import ImageFont
    candidates = (
        [r"C:\Windows\Fonts\segoeuib.ttf", r"C:\Windows\Fonts\arialbd.ttf"] if bold
        else [r"C:\Windows\Fonts\seguisb.ttf", r"C:\Windows\Fonts\arial.ttf"]
    ) + ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"]
    for path in candidates:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def wide_logo(icon, title: str, subtitle: str, title_color, sub_color):
    """The logo at the top of the main screen: shown at most 300x60, drawn at twice that."""
    from PIL import Image, ImageDraw
    width, height = 600, 120
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    image.alpha_composite(icon.resize((108, 108), Image.LANCZOS), (6, 6))
    draw = ImageDraw.Draw(image)
    room = width - 140
    size = 58
    while size > 26 and draw.textlength(title, font=font(size, True)) > room:
        size -= 2
    if subtitle:
        draw.text((132, 4), title, font=font(size, True), fill=title_color)
        sub = visual_order(subtitle)
        sub_size = 27
        while sub_size > 14 and draw.textlength(sub, font=font(sub_size, False)) > room:
            sub_size -= 1
        draw.text((136, 78), sub, font=font(sub_size, False), fill=sub_color)
    else:
        draw.text((132, (height - size) // 2 - 6), title, font=font(size, True), fill=title_color)
    return image


def make_pictures(logo, display_name: str, subtitle: str, out: Path) -> None:
    from PIL import Image
    out.mkdir(parents=True, exist_ok=True)
    sizes = [16, 20, 24, 32, 40, 48, 64, 128, 256]
    logo.resize((256, 256), Image.LANCZOS).save(out / "icon.ico", sizes=[(s, s) for s in sizes])
    logo.resize((512, 512), Image.LANCZOS).save(out / "icon.png")
    for name, size in [("32x32.png", 32), ("64x64.png", 64), ("128x128.png", 128), ("128x128@2x.png", 256)]:
        logo.resize((size, size), Image.LANCZOS).save(out / name)
    brown, cream = (168, 97, 42, 255), (250, 238, 220, 255)
    muted_light, muted_dark = (122, 106, 85, 255), (226, 205, 176, 255)
    title = visual_order(display_name)
    wide_logo(logo, title, subtitle, brown, muted_light).save(out / "logo.png")
    wide_logo(logo, title, subtitle, brown, muted_light).save(out / "logo_light.png")
    wide_logo(logo, title, subtitle, cream, muted_dark).save(out / "logo_dark.png")


def copy(folder: Path, asset: str, *targets: str) -> None:
    for target in targets:
        dst = ROOT / target
        if not dst.parent.is_dir():
            fail(f"missing folder for {target}")
        shutil.copyfile(folder / asset, dst)
        print(f"copied {asset} -> {target}")


# ------------------------------------------------------------------ main

def main() -> None:
    app_name = setting("BRAND_APP_NAME")
    display_name = setting("BRAND_DISPLAY_NAME")
    subtitle = setting("BRAND_SUBTITLE")
    if subtitle == "-":
        subtitle = ""   # "-" in the form: no second line on the logo
    company = setting("BRAND_COMPANY")
    server = setting("BRAND_SERVER")
    key = setting("BRAND_KEY")

    # The name goes into service commands, folder names and a link scheme unquoted, so RustDesk
    # allows only letters, digits, "-" and "_" (src/platform/mod.rs).
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{1,31}", app_name):
        fail(f"app name {app_name!r}: only English letters, digits, - and _ (2-32 characters, no spaces)")
    if app_name == "RustDesk":
        fail("the app name must differ from RustDesk")
    if not re.fullmatch(r"[A-Za-z0-9.:-]+", server):
        fail(f"server {server!r} is not an address")
    if not re.fullmatch(r"[A-Za-z0-9+/=]{40,60}", key):
        fail("the server key does not look like a RustDesk key (44 base64 characters)")
    about_text = setting("BRAND_ABOUT")
    about = [] if about_text == "-" else [x.strip() for x in about_text.split("|") if x.strip()]
    accent = setting("BRAND_ACCENT").lstrip("#").upper()
    if not re.fullmatch(r"[0-9A-F]{6}", accent):
        fail(f"color {accent!r}: 6 hex digits, like A9622B")
    source = setting("BRAND_SOURCE")
    if not re.fullmatch(r"https://[A-Za-z0-9./_~:-]+", source):
        fail(f"source address {source!r} must be an https:// address")

    config = "libs/hbb_common/src/config.rs"
    replace_once(config, r'(APP_NAME: RwLock<String> = RwLock::new\(")RustDesk("\.to_owned\(\)\))',
                 r"\g<1>" + app_name + r"\g<2>")
    replace_once(config, r'pub const RENDEZVOUS_SERVERS: &\[&str\] = &\[[^\]]*\];',
                 f'pub const RENDEZVOUS_SERVERS: &[&str] = &["{server}"];')
    replace_once(config, r'pub const RS_PUB_KEY: &str = "[^"]*";', f'pub const RS_PUB_KEY: &str = "{key}";')

    shown = rc_text(display_name)
    rc = "flutter/windows/runner/Runner.rc"
    replace_once(rc, r'VALUE "CompanyName", "[^"]*"', f'VALUE "CompanyName", "{rc_text(company)}"')
    replace_once(rc, r'VALUE "FileDescription", "[^"]*"', f'VALUE "FileDescription", "{shown}"')
    replace_once(rc, r'VALUE "InternalName", "[^"]*"', f'VALUE "InternalName", "{app_name.lower()}"')
    replace_once(rc, r'VALUE "OriginalFilename", "[^"]*"', f'VALUE "OriginalFilename", "{app_name}.exe"')
    replace_once(rc, r'VALUE "ProductName", "[^"]*"', f'VALUE "ProductName", "{shown}"')

    cargo = "Cargo.toml"
    replace_once(cargo, r'(\[package\.metadata\.winres\][^\[]*?)ProductName = "[^"]*"',
                 r'\g<1>ProductName = "' + toml_text(shown) + '"', re.S)
    replace_once(cargo, r'(\[package\.metadata\.winres\][^\[]*?)FileDescription = "[^"]*"',
                 r'\g<1>FileDescription = "' + toml_text(shown) + '"', re.S)

    # The program people download is a small self-extracting wrapper with its own file properties
    # (its icon already comes from res/icon.ico).
    portable = "libs/portable/Cargo.toml"
    replace_once(portable, r'(\[package\.metadata\.winres\][^\[]*?)ProductName = "[^"]*"',
                 r'\g<1>ProductName = "' + toml_text(shown) + '"', re.S)
    replace_once(portable, r'(\[package\.metadata\.winres\][^\[]*?)FileDescription = "[^"]*"',
                 r'\g<1>FileDescription = "' + toml_text(shown) + '"', re.S)
    replace_once(portable, r'(\[package\.metadata\.winres\][^\[]*?)OriginalFilename = "[^"]*"',
                 r'\g<1>OriginalFilename = "' + app_name + '.exe"', re.S)

    # The R-TECH screens and RustDesk's own screens (buttons, links, switches) in the main color.
    write_dart_brand(display_name, subtitle, about, source, accent)
    theme = "flutter/lib/common.dart"
    replace_once(theme, r"(static const Color accent = )Color\(0xFF0071FF\);",
                 r"\g<1>Color(0xFF" + accent + ");")
    replace_once(theme, r"(static const Color accent50 = )Color\(0x770071FF\);",
                 r"\g<1>Color(0x77" + accent + ");")
    replace_once(theme, r"(static const Color accent80 = )Color\(0xAA0071FF\);",
                 r"\g<1>Color(0xAA" + accent + ");")

    pictures = ROOT / "target" / "brand-pictures"
    make_pictures(load_logo(setting("BRAND_LOGO")), display_name, subtitle, pictures)
    copy(pictures, "icon.ico", "res/icon.ico", "res/tray-icon.ico",
         "flutter/windows/runner/resources/app_icon.ico", "flutter/assets/icon.ico")
    copy(pictures, "icon.png", "res/icon.png", "flutter/assets/icon.png")
    for size in ("32x32.png", "64x64.png", "128x128.png", "128x128@2x.png"):
        copy(pictures, size, f"res/{size}")
    for logo in ("logo.png", "logo_light.png", "logo_dark.png"):
        copy(pictures, logo, f"flutter/assets/{logo}")

    # For the next steps of the workflow (file names, release tag).
    if "GITHUB_ENV" in os.environ:
        with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as env:
            env.write(f"BRAND_APP_NAME={app_name}\n")
    print(f"brand.py: {app_name} ({display_name}) -> {server}")


if __name__ == "__main__":
    main()
