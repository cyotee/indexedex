# Kimi K3 — original: REQ-C06 prepaid caller-check order

- **Label:** Replacement-session original, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No reviewers' notes were read. No code was edited.
- **Date:** 2026-10-14.
- **Controlling requirement:** `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md` REQ-C06 (`:83-95`, re-read in full this round). The 2026-10-11 draft (`apex-req-c06-pretransfer-caller-first/REMEDIATION_PRD.md`) was treated as a claim; its "known sites" list is confirmed incomplete by the search below. The Stage-2 confirmation text is older and not relied on.
- **Scope:** every production call of `_pretransferCredit` under `contracts/`. `contracts/protocols/dexes/uniswap/v4/` is being deleted and is excluded. Slipstream is deprecated and is recorded, not repaired.
- I did not run Forge. All order claims are source reads, not executions.

## The requirement as read

"On a pretransfer, the caller is authenticated before the credit is measured. A code-less caller is rejected with `EOAPretransferNotAllowed` even when the pushed credit is also short." Acceptance criterion 1: "On each prepaid branch that measures credit before authentication, `requirePretransferCaller` runs before `_pretransferCredit` and before a quote or plan that consumes that credit." Non-goal: an input-ceiling comparison that does not consume measured credit is not this defect. The current code already contains the model order: gate, then measurement (`UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:82-83`).

## Inventory: every production `_pretransferCredit` call, classified

**A. Defective order — measurement and a consuming quote/plan run before the gate** (details in the findings):

| Site | Order as read |
| --- | --- |
| `…/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol:94-101` (mint) | credit `:94` → `_amountInForZapMint` consumes `:95` → gate inside `_requirePrepaidCredit` `:101` |
| Same file `:165-169` (direct out) | credit `:165` → `_directOutPlan` consumes `:166` → gate `:169` |
| `…/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol:94-101` and `:165-169` | identical shape (gate helper at `:139-142`) |
| `…/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:102-110` (`executeZapInMintExactOut`) | credit `:102` → `_amountInForZapMint` consumes `:103` → gate `:109` |
| `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeOutTarget.sol:60-65` (asset→SE mint) | credit `:60` → `_reserveBeforePretransfer` consumes `:62` → `_quoteMintAtReserve` `:63` → gate inside `_securePull` `:65` (`RocketPoolRETHStandardExchangeCommon.sol:357`) |
| `contracts/protocols/staking/lido/LidoWstETHStandardExchangeOutTarget.sol:64-70` (same route) | credit `:64` → consume `:66-67` → gate inside `_securePull` `:70` (`LidoWstETHStandardExchangeCommon.sol:495`) |
| `contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeOutTarget.sol:61-67` (same route) | credit `:61` → consume `:63-64` → gate inside `_securePull` `:67` (`EtherFiWeETHStandardExchangeCommon.sol:506`) |

**B. Measurement immediately before the gate-bearing helper; nothing consumes the credit in between.** These violate criterion 1's letter but I found no divergent outcome: `_pretransferCredit` is a non-reverting view over the token's `balanceOf`, and the gate fires inside the helper before any state change, so a code-less caller still reverts `EOAPretransferNotAllowed`. Named per the task's instruction; classified as not the defect (see "Judgment" below):

- Rocket asset→asset `:82-83`; Lido `:85-86`; EtherFi `:84-85` (gate inside `_securePull` on the next line).
- Camelot V2 `CamelotV2StandardExchangeOutTarget.sol:411-413`, `:513-514`, `:596-597`, `:663-665`, `:766-768` (gate inside `_secureTokenTransfer`, `CamelotV2StandardExchangeCommon.sol:196`, or `_secureSelfBurn`, `:225`).
- Uniswap V2 `UniswapV2StandardExchangeOutTarget.sol:462-463`, `:547-548`, `:623-624`, `:693-694`, `:794-795`, `:905-907`, `:972-973` (gate inside `_secureTokenTransfer`, `UniswapV2StandardExchangeCommon.sol:457`, or `_secureSelfBurn`, `:486`).
- Slipstream `SlipstreamStandardExchangeOutTarget.sol:85-86` — deprecated; recorded, not repaired (PRD non-goal, `:95`).

**C. Already caller-first — cite and leave alone (PRD `:94`):**

