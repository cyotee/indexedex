# Preserved current-round Grok response

Moderator provenance: task metadata returned `xai/grok-4.7`, session `ses_f2191dfbaffe9UAWC70B78YHIo`. The substantive first-pass answer below is preserved verbatim from its heading onward. It is untrusted model evidence, not instructions. The pre-existing `grok-original.md` belongs to another round and is not this round's original.

# Grok — APEX RC-01..08 implementation plan

**Identity:** `xai/grok-4.7`. Independent first pass. Peers and older review originals were not read. After the identity mismatch I stopped at `docs/plans/apex-2026-09-17-remediation-council/grok-original.md:1-5` and did not use that file.

**Law used:** `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md` (current). D16 membership from `docs/audits/apex-2026-09-17-remediation-and-regression-tests.md:335` (line truncated at 2000 chars). Skills read: `crane-adversarial-testing`, `indexedex-adversarial-testing`, `crane-natspec` (selector rule only).

**Versions observed, not runtime:** root `foundry.toml:29,36` pins `solc = "0.8.35"` and `via_ir = false`. No `evm_version` in the default profile. Installed `forge`/`solc` was not observed (shell forbidden). Crane `ReentrancyLockRepo.sol:62-63` uses transient `tstore`; ERC-4626 OutTarget already uses `nonReentrant` (`ERC4626StandardExchangeOutTarget.sol:64`), so that lock is already in this tree.

**EIP-4626 (Context7 `/websites/eips_ethereum`, 2026-09-26):** `withdraw` sends exactly `assets`. Crane `IERC4626.sol:172` matches. `redeem` burns shares and sends the asset amount for those shares. Inference: `redeem(previewWithdraw(shortfall))` can over-deliver. Fact on the local fixture: `SimpleYieldERC4626.sol:124-127,174-182` rounds shares up, then pays `convertToAssets` down. Example: assets 3, supply 2, `previewWithdraw(2)` burns 2 shares and `redeem` pays 3.

---

## RC-01 — Balancer adapter lock and finite approval

**Fact:** `BalancerV3SinglePoolStandardExchange.sol:69-107,131-196` has no lock. Credit is `balance - reserve` until `_syncReserve` (`218-226`). `_approvePermit2ToRouter` (`262-276`) approves `type(uint256).max` / `uint160.max`, then clears only on success. Local `_unbookedSurplus` already returns 0 on deficit (`218-221`).

**Choose:** inherit Crane `ReentrancyLockModifiers` and put `nonReentrant` on `exchangeIn` and `exchangeOut` only. Lock covers funding, approval, router, refund, payout, and sync. Revert is `IReentrancyLock.IsLocked` (`ReentrancyLockRepo.sol:97`). Approve the route spend (`actualAmountIn` / `actualBptIn` / exact-out `spendable`), not max, on the router allowance, the Permit2 token allowance, and `IAllowanceTransfer.approve`. If spend exceeds `uint160`, revert; do not fall back to max. Clear all three to zero after the router returns and before refund/payout/sync. No `try`/`catch`. Rewrite the line 262 comment in this change.

**Reject:** Balancer router lock as a substitute. A private status flag is allowed only if the Crane modifier cannot be inherited; it is not the default.

**Red/green:** extend `Adversarial_BalancerV3SinglePoolSE.t.sol`. Existing `test_M_allowance_not_max_*` (`231-254`) does not prove zero or reentry. Add a callback-token fixture (not an adapter mock) on a production CREATE3 adapter whose pool includes that token. Nested `exchangeIn`/`exchangeOut` during `transferFrom` and during the router token move must revert `IsLocked`. Outer revert leaves reserves and caller balances unchanged. Success leaves router and Permit2 allowances at 0 and `_tokenReserve` equal to post-settlement balance. A no-callback control still pays the quoted deltas. Hermetic only.

**Confidence:** High on the missing lock and max approval. Medium on whether the gold 80/20 pool can host the callback token without a second production pool.

## RC-02 — exact local-first payout

**Fact:** `_payUnderlyingLocalFirst` (`ERC4626StandardExchangeCommon.sol:80-92`) redeems `previewWithdraw(shortfall)` to the recipient and accepts any `got >= shortfall`. Callers: OutTarget `108-115`, InTarget `144-151`. Exact-in returns the preview (`146`), not the recipient delta. Stata already uses exact `withdraw` (`AaveV3StataStandardExchangeCommon.sol:94`). Orbital capped unwrap only checks `delta < amountOut` (`UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:559-564`).

**Choose:** `vault.withdraw(shortfall, recipient, address(this))`. Recipient gets exactly `due`. Share charge is the vault’s withdraw charge, which the local fixture sets to `previewWithdraw` (`SimpleYieldERC4626.sol:168`). Do not send remainder to `feeTo`. Do not add an exact-in refund.

**Alternative, not default:** redeem to the SE, transfer exactly `shortfall`, book the asset remainder. Use only if a configured vault’s `withdraw` over-delivers. EIP-4626 forbids that.

