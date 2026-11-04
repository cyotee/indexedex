# Astra advisory on weir-import-plan-draft-r1

## Identity

Astra, one independent advisory for council `weir-source-import-plan-20261029-01a18660`, dated 2026-10-29. Requested route remains `chatgpt-subscription/gpt-6-astra:high`. This identifies the assigned role and route; it is not a new independent runtime-route attestation.

I read the complete frozen draft and the complete Grok, Kimi, and MiniMax originals named in this assignment. I used my prior original and source-reading context without reopening source, the PRD, earlier councils, or peer feedback. My original remains unchanged.

## Draft under review

- Path: `docs/research/weir-source-import-plan-20261029-01a18660/coordinator/draft.md`
- Revision: `weir-import-plan-draft-r1`
- Coordinator-supplied SHA-256: `5515502e83176fc1423d68bea8f73af8e9bea0efa98c2bdde6bdba92993e7942`

The hash is supplied provenance. I did not recompute it. The named draft was readable; no substitute draft was reviewed.

## Disposition

**REQUEST CHANGES.**

I support the standalone import scope, the canonical dependency route, the real-manager requirement, the separation of ordinary and hostile accounting, and the blocked-not-passed archive gate. I also accept the four architectural choices specifically identified in this assignment, subject to the implementation details below. I do not require my original's larger file inventory or CREATE3 preference to be restored.

The blocking issues are narrower: the draft conditionally weakens fixed acceptance anchors, prescribes verification before its inputs exist, and leaves the difficult hook and parity constructions less complete than the available originals. All 37 WI and 69 AC identifiers are present, but that alone does not preserve their required subcases or make the work order executable.

## Concerns and exact corrections

### C1. Fixed F0-F3 assertions must not adapt to the observed SUT result

**Draft sections:** 5, "Anchors"; 6, AC09, AC21, AC30-32; 4, WP-05; 11, limits. **Requirements:** WI-04, WI-34, AC09, AC21, AC30, AC31.

The F0 row says, "If the real add delta is not K, used and refund follow the real delta." AC09 makes the share result conditional on actual liquidity; AC21 says the output holds "if the oracle amount holds." F1/F2 "become expected values only after a real donate and the independent fee formula agree."

Execution must follow actual deltas, but a fidelity test must compare those deltas against independently fixed expectations. Otherwise a changed manager charge can redefine its own expected refund and still appear accepted. An unrun gate is not a reason to make its expected value conditional on the result being tested.

**Exact correction:** replace that qualification with:

> F0-F3 are fixed acceptance vectors under their specified preconditions. Establish the independent integer expectations before executing the SUT. F0 must produce L=T=K, manager costs K per side, refunds 2 per side, and the specified assigned-share withdrawal outputs. F1 must accrue gross fees (20,0), cut (1,0), and idle (19,0); F2 must add 17 liquidity and finish with idle (2,2). A mismatch is a failed fixture, oracle, import, or dependency compatibility gate pending diagnosis. Do not replace an expected value with an observed SUT delta. If the frozen requirement itself is shown inconsistent with its admitted source, record that conflict for an owner decision; do not silently amend the acceptance row.

Remove the corresponding "if actual" conditions from AC09/AC21/AC30. Keep their execution status unverified, which is the honest qualification. The general first-return settlement rule remains unchanged.

### C2. Separate pre-build transformation verification from post-build ABI verification

**Draft sections:** 4, WP-01 through WP-04; 10, commands. **Requirements:** WI-02, WI-06, WI-37.

WP-01 requires `check_fidelity.py` to pass before WP-02 compilation, but the only specified invocation requires `out/WeirVaults.sol/WeirVaults.json`. On the first import that artifact does not yet exist. WP-02 likewise directs the focused test command before WP-03/04 have necessarily created the named test root and concrete specs. This is a dependency error, not merely a command-label issue.

**Exact correction:** define these distinct steps:

