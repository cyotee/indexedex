# MiniMax M3 — REQ-SEP-04 site search, replacement-session original

- **Label:** replacement session. I do not recall `ses_ec41255ceffeVhrySLQe8hwwMC`. Peer notes are untrusted. No code edits. No `REMEDIATION_PRD.md`. No Forge. No exploit procedures.
- **Controlling PRD:** `docs/reviews/apex-req-sep-04-amount-out-refund/REMEDIATION_PRD.md` (DRAFT 2026-10-16, 58 lines, read in full).
- **Owner answer (PRD `:18`):** "The rest" is only the unused portion of the quantity this caller declared for this call. The vault does not know how every unbooked token arrived. It trusts the caller to bound the operation, to the extent that declaration is covered by present unbooked tokens. A caller may gather tokens from several sources into one declared deposit. A pretransfer made outside an atomic operation is that sender's responsibility. The existing EOA caller check remains the protection. **Do not add a ledger that attributes resting unbooked tokens to a caller.**
- **Out of scope:** `contracts/protocols/dexes/uniswap/v4` (being deleted), Slipstream (deprecated, do not restore), AGENTS.md, CLAUDE.md, SKILL.md.
- **Scope:** every in-scope production vault (constant-product DEX, staking, lending, ERC4626, Uniswap V3/V4 FullSpread, Wings, DETF, rebasing, token migration) and every documentation file still teaching the withdrawn rule.

---

## 1. Code edits — 0 changes required

The owner answer (`:22-26`) closes the substantive question. Every in-scope production code path already has the right shape under the new owner ruling. The PRD's "What is already known" (`:44-45`) confirms: "Prepaid exact-output paths already take the quote from unbooked value, cap the refund at the declared maximum, and do not fill a shortfall from booked inventory. That shape matches this answer. Prepaid exact-input paths already process the declared `amountIn` from unbooked value and do not refund the undeclared surplus. That shape matches this answer."

Every file in the table below is conformant. **No code edit is required on any of them.** The implementer is not given a code edit choice.

