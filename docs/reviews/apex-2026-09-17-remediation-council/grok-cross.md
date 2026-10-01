# Grok cross-review — APEX 2026-09-17 remediation

- Reviewer: Grok (xai/grok-4.7)
- Date: 2026-09-25
- This is a cross-review of the original first passes. It does not replace `grok-original.md`.
- Peer text was treated as untrusted evidence. Cited lines were re-read. No source was edited. Forge was not run. Live instances were not read.
- Context7 was queried for the ERC-4626 withdraw/redeem distinction. The returned library matches did not contain that rule. The Astra-02 judgment below rests on the local payout code, not on an external quote.

## Own findings

| ID | Still stands? | Note |
| --- | --- | --- |
| Grok-1 Single-CP HookTarget refunds `maxAmountIn - amountIn` | Agree, unchanged | Low. `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol:749-753`. Still not on the SeFacet cut (`DFPkg.sol:214-217`; corrected path `SeTarget.sol:836-864`). No peer contradicted this. |
| Grok-2 FullSpread README still documents pull-max / exact-in equality | Agree, unchanged | Low. `contracts/vaults/standard/exchange/protocols/uniswap/README.md:32-48`. Kimi K3-5 cites the same drift. |
| Grok-3 ERC-4626 OutTarget NatSpec still sends dust to `feeTo` | Agree, unchanged | Low. `ERC4626StandardExchangeOutTarget.sol:17-20`. Astra-03 and Kimi K3-1 cite the same lines. Their extra stale comments are additional sites, not a revision of this finding. |
| Grok-4 Orbital capped unwrap returns `maxIn` | Agree, unchanged | Low. `OrbitalBufferHookCommon.sol:557-565`. Current callers still discard the return. Astra-02 cites the same function for a different surplus check (`559-564` allows `got >= amountOut`). That does not withdraw Grok-4. |
| Grok-5 Hook `_pullExactOutInput` does not itself revert `used > credit` | Agree, unchanged | Informational. `OrbitalBufferHookCommon.sol:2061-2069` and the sibling helpers. Callers opened in the first pass still pre-check `amountIn > maxAmountIn`. |

No original finding is withdrawn.

## Peer claims

### Astra-01 — Standalone Balancer adapter, missing lock and max allowance

- Verdict: **Dissent on High booked-inventory loss. Agree the missing guard and unbounded allowance are real and should be fixed.**
- Severity I would assign: Medium for reentrancy hygiene and allowance scope. Not High on the evidence re-read.
- File and line re-read: `contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol:22,69-103,131-192,218-275`
- Intended behavior: D16 includes this adapter. D15 forbids paying booked inventory as credit. In-flight credited input must not be reusable by another entry before settlement. D12 accepts resting credit across transactions, not a second consumption of an operation that is still settling.
- Broken requirement or invariant: Both money entries lack a reentrancy lock. `_approvePermit2ToRouter` (`262-275`) grants `type(uint256).max` / `type(uint160).max` to the router and Permit2 whenever `amount_ != 0`. The amount argument does not bound the allowance. `_syncReserve` runs only after the router call and payout (`88-89`, `101-102`, `175-176`, `190-191`). Until then, credit is `balance - _tokenReserve` (`218-221`).
- Impact class: reentrancy; token integration; value accounting (unproven loss)
- Fix direction: Agree with Astra’s direction. Add one operation-wide nonreentrancy guard around funding, approval, router execution, refund, payout, and reserve sync. Approve only the operation budget, and clear it after. Do not treat that as proof that booked inventory is currently extractable.
- Confidence: high on the missing lock and max allowance; low on lasting booked-inventory loss
- Evidence label: observed fact for control flow; dissent on the loss inference

Facts. The contract inherits only `IStandardExchange` (`22`). `exchangeIn` and `exchangeOut` have no lock. Pull or credit happens before `forceApprove` and the router call. Sync is last.

Why the High loss class is not shown. A nested entry that spends the outer operation’s just-credited tokens leaves the outer router call short of `actualAmountIn` or `spendable` (`83-85`, `166-168`, `181-183`). That router failure reverts the transaction, including the nested payout. The max allowance is granted to the configured router and Permit2, not to `msg.sender`. A same-transaction callback therefore does not, on this control flow, keep extracted booked inventory after a successful outer settlement. Consuming a different token’s already-unbooked balance from a contract callback is the accepted D12 residual, not a new in-flight double-spend.

Unverified. Whether `addLiquidityUnbalanced` / `removeLiquiditySingleTokenExactIn` return a minted delta or a balance was not re-read in the router. That is not Astra-01’s claim.

