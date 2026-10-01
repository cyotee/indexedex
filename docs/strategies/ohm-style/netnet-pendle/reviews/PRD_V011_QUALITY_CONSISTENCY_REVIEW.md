# NetNet–Pendle DETF v0.11 — quality and consistency review

Date: 2026-09-24. Research/document authoring only. PRD and requirements tracker unchanged.

## Scope and verdict

Question: Review the PRD for quality and consistency; identify necessary requirement clarifications.

**Verdict:** v0.11 and the tracker capture the latest human decisions consistently. The architecture and accounting responsibilities are substantially clearer than v0.10. No verified contradiction requires reopening the selected interfaces, fee-oracle identities, public LP ownership, NFT transferability, exact-peg behavior, atomic failure policy or participant-specific staking debit.

The highest-priority remaining issue is the scope of the anti-cycling statement: excluding the contraction incentive from the dedicated reinvestment flow does not establish that independently allowed contraction followed by a bond purchase cannot produce similar economic effects. Exact bond/expansion terms and a few remaining lifecycle choices also need specification. The PRD is a sound basis for continued requirements work, not evidence of economic safety or implementation readiness.

## Council protocol and preserved evidence

Six synchronous task calls completed: three independent first passes with the same context, then one continuation per original session. Every continuation received both other original final answers through the preserved files below, marked untrusted model evidence. No earlier cross-review artifacts were supplied. Retained sessions contain earlier discussion history; independence refers to this round's first-pass findings, not erased memory.

| Researcher | Original final answer | Preserved session | Reported model metadata |
| --- | --- | --- | --- |
| Astra | [V011_ASTRA_ORIGINAL.md](./V011_ASTRA_ORIGINAL.md) | `ses_f4edf055affe5dSHkzSUwwINjw` | `openai/gpt-6-astra` |
| Grok | [V011_GROK_ORIGINAL.md](./V011_GROK_ORIGINAL.md) | `ses_f4edb8e85ffeCS8Miy5XkGe6Nk` | `xai/grok-4.6` |
| MiniMax M3 | [V011_MINIMAX_ORIGINAL.md](./V011_MINIMAX_ORIGINAL.md) | `ses_f4ea97c4dffelmRAaq1xOU5Lmt` | `minimax/MiniMax-M3` |

Metadata is not independent provider attestation. Original answers remain unchanged; cross-review responses are retained in the original sessions/task transcript. This report consolidates their findings with moderator corrections rather than treating model agreement as authority or proof. No participant continuation failed.

## Quality assessment

### Strengths observed

- One current controlling specification and explicit later-decision precedence: PRD lines 7–28.
- R39–R45 separate ownership-limited quotation, interest-only trading, incentive-free reinvestment, LP transfers, staking backing and external-bond atomicity: lines 103–109.
- Clear distinction between hook-LP component ownership and liquid DETF route-based outputs: lines 238–255.
- A concrete participant-accounting example distinguishes consuming existing stake from wallet inputs: lines 379–381.
- Requirements register Q4–Q13 is synchronized to the new choices and preserves remaining work rather than reviving historical alternatives: tracker lines 25–34.
- Acceptance criteria cover failed delivery, non-drainage, repeated cycles, participant backing and atomic external-note processing: PRD A26–A30, lines 504–508.

### Improvements recommended, not applied

1. Add a compact operation matrix distinguishing ordinary swaps, incentivized contraction, elected burn/rebond reinvestment, direct bond contribution, hook-LP redemption, staking reward minting and native-note collection. Specify quote domain, actual token/supply effects, funding components, incentive applicability, lock effects and failure semantics for each. This need not prescribe new public selectors.
2. Replace broad anti-cycle language with the precise intended guarantee and associated tests. Direct reinvestment, router-composed operations and separately executed contraction/bond sequences must not be conflated.
3. Pin the meaning of “normal bond-contribution calculations” to explicit equations or a current reference plus a list of custom-family departures. Selector parity or a function name is not enough to specify economics.
4. Define the owned reserve book mathematically: ownership snapshot, component scaling, self-leg treatment, fees and realizable output. Do not replace the selected quote domain with a full-pool quote capped after calculation.
5. Define interest provenance consistently across unclaimed amounts, actual claimed cash, residue and conversions. A claim changing custody state must not erase earned value or relabel principal as income. Include any third-party claim paths supported by the pinned implementation.

