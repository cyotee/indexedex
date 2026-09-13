#!/usr/bin/env python3
"""Hermetic checks for local deployment guardrails (no contract mocks)."""
import importlib.util
from pathlib import Path
import unittest

MODULE = Path(__file__).parent / 'shell/lib/rh_4663_fee_accrual.py'
spec = importlib.util.spec_from_file_location('fee_checks', MODULE)
checks = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checks)

class FeeAccrualChecks(unittest.TestCase):
    def test_script_update_requires_exact_reviewed_pair_and_unchanged_identity(self):
        before = {'scriptSourceSha256': 'old', 'configSha256': 'config', 'instanceId': 'public-4663', 'coreCodeSha256': {'core': 'code'}}
        after = {**before, 'scriptSourceSha256': 'new'}
        transition = {'from': 'old', 'to': 'new'}
        checks.validate_script_transition(before, after, transition)
        for changed in ({'scriptSourceSha256': 'unreviewed'}, {'configSha256': 'changed'},
                        {'instanceId': 'another-chain'}, {'coreCodeSha256': {'core': 'changed'}}):
            with self.subTest(changed=changed), self.assertRaises(ValueError):
                checks.validate_script_transition(before, {**after, **changed}, transition)
        with self.assertRaises(ValueError):
            checks.validate_script_transition({**before, 'scriptSourceSha256': 'unknown'}, after, transition)

    def test_snapshot_refresh_only_before_first_migration(self):
        journal = {'stages': [], 'initialReserve': 100, 'initialPrincipal': 80, 'migrationStarted': True}
        checks.refresh_pre_migration_snapshot(journal, 0, 90, 70)
        self.assertEqual((journal['initialReserve'], journal['initialPrincipal']), (90, 70))
        self.assertEqual(journal['preMigrationSnapshots'], [{'initialReserve': 100, 'initialPrincipal': 80}])
        with self.assertRaises(ValueError):
            checks.refresh_pre_migration_snapshot(journal, 1, 50, 70)
        journal['stages'] = [{'migration': {'amountIn': 40}}]
        checks.refresh_pre_migration_snapshot(journal, 1, 50, 70)
        self.assertEqual(journal['initialReserve'], 90)

    def package_manifests(self):
        return {filename: {'chainId': 4663, key: '0x' + f'{index + 1:040x}'}
                for index, (filename, key) in enumerate(checks.PACKAGE_MANIFESTS.values())}

    def test_package_resolution_preserves_all_economic_choices(self):
        config = {'packages': None, 'bootstrap': {'wethInput': '1000000000000000'},
                  'weights': {'detf': 60, 'weth': 20, 'dtf': 20}}
        resolved = checks.resolve_package_config(config, self.package_manifests())
        self.assertEqual(resolved['bootstrap'], config['bootstrap'])
        self.assertEqual(resolved['weights'], config['weights'])
        self.assertEqual(set(resolved['packages']), set(checks.PACKAGE_MANIFESTS))
        self.assertIsNone(config['packages'])

    def test_package_resolution_rejects_missing_wrong_chain_or_empty_addresses(self):
        for kind in ('missing', 'chain', 'zero'):
            manifests = self.package_manifests()
            file, field = next(iter(checks.PACKAGE_MANIFESTS.values()))
            if kind == 'missing': del manifests[file]
            elif kind == 'chain': manifests[file]['chainId'] = 1
            else: manifests[file][field] = '0x' + '00' * 20
            with self.subTest(kind=kind), self.assertRaises((ValueError, KeyError)):
                checks.resolve_package_config({'packages': {}}, manifests)

    def test_explicit_loopback_endpoints(self):
        for value in ('http://127.0.0.1:8545', 'http://localhost:8545', 'http://[::1]:8545'):
            self.assertEqual(checks.local_url(value), value)

    def test_public_and_ambiguous_endpoints_rejected(self):
        for value in ('https://rpc.mainnet.chain.robinhood.com', 'http://localhost',
                      'http://localhost.example.com:8545', 'http://localhost@evil.example:8545',
                      'http://user:password@localhost:8545', 'file:///tmp/rpc', 'ws://localhost:8545'):
            with self.subTest(value=value), self.assertRaises(ValueError):
                checks.local_url(value)

    def test_public_rpc_selection_is_explicit_and_requires_https(self):
        self.assertEqual(checks.public_url('https://rpc.mainnet.chain.robinhood.com'),
                         'https://rpc.mainnet.chain.robinhood.com')
        for value in ('http://rpc.example', 'file:///tmp/rpc', 'https://user:secret@rpc.example', 'https://'):
            with self.subTest(value=value), self.assertRaises(ValueError):
                checks.public_url(value)

    def test_sender_must_be_explicit_valid_and_match_owner(self):
        owner = '0x' + 'ab' * 20
        checks.require_sender(owner, owner)
        checks.require_sender('0x' + 'AB' * 20, owner)
        for sender in (None, '', '0x123', '0x' + '00' * 20, '0x' + 'zz' * 20, '0x' + 'cd' * 20):
            with self.subTest(sender=sender), self.assertRaises(ValueError):
                checks.require_sender(sender, owner)

    def test_unresolved_nested_decisions_fail_with_path(self):
        with self.assertRaisesRegex(ValueError, r'config.bootstrap.wethInput'):
            checks.require_complete({'bootstrap': {'wethInput': None}})

    def test_explicit_zero_is_not_an_unanswered_decision(self):
        # Economic ranges are validated by the scripts; e.g. zero pool fee is legitimate.
        checks.require_complete({'poolFee': 0, 'ownerOnlyLiquidity': False})

    def test_no_rpc_redirects(self):
        with self.assertRaisesRegex(ValueError, 'redirects'):
            checks.NoRedirect().redirect_request(None, None, 302, '', {}, 'https://public.example')

    def migration_batch(self):
        target = '0x' + '12' * 20
        events, quotes = [], []
        remaining = 100
        for amount in (25, 30, 45):
            after = remaining - amount
            events.append({'topics': ['0xevent', '0x' + '00' * 12 + target[2:]],
                           'data': '0x' + ''.join(value.to_bytes(32, 'big').hex()
                                                for value in (amount, amount * 2, amount * 2, amount * 3, after))})
            quotes.append({'amountIn': amount, 'minClaimOut': amount,
                           'beforeRemaining': remaining, 'afterRemaining': after})
            remaining = after
        return events, quotes, target

    def test_batch_reconciles_every_chunk(self):
        events, quotes, target = self.migration_batch()
        totals = checks.verify_migration_events(events, quotes, target, 100, 0)
        self.assertEqual(totals, {'amountIn': 100, 'detfOut': 200, 'claimOut': 200, 'sharesOut': 300, 'chunks': 3})

    def test_batch_accepts_forge_decimal_strings_without_precision_loss(self):
        events, quotes, target = self.migration_batch()
        quotes = [{key: str(value) for key, value in quote.items()} for quote in quotes]
        self.assertEqual(checks.verify_migration_events(events, quotes, target, 100, 0)['amountIn'], 100)
        self.assertEqual(checks.quote_uint('223355050624580728299834717'), 223355050624580728299834717)

    def test_quote_integer_rejects_lossy_and_invalid_values(self):
        for value in (True, 1.5, -1, '-1', '1e18', '', None, 2**256):
            with self.subTest(value=value), self.assertRaises(ValueError):
                checks.quote_uint(value)

    def test_batch_rejects_missing_reordered_or_repeated_events(self):
        events, quotes, target = self.migration_batch()
        for invalid in (events[:-1], list(reversed(events)), [events[0], events[0], events[2]]):
            with self.assertRaises(ValueError):
                checks.verify_migration_events(invalid, quotes, target, 100, 0)

    def test_batch_rejects_intervening_reserve_change(self):
        events, quotes, target = self.migration_batch()
        for before, after in ((101, 0), (100, 1)):
            with self.assertRaises(ValueError):
                checks.verify_migration_events(events, quotes, target, before, after)

    def test_batch_enforces_each_chunks_minimum(self):
        events, quotes, target = self.migration_batch()
        quotes[1]['minClaimOut'] = 61
        with self.assertRaisesRegex(ValueError, 'below limits'):
            checks.verify_migration_events(events, quotes, target, 100, 0)

if __name__ == '__main__':
    unittest.main()
