#!/usr/bin/env python3
"""Hermetic checks for local deployment guardrails (no contract mocks)."""
import importlib.util
import json
import copy
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

    def test_first_cutover_can_differ_from_simulation_without_weakening_debits(self):
        events, quotes, target = self.migration_batch()
        # A user deposits 20 after the quote and before staking is frozen.
        for event in events:
            data = bytes.fromhex(event['data'][2:])
            event['data'] = '0x' + (data[:-32] + (int.from_bytes(data[-32:], 'big') + 20).to_bytes(32, 'big')).hex()
        self.assertEqual(checks.verify_migration_events(events, quotes, target, 120, 20)['amountIn'], 100)
        with self.assertRaisesRegex(ValueError, 'reserve delta mismatch'):
            checks.verify_migration_events(events, quotes, target, 121, 20)
        quotes[1]['beforeRemaining'] += 1
        with self.assertRaisesRegex(ValueError, 'quote reserve delta mismatch'):
            checks.verify_migration_events(events, quotes, target, 120, 20)

    def test_cutover_rejects_previous_block_or_same_block_unjournaled_migration(self):
        checks.verify_cutover_timestamp(100, 100, 100, [])
        for finish, update, earlier in ((99, 99, []), (100, 99, []), (100, 100, ['earlier event'])):
            with self.subTest(finish=finish, update=update, earlier=earlier), self.assertRaisesRegex(ValueError, 'unjournaled'):
                checks.verify_cutover_timestamp(100, finish, update, earlier)

    def test_recovery_never_replays_or_accepts_partial_records(self):
        transactions = [{'hash': '0xabc'}, {'hash': '0xdef'}]
        journal = {'stages': []}
        self.assertTrue(checks.recovery_needed(transactions, journal))
        journal['stages'] = [{'receipts': [{'transactionHash': '0xABC'}, {'transactionHash': '0xdef'}]}]
        self.assertFalse(checks.recovery_needed(transactions, journal))
        journal['stages'][0]['receipts'].pop()
        with self.assertRaisesRegex(ValueError, 'Partially journaled'):
            checks.recovery_needed(transactions, journal)
        for invalid in ([], [{'hash': None}], [transactions[0], transactions[0]]):
            with self.assertRaises(ValueError):
                checks.recovery_needed(invalid, {'stages': []})

    def test_confirmed_mainnet_batch_with_pre_cutover_principal_withdrawal(self):
        fixture = json.loads((Path(__file__).parent / 'fixtures/fee_accrual_first_cutover.json').read_text())
        before, after = int(fixture['cutoverReserve']), int(fixture['finalReserve'])
        totals = checks.verify_migration_events(fixture['events'], fixture['quotes'], fixture['target'], before, after)
        self.assertEqual(totals['chunks'], 4)
        self.assertEqual(totals['amountIn'], 523077474431250000000)
        self.assertEqual(totals['amountIn'], before - after)
        with self.assertRaisesRegex(ValueError, 'reserve delta mismatch'):
            checks.verify_migration_events(fixture['events'], fixture['quotes'], fixture['target'],
                                            int(fixture['quotes'][0]['beforeRemaining']), after)

    def reverted_batch(self):
        tx = {'from': '0xowner', 'to': '0xstaking', 'input': '0x1234', 'nonce': '0x10'}
        transactions = [{'hash': '0xfailed', 'transaction': tx},
                        {'hash': None, 'transaction': {**tx, 'nonce': '0x11'}}]
        receipt = {'status': '0x0', 'logs': [], 'transactionHash': '0xfailed'}
        return transactions, receipt, {**tx, 'hash': '0xfailed'}

    def test_reverted_first_transaction_can_be_discarded_without_a_migration_debit(self):
        transactions, receipt, live_tx = self.reverted_batch()
        checks.verify_reverted_batch(transactions, receipt, live_tx, 17, 17)

    def test_failed_batch_recovery_rejects_pending_later_or_successful_transactions(self):
        transactions, receipt, live_tx = self.reverted_batch()
        for mined, pending in ((16, 16), (17, 18), (18, 18)):
            with self.subTest(mined=mined, pending=pending), self.assertRaises(ValueError):
                checks.verify_reverted_batch(transactions, receipt, live_tx, mined, pending)
        for modified in ({**receipt, 'status': '0x1'}, {**receipt, 'logs': ['event']},
                         {**receipt, 'transactionHash': '0xother'}):
            with self.assertRaises(ValueError):
                checks.verify_reverted_batch(transactions, modified, live_tx, 17, 17)
        transactions[1]['hash'] = '0xsubmitted'
        with self.assertRaises(ValueError):
            checks.verify_reverted_batch(transactions, receipt, live_tx, 17, 17)

    def test_failed_batch_recovery_binds_sender_calldata_and_nonce(self):
        transactions, receipt, live_tx = self.reverted_batch()
        for field in ('hash', 'from', 'to', 'input', 'nonce'):
            with self.subTest(field=field), self.assertRaises(ValueError):
                checks.verify_reverted_batch(transactions, receipt, {**live_tx, field: '0xchanged'}, 17, 17)
        bad = copy.deepcopy(transactions)
        bad[1]['transaction']['nonce'] = '0x12'
        with self.assertRaises(ValueError):
            checks.verify_reverted_batch(bad, receipt, live_tx, 17, 17)

    def test_partial_batch_separates_successful_prefix_from_terminal_failure(self):
        transactions, receipt, live_tx = self.reverted_batch()
        successful = {'hash': '0xsuccess', 'transaction': {**live_tx, 'nonce': '0xf'}}
        batch = [successful, *transactions]
        count = checks.submitted_prefix(batch)
        self.assertEqual(count, 2)
        checks.verify_reverted_batch(batch[count - 1:], receipt, live_tx, 17, 17)
        self.assertEqual(batch[:count - 1], [successful])
        # Once the successful prefix is recorded, recovery must not count it again.
        journal = {'stages': [{'receipts': [{'transactionHash': '0xsuccess'}]}]}
        self.assertFalse(checks.recovery_needed(batch[:count - 1], journal))

    def test_partial_batch_rejects_missing_duplicate_or_noncontiguous_hashes(self):
        for batch in ([], [{'hash': None}], [{'hash': '0xa'}, {'hash': None}, {'hash': '0xb'}],
                      [{'hash': '0xa'}, {'hash': '0xA'}]):
            with self.assertRaises(ValueError):
                checks.submitted_prefix(batch)

    def successful_partial_batch(self):
        base = {'from': '0xowner', 'to': '0xstaking', 'input': '0x1234'}
        transactions = [{'hash': '0xfirst', 'transaction': {**base, 'nonce': '0x10'}},
                        {'hash': '0xlast', 'transaction': {**base, 'nonce': '0x11'}},
                        {'hash': None, 'transaction': {**base, 'nonce': '0x12'}}]
        receipt = {'status': '0x1', 'transactionHash': '0xlast'}
        live = {**transactions[1]['transaction'], 'hash': '0xlast'}
        return transactions, receipt, live

    def test_successful_prefix_recovers_without_counting_unsent_transactions(self):
        transactions, receipt, live = self.successful_partial_batch()
        checks.verify_successful_prefix(transactions, 2, receipt, live, 18, 18)
        prefix = transactions[:2]
        self.assertTrue(checks.recovery_needed(prefix, {'stages': []}))
        journal = {'stages': [{'receipts': [{'transactionHash': t['hash']} for t in prefix]}]}
        self.assertFalse(checks.recovery_needed(prefix, journal))

    def test_successful_prefix_rejects_later_mined_pending_or_lagging_nonce(self):
        transactions, receipt, live = self.successful_partial_batch()
        for mined, pending in ((18, 19), (19, 19), (17, 18), (18, 17)):
            with self.subTest(mined=mined, pending=pending), self.assertRaisesRegex(ValueError, 'Later or pending'):
                checks.verify_successful_prefix(transactions, 2, receipt, live, mined, pending)

    def test_successful_prefix_binds_live_calldata_and_sender(self):
        transactions, receipt, live = self.successful_partial_batch()
        for field in ('hash', 'from', 'to', 'input', 'nonce'):
            with self.subTest(field=field), self.assertRaises(ValueError):
                checks.verify_successful_prefix(transactions, 2, receipt, {**live, field: '0xbad'}, 18, 18)

    def test_successful_prefix_rejects_modified_tail_or_nonce_gaps(self):
        transactions, receipt, live = self.successful_partial_batch()
        for index, field, value in ((2, 'nonce', '0x13'), (0, 'nonce', '0xf'),
                                    (2, 'from', '0xother'), (2, 'to', '0xother')):
            bad = copy.deepcopy(transactions)
            bad[index]['transaction'][field] = value
            with self.subTest(index=index, field=field), self.assertRaises(ValueError):
                checks.verify_successful_prefix(bad, 2, receipt, live, 18, 18)

    def test_successful_prefix_requires_a_confirmed_success_and_matching_receipt(self):
        transactions, receipt, live = self.successful_partial_batch()
        for bad in (None, {**receipt, 'status': '0x0'}, {**receipt, 'transactionHash': '0xother'}):
            with self.subTest(receipt=bad), self.assertRaises(ValueError):
                checks.verify_successful_prefix(transactions, 2, bad, live, 18, 18)

if __name__ == '__main__':
    unittest.main()
