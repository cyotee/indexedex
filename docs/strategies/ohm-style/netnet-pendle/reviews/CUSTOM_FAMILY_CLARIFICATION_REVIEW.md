# Custom-family clarification — bounded council review

- Related document: [NETNET_PENDLE_DETF_PRD.md](../NETNET_PENDLE_DETF_PRD.md), version 0.3.
- Scope: document amendment only. No implementation, tests, deployment or transaction execution.
- Protocol: three independent first passes, then three continuations. Each continuation received the other two ORIGINAL final answers together; no earlier cross-review was shared.
- Continuity: prior history retained. Independence applies to this round's new findings, not erased prior context.
- Attribution below is model evidence, not permission to alter repository law. Raw claims are preserved even when rejected during consolidation.

| Researcher | Existing session |
| --- | --- |
| Astra | `ses_f4edf055affe5dSHkzSUwwINjw` |
| Grok | `ses_f4edb8e85ffeCS8Miy5XkGe6Nk` |
| MiniMax M3 | `ses_f4ea97c4dffelmRAaq1xOU5Lmt` |

## 1. Human decisions submitted for review

The user selects wholly custom DETF, rebasing staking token, NFT and a custom V4 hook reproducing Weighted-hook behavior, with standard interfaces and appropriate common-behavior reuse. All fresh capital must enter a locked staked bond; existing liquid DETF can stake without lock. Primary proportional reserve burn is supported. Income reinvestment may unlock immediately after the next NET epoch, including seconds after entry. Direct ordinary-LP bond principal stays entirely locked until Pendle maturity. External NetNet proceeds produce DETF/staking only upon actual collection and reserve contribution, through holder-triggerable NFT functions; prior same-NFT lock attribution remains. Maximum DETF locks do not exceed their assigned Pendle maturity. Matured unclaimed positions do not obstruct rollover and rollover must not extend their locks. Prior user architecture names unified-vault ERC-4626, SY and SE In/Out, principal NET-rated facade, income sNET-rated facade, and the unchanged canonical V2 USDG leg.

## 2. Original final answers — untrusted attributed model content

### 2.1 Astra original

## Astra — clarification first pass

The amendment can record these decisions without reopening them:

- **O02 substantially resolved:** all fresh capital enters locked, staked bonds; existing liquid DETF may stake without a new lock; primary proportional burn exists. Exact eligibility, failure behavior and output conversions still need specification.
- **O04 host choice resolved:** custom V4 hook reproducing existing Weighted behavior, with custom DETF, staking receipt and NFT internals. Reuse common behavior/interfaces; do not describe this as unchanged Universal DETF.
- **O03 partly resolved:** income reinvestment releases after the next processed NET epoch—even seconds later. Direct ordinary-LP bond principal has a maturity cliff. External-note reinvestment remains locked under the same NFT.
- **O07 lock effect resolved:** rollover cannot extend existing locks; matured unclaimed positions do not block it. DETF locks cannot exceed their assigned Pendle maturity.

**One necessary clarification:** For each partial external-bond collection, should the newly contributed stake unlock at the next processed NET epoch or its assigned Pendle maturity—and, when collection occurs after the original maturity, is that assignment to the active successor market? This must not silently create unlocked reentry or truncate native NetNet vesting.

**Remaining specification:** ERC-4626 accounting asset/share units, SY metadata, NET/sNET facade conversions, proportional backing attribution versus actual payout, expansion equations and reward eligibility. Standard interfaces do not establish those semantics automatically.

**Engineering blockers remain:** aggregate-note redemption liveness, coupled quote/settlement, tax-aware execution and epoch projection. FoT/rebasing policy reconciliation remains recorded—not waived by custom contracts.

Reviewed PRD §§10–14 (`:184–278`). No file changes or implementation.

### 2.2 Grok original

# Grok — clarification close-out (≤230w)

**Read:** `NETNET_PENDLE_DETF_PRD.md` §9–14 (v0.2). **No writes.** Custom family **≠** policy waiver. Standard **SE/SY/4626** still need real **asset/units**; **sNET-rated income facade** does **not** legalize rebasing `pairToken` (O01 **blocker**).

