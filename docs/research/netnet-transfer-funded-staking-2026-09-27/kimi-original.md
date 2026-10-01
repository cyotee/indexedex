# Kimi K3 — ORIGINAL: switch to funded-gons staking + plain-transfer distribution

| Field | Value |
| --- | --- |
| Author | Kimi K3 (`kimi-code-plan-global/k3`) — routing metadata only |
| Date | 2026-09-27 |
| Scope | Answer "why not switch to sNET implementation" + "distribute NET-DETF by plain transfer without calling a function." Research only; no execution/delegation; no current-round peers. |
| Sources (direct reads, 2026-09-27) | `contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol` (full 248 lines); `DETFFundedStakingRepo.sol:90–224`; `DETFFundedStakingMath.sol:90–124`; `DETFSeigniorageShareLib.sol:18–33` (prior); NetNet `StakedNET.sol`, `Staking.sol`, `perp/WrappedStakedNET.sol` (prior round); plan v0.2 §9/L1; PRD v0.30 §10.2. |

## 1. Direct answers

**"Why not just switch to sNET implementation?"** Two different things are named "sNET implementation":

1. **NetNet's stock sNET** (`StakedNET.sol` + `Staking.sol`): pre-minted full inventory at wire with pinned 1.0 index (`StakedNET.sol:45–49`), MAX_SUPPLY cap (:28,95), 8-hour epoch clock (`Staking.sol:134–151`). All three are NetNet-specific machinery the family must not import — excluded by instruction.
2. **IndexedEx's existing funded-gons component** (`StakedDETFTarget.sol` / `DETFFundedStakingRepo.sol`): exactly the proven L1-safe implementation — this is the switch that makes sense, and the user has now permitted the model change.

**"Distribute NET-DETF by transferring to sNET-DETF without calling a function — is it possible?"** Distinguish two readings, as asked:

- **No additional USER transaction/function: yes, achievable** in two ways (below).
- **No internal function/state update at all: not possible on vanilla ERC-20** — plain `transfer` carries no recipient notification; something must apply the distribution. The existing component's accounting makes this precise: `_requireBacking` (`DETFFundedStakingRepo.sol:213–218`) deliberately does **not** treat unsolicited balances as rewards; `accountedBacking` (:54) only moves when `_distribute` runs (:185–202). A plain transfer without any distribution step is currently recorded as *unaccounted backing*, not distributed rewards.

## 2. The existing funded-gons component already solves L1 exactly

Verified mechanics:

- **Principal credit/debit are exact multiplications at the current divisor:** `_creditPrincipal` (:93–100) issues gons via `_issueAllocatedPrincipal` at current `gonsPerUnit`; `_debitPrincipal` (:109–124) debits `StakingMath._toGons(amount, gonsPerUnit)` — an exact multiply, with full-exit remainder retirement (:116–118, :131–140). No proportional division against a share counter, so the L1 counterexamples (B=3/U=2/x=1; B=10/U=6/s=3/P=4/reward=1) dissolve: native principal is gons-denominated and exact; rewards flow by divisor rebase (`StakingMath._rebase` via :197–199); reward claims debit gons exactly.
- **Standing fee/creator weights:** top-up-only algebra (`DETFSeigniorageShareLib._topUpDeltas` via `_topUpWeights` :164–175), weights never counted as backing/supply; allocation with explicit dust buckets (`allocationDust`, `stakingDust` :54).
- **Zero-circulation:** the established handling (funded plan §4.4) plus queued-reward retention (NetNet analog `Staking.sol:138–144`).
- **No per-holder loop, no distribution index per holder:** one shared divisor, refreshed only when rewards are applied.
- **Pretransfer/authentication:** `_exchange` rejects public pretransfer flags and EOAs (`StakedDETFTarget.sol:199–204`), pulls are measured-delta (:228–234).
- **Existing sync choreography:** receipt transfer/stake/unstake run `_synchronize()` (:34–38), which calls `IDETFFundedRewards(detf).synchronizeRewards()` (:241–247) with a recursion guard (`synchronizing` flag :243). So DETF→child push-on-interaction already exists.
- **Projected views exist:** `previewDistributions` (:60–84) projects pending rewards without writing.

## 3. The one real change: the distribution trigger

