# PairToken stage-one PRD assessment: coordinator draft r1

Draft identity: `pairtoken-se-stage-one-council-20261028-01a1810f-draft-r1`.
Date: 2026-10-28. This draft is frozen for one advisory pass.
It is a recommendation report, not an edit to the target PRD.

## 1. Question, participation, and outcome

The owner asked what requirements need clarification and whether the council
has suggestions to improve
`contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md`.
The target revision includes S1-ARCH-04/05 and 57 acceptance rows.

All four requested independent initial assignments settled before this draft:

| Member | Native-resolved route | Original |
| --- | --- | --- |
| Astra | `chatgpt-subscription/gpt-6-astra:high` | `members/astra/response.md` |
| Grok | `xai/grok-4.7:xhigh` | `coordinator/received/grok-original.md` |
| MiniMax | `minimax/MiniMax-M3` | `members/minimax/response.md` |
| Kimi | `kimi-coding/k3.1-pro:high` | `coordinator/received/kimi-original.md` |

Invoking coordinator: `gpt-6.1-sol`, not a fifth independent vote. Runtime
metadata confirms the four model routes and process execution. MiniMax's
adaptive-thinking override was inspected; wire payload/billing was not.
Grok used one same-task delivery-format recovery to repeat an elided section,
not to change its assessment. Grok and Kimi used the allowed inline fallback.
MiniMax reported using another Markdown writer despite the required inline
fallback when apply_patch was unavailable; this process deviation is preserved
in RUN.md and is not hidden by reauthoring its original.

**All four members judged the PRD not yet implementation-ready.** They broadly
agree on unfinished zap attribution, insufficient economic acceptance criteria,
and the scope/liveness implications of exact V4 projections. Their proposed
solutions do not all agree and are not automatically adopted.

The five reused facets, 20 package selectors, exclusion of factory-supplied
facets from package cuts, one public share supply, native ETH support, and
explicit exact-output rejection are supported directions. None needs to be
reopened merely to address the findings below.

## 2. Authority, coverage, and evidence limits

Confirmed: one full-range position; no dead shares, retention, or baseline
protocol-fee routing; baseline mandatory swap-based compounding; actual ETH;
installed-but-reverting exact-output methods; canonical facet reuse; staged
delivery with the nested reserve model deferred.

Not automatically confirmed: the draft's detailed zap equation, spot SY
valuation, 512-step execution limit, credit ledger, donation disposition,
zero-output behavior, new validation rules, or every named correctness deviation.

All four members report complete examination of the PRD and three baseline
files. Additional context coverage is enumerated in each original. The
coordinator checked important locators in the baseline, shared SY code,
basic-vault targets, registry queries/registration, and V4 settlement/position
code. This is static analysis and arithmetic, not execution, gas evidence,
economic proof, or a security certification. No contracts or target PRD were
edited. No tests, builds, deployments, or Git commands were run.

Abbreviations below:

- `PRD`: the target above.
- `Baseline`: `contracts/pairtoken-baseline/PairToken.sol`.
- `V4`: `lib/crane/contracts/protocols/dexes/uniswap/v4/`.
- `SYUtils`: `lib/crane/contracts/protocols/perps/pendle/core/StandardizedYield/SYUtils.sol`.

## 3. Verified technical corrections

### C1. Correct canonical SY rate units

**Sources:** PRD S1-QUOTE-02; `SYUtils.sol:7-20`;
`lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol::exchangeRate`.
**Evidence:** source observation and integer arithmetic.
**Support:** Astra R1, Grok R2, MiniMax R1; Kimi R7 discusses inputs/rounding
without independently identifying this scaling error.

Canonical helpers compute raw asset amount as `rawShares * rate / 1e18`.
The draft's human-normalized formula has an extra factor `1e18 / 10^d`.
For a total book of `1e6` raw six-decimal asset units and `1e18` raw shares:

| Quantity | Correct result |
| --- | --- |
| Canonical SY rate | `1e6` |
| Raw assets from one whole share | `1e18 * 1e6 / 1e18 = 1e6` |
| Draft rate | `1e18` |
| Raw assets a canonical helper would infer from draft rate | `1e18`, overstated by `1e12` |

Recommend `exchangeRate = floor(Vraw * 1e18 / S)` with full precision,
zero at zero supply under the existing proposed policy, and actual asset
decimals in `assetInfo`. Avoid `10^d` in this raw-unit formula.
No owner question is needed to fix compatibility arithmetic. Whether `Vraw`
should use spot accounting is a separate owner policy question, Q3.

Do not conflate SY accounting rate with a normalized one-share executable
exit quote or add the excluded rate-provider surface.

### C2. Separate registry identity ordering from pool accounting ordering

**Sources:** PRD S1-ARCH-05/S1-NATIVE-01;
`contracts/registries/vault/VaultRegistryVaultQueryTarget.sol:64-84,149,196`;
`contracts/registries/vault/VaultRegistryVaultRepo.sol:92-133`.
**Evidence:** source observation. **Origin:** Grok R3.

Registry pair queries hash an address-sorted token list. Registration indexes
the supplied `contentsId`. The draft hashes PoolKey face order. In a native
pool, substituting wrapped native for address zero can make that face order
unsorted, so pair discovery can miss a registered vault.

Recommend:

- Keep `vaultTokens()` and `reserves()` in PoolKey face order `[C0,C1]`.
- Compute `contentsId` from an independently sorted copy, using the registry's
  canonical contents-ID semantics.
- Test a native pair whose wrapped face sorts after the other currency.

MiniMax R15's proposed unsorted hash is not adopted. It repeats the draft's
internally consistent list choice but misses the registry lookup contract.

### C3. Reconcile read guards with unchanged canonical facets

**Sources:** PRD S1-ARCH-04/05 and S1-SEC-01;
`contracts/vaults/basic/MultiAssetBasicVaultTarget.sol:16-26`;
`contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:32-77`.
**Evidence:** source observation and architectural inference.
**Origin:** Astra R4; partially recognized by Kimi R8.

The unchanged basic-vault facet directly reads its Repo with no family busy
guard. Canonical ERC-20 reads are similarly unguarded. A universal claim that
all economic reads revert during mutation is incompatible with unchanged reuse.

Recommend a selector-level read policy: new family economic queries and
previews fail closed; shared basic-vault reserves expose the last committed
snapshot; canonical token/metadata reads retain their behavior. Commit both
shared reserve values after external payout/refund interactions. Document that
mixing unguarded views during a callback does not produce coherent live NAV.
Do not modify shared facets, add a proxy-wide guard, or recut factory selectors.

Grok R12 and Kimi R8 still list basic reserves among guarded reads. That portion
cannot be adopted under the confirmed unchanged-facet requirement.

### C4. Specify native sync and real proxy receipt behavior

**Sources:** `V4/PoolManager.sol:228-236,298-313`; PRD S1-NATIVE-01;
`lib/crane/contracts/proxies/Proxy.sol::receive`.
**Evidence:** source observation.
**Origin:** Astra R6, Kimi R5; Grok R8 supplies proxy/receipt detail.

Before a native debt settlement, explicitly sync the native currency, then
settle the exact value and validate the result. PoolManager chooses its
settlement branch from the synced currency; nonzero value with a stale ERC-20
sync fails. The ordinary ERC-20 branch resets sync after settlement, so this
finding is not a claim that every normal ERC-20-then-native sequence fails.
The requirement protects against an outstanding/stale sync state.

The unchanged proxy accepts empty-calldata ETH without dispatching a facet
receive function. Book expected manager/wrapper receipts in the active engine,
not in a nonexistent family receive hook. Preserve refund reservations,
one-to-one wrap/unwrap attribution, receiver failure rollback, and forced-ETH
separation.

### C5. Define the ownership ledger and fee checkpoints

