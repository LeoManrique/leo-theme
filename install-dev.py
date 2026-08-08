#!/usr/bin/env python3
"""Link this repo's themes into VS Code and Zed for local editing.

VS Code gets a separate "Leo Dark (Dev)" extension rather than an overwrite of
the marketplace install: the store copy is owned by VS Code's own extension
manager, and an auto-update would silently restore the published colors. A
distinct publisher.name also keeps the two out of each other's way in the theme
picker, so the dev build can be compared against the released one.

Zed gets a symlink. A copy goes stale without saying so.

    python3 install-dev.py              # both editors
    python3 install-dev.py --status     # report, change nothing
    python3 install-dev.py --uninstall  # remove what this script created
"""

import argparse
import json
import os
import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent

VSCODE_EXTENSIONS = Path.home() / ".vscode" / "extensions"
ZED_THEMES = Path.home() / ".config" / "zed" / "themes"

DEV_PUBLISHER = "leo-dev"
DEV_NAME = "leo-theme-dev"
DEV_LABEL = "Leo Dark (Dev)"

VSCODE_THEME = "leo-dark-color-theme.json"
ZED_THEME = "leo-dark.json"


def say(status, message):
    print(f"{status:>10}  {message}")


def repo_manifest():
    return json.loads((REPO / "package.json").read_text())


def dev_extension_dirs():
    """Every dev extension this script has ever installed, any version."""
    if not VSCODE_EXTENSIONS.is_dir():
        return []
    prefix = f"{DEV_PUBLISHER}.{DEV_NAME}-"
    return sorted(p for p in VSCODE_EXTENSIONS.iterdir() if p.name.startswith(prefix))


def dev_manifest(source):
    """A standalone manifest for the dev extension.

    Built fresh rather than patched from the repo's so marketplace-only fields
    (publisher, icon, gallery banner) cannot leak into a sideloaded install.
    """
    return {
        "name": DEV_NAME,
        "displayName": DEV_LABEL,
        "description": f"Local dev build of {source['displayName']}. Not for publishing.",
        "version": source["version"],
        "publisher": DEV_PUBLISHER,
        "license": source.get("license", "MIT"),
        "engines": source["engines"],
        "categories": ["Themes"],
        "contributes": {
            "themes": [
                {
                    "label": DEV_LABEL,
                    "uiTheme": "vs-dark",
                    "path": f"./themes/{VSCODE_THEME}",
                }
            ]
        },
    }


def link(target, link_path):
    """Point link_path at target, replacing whatever is there now."""
    if link_path.is_symlink() or link_path.exists():
        if link_path.is_dir() and not link_path.is_symlink():
            shutil.rmtree(link_path)
        else:
            link_path.unlink()
    link_path.parent.mkdir(parents=True, exist_ok=True)
    link_path.symlink_to(target)


def install_vscode():
    if not VSCODE_EXTENSIONS.is_dir():
        say("skip", f"VS Code extensions dir not found at {VSCODE_EXTENSIONS}")
        return False

    source = repo_manifest()
    # Old versions first: the dir name encodes the version, so a version bump
    # would otherwise leave a second dev extension registered alongside.
    for stale in dev_extension_dirs():
        shutil.rmtree(stale)

    ext = VSCODE_EXTENSIONS / f"{DEV_PUBLISHER}.{DEV_NAME}-{source['version']}"
    ext.mkdir(parents=True)
    (ext / "package.json").write_text(json.dumps(dev_manifest(source), indent=2) + "\n")
    link(REPO / "themes", ext / "themes")

    say("linked", f"{ext}  ->  themes/{VSCODE_THEME}")
    return True


def install_zed():
    if not ZED_THEMES.parent.is_dir():
        say("skip", f"Zed config dir not found at {ZED_THEMES.parent}")
        return False

    installed = ZED_THEMES / ZED_THEME
    # A real file here is the user's own copy, not ours. Never drop it silently.
    if installed.exists() and not installed.is_symlink():
        backup = installed.with_suffix(".json.bak")
        shutil.move(str(installed), str(backup))
        say("backed up", f"existing copy -> {backup}")

    link(REPO / "themes" / ZED_THEME, installed)
    say("linked", f"{installed}  ->  themes/{ZED_THEME}")
    return True


def uninstall():
    removed = False
    for ext in dev_extension_dirs():
        shutil.rmtree(ext)
        say("removed", ext)
        removed = True

    installed = ZED_THEMES / ZED_THEME
    if installed.is_symlink():
        installed.unlink()
        say("removed", installed)
        removed = True
    elif installed.exists():
        say("kept", f"{installed} is a real file, not our symlink")

    if not removed:
        say("clean", "nothing installed by this script")


def status():
    marketplace = sorted(VSCODE_EXTENSIONS.glob("leoshell.leo-theme-*")) if VSCODE_EXTENSIONS.is_dir() else []
    for ext in marketplace:
        say("store", f"{ext.name}  (published build, untouched)")

    dev = dev_extension_dirs()
    for ext in dev:
        themes = ext / "themes"
        live = themes.is_symlink() and Path(os.readlink(themes)) == REPO / "themes"
        say("dev" if live else "broken", f"{ext.name}  ->  {os.readlink(themes) if themes.is_symlink() else 'not a symlink'}")
    if not dev:
        say("missing", f'VS Code "{DEV_LABEL}" not installed')

    installed = ZED_THEMES / ZED_THEME
    if installed.is_symlink():
        say("zed", f"{installed}  ->  {os.readlink(installed)}")
    elif installed.exists():
        same = installed.read_bytes() == (REPO / "themes" / ZED_THEME).read_bytes()
        say("copy", f"{installed} is a {'current' if same else 'STALE'} copy, not a symlink")
    else:
        say("missing", f"Zed theme not installed at {installed}")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--vscode", action="store_true", help="VS Code only")
    parser.add_argument("--zed", action="store_true", help="Zed only")
    parser.add_argument("--uninstall", action="store_true", help="remove the dev extension and Zed symlink")
    parser.add_argument("--status", action="store_true", help="report what is installed, change nothing")
    args = parser.parse_args()

    if args.status:
        status()
        return 0

    if args.uninstall:
        uninstall()
        return 0

    both = not (args.vscode or args.zed)
    did_vscode = install_vscode() if (both or args.vscode) else False
    did_zed = install_zed() if (both or args.zed) else False

    print()
    if did_vscode:
        print(f'  VS Code   reload the window, then pick "{DEV_LABEL}" in the theme picker.')
    if did_zed:
        print("  Zed       select Leo Dark; restart Zed if an edit does not show up.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
