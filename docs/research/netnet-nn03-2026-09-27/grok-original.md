# Grok original — NN-03 full-set sync vs availability

| Field | Value |
| --- | --- |
| Routing | `grok-4.6` / `xai/grok-4.6` (not provider-verified) |
| Date | 2026-09-27 |
| PRD | v0.26 §§6.3, 11.2, 13; A11, A36, A49 |
| Source | `BasicVaultCommon.sol:15–19,41–54,80–105`; `MultiAssetBasicVaultRepo.sol:50–96`; `BasicVaultRepo.sol:20–28`. `_syncAllExpectedHoldReserves` is **not** `virtual`. Repo has **add**, **no remove/quarantine**. |

---

## 1. Plain English

After every **successful** money path, the family must **re-book live `balanceOf` for every token on the expected-held list** (A49/§6.3): DETF, SE shares, SY, PLP/YT, dust, **failed-forward rewards**, **old-series** tokens.

Separately: **fee forwarding must not kill** a user swap (A11/§13). And **normal ops must not walk unbounded history** (A36/§11.2).

**Supported tension (not “impossible”):** if the **same** non-virtual loop (`:48–54`) runs `balanceOf` on **all** registered tokens, then (a) a **hostile `balanceOf`** on a **fee-only** leftover, or (b) a **long rollover history** of old SY/YT still registered, can **revert or gas-out the user’s trade**. That **collides** with A11/A36 **if** those tokens stay on the **hot** sync list.

Not claimed: paused **transfer** ⇒ `balanceOf` fails. Not claimed: random spam ERC-20s auto-join the set (§6.3: **explicit** add/discovery only). Not claimed: the map already has quarantine. Not claimed: a family override of `_syncAllExpectedHoldReserves` already exists.

---

## 2. Failure classes

| Class | Sync effect | Policy |
| --- | --- | --- |
| **Fee `transfer` fails**, `balanceOf` OK | Sync can still book physical remainder | A11: keep payable, **continue** user op |
| **Hostile/gas `balanceOf`** on a listed token | Entire `_syncAll…` reverts → **whole money route fails** | **Required** legs (active SY, DETF, SE shares, PLP/YT) = **fail closed**. **Fee-only / dead history** must **not** be on that hot loop |
| **Growing discovered set** (new SY each rollover, extra reward tokens) | Linear gas every swap | Bound **hot** set; archive rest |
| **Same address, two roles** (old SY = interest cash **and** fee-token collision) | Provenance, not extra ERC-20 | Ledger split (C12), still one `balanceOf` |

---

## 3. Engineering-first (minimal owner)

**Do not ask the owner for storage fields.** Bring a **written state machine** first.

**Recommendation (UNAPPROVED until A49 wording checked):**

1. **Expected set** = **discovered** markets/reward lists only (init + rollover + Pendle reward tokens). **No** dust-spam auto-register.
2. **Hot sync** each money route: **bounded active custody** (current series + current spendable/fee-retry tokens **needed this tx**). Family **wrapper** around Common — **copy/call a bounded list**, do **not** pretend `:48` is virtual.
3. **Archive** historical series + stranded fee payables: still **tracked** (A49 “historical/residual”), with **stale/unknown** if `balanceOf` fails; **retry isolated** (A11). **Not** on every swap’s hot loop (A36).
4. **Never** omit physical custody, forgive a payable, or **write off** to zero to “make sync pass.”
5. **HLP:** old SY/PLP still **owned claims**. Cannot drop them from **valuation** without a **conservation proof**. Tracking ≠ putting them on the **hot** `balanceOf` loop.

**Literal A49** (“full expected-set sync **every** successful money route”) vs this **partition** is the **only** likely owner fork.

---

## 4. Example

Rollover 1: active SY-A. Reward token PENDLE listed; `transfer(feeTo)` reverts; PENDLE **stays in the hook**.  
Rollover 2–N: SY-B, SY-C, … all **remain registered**.

If every swap `balanceOf`s SY-A…C **and** PENDLE: a PENDLE `balanceOf` bomb **fails a user’s sNET withdraw** — against A11.

If hot sync is **SY-C + DETF + SE + PLP/YT** only, and PENDLE/SY-A live in **archive + isolated retry**: user withdraw can succeed; payable remains; A36 holds. **A49** still “tracks all” if archive is part of the book — **or** A49 must be **amended** if “full-set” means the **Common loop**.

---

## 5. Proof before any exclusion

Pretransfer: do **not** full-sync **before** credit (PRD:379). Donations/force-claim SY ≠ caller HLP (A05). No silent **zero**, **sweep**, or **feeTo reassignment** of history. Fail-closed on **required** legs.

---

## 6. Action now vs later

**Not** an owner storage vote **now**. Spec author drafts the **hot vs archive** machine + A49 **literal vs partitioned** wording. **Owner checkpoint only if** A49 must change.

**Checkpoint (narrow):**  
> Keep A49 as **every registered token `balanceOf` on every money route** (then prove gas/hostile-fee isolation **without** leaving the Common loop), **or** allow **partitioned** tracking: **bounded hot sync** + **full archive book** (A49/A11/A36 together), **without** dropping HLP claim valuation?

**Not asked:** which mapping keys; auto-register spam; pause=`balanceOf` fail.

Confidence: **high** on helper facts and the A11×A49 loop collision **if** fee/history stay hot; **not** a universal impossibility.