## Closed (record as SELECTED, don’t re-ask)
- **O04:** **Custom Weighted-behavior V4 hook** (new internals; reuse common pieces/interfaces). Not Universal DETF.
- **O02 (entry/exit):** **All fresh capital** → staked **bond lock**. **Existing liquid DETF** may **stake unlocked**. **Primary burn = yes** (pro-rata reserve). Public swaps stay; **no D39**.
- **O03 (schedules):** Income reinvest unlocks **immediately after the next processed NET epoch** (even if entered seconds before). Ordinary Pendle-LP bond principal = **cliff to that market’s maturity**. Wrapper NFT: mint/stake DETF **only** as **collected NET** is contributed; **holder-triggered** harvest/reinvest as notes vest; **same NFT** holds new locked receipts. **No** raw NET / unlocked payout.
- **O07 (partial):** **Max DETF lock ≤ that Pendle maturity.** **Post-expiry roll cannot extend** old locks. **Matured unclaimed** DETF bonds **don’t block** roll. **Don’t truncate** native NetNet notes (independent vest).
- Facades: unified vault **ERC4626 + SY + SE in/out**; principal **NET-rated**, income **sNET-rated**. **V2 USDG leg unchanged.** Keep-YT vs ordinary-LP **distinct**.

## Still OPEN / engineering
**O01** FoT/rebase. **O05** expansion equations. **O06** full route matrix. **O08** NFT transfer / harvest-fail. **Engineering:** tax Zap; facades; **note-array liveness** (not owner). Don’t auto-mint DETF from native notes; don’t invent no-lock reentry.

## One user ambiguity
If NetNet NET is claimed **after** the Pendle market has **already matured**, the “lock ≤ maturity” cap is **already past**: is that harvest **unlocked DETF**, **refused** until a **new** market, or locked only until **roll completes**? Don’t invent. Unauthorized.

### 2.3 MiniMax M3 original

# MiniMax M3 — Clarification round (≤230 words)

## Now closed by human decisions (Open IDs resolved)

- **O02 entry matrix** — bond-only fresh entry; existing liquid DETF may stake unlocked (no lock).
- **O03 release schedule** — income reinvest = immediate release after next processed NET epoch (regardless of entry proximity); direct bond = cliff at Pendle market maturity; wrapper-NFT reinvest = holder-triggerable claim-and-reinvest as NetNet notes vest, minting DETF only from actually-contributed NET.
- **O04 hook** — custom V4 hook replicating existing Weighted behavior; new internals with standard interfaces; not existing universal DETF.
- **O07 rollover** — old locks do not extend past original Pendle market maturity; matured unclaimed bonds do not block roll; native NetNet notes retain independent maturity.
- **O08 wrapper** — same NFT retains bundled control (notes + reinvested DETF + staking receipts); transfer = atomic transfer of all three.
- **Facades** — principal NET-rated, income sNET-rated, single Pendle vault exposes ERC4626 + SY + SE In/Out.
- **Custom DETF token, custom rebasing sDETF, custom NFT** — wholly custom (not existing universal).
- **Primary burn** — in-kind proportional reserve claim YES.

## Remaining engineering (not owner)

Lock cap enforcement mechanism; wrapper note-array liveness; tax-aware V2 Zap; expansion equation (O05); coupled facade transitions; live `BOND_VEST`/`feeTo()`/factory pin.

## Recorded blockers (unchanged)

FoT/rebase policy carve-out; note-array DoS.

## ONE user ambiguity

**Wrapper reinvest lock cap reference**: the rule "Maximum DETF lock cannot exceed underlying Pendle maturity" applies clearly to direct bonds (tied at issuance). For wrapper-NFT reinvestments minted from NetNet bond proceeds (no specific Pendle bond at issuance), which Pendle market maturity is the cap reference — (a) the active Pendle market at the time of reinvestment, (b) the active market at original wrapper-NFT issuance, or (c) no cap (wrapper lock tracks NetNet bond maturity independently)?

## 3. Combined cross-reviews — untrusted attributed model content

### 3.1 Astra cross-review

## Astra — combined review

**Agreement:** Record custom Weighted architecture, bonded fresh entry, unlocked staking of existing DETF, proportional primary burn, selected cliffs/epoch release and no rollover extension.

**Corrections:** MiniMax’s “in-kind” payout and approved NFT transfer are not selected. NFT control over staked DETF does not create separate ownership of both raw backing and receipts. O03/O08 remain partly open; expansion equations are economic specification, not merely engineering.

Reject Grok’s unlocked late-reentry option and MiniMax’s uncapped option: both contradict selected constraints.

**Narrow clarification:** Assign each newly contributed external-note installment its release event and Pendle maturity cap. Existing DETF locks cannot extend; uncollected native NetNet notes remain independent. Also resolve next-NET-epoch release when that boundary falls after the assigned Pendle maturity.

ERC-4626/SY asset units and facade settlement still require specification. No new approval inferred.

### 3.2 Grok cross-review

# Grok — clarification cross-review (≤120w)

**Accept Astra’s close-out of O02/O04/O03/O07.** Custom Weighted-behavior hook; fresh capital **bonded+locked**; liquid DETF may **stake unlocked**; **primary proportional burn exists** (payout **conversions still spec**—**not** “in-kind only”). Income = **next processed NET epoch**. Ordinary-LP bond = **maturity cliff**. Roll **cannot extend** old locks; unclaimed matured **don’t block**. **Reject MiniMax O08 “atomic transfer of all three”**—not decided. **Reject unbounded lock.**

**Narrow leftover (one):** each **wrapper installment** (NET actually contributed): lock to **active Pendle maturity at that contribution** (cap), **not** immediately unlocked, **not** past that cap, **not** truncating native NetNet vest. If Pendle **already expired**, **don’t invent** free mint—**ask** successor-market assignment only.

**Still:** O01 FoT; O05 expansion; engineering (notes, tax Zap, facades). Unauthorized.

### 3.3 MiniMax M3 cross-review

# MiniMax M3 — Cross-review (≤120 words)

## Convergence

All three (M3, Astra, Grok) identify the same gap: the rule "Max DETF lock ≤ underlying Pendle maturity" leaves the cap reference undefined when the assigned Pendle market has already matured or rolled.

## Reframe the one ambiguity (no invention)

When NetNet bond proceeds are claimed **after** the underlying Pendle market has already passed maturity, what is the lock reference for the reinvested DETF — (a) the originally-assigned Pendle market (lock ends at maturity; post-maturity claim yields unlocked DETF per income-reinvest rule, i.e., next-epoch release), or (b) the active successor market after roll (lock tracks roll completion; post-maturity claim waits until roll completes)? Owner picks the rule; PRD records it; no silent unlocked reentry; no native-note truncation.

## Confirmed

Standard interfaces (`SE`, `SY`, `ERC4626`) do not establish asset/units, expansion equations, or facade conversions — those remain engineering specifications. FoT/rebase blocker unchanged. **Implementation unauthorized.**

## 4. Moderator disposition

Accepted: custom Weighted-behavior family, new token/receipt/NFT internals with standard interfaces, unified-vault/facade surfaces and ratings, bonded fresh entries, unlocked staking of existing liquid DETF, existence of primary proportional burn, immediate next-processed-epoch income release, direct-LP maturity cliff, contribution-time-only external-note issuance, maximum DETF lock bound and no extension/blocking by matured unclaimed bonds at rollover.

Not accepted: mandatory in-kind-only payout; assumed NFT transferability; literal independent claims on raw staked DETF and its receipt; uncapped locks; automatic unlocked fresh issuance after expiry. Grok's proposed active-market maturity assignment for each external installment is a candidate, not a new owner decision. MiniMax's attempt to equate unlocked issuance, next-epoch release and roll completion is not adopted. Those are distinct events.

The remaining narrow lock question concerns the release class and Pendle market assignment of a **new installment** from previously uncollected native NetNet notes. It does not reopen the user's no-extension rule for already minted DETF positions. The native external note schedule is not truncated. If processing requires a deposit into an expired Pendle market, the already-selected expired-route restriction remains operative.

For the final short epoch intersecting Pendle maturity, the user's maturity cap is binding; implementation must specify terminal settlement ordering without extending that cap or inventing a full-epoch holding minimum. Exact wrapper-installment release assignment remains OPEN.

The PRD is amended to v0.3. Formula/route details and engineering proof remain incomplete. Reproducing Weighted behavior does not prove exact behavioral parity, policy compatibility, security or economic soundness. No implementation authorized or performed.