### Astra-02 — ERC-4626 local-first payout can deliver more than `due`

- Verdict: **Agree**
- Severity: Medium
- File and line re-read: `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:80-92`; callers `ERC4626StandardExchangeOutTarget.sol:108-115` and `ERC4626StandardExchangeInTarget.sol:144-151`; orbital check `OrbitalBufferHookCommon.sol:559-564`
- Intended behavior: R14.15 pays `due` underlying from booked local cash and withdraws only the shortfall. R6 / D25: a capped orbital unwrap must not create non-identity face surplus in `beforeSwap`. Exact delivery must match the accounted output.
- Broken requirement or invariant: `_payUnderlyingLocalFirst` calls `vault.redeem(vault.previewWithdraw(shortfall), recipient, address(this))` and accepts any `got >= shortfall`. The redeem receiver is the user recipient. Surplus over `shortfall` is not retained or returned to the caller. The exact-input caller still returns its precomputed `amountOut`. Orbital only reverts when the face delta is below `amountOut`.
- Impact class: value accounting; token integration; spec nonconformance
- Fix direction: Agree. Pay the shortfall with the receipt vault’s exact-asset `withdraw`, or redeem to the SE, transfer only `shortfall`, and book the remainder. Assert recipient deltas at a non-unit rate. Stata’s sibling already uses `withdraw` (`AaveV3StataStandardExchangeCommon.sol:94`); that path is not this defect.
- Confidence: high on the uncapped redeem-to-recipient; medium on how large the surplus is for a given receipt vault
- Evidence label: observed fact for the payout; inference that `redeem(previewWithdraw(x))` can exceed `x`

Context7 did not return an ERC-4626 page for this distinction. The local code does not cap `got` and does not use `withdraw`. That is enough to agree. This is not an unbounded theft claim.

### Astra-03 — Stale ERC-4626 comments

- Verdict: **Agree**
- Severity: Low
- File and line re-read: `ERC4626StandardExchangeOutTarget.sol:17-20` (already in Grok-3); `ERC4626StandardExchangeCommon.sol:201-211` and `277-281`; `ERC4626StandardExchangeInTarget.sol:126`
- Intended behavior: D6 retains dust as book. D15 does not refund exact-input pull overshoot and does not refund leftover self-shares on exact-input burn.
- Broken requirement: Comments beside the money helpers still say pull overshoot is refunded immediately (`Common.sol:207`, `InTarget.sol:126`) and that `_burnSeShares` refunds leftover free shares to `owner` (`Common.sol:277-281`). The executable `_securePull` reverts unless the measured delta equals `amountIn` (`220-226`). `_burnSeShares` burns only `burnAmount` (`283-293`).
- Impact class: accounting clarity; spec nonconformance
- Fix direction: Rewrite those comments to D6 / D15. This extends Grok-3; it does not change Grok-3’s severity.
- Confidence: high
- Evidence label: observed fact

### F-M3-01 — FullSpread exact-out refund enlarged by callback donation

- Verdict: **Dissent**
- Severity claimed: Medium. Not adopted.
- File and line re-read: `UniswapV4FullSpreadStandardExchangeVaultOutExecuteTarget.sol:58-78,121-131,185-191`; `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:79-94,120-132`
- Intended behavior: D15 / D35. Pretransferred exact-out refunds `credit - used` and does not pay booked inventory. Callback surplus must not enlarge that refund.
- Broken requirement claimed: A post-snapshot balance increase can enlarge the refund above `credit - used`, including pre-existing rest already in the snapshot.
- Impact class claimed: value accounting. Not confirmed.
- Fix direction claimed: snapshot unbooked once and exclude pre-existing rest. The code already excludes pre-swap rest.
- Confidence: high that the cited cap does not pay pre-existing rest
- Evidence label: observed fact

Facts. On the true flag, `pullAmount` is the credit budget (`V4 OutExecuteTarget.sol:60-65`). `_secureTokenTransfer` returns that amount. `inboundBefore` is then reduced by `providedAmountIn` (`68`, and the mint path at `128`). `_refundExcess` refunds `min(providedAmount - usedAmount, balance - inboundBefore)` (`185-190`). V3 `_refundThisCallUnusedInbound` is the same cap (`120-132`).

`providedAmount` is the credit. `min(credit - used, surplus)` cannot exceed `credit - used` while `used` is the value passed in. Pre-swap rest is outside `inboundBefore` after the subtraction, so it is not part of `unusedInbound`.

