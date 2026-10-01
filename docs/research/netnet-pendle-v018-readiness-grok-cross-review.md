# Grok cross-review — NetNet–Pendle PRD v0.18 readiness

Date: 2026-09-26. Reviewer: Grok (`xai/grok-4.6` routing metadata, not attestation). Inputs: Astra, MiniMax M3, Kimi K3 **v0.18 originals only**. No cross-review artifacts. Grok original `docs/research/netnet-pendle-v018-readiness-grok-original.md` unchanged.

**Readiness (evidence, not consensus):** gated implementation-planning document **yes**; frozen executable specification **no**. Matches all four originals.

## Agreements

- V18-1–V18-5 control (`PRD.md:18–83`). Do not reopen family approval, 3600s arithmetic, two-series split, existing-hook retrofit, generalized `feeTo` except designated yield token, or single (non-compounded) catch-up.
- Body R52/§9.1/A40 still require compounding and A40 forbids linear catch-up (`:189,440–456,769`) — plan hazard if quoted without the banner (`:20–21`).
- `floor(S0*n/200)` is labeled unconfirmed (`:59–71`). Confirm before freezing.
- O01 answered; do not re-ask. Shared `INDEXEDEX_AGENT_LAW.md:89–101` still forbids FoT globally for other families.
- Matrix (`OPERATION_MATRIX.md:1–4`) and Q tracker remain stale; they must not override V18.
- Engineering gates unchanged: conservation, note liveness, V2 parity, owned-book, duration/cliff, salt proof.

## Source-checked corrections

### 1. Kimi: Universal companion is v0.2 — factually stale

Kimi (`kimi-original.md:5,49`) cites **U v0.2**. Current file is **v0.5** (`UNIVERSAL_V4_DETF_COMPOUNDED_EXPANSION_PRD.md:7`). Astra (`:7,31`) and MiniMax (`:11,87`) read v0.5.

**Fact.** U:11 still names NetNet v0.17; U:17–19 still require **both** families to **compound**. That contradicts V18-4. U:178 Universal **cold-start: mint 0 and advance marker** is Universal-specific. P:20,39 forbid companion override and inferred skip-on-unavailable.

**Do not import into NetNet:** Universal fee/creator internal-share issuance and zero-share donation split (Astra `:32`; U:25,113–132 vs P:518,522 unchanged-share expansion). Shared utilities must not carry those economics.

### 2. Extra D9 approval — not required

Kimi Q2 (`:67`) optionally asks owner to confirm V18-1 covers D9 vs public HLP. MiniMax (`:105`) treats D9/R32 as engineering encapsulation.

**Fact.** `DETF_ALIGNMENT_PRD.md:9`: **D32–D66 supersede conflicting D1–D31**. Historical D9 (`:42`) is DETF-only Uni V4 LP. **D61 (`:101`)** already exposes `ownerOnlyLiquidity`; **`false` permits public deposits**. NetNet R32/P:165 public shared HLP is selected family behavior under V18-1 (`:24`).

**Inference.** Enumerate D9/D61 in §2.1 as editorial so planners do not copy “flag on.” **No extra owner approval.** Do not reopen public HLP.

### 3. `floor(S0*n/200)` batch-cadence dependence — accept Astra arithmetic

Astra (`:37`): from S0=1,000, two eligible epochs **batched** mint 10; **separate** settlements mint 5 then 5.025 = 10.025 before rounding. “Non-compounded catch-up” does not eliminate compounding **across actual settlements**.

**Fact.** Formula uses current S0 and full remaining n in one mint (`PRD.md:62–69`). Cadence changes total issuance. This is inference about the working interpretation, not an exploit claim.

**Correction to Grok original:** the necessary owner freeze is the equation **plus** whether batch-local `n` on then-current S0 is intended. Do **not** add a global base or flat one-time 0.5% (`:71`).

### 4. Unavailable-history policy — not a blocking owner item *now*

MiniMax Q2 (`:99,113`) makes oracle failure **blocking owner**, offering Universal skip-and-advance as a menu item.

