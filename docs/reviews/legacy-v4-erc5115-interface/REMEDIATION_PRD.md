> **Superseded — legacy family deleted (2026-10-15).** Retained as historical evidence only. Do not execute this plan or restore its implementation. See the [removal report](../legacy-v4-removal/EXECUTION_REPORT.md).

# Remediation PRD — legacy V4 implements ERC-5115, not Pendle SY

- **Status:** WITHDRAWN, 2026-10-15. The owner is deleting `contracts/protocols/dexes/uniswap/v4`. Do not implement this PRD or its plan. Other families keep Pendle. This withdrawal does not redesign `contracts/vaults/standard/sy/`.
- **Date:** 2026-10-15
- **ID:** REQ-ERC5115
- **Review target:** Legacy Uniswap V4 Standard Exchange yield surface.
- **Named interface:** `lib/crane/contracts/tokens/ERC5115/IERC5115_StandardizedYield.sol`
- **Owner ruling:** The vault implemented the Pendle Standardized Yield interface. It must implement that ERC-5115 interface instead. Do not split facets in this item. Measure size after the change.
- **Astra participation:** Substantive first pass and substantive review cross-review from `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Not censored. That session's plan cross-review failed an attribution check and was not resumed. Authorized replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi` wrote the plan cross-review and does not recall the old session.
- **Grok:** `ses_ec4128917ffeeVds3Y2p7xrVjp`. Substantive first pass and cross-review.
- **Kimi K3:** Labeled replacement `ses_ec3d04e91ffeJa0is24e2jZv06`. It does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`.
- **MiniMax M3:** Labeled replacement `ses_ebdf718feffemWQNf7wuTpapqX`. It does not recall failed session `ses_ec41255ceffeVhrySLQe8hwwMC`. The earlier stop in this file is historical.
- **Execution evidence:** No Forge run. A present selector is not a pass. Consensus is not proof.

Writing this PRD does not authorize code changes.

## Required outcome

The legacy V4 vault stops advertising and implementing Pendle `IStandardizedYield`. It implements `IERC5115_StandardizedYield`. Other families keep Pendle. Shared files under `contracts/vaults/standard/sy/` are not redesigned. This item does not choose a later facet split.

## Selector change

Money selectors stay on `UniswapV4StandardExchangeInFacet`. Query selectors stay on `UniswapV4StandardExchangeOutMultiQueryFacet`.

Remove these Pendle-only selectors from the legacy V4 proxy:

- `deposit(address,address,uint256,uint256)`, the four-argument payable form
- `claimRewards(address)`
- `rewardIndexesCurrent()`
- `assetInfo()`
- `isValidTokenIn(address)`
- `isValidTokenOut(address)`
- `getRewardTokens()`
- `accruedRewards(address)`
- `rewardIndexesStored()`

Add the non-payable `deposit(address,address,uint256,uint256,bool)`.

Keep these selectors, declared from `IERC5115_StandardizedYield`:

- `redeem(address,uint256,address,uint256,bool)`
- `exchangeRate()`
- `getTokensIn()`
- `getTokensOut()`
- `yieldToken()`
- `previewDeposit(address,uint256)`
- `previewRedeem(address,uint256)`

The IN facet's product selectors are `exchangeIn`, ERC-5115 `deposit`, and ERC-5115 `redeem`. The OUT multi-query facet keeps `previewExchangeOutOneToMany` and the six ERC-5115 reads. Do not move a selector to another facet.

Everywhere this family currently declares `type(IStandardizedYield).interfaceId`, including the package `facetInterfaces` and `UniswapV4StandardExchangeOutMultiQueryFacet.facetInterfaces`, replace it with `type(IERC5115_StandardizedYield).interfaceId`. Do not add or drop a declaration site. ERC-20, permit, and Standard Exchange interfaces stay.

## Deposit flag

Implement the money functions in the existing `UniswapV4StandardYieldExecutionTarget.sol`. It stops inheriting the Pendle money target. Do not create a parallel class.

`redeem` keeps its current body, including the existing internal-balance caller gate.

When `depositFromInternalBalance` is false, use the current token pull. When it is true, call the existing token transfer helper with `pretransferred` true. Do not add `LocalCreditLib.requirePretransferCaller` on that token path. That gate stays on share delivery and on `redeem` when `burnFromInternalBalance` is true. Do not invent a new credit ledger. Do not repair the stored-reserve credit residual in this item.

The new `deposit` is not payable. Do not keep a native-payment check that only existed because the Pendle deposit was payable.

## Files

- Edit `UniswapV4StandardYieldExecutionTarget.sol`, `UniswapV4StandardExchangeInFacet.sol`, `UniswapV4StandardExchangeOutMultiQueryTarget.sol`, `UniswapV4StandardExchangeOutMultiQueryFacet.sol`, and the legacy V4 package interface registration.
- Do not edit `contracts/vaults/standard/sy/` except a legacy-V4 test that must call the new signature. Do not edit the vendored Pendle interface.
- Do not edit V3, hookless, Pons, or other families' yield targets.
- Retarget legacy V4 tests that call `IStandardizedYield` on this vault to `IERC5115_StandardizedYield`. A `deposit` call on this vault gains the bool. Do not rewrite another family's tests.

## Size

After the interface change, measure `UniswapV4StandardExchangeInFacet` and `UniswapV4StandardExchangeOutFacet`. Report the sizes. If either still exceeds 24,576 bytes, stop and report. Do not restore a delegate hop, a self-call, or `via_ir`. Do not split facets in this item. A later item may split only after that measurement.

## Acceptance criteria

- The legacy V4 proxy no longer exposes the nine removed selectors.
- It exposes the ERC-5115 `deposit` and the seven retained selectors.
- `facetInterfaces` for this family uses the ERC-5115 interface id at the sites that previously used the Pendle id.
- `depositFromInternalBalance == false` pulls tokens. `true` uses the existing pretransfer token path and does not add the share-delivery caller gate.
- Other families still implement Pendle `IStandardizedYield`.
- The two facet sizes are reported. No hop was restored to shrink them.

## Non-goals

- Do not split facets.
- Do not remove Pendle from other families.
- Do not add reward, `assetInfo`, or public `isValidToken*` functions to match a fuller EIP-5115 text. The named file is the interface.
- Do not change Standard Exchange `exchangeIn` or `exchangeOut` signatures.
- Do not claim the oversized facets are fixed.

## Dissent

- Astra and Kimi would call `LocalCreditLib.requirePretransferCaller` before a true-flag deposit. Grok and the MiniMax replacement would not, because the current token pretransfer path does not use that gate. This draft follows the current token path. The owner can amend that one sentence if the new deposit must reject a code-less caller.
- The MiniMax replacement would drop the query facet's interface-id slot and would add a parallel execution-target class. This draft replaces the id in place and edits the existing target.

## Plan written, 2026-10-15

The authorized Astra replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi` confirmed both compile rules and does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. The consolidated plan is [REMEDIATION_PRD.plan.md](./REMEDIATION_PRD.plan.md). It is DRAFT and does not authorize implementation.