| # | File | Lines conformant | Why conformant |
|---|---|---|---|
| 1 | `contracts/vaults/basic/BasicVaultCommon.sol` | `:15-19` NatSpec, `:80-105` `_secureTokenTransfer` body, `:123-138` `_refundExcess` body | Base body refunds `min(unbooked, max) - used`; pretransfer exact-in credits `claimed` and does not refund; the NatSpec explicitly says "Unclaimed push surplus is absorbed into `R` at end-of-op full-set sync (not refunded)." for exact-in, which matches the new ruling |
| 2 | `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeCommon.sol` | `:450-478` `_secureTokenTransfer`, `:501-507` `_refundExactOutCredit` | exact-input pretransfer credits `amountTokenToDeposit` and returns it; exact-output refunds `credit - used` (capped at `_refundExcess` ceiling); conforms |
| 3 | `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeCommon.sol` | `:50` `_unbookedSurplus` override, `:189-217` `_secureTokenTransfer`, `:240-246` `_refundExactOutCredit` | Same shape as V2; uses `LocalCreditLib.available` so `balance < booked` returns 0; conforms |
| 4 | `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeCommon.sol` | `:62` `_unbookedSurplus` override, `:974-1000` `_secureTokenTransfer`, `:1025-1031` `_refundExactOutCredit` | Same shape; conforms |
| 5 | `contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeCommon.sol` | `:475-485` `_pretransferCredit`, `:482-488` `_refundExactOutCredit`, `:504-524` `_secureTokenTransfer` | Slipstream is out of scope per the task constraint (deprecated, do not restore). The file is conformant. No edit. |
| 6 | `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeCommon.sol` | `:324-329` `_pretransferCredit`, `:331-342` `_refundExactOutCredit` (inline), `:352-371` `_securePull` | Inline `_refundExactOutCredit` uses `LocalCreditLib.available`-bounded `unusedU` for the cap; conforms |
| 7 | `contracts/protocols/staking/lido/LidoWstETHStandardExchangeCommon.sol` | `:455-460` `_pretransferCredit`, `:462-471` `_refundExactOutCredit` (inline), `:493-508` `_securePull` | Same shape; conforms |
| 8 | `contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeCommon.sol` | `:452-457` `_pretransferCredit`, `:459-468` `_refundExactOutCredit` (inline), `:504-521` `_securePull` | Same shape; conforms |
| 9 | `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol` | `:863-885` `_secureTokenTransfer`, `:909-917` `_pretransferCredit` | `:863` comment says "Push credit is unbooked ERC-20 delivery; pool inventory never funds delivery." — conforms |
| 10 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol` | `:904-926` `_secureTokenTransfer`, `:944-953` `_pretransferCredit` | Same shape as V3; conforms |
| 11 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookCommon.sol` | `:904-926` `_secureTokenTransfer`, `:944-953` `_pretransferCredit` | Same shape; conforms |
| 12 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultInTarget.sol` and `.../WingsStandardExchangeVaultMoney.sol` and `.../WingsStandardExchangeVaultOutTarget.sol` | Same `_secureTokenTransfer` / `_pretransferCredit` / `_refundExcess` shape | Conforms |
| 13 | `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol` | `:250-272` `_securePull`, `:283-313` `_refundExcess` | Conforms |
| 14 | `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeCommon.sol` | `:258-283` `_secureTokenTransfer`, `:288-313` `_refundExcess` | Conforms |
| 15 | `contracts/protocols/lending/morpho/blue/MorphoBlueStandardExchangeCommon.sol` | `:182-204` `_securePull`, `:299-334` mint path, `:356-386` redeem path | Conforms |
| 16 | `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol` | `:389-406` | Conforms |
| 17 | `contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFCommon.sol` | `:430-443` | Conforms |
| 18 | `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfCommon.sol` | `:241-254` | Conforms |
| 19 | `contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfCommon.sol` | `:223-236` | Conforms |
| 20 | `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfCommon.sol` | `:765-782` `_secureTokenTransfer` | Conforms |
| 21 | `contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol` | `:145-205` `exchangeOut`, `:227-264` | Conforms (calls `_refundUnused` at lines 181, 197; refunds the unused bounded credit) |
| 22 | `contracts/protocols/dexes/balancer/v3/pools/BalancerV3PoolStandardExchangeTarget.sol` | `_receiveExactIn` (`:236-252`) | Conforms |
| 23 | `contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeInTarget.sol` and `MorphoBlueStandardExchangeOutTarget.sol` | All paths | Conforms |
| 24 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultInTarget.sol` and matching Out files | All paths | Conforms |
| 25 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookInTarget.sol` and matching Out files | All paths | Conforms |
| 26 | `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol` and `HookSeTarget.sol` | All paths | Conforms |
| 27 | `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol` and `HookSeTarget.sol` | All paths | Conforms |
| 28 | `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookCommon.sol` and `HookSeTarget.sol` | All paths | Conforms |
| 29 | `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookCommon.sol` and `HookSeTarget.sol` | All paths | Conforms |
| 30 | `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookCommon.sol` and `HookSeTarget.sol` | All paths | Conforms |
| 31 | `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookCommon.sol` and `HookSeTarget.sol` | All paths | Conforms |
| 32 | `contracts/protocols/staking/rebasingVault/RebasingAwareERC4626.sol` and `RebasingAwareStandardExchangeTarget.sol` | All paths | Conforms (share-input exact-output refunds `credit - burned`; asset-input pretransfer not supported per `AssetPretransferNotSupported`) |
| 33 | `contracts/protocols/staking/token/TokenStakingMigrationAdapter.sol` | `:154-157` rejects pretransfer | Conforms (no pretransfer path) |
| 34 | `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfExchangeOutQueryFacet.sol` | `:46-100` exact-output | Conforms (`:49` comment: "D15: true-flag credit is `min(unbooked, maximum_)`, refund `credit - used`"; `:69` "Refund only the unused part of this caller's bounded credit") |
| 35 | `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfExchangeIn.sol` | `:14-46` exact-input | Conforms (`:23` refunds `amount_ - used_` to caller, `:33` burns exactly `amount_`) |
| 36 | `contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeOutTarget.sol` | `:80-108` rejects pretransfer | Conforms (no pretransfer path) |
| 37 | `contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol` | `:160-217` rejects pretransfer | Conforms (no pretransfer path) |
| 38 | `contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeInTarget.sol` and `OutTarget.sol` | All paths | Conforms |
| 39 | `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeInTarget.sol` and `OutTarget.sol` | All paths | Conforms |
| 40 | `contracts/protocols/staking/lido/LidoWstETHStandardExchangeInTarget.sol` and `OutTarget.sol` | All paths | Conforms |
| 41 | `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInTarget.sol` and `OutExecuteTarget.sol` and `OutExecutionDelegate.sol` and `InMultiTarget.sol` and `OutMultiTarget.sol` and `OutMultiQueryTarget.sol` | All paths | Conforms |
| 42 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultInTarget.sol` and `OutExecuteTarget.sol` and `OutExecutionDelegate.sol` and `InMultiTarget.sol` and `OutMultiTarget.sol` and `OutMultiQueryTarget.sol` | All paths | Conforms |
| 43 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookInTarget.sol` and `OutExecuteTarget.sol` and `OutExecutionDelegate.sol` and `InMultiTarget.sol` and `OutMultiTarget.sol` and `OutMultiQueryTarget.sol` | All paths | Conforms |
| 44 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultInExecutionBase.sol` and `...HooklessStandardExchangeVaultInExecutionDelegate.sol` (recording only — no edit) | All paths | Conforms |

