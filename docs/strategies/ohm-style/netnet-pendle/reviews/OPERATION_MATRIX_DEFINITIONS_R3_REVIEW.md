# Operation matrix definitions — R3 council consolidation

Date: 2026-09-24. Basis: current operation matrix, PRD v0.14 and the human's later matrix clarifications. Research only; matrix, PRD and tracker unchanged.

## Verdict

The matrix distinguishes the selected operations well. Remaining UNKNOWNs include both genuine product choices and technical specifications; they should not all be sent to the owner as undecided economics. Five near-term clarification topics are listed below. No new approvals, numerical defaults, fees, custody choices or public endpoints are selected by this review.

Settled: component/instance deployment split; Package immutable dependencies and PkgArgs market/Bond Depository/Staking split; trusted-factory-first market validation; new successor SY allowed; singleton intent; first bond supplies initial liquidity; public LP access; principal cliffs with earlier reward claims; accrued value transfers with LP; dedicated reinvestment without contraction bonus; normal independent contraction/bond economics; atomic native-note processing; standard-interface owner disposition. Matrix 05–07 are ordinary ERC20 surfaces with their existing accounting obligations, not additional token-level lock mechanisms; 04 includes broader views/previews.

## Round and attribution

Four independent first passes were followed by four combined cross-review continuations. Each researcher resumed its original session and read all three other ORIGINAL artifacts together, marked untrusted model evidence. No earlier cross-review was supplied. All eight calls completed; no participant reported a guard denial or lost context this round. Preserved sessions contain prior discussion history; independence is informational for this round.

| Researcher | Original artifact | Session | Reported metadata |
| --- | --- | --- | --- |
| Astra | [Original](./DEFINITIONS_R3_ASTRA_ORIGINAL.md) | `ses_f4edf055affe5dSHkzSUwwINjw` | `openai/gpt-6-astra` |
| Grok | [Original](./DEFINITIONS_R3_GROK_ORIGINAL.md) | `ses_f4edb8e85ffeCS8Miy5XkGe6Nk` | `xai/grok-4.6` |
| MiniMax M3 | [Original](./DEFINITIONS_R3_MINIMAX_ORIGINAL.md) | `ses_f4ea97c4dffelmRAaq1xOU5Lmt` | `minimax/MiniMax-M3` |
| Kimi K3 | [Original](./DEFINITIONS_R3_KIMI_ORIGINAL.md) | `ses_f2abe1e07ffe0izL8DAH8boF2W` | `kimi-code-plan-global/k3`, high variant |

These are supplied routing/session metadata, not provider attestation. Originals remain unchanged. Cross-review responses are retained in the task transcript and corresponding sessions. This report is moderator consolidation, not a purported verbatim replacement for the originals.

## Prioritized human questions

### 1. First-bond opening parameter and selectable payment denomination

**Evidence:** matrix row 02–03, Input/Quote (`NETNET_PENDLE_OPERATION_MATRIX.md:16,70–85,100`); PRD §10.4, especially `NETNET_PENDLE_DETF_PRD.md:441–451`.

The first-bond formula, liquidity seeding and reference full-book additional-leg sizing are selected. The document still labels 1 NET-equivalent per DETF as a proposal. Confirm that opening parameter or supply a different one. If the first buyer may choose a lead payment denomination, identify the supported lead currencies rather than asking the owner to calculate every initial asset quantity.

**Engineering boundary:** derive required additional legs and amounts from the selected reference and configured book; report an actual incompatibility if that cannot be mapped. Zero-interest/full-book reconciliation is not permission to label contributed principal as income, create another bootstrap transaction or request arbitrary new internal-token inputs.

### 2. Public hook-LP join assets

**Evidence:** row 08 Input (`Matrix:21`), with public access selected in R32 and remaining input-set uncertainty at matrix line 99.

Which user-facing assets may an LP provider supply after activation? Is the intention routed single-token NET/sNET/USDG joins, contributions of some specified component assets, or both? State the supported asset set; the engineering team derives the zaps and quote mechanics.

Public permission is already selected. The fact that the hook holds LP/YT/SY/SE shares does not establish that every asset is accepted directly, nor that DETF-facing payment routing automatically defines the HLP join interface.

### 3. Optional single-output hook-LP redemption

**Evidence:** row 10 Output/Eligibility (`Matrix:23`); row 09 component entitlement (`:22`); PRD §7.1's conditional conversion language.

Should a holder be able to convert its proportional exit allocations into one chosen token? If yes, which outputs are supported? NET/sNET/USDG is a possible owner choice, not an inferred restriction from DETF-out R22. If no, remove the optional conversion route rather than leave it looking implemented.

**Correction:** component-wise ownership is selected; exact physical delivery/variant APIs are not established merely by that entitlement. Conversion cannot spend another holder's cash or enlarge the exit allocation. Do not automatically add raw PT/YT/LP as new single-output conversion options.

