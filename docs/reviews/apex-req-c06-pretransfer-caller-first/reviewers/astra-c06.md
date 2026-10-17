# Astra — REQ-C06 replacement-session original

## Identity, authority and scope

Independent first pass by the explicitly authorized replacement Astra session, not continuity. I do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0` and did not read its history. No other reviewer's original or cross-review notes were read for this assignment. Historical reviewer summaries inside the supplied PRDs were not used as proof.

Controlling requirement: `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md:83–95`. The two supplied October 11 PRDs were read as older claims, checked against current source. All supplied input paths were present. The assigned output did not exist before this write.

This is a defensive source review, not implementation authorization. No code, PRD, tests, configuration or deployment was changed. No reproduction, exploit procedure, payload or attack parameters are included. Delegation, background agents and shell execution were not used because this reviewer session prohibits them. No AST/LSP tool was available. A multiline grep attempt was rejected by the search tool; ordinary symbol searches and direct function reads supplied the inventory instead. No external documentation was necessary for this source-order review.

Guidance read directly in this session: root `CLAUDE.md`, `docs/agent/SKILL_CATALOG.md`, canonical Crane architecture guidance, local `indexedex-testing/SKILL.md`, and canonical Crane adversarial-testing guidance (relevant opening sections). No skill tool was invoked.

## Result

**REQ-C06 remains incompletely applied.** The five known late-measurement sites remain: two hookless, two Pons and V3 exact-output mint. The wider production search also finds eighteen late-measurement calls in Uniswap V2, Camelot, Rocket Pool, Lido and EtherFi. Ten other call sites already authenticate before credit measurement. One further late-measurement call is in deprecated Slipstream and is recorded without recommending its restoration or repair.

Search results: `_pretransferCredit` in repository `contracts/**/*.sol` returned **44 occurrences across 26 files: 10 definitions and 34 calls**. All 34 call sites and all 10 definitions were inspected. Searching Solidity files under `lib/` returned no matches. There were no matches from the excluded `contracts/protocols/dexes/uniswap/v4` tree; that legacy package was not reviewed or proposed for repair. The hookless/Pons paths below are different trees and remain in scope.

**Scope qualification:** The application PRD's whole-draft non-goals at line 178 say “No EtherFi change.” Its two calls are therefore explicitly reported in the exhaustive inventory and as the same source-order mismatch, but this report does not authorize an EtherFi edit contrary to that non-goal. This does not affect the findings on the other 21 nondeprecated late-measurement sites. A coordinator must preserve that distinction in any later authorized repair scope.

### Common intended behavior and impact

For each finding below, the intended behavior is application PRD REQ-C06: on a true pretransfer flag, `LocalCreditLib.requirePretransferCaller(msg.sender)` executes **before `_pretransferCredit` and before any computation consuming that measured credit**; existing credit comparisons remain afterward. False-flag pulls do not acquire this caller check. `LocalCreditLib.sol:23–27` implements the named bytecode-based rejection. It does not establish ownership of a prior transfer.

All findings are **Low severity**, **high confidence in source ordering**, with impact class **diagnostic-order / requirement-conformance failure**. They do not establish an authorization bypass, principal loss, or the precise error observed in an executed transaction. Measurement invokes a balance read before authentication; credit-dependent quoting/planning can also run first at the identified sites. It is an inference that an earlier measurement/plan failure can mask the required caller diagnostic; no particular runtime failure was reproduced. No speculation about theft is adopted.

Independent input-ceiling checks that do not consume measured credit are **not** findings. The good V3 quoted-swap branch is an explicit example of a permitted earlier quote/input-ceiling check.

## Findings

### Astra-C06-01 — Hookless mint and direct-out measure and price credit before authenticating

- **Severity / impact / confidence:** Low; diagnostic-order conformance; high.
- **File:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol`.
- **Sites:** `_executeZapInMintExactOut`, lines **94–101**; `_executeDirectOut`, lines **165–169**.
- **Facts:** Mint measures at 94, consumes credit in `_amountInForZapMint` at 95 and reaches `_requirePrepaidCredit` only at 101. Direct-out measures at 165 and builds `_snapshot` / `_directOutPlan` from it at 166 before the helper at 169. That helper authenticates at 140 and compares `used > credit` at 141. The common `_pretransferCredit` at lines 945–953 does not authenticate. The operation-scope modifier does not supply a caller check. The mint quote's OutBase lines 59–70 explicitly use prepaid credit in reserve checks and arithmetic.
- **Broken requirement / intended behavior:** REQ-C06 lines 87–93 requires authentication before these measurements and their consuming computations, not merely before the final short-credit comparison.
- **Exact fix direction:** In mint, immediately after the existing zero-share check at 93, insert a true-flag-only `LocalCreditLib.requirePretransferCaller(msg.sender)` statement; then retain the credit assignment, credit-dependent amount calculation, input-ceiling comparison, balance snapshot and later prepaid block in their existing order. In direct-out, insert a `prepaid`-only caller check immediately before the credit assignment at 165, after the existing frame/direction initialization; then retain measurement, plan, `used` assignment, maximum comparison and prepaid-credit comparison in that order. **Keep `_requirePrepaidCredit` unchanged**, including its existing caller check and `used > credit` comparison. Keep the later custody check, transfer/refund behavior and false path unchanged. Duplicate downstream checking is intentional here; do not redesign helpers or remove a check as part of this narrow fix.

