# Composed-route capabilities and limits

Date: 2026-11-07.

The gas matrix measures real exact-input mint and redemption transactions on
both member faces of the primary FullSpread vault. LP-bearing rows bind the
matching external provider. H1 has no provider field; it binds each member
face and its actual SE-share conversion route. Every measured mint increases
primary SE supply, and every measured redemption decreases it. LP-bearing
redemptions additionally require a preview above the entire locally held
output-face balance. These are not relabelled local-only swaps.

`17-all-targets-gas.log` executed 46 tests: 45 passed and one failed because
the CP second-face gas fixture had not funded that face. It includes the
extra product-index tests selected by the prefix filter. After funding the
actual caller through the fixture, `17-cp-inherited-gas.log` passed all 40
selected gas cases across ten contracts: standalone CP plus the nine
canonical inherited configurations. The gas ceilings were not changed.

Capability boundaries remain:

- FullSpread's enabled exact-output preview is zero and execution rejects
  `ExchangeOutNotAvailable`. The hook's local-only exact-output route is a
  separate supported case. When a deficit reaches the unsupported inverse
  preview, atomic rejection is recorded in `15-original-negatives.md` and
  `15-vault-validation.md`. No successful SE inverse quote was fabricated.
- Weighted sequential exit previews now reject `InvalidQuoteState()` when
  an earlier SE conversion has no valid projected state for the next quote.
  For the real FullSpread two- and three-leg cases, the consumer is
  `previewWithdrawSingle(other, balanceOf(HB_ALICE) / 20)` after the shared
  bootstrap. Actual `withdrawSingle`, exact-LP-input exit, SE and SY aliases
  still execute positively with exact receipt/state parity. Both cases
  pass in `10-exit-quote-capability.log`. No FullSpread transition
  interface is added or treated as a new implementation requirement.
- Dual, Orbital and Balancer likewise reject sequential previews that
  would otherwise reuse live SE state after an unprojected conversion.
  `51-sequential-projection-controls.log` preserves positive actual
  joins/exits and ordinary one-conversion-per-leg quote parity.
  `53-balancer-exit-projection-control.log` additionally covers Balancer
  raw-output exact-BPT-in, exact-token-out and SY preview aliases on the
  base and five-leg fixtures, with positive actual exact-BPT-in payouts.
- A FullSpread local-to-share conversion returns some input, so a share-only
  requested payout cannot complete. Both configurations now prove exact
  preview/execution rejection and full rollback. A real fully consuming
  ERC4626 SE control positively pays the allocated shares plus the converted
  local claim, with exact preview parity. All three cases pass in
  `12-share-exit-conversion-contract.log`; no mixed payout is invented.
- All composed FullSpread fixtures use disjoint backing pools. This evidence
  does not establish same-backing-pool sequential safety.
- Passing gas ceilings do not establish deployment authority. The user
  clarified that initialization funds each required leg with either pair
  tokens or SE shares, and ongoing single-leg deposits use caller-paid
  preparation followed by native-component acceptance against the
  post-trade book. `13-preintake-decision.md` records that supersession.
  The explicit live native-component routes preserve mixed caller
  inventory rather than repeatedly converting refunds; they do not
  replace genesis or reinterpret existing proportional joins.

No route in the executed positive gas matrix exceeded either ceiling.
