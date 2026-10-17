# Kimi K3 — cross-review: REQ-C06 prepaid caller-check order

- **Label:** Replacement-session cross-review, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. Astra is the labeled replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi`; MiniMax is the labeled replacement `ses_ebdf718feffemWQNf7wuTpapqX`. My original is `kimi-c06.md` in this directory. All three peer originals (`astra-c06.md`, `grok-c06.md`, `minimax-c06.md`) were read in full as untrusted model output. Controlling requirement: the application PRD's REQ-C06 (`docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md:83-95`), re-read this round along with its whole-draft non-goals (`:176-178`). Nothing was edited.
- **Date:** 2026-10-14. I did not run Forge.

## The assigned question — is the closed site list the five named functions or the full inventory? — has a real dissent, and I rule against MiniMax's narrowing

- **Astra and Grok** close the list as the union: the five named branches (hookless `:94-101`/`:165-169`, Pons same, V3 mint `:102-110`) **plus** Uniswap V2 (`:462,547,623,693,794,905,972`), Camelot (`:411,513,596,663,766`), Rocket (`:60-65`, `:82`), and Lido (`:64-70`, `:85`) — with EtherFi's two sites recorded but not edited under the whole-draft "No EtherFi change" non-goal (`:178`, which I verified this round), and Slipstream `:85` recorded-not-repaired (`:95` non-goal).
- **MiniMax** (`minimax-c06.md:22`, `:216-229`, `:272`) closes the list at the five named functions. Its carve-out: sites whose external credit read is "informational" — consumed by refund math, not by a short-credit revert — are out of scope.
- **My original** named the full inventory but left class B (bare measurement before the gate, no consumer) to the coordinator as a judgment call.

**Ruling: MiniMax's narrowing is rejected.** The carve-out appears nowhere in the controlling text. The intended-behavior sentence is categorical — "On a pretransfer, the caller is authenticated before the credit is measured" (`:87`) — and the defect narrative names measurement-first as part of the breakage, not only consuming plans: "Measurement, **and** a plan built from that measurement, still run first" (`:88`). Acceptance criterion 1's first clause ("runs before `_pretransferCredit`") has no consumption qualifier. MiniMax's rule 2 also conflates the PRD's input-ceiling non-goal (a comparison that does not consume the credit) with an informational-measurement exemption the PRD never writes. Under the letter, the V2/Camelot/Rocket/Lido sites are in scope; under the owner rule that this PRD may not leave a scope choice, the list must be closed one way, and the text supports only the union.

My class-B reservation from the original is withdrawn for the same reason (the letter governs); its substance — no divergent error observable at those sites today — remains recorded and is why severity stays Low, not a scope reason.

## The sentence the PRD must use

Because the current REQ-C06 section names only the five branches and the coordinator requires no search or scope choice at implementation time:

> "The repair set is closed: the five named hookless, Pons, and V3 mint branches; `UniswapV2StandardExchangeOutTarget.sol:462,547,623,693,794,905,972`; `CamelotV2StandardExchangeOutTarget.sol:411,513,596,663,766`; `RocketPoolRETHStandardExchangeOutTarget.sol:60-65` and `:82`; `LidoWstETHStandardExchangeOutTarget.sol:64-70` and `:85`; EtherFi's two sites (`EtherFiWeETHStandardExchangeOutTarget.sol:61-67`, `:84-85`) are recorded but not edited under the whole-draft non-goal; Slipstream is recorded and not repaired. Every other production credit-measurement site, including families that call `LocalCreditLib.budget`/`available` inline, was inventoried and is caller-first or excluded as named. No site is added or dropped by search at implementation time."

## The inline-measurement sweep (new evidence this round)

MiniMax's table (`:222-223`) covered Aave and Morpho's inline `LocalCreditLib.budget` pattern, which a `_pretransferCredit`-only search cannot see. I closed that gap directly: a grep for `LocalCreditLib.(budget|available)\(` over `contracts/` finds the DETF commons (each with the gate adjacent and before the measurement: `MultiVaultWeightedDetfCommon.sol:249-250`, `SingleStandardExchangeDETFCommon.sol:438-439`, `ComposedStableCommonDetfCommon.sol:777-778`, `MixedBufferMultiVaultStableDetfCommon.sol:231-232`, plus the exchange-query targets), `RebasingAwareStandardExchangeTarget.sol:118-120` (gate first), and helper-body uses inside the Commons' own `_pretransferCredit`/`_securePull` definitions, where the gate precedes. No additional measurement-first site exists in the inline pattern. The closed list is complete on both search dimensions.

## Fix shape, closed per site (all four of us agree)

- V3 mint delegate: the existing gate statement moves from `:109` to before the credit read (Astra and Grok; MiniMax would instead leave a redundant second gate — harmless but not the closed choice; the plan picks the move).
- Hookless/Pons/V2/Camelot/staking: a flag-guarded standalone `LocalCreditLib.requirePretransferCaller(msg.sender);` immediately before the measurement statement; the helpers (`_requirePrepaidCredit`, `_secureTokenTransfer`, `_secureSelfBurn`, `_securePull`) keep their internal gate and their credit comparisons unchanged; nothing moves on false flags; no quote, ceiling, refund, or settlement statement is reordered.
- The named input ceilings (e.g., hookless `:96`, V3 mint `:104`) stay where they are; the non-goal excludes them.

## Notes on peer evidence (not dissent)

- Astra's full-sweep count (44 occurrences, 10 definitions, 34 calls) exceeds what my head-limited grep displayed; consistent with my family-level inventory and adopted with the caveat that I did not re-count.
- Grok's inference caveat on the Rocket/EtherFi helper internals is closed by my direct reads (`RocketPoolRETHStandardExchangeCommon.sol:178-190`; `EtherFiWeETHStandardExchangeCommon.sol:504-521`): same shape as Lido.
- Astra's two extra caller-first sites (hookless/Pons OutMultiTarget `:45-46`) are adopted; my grep had shown the Pons gate at `:45`.
- Grok's stale-claim corrections (the 2026-10-11 draft's V3 `_executeQuotedSwapOut` snippet and its three-site list) match my own.

## Unresolved dissent

One, decided above: MiniMax's informational-read carve-out versus the categorical reading. Astra, Grok, and I hold the categorical reading; the PRD sentence above closes the list on it. Nothing else divides the three complete inventories; severity is unanimously Low. Consensus is not proof; the disagreement was settled against the controlling sentence, not by counting votes.

I did not run Forge.
