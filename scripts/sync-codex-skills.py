#!/usr/bin/env python3
"""Maintain the compact Codex skill catalog and its canonical discovery links."""

import argparse
import json
import os
import re
from pathlib import Path

MANIFEST = Path("scripts/codex-skill-catalog.json")
DISCOVERY = Path(".agents/skills")
SOURCE_ROOTS = (".claude/skills", ".opencode/skills", ".grok/skills", "lib/crane/.claude/skills")


def metadata(path):
    """Read the catalog's one-line YAML name/description scalars, without dependencies."""
    parts = path.read_text().split("---", 2)
    if len(parts) != 3 or parts[0].strip():
        raise ValueError(f"Missing frontmatter: {path}")
    fields = {}
    for field in ("name", "description"):
        match = re.search(rf"^{field}:[ \t]*([^\n]*)$", parts[1], re.MULTILINE)
        if not match:
            raise ValueError(f"Missing {field}: {path}")
        value = match.group(1).strip()
        if value.startswith('"'):
            value = json.loads(value)
        elif value.startswith("'") and value.endswith("'"):
            value = value[1:-1].replace("''", "'")
        elif value.startswith((">", "|")):
            raise ValueError(f"Use a concise, one-line {field} in discoverable skill: {path}")
        if not isinstance(value, str) or not value.strip():
            raise ValueError(f"Empty {field}: {path}")
        fields[field] = value
    return fields


def source_path(root, name, relative):
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,63}", name):
        raise ValueError(f"Invalid catalog key: {name}")
    path = root / relative
    if Path(relative).is_absolute() or not path.resolve().is_relative_to(root.resolve()):
        raise ValueError(f"Source outside repository: {relative}")
    if not (path / "SKILL.md").is_file():
        raise ValueError(f"Missing topic source: {relative}/SKILL.md")
    return path


def load_catalog(root):
    catalog = json.loads((root / MANIFEST).read_text())
    if catalog["version"] != 1:
        raise ValueError("Unsupported catalog version")
    entries = dict(catalog["direct"])
    topics = dict(catalog["direct"])
    for name, group in catalog["groups"].items():
        if name in entries:
            raise ValueError(f"Duplicate discovery entry: {name}")
        entries[name] = group["source"]
        body = (source_path(root, name, group["source"]) / "SKILL.md").read_text()
        for topic, relative in group["topics"].items():
            if topic in topics:
                raise ValueError(f"Topic assigned more than once: {topic}")
            topics[topic] = relative
            topic_path = source_path(root, topic, relative)
            link = os.path.relpath(topic_path / "SKILL.md", root / group["source"])
            if f"]({link})" not in body:
                raise ValueError(f"Router {name} does not link topic {topic}")
    for name, relative in topics.items():
        source_path(root, name, relative)
    # New installed skills must get an explicit route; never silently grow the catalog.
    installed = {p.parent.name for p in (root / ".claude/skills").glob("*/SKILL.md")
                 if not p.parent.name.endswith(" copy")}
    unclassified = installed - entries.keys() - topics.keys()
    if unclassified:
        raise ValueError(f"Add installed skills to {MANIFEST}: {', '.join(sorted(unclassified))}")

    records = []
    seen_names = set()
    seen_sources = set()
    for name, relative in sorted(entries.items()):
        path = source_path(root, name, relative)
        fields = metadata(path / "SKILL.md")
        key = fields["name"].casefold()
        if key in seen_names or path.resolve() in seen_sources:
            raise ValueError(f"Duplicate skill name or canonical source: {name}")
        seen_names.add(key)
        seen_sources.add(path.resolve())
        records.append({"key": name, "source": path, **fields})
    rendered = "\n".join(
        f"- {r['name']}: {r['description']} (file: {root / DISCOVERY / r['key'] / 'SKILL.md'})"
        for r in records
    )
    stats = {"entries": len(records), "retained_topics": len(topics),
             "description_chars": sum(len(r["description"]) for r in records),
             "catalog_chars": len(rendered)}
    budget = catalog["budget"]
    if stats["entries"] > budget["max_entries"]:
        raise ValueError(f"Catalog entry budget exceeded: {stats['entries']} > {budget['max_entries']}")
    if stats["catalog_chars"] > budget["max_catalog_chars"]:
        raise ValueError(f"Catalog character budget exceeded: {stats['catalog_chars']} > {budget['max_catalog_chars']}")
    for record in records:
        if len(record["description"]) > budget["max_description_chars"]:
            raise ValueError(f"Description budget exceeded: {record['key']}")
    return records, topics, stats


def check_duplicates(root, records):
    names = {r["name"].casefold() for r in records}
    keys = {r["key"] for r in records}
    for path in sorted((root / ".codex/skills").glob("*/SKILL.md")):
        # Directory identity also catches old, long or folded duplicate metadata.
        if path.parent.name in keys or metadata(path)["name"].casefold() in names:
            raise ValueError(f"Duplicate legacy discovery entry: {path}")
        raise ValueError(f"Unbudgeted legacy discovery entry; register under .agents/skills: {path}")


def plan_links(root, records, topics):
    destination = root / DISCOVERY
    # A symlinked discovery root could redirect writes outside this repository.
    if destination.is_symlink() or not destination.resolve().is_relative_to(root.resolve()):
        raise ValueError(f"Discovery directory must be local: {destination}")
    expected = {r["key"]: os.path.relpath(r["source"], destination) for r in records}
    changes = []
    if destination.exists():
        for link in sorted(destination.iterdir()):
            name = link.name
            if name not in expected and name not in topics:
                raise ValueError(f"Unexpected entry (left untouched): {link}")
            if not link.is_symlink():
                raise ValueError(f"Conflicting non-symlink (left untouched): {link}")
            target = link.resolve()
            allowed = {(root / base / name).resolve() for base in SOURCE_ROOTS}
            if not target.is_relative_to(root.resolve()) or target not in allowed:
                raise ValueError(f"Unrecognized link target (left untouched): {link}")
            if name not in expected:
                changes.append((link, None))
    for name, target in sorted(expected.items()):
        link = destination / name
        if not link.is_symlink() or os.readlink(link) != target:
            changes.append((link, target))
    return changes


def sync(root, check=False, stats_only=False):
    records, topics, stats = load_catalog(root)
    if stats_only:
        return stats
    check_duplicates(root, records)
    changes = plan_links(root, records, topics)
    if check and changes:
        detail = "\n".join(f"{path}: {'retire link' if target is None else target}" for path, target in changes)
        raise ValueError(f"Discovery links need synchronization:\n{detail}")
    if not check:
        destination = root / DISCOVERY
        destination.mkdir(parents=True, exist_ok=True)
        for link, target in changes:
            # All destinations were validated before any mutation; only symlinks change.
            if link.is_symlink():
                link.unlink()
            if target is not None:
                link.symlink_to(target, target_is_directory=True)
    return {**stats, "links_changed": len(changes)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true", help="Validate budgets, topics, duplicates and links without writing")
    mode.add_argument("--stats", action="store_true", help="Report planned repository catalog size without writing")
    args = parser.parse_args()
    try:
        result = sync(Path(__file__).resolve().parent.parent, check=args.check, stats_only=args.stats)
    except (ValueError, KeyError, OSError) as error:
        raise SystemExit(str(error)) from error
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
