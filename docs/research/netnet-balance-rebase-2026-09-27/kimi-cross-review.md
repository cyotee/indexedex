# Kimi K3 — Balance-rebase L1 CROSS-REVIEW (Astra / Grok / MiniMax M3)

| Field | Value |
| --- | --- |
| Author | Kimi K3 (`kimi-code-plan-global/k3`) — routing metadata only |
| Date | 2026-09-27 (note: Astra's report is dated 2026-09-28 session-environment — environment-date discrepancy recorded honestly, consistent with PRD §16's documented practice; no history rewritten) |
| Basis | Full reads of the three originals (untrusted evidence); my unchanged original; moderator's challenge list applied as rubric. |

## 1. Corrections to my original (moderator-directed; the algebra matters)

- **C1 — my "identity" was wrong.** `floor(g/floor(T/B)) ≠ floor(B·g/T)`: T=10, B=3, g=3 → `floor(3/floor(10/3)) = floor(3/3) = 1` vs `floor(9/10) = 0`. StakedNET's semantics is the **stored divisor** `K = floor(T/supply)`, updated explicitly on rebase — not a live ratio. A rate anchored to live B makes every deposit shift every other holder's displayed balance; that is not the selected semantics and not StakedNET's.
- **C2 — my rebase + recipient formulation double-distributes.** Rebase scales all balances by the full Δ, then issuing recipients f·Δ gives them f·Δ twice. Corrected in §3 below (ordinary share via B, recipient share via additive issuance, one floor each, conserved).
- **C3 — my formulation imported NetNet-specific machinery the selection excludes:** the MAX_SUPPLY cap, the pre-minted inventory, and — decisively — the **explicit global divisor refresh on reward arrival**, which conflicts with §10.2's selected "live B … not an authoritative distribution index that must be refreshed when a reward arrives." Grok's 1:1-inventory-issuance-plus-rebase scheme is exact but makes the same trade: it is an **alternative semantic** the owner could choose, not something importable silently.
- **C4 — wsNET roundtrip loss:** up to **one whole raw native unit** (9-dec), not always sub-native — Astra's index-1.5e9 example (wrap 1e9 → unwrap 999,999,999) is exact.

## 2. The key reconciliation: two semantics, one selection

- **NetNet's actual semantics:** explicit divisor refresh at reward funding + 1:1 inventory issuance. Exact, non-dilutive — but requires the refresh-on-reward, the preminted inventory, and the cap. Grok's candidate is this faithfully.
- **The PRD's selected semantics (§10.2):** live B, internal shares, rewards flow **automatically** with no index/divisor refresh ("not an authoritative distribution index that must be refreshed when a reward arrives"; the funded plan's gons/K model is what was deliberately not selected). Under this model, the reward-bearing state has B > U, so a 1:1 deposit after rewards **dilutes accrued rewards** (B=12,U=10,s=5: reward to 6; stake 1 at 1:1 → B=13,U=11, old balance drops to 5). Therefore under the selection the deposit MUST be proportional `floor(x·U/B)` — the dilution NetNet avoids by construction is avoided here by the mint formula, and the integer-floor obstruction returns, bounded by share precision.

Conclusion: the maximal correct **plan-compatible** algorithm is the live-B/U one below; NetNet's scheme is the documented alternative if the owner prefers exactness over the live-B/no-refresh selection — a genuine, narrow semantic fork, not a defect in either.

## 3. Merged maximal algorithm (all selected rights preserved)

**State:** per-account shares `u[h]` (scaled: share unit ≪ 1 native unit); aggregate `U` (stored counter, never enumerated); per-position native principal `P`; `B` live custody.

