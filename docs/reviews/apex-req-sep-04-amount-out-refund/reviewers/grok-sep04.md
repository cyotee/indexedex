# Grok — REQ-SEP-04 amount-out refund

Independent first pass. Later owner text controls. `contracts/protocols/dexes/uniswap/v4` was not reviewed. Slipstream is recorded and not restored. No new economic model is invented.

## Exact-out mapping, closed

On an exact-out call, the requested amount out is the caller's `amountOut`, share output, or exact asset output. The amount processed is the quoted amount that output needs. That amount comes only from unbooked value. A shortfall reverts. It is not filled from booked inventory. On a prepaid call, unbooked credit minus that processed amount is refunded to `msg.sender`. A false-flag call that pulls only that processed amount has nothing left to refund. That pull is not this defect.

## Owner question — exact-in

Exact-in has a declared `amountIn` and a minimum output. It has no requested amount out. Mapping it to "the amount needed to meet the requested amount out" would invent a rule.

Question: on a prepaid exact-in call, what amount is processed from the unbooked balance?

Sentence that would close it: "On prepaid exact-in, process the caller's declared amountIn from unbooked value only, refund unbooked minus amountIn to the caller, and do not revert only because amountIn differs from the unbooked surplus."

Until that sentence is adopted, do not edit exact-in code. The sites below are the inventory that sentence would govern. They are not a second model.

## Grok finding 1 — Uniswap README still states both withdrawn sentences

- **Severity:** Low
- **File and line:** `contracts/vaults/standard/exchange/protocols/uniswap/README.md:32` and `:38`
- **Intended behavior:** The README states the 2026-10-16 ruling. A prepaid exact-out call processes only the unbooked amount the requested output needs and refunds the rest to the caller. Booked inventory is not spent. A shortfall is not filled from booked inventory.
- **Broken invariant:** Line 32 says exact-in credits the declared amount and never refunds an excess push. Line 38 says an exact-in call reverts when the declared amount differs from the surplus. Both sentences are withdrawn.
- **Impact class:** Documentation. A later session can implement the withdrawn rule from this file.
- **Fix direction:** Replace lines 32 and 38 with the exact-out ruling above. Do not rewrite lines 3 and 56. Do not add an exact-in processing rule in this file until the owner adopts the sentence in the question.
- **Confidence:** High

Facts: those two lines were read. Inference: none. Speculation: none.

## Grok finding 2 — Three live instruction docs still require the withdrawn exact-in rule

- **Severity:** Low
- **File and line:** `contracts/vaults/standard/exchange/protocols/uniswap/uniswap-se-v2-liquidity-leak-fixes.md:14`, `:63`, and `:202`; `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md:21` and `:111`; `docs/agent/INDEXEDEX_AGENT_LAW.md:422`
- **Intended behavior:** Same as finding 1. These files must not instruct a later session to credit a declared exact-in amount and keep the surplus, or to revert only because the declared amount differs from the surplus.
- **Broken invariant:** Each cited line still says exact-in credits the declared amount and refunds nothing. The leak-fixes file also says excess stays uncredited and is not a revert.
- **Impact class:** Documentation. Agent law and the vault PRD still direct that implementation.
- **Fix direction:** Delete those withdrawn sentences from the three files. State the exact-out ruling in their place. Do not add an exact-in processing rule until the owner adopts the sentence in the question. Do not edit historical audit notes.
- **Confidence:** High

Facts: the cited lines were read. Inference: none. Speculation: none.

## Families that already refund exact-out from unbooked value

Leave this refund behavior alone:

- Uniswap V2, Camelot V2, and Aerodrome v1 call `_refundExactOutCredit` after a prepaid exact-out. The helper returns when the flag is false, reverts if used exceeds credit, and refunds credit minus used.
- Lido, Rocket Pool, and EtherFi do the same on exact-out.
- V3 FullSpread quoted exact-out refunds unused inbound after the caller check and the credit comparison.
- Hookless and Pons exact-out refund excess after `_requirePrepaidCredit`.
- Morpho Blue prepaid exact-out mint measures unbooked credit, reverts if the needed amount exceeds it, and transfers credit minus actual input to `msg.sender` at `MorphoBlueStandardExchangeCommon.sol:331`.

Slipstream has the same refund helper. Do not edit it.

False-flag exact-out pulls of only the quoted used amount are not defects. They do not take a remainder.

## Exact-in inventory, not a chosen repair

These prepaid paths credit the declared amount from unbooked value and do not refund a larger surplus. They do not fill a shortfall from booked inventory on the lines read. Do not change them until the owner adopts the sentence above.

- `UniswapV3FullSpreadStandardExchangeVaultInTarget.sol:51`, `:59`, and `:66`, through `_secureTokenTransfer` at `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:867-874`
- `UniswapV2StandardExchangeInTarget.sol:586`
- `ERC4626StandardExchangeInTarget.sol:70-78`
- `UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:81-87`

No production path read in this pass spends booked inventory to fill the processed amount. That absence is not a claim that every unread family was inspected.

I did not run Forge.