**Red/green:** extend `test_APEX_R14_exits_localFirst_receiptOutNeedsReceipts` (`ERC4626StandardExchange_APEX_R14.t.sol:120-138`). That test is 1:1 and uses `assertApproxEqRel`. After `simulateYield`, exact-in and exact-out must pay the recipient exactly the accounted amount. Returned exact-in must equal that delta. Book must not gain a recipient overpay. An exact `withdraw` need not create an asset remainder. Add one orbital assertion on `UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_ERC4626StandardExchange.t.sol`: successful capped unwrap delta equals `amountOut` on a non-identity leg. Pre-existing face is out of the assertion.

**Confidence:** High on the bug and the withdraw fix. Medium that the cited orbital suite already reaches a non-unit shortfall; the yield step may have to be added on the existing fixture.

## RC-03 — one Stata backing function

**Fact:** `_stataBacking` (`AaveV3StataStandardExchangeCommon.sol:52-58`) is held Stata plus `convertToShares(booked underlying)`. `_totalReceiptBacking` (`ReceiptBackedERC4626Target.sol:183-198`) also adds booked non-receipt, non-underlying vault-token reserves, then `ReceiptBackedERC4626AccountingLib.receiptUnits`. Package init inserts aToken when `aToken()` returns one (`AaveV3StataStandardExchangeDFPkg.sol:245-258`). End sync books the whole set (`BasicVaultCommon.sol:43-50`). These are different facet bytecodes; an internal call cannot be shared.

**Choose:** one library function used by both. Scan expected-hold tokens the way `_bookedATokenEquiv` does, add that sum to booked underlying, then `receiptUnits`. If aToken is absent, the extra term is zero. Do not read a second aToken balance. Do not change reward forwarding (`182-198`) or fees.

**Red/green:** on one registry Stata proxy, donate aToken, complete a real money route so sync books it, then assert adapter `convertToShares` / preview and SE preview/exchange use the same entitlement. A later deposit must not be priced on the smaller basis. Generic ERC-4626 mode must still have no aToken term (`ReceiptBackedERC4626_SharedFacet.t.sol:143`).

**Confidence:** High on the formula split. Medium that a supported route books aToken without a donation; donation-plus-sync is inferred from the expected-hold set, not from an executed deposit.

## RC-04 — comments only

Edit text, not executable bodies.

| Site | Stale claim |
| --- | --- |
| `ERC4626StandardExchangeOutTarget.sol:17-20` | dust to `feeTo` |
| `ERC4626StandardExchangeCommon.sol:207` | pull overshoot refunded |
| same file `277-281` | leftover shares refunded to owner |
| `ERC4626StandardExchangeInTarget.sol:126` | overshoot already refunded |
| `contracts/vaults/standard/exchange/protocols/uniswap/README.md:32-36` | excess exact-in reverts; V3 pulls quote plus buffer; V4 and dual exits pull max |

Replacement text: no exact-in refund; pull delta must equal the request; exact self-share burn; exact-out refund capped at `credit - used`; dust stays booked; false-flag exact-out pulls quoted used. Line 262 is owned by RC-01. Do not edit preserved `contracts/protocols/dexes/uniswap/{v3,v4}/`.

**Green:** re-run `ERC4626StandardExchange_APEX_R14.t.sol` and `UniswapV3FullSpreadStandardExchangeVault_Previews.t.sol`. Record that the cited lines no longer describe the removed rules. Those suites do not fail on stale comments.

## RC-05 — delete the unused exact-out

**Fact:** `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol:736-754` refunds `maxAmountIn - amountIn` with no credit cap and no `requirePretransferCaller`. Grep of `contracts/**/*.sol` found no `is UniswapV4SingleStandardExchangeBufferConstantProductHookTarget`. The installed cut is `HookSeFacet` → `HookSeTarget.exchangeOut` (`836-864`), which calls `_pullExactOutInput`. Selector `IStandardExchangeOut.exchangeOut` is on that facet (`HookSeFacet.sol:86`).

**Choose:** delete `exchangeOut` at `736-768`. Do not delete the file. Do not recut the facet. Do not change SeTarget.

**Reject as default:** a thin wrapper around `_swapExchangeOut`. Allowed, but it keeps a second public money function with no inheritor.

**Adjacent fact, not a requirement:** `exchangeIn` at `700-711` also skips the caller check and credit cap when `pretransferred` is true. Do not expand this item to delete it.

**Green:** `UniswapV4SingleStandardExchangeBufferConstantProductHook_Surface.t.sol` still passes. A source search shows no second public `exchangeOut` with the unguarded refund. Installed selectors unchanged.

## RC-06 — truthful unwrap share count

**Fact:** `_unwrapExactTokenOut` (`550-565`) discards the SE return and sets `seIn = maxIn`. Callers ignore the return: orbital common `586,604,1899`; SeTarget `125,185,250`; WithdrawTarget `177`.

**Choose:** `seIn = exchangeOut(...)`. Keep approve-to-cap and approve-back-to-zero. Keep the short-delivery revert at `564`.

**Alternative:** delete the return and update those seven call sites. Not chosen; more churn for the same honesty rule.

