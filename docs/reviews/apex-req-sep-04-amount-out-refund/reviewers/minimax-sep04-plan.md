# MiniMax M3 — REQ-SEP-04 ordered plan, replacement session

- **Label:** replacement session `ses_ebdf718feffemWQNf7wuTpapqX`. I do not recall `ses_ec41255ceffeVhrySLQe8hwwMC`. No code edits. No `REMEDIATION_PRD.plan.md`. No Forge. No exploit procedures.
- **Controlling PRD:** `docs/reviews/apex-req-sep-04-amount-out-refund/REMEDIATION_PRD.md` (DRAFT 2026-10-16, 58 lines, read in full this round).
- **Out of scope:** `contracts/protocols/dexes/uniswap/v4` (being deleted), Slipstream (deprecated, do not restore), `AGENTS.md`, `CLAUDE.md`, `SKILL.md`, and all dated review records (audit evidence, historical PRDs/plans/reviews). Do not add a ledger. Do not refund the whole unbooked remainder.
- **Edit scope from the closed list cross-review:** 0 code edits; 2 README documentation edits; 5 DETF interface comment files. No other site is in scope.

---

## §0 — Spot-check of every Required outcome line and Documentation line

The plan author (a later session) must re-verify each of these lines before any edit. The numbers below are the PRD's line numbers as of this read.

### Required outcome (PRD `:20-26`)

| Line | Verbatim text | Cranes sync note |
|---|---|---|
| `:22` | "A prepaid exact-output call processes the quote for the requested output, taken only from unbooked value and bounded by the caller's declared maximum. It refunds `min(unbooked, declared maximum) - used` to the caller. It does not refund unbooked value above that declaration." | The `_refundExactOutCredit(token, credit, used, pretransferred)` helpers in `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeCommon.sol:501`, `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeCommon.sol:240`, `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeCommon.sol:1025`, `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeCommon.sol:331`, `contracts/protocols/staking/lido/LidoWstETHStandardExchangeCommon.sol:462`, `contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeCommon.sol:459` already implement this exact shape (with inline or `_refundExcess` delegation). The plan author must confirm these bodies are unchanged in this item. |
| `:24` | "A prepaid exact-input call processes the declared `amountIn`, taken only from unbooked value. That declaration is the bound. It does not refund unbooked value above `amountIn`. It does not revert merely because `amountIn` differs from the whole surplus." | The `_secureTokenTransfer` and `_securePull` pretransfer branches in the seven Common files plus the in-scope hook families already implement this exact shape. No code edit. |
| `:26` | "A shortfall against the declaration is not filled from booked inventory. Do not change a vault path that already has this shape. Do not refund the entire unbooked remainder." | The plan author must confirm the C8 sync note is preserved: `_syncAllExpectedHoldReserves()` is called at the end of every supported money route (e.g., V2 Common line 473, V3 Common line 884, hookless/Pons Common line 924, Camelot Common line 213, Aerodrome Common line 998, Aave Common line 282, ERC4626 Common line 260, Morpho Common line 192, Rocket Common line 367, Lido Common line 506, EtherFi Common line 517, Balancer single-pool line 263, Composed DETF OutFacet line 107). The sync books the post-operation balance and is the canonical C8 implementation. Do not add a new refund or a new entry gate. |

### Documentation (PRD `:28-40`)

