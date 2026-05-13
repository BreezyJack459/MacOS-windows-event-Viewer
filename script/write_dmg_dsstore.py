#!/usr/bin/env python3
import argparse
import os

from ds_store import DSStore
from mac_alias import Alias


def main() -> None:
    parser = argparse.ArgumentParser(description="Write Finder DMG layout metadata.")
    parser.add_argument("--mount", required=True)
    parser.add_argument("--app-name", required=True)
    parser.add_argument("--background", required=True)
    args = parser.parse_args()

    mount = os.path.abspath(args.mount)
    ds_store_path = os.path.join(mount, ".DS_Store")
    background_path = os.path.abspath(args.background)

    alias_bytes = Alias.for_file(background_path).to_bytes()

    icon_view = {
        "arrangeBy": "none",
        "backgroundImageAlias": alias_bytes,
        "backgroundType": 2,
        "gridOffsetX": 0.0,
        "gridOffsetY": 0.0,
        "gridSpacing": 100.0,
        "iconSize": 96.0,
        "labelOnBottom": True,
        "scrollPositionX": 0.0,
        "scrollPositionY": 0.0,
        "showIconPreview": True,
        "showItemInfo": False,
        "textSize": 13.0,
        "viewOptionsVersion": 1,
    }
    browser_window = {
        "ContainerShowSidebar": False,
        "ShowSidebar": False,
        "ShowStatusBar": False,
        "ShowTabView": False,
        "ShowToolbar": False,
        "WindowBounds": "{{120, 120}, {960, 540}}",
    }

    with DSStore.open(ds_store_path, "w+") as store:
        store["."]["bwsp"] = browser_window
        store["."]["icvp"] = icon_view
        store["."]["vSrn"] = ("long", 1)
        store["Applications"]["Iloc"] = (730, 270)
        store[f"{args.app_name}.app"]["Iloc"] = (230, 270)
        store.flush()


if __name__ == "__main__":
    main()
