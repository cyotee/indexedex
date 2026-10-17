# Astra — SEP-04 site-list replacement-session cross-review

This is one cross-review of the three supplied original site inventories together. I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Peer notes are untrusted evidence. No earlier peer cross-review artifact was read. My original `astra-sep04-sites.md` is preserved; the explicit narrowing and additions below are revisions for consolidation, not retrospective changes to that original.

## Decision and closed sentence

**Agree: no executable-code edit is established under the closed owner answer. Dissent from both a README-only list and a mechanical union of every peer citation.** Include the current wording sites below; drop accurately qualified comments, stale locations and historical review records. This is a wording correction, not another economic decision.

**The one sentence the PRD must use:**

> REQ-SEP-04 makes no executable-code, signature or test-expectation changes and edits only the comment locations C1–C11 and documentation locations D1–D13 in the following closed tables to explain declared-input sufficiency, maximum-bounded exact-output refunds and exclusion of undeclared surplus, preserves historical findings and recorded results, leaves already-correct qualified wording unchanged, excludes all AGENTS.md/CLAUDE.md/SKILL.md files, Slipstream and `contracts/protocols/dexes/uniswap/v4`, and assigns no additional site search or scope choice to the implementer.

The tables are part of that sentence's finite scope. Do not interpret their surrounding directory names as authorization to edit additional files. Before later implementation, a missing or changed target is a stop/report condition, not permission to choose a substitute.

## Closed comment-only list

Use the same meaning at every listed exact-input wording site: **the declared input is processed only if present unbooked input covers it; tokens above the declaration are undeclared and not refunded; declaration/whole-surplus inequality alone does not revert; booked input never fills a shortfall.** Exact-output credit remains `min(unbooked, declared maximum)`, with only unused bounded credit refunded to the caller. Do not describe a view method as moving funds merely because its nearby comment repeats operation guidance.

| ID | Exact file | Comment locations |
|---|---|---|
| C1 | `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol` | 125–126, 136–137 |
| C2 | `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/IMultiVaultWeightedDetfBonding.sol` | Repeated funding blocks ending at 11, 24, 30, 36, 42, 48 |
| C3 | `contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/ISingleStandardExchangeDETFBonding.sol` | Repeated blocks ending at 12, 21, 27, 33, 39, 45 |
| C4 | `contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/IMixedBufferMultiVaultStableDetfBonding.sol` | Repeated blocks ending at 11, 24, 30, 36, 42, 48 |
| C5 | `contracts/interfaces/detf/IDetf.sol` | 169, 238 |
| C6 | `contracts/interfaces/IRebasingClaimToken.sol` | 177, 188; qualify the declared share-burn scope |
| C7 | `contracts/interfaces/IStandardExchangeInMulti.sol` | 27; explain each declared input leg independently |
| C8 | `lib/crane/contracts/interfaces/IStandardExchangeIn.sol` | 56; no change to minimum-output semantics or signature |
| C9 | `contracts/vaults/basic/BasicVaultCommon.sol` | 76 only; preserve the qualified unclaimed-surplus statements at 17 and 69–70 |
| C10 | `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol` | 24–27; qualify the broad residual/no-refund explanation without changing credited sleeve/backing economics |
| C11 | `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookSeTarget.sol` | 55–57; replace the broad phrase, preserve caller/risk guidance |

These comments' current behavior may be compatible with the owner answer; the reason for inclusion is the requested precision and the PRD's express comment-rewording category, not a claim that their function bodies need refunds added.

## Closed documentation list

