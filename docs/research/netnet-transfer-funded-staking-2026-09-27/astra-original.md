# Astra — ORIGINAL: transfer-funded staking recommendation

Continuing council-astra, assigned `openai/gpt-6-astra` routing only; not provider verification. Independent current round, prior history retained, no current-round peer artifacts read. Environment access date2026-09-28; earlier directory/report dates remain unchanged and are not independently reconciled. Research only; this report is the only write. No execution, tests, RPC, browser, code/configuration edits or delegation.

## Recommendation

**Use IndexedEx's existing funded-gons arithmetic, adapted for automatic notification by OUR NET-DETF token.** A user can make one ordinary `NET-DETF.transfer(stakingChild, amount)` and have allocation/rebase finish atomically in that transaction. They need no second transaction or separate `fundRewards` call. The parent token must make an internal cross-contract notification and staking must update state. Zero internal function calls/state updates is not stock sNET behavior and is not promised here.

The human now permits a model change. Replace literal live-B/U balances with funded gons and stored K; do not attempt to prove the two formulas equivalent. This resolves the prior L1 native-principal conversion problem by changing the representation explicitly. Current on-disk PRD v0.30 §10.2 and plan v0.3 §9 still contain the older formula; this report neither edits them nor authorizes implementation.

## 1. Three alternatives

| Alternative | User experience | Assessment |
|---|---|---|
| Stock NetNet sNET | Rebase invoked by Staking; transferring backing alone does not update sNET | Wrong drop-in: imports inventory, capped fragment supply and NetNet epoch machinery unless adapted. |
| **Existing funded-gons child + controlled-parent notification** | Ordinary transfer triggers complete distribution in the same transaction | Recommended: immediate consistent views, actual receipt attribution, source allocation/dust reuse. Requires new family-local hook/receiver integration. |
| Lazy synchronization/projected views | Transfer only records custody; later interaction commits distribution, or views project it | Possible but worse fit: views/writes must project the same recipients, dust and index; receipt sequencing and principal discrimination remain necessary. Aggregating transfers can change allocation rounding and participation. |

Stock source: `lib/crane/contracts/protocols/pol/net/src/StakedNET.sol:25–49,83–99` initializes preminted inventory, caps supply, and explicitly writes its divisor; `Staking.sol:88–150` calls rebase through its epoch path. Correct `src/perp/WrappedStakedNET.sol:48–85` is an index-conversion wrapper, not transfer-triggered distribution.

## 2. Reuse the actual funded component—not its pull ABI after a transfer

`contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol:170–183` restricts `fundRewards(amount)` to the DETF and **pulls** the amount through `_pullDetf` (:228–234). A user cannot call it directly; invoking it after an already completed reward transfer can double-pull or revert.

`DETFFundedStakingRepo.sol:185–202` already has the reusable funded accounting core: recognize amount once, check custody, allocate, rebase ordinary gons, issue funded fee/creator receipts. Add a **new authenticated already-received path**, without another pull, sharing this core. Its semantic contract is parent-token-only, exact operation receipt, exactly-once consumption—not arbitrary `balance-accountedBacking` discovery.

Existing parent reference `UniswapV4DetfCommon.sol:373–379` currently mints to itself, approves staking, calls the pulling `fundRewards`, then clears approval. For this custom family replace that reward delivery with one notified transfer or one notified mint directly to staking. If the old pull entry is retained for compatibility, give its pull a distinct funding context and distribute exactly once after the pull; do not let notification and `fundRewards` both distribute.

## 3. Concrete parent/child funding protocol (new adaptation)

**A. Cover every actual token movement.** Crane `ERC20Target.sol:52–68` delegates public transfer/transferFrom to Repo; `ERC20Repo.sol:258–268,297–301` just moves balances/spends allowance. `_mint` (:329–346) directly writes balances/supply. There is no existing receiver notification. Installing a callback only on public transfer would miss direct minting: the V4 common `_mintDetf` calls `ERC20Repo._mint` directly (:138–140).

Install family-specific transfer/transferFrom selector implementations and route all custom internal transfers/mints through one funding-aware movement service. Keep normal allowance checks. Inventory every direct Repo write in the custom parent and attached targets; arbitrary facet paths cannot bypass it. Do not modify unrelated families or assume a universal ERC20 hook exists. Outgoing staking backing and direct burns from that custody also need authorized debit ordering, never an unaccounted burn.

**B. Principal must be marked BEFORE movement.** On staking entry, synchronize due expansion first, acquire the staking-operation guard, and establish a one-shot context bound to kind, nonce, payer/source, authorized operator, recipient/position and exact amount before `transferFrom`. Direct principal minting to staking needs the equivalent authenticated context before `_mint`; `from==0` alone is not reward classification.

The parent updates balances, then reports the actual movement to the configured child. For a matching principal context the child records/acknowledges the receipt without distributing it. The initiating staking operation verifies the measured receipt and credits principal exactly once. A broad boolean “ignore incoming transfers” is insufficient: mismatched payer/amount/operator/nested delivery must fail. Never mint principal from an old balance surplus.

Existing NFT funding already measures/pulls, approves the child, stakes and verifies credited gons (`DETFFundedBondTarget.sol:108–125`); preserve this authenticated sequence and allowance cleanup. Ordinary deposits settle previous expansion first; purchased bond principal still enters before its own immediate bond reward.

