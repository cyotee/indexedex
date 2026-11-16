# Independent T5-EGRESS verification

Date: 2026-11-10.

**Verdict: needs-fix.** The native-principal / retained-gon ledger survives the bounded independent arithmetic checks below, including successful mature-principal exit and later reward payment. The complete construction does not yet satisfy its production SY integration boundary. Three concrete counterexamples concern the actual vendored Pendle reward consumer and redemption callers, not disagreement with the construction's own equations.

Reviewed construction: `egress-contract.md`, revision `t5-egress-principal-sy-r1`, all 701 lines. SHA-256 of the complete text returned by `read`: `5104e78908e38274c987b7e8dfcd2e291373d984c78d919908a5f11f4bcb0506`. This identifies inspected source text, not deployed bytecode.

This verdict does not close T5-EGRESS, task 5, or runtime E5 acceptance. It does not reopen the accepted principal/reward requirement, settle E1/E2/E3 or BOOTSTRAP-AUTH, authorize implementation, or modify an upstream report.

## 1. Findings, highest impact first

### F1 - The proposed standard reward index produces unfunded native reward claims in the actual consumer

**Location:** construction sections 6.5 and 7, `rewardIndexesCurrent/Stored() = [Q-k]`, with `getRewardTokens() = [sDETF]`.

**Source observation:** `IStandardizedYield.sol:120-122` does not itself state a reward-index unit. The actual consumer does:

- `K/protocols/perps/pendle/core/YieldContracts/PendleYieldToken.sol:479-495` treats reward shares as SY amounts and takes the indexes directly from SY.
- `K/protocols/perps/pendle/core/RewardManager/RewardManagerAbstract.sol:44-64` initializes an unset user index to 1, calculates `deltaIndex`, and credits `userShares.mulDown(deltaIndex)` into a **native reward-token amount**.
- `K/protocols/perps/pendle/core/libraries/math/PMath.sol:20,34-38` defines that multiplication as `floor(a*b/1e18)`.
- `PendleYieldToken.sol:443-476` attempts to pay that recorded native amount, calling the SY's `claimRewards(address(this))` if its reward inventory is insufficient.

**Executed counterexample, production Q:**

1. Stake and wrap 10 native DETF units for a YT-contract holder at `Q = 10^36`.
2. Actually fund 10 units. The allocation is exact in this vector; `k = 5*10^35`.
3. The construction exposes `index = Q-k = 5*10^35`.
4. For 10 reward shares and the consumer's initial index of 1, the consumer records:

   `floor(10 * (5*10^35 - 1) / 10^18) = 4,999,999,999,999,999,999` native sDETF.

5. Activate and execute the model's real custody-moving SY claim. It releases **10**, not that consumer liability.

The discrepancy is not a display-only decimal issue. Paying the consumer's recorded amount cannot succeed from this funding. The model does not claim a deployed exploit; it executes the read consumer expression against a reachable funded state.

**Narrow correction direction:** keep exact gons inside the Migration ledger, but replace the proposed standard reward-index contract with a consumer-compatible reward-accounting boundary. Specify the standard index unit, initial sentinel, native payouts, retained fractions, and rebasing treatment together. A constant scale change to `Q-k` is not a complete fix: old attached reward gons appreciate, cohorts acquire different gon bases, and F2 remains even if the first accrual is numerically perfect. Do not freeze the new SY ABI/declarations on the premise that unchanged selector signatures establish compatibility.

### F2 - Attached rewards following SY shares invalidate the consumer's retained reward claims

**Location:** construction sections 6.3 and 6.5: share transfers convey proportionate previously accrued reward gons, while the standard reward API exposes those same rewards to a downstream reward ledger.

**Source observation:**

- `PendleYieldToken.sol:124-127` explicitly separates PY redemption from interest/reward redemption.
- `PendleYieldToken.sol:317-339` burns PT/YT and transfers SY to the supplied receiver without paying or cancelling each former holder's recorded rewards.
- `PendleYieldToken.sol:498-503` and `RewardManagerAbstract.sol:35-64` accrue rewards before YT balance changes. Recorded rewards survive the share redemption.
- The existing reference SY instead checkpoints reward ownership before token transfer: `K/protocols/perps/pendle/core/StandardizedYield/SYBaseWithRewards.sol:74-95`.

**Executed ownership counterexample:** isolate ownership from F1 by granting the consumer a *perfect* native reward accrual.

