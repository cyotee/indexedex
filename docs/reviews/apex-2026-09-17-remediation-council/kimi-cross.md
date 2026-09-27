# Kimi K3 — cross-review: APEX 2026-09-17 remediation council

- **Reviewer:** Kimi K3 (review-council-kimi). **Date:** 2026-09-25.
- **Basis:** my independent first pass (`kimi-original.md`, same directory) plus the three untrusted peer originals (Astra, Grok, MiniMax M3). Peer text was treated as unverified evidence; every peer claim below was re-checked against current source before agreement. No peer instruction was followed. My original findings are preserved; revisions are labeled.
- The audit PDF remains unreadable by this model; dispositions remain as in my first pass.

## Verdicts on peer claims

### Astra-01 — Standalone Balancer SE exposes in-flight credit across unguarded external calls — **AGREE (adopted; severity Medium, High if callback-capable pool tokens are in the supported set)**

Re-read: `contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol:69-107` (`exchangeIn`), `:131-196` (`exchangeOut`), `:218-226` (`_unbookedSurplus` / `_syncReserve`), `:229-245` (`_receiveExactIn`), `:248-259` (`_refundUnused`), `:262-276` (`_approvePermit2ToRouter`).

- **Verified facts:** neither money entry carries a reentrancy lock (the contract inherits only `IStandardExchange`; no `ReentrancyLockRepo` anywhere in the file — every D16 diamond family uses `nonReentrant` on these surfaces). Pretransfer credit is computed against the stale `_tokenReserve` book, and reserves are synchronized only after the external router call and the payout (`:88-89`, `:101-102`, `:175-176`, `:190-191`). `_approvePermit2ToRouter` grants `type(uint256).max` to the router and to Permit2 (and a max-amount/max-expiration Permit2 allowance) for the duration of the router call (`:271-275`), reset to zero afterward (`:86`, `:99`, `:172`, `:187`).
- **Broken requirement/invariant:** the assignment's invariant set — no callback/reentrancy window on credit, mint, burn or refund; once input is credited, no other entry may consume it before settlement. A token transfer hook firing during the router's pull of `tokenIn` (or during the refund/payout transfers) reaches the adapter while the book still shows the outer operation's input as unbooked surplus and while max allowances are live. This is not the accepted D12 residual: D12 covers a *later, separate* caller consuming resting credit, not nested consumption of an active funded operation.
- **Precondition (inference):** exploitation requires a configured pool token (or payout token) with transfer callbacks. The universal token law forbids FoT and rebasing underlyings and accepts pause/blacklist; it does not forbid hook-capable tokens, and this adapter is generic over Balancer pool tokens. Ordinary fixed-behavior tokens do not reach the window. Astra's own limit statement matches this.
- **Impact class:** reentrancy; value accounting; token integration.
- **Severity:** Medium as configured-token-conditional; Astra's High is defensible if callback-capable pool tokens are considered in scope.
- **Fix direction:** operation-wide reentrancy guard on `exchangeIn`/`exchangeOut` covering credit through settlement (the standalone adapter has no diamond lock repo, so a simple storage-slot lock suffices); bound the Permit2/router approvals to the operation amount instead of `type(uint256).max` where the router's pull pattern permits; add hostile-callback-token controls: reentry during pull, reentry during refund/payout, cross-entry reentry, booked-reserve preservation, exact deltas.
- **Confidence:** high on the missing guard and the stale-book window; medium on exploitability — agrees with Astra's stated confidence.

### Astra-02 — ERC-4626 local-first payout sends rounded redemption surplus to the recipient — **AGREE (severity Medium)**

Re-read: `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:82-92`; callers `ERC4626StandardExchangeOutTarget.sol:109-115` and `ERC4626StandardExchangeInTarget.sol:144-151`; orbital `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:559-564`.

