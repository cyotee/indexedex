"""Check artifact build planning without invoking a compiler or using real caches."""

import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch


spec = importlib.util.spec_from_file_location("forge_artifacts", Path(__file__).with_name("forge-artifacts.py"))
artifacts = importlib.util.module_from_spec(spec)
spec.loader.exec_module(artifacts)


class ArtifactPlanTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.config = {"src": "contracts", "out": "out", "test": "test/foundry/spec",
                       "remappings": ["@dep/=lib/dep/", "@dep/special/=lib/special/"]}

    def write(self, path, source):
        file = self.root / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(source)

    def graph(self):
        return artifacts.SourceGraph(self.root, self.config)

    def target_facet(self):
        self.write("contracts/Target.sol", "abstract contract Target {}")
        self.write("contracts/Facet.sol", 'import {Target} from "./Target.sol"; contract Facet is Target {}')

    def test_target_change_builds_concrete_descendants_without_test_roots(self):
        self.target_facet()
        self.write("contracts/test/TestBase.sol", 'import {Facet} from "contracts/Facet.sol"; abstract contract TestBase {}')
        self.write("test/foundry/spec/Facet.t.sol", 'import "contracts/test/TestBase.sol"; contract FacetTest {}')
        plan = self.graph().plan(["contracts/Target.sol"])
        self.assertEqual(plan["roots"], ["contracts/Facet.sol", "contracts/Target.sol"])
        self.assertEqual(plan["impact"][0]["hermetic_dependents"], 1)

    def test_runtime_artifact_has_no_compile_dependency_but_consumer_seeds_it(self):
        self.target_facet()
        self.write("contracts/Deploy.sol", 'library Deploy { string constant ID = "Facet.sol:Facet"; }')
        self.write("test/foundry/spec/Facet.t.sol", 'import "contracts/Deploy.sol"; contract FacetTest {}')
        graph = self.graph()
        self.assertEqual(graph.impact("contracts/Target.sol")["hermetic_dependents"], 0)
        plan = graph.plan([], ["test/foundry/spec/Facet.t.sol"])
        self.assertEqual(plan["roots"], ["contracts/Facet.sol"])
        self.assertIn("Facet.sol:Facet", plan["runtime_artifacts"])

    def test_current_imports_override_stale_foundry_cache(self):
        self.target_facet()
        self.write("cache_forge/solidity-files-cache.json", json.dumps({"bogus": {"imports": ["contracts/Target.sol"]}}))
        self.write("contracts/Deploy.sol", 'library Deploy { string constant ID = "Facet.sol:Facet"; }')
        plan = self.graph().plan(["contracts/Target.sol"])
        self.assertNotIn("contracts/Deploy.sol", plan["roots"])

    def test_nested_runtime_artifact_and_external_library_are_included(self):
        self.write("contracts/Deploy.sol", 'library Deploy { string constant ID = "Facet.sol:Facet"; }')
        self.write("contracts/Facet.sol", 'contract Facet { string constant ID = "@dep/Nested.sol:Nested"; }')
        self.write("lib/dep/Nested.sol", 'import "./Math.sol"; contract Nested {}')
        self.write("lib/dep/Math.sol", 'library Math {}')
        self.write("out/Facet.sol/Facet.json", json.dumps({"bytecode": {"linkReferences": {"lib/dep/Math.sol": {"Math": [{"start": 1, "length": 20}]}}}}))
        plan = self.graph().plan(["contracts/Deploy.sol"])
        self.assertEqual(set(plan["roots"]), {"contracts/Deploy.sol", "contracts/Facet.sol", "lib/dep/Nested.sol", "lib/dep/Math.sol"})
        self.assertIn("lib/dep/Math.sol:Math", plan["runtime_artifacts"])

    def test_missing_library_artifact_compiles_from_source_dependency(self):
        self.write("contracts/Deploy.sol", 'library Deploy { string constant ID = "Facet.sol:Facet"; }')
        self.write("contracts/Facet.sol", 'import "@dep/Math.sol"; contract Facet {}')
        self.write("lib/dep/Math.sol", "library Math {}")
        graph = self.graph()
        plan = graph.plan(["contracts/Deploy.sol"])
        self.assertIn("lib/dep/Math.sol", graph.closure(plan["roots"]))
        self.assertFalse((self.root / "out").exists())

    def test_longest_remapping_and_relative_imports(self):
        self.write("contracts/Facet.sol", 'import "@dep/special/Target.sol"; contract Facet {}')
        self.write("lib/special/Target.sol", 'import "./Math.sol"; abstract contract Target {}')
        self.write("lib/special/Math.sol", "library Math {}")
        graph = self.graph()
        self.assertEqual(graph.forward["contracts/Facet.sol"], {"lib/special/Target.sol"})
        self.assertEqual(graph.forward["lib/special/Target.sol"], {"lib/special/Math.sol"})

    def test_ambiguous_short_id_fails_and_qualified_id_succeeds(self):
        self.write("contracts/a/Facet.sol", "contract Facet {}")
        self.write("contracts/b/Facet.sol", "contract Facet {}")
        graph = self.graph()
        with self.assertRaisesRegex(ValueError, "resolves to 2 sources"):
            graph.resolve_artifact("Facet.sol:Facet")
        self.assertEqual(graph.resolve_artifact("contracts/a/Facet.sol:Facet"), "contracts/a/Facet.sol")

    def test_unresolved_selected_import_fails_before_compilation(self):
        self.write("contracts/Facet.sol", 'import "@missing/Target.sol"; contract Facet {}')
        with self.assertRaisesRegex(ValueError, "Unresolved imports"):
            self.graph().plan(["contracts/Facet.sol"])

    def test_comments_do_not_add_edges_and_audit_preserves_line_numbers(self):
        self.write("contracts/Deploy.sol", '// import "missing.sol";\n/*\n type(Missing).creationCode\n*/\nlibrary Deploy { bytes value = type(Actual).creationCode; }')
        graph = self.graph()
        self.assertFalse(graph.unresolved)
        audit = graph.audit([])
        self.assertEqual(audit["creation_code"], [{"path": "contracts/Deploy.sol", "line": 5,
                                                  "contract": "Actual", "exception": None}])

    def test_audit_detects_import_that_reconnects_runtime_artifact(self):
        self.target_facet()
        self.write("contracts/Deploy.sol", 'import "contracts/Facet.sol"; library Deploy { string constant ID = "Facet.sol:Facet"; }')
        findings = self.graph().audit([])["artifact_implementation_imports"]
        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0]["import"], "contracts/Facet.sol")

    def test_all_artifacts_seeds_helpers_without_negative_test_strings(self):
        self.target_facet()
        self.write("contracts/Deploy.sol", 'library Deploy { string constant ID = "Facet.sol:Facet"; }')
        self.write("test/foundry/spec/Negative.t.sol", 'contract Negative { string constant ID = "Missing.sol:Missing"; }')
        plan = self.graph().plan([], all_artifacts=True)
        self.assertEqual(plan["roots"], ["contracts/Facet.sol"])

    def test_runtime_artifact_under_scripts_is_rebuilt_when_edited(self):
        self.write("scripts/foundry/Deploy.s.sol", 'contract Deploy { string constant ID = "Seeder.sol:Seeder"; }')
        self.write("scripts/foundry/shared/Seeder.sol", "contract Seeder {}")
        plan = self.graph().plan(["scripts/foundry/shared/Seeder.sol"])
        self.assertEqual(plan["roots"], ["scripts/foundry/shared/Seeder.sol"])

    def test_exact_test_file_scope_does_not_expand_to_sibling_tests(self):
        self.target_facet()
        self.write("test/foundry/spec/Selected.t.sol", 'contract Selected { string constant ID = "Facet.sol:Facet"; }')
        self.write("test/foundry/spec/Unrelated.t.sol", "contract Unrelated {}")
        plan = artifacts.test_plan(self.graph(), ["contracts/Target.sol"],
                                   "test/foundry/spec/Selected.t.sol", forge_args=["-vv"])
        self.assertEqual(plan["test_files"], ["test/foundry/spec/Selected.t.sol"])
        self.assertEqual(plan["test_command"], ["forge", "test", "-vv", "--skip", "contracts/**",
                                                "--skip", "test/foundry/spec/Unrelated.t.sol"])
        self.assertNotIn("test_environment", plan)
        self.assertIn("contracts/Facet.sol", plan["roots"])

    def test_test_directory_scope_includes_only_descendant_tests(self):
        self.write("test/foundry/spec/a/One.t.sol", "contract One {}")
        self.write("test/foundry/spec/a/sub/Two.t.sol", "contract Two {}")
        self.write("test/foundry/spec/b/Other.t.sol", "contract Other {}")
        plan = artifacts.test_plan(self.graph(), [], "test/foundry/spec/a")
        self.assertEqual(plan["test_files"], ["test/foundry/spec/a/One.t.sol", "test/foundry/spec/a/sub/Two.t.sol"])
        self.assertEqual(plan["command"], [])  # No runtime artifacts or production edits need a separate build.
        self.assertEqual(plan["test_skip_patterns"], ["test/foundry/spec/b/**"])

    def test_negative_loader_test_prepares_explicit_real_sources(self):
        self.write("contracts/Fixture.sol", "contract Fixture {}")
        self.write("test/foundry/spec/Negative.t.sol", 'contract Negative { string constant ID = "Missing.sol:Missing"; }')
        graph = self.graph()
        with self.assertRaisesRegex(ValueError, "resolves to 0 sources"):
            artifacts.test_plan(graph, ["contracts/Fixture.sol"], "test/foundry/spec/Negative.t.sol")
        plan = artifacts.test_plan(graph, ["contracts/Fixture.sol"], "test/foundry/spec/Negative.t.sol",
                                   no_consumer_artifacts=True)
        self.assertEqual(plan["roots"], ["contracts/Fixture.sol"])
        with self.assertRaisesRegex(ValueError, "requires explicit"):
            artifacts.test_plan(graph, [], "test/foundry/spec/Negative.t.sol", no_consumer_artifacts=True)

    def test_test_scope_cannot_cross_active_profile_root(self):
        self.write("test/foundry/fork/Fork.t.sol", "contract Fork {}")
        with self.assertRaisesRegex(ValueError, "outside the active profile"):
            artifacts.test_plan(self.graph(), [], "test/foundry/fork/Fork.t.sol")

    def test_imported_external_test_file_adds_execution_filter(self):
        self.write("test/foundry/spec/Selected.t.sol", 'import "./Other.t.sol"; contract Selected {}')
        self.write("test/foundry/spec/Other.t.sol", "contract Other {}")
        plan = artifacts.test_plan(self.graph(), [], "test/foundry/spec/Selected.t.sol")
        self.assertEqual(plan["test_command"], ["forge", "test", "--match-path", "test/foundry/spec/Selected.t.sol",
                                                "--skip", "test/foundry/spec/Other.t.sol"])

    def test_failed_artifact_build_prevents_test_execution(self):
        plan = {"command": ["forge", "build", "contracts/Fixture.sol"],
                "test_command": ["forge", "test"]}
        with patch.object(artifacts.subprocess, "run", return_value=Mock(returncode=1)) as run:
            self.assertEqual(artifacts.execute_plan(self.root, plan, run_tests=True), 1)
            self.assertEqual(run.call_count, 1)

    def test_build_and_test_preserve_same_environment_and_project_paths(self):
        plan = {"command": ["forge", "build", "contracts/Fixture.sol"],
                "test_command": ["forge", "test"]}
        with patch.dict(os.environ, {"FOUNDRY_PROFILE": "default", "FOUNDRY_TEST": "test", "TASK_VALUE": "preserve"}):
            with patch.object(artifacts.subprocess, "run", return_value=Mock(returncode=0)) as run:
                self.assertEqual(artifacts.execute_plan(self.root, plan, run_tests=True), 0)
                build_call, test_call = run.call_args_list
                self.assertNotIn("env", build_call.kwargs)
                self.assertNotIn("env", test_call.kwargs)
            self.assertEqual(os.environ["FOUNDRY_TEST"], "test")

    def test_cli_accepts_options_before_sources_and_separate_forge_options(self):
        self.target_facet()
        self.write("test/foundry/spec/Selected.t.sol", "contract Selected {}")
        self.write("test/foundry/spec/Second.t.sol", "contract Second {}")
        argv = ["forge-artifacts.py", "plan", "--test-root", "test/foundry/spec/Selected.t.sol",
                "--test-root", "test/foundry/spec/Second.t.sol",
                "--no-consumer-artifacts", "contracts/Target.sol", "--json", "--", "-vv"]
        output = io.StringIO()
        with patch.object(artifacts, "SourceGraph", return_value=self.graph()), \
                patch.object(artifacts.sys, "argv", argv), patch.object(artifacts.sys, "stdout", output):
            self.assertEqual(artifacts.main(), 0)
        plan = json.loads(output.getvalue())
        self.assertEqual(plan["changed"], ["contracts/Target.sol"])
        self.assertEqual(plan["test_roots"], ["test/foundry/spec/Second.t.sol", "test/foundry/spec/Selected.t.sol"])
        self.assertEqual(plan["test_command"], ["forge", "test", "-vv", "--skip", "contracts/**"])

    def test_union_scopes_do_not_exclude_each_other(self):
        self.write("test/foundry/spec/a/One.t.sol", "contract One {}")
        self.write("test/foundry/spec/a/Other.t.sol", "contract Other {}")
        self.write("test/foundry/spec/b/Two.t.sol", "contract Two {}")
        self.write("test/foundry/spec/c/Third.t.sol", "contract Third {}")
        plan = artifacts.test_plan(self.graph(), [], ["test/foundry/spec/a/One.t.sol", "test/foundry/spec/b"])
        self.assertEqual(plan["test_files"], ["test/foundry/spec/a/One.t.sol", "test/foundry/spec/b/Two.t.sol"])
        self.assertEqual(plan["test_skip_patterns"], ["test/foundry/spec/a/Other.t.sol", "test/foundry/spec/c/**"])

    def test_explicit_runtime_test_artifact_is_not_skipped_by_build(self):
        self.write("contracts/Deploy.sol", 'library Deploy { string constant ID = "Fixture.t.sol:Fixture"; }')
        self.write("test/foundry/spec/Fixture.t.sol", "contract Fixture {}")
        plan = self.graph().plan(["contracts/Deploy.sol"])
        self.assertEqual(plan["command"], ["forge", "build", "contracts/Deploy.sol", "test/foundry/spec/Fixture.t.sol"])

    def test_closure_loads_explicit_sources_outside_initial_discovery(self):
        self.write("scripts/archive/Old.s.sol", 'import "./Dependency.sol"; contract Old {}')
        self.write("scripts/archive/Dependency.sol", "contract Dependency {}")
        graph = self.graph()
        self.assertNotIn("scripts/archive/Old.s.sol", graph.sources)
        self.assertEqual(graph.closure(["scripts/archive/Old.s.sol"]),
                         {"scripts/archive/Old.s.sol", "scripts/archive/Dependency.sol"})

    def test_closure_exposes_broken_explicit_archive_imports(self):
        self.write("scripts/archive/Old.s.sol", 'import "./Missing.sol"; contract Old {}')
        graph = self.graph()
        graph.closure(["scripts/archive/Old.s.sol"])
        self.assertEqual(graph.unresolved["scripts/archive/Old.s.sol"], {"./Missing.sol"})
        with self.assertRaisesRegex(ValueError, "Solidity source not found"):
            graph.closure(["scripts/archive/DoesNotExist.s.sol"])


if __name__ == "__main__":
    unittest.main()