1. The YT contract holds 10 principal SY shares; funding creates 10 native units of attached reward.
2. The old YT holder has a recorded claim for those 10 rewards.
3. That holder transfers/burns its PT/YT and directs the resulting 10 SY to a different receiver, as the production `_redeemPY` permits.
4. Under construction section 6.3, all attached reward gons accompany those SY shares.
5. `claimRewards(YT)` can now release **0** from the emptied SY slot. `claimRewards(newHolder)` releases **10**. The old user's downstream reward ledger still records **10**.

This does not mint two funded receipts. It creates two representations of the economic claim, of which the old recorded one has lost its backing. F1 can amplify the failure but is not its cause.

**Narrow correction direction:** define one reward-ownership settlement boundary for standard consumers. Already-accounted rewards must remain with the consumer's recorded beneficiary when its principal SY leaves; they cannot also travel inside the transferred share packet. Reconcile this at the Migration SY/consumer adapter boundary before fixing storage and final bindings. Keep transferable **locked rights** available as rights, but do not expose one attached right simultaneously as a standard retained reward claim and as a transferable share benefit. No owner decision is needed to prohibit double attribution or loss of accrued ownership.

### F3 - The internal-burn extension is insufficient for actual multihop callers

**Location:** construction sections 6.3 and 7, ticket `(actual msg.sender, from)`, old `redeem(...,true)` restricted to `(caller,caller)`, and proposed `redeemInternal(owner,...)`.

**Source observation:** the construction's 63-file `contracts/**/*Router*.sol` search correctly found no local matches, but does not cover the relevant vendored callers:

- `K/protocols/perps/pendle/router/ActionMiscV3.sol:18-23` calls `_redeemSyToToken(...,true)`.
- `K/protocols/perps/pendle/router/base/ActionBase.sol:94-103` pulls `user -> SY`, then calls old `SY.redeem(...,true)`.
- `ActionMiscV3.sol:39-46` instead redeems PY **to the SY address**, then calls `_redeemSyToToken(...,false)`.
- `ActionBase.sol:117-129` calls `YT.redeemPY(receiver)`. The actual SY transfer is made by YT in `PendleYieldToken.sol:329-332`, not by the router or end user.
- The same upstream-push pattern exists for a market: `ActionAddRemoveLiqV3.sol:307-323` sends burned-LP SY to SY; `ActionSwapPTV3.sol:43-55` requests swap output at SY.

**Executed caller counterexamples:**

| Path | Ticket actually created | Why egress fails |
| --- | --- | --- |
| Router pulls Alice's 5 SY into SY | `(router,Alice)=5` | Old redeem checks `(router,router)=0`. |
| Same direct pull, router uses new `redeemInternal(Alice,...)` | `(router,Alice)=5` | Succeeds in the model; Alice retains the detached reward. This is the limited case the proposed extension solves. |
| YT pushes 5 SY to SY, router performs onward redemption | `(YT,YT)=5` | Both old redeem and `redeemInternal(YT,...)` by router fail. `(router,YT)=0`; `(router,Alice)=0` as well. |
| Router directly funds a deposit with `receiver=SY` | `(router,router)=5` | Caller-owned old internal redeem succeeds. Not every router operation fails. |

The third row cannot be repaired merely by passing the original share owner into the new selector. Even that owner has not authorized this operator through the proposed ticket-producing call. Inferring owner from payout receiver would reintroduce the attribution bug.

**Narrow correction direction:** complete a typed, authenticated internal-custody handoff for the actual upstream YT/market -> SY -> router graph, with the principal-spending operator and reward beneficiary fixed independently. Name the exact adapter call sites and minimal necessary ABI before declaring this path supported. Keep arbitrary aggregate-self-balance spending forbidden. Replacing only the final `redeem` selector is demonstrably insufficient. This is an engineering integration correction, not permission to add an owner-rescue method, mutable arbitrary executor, or new entitlement policy.

### Scope of these findings

These are source-backed compatibility failures of the proposed new representation. No current Migration deployment, market registration, exploit transaction, or external router acceptance is claimed. The construction already disclaims installed router acceptance; that disclaimer does not supply the missing compatibility contract requested for freezing the complete construction.

The constant `exchangeRate = 1e18` is **not independently rejected**. `IStandardizedYield.sol:95-101` and `SYUtils.sol:5-20` permit correct 1:1 principal conversion if reward assets are accounted separately. The issue is the complete reward/caller contract, not a claim that every SY must appreciate or that the interface itself says indexes are WAD.

## 2. Authority, inspected inputs and source map

