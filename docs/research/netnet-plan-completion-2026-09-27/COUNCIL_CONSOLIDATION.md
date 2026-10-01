# Plan-completion round — completed reviews and in-place revision

Date: 2026-09-27. **All four originals and four combined original-session cross-reviews are complete.** Plan revised in place to v0.2; not certified unconditionally executable.

## 1. Result

The plan now includes concrete inner-share formulas/residual allocation, operation-bound funding receipt requirements, a retained V2 surface inventory, local exact-output inverses, a specified arithmetic-observation ABI and3601-entry retention proof, bootstrap formulas, principal counterexamples, correct conditional reward-funded share equations, and terminal transitions through a drained candidate. Former blanket G2–G5 requests for future annexes have been removed throughout the work-package dependencies.

G0 instruction authority and required G1 external verification remain. Four narrowly scoped cases L1–L4 explicitly identify what was not solved rather than calling every draft a correct final algorithm. There are also remaining custom ABI/initialization and configured route mappings; they are ordinary unfinished plan work, not an invented product impossibility. It would be inaccurate to say the user's requested decision-free implementation plan is now fully finished.

The plan's own §2 names each affected path and §6/§8/§9 supplies the relevant derivation. This report does not create another prerequisite annex.

## 2. Important technical adjudications

### L1 — simple integer B/U conversions do not prove fixed-principal preservation

Selected B/U balance is `floor(B*u/U)`. Native rounding is permitted; exact fractional ownership and sum-of-all-floored-balances==B are not required. But computed native bond principal and locked principal during reward-only claims must remain funded to the position.

For old fixed principal equal to B, adding native fixed principal x with unchanged old shares U requires `m<=xU/B` to protect old principal and `m>=xU/B` to give the new position x. If xU/B is noninteger, the two inequalities cannot be met with an integer m. B3/U2/x1 and B3/U10^27/x1 are examples.

**High precision is not by itself a solution.** Properly scaling every old share and U leaves the same division test in the scaled units; multiplying only the new mint by another SCALE is a unit error and dilutes old shares. For a concrete sequence under the rejected floor-mint/ceil-withdraw candidate, let Q=10^27: initial stake2 gives B2/U2Q; add reward1; sole holder claims reward1 by burning ceil(2Q/3). Its remaining backing/principal is2 and remaining U=(4Q−1)/3, an odd integer. A subsequent fixed-principal deposit1 requires m=U/2, noninteger. The first reward claim itself leaves the sole holder's principal intact, so that candidate algorithm cannot dismiss the later state merely because the initial share scale was large. This is algebraic analysis, not an executed deployment trace.

B10/U6/position shares3/principal4 gives value5. Paying reward1 by burning ceil(6/10)=1 share leaves B9/U5/shares2/value3, below locked principal4. The post-state principal test—not just value of burned shares—is necessary.

These refute the reviewed simple algorithms, not every conceivable augmented representation or the whole PRD. Reverting all nondivisible inputs, capping rewards, adding a subsidy, switching to gons or weakening principal promises is not silently authorized. No accepted replacement representation/reachability proof was produced this round.

Standing allocation weights are nonredeemable and persist independently of existing receipt ownership. The correct supporting source uses O+Wf+Wc allocation and separate floors. With exactly divisible allocation and no unresolved dust, new fee receipt shares are F*U/(B+ordinaryReward), not the standing-weight top-up delta. Minting those weight deltas as ownership can transfer old principal. The plan gives the O80/B800/A100/f20% counterexample and a valid zero-ordinary-share standing20/30→40/60 funded allocation. Physically included B dust cannot be distributed pro-rata and then allocated a second time.

### L2 — contract-only callers are not authenticated funding receipts

Moderator directly read `contracts/utils/LocalCreditLib.sol:7–9,23–27`. It explicitly says `requirePretransferCaller` only inspects bytecode and cannot prove atomic transfer-and-consume. Kimi's assertion that this is already the authenticated boundary is rejected.