| Line | Verbatim text | Plan author action |
|---|---|---|
| `:30` | "Replace the withdrawn sentences. Do not rewrite README lines 3 and 56." | The plan author must verify the README's line 3 and line 56 are not touched by this item. |
| `:32` | "In `contracts/vaults/standard/exchange/protocols/uniswap/README.md`, keep the measurement sentence in line 32 and replace the exact-in refund and equality sentences with:" | The README line 32 has four sentences; the first sentence (the measurement sentence) is kept; the remaining three are replaced. The README line 32 first sentence (current text, kept): "The measured pushed input is `balanceOf(vault) - reserveOfToken(token)` captured before settlement changes balances." |
| `:34` | Replacement for README line 32 sentences 2-4: "The caller declares the bound. The vault processes only the amount needed for the requested output, and only from present unbooked tokens within that declaration. It refunds the unused part of the declaration to the caller. It does not refund unbooked tokens the caller did not declare. A shortfall is not filled from booked inventory. A pretransfer outside an atomic operation is the sender's responsibility." | This sentence replaces README line 32's existing sentences "Exact-in credits exactly `amountIn` when unbooked availability is sufficient. An exact-in excess push does not revert merely for being excess, and exact-in never refunds. A short push reverts `TransferDeltaInsufficient`." verbatim. |
| `:36` | "Replace line 38's equality-revert sentence with:" | The README line 38 has one sentence to be replaced. |
| `:38` | Replacement for README line 38: "Unsolicited transfers remain donor risk and can later count toward a declared bound. They are not refunded to a later caller. This does not permit spending inventory already booked by a vault operation." | This sentence replaces README line 38's existing sentence "An exact-in call whose declared amount differs from that surplus reverts." verbatim. |
| `:40` | "Apply that same meaning to DETF interface comments that say an exact-input prepaid call refunds nothing or reverts unless the declaration equals the whole surplus. Do not change those interfaces' executable signatures in this item." | The plan author must verify the DETF interface comment edits below do not change any function signature. Comment-only edits. |

### What is already known (PRD `:42-46`)

| Line | Verbatim text | Plan author action |
|---|---|---|
| `:44` | "Prepaid exact-output paths already take the quote from unbooked value, cap the refund at the declared maximum, and do not fill a shortfall from booked inventory. That shape matches this answer. Do not remove the cap." | No code edit. The cap is intentional and matches the new rule. |
| `:45` | "Prepaid exact-input paths already process the declared `amountIn` from unbooked value and do not refund the undeclared surplus. That shape matches this answer." | No code edit. The existing `_secureTokenTransfer`/`_securePull` pretransfer branches already do this. |
| `:46` | "The README and the named DETF comments still teach the withdrawn equality revert or an unqualified 'never refund.' Those sentences are the remaining edit." | The closed edit list (this plan §1) is the implementation of this sentence. |

### Non-goals (PRD `:48-54`)

| Line | Verbatim text | Plan author action |
|---|---|---|
| `:50` | "Do not edit `contracts/protocols/dexes/uniswap/v4`." | The plan author must verify no edit lands in that path. |
| `:51` | "Do not restore Slipstream." | The plan author must verify no edit lands in `contracts/protocols/dexes/aerodrome/slipstream/`. |
| `:52` | "Do not invent a caller-attribution ledger." | No new storage variable, mapping, or per-caller tracking is added. |
| `:53` | "Do not change lines 3 and 56 of the Uniswap README to satisfy this item." | The plan author must verify README lines 3 and 56 are unchanged. |
| `:54` | "Do not implement either refund reading in this review session." | The plan author must not introduce a new `_refundExcess` variant, a new `_secureTokenTransfer` branch, a new ledger, or a new surrogate for the C8 sync. |

### Stop condition

If a named sentence is gone (the plan author re-reads the source and finds the line text removed or rewritten by a prior change), stop and report. The plan author must not invent a substitute sentence. The implementer must not search.

---

## §1 — Comment-only edit list (closed, no function-body edits)

Every edit below is a NatSpec or comment-only change. The plan author must verify the source line text and then perform a verbatim replacement using the sentence in the "Replacement" column. The "Verification" column gives the line numbers the plan author must re-read before the edit.

### 1.1 README documentation edits (verbatim, two files)

| # | File | Line | Current text (must be verified) | Replacement (verbatim from PRD) |
|---|---|---|---|---|
| 1 | `contracts/vaults/standard/exchange/protocols/uniswap/README.md` | `:32` sentences 2-4 | "Exact-in credits exactly `amountIn` when unbooked availability is sufficient. An exact-in excess push does not revert merely for being excess, and exact-in never refunds. A short push reverts `TransferDeltaInsufficient`." | "The caller declares the bound. The vault processes only the amount needed for the requested output, and only from present unbooked tokens within that declaration. It refunds the unused part of the declaration to the caller. It does not refund unbooked tokens the caller did not declare. A shortfall is not filled from booked inventory. A pretransfer outside an atomic operation is the sender's responsibility." (The first measurement sentence at README `:32` is kept: "The measured pushed input is `balanceOf(vault) - reserveOfToken(token)` captured before settlement changes balances.") |
| 2 | `contracts/vaults/standard/exchange/protocols/uniswap/README.md` | `:38` | "An exact-in call whose declared amount differs from that surplus reverts." | "Unsolicited transfers remain donor risk and can later count toward a declared bound. They are not refunded to a later caller. This does not permit spending inventory already booked by a vault operation." |

