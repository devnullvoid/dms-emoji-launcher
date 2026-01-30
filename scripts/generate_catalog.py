#!/usr/bin/env python3
"""Builds the catalog.js bundle from the plain-text data sources."""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
OUTPUT = ROOT / "catalog.js"


def main() -> None:
    emoji_entries = parse_emoji(DATA / "emojis.txt")
    unicode_entries = parse_unicode(DATA / "math.txt")
    nerd_font_entries = parse_nerdfont(DATA / "nerdfont.txt")
    latin_extended_entries = parse_latin_extended(DATA / "latin-extended.txt")

    write_catalog(
        emoji_entries=emoji_entries,
        unicode_entries=unicode_entries,
        nerd_font_entries=nerd_font_entries,
        latin_extended_entries=latin_extended_entries,
    )


def parse_emoji(path: Path) -> list[dict]:
    return _parse_symbol_file(
        path,
        key_name="emoji",
        extra_keywords=lambda raw: [],
    )


def parse_unicode(path: Path) -> list[dict]:
    return _parse_symbol_file(
        path,
        key_name="char",
        extra_keywords=lambda raw: [],
    )


def parse_latin_extended(path: Path) -> list[dict]:
    """Parse Latin extended file with language-specific keywords."""
    text = path.read_text(encoding="utf-8")
    entries: list[dict] = []
    current_language = None

    # Map comment patterns to language keywords
    language_map = {
        "spanish": ["spanish", "español"],
        "french": ["french", "français"],
        "portuguese": ["portuguese", "português"],
        "german": ["german", "deutsch"],
        "nordic": ["nordic", "scandinavian"],
        "italian": ["italian", "italiano"],
        "icelandic": ["icelandic"],
        "czech": ["czech", "slovak"],
        "polish": ["polish", "polski"],
        "romanian": ["romanian"],
        "hungarian": ["hungarian", "magyar"],
        "turkish": ["turkish", "türk"],
        "esperanto": ["esperanto"],
        "vietnamese": ["vietnamese"],
    }

    for raw_line in text.splitlines():
        if not raw_line:
            continue
        trimmed = raw_line.strip()

        # Track current language section from comments
        if trimmed.startswith("#"):
            comment_lower = trimmed.lower()
            for lang_key, lang_keywords in language_map.items():
                if lang_key in comment_lower:
                    current_language = lang_keywords
                    break
            continue

        if not trimmed:
            continue

        match = re.match(r"^(\S+|\s)\s+(.*)$", raw_line)
        if not match:
            continue

        symbol = match.group(1)
        raw_name = match.group(2).strip()

        if not raw_name or ".." in symbol:
            continue

        friendly = prettify_name(raw_name)

        # Build keywords with language context
        extra = ["latin", "accented"]
        if current_language:
            extra.extend(current_language)

        keywords = build_keywords(raw_name, extra)

        entry = {
            "char": symbol,
            "name": friendly,
            "keywords": keywords,
        }
        entries.append(entry)

    return entries


def parse_nerdfont(path: Path) -> list[dict]:
    def extra_keywords(raw: str) -> list[str]:
        extras = ["nerdfont", raw]
        if raw.startswith("ple-"):
            extras.extend(["powerline", "ple"])
        return extras

    entries = _parse_symbol_file(
        path,
        key_name="char",
        preprocess_name=lambda name: re.sub(r"[_-]+", " ", name).strip(),
        extra_keywords=extra_keywords,
    )

    for entry in entries:
        name = entry.get("name", "")
        if name.startswith("Ple "):
            entry["name"] = "Powerline " + name[4:]

    return entries


def _parse_symbol_file(
    path: Path,
    *,
    key_name: str,
    preprocess_name=lambda name: name,
    extra_keywords=lambda raw: [],
) -> list[dict]:
    text = path.read_text(encoding="utf-8")
    entries: list[dict] = []

    for raw_line in text.splitlines():
        if not raw_line:
            continue
        trimmed = raw_line.strip()
        if not trimmed or trimmed.startswith("#"):
            continue

        match = re.match(r"^(\S+|\s)\s+(.*)$", raw_line)
        if not match:
            continue

        symbol = match.group(1)
        raw_name = match.group(2).strip()

        if not raw_name or ".." in symbol:
            continue

        cleaned_name = preprocess_name(raw_name) or raw_name
        friendly = prettify_name(cleaned_name)
        keywords = build_keywords(cleaned_name, extra_keywords(raw_name))

        entry = {
            key_name: symbol,
            "name": friendly,
            "keywords": keywords,
        }
        entries.append(entry)

    return entries


def prettify_name(raw: str) -> str:
    tokens = [token for token in re.split(r"\s+", raw) if token]
    return " ".join(token.capitalize() for token in tokens)


def build_keywords(raw: str, extras: list[str]) -> list[str]:
    seen: set[str] = set()
    keywords: list[str] = []

    def add_token(token: str) -> None:
        lowered = token.lower()
        if lowered and lowered not in seen:
            seen.add(lowered)
            keywords.append(lowered)

    def tokenize(value: str) -> list[str]:
        # Keep Unicode letters (including accented), numbers, and +
        return [part for part in re.split(r"[^\w+]+", value.lower(), flags=re.UNICODE) if part]

    for token in tokenize(raw):
        add_token(token)

    for extra in extras:
        for token in tokenize(extra):
            add_token(token)

    return keywords


def write_catalog(*, emoji_entries, unicode_entries, nerd_font_entries, latin_extended_entries) -> None:
    OUTPUT.write_text(
        "\n".join(
            [
                "// Auto-generated by scripts/generate_catalog.py",
                "// Do not edit manually.",
                ".pragma library",
                "",
                f"var emojiEntries = {json.dumps(emoji_entries, ensure_ascii=False)};",
                f"var unicodeEntries = {json.dumps(unicode_entries, ensure_ascii=False)};",
                f"var nerdFontEntries = {json.dumps(nerd_font_entries, ensure_ascii=False)};",
                f"var latinExtendedEntries = {json.dumps(latin_extended_entries, ensure_ascii=False)};",
                "",
                "function clone(array) {",
                "    return array ? array.slice() : [];",
                "}",
                "",
                "function getEmojiEntries() { return clone(emojiEntries); }",
                "function getUnicodeEntries() { return clone(unicodeEntries); }",
                "function getNerdFontEntries() { return clone(nerdFontEntries); }",
                "function getLatinExtendedEntries() { return clone(latinExtendedEntries); }",
            ]
        )
        + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
