"""Writes .github/workflows/amzdesk.yml from the repository's own flutter-build.yml.

The R-TECH DESK build is the upstream Windows x64 build, unchanged, plus one step that runs
amzdesk/brand.py right after the checkout. It is cut out of flutter-build.yml (not copied by hand),
so the versions it pins (Flutter, vcpkg, Rust, actions) are always the ones of this checkout.
Kept: the environment, the bridge job, the top-most-window helper (x64), the Windows job (x64):
build, portable single-file program, msi (allowed to fail), release named after the app name.
Dropped: arm64, signing, the msi template, update metadata, every other platform.

Run from the repository root: python amzdesk/make_workflow.py
"""
import re
import sys
from pathlib import Path

SOURCE = Path(".github/workflows/flutter-build.yml")
TARGET = Path(".github/workflows/amzdesk.yml")
BRANCH = "amzdesk"
TAG_PLACEHOLDER = "@@TAG@@"
TAG_EXPRESSION = "${{ inputs.app_name || 'R-TECH-DESK' }}"

HEADER = f"""# R-TECH DESK: RustDesk (AGPL-3.0) for Windows x64 with its own name, logo and server built in.
# Made by amzdesk/make_workflow.py from flutter-build.yml; rerun it after syncing with upstream.
# "Run workflow" is the generator: fill the form (or leave the defaults) and the program is
# published under a release named after the app name, about an hour later.
name: R-TECH DESK build (generator)

on:
  workflow_dispatch:
    inputs:
      app_name:
        description: "Technical name: English letters, digits, - and _ only, no spaces (program file, service)"
        default: "R-TECH-DESK"
      display_name:
        description: "Name on the logo and in the file properties (spaces allowed)"
        default: "R-TECH DESK"
      subtitle:
        description: "Second line on the logo (- for none)"
        default: "מעבדה מקצועית למחשבים ולאנדרואיד"
      logo:
        description: "Square picture (PNG/JPG): a path in this repository, or an https address"
        default: "amzdesk/assets/rtech-icon.png"
      company:
        description: "Company in the file properties"
        default: "AMZ Computer Lab"
      server:
        description: "Server address"
        default: "64.176.174.232"
      key:
        description: "Server public key"
        default: "vE0E77BjfekoChLKzFeY+cwM0hCzyv4zSLUDDQtYrsU="
      about:
        description: "Lines in About, separated by | (- for none)"
        default: "פיתוח: א.מ.ז|053-3157965|a0533157965@gmail.com"
      accent:
        description: "Main color, 6 hex digits"
        default: "DC6425"
      maker_logo:
        description: "Maker's small logo next to the name and in About (- for none)"
        default: "amzdesk/assets/logo-source.png"
  push:
    branches:
      - {BRANCH}

permissions:
  contents: write

"""

BRANDING_STEP = """
      - name: Branding (R-TECH DESK generator)
        shell: bash
        env:
          BRAND_APP_NAME: ${{ inputs.app_name }}
          BRAND_DISPLAY_NAME: ${{ inputs.display_name }}
          BRAND_SUBTITLE: ${{ inputs.subtitle }}
          BRAND_LOGO: ${{ inputs.logo }}
          BRAND_COMPANY: ${{ inputs.company }}
          BRAND_SERVER: ${{ inputs.server }}
          BRAND_KEY: ${{ inputs.key }}
          BRAND_ABOUT: ${{ inputs.about }}
          BRAND_ACCENT: ${{ inputs.accent }}
          BRAND_MAKER_LOGO: ${{ inputs.maker_logo }}
          BRAND_SOURCE: ${{ github.server_url }}/${{ github.repository }}
        run: |
          python3 -m pip install --quiet --disable-pip-version-check pillow
          python3 amzdesk/brand.py
"""

RENAME_STEP = """
      - name: File names from the app name
        if: env.UPLOAD_ARTIFACT == 'true'
        shell: bash
        run: |
          cd SignOutput
          for f in rustdesk-*; do mv "$f" "${BRAND_APP_NAME}-${f#rustdesk-}"; done
          ls -l
"""


MSI_LINES = """
          python preprocess.py --arp -d ../../rustdesk --app-name "$env:BRAND_APP_NAME" -m "$env:BRAND_MSI_MANUFACTURER"
"""


RENAME_EXE_LINE = (
    "          # R-TECH DESK: the main program is named after the app (Install starts <app name>.exe)\n"
    "          Move-Item ./rustdesk/rustdesk.exe \"./rustdesk/$($env:BRAND_APP_NAME).exe\""
)