### 1.2 DETF interface comment edits (verbatim, five files; line groups from the closed list)

Each DETF file has multiple identical NatSpec blocks (one per operation). The plan author must apply the replacement to every occurrence in the listed line groups. The replacement text is the same in every case. Function signatures, parameter lists, return types, event declarations, storage layouts, and selectors must not change.

| # | File | Line groups (per closed list) | Current text pattern | Replacement (verbatim) |
|---|---|---|---|---|
| 3 | `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol` | `:125-126, :136-137` | "Exact-input credits the requested amount from unbooked available and refunds nothing." (on `bond` and `donate`) | "The declared input amount bounds this operation and is processed only when present unbooked input covers it; tokens above that declaration are not refunded, inequality between the declaration and the whole surplus is not an error, and booked inventory never fills a shortfall." |
| 4 | `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/IMultiVaultWeightedDetfBonding.sol` | `:7-11, :20-24, :26-30, :32-36, :38-42, :44-48` (six identical blocks) | "Exactly the requested amount is credited when at least that much unbooked input exists; excess is left uncredited and nothing is refunded." | Same replacement as row 3. |
| 5 | `contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/IMixedBufferMultiVaultStableDetfBonding.sol` | `:7-11, :20-24, :26-30, :32-36, :38-42, :44-48` (six identical blocks; first block verified verbatim; layout identical to row 4) | Same as row 4. | Same replacement as row 3. |
| 6 | `contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/ISingleStandardExchangeDETFBonding.sol` | `:8-12, :17-21, :23-27, :29-33, :35-39, :41-45` (six identical blocks) | Same as row 4. | Same replacement as row 3. |
| 7 | `contracts/interfaces/detf/IDetf.sol` | `:169, :238` | `:169` (in `mintWithRateAsset`): "leaves excess uncredited, and refunds nothing." `:238` (in `donate`): "leaves excess uncredited to this operation and refunds nothing." | Same replacement as row 3. |

### 1.3 Canonical replacement sentence (verbatim, applies to all 5 DETF files)

The single sentence the implementer pastes at every site:

> "The declared input amount bounds this operation and is processed only when present unbooked input covers it; tokens above that declaration are not refunded, inequality between the declaration and the whole surplus is not an error, and booked inventory never fills a shortfall."

### 1.4 Lines that DO NOT change (the plan author must re-verify each is present after the edits)

The following sentence groups are NOT in the closed edit list. The plan author must confirm they are unchanged after the edits above. If any is missing from the source, stop and report.

