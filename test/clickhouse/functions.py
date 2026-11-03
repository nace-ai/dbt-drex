#!/usr/bin/env python3
"""Writes drex-clickhouse's shipped functions config with every command pointed at another base URL.

The functions keep their names, types, format and pool; only `--base-url` is added, so dbt calls what users install.

Run: python3 test/clickhouse/functions.py <drex-clickhouse checkout>/config/drex_function.xml <base URL> <output>
"""

import sys
import xml.etree.ElementTree as ElementTree
from pathlib import Path


def with_base_url(shipped: Path, base_url: str) -> str:
    root = ElementTree.parse(shipped).getroot()
    for command in root.iter("command"):
        if "--base-url" in command.text:
            raise SystemExit(f"{shipped} already names a base URL")
        command.text += f" --base-url {base_url}"
    return ElementTree.tostring(root, encoding="unicode") + "\n"


if __name__ == "__main__":
    shipped, base_url, output = sys.argv[1:]
    Path(output).parent.mkdir(parents=True, exist_ok=True)
    Path(output).write_text(with_base_url(Path(shipped), base_url))
