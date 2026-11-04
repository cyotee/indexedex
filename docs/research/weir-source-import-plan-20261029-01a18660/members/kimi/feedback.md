I read this as the authorized transient retry of the same advisory - I’ll deliver the complete feedback inline because `apply_patch` is unavailable, then stop.

# Identity

Kimi, independent council member, submitting the single assigned advisory on the frozen synthesized draft and the three named peer originals. This is not a new original, another debate round, or implementation.

# Draft under review

- Path: `docs/research/weir-source-import-plan-20261029-01a18660/coordinator/draft.md`
- Revision: `weir-import-plan-draft-r1`
- Coordinator-supplied SHA-256: `5515502e83176fc1423d68bea8f73af8e9bea0efa98c2bdde6bdba92993e7942`
- The supplied hash was not recomputed. The complete readable draft at that path was the only draft reviewed.

# Disposition

**SUPPORT WITH CORRECTIONS**

The draft preserves the required standalone-import scope, real-manager topology, independent-oracle discipline, complete WI/AC traceability, honest reachability gaps, and separate compiler/hermetic/fork/security/license gates. The corrections below are localized and do not require a different architecture or another original.

# Concerns

## K-01 — F0 expectations must not be recomputed from the observed SUT result

**Draft sections:** 5, “Anchors”; 6, AC09 and AC21.

The draft says that if the real add delta is not `K`, “used and refund follow the real delta,” and conditions some F0 assertions on the real liquidity or oracle amount holding. Used this way, the actual SUT result becomes its own expectation, contrary to WI-34 and the exact F0 acceptance rows.

**Exact correction:** Make every published F0 value a hard assertion: liquidity and total shares `K`, manager cost `K` per currency, refund `2` per currency, recipient shares `1,047,576`, full assigned withdrawal output `1,047,575` per currency, and residual `L=T=1,000`. Observed manager deltas are compared against those independent expectations; they never redefine them. Any deviation is a failing dependency/behavior gate, not an alternate valid fixture. “Not yet executed” may remain the status, but no conditional alternative result may be accepted.

## K-02 — AC49 needs an actual zero-refund construction

**Draft section:** 6, AC49.

The draft names `test_AC49_zeroRefundNoCall`, but its construction only says that the payer rejects native. It does not specify how a successful native deposit reaches the outer refund with `declared - used == 0`. The ordinary F0 construction cannot supply this case because it refunds two units.

**Exact correction:** Require an independently constructed native-input deposit whose final used native amount equals the declared native amount and whose manager deltas close. A valid return-delta hook may increase the native liability while settling its own hook credit, or an independently solved zap fixture may produce the equality. Assert both that the deposit succeeds and that no native refund call reaches the rejecting payer. If neither real construction reaches zero refund, record that precise gap rather than claiming the subcase from the positive-refund test.

## K-03 — AC67 should include the available concrete real-hook candidate

**Draft sections:** 6, AC67; 8, hook settlement.

The draft preserves the correct wrapped-idle assertion and honest gap status, but leaves the difficult `oldIdle + net = -1` construction generic. Astra supplied a concrete, source-derived candidate that makes the plan more decision-complete without injecting state.

**Exact correction:** Add the following as an unexecuted conditional fixture:

1. Establish F1 in a valid return-delta-hook pool with the hook disabled during setup, yielding recorded idle `(19,0)` and `L=T=K`.
2. Donate one currency0 unit directly to Weir as tracked unassigned inventory, making its physical currency0 balance 20.
3. Donate `(0,20)` through the real pool router. On compound, gross is `(0,20)`, cut is `(0,1)`, and reinvestment is 17 liquidity with principal add delta `(-17,-17)`.
4. Enable the hook only for that positive add. The hook takes 3 currency0 and returns hook delta `(3,0)`, while settling its own resulting manager delta. Weir’s first add return becomes `(-20,-17)`.
5. Assert Weir nets `(-20,2)`, signed idle sums `(-1,2)`, recorded idle `(2^256-1,2)`, physical payment of all 20 currency0, receipt of 2 currency1, hook receipt of 3, treasury receipt of 1 currency1, `L=K+17`, unchanged `T=K`, and closed final deltas.

Any earlier real-manager failure must be reported with its exact envelope and rollback boundary. The candidate remains conditional until executed; it is not a claimed exploit result.

## K-04 — Fork preflight must verify the immutable binding and equivalent reference/copy settings

**Draft section:** 9, especially steps 4–8.

The fork preflight checks code at the reference and manager, but does not explicitly read the reference Weir’s `poolManager()` binding. Step 6 also says to align fee and pause using the copy owner without explicitly requiring equality with the reference’s actual state. That is insufficient for equivalent initial conditions.

**Exact correction:**

- During preflight, require reference `poolManager()` to return `0x8366a39CC670B4001A1121B8F6A443A643e40951`, in addition to the chain/block/hash/code checks.
- Read and record the reference’s actual `perfFeeBps`, `paused`, owner, pending owner, treasury, and selected-pool state.
- Set the copy to equivalent fee/pause conditions through legitimate local calls, or document an explicit role mapping where addresses intentionally differ. Do not merely choose arbitrary test-owner/test-treasury settings.
- Take the branch snapshot only after role/policy alignment, funding, approvals, and shared auxiliary state are equivalent.
- If reference role state prevents alignment, mark only the affected parity action BLOCKED with the exact cause.