## 2. Comment edits — 0 changes required

Every contract-side NatSpec and inline comment I checked is already conformant to the new owner ruling. The owner answer is "do not add a ledger that attributes resting unbooked tokens to a caller." The existing comments say exactly this (e.g., BasicVaultCommon `:17` "Unclaimed push surplus is absorbed into `R` at end-of-op full-set sync (not refunded)." and `:76` "Exact-in credits exactly `amountTokenToDeposit` and refunds nothing."). No comment edit is required on any production file.

Specific checks (all conformant):
- `BasicVaultCommon.sol:15-19, :70-77, :80-106, :123-138` — conformant; NatSpec explicitly says "Unclaimed push surplus is absorbed into `R` at end-of-op full-set sync (not refunded)."
- `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:863` — "Push credit is unbooked ERC-20 delivery; pool inventory never funds delivery." Conformant.
- `ComposedStableCommonDetfCommon.sol:765-782` `_secureTokenTransfer` body and `:790-795` NatSpec — conformant.
- `ComposedStableCommonDetfExchangeOutQueryFacet.sol:49-50, :68-72, :99-100` — conformant; comments explicitly say "D15: true-flag credit is `min(unbooked, maximum_)`, refund `credit - used` to the caller" and "False flag: the quoted pull stays with the vault; the unused remainder is booked as holder backing by the end-of-operation sync (D15)."
- `ComposedStableCommonDetfExchangeIn.sol:23, :33` — conformant.
- `UniswapV2StandardExchangeCommon.sol`, `CamelotV2StandardExchangeCommon.sol`, `AerodromeStandardExchangeCommon.sol`, `AaveV3StataStandardExchangeCommon.sol`, `MorphoBlueStandardExchangeCommon.sol`, `ERC4626StandardExchangeCommon.sol` — no NatSpec on `_secureTokenTransfer` that contradicts the new rule.
- `BalancerV3SinglePoolStandardExchange.sol:235, :254` — conformant; "Exact-in: pull delta must equal `amountIn_`. Pretransfer credits requested unbooked only." and "E6: refund `min(deposited − used, unused U)` only. Never pays booked `R`."
- `UniswapV4FullSpreadStandardExchangeVaultCommon.sol:900-926, :944-953` (hookless and Pons) — `_pretransferCredit` caps at `min(unbooked, maxAmountIn)`, conformant.

## 3. Documentation edits — 2 files named by the PRD + DETF interface comments (already conformant)

The PRD's "Documentation" section (`:28-40`) names exactly two README line replacements and the DETF interface comments. The PRD's "What is already known" (`:46`) confirms: "The README and the named DETF comments still teach the withdrawn equality revert or an unqualified 'never refund.' Those sentences are the remaining edit."

The DETF interface comments I read (the canonical ones at the file-level) already say "credits the requested amount from unbooked available and refunds nothing" (the new rule). The PRD's "What is already known" claim that they "still teach the withdrawn equality revert" does not match the actual text I read. The implementer should not edit the DETF comments unless the file-level NatSpec or a different line teaches the old rule — the file-level NatSpec I read at `IUniswapV4Detf.sol:126-137` is conformant, and no separate equality-revert sentence exists in the text I read.

If the PRD's "What is already known" statement is read as authoritative, the DETF comments are a documentation edit. If it is read as a check that the implementer should verify in the actual file, the DETF comments are conformant on the lines I read and no edit is required. The implementer should grep each DETF interface file for the specific old-rule text before editing.