**Sources:** PRD S1-ACC-01/03/04, S1-OP-02/04/05;
`Baseline::_compound/_deploy/_add/_redeem`;
`V4/libraries/Position.sol:78-102`; `V4/PoolManager.sol::modifyLiquidity`;
`contracts/utils/LocalCreditLib.sol`.
**Evidence:** source observation and inference.
**Support:** all four identify ledger/attribution specification needs.

Write one transition table covering incumbent book, current input, exit
allocation, refund, and unbooked excess. Each settled manager receipt/debt and
temporary wrapped representation must have one owner and be booked once.
Separate raw local custody from deployed liquidity and position fee claims.

Fees deserve explicit checkpoints: the baseline initially collects, then may
swap and add. A positive add can realize more fees; a no-add branch can leave
new fee growth uncollected. A later partial removal may realize fees earned
by the entire old position, not only by the removed fraction.

Recommend defining the pre-entry/pre-exit snapshot to include fees earned
through completion of mandatory compounding exactly once, via projection or
a defined nonrecursive collection checkpoint. Separate principal and fee
components of modify results; do not give a partial exiter all whole-position
fees merely because they arrive in its removal receipt. Record any extra
checkpoint as a deliberate baseline deviation for owner review.

Grok R6 recommends excluding compound-swap fees from the snapshot as baseline
fidelity. That differs from Astra R5 and from the draft's all-fees snapshot
intent. It also overstates exclusion: a subsequent positive add can collect
those fees. This disagreement belongs in Q1's complete attribution decision;
do not quietly choose an implementation branch.

### C6. Complete ABI, canonical math domain, and acceptance predicates

**Sources:** PRD S1-OP-01/03, S1-X13, S1-A15/A24/A27/A28/A45/A46;
canonical scalar/multi-asset interfaces; `V4/libraries/TickMath.sol`,
`SqrtPriceMath.sol`, `LiquidityAmounts.sol`, `Pool.sol`, `Position.sol`.
**Evidence:** source observations plus technical recommendations.

Specify complete parameter/return types and mutability for paired methods,
previews, queries, compound, and donation. Keep the narrow paired surface
unless a separately approved interface change is wanted; the broad canonical
multi-asset interface also brings extra operations and nonpayable join
semantics. Do not add new single-token aliases duplicating SE/SY.

Use one piecewise principal/cost definition below, at, inside, and above the
full-range boundaries, with specified rounding. Apply it to basket amounts,
compound leftovers, additions, and projections. Manager-equal results are the
acceptance authority; preserve baseline interior math where proven equivalent.
No actual interior mismatch was demonstrated in this consultation, so Grok R4
does not establish that preserving it is impossible. Do not silently introduce
capacity clamping or changed residual ownership.

Give A15/A46 objective approved economic predicates, not just measurements.
Add real-manager cases for fee checkpoints, protocol fees, native sync history,
callback reads, liquidity capacity, and terminal exits. Retain scripted
baseline comparisons only for their stated characterization role.

## 4. Material owner choices

### Q1. Correct entry attribution, or preserve baseline behavior?

All four identify this as the principal unfinished economic choice.
Gross liquidity deployment is not proof of caller-funded contribution.

**Recommendation:** authorize the direction that incumbent reserves and fees
cannot themselves create shares for the entrant. Require a complete integer
equation, price/snapshot basis, fee attribution, residual ownership, and
rounding criteria in the PRD before coding.

Grok proposes a useful candidate: isolate the caller's inventory, swap half
of it, add only from it, mint from its deployed amounts, then book its
unmatched remainder without more shares. This prevents incumbent idle from
entering that numerator, but does not by itself prove fair pricing across
self-swaps, fees, and price movement. It is not yet a validated final formula.

MiniMax's alternative `deployed_i - idleBefore_i` is not adopted: the subtraction
can be negative, does not trace swap-converted ownership, and does not resolve
fee attribution. Merely adding a one-share tolerance does not repair it.

The owner may instead choose explicit baseline characterization with accepted
limitations, but that cannot be described as a fully resolved deployable
ownership model under the present completion gate.

### Q2. What exit availability must accompany mandatory compounding?

