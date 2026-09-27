#!/usr/bin/env python3
"""Local R12 evidence-tool regressions; no Forge or network access."""
import contextlib
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import r12_selector_size_compare as r12


class SelectorSizeEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.old_cwd = Path.cwd()
        os.chdir(self.temp.name)
        Path('contracts/se').mkdir(parents=True)
        self.base = [{'source': 'contracts/se/ExistingFacet.sol',
                      'artifact': 'out/ExistingFacet.sol/ExistingFacet.json',
                      'methodIdentifiers': {}}]
        Path('contracts/se/ExistingFacet.sol').write_text('contract ExistingFacet {}')
        Path('baseline.json').write_text(json.dumps(self.base))
        self.artifact('ExistingFacet', 1)

    def tearDown(self):
        os.chdir(self.old_cwd)
        self.temp.cleanup()

    def artifact(self, name, size):
        path = Path(f'out/{name}.sol/{name}.json')
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({'deployedBytecode': {'object': '0x' + '00' * size},
                                    'methodIdentifiers': {}}))

    def run_compare(self, *extra):
        with patch.object(r12, 'BASE', 'baseline.json'), patch.object(r12, 'OUT', 'old.json'), \
             patch('sys.argv', ['r12', '--output', 'result.json', *extra]), \
             contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            return r12.main()

    def test_new_deployment_discovered_but_abstract_comment_and_stale_artifact_excluded(self):
        Path('contracts/se/NewFacet.sol').write_text(
            '// contract ExampleFacet {}\nabstract contract AbstractFacet {}\ncontract NewFacet {}')
        self.artifact('DeletedFacet', 30000)
        found = r12.discover_artifacts(self.base)
        self.assertEqual([r['artifact'] for r in found], ['out/NewFacet.sol/NewFacet.json'])

    def test_missing_new_artifact_is_failing_gate(self):
        Path('contracts/se/NewFacet.sol').write_text('contract NewFacet {}')
        with self.assertRaises(SystemExit) as result:
            self.run_compare()
        self.assertEqual(result.exception.code, 1)
        report = json.loads(Path('result.json').read_text())
        self.assertEqual(report['missing'], ['out/NewFacet.sol/NewFacet.json'])

    def test_oversized_new_artifact_is_failing_gate(self):
        Path('contracts/se/NewFacet.sol').write_text('contract NewFacet {}')
        self.artifact('NewFacet', 24577)
        with self.assertRaises(SystemExit) as result:
            self.run_compare()
        self.assertEqual(result.exception.code, 1)
        report = json.loads(Path('result.json').read_text())
        self.assertEqual(report['oversizeCount'], 1)
        self.assertEqual(report['newArtifactCount'], 1)

    def test_existing_evidence_not_overwritten(self):
        Path('result.json').write_text('historical evidence')
        with self.assertRaises(SystemExit) as result:
            self.run_compare()
        self.assertEqual(result.exception.code, 2)
        self.assertEqual(Path('result.json').read_text(), 'historical evidence')

    def test_rebaseline_preserves_original(self):
        initial = Path('baseline.json').read_bytes()
        self.run_compare('--rebaseline', 'ExistingFacet')
        self.assertEqual(Path('baseline.json').read_bytes(), initial)
        self.assertTrue(Path('result.json.baseline.json').is_file())


if __name__ == '__main__':
    unittest.main()
