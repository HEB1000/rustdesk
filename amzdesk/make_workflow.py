"""Writes .github/workflows/amzdesk.yml from the repository's own flutter-build.yml.

The AMZDesk build is the upstream Windows x64 build, unchanged, plus one step that runs
amzdesk/brand.py right after the checkout. It is cut out of flutter-build.yml (not copied by hand),
so the versions it pins (Flutter, vcpkg, Rust, actions) are always the ones of this checkout.
Kept: the environment, the bridge job, the top-most-window helper (x64), the Windows job (x64):
build, portable single-file program, msi (allowed to fail), release under the tag "amzdesk".
Dropped: arm64, signing, the msi template, update metadata, every other platform.

Run from the repository root: python amzdesk/make_workflow.py
"""
import re
import sys
from pathlib import Path

SOURCE = Path(".github/workflows/flutter-build.yml")
TARGET = Path(".github/workflows/amzdesk.yml")
TAG = "amzdesk"

HEADER = f"""# AMZDesk: RustDesk (AGPL-3.0) for Windows x64 with the a.m.z branding and server built in.
# Made by amzdesk/make_workflow.py from flutter-build.yml; rerun it after syncing with upstream.
name: AMZDesk Windows build

on:
  workflow_dispatch:
  push:
    branches:
      - {TAG}

permissions:
  contents: write

"""

BRANDING_STEP = """
      - name: AMZDesk branding
        shell: bash
        run: python3 amzdesk/brand.py
"""

RENAME_STEP = """
      - name: AMZDesk file names
        if: env.UPLOAD_ARTIFACT == 'true'
        shell: bash
        run: |
          cd SignOutput
          for f in rustdesk-*; do mv "$f" "AMZDesk-${f#rustdesk-}"; done
          ls -l
"""


def fail(message: str) -> None:
    sys.exit(f"make_workflow.py: {message}")


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
        text = text.replace("${{ inputs.upload-tag }}", TAG)
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
    text = "\n".join(windows)
    text = text.replace("./SignOutput/rustdesk-*.msi", "./SignOutput/AMZDesk-*.msi")
    text = text.replace("./SignOutput/rustdesk-*.exe", "./SignOutput/AMZDesk-*.exe")
    windows = text.split("\n")

    out = HEADER + "\n".join(env) + "\n\njobs:\n" + "\n".join(bridge) + "\n" + "\n".join(topmost) + "\n" \
        + "\n".join(windows) + "\n"
    TARGET.write_text(out, encoding="utf-8", newline="\n")
    print(f"wrote {TARGET} ({len(out.splitlines())} lines)")


if __name__ == "__main__":
    main()
