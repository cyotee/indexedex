#!/usr/bin/env python3
"""Exercise the R2.4 gate in isolated repositories, including lexer edge cases."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCANNER = Path(__file__).with_name("apex_bare_expectrevert_scan.sh").resolve()


class BareExpectationGateTest(unittest.TestCase):
    def scan(self, source, path="hooks/uniswap/v4/standardExchange/Example.t.sol"):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            target = root / "test/foundry/spec" / path
            target.parent.mkdir(parents=True)
            target.write_text(source)
            shutil.copyfile(SCANNER, root / "scan.sh")
            result = subprocess.run(
                ["bash", "scan.sh", "--check"], cwd=root, text=True, capture_output=True
            )
            evidence = root / "docs/audits/apex-2026-09-17-evidence/bare-expectrevert.txt"
            return result.returncode, result.stdout, evidence.read_text()

    def test_empty_scan_succeeds(self):
        code, output, evidence = self.scan("pragma solidity ^0.8.0;\n")
        self.assertEqual(code, 0, output)
        self.assertEqual(evidence, "")

    def test_strings_and_comments_are_not_empty_arguments(self):
        code, output, evidence = self.scan('''
// vm.expectRevert();
/* vm.expectRevert( ); */
string memory example = "vm.expectRevert()";
vm.expectRevert("not owner");
vm.expectRevert(bytes(""));
vm.expectRevert(MyError.selector);
''')
        self.assertEqual(code, 0, output)
        self.assertEqual(evidence, "")

    def test_spaced_multiline_empty_argument_fails(self):
        code, output, evidence = self.scan("\nvm . expectRevert ( /* no reason */\n );\n")
        self.assertEqual(code, 1, output)
        self.assertIn("Example.t.sol:2:", evidence)

    def test_apex_regressions_extend_scope_without_matching_cap_exceeded(self):
        path = "protocol/staking/example/Example.t.sol"
        code, output, _ = self.scan("// capExceeded\nvm.expectRevert();", path)
        self.assertEqual(code, 0, output)
        code, output, evidence = self.scan("// APEX-005\nvm.expectRevert();", path)
        self.assertEqual(code, 1, output)
        self.assertIn("Example.t.sol:2:", evidence)


if __name__ == "__main__":
    unittest.main()
