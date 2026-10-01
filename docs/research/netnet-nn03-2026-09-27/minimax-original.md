# MiniMax M3 — NN-03 Full-Set Sync & Bounded History (Bounded Round)

> **Scope:** elaborate NN-03 (PRD_OPEN_QUESTIONS.md §3 NN-03) and identify exact owner checkpoints. Read current PRD v0.26 §6.3 (line 373), §11, §13, A11/A36/A49 (line 980), tracker NN-03, BasicVaultCommon.sol and BasicVaultRepo.sol from prior rounds. Research-only; routing metadata `minimax/MiniMax-M3` only. Date 2026-09-27.

---

## 1. Plain-English explanation of NN-03

The hook holds: raw NET-DETF, raw SE shares, Pendle SY, raw PLP/YT, intermediate route tokens, reward tokens (PENDLE, USDG, etc.), historical-series rewards and residuals, plus a refundable payable balance for failed-forwarding rewards (PRD §13). The selected money-route pattern in PRD §6.3 + A49 is: **at the end of every successful money route, sync every registered expected-held token's `balanceOf` into the local Repo so the protocol-internal accounting reflects actual on-chain holdings.** Per A36, however, the hook cannot iterate unbounded history.

**The conflict (only if supported):** the full-set sync walks every registered token. Per-token failure modes (gas, returndata, hostile ERC-20 `balanceOf`) compound. As the active set grows — across markets, reward discoveries, rollover — so does the worst-case sync cost. **However**, PRD §13 already separates **isolated fee-only failure retry** (line 880): "if a fee-destined token cannot be forwarded, continue the rest of the operation and retain the undelivered token/payable." So fee-forwarding already has a bounded failure-isolation pattern; only the **sync-after-route** path remains coupled.

---

## 2. Failure-class taxonomy (only what's supported by source)

| Class | What happens | Detection | Permitted response |
| --- | --- | --- | --- |
| **F1 — Transfer-only failure with good balance read** | `safeTransfer`/`transfer` reverts; `balanceOf` succeeds | returndata | Sync reserve; mark refundable; continue |
| **F2 — Hostile `balanceOf`** | reverts / OOG / returns garbage | explicit try/catch on read | Skip from full-set sync; flag `unknown_balance=true`; require explicit re-attempt |
| **F3 — Gas exhaustion across the active set** | one bad token drains block gas | per-token gas cap (e.g., 50k each) | Skip the failing token; sync remaining; report |
| **F4 — Growing active set without bound** | unbounded sync as rewards/rollover accumulate | token registration cap or archival | Engineering (NN-03 deliverable) |
| **F5 — Economically-required asset (e.g., NET, USDG, SY)** | sync fails → subsequent operation can't quote | per-asset mandatory sync | Fail-closed; revert the whole route |
| **F6 — Reward-payable isolation** | forwarding fails | §13 already covers; not NN-03 | Already isolated |
| **F7 — Pending-claim role collision** | reward-balance-bearing token confused with strategy asset | per-token role tag in Repo | Sync; flag; do not route as strategy asset |
| **F8 — Forced pretransfer** | third-party transfers SY/PLP into hook before action | pretransfer validation per §13/§6.2/A05 | Reconcile at credit; do not erase |

**The user explicitly warns against inventing:**
- Arbitrary spam-token auto-registration. **PRD §6.3 line 377 says "register expected-held token addresses through the Repo's initialization/add-token functions"** — explicit discovery, not auto-add from `Transfer` events.
- Claim that transfer pause implies `balanceOf` fails. **F1 separates transfer failure from balance-read failure** — pausing transfer does not preclude a balance read on a non-paused function.
- Claiming the existing map has removal/quarantine fields. **`BasicVaultRepo.sol:60–70` exposes `_addVaultToken` / `_addVaultTokens`; no `_removeVaultToken` is in the public surface** (verified prior rounds). **Do not pretend override.**
- Claiming the shared helper is overridden if not virtual. **`BasicVaultCommon._syncReserveToBalance` (`:41–44`) is internal, not virtual; cannot be overridden** without source modification. **Do not claim override.**

---

## 3. Engineering-first recommendation (no owner storage design)

**Recommend a single relaxation: relax §6.3 + A49 full-set sync into a tiered-sync model with three categories. Engineering specifies; owner decides the policy frame.**

**Tiered sync (proposed engineering design, engineering owns the details):**
1. **Mandatory-sync tier (F5):** NET, sNET, USDG, current-active Pendle SY, canonical V2 LP share token, hook's own NET-DETF self-leg. **Failure closes the whole route.** Bound this tier to ~5–7 tokens by selection; bounded by definition.
2. **Best-effort-sync tier (F2/F3/F4):** historical SYs, prior-series PLP/YT residuals, intermediate route tokens. **Failure is isolated** — token skipped, marked `unknown_balance=true`, route continues. Per-token gas cap (e.g., 30k–50k) prevents OOG.
3. **Archive tier (F4 long-term):** tokens not seen in N epochs are archived into a separate `ArchivedRepo` (or analogous flag in the existing Repo). They don't get full-set sync; they get only on-demand reconciliation on user-authorized action or rollover.