Work was confined to the phase-03 worktree for authored files. The explicitly required main-checkout continuation brief, its original phase brief, and its designated complete main-checkout implementation plan were read as instructions; the plan does not exist at the worktree-relative incident path. No other lane's report or code was changed.

Read completely: the continuation and original phase briefs, `implementation-handoff.md` (374 lines), `egress-contract.md` (701 lines), the implementation plan, and the producer's `evidence/egress/model.mjs`, `vectors.mjs`, and `results.md`. Loaded repository routers, assistant coding/deployment/testing rules, applicable DETF agent law, canonical Crane architecture/deployment/testing/adversarial guidance, IndexedEx testing/adversarial guidance, and Bun/JavaScript arithmetic-script guidance. Migration-specific accepted requirements override ordinary linear-bond, immediate-role-payout and full-account-retirement defaults.

Primary requirements: Plan MIG-P07/P08/P11, sections 4.1, 5.5, 6.1, task 5 and section 8.2; handoff sections 4.3-4.4. These require both successful mature principal access and retained funded rewards. They do not permit an all-revert substitute.

All aliases below are exact prefixes under `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-03/`:

| Alias | Prefix |
| --- | --- |
| `C/` | `contracts/vaults/detf/common/` |
| `D/` | `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/` |
| `K/` | `lib/crane/contracts/` |
| `P/` | `lib/crane/contracts/protocols/perps/pendle/` |

Short file labels in the coverage tables resolve as follows: `BondTarget` is `C/bondNft/DETFFundedBondTarget.sol`; `StakedTarget` is `C/claimToken/StakedDETFTarget.sol`; `SYTarget` and `SYRepo` are `C/sy/DETFSYTarget.sol` and `C/sy/DETFSYRepo.sol`. `D/Target`, `D/Common` and `D/MaintenanceTarget` mean `D/UniswapV4DetfTarget.sol`, `D/UniswapV4DetfCommon.sol` and `D/UniswapV4DetfMaintenanceTarget.sol`. Other unprefixed filenames refer to their fully qualified source-map or finding entry.

Every production anchor used here was independently read:

| Concern | Source |
| --- | --- |
| Canonical units, floor allocation, funded ceil rebase, bond deficit | `C/core/DETFFundedStakingMath.sol:9-12,46-94,97-123` |
| Physical gons, backing, dust, principal issue and ordinary destructive fraction paths | `C/claimToken/DETFFundedStakingRepo.sol:24-36,52-64,93-139,148-156,185-234` |
| Receipt public routes, allowance, exact funding, synchronization | `C/claimToken/StakedDETFTarget.sol:34-38,112-124,147-253` |
| Persistent standing weights | `C/core/DETFSeigniorageShareLib.sol:18-33` |
| Funded bond creation, claims, delivery, fraction retirement | `C/bondNft/DETFFundedBondTarget.sol:94-130,139-208`; `C/bondNft/DETFFundedBondRepo.sol:46-70` |
| NFT transfer and actual pre-mutation callback | `C/bondNft/DETFFundedBondTarget.sol:220-252`; `K/tokens/ERC721/ERC721Repo.sol:153-169` |
| Bond donations and protected staking assets | `C/bondNft/DETFFundedBondTarget.sol:212-218,260-309,327-389` |
| Ordinary SY acquisition, internal burn, direct receipt output, routed output and minimum | `C/sy/DETFSYTarget.sol:54-121,147-180,196-256` |
| Wrapper identity, mode, routes, shared backing fields, initialization | `C/sy/DETFSYRepo.sol:15-23,38-69`; `C/sy/DETFSYDFPkg.sol:41-51,66-74,99-117`; `C/sy/DETFSYDeploymentLib.sol:15-27` |
| Parent branch selection, stake/unstake, payout budget | `D/UniswapV4DetfTarget.sol:200-230,261-324,344-374,410-477` |
| Parent funding, epoch consumption, locked-child exemption, ordinary sweeps | `D/UniswapV4DetfCommon.sol:314-325,349-385,483-544`; `D/UniswapV4DetfMaintenanceTarget.sol:16-27,30-62` |
| Allowance and permit authority | `K/tokens/ERC20/ERC20Repo.sol:157-166,297-301`; `K/tokens/ERC2612/ERC2612Target.sol:39-58` |
| Selector ownership and lifecycle removal | `K/introspection/ERC2535/ERC2535Repo.sol:104-116,245-270`; factory/proxy anchors in section 5 |
| Consumer semantics | Full interface and the concrete source ranges in F1-F3 |

Text fingerprints confirm preparation's consumed `_calculateClaim`, `_claim`, and `_distributeRewards` seams were present:

| Read source | SHA-256 of `read` text |
| --- | --- |
| `C/claimToken/StakedDETFTarget.sol` | `fed9bd4bf324c8e1c3d71e1809c3ae516320d05beb580085b2deedb83bb24f82` |
| `C/bondNft/DETFFundedBondTarget.sol` | `ff3c95b45adec74973aabcb874be2a8d86aa79a9af8770949b0b7e635fbcc360` |
| `C/sy/DETFSYTarget.sol` | `245a0a49e045c663c432391bafd2efd3d6778e71ae5e9b18e8855e7c9bc749c2` |
| `P/core/RewardManager/RewardManagerAbstract.sol` | `f7722ffad4b1093ef8004b27195da428c7c6057d1b72681600bf416cd9268be4` |

LSP reference lookup timed out. Direct reads and bounded content searches supplied the consumer evidence; absence from one search was not treated as absence from the repository. No fresh clean LSP result or Solidity compilation is claimed.

## 3. Independent arithmetic evidence

Owned evidence is solely under `evidence/egress-verification/`:

- `reference.mjs`: independent aggregate ledger storing **total entitled gons per slot**, not the producer's `lastK + attachedRewardGons` representation.
- `sequences.mjs`: bounded positive and negative operation sequences.
- `compatibility.mjs`: concrete consumer counterexamples and explicitly conditional phase/custody checks.
- `run.mjs`: reproducible combined runner.
- `results.md`: observed execution results and limits.

The reference does not import the producer's model. For a SY slot it derives reward entitlement as `heldSlotGons - principalShares*k`, and checks the proposed lazy `s*lastK+r` decomposition against that independent representation. It checks total physical entitlement, backing versus native dust, remaining principal coverage, internal ticket totals, and external input minus actual native withdrawals after successful sequences.

### Observed positive witnesses

| Witness | Executed result |
| --- | --- |
| Mature principal -> different recipient -> later rebase -> partial/full exit -> further funding -> activation | 10 principal paid before activation. Original bond retains `5*10^36` gons; claimant retains a different `10^36` gons. Later payments are 25 and 5 respectively, immediate repeat zero. All 40 funded units are paid; backing is zero. |
| Wrapper mixed deposits, every split including zero/full, rebase, transfer back, partial/full exits, same/different receiver | **4,320** sequences at `Q=1000` and `Q=10^36`, principal 1..12, two funding magnitudes, three output-budget branches, both external/internal sources and two receiver identities. Aggregate successful principal budgets: **47,904** native units. |
| Minimum-output failure after checkpoint/burn/detach and simulated funding | **4,320** transactional rollback checks. Model restores the whole snapshot; this assumes EVM atomicity, rather than proving deployed exception propagation. |
| Receipt Alice -> parent -> mixed Bob, allowance, self/zero transfer | All 30 principal units exit. Alice/Bob retain 4,600/2,300 gons at readable scale. Maximum allowance is decremented by 7; owner-as-spender self-transfer consumes its allowance. Failed over-principal spend rolls back. |
| Role capture, same beneficiary, changed roles, activation, active distribution | Shared old role beneficiary retains 1,581 gons and receives 4 at the later index. Subsequent active ordinary recipient gets 4 liquid units; protected SY beneficiary gets 530 separately attributed gons, not user principal. |
| Standing-weight-only participation after all principal leaves | `T=0` but fee weight is 10,000. A real 10-unit funding creates 10,000 retained role gons, later released and unstaked successfully. Total principal-plus-reward paid is 20 and final backing/gons are zero. Empty participation is not equivalent to zero liquid principal. |
| Two owners' internal tickets held by one router | Alice/Bob retain 2,000/3,000 reward gons after 10 principal units leave. Neither ticket borrows from the other. Voluntary domain-2 assignment then releases 10, once, with zero remaining backing. |
| Final bond fraction, owner differs from payout recipient | Recipient gets 8; NFT owner retains exactly 776 gons, initially below one native unit. Later actual funding permits payment of 2 to that owner. One allocation-dust unit remains accounted. |
| Activated full displayed-balance withdrawal | Eight native units leave; 776 wallet gons remain and are checkpointed intact into the same owner's deferred account. |
| Donations and smallest representable divisor | 999 unsolicited DETF units never become basis. At `k=1`, another 50 funded units remain canonical staking dust. Principal and 999 reward units exit correctly; unsolicited inventory stays separate. |
| Raw SY budget branches | **72** bounded arithmetic cases cover 1..12 shares, both burn modes, raw/receipt/configured-output budget shapes. No wrapped yield or reward ledger is invented. |
| Real consumer compatibility | F1 native over-accrual, F2 lost downstream reward backing, and F3 wrong operator tickets reproduced. A direct ticket-aware adapter and a router-funded self-deposit also succeed; these are not all-revert witnesses. |