1. WP-01 implements and runs a source-only fidelity mode using frozen files, imported files, and the transformation manifest. It must not require an ABI artifact.
2. WP-02 performs the documented `forge-artifacts.py build` workflow on the three imported production paths. It records actual compiler settings, exit status, and any necessary WI-06 changes.
3. After successful compilation, run the ABI/layout mode against fresh artifacts. Missing artifacts fail that mode; they are never silently ignored.
4. Once WP-03/04 have created the TestBase and selected specs, run the documented focused `forge-artifacts.py test ... --test-root ...` workflow and its prerequisite runtime-artifact preparation.

The proposed verifier may have separate modes or separate invocations; specify the chosen mode contract in the plan. Do not offer a fabricated existing CLI flag. Also assign authorship of `check_fidelity.py` explicitly to the import/evidence owner; currently it is required by WP-01 but is not clearly in that package's owned outputs.

### C3. State the hook accounting timing and retain concrete AC60/AC67 constructions

**Draft sections:** 4, WP-03/WP-06; 5, hook setup; 6, AC59, AC60, AC67; 8, "Hook settlement is real." **Requirements:** WI-15, WI-21, WI-22, WI-32, WI-35.

The draft says the hook settles its debt inside the callback but does not explain that the returned hook delta is accounted after the callback returns. A helper that merely reads its currently visible delta and settles that value can therefore leave the eventual returned delta open. MiniMax's phrasing about returning a delta and then settling it is not an executable sequence either. The synthesis should resolve this rather than preserve a generic obligation.

**Exact correction:** add:

> For modifyLiquidity, callerDelta equals the pre-hook principal-plus-fees delta minus the returned hookDelta. The manager accounts that hookDelta to the hook after the callback returns. Inside the callback, a positive returned hookDelta h can be offset by a real take of h, creating temporary hook debt -h before the later +h credit. A negative returned hookDelta -h can be offset by a real payment and settle of h before the later -h debt. Record both stages, ensure physical funding is sufficient, and assert final hook and Weir deltas independently.

Name the actual zero-poke dispatch: under the inspected manager it uses applicable before/after-remove callbacks for `liquidityDelta <= 0`, not after-add or a new poke hook. Record the pre-hook delta, informational `feesAccrued`, returned hookDelta and expected final callerDelta separately.

Retain these source-derived, unexecuted constructions from my original:

- **AC60 positive distinction:** with no position fees on the poke, a funded hook prepays h and returns `-h`; Weir sees a positive first component h while informational fees remain zero. Apply the source fee/cut/idle arithmetic to h.
- **AC60 negative distinction:** with no idle or other fees, the hook takes 1 and returns `+1`. The hook's eventual delta closes; Weir sees `-1`, ignores it as gross fees, and leaves its own debt. The expected outer failure is `CurrencyNotSettled`, not an unclosed-hook failure.
- **AC67 candidate:** reproduce F1 with the return-delta hook disabled during setup, so idle=(19,0) and L=T=K. Donate 1 currency0 directly to Weir as unassigned inventory, then donate 20 currency1 through the funded pool router. Enable the return delta only for the next positive reinvestment add. Compound sizes 17 liquidity; principal add delta is (-17,-17). The hook takes 3 currency0 and returns hookDelta=(3,0). Weir's add caller delta becomes (-20,-17), settlement net=(-20,2), and signed idle update=(-1,2). Expected final recorded idle is `(2^256-1,2)`, physical Weir balances `(0,2)`, L=K+17, T=K; the hook receives 3 currency0 and external treasury receives 1 currency1. All hook/Weir deltas must close.

These are proposed fixtures, not verified runtime results. If a real-manager condition prevents the construction, record the exact failing stage and keep the acceptance branch unresolved. That is materially stronger than naming `wrappedIdleOrGap` without a construction.

### C4. Make paused reentry and stale-sync scenarios executable rather than symmetric labels

**Draft sections:** 6, AC20, AC51, AC54, AC58; 8, callbacks and rollback. **Requirements:** WI-11, WI-28, WI-29, WI-30.

