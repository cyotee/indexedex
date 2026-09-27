# Grok original — NetNet–Pendle PRD v0.18 readiness

| Field | Value |
| --- | --- |
| Researcher | Independent Grok first pass (new bounded round) |
| Observed model metadata | Prompt names `grok-4.6`; ID `xai/grok-4.6`. Routing metadata, not provider attestation. |
| Environment date | 2026-09-25 |
| Subject | `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md` v0.18 (950 lines) |
| Authorization | Research/documentation review only. No implementation, tests, or plan execution. |
| Access date | 2026-09-25 |
| Peer artifacts | None read. |

**Verdict:** v0.18’s **controlling banner** (`PRD.md:18–83`) records owner approval of this custom family and the new TWAP/reward/catch-up choices. The **body below is not synchronized**. Ready for a **gated implementation-planning document** that treats V18-1–V18-5 as controlling and lists stale sections as non-operative. **Not** ready for a frozen executable plan until the catch-up **equation** is owner-confirmed and planners cannot implement retired R52/§9.1/A40 text.

Do **not** reopen: custom-family approval; 3,600s arithmetic window; two distinct TWAPs; existing-hook retrofit as a separate effort; feeTo routing except designated interest-reserve yield token; single (non-compounded) catch-up as an economic change.

## Assumptions

1. V18 precedence (`:21`) beats conflicting later R-table, §§1/2/9/13/14, A-rows, and companions.
2. Owner approved **this family**, including configured FoT NET and rebasing sNET (`V18-1:23–24`). Shared `CLAUDE.md:46` / `INDEXEDEX_AGENT_LAW.md:89–101` remain unchanged for other families. Do not re-ask O01.
3. This council turn does not itself implement (`:14,25,83`). Family approval ≠ frozen spec or deployment.
4. No tests, forks, or live 4663 verification.

## Human choices vs assistant inference

| Kind | Content | Source |
| --- | --- | --- |
| **Human** | Approve custom family (scoped FoT NET / rebasing sNET + described behavior) | V18-1 `:23–24` |
| **Human** | Two series: hook **spot** TWAP and DETF **synthetic** TWAP; both **3600s arithmetic** `TWAP=(C(t)-C(t-3600))/3600`; do not conflate | V18-2 `:27–33` |
| **Human** | Specify a reusable TWAP **interface/semantic contract**; **existing-hook implementation is a different effort** | V18-2 `:35–36` |
| **Human** | All attributable Pendle rewards except the **designated interest-reserve yield token** → current `feeTo()`; example sNET/SY retained, PENDLE and reward USDG to feeTo; reward USDG is not strategy backing | V18-3 `:43–47` |
| **Human** | Replace compounded missed-epoch expansion with **single catch-up**; no per-missed-epoch production loop; keep 0.5% rate, current hook TWAP > 1 gate, mint to sNET-DETF, once-only markers | V18-4 `:53–57` |
| **Not human (do not freeze)** | `pendingMint = floor(S0 * n / 200)` | Explicitly “working interpretation… not a separately confirmed owner equation” (`:59–71`) |
| **Not human** | Skip expansion while allowing claims on invalid TWAP | “Earlier assistant suggestions… were not explicit owner decisions” (`:39`) |
| **Not human** | Every same-token incentive must be forwarded anyway | “was not an owner-selected override” of the yield-token exception (`:49`) |

## Quality / contradictory legacy (operative if a planner ignores V18)

V18 says older text is traceability only (`:21`). The body still **reads as operative**:

| Stale operative text | Conflicts with |
| --- | --- |
| §1 `:93–95` “Controlling… 0.5% of the **compounded** total” | V18-4 |
| R13 `:150`, R30 `:167`, diagram `:208`, §13 `:693–699` PENDLE-only; “other destinations are OPEN” | V18-3 |
| R52 `:189` “fixed-percentage and **compounded**”; R53 `:190` window still “unapproved” | V18-4 / V18-2 |
| §9.1 `:440–456` compounded formula **and** “Do not silently revert to `S0 * 0.005 * n`” | Directly forbids the V18 working linear interpretation |
| §9.2 `:464` “do not choose an unapproved duration” | Duration is 3600s |
| O01 `:711` still unresolved authority | V18-1 answered; do not re-ask |
| O05 `:715` compounded remaining; O08 `:718` other reward destinations | V18-4 / V18-3 |
| A11 `:740` PENDLE-only; A40 `:769` compounding example **and** “Verify no … **linear catch-up**” | V18-5 `:76–80` required the opposite tests |
| `:85` “no implementation is authorized”; `:900` FoT still “authority blocker”; `:843` supersession still unapproved | V18-1 family approval (scoped). Shared law files still forbid FoT globally (`INDEXEDEX_AGENT_LAW.md:95–96`) |
| Universal companion still compounding (`PRD.md:480,948`) | Allowed: different family. Do not copy Universal compounding back onto NetNet |

**Companions (stale, must not override — V18 `:21`):** `NETNET_PENDLE_OPERATION_MATRIX.md:1–4` still v0.15 and treats expansion mechanics as unresolved. `REQUIREMENTS_QUESTIONS.md` (linked `:707`) is not re-read here as a decision source; V18 already warns companions are unsynced.

