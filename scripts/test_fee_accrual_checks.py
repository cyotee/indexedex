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
    def test_explicit_loopback_endpoints(self):
        for value in ('http://127.0.0.1:8545', 'http://localhost:8545', 'http://[::1]:8545'):
            self.assertEqual(checks.local_url(value), value)

    def test_public_and_ambiguous_endpoints_rejected(self):
        for value in ('https://rpc.mainnet.chain.robinhood.com', 'http://localhost',
                      'http://localhost.example.com:8545', 'http://localhost@evil.example:8545',
                      'http://user:password@localhost:8545', 'file:///tmp/rpc', 'ws://localhost:8545'):
            with self.subTest(value=value), self.assertRaises(ValueError):
                checks.local_url(value)

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