### Derived conservation and ownership obligations

1. A funded distribution allocates `f+Da` through the actual `10^54` floor, rebases pre-existing gons with the actual ceiling divisor, then issues role gons at the resulting index. Therefore `B=floor(T/k)+Da+Ds` is preserved. Roles receive no reward on their own newly issued allocation. This matches the source order, not a simplified percentage model.
2. `floor((T-n*k)/k)=floor(T/k)-n`. Every exact native principal withdrawal can reduce backing by `n` without consuming someone else's fractional gons or changing native dust.
3. A Stage-1 wallet checkpoint moves exactly `G-P*k` into that wallet's deferred account. Transfers move `n` basis with `n*k` gons. Allowance cannot authorize more basis. Thus growth cannot become new principal merely by changing wallet, approved operator, parent intermediate or raw wrapper.
4. For a bond principal claim at `kc`, later wallet growth is `p*(kc-k)`. The original bond was already debited by `p*kc`. Counting the two remaining gon holdings separately is necessary; neither is a second copy of the original principal.
5. A SY packet is `x*k + floor((slotGons-s*k)*x/s)`; full consumption takes the exact remainder. Moving that packet preserves total gons; exit detaches its reward part and spends only its principal part. This works internally, but F2 prevents treating it as already-compatible standard consumer reward ownership.
6. Deferred payout debits `floor(R/k)*k` before delivering already-issued receipts. At unchanged `k`, the remainder is below one unit and a repeat pays zero. New funding or an authenticated additional right is needed for another positive payment.
7. Activated full displayed-balance withdrawal must still burn only `n*k`, leaving the modulus. The common source's full-account branch and `retireEscrowDust(nonzero)` cannot remain alternate Migration routes.

The finite sequences support these specific invariants; they are not exhaustive uint256 verification. One explicit over-limit `n*Q` is rejected by the model. Aggregate addition limits, gas, compiler behavior and all possible overflow states still need production tests.

## 4. Required operation-path coverage

Legend: **supported arithmetic** means the construction's internal ledger has positive bounded evidence, not deployed acceptance; **source-conditioned** means the current call path was traced but its proposed replacements were not executed; **fails compatibility** refers to F1-F3.

