# Astra — NN-02 ORIGINAL: external-note custody and claim liveness

2026-09-27. Assigned routing `openai/gpt-6-astra`, not provider verification. Prior session retained; no new-round peer outputs read. Research only; only this Markdown report written.

## Plain English

**The NFT can control who gets a bond's money, but it cannot control how much work NetNet requires to collect it.** NetNet keeps a permanent list of notes for each receiving address. Other people can pay to add notes to that address. Every collection scans the entire list—even entries already paid or worth zero. Enough accumulated entries can make the transaction too large to finish.

NN-02 must establish a custody design plus a defensible claim-work bound, or disclose and obtain approval for a narrower guarantee/scope. It is not permission to invent an upstream recovery function.

Current tracker `44,69–82` records the constants update but retains NN-01 IN PROGRESS and NN-02 OPEN. The user-confirmed constants edit is not deployed-equivalence or liveness evidence. NN-01 live checks remain pending.

## Source facts and prioritized findings

Paths below are relative to `lib/crane/contracts/protocols/pol/net/src/`.

**1. No enforced per-recipient note-count bound.** `BondDepository.sol:104–139` accepts positive payment and arbitrary `to`, transfers payment to Treasury, then appends `notes[to]`. There is no recipient callback/consent check, code-existence requirement, minimum positive payout or array-length limit. `:54` stores the array. This permits both voluntary gifts and hostile appends to a custody address, including before that address has code.

**2. Collection cannot skip unwanted/history entries.** `redeem` at `:143–153` loops all `notes[msg.sender]`; zero claimable entries are skipped only **after being visited**. No pruning occurs. `pendingFor` at `:156–165` also loops the whole array; a view label does not bound computation. `noteCount` (`:168–170`) and the public individual-note records can support bounded wrapper bookkeeping, but cannot change upstream redemption cost. `interfaces/IBondDepository.sol:28–42` exposes neither selective/paginated redemption nor note transfer.

**3. The payout cap is not a note-count cap, particularly for zero payouts.** Payout is `floor(valueWad * 1e9 / price)` (`BondDepository.sol:126`, `Constants.sol:14`, `libraries/FixedPointMath.sol:10–21`). Positive payment can produce zero payout when that numerator is below price, including potentially floor-rounded LP valuation (`BondDepository.sol:174–180`). No positive-payout check follows. `Treasury.sol:127–131` and `NET.sol:150–156` do not reject a zero mint under valid wiring.

The cap accounts **payout**, not deposits (`BondDepository.sol:183–188`); local constants specify 25 bps per eight-hour epoch (`Constants.sol:17,79`). A successful zero-payout note consumes no payout capacity. Actual cheap-zero-note feasibility still depends on price, LP state, payment token behavior and valid oracle/wiring; no live exploit is claimed. Zero payout is not zero attack cost: payment and gas are spent.

Local vesting is two days (`Constants.sol:76`), whereas interface prose says five (`IBondDepository.sol:5–6`). Neither supplies a note-count bound or guarantees timely final collection; deployed timing remains NN-01 evidence work.

## Do wrapper-only approaches bound it?

| Proposal | What it achieves / what it cannot prove |
| --- | --- |
| One custody address per registered native note/NFT | Isolates other positions and legitimate history. Attackers can still append to each address. Useful containment, not unconditional liveness. No extra NFT is implied. |
| Precomputed address, deployed only when claiming | Notes are keyed by address, not recipient code. Purchase reveals the target; anyone can append before deployment. Secret/random address selection does not hide it after purchase. |
| Wrapper batching or gas-limited calls | Can process different custody addresses separately and contain failed calls. Cannot split one upstream all-note scan; a reverted call makes no redemption progress. |
| Local purchase cap or fresh-address rotation | Limits wrapper-created notes/new exposure. Does not cap third-party appends or move existing notes to a fresh address. Admission checks cannot protect subsequent claims. |
| Frequent claims | Reduces currently unpaid value when successful; never removes visited history. Cannot promise completion against accumulated spam, delayed holders or indefinite inactivity. |
| Minimum payout / capacity assumptions | A wrapper minimum binds its own purchases only. Even upstream positive minimum would bound notes per epoch only under quantified capacity/supply assumptions, not lifetime history. Current source has no such minimum. |
| Treat all extra notes as gifts | May convey real value, but cannot reject entries or bound scanning. Calling gifts harmless ignores tiny/zero payouts. |

**Conclusion:** no evaluated wrapper-only mechanism enforces a useful per-custody redemption-work bound independent of third-party appends. This is narrower than a mathematical impossibility theorem about every imaginable construction. Finite block throughput and attacker resources provide possible economic/horizon bounds, not an existing contract guarantee.

## Conditional resolution options—not selections

**A. Quantified residual-risk design.** Evaluate per-position custody with no reuse, constant-size registered-note accounting, and failures isolated from unrelated NFTs. Specify unsolicited-note attribution: aggregate NET received may include other notes with different maturities; do not automatically grant their proceeds the registered note's release schedule or accept arbitrary native gifts into new NFT rights. Preserve selected authorized atomic collection→Keep-YT→mint/stake and exclusive ownership.

For an explicit exposure horizon, derive/measure `G_redeem(n, noteStates) + G_atomicReinvestment <= availableTransactionBudget`; determine the failing count, minimum successful spam payment/payout for **both** markets, attacker gas/capital and achievable appends. Include zero, fully claimed and newly vesting notes, precreation spam, deferred final claims and gift attribution. No gas threshold or economic safety margin was measured here. “Attack costs money” alone is insufficient; any restricted claim window or residual stranding risk requires owner acceptance, not silent implementation.

**B. Upstream capability change.** Selective redemption, bounded ranges or receiver-authorized admission could alter feasibility, but none exists in the inspected ABI. Obtaining it would require separate upstream/scope authorization and fresh dependency evidence—not a wrapper helper pretending to provide it.

**C. Explicit feature deferral** if no acceptable design/assumptions satisfy the chosen rights. Requires owner approval; no automatic descope, raw-NET escape or abandoned-note recovery is selected.

## Narrow checkpoint / UNAPPROVED clause

**Checkpoint:** should the specification author first quantify option A's residual risk, with NN-02 remaining open, or require bounded upstream redemption before this external-note feature may proceed? No lock or scope change is approved by this question.

> **UNAPPROVED:** NN-02 closure must distinguish an enforceable workload bound from an economic-risk assumption. Account for arbitrary recipient appends, zero-payout and fully claimed notes, delayed claims and aggregate gift attribution. Wrapper caps, isolated custody and repeated claims are not alone a bound. Preserve atomic reinvestment and NFT rights; any weaker availability guarantee or feature deferral requires explicit owner disposition.

High confidence in local source facts (`^0.8.24` snapshot); economic feasibility/deployed equivalence unverified. Read current CLAUDE, relevant canonical Crane/local testing-adversarial skills, catalog, PRD §§12/C08 and tracker. No external documentation claim required lookup; no RPC/shell/tests/delegation or read failures. No PRD/tracker edit or closure claimed.