- `contracts/vaults/standard/exchange/protocols/uniswap/README.md:3` and `:56` (PRD non-goal `:53`).
- `contracts/vaults/standard/exchange/protocols/uniswap/README.md:34` (existing exact-out bounded refund text; PRD "What is already known" `:44`).
- `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:56` (already updated to the new wording by a prior change; the plan author must confirm the new wording is present and not re-edit).
- `lib/crane/contracts/interfaces/IStandardExchangeOut.sol:57, :63` (already updated; confirm and do not re-edit).
- The DETF interface files' function signatures, parameter lists, return types, event declarations, storage layouts, and selectors (PRD `:40` "Do not change those interfaces' executable signatures in this item").
- The production-code paths in §2 below: `_secureTokenTransfer`, `_securePull`, `_refundExactOutCredit`, `_refundExcess`, `_syncAllExpectedHoldReserves`, `_secureTokenTransfer` pretransfer branch in every in-scope Common file. The plan author must not introduce a new branch or change a function signature.
- `AGENTS.md`, `CLAUDE.md`, `SKILL.md` (excluded).
- Slipstream source and comments (excluded; PRD non-goal `:51`).
- `contracts/protocols/dexes/uniswap/v4` (excluded; PRD non-goal `:50`).
- Dated review records under `docs/reviews/**`, `docs/audits/**`, `docs/research/**`, `docs/plans/**`, `docs/vaults/DETF_NESTED_SE_PUSH_PRETRANSFER_IMPLEMENTATION_PLAN.md`, and similar historical documents (preserved, not rewritten; the cross-review site's "what is already known" + "historical records" section).

### 1.5 Stop if a named sentence is gone

If, on re-read, the source no longer contains the current text the plan author was about to replace (because a prior change already removed it), stop and report. Do not invent a substitute sentence. Do not search. The implementer must not re-edit a sentence that is no longer there.

### 1.6 The canonical Crane sync note (C8)

The C8 requirement (PRD Required outcome `:26`: "A shortfall against the declaration is not filled from booked inventory. Do not change a vault path that already has this shape. Do not refund the entire unbooked remainder.") is implemented in production by `_syncAllExpectedHoldReserves()` and its callers. The plan author must confirm the call site is preserved (no edit removes the sync). The following call sites are the canonical C8 implementation and must not change:

- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeInTarget.sol:470-474` and `OutTarget.sol:473, 588, 635, 715, 812, 965, 1004`
- `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeInTarget.sol:553, 608, 663, 712, 768` and `OutTarget.sol:442, 557, 608, 686, 785`
- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeInTarget.sol:301, 343, 372, 386, 425, 481, 513` and `OutExecuteTarget.sol:166, 333, 368, 496, 550`
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInTarget.sol:67, 76` and `OutExecuteTarget.sol:91, 113` and `OutExecutionDelegate.sol:126` and `InMultiTarget.sol:33, 36` and `OutMultiTarget.sol:47, 50`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultInTarget.sol:114, 122` and `OutExecuteTarget.sol:113, 186` and `OutExecutionDelegate.sol:56` and `InMultiTarget.sol:34, 37` and `OutMultiTarget.sol:48, 51`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookInTarget.sol:114, 122` and `OutExecuteTarget.sol:113, 186` and `OutExecutionDelegate.sol:56` and `InMultiTarget.sol:34, 37` and `OutMultiTarget.sol:48, 51`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultInTarget.sol:51, 70` and `OutTarget.sol:38, 41` and `WingsStandardExchangeVaultOutExecuteTarget.sol:51, 54` and `WingsStandardExchangeVaultOutExecutionDelegate.sol:29, 32`
- `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeInTarget.sol:78, 94` and `OutTarget.sol:77, 93` and `Common.sol:370, 386, 409`
- `contracts/protocols/staking/lido/LidoWstETHStandardExchangeInTarget.sol:90, 105` and `OutTarget.sol:81, 96` and `Common.sol:506, 521`
- `contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeInTarget.sol:83, 98` and `OutTarget.sol:76, 90` and `Common.sol:517, 531`
- `contracts/vaults/standard/erc4626/ERC4626StandardExchangeInTarget.sol:43, 54, 71, 85, 113` and `OutTarget.sol:50, 76` and `Common.sol:312, 326`
- `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeInTarget.sol:65, 77` and `OutTarget.sol:99, 139` and `Common.sol:283, 296`
- `contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeInTarget.sol:106, 125` and `OutTarget.sol:108, 142` and `Common.sol:204, 217, 332, 386`
- `contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeOutTarget.sol:108` and `CrossVersionLoopExchangeBase.sol:80, 105`
- `contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol:184, 200, 251, 264` and `BalancerV3PoolStandardExchangeTarget.sol:168, 188`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfCommon.sol:790-795` and `ExchangeOutQueryFacet.sol:107` and `ExchangeIn.sol:46` and `RebasingDETFTokenTarget.sol:259, 490` and `StakedDETFTarget.sol:166, 217`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFCommon.sol:457, 474` and `ExchangeOutQueryFacet.sol:30`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfCommon.sol:254` and `ExchangeInTarget.sol:76` and `ExchangeOutQueryTarget.sol:76`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfCommon.sol:236` and `ExchangeInTarget.sol:77` and `ExchangeOutQueryTarget.sol:77`
- `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookSeTarget.sol:187, 212` and `Common.sol:186`
- `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookSeTarget.sol:178, 200` and `Common.sol:2243`
- `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookSeTarget.sol:248` and `Target.sol:505`
- `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol:913` and `InExecutionBase.sol:88`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookSeTarget.sol:202` and `Target.sol:295`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookSeTarget.sol:209` and `Target.sol:523`

The plan author must confirm each of these `_syncAllExpectedHoldReserves()` (or equivalent) calls is present at the end of the supported money route. If any is missing, stop and report. The plan does not add a new refund logic, a new ledger, or a new attribution model.

---

## §2 — What the plan does NOT do (exclusions, restated)

- 0 code edits. No function-body change, no storage change, no new refund branch, no new ledger, no new `_refundExcess` variant.
- No edit to `contracts/protocols/dexes/uniswap/v4` (being deleted; PRD non-goal `:50`).
- No edit to Slipstream (`SlipstreamStandardExchangeInTarget.sol:220` is the same comment; PRD non-goal `:51`).
- No edit to `AGENTS.md`, `CLAUDE.md`, `SKILL.md`.
- No edit to dated review records (`docs/reviews/**`, `docs/audits/**`, `docs/research/**`, `docs/plans/**`, `docs/vaults/DETF_NESTED_SE_PUSH_PRETRANSFER_IMPLEMENTATION_PLAN.md`, and similar historical documents).
- No edit to README lines 3 and 56.
- No edit to DETF interface function signatures, parameter lists, return types, event declarations, storage layouts, or selectors.
- No new caller-attribution ledger.
- No new `push > max` refund branch.
- No new "declared amount must equal the whole surplus" revert condition.

---

## §3 — Ordered plan

The implementer (later session) executes the following steps in order. Each step is closed; no search, no choice.

### Step 0 — Pre-flight

- 0.1. Read the PRD in full.
- 0.2. Confirm Foundry 1.5.1, solc 0.8.35, `via_ir = false`, warm `out/` and `cache_forge/`.
- 0.3. Confirm `git status` shows only the files in the closed edit list (and no Slipstream, no `uniswap/v4`, no `AGENTS.md`/`CLAUDE.md`/`SKILL.md`).

### Step 1 — Re-read every named line and confirm text

For each line in §1.1, §1.2, §1.4, §1.6, the implementer re-reads the current source text and confirms it matches the "Current text" column. If any is missing or differs, stop and report. Do not invent.

### Step 2 — README documentation edits (2 edits, verbatim)

Apply the two README edits in §1.1 verbatim. Do not change any other line in the README. Do not change lines 3 and 56.

### Step 3 — DETF interface comment edits (5 files, 5 verbatim replacements)

For each DETF file in §1.2, apply the replacement text in §1.3 verbatim to every occurrence in the listed line groups. Do not change any function signature, parameter, return, event, storage, or selector. Do not change any other line in the file.

### Step 4 — Stop if a named sentence is gone

After Steps 2 and 3, re-read the source to confirm the current text was replaced by the new text. If the current text was already removed (by a prior change) and the replacement would insert a duplicate or land in the wrong place, stop and report. Do not search. Do not invent.

### Step 5 — Confirm C8 sync note preserved

Re-read every `_syncAllExpectedHoldReserves()` (or equivalent) call site listed in §1.6. Confirm the call is present at the end of every supported money route. If any is missing, stop and report.

### Step 6 — Confirm non-goals (no edits outside scope)

Re-read README lines 3 and 56. Confirm no edit landed in `contracts/protocols/dexes/uniswap/v4/`, in Slipstream, in `AGENTS.md`/`CLAUDE.md`/`SKILL.md`, or in any dated review record.

### Step 7 — Confirm no code edit and no function-body change

`git diff --stat` and `git diff contracts/` should show zero changed production-source lines. The implementer must not introduce a new branch, a new ledger, or a new refund logic.

### Step 8 — Done

The plan is complete when:
- The README line 32 sentences 2-4 and line 38 are replaced verbatim per §1.1.
- The DETF interface files in §1.2 have the replacement text at every line group.
- The C8 sync note is preserved at every call site in §1.6.
- No other file changed.
- No new ledger, no new refund branch, no new `_refundExcess` variant.
- The implementer can write a single Markdown summary naming the seven files changed and the C8 sync preservation.

I did not run Forge.