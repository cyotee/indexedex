# MiniMax M3 — REQ-C06 cross-review, replacement session

- **Session label:** replacement session `ses_ebdf718feffemWQNf7wuTpapqX`. I do not recall `ses_ec41255ceffeVhrySLQe8hwwMC`. I read only the three originals below and the controlling application PRD; I do not read any prior MiniMax session memory.
- **Files read for this cross-review:**
  - `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md` (controlling current requirement, section REQ-C06 at `:83-95`, read in full)
  - `docs/reviews/apex-req-c06-pretransfer-caller-first/REMEDIATION_PRD.md` (2026-10-11 draft, treated as a claim to confirm or correct, not authority)
  - `docs/reviews/apex-req-c06-pretransfer-caller-first/reviewers/astra-c06.md` (Astra replacement-session original)
  - `docs/reviews/apex-req-c06-pretransfer-caller-first/reviewers/grok-c06.md` (Grok original)
  - `docs/reviews/apex-req-c06-pretransfer-caller-first/reviewers/kimi-c06.md` (Kimi replacement-session original)
  - My own first pass: `docs/reviews/apex-req-c06-pretransfer-caller-first/reviewers/minimax-c06.md`
- **Coordinator's question:** agree or dissent on the closed site list. The PRD cannot leave a search or a scope choice for the implementer. If I dissent, give the one sentence the PRD must use.
- **Standing constraints (not negotiable):** legacy `contracts/protocols/dexes/uniswap/v4` is the legacy V4 being deleted by a separate agent and is out of scope. The V4 FullSpread hookless and Pons-family under `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/` is in scope. No code edits. No `REMEDIATION_PRD.md`. No Forge. No exploit procedures.

---

## 1. Where the four reviews agree

All four reviews agree on the following; no dissent is recorded here.

1. **The five consuming-plan sites (PRD-named):**
   - V4 FullSpread hookless `_executeZapInMintExactOut` lines **94-101** and `_executeDirectOut` lines **165-169** (`UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol`).
   - V4 FullSpread Pons-family `_executeZapInMintExactOut` lines **94-101** and `_executeDirectOut` lines **165-169** (`UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol`).
   - V3 FullSpread `executeZapInMintExactOut` lines **102-110** in `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol`.
2. **The cited-and-left-alone site:** V3 FullSpread `_executeQuotedSwapOut` lines **82-84** in `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol`. Caller check on line 82, measurement on line 83, credit check on line 84.
3. **The already-correct production call sites (10 functions, named by every reviewer):**
   - V3 `executeZapOutWithdrawal` lines 31-32.
   - V3 `exchangeOutOneToMany` lines 39-40.
   - V4 FullSpread hookless `executeZapOutWithdrawal` lines 36-37.
   - V4 FullSpread hookless `exchangeOutOneToMany` lines 45-46.
   - V4 FullSpread Pons-family `executeZapOutWithdrawal` lines 36-37.
   - V4 FullSpread Pons-family `exchangeOutOneToMany` lines 45-46.
   - Aerodrome V1 `_creditOutInbound` lines 290-291.
   - Aerodrome V1 `_execRoute6` lines 396-397.
   - Aerodrome V1 `_execUnderlyingPoolVaultDeposit` lines 488-489.
4. **The deprecated Slipstream line 85** is recorded and not repaired. PRD non-goal forbids restoration.
5. **The legacy `contracts/protocols/dexes/uniswap/v4` tree** is out of scope.
6. **The fix direction for the consuming-plan sites is the same statement order across all four reviews:** insert a `LocalCreditLib.requirePretransferCaller(msg.sender)` call inside the existing `pretransferred`/`prepaid` guard, immediately before the `_pretransferCredit` measurement. Keep the existing credit comparison. A false flag does not gain the caller check.
7. **The non-goal on input-ceiling checks is observed:** the `quote > max` comparisons that sit before the gate on several branches (e.g., hookless `:96`, V3 mint `:104`, Rocket `:64`, Lido `:69`) are not defects; they do not consume measured credit.
8. **Severity is Low, impact class is diagnostic order, not authorization bypass.** No principal-loss path is shown.

There is no dissent on items 1-8.

---

## 2. Where the four reviews disagree

### 2.1 Staking-family mint sites (Rocket 60-65, Lido 64-70, EtherFi 61-67) — RESOLVED toward Kimi/Grok/Astra

**Where the disagreement lives.**