### Astra-C06-02 — Pons mint and direct-out have the same late caller check

- **Severity / impact / confidence:** Low; diagnostic-order conformance; high.
- **File:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol`.
- **Sites:** `_executeZapInMintExactOut`, lines **94–101**; `_executeDirectOut`, lines **165–169**.
- **Facts:** These separately inspected functions have the same ordering as hookless: credit measurement, credit-dependent amount/plan, then `_requirePrepaidCredit`. Its caller check/comparison are at 140–141. Pons Common lines 945–953 measures without authenticating, and its OutBase lines 59–70 consume the credit.
- **Broken requirement / intended behavior:** REQ-C06 lines 87–93 requires caller-first measurement separately for this family; repairing hookless does not repair Pons.
- **Exact fix direction:** Apply exactly the statement ordering specified for Astra-C06-01 **in this Pons file too**: guarded check after the mint zero-share check and before its credit assignment; guarded check immediately before direct-out credit assignment after frame/direction initialization; all later amount/plan/maximum/credit comparisons stay in order. Leave `_requirePrepaidCredit`, including both statements, unchanged. Do not add the caller check to a false flag or modify custody, refund or settlement math.

### Astra-C06-03 — V3 exact-output mint consumes measured credit before its caller check

- **Severity / impact / confidence:** Low; diagnostic-order conformance; high.
- **File:** `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol`.
- **Site:** `executeZapInMintExactOut`, lines **102–110**.
- **Facts:** Credit is measured at 102, used in the amount calculation at 103 and followed by the maximum comparison at 104. Authentication is at 109, before the short-credit comparison at 110 but after measurement. OutBase lines 44–51 subtract prepaid credit in the mint quote. The remaining common helper does not authenticate on measurement.
- **Broken requirement / intended behavior:** REQ-C06 requires the caller check before measurement and that quote, while retaining the short-credit rejection and false-flag pull behavior.
- **Exact fix direction:** Move the existing caller-check statement at 109 into a new `pretransferred`-only check immediately after `IERC20 token = IERC20(tokenIn)` at 101 and before credit assignment at 102. Keep the zero-share check, token conversion, guarded caller check, credit measurement, amount calculation and maximum comparison in that sequence. Keep the later prepaid block's `amountIn > credit` comparison and `pullAmount = credit` unchanged; only its now-relocated caller-check statement is removed. Leave `_secureTokenTransfer`, `_requireDelivered`, refund, mint and sync code unchanged. The false flag skips the new guarded statement.

### Astra-C06-04 — Uniswap V2 exact-output routes measure credit before their downstream guard

- **Severity / impact / confidence:** Low; measurement-order conformance; high.
- **File:** `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol`.
- **Every affected call site:**

| Line | Branch/function | Later guard/check path |
|---|---|---|
| **462** | `exchangeOut`, pass-through swap | `_secureTokenTransfer` at 463 |
| **547** | `exchangeOut`, pass-through zap-out | `_secureTokenTransfer` at 548–555 |
| **623** | `exchangeOut`, underlying-pool vault deposit | `_secureTokenTransfer` at 624 |
| **693** | `exchangeOut`, underlying-pool vault withdrawal | `_secureSelfBurn` at 694–701 |
| **794** | `exchangeOut`, zap-out vault withdrawal | `_secureSelfBurn` at 795 |
| **905** | `_exchangeOut_zapInVaultDeposit` | `_secureTokenTransfer` at 907 |
| **972** | `_exchangeOut_passThroughZapIn` | `_secureTokenTransfer` at 973 |

- **Facts:** The dispatcher and helper bodies do not authenticate before these assignments. Common `_pretransferCredit` at 494–499 only measures/caps available credit. The later token and self-burn checks authenticate at Common 457 and 486, respectively. This is the measurement-before-authentication defect even where the subsequent insufficient-credit error already follows authentication.
- **Broken requirement / intended behavior:** The application PRD's “each prepaid branch” measurement-order invariant is not met by a later custody guard. The independent maximum comparisons preceding these assignments are not themselves defects.
- **Exact fix direction:** At **each of the seven listed assignments**, insert `if (pretransferred) LocalCreditLib.requirePretransferCaller(msg.sender);` immediately before the assignment, preserving the earlier quote and maximum comparison. Keep each existing ternary credit assignment, subsequent token-transfer/self-burn call and refund path in its current order. Retain the existing Common token-credit comparison at 461–462, self-balance comparison at 489, and bounded-credit comparison at 505; do not move, replace or remove them. Import the canonical library in the OutTarget if needed. Do not modify the common helpers, add an unconditional entry gate, or subject false-flag calls to the new check.

### Astra-C06-05 — Camelot exact-output routes also measure before their downstream guard

- **Severity / impact / confidence:** Low; measurement-order conformance; high.
- **File:** `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol`.
- **Every affected call site:**

| Line | `exchangeOut` branch | Later guard/check path |
|---|---|---|
| **411** | Pass-through swap | `_secureTokenTransfer` at 413 |
| **513** | Pass-through zap-out | `_secureTokenTransfer` at 514–521 |
| **596** | Underlying-pool vault deposit | `_secureTokenTransfer` at 597 |
| **663** | Underlying-pool vault withdrawal | `_secureSelfBurn` at 665–672 |
| **766** | Zap-out vault withdrawal | `_secureSelfBurn` at 768 |

- **Facts:** Common `_pretransferCredit` at 233–238 has no caller check. Authentication occurs later in Common `_secureTokenTransfer` at 196 or `_secureSelfBurn` at 225. No entry check precedes these measurements.
- **Broken requirement / intended behavior:** REQ-C06's caller-before-measurement invariant is unmet; no authorization bypass is inferred. The already-correct share maximum comparison at 762–764 is not reopened.
- **Exact fix direction:** Insert the true-flag-only canonical caller check immediately before **each of these five credit assignments**; keep all preceding quote/input-ceiling statements, then measurement, then custody/burn and refund in their current order. Preserve Common's token-credit comparison at 200–201, self-share balance comparison at 228 and bounded-credit comparison at 244, as well as their existing caller checks. Import the library in the OutTarget if needed. Do not rewrite common helpers or apply this new guard on false flags.

### Astra-C06-06 — Rocket Pool measures credit before mint pricing and secure pull

- **Severity / impact / confidence:** Low; measurement-order / credit-dependent-quote conformance; high.
- **File:** `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeOutTarget.sol`.
- **Sites:** `exchangeOut` asset-to-share branch at **60–65** and asset-to-asset branch at **82–83**.
- **Facts:** The first branch measures at 60, then passes credit to `_reserveBeforePretransfer` and prices at 62–63. Both branches reach the caller check only through `_securePull` (Common line 357). Common `_pretransferCredit` at 324–329 has no check.
- **Broken requirement / intended behavior:** REQ-C06 requires authentication before measurement and credit-dependent pricing; the earlier asset-to-asset quote/maximum comparison, which does not consume this credit, is not a defect.
- **Exact fix direction:** Insert a `pretransferred`-only canonical caller check immediately before line 60 and separately immediately before line 82, importing the library in this OutTarget if necessary. Preserve route validation before each insertion and retain the existing measurement, reserve/pricing computation where present, maximum comparison, secure pull, execution and refund order. Keep Common's amount-versus-available comparison at 359–360 and refund bounded-credit comparison at 335 unchanged, including its existing later secure-pull caller check. Do not add the check to false flags or the ordinary share-burn route.

### Astra-C06-07 — Lido measures credit before mint pricing and secure pull

- **Severity / impact / confidence:** Low; measurement-order / credit-dependent-quote conformance; high.
- **File:** `contracts/protocols/staking/lido/LidoWstETHStandardExchangeOutTarget.sol`.
- **Sites:** `exchangeOut` asset-to-share at **64–70** and asset-to-asset at **85–86**.
- **Facts:** Mint credit precedes reserve adjustment and pricing at 66–67. The two branches authenticate later through Common `_securePull` at 495. Common `_pretransferCredit` at 455–460 measures without checking.
- **Broken requirement / intended behavior:** Same REQ-C06 invariant; preserving the later short-credit comparison alone is insufficient.
- **Exact fix direction:** Insert the `pretransferred`-only canonical caller check immediately before each credit assignment at 64 and 85; import the library in the OutTarget if needed. Keep the mint reserve/pricing statements, false-flag stETH adjustment, maximum comparisons, secure pulls and refunds in their existing relative order. Preserve Common's available-credit comparison at 497–498 and refund credit comparison at 464, including the existing secure-pull guard. False-flag and ordinary share-burn routes do not receive this new check.

### Astra-C06-08 — EtherFi has the same two late measurements; record the no-edit scope restriction

- **Severity / impact / confidence:** Low; measurement-order / credit-dependent-quote conformance; high.
- **File:** `contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeOutTarget.sol`.
- **Sites:** `exchangeOut` asset-to-share at **61–67** and asset-to-asset at **84–85**.
- **Facts:** Credit is measured before mint reserve/pricing at 63–64 and before either secure pull. Common `_pretransferCredit` at 452–457 does not check; `_securePull` checks at 506 and compares available credit at 508–509.
- **Broken requirement / intended behavior:** The source has the same caller-before-measurement mismatch identified by REQ-C06. **Application PRD line 178 separately forbids an EtherFi change**, so this finding is inventory evidence, not permission to implement it under the unchanged application scope.
- **Exact fix direction if separately authorized:** Immediately before each credit assignment at 61 and 84, insert the `pretransferred`-only canonical caller check; import that library in the OutTarget if needed. Leave route validation, reserve/pricing, false-flag eETH adjustment, maximum comparison, secure pull, execution and refund in their current relative order. Keep Common's available-credit comparison at 508–509, refund-credit comparison at 461 and existing later caller check unchanged. Do not add the guard to false flags or ordinary share burns. **Under the currently supplied no-EtherFi-change rule, record rather than execute this repair.** There is no implementer discretion to silently override that scope rule.

## Caller-first production sites — leave alone

The following table accounts for the **ten already-correct `_pretransferCredit` calls**. Earlier independent quotes and input ceilings do not consume the subsequently measured credit and are not REQ-C06 defects.

| File | Function/site | Caller check → measurement → comparison |
|---|---|---|
| `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol` | `_executeQuotedSwapOut` | **82 → 83 → 84**; leave quote/maximum at 77–78 alone |
| `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol` | `executeZapOutWithdrawal` | **31 → 32 → 33–34**; this function stays unchanged despite the sibling mint finding |
| `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutMultiTarget.sol` | `exchangeOutOneToMany` | **39 → 40 → 41–42** |
| `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecutionDelegate.sol` | `executeZapOutWithdrawal` | **36 → 37 → 38** |
| `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutMultiTarget.sol` | `exchangeOutOneToMany` | **45 → 46 → 47–48** |
| `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutExecutionDelegate.sol` | `executeZapOutWithdrawal` | **36 → 37 → 38** |
| `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutMultiTarget.sol` | `exchangeOutOneToMany` | **45 → 46 → 47–48** |
| `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeOutExecuteTarget.sol` | `_creditOutInbound` | **290 → 291 → 292–293** |
| Same Aerodrome file | `_execZapInVaultDeposit` | **396 → 397 → 425–426**, with credit captured before subsequent compounding |
| Same Aerodrome file | `_execUnderlyingPoolVaultDeposit` | **488 → 489 → 496**, with credit captured before subsequent compounding |

The V3/hookless/Pons common `_secureTokenTransfer` functions themselves also have the required order: respectively **868 → 869–873**, **909 → 910–914**, and **909 → 910–914**. They are not the fix sites. The Uniswap V2/Camelot secure-transfer and secure-self-burn helpers, and staking secure-pull helpers cited above, also already authenticate before their own balance/credit checks. Leave those functions intact; they do not retroactively authenticate an earlier `_pretransferCredit` call.

## Deprecated site — record, do not repair or restore

`contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeOutTarget.sol:85` measures credit in `exchangeOut` before `_secureTokenTransfer` at 86. Common `_pretransferCredit:475–480` contains no check; Common `_secureTokenTransfer:508–514` checks the caller before its own measurement/comparison. This is the same measurement-order pattern, but Slipstream is deprecated and the PRD explicitly says not to restore it. Its independent maximum comparison at OutTarget 83 is not the defect. No Slipstream edit is proposed.

## Corrections to the older supplied claims

1. The October 11 caller-first PRD's quoted V3 `_executeQuotedSwapOut` snippet is stale. Current lines 82–84 already check, measure, compare; do not repair that branch again.
2. Hookless/Pons now place the **short-credit comparison** behind authentication through `_requirePrepaidCredit`. Their remaining defect is the earlier measurement and credit-consuming quote/plan, not an unguarded short-credit comparison at that helper.
3. V3 exact-output withdrawal remains correctly ordered. V3 exact-output **mint**, a different function in the same file, remains late.
4. The exhaustive inventory is larger than the named three-family examples: measurement-first sites also exist in V2, Camelot and the three staking adapters. This report does not infer that the input-ceiling error is necessarily the diagnostic reached on any of them.
5. The requirement is not “make the caller check the first instruction in every function.” Keep unrelated validation and independent input-ceiling comparisons; insert/move the check at the precise measurement boundary specified above.

## Files examined without a REQ-C06 defect, and evidence limitations

No REQ-C06 defect was found in the complete caller-first functions listed above. The entire review is scoped to ordering, not a general clearance of those contracts. Files with no defect identified in the inspected relevant portions include:

- V3 `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol` and `UniswapV3FullSpreadStandardExchangeVaultOutMultiTarget.sol`.
- Hookless and Pons `*OutExecutionDelegate.sol` and `*OutMultiTarget.sol` named in the caller-first table.
- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeOutExecuteTarget.sol`, its three measured-credit branches, and the inspected helper portion of `AerodromeStandardExchangeCommon.sol`.
- `contracts/utils/LocalCreditLib.sol` and `lib/crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol`.
- V3/hookless/Pons `*OutBase.sol` quote bodies: they consume supplied credit as expected; fixing their callers' ordering does not require changing those quotes.
- The ten Common `_pretransferCredit` definitions are measurement-only helpers. Their lack of an internal caller check is not independently counted as ten defects: correctly guarded callers already use them. Their bodies and the correctly ordered custody helpers should remain unchanged under the concrete fixes above.

All paths cited in findings, the caller-first table, and the Common helper evidence were examined at the relevant current bodies. No test execution, artifact freshness, compiled size, runtime revert trace, source hash or deployed-instance inventory was obtained. Counts refer to the direct symbol search of the accessible source tree, not a compiler-resolved call graph or a claim about differently named credit mechanisms. A later authorized implementation must obtain production-proxy evidence for caller diagnostic precedence, retained insufficient-credit rejection, unchanged balances on failure and unaffected false-flag behavior; this report does not claim those tests passed.

I did not run Forge.
