# Astra — Combined open-items cross-review

**Date:** 2026-09-27. Read all three complete unchanged originals together as untrusted evidence. No cross-review artifact read. My original remains unchanged. Direct source checks only; no shell, builds, tests, code/config changes, deletion or delegation.

## Conclusion

Retain my original conclusion, shared substantially with Grok: **no unconditional policy question needs an owner answer before implementation planning proceeds**. The critical-path deliverable is the source-backed §6.4 formula/route matrix. Production runtime equivalence is a parallel verification gate, not an unresolved hook-address choice. Actual audit-submission readiness later needs a recorded determination before legacy removal.

Kimi's proposed hookless-fee question does not block this plan: reject structurally impossible/malformed hookless keys under existing rules, and handle core-valid but infeasible operations through the specified route-domain/protection behavior. A new blanket 100%-fee deployment ban would be an optional new policy—not a necessary unresolved requirement.

Here **Z** is `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md`; **C/** is `lib/crane/contracts/protocols/dexes/uniswap/v4/`; **U/** is `contracts/vaults/standard/exchange/protocols/uniswap/`.

## 1. Hookless fee validation: separate structural rules from optional restrictions

**Direct evidence:** `C/libraries/Hooks.sol:124–128` rejects a dynamic key with a zero hook. `C/libraries/LPFeeLibrary.sol:15–56` defines the dynamic sentinel as exactly `0x800000`, static validity as `fee <= 1_000_000`, and initialization validation of non-dynamic fee encodings. Malformed mixed/override-bit keys do not become valid by masking away bits.

Z:371 mandates a zero hook; Z:381 retains deterministic structural PoolKey validation. Implementing those canonical checks does **not** require a new owner decision to ban an otherwise supported dynamic hookless pool: such a pool is not valid on the selected manager. This is narrower than declaring an earlier unapproved static-only policy inherited for every family, as MiniMax suggests.

**100% is different:** static 1,000,000 pips is core-valid. The core exact-output path rejects the 100% effective-fee case (`C/libraries/Pool.sol:315–320`), and productive hookless composition cannot assume positive post-fee input there. The applicable route must reject when its formula/funding/protection conditions fail (Z:218,264). This need not disable unrelated funded sleeve or withdrawal operations, nor require banning the vault at deployment.

Thus I disagree with Kimi A1 as a residual mandatory policy gap. If someone wants a blanket admission ban, ask for that additional scope explicitly; do not make it a planning prerequisite. “Every valid static fee is mathematically supported” is also too broad: core-valid encoding is not proof a particular operation is executable.

Context7 `/uniswap/v4-core` was queried for these fee APIs; direct local sources establish the specific checks. No newly adopted fee policy is inferred from researcher agreement.

## 2. LiquidityAmounts is not proof of a combined closed form

MiniMax's §3.4/MIR-1 inference overreaches. `C/libraries/LiquidityAmounts.sol:48–77` computes maximum liquidity from **already supplied** token budgets, price and range. It does not derive the preceding swap, terminal price, fee recovery, attributed budgets, required removal or holder-composition repair. It does not certify that both final thresholds pass or that a proposed partial repair is useful after costs.

A placement helper may be a valid subexpression in a fully specified combined closed-form transition, including a justified no-trade/placement-only case. Its existence alone does not establish that transition. Z:214,218–233 requires actual route semantics, fees, rounding and supported-domain evidence. Neither “all vanilla combinations are supported” nor “none can exist” follows.

Likewise, naming `UniswapV4Quoter.quoteExactOutput` does not alone establish eligibility for every exact-output branch or its maintenance. A forward `_singleExit` formula maps shares to assets; that is not the exact-output inverse.

Kimi's inventory labels the ConstProdUtils group as closed-form too broadly. Directly inspected in my first pass:

- `lib/crane/contracts/utils/math/ConstProdUtils.sol:619–652`: target-LP zap-in includes expansion/bisection/safety steps.
- The same file :801–832: target-output zap-out uses a quadratic guess followed by bisection and an increment loop.
- `U/StandardExchangeConstantProduct.sol:113–128`: single-exit inverse is bisection.
- Its :78–95 input inverse is algebraic for its stated invariant-growth route, not automatically for idle external composition.

Correct the matrix classification; do not automatically reject a broader route before finishing the designated-source inventory.

### Additional source correction: prepaid credit is not an established PRD contradiction

MiniMax calls subtraction of prepaid credit an erroneous scaling requiring rederivation. `U/v4/UniswapV4FullSpreadStandardExchangeVaultOutBase.sol:53–61` explicitly excludes prepaid caller assets already present in total reserves from **pre-deposit backing**. This separates caller contribution from incumbents; it does not reduce declared credit or invent a scaled delivery. No defect follows merely from this subtraction. Preserve the attribution purpose when assessing formula applicability; do not mandate the proposed fix without a demonstrated discrepancy.

## 3. Fixed address versus runtime evidence

D26 fixes the expected hook address through `ROBINHOOD_MAIN.PONS_V2_MEME_HOOK`. **It does not supply a codehash pin.** MiniMax's claims that D26 fixes both address and codehash are incorrect. Z:365 explicitly says the source path does not prove deployed equivalence; Z:475 requires source/runtime identity evidence.

Compare the deployed **hook runtime** at that fixed address with the corresponding hook reference/build, including compiler settings and immutable substitutions. Do not compare a generated **vault package's** bytecode with the hook's bytecode, as MiniMax V-1 proposes. Verify the hook's manager binding and relevant state/behavior separately. A current `memeHook()` address observation resolves identity selection, not source equivalence or security.

No policy choice is implied by `info[0]`: it is the launch registration boolean, not a version field. The current PRD does not establish a contrary version-sentinel requirement. If runtime behavior differs materially, stop the affected readiness claim and escalate the concrete mismatch; do not silently pick another hook or model.

## 4. Diagnostics, candidate adoption and execution evidence

Kimi reports an editor stack-too-deep diagnostic and a WIP candidate/parity test. This review has not run or independently established a build failure. An editor diagnostic can motivate checking the compilation unit; it is **not executed build evidence**, a reproducible final compiler result or proof the production release is blocked.

No candidate is adopted merely because a file exists. The PRD explicitly prioritizes existing applicable sources over speculative candidate searches (Z:209–214,233). Do not make repairing, completing or proving an unadopted candidate a prerequisite. If engineering selects a helper for an actual matrix entry, then its integer semantics and production-path integration become mandatory verification work.

Current direct directory reads show both required family directories **exist and are empty**. This corrects the current-state description of “absent” in Grok/MiniMax; differing read times may explain the discrepancy. Empty directories establish neither replacement implementation nor test readiness.

My original deliberately made no candidate adoption, compile result or new-tree completion claim. I retain that evidence boundary. I did not exhaustively inventory all formula sources, so my examples remain starting observations, not final eligibility decisions.

## 5. Prioritized remaining work and human checkpoint

1. **Route/formula matrix:** both families × token/share directions × modes × interaction states. Identify source/helpers, actual execution semantics, integer/fee domains, combined maintenance status, D19 exception eligibility, previews/availability and early `InvalidRoute`. Do not omit Multi/SY/consumer surfaces or broaden the exception beyond loss of both modes of the same route.
2. **Numerical/accounting specification:** post-swap incumbent backing, caller versus holder budgets, LP/protocol/hook fees, residuals, full sync; overflow-safe fixed protection checks, solver work bounds and exact normalized progress ordering. The policy values/targets are not open.
3. **Separate family/component manifest:** exact D22 names/paths, no family dispatcher, permitted genuinely generic reuse, dependencies/immutables, selector coverage, package/factory identities and occupied-address checks. Sharing a family LiquidReserve or PositionImport component is not automatically generic just because its name sounds reusable; inspect its dependencies.
4. **Parallel production evidence:** fixed-address source/runtime equivalence, manager binding, launch-state model and honest separation from hermetic tests. Contrary to MiniMax's wording, the user did not declare this a prerequisite to *all* planning; source inventory can proceed now.
5. **Executed validation and removal evidence:** implement/test both replacements, then record audit-submission readiness. Only afterward perform the exact inventoried legacy removal, preserve historical provenance/regressions, refresh runtime artifacts and rerun replacement/consumer suites against the final revision (Z:85–95,476–477). Readiness is not audit completion or production-deployment authorization.
6. **Documentation reconciliation:** update maintained conflicting guidance under the stated authorization; historical source hashes/reports remain dated evidence, not records to rewrite into the replacement source identity. D24 does not authorize blind parent-directory deletion.

**Human checkpoint:** review the decision-complete plan and, later, record the §3.1 readiness determination before removal. Ask a new policy question only for a concrete verified conflict that cannot satisfy current law without changing a requirement. No unconditional new policy questionnaire is needed now.

## Agreements, dissent and confidence

Agree with all three on substantial policy closure, separate families, fixed binding/protections and the need for source/route/consumer verification. Agree most closely with Grok's no-new-policy verdict and Kimi's route-matrix critical path/readiness checkpoint. Dissent from Kimi's mandatory fee-admission question, MiniMax's combined-form inference, codehash claim, prepaid-credit defect and implication that verification is already sufficient to mark routes supported.

**Confidence:** high on these corrections and classification; incomplete on exhaustive formula applicability, deployed-runtime equivalence and practical build/gas results. No security, economic-soundness or mathematical-nonexistence claim. No peer cross-review read; original preserved unchanged.