The user's constraint is exact and correct: existing `fundRewards` (:170–184) is DETF-only and **pulls** (`_pullDetf`, transferFrom delta check) — it cannot be called after a plain transfer (nothing left to pull) and must not double-pull. So the needed artifact is a **new delta-based funding entry** on the child: `noteFunding()` computing `delta = detf.balanceOf(child) − accountedBacking` and running `_distribute(delta)` once, with no pull. **This adapter does not exist unchanged** in the current component — stating that explicitly, per instruction. Everything else (gons math, weights, dust, exits) is reused as-is.

Two trigger mechanics:

| | (a) On-transfer internal hook | (b) Lazy delta sync + projected views |
| --- | --- | --- |
| Mechanism | Custom NET-DETF token's transfer/transferFrom/**`_mint`** paths detect recipient == staking child and call `noteFunding()` (our token, our transfer code — legal internal call; burn-from-child is impossible since the child never holds burn authority; unstake's outbound transfer needs no notification because `_debitPrincipal` already accounted it) | No token change. Funding transfer sits as unaccounted backing; the next `synchronized` operation (stake/unstake/receipt transfer) or the DETF coordinator's own settlement call applies `_distribute(delta)` once; views project via `previewDistributions` |
| Reward visible in balances | Same transaction as the transfer | At next touching operation; projected in views meanwhile |
| Token change | Yes — all three movement paths must notify (missing one — e.g. direct `ERC20Repo._mint` — silently strands rewards) | None |
| New attack surface | Hook reentrancy during ERC-20 transfer; mitigated because `_distribute` moves no DETF (gons-only allocation, :185–202) and the existing `synchronizing` guard pattern applies | None new |
| Direct gift transfer to child | Distributed immediately | Pending until next touch (documented) |

Note: every **mandatory** funding path (expansion settlement) is already a DETF-coordinator transaction, which can invoke the child's distribution inline — under both (a) and (b), mandatory rewards land in the funding transaction. The only case the trigger choice affects is ad-hoc direct transfers/gifts to the child.

## 4. Recommendation and change boundary

**Recommend: funded-gons adaptation with (a) the on-transfer internal hook**, because it delivers the user's stated preference exactly — an ordinary transfer (or expansion mint) to the child distributes immediately with no user-visible function call — while reusing the proven component end-to-end. Fallback (b) is acceptable and requires zero token changes if the hook is rejected in review; state both in the plan with (a) selected pending one narrow confirmation below.

**Exact change boundary:**

- **Changes (user-permitted model change, recorded as such):** §10.2's "live B / no divisor refresh" language is superseded by the funded-gons model (single shared divisor refreshed at reward application); new `noteFunding()` delta-based entry on the child; custom DETF token transfer/mint paths gain an internal recipient check + call; L1 is closed by exact-multiply gon accounting (`_creditPrincipal`/`_debitPrincipal`), dissolving the §9.1 counterexamples.
- **Unchanged:** nine-decimal receipt; 1:1 native stake/unstake; funded backing and `_requireBacking`; standing fee/creator weights and their top-up algebra; early reward claims; pre-maturity rebond (re-expressed as exact gon debit: burn `StakingMath._toGons(q, gonsPerUnit)` — the second counterexample resolves exactly); no NetNet inventory/cap/8-hour clock; no fee/lock changes; no per-holder loop.
- **Reentrancy/guards:** hook executes under the existing `synchronizing`-style recursion guard; `_distribute` is gons-only (no outbound DETF call), so the hook cannot re-enter a DETF money path through the distribution itself.

**Narrow clarification actually needed (one sentence):** for ad-hoc **direct** transfers to the child (gifts, not coordinator-orchestrated funding), must distribution be visible in the same transaction (requires (a)), or is application at the next touching operation with projected views acceptable (b)? Mandatory expansion funding is identical under both.

## 5. Limits

All cited behavior from direct reads dated 2026-09-27; no execution; no external lookups required (no new external library/API claims arose — the components are local). The delta-based `noteFunding` entry and the DETF-side hook are new adapters, not existing code; nothing above asserts they are implemented or tested. The user's model-change permission is the recorded authority for superseding §10.2's live-B/U wording; absent that permission this route would have been a prohibited substitution.
