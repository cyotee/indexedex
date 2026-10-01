# NetNet–Pendle DETF v0.10 — council consistency review

Date: 2026-09-23 (moderator environment date). Research/document authoring only.

## Scope and verdict

Question: Is the current PRD consistent, and what requirements still need human clarification?

Reviewed `../NETNET_PENDLE_DETF_PRD.md` v0.10, `../REQUIREMENTS_QUESTIONS.md`, relevant canonical law and external interface specifications. Line citations below refer to the inspected repository snapshot; they are not immutable revision pins. The PRD and tracker were not changed in this round.

**Verdict:** The latest product choices are recorded consistently. The highest-priority issue is an identified conflict between the selected swap-based share flows and full ERC-4626/Pendle SY semantics, not uncertainty over the already selected token identities. Additional economic choices remain open. This is a reviewable draft, not an executable or standards-certified specification.

## Protocol and attribution

Three independent first passes with the same question/context were followed by three same-session combined cross-reviews. Each continuation received the other two original final answers verbatim, marked untrusted model evidence. No earlier cross-review answer was supplied. Independence was informational: retained sessions also contain earlier discussion history. Six synchronous calls completed this round without a reported participant failure.

| Researcher | Preserved session | Reported model metadata |
| --- | --- | --- |
| Astra | `ses_f4edf055affe5dSHkzSUwwINjw` | `openai/gpt-6-astra` |
| Grok | `ses_f4edb8e85ffeCS8Miy5XkGe6Nk` | `xai/grok-4.6` |
| MiniMax M3 | `ses_f4ea97c4dffelmRAaq1xOU5Lmt` | `minimax/MiniMax-M3` |

These are exposed/session identity metadata, not independent provider verification. Original final answers remain in these sessions and the task transcript, including the verbatim copies exchanged for cross-review. The following is attributed consolidation, not a replacement purportedly reproducing those originals.

### Initial positions

- **Astra:** explicit mint/burn semantics conflict; accounting views need definition; contraction funding remains open; tracker stale; separate raw-DETF SY requirement in existing family law needs an explicit custom-family departure.
- **Grok:** accepted all recent choices, emphasized header/tracker cleanup and existing income, failure, NFT and external-bond funding questions; initially treated standards compatibility primarily as unproved engineering.
- **MiniMax M3:** emphasized incentive-zero behavior, equality, multi-input SY and feature-parity wording. Several of these findings were false positives, retained here as attributed history rather than accepted requirements.

### Cross-review corrections and unresolved dissent

- Grok accepted Astra's stronger finding: swap-only deposit and non-burning withdrawal conflict with specified share mint/burn semantics. MiniMax also accepted this central concern.
- Astra and Grok rejected reopening exact equality: R38 already says swap at price >= 1 NET per DETF.
- Astra and Grok rejected treating stored zero as an incentive-disable flag. If the resolved effective incentive is zero, the formula produces `qQuote=q`; that does not itself change the burn branch to a swap.
- Astra rejected MiniMax's claim that one SY cannot support NET/sNET/USDG. The moderator independently confirmed the interface has `tokenIn`, `tokenOut`, `getTokensIn` and `getTokensOut`. Multiple supported tokens are not the standards conflict.
- MiniMax's cross-review nevertheless continued to classify multi-input SY and V2 feature-parity scope as standards conflicts. **Not adopted:** neither conclusion follows from the cited interfaces or PRD.
- MiniMax downgraded elected-income financing and historical-income ownership to engineering gates. **Not adopted:** who is entitled to which income and what finances an award are economic requirements until explicitly selected. Implementation mechanics are separate.
- Grok/MiniMax called the v0.6 controlling-header label a contradiction. Astra qualified it; moderator agrees with the qualification: v0.10 precedence is explicit at PRD line 26. Consolidation would improve readability, but an old version label alone is not an operative contradiction.
- V2 parity includes supported behavior as well as selectors. Do not narrow the requirement to selector presence, invent formerly unsupported features, or add fees outside the approved fee scope.

## Findings and evidence

### F1 — standards semantics: identified conflict, not merely absent tests

**Observed:** PRD lines 286–290 require deposit-side swaps delivering existing DETF and at/above-peg withdrawal-side swaps without burning DETF. DETF itself is the share token; a separate wrapper is expressly excluded at lines 295–297.

**Observed external requirements:** ERC-4626 specifies deposit/mint as minting shares and withdraw/redeem as burning shares; its specification describes shares as a fractional ownership claim on underlying holdings. Pendle's current `IStandardizedYield` describes deposit as minting shares and redemption as burning them, including the ownership meaning of `burnFromInternalBalance`.

**Conclusion:** the selected token flows do not satisfy those mint/burn semantics as written. `asset() = sNET` resolves asset identity, not this conflict. ERC-4626 leaves substantial freedom in internal investment/accounting, but that does not erase its externally specified share behavior. Matching selectors and token amounts is not full standards compliance or proof that a particular integrator is compatible.

**Recommended disposition:** preserve the selected economics and describe the interfaces as custom routes using ERC-4626/Pendle-SY signatures, with a documented deviation and integration-compatibility matrix. Do not silently introduce wrappers, fresh liquid issuance or proportional reserve claims. If strict compliance remains a release requirement, the conflict must be resolved explicitly before implementation. Owner approval cannot make a conflicting compliance claim true.

