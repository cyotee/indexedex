# Grok cross-review — NetNet–Pendle PRD v0.17 readiness

Date: 2026-09-25. Reviewer: Grok (`xai/grok-4.6` routing metadata, not provider attestation). Inputs: three **original** reports only — Astra, MiniMax M3, Kimi K3 — plus current PRD/law/source. No cross-review artifacts read. Grok original at `docs/research/netnet-pendle-readiness-2026-09-25-grok-original.md` is unchanged.

**Readiness (evidence, not consensus):** ready for a **gated planning document** with stop/go gates. **Not** ready for a frozen executable implementation plan. Matches Astra’s verdict (`astra-original.md:7`). Grok original’s “not implementation-plan ready” (`grok-original.md:13`) still holds for a frozen plan; Astra’s gated-vs-frozen split is the more precise handoff.

## Agreements (all four originals)

- Do not reopen R52–R55: 1,000 NET opening; 0.5% compounded total-supply expansion; current hook TWAP > 1 qualifies all missed epochs; balance-derived rebasing; direct mint to sNET-DETF.
- O01 (FoT NET / rebasing sNET supersession) is the hard owner/authority blocker (`INDEXEDEX_AGENT_LAW.md:89–99`; `PRD.md:49–56,644`).
- Matrix/Q7 lag v0.17 (`OPERATION_MATRIX.md:3,49,85,104,111`; `REQUIREMENTS_QUESTIONS.md:7,26`) is documentation risk, not economic reopen.
- Public shared HLP, Keep YT / V2 split, owned-reserve contraction, incentive-free reinvestment, atomic rollover, first-bond bootstrap, no ERC-4626 certification gate, cliff vs linear `_claim` (`DETFFundedStakingMath.sol:96–116`) are settled.
- Engineering gates: Weighted multi-reserve conservation; note-array liveness (`BondDepository.sol:104–153`); owned-book mapping; V2 SE parity; native `1.005^n`; duration compatibility.
- Passing tests / council agreement prove neither security nor peg.

Astra additionally flags Universal companion stale sentence `UNIVERSAL_V4_DETF_COMPOUNDED_EXPANSION_PRD.md:111` (“do not interpret 0.5% as flat…”). **Accepted as extra companion lag.** Universal amount policy remains premium-dependent (`U:19,32`); NetNet v0.17 did select flat 0.5%. Planners must not copy U:111 onto NetNet.

## Corrections to peers (source-checked)

### 1. MiniMax: D9 owner-only liquidity on this hook — reject

MiniMax (`minimax-original.md:115`): “D9 owner-only liquidity — owner = the DETF; flag on.”

**Fact.** Historical D9 (`DETF_ALIGNMENT_PRD.md:42`) requires Uni V4 DETF-only add/remove. Accepted D61 (`:101`) already allows `ownerOnlyLiquidity = false` for public deposits. D32–D66 supersede conflicting D1–D31 (`:9`). This custom family is not silent Universal law (`PRD.md:45–56`).

**Fact.** Public shared HLP is SELECTED (`PRD.md:165–167`, R32/R35, v0.8). Anyone may mint/redeem authorized HLP; other DETFs hold the same LP as an asset.

Applying D9 “flag on” would **reopen settled public HLP**. If Universal D9 and NetNet R32 conflict, that is an O01-class supersession item, not a plan instruction to restrict the hook. D61 `false` is closer than D9, but still must not be copied as if this family were Universal.

### 2. MiniMax: contraction funding waterfall as a fixed sequence — reject

MiniMax (`:72`): “Own reserve portion → claim income → unbuffer SE shares → redeem owned hook LP → convert → pay.”

**Fact.** `PRD.md:309`: those are “possible realization steps; **the precise funding waterfall is not fixed**.” Quote domain and atomic revert are settled (`:309–311`). Ordering is engineering, not an owner sequence.

### 3. Kimi: owner confirmation of 1,000→1 price decay / staker-only dilution — reject as owner question

Kimi Q2 (`kimi-original.md:51–52,28`): ask whether launch-to-peg is “long price decay” with expansion “diluting liquid DETF holders.”

**Fact.** Opening 1,000 vs ongoing 1 NET are distinct (`PRD.md:513`). Minting to staking “does not mechanically add tokens to the reserve pool” (`:399`). No premium, rebase, or peg is guaranteed (`:41–43`).

**Inference (Astra `:45`, Grok original):** expansion does not close a 1,000-to-1 trading premium. That is an economic **risk assessment**, not a missing owner selection. Asking “intended decay path” reopens rate/destination. Do not add an owner question.

Kimi’s own counterargument (`:60`) already allows dropping Q2.

### 4. Empty-target and extra eligibility are already settled negatives