Retain confirmed mandatory swap-based compounding. Clarify that under strict
atomic behavior, a paired exit can still fail because its preceding compound
cannot execute. A paired exit only avoids the final unwanted-token sale; it
does not eliminate earlier swaps.

Exact multi-operation previews need a projected pool state: slot0, active
liquidity, ticks/bitmap, LP and directional protocol fees, fee growth, owned
liquidity/checkpoints, and local inventory transitions. Define a step as one
canonical swap-loop iteration, including empty-word/zero-liquidity progress.

The proposed 512-step cap is an unverified operational limit, not a known
safe gas bound. Applying it to execution can reject a manager-executable exit.
Specify its effect on standalone compound and all money paths.

**Recommendation:** retain exact economic parity over a precisely documented
admitted domain; validate the work limit before ratifying 512, and explicitly
approve the resulting conditional-exit policy. If stronger exit availability
is required, revise the design before implementation.

Kimi prefers a narrowly defined collect-only exit fallback when the ratio
swap is not executable. That changes the confirmed baseline compound
sequence and needs explicit owner approval; do not describe skipping its swap/
reinvestment as unchanged mandatory baseline compounding.
MiniMax prefers conservative previews. A conservative output/error bound was
not supplied, and tick-crossing state is simulatable in principle; do not
replace exact parity with an unproved conservative guarantee.

### Q3. Approve spot basket accounting as SY's reporting policy?

The draft chooses a price-sensitive accounting value in one configured asset,
including principal, booked idle, and pending fees. That is distinct from a
withdrawal-and-sale quote and is not required by the settled architecture.

**Recommendation:** retain this simple reporting policy if the owner approves,
fix C1's raw units, define fee-growth inputs and rounding, and keep it out of
issuance. It is not an independent oracle or guaranteed exit proceeds.
No new `getRate()` surface is recommended in stage one.

### Secondary policy choices to record, not silently infer

| Choice | Proposed recommendation / limit |
| --- | --- |
| Positive-share burn with zero total payout | Reject; one-sided positive paired payout remains valid. This is an additional behavior choice, not already approved. |
| Small genesis and donation rounding risk without dead shares | Keep the confirmed no-dead/virtual-share decision. Establish risk bounds or explicitly accept the residual; Kimi's proposed immutable genesis minimum is an option needing owner approval, not a proven cure. |
| Donation and public compound while disabled | Keep exits and their mandatory compound available. Recommend allowing standalone compound but blocking new donation while disabled; the owner has not yet chosen this detail. |
| Unsolicited balances | Draft keeps them unbooked with no rescue. Make the consequence explicit; do not add a public adoption/sweep path that competes with pretransfer credit without approval. |
| Decimals metadata | Correct raw-unit rate arithmetic does not need decimals normalization. Pin whether `assetInfo` caches validated initialization metadata or queries it live; neither member preference is an owner ruling. |

Only Q1-Q3 need lead the next owner discussion. The secondary choices belong
in the same requirements revision, with proposed defaults clearly labeled.

## 5. Claims and suggestions not adopted as stated

1. **MiniMax R3/R14: inherited interface selectors.** Solidity defines
   `type(I).interfaceId` using selectors declared directly in that interface,
   excluding inherited functions. `IStandardExchange` is inheritance-only;
   it is not automatically the XOR of In and Out. SY's own interface ID does
   not include inherited metadata selectors. Independently declare the intended
   canonical interfaces; verify IDs through the repository workflow, and do
   not treat a combined inheritance-only marker as a route-capability bitmap.
   Keep the confirmed unsupported Out selectors; do not override the owner's
   choice based on MiniMax's erroneous ID argument.
2. **MiniMax R6: baseline refund deployment.** At `Baseline:221`, the
   reservation is changed to the refund remainder before addition; `_idle`
   subtracts that reservation (`Baseline:370-372`). The claimed premature
   release is contradicted by the source. Keep explicit reservation invariants,
   but do not report that alleged baseline defect.
