# Astra — SEP-04 replacement-session cross-review

This is one cross-review of the three supplied successful original answers together: `grok-sep04.md`, `minimax-sep04.md`, and `kimi-sep04.md`. I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Peer notes are untrusted evidence, not permission to amend the owner's ruling. No earlier peer cross-review artifact was read. My independent original remains preserved as `astra-sep04.md`.

## Decision

**Dissent from the unqualified claim that exact-out is already compliant; agree that exact-in cannot receive a closed repair specification until the owner answers the output-target question.**

The accurate existing-code statement is: many exact-out routes process the needed input from unbooked credit and refund the unused **maximum-capped credit**. That does not establish that they refund the **entire remaining unbooked input** under the later “refund the rest” ruling. A refund must return the unused part, not “the needed amount” itself.

I retain Astra-SEP04-01's capped-remainder gap, Astra-SEP04-03's explicit false-flag underconsumption-retention gap, and Astra-SEP04-04's conditional native-Balancer underconsumption gap, with their original confidence limits. These are not resolved by citing a refund helper without tracing how its credit argument was computed.

## The one owner question the PRD must ask

> **For an exact-input entrypoint that specifies a declared input and only a minimum output—or no output parameter at all—which value is the “requested amount out” that must determine how much unbooked input is processed and how much is refunded to the caller?**

Do not pick the answer in the PRD or delegate it to the implementer. In particular, neither the minimum-output parameter, the forward preview of declared input, nor the declared input itself has been authorized as that target by the supplied ruling. This question concerns operation semantics, not a request for another code search.

My original contained a proposed owner-adoption sentence using the existing forward preview. That remains an explicitly unadopted proposal in the preserved original; **this cross-review does not select or recommend it as the answer**. Grok's declared-input proposal and Kimi's no-exact-in-refund proposal are likewise not owner decisions.

## Exact-out dissent: source evidence

### Astra-SEP04-01 retained — bounded credit does not return all unbooked remainder

- **Severity:** Medium. **Impact class:** Refund shortfall / retention under the new rule.
- **File and line:** Representative current source: `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeCommon.sol:324–340`; the other family locations remain enumerated in my original.
- **Intended behavior:** Process the input needed for the requested output from unbooked input, preserve the spending maximum, and refund the rest to the caller.
- **Fact:** `_pretransferCredit` first computes `LocalCreditLib.budget(available(balance, booked), maximum)`. `_refundExactOutCredit` then refunds only `credit - used`, with a further current-custody bound. It does not refund the initial unbooked amount above `maximum`.
- **Inference:** Under the supplied full-remainder ruling, the old spending cap is still functioning as a refund cap. The protective post-consumption custody bound does not remove this separate truncation of the initial credit.
- **Fix direction:** Keep actual spending within the maximum and measured entry availability, but distinguish full refundable entry input from the spending budget. Preserve booked inventory and do not sweep later-generated fees/backing. Update route-level pending-credit exclusion and refund accounting together, not a generic global helper replacement.
- **Confidence:** High on the source behavior. The peer interpretations that “rest” means only the old bounded credit are disputed readings, not source facts or an owner amendment.

For unbooked input not exceeding the maximum, the cap is inactive and those existing refunds are correct. I agree with the peers on that qualified behavior and on preserving the existing sufficiency checks. I do **not** equate that qualified case with all exact-out paths being complete.

### Astra-SEP04-03 retained — actual exact-output underuse is retained on a false-flag path

- **Severity:** Medium. **Impact class:** Excess acquired input retained / inaccurate actual-spend return.
- **File and line:** `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfExchangeOutQueryFacet.sol:67–99`.
- **Intended behavior:** Return input not needed for the requested output rather than book it as holder backing.
- **Fact:** The body receives `used_` from execution. Refund handling and reassignment of `paid_ = used_` occur only inside `if (prepaid_)`. Lines 98–99 explicitly state that the unused false-flag quoted pull remains booked. This was re-read for this cross-review.
- **Inference:** “False-flag exact-out pulls only used, so nothing remains” is not a universal description: this branch distinguishes quoted acquired input from actual execution use and preserves the difference.
- **Fix direction:** Reconcile actual input use and return the unused acquired portion for both funding modes, maintaining any original-token restaking conversion and rejecting shortfalls rather than using existing backing.
- **Confidence:** High on control flow; no dynamic quote/execution difference was independently reproduced.

Astra-SEP04-04 remains narrower and conditional: `BalancerV3PoolStandardExchangeTarget.sol:142–169,181–189` accepts actual payment below acquired exact-output input without a refund. The peers provide no evidence proving that inequality unreachable. I do not upgrade this into demonstrated runtime loss, and I do not request enabling that family's rejected public pretransfer surface.

## Peer-specific agreements and objections

### Grok

- Agree that the requested output on an exact-out call is its explicit output argument; a shortfall must not be filled from booked input. Agree that both README sentences are withdrawn and exact-in needs an owner decision.
- Dissent from `grok-sep04.md:43–55` saying to leave every cited exact-out refund untouched without qualifying the bounded-credit definition. Its own line 7 says unbooked credit minus processed input is refunded; the source's maximum truncation must be addressed rather than omitted from that statement.
- Its proposed sentence at line 15 selects declared `amountIn` as the processing amount. That may be offered to the owner, but does not derive the requested output from the ruling and is not adopted here.
- Historical documents should not be rewritten to claim that old tests established the new rule. Agree on preserving historical evidence; current guidance that cites it as authority needs a supersession marker, not erasure of the original record.