| Required path | Finding and coverage |
| --- | --- |
| Bond create, unlock-1/unlock/unlock+1, principal-only | Supported arithmetic, with actual start and 90-day cliff. Current parent-only exact pull/stake/delta path is reusable (`BondTarget:94-130`); no test issuer or old timestamp was substituted. Genuine Migration issuance integration remains unrun. |
| Rewards-only/combined before activation | Whole rejection required even when principal is mature. No state persists under the model transaction. A principal-only success is separately demonstrated. |
| Bond reward-only survivor and final fraction | Reward gons stay on the NFT until paid; only sub-native final residue moves to current NFT owner, not an arbitrary claim receiver. Positive final-fraction witness executed. |
| Three NFT transfer selectors, operator, safe receiver | Transfer conveys remaining clock/principal/gons, not payout. Source calls receiver before ownership mutation. Phases must span that callback; no current owner identity can be inferred from an assumed post-transfer callback. |
| Receipt direct stake, parent stake, mixed recipient | Exact actual DETF funds `n*k`. Stage-1 old recipient growth is detached before credit. Parent `_stakeHeld` must keep exact approvals and normal receipt policy (`D/Target:344-361`). |
| Receipt exact-input/exact-output unstake | Same native basis cap; exact-output max cannot buy access to rewards. Source direct selectors both use `_exchange` (`StakedTarget:147-166,200-224`). Native minimum/max/deadline/zero/pretransfer checks remain. |
| Receipt transfer/transferFrom, self, zero, max allowance | Supported arithmetic. Source allowance always decrements, including max; permit changes that ledger only, not reward ownership or spendability. Cryptographic permit replay/domain validation was read but not executed. |
| Parent intermediate receipt -> raw or configured output | Parent first pulls receipt into its own account (`D/Target:364-374`); therefore it must receive the same principal packet, not reclassify its full balance. Normal parent receipt inventory is not a privilege. Both primary-burn and swap output branches retain the operation's budget. |
| Parent Stage-1 ordinary external acquisition and bonding | Must reject before primary/swap selection (`D/Target:200-230,261-279`). Source-conditioned proposed gate; arithmetic model does not create a working parent implementation. |
| Staking SY direct DETF / receipt deposit | Supported arithmetic for exact principal. Direct receipt pull is by wired SY, no user-supplied custodian. Actual gon delta, not rebase-inflated native delta, determines newly acquired inventory. |
| Staking SY configured external acquisition | Source-conditioned; reject Stage 1, acquire first then pin final index when activated (`SYTarget:196-217`, `D/Target:302-304`). Producer's final-index rule is necessary because issuance can fund a distribution. |
| SY external share transfers, mixed holders, proportional split/merge | Supported internal arithmetic. Existing shared ERC20 helpers alone cannot maintain slots. Standard consumer compatibility fails F1/F2. |
| SY caller-owned internal burn | Positive model coverage. Self deposit and self transfer create `(caller,caller)` ownership; no stranger can spend aggregate self balance. |
| SY approved-router internal burn | Direct pull plus `redeemInternal(owner,...)` succeeds; old router call fails. Actual YT/market upstream-push chain remains unsupported even with that new final selector (F3). |
| Staking SY -> sDETF output | Exact principal only through typed `transferSyPrincipal`; recipient receives basis and can actually unstake it. Attached locked rewards go to source owner, not receiver/router. This bypasses parent, so receipt/SY policies themselves must enforce it. |
| Staking SY -> DETF output | Exact `x*k` burn through authenticated receipt withdrawal. No ordinary full-account retirement or SY dust clamp. Positive principal exit in both burn modes. |
| Staking SY -> every other configured tokenOut | Three-way source dispatch inspected (`SYTarget:220-242`, `D/Target:410-477`). Model verifies budget isolation and minimum rollback only. **Unproved:** real configured pool outputs, fees, decimals, primary/swap liquidity and min-out propagation. No actual Migration `getTokensOut` set exists here to certify exhaustively. |
| Raw SY deposit/transfer/internal source/redemption | Raw backing equals principal shares, no automatic rewards. 72 budget cases. sDETF routes are conditional on actual configuration, not default raw-SY routes: `SYRepo:49-56` automatically adds receipt only to staking mode. Receipt acquisition/output must use parent principal-aware paths. |
| SY `claimRewards`, accrued view, zero-share detached residue | Positive activated detach/release and repeated-zero checks; preactivation rejects. Native accrued ownership is coherent within this wrapper. Standard indexes/consumer claims fail F1/F2. |
| Deferred wallet/SY assignments | Exact gons, owner-authorized, domains 0/2 only; no liquid payout or basis creation. Transferring a locked right is not activation. Role domain remains fixed and nonassignable. |
| Fee/creator allocation, owner change, identical beneficiary | Captured domain-1 gons retain identity and participation. Same-address addition and later changed recipient are covered. Active ordinary delivery and protected-custodian escrow are covered arithmetically. |
| Protected contract role recipient | Separately attributed, not a user's principal or a wrapper surplus. The construction intentionally offers no generic executor for that contract's own gift; this is not demonstrated eventual payout liveness for a contract lacking a callable claim path. No admin rescue is inferred. |
| Donations, idle inventory, budgeted sweeps | No principal from gifts. Bond already rejects receipt donations and protects principal/receipt sweeps (`BondTarget:212-218,337-338`). Migration must replace inherited whole-balance parent sweep use, including internal/self-call paths (`D/Common:483-544`). Model proves only its excluded-surplus budget assumption. |
| Native allocation/rebase dust and owned fractional gons | Kept distinct. Sub-native rights survive full principal exit and later funding; they are never rounded into protocol dust. At `k=1`, more funding becomes native dust, not an index reset. |
| Activation and exact-once release | Activation moves no balances, resets no clocks/index and scans no holders. Positive before/after witnesses plus conditional busy-child checks; actual cut/loupe/callback acceptance remains unrun. |

No new owner-policy question is raised by this review. The already-open bootstrap authority and legacy/pricing gates are independent. Lack of a production witness is labelled unproved rather than converted into a product choice.

## 5. Call-order, cross-proxy and implementation-boundary assessment

### Locks and callers

The proposal correctly identifies a required ordering that simple per-proxy `nonReentrant` cannot supply. The modifier locks only the current proxy's namespace (`K/access/reentrancy/ReentrancyLockModifiers.sol:21-29`).

