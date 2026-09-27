#!/usr/bin/env python3
"""Regression checks for the release matrix's evidence gate."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).with_name('hook_se_matrix_evidence.py').resolve()
CONTROLS = [
    'ammCallerFundSeparation', 'bind_deploysThroughPackage',
    'bufferFirst_restingFace_notPaidToJoiner',
    'hookSwap_exactIn_eoaPretransferRejected',
    'hookSwap_exactOut_falseFlag_pullsUsedOnly',
    'hookSwap_exactOut_trueFlag_refundsCreditMinusUsed',
    'partialConsumption_bookedNotRefunded',
    'poolManagerSwap_bothDirections_noFaceResidual',
    'previewMatchesExecution', 'seFailure_rollsBack',
]


class MatrixEvidenceTest(unittest.TestCase):
    def generate(self, results, missing_suite=False):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            log = root / 'run.log'
            output = root / 'matrix.json'
            source = root / 'test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/Example_SeMatrix_ERC4626.t.sol'
            source.parent.mkdir(parents=True)
            source.write_text('contract Example_SeMatrix_ERC4626 {}\n')
            if missing_suite:
                source.with_name('Example_SeMatrix_Stata.t.sol').write_text('contract Example_SeMatrix_Stata {}\n')
            log.write_text(
                f'Ran {len(results)} tests for test/foundry/spec/hooks/uniswap/v4/'
                'standardExchange/orbital/Example_SeMatrix_ERC4626.t.sol:Example_SeMatrix_ERC4626\n'
                + '\n'.join(results) + '\nSuite result: finished\n'
            )
            result = subprocess.run([sys.executable, str(SCRIPT), str(log), str(output)],
                                    cwd=root, capture_output=True, text=True)
            return result.returncode, json.loads(output.read_text())

    def test_all_ten_controls_are_required(self):
        valid = [f'[PASS] test_row_{name}() (gas: 100)' for name in CONTROLS]
        code, evidence = self.generate(valid)
        self.assertEqual(code, 0)
        self.assertEqual(evidence['rows'][0]['state'], 'COMPATIBLE')
        code, evidence = self.generate(valid[:-1])
        self.assertNotEqual(code, 0)
        self.assertEqual(evidence['rows'][0]['state'], 'INCOMPLETE')
        self.assertEqual(evidence['rows'][0]['missingTests'], ['test_row_seFailure_rollsBack'])

    def test_duplicate_control_does_not_replace_missing_one(self):
        controls = [f'[PASS] test_row_{name}()' for name in CONTROLS[:-1]]
        code, evidence = self.generate(controls + controls[:1])
        self.assertNotEqual(code, 0)
        self.assertEqual(evidence['rows'][0]['state'], 'INCOMPLETE')

    def test_failing_named_rejection_is_failing(self):
        for state in ('INCOMPATIBLE', 'DEPRECATED', 'DEFERRED', 'BLOCKED'):
            with self.subTest(state=state):
                code, evidence = self.generate([f'[FAIL: wrong error] test_{state}_guard()'])
                self.assertNotEqual(code, 0)
                self.assertEqual(evidence['rows'][0]['state'], 'FAILING')

    def test_passing_named_rejection_is_compatible_evidence(self):
        code, evidence = self.generate(['[PASS] test_INCOMPATIBLE_namedGuard()'])
        self.assertEqual(code, 0)
        self.assertEqual(evidence['rows'][0]['state'], 'INCOMPATIBLE')

    def test_empty_suite_does_not_pass(self):
        code, evidence = self.generate([])
        self.assertNotEqual(code, 0)
        self.assertEqual(evidence['rows'][0]['state'], 'INCOMPLETE')

    def test_omitted_source_suite_prevents_closure(self):
        valid = [f'[PASS] test_row_{name}()' for name in CONTROLS]
        code, evidence = self.generate(valid, missing_suite=True)
        self.assertNotEqual(code, 0)
        self.assertEqual(evidence['missingSuites'], ['Example_SeMatrix_Stata'])
        self.assertEqual(evidence['expectedRowCount'], 2)


if __name__ == '__main__':
    unittest.main()