**Why this is engineering-first:**
- No new owner checkpoints on storage layout, quarantine fields, or helper overrides.
- The mandatory tier is bounded **by selection** (~5–7 tokens), not by per-token success.
- The best-effort tier absorbs the failure-isolation logic already present in §13 for fee forwarding.
- The archive tier addresses **historical** accumulation without forcing it into the active sync.

---

## 4. Plain-English example

Suppose the hook has registered: NET, sNET, USDG, current-SY, sNET-scaled18 wrapper, PENDLE reward, USDG reward (from §13 example), historical-series-SY (rolled over from 2026-09-17), and a pre-funded recipient's empty sNET-DETF wrapper. Sync walks all 9.

- **Mandatory tier (5 tokens):** NET, sNET, USDG, current-SY, hook-self-leg. If any of these fails (e.g., current-SY's `balanceOf` reverts), the whole route reverts. This is **F5 — fail closed**.
- **Best-effort tier (3 tokens):** sNET-scaled18, PENDLE, USDG-reward. If PENDLE's `balanceOf` reverts (a malicious reward token), the route continues; PENDLE is flagged `unknown_balance=true`; reconciliation attempts at the next reward-collection window.
- **Archive tier (1 token):** historical-series-SY. Not synced; only reconciled on rollover or explicit user-authorized action.

**Bounded sync cost = mandatory tier + best-effort tier = ~8 tokens × bounded gas. Archive tier grows with history but does not contribute to sync cost.** Failure of any mandatory-tier token closes the route; failure of any best-effort token is isolated.

---

## 5. Owner decision needed — exact narrower checkpoint

**Question:** does the owner accept the tiered-sync relaxation, **bounded by selection on the mandatory tier** (5–7 tokens), with best-effort isolation for historical/reward/registry growth and archival for unused history?

**Two alternatives, no policy invention beyond this:**
- **(A) Adopt tiered sync** (above). Engineering owns the implementation.
- **(B) Preserve literal §6.3 / A49 full-set sync** via bounded custody partition + invariant demonstration. Engineering must demonstrate the active set is bounded by construction (e.g., pre-register only 8 tokens, refuse any new registration). **No measured N* is provided; the bounding is by configuration, not by measurement.**

The owner does **not** decide:
- The exact mandatory-tier token list (selection, NN-05 territory).
- Whether quarantine/remove/pause fields exist (they don't, in the current Repo).
- Whether the helper is overridden (it isn't virtual).

The owner **does** decide:
- Whether to relax §6.3 / A49 (one of A or B).

---

## 6. Conditions for the chosen path to be sound

**Pre-transfer / donations safety (user's explicit requirement):**
- Forced pretransfers must reconcile at credit, not silently erase legitimate pretransfer credit (per A05).
- Donations are not zero'd, not written off, not swept, not reclassified as fee-owned. They are tracked as **physical custody** with separate role flag (strategy-asset vs fee-payable vs user-segregated).
- Reward USDG is **not** strategy backing (per PRD §13: "Reward USDG must not increase the USDG strategy backing or synthetic valuation").

**Shared-backing history ownership valuation proof (user's explicit requirement):**
- HLP has actual claims from hook-LP holders (§7.1). If the **shared-backing history** (i.e., the hook LP token, the canonical V2 LP share token, the current-active SY) is excluded from best-effort or archive tier, **the safety proof is not satisfied**. **The mandatory tier MUST include all tokens that constitute shared backing.**
- Engineering must demonstrate which tokens are shared backing and which are not; this is **not** an owner storage decision but **is** an owner policy confirmation that the mandatory tier covers shared-backing tokens.

**Is action needed now vs bring concrete design first?**
- The PRD §14.1 NN-03 row already says "Reconcile PRD §6.3/A49 full-set synchronization with §13/A11 non-blocking hostile reward forwarding and §11/A36 bounded historical processing." This is engineering work.
- Owner approval is needed **only** for the tiered-sync relaxation. If owner picks (B) preserve literal, no PRD amendment needed; engineering must demonstrate bounded active set.
- **Recommended sequence:** (1) engineering produces tiered-sync spec including mandatory-tier token list and shared-backing proof; (2) owner approves (A) or rejects to (B); (3) PRD §6.3 + A49 amended to record the chosen frame; (4) implementation follows.

**No universal impossibility claim.** The conflict is "sync-after-route coupled to all registered tokens" vs "hostile/reward/history growth unbounded." The user's prompt rightly notes "no universal impossible claim" — the tiered model is one concrete engineering solution; bounded-active-set is another; both are achievable.

---

## 7. Confidence and evidence limits

- **High** that `BasicVaultRepo` exposes only add-token functions (`:60–70`) and `BasicVaultCommon._syncReserveToBalance` (`:41–44`) is internal non-virtual. Source-verified prior rounds.
- **High** that §13 fee-forwarding already isolates F6. PRD §13 line 880.
- **Medium** that tiered-sync is implementable within current Repo layout (engineering detail).
- **Low** on whether the mandatory-tier token list matches shared-backing without a measured proof (engineering-required proof).
- **Not claiming** the tiered-sync is the only solution; bounded-active-set (alternative B) is also feasible; no universal impossibility.
- **Not reopening** per-NFT isolation, R41 no-bonus, atomic installment, excess-as-same-NFT, O03 reinvestment policy, NN-01/NN-02 evidence work.

**Saved:** `docs/research/netnet-nn03-2026-09-27/minimax-original.md`. Originals untouched.