### 4. USDG-funded bond principal maturity

**Evidence:** row 24 Locks and rewards (`Matrix:37`); PRD §10 position-class table and O03.

Which maturity reference governs fresh USDG-funded bonds whose contribution enters the V2 SE leg? For example, should they inherit the current Pendle market's maturity despite the V2 destination, or another explicitly chosen schedule?

The existing full-maturity principal lock and pre-maturity reward access remain selected. This question assigns the USDG position's release reference; it does not reopen rewards, direct-Pendle cliffs or native NetNet wrapper maturity.

### 5. Rollover commitment and user-visible availability

**Evidence:** row 42 Limits and failure (`Matrix:55`); PRD §11.3–11.4 (`PRD:495–511`).

Is it acceptable for rollover to leave successfully committed intermediate migration states across transactions, or must a failed rollover leave the pre-roll state intact? If intermediate states are allowed, which joins, exits and swaps may remain available during them?

The detailed transaction ordering is engineering work. A committed partially migrated book and its user availability are product-facing behavior. Atomic rollover remains a proposal in the current PRD. The already approved atomic native-note collection path does not decide this separate operation's policy. Engineers should evaluate feasibility before proposing a detailed state machine.

## Attributed initial positions and cross-review changes

- **Astra:** initially prioritized opening economics, combined HLP input/output definition, USDG maturity and rollover availability. Cross-review narrowed first-bond questions to actual opening/lead parameters, not reference-derived extra-leg arithmetic; retained user-visible rollover availability as a product concern.
- **Grok:** initially emphasized first-bond inputs, HLP joins, optional converted exits and rollover. Cross-review preferred opening parameters/lead denomination, join inputs, exit support and USDG maturity as its top four; qualified rollover as an owner issue when staged progress commits and affects availability.
- **MiniMax:** initially raised exit output set, first-bond composition, literal-versus-accounting self-leg and NFT retirement/purge. Cross-review moved toward the common HLP/opening/USDG topics but mischaracterized moderator review questions as human instructions to drop rollover and expansion issues. **Those were assessment prompts, not owner decisions.** Its assertion that rollover is purely engineering is not adopted.
- **Kimi:** initially emphasized expansion economics, USDG maturity, converted exits and join assets. Cross-review accepted opening/lead parameters as owner configuration and staged availability as product-facing, while demoting expansion because it is an already tracked issue rather than a newly discovered operation-definition gap.

## Corrections and unresolved dissent

1. MiniMax initially claimed §7.1 already selects HLP single-output conversion. It does not: the text says “if” offered. The output set and availability remain open.
2. No “purge” or public NFT-burn API is implied. The engineering retirement predicate must protect every undischarged native-note, principal and reward right. An additional collectible/purge product would require separate selection.
3. Self-leg storage/token-list representation should first be mapped from the selected Weighted reference and real token flows. No accounting-only or virtual leg is selected here.
4. Expansion conditions and amount/allocation equations remain tracked in Q7/row36. Do not reinterpret that gap as permission to choose a new custody destination: minted staking rewards and their backing in sNET-DETF are already selected. Conversely, custody alone does not complete all issuance/allocation mathematics. This remains unresolved specification work, not dismissed as purely mechanical by vote.
5. Reviewers differ on prioritizing opening calibration versus expansion and rollover. The consolidated list retains five topics rather than claiming unanimous agreement on one four-question ranking.
6. Historical version labels and stale tracker/evidence ranges merit reconciliation, not reopening settled deployment or new-SY decisions. Current §11 and explicit human choices override ambiguous earlier “same SY” shorthand. No documentary cleanup was performed in this review.

## Evidence and confidence

Moderator directly checked the four original files, current matrix rows 02–03/08–10/24/36/42 and PRD §10.4/§11.3–11.4. Current alignment reference `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md:1061–1075` distinguishes LP payment/first-bond activation and funded reward/principal claims; it is reference evidence, not permission to replace custom release rules. Canonical router/law and relevant skill guidance remain controlling.

All evidence is local/source-level as of 2026-09-24. No new external API claims, external retrievals, dependency/runtime-version verification, live market/fee observations, simulations or tests were used to settle these questions. Prior source constraints and deployment caveats in the PRD remain unchanged. High confidence in the cited definitional gaps; no economic safety, gas-liveness, bootstrap feasibility or implementation-readiness conclusion follows from council agreement.

## Human checkpoint / separate implementation handoff

Answer the prioritized product questions at your preferred pace. Unknown technical fields should be populated by source-backed engineering specifications, not by asking the owner to reconstruct selected formulas or invent APIs. This round authored only the four original review reports and this consolidation. The operation matrix, PRD, tracker, code and configuration are unchanged. No implementation, shell/tests, deployment or transactions were performed or authorized.