The query target stops inheriting the Pendle preview and discovery bases. The money target does not inherit `IERC5115_StandardizedYield`. Both deposit flag values go through the existing guarded `_exchangeIn` branch. No new token-path caller gate is added.

## Plan round stopped again, 2026-10-15

Historical. MiniMax replacement `ses_ebdf718feffemWQNf7wuTpapqX` wrote `reviewers/minimax-plan.md`. Grok, Kimi, and the MiniMax replacement completed cross-review. Astra session `ses_ec412bcc2ffejKLo7nuoEAqbV0` returned an attribution guard failure and did not write `reviewers/astra-plan-cross.md`. That session was not resumed. The later replacement completed the missing cross-review.

## Plan round stopped, 2026-10-15

The human asked for an implementation plan. The named path `lib/crane/contracts/tokens/ERC5115/IERC5115_StandardizedYield.sol` is the interface, not this PRD.

Astra, Grok, and Kimi wrote plan drafts. Their drafts agree: edit the existing yield target, do not add a parallel class, do not split facets, other families keep Pendle, and a true deposit flag uses the existing token pretransfer path without adding `LocalCreditLib.requirePretransferCaller`.

MiniMax replacement `ses_ebdf718feffemWQNf7wuTpapqX` read the PRD and returned a plan summary, but the write of `reviewers/minimax-plan.md` was denied by the review-council guard. That file was not written. Cross-review was not started. This is not a four-member plan. No `REMEDIATION_PRD.plan.md` was written.

I did not run Forge.