"Paused twins of each" callback test is underspecified. An already-paused outer deposit never reaches its token pull or native refund. Similarly, a router already owning the manager unlock cannot call Weir and reach native settlement: the nested unlock fails first.

**Exact correction:** specify the trigger and boundary for each variant:

- An already-paused outer deposit is a no-callback EnforcedPause test.
- For pause-before-guard during an active deposit's pull/refund hook, begin the outer deposit unpaused. Give the real callback actor current-owner authority; inside its actual callback, pause and then attempt the nested deposit. The nested call must reach EnforcedPause before the active reentrancy guard. Alternatively use a reachable withdraw/compound callback while deposits are paused. State which construction is used for each phase.
- Unpaused reentry into deposit, withdrawal and compound must separately assert the guard failure at the actual callback caller.
- In AC51's pre-sync variant, sync from a router **without first acquiring manager unlock**, then invoke an empty-vault native/ERC20 deposit with positive native debt and no intervening clear. Keep the independent already-unlocked-router experiment in AC58.
- In AC51's callback variant, use an actual after-add hook or token callback that leaves a non-native sync open before positive native payment. A sync created inside the failing Weir subtree rolls back even if an outer router catches that failure. Only a pre-existing outer-router sync survives that caught subtree, within the same transaction.
- In AC58, explicitly cover both valid and malformed outsider callback bytes and distinguish direct errors from hook-wrapped propagation.

Also amend the compound sequence in section 8 to state `nonReentrant` before the existence check. It matters when guarded reentry uses an unknown key.

### C5. Preserve the declared domain of the common assertions and campaign exit

**Draft sections:** 6, introductory paragraph and AC63/64; 7, WI-33/WI-36; 8, inventory; 4, WP-07. **Requirements:** WI-24, WI-33, WI-35, WI-36.

Section 6 currently says every successful runtime row runs the closed-inventory check, except static and intermediate callbacks. That still includes successful hostile short delivery and wrapped idle, for which the ordinary reconciliation can be false. It also risks imposing unlock closure on unguarded operations under another actor's unlock. The narrower caveats in section 8 do not remove this conflicting blanket instruction.

**Exact correction:** replace the common rule with:

> Every runtime row asserts the exact observations applicable to that operation and its stated domain. The ordinary physical-inventory/share invariants apply only to supported exact-transfer, nonrebasing cases without invariant-breaking hook/callback effects. Manager relock and all required delta closure are asserted after a successful top-level operation that acquired and completed its own unlock. Unguarded operations under an independently owned unlock and hostile characterizations use their separately specified checkpoints and ledgers.

Keep the root 16-run/depth-8 settings if that is the coordinator's selected campaign. But `success count > 0` is too weak to show the required dimensions. Add deterministic scripted sequences and per-action/per-pool/per-direction success counters for the admitted operations, native/ERC20, donations, share transfers, pause and owner transitions. The plan must not rely on random selection within 16 runs to cover those requirements. No profile edit or mandatory larger campaign is needed to make this correction.

### C6. Complete the fork parity sequence and address mapping

**Draft sections:** 4, WP-08; 6, AC65; 9, recipe. **Requirements:** WI-03, WI-32, WI-37.

The draft's fresh-pool/snapshot approach is sound, but "run the action" does not choose the parity actions. The explicit map names Weir, payer, recipient and pool key but omits owner/treasury roles even though the copy is given different owner/treasury addresses. Reference code existence also does not prove its immutable manager binding.

**Exact correction:** expand the recipe to require:

1. Read the reference `poolManager()` and compare it to the supplied manager; read actual owner, pending owner, treasury, perfFeeBps and paused state rather than treating constructor values as current state.
2. Before the shared baseline snapshot, establish funding, approvals, identical pool/auxiliary-position conditions, and legitimate role alignment. Assert the selected PoolId is absent in both deployments.
3. Run an explicit minimum selected-pool sequence on each branch: create; paired deposit with payer distinct from recipient; funded fee donation and compound; second deposit; share transfer; partial withdrawal; each selected zap direction; and late-slippage rollback. Give administration/ownership parity its own equivalent-state branches. Native parity must be a named additional fixture or a specifically documented limitation, not silently inferred from the fresh ERC20 pool.
4. Map reference/copy Weir, owner, pending owner, treasury, payers, share holders, output recipients, position owner, allowances, and self-recipient/self-treasury roles when exercised. Compare selected-pool state and mapped balance/array changes, not unrelated prefixes.
5. Require `revertToState` to return true; restore the entire fork, including manager/tokens/hooks and allowances, between branches. Preserve comparison observations in memory or an admitted record not reverted with post-snapshot test storage.
6. Retain explicit archive-header provenance for the pin/hash; do not use `blockhash(block.number)`. Missing archive, role equivalence or code remains BLOCKED.

The fork-first choice discussed below is not this defect. The missing action set and role mapping are.

### C7. Restore concrete treatment of conditional branches and omitted subcases

**Draft sections:** 6, AC23, AC33, AC41, AC49, AC52, AC54-56, AC58. **Requirements:** WI-26, WI-28, WI-31, WI-35.

These rows should not be represented as fully executable merely by allocating method names.

**Exact corrections:**

- **AC23:** carry the ordinary-domain reachability argument. Genesis gives L=T; nonnegative compounding, floor issuance and proportional burns preserve L>=T. For valid positive s, `floor(L*s/T)>=s`, so the zero-removed-liquidity branch cannot be reached by those ordinary actions. Label the proposed exceptional investigation separately; retain no-remove, idle-only and all-zero-output subcases as distinct gaps if not constructible. A pure math vector does not establish vault reachability.
- **AC33:** choose a fee-zero pool with spacing greater than one, real one-sided donated idle, and a real move into an interval outside the stored usable range but inside global price limits. Size idle independently so the one-sided reinvestment is positive. Prove zero newly harvested positive fees rather than excluding real swap fees from the expected result. The sentence "Fees from the price-moving swaps are not counted" must instead say they must be absent at this compound's harvest checkpoint or separately harvested before it.
- **AC41:** specify the spacing/range construction for reachable below/above observations; keep lifecycle fee-growth wrap distinct from independent modular arithmetic vectors.
- **AC49:** retain the nonzero-refund case, but mark zero-refund reachability conditional until a construction is provided. One concrete candidate is a native/ERC20 pool at Q with prior real auxiliary liquidity to fund a hook's native take. A hook disabled during auxiliary setup returns an extra positive native hook delta of 2 on Weir's first add and takes those 2 units inside its callback. For declared native K+2 and source-sized liquidity K, native used becomes K+2, so the rejecting payer receives no native refund call; the hook delta must close. This candidate is unrun and must be checked, not assumed.
- **AC52/WI-26:** add explicit repeated pause and unpause methods asserting EnforcedPause and ExpectedPause. Naming these only in the WI summary is insufficient.
- **AC54:** enumerate the guarded target methods and caught/bubbled outcomes for each actual callback phase; the paused constructions must follow C4.
- **AC55:** name zero delivery as well as short delivery, and exercise each with and without independently tracked pre-existing inventory where required. A short-delivery method name alone does not prove the zero-delivery branch was tested.
- **AC56:** include owner-callback ownership methods as well as setters, and insufficient share/authority controls with full errors; the current row stops at setters and a caller-ownership statement.
- **AC58:** explicitly retain both valid and malformed outsider bytes, as noted in C4.

These corrections preserve existing requirements. They add no new economic behavior or acceptance IDs.

### C8. Reduced evidence files must retain machine layout, graph, and complete diff evidence

**Draft sections:** 2, selected decision 7; 3, evidence inventory; 4, WP-00/WP-02; 6, AC01/68/69. **Requirements:** WI-02 through WI-06.

I accept collapsing human documents. However, WP-02's "record source declaration and inheritance storage order" is weaker than generated storage-layout proof, and the listed machine outputs do not give layout/graph evidence a clear home. A helper that fails only on unlisted token changes also does not by itself prove unchanged comments/notices.