- **Astra (Astra-C06-06, Astra-C06-07, Astra-C06-08):** Staking mint sites in Rocket, Lido, and EtherFi all measure credit then pass it to `_reserveBeforePretransfer` and `_quoteMintAtReserve` before `_securePull` reaches the gate. Astra calls these defects. Astra records EtherFi as out of repair scope per the application PRD line 178 ("No EtherFi change") but the source-order finding is the same.
- **Grok (Grok finding 6):** Same three staking mint sites are defects on the consuming-plan reading. EtherFi included.
- **Kimi (F2):** Same three staking mint sites are defects, classified as consuming-plan defects, with explicit fix direction.
- **MiniMax M3 first pass:** I said the staking sites are NOT defects because the external `_pretransferCredit` is informational and the short-credit revert lives inside `_securePull`, which checks the caller first.

**Resolution.**

Astra, Grok, and Kimi are correct; my first pass was wrong on these three sites. The reason: in each staking mint site, the measured `credit` is passed to `_reserveBeforePretransfer(in_, credit)` (Lido) and `_quoteMintAtReserve(in_, amountOut, totalBefore)` to compute `amountIn` for the mint — a **plan that consumes the measured credit** runs before the gate inside `_securePull`. This is exactly the PRD's criterion 1 trigger: a quote or plan that consumes the credit runs before `requirePretransferCaller`. My first pass conflated "informational measurement for refund math" (V2/Camelot bare-measurement pattern) with "consumed by the mint quote" (staking pattern). The two are distinct.

The fix direction for the three staking mint sites: insert `if (pretransferred) { LocalCreditLib.requirePretransferCaller(msg.sender); }` immediately before `uint256 credit = pretransferred ? _pretransferCredit(tokenIn, maxAmountIn) : 0;` on each branch. Keep the existing `_securePull` call (its internal caller check is now redundant but harmless). Keep the `_reserveBeforePretransfer` and `_quoteMintAtReserve` calls in their existing order after the measurement. Do not add the check on a false flag.

The EtherFi record note: the application PRD's whole-draft non-goal at line 178 says "No EtherFi change." EtherFi is therefore recorded as a finding, not opened for repair under the current scope. The source defect is the same as Rocket and Lido; the closed repair scope is determined by the application PRD, not by my first pass.

### 2.2 Staking-family asset-to-asset sites (Rocket 82-83, Lido 85-86, EtherFi 84-85) — RESOLVED toward Kimi/Grok/Astra

**Where the disagreement lives.**

- **Astra (Astra-C06-06, Astra-C06-07, Astra-C06-08):** The asset-to-asset branch in Rocket, Lido, and EtherFi is named as a defect in each finding's "Sites" list. Astra treats the measurement before the gate as the defect trigger.
- **Grok (Grok finding 6, second sentence in "Sites"):** Same three asset-to-asset sites are defects.
- **Kimi (F2 + class B discussion):** The asset-to-asset branch is named in Kimi's "Sites" line. Kimi also has a class-B discussion that lists Rocket `:82-83`, Lido `:85-86`, EtherFi `:84-85` as "measurement immediately before the gate-bearing helper; nothing consumes the credit in between." Kimi says "I do not choose between those readings; no defect finding is opened on class B."
- **MiniMax M3 first pass:** I said the staking sites are NOT defects because the external `_pretransferCredit` is informational and the short-credit revert lives inside `_securePull`, which checks the caller first.

**Resolution.**

Astra and Grok apply the literal PRD criterion 1 ("runs before `_pretransferCredit`") to these sites. Kimi records them but defers. The literal reading of criterion 1 is: on each prepaid branch that measures credit before authentication, the gate must run before the measurement. The non-goal "An input-ceiling comparison that does not consume measured credit is not this defect" specifically addresses input-ceiling checks (quote-vs-max), not bare measurements. The asset-to-asset sites have a bare measurement before the gate; under the literal reading they are defects.

My first pass applied a "consuming-plan" reading that the PRD's literal text does not support. The PRD's "and before a quote or plan that consumes that credit" clause is an additional constraint, not a limiter: where there is no consuming plan, the gate still must run before the measurement.

The fix direction for the three staking asset-to-asset sites: insert `if (pretransferred) { LocalCreditLib.requirePretransferCaller(msg.sender); }` immediately before `uint256 credit = pretransferred ? _pretransferCredit(tokenIn, maxAmountIn) : 0;` on each branch. Keep the existing `_securePull` call (its internal caller check is now redundant but harmless). Do not add the check on a false flag. The EtherFi asset-to-asset site is recorded but excluded from repair per line 178.

### 2.3 Uniswap V2 and Camelot bare-measurement sites — RESOLVED toward Kimi/Grok/Astra

**Where the disagreement lives.**