1. **Stake x:** `m = floor(x·U/B)` at scaled precision (floor loss < 1 raw native unit); revert at `m == 0` (no confiscation); old holders undiluted.
2. **Unstake x:** `d = ceil(x·U/B)`; pay exactly x; forward-verify `floor(B·d/U) ≥ x`; the <1-unit excess stays in custody pro-rata (conservative).
3. **Reward funding Δ (expansion mint):** `B += Δ`; `U` unchanged — automatic live-B reward, no refresh. **Recipient issuance is additive on the new Δ only (no fee ownership of pre-existing principal, no double-distribution):** target `Tf = floor(B·sF/U) + floor(Δ·f/1e18)`; issue `ΔsF = max(ceil(Tf·U/(B+Δ)) − sF, 0)`; ordinary holders' share arrives via B growth; conservation holds within <1-unit dust. **`O == 0` (no ordinary shares):** per the funded plan's established zero-share handling (`DETF_FUNDED_STAKING...PLAN.md:198–227`: `T = 0`, `rps = A/(Wf+Wc)`, S=0), recipients split the **entire** Δ in ratio Wf:Wc — replicate that, not f·Δ.
4. **Reward-only claim (Astra's budget — adopted):** reserve `p = ceil(P·U/B)` shares for principal; reward budget `u − p`; pay `x = floor(B·(u−p)/U)`; burn `d = ceil(x·U/B)` (proof `d ≤ u − p`); `P` unchanged. The <1-native-unit deferred residual **remains attributed to the position** — position-local dust the PRD expressly permits (§10.2 native rounding; §10.3 principal/reward separation; `DETFFundedStakingMath.sol:110–116` reverts below principal and defines rewards as value − principal). It is deferred, not confiscated, never paid to others; do not invent tighter bounds or an acceptance rule.
5. **Partial rebond q ≤ P:** burn `d = ceil(q·U/B)`; require `floor(B·d/U) ≥ q` and remaining shares `≥ ceil((P−q)·U/B)`; `P −= q`; rewards retained via the budget invariant.
6. **U0 guards:** `U==0 && B==0` → 1:1 seed; `U==0 && B>0` → revert `OrphanBacking` (never gift orphan backing to a later depositor).
7. **Full exit:** pay `floor(B·u/U)`, burn all `u`; account-local dust only; no pooled sweep.

**Counterexample reachability (precise, no "every state impossible"):** B=3,U=2,x=1 resolves with scaled shares (loss <1 raw unit; old keeps 3, new gets 1 at native precision). B=10,U=6,s=3,P=4,rewards=1: budget gives `p = ceil(24/10) = 3`, `x = floor(10·0/6) = 0` — the displayed 1-unit reward is **deferred** (position-local dust), principal intact; when value grows, the unit becomes claimable. Astra's high-precision variant (u=2Q,U=4Q,B=6,P=2): `p = ceil(8Q/6)`, `x = floor(6·(2Q−p)/4Q) = 0` — same deferred-dust outcome, exactly as her analysis states; the unsafe naive ceil-debit (d=ceil(2Q/3)) is what her example correctly kills.

## 4. Peer corrections (attributed)

- **MiniMax §3.4 (rejected):** reward-only claim by transfer with shares unchanged **drains other holders** — the claim consumes pool value pro-rata from everyone while the claimant keeps shares. The budget burn (§3.4) is mandatory. His separate `n[h]` ledger is necessary but not sufficient — the `value ≥ P` invariant must be enforced at every transition (moderator's point, Astra's framing).
- **MiniMax's "implementable, just dust" conclusion:** only true *with* the budget construction; his written version double-dips.
- **Grok:** his 1:1 + explicit-rebase candidate is algebraically sound (his rebase restores claims = backing before the next 1:1 stake, avoiding the §2 dilution) — recorded as the legitimate alternative semantic, not an error; it is not importable silently because it refreshes a global divisor on reward arrival and imports inventory/cap machinery.
- **Astra:** her budget is adopted as the claim mechanism; her conclusion that no single reference supplies the complete selected algorithm is accurate — the merged algorithm is assembled from scaled proportional mint + her budget + the funded plan's standing-weight allocation (including the O=0 full-to-recipients branch) + NetNet's rounding conventions.

## 5. Dissent record

- **Semantic fork (the one genuine residual):** live-B/no-refresh (selected) vs NetNet's exact divisor-refresh model. If exact-integer behavior is ever preferred over the selected semantics, that is a narrow owner clarification — one sentence, with Grok's candidate as the shape. Not required now: §3 preserves every selected right within PRD-permitted position-local dust.
- My original's C1–C3 errors are recorded above, not defended.

## 6. Evidence limits

All code facts from direct reads this session (`StakedNET.sol`, `perp/WrappedStakedNET.sol`, `Staking.sol`, funded-staking plan, `DETFFundedStakingMath.sol`, `BasicVaultCommon.sol`). External SY-sNET conversion implementation remains unverified (NN-10/G1). No execution; no provider verification claimed for any citation; the Astra date discrepancy is recorded, not smoothed over. Originals unchanged; no new round initiated.
