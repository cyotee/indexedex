"""Exercise skill discovery migration and preservation in isolated temporary trees."""

import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("sync_codex_skills", Path(__file__).with_name("sync-codex-skills.py"))
skills = importlib.util.module_from_spec(spec)
spec.loader.exec_module(skills)


class SkillCatalogTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.write_skill("testing", "Production-first test workflows.")
        self.write_skill("library-ops", "Library operations.")
        self.write_skill("library", "Library API and operations.", "[Operations](../library-ops/SKILL.md)\n")
        self.catalog = {
            "version": 1,
            "budget": {"max_entries": 5, "max_description_chars": 160, "max_catalog_chars": 14000},
            "direct": {"testing": ".claude/skills/testing"},
            "groups": {"library": {"source": ".claude/skills/library", "topics": {"library-ops": ".claude/skills/library-ops"}}},
        }
        self.save_catalog()

    def write_skill(self, name, description, body="Keep the existing guidance.\n", base=".claude/skills"):
        path = self.root / base / name / "SKILL.md"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(f'---\nname: {name}\ndescription: {json.dumps(description)}\nlicense: MIT\n---\n{body}')
        return path

    def save_catalog(self):
        path = self.root / skills.MANIFEST
        path.parent.mkdir(exist_ok=True)
        path.write_text(json.dumps(self.catalog))

    def link(self, name, base=".claude/skills"):
        path = self.root / skills.DISCOVERY / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.symlink_to(os.path.relpath(self.root / base / name, path.parent), target_is_directory=True)
        return path

    def test_migration_keeps_sources_and_is_idempotent(self):
        old_source = self.write_skill("library-ops", "Older mirror.", base=".opencode/skills")
        self.link("library-ops", ".opencode/skills")
        self.write_skill("testing", "Older test mirror.", base=".opencode/skills")
        self.link("testing", ".opencode/skills")
        original = {p: p.read_bytes() for p in self.root.glob("**/SKILL.md") if not p.is_relative_to(self.root / skills.DISCOVERY)}
        result = skills.sync(self.root)
        self.assertEqual(result["entries"], 2)
        self.assertEqual(result["retained_topics"], 2)
        self.assertFalse((self.root / skills.DISCOVERY / "library-ops").exists())
        self.assertTrue(old_source.exists())
        for path, content in original.items():
            self.assertEqual(path.read_bytes(), content)
        self.assertEqual(skills.sync(self.root)["links_changed"], 0)
        self.assertEqual(skills.sync(self.root, check=True)["links_changed"], 0)

    def test_check_and_stats_never_create_discovery(self):
        self.assertEqual(skills.sync(self.root, stats_only=True)["entries"], 2)
        with self.assertRaisesRegex(ValueError, "need synchronization"):
            skills.sync(self.root, check=True)
        self.assertFalse((self.root / skills.DISCOVERY).exists())

    def test_unknown_entry_blocks_all_changes(self):
        old = self.link("library-ops")
        unknown = self.root / skills.DISCOVERY / "personal-notes"
        unknown.write_text("Preserve me")
        with self.assertRaisesRegex(ValueError, "Unexpected entry"):
            skills.sync(self.root)
        self.assertTrue(old.is_symlink())
        self.assertEqual(unknown.read_text(), "Preserve me")
        self.assertFalse((unknown.parent / "testing").exists())

    def test_real_directory_is_never_replaced(self):
        folder = self.root / skills.DISCOVERY / "testing"
        folder.mkdir(parents=True)
        with self.assertRaisesRegex(ValueError, "non-symlink"):
            skills.sync(self.root)
        self.assertTrue(folder.is_dir())
        self.assertFalse(folder.is_symlink())

    def test_duplicate_legacy_discovery_is_rejected(self):
        self.write_skill("testing", "Legacy description.", base=".codex/skills")
        with self.assertRaisesRegex(ValueError, "Duplicate legacy"):
            skills.sync(self.root)
        self.assertFalse((self.root / skills.DISCOVERY).exists())

    def test_duplicate_name_is_rejected(self):
        path = self.root / ".claude/skills/library/SKILL.md"
        path.write_text(path.read_text().replace("name: library", "name: testing"))
        with self.assertRaisesRegex(ValueError, "Duplicate skill"):
            skills.sync(self.root)

    def test_budgets_include_descriptions_entries_and_paths(self):
        for key in ("max_entries", "max_description_chars", "max_catalog_chars"):
            with self.subTest(key=key):
                old = self.catalog["budget"][key]
                self.catalog["budget"][key] = 1
                self.save_catalog()
                with self.assertRaisesRegex(ValueError, "budget exceeded"):
                    skills.sync(self.root)
                self.catalog["budget"][key] = old
                self.assertFalse((self.root / skills.DISCOVERY).exists())

    def test_missing_topic_or_router_link_is_rejected(self):
        path = self.root / ".claude/skills/library/SKILL.md"
        path.write_text(path.read_text().replace("[Operations](../library-ops/SKILL.md)", ""))
        with self.assertRaisesRegex(ValueError, "does not link topic"):
            skills.sync(self.root)
        (self.root / ".claude/skills/library-ops/SKILL.md").unlink()
        with self.assertRaisesRegex(ValueError, "Missing topic source"):
            skills.sync(self.root)

    def test_new_installed_topic_requires_a_route(self):
        self.write_skill("new-topic", "New functionality.")
        with self.assertRaisesRegex(ValueError, "Add installed skills"):
            skills.sync(self.root)

    def test_external_source_and_discovery_are_rejected(self):
        with tempfile.TemporaryDirectory() as outside:
            self.catalog["direct"]["testing"] = outside
            self.save_catalog()
            with self.assertRaisesRegex(ValueError, "Source outside repository"):
                skills.sync(self.root)
            self.catalog["direct"]["testing"] = ".claude/skills/testing"
            self.save_catalog()
            (self.root / ".agents").symlink_to(outside, target_is_directory=True)
            with self.assertRaisesRegex(ValueError, "Discovery directory must be local"):
                skills.sync(self.root)
            self.assertEqual(list(Path(outside).iterdir()), [])

    def test_folded_metadata_has_actionable_error(self):
        path = self.root / ".claude/skills/testing/SKILL.md"
        path.write_text('---\nname: testing\ndescription: >-\n  A long folded description.\n---\n')
        with self.assertRaisesRegex(ValueError, "one-line description"):
            skills.sync(self.root)
        path.write_text('---\nname: testing\ndescription:\nlicense: MIT\n---\n')
        with self.assertRaisesRegex(ValueError, "Empty description"):
            skills.sync(self.root)


if __name__ == "__main__":
    unittest.main()