- **Astra (Astra-C06-04, Astra-C06-05):** All seven Uniswap V2 sites (`462, 547, 623, 693, 794, 905, 972`) and all five Camelot sites (`411, 513, 596, 663, 766`) are defects under the literal PRD criterion 1.
- **Grok (Grok finding 7):** Same twelve sites. The fix direction is identical.
- **Kimi (class B):** Same twelve sites are listed as "class B" — measurement before the gate, no consuming plan between them. Kimi defers the reading question.
- **MiniMax M3 first pass:** I said these are NOT defects because the external `_pretransferCredit` is informational and the short-credit revert lives inside `_secureTokenTransfer`/`_secureSelfBurn`/`_securePull`, all of which check the caller first.

**Resolution.**

Astra and Grok are correct; my first pass was wrong. The literal PRD criterion 1 says the gate must run before `_pretransferCredit` on each prepaid branch that measures credit before authentication. The non-goal on "input-ceiling comparison that does not consume measured credit" specifically addresses input-ceiling checks; it does not exempt bare measurements. The V2 and Camelot sites have a bare measurement before the gate; they are defects.

The fix direction for the twelve V2 and Camelot sites: at each named line, insert `if (pretransferred) LocalCreditLib.requirePretransferCaller(msg.sender);` immediately before the `_pretransferCredit` call. Keep the existing `_secureTokenTransfer` / `_secureSelfBurn` / `_securePull` call (its internal caller check is now redundant but harmless). Keep the existing credit comparison inside the secure helper. Do not add the check on a false flag. The application PRD's known site list (the V4 FullSpread and V3 mint families) is incomplete under the literal reading; the implementer must extend the search to V2 and Camelot.

### 2.4 EtherFi repair scope — RESOLVED, EtherFi is recorded but not repaired

**Where the disagreement lives.**

- **Astra:** Records the EtherFi finding as inventory evidence, not permission to implement. "Application PRD line 178 separately forbids an EtherFi change, so this finding is inventory evidence, not permission to implement it under the unchanged application scope."
- **Grok:** Names EtherFi in the defect list. Grok's fix direction is the same as Rocket and Lido, but does not acknowledge the line-178 carve-out.
- **Kimi:** Names EtherFi in the sites list with the same fix direction; does not address the line-178 carve-out.
- **MiniMax M3 first pass:** Did not name EtherFi.

**Resolution.**

The application PRD's whole-draft non-goal at line 178 says "No EtherFi change." Under the unchanged application scope, EtherFi is recorded as a source defect but excluded from the repair scope. The implementer does not edit EtherFi. This is the same scope treatment Astra records.

### 2.5 Order of edit (whether the V3 mint delegate fix relocates the existing caller check or adds a new one) — RESOLVED toward Grok

**Where the disagreement lives.**

- **Astra (Astra-C06-03):** "Move the existing caller-check statement at 109 into a new `pretransferred`-only check immediately after `IERC20 token = IERC20(tokenIn)` at 101 and before credit assignment at 102."
- **Grok (Grok finding 5):** "Move the existing `LocalCreditLib.requirePretransferCaller(msg.sender)` from line 109 to immediately before the credit read, still only when `pretransferred` is true."
- **Kimi (F1):** "Insert `LocalCreditLib.requirePretransferCaller(msg.sender);` as the first statement inside the existing `pretransferred`/`prepaid` guard, before the `_pretransferCredit` call."
- **MiniMax M3 first pass (F5):** "Insert `LocalCreditLib.requirePretransferCaller(msg.sender);` immediately before line 102; keep the existing `LocalCreditLib.requirePretransferCaller(msg.sender);` call on line 109 (now redundant but harmless)."

**Resolution.**

Astra and Grok propose a relocate: move the existing caller check from line 109 to immediately before line 102. The relocate produces a single caller check, no redundancy. Kimi and my first pass propose an add: insert a new caller check before line 102 and keep the existing one on line 109.

The PRD requires "no implementer choice" and the implementer must do exactly one thing. Both approaches satisfy the source-order invariant, but they differ on the final shape of the code. The relocate is cleaner (one call, no redundant statement) and matches the existing project style; the add is more conservative (the original line-109 statement is not touched). The PRD's non-goals do not favor either, but the application PRD's REQ-C06 acceptance criteria do not forbid the relocate. The application PRD does not require the existing line-109 call to remain at line 109.

The implementation choice should be the relocate (Astra/Grok) because it leaves a single, non-redundant caller check in the function and matches the source-order invariant the PRD requires. The fix direction closes: the line-109 caller check is removed and a new caller check is inserted at the top of the `pretransferred` guard immediately before the credit read. The credit comparison on line 110 stays.