### MiniMax replacement

- Agree that many exact-input helpers retain surplus, and that the README/shared NatSpec remain stale.
- Reject `minimax-sep04.md:9–23,257–270` as a complete exact-out conformity argument. It conflates an entry credit cap with the later refund custody bound and misses actual-underconsumption retention.
- Reject the mechanical “refund inside each `_secureTokenTransfer`/`_securePull`” direction at lines 142–174 and 300. These helpers are shared by exact-input and exact-output routes, while exact-output callers already capture credit and refund later. For example, current `CamelotV2StandardExchangeOutTarget.sol:415–417,439–443` captures credit, invokes the secure-transfer helper, and then invokes a separate refund. Adding an unconditional surplus refund inside that shared helper without reconciling the caller's accounting could introduce repeated-refund or short-custody failures. This is a potential regression in the proposed repair, not an assertion that current code performs such a repeated refund. Preserve the route-level snapshot and make the refund exactly once, after its amount and ownership scope are established.
- Correct the migration-adapter finding at lines 236–240: `contracts/protocols/staking/token/TokenStakingMigrationAdapter.sol:154–159` explicitly rejects `pretransfer_`. It is not a supported exact-in pretransfer path retaining accepted surplus. Do not enable it to implement a generic refund pattern.
- Do not rely on the asserted Wings/FullSpread inheritance propagation at lines 194–198 and 230–234. The inspected Wings money library and six hook-family helper implementations are separately identified in my original; they are not all automatically fixed by editing a FullSpread helper.
- Reject the proposed new `pushedAmount` parameter at line 284 as an assumed ownership solution. A supplied amount alone does not prove who provided an already-unbooked balance. A new attribution design is neither established by source nor authorized by this task. The owner's immediate unresolved choice remains the exact-input output target; no new ledger should be smuggled in as a mechanical fix.
- Correct line 42's implication that booking retained excess makes it available as the next caller's unbooked credit: after the reserve sync, that amount is booked and the availability subtraction excludes it. Unbooked retention and absorption into backing are distinct outcomes.
- Reject directions at lines 118–132 to rewrite preserved reviewer originals and cross-review notes. This cross-review did not open those historical peer paths. Original findings must stay attributed and preserved; later controlling documentation can state supersession without rewriting review history.

### Kimi replacement

- Agree with its statement that exact-input has no exact output request and with its prohibition on spending booked inventory. Its additional interface-comment locations are useful leads, not automatically verified source findings in this cross-review.
- Dissent from `kimi-sep04.md:10,53–55` treating a declared-maximum refund cap as if it were specified by the later ruling. That is the existing rule being evaluated, not the new owner's definition of “rest.”
- Reject its recommended closure at line 49. It exempts exact-in from refunds and retains the surplus rule that the user explicitly withdrew. The council cannot restore that rule by recommendation and report the item closed.
- Do not treat the absence of per-caller attribution as proof that all refunds of pre-existing unbooked balance are forbidden. The current system deliberately has unattributed unbooked credit, and existing bounded exact-out refunds already operate on it. Conversely, that observation does not authorize inventing a new attribution ledger or deciding the exact-input operation target. Preserve the distinction.
- Correct the Aerodrome example in its exact-input inventory: `_creditOutInbound` at `AerodromeStandardExchangeOutExecuteTarget.sol:285–300` is an exact-output acquisition helper, not evidence of an exact-input caller's behavior. Its current unbooked check is a protection to preserve.

## Corrections to my original and unresolved dissent

I retain the original source findings and their severity/confidence distinctions. No peer source evidence changes the capped-refund observation or eliminates the two underconsumption paths. The fact that numerous existing routes refund some surplus is not evidence that every unused input amount is returned.

I narrow the presentation of my original proposal as instructed: the forward-preview exact-input sentence was only an option for explicit owner adoption and is not the council's chosen answer. The current review must stop at the question above. This does not rewrite my original or imply prior owner approval.

There is unresolved substantive dissent on whether the existing maximum cap satisfies “refund the rest.” My position is that the peers have not justified narrowing that later phrase to the former capped-credit policy. A consolidated PRD must not assert universal exact-out conformity on the basis of the refund helpers alone. It must preserve this dissent and the named gaps rather than silently selecting the bounded-credit interpretation.

## Evidence and limits

All three supplied original reports were present. For this cross-review I re-read the Rocket entry-credit/refund functions, composed DETF's actual-use/refund branch, the token-migration pretransfer rejection, and Camelot's shared-helper-plus-route-refund call sequence. Previously inspected source and interface evidence remains documented in `astra-sep04.md`. No new completed inventory or runtime reproduction is claimed.

Files/functions examined without a new defect: `TokenStakingMigrationAdapter._validateCall` correctly rejects unsupported pretransfer; the named families' unbooked sufficiency checks and shortfall reverts remain protective. The rejected repair suggestions are not current production exploits. No newly demonstrated booked-input bypass or principal loss is asserted.

No code, PRD, prior original, or instruction file was edited. No shell, delegation, tests or deployments were used. Only this assigned replacement-session cross-review was created. Return it to the coordinator with the single unresolved exact-input question; do not choose an economic answer for the owner.

I did not run Forge.