3. **MiniMax R7: mandatory full SY redeem override.** Shared `_standardRoute`
   and `_redeemVaultHeld` are virtual seams. Native behavior needs correct
   internal dispatch; it does not necessarily require replacing the complete
   public redeem implementation and duplicating its validation/events.
4. **MiniMax R19: abandon/sweep terminal operation residue.** Owned
   operation-generated assets should not become unbooked or go to a dead
   address. The draft already assigns all booked assets to the last paired
   exiter. Do not create a new forfeiture policy or claim every rounding
   difference is stranded custody.
5. **MiniMax R13: reject wrapped-native donations on all ERC-20 pools.**
   If wrapped native is an actual configured ERC-20 pool currency, it remains
   a valid ordinary ERC-20 donation and must not be unwrapped. Only an alias
   for an actual native leg uses unwrap accounting.
6. **MiniMax R20: sequential mulDiv is universally full-precision conversion.**
   Two floors can differ from one mathematical floor, and an intermediate
   result can exceed uint256 even when a final result would fit. Pin the
   chosen arithmetic and domain; do not make an unsupported universal guarantee.
7. **MiniMax R10: 18 decimals as a baseline deviation.** PairToken already
   uses 18 decimals. Wings is only packaging context, so no deviation from
   baseline economics exists on that fact.
8. **Grok R13: no dead shares proves owner acceptance of all donation risk.**
   It does not. Do not reintroduce a sink, but still ask for objective risk
   criteria rather than infer blanket acceptance.
9. **Zero tick-movement limit disables every price-moving zap.** Tick movement
   and square-root-price movement are different; a swap can move within the
   same tick. Preserve the exact tick-based predicate, not that overstatement.

Interface-ID reference checked by coordinator: Solidity documentation,
Type Information, retrieved 2026-10-28 from
`https://docs.soliditylang.org/en/latest/units-and-global-variables.html`.
No private source was sent to this public documentation retrieval.

## 6. Traceability of all original recommendations

The references below disposition the whole original set, including suggestions
that reduce to ordinary specification precision rather than owner questions.

