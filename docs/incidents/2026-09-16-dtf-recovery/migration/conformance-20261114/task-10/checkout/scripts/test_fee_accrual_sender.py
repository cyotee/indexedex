#!/usr/bin/env python3
"""Exercise shell signing/sequence failures with fake CLI processes, never contract mocks or RPC writes."""
import json
import os
from pathlib import Path
import subprocess
import shutil
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
OWNER = '0x' + 'ab' * 20

CLI = r'''
import json, os, sys, time
from pathlib import Path
name = Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ['CLI_LOG'], 'a') as f:
    f.write(json.dumps({'cli': name, 'args': args, 'sender': os.environ.get('DEPLOYER_ADDRESS'),
                        'key': os.environ.get('PRIVATE_KEY'), 'config': os.environ.get('FEE_ACCRUAL_CONFIG'),
                        'output': os.environ.get('OUT_DIR_OVERRIDE')}) + '\n')
if name == 'cast':
    print('4663' if args[0] == 'chain-id' else '0x' + '00' * 20)
elif name == 'jq':
    print('https://rpc.default.example' if '--arg' in args and 'alias_name' in args else '0x' + '12' * 20)
elif name == 'python3':
    mode = args[2]
    if mode == 'recover-migration' and os.environ.get('FAIL_RECOVERY'): sys.exit(1)
    Path(os.environ['OUT_DIR_OVERRIDE']).mkdir(parents=True, exist_ok=True)
    if mode == 'stage-complete':
        if os.environ.get('INVALID_PRIOR_RECEIPT'): sys.exit(1)
        sys.exit(0 if args[3] in os.environ.get('COMPLETED_STAGES', '').split(',') else 3)
    if mode == 'pin-packages':
        (Path(os.environ['OUT_DIR_OVERRIDE']) / 'fee-accrual-config.resolved.json').write_text('{}')
    if mode == 'remaining':
        marker = Path(os.environ['CLI_LOG'] + '.remaining')
        values = os.environ.get('MIGRATION_REMAINING', '100,0').split(',')
        index = int(marker.read_text()) if marker.exists() else 0
        print(values[min(index, len(values) - 1)])
        marker.write_text(str(index + 1))
    if mode == 'receipts' and os.environ.get('FAIL_RECEIPTS'):
        sys.exit(1)
elif name == 'forge':
    if os.environ.get('FAIL_SIM') and '--broadcast' not in args:
        sys.exit(1)
    if '--broadcast' in args:
        if os.environ.get('FAIL_BROADCAST'):
            sys.exit(1)
        record = Path(os.environ['FOUNDRY_BROADCAST']) / Path(args[1]).name / '4663/run-latest.json'
        record.parent.mkdir(parents=True, exist_ok=True)
        record.write_text(json.dumps({'test': time.time_ns()}))
        if 'Phase_06_Stage_01_' in args[1]:
            (Path(os.environ['OUT_DIR_OVERRIDE']) / 'phase06_stage01_bond_nft_pkg.json').write_text('{}')
'''