**Fact.** P:39: skip-expansion-while-allowing-claims was **not** an owner decision; missing history ≠ below-peg or spot. P:472–478 couples many operations to settlement. U:178 skip+advance is **not** NetNet law.

Unavailable history **can** change entitlements (revert funded claims vs defer debt vs consume n unpaid). That is why Astra (`:38`) wants owner **after engineers present alternatives**, and Kimi (`:24,69`) treats it as specification unless entitlements change.

**Grok view (unchanged substance, tighter):** gated plan must specify the distinction table and **must not copy U:178**. Owner chooses only among engineer-presented entitlement forks. Not a freeze prerequisite for starting the gated plan.

### 5. Synthetic TWAP consumers — not an owner empty-set confirmation

MiniMax Q5 (`:102,116`): confirm consumer set is empty today.

**Fact.** P:41: recording synthetic TWAP does not by itself replace instantaneous synthetic reads or finite-size quotes. Expansion remains hook TWAP unless superseded.

**Inference.** Default = **no silent consumer switch**. Engineering supplies a consumer table vs instantaneous baseline (Astra `:39`; Kimi `:60`; Grok original). Ask owner only if a plan proposes switching a named gate/view. Do not reopen window/method.

### 6. Retained-token incentive — specification stop-gate, not new destination election

MiniMax Q3 (`:100`) blocking owner: feeTo vs interest vs split. Q4 (`:101`) bind live addresses as owner.

**Fact.** P:47 example is **not** live SY=sNET verification. P:49: if retained token is also an incentive, **classify before** admitting to interest inventory; do not auto-forward merely because “incentive,” or relabel as YT interest because addresses match.

**Inference.** Gated plan can freeze: **do not admit to interest-only inventory until classified**. Address binding is engineering verification. Escalate to owner only if a proposed classification moves value between feeTo and LP/interest (Astra `:40`; Kimi `:25`). Do not reopen V18-3 destinations.

## Unresolved dissent

| Item | Positions | Disposition |
| --- | --- | --- |
| Oracle failure as blocking owner **now** | MiniMax yes; Astra after alternatives; Kimi/Grok engineering-first | Dissent on **timing**, not on “don’t copy Universal skip” |
| Same-token incentive as blocking owner **now** | MiniMax yes; others escalate if entitlements change | Same |
| Editorial D9 note vs extra approval | Kimi optional confirm; others no | **No extra approval** (D61 + V18-1) |
| Universal version | Kimi v0.2; others v0.5 | **v0.5**, still stale on NetNet compounding |

## Grok original — attributed adjustments (not rewritten)

Keep: V18 banner vs body; gated vs frozen; one necessary equation confirm; do not re-ask O01; Uniswap tick-TWAP ≠ arithmetic price TWAP; existing-hook out of scope.

Add from peers: Astra cadence arithmetic inside that same equation question; Astra/MiniMax Universal v0.5 must not override NetNet or import fee-share issuance; D61/`ALIGN:9` already supersede D9—no extra approval.

Drop from MiniMax checkpoint: live reward-address owner bind; empty synthetic-consumer confirm; Universal skip as a NetNet menu default.

## Minimal human checkpoint

1. **Catch-up equation (only freeze):** confirm `pendingMint = floor(S0 * n / 200)` when valid 1h hook TWAP > 1, else 0 if valid ≤ 1, **including** that two missed epochs settled together use one S0 (10 from 1,000) rather than sequential 5+5.025. No compounding restore; no flat 0.5% ignoring n.

**Not now:** family approval; window; two series; existing-hook work; D9; extra contraction; empty-target seed; synthetic-consumer set; live token addresses; Universal cold-start skip.

**Later, only with an engineer table:** unavailable-history (revert vs defer vs other—not U:178); retained-token-as-incentive classification if a real market can emit it.

Gated plan may start citing V18, forbidding stale R/A/matrix/U:17–19 cells, and treating items 4–6 as specification stop-gates. No implementation, tests, or frozen executable plan authorized.