`BasicVaultCommon.sol:80–105` measures pull deltas but credits push-mode availability from B−R. A prior forced claim may leave zero new claim return while increasing held balance. Neither that return nor an arbitrary subtraction distinguishes legitimate user input from unrelated cash. The plan now specifies a controlled receipt context created before funding, consumed once and bound to authenticated components/callbacks. It does not claim every inherited push caller was traced to that boundary. Removing a retained feature or crediting anonymous surplus is not an acceptable substitute.

### L3 — exact local inverse does not establish the whole route

Accepted primitives are linear floor inverse, exact floor-tax gross inverse, source Weighted input calculation, actual BasePoolMath HLP debit and contraction-uplift inverse. Backward composition must use the actual configured conversion graph and be replayed forward with exact fees, units, state mutation and ownership debits.

Reject sampled SY rate plus universal one-unit fix-up, double fee gross-up, multiplying token-unit outputs together, iterative redemption as an inverse, or a replacement external Pendle SY. The configured SY may in fact have a usable source inverse; this was not established by the drafts. That remains G1-dependent source mapping, not a demonstrated requirement to redesign pricing.

Owned reserve liquidity is `HLP.balanceOf(DETF)`, not `DETF.balanceOf(hook)`. A quote-only synthetic mark is not a unique liquidation waterfall. The remaining composed funding graph is acknowledged rather than hidden behind an internal function name.

### L4 — terminal native-holder rights remain narrowly unresolved

The plan fixes purchase, partial collection, full intended completion, E+1, early rewards, partial/all funded-principal rebond and drained-candidate transitions. It does not accept all-gift `pendingFor==0` as the intended-note completion condition. It also does not invent transfer of proxy ownership, gift forfeiture or a nonburning DORMANT NFT as the user's chosen retirement policy.

Earlier Astra DORMANT text was explicitly withdrawn in Astra's own cross-review. MiniMax and Kimi read only Astra's ORIGINAL, as protocol requires; their later claims that DORMANT is selected are therefore not accepted by the moderator. Exact post-completion excess release and irreversible terminal disposition are previously retained PRD edges, not solved by renaming a state. No new broad lock questionnaire is raised.

## 3. Completed specifications adopted into the plan

- Inner first issuance: geometric root, locked minimum1000 included in total S; later m=min(floor(xS/L),floor(yS/Y)); accepted quantities ceil(mL/S),ceil(mY/S); operation-owned residuals realized/refunded under supported routes/limits. No donation by calling the excess a book entry. No last-circulating-holder sweep of minimum-locked backing.
- Arithmetic oracle: exact observed piecewise-constant price×time, per-integer-second coalescing, two512-bit cumulative limbs,3601-entry ring and explicit predecessor proof, read-only boundary extension and independently identified series. No invalid-zero-as-warm-up or unsampled history reconstruction.
- Local inverse table including floor-tax example y19/t500/D10000→gross19, not a guessed20.
- Bootstrap G/U/principal/reward expressions, actual direct SY capital, all four legs and atomic activation. No invented equality of NET/sNET prices or unverified USDG opening conversion.
- Fixed retained V2 nine-cut/fourteen-interface inventory and operation-context fields; custom selector/dependency graph omissions remain honestly identified instead of falsely called enumerated.
- Required analytical test vectors, no fabricated passing tests or gas results.

## 4. Attribution, disagreements and reliability

| Researcher | Useful contribution | Rejected/corrected claim |
| --- | --- | --- |
| Astra | Principal counterexamples, correct conditional receipt equations, authenticated context distinction, local inverses and ring proof | Original demanded overly strong exact fractional preservation; narrowed to fixed native-principal failures. Original DORMANT design withdrawn as unselected. |
| Grok | Explicit conditional inverse and principal-preserving checks; correction of old formulas | Blanket reversion is not proof all selected staking routes work. Original all-gift retirement condition and kept-residual donations are not accepted. |
| MiniMax M3 | Acknowledged original initial-share/weight/unit errors; agrees no arbitrary anonymous credit | Cross-review still declares DORMANT selected, repeats new external SY, leaves unowned residuals and unproved rounding fixes. Those are not accepted. |
| Kimi K3 | Ring proof and correct local floor-tax formula | Scaling does not cure all principal-boundary cases; bytecode caller check is not authentication; leftover retained value is not proved non-donative; DORMANT is not selected. |