class FeeAccrualSender(unittest.TestCase):
    def run_public(self, options=('--broadcast',), command='fee-accrual-migrate', defaults=False, **changes):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp)
            for name in ('forge', 'cast', 'jq', 'python3'):
                exe = p / name
                exe.write_text('#!' + sys.executable + '\n' + CLI)
                exe.chmod(0o755)
            core = p / 'core'
            core.mkdir()
            for name in ('phase01_stage01_permit2', 'phase01_stage02_weth', 'phase01_stage03_uniswap_v4',
                         'phase02_stage01_create3_factory', 'phase02_stage02_diamond_package_factory',
                         'phase02_stage03_hook_factory', 'phase03_stage01_common_facets',
                         'phase04_stage01_fee_collector_and_manager', 'phase05_stage02_uniswap_v4_twap_oracle'):
                (core / (name + '.json')).write_text('{}')
            packages = p / 'packages'
            packages.mkdir()
            (packages / 'phase06_stage01_bond_nft_pkg.json').write_text('{}')
            config = p / 'config.json'
            config.write_text('{}')
            env = {**os.environ, 'PATH': str(p) + ':' + os.environ['PATH'],
                   'RPC_URL': 'https://rpc.example', 'DEPLOYER_ADDRESS': OWNER,
                   'ETH_KEYSTORE_ACCOUNT': 'owner-wallet', 'PRIVATE_KEY': '123',
                   'FEE_ACCRUAL_CONFIG': str(config), 'FEE_ACCRUAL_RUN_DIR': str(p / 'run'),
                   'FEE_ACCRUAL_CORE_DIR': str(core), 'FEE_ACCRUAL_PACKAGE_DIR': str(packages),
                   'CLI_LOG': str(p / 'log')}
            cwd = ROOT
            if defaults:
                cwd = p / 'repo'
                for relative in ('scripts/shell/robinhood_main.sh', 'scripts/shell/lib/rh_4663_stages.sh',
                                 'scripts/foundry/anvil_robinhood_main/fee_accrual_launch.robinhood.json'):
                    destination = cwd / relative
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(ROOT / relative, destination)
                for stage in (ROOT / 'scripts/foundry/anvil_robinhood_main').glob('*.s.sol'):
                    (cwd / 'scripts/foundry/anvil_robinhood_main' / stage.name).touch()
                shutil.copytree(core, cwd / 'deployments/anvil_robinhood_main')
                for key in ('RPC_URL', 'ETH_KEYSTORE_ACCOUNT', 'FEE_ACCRUAL_CONFIG', 'FEE_ACCRUAL_RUN_DIR',
                            'FEE_ACCRUAL_PACKAGE_DIR', 'FEE_ACCRUAL_CORE_DIR', 'REHEARSAL_CORE_DIR',
                            'OUT_DIR_OVERRIDE', 'FOUNDRY_BROADCAST'):
                    env.pop(key, None)
            env.update(changes)
            if env.get('EXISTING_MIGRATION_JOURNAL'):
                run = Path(env['FEE_ACCRUAL_RUN_DIR'])
                run.mkdir(parents=True, exist_ok=True)
                (run / 'fee-accrual-journal.json').write_text('{}')
            if command == 'fee-accrual-launch' and '06-01' in env.get('COMPLETED_STAGES', '').split(','):
                saved_packages = Path(env['FEE_ACCRUAL_RUN_DIR']) / 'packages'
                saved_packages.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(packages / 'phase06_stage01_bond_nft_pkg.json',
                                saved_packages / 'phase06_stage01_bond_nft_pkg.json')
            result = subprocess.run(['bash', 'scripts/shell/robinhood_main.sh',
                                     command, *options], cwd=cwd,
                                    env=env, capture_output=True, text=True)
            rows = [json.loads(s) for s in (p / 'log').read_text().splitlines()] if (p / 'log').exists() else []
            return result, rows

    def test_public_sender_signing_and_order(self):
        result, rows = self.run_public()
        self.assertEqual(result.returncode, 0, result.stderr)
        forge = [r for r in rows if r['cli'] == 'forge']
        for r in forge:
            args = r['args']
            self.assertEqual(args[args.index('--sender') + 1], OWNER)
            self.assertEqual(r['key'], '0')
            self.assertIn('--offline', args)  # Trace metadata must not consume the deadline.
            for forbidden in ('--unlocked', '--legacy', '--gas-price', '--skip-simulation', '--resume'):
                self.assertNotIn(forbidden, args)
        broadcasts = [r for r in forge if '--broadcast' in r['args']]
        self.assertEqual(len(broadcasts), 2)
        self.assertIn('Stage_05', broadcasts[0]['args'][1])
        self.assertIn('Stage_07', broadcasts[1]['args'][1])
        for r in broadcasts:
            self.assertIn('--slow', r['args'])
            self.assertNotIn('--account', r['args'])

        checks = [r['args'][2] for r in rows if r['cli'] == 'python3']
        self.assertEqual(checks, ['preflight', 'ready', 'stage-complete', 'receipts', 'begin-migration', 'remaining', 'receipts', 'remaining', 'verify'])

    def test_migrate_recovers_existing_journal_before_any_forge_stage(self):
        result, rows = self.run_public(EXISTING_MIGRATION_JOURNAL='1')
        self.assertEqual(result.returncode, 0, result.stderr)
        first_forge = next(i for i, row in enumerate(rows) if row['cli'] == 'forge')
        modes = [row['args'][2] for row in rows[:first_forge] if row['cli'] == 'python3']
        self.assertEqual(modes[:2], ['reconcile-scripts', 'recover-migration'])

    def test_uncertain_recovery_stops_before_forge_can_overwrite_quotes(self):
        result, rows = self.run_public(EXISTING_MIGRATION_JOURNAL='1', FAIL_RECOVERY='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(row['cli'] == 'forge' for row in rows))
        self.assertFalse(any(arg.startswith('anvil_') for r in rows for arg in r['args']))

    def test_requires_explicit_broadcast(self):
        for options, changes in [((), {}), (('--broadcast', '--dry-run'), {}), (('--broadcast', '--force'), {})]:
            with self.subTest(options=options, changes=changes):
                result, rows = self.run_public(options, **changes)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(any(r['cli'] == 'forge' for r in rows))

    def test_migration_requotes_and_reconciles_each_batch_until_complete(self):
        result, rows = self.run_public(MIGRATION_REMAINING='100,75,50,0')
        self.assertEqual(result.returncode, 0, result.stderr)
        batches = [r for r in rows if r['cli'] == 'forge' and '--broadcast' in r['args'] and 'Stage_07' in r['args'][1]]
        self.assertEqual(len(batches), 3)
        checks = [r['args'][2] for r in rows if r['cli'] == 'python3']
        self.assertEqual(checks.count('receipts'), 4)  # adapter + three batches
        self.assertEqual(checks.count('remaining'), 4)
        self.assertEqual(checks[-1], 'verify')

    def test_migration_stops_if_batch_makes_no_progress(self):
        result, rows = self.run_public(MIGRATION_REMAINING='100,100')
        self.assertNotEqual(result.returncode, 0)
        batches = [r for r in rows if r['cli'] == 'forge' and '--broadcast' in r['args'] and 'Stage_07' in r['args'][1]]
        self.assertEqual(len(batches), 1)

    def test_script_reconciliation_checks_both_journals_without_broadcast(self):
        result, rows = self.run_public(command='fee-accrual-reconcile', options=())
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any(r['cli'] == 'forge' and r['args'][0] == 'script' for r in rows))
        checks = [r for r in rows if r['cli'] == 'python3']
        self.assertEqual([r['args'][2] for r in checks], ['reconcile-scripts', 'reconcile-scripts', 'recover-migration'])
        self.assertTrue(checks[0]['output'].endswith('/packages'))
        self.assertTrue(checks[1]['output'].endswith('/composition'))

    def test_full_launch_orders_all_dependencies_before_migration(self):
        result, rows = self.run_public(command='fee-accrual-launch')
        self.assertEqual(result.returncode, 0, result.stderr)
        broadcasts = [r for r in rows if r['cli'] == 'forge' and '--broadcast' in r['args']]
        stages = ['-'.join(Path(r['args'][1]).name.split('_')[i] for i in (1, 3)) for r in broadcasts]
        self.assertEqual(stages, ['05-01', '05-03', '06-01', '06-02', '06-04', '06-07', '06-10',
                                  '07-01', '07-02', '07-03', '07-04', '08-03', '08-04', '08-05', '08-07'])
        for r, stage in zip(broadcasts, stages):
            args = r['args']
            self.assertEqual(args[args.index('--sender') + 1], OWNER)
            self.assertEqual(args[args.index('--gas-estimate-multiplier') + 1], '100' if stage == '08-03' else '150')
            self.assertNotIn('--skip-simulation', args)
            self.assertNotIn('--unlocked', args)
            self.assertNotIn('--legacy', args)
            self.assertNotIn('--gas-price', args)
            self.assertIn('--slow', args)
        previous_forge = None
        for row in rows:
            if row['cli'] == 'forge':
                if '--broadcast' in row['args']:
                    self.assertEqual(previous_forge, row['args'][:-2])
                previous_forge = row['args']
        first_script = next(i for i, r in enumerate(rows) if r['cli'] == 'forge' and r['args'][0] == 'script'
                            and 'Phase_05_' in r['args'][1])
        self.assertTrue(any(r['cli'] == 'forge' and r['args'][0] == 'build' for r in rows[:first_script]))

    def test_full_launch_defaults_with_only_deployer_address(self):
        result, rows = self.run_public(command='fee-accrual-launch', defaults=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        broadcasts = [r for r in rows if r['cli'] == 'forge' and '--broadcast' in r['args']]
        self.assertEqual(len(broadcasts), 15)
        for r in broadcasts:
            args = r['args']
            self.assertEqual(args[args.index('--sender') + 1], OWNER)
            self.assertEqual(args[args.index('--rpc-url') + 1], 'https://rpc.default.example')
            self.assertNotIn('--account', args)
            self.assertNotIn('--skip-simulation', args)
        self.assertTrue(broadcasts[0]['config'].endswith('/scripts/foundry/anvil_robinhood_main/fee_accrual_launch.robinhood.json'))
        self.assertTrue(broadcasts[0]['output'].endswith('/deployments/robinhood_main_fee_accrual/packages'))
        self.assertTrue(broadcasts[-1]['config'].endswith('/packages/fee-accrual-config.resolved.json'))
        self.assertTrue(broadcasts[-1]['output'].endswith('/deployments/robinhood_main_fee_accrual/composition'))

    def test_confirmed_seed_and_first_bond_are_not_replayed(self):
        result, rows = self.run_public(command='fee-accrual-prepare', COMPLETED_STAGES='07-04,08-04')
        self.assertEqual(result.returncode, 0, result.stderr)
        for r in rows:
            if r['cli'] == 'forge':
                self.assertNotIn('Phase_07_Stage_04', ' '.join(r['args']))
                self.assertNotIn('Phase_08_Stage_04', ' '.join(r['args']))

    def test_full_launch_resumes_after_confirmed_rate_providers(self):
        completed = '05-01,05-03,06-01,06-02,06-04,06-07,06-10,07-01,07-02,07-03'
        result, rows = self.run_public(command='fee-accrual-launch', COMPLETED_STAGES=completed)
        self.assertEqual(result.returncode, 0, result.stderr)
        broadcasts = [r for r in rows if r['cli'] == 'forge' and '--broadcast' in r['args']]
        stages = ['-'.join(Path(r['args'][1]).name.split('_')[i] for i in (1, 3)) for r in broadcasts]
        self.assertEqual(stages, ['07-04', '08-03', '08-04', '08-05', '08-07'])
        previous_forge = None
        for row in rows:
            if row['cli'] == 'forge':
                if '--broadcast' in row['args']:
                    self.assertEqual(previous_forge, row['args'][:-2])
                    self.assertNotIn('--skip-simulation', row['args'])
                previous_forge = row['args']

    def test_invalid_prior_receipt_stops_instead_of_rebroadcasting(self):
        result, rows = self.run_public(command='fee-accrual-prepare', INVALID_PRIOR_RECEIPT='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any('--broadcast' in r['args'] for r in rows))

    def test_full_launch_stops_at_failed_package_broadcast(self):
        result, rows = self.run_public(command='fee-accrual-launch', FAIL_BROADCAST='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(sum('--broadcast' in r['args'] for r in rows), 1)
        self.assertFalse(any('Phase_07_' in ' '.join(r['args']) for r in rows))

    def test_simulation_failure_prevents_broadcast(self):
        result, rows = self.run_public(FAIL_SIM='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any('--broadcast' in r['args'] for r in rows))

    def test_missing_sender_fails_without_forge(self):
        result, rows = self.run_public(DEPLOYER_ADDRESS='')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('requires DEPLOYER_ADDRESS', result.stderr)
        self.assertFalse(any(r['cli'] == 'forge' for r in rows))

    def test_read_commands_do_not_broadcast_or_require_keystore(self):
        for command in ('fee-accrual-preflight', 'fee-accrual-verify'):
            with self.subTest(command=command):
                result, rows = self.run_public((), command=command, ETH_KEYSTORE_ACCOUNT='')
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertFalse(any('--broadcast' in r['args'] for r in rows))

    def test_broadcast_failure_stops_without_retry_or_migration(self):
        result, rows = self.run_public(FAIL_BROADCAST='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(sum('--broadcast' in r['args'] for r in rows), 1)
        self.assertFalse(any('Stage_07' in ' '.join(r['args']) for r in rows))

    def test_receipt_failure_prevents_migration(self):
        result, rows = self.run_public(FAIL_RECEIPTS='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any('Stage_07' in ' '.join(r['args']) for r in rows))

    def test_local_mismatched_owner_fails_before_cli(self):
        source = (ROOT / 'scripts/foundry/anvil_robinhood_main/deploy_all.sh').read_text()
        function = source.split('rh_fee_accrual_stage() {', 1)[1].split('\nrh_run_fee_accrual() {', 1)[0]
        result = subprocess.run(['bash', '-c', 'rh_fee_accrual_stage() {' + function +
                                 '\nrh_fee_accrual_stage 08 07 0x' + 'cd' * 20 + ' broadcast'],
                                env={**os.environ, 'DEPLOYER_ADDRESS': OWNER}, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('DEPLOYER_ADDRESS must match', result.stderr)

if __name__ == '__main__':
    unittest.main()