**Clarity strength:** V18 banner is explicit about precedence, inferred vs selected, and existing-hook scope. **Clarity failure:** 800+ lines of retired “must”/R/A text remain unlabeled except by the banner. A gated plan must cite V18 IDs, not R52/§9.1/A40.

## Readiness for an implementation plan

**Gated plan (yes, with stop/go):** family approved; architecture (hook custody, public HLP, Keep YT/V2, contraction, cliffs, first bond, ERC-4626/SY) unchanged and still specified. Plan must: (1) treat V18 as law; (2) stop on unconfirmed catch-up equation; (3) specify TWAP interface without implementing existing hooks; (4) keep engineering gates.

**Frozen executable plan (no):** catch-up equation unconfirmed; body contradicts V18; matrix/A40 would generate wrong tests; TWAP consumer mapping unset (`:41`); oracle init/failure unset (`:39`); same-token incentive classification unset (`:49`).

V18-1 does **not** rewrite `CLAUDE.md`. Implementation, when separately authorized, still needs a **family-local supersession record** so agents do not apply global FoT-forbidden tests as a ship blocker for this family’s configured NET/sNET. That is process/engineering, not a new O01 question.

## Remaining engineering / specification gates (not owner)

Unchanged from prior product: Weighted multi-reserve conservation; owned-book contraction; V2 SE full parity; note-array liveness (`PRD.md:687–691`); bond min-duration vs next-epoch cliff; salt singleton proof; callback authority; zero-interest full-book first join.

**New from V18:**

- TWAP interface: series id, units, cumulative timestamp, one-hour result, history availability, preview/consultation (`:35–37`). Hook series updates on swaps; synthetic series on supply/owned-reserve/valuation changes, not swaps alone.
- Arithmetic **price** average is **not** Uniswap V3 tick TWAP. Context7 `/uniswap/docs` 2026-09-25: tick-cumulative delta / time is arithmetic **mean tick**, used to get a **geometric mean price**. Do not copy PoolManager `observe` semantics into this standard.
- Consumer map: expansion still uses hook TWAP unless superseded (`:41`); synthetic TWAP must not silently replace finite-size quotes or post-expansion owned-reserve burn pricing (`:41,466`).
- Init, insufficient history, callback safety, rollover continuity, quiet-period extension vs non-swap staleness (`:39`). **Do not** treat missing history as below-peg or substitute spot. **Do not** freeze assistant “skip expansion, allow claims.”
- Reward provenance when addresses coincide: principal SY, YT interest, incentive of the retained token, donations, fee payables (`:49`). Bind actual market/SY and designated retained token; example is not live verification (`:47`). Pendle docs 2026-09-25 distinguish LP **incentives** (e.g. PENDLE) from SY **underlying yield** — supports the owner split, not a token-address proof.
- Linear catch-up overflow/horizon without a disguised D52 cap (`:73`; `DETF_ALIGNMENT_PRD.md` D52). No epoch-count production loop (`:55`).
- Crane/hook deploy path unchanged: PkgInit on interface; never `new`; V4 hooks via registry/hook factory (`crane-architecture`; `indexedex-uniswap-v4-hook-packages`).

## Narrow owner questions (only necessary)

1. **Catch-up equation (blocking for a frozen spec):** confirm or replace `pendingMint = floor(S0 * n / 200)` when valid hook 1h TWAP > 1, else 0 if valid ≤ 1 (`:59–71`). Do not accept “one flat 0.5% regardless of elapsed epochs.” Do not restore compounding.

**Do not ask:** family approval; 3600s/arithmetic; two-series split; existing-hook retrofit now; PENDLE-only vs generalized feeTo; extra contraction eligibility; empty-target silent seed; D9 owner-only HLP (public HLP remains selected R32).

**Ask later only if engineers present entitlement-changing alternatives:** invalid-TWAP availability (block settlement vs skip mint vs other); classification if the retained yield token is also emitted as an incentive.

## Facts / inference / speculation

| Kind | Claim |
| --- | --- |
| Fact | V18-1–V18-4 are written as owner quotes/decisions; linear formula is labeled unconfirmed. |
| Fact | R52/§9.1/A40 still require compounding and A40 forbids linear catch-up. |
| Fact | Shared token policy still forbids FoT/rebasing underlyings globally. |
| Fact | Uniswap documented TWAP is tick-arithmetic / price-geometric, unlike selected arithmetic price TWAP. |
| Inference | A planner using the R-table without the banner will implement v0.17. |
| Inference | Gated plan can start if it forbids copying stale R/A/matrix cells. |
| Speculation | Solvency, peg, gas, note liveness, live reward-token set remain unproven. |

## Confidence and limits

- **High** that V18 human choices are captured and must not be reopened.
- **High** that the body/matrix/A40 contradiction is the main plan hazard.
- **High** that only the catch-up **equation** is a necessary owner freeze before executable spec.
- **None** on deployed markets, fees, or economic soundness.

No Context7 EIP-4626 re-fetch this pass (no new 4626 claim). Pendle `/websites/pendle_finance` and Uniswap `/uniswap/docs` accessed 2026-09-25. No shell/tests/delegation. Earlier v0.17 research files preserved, unread this pass.

**Handoff:** confirm `floor(S0*n/200)` (or a replacement); then a separately authorized gated plan may specify TWAP interface, reward ledger, and remaining gates—without existing-hook TWAP work and without treating stale R52/§9.1/A40 as requirements.