# A quick Dart check of the R-TECH screens (about 5 minutes) before the hour-long Windows build,
# so a mistake there fails early. The @@...@@ are the pinned actions of the Windows job.
DART_CHECK_JOB = """
  dart-check:
    name: Dart check (R-TECH screens)
    needs: [generate-bridge]
    runs-on: ubuntu-22.04
    steps:
      - name: Checkout source code
        uses: @@CHECKOUT@@
      - name: Restore bridge files
        uses: @@DOWNLOAD@@
        with:
          name: bridge-artifact
          path: ./
      - name: Install flutter
        uses: @@FLUTTER@@
        with:
          channel: "stable"
          flutter-version: ${{ env.FLUTTER_VERSION }}
      - name: Patch flutter (as the Windows build does)
        shell: bash
        run: |
          cd $(dirname $(dirname $(which flutter)))
          git apply ${{ github.workspace }}/.github/patches/flutter_3.24.4_dropdown_menu_enableFilter.diff
      - name: Analyze the R-TECH screens
        # Errors and warnings also become annotations, which the public API shows without a login.
        shell: bash
        run: |
          cd flutter
          flutter pub get
          set +e
          flutter analyze --no-fatal-infos --no-fatal-warnings lib/rtech lib/desktop/pages/desktop_home_page.dart lib/common/widgets/dialog.dart > analyze.txt 2>&1
          status=$?
          set -e
          cat analyze.txt
          python3 - <<'PY'
          import re
          pattern = r"\\s*(error|warning) [•-] (.*) [•-] (\\S+?):(\\d+):(\\d+) [•-] (\\S+)\\s*$"
          for line in open("analyze.txt", encoding="utf-8", errors="replace"):
              m = re.match(pattern, line)
              if m:
                  text = m.group(2).replace("%", "%25")
                  print(f"::{m.group(1)} file=flutter/{m.group(3)},line={m.group(4)},col={m.group(5)}::{text} ({m.group(6)})")
          PY
          exit $status
"""


def fail(message: str) -> None:
    sys.exit(f"make_workflow.py: {message}")


def uses_of(block: list[str], action: str) -> str:
    """The pinned "uses:" value of an action in a job, e.g. actions/checkout@<sha> # v4."""
    found = [l.split("uses:", 1)[1].strip() for l in block if l.strip().startswith(f"uses: {action}@")]
    if not found:
        fail(f"no {action} in the Windows job")
    return found[0]


def top_block(lines: list[str], key: str) -> list[str]:
    """A top-level block ("env:") up to the next top-level key."""
    start = next((i for i, l in enumerate(lines) if l.rstrip() == f"{key}:"), None)
    if start is None:
        fail(f"no top-level {key}")
    end = next((i for i in range(start + 1, len(lines)) if lines[i] and not lines[i][0].isspace()
                and not lines[i].startswith("#")), len(lines))
    return lines[start:end]


def job_block(lines: list[str], name: str) -> list[str]:
    """A job under jobs: (two-space key) up to the next job."""
    start = next((i for i, l in enumerate(lines) if l.rstrip() == f"  {name}:"), None)
    if start is None:
        fail(f"no job {name}")
    end = next((i for i in range(start + 1, len(lines)) if re.match(r"^  [A-Za-z0-9_-]+:\s*$", lines[i])),
               len(lines))
    return lines[start:end]


def drop_matrix_entry(block: list[str], marker: str) -> list[str]:
    """Removes the "- { ... }" matrix entry that contains marker."""
    out, i = [], 0
    removed = 0
    while i < len(block):
        if block[i].strip() == "- {":
            j = i
            while block[j].strip() != "}":
                j += 1
            entry = block[i:j + 1]
            if any(marker in l for l in entry):
                removed += 1
            else:
                out.extend(entry)
            i = j + 1
        else:
            out.append(block[i])
            i += 1
    if removed != 1:
        fail(f"expected one matrix entry with {marker}, removed {removed}")
    return out


def drop_step(block: list[str], name: str) -> list[str]:
    """Removes the step "- name: <name>" (up to the next step)."""
    start = next((i for i, l in enumerate(block) if l.strip() == f"- name: {name}"), None)
    if start is None:
        fail(f"no step {name}")
    end = next((i for i in range(start + 1, len(block)) if block[i].startswith("      - ")), len(block))
    return block[:start] + block[end:]


def insert_after(block: list[str], predicate, text: str, what: str) -> list[str]:
    at = next((i for i, l in enumerate(block) if predicate(l)), None)
    if at is None:
        fail(f"no place for {what}")
    return block[:at + 1] + text.strip("\n").split("\n") + block[at + 1:]


def insert_before_step(block: list[str], name: str, text: str) -> list[str]:
    at = next((i for i, l in enumerate(block) if l.strip() == f"- name: {name}"), None)
    if at is None:
        fail(f"no step {name}")
    return block[:at] + text.strip("\n").split("\n") + [""] + block[at:]