- Receipt synchronizes **before** local lock. Parent reward funding is allowed to enter receipt while its outer phase is Synchronizing; save and restore the previous phase. Restoring Idle would expose a callback window. Conditional model checks cover prior Idle and Synchronizing, and reject nested public mutation.
- Parent settles before adding new bond/receipt participation. The actual locked-parent no-op is restricted to wired receipt and bond (`D/MaintenanceTarget:16-27`); it cannot be expanded to arbitrary SY callers or treated as settlement.
- Bond claim must debit position and aggregate attribution before `deliverBondClaim` / `deferCustodyRewards`. Receipt then checks the caller's **post-effects** attribution. Checking old attribution after moving physical gons would reject a valid delivery. The same ordering applies to SY packet debit before detach and principal debit.
- SY redemption first synchronizes, then fixes/debits the full source packet, then detaches reward gons and pays principal. Typed custody calls validate `expectedK`; the existing receipt withdrawal itself still synchronizes. The parent admission logic must permit that genuine wired-receipt sync inside SY's phase while preventing an independent hostile economic operation from changing the pinned index. This is an installation obligation, not something the scalar model proves.
- Safe NFT receiver sees old ownership. Callback-owner activation is rejected while any fixed child's phase is busy. Sixteen child/phase combinations are checked conditionally; the guarded callback's caller and current owner still need actual proxy execution.
- Keep bond-first donation -> parent join/notify composition. Pre-locking the parent's forwarding facade would deadlock the authorized cycle (`BondTarget:364-377`, `D/MaintenanceTarget:30-43`).
- Parent's ordinary ERC20 transfers/allowances must remain usable while funding and paying backing. Treating every parent ERC20 call as a lifecycle/economic entry would deadlock the receipt's own backing pull.

No concrete bypass of the *specified* principal guards was found in the bounded closed-stage sequences. This is conditional on the phase and custody checks being installed on all selectors, including inherited ones; they are not present just because the report names them.

### Activation routing

The proposed local removal direction is compatible with the read primitive: `_diamondCut` processes cuts and only delegatecalls when nonempty init data and a nonzero target are supplied (`ERC2535Repo:104-116`); `_removeFacet` checks actual owning facet and clears mapping (`:245-270`). There must be no external callback between removal and finalized activation.

The factory's existing-address path returns before initialization, but its stored package context persists (`K/factories/diamondPkg/DiamondPackageCallBackFactory.sol:201-231,407-410`). Base cuts install only the ERC8109 query plus temporary postDeploy (`:261-309`). `PostDeployAccountHookFacet.sol:19-22` delegatecalls its caller; factory completion removes that route (`DiamondPackageCallBackFactory:425-451`). Proxy resolution reads its own selector map (`K/proxies/MinimalDiamondCallBackProxyResolution.sol:24-26`).

These facts support the proposed proof boundary: audit reachable delegatecall/routing edges, not merely the activation flag or the factory's function names. They do **not** prove that an as-yet-unbuilt Migration facet contains the complete removable selector set. Actual fixed owner authority, failed-cut rollback, completed proxy loupe, no callable initializer and post-activation restoration attempts remain runtime obligations.

### Every proposed storage/API group

