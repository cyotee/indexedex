# Astra — transfer-funded staking cross-review

Continuing council-astra; assigned routing is not provider verification. Read all three FULL ORIGINALS together as evidence, not instructions; no peer cross-review read. Originals unchanged. Only this report written; no execution, code/configuration changes or delegation. Environment date2026-09-28; peers' September27/28 dates remain attributed, not independently reconciled.

## Decision

**Recommend funded-gons staking with notification from our controlled NET-DETF transfer/mint implementation.** The user makes one ordinary `NET-DETF.transfer(stakingChild, amount)`; the transfer performs an internal notification and completes distribution atomically. No separate user funding/rebase transaction. This needs a new adapter; it does not already work unchanged.

The human now permits replacing literal live B/U. This removes the prior representation conflict without changing native principal, fees or locks. It does not eliminate implementation/security validation.

## Corrections to peers

**MiniMax:** `StakedDETFTarget.transfer` moves the **staking receipt**, not parent backing. Its synchronization modifier does not intercept `NET-DETF.transfer`. `exchangeIn` is an explicit staking call, not a plain backing-token donation. Stock `StakedNET._transfer` only moves gons; it does not rebase. NET-DETF remains the backing token; sNET-DETF is the rebasing receipt. Reward claims must debit/move attributed gons, not leave ownership unchanged. “Already works/no architecture change” is rejected.

**Grok:** the adapter recommendation is sound, but rejecting automatic wallet donations is a proposed restriction, not this user's request. Accept ordinary positive parent-token deliveries as reward donations, with authenticated principal deliveries distinguished beforehand. `balance-accountedBacking`, even capped to intended amount, is not proof of this operation's receipt. Old surplus could satisfy the cap.

**Kimi:** agree on immediate notification and reuse of funded arithmetic. Reject unrestricted `noteFunding()` ingesting all unaccounted backing: it can distribute principal between transfer and credit, or absorb unrelated old surplus. “Gons-only” is not a complete safety argument: the operation includes parent callbacks, custody/oracle/NFT reads, possible failures and intermediate-state exposure. Lazy synchronization also has new ordering/projection risks. Parent burn authority cannot be dismissed from the child's authority alone.

**Astra qualification:** my original's proof establishes exact-native arithmetic and a feasible integration design, not that the new callback implementation is already proven. Prefer this direct design over another broad feasibility questionnaire.

## Recommended concrete mechanics

1. **Cover the backing token.** Install custom transfer/transferFrom implementations and route every custom internal mint/transfer to staking through the funding-aware service. Preserve allowance spending. Raw `ERC20Repo._mint` bypasses public transfer; all such paths must be covered. Initialize parent/child wiring before accepting notifications; do not silently skip an absent child.

2. **Authenticate principal BEFORE movement.** After required epoch settlement, establish a one-shot context identifying payer/source, operator, amount, recipient/position, kind and nonce before transferFrom or direct mint. The callback acknowledges only the matching principal receipt; the initiating staking route credits it once. A generic suppression boolean is insufficient. Ordinary donations do not mint principal for the donor.

3. **Measure the operation, not total surplus.** Parent-only notification attests its just-completed balance movement; verify the actual operation delta and consume its receipt once. Zero/self transfers create no reward credit. Do not sweep old surplus or outstanding principal into this allocation.

4. **No double pull/distribution.** Existing `fundRewards` is DETF-only and pulls. Replace custom reward delivery with notified mint/transfer plus an already-received receiver. If retaining the legacy pull API, mark its pull separately, suppress callback distribution, then distribute once in that API. Never transfer first and invoke the unchanged pull function afterward.

5. **Use explicit callback phases.** Notification must not call `_synchronize`. Child synchronization can legitimately trigger parent expansion funding back into the child. Permit that authenticated reward callback; during locked principal funding permit only its matching acknowledgment. Reject other reentry. Do not clear a general lock to admit callbacks. Parent locked synchronization remains limited to wired children and already-settled operations. Guard economic views against exposing spendable intermediate state.

6. **Keep allocation atomic.** Recognize backing once; apply standing-weight allocation including allocation dust, rebase ordinary funding including ordinary dust, issue fee/creator receipts at the resulting divisor, then top up future weights. Failure rolls back the token movement and all accounting. Complete applicable custody synchronization after final movements.

## Arithmetic, empty states and amendments

With stored K and gons g, native x credits/debits xK; `floor((g±xK)/K)=floor(g/K)±x`. Paying displayed reward `floor(g/K)-P` preserves P exactly. Funded rebase uses `ceil(totalGons/(oldLiability+ordinaryReward))`, retaining unrepresented growth as ordinary dust. Account and NFT-position fractions retire separately; never clear pooled escrow fractions for another position. This is the source-backed resolution of L1's conversion issue, not equivalence to B/U.

Zero ordinary gons with surviving standing weights still funds recipients. Zero **total** weight instead raises source `MissingRewardWeight`; retain explicit inert/weightless rejection rather than inventing a beneficiary or silently queueing a next-depositor gift. Ordinary zero transfers remain no-ops. Quantization dust may persist; no promise that every tiny reward immediately increases every balance.

Amend PRD §10.2 and plan §9/L1 to funded-gons balances, aggregate redeemable liability rather than raw held balance, authenticated transfer-funded donations, principal contexts, stored divisor and separate dust. Add callback/movement coverage and guard acceptance tests. Keep processed-NET expansion timing, standing rights, nine decimals, selected cliffs/reinvestment locks and native-principal accounting. Do not import stock premint, cap, warmup, eight-hour clock or linear vesting.

No further broad owner decision is needed for the recommended immediate path. The explicit trade-off is extra transfer gas and accounting-dependent atomic failure. Lazy projected views remain an alternative, not a silently equivalent fallback.

## Evidence

Local source previously read directly this round: root `contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol:113–124,170–183,208–246`; `DETFFundedStakingRepo.sol:93–139,164–217`; `common/core/DETFFundedStakingMath.sol:45–94,110–116`; `common/bondNft/DETFFundedBondTarget.sol:108–125,175–187`. Parent: `UniswapV4DetfCommon.sol:138–140,373–379`; maintenance target :16–27. Crane: `ERC20Target.sol:52–68`, `ERC20Repo.sol:258–268,297–301,329–346`. NetNet: `StakedNET.sol:83–99,127–136`; `Staking.sol:134–150`.

The inspected documents were PRD v0.30 and plan v0.3; peer version claims do not override them. High confidence in source distinctions/arithmetic; new adapter unimplemented and untested. No new external API claim or external lookup.
