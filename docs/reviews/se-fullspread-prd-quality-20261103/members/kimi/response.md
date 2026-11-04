# Identity

- Member: `kimi`
- Profile: `review`
- Phase: `initial independent response`
- Requested role: `council-member`
- Requested model: `kimi-coding/k3.1-pro:high`, global route
- Owned path: `members/kimi/response.md`
- Runtime identity beyond the assignment: not exposed
- Peers read before submission: no

# Question and targets

Does the rewritten full-spread PRD say each locked requirement clearly enough that two implementors would copy it the same way?

Required target, read in full:

- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`

Controlling clarity references, also read in full:

- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md`, with the 2026-11-03 overrides taking precedence over earlier sentences.
- `docs/vaults/PRETRANSFER_DIRECTIVE.md` for every call taking `pretransferred`.

# Evidence

I read all 644 lines of the PRD, all 413 lines of the blocker file, and all 16 lines of the pretransfer directive. The findings below compare the PRD's operative sentences and acceptance rows with those locks. In particular, the 2026-11-03 F1, F2, F5, F6, F7, and F12 overrides were treated as controlling over conflicting earlier text. No peer response, production source, test source, or other document was used as review evidence.

# Assumptions

- A sentence explicitly scoped by its surrounding lock is read in that scope; an unqualified sentence that broadens the scope is a clarity defect when another lock narrows it.
- The B-06 rule that no view has a coded vault-error revert applies to the preview functions as well as reserve queries.
- The pretransfer directive applies independently to every declared input token unless the PRD clearly states a different whole-call rule.
- This is a clarity review, not a security, economic, or implementation-correctness review.

# Coverage

The review covered the delta table; FS-OWN-01 through FS-OWN-33; precedence and retained dispositions; facets, files, package initialization, and validation; money rules and both unlock paths; quote and external rate-provider rules; hook integration; all FS-A acceptance rows; audit-absence rows; and non-goals. It specifically checked fee netting and the 30% clamp, raw-liquidity share units, genesis issuance, accrued-fee and booked-balance apportioning, maintenance authorization and events, external rate providers, Crane protocol/position reads, WETH boundaries, quote-cap prohibitions, and hook fixtures. Apart from the findings below, I found no remaining contradiction with the controlling locks in those areas.

# Review findings

## 1. FS-OWN-13 broadens borrowed-unlock execution beyond `exchangeIn`

- **Location:** PRD line 164, FS-OWN-13. Compare PRD lines 30, 268, 438, and 573.
- **Requirement that failed:** FS-X01 and FS-UNLOCK-01 permit the already-unlocked path only for canonical `exchangeIn`; bundle routes, `donate`, and `compound` must revert `ManagerAlreadyUnlocked`.
- **Defect:** FS-OWN-13 instead says generically that if another caller holds the unlock, “this vault” calls `modifyLiquidity` and `swap` directly. It does not name `exchangeIn` or the non-`exchangeIn` rejection. One implementor could apply that paragraph to every money route while another applies the explicit FS-X01 restriction.
- **Impact:** The two readings produce different manager calls, route availability, and revert behavior for bundle operations and maintenance calls.
- **Fix direction:** Qualify the FS-OWN-13 borrowed branch as the canonical `exchangeIn` branch and cross-reference the existing `ManagerAlreadyUnlocked` rule for every other route. Do not broaden the borrowed-unlock surface.

## 2. The invalid-route error paragraph conflicts with the no-view-revert lock

- **Location:** PRD line 242, FS-OWN-32, compared with lines 186 and 583. Controlling lock: blocker file lines 160-170, B-06.
- **Requirement that failed:** No view may revert by a coded vault error; an unsupported view route returns zero.
- **Defect:** Line 242 says without an execution-only qualifier that `tokenIn == tokenOut` reverts `InvalidRoute`, `amountIn == 0` reverts `EmptyExchange`, and `address(0)` reverts `TokenNotExchangeable`. Those arguments occur on both execution and preview routes. An implementor can therefore either apply these reverts to previews or honor B-06 and return an unsupported-view result.
- **Impact:** Preview behavior and hook fallback behavior diverge for the same inputs, and FS-A32 cannot be implemented consistently with a literal reading of line 242.
- **Fix direction:** Scope the named reverts explicitly to execution and state the corresponding preview behavior under B-06. Preserve the existing errors on execution rather than inventing new view errors.

