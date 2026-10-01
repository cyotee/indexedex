#!/usr/bin/env python3
"""Offline package-family discovery regressions; no RPC, contracts or compiler."""
import importlib.util
import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest


MODULE = Path(__file__).parent / "shell/lib/rh_4663_verify_inventory.py"
spec = importlib.util.spec_from_file_location("fullspread_inventory", MODULE)
assert spec is not None and spec.loader is not None
inventory = importlib.util.module_from_spec(spec)
spec.loader.exec_module(inventory)

spec = importlib.util.spec_from_file_location(
    "fullspread_artifacts", Path(__file__).parent / "check-fullspread-consumer-artifacts.py")
assert spec is not None and spec.loader is not None
artifacts = importlib.util.module_from_spec(spec)
spec.loader.exec_module(artifacts)


class FullSpreadConsumerArtifacts(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)

    def artifact(self, name, creation=(), runtime=(), size=None, source=None):
        def bytecode(dependencies):
            return {
                "object": "0x00" + ("__$" + "a" * 34 + "$__") * len(dependencies),
                "linkReferences": {
                    f"contracts/{dep}.sol": {dep: [{"start": 1 + i * 20, "length": 20}]}
                    for i, dep in enumerate(dependencies)
                },
            }
        data = {
            "metadata": {"settings": {"compilationTarget": {source or f"contracts/{name}.sol": name}}},
            "bytecode": bytecode(creation), "deployedBytecode": bytecode(runtime),
        }
        if size is not None:
            data["deployedBytecode"]["object"] = "0x" + "00" * size
        path = self.root / "out" / f"{name}.sol" / f"{name}.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data))
        return data

    def check(self):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            result = artifacts.check_artifacts(self.root, [("contracts/Consumer.sol", "Consumer")])
        return result, output.getvalue()

    def test_recursive_creation_runtime_closure_deduplicates_cycles(self):
        self.artifact("Consumer", creation=("Claim",), runtime=("Math",))
        self.artifact("Claim", runtime=("Context", "Math"))
        self.artifact("Context", creation=("Math",))
        self.artifact("Math", runtime=("Claim",))
        result, output = self.check()
        self.assertEqual(result, 0, output)
        self.assertIn("Consumer runtimes: 1 checked, 0 failures", output)
        self.assertIn("Linked library runtimes: 3 checked, 0 failures", output)
        self.assertEqual(output.count("Linked library Math:"), 1)

    def test_transitive_library_failure_is_reported_separately(self):
        self.artifact("Consumer", runtime=("Claim",))
        self.artifact("Claim", creation=("Context",))
        for case in ("missing", "oversize", "identity"):
            with self.subTest(case=case):
                if case == "oversize":
                    self.artifact("Context", size=24_577)
                elif case == "identity":
                    self.artifact("Context", source="elsewhere/Context.sol")
                result, output = self.check()
                self.assertEqual(result, 1)
                self.assertIn("contracts/Context.sol:Context", output)
                self.assertIn("Consumer runtimes: 1 checked, 0 failures", output)
                self.assertIn("Linked library runtimes: 1 checked, 1 failures", output)

    def test_size_boundary_and_library_self_address_are_valid(self):
        self.artifact("Consumer", size=24_576)
        self.assertEqual(self.check()[0], 0)
        self.assertEqual(artifacts.bytecode_dependencies({
            "object": "0x73" + "00" * 20 + "3014", "linkReferences": {},
        }), set())

    def test_placeholders_require_exact_nonoverlapping_link_ranges(self):
        data = self.artifact("Consumer", runtime=("Claim",))["deployedBytecode"]
        self.assertEqual(artifacts.bytecode_dependencies(data), {("contracts/Claim.sol", "Claim")})
        linked = {**data, "object": "0x00" + "12" * 20}
        self.assertEqual(artifacts.bytecode_dependencies(linked), {("contracts/Claim.sol", "Claim")})
        for invalid in (
            {**data, "linkReferences": {}},
            {**data, "object": "0x00" + "z" * 40},
            {**data, "object": data["object"] + "0"},
            {**data, "object": "0x"},
        ):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                artifacts.bytecode_dependencies(invalid)
        references = data["linkReferences"]["contracts/Claim.sol"]["Claim"]
        for start, length in ((-1, 20), (2, 20), (1, 19), (True, 20)):
            references[:] = [{"start": start, "length": length}]
            with self.subTest(start=start, length=length), self.assertRaises(ValueError):
                artifacts.bytecode_dependencies(data)
        references[:] = [{"start": 1, "length": 20}] * 2
        with self.assertRaisesRegex(ValueError, "overlapping"):
            artifacts.bytecode_dependencies(data)


class FullSpreadConsumerInventory(unittest.TestCase):
    def test_backend_export_names_and_canonical_pons_hook(self):
        repo = Path(__file__).resolve().parents[1]
        main = (repo / "scripts/foundry/anvil_robinhood_main/Phase_09_Stage_01_ExportFrontend.s.sol").read_text()
        testnet = (repo / "scripts/foundry/anvil_robinhood_testnet/Phase_09_Stage_01_ExportFrontend.s.sol").read_text()
        self.assertIn('"uniV4PonsSeHook", ROBINHOOD_MAIN.PONS_V2_MEME_HOOK', main)
        self.assertIn('"uniV4SePkgName", s.uniV4SePkg.packageName()', main)
        self.assertIn('"uniV4PonsSePkgName", s.uniV4PonsSePkg.packageName()', main)
        self.assertIn('"uniV4SePkgName", s.uniV4SePkg.packageName()', testnet)
        self.assertNotIn('"uniV4PonsSeHook"', testnet)
        self.assertNotIn('"uniV4PonsSePkg"', testnet)

    def load_manifest(self, data):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "phase05_stage03.json").write_text(json.dumps(data))
            return inventory.load_deploy_json(root, root)

    def test_unqualified_old_key_is_not_relabelled_as_hookless(self):
        self.assertEqual(self.load_manifest({"uniV4SePkg": "0x" + "12" * 20}), {})

    def test_distinct_family_metadata_preserves_distinct_source_names(self):
        data = {}
        for key, address in (("uniV4SePkg", "0x" + "12" * 20),
                             ("uniV4PonsSePkg", "0x" + "34" * 20)):
            data[key] = address
            data[f"{key}Name"] = inventory.JSON_NAME[key]
        rows = self.load_manifest(data)
        self.assertEqual(len(rows), 2)
        self.assertEqual(rows[inventory.checksum_key(data["uniV4SePkg"])]["name"],
                         "UniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg")
        self.assertEqual(rows[inventory.checksum_key(data["uniV4PonsSePkg"])]["name"],
                         "UniswapV4FullSpreadPonsFamilyHookDFPkg")

    def test_wrong_family_metadata_is_not_a_source_identity(self):
        self.assertEqual(self.load_manifest({
            "uniV4SePkg": "0x" + "12" * 20,
            "uniV4SePkgName": inventory.JSON_NAME["uniV4PonsSePkg"],
        }), {})

    def test_registry_identity_overrides_stale_json_identity(self):
        address = "0x" + "12" * 20
        inferred, actual = {}, {}
        inventory.add_item(inferred, address, inventory.JSON_NAME["uniV4SePkg"], "json:phase05.json")
        inventory.add_item(actual, address, "UniswapV4StandardExchangeDFPkg", "registry:package")
        row = inventory.merge(inferred, actual)[inventory.checksum_key(address)]
        self.assertEqual(row["name"], "UniswapV4StandardExchangeDFPkg")
        self.assertEqual(row["source"], "registry:package")


if __name__ == "__main__":
    unittest.main()