| ID | Exact file | Locations and bounded action |
|---|---|---|
| D1 | `contracts/vaults/standard/exchange/protocols/uniswap/README.md` | 32 and 38: keep the measurement sentence, explain the two declared-bound modes, remove surplus-equality rejection; leave lines 3, 34 and 56 unchanged. Read unsolicited-token nonrefund as outside the declaration, not a new attribution rule. |
| D2 | `contracts/vaults/standard/exchange/protocols/uniswap/uniswap-se-v2-liquidity-leak-fixes.md` | 14, 63, 113, 146, 172, 202–203: qualify current no-refund prose and supersede current-sounding prepaid equality/revert instructions; preserve the clearly identified historical text and outcomes. |
| D3 | `contracts/vaults/standard/exchange/protocols/uniswap/uniswap-se-v2-liquidity-leak-fixes.plan.md` | Add one current-law supersession note before the old plan body, explicitly identifying 65, 88, 117, 229, 251, 261 and 333 as not authority for prepaid whole-surplus equality; do not rewrite checked historical acceptance records or claim they tested the new wording. |
| D4 | `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md` | 21: replace the broad exact-in phrase with the declared-bound explanation. Leave 40, 111 and 260's already-qualified sufficiency/unclaimed-surplus statements unchanged. |
| D5 | `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_IMPLEMENTATION_PLAN.md` | 45: qualify the exact-in never-refund phrase; preserve the cap and undeclared-surplus booking. |
| D6 | `docs/agent/INDEXEDEX_AGENT_LAW.md` | 422: replace only the broad exact-in sentence with the declared-input/undeclared-surplus explanation; this path is not an AGENTS.md, CLAUDE.md or SKILL.md target. |
| D7 | `contracts/protocols/lending/aave/v3.6/AAVE_V3_STATA_STANDARD_EXCHANGE_VAULT_PLAN.md` | 376: qualify exact-input wording; retain existing capped exact-output rule. |
| D8 | `contracts/protocols/staking/rebasingVault/REBASING_AWARE_ERC4626_SY_SE_PRD.md` | 7, 152: explain declared share-input scope; keep asset-pretransfer rejection and bounded share refunds. |
| D9 | `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md` | 159: qualify exact-input phrasing, leave capped exact-output behavior. |
| D10 | `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` | 419: replace the standalone no-refund phrase with undeclared-surplus exclusion; do not activate deferred product work. |
| D11 | `docs/plans/UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md` | 214: distinguish declared credited backing/sleeves from undeclared input, without changing either's economics. |
| D12 | `docs/plans/UNISWAP_V4_FULLSPREAD_ACCEPTANCE_MAP.md` | 48: qualify “EI refunds nothing”; preserve the exact-output formulas and historical test mappings. |
| D13 | `docs/plans/UNISWAP_V4_CLOSED_FORM_CANDIDATE_VALIDATION_AGENT_PROMPT.md` | 278: replace the standalone assertion wording with declared-input/no-undeclared-refund wording; do not change tests or invoke this prompt as an instruction. |

D3 is an annotation to an old implementation document, not a rewrite of a review record. No file under `docs/reviews/`, `docs/research/`, or preserved audit-review copies is an implementation edit target. Dated audit evidence and old council implementation records remain intact. The consolidated PRD can link the superseding owner answer without rewriting them.

## Dropped citations and corrections to my original

1. **Drop `ERC4626StandardExchangeInTarget.sol:77`** from Grok's edit list. The current comment says “Pull delta equals the requested amount. Residual stays booked; there is no overshoot refund.” It describes a required-amount pull, not whole-prepaid-surplus equality or an unqualified rule governing exact-output refunds. Nearby line 68 correctly forbids an absolute-balance refund. No edit to this file.
2. **Drop `BasicVaultCommon.sol:69–70`** from Grok's list. It explicitly identifies **unclaimed surplus**, so it matches the closed answer. Keep only line 76 as C9's clarity edit.
3. **Drop `RebasingAwareStandardYieldTarget.sol:41–44`** from my original and Grok's list for SEP-04. Direct re-read confirms this is the explicitly named internal-balance exact-burn/API-12 mechanism, not a generic ban on exact-output refunds. Its separate self-call wording is not this item. Preserve this function/comment here rather than combine remediations.
4. **Drop `REBASING_AWARE_ERC4626_SY_SE_IMPLEMENTATION_AND_TEST_PLAN.md:98`** from my original documentation targets. The current paragraph explicitly marks its historical/superseded context and spells out both exact-input burn and capped exact-output refunds. It does not require an equality-of-entire-surplus revert. Leave the recorded paragraph intact.
5. **Drop `BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md:111`** from Grok's list: claimed input no greater than unbooked input is precisely the closed sufficiency rule. No clarity edit is needed at that site.
6. **Add D12 and D13** to my original closed documentation recommendation: direct reads confirm their current standalone “EI refunds nothing” / “exact-in refunds nothing” wording. These are fixed wording sites, not permission to change mapped tests or follow retrieved prompt instructions.