### 2.6 Cited-and-left-alone site count and the in-scope "10 already-correct" call sites — RESOLVED, consensus

All four reviews agree on the 10 already-correct sites. The exact line ranges cited differ by reviewer (e.g., the V3 OutMulti line 39-40 is named by all four; the Aerodrome V1 three sites 290-291, 396-397, 488-489 are named by all four; the V4 hookless and Pons OutExecutionDelegate and OutMultiTarget sites are named by all four). The set of cited-correct sites is consensus.

### 2.7 Scope qualification for the search instruction — RESOLVED, the search must be exhaustive

The application PRD's REQ-C06 search instruction is broad: "Search active production pretransfer paths for the same early credit revert." The PRD does not limit the search to the three named families. The implementer must search the entire `contracts/` tree for `_pretransferCredit` call sites and apply the same source-order invariant.

Astra's exhaustive inventory (44 occurrences across 26 files, 34 calls, 10 definitions) matches the production grep I ran in my first pass. The implementer can reproduce this by running `grep -rn "_pretransferCredit" contracts/ --include="*.sol"` and inspecting the same files. The PRD's closed list is not the three families it names; it is every site that satisfies the criterion.

---

## 3. Closed site list (the position the PRD must use)

The PRD's REQ-C06 acceptance criterion 1, read literally, covers every prepaid branch that measures credit before authentication. The fix set is:

| Family | File | Lines (call site) | Defect class |
|---|---|---|---|
| V4 FullSpread hookless | `UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol` | 94 (`_executeZapInMintExactOut`), 165 (`_executeDirectOut`) | consuming plan |
| V4 FullSpread Pons-family | `UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol` | 94 (`_executeZapInMintExactOut`), 165 (`_executeDirectOut`) | consuming plan |
| V3 FullSpread | `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol` | 102 (`executeZapInMintExactOut`) | consuming plan |
| Rocket Pool | `RocketPoolRETHStandardExchangeOutTarget.sol` | 60 (asset→SE mint), 82 (asset→asset) | mint consumes; asset-to-asset is bare measurement |
| Lido | `LidoWstETHStandardExchangeOutTarget.sol` | 64 (asset→SE mint), 85 (asset→asset) | mint consumes; asset-to-asset is bare measurement |
| EtherFi | `EtherFiWeETHStandardExchangeOutTarget.sol` | 61 (asset→SE mint), 84 (asset→asset) | recorded, **excluded from repair** per application PRD line 178 |
| Uniswap V2 | `UniswapV2StandardExchangeOutTarget.sol` | 462, 547, 623, 693, 794, 905, 972 | bare measurement (literal criterion 1) |
| Camelot V2 | `CamelotV2StandardExchangeOutTarget.sol` | 411, 513, 596, 663, 766 | bare measurement (literal criterion 1) |
| Slipstream | `SlipstreamStandardExchangeOutTarget.sol` | 85 | recorded, **deprecated**, not repaired per application PRD non-goal |

The cited-and-left-alone set (no edits) is the 10 already-correct sites named in §1.

The fix direction for every entry in the first nine rows is identical: insert `if (pretransferred) { LocalCreditLib.requirePretransferCaller(msg.sender); }` (or the equivalent `if (prepaid) {...}` for the two hookless/Pons `_executeDirectOut` functions) immediately before the `_pretransferCredit` call on that line. Keep the existing credit comparison. Do not add the check on a false flag. The implementation choice for the V3 mint delegate is the relocate (Astra/Grok), not the add (Kimi/me): the line-109 caller check is removed and a new caller check is inserted before line 102.

For the V3 mint delegate specifically, the relocate produces a single caller check, no redundancy. For all other sites, there is no existing inline caller check in the function being edited, so the insert is the only statement.

For the V4 FullSpread hookless and Pons `_executeDirectOut` functions, the `_requirePrepaidCredit` helper (defined at lines 139-142 of each file) keeps both its lines (caller check + credit comparison) unchanged. The new caller check at the top of the pretransfer branch is the one that places the diagnostic in the required position. The helper's internal caller check is redundant but harmless.

---

## 4. The one sentence the PRD must use to close the choice

If the coordinator agrees with the closed list above, the PRD's REQ-C06 repair-scope paragraph can be closed with the following one-sentence addition to the acceptance criteria:

> REQ-C06's source-order invariant is applied to every prepaid branch that calls `_pretransferCredit` outside the already-correct call sites named in the cited-and-left-alone table. The fix is the insert: `if (pretransferred) { LocalCreditLib.requirePretransferCaller(msg.sender); }` immediately before the `_pretransferCredit` call on each named line. The V3 mint delegate is closed by relocating the line-109 caller check to immediately before line 102. EtherFi (`EtherFiWeETHStandardExchangeOutTarget.sol:61` and `:84`) and Slipstream (`SlipstreamStandardExchangeOutTarget.sol:85`) are recorded as the same source defect and excluded from the repair scope by the application PRD's line-178 non-goal and the Slipstream deprecation non-goal, respectively.

If the implementer applies this sentence, every site where `_pretransferCredit` runs before the gate is fixed. The cited-and-left-alone set is not touched. The 10 already-correct sites are not touched. The legacy V4 tree under `contracts/protocols/dexes/uniswap/v4` is not touched.

---

## 5. Position on the coordinator's question

The coordinator asked me to agree or dissent on the closed site list.

**I agree with the broad scope (Astra + Grok + Kimi) and dissent from my own first pass.** My first pass was too narrow: I treated all bare-measurement sites as non-defects because the short-credit revert happens inside a later secure helper that checks the caller first. The literal PRD criterion 1 ("On each prepaid branch that measures credit before authentication, `requirePretransferCaller` runs before `_pretransferCredit` and before a quote or plan that consumes that credit") does not limit defects to consuming-plan sites; the "and before a quote or plan that consumes that credit" clause is an additional constraint, not a limiter. The non-goal on "input-ceiling comparison that does not consume measured credit" specifically addresses input-ceiling checks, not bare measurements.

**The closed site list is the table in §3.** The fix direction is the insert (or the relocate for the V3 mint delegate). EtherFi and Slipstream are recorded but excluded from repair scope per the application PRD's non-goals. The cited-and-left-alone set is the 10 already-correct sites named in §1.

**A later implementer can execute without further input** if the sentence in §4 is added to the PRD's acceptance criteria. The PRD will then have a closed site list, a closed fix direction (insert or relocate), and a closed scope (EtherFi and Slipstream excluded). Without §4, my first pass's narrower list would leave 14 sites unfixed and the implementer would have a scope choice.

---

## 6. Corrections to my own first pass

For traceability, the corrections I have made in this cross-review against my first pass:

- §2.1: I now classify the three staking-family mint sites (Rocket 60-65, Lido 64-70, EtherFi 61-67) as defects, where my first pass excluded them. The credit is consumed by `_reserveBeforePretransfer` and `_quoteMintAtReserve` before the gate inside `_securePull`; that is a consuming-plan defect.
- §2.2: I now classify the three staking-family asset-to-asset sites (Rocket 82-83, Lido 85-86, EtherFi 84-85) as defects, where my first pass excluded them. Under the literal PRD criterion 1, a bare measurement before authentication is a defect even when no consuming plan follows.
- §2.3: I now classify the seven Uniswap V2 and five Camelot V2 sites as defects, where my first pass excluded them. Same literal-reading justification.
- §2.4: I now record EtherFi as a finding with a line-178 carve-out, where my first pass did not name EtherFi at all.
- §2.5: I now prefer the relocate (Astra/Grok) over the add (my first pass) for the V3 mint delegate fix. The relocate produces a single, non-redundant caller check.
- §2.6 and §2.7: I now align with the consensus on the cited-and-left-alone set and the search-exhaustiveness rule.

The corrections in §2.1, §2.2, §2.3, and §2.4 are clarifications of which sites are defects per the literal PRD criterion 1. The corrections in §2.5, §2.6, and §2.7 are clarifications of the fix direction and the cited-and-left-alone set. The §3 table is the closed list; the §4 sentence is the closure.

---

## 7. Summary

- **Consensus (§1, 8 items):** the five consuming-plan sites, the V3 cited-correct site, the 10 already-correct sites, the Slipstream record, the legacy V4 carve-out, the fix-direction statement order, the input-ceiling non-goal, the Low severity and diagnostic-order impact class.
- **Material disagreements (§2, 7 items):** staking mint sites, staking asset-to-asset sites, V2 and Camelot sites, EtherFi scope, V3 mint delegate fix direction (relocate vs. add), cited-correct set, search-exhaustiveness rule. All seven resolved in favor of the broad scope (Astra + Grok + Kimi on the consuming-plan sites; the literal PRD reading on the bare-measurement sites).
- **Position on the coordinator's question:** the PRD can be written with no search or scope choice for the implementer if the §4 sentence is added. Without it, the implementer has a scope choice on the V2, Camelot, Rocket, Lido sites. The closed list is the §3 table.
- **Disagreement with my own first pass:** §6 records the six corrections. The most material is the broad-scope reading of the PRD's literal criterion 1; my first pass was too narrow.

I did not run Forge.