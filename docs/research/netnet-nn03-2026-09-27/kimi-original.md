# Kimi K3 — ORIGINAL: NN-03 full-set synchronization vs hostile tokens and bounded history

| Field | Value |
| --- | --- |
| Author | Kimi K3 (`kimi-code-plan-global/k3`) — routing metadata only |
| Date | 2026-09-27 |
| Scope | NN-03 only: elaborate the conflict, engineering-first recommendation, minimal owner checkpoint. Research only; no execution/delegation; no new-round peer artifacts. |
| Sources (all read directly this session) | PRD v0.26 §6.3 (:367–390), §11/A36, §13 (:863–874 area), A11/A49; tracker NN-03 (`PRD_OPEN_QUESTIONS.md`:46,80–85); `BasicVaultRepo.sol` (full), `MultiAssetBasicVaultRepo.sol` (full), `BasicVaultCommon.sol` (full). No external claims arose; Context7 not needed. |

## 1. Plain-English statement of the conflict (only what the source supports)

The owner instructed (v0.23, §6.3/A49): **every** token the hook physically holds — current SY/PLP/YT, SE shares, reward tokens, failed-forwarding payables, and **historical** residuals from expired/rolled markets — is registered in the expected-held set, and the shared helper's contract is: at the end of every successful money route, refresh the booked balance of **every** registered token (`BasicVaultCommon.sol:46–54`, the unguarded per-token `balanceOf(address(this))` loop; money-route contract at :15–20, :123–138).

Two other selected rules pull against this:

- **§13/A11 (non-blocking fee forwarding):** a hostile fee-destined token must not be able to break the surrounding operation.
- **§11/A36 (bounded history):** rollover must not force every normal operation to walk an ever-growing history.

The concrete collision: (a) a registered token whose `balanceOf` reverts, hangs or returns hostile returndata makes **every money route revert at its final sync**, bricking the hook even for operations that never touched that token; (b) the registered set grows with every rollover and reward discovery, and **neither Repo exposes a removal function** (`BasicVaultRepo.sol:67–81`, `MultiAssetBasicVaultRepo.sol:66–79` have `_addVaultToken(s)` only — no removal/quarantine exists today, and none should be claimed to exist), so route cost grows monotonically.

## 2. Failure classes — keep them separate

| Class | Reality | Conflict? |
| --- | --- | --- |
| Hostile **transfer**, good `balanceOf` | §13's forwarding isolation already covers it; sync reads fine | **No** |
| Hostile **`balanceOf`** (revert/gas/returndata) | Kills the full-set sync → kills all routes | **Yes — the core case** |
| **Growing set** | Linear gas growth per route | Conditional: rollover is expiry-gated (months apart, ~4–6 tokens per series); realistic growth is dozens of tokens over years, not permissionless spam. **Registration is explicit/discovery-driven — there is no spam auto-registration vector** (anyone can *transfer* tokens in, but unregistered transfers are just unbooked surplus, absorbed per the helper's existing rule :15–20 — they never enter the set without a deliberate registration step) |
| Pause/blacklist tokens | Accepted by token policy; **pause blocks transfers, and nothing says `balanceOf` fails** — do not claim it does | Not a sync conflict by itself |
| **Role collisions** (same address = interest reserve AND failed-forward payable AND historical claim) | Physical sync is provenance-blind and fine; the collision lives in the eligibility/liability layer §6.3 already separates | No new sync conflict |
| Economically required assets vs fee-only/history | Required assets must fail closed; fee-only payables and historical residuals are exactly the candidates for deferred handling | This asymmetry is the design lever |

## 3. Hard helper facts (no invention)

`_syncAllExpectedHoldReserves` (:48–54) and `_syncReserveToBalance` (:41–44) are **`internal`, non-virtual** — the family **cannot override** them; only `_unbookedSurplus` (:37) is virtual. So any refinement is either (a) call the per-token helper for an active subset and never call the all-set helper on hot routes — possible without touching shared code, but it deviates from the helper's documented "every successful money route" contract, which is what the owner's v0.23 instruction referenced; or (b) modify the shared helper (shared-code change, separate authorization). Pretending an override exists would be false.

## 4. Options assessed (engineering-first)

**Option 1 — policy relaxation (selective sync):** track everything; fresh-sync only the **active set** (every token any hot route can move) on each route; historical residuals and fee payables live in an **archival** class synced lazily at the protected boundary of any route that touches them (sync-on-use), carrying unknown/stale flags; failed-forwarding retries sync their own token on the retry path. Honest invariant: *a token may be archival only while no route can price or move it without syncing it first.* Because old-series SY/PT/YT still back outstanding HLP, safe exclusion from hot-path sync requires the ownership/valuation proof that their valuation is claim-based (read from Pendle state at quote time), not read from the raw snapshot — that proof is a specification deliverable, not an assumption. Pretransfer safety is preserved per token because `U = B − R` credit is only meaningful for active tokens; an archival token accepting a pretransfer must first be synced in the same boundary. No zero/writeoff of payables, no sweep, no fee reassignment, donations unchanged.

**Option 2 — preserve literal sync:** keep A49 verbatim and either (a) demonstrate, with measured gas, that the realistic registered-set size stays within budget for the operating horizon (NN-18 evidence), or (b) partition custody (separate archival custody contract). Note (b) does **not** fully escape registration: old-series claims pay the earning address — the hook (`InterestManagerYT.sol:43–57` verified earlier) — so historical SY arrives at the hook regardless and must be registered there or moved in an extra step. (b) adds machinery; (a) may simply be true — the conflict's teeth are the hostile-`balanceOf` case, not the growth case.

**No universal impossibility is claimed:** growth is governance-paced and quantifiable; the genuinely hard sub-case is one hostile registered token's read.

## 5. What the owner must decide — minimal, one question

Not storage design. Only: **"May A49's literal rule — full expected-set fresh sync at the end of every successful money route — be refined to active-set sync per route plus sync-on-use for archival tokens plus isolated fee-payable sync on retry routes, provided the stated invariants (sync-before-use, no false pretransfer credit, no payable writeoff, no sweep/fee reassignment) are proven; or must literal full-set sync be preserved, accepting a custody-partition or a measured-bound demonstration as the cost?"** Everything else is engineering.

**Sequencing recommendation (investigate-first, same discipline as NN-02):** design and measure first. The specification author should produce the Option-1 state machine and the Option-2(a) gas/growth measurement; only then does the checkpoint carry evidence. It is possible the measurement shows literal sync is safe at any realistic horizon and no relaxation is needed at all — the owner should not be asked to relax a rule against a hypothetical.

## 6. Status of any selective/quarantine design

UNAPPROVED. It **may change A49**; if adopted, A49 must be amended explicitly rather than silently reinterpreted, and the archival-exclusion proof (HLP backing via claims, not raw snapshots) is a precondition.

## 7. Limits

All helper/Repo/PRD facts from direct full reads this session; no external claims; no gas measured (that is the NN-18 deliverable this item requests); no peer artifacts read this round; no override/removal capability is claimed to exist in current shared code.
