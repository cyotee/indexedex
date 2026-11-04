# Astra planning advisory: coordinator archival receipt

Verbatim final response from Native task `st_01a18421`, advisory epoch 1, on frozen r1.

---

## Identity

**Astra — independent Native council planning member**

Original route retained: `chatgpt-subscription/gpt-6-astra:high`. Provider/model identity was exposed in the earlier Native metadata; I did not perform a new identity probe during this restricted review.

This is my single advisory pass. It does not replace my original contribution and does not authorize implementation.

## Draft under review

- Revision: `pairtoken-se-stage-one-plan-20261028-01a1810f-r1`
- File: `docs/research/pairtoken-se-stage-one-plan-20261028-01a1810f/coordinator/draft.md`
- Coordinator-supplied SHA-256: `e586652849499d117b97c01882e66651777a3cbf3a50a5cd2750ea4c01660737`

I read the complete draft through the end of section 9. The hash is supplied provenance, not my independent attestation.

## Disposition

**SUPPORT WITH CORRECTIONS**

The draft fairly represents the substance of my original contribution. It preserves caller-attributed issuance, explicit fee checkpoints, conditional rather than exception-driven fallback, native custody isolation, exact multiword valuation, the 60-selector composition, and production-first acceptance.

Its revised work order is reasonable: component validation precedes complete registered-proxy acceptance, without pretending that unfinished facets are working products. All A01–A70 appear individually in the matrix. The deployment gas envelope is correctly identified as unresolved release input, and no compilation, test, or feasibility result is claimed.

The following localized corrections would make the work order and validation instructions less open to incorrect implementation.

## Concerns

### 1. Correct the paired-entry sequence explicitly

**Location:** §5.3, first paragraph.  
**Priority:** High.

The sequence currently begins:

> “Paired: candidate qQuote/accepted inputs, maintenance/final fees…”

This places candidate and accepted-input calculation before maintenance without specifying that an earlier preflight calculation uses the **projected post-maintenance** reserves. Following that order literally could produce stale accepted amounts and `qQuote`.

Replace the sequence with:

> Preflight the complete operation using hypothetical caller funding and projected post-maintenance reserves. Execute incumbent maintenance and its final fee checkpoint. Validate the resulting snapshot against the plan, then use that post-maintenance snapshot for qQuote and accepted-input selection. Pull only accepted ERC-20 amounts, validate intervening state, add from caller inventory, calculate G_i/J_i and final credit, enforce the actual-share minimum, and mint/book/refund.

Retain the existing instruction not to recalculate accepted inputs after applying the final credit cap. This is a sequencing clarification, not a different issuance equation.

### 2. Make manager-delta subtraction explicitly component-wise

**Location:** §5.1, `principalDelta = callerDelta - feesAccrued`.  
**Priority:** Medium.

The algebra is correct, and the draft correctly rejects the alleged reversal of the baseline addition-cost sign. However, the implementation instruction should distinguish currency-wise arithmetic from arithmetic on the packed `BalanceDelta` representation.

Add:

> Decode each signed currency component first and widen it before subtraction or negation. Compute principalDelta_i = callerDelta_i - feesAccrued_i independently for each currency. Never subtract the packed words as ordinary integers. Validate the resulting principal, fee, net settlement, and liquidity quantities against their respective domains.

For an addition, principal is **nonpositive** per leg; an unused leg can be zero. Its cost is `feesAccrued_i - callerDelta_i`. For removal, actual principal proceeds are nonnegative.

This preserves the correct sign analysis while closing a concrete implementation hazard.

### 3. Replace the SY “round trips” acceptance wording

**Location:** §7.4, S1-A32.  
**Priority:** Medium.

“SYUtils round trips” is ambiguous and can encourage an incorrect exact-inverse assertion. Floor conversions generally do not round-trip exactly. The shared helper’s checked one-word multiplication also has a narrower operational domain than the proposed wide valuation calculation.

Replace that portion with:

> Independently assert the single-floor currency conversion, final floor(Vraw × 1e18 / S), and SYUtils.syToAsset raw-unit result within the helper’s checked-multiplication domain. Where both conversion directions are exercised, assert their individual rounding contracts rather than exact invertibility. Test representable wide-intermediate rates and genuinely overflowing final rates separately from shared-helper multiplication overflow.