## 3. The overstated-pretransfer rule changes the object of “do not spend”

- **Location:** PRD line 238, FS-OWN-32. Controlling locks: blocker file line 21, override F1, and pretransfer directive line 9.
- **Requirement that failed:** When the declared maximum exceeds the unbooked balance, refund that unbooked balance, do not spend it, and do not pull the shortfall.
- **Defect:** The PRD says “Do not spend that declared amount.” The declared amount is the maximum, not the unbooked balance that F1 forbids spending. One reading permits consuming the available balance as long as the larger declared maximum is not spent; the other requires zero consumption of that token.
- **Impact:** Consumed input, minted shares or payout, and the economic effect of the full-balance refund differ between implementations. The generic APEX-2026-039 wording on PRD line 616 does not resolve this case.
- **Fix direction:** Identify the unbooked balance itself as the amount not to spend. Add an acceptance assertion for an overstated maximum that distinguishes zero consumption and refund of the unbooked balance from consumption followed by a refund, while retaining the no-shortfall-pull rule.

## 4. Bundle pretransfer behavior is expressly left indeterminate

- **Location:** PRD line 238, especially “This sentence does not say what the other declared amounts in the same call do.” The bundle input arrays are declared on PRD lines 125-132. Binding rule: pretransfer directive lines 5-9.
- **Requirement that failed:** Calls taking `pretransferred` need a testable attribution and refund rule for every declared token input.
- **Defect:** The PRD gives a single-token overstated-maximum paragraph and then disclaims the behavior of other declared amounts in the same call. It does not say whether bundle elements are processed independently or whether one overstated element changes the whole call.
- **Impact:** Implementors can produce different liquidity, refunds, and whole-call revert behavior for a bundle containing a mixture of ordinary and overstated maxima. No acceptance row supplies the missing expected result.
- **Fix direction:** State how the directive applies to each bundle element and what happens to the other elements when one maximum exceeds its unbooked balance. Add a mixed-maxima bundle acceptance case without introducing a new error or changing the locked refund economics.

## 5. FS-OWN-31 states an exhaustive failure rule that contradicts other required failures

- **Location:** PRD line 232. Compare PRD line 224 and lines 444-451. Source lock: blocker file lines 216-228, B-09.
- **Requirement that failed:** B-09 closes only the supposedly unpullable borrowed fraction; it does not eliminate `AmountOutNotMet`, borrowed-context, funding, or settlement failures.
- **Defect:** “The call fails only if this vault's own code calls `unlock()` again, or if the hook never calls the vault” is unqualified and makes those two conditions appear exhaustive. The same PRD requires several other failure modes.
- **Impact:** An implementor could remove or misclassify required reverts, and a test author could not reconcile the exhaustive sentence with FS-OWN-30 and FS-UNLOCK-02.
- **Fix direction:** Scope the sentence to the manager's ability to pull and modify the position during an already-open unlock. Retain all separately specified route, minimum-output, funding, and settlement failures.

## 6. The package inputs do not unambiguously realize the required two-facet reserve cut

- **Location:** PRD lines 293-304 and 375, against the required selector mapping on line 63.
- **Requirement that failed:** `vaultTokens` must map to `MultiAssetBasicVaultFacet`, while `reserveOfToken` and `reserves` must map to the family custom facet; package binding order and `bindingHash` must cover the selected facets.
- **Defect:** Line 293 calls `basicVaultFacet` the custom implementation, while line 304 requires both that custom facet and the shared `MultiAssetBasicVaultFacet`. The `PkgInit` ordering paragraph does not identify how those two distinct facet addresses enter the package fields and cuts.
- **Impact:** Implementors can choose different package structs, facet cuts, binding order, and consequently different `bindingHash` values, or omit one of the required selector mappings.
- **Fix direction:** Identify the distinct package inputs and binding-order positions for the shared `vaultTokens` facet and the custom reserve facet, while preserving the selector mapping already locked by FS-OWN-07.

# Limits

This response is advisory only. It neither replaces the PRD or locks nor authorizes implementation or edits. I did not inspect the referenced ABI report, consumer inventory, production code, tests, or peer responses, and I make no claim about their contents. I ran no compiler, tests, deployment, wallet, install, search, or Git operation. Runtime provider and execution internals beyond the requested model route were not exposed.