**C. Plain positive incoming transfers are reward funding.** With no principal/legacy-pull context, an actual positive NET-DETF delivery to the initialized child is a donation to the existing distribution, not a stake for the sender. Parent-only notification verifies the exact movement, credits accounted backing once, distributes and tops up future weights. Zero transfers and staking-to-itself transfers create no reward credit. Old unexplained surplus is not swept into the current receipt. Failed accounting reverts the whole transfer/mint. Wiring must be complete before notification is accepted; do not silently skip a missing child.

**D. Guard and synchronization states are load-bearing.** Existing `_synchronize` runs before the child lock and calls parent `synchronizeRewards` (`StakedDETFTarget.sol:34–38,241–247`). The parent may fund expansion back into the child. The new receipt entry must therefore NOT call `_synchronize` recursively. During synchronization allow only the authenticated reward callback; during a locked principal pull allow only its matching receipt acknowledgment, not general distribution or reentry. Otherwise require idle state and acquire a distribution guard. Consume contexts before any further external interaction; never reset a general lock to admit callbacks.

The existing parent maintenance pattern allows only its wired children a locked no-op synchronization callback (`UniswapV4DetfMaintenanceTarget.sol:16–27`). Reuse that authorization concept, not a public skip flag. Plain transfer-triggered allocation need not itself generate another epoch synchronization; ownership-changing stake/claim routes continue settling required epochs. Fee-recipient/oracle reads, backing reads and read-only reentrancy must not expose spendable intermediate ledgers. Return successfully only with balances, accounting and applicable custody snapshots reconciled.

## 4. Why native principal is now exact

Reuse `DETFFundedStakingMath.sol:10–11,45–74`:

`K0=1e36`, `balance_i=floor(g_i/K)`, `L=floor(Q/K)`.

Funding principal x issues xK gons; transferring/withdrawing native x debits xK. With K unchanged during principal movement:

`floor((g_i+xK)/K)=floor(g_i/K)+x`,
`floor((g_i-xK)/K)=floor(g_i/K)-x`.

Thus reward claim `balance_i-P` leaves precisely P displayed units, without shaving principal or deferring a displayed unit. Source `_claim` preserves the separate native principal ledger (:96–116). The custom NFT must retain its selected cliffs/epochs, not copy the source's linear vesting predicate.

For funded ordinary reward S plus prior ordinary dust, the core computes `target=L+S`, `Knew=ceil(Q/target)`, realized growth=`floor(Q/Knew)-L`, and retains undistributed ordinary dust. K never increases on such a funded update; it stays unchanged on zero reward or Q0. This is stored funded normalization, not `ceil(Q/liveBalance)`.

Keep full-account and per-position retirement distinct: Repo :109–139 pays whole account units and accounts released fractional liability as staking dust; the NFT must retire only the affected position's remainder, never wipe a pooled escrow using a generic full-account branch. Fraction retirement does not reprice unrelated positions because K remains fixed.

## 5. Allocation, zero circulation and dust

Preserve `_allocate` (:79–94), Repo `_distribute` (:185–202), and `_topUpWeights` (:164–175). Allocate `newReward+allocationDust` across total funded gons plus persistent standing weights. Rebase only ordinary S; issue fee F/creator C using the resulting K; top up future weights afterward. No second issuance fee, no fA shortcut, no claim on old principal. No perholder enumeration: fixed role issuance plus arithmetic.

Backing discipline: actual held DETF >= accountedBacking; aggregate redeemable liability and recorded allocation/ordinary dust remain funded. New accountedBacking increases once per authenticated principal/reward receipt. Receiver issuance consumes allocated backing, not an additional transfer.

Q0 with surviving standing weights works: ordinary allocation0, F/C still receive funded receipts. Preserve K and dust when users exit. If **all** reward weights are zero, existing math raises `MissingRewardWeight`; recommend retaining that explicit preactivation/weightless rejection rather than inventing a recipient or silently gifting queued funds to the next depositor. This is not a blanket zero-circulation rejection. Zero-amount token transfers remain harmless no-ops.

Finite arithmetic/quantization remain: source retains unrepresentable growth as dust, including near K1; it does not guarantee every reward immediately increases every native balance. Do not add NetNet's premint, uint128 supply ceiling, warmup or eight-hour clock. Keep the custom processed-NET expansion clock, standing allocations and chosen locks unchanged.

## Change boundary and confidence

Adopt an explicit PRD/plan change from literal B/U/no-refresh to funded-gons/accounted-liability/dust with automatic **internal** notification. User-facing reward funding becomes one ordinary transfer; direct funding is not staking. Existing arithmetic substantially resolves L1; custom callback coverage, contexts, guards, initialization and preview/event parity still need implementation and validation. Transfer gas and availability now include reward-accounting dependencies—an intentional cost of immediate same-transaction distribution.

High confidence in inspected arithmetic and the feasibility of controlled-parent notification. Proposed adapter/state machine is new design, not code claimed to exist unchanged or a tested security result. Canonical CLAUDE, Crane architecture, local adversarial guidance and current PRD/plan were read directly. All claims here are local source review/derivation; no external API claim or new external lookup was needed. Only this report is authored; return to moderator/human for consolidation.