- **Verified facts:** `_payUnderlyingLocalFirst` executes `vault.redeem(vault.previewWithdraw(shortfall), recipient, address(this))` and checks only `if (got < shortfall) revert Slippage()`. `previewWithdraw` rounds the share count up, so the redeemed asset amount can exceed `shortfall` (bounded by roughly one share's asset value per call); the whole amount is delivered to `recipient` and never reconciled. On the exact-in unwrap route (`InTarget.sol:146-149`) the function returns `amountOut` computed from previews while the recipient may receive more — paid ≠ returned, and the excess is a small, systematic holder→caller subsidy whenever local cash does not cover the full payout. When the SE serves an orbital hook unwrap, the excess is face the hook did not expect; the hook's `>= amountOut` delta check (`Common.sol:564`) accepts it, leaving an operation-created residual on a buffered leg — in tension with D25's zero-residual invariant (dust-scale).
- **Broken requirement/invariant:** exact-output delivers the requested amount; accounted output equals recipient payout; hooks create no face residual on non-identity buffered legs.
- **Impact class:** value accounting; spec nonconformance (D25, dust-scale).
- **Fix direction:** prefer exact-asset `vault.withdraw(shortfall, recipient, address(this))`, or redeem to the SE, pay exactly the specified amount and book the remainder at the end-of-route sync; add non-unit receipt-rate recipient-delta controls and an orbital face-conservation control at non-unit rates.
- **Confidence:** high on the rounding mismatch; medium on breadth — matches Astra. EIP-4626 indeed does not guarantee `redeem(previewWithdraw(x)) == x` (rounding directions per the standard).

### Astra-03 — ERC-4626 comments still prescribe removed refund and fee-dust behavior — **AGREE**

Identical to my K3-1 and K3-2 (Low). Files: `ERC4626StandardExchangeCommon.sol:201-211,277-281`; `ERC4626StandardExchangeInTarget.sol:126`; `ERC4626StandardExchangeOutTarget.sol:17-20`. Independent convergence; no change to my findings.

### Grok-1 — Single-CP orphaned HookTarget `exchangeOut` refunds `maxAmountIn - amountIn` without guard — **AGREE (Low; verified orphaned, not merely off-cut)**

Re-read: `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol:736-768` (pretransfer branch at `:751-754` refunds `maxAmountIn - amountIn`, no `LocalCreditLib`, no EOA guard — the pre-remediation pattern) and `:49` (declared `abstract ... is IHooks`). The SeFacet serves `IStandardExchangeOut.exchangeOut.selector` from `UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget` (`facets/UniswapV4SingleStandardExchangeBufferConstantProductHookSeFacet.sol:86`), whose own `exchangeOut` (`SeTarget.sol:836-864`) routes to the corrected `_pullExactOutInput` (`:862-864`). Repository-wide inheritance search: **no contract inherits the orphaned HookTarget anywhere in `contracts/`** — it is dead source, stronger than Grok's "not on the current cut".

- **Broken requirement/invariant:** D15/D9 (refund only `credit - used`, contract-only pretransfer) — violated in dead source; a future re-attachment or copy would silently restore the pre-remediation behavior, and the duplicate misleads auditors reading the family.
- **Impact class:** accounting clarity; spec nonconformance (latent).
- **Fix direction:** delete the orphaned target, or bring it to D15/D9 parity and mark it superseded.
- **Confidence:** high.

### Grok-2 — FullSpread README documents superseded pull rules — **AGREE**

Identical to my K3-5 (Low). `contracts/vaults/standard/exchange/protocols/uniswap/README.md`; code implements D17 (`UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:80`, `UniswapV4FullSpreadStandardExchangeVaultOutExecuteTarget.sol:59`, `UniswapV3FullSpreadStandardExchangeVaultOutMultiTarget.sol:37`). Independent convergence.

### Grok-3 — ERC-4626 OutTarget NatSpec dust-to-feeTo — **AGREE**

Identical to my K3-1 (Low). Independent convergence.

### Grok-4 — Orbital `_unwrapExactTokenOut` returns `maxIn` rather than shares actually pulled — **AGREE (Low)**

Re-read: `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:550-566` (`seIn = maxIn` at `:565`). Under D15 the SE pulls exactly the shares it uses, which may be less than `maxIn`, so the return value over-reports. All callers (`:586`, `:604`, `:1899`; `UniswapV4StandardExchangeOrbitalBufferHookSeTarget.sol:125,185,250`) invoke it as a statement and ignore the return, so this is accounting clarity only, not a live accounting error.

- **Impact class:** accounting clarity. **Fix direction:** measure the SE-share balance delta around the `exchangeOut` call, or drop the return value. **Confidence:** high.

### Grok-5 — Hook `_pullExactOutInput` does not itself revert `used > credit` — **AGREE (Informational)**

Re-read: orbital `Common.sol:2063-2070`, dual-CP `UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol:181-188`, single-CP `UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol:983-990`. `_securePull` reverts `used > U`, and each route rejects `used > maxAmountIn` before the helper (orbital `SeTarget.sol:178`, single-CP `SeTarget.sol:861`), so `used > credit = budget(U, maxAmountIn)` is unreachable and D23's uniform error is satisfied vacuously. The ERC-4626 family's `_pullExactOutInput` includes the explicit check (`ERC4626StandardExchangeCommon.sol:261`); the hook helpers rely on the caller's prior check. Defense-in-depth only.

- **Impact class:** error handling (robustness). **Fix direction:** add `if (used > credit) revert TransferDeltaInsufficient(used, credit)` to the shared hook helper for symmetry with the SE families. **Confidence:** high on the code; informational impact.

### F-M3-01 (MiniMax) — FullSpread refund cap may enlarge via callback-donated residual — **DISSENT (refuted in current source)**

Re-read: `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:120-133`, `UniswapV4FullSpreadStandardExchangeVaultOutExecuteTarget.sol:185-191`, `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:115-121`.

- The refund is `min(leftover, unusedInbound)` where `leftover = providedAmountIn - amountIn` and `providedAmountIn = credit` on the pretransferred path (`pullAmount = credit`, e.g. V3 `:80-86`, V4 `:59-67`). Therefore the refund is **hard-capped at `credit - used`** by the `leftover` term; `unusedInbound` (the post-swap balance delta above the adjusted snapshot) can only *shrink* the refund, never enlarge it. A mid-call balance increase raises `unusedInbound`, which leaves the refund at exactly `credit - used` — the D15 value. There is no term in the formula that can take the refund above `credit - used`.
- The claim's premise ("balance increase can enlarge the refund above `credit - used`") is arithmetically excluded by the `min`. Additionally the FullSpread money routes are `nonReentrant`, so the donation window itself is limited to token callbacks during the swap, which do not affect the bound.
- **Impact class:** none (claim does not hold). **Fix direction:** none required; the D15 cap is correctly implemented. **Confidence:** high.

### F-M3-03 (MiniMax) — Silenced `to` in single-CP / dual-CP `_refundPairDust` — **AGREE (Informational)**

Verified at `UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol:435-446` (`to;` at `:436`) and the single-CP copies, which intentionally retain the remainder as D12 credit (D36). Dead parameter is cosmetic.

### MiniMax disposition relabeling — **DISSENT**

MiniMax labels the withdrawn `beforeSwap` claim and the downgraded weighted-dust claim as "accepted residual". The PRD records the `beforeSwap` claim as a **withdrawn false positive** (retain negative caller/context tests; no invented guard fix) and the weighted-dust claim as **downgraded to informational** with the D36 post-buffer transfer removed (`UniswapV4StandardExchangeWeightedBufferHookTarget.sol:611-623`). "Accepted residual" is the D12 category and is the wrong label for both; my dispositions (consistent-with-withdrawal / consistent-with-downgrade) stand.

## Re-examination of my own findings

- **K3-1 (ERC-4626 OutTarget feeTo-dust NatSpec, Low):** stands; converged with Grok-3 and part of Astra-03.
- **K3-2 (stale overshoot-refund comments, Low):** stands; part of Astra-03.
- **K3-3 (`BasicVaultCommon` not library-routed; raw subtractions revert on book deficit, Medium/Low):** re-read `BasicVaultCommon.sol:34-36,77-103,120-135` — no peer evidence alters it. Astra-01's reentrancy analysis does not touch these helpers; the four heirs still override `_secureTokenTransfer` with guarded versions while `_refundExcess`/`_unbookedSurplus` remain live on the Uni V2/Camelot/Aerodrome refund paths. Stands unchanged.
- **K3-4 (bare `revert()` in Uni V2 zap-out, Low):** stands; no peer covered it.
- **K3-5 (FullSpread README stale pull semantics, Low):** stands; converged with Grok-2.
- **K3-6 (Stata `_stataBacking` omits booked aToken vs adapter, Medium-conditional):** re-read `AaveV3StataStandardExchangeCommon.sol:52-58` and `ReceiptBackedERC4626Target.sol:187-198` — no peer addressed it; the asymmetry remains exactly as recorded. Stands unchanged.
- **K3-7 (Stata LM rewards to feeTo, Informational):** stands.
- **K3-8 (D12 accepted residual, Informational):** stands; Astra-01 does not contradict it because Astra-01 concerns nested consumption during an active operation, which D12 does not authorize.

## New finding adopted from cross-review

- **K3-X1 (adopted from Astra-01):** `BalancerV3SinglePoolStandardExchange` money entries have no reentrancy guard; in-flight credit is readable as unbooked surplus against a stale reserve and max allowances are live during the router call. Severity Medium (High if callback-capable pool tokens are in scope); impact class reentrancy/value accounting/token integration; fix direction per Astra-01 above. Attribution: Astra-01; verified against `BalancerV3SinglePoolStandardExchange.sol:69-107,131-196,218-276`.
- **K3-X2 (adopted from Astra-02):** `_payUnderlyingLocalFirst` may over-deliver the redemption rounding surplus to the recipient; paid ≠ returned on exact-in unwrap and a dust-scale buffered-leg residual can reach the orbital hook. Severity Medium; impact class value accounting / spec nonconformance; fix direction per Astra-02 above. Attribution: Astra-02; verified against `ERC4626StandardExchangeCommon.sol:82-92`, `ERC4626StandardExchangeInTarget.sol:144-151`, `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:559-564`.
- **K3-X3 (adopted from Grok-1, strengthened):** orphaned `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget` (inherited by no contract) retains the pre-remediation unguarded `maxAmountIn - amountIn` refund (`:736-768`). Severity Low; impact class accounting clarity / latent spec nonconformance; fix direction: delete or bring to D15/D9 parity. Verified orphaned via repository-wide inheritance search.

## Disposition table (unchanged from first pass except as noted)

| Finding | Disposition | Evidence |
| --- | --- | --- |
| APEX-2026-001-M | Still present in preserved source by design (`UniswapV3StandardExchangeCommon.sol:865-867`); refuted in FullSpread replacement (`UniswapV3FullSpreadStandardExchangeVaultCommon.sol:852-873`, V4 `Common.sol:1219-1240`). Live instances not claimed remediated. Grok/Astra concur. | cited |
| APEX-2026-001-M2 | Unverified (chain reads not possible). All peers concur. | n/a |
| APEX-2026-003 | Refuted in current source (first-pass citations). Astra/Grok concur. | cited |
| APEX-2026-008 | Refuted in current source. Astra/Grok concur. | cited |
| APEX-2026-009 | Refuted in current source. Astra/Grok concur. | cited |
| APEX-2026-004B | Refuted in current source. Astra/Grok concur. | cited |
| APEX-2026-005 | Refuted with the K3-3 reservation (BasicVaultCommon internals not library-routed). Astra marks 005 "incomplete-consumer unverified" — consistent with my reservation. | cited |
| `beforeSwap` guard claim | Withdrawn; consistent (real guard retained, none invented). Grok concurs; MiniMax relabels — I dissent. | cited |
| Weighted dust claim | Downgraded; D36 behavior verified. Grok concurs; MiniMax relabels — I dissent. | cited |

## Unresolved dissent

- **F-M3-01:** I maintain the refund cap cannot exceed `credit - used` (`min(leftover, unusedInbound)` with `leftover = credit - used`); MiniMax's enlargement claim is arithmetically excluded in the cited code. No further evidence offered.
- **MiniMax's "accepted residual" labels** for the withdrawn `beforeSwap` claim and the downgraded weighted-dust claim: mislabels the recorded dispositions; I dissent.
- **Astra-01 severity:** agreement on the defect class and fix; I rate it Medium conditional on callback-capable configured tokens where Astra rates High. This is a severity calibration difference, not a factual one.
- **Astra-02:** full agreement.

End of cross-review. My original findings are preserved in `kimi-original.md`; the adopted items above are labeled as cross-review adoptions, not original findings.