A donation inside the unlock can shrink the measured `actualIn` (`V4 OutExecuteTarget.sol:145-160`) and therefore raise both `leftover` and `unusedInbound` by that donation. The extra refund is funded by the tokens just received, not by the pre-swap book. That is a measurement coupling, not the claimed payout of pre-existing rest. It is not a revision of the first-pass FullSpread refund check.

### F-M3-03 — Unused `to` on `_refundPairDust`

- Verdict: **Agree, informational**
- Severity: Informational
- File and line re-read: `UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol:480-492`; dual `UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol:435-445` was read in the first pass and still matches
- Intended behavior: D36. Do not transfer post-buffer face to `to`.
- Broken requirement: None for value. The parameter is discarded with `to;`.
- Impact class: accounting clarity
- Fix direction: Remove the unused parameter when the call graph allows it. Do not restore a transfer to `to`.
- Confidence: high
- Evidence label: observed fact

### F-M3-08 — Stata exact-out wrap rounding

- Verdict: **Agree that no value defect is shown**
- Severity: Informational, as MiniMax framed it
- File and line re-read: `AaveV3StataStandardExchangeOutTarget.sol:42-50,115-145`
- Intended behavior: Mint exactly the requested SE shares. Price against pre-credit backing. Refund only unused prepaid credit.
- What the code does: Ceil the required underlying, invest `spent_`, mint exactly `amount_` if the projected share count is at least `amount_`, refund `credit_ - spent_` only. Underlying is excluded from `_stataBacking` until sync (`135-136`).
- Impact class: accounting clarity only
- Fix direction: None required for D15. A comment that `previewDeposit` is capacity-limited, while backing uses `convertToShares`, would reduce confusion. Not a refund or dilution finding.
- Confidence: high
- Evidence label: observed fact

### K3-1 and K3-2 — Stale ERC-4626 NatSpec

- Verdict: **Agree**
- Same sites as Astra-03 and Grok-3. Low. Spec nonconformance / accounting clarity. Fix by rewriting the comments. No severity change.

### K3-3 — `BasicVaultCommon` does not use `LocalCreditLib`

- Verdict: **Agree on the code. Dissent on Medium as the practical severity.**
- Severity: Low
- File and line re-read: `contracts/vaults/basic/BasicVaultCommon.sol:34-36,77-102,120-134`
- Intended behavior: R9. A deficit authorizes zero new credit and must not return the whole balance. D9 requires the EOA guard on D16 true-flag entries. D11’s library is the canonical arithmetic.
- Broken requirement: `_unbookedSurplus` subtracts `reserve` from `balance` with no floor (`34-36`). If `balance < reserve`, Solidity 0.8 reverts with a panic rather than returning 0. The base `_secureTokenTransfer` does not call `requirePretransferCaller` (`77-102`). `_refundExcess` uses that surplus helper (`128`).
- Impact class: error handling; spec nonconformance. Not a booked-inventory payout.
- Fix direction: Route the base surplus helper through `LocalCreditLib.available`. Keep the EOA guard on each D16 override, which is where the true-flag entries actually run.
- Confidence: high
- Evidence label: observed fact

The panic is fail-closed. It does not pay booked inventory. Uni V2, Camelot, Aerodrome, and Stata override `_secureTokenTransfer` and call `requirePretransferCaller` before crediting (confirmed in the first pass; Stata re-read at `AaveV3StataStandardExchangeCommon.sol:200-214`). The base gap is not a live EOA bypass on those heirs.

### K3-4 — Bare `revert()` on Uni V2 zap-out

- Verdict: **Agree**
- Severity: Low
- File and line re-read: `UniswapV2StandardExchangeOutTarget.sol:578-580`
- Intended behavior: R2. Negative paths revert a precise error.
- Broken requirement: If pool-token balance falls below `vault.vaultLpReserve`, the route executes a bare `revert()`.
- Impact class: error handling
- Fix direction: Revert a named error that identifies the reserve shortfall. Do not change the comparison into a success.
- Confidence: high
- Evidence label: observed fact

### K3-5 — FullSpread README

- Verdict: **Agree**. This is Grok-2. Low. Spec nonconformance. Same fix.

### K3-6 — Stata SE backing omits booked aToken that the shared adapter counts