**Exact correction:** keep the selected filenames but specify that their contents or linked retained artifacts include:

- Full compiler storage-layout evidence, compared against the independently derived expected sequential inherited/domain layout, including slot, offset, width, packed inherited fields, mapping/array locations and Vault member layout. Recording declaration order is not the comparison.
- The actual resolved production and test graph separately, with exact paths and license/version provenance. If the build does not retain a particular compiler-input artifact, define the admitted extraction/resolution method rather than pretending it exists.
- The complete original-to-adjusted source diff and its approved scope/memory-struct hunks, plus a byte-level check that comments/notices outside those edits remain unchanged.
- WP-00's used-surface checks for FullMath/fixed-point constants, TickMath, signed BalanceDelta behavior, and actual manager storage layout in addition to the six currently listed steps.

This can all be embedded in `dependency-compatibility.json`, `import-transform.json`, retained compiler outputs and the release ledger; my original's extra files are not mandatory.

Also change "If this oracle and canonical FullMath disagree ... that is a dependency mismatch" in section 5 to "that is an unresolved oracle or dependency mismatch." The new limb oracle is not automatically correct. The independent wide-integer result and stage specification must arbitrate before diagnosing either implementation.

### C9. Freeze one owner and one concrete destination for each shared helper and test subcase

**Draft sections:** 3, test inventory; 4, WP-03 through WP-07; 7, WI-34.

The draft claims disjoint tracks, but AC36 appears in multiple primary test files, AC48-49 are assigned "where the deposit file owns the fixture," AC62 is assigned "if not already closed," and the library exposure/math work overlaps WP-04/WP-05. The proposed published surface also uses `...` for hook initialization and omits observation/Behavior parameter contracts. WP-07 states ownership of the invariant file/handler, while the handler is under the shared infrastructure tree; that boundary should be explicit.

**Exact correction:** assign one definitive file/class and owner per AC subcase, with other suites calling a shared fixture rather than redefining it. Allocate the shared observer, both routers, oracle/fixture generator, hook deployer and callback programming surface to named package owners. Before parallel test authoring, publish their actual input/output types, data ownership and catch/bubble semantics. Mark these as proposed test-only APIs, not existing interfaces. Correct WI-34's owner from the money-path package to the package that owns the oracle, with WP-05 as consumer.

The two-router split is acceptable; its contract needs to be complete enough that separate authors do not implement different funding and settlement assumptions.

### C10. Fix source attribution, cross-references, and rollback wording

**Draft sections:** 2, "Not adopted"; 4, WP-02; 6, AC65; 8, rollback; 9, recipe.

These are smaller corrections but they matter for a traceable frozen synthesis:

- The rejection table attributes `v4-core/test/utils/HookMiner.sol` to Kimi. The delivered Kimi original's section 1.4 names `.../v4/utils/HookMiner.sol`, not that rejected path. Preserve the selected public-utils miner if desired, but correct the attribution and explain that selection without inventing a peer proposal.
- References to commands in section 11 should point to section 10. AC65's fork-recipe reference should point to section 9, not section 10.
- Replace "A caught reentrant rejection does not by itself undo a successful outer Weir call that already finished" with "A caught rejected reentrant call can occur while the outer Weir call is still executing; the outer call may subsequently succeed or fail on its own later conditions."
- Distinguish snapshot isolation from rollback proof. Read pre/post state around the actual failed invocation and assert equality **before** restoring a VM snapshot. Manually restoring state cannot demonstrate that the failed call reverted it.
- Preserve the receipt disclaimer. In AC26, "persistent logs" cannot be reported as independently verified merely because post-state matches or `recordLogs` returned entries; require actual local receipt evidence for that claim or mark receipt-level verification unperformed.

## Dispositions of my proposals and the identified coordinator choices

