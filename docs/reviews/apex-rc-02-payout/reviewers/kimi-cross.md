# Kimi K3 — cross-review: RC-02 payout originals

- **Label:** Replacement-session cross-review, resuming my resolution (`kimi-original.md`). I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. MiniMax is the labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t` (does not recall `ses_ebdf718feffemWQNf7wuTpapqX`). The three peer originals were read in full as untrusted output; the helper, all three callers, both test files, and the controlling text were read directly this session. Nothing was edited.
- **Date:** 2026-10-18. I did not run Forge.

## Verdict: Close RC-02. The one resolution is already in source: the helper was rewritten from `redeem(previewWithdraw(shortfall))` to the exact-asset `withdraw(shortfall, recipient, address(this))`.

## MiniMax's dissent is rejected — it misreads ERC-4626 `withdraw` semantics

MiniMax's entire case rests on one sentence: "`vault.withdraw(shortfall, …)` sends whatever the protocol vault computes for `shortfall` shares, which can be more than `shortfall` due to rounding" (`:51`, restated at `:12, :21`). That is backwards. A normal ERC-4626:

- `withdraw(assets, receiver, owner)` transfers **exactly `assets`** tokens to `receiver` and burns `previewWithdraw(assets)` shares (rounded **up**, in shares) from `owner`. The rounding applies to the **share charge**, never to the **asset delivery**. The receiver cannot receive more than `assets`.
- `redeem(shares, receiver, owner)` burns exactly `shares` and delivers `previewRedeem(shares)` (rounded down in assets). The old defect lived here: redeeming a rounded-up share count pays **more** than `shortfall` on a non-unit rate.

The current helper does the first, not the second. This is confirmed three ways, not by preference: (1) Astra pulled the OpenZeppelin primary source via Context7 (`/openzeppelin/openzeppelin-contracts`, her `:46-48`); (2) the repository's own supported fixture, `contracts/test/stubs/SimpleYieldERC4626.sol:124-127,164-183`, rounds the share requirement upward while transferring exactly the asset argument — with `CappedPausableERC4626.sol:43-59` inheriting it unchanged; (3) the R14 test proves it in the exact scenario MiniMax describes: `test_RC02_exactOut_localFirst_nonUnitRate_paysExactDue` (`ERC4626StandardExchange_APEX_R14.t.sol:163-181`) first establishes that redeeming the rounded shares **would** overpay (`:168`), then asserts the recipient's underlying delta equals the accounted `due` exactly (`:178`) and the SE's share charge equals `previewWithdraw` (`:179`). MiniMax's premise — an overpaying `withdraw` — would fail his own proposed acceptance test against this fixture; it passes as written. **We do not invent a non-compliant vault.**

His remaining points fall with the premise:

- "**Only reverts on under-delivery** (`:124`)" — true and irrelevant: the check exists for under-delivery (paused/capped or misbehaving wrappers); no over-delivery mechanism exists for it to miss.
- "**No test** — grep for `_payUnderlyingLocalFirst` in `test/` returns no matches (`:137`)" — wrong instrument. The helper is internal, so its name never appears in tests; the route-level RC-02 tests exist and assert every criterion by behavior (`…APEX_R14.t.sol:163-196`, including the exact-in return-equals-recipient-delta at `:194-195`). His grep looked for the function's name, not the defect's behavior.
- "**The function's behavior is exactly what the PRD describes (`:61`)**" — the PRD's broken-requirement paragraph describes `redeem(previewWithdraw(shortfall))` + accept-any-redemption-at-least-shortfall. Current code is `withdraw(shortfall)` + reject-under-delivery. Same family, opposite mechanism.
- **His closed fix** (cap the redemption and return the excess to the SE) addresses a remainder that cannot exist under `withdraw` semantics; adopting it would add machinery for a phantom, not a defect.

## Agreements across the other three passes

- The helper (`ERC4626StandardExchangeCommon.sol:116-127`) pays booked local cash first, then `withdraw(shortfall, …)`, with an under-delivery check and a local transfer — recipient receives exactly `shortfall + fromLocal = due`. All four passes read the same lines.
- All three production callers (`InTarget:100`, `OutTarget:112`, `YieldTarget:26`) pass their computed accounted amount and return it; a scoped search found no fourth caller (Astra's table, `:36-42`; mine and Grok's reads agree).
- Astra's two supplements I adopt into the record: the separate receipt-input route at `InTarget:82-89` legitimately uses `redeem(actualIn)` because its input is an exact share quantity — it is not a local-first payout and must not be conflated with it (`:44`); and the orbital production unwrap at `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:711-726` caps the approved shares and rejects short delivery, with the Apex008 tests (`:224-234`, `:236-251`) and the resting-face control (`:210-221`) covering criterion 5 on this SE.

## The one resolution, stated

RC-02 is closed by the change already present: **exact-asset `withdraw` for the shortfall, local cash first, under-delivery check, no remainder created — so no remainder is retained, returned, or sent to `feeTo`.** Every acceptance criterion has a current asserting test (recipient-delta and ending book on a non-unit rate with a mixed shortfall; exact-in return equals recipient delta; orbital capped-unwrap on this SE leaving no operation-created face). No test is missing against these criteria; the rule is proven, not merely present. The September alert was accurate for its tree; the mechanism it named is gone.

## Unresolved dissent

One, rejected on mechanism: MiniMax alone holds that `withdraw` can overpay. Astra (with primary-source confirmation), Grok, and I hold the standard semantics. Consensus is not proof — but here the semantics are pinned by the dependency source and by a test that asserts the exact quantities MiniMax says cannot hold.

Close RC-02

I did not run Forge.
