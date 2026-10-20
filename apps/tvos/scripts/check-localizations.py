#!/usr/bin/env python3
"""Verify that every Localizable.strings key exists in all four languages."""

import json
import re
import sys
from pathlib import Path

RESOURCES = Path(__file__).resolve().parent.parent / "PatreonTV" / "Resources"
LANGUAGES = ["en", "es", "pt-BR", "fr"]
LINE = re.compile(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";$')


def load(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        match = LINE.match(line.strip())
        if not match:
            continue
        key = json.loads(f'"{match.group(1)}"')
        value = json.loads(f'"{match.group(2)}"')
        if key in values:
            raise SystemExit(f"{path}: duplicate key {key!r}")
        values[key] = value
    return values


def main() -> int:
    files = {
        language: RESOURCES / f"{language}.lproj" / "Localizable.strings"
        for language in LANGUAGES
    }
    missing_files = [str(path) for path in files.values() if not path.exists()]
    if missing_files:
        print("Missing localization files:")
        print("\n".join(missing_files))
        return 1

    translations = {language: load(path) for language, path in files.items()}
    all_keys = set().union(*(values.keys() for values in translations.values()))
    failures: list[str] = []

    for language, values in translations.items():
        for key in sorted(all_keys - values.keys()):
            failures.append(f"{language}: missing {key!r}")
        for key, value in values.items():
            if not value.strip():
                failures.append(f"{language}: empty value for {key!r}")

    if failures:
        print("Localization check failed:")
        print("\n".join(failures))
        return 1

    print(f"Localization OK: {len(all_keys)} keys × {len(LANGUAGES)} languages")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