| Proposal or decision | My disposition after reviewing the draft and peers |
|---|---|
| Direct `new PoolManager(address(this))` instead of CREATE3/artifact loading | **Accept; not a remaining defect.** The assignment permits a minimal real-port deployment and the draft supplies current real-manager examples. CraneTest bootstrap still runs, and Weir remains standalone. My original preferred an inspected CREATE3 pattern, but did not establish that direct construction changes required behavior. Revise the rationale: CREATE3 is not intrinsically less faithful; stale artifacts are a workflow risk already addressed by required fresh builds. Direct construction does not waive build-before-test or dependency compatibility. |
| Two owned routers | **Accept the split; require the contracts in C3/C4/C9.** A pool-operation router and a boundary/catch router are coherent. Reusing upstream operation routers is not mandatory, and copying their tree is unnecessary. Two routers must not silently become two inconsistent economic settlement implementations. Share the minimal necessary test-only settlement primitive, or keep the call router non-economic except for the precisely specified outer-unlock case. |
| Collapsed evidence files | **Accept the reduced human document set.** `VENDOR.md` plus `IMPORT_EVIDENCE.md` is sufficient if C8's full diff, ABI/layout/graph artifacts and result statuses remain accessible and machine-consumed where appropriate. My original's separate evidence filenames are optional, not requirements. |
| Fork selection before CraneTest bootstrap | **Accept the fork-specific order.** Selecting the target fork before bootstrap avoids constructing setup on the wrong state. Explain parent-first as CraneTest being the first fixture/bootstrap setup on the selected fork, before Weir/token/router setup; hermetic setup remains literally parent-first. Do not inherit hermetic manager deployment or call it and then fork. This does not excuse C6's missing reference binding/action/role details. |
| Independent Python vectors plus a Solidity limb oracle | **Accept with C1/C8 corrections.** The Solidity oracle is additional test logic that needs independent verification; it is not proof against itself or authority to override frozen anchors. My Python-led proposal does not require removing the Solidity helper. |
| Default 16-run/depth-8 campaign rather than my proposed larger release campaign | **Accept the selected budget, not success>0 as coverage.** Deterministic required-dimension sequences and counters are needed under C5. My suggested expanded counts and seed are not binding requirements. |
| Missing detailed return-delta and AC67 sequences from my original | **Still a defect in a decision-complete plan.** Restore the concrete constructions and pre/post-hook accounting in C3, labeled unexecuted. |
| My original's AC23 reachability argument, AC33 range construction and AC49 conditional zero-refund treatment | **Still needed in substance.** Exact filenames are optional; C7 gives the correction. |
| Grok's observed-delta qualification of F0/F1 expectations | **Do not retain as acceptance logic.** It is reasonable diagnostic caution but becomes circular when expected values follow the SUT. C1 preserves both fixed assertions and honest unverified status. |
| Kimi's deposit sequence wording that places refunds before recipient credit | **Do not adopt.** The draft correctly puts recipient credit before outer refunds. Preserve that order and the AC61 observation. |
| MiniMax's loosely phrased post-return hook settlement and log-capture wording | **Do not adopt literally.** A returned hook delta must be offset with executable pre-return actions; debug log buffers are not receipt persistence proof. C3/C10 resolve the two points. |

## Limits

This advisory is based on the complete named draft, the complete three permitted originals, and retained context from my original's admitted reads. I did not recompute either supplied hash, reread the PRD/source, verify newly cited repository paths, inspect runtime/authentication state, or run commands, tests, builds, RPC, Git, deployments or delegation. No peer feedback was read.

The CREATE3 and direct-construction examples cited by other members/coordinator remain their source observations, not new independent execution evidence from me. Every concrete hook, range, refund and fork construction above is a proposed correction requiring later validation. Archive access, actual compiler/ABI/storage proof and licensing disposition remain unresolved gates.

This is the one requested advisory. It **neither replaces the draft nor authorizes implementation**. The coordinator may resolve these concerns in its final synthesis without another member debate or unanimity requirement. My original, the draft, PRD, source and peer originals are unchanged.