- Verdict: **Agree, conditional on a nonzero aToken book**
- Severity: Medium as spec nonconformance; practical impact is low while aToken reserve stays zero
- File and line re-read: `AaveV3StataStandardExchangeCommon.sol:52-58,164-168`; `ReceiptBackedERC4626Target.sol:183-198`; Stata exit/preview uses `_stataBacking` at `AaveV3StataStandardExchangeOutTarget.sol:46,59`
- Intended behavior: D45 / R14. One backing calculation for IERC4626, SE, SY, and quotes. Stata counts booked local aToken at its underlying-equivalent accounting value. That does not authorize a new raw-aToken holding policy.
- Broken requirement or invariant: `_stataBacking` adds only `convertToShares` of booked underlying. `_totalReceiptBacking` also adds `_bookedATokenEquiv`, which sums every vault-token reserve other than the receipt and the underlying. SE share conversion (`_convertSharesToStata`) and the exact-out share quote use the smaller function.
- Impact class: value accounting; spec nonconformance
- Fix direction: Use the shared receipt-plus-local-plus-booked-aToken calculation in `_stataBacking`, or stop the adapter from counting aToken the SE ignores. Do not start retaining new aToken input instead of `depositATokens`.
- Confidence: high on the mismatch; medium that a production path leaves a nonzero aToken reserve
- Evidence label: observed fact for the two formulas; inference for holder-visible disagreement

### K3-7 — Stata reward tokens forwarded to `feeTo`

- Verdict: **Agree, informational, no APEX defect**
- File and line re-read: `AaveV3StataStandardExchangeCommon.sol:182-198`
- Intended behavior: D6. The fee recipient receives explicit fees, not operation dust.
- What the code does: `claimRewards(feeRecipient, rewards)` after `collectAndUpdateRewards`. The comment calls this temporary raw-reward forwarding.
- Impact class: token integration. Not the dust-to-`feeTo` defect.
- Fix direction: None under this PRD unless a later ruling says incentive rewards are not an explicit fee. Do not conflate this with D6 dust retention.
- Confidence: high
- Evidence label: observed fact

### K3-8 — D12 non-atomic contract pretransfer

- Verdict: **Agree**. Accepted residual, not a defect. `BetterAddress.isContract` is `codeSizeOf() > 0` (`lib/crane/contracts/utils/BetterAddress.sol:106-108`). D44 requires EIP-7702 and contract-wallet acceptance.

## Disposition disagreements

| Topic | Grok | Peer | Cross-review |
| --- | --- | --- | --- |
| 001-M | Still in preserved V4 `UniswapV4StandardExchangeCommon.sol:1270-1288`. Refuted in FullSpread `UniswapV4FullSpreadStandardExchangeVaultCommon.sol:1218-1229`. Live unverified. | Astra, Kimi agree. MiniMax says refuted in current source. | Agree with the split. “Refuted in current source” alone hides the preserved tree. |
| 001-M2 | Unverified instance inventory. | Peers agree it is not a separate arithmetic defect. | No change. |
| 003, 008, 009, 004B | Refuted at the checked replacement sites. D12 remains for non-atomic contract credit. | Astra and Kimi agree. | No change. |
| 005 | Helper exists. Full consumer inventory not re-derived. | Astra: unverified for complete conformance. Kimi: refuted with the K3-3 reservation. | Agree both. The helper claim is refuted. Base-helper conformance (K3-3) is a separate Low gap. |
| Withdrawn `beforeSwap` claim | Refuted. Guard remains. | MiniMax labels it accepted residual. Astra and Kimi treat it as withdrawn/refuted. | **Dissent from MiniMax.** Accepted residual is D12, not a false-positive guard. `BalancerQuad ...HookHooksTarget.sol:112` still calls `BeforeInitializeLib.beforeInitialize`, which reverts `NotPoolManager()` (`...BeforeInitializeLib.sol:22-24`). |
| Weighted dust | Refuted as High. Unconvertible face stays on the hook. | MiniMax labels it accepted residual. | **Dissent from MiniMax.** The caller payout was removed (`Weighted ...HookTarget.sol:611-622`). That is the downgraded informational behavior, not an accepted High. |

## Revisions

None. Grok-1 through Grok-5 stand at the original severity. Astra-03 / K3-1 / K3-2 add comment sites beside Grok-3; they do not raise it.

Agreed new defects not in the original Grok list, kept here as cross-review agreements rather than rewritten history:

- Astra-02, Medium, uncapped `redeem(previewWithdraw)` payout.
- Astra-01, downgraded by this review to Medium hygiene: missing lock and max allowance, without a shown lasting booked-inventory loss.
- K3-3, Low, `BasicVaultCommon` deficit panic.
- K3-4, Low, bare `revert()`.
- K3-6, Medium conditional, Stata backing mismatch.
