# h2v-balancer-detf-bond-mint-spot-no-unlock-gate — PoC result

Round-2 hypothesis: Balancer V3 DETF families price bond principal / `g` and the mint gate
off live reserve-pool spot, and no entry point checks `IVault.isUnlocked()`. An attacker opens
its **own** Balancer unlock, moves the reserve pool with deferred settlement, calls bond/mint
inside that unlock, restores the pool, and settles — zero capital needed for the manipulation.

## Verdict
- **MixedBuffer mint (`exchangeIn` → `_acquireDetf`): CONFIRMED** at the shipped default static
  fee (5e16). Already validated in `h2v-bal-detf-unlock`; re-confirmed here.
- **SingleSE bond (`bond()`): CONFIRMED.** New result. Realized net profit after the lock, not
  just an inflated spot principal. This is the strongest leg of the hypothesis.
- **SingleSE mint:** NOT profitable at the fixture's deployed parameters — the production SingleSE
  fixture ships with `mintThreshold = 1.05e18` and a post-bootstrap synthetic price ≈ 0.507e18, so
  `isMintingAllowed()` is false and `_acquireDetf` falls through to `_reserveSwap` (a priced swap,
  no free mint). The dump-and-mint sweep is uniformly negative (see below). The bond path does not
  consult the mint gate, which is why bond is exploitable where SingleSE mint is not.
- **MVW / ComposedStable:** not executed here. Mechanism is identical (same `_quoteBondJoinDetf =
  amount*raw[detf]/raw[leg]` spot ratio, same missing `isUnlocked` gate); covered by the
  confirmed SingleSE-bond and MixedBuffer-mint legs. The V4 analogues are independently confirmed
  in sibling dirs `detf-bond-spot` and `detf-spot-mint`.

## Files
- `R2SingleSE.t.sol`
  - `R2_SingleSE_BondTest::test_sandwich25` / `test_sandwich10` / `test_sandOnly` / `test_honest`
    — attacker `R2SseBondAttacker` opens its own `vault.unlock`, dumps DETF it does not own into
    the 2-token weighted reserve pool (deferred DETF debt), bonds its own SE shares at the skewed
    spot, binary-search-restores the ratio, settles all deltas; then after the lock it claims the
    bond, unstakes sDETF→DETF via the public `exchangeIn`, and sells for shares. Realized PnL.
  - `R2_SingleSE_MintTest::test_sse_mint_sweep` / `test_sse_mint_openGate_sweep` — mint variant,
    refuted at fixture params (gate closed; priced swap).
- `R2MixedBuffer.t.sol::test_assert_defaultFee_mintSandwich` — MixedBuffer mint, shipped 5e16 fee,
  unprivileged, asserts profit and >10% backing loss. (Static-fee helper patched to skip the
  prank when the pool already carries the shipped default, so no privileged state write occurs in
  the asserted case.)

## PoC validity
Attacker is unprivileged: a plain contract calling public `vault.unlock`, `vault.swap`,
`DETF.bond`/`exchangeIn`, and settling with its own tokens. No `vm.store/etch/mockCall/deal` on
protocol state during the attack; no privileged pranks in the asserted cases. All Balancer deltas
settled in-tx (the unlock would revert otherwise). Attacker capital is honest SE deposits counted
as cost. Victims (honest bonder Alice, honest second bonder Bob / honest minters) are set up
before the attack. Profit is realized at the restored/fair pool ratio after the lock, and victim
loss is shown as the reserve share-leg backing reduction.

## Numbers — SingleSE bond (`test_sandwich25`, shipped 0.3% static fee, 180d max lock)
Reserve pool starts d/s = 4400e9 DETF / 1100e18 share.

| | honest bond (same B=30 shares) | sandwiched bond (dump 25% of pool DETF) |
|---|---|---|
| vault unlocked during bond | false | **true** |
| principal (DETF 1e9) | 30.68 | **91.05** (≈3x) |
| attacker share delta during attack | −30.0 | −74.19 |
| realized share PnL after lock + full exit | +0.098 (≈break-even) | **+72.46** |
| reserve share leg at end (DETF-holder backing) | 1099.90e18 | **1027.54e18** (−72.4 vs honest) |

`test_sandwich10` (10% dump): realized honest +0.098 vs sandwich **+17.85**; principal 30.68 vs 48.95.

Assertions in `test_sandwich25`: `sawUnlocked`, principal > 2x honest, honest realized < 1 share,
attacker realized > 50 shares, reserve share-leg loss > 50 shares. All pass.

## Numbers — MixedBuffer mint (`test_assert_defaultFee_mintSandwich`, shipped 5e16 fee)
- control 7x round-trip, no mint: **−200.8 shares** (pool round-trip alone is a loss).
- control honest mint of 2 shares + sell: **−0.20 shares**.
- attack (dump 7x pool DETF, mint paying 2 shares, buy back, sell): **+1213.3 shares** net profit.
- synthetic price 1.302e18 → 0.926e18 (DETF holders lose >28% backing); attacker holds 0 DETF at end.

## Root cause
`bond()` / `_acquireDetf` read the reserve pool's live `getPoolTokenInfo` balances for `g`
(`_quoteBondJoinDetf = amount*raw[detf]/raw[leg]`), the principal (`_quoteReserveSwap` /
StableMath over live balances), and the mint gate (`_syntheticPriceForSupply` over live
balances). None of the DETF entry points calls `IVault.isUnlocked()`. Balancer V3's transient
unlock nests — the outer unlock the attacker opens stays open across the DETF's own nested reserve
swap, and deltas settle only at the outermost level — so an attacker can skew the reserve pool,
transact with the DETF at the skewed spot on deferred credit, and restore within one unlock. Fix:
gate bond/mint/exchange entry on `!IVault(reserveVault).isUnlocked()` (or use a manipulation-
resistant price), and add a minimum-principal / minimum-out argument to `bond`.