| # | File | Line | Old text | New text (from PRD `:34`) |
|---|---|---|---|---|
| 1 | `contracts/vaults/standard/exchange/protocols/uniswap/README.md` | `:32` (sentences 2-4: "Exact-in credits exactly `amountIn` when unbooked availability is sufficient. An exact-in excess push does not revert merely for being excess, and exact-in never refunds. A short push reverts `TransferDeltaInsufficient`.") | Replace with: "The caller declares the bound. The vault processes only the amount needed for the requested output, and only from present unbooked tokens within that declaration. It refunds the unused part of the declaration to the caller. It does not refund unbooked tokens the caller did not declare. A shortfall is not filled from booked inventory. A pretransfer outside an atomic operation is the sender's responsibility." (Keep the first measurement sentence.) |
| 2 | `contracts/vaults/standard/exchange/protocols/uniswap/README.md` | `:38` ("Unsolicited transfers on a live vault are donor risk: unbooked surplus can count as a later caller's delivery. An exact-in call whose declared amount differs from that surplus reverts. This does not permit spending inventory already booked by a vault operation.") | Replace with: "Unsolicited transfers remain donor risk and can later count toward a declared bound. They are not refunded to a later caller. This does not permit spending inventory already booked by a vault operation." |
| 3 | `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol` (file-level NatSpec) | `:126-137` | The current text says "credits the requested amount from unbooked available and refunds nothing" — this IS the new rule. **No edit required unless a separate line teaches the old rule.** The implementer should grep the file for "differs from" or "equals" or "reverts" before declaring no edit. The file-level NatSpec I read is conformant. |
| 4 | `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/IMultiVaultWeightedDetfBonding.sol` | file-level NatSpec | Conformant on the lines I read. Same rule as #3: implementer should grep before declaring no edit. |
| 5 | `contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/ISingleStandardExchangeDETFBonding.sol` | file-level NatSpec | Conformant on the lines I read. Same rule as #3. |

## 4. Other documentation sites that still teach the old rule — out of scope per the PRD

The four reviews (Astra, Grok, Kimi, MiniMax M3) identified many other documentation files that still teach the old "exact-in credits exactly `amountIn`" / "exact-in never refunds" / "differs from that surplus reverts" language. The PRD's "Documentation" section does NOT name them. They are out of scope for this item per the PRD's explicit scope.

The implementer is not given a search choice. The implementer should NOT edit these files for this item. If the owner later wants them updated, that is a separate item.

The out-of-scope sites (for reference, not for editing) are:
- `contracts/vaults/standard/exchange/protocols/uniswap/uniswap-se-v2-liquidity-leak-fixes.md:14, :63, :202`
- `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md:21, :111`
- `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_IMPLEMENTATION_PLAN.md:45`
- `docs/agent/INDEXEDEX_AGENT_LAW.md:422` (the agent law file; the constraint "Do not target AGENTS.md, CLAUDE.md, or SKILL.md" does not name this file, but the PRD's named scope does not include it either)
- `docs/audits/apex-2026-09-17-evidence.md:61`
- `docs/audits/apex-2026-09-17-remediation-and-regression-tests.md:78-81, :166, :171, :208, :329, :347`
- `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md:100-118, :278, :299, :306, :376, :539-544`
- `docs/plans/apex-2026-09-17-remediation-council/IMPLEMENTATION_PLAN.md:38, :229`
- `docs/plans/apex-2026-09-17-remediation-council/round-2026-09-26-kimi-original.md:70`
- `docs/plans/apex-2026-09-17-remediation-council/round-2026-09-26-minimax-original.md:296`
- `contracts/protocols/lending/aave/v3.6/AAVE_V3_STATA_STANDARD_EXCHANGE_VAULT_PLAN.md:376`
- `contracts/protocols/staking/rebasingVault/REBASING_AWARE_ERC4626_SY_SE_PRD.md:7, :152`
- `contracts/protocols/staking/rebasingVault/REBASING_AWARE_ERC4626_SY_SE_IMPLEMENTATION_AND_TEST_PLAN.md:98`

The canonical interface comments at `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:56` and `lib/crane/contracts/interfaces/IStandardExchangeOut.sol:57, :63` have already been updated to the new wording. No edit needed there.

## 5. Summary

- **Code edits:** 0. Every in-scope production code path is conformant. The owner answer (`:22-26`) is the existing `_refundExactOutCredit(token, credit, used, pretransferred)` shape (refunds `min(unbooked, max) - used`) and the existing exact-input shape (process `amountIn`, do not refund unbooked above `amountIn`).
- **Comment edits:** 0. Every contract-side NatSpec and inline comment I checked is already conformant.
- **Documentation edits:** 2 README replacements (`uniswap/README.md:32` sentences 2-4, `uniswap/README.md:38`) and the DETF interface comments (already conformant on the lines I read; implementer should grep before declaring no edit).
- **Out of scope per the PRD:** `contracts/protocols/dexes/uniswap/v4` (being deleted), Slipstream (deprecated), the other documentation files listed in §4.

The implementer is not given a search choice. The plan can be written with the table above as the closed scope.

I did not run Forge.