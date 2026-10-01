# Kimi K3 — cross-review: concrete open-items audit

| Field | Value |
| --- | --- |
| Reviewer | Kimi K3 (`kimi-code-plan-global/k3`, variant high), retained session |
| Date / access date | 2026-09-28 |
| Inputs (untrusted attributed evidence) | `astra-original.md`, `grok-original.md`, `minimax-original.md` in this directory, read complete. No peer cross-reviews read. My original `kimi-original.md` preserved unchanged; corrections in §2. |
| Direct source checks | `UniswapV4DetfDFPkg.sol:258`; `IUniswapV4Detf.sol:42`; `IDETFNFTVault.sol:205–207` (D7/D21); `IMultiVaultWeightedDetfDFPkg.sol:67`, `ISingleStandardExchangeDETDFPkg.sol:61`, `IMixedBufferMultiVaultStableDetf.sol:58` (creator field, `0 → feeTo` convention); `VaultFeeOracleRepo.sol:51` (creator **weight**, not address); `DETFFundedStakingRepo.sol:201` (`creatorRecipient_` required); plan:128,203,779–798; `ROBINHOOD_MAIN.sol:36–53,184–201` (`DEFAULT_FORK_BLOCK = 20_714_383`, four Pendle anchors). |
| Constraints | No shell/tests/implementation/delegation. One review, then stop. |

## 1. Four-way agreements (verified against current documents)

All four originals converge, and I re-verified each point:

1. **G1/address authority:** per the human ruling, all deployed-identity/address/block items are implementation/fork obligations using Pendle documentation addresses and `ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK = 20_714_383` (`:52–53`, anchors `:195–201`). Withdrawn as research blockers by all four. YT V1/V2, factory fees, gauge/PENDLE identity, warmup, tax predicates, staking equivalence: fork-validation rows, not spec gaps.
2. **Force-claim reconciliation:** the "missing mechanism" allegation is withdrawn four-way. Native-derived C (recomputed from `userInterest` reads), role-exclusion H, capture-credit-before-sync, and once-only booking already determine every reachable case (force-claim → unbooked credit → consume or sync). No provenance mechanism is required; demanding one would violate L2. Remainder is one §6.6.4 consolidation paragraph plus the already-written §6.6.6 vectors.
3. **Provider/caller rounding:** the sample (`q=1e18 → a=Ic → rate=Ic×1e9`), the normalization (PRD §4.5), the forbidden substitutions (no whole-book redeem floor, no projected `exchangeRate()` as sNET quote), and the Weighted fee order are all already pinned (plan §6.5.6, §6.4). Remainder is adapter wiring and dust-boundary tests.
4. **Owned-HLP/Keep-YT chronology:** transitions, per-stage math, quote recipe, limits and failure rules are specified (PRD §§6–7, 11.4; plan §§6.2, 6.4, 6.5.5, 6.6.5, 7.1–7.2, 10). The call-graph/argument-source table is NN-14 wiring work, not a design hole. All four withdraw the "chronology" blocker.
5. **Exact-output residual:** R22's deliver-or-revert is the selected residual rule; for `0<I≤1e18` the inverse is exact; `I>1e18` unrepresentable dust targets revert — no residual beneficiary, no dropped ERC-4626 route, no warehousing. Grok and MiniMax classify fully RESOLVED; Astra keeps it as an arithmetic/test condition; my original said RESOLVED + horizon-bound deliverable. No disagreement of substance: the NN-18 horizon bound and revert vectors are test/analysis work, and no one may invent a dust account. **I adopt Grok's cleaner statement and drop my "composition item" remnant entirely.**
6. **G0:** PROCESS ONLY (maintainer instruction reconciliation), four-way, per tracker NN-13. Approval is recorded, not pending.
7. **Tracker hygiene:** stale "mechanism required / composition pending" labels are documentation reconciliation (NN-20/moderator), not requirements.

## 2. Corrections to my own original

### 2.1 I missed a concrete gap: creator recipient binding (concede to Astra — verified)

Astra's gap A is real and my audit overlooked it. Direct trace:

- The funded-staking design **requires** a creator recipient: persistent `feeWeight/creatorWeight` (plan:779), allocation `allocation_.creator` (plan:796), `issue fee/creator funded receipts` (plan:798), and `DETFFundedStakingRepo.sol:201` issues to `creatorRecipient_`. PRD:55 selects creator participation in expansion. This recipient is needed at the first bond/expansion — a concrete reachable required transition.
- The Universal reference binds it through PkgArgs: `IUniswapV4Detf.sol:42` (`address creator;`), `UniswapV4DetfDFPkg.sol:258` (`creator: args.creator`). Every sibling DETF package carries the same field with the convention **`creator == 0 → feeTo` owns the creator position (D21)** (`IMultiVaultWeightedDetfDFPkg.sol:67`; `ISingleStandardExchangeDETDFPkg.sol:61`; `IMixedBufferMultiVaultStableDetf.sol:58`; `IDETFNFTVault.sol:205–207`, D7/D21).
- The custom family's selected PkgArgs is exactly three addresses (R55; plan §4.1) with no creator field, and plan:128 expressly states the source is not established and **forbids both derivations** ("no implementation may guess deployer/current feeTo as creator"); plan:203 repeats it. The fee oracle stores the creator **weight** (`VaultFeeOracleRepo.sol:51`, a WAD share), not the recipient **address** — so the oracle is not a source for the identity either.

Assessment: this is a genuine **narrow configuration-binding gap**, not economics (weights, formula and rights are unchanged). The existing D21 convention is the obvious candidate resolution, but the plan's express prohibition means adopting it (or adding a creator field, which amends R55's selected three-address surface, or naming another identity) is a selection the plan deliberately deferred ("Record that exact configuration gap in W10"). **Classification: ACTUAL SPEC GAP (configuration binding), blocking W10 initialization only; all math/source work unblocked.** Minimal deliverable: one-line binding decision — moderator may propose adopting the existing D21 zero→feeTo convention as the minimal existing-source citation; because plan:128 forbids feeTo-by-guess, that adoption needs explicit owner/moderator confirmation, not silent reuse. I adopt Astra's finding with the D21 evidence added.

### 2.2 Downgrade: L4 post-completion excess lock class (from owner-level to one-line derivation)

My original's T1 (does post-completion excess principal inherit the satisfied E+1 target or get a fresh hold?) is, on reflection with Grok's and MiniMax's analysis, **determined by existing text**: R17 ("Income reinvestment unlocks immediately after the next processed NET epoch… no newly imposed full-epoch holding requirement") and the v0.28 purpose statement ("hold newly processed final principal across a subsequent epoch/rebase opportunity, not… an extra full eight hours") establish that the next-processed-epoch hold attaches to **each newly funded principal event**, not once per note. Reading the E+1 target as a one-time field that later funded principal ignores would exempt post-completion principal from the standing rule with no textual basis. So the derivation "new funding at processed epoch E′ unlocks at E′+1, no more and no less" follows existing rules. **Corrected classification: RESOLVED by derivation; one-line documentation confirmation (IMPLEMENTATION), not an owner question.** Astra classifies this same transition as part of its gap B; I record that as remaining dissent (§3.3) — her reading treats the singular "sets…unlock to E+1" as exhaustive, but that reading creates an unprincipled exception to R17 that no clause selects.

## 3. Retained dissent

### 3.1 L4 terminal retirement and late-gift disposition — I maintain one narrow gap; Grok/MiniMax dissent

**Grok's position:** "The prohibitions already pick the safe required behavior… No user-facing transition requires a destructive retirement. Inventing burn versus abandon would be a new requirement." **MiniMax:** the mature-and-empty predicate is composable within the prohibitions; IMPLEMENTATION/TEST.

**My maintained position (narrowed):** the prohibitions (plan:716 — no `pendingFor==0` substitution, no silent burn of recognized rights, no proxy-ownership transfer, no permanent DORMANT/nonburning adopted *as if selected*) fully determine **operative** behavior: positions persist with rights intact, and no required user transition (purchase, collect, reinvest, claim, withdraw, transfer) is blocked or undefined. On that, Grok/MiniMax are right and I absorb the point: **this gap blocks nothing.** But the terminal feature itself remains expressly unassigned: the tracker requires "exact final NFT retirement conditions" (NN-15; H03 "specify mature-and-empty retirement/late gifts separately"), the plan exposes `retire(tokenId)` (§5.4), and plan:716 declares the candidate outcomes **non-interchangeable** — burn (late gifts forfeited), permanent retention (late gifts keep funding the old NFT), abandon (rights stranded). If retirement is offered and executed, the late-gift disposition is an entitlement choice with no derivable default; forbidding silent selection is not selecting. Per the moderator's instruction I do **not** pretend preservation selects the terminal requirement — preservation is the operative default, not the chosen terminal semantics.

**Classification: ACTUAL SPEC GAP — narrow, contingent, non-blocking.** It becomes live only when the terminal feature is specified, and it can be closed by one owner confirmation (including ratifying "no irreversible retirement; permanent retention with continued collection" — the no-forfeiture option). This is a checkpoint item, not a design project.

### 3.2 MiniMax's "predicate composable" overstatement

MiniMax says the implementer can compose the mature-and-empty predicate "without inventing economics." For the **gate predicate** (intended-note complete + zero funded principal + zero rewards + no unsettled obligations) that is true — plan §7.3's "Drained candidate" already defines it. But the predicate is not the gap; the gap is what happens **after** an irreversible action with future arbitrary-recipient gifts possible (`BondDepository.sol:104–165` accepts arbitrary recipients). MiniMax's own composition cannot choose among forfeit/retain/forward without an entitlement decision. Its "withdrawn" row for L4 therefore overstates.

### 3.3 Astra's L4 gap B — partially adopted

Astra's transition 1 (post-completion excess lock) I downgrade per §2.2; her transition 2 (retirement + late gifts) is my §3.1. Net: I adopt half of her gap B.

## 4. Final corrected classification

**ACTUAL SPEC GAPS (two, both narrow):**
1. **Creator recipient configuration binding** (§2.1) — required recipient, no selected source, both derivations expressly forbidden, existing D21 convention available but needs explicit adoption. Blocks W10 initialization only. One-line confirmation closes it.
2. **L4 terminal retirement offer + late-gift disposition** (§3.1) — contingent, non-blocking; one owner checkpoint with alternatives (offer burn with stated disposition, or ratify permanent retention). 

**RESOLVED (design), with documentation confirmations only:** force-claim reconciliation; provider rounding; owned-HLP/Keep-YT chronology; exact-output residual (R22 revert); L4 post-completion excess lock (E′+1 per funding event via R17 + v0.28 purpose); NN-03; L1/L2.

**IMPLEMENTATION/TEST (no decisions):** all G1/fork rows at `DEFAULT_FORK_BLOCK` (YT V1/V2 body, factory fees/treasury, gauge/PENDLE vs SY identity, warmup, tax predicates, staking mirror, decimals); §6.6.4 consolidation paragraph + §6.5.8/§6.6.6/§11 vectors; NN-14 call-graph/argument-source table; provider adapter wiring; funded-gons notification adapter; V2 SE parity; ABI/wiring completion; NN-18 horizon arithmetic; NN-19 acceptance execution.

**PROCESS ONLY:** G0/NN-13 maintainer reconciliation; NN-20 stale-label hygiene (including the tracker/plan status lines this audit withdraws).

**Owner-question count:** **two narrow confirmations** (creator binding; L4 terminal disposition) — or **one** if the moderator adopts the existing D21 `creator == 0 → feeTo` convention as an already-existing source citation rather than a new question. Grok and MiniMax say zero; Astra says two; I land on two, differently composed (I drop the excess-lock transition both Astra and my original retained).

## 5. Concise answer to the user

The six challenged areas are resolved by current text plus the human address/block/fork ruling; the old blockers are withdrawn four-way. Two narrow items survive: **(1) creator recipient binding** — the funded-staking design must pay a creator share but the selected three-address PkgArgs has no creator source and the plan forbids guessing deployer/feeTo; the existing DETF convention (`creator == 0 → feeTo`, D21) is the one-line candidate fix needing explicit adoption; **(2) L4 terminal retirement/late-gift disposition** — non-blocking, contingent on offering `retire()`, one checkpoint with alternatives (including ratify permanent retention). The post-completion excess lock follows existing rules (E′+1 per funding event). Everything else is implementation, fork validation at the library default block, or process hygiene. Facts are cited current text; classifications and the two gap determinations are my reasoned inference. No tests run; no execution authorized.

Saved: `docs/research/netnet-concrete-open-items-audit/kimi-cross-review.md`. Original preserved at `kimi-original.md`. Returning to the moderator; stopping.
