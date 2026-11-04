# dz-detf-inv3-pretransfer-roundtrip: REFUTED_BY_EXECUTION (harness false positive)

Break: DetfInvariantRichTest INV-3. Shrunk sequence: `a_pretransfer(3e14, 23625, 2^256-4)` then `h_roundTrip(145)`.
Sources: the audit runner ~/audits/deep/detf.log and ~/audits/slot10/cache/invariant/failures/.

## How the arguments decode
- tokSel = 3e14 % 3 = 0, so the token is pair. dstSel = 23625 % 4 = 1, so the destination is the **reserve hook**. amtSeed % 3 == 0 picks the large branch, so amt = bal/10 - 2 = **249.999999999999999998 pair** sent by the adversary.
- h_roundTrip(145) bounds to amt = 99.999e18 pair. Alice mints DETF with it, then burns the DETF back to pair.

## Executed (DzDetfInv3.t.sol, all 3 tests pass)
- test_replay: ghost_roundTripViol = 1, so the break reproduces.
- test_decompose:
  - Without the gift: m = 39,167,455,837 DETF, out = 97.453 pair, PnL = **-2.546 pair**.
  - With the 250-pair gift on the hook: m is the same (no extra DETF minted), out = 101.321, PnL = **+1.322 pair**.
  - The hook's pair balance goes from 250e18 to 10 wei during the **mint**. The mint path sweeps the stray balance single-sided into the reserve, which moves the price that the burn then sells into.
  - Alice's round trip improves by 3.87 pair, which is 1.5% of the gift. The adversary lost 250 pair.
- test_attackerCapturesStray: a victim strands 10 pair on the hook, then a fresh unprivileged attacker does a 100-pair round trip. Attacker PnL is -2.391 pair, against a baseline of -2.546. The attacker captures only 0.155 (1.5% of the stray) and stays net negative. A direct EOA `hook.exchangeIn(..., pretransferred=true)` claim of the stray **reverts** (0xb18c67ea, the pretransfer-caller gate).

## Verdict
There is no attacker profit and no loss to an honest user. The honest round trip's "profit" is a small slice of the adversary's own donation. Most of the donation (about 98.5%) stays in the reserve and goes to protocol LP and holders.

The invariant fired only because the handler's `_looseValue()` counts residuals on the DETF diamond and the bond NFT but not on the reserve hook. The same mechanism with dst=detf is quarantined as `ghost_roundTripResidualCapture` (regress break #7). This is the residual-sandwich class already listed in CATALOG `refuted_or_dropped` ("p4:detf residual-sandwich ... no PoC").

Nearest catalog ids, for reference only:
- APEX-2026-036 is the stray pair on deployed pre-HEAD CP hooks. At HEAD the direct claim is gated, as shown here.
- APEX-2026-039 is the unattributed pretransfer credit. Here no credit goes to the caller; the stray is joined into the reserve.

Harness fix: add `pair.balanceOf(hook)` (and the hook's SE/DETF strays) to `_looseValue()`.