## K-05 — The HookMiner non-adoption table misattributes the path correction

**Draft section:** 2, “Not adopted, and why.”

The row attributing `v4-core/test/utils/HookMiner.sol` to Kimi is inaccurate. Kimi’s original used the existing `lib/crane/contracts/protocols/dexes/uniswap/v4/utils/HookMiner.sol`, not the nonexistent v4-core test path.

**Exact correction:** Replace that row with a coordinator-selection note: the draft selects `lib/crane/contracts/protocols/dexes/uniswap/v4/hooks/public/utils/HookMiner.sol` because that file and its MIT header were inspected. Kimi’s alternative `v4/utils/HookMiner.sol` was also an existing path, so no “Kimi path correction” should be recorded. Retain the selected public-utils miner and real CREATE2 mining.

## K-06 — AC26’s log wording must not imply receipt persistence from debug capture

**Draft section:** 6, AC26.

“Restores … persistent logs” is ambiguous and can be read as asserting receipt-log behavior from Forge instrumentation.

**Exact correction:** Replace it with: the failed withdrawal restores all listed state and balances, and no log from the reverting subtree persists in an actual receipt. `recordLogs`/`getRecordedLogs` may support call-tree diagnosis only. If receipt-level persistence is claimed, collect and cite an actual local transaction receipt as section 8 already requires.

## K-07 — Add the available reachability reasoning for AC23 and AC33

**Draft section:** 6, AC23 and AC33.

The draft correctly permits precise gaps, but the fixtures remain more generic than necessary.

**Exact correction:**

- For AC23, record Astra’s ordinary-domain reachability analysis before attempting the branch: genesis establishes `L=T`; compounding only increases `L`; issuance preserves `L>=T`; and a valid withdrawal normally removes at least one liquidity unit for positive shares. A zero-removal branch therefore needs an admitted exceptional real-action construction or a documented reachability gap, not an arbitrary tiny-share assertion.
- For AC33, use the proposed fee-zero, tick-spacing-greater-than-one construction: accrue sufficiently large one-sided idle through real donation, move price with real fee-zero swaps into a deployable one-sided region, and independently prove zero newly harvested positive fees before compounding. Keep the exact positive-reinvestment requirement and gap status if the required price/idle magnitude cannot be reached.

# Dispositions of proposals the draft did not adopt

| Proposal | Disposition |
|---|---|
| Reuse `PoolSwapTest` / `PoolModifyLiquidityTest` | **Accept non-adoption.** Kimi proposed reuse only where their real unlock/settlement behavior fit, with auxiliary code for donate, stale sync, and caught nested unlock—not universal dependence on them. The selected owned `WeirPoolRouter` and `WeirCallRouter` cover all required operations with one controlled settlement surface and avoid copying UNLICENSED upstream test helpers. No correction is needed beyond preserving that narrower description of the original proposal. |
| HookMiner path correction | **Correct the attribution, retain the selected miner.** See K-05. Kimi did not propose the nonexistent v4-core test path. The selected public-utils `HookMiner` is valid. |
| CREATE3/`ArtifactCreationCode` manager deployment | **Accept non-selection.** It is a real alternative, but direct construction of the canonical manager inside the standalone TestBase is expressly permitted and avoids product inheritance. Artifact freshness remains mandatory for `CraneTest` bootstrap and all runtime artifact consumers. |
| Collapse overlapping release ledgers into `VENDOR.md` plus `IMPORT_EVIDENCE.md` | **Support.** The split retains human provenance and release results without duplicative documents; machine JSON remains the appropriate fidelity evidence. |
| Reject a fork base that deploys hermetic state before selecting the fork | **Support.** Fork-first setup avoids wiping factories and local deployments. `CraneTest.setUp()` may run only after the fork is selected, and no second manager is deployed. |
| Refuse green-on-build-failure and prose-pinning tests | **Support.** AC03 remains a command gate, and fidelity checks compare machine-consumed source transformations/ABI rather than plan or PRD prose. |
| Astra’s concrete AC67 candidate | **Adopt as a conditional fixture.** See K-03. It materially improves decision completeness without changing requirements. |
| Astra’s AC49 zero-refund warning | **Adopt as a required construction detail.** See K-02. Naming the subcase is not enough. |
| Astra’s AC23/AC33 reachability analysis | **Adopt as explanatory construction guidance.** See K-07. It does not convert unreachable branches into passes. |
| Astra’s expanded campaign suggestion | **Accept the draft’s non-adoption for the required gate.** Keep the observed 16-run/depth-8 configuration and require productive deterministic regressions and successful-action counters. Any later expanded run needs separately verified runner syntax and must not edit profiles. |

# Limits

This advisory reviewed only the complete frozen draft and the complete Astra, Grok, and MiniMax originals. It did not recompute the supplied hash, review another draft, read peer feedback, edit Kimi’s original, perform new dependency research, or execute compilation, tests, RPC, Git, deployment, or license clearance work. All proposed fixtures and corrections remain unexecuted planning; no runtime, archive-parity, economic-safety, or legal-clearance claim is made.

This advisory neither replaces the draft nor authorizes implementation.
