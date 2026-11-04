# Astra independent review

## Identity

- Council: `se-fullspread-blockers-review-20261102`
- Member: astra
- Profile: review
- Phase: initial independent response
- Requested role: council-member
- Requested model: `chatgpt-subscription/gpt-6-astra:high`
- Runtime role, model, provider, reasoning setting, and task identity: not exposed as independently identified runtime metadata.
- Peers read before submission: no.

## Question and disposition

**Requested changes.** The blockers file settles most of the earlier owner questions, but it is not yet an unambiguous source for the comprehensive PRD rewrite. In particular, optional share scaling changes observable balances; the donation rules select different operations for the same inventory; and the reserve-view and pretransfer rules leave consequential accounting branches unspecified. These are problems within the proposed replacement requirements, not objections to changing the older PRD.

The file can support a rewrite after the conflicts and missing branch definitions below are resolved. This review does not authorize implementation or a PRD edit.

## Evidence and scope

Read the entire 399-line target:

`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md`

Also read the two admitted context documents:

- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`
- `docs/vaults/PRETRANSFER_DIRECTIVE.md`

Below, `BLOCKERS:L` identifies line L of the full target path above. Section names identify the corresponding requirements when lines move.

The blockers file is the later authority. I did not classify the sleeve removal, fee clamp, fee netting, donation authorization, reserve exclusion, or removal of view reverts as defects merely because the PRD still says something else. I did not inspect contract implementations, external reports, audits, or peer submissions. Findings concern the text's observable contracts; they are not reproduced implementation failures.

## Review findings

### R1. High: optional share scaling conflicts with the fixed raw-share issuance rule

**Location:** `BLOCKERS:214-230`, B-10, especially line 228; the fixed floor and repeated raw-share formulas under "Already locked" at lines 377 and 386.

**Observation:** B-10 says genesis shares are raw added liquidity minus 1,000. It then permits a scale on stored share balances, including the floor, without selecting a scale or requiring one.

**Why readers diverge:** With 10,000 added liquidity before the usage fee, one implementation records 9,000 depositor shares and 1,000 floor shares. An implementation choosing a share-side multiplier k records 9,000k and 1,000k. The multiplier can cancel in proportional liquidity calculations while still changing `balanceOf`, `totalSupply`, transfers, raw preview outputs, and the amount represented by one displayed share. That is not merely internal arithmetic organization. It also changes the literal 1,000-share floor.

**Fix direction, advice only:** Select one externally observable share unit and floor amount. If raw units are intended, remove the optional stored-balance scaling permission. If normalization is intended, specify its exact factor and update every affected genesis, floor, preview, fee, mint, and burn requirement together. Do not leave that selection to an implementor.

### R2. High: the donation-specific rule and combined-balance rule choose different swaps

**Location:** `BLOCKERS:128-138`, B-05; `BLOCKERS:250-260`, Donation and compound booking.

**Observation:** B-05 says an underlying donation swaps its own tokens, spends donated tokens only, and does not take holders' opposite tokens. The later booking lock says `donate()` also compounds, combines fees, donations, and booked balances, swaps a one-token combined balance, and does not swap a both-token combined balance.

**Why readers diverge:** Donate token0 while a token1 remainder is already booked. A reader implementing B-05 literally swaps the token0 gift before adding liquidity. A reader implementing the combined-balance lock makes no swap and deposits the gift with the holder-owned token1 remainder. Likewise, a token0 gift plus token0 fees can produce a swap spending only the gift or a swap spending the combined balance. The later text explicitly replaces the old refund rule, but does not explicitly retire B-05's separate swap-input restriction.

Share donation creates another branch of this same ambiguity. B-05 says it burns shares and does not run the swap; the unqualified "`donate()` also compounds" could cause a share donation to trigger a swap of existing fees or a booked one-token remainder. The share burn itself and maintenance of the underlying inventory need distinct instructions.

**Fix direction, advice only:** State which donation branches enter combined-balance processing and the exact scope of the no-swap sentence for share donation. Express the underlying branch using one authoritative inventory definition, explicitly superseding the gift-only swap rule if the combined-balance lock is intended to govern. Preserve the no-position-swap and no-share-mint rules.

### R3. High: the retained local reserve term has no defined included balance after the sleeve removal

**Location:** `BLOCKERS:152`, B-06; `BLOCKERS:254-258`, Donation and compound booking; the repeated exclusions at `BLOCKERS:387`.

**Observation:** B-06 preserves a last-committed local reserve term and a live deployed term. The booking lock excludes booked remainder and uncollected fees from `reserves()`. B-13 excludes unbooked balances. The sleeve is gone.

**Why readers diverge:** One reader can retain the old snapshot-based local-reserve addition and populate that snapshot with the newly booked held balance. Another can make the eligible local reserve term zero and use only deployed principal. Those implementations return different reserves for the same booked inventory. The later exclusion is clear, but the surviving instruction to retain a local term does not say what, if anything, is eligible for that term.

The exclusion is written explicitly for `reserves()`, while the inherited `reserveOfToken` contract describes the corresponding per-token sum. A rewrite should not leave the two views to be reconciled independently.

**Fix direction, advice only:** Define the included reserve inventory once and apply it explicitly to both selectors. State whether the local term is always zero under the new model, or name its remaining eligible inventory and snapshot update points. Keep booked remainder and uncollected fees excluded as locked; this finding does not recommend restoring them to issuance or reserve valuation.

### R4. High: a declared pretransfer maximum can exceed the available unbooked balance

**Location:** `BLOCKERS:282` and `BLOCKERS:392`, B-13 and its repeated lock; contextual pretransfer directive, maximum/refund paragraphs.

**Observation:** The call uses unbooked held balance "up to" the caller's maximum, excludes booked balances, and refunds maximum minus used. Neither admitted statement defines what happens when the declared maximum exceeds the unbooked held balance.

**Why readers diverge:** Suppose the declared maximum is 100, unbooked held input is 60, and booked input is 100. If execution uses 40, the specified refund is 60. Spending 40 and refunding 60 consumes 100 although only 60 was available to this call. One implementation rejects the declaration before execution; another clips executable input to available unbooked funds but retains the stated refund formula, potentially spending booked funds; a third silently clips the refund. Those are materially different contracts.

This is separate from authenticating the original sender of a transfer. It does not challenge the accepted non-atomic pretransfer risk or request sender attribution.

**Fix direction, advice only:** Specify the backing condition for the declared maximum and the failure behavior when it is unmet. Requiring the whole declared maximum to be available as unbooked input before execution would preserve the locked refund formula; adopting a different funded-maximum concept would need an explicit owner decision rather than an implicit clip. Apply the chosen rule consistently to each pretransferred input route.

### R5. Medium: exact exhaustion of the scarcer token is not reconciled with best-effort residual booking

**Location:** `BLOCKERS:242`, B-11; `BLOCKERS:252-254`, Donation and compound booking.

**Observation:** The both-token branch says the scarcer token is fully used and only the other token's excess is booked. The surrounding rule instead says to make a best-effort deposit, book actual held balances, and not revert merely because a remainder remains.

**Why readers diverge:** The text does not specify how to handle integer dust in both tokens or a positive combined balance that produces no addable liquidity. A literal exhaustion implementation can require a zero scarcer-token remainder; a best-effort implementation can retain dust in both tokens. The former can reject a state the latter accepts. The document expressly raises undeployable fees, so this boundary belongs in the contract rather than being left to an assumed conversion behavior.

**Fix direction, advice only:** Clarify whether "fully used" describes the ideal ratio or an exact postcondition. Define the rounded zero-liquidity outcome and permitted residual token set while preserving actual-held-balance booking and the no-revert-merely-for-remainder rule. Do not add a minimum donation, swap cap, or tick bound to resolve this wording.

### R6. Medium: `Compounded()` has a signature but not a complete emission predicate

**Location:** `BLOCKERS:234-244`, B-11; `BLOCKERS:250-258`, Donation and compound booking.

**Observation:** Emit `Compounded()` "when fees are compounded." The event is also described as distinguishing compounding from caller activity. But maintenance can now process donation-only inventory, booked remainder without new fees, or fees that remain entirely undeployed.

**Why readers diverge:** One implementation emits on every nonempty maintenance call; another emits only when freshly collected fees become liquidity; a third emits whenever liquidity grows, including donation-only growth. All can plausibly follow part of B-11. The no-input/no-event case does not decide these other branches. A `donate()` that also processes fees further blurs the claimed distinction between caller activity and fee compounding.

**Fix direction, advice only:** Give an emission table for `compound()` and each `donate` branch, covering new fees, only booked remainder, only donation, zero added liquidity, and the empty no-op. Specify the number of markers per call. Keep the locked zero-argument signature and reliance on PoolManager logs; no additional event fields are proposed.

### R7. Medium: the batch-swap exclusion has no operational boundary

**Location:** `BLOCKERS:88`, B-02; `BLOCKERS:208`, B-09; `BLOCKERS:342-360`, Matrix files.

**Observation:** The owner accepts that the vault cannot be included in a batch swap with other V4 pools, while expressly retaining borrowed unlock and FS-HOOK-02.

**Why readers diverge:** The text says these are not intended to revoke one another, so it is not correct to discard the hook rows. However, it does not define which execution structure counts as the forbidden batch. A reader could exclude every outer unlock containing work on another pool, while another excludes only a particular router batch form and retains the required cross-vault fixture. The retained PRD fixture describes multiple backing pool keys and hook-composed execution, so this distinction matters to both acceptance and supported-route documentation.

**Fix direction, advice only:** Identify the excluded composition by its call topology or named route, and contrast it with the retained borrowed-unlock fixture. State whether the exclusion is a supported-surface limitation, a required rejection, or an acknowledged integration limitation. Do not infer revocation of FS-HOOK-02 or introduce an allowlist.

### R8. Medium: the new reusable facets are not yet a single public ABI and package schema

**Location:** `BLOCKERS:156-182`, B-07.

**Observation:** B-07 locks the seven infrastructure components, a Protocol Aware facet, the position Repo/Facet pair, per-instance position identity, and `positionLiquidity()` semantics. It does not enumerate the complete getter signatures and return layouts or the final named package fields and binding order for the new inputs.

**Why readers diverge:** Two implementations can expose the same seven addresses with different getter names. They can expose position salt through different selectors, or disagree whether a separate salt getter is required by "its getters are externally callable." They can also serialize different package structures while each takes both facets and all required addresses. Those are public selector and deployment ABI differences, not the permitted choice of internal storage organization.

The older PRD supplies some position getter names and an older package order, but B-07 replaces that incomplete input model without providing a complete replacement manifest.

**Fix direction, advice only:** Attach or identify one authoritative getter/interface manifest and one complete package input schema, including types, ordering, and the initialization source of each address and position field. If an existing canonical interface supplies the details, cite that exact contract rather than choosing fresh names. This review did not inspect source outside the admitted files and does not invent the missing selectors.

### R9. Medium: quote-failure language still permits two interpretations of the no-view-revert lock

**Location:** `BLOCKERS:144-154`, B-06; `BLOCKERS:320`, N-04.

**Observation:** B-06 forbids coded view reverts and expressly distinguishes EVM out-of-gas failure. N-04 still says, without that qualification, "A quote that cannot finish reverts."

**Why readers diverge:** One reader can treat N-04 as permission for a deliberate quote-failure revert or propagated planner failure. Another can treat the only permitted failure as unavoidable EVM exhaustion. Both reject an invented 64-step cap, but expose different preview behavior when a chosen quote mechanism fails for another reason.

**Fix direction, advice only:** Qualify N-04 with the exact B-06 failure boundary and define whether/how lower-level quote failures are exposed. If N-04 means only unavoidable EVM exhaustion, say that explicitly. Do not reintroduce a step-cap error, fallback partial fill, or minimum tick spacing. The freedom to choose an implementation algorithm is not itself a defect; inconsistent observable failure behavior is.

### R10. Low: retained summaries and matrix instructions overgeneralize rules that now have explicit exceptions

**Locations and divergence:**

- **`BLOCKERS:110`, B-03:** "a no-fee `compound()` returns unchanged" omits the locked booked-remainder exception in the same section. A reader copying that answer rather than the decision line would skip remainder-only processing.
- **`BLOCKERS:310`, N-03:** The explanation names only harvested-fee compounding and ends with pool swaps for `exchangeIn` "only." It does not incorporate the now-authorized donation and booked-remainder swaps. Copied as a general restriction, it contradicts the later maintenance inventory rule.
- **`BLOCKERS:356`, Matrix files:** "Booked-remainder rows cannot pass here" is unqualified. Refunded unused user input must not become a booked remainder, but maintenance leftovers and withdrawal-collected fees must be booked. One test author can exclude all remainder assertions while another excludes only user-entry remainder rows.
- **`BLOCKERS:371`, audit table, APEX-2026-039:** The expected result still "waits on attribution," although B-13 is marked locked. The row does not distinguish the adopted attribution policy from any remaining completeness issue such as R4.

**Fix direction, advice only:** Synchronize these summaries with the actual locked branches. Distinguish user-entry refunds from maintenance/withdrawal booking in the matrix. Mark the adopted 039 attribution expectation as adopted, while tracking any remaining specification defect separately. These are copy-through corrections, not grounds to reopen the owner decisions.

## Coverage

| Item | Reviewed disposition |
| --- | --- |
| B-01 | Netting, net previews/minima, floor exclusion, no fee-on-fee, vault-only 30% clamp, WAD precision, and zero-fee behavior are mutually intelligible. No independent defect found. Its genesis gross-share input must use the final unit chosen under R1. |
| B-02 | Sleeve removal, restricted maintenance, unbounded entry/exit limits, withdrawn-net-only redemption, and accepted maintenance exposure are clear. Combined inventory and composition boundaries need R2 and R7. No recommendation to add a price guard or revoke the accepted exposure. |
| B-03 | Decision line correctly includes the booked-remainder exception. The concluding summary needs R10. |
| B-04 | The stated no-zero-liquidity argument is coherent with a positive genesis position and an unredeemable floor. This is textual consistency, not an independently tested reachability proof. No alternate denominator proposed. |
| B-05 | Authorization, zero-supply rejection, share burn without withdrawal, and no mint are clear. Donation swap inventory and share-donation maintenance need R2. |
| B-06 | Unsupported-route zero views and execution rejection are clear. Reserve composition needs R3; failure boundary needs R9. |
| B-07 | Package-bound infrastructure, instance-bound position identity, direct diamond ownership, salt zero, Crane ownership/tests, and removal of local-reserve getter are clear. Public ABI/package completeness needs R8. |
| B-08 | External provider per configured vault/target, no provider address stored by the vault, no vault rate, no enforced provider-count cap, and tuple migration obligation are clear. No independent defect found. Consumer enumeration is explicitly deferred to the comprehensive PRD pass, not silently omitted here. |
| B-09 | Borrowed unlock uses direct operations, no nested unlock, no sleeve fallback, and settlement of the vault's own deltas. No independent contradiction found. I do not treat its explanatory manager-success sentence as overriding ordinary route, authority, or settlement failures. |
| B-10 | Raw-liquidity formulas and exclusion of token-decimal scaling are clear, but optional stored-share scaling prevents a unique observable unit. R1. |
| B-11 | Zero-argument event and empty no-op are clear. Emission branches and undeployable/dust behavior need R5 and R6. |
| Donation and compound booking | Actual-held-balance booking, stray-transfer inclusion, principal-only withdrawal payout, fee booking, no entry/exit deployment of remainders, and exclusion of undeployed value are explicit. R2, R3, R5, and R6 address the remaining branch conflicts. The non-atomic stray-transfer risk is accepted, not reported as a new defect. |
| B-12 | Event names and sole indexed caller argument are fully specified. No independent defect found. |
| B-13 | No origin tracing, caller maximum, exclusion of booked funds, limited refund, no-bytecode rejection, and caller-owned burn are clear. Insufficient unbooked backing needs R4. |
| N-01 | Address-zero floor through the stated mint path is a resolved textual choice. Source behavior was not independently verified; no holder change proposed. |
| N-02 | Floor exclusion and no fee-on-fee agree with B-01. No independent defect found. |
| N-03 | Sleeve-adjustment swap is correctly absent. Its residual swap summary needs R10. |
| N-04 | No invented cap, spacing restriction, or partial fill. Algorithm selection alone can remain an implementation matter, but its failure behavior must satisfy R9. No source-based quoter recommendation made. |
| N-05 | WETH-only caller boundary and equality to the network constant are fixed. Storage home is an expressly permitted internal choice, not a defect. If the optional package field is retained, the final package schema in R8 must make that public ABI choice explicit. |
| N-06 | Assignment of already specified operations between the named libraries is an expressly allowed code-organization choice, not a missing economic requirement. |
| N-07 | Liquidity-only issuance remains closed. No request to reopen it or add booked assets to the denominator. |
| Matrix files | All seven listed behavior contracts, family-only adaptations, preserved V3 rows, and replacement of stale V4 evidence are accounted for. R7 and R10 affect the expected full-spread rows. Existing evidence is not treated as a pass. |
| Audit-test section | 044 netting, 023 partial acceptance, 024 withdrawn quantity, 039 attribution, and 048 remainder/no-op expectations were checked against the locks. R4 and R10 concern 039; R5/R6 clarify maintenance edge behavior. The external 45-ID disposition was not admitted or independently verified. |
| Already-locked summary | Read every bullet and cross-checked it against the corresponding section. It largely repeats the operative decisions; it does not cure R1-R10. |
| How to use / plan scope | Integration-matrix extension, integration tests, and regression coverage remain required. The accepted 023 exposure must not be tested as absent. Comprehensive rewrite and preview-consumer enumeration remain later authorized work, not actions taken by this response. |

## Conclusions

The review does not require restoring the sleeve, changing liquidity-only issuance, withdrawing the 30% clamp, reintroducing a vault rate, or adding swap protection. Most locks can be preserved verbatim in substance.

The blockers are not yet safe to copy as one coherent requirement set. Resolve the observable choices in R1-R9 and synchronize the narrow summaries in R10 before the comprehensive rewrite. Internal choices expressly left open in N-05 and N-06 need not become owner-designed implementation details; public ABI and accounting behavior do.

## Limits

This is an independent document review, not a security clearance or an implementation audit. No peers were read. No sub-agents, Forge, tests, installs, Git, or external research were used. Only the assigned `members/astra/response.md` was written.

No contract behavior, gas bound, current hook compatibility, source mint path, or external audit disposition was independently executed or verified. The numeric examples demonstrate specification divergence, not an observed exploit.

This response does not authorize implementation or a PRD edit.