| Member recommendations | Draft treatment |
| --- | --- |
| Astra R1 | C1: adopt raw-unit correction. |
| Astra R2 | Q1: owner economic decision; no formula silently approved. |
| Astra R3 | Q2: projection domain and conditional exit semantics. |
| Astra R4 | C3: retain unchanged facets and committed shared snapshots. |
| Astra R5 | C5/Q1: include precise fee checkpoints; document baseline deviation. |
| Astra R6 | C4: native sync and actual proxy receipt path. |
| Astra R7 | C6: piecewise math, capacity domain, one-sided input rule. |
| Astra R8 | C5: operation ledger and staged-share-credit caveat. |
| Astra R9 | C6/Q2: typed ABI; parity excludes unavailable caller/recipient facts. |
| Astra R10 | Secondary policy: zero-output burns; clean empty compound no-op. |
| Astra R11 | Q3/C1/C5: explicit accounting policy and fee/rounding inputs. |
| Astra R12 | C6/section 5: complete manifest, canonical IDs, absent admin surfaces, package binding identity. |
| Astra R13 | C6: falsifiable outcomes and independent real-manager controls. |
| Grok R1 | Q1: private-inventory candidate, not yet validated final issuance math. |
| Grok R2 | C1/Q3: rate compatibility correction; policy remains separate. |
| Grok R3 | C2: adopt sorted registry identity correction. |
| Grok R4 | C6: canonical removal authority; no demonstrated interior mismatch or approved clamp policy. |
| Grok R5 | Q2/C5: state-machine definition; fee exclusion not adopted as blanket rule. |
| Grok R6 | C5: dissent on compound-generated fee snapshot retained. |
| Grok R7 | C5/C6: booked-only compound input and exact raw-unit dust/cap branches. |
| Grok R8 | C4/C5: native receipt/reservation/backing rules. |
| Grok R9 | C6: complete ABI, burn authority/order, typed errors and actual input deltas. |
| Grok R10 | C6/section 5: route errors and real canonical interface IDs; avoid speculative marker arithmetic. |
| Grok R11 | C6: precise pool/zap constraints and package identity; no new defaults. |
| Grok R12 | C3/C4: callback commitment and canonical unlock read; unguarded shared reserves cannot be made guarded unchanged. |
| Grok R13 | Secondary risk policy; reject inferred blanket owner risk acceptance. |
| MiniMax R1 | C1: adopt formula correction, not misleading title or extra owner question about arithmetic. |
| MiniMax R2 | C5: adopt ledger requirement; booking at settlement is technical completion, not an option to discard holder fees. |
| MiniMax R3 | Section 5: reject inherited-ID argument; preserve explicit unsupported route semantics. |
| MiniMax R4 | C6: finish ABI; do not mandate broad alias expansion. |
| MiniMax R5 | Q2: acknowledge simulator cost; do not adopt unsupported impossibility or conservative guarantee. |
| MiniMax R6 | Section 5: reject baseline defect; retain reservation clarity. |
| MiniMax R7 | Section 5/C4: correct native adapter, no mandatory full public-method override. |
| MiniMax R8 | Q1: adopt problem, reject incomplete subtraction formula. |
| MiniMax R9 | Verify zero fee-ID registration in implementation; no speculative fallback fee configuration authorized. |
| MiniMax R10 | Section 5: no new baseline decimal deviation. |
| MiniMax R11 | C6: pin canonical state reads/position identity; equivalent reads are preserved behavior, not unsupported scope. |
| MiniMax R12 | C6: use canonical extreme swap limits; no new policy question. |
| MiniMax R13 | C4/C5 and section 5: same-call donation deltas; distinguish actual ERC-20 wrapper leg from native alias. |
| MiniMax R14 | Section 5: reject inherited SY interface-ID claim. |
| MiniMax R15 | C2: use sorted registry identity, preserve pool face order separately. |
| MiniMax R16 | Document DUST=1000 raw units without declaring a branch universally disabled; no normalization approved. |
| MiniMax R17 | Add new-capability category to comparison ledger; useful editorial improvement. |
| MiniMax R18 | Document parameter coupling/tick predicate; reject universal zero-limit price claim. |
| MiniMax R19 | Section 5: reject terminal holder-asset abandonment. |
| MiniMax R20 | Section 5/C1: specify exact conversion math and failure domain without universal overflow claim. |
| MiniMax R21 | C6/Q1: objective predicates; do not adopt invalid fairShares formula or require a nonzero rate/exit difference in every rounded case. |
| MiniMax R22 | C4/C6: name TransientStateLibrary read and explicit unlock error. |
| MiniMax R23 | Secondary metadata policy: query versus cache is not resolved by absent shared mapping writers. |
| Kimi R1 | Q1: complete entrant attribution before coding. |
| Kimi R2 | Secondary risk decision: genesis minimum optional, not approved or sufficient by itself. |
| Kimi R3 | Q2: precise full projected state and work unit; no gas feasibility claimed. |
| Kimi R4 | Q2: fallback is a proposed departure from confirmed baseline compounding. |
| Kimi R5 | C4: adopt explicit native sync. |
| Kimi R6 | C5/C6: reservation ledger and common preflight ordering. |
| Kimi R7 | C1/Q3: define input fees/rounding; correct rate units; metadata cache preference not approved. |
| Kimi R8 | C3: guard new family views, not unchanged shared reserve/token selectors. |
| Kimi R9 | C6: exact piecewise canonical math and equivalence controls. |

## 7. Proposed next action and advisory scope

Do not implement yet. Present Q1-Q3 to the owner, distinguish C1-C6 technical
corrections from economic/liveness policy, then make a separately authorized
PRD revision with exact equations and new acceptance rows as required.

For this advisory pass, review this frozen draft only. Return one disposition,
material corrections, significant original recommendations not fairly
represented, and limits. No new research, source reads, peer reads, file edits,
or additional council rounds. Feedback does not replace the member's original.
The coordinator will archive each exact inline advisory response and resolve
it in a separate final report without altering this reviewed draft.