All reports remain unchanged attributed evidence. Four model responses are not four independent mathematical proofs, and majority repetition does not override source or arithmetic. The moderator verified LocalCreditLib and the source/expected-value distinctions directly. No claim of unanimous resolution of L1–L4 is made.

## 5. Round continuity and incidents

Four originals were collected before peer sharing. Astra's first cross-review attempt failed with explicit RC_ATTRIBUTION. A later human-authorized ordinary retry in the same session succeeded. The moderator then mistyped Grok's session ID once; dispatch returned RC_UNAVAILABLE before a valid continuation. The human authorized resumption using the exact original ID, and Grok/MiniMax/Kimi completed.

**Ten task invocations produced eight substantive deliverables:** four originals, four completed original-session cross-reviews, one failed Astra continuation and one denied mistyped Grok dispatch. No participant/model substitution, new session or alternate-path guard bypass was used. Success of retries is not a diagnosis or claimed repair of the attribution service.

Each cross-review received the other three complete ORIGINAL reports, never another cross-review. Prior histories retained. Original routing metadata reported openai/gpt-6-astra, xai/grok-4.6, minimax/MiniMax-M3, kimi-code-plan-global/k3; metadata is not provider attestation.

| Researcher | Original | Cross-review | Session |
| --- | --- | --- | --- |
| Astra | [Original](astra-original.md) | [Cross-review](astra-cross-review.md) | `ses_f1c499b6bffe6RiNjZZUSMsP8S` |
| Grok | [Original](grok-original.md) | [Cross-review](grok-cross-review.md) | `ses_f1c4384d7ffeZX74uV9yhIXbVq` |
| MiniMax M3 | [Original](minimax-original.md) | [Cross-review](minimax-cross-review.md) | `ses_f1c3f57edffedYs43k2PBvA5xU` |
| Kimi K3 | [Original](kimi-original.md) | [Cross-review](kimi-cross-review.md) | `ses_f1c3a8701ffeB4x8S7oRn2JnXK` |

Astra disclosed an accidental unauthorized sibling `as-cross-review.md` containing `# invalid target`. It has not been deleted/moved or treated as a review artifact. Human cleanup remains needed; the report does not conceal that file-target violation. The earlier PARTIAL_STATUS.md remains preserved history; current round completion is recorded here.

## 6. Sources and limitations

Direct moderator source reads include `LocalCreditLib.sol:7–28`; `DETFMintSplitLib` and the selected source mappings from earlier rounds; current `DETFFundedStakingMath.sol:45–94` separating standing weights/allocation/gons; and `UniswapV2StandardExchangeDFPkg.sol:401–518` for exact advertised interfaces and cuts. Astra's report cites the remaining source and current PRD/plan ranges. All are local snapshots inspected 2026-09-27, not a new deployed-runtime comparison. Compiler0.8.35 remains configured, not newly executed.

High confidence in source statements and counterexamples to the reviewed simple formulas. Conditional/incomplete: actual whole-model reachability, an alternative compatible share representation, full retained-caller mapping, configured inverse composition and terminal-rights disposition. No shell, tests, RPC, browser execution, signing, deployment, source/config/instruction changes or measurements were performed. A broad glob emitted broken-symlink discovery errors; no secret/config search or access workaround followed.

## 7. Handoff

The implementation plan was revised **in place** to v0.2. Broad future-annex gates G2–G5 are removed; correct material is inline, G0/G1 remain external, and L1–L4 identify exact affected paths. The plan still cannot truthfully be called fully finished/ready to execute. A narrow representation or terminal-policy resolution may require an explicit choice; ordinary retained-interface/init/source mapping remains plan-author work. This result is not an instruction to the implementer to make those choices.

The requested resumption is complete. Stop at the human checkpoint with the improved plan and exact limitations; do not automatically start another round or implement anything.
