# OPEN_ITEMS_R7 Grok original — remaining owner economics

| Field | Value |
| --- | --- |
| Researcher | Grok |
| Routing | `xai/grok-4.6` — not provider attestation |
| Read | PRD **v0.16** `:7,26`; matrix (01a–44 + UNKNOWN); `REQUIREMENTS_QUESTIONS.md` Q4–Q13; `docs/plans/detf/UNIVERSAL_V4_DETF_COMPOUNDED_EXPANSION_PRD.md` v0.1 C01–C16, U01–U04 |
| Peers | unread |
| Status | Research. Unauthorized. |

**Do not re-ask:** opening **1000 NET/DETF**; expansion **strictly >1 NET/DETF** on **processed NET epochs**; **premium-dependent compounded** pending (views then mint/fund); **no** linear `perEpoch×n`; **atomic** rollover; HLP proportional/subset/single on NET,sNET,USDG,DETF; USDG bonds = other fresh locks; 01a/01b PkgInit/Args/salt/factory-first; R43 custody; no 4626/SY certification. Ignore matrix `:111` / v0.15 `:28` “proposal” labels.

## Not owner questions
| Class | Items |
| --- | --- |
| **Engineer** (plan) | Owned-book/inverses; Weighted mapping of PLP/YT/`C`/SE/self-leg; empty-Pendle seed (`mintPY`+dual mint, **≠** R51); first-bond extra legs; **do not** seed `C` from principal; SY wrap; V2 selector matrix; note-array gas; PENDLE forward-fail; dust U03; gas of virtual-n |
| **Authority** | O01 FoT/rebase vs `CLAUDE.md:45`; alignment §24 noncompounding **supersession** (`UNIVERSAL…PRD` §1.1) |
| **Doc** | Tracker still “through v0.12”; Q7 incomplete vs v0.16; matrix USDG-lock UNKNOWN `:88` vs selected same-lock |

## ≤3 owner questions (user-visible)

### 1. Coefficient `c` — what is “0.5%”?
**Still unclear** (`v0.16:26`; compounded PRD `:19,90`). Premium model is `Ei = floor(Si*(Pi−W)/Pi * c / W)`. 0.5% is **not** flat 0.5% of `S` and **not** Universal `10%/year→8h`.
**Ask:** is 0.5% the **per processed-NET-epoch closure of the premium base** (`c = 0.005e18`), another encoding, or **withdrawn**?
**Proposal only:** treat **0.5% as `c` per NET epoch on premium**, not on raw supply — until confirmed. Do not import R6 `54.75e18` annualization.

### 2. Which **NET price**, and how **`Pi` updates**? (U01)
Gate is **>1 NET per DETF**, **not** creation-normalized `P>1` vs **1000** (C11). Opening 1000 ≠ ongoing 1-NET target.
**Ask:** (a) Is `P` the **R38 NET/DETF mark** (inventory synthetic in **NET units**, or executable swap)? (b) Across virtual epochs, **freeze P0** while compounding **only `Si`**, or **recompute `Pi(Si)`** so later epochs can fall ≤1 and stop?
**Proposal only:** **NET-denominated inventory mark vs 1**, not highest-of-legs vs creation. **Freeze P** for pending `n` (geometric on supply; no fake history). Recompute-`Pi` only if owner wants premium decay inside the projection.

### 3. What do **balances display** before the mint tx? (U04 / U02)
C04–C05: users must **see** compounded accrual; `totalSupply`/ERC20 must **not** include unminted DETF. U02: one aggregate `fundRewards` vs sequential virtual index.
**Ask:** Do `balanceOf` / staking views stay **funded-only** with **separate pending getters**, or may a named projected getter be the UI default? One **aggregate** allocation at realization vs emulate per-epoch gons?
**Proposal only:** **stored balances = funded**; **explicit pending/projected views** for UI; realization = **one mint + one `fundRewards`** matching `Sn−S0` (no extra recipients). Sequential virtual index is **not** required for the selected product sentence.

Empty successor / zero-interest first join: **engineer** (Keep-YT empty ≠ Weighted bootstrap; don’t label principal as interest). Not a fourth owner question.