### F2 — below-peg failure response remains open

PRD lines 274–280 distinguish quotation from actual funding. Line 301 fixes at/above-peg swapping but leaves otherwise ineligible or insufficiently funded below-peg contraction unresolved. A virtual quote bonus cannot create real payout assets. Decide failure behavior; do not infer automatic swap fallback or pending entitlements. Independently prove price-reference integrity, funding conservation, exact-output inversion and post-operation price effects.

### F3 — public swap exhaustion is an economic boundary

PRD line 203 expressly leaves open whether adverse pricing merely discourages principal liquidation or enforces a hard boundary. This is separate from the already selected component-wise hook-LP exit rights. A current-book proportional exit does not protect holders from authorized common strategy trading losses.

### F4 — income rights and elected reinvestment need economic definitions

PRD lines 229–244 select current component claims but leave separately booked historical-income rights and transfer treatment open. Line 353 requires a permitted financing source and participant allocation for elected reinvestment. Do not count current LP backing and a historical payable twice, or spend DETF backing sDETF to fund an invented award.

### F5 — external-bond lifecycle questions remain open

PRD R12 at line 74 and O08 at line 439 leave replacement purchase funding/authorization unresolved. NFT transferability remains open at line 404; tracker Q8–Q9 at lines 29–30 also records harvest/reinvestment failure policy. Native full maturity, mandatory Keep-YT reinvestment and successor-market routing remain settled.

For failure discussions distinguish an atomic failed initial purchase, which restores the original payment state, from an atomic failed harvest/reinvestment of an already funded native note, which rolls back that attempted claim. A hypothetical wrapper/batch function does not prove native aggregate-note gas liveness.

### F6 — documentary drift and authority reconciliation

- Tracker line 7 still says v0.9; Q4/Q10/Q12 at lines 25/31/33 have residual language that can reopen resolved mapping questions. Update status and append the v0.10 human answers in a separately authorized reconciliation; preserve historical answers.
- PRD line 18's v0.6 heading can be consolidated with the explicit v0.10 precedence at line 26. Editorial cleanup is not a new owner choice.
- `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md:1129–1137` requires a separate raw-DETF SY wrapper for the current family. Record the custom family's direct DETF-as-SY departure explicitly alongside the already recorded departures. Do not apply either family’s assumptions to the other silently.
- `CLAUDE.md:45` and `docs/agent/INDEXEDEX_AGENT_LAW.md:89–101` retain the FoT/rebasing-underlying authority blockers. No research finding waives them, and no repeated tax-exemption preference question is needed.

## Human decision checkpoint

Prioritize these questions; no answer is selected by this report:

1. **Interface compatibility goal:** keeping the chosen economics, is custom signature/ABI compatibility with explicitly documented deviations the intended deliverable, rather than strict ERC-4626/Pendle-SY conformance? Which consuming integrations must actually work?
2. **Below-peg failure:** when eligible contraction cannot fund the required payout, should the whole call revert, or is another explicit behavior required? A fallback swap has not been approved.
3. **Income exhaustion:** may public swaps sell Pendle principal at the adverse curve price after available income is exhausted, or must the route stop at that boundary?
4. **Income rights:** should hook-LP transfers carry all current accrued value with no seller-retained historical claim? Separately, what funds elected staker reinvestment and how is each participant's allocation determined?
5. **External-bond lifecycle:** is purchase using authorized proceeds of a DETF-out swap/eligible contraction approved; may the NFT transfer with its unchanged obligations; and should failed mandatory reinvestment revert harvesting or leave explicitly locked pending NET? These are distinct subdecisions, not one bundled default.

Other outstanding requirements, including reward access during locks, USDG-bond scheduling and expansion economics, remain in the PRD/register; this prioritization does not resolve or remove them.

## Standards and source record

Primary external sources accessed by the moderator on 2026-09-23:

- https://eips.ethereum.org/EIPS/eip-4626 — Final ERC-4626; Specification, deposit/mint/withdraw/redeem, conversion views, limits and Security Considerations. A final standard, not an installed runtime version.
- https://raw.githubusercontent.com/pendle-finance/pendle-core-v2-public/main/contracts/interfaces/IStandardizedYield.sol — unpinned `main`, Solidity pragma `^0.8.0`; deposit/redeem comments, token discovery and `exchangeRate`. No deployed-version equivalence is claimed.
- Context7 lookup `/openzeppelin/openzeppelin-contracts` preceded the moderator's primary-source check. Its returned snippets are secondary evidence and are not treated as normative, version-pinned implementation code.

No new dependency/runtime versions, live oracle addresses, active markets, code hashes, tax configuration or deployment blocks were verified. Existing PRD vendor/version notes remain historical provenance, not refreshed deployment evidence.

## Confidence and implementation handoff

High confidence in the observed current-document decisions, stale tracker and ERC-4626 supply-semantics conflict. Pendle's cited interface establishes a semantic mismatch, but acceptance by any particular deployed integration is untested. No claim of economic solvency, peg stabilization, conformance certification, bounded note-array liveness or security follows from council agreement.

The council completed this bounded round. No PRD/tracker edits, code, tests, shell, simulation, deployment or transaction execution occurred. Only this consolidated review document was authored. A future authorized implementation plan must pin sources, specify accounting views and price/failure transitions, resolve authority departures and map acceptance criteria to evidence; writing such a plan would not authorize executing it.
