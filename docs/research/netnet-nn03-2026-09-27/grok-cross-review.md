# Grok NN-03 cross-review

| Field | Value |
| --- | --- |
| Routing | `grok-4.6` / `xai/grok-4.6` (not provider-verified) |
| Inputs | Own original (untouched). Full Astra, MiniMax, Kimi. No peer cross-reviews. |
| Date | 2026-09-27 |

---

## Agreement (keep)

A49/§6.3: after **successful** money routes, refresh **registered expected-held** `balanceOf`s. A11: failed **fee transfer** must **not** kill the user op; **retain payable**, not refund the caller. A36: no **unbounded history walk** on ordinary ops.

Helper: `_syncAllExpectedHoldReserves` **non-virtual** loop (`:46–54`); Repo **add-only**, **no** quarantine/remove. **Explicit** discovery registration — **not** spam auto-add. Unregistered pushes are **unbooked surplus**, **not** in the loop (Kimi). Pause **transfer** ≠ `balanceOf` fail.

**Conditional collision, not impossibility:** hostile/`OOG` **`balanceOf`** on a **registered** token can fail **every** money route. Transfer-fail + good read can coexist with A11.

**Now:** spec author writes a **state machine**. **No owner storage vote.** Required legs **fail closed**.

---

## Corrections

| Claim | Why drop |
| --- | --- |
| MiniMax ~5–7 / ~8 tokens, 30–50k gas/token, archive after N epochs | **Invented caps.** Per-token gas **does not** bound an **arbitrary list**. |
| Kimi 4–6 tokens/series, months between rollovers, “dozens over years,” governance-paced | **Unsupported frequency.** Finite **today** ≠ **mathematically** unbounded growth of the **registered** set. |
| Measuring realistic gas (Kimi Option 2a) | Does **not** fix a **hostile `balanceOf`**. |
| MiniMax “best-effort skip if not touched this tx” | **Touched ≠ economically complete.** Historical SY/PLP **still price HLP for everyone** (R42). Skipping valuation needs a **conservation proof**, not “not this swap’s I/O.” |
| Age/name isolation of roles | Same address can be **interest + fee + history**. **Provenance ledger**, not “old ⇒ archive.” |
| Stale/`unknown` flag **solves** credit | **No.** Sync-**before** credit **erases** legitimate pretransfer (PRD:379). Flag ≠ force-claim vs donation vs caller. |
| Custody partition as free A49 keep | Moving tokens **changes the earning address**; Pendle pays the **hook**. Extra move can **fail** like fee transfer. Not a silent preserve-literal trick. |
| MiniMax owner pick A/B **now** with a token list | Engineering **design first**. Owner only **if** A49 **freshness** must be amended. |

Grok original’s “hot vs archive” is **UNAPPROVED** until A49 is **explicitly** changed; do not relabel it as implementing A49 as written (Astra).

---

## Default policy (no new economics)

- **Economically required** for **this** op (credit, funding, **HLP/solvency valuation**, user entitlement): **fail closed** if freshness missing.  
- **Fee-only leftover** whose **transfer** failed: keep **payable**, isolated retry; **do not** refund the user.  
- **Do not** write off, sweep, or reassign `feeTo`.  
- Unregistered tokens: **not** in the loop; **also not** A49-tracked until **discovered/added**.

---

## Narrow conditional amendment (only if needed)

If literal full-set **fresh** `balanceOf` **every** route **cannot** meet A11/A36:

> May an otherwise independent operation **skip a fresh read** of a token **proven fee-only or not in this op’s economic dependency set**, if holdings/payables stay **tracked**, status **truthful**, **required** assets **fail closed**, and **HLP/pretransfer** proofs hold?

That amends **A49 freshness**, not a quarantine layout.

**Rejecting it** ⇒ demonstrate literal sync **or** disclose availability — **don’t** silently weaken A11/A36.

---

## Recommendation (user-facing)

**Don’t decide engineering now.** Ask for a **written** token-role × operation table + how history is **valued** without an unbounded hot loop. **Then** either keep A49 literal or take the **one** freshness question above.

Confidence: **high** on helper facts and “no owner storage now”; **none** on gas or a live hostile token.