**Empty target.** `PRD.md:577`: successor must support Keep-YT entry or **rollover reverts atomically**; a dual SY/PT seed “could be specified separately” and “is not silently enabled.” MiniMax (`:94`) “empty successor is rejected” is right as **v1 default = revert**, wrong as a forever ban on a later specified seed. Grok original Q4 over-asked the owner. **Correction to Grok original:** empty-target is settled (revert; no silent first-bond seed). Ask the owner only if they want to add a seed now.

**Extra contraction eligibility.** `PRD.md:337–340`: no hysteresis/caps/second buyback selected; additional rules must be explicit, not invented. Kimi Q6 (`:55`) and Grok original item 6 are confirmations of a recorded “none.” Drop from owner list.

### 5. MiniMax O-register over-classifies engineering as human input

MiniMax §2 (`:42–52`) lists O02–O10 as “requiring human input.” PRD §14 already splits remaining work: O02 price construction, O04 mapping, O05 TWAP mechanics, O07 execution, O09 inverse, O10 self-leg are **engineering/specification**, not new product forks. Astra (`:69–76`) and Grok original match that split. Singleton salt proof (`PRD.md:125,173`; matrix `:96`) is **planning proof**, not an owner mechanism choice (MiniMax Q2).

### 6. Kimi BondDepository 2-day vs 5-day

Kimi (`:20,54`) left vesting unverified. **Fact (Grok original):** `Constants.sol:76` `BOND_VEST = 2 days`; `GENESIS_VEST = 5 days` (`:54`) explains historical prose (`PRD.md:598`). Deployed 4663 equivalence remains unverified. Verification task, not owner.

## Evidence that changes Grok original

| Change | Why |
| --- | --- |
| Adopt Astra gated-vs-frozen plan wording | Same substance; clearer handoff |
| Drop owner Q4 empty-target and Q6 extra eligibility | Already settled in PRD |
| Recategorize authoritative contraction P | `PRD.md:396–399` already separates expansion TWAP from post-expansion synthetic burn price; specifying that mark is engineering, not a TWAP-vs-synthetic owner fork |
| Accept Astra U:111 lag and TWAP/settlement circularity | Extra documentation/engineering gates; not owner unless availability changes entitlements |
| Accept Astra pre-live public HLP vs first-bond activation | Engineering state machine; owner only if both cannot be preserved (`astra-original.md:35`) |

Unchanged Grok original: O01 blocking; matrix/Q7 lag; public HLP; conservation/liveness; no D52 cap restore; no certification restore; linear `_claim` incompatibility.

## Unresolved dissent (not papered over)

- **TWAP window:** Grok/Kimi/Astra treat duration as owner-shaped (`PRD.md:397` “do not choose an unapproved duration”). MiniMax defers window length to planning (`:56`). **Dissent remains:** engineers should propose; owner approves duration/fail-closed policy.
- **When a gated plan may start:** MiniMax wants O01+singleton+TWAP first (`:165`). Astra allows gated planning now with those as stop/go. **Dissent remains on sequencing, not on blockers.**
- **I/O-routing / D55 SVG / D60 rate providers (MiniMax `:113–119`):** whether this family must reconcile Universal I/O tables is unspecified. Custom family (`R14`) plus “does not silently alter” Universal §24.7 (`PRD.md:334`) implies a **new package**, not silent D9/D39 import. Unresolved as planning scope, not as public-HLP reopen.

## Owner vs engineering vs planning

**Owner (narrow):** (1) O01 supersession map and checkpoint; (2) TWAP window + invalid/stale/missing-history behavior (not spot, not auto-below-peg); (3) non-PENDLE reward destinations only if named now; (4) approve engineer-proposed weights/rollover bounds — do not reselect curve/rate/atomicity (Astra Q4).

**Not owner:** D9 restriction; fixed waterfall; price-decay narrative; extra eligibility “confirm none”; empty-target revert; singleton algorithm; self-leg as component `S`; V2 binding query; I/O table package choice beyond “custom, not silent Universal.”

**Engineering gates:** ledger mapping; conservation; note liveness; TWAP/settlement dependency graph (Astra `:43`); zero-interest full-book first join; compounding precision without a disguised cap; duration vs min-lock including post-native-maturity zero lock (Astra `:51`); hostile-rollover limits.

**Planning:** matrix/Q7/U:111 sync; selector inventories; Repo layout; A01–A45 map; pin hashes.

## Prioritized decision checkpoint (≤ owner list)

1. **O01** — scoped custom-family supersession for FoT NET, rebasing sNET, NET-epoch clock, cliff principal, DETF-as-SY, no D39 fallback on failed contraction, **and public HLP vs Universal D9**. Refuse silent D9 “flag on.”
2. **TWAP policy** — window/band and fail-closed behavior for missing/stale history, including whether unavailable TWAP may block funded exits (Astra `:71–72`). Engineers supply the graph first.
3. **Optional residual** — other reward-token destinations; maintenance compensation. Never infer sweep rights.

Everything else is gated planning or engineering. No implementation, tests, or frozen executable plan is authorized.