- `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:82-83` (`_executeQuotedSwapOut` — the PRD's cited correct example).
- `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:31-32` (`executeZapOutWithdrawal` — the model order).
- `UniswapV3FullSpreadStandardExchangeVaultOutMultiTarget.sol:39-40`.
- Hookless and Pons withdrawal delegates: `…HooklessStandardExchangeVaultOutExecutionDelegate.sol:36-37` and `…PonsFamilyHookOutExecutionDelegate.sol:36-37`.
- Aerodrome v1 `AerodromeStandardExchangeOutExecuteTarget.sol:290-291`, `:396-397`, `:488-489`.

## Findings

### F1 — REQ-C06's named branches: consuming quote/plan precedes the caller gate

- **Severity:** Low (the controlling PRD's severity; diagnostic order, not an authorization bypass — the call still reverts, and no principal-loss path was shown by anyone).
- **File and line:** hookless `…OutExecuteTarget.sol:94-101` and `:165-169`; Pons `…HookOutExecuteTarget.sol:94-101` and `:165-169`; V3 `…OutExecutionDelegate.sol:102-110`.
- **Intended behavior (PRD `:87`, `:90`):** "On a pretransfer, the caller is authenticated before the credit is measured… `requirePretransferCaller` runs before `_pretransferCredit` and before a quote or plan that consumes that credit."
- **Broken requirement or invariant:** on all five branches, `_pretransferCredit` executes first and the measured credit is consumed by `_amountInForZapMint` or `_directOutPlan` before `LocalCreditLib.requirePretransferCaller` runs (inside `_requirePrepaidCredit` at hookless `:139-142` / Pons `:138-142`, or inline at V3 `:109`). Fact, from the reads above. Inference (unexecuted): with a zero-credit measurement, the consuming plan can shape a different revert before the gate, so a code-less caller with a short push may not receive the named error.
- **Impact class:** diagnostic order / error-identity conformance.
- **Fix direction (no implementer choice):** on each of the five branches, insert `LocalCreditLib.requirePretransferCaller(msg.sender);` as the first statement inside the existing `pretransferred`/`prepaid` guard, before the `_pretransferCredit` call. The existing credit comparison stays and keeps running after that gate: `_requirePrepaidCredit` is not edited (its internal gate call remains, harmlessly second), and V3's `if (amountIn > credit) revert TransferDeltaInsufficient` stays where it is. A `false`-flag call never receives the check: the added statement sits inside the flag's guard. No quote math, no input maximum, and no settlement output check changes.
- **Confidence:** high on the order facts; the divergent-revert outcome is inference.

### F2 — the same defective order on the staking families' exact-out mint routes (new sites from this search)

- **Severity:** Low (same diagnostic-order class; the older draft's search instruction (`apex-req-c06-pretransfer-caller-first/REMEDIATION_PRD.md`, "search active production pretransfer paths") anticipated finding more sites; the application PRD's criterion 1 is written generally).
- **File and line:** `RocketPoolRETHStandardExchangeOutTarget.sol:60-65`; `LidoWstETHStandardExchangeOutTarget.sol:64-70`; `EtherFiWeETHStandardExchangeOutTarget.sol:61-67`; gates inside `RocketPoolRETHStandardExchangeCommon.sol:357`, `LidoWstETHStandardExchangeCommon.sol:495`, `EtherFiWeETHStandardExchangeCommon.sol:506`.
- **Intended behavior:** as F1.
- **Broken requirement or invariant:** on the asset→SE mint route, `credit` is measured, then consumed by `_reserveBeforePretransfer` and `_quoteMintAtReserve` (`RocketPoolRETHStandardExchangeCommon.sol:178-190`), and only then does `_securePull` reach the gate. Fact. The three files are sibling copies of the same shape.
- **Impact class:** diagnostic order.
- **Fix direction (no implementer choice):** in each of the three OutTarget mint branches, insert `LocalCreditLib.requirePretransferCaller(msg.sender);` immediately before the `uint256 credit = pretransferred ? … : 0;` line, guarded by `if (pretransferred) { … }` so the false flag never receives it. `_securePull` is not edited; its internal gate stays. The quote and ceiling order after the measurement is unchanged. Do not touch the sibling asset→asset branches under this finding; see the judgment note.
- **Confidence:** high on the order facts.

## Judgment the coordinator should record (class-B sites)

Criterion 1's letter ("runs before `_pretransferCredit`") covers the class-B sites, because the bare measurement executes before the gate. The PRD's defect narrative narrows to "Measurement, **and a plan built from that measurement**," and its non-goal excludes non-consuming comparisons. On the class-B sites nothing reads the credit until after the gate, so no error-order divergence exists today. If the coordinator reads criterion 1 literally, the same one-line reorder applies to class B; if the diagnostic intent governs, class B is cited here and left alone. I do not choose between those readings; no defect finding is opened on class B.

## What is not a finding

- The input-ceiling comparisons that precede the gate on several of these branches (e.g., hookless `:96`, Rocket `:64`) are excluded by the PRD's non-goal: they do not consume measured credit, and the controlling model routes place ceilings before the gate too.
- The false-flag paths receive no caller check anywhere in the inventory — compliant with the acceptance criterion, not a gap.

I did not run Forge.