## Findings requiring distinction

### F1 — route composition is not the same as the reinvestment entrypoint

**Observed:** PRD lines 265–271 apply the input incentive to eligible contraction; lines 368–371 exclude it from elected reinvestment and apply normal bond-contribution calculations afterward. Line 373 broadly says no caller or nested route may obtain the contraction bonus merely by cycling reinvestment.

**Inference:** a user may execute a separately permitted below-peg contraction and later use its actual proceeds for a normal bond purchase. The direct reinvestment function's `qQuote=q` does not prevent that sequence. An external sequence may have different fees, price impact, eligibility, locks and outputs, so equivalence and profitability are **not established**.

**Clarification needed:** is the guarantee specifically that the dedicated reinvestment flow never applies the contraction bonus, while independently permitted operations retain their normal economics? Or is a broader economic no-profitable-cycle property intended? The latter requires explicit analysis before selecting any controls. Do not invent caller bans, token provenance restrictions, cooldowns or new fees.

### F2 — “normal bond” still needs an authoritative economic definition

PRD lines 353, 370–377 allow next-processed-NET-epoch release, potentially seconds after entry, but do not fully pin the duration multiplier, purchased-principal quote, fee/reward allocations or interaction with expansion. These are not merely storage/rounding choices. Preserve the selected short release and funded mint/stake flow; identify which existing calculation is inherited and which inputs represent this custom bond duration. Do not automatically grant a full-maturity bonus or remove an existing bonus.

### F3 — public NET output needs route-scope clarity

PRD line 210 says NET/sNET outputs can use the same accrued SY, while line 212 explicitly restricts the sNET trading leg to interest and preserves the separate USDG leg. A NET payout might be a conversion of the interest leg or a distinct route through other inventory; the available text does not exhaustively map it.

Clarify whether an ordinary public NET-out trade through the NET/sNET leg inherits the same interest-only inventory restriction. Do not broaden this question into denying separately authorized USDG-leg routes, hook-LP component exits or owned-reserve contraction/reinvestment. Output token identity alone does not specify funding provenance.

### F4 — rewards during principal locks remain genuinely open

PRD lines 354–355 expressly leave rewards during direct-bond locks and native-note vesting unresolved. The fact that minted NET-DETF backs the staking claim does not alone decide when its reward portion can be withdrawn. Select whether rewards are separately claimable before principal release and, if so, ensure accounting leaves the locked principal funded. This does not reopen the already selected principal release times.

### F5 — mathematics and price-state specification, not new architecture votes

- Owned-reserve domain: lines 261–287 need a complete state transition, not just the name `ownedReserveSnapshot`. Include zero/tiny DETF ownership, external LP joins/exits, share rounding and LP redemption before conversion.
- Price reference and expansion: line 347 and O02/O05 still require the authoritative NET-rated price measure and actual economic expansion rule. Engineering should propose a reference-backed specification rather than ask the owner to choose low-level implementation APIs without alternatives/evidence.
- Non-drainage: R40 and line 212 already forbid completely draining the interest trading leg. No new owner vote is needed to enforce the invariant. Exact-output attempts inconsistent with it cannot succeed; quote/rounding/limit behavior requires proof. Do not invent a percentage reserve floor or forbid a legitimate holder from redeeming its own hook-LP allocation.
- Atomic external-note processing does not solve aggregate native-note gas liveness. An operation being retryable in state is not proof that it can ever complete within gas limits.

## Attributed cross-review disposition

### Astra

Initial emphasis: composition risk, interest provenance, complete owned-book mathematics and unresolved economic parameters. Cross-review retained those findings and correctly separated invariant enforcement from owner choices. Astra's renewed question about principal versus rewards-only reinvestment is not promoted: the human-confirmed 100/40 staking example and wallet-input rule already establish participant input conversion. Any remaining authorization interface detail should be specified without silently restricting the accepted position types.

### Grok

Initial emphasis: separating reinvestment from ordinary redemption, sNET non-drainage and shared-owner isolation. Cross-review agreed with Astra on composition and bond economics. Corrections:

- A distinct operation does not necessarily require a new selector. No interface design is selected here.
- V2 parity means supported behavior, routes and accounting as well as selector presence; it is not merely “installed-selector parity.”
- The original staking example is 100 staked, consume 40, retain 60 plus replacement. Wallet-funded reinvestment leaving existing stake untouched is a separate case; do not conflate them.
- Reward claiming and interest claiming are distinct. Grok's reference to `redeemRewards(hook)` does not verify how SY interest becomes cash. The pinned interest path must be inspected before making that API claim.

### MiniMax M3

Initial emphasis: version labels, fee wording, successor SY identity and terminal-epoch ordering. Several claims were not adopted:

- The alleged v0.10 labels at PRD lines 87/91/102/105 were not present in the inspected text. Old retained headings are provenance, not demonstrated conflicting requirements. Cross-review did not adequately retract this false positive.
- The claim that usage fees are exclusively per-swap was unsupported; LP-mint usage fees and their oracle key are explicitly owner-selected. No new fee-policy question is warranted.
- Describing the already selected non-drainage invariant as a new caller restriction is incorrect. Enforcing a state invariant need not discriminate between callers.
- Separating quotation functions implements the dedicated reinvestment rule but does not answer whether an independently permitted contraction-plus-bond sequence can produce an economic cycle. The report retains Astra's distinction.

### Remaining dissent

Researchers differ on whether self-leg `tokens()` membership, residual handling and successor SY identity should be presented as immediate owner questions. Moderator disposition: self-leg representation and finite-precision enforcement belong first in an engineering specification. Successor identity/equivalence remains a genuine documented policy detail at line 389, but metadata equality alone would not establish equivalent risk; it is not newly resolved or prioritized ahead of the economic questions above.

## Human checkpoint — four prioritized clarifications

1. **Anti-cycle scope:** does “no incentive on reinvestment” govern the dedicated reinvestment flow, while ordinary contraction and a later ordinary bond retain their respective economics? If a broader no-profitable-cycle requirement is intended, commission analysis before selecting restrictions.
2. **Normal bond terms:** which existing bond-contribution formula and duration/fee/reward rules should the next-epoch reinvestment inherit? Identify the reference and departures; do not change the settled release time.
3. **NET-out route:** should ordinary NET output through the NET/sNET trading leg use the same interest-only inventory as sNET output? Map any separate alternative route explicitly rather than inferring its funding from the requested token.
4. **Locked rewards:** may rewards on locked bond positions be claimed before principal release, or do those rewards remain locked with principal?

Other explicitly open matters—USDG-bond schedule, expansion economics, successor-market validation bounds and deployment/parameter pins—remain in the PRD. This prioritization does not resolve them or authorize implementation.

## Evidence, confidence and implementation handoff

Local sources read during this review, accessed 2026-09-24:

- `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md` v0.11, especially lines 195–287, 345–389 and O01–O10/A26–A30.
- `docs/strategies/ohm-style/netnet-pendle/REQUIREMENTS_QUESTIONS.md` lines 7, 25–34 and latest answer records.
- `CLAUDE.md`, current `DETF_ALIGNMENT_PRD.md` and canonical law remain governing references; this report does not supersede them.
- `.claude/skills/indexedex-adversarial-testing/SKILL.md:58–84` supplies cycle, snapshot, atomicity and authorization test themes, not permission to run tests or override later PRDs.

No new external documentation search, dependency/runtime version pin, deployed code/fee/oracle verification, economic simulation, test run or transaction was performed by the moderator in this round. Assertions about external interest-claim APIs are therefore not certified here; convert them into checks against the pinned implementation. Repository line references are snapshot-relative, not immutable commits. Earlier external URLs/version notes remain historical sources, not refreshed evidence.

Confidence is high that the latest owner choices are captured and most earlier ambiguities are closed. Confidence is moderate in the completeness of remaining economic requirements; no profitability, solvency, peg stabilization, security or liveness proof is claimed. The original model findings are evidence, not authority.

**Separate implementation handoff:** after human clarification, prepare an operation/state matrix, explicit owned-book and issuance equations, integration and authority mapping, and an acceptance-test plan in a separately authorized task. Do not execute it. This round authored only the three original-review records and this consolidated report; the PRD, tracker, code, configuration and historical reviews are unchanged.