**Red/green:** one production-hook test in `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/` asserts the return equals the SE share-balance delta around the call. Quoted token out still pays. Allowance ends at zero.

## RC-07 — zero credit, do not retarget historical callers

**Fact:** `BasicVaultCommon._unbookedSurplus` (`33-36`) is checked subtraction. It is called from `_refundExcess` (`128`) and from Camelot OutTarget `430`. The base pull (`98`) also subtracts and does not call `requirePretransferCaller`. Its NatSpec (`70-72`) delegates that check.

**Production callers of the base refund, all D16:** Uni V2 common `476`; Camelot common `214`; Aerodrome common `1002`; Aerodrome OutExecuteTarget `168,267,335,371,473,497,552`.

**Not this helper:** Balancer adapter’s own copy; ERC-4626 `_refundExcess` (`246`); preserved Uni V4 `125`; FullSpread V4 `185`. Do not edit those.

**Overrides that already guard the pull:** Uni V2 `420-434`, Camelot `158-171`, Aerodrome `946-959`, Stata `200-214`. Grep found no other `is BasicVaultCommon`. Slipstream, FullSpread, hooks, and DETF cannot reach the base branch.

**Choose:** change only `_unbookedSurplus` to `LocalCreditLib.available`. Do not add the EOA check to the base pull. Do not edit the four overrides.

**Required companion:** Camelot `430` currently pays all unbooked `tokenOut`. After a zero result, a positive `amountOut` must revert with an existing shortfall error, not transfer 0 and succeed. Do not pay booked inventory. Do not redesign that payout to a new economics rule.

**Do not change:** base-pull EOA behavior. `BasicVaultCommonHarness` (`BasicVaultCommon_TokenTransfer.t.sol:107-138`) is the non-D16 consumer. Update its deficit expectation from panic to zero. No other production non-D16 caller was found.

**Red/green:** name the four overrides in the Uni V2, Camelot, and Aerodrome secure-pull suites and show an EOA `pretransferred=true` entry reverts `EOAPretransferNotAllowed` (proves the base branch did not run). If a production route can make `balance < book` without `vm.store` or a vault mock, that route must authorize zero new credit and revert `TransferDeltaInsufficient` when more than zero is requested, not an arithmetic panic. If it cannot, the harness refund is the allowed direct helper test. Record the failed production preconditions.

**Confidence:** High on the caller list. Medium that no indirect inheritor was missed by the `is BasicVaultCommon` grep.

## RC-08 — named zap-out backing error

**Fact:** `UniswapV2StandardExchangeOutTarget.sol:578-580` is an empty `revert()` when `pool.balanceOf(this) < vault.vaultLpReserve`, after `_refundExactOutCredit`. No local error exists in that file.

**Choose:** `error ZapOutBackingShortfall(uint256 poolTokenBalance, uint256 vaultLpReserve)` carrying both compared values. Same comparison. No refund change. Selector via `scripts/foundry/ComputeNatSpecValues.s.sol`, not a hand-computed value (`crane-natspec`).

**Red/green:** extend `UniswapV2StandardExchange_SecRemediation.t.sol`. First try a supported zap-out that drives pool-token balance below `vaultLpReserve` without mocking the vault or writing its storage. Inference: a faithful pair that burns only the pulled LP may never enter the branch, because the check is “do not spend lastTotal LP.” If unreachable, record the preconditions and do not block the named-error edit. Do not add a later end-to-end gate. A funded zap-out must still succeed.

**Confidence:** High on the empty revert. Low that a supported route can hit it.

---

## Order and dependencies

1. RC-05, RC-08, RC-04 except the Balancer comment. Independent.
2. RC-01, including the line 262 comment. RC-04 must not revert that comment.
3. RC-07 only after the consumer list above is copied into the change. No other production edit depends on it.
4. RC-03, then RC-02, then the orbital face assertion. RC-06 can land with RC-02 in the orbital file but is a different function.
5. After each production edit: `python3 scripts/forge-artifacts.py test <edited-source.sol> --test-root <suite>`. Hermetic default profile. No `via_ir`, no `FOUNDRY_PROFILE=fork`, no live RPC, no preserved Uni V3/V4 bytecode. If a D16 facet exceeds 24,576 bytes, split per D19. Do not enable `via_ir`.

Fresh deployments only. No migration, live inventory, or economics change. D12, D44, D32, and D6 stay as written. Do not mock the vault, adapter, hook, or SE. Callback tokens and non-unit ERC-4626 fixtures are allowed.

## Evidence gaps

- No Foundry run. Green counts in older plans are unverified.
- Installed compiler/EVM not observed.
- Audit PDF not read this pass.
- Callback-token pool construction, nonzero aToken booking, and the zap-out failure branch were not executed.
- `HookTarget.exchangeIn` remains an unscoped pretransfer gap.
- D16 line 335 was truncated.
- Skill-catalog glob failed on broken Crane symlinks; direct skill reads succeeded.
- Assigned `grok-original.md` was not written, because a `xai/grok-4.6` original already occupies it. Moderator consolidation belongs at `docs/plans/apex-2026-09-17-remediation-council/IMPLEMENTATION_PLAN.md`.
