# Strict pre-intake family results

Date: 2026-11-07. `13-strict-six-families.log` compiled successfully and
executed 4,296 cases: 4,222 passed, 74 failed, zero skipped.

| Family | Suites | Cases | Result at that run |
|---|---:|---:|---|
| CP single | 56 | 582 | All passed |
| Dual CP | 73 | 591 | One zero-input error-contract regression |
| Orbital | 69 | 713 | All passed |
| Weighted | 76 | 905 | Legacy single-input fixtures plus two sequential preview mismatches remain |
| Curve quad | 60 | 740 | Four legacy single-input fee/smoke expectations remain |
| Balancer stable | 61 | 730 | Legacy single-input funding/reentry/decimal fixtures remain |

The remaining 35 cases are shared component/interface tests. Counts are
derived from the exact per-family suite headers, not a sampled log prefix.
The complete 74-failure footer was read before deciding the next fixes.

## Subsequent focused corrections

`22-audit-regressions-red.log` reproduced all three source-audit issues on
real proxies:

- Orbital's refund callback observed LP supply `295000000000000000000`
  rather than final supply `297950000000000000000`.
- Dual advertised the full reserve-projection interface with three
  uninstalled selectors.
- Curve omitted two interface registrations for installed surfaces.

`22-audit-regressions-green.log` then passed all four selected cases:
the three unchanged regressions plus the unchanged dual
`test_E2_zeroAmount_reverts`. Dual's component engine again rejects an
entirely zero input with its existing `ZeroAmount()` error while retaining
zero quantities for legitimate zero-book components.

Orbital now commits every component, completes LP issuance, recomputes L2
and synchronizes its reserve views before transferring caller refunds.
The real callback observes final supply, depositor LP and all three public
local component queries.

Dual no longer advertises the incomplete `IDetfReserveQuote` capability;
its two existing legacy selectors remain installed. No new quote stub,
projection interface or selector was invented. Curve now registers the
two interfaces whose installed selector coverage the proxy test checks.

Task 7 is verified by its complete 582-case run. Task 8 is verified by
the 590 unchanged passing cases plus the repaired zero-input case and
new metadata regression. Task 9 is verified by its 713-case run plus the
new real refund-observer regression. Final integrated/build/size checks
remain separate tasks.