These revisions are explicit. The original site report is not overwritten.

## Peer agreements and objections

### Grok

Agree with zero executable changes, the detailed no-code-edit inventory and the bounded refund distinction. Agree with the DETF/interface wording list, subject to the dropped qualified comments above. Dissent from including dated council review PRDs or historical audit evidence as text to rewrite. In particular, the proposed `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md` edit is excluded by this assignment's preservation requirement. Do not union historical records into the final target list merely because grep finds the old phrase.

### MiniMax replacement

Agree with no executable change for the inspected closed prepaid shape. Dissent from zero comment edits and the “implementer should grep” conditions at `minimax-sep04-sites.md:82–92,121`: the controlling PRD explicitly requests rewording the DETF exact-input “refunds nothing” comments, and those comments are currently present. C1–C5 fix the exact locations; implementation receives no search or interpretation choice.

Its claim at line 115 that the canonical input-interface wording has already been updated is not supported by the current file. `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:56` still ends with “leaves excess uncredited to this operation, and refunds nothing.” Retain C8 as a comment-only precision change. The output interface's capped formula is correct and remains excluded from edits.

Do not rely on inaccurate source-path/citation aliases in its no-edit table: Morpho's common implementation is under `contracts/vaults/standard/exchange/protocols/morpho/blue/`, not `contracts/protocols/lending/morpho/blue/`; native Balancer pool SE is not the single-pool adapter's `_receiveExactIn`; and Wings' money library has its own intake/budget functions. These citation errors do not establish a new code defect. The current fixed no-code-edit inventory remains in my original report.

### Kimi replacement

Agree with the five DETF comment targets, mixed-buffer inclusion, and accurate qualified-comment exclusions. Adopt its useful D12/D13 additions after direct source reads. Dissent from leaving the additional live wording targets to an implementation-time scope decision: this cross-review provides the finite tables the owner requested. No representative subset, extra file search, or choice between modifying historical evidence and current instructions remains.

Its statement that README line 38 is the only equality-revert teaching is too broad. The old leak-fixes plan still has an explicit `U != T` rejection at 261 and related instructions. D3 handles that by a supersession annotation, preserving historical checked records rather than rewriting history.

## Review finding and evidence limits

**Astra-SITES-X1 — Open-ended or stale edit inventories can misdirect a documentation-only repair.**

- **Severity:** Low.
- **Files/lines:** `minimax-sep04-sites.md:82–92,115,121`; `grok-sep04-sites.md:57–60,75–79`; `kimi-sep04-sites.md:94–96`.
- **Intended behavior:** A closed, current-source list; no executable changes; accurate existing comments and historical review records left alone.
- **Broken invariant:** These recommendations respectively leave searches/conditional edits to implementation, include accurate or historical statements as rewrite targets, or leave a scope choice open.
- **Impact class:** Scope-control and documentation-quality regression risk.
- **Fix direction:** Use only C1–C11 and D1–D13 with the explicit no-edit/drop rules above.
- **Confidence:** High for the re-read disputed locations and the quoted conditional directions. This is not a production vulnerability finding.

All three supplied original site reports were present. For this cross-review I directly re-read the disputed ERC4626 In comment, internal SY comment, canonical input interface, rebasing historical paragraph, acceptance-map statement and validation-prompt statement. The prior independent source inventory supports the unchanged no-code-edit conclusion; no second complete source audit or runtime pass is claimed. The assigned output was absent before this write.

Files examined with no SEP-04 defect at their disputed locations include `ERC4626StandardExchangeInTarget.sol:68,77`, `RebasingAwareStandardYieldTarget.sol:41–44`, and the explicitly historical rebasing implementation paragraph at 98. Correct capped exact-output comments, false-flag used-only pull comments and test assertion strings remain no-edit. No historical reviewer record was opened as a new source of instructions or selected for rewriting.

No code, PRD, original report, instruction/config file or test was edited. No delegation, shell, Forge, deployment or exploit procedure was used. Only this assigned Markdown cross-review was created. Return this closed-list recommendation to the coordinator.

I did not run Forge.