def main() -> None:
    lines = SOURCE.read_text(encoding="utf-8").splitlines()

    env = top_block(lines, "env")
    bridge = job_block(lines, "generate-bridge")
    topmost = job_block(lines, "build-RustDeskTempTopMostWindow")
    windows = job_block(lines, "build-for-windows-flutter")

    # Inputs of the reusable workflow become fixed values.
    def fix(block: list[str]) -> list[str]:
        text = "\n".join(block)
        text = text.replace("${{ inputs.upload-tag }}", TAG_PLACEHOLDER)
        text = text.replace("${{ inputs.upload-artifact }}", "true")
        text = text.replace("inputs.upload-artifact", "true")
        text = text.replace("${{ inputs.publish-update-metadata }}", "false")
        text = re.sub(r"^\s*needs: \[validate-update-metadata-keys\]\s*$\n?", "", text, flags=re.M)
        if "inputs." in text:
            fail("an input is still referenced: " + re.search(r".*inputs\..*", text).group(0).strip())
        return text.split("\n")

    env, bridge, topmost, windows = fix(env), fix(bridge), fix(topmost), fix(windows)

    topmost = drop_matrix_entry(topmost, "windows-11-arm")
    windows = drop_matrix_entry(windows, "aarch64-pc-windows-msvc")

    windows = insert_after(windows, lambda l: l.strip() == "submodules: recursive", BRANDING_STEP, "branding")
    for step in ("Build pre-built MSI template", "Upload unsigned msi template"):
        windows = drop_step(windows, step)
    # The msi is a bonus: if its tools do not like the new name, the release still goes out.
    windows = insert_after(windows, lambda l: l.strip() == "- name: Build msi", "        continue-on-error: true", "msi")
    windows = insert_before_step(windows, "Publish Release", RENAME_STEP)
    dart_check = DART_CHECK_JOB.strip("\n")
    for mark, action in (("@@CHECKOUT@@", "actions/checkout"), ("@@DOWNLOAD@@", "actions/download-artifact"),
                         ("@@FLUTTER@@", "subosito/flutter-action")):
        dart_check = dart_check.replace(mark, uses_of(windows, action))
    old_needs = "    needs: [build-RustDeskTempTopMostWindow, generate-bridge]"
    if sum(1 for l in windows if l == old_needs) != 1:
        fail("the Windows job's needs line changed")
    windows = [old_needs[:-1] + ", dart-check]" if l == old_needs else l for l in windows]
    text = "\n".join(windows)
    # The msi gets the app name too. Without it the msi is "RustDesk" by Purslane, with RustDesk's
    # upgrade code: on a computer with RustDesk it stops ("installed by self-installation") or
    # would replace it. preprocess.py looks for <app name>.exe in the folder it packs.
    #
    # The main program is <app name>.exe from the start: "Install" copies the folder and then
    # starts <app name>.exe (src/platform/windows.rs), so with rustdesk.exe it failed with
    # "Windows cannot find ...\R-TECH-DESK.exe".
    old_mv = "          mv ./flutter/build/windows/${{ matrix.job.flutter-arch }}/runner/Release ./rustdesk"
    if text.count(old_mv + "\n") != 1:
        fail("the Build rustdesk step's mv line changed")
    text = text.replace(old_mv + "\n", old_mv + "\n" + RENAME_EXE_LINE + "\n")
    for old, new in (
        ('& ".\\rustdesk\\rustdesk.exe" --version', '& ".\\rustdesk\\$($env:BRAND_APP_NAME).exe" --version'),
        ("-e rustdesk.exe -l 11", '-e "${BRAND_APP_NAME}.exe" -l 11'),
        ("-e ../../rustdesk/rustdesk.exe", '-e "../../rustdesk/${BRAND_APP_NAME}.exe"'),
    ):
        if text.count(old) != 1:
            fail(f"expected one {old!r} in the Windows job")
        text = text.replace(old, new)
    old_msi = "          python preprocess.py --arp -d ../../rustdesk"
    if text.count(old_msi + "\n") != 1:
        fail("the msi step's preprocess line changed")
    text = text.replace(old_msi + "\n", MSI_LINES.strip("\n") + "\n")
    text = text.replace("./SignOutput/rustdesk-*.msi", "./SignOutput/*.msi")
    text = text.replace("./SignOutput/rustdesk-*.exe", "./SignOutput/*.exe")
    windows = text.split("\n")

    env = [l.replace(TAG_PLACEHOLDER, TAG_EXPRESSION) for l in env]
    out = HEADER + "\n".join(env) + "\n\njobs:\n" + "\n".join(bridge) + "\n" + "\n".join(topmost) + "\n" \
        + dart_check + "\n\n" + "\n".join(windows) + "\n"
    TARGET.write_text(out, encoding="utf-8", newline="\n")
    print(f"wrote {TARGET} ({len(out.splitlines())} lines)")


if __name__ == "__main__":
    main()