| Proposed group | Minimal source boundary and assessment |
| --- | --- |
| Receipt basis, `deferredGons`, total, phase; `egressState`, getters, checkpoint, assignment and public release/role alias | Implementable in new namespaced Migration Repo/Target/Facet with canonical common gons/backing retained. Queries must special-case escrow/bond/SY rather than interpret protected inventory as wallet growth. No beneficiary scan, second token or duplicate backing authority is necessary for this internal ledger. |
| `deliverBondClaim`, `deferCustodyRewards`, `transferSyPrincipal`, `releaseSyRewards` | Implementable as exact wired-caller methods with no arbitrary `from`, index equality and post-effects attribution queries. Update actual custody, not just a bookkeeping receipt. Bond/SY-only authority is not granted by an allowance or external caller-supplied phase. |
| Existing receipt transfer/withdrawal/credit/retirement selectors | Need real overridable dispatch or replacement targets in `C/claimToken/StakedDETFTarget.sol`. Present external methods and `_exchange` are not virtual; inheriting a new internal policy name alone cannot replace compiled ordinary behavior. Existing implemented distribution seam at `:186-189` is usable. Keep ordinary Repo math unchanged. |
| Bond cliff flag, phase, claim policy, exact residue | New Migration storage with existing position/aggregate fields authoritative. Preparation's `_calculateClaim` and `_claim` are virtual (`BondTarget:146-149,173-198`); current `_retireIfPaid` is not (`:200-208`). Override the complete claim or expose the narrow delivery/retirement seam. Replace all three guarded NFT transfer selectors, as common package does at `C/bondNft/DETFNFTVaultDFPkg.sol:83-92`. |
| SY external/internal slots, tickets, phase, `internalSharesOf`, `internalSpendSharesOf`, `attributedSyGons`, `redeemInternal` | Internal representation is implementable using existing ERC20 external balances and common `backingGons`, without duplicate external share counts. New slot and ticket transitions require replacement of concrete transfer/deposit/redeem paths, not just extra getters. Complete integration is blocked by F1-F3. |
| SY standard reward methods, rate, previews and declarations | Constant principal rate is possible; current target's empty rewards/static-gon conversion cannot be reused unchanged (`SYTarget:124-180`). F1/F2 require a revised concrete standard adapter contract, not only a declaration change. Neither a gon unit annotation nor a new final redeem selector resolves the observed consumers. |
| `attributedBondGons` and four child `migrationAccountingPhase` views | Narrow new read selectors; bind to actual current child storage. Add no setter. Parent admission uses fixed initialized identities, not an allowlist supplied by the caller. |
| Package selection and declarations | Existing receipt/SY packages select real facets in constructors. Declaration functions are non-virtual (`RebasingClaimTokenDFPkg:76-85`, `DETFSYDFPkg:66-74`, `DETFNFTVaultDFPkg:68-75`): minimal declaration extensibility must accompany actual selected interfaces. Ordinary target selectors must not survive as alternate Migration paths. |
| Parent policy facets, final child binding, baseline, budgets and activation | Concrete seams needed in `D/UniswapV4DetfCommon.sol` and `D/UniswapV4DetfTarget.sol`, as handoff specifies. Current postDeploy wires bond, receipt and both SYs (`D/UniswapV4DetfDFPkg.sol:227-238`). Final immutable composition must wait for the corrected SY contract; no ordinary child placeholder is acceptable. |
| New exact-gon events and errors | Implementable in Migration interfaces, preserving native events and making fractional attribution reconstructable. Event/selector declarations, bytecode size and actual proxy routing have not been compiled or verified here. |
| Actual required consumer adapters | **Missing from the proposed complete boundary.** F3 requires more than adding `redeemInternal` to each local wrapper; the upstream sender/operator/beneficiary graph must be specified. F1/F2 require reward accounting at the standard-consumer boundary. Shared read-only Crane is not implicitly authorized for edits by this finding. |

The claimed internal storage can therefore be implemented without a global staking-math rewrite. The complete ABI/API contract cannot yet be frozen within the report's named boundaries while also claiming the inspected standard consumers are supported.

## 6. Resolution, unproved cases and cleanup

**Required correction:** revise only the Migration SY integration portion of the construction to reconcile native reward-index consumption, reward ownership when SY leaves a standard consumer, and upstream-push internal redemption authority. Preserve the working exact native principal packets, deferred gon ownership, source-only custody, mature exits and exact-once release. Supply positive source-derived consumer sequences, not just more self-consistency splits. Do not replace these obligations with a blanket pause, hidden adapter assumption or an owner-policy question.

The alternatives rejected by this review are: approving solely from the 648 producer cases or the 4,320 independent cases; labelling `Q-k` WAD without following the consumer; repairing only the final router selector; treating locked-right transfer as payout; destroying residual gons; and demanding a policy decision for an engineering mismatch already constrained by retained ownership and standard integration.

Explicitly unproved here:

- Production Migration selector installation, complete phase enforcement and cross-proxy reentrancy resistance.
- Actual configured reserve/SE outputs, primary/swap route behavior, min-output token rollback, supported adapter gas and overflow bounds.
- Cryptographic permits, registry/factory deployment, source bytecode binding, ownership/activation cuts and restoration attempts.
- Full operational E1/E2, actual recovery E3, BOOTSTRAP-AUTH, E4 and E5.

The user prohibited Forge, production/test/config edits and delegation in this lane. None ran. Arithmetic uses no mocks presented as production tests and makes no runtime E5 claim.

**Cleanup:** authored files are only this report and its own `evidence/egress-verification/` artifacts. No dependencies, caches, node/RPC listeners, worktrees or temporary data directories were created. Shared `out/`, `cache_forge/`, node_modules and Crane were left untouched. The finite arithmetic launcher attempts and their observed terminal statuses are recorded in `results.md`; no standing monitor or background runtime is needed by the deliverable.