This distinction was explicit in my original. It avoids either weakening the wide-rate implementation or treating a legitimate helper overflow as a vault valuation defect.

### 4. Add an executable selector/NatSpec verification gate

**Locations:** §3.1, P0/P4/P7, and §8.  
**Priority:** Medium.

The independent manifest requirement is sound, but the command section does not identify the compiled verification step that produces and checks selectors, interface IDs, and event topics. The generic build/test commands do not, by themselves, specify that work.

Restore a scoped verifier task and proposed path, for example:

`scripts/foundry/ComputePairTokenStageOneNatSpecValues.s.sol`

Require it to import actual interfaces rather than duplicating simplified declarations. Its future commands can follow the artifact-first pattern from my original:

```bash
python3 scripts/forge-artifacts.py build \
  --consumer scripts/foundry/ComputePairTokenStageOneNatSpecValues.s.sol

forge script \
  scripts/foundry/ComputePairTokenStageOneNatSpecValues.s.sol \
  --sig "run()" -vvv
```

Label the script as proposed until implemented. It must perform local verification without broadcasting.

The existing §8 commands otherwise follow credible repository patterns. This concern is a missing explicit gate, not a claim that those commands were executed or are invalid.

### 5. Define “touched” witnesses to include future planned reads

**Locations:** §6.2 and S1-A67.  
**Priority:** Medium clarification.

The draft requires witnesses for “touched ticks/words.” Specify that these include records read by the **complete projected plan**, including records needed only by later phases—not merely records already changed during execution.

Add an explicit A67 subcase:

> A token/wrapper interaction changes a bitmap word or tick record needed by a later planned swap while leaving current price unchanged. Execution must detect the changed plan assumptions and revert EconomicStateChanged before consuming that later action.

This preserves the original requirement that checking slot0, or only already-executed transitions, is insufficient. It does not require monitoring unrelated pool storage.

### Coverage and release assessment

Apart from those corrections:

- The acceptance matrix retains every ID without an apparent omission.
- The full-candidate scope of `MaintenanceWorkLimit` is correct.
- The distinction between compound’s sequential-floor comparison and SY’s single-floor valuation is correct.
- The multiword widths and late narrowing approach remain consistent with my original.
- Component tests are properly distinguished from real-proxy acceptance.
- Fallback reachability is not falsely discharged by injecting planner results.
- Runtime sizes, gas measurements, and deployment limits remain explicitly unproved.
- Exact-output error precedence and guard-first invalid-token SY previews are clearly stated.

The matrix remains a test specification, not evidence that the cases have passed.

## What was not adopted from others

I did not read other members’ contributions. I can assess the draft’s resolutions, but cannot independently confirm that its descriptions fairly characterize those originals.

As written, I support these resolutions:

- Reject narrowing work-limit fallback to exhaustion inside the maintenance swap; the complete normal withdrawal candidate is the relevant scope.
- Reject the alleged baseline principal-sign defect; the addition-cost relationship recorded in the draft is correct when applied per currency.
- Reject premature 256-bit narrowing that would exclude representable final results.
- Reject fictional helper imports, placeholder acceptance tests, duplicate selector ownership, and inferred credit for unavailable contribution text.

The draft does not adopt the economic alternatives my original excluded: unconditional collection-only withdrawals, different issuance pricing, dead shares, protocol-fee routing, or an oracle substitution.

My original’s material points that need clearer retention are the post-maintenance paired-entry ordering, the shared SY helper’s arithmetic domain, and the concrete compiled selector-verification workflow identified above.

## Limits

- I reviewed only the complete frozen draft and prior conversation context.
- I did not reopen the PRD, implementation sources, my archived original, peer contributions, memory, or other files.
- I performed no hash command, research, shell/project command, test, build, Git operation, delegation, write, or edit.
- The stated behavior of `scripts/size_oversize_facets.py` was not verified in my original inspection and remains an **unverified source claim** in this advisory. The draft’s instruction not to treat its exit code alone as proof is prudent, but the implementer must inspect the tool before relying on its behavior.
- Council archive completeness, the reported transcript elision/provider failure, and peer-attribution claims are coordinator-reported provenance, not independently verified findings.
- Source observations retained from my original are prior-context evidence, not fresh verification of the current checkout.
- This advisory establishes neither economic security nor deployment feasibility. Those require the implementation evidence and release gates specified in the plan.

This completes my single advisory pass and leaves my original contribution intact.
