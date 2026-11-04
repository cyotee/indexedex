# PairToken Standard Exchange stage-one PRD: council report

Date: 2026-10-28
Target: `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md`
Scope: requirements clarification and improvement suggestions only.

## 1. Conclusion

**The package/interface direction is sound, but the PRD is not yet ready to
implement as a decision-complete specification.** All four independent members
reached that conclusion. The main unfinished decision is how deposits and
withdrawals attribute existing reserves and fees; the other major issue is
what withdrawal availability the mandatory compound and bounded quote engine
actually promise.

There are also concrete technical corrections: canonical SY rate scaling,
registry contents-ID ordering for native pairs, read consistency with unchanged
shared facets, and explicit native settlement synchronization.

The five reused facets and their 20 selectors are correct. Factory-provided
facets stay out of package lists/cuts. Keep one full-range position, one public
share supply, native ETH, no dead shares/retention/protocol-fee routing, and
the explicitly unsupported exact-output methods. No target PRD or production
file was changed by this council.

## 2. Participation, artifacts, and limits

| Participant | Native-resolved route | Initial artifact | Advisory outcome |
| --- | --- | --- | --- |
| Astra | `chatgpt-subscription/gpt-6-astra:high` | `members/astra/response.md` | Support with reservations. |
| Grok | `xai/grok-4.7:xhigh` | `coordinator/received/grok-original.md` | Support with reservations. |
| MiniMax | `minimax/MiniMax-M3` | `members/minimax/response.md` | Support with reservations. |
| Kimi | `kimi-coding/k3.1-pro:high` | `coordinator/received/kimi-original.md` | Support with reservations. |

Coordinator: invoking `gpt-6.1-sol`, not an additional vote. All four initial
tasks and all four advisory passes settled. No participant or model was
substituted. The configured MiniMax adaptive override was observed; actual
wire payload and billing were not independently attested.

The frozen reviewed synthesis is `coordinator/draft.md`, revision
`pairtoken-se-stage-one-council-20261028-01a1810f-draft-r1`. Its bytes remain
unchanged. Exact feedback is in `coordinator/received/*-feedback.md`; every
substantive concern is dispositioned in `coordinator/resolution.md`.
The synthesis traceability table covers all 58 original recommendations;
the resolution supersedes its dispositions where specified.

This final report contains coordinator changes after advisory review, not a
new unanimous approval. Grok and Kimi returned originals inline when apply_patch
was unavailable; those are preserved exactly. Grok required one delivery-only
recovery of elided text, without new research. MiniMax used a different
first-class Markdown writer at its assigned path instead of the required
inline fallback, disclosed that substitution, and made no alternate-path
write; RUN.md records the process deviation.

Evidence is local source observation, supplied owner decisions, and arithmetic/
architectural inference. Required PRD/baseline sources were examined by every
member; optional context coverage is recorded in their originals. There were
no tests, builds, gas measurements, deployments, wallet operations, or Git
actions. This is not proof of economic safety or runtime correctness.

## 3. Source-confirmed corrections

### T1. Canonical SY uses raw asset units, not an extra decimal normalization

Target requirement: S1-QUOTE-02.

`SYUtils.syToAsset` multiplies raw share balance by rate and divides by `1e18`.
The target PRD's formula adds a factor `1e18 / 10^d`. With a book worth
`1e6` raw six-decimal asset units and `1e18` raw shares, the canonical rate is
`1e6`; the target formula returns `1e18`, making the helper overstate assets by
`1e12`.

**Correction:** use `floor(Vraw * 1e18 / S)` with full-precision arithmetic.
Expose actual asset decimals separately. Test round trips through canonical
SY conversion helpers for 6-, 8-, and 18-decimal assets.
Whether `Vraw` is a spot-marked accounting value remains policy Q3 below;
correcting the units does not approve that policy.

Evidence:
`lib/crane/contracts/protocols/perps/pendle/core/StandardizedYield/SYUtils.sol:7-20`;
`lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol::exchangeRate`.
Raised independently by Astra, Grok, and MiniMax; accepted by Kimi in advisory.

### T2. Hash a sorted copy for registry contents identity

Target requirements: S1-ARCH-05, S1-NATIVE-01, A01/A07.

Registry pair lookups sort addresses before hashing. The target PRD hashes the
PoolKey face order. For native pools the wrapped face can sort after the other
token, so those hashes differ and pair discovery can miss the vault.

**Correction:** replace the unsorted contents-ID formula with the registry's
sorted-token calculation. Keep `vaultTokens`, `vaultConfig.tokens`, and
`reserves` in PoolKey face order; use a separate sorted copy only for contents
identity. Test a native pair for which those orders differ.

Evidence:
`contracts/registries/vault/VaultRegistryVaultQueryTarget.sol:64-84,149,196`;
`contracts/registries/vault/VaultRegistryVaultRepo.sol:92-133`.
Grok finding, checked by the coordinator. MiniMax withdrew its contrary
unsorted-hash recommendation after advisory review.

### T3. Shared unchanged facets cannot acquire a family read guard

Target requirements: S1-ARCH-04/05, S1-SEC-01.

`MultiAssetBasicVaultTarget` reads its Repo directly. Canonical token reads
also have no family guard. A universal read-rejection requirement conflicts
with the confirmed unchanged reuse requirement.

**Correction direction:** new family basket/rate/position economic reads and
previews reject while the operation guard is active. Shared basic-vault
reserves return the last committed snapshot; publish both reserve values
after external payout/refund interactions. Canonical token/metadata views stay
canonical. Document that combining those unguarded views during callbacks is
not a coherent whole-book valuation.

Add a selector-level read policy and callback-time observations. Do not modify
shared facets or introduce a proxy-wide guard to satisfy vague wording.

Evidence: `contracts/vaults/basic/MultiAssetBasicVaultTarget.sol:16-26`.
Astra identified the full conflict; Grok and Kimi accepted the correction to
their broader guard recommendations during advisory review.

### T4. Make native synchronization and proxy receipt explicit

Target requirements: S1-NATIVE-01, S1-SEC-01, A51/A52.

The PoolManager settlement branch depends on its synced currency. Explicitly
sync native currency immediately before a native debt's value settlement,
then validate the paid amount. Test outstanding ERC-20 sync state. Normal
ERC-20 settlement already resets sync, so this is not a claim that every
ordinary mixed sequence fails.

The proxy's empty-calldata `receive()` does not dispatch a facet. Attribute
expected native receipts in the active operation engine; do not book them in
a family receive hook. Preserve refund reservations until payout. The
standalone baseline already excludes its refund remainder from `_idle` before
paired addition; MiniMax withdrew its contrary alleged defect.

Evidence: `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:228-236,298-313`;
`lib/crane/contracts/proxies/Proxy.sol::receive`;
`contracts/pairtoken-baseline/PairToken.sol:205-235,370-372`.
Record explicit sync as an intentional integration-sequence difference from
the baseline, not a new economic policy or proof the baseline always fails.

## 4. Technical requirements to make explicit in the revision

These are specification work, not completed implementation or economic proof.

### Ownership and operation ledger

Define signed transitions among incumbent booked inventory, pending caller
input, exit allocation, refund, unbooked excess, deployed liquidity, and
uncollected position fees. One received unit must have one owner/category.
Record every actual manager debt/credit once; wrap/unwrap replaces one
representation rather than creating a second reserve.

The source confirms that position modifications can realize fees calculated
over the old entire position. The pre-compound collect, a subsequent swap,
and a positive or zero liquidity addition do not all have identical fee
checkpoint effects. **Who receives each resulting fee belongs to Q1; a complete
allocation algorithm has not been verified.**

Operation-generated terminal assets must be booked/allocated and paid to the
last entitled holder, not abandoned or swept to a dead address. Unsolicited
balances are a different category and remain subject to the proposed unbooked
policy. A mathematical rounding difference is not automatically stranded
token custody.

### Common sequence and preview contract

Specify this sequence consistently for paired, SE, SY, native and wrapped
money paths:

```text
validate
-> acquire guard
-> isolate/reserve input
-> preflight complete economic plan
-> mandatory compound
-> execute entry/exit
-> settle payout/refund reservations
-> publish shared reserve snapshots
-> release guard
```

For pull routes, isolate the proposed input logically before preflight and
pull only after it succeeds; do not treat validation as proof funds arrived.
Native value already received on entry is reserved and excluded from the
pre-operation book. True-flag credit must be authenticated without adopting
booked backing or unrelated excess.

Preview parity covers economic outputs and economic-domain failures from the
same initial pool/book/configuration state. It does not establish unavailable
caller authorization, allowances, staged-credit availability, recipient
acceptance, attached value, or deadline validity. Execution checks those
separately, uses actual manager deltas, and revalidates preflight assumptions
invalidated by external token/wrapper interactions.

The full projection needs slot0, liquidity, ticks/bitmap, LP and directional
protocol fees, fee growth, position checkpoints, and changes made by preceding
simulated additions/removals. Define a work step as one canonical swap-loop
iteration, including empty-word and zero-liquidity progress. Validate its
budget and effects under Q2; a conservative quote with no proved error bound
is not a substitute for the requested exact-parity design.

### API, facet, and initialization controls

- Publish the complete typed ABI, mutability, and return values for paired
  entry/exit, previews, family queries, donation and compound.
- Maintain the five-facet/20-selector reuse manifest, family-owned additions,
  shared Repo initialization, and disjoint factory/package ownership.
- Verify final-proxy absence of operational ownership, upgrade, rescue,
  ERC-4626 and excluded integration selectors; absence from one source file
  is insufficient. Identity controls cover package bindings and instance args.
- Use canonical directly declared interface IDs. Solidity excludes inherited
  selectors from `type(I).interfaceId`; the inheritance-only combined
  `IStandardExchange` type is not an In/Out capability bitmap. Avoid advertising
  its empty identifier as a distinct product capability.
- Keep installed In/Out declarations consistent with the canonical ABI and
  explicit `ExchangeOutNotAvailable()` behavior. The coordinator recommends
  retaining the concrete Out interface declaration while clearly documenting
  unavailable routes; MiniMax prefers omitting it. This is recorded integration
  dissent, not a proved safety defect or an owner-confirmed ERC-165 policy.
  Interface presence alone must not be used as an execution-availability test.
- Derive native validity from supported token lists. Native pools accept raw
  zero-address SY input/output; ordinary ERC-20 pools do not. Equal native and
  wrapped settlement amounts have equal economic previews.
- Use virtual internal route/redemption seams where suitable; a full public
  `redeem` override is not inherently required. Never send a native branch into
  ERC-20 zero-address operations.

### Boundary and configuration precision

- Define canonical full-range ticks, pool/position IDs, state-library reads,
  and piecewise token amounts with exact floor/ceiling rules.
- Test interior and endpoint equivalence against manager receipts. No actual
  interior baseline/manager discrepancy was demonstrated by this council.
- Preserve the one-sided positive-supply branch's complete maximum of the
  live leg and zero of the other; do not silently replace it with trimmed
  acceptance.
- Specify per-tick liquidity capacity and signed-delta failure behavior.
  Capacity clamping and residual reassignment are not automatically approved.
- On a clean empty instance, compound should be a defined no-op that neither
  pokes an empty position nor adopts unsolicited assets.
- Pin `DUST = 1000` as raw native units, exact compound cap rounding, and the
  two uses of `maxZapBps`. `maxZapTickMove` measures ticks, not every price
  movement. No decimals-normalized dust or new parameter defaults are approved.
- Use canonical `TransientStateLibrary.isUnlocked` and explicit pre-nested-
  unlock failure rather than Wings' local-sleeve fallback.
- Verify zero fee-type IDs through the real registry deployment path. Do not
  invent fee configuration or fee-manager fallback to bypass a failure.
- Add a “new capability / no baseline counterpart” comparison-ledger class.
  Canonical state-read substitution with equal outputs is preserved behavior.

Keep all 57 acceptance IDs, add precise subcases/new IDs, and give economic
rows actual pass/fail predicates once Q1 and residual-risk policy are decided.
No prose-pinning tests are needed.

## 5. Three questions for the owner

### Q1. Should stage one correct reserve and fee attribution before coding?

The current zap mints from gross liquidity deployed, which may include
incumbent idle assets. All four members identify this as unresolved. Fees
earned during compounding, entry swaps, and later partial removals also need
explicit ownership rules.

**Recommendation:** approve the direction that existing reserves/fees cannot
themselves create entrant shares, and that a partial exit cannot take fee
claims belonging to remaining holders. Prefer a snapshot that recognizes
fees earned through completion of mandatory compounding exactly once.
This is a proposed policy covering **both entry and exit**, not an already
verified allocation algorithm.

Require the full integer equations, ownership checkpoints, price basis,
swap-fee treatment, residual disposition, and rounding bounds in the PRD before
implementation. Grok's private-inventory candidate is a useful starting point,
not a proven final equation. MiniMax withdrew its subtraction candidate.

Alternatives are explicit baseline characterization with accepted limits, or
owner-authorized paired-only deferral of zaps. The latter reduces the currently
requested stage-one single-token SE/SY scope and cannot be selected silently.
Grok's preference for excluding compound-swap fees is retained as dissent;
positive-add/no-add branches make blanket exclusion an incomplete description.

### Q2. Must exits remain available when mandatory compounding cannot complete?

Strict baseline compounding can make a paired exit fail before its proportional
withdrawal, even though the paired exit avoids the final unwanted-token sale.
A projector cap can also reject a manager-executable operation.

**Recommendation:** keep the confirmed compound sequence, specify exact
economic parity over an admitted domain, and validate the work budget before
ratifying 512. Explicitly accept or reject maintenance-dependent exit
availability. Do not promise that standalone compound or donation guarantees
recovery.

If stronger exit availability is required, design it before implementation.
Kimi's collect-only fallback is one proposal, but skipping ratio-swap/
reinvestment changes the confirmed baseline sequence and needs explicit
owner approval. It is not a technical clarification that preserves all
current behavior.

### Q3. Do you approve spot-marked basket value solely for SY reporting?

The target PRD selects a live spot-accounting value in one configured asset.
That is distinct from executable withdrawal-and-sale proceeds and was not
settled by choosing the package architecture.

**Recommendation:** approve this simple reporting policy if desired, using
T1's corrected raw-unit rate, defined pending-fee inputs/rounding, and zero
before genesis. Keep it out of issuance and do not present it as an independent
oracle or exit guarantee. No additional `getRate()` deployment is proposed.

## 6. Smaller policy choices for the same revision

These do not replace the three lead questions. They remain unapproved defaults
or alternatives, not findings that the owner already chose them.

| Topic | Proposed direction and trade-off |
| --- | --- |
| Zero-total-output burn | Reject despite zero minima; allow a positive payout in only one paired leg. This avoids accidental dust destruction but can require combining shares for redemption. |
| Genesis/donation rounding risk | Preserve no dead/virtual shares. Define economic bounds or explicitly accept residual risk. Kimi proposes minimum genesis parameters, but they need approval and are not a proved cure. |
| Donation while disabled | Decide whether disabled means no new capital or only no new shares. Blocking donation restricts funding but may remove a maintenance-funding avenue; allowing it is not a recovery guarantee. Keep exits and their mandatory compound available, and specify standalone compound separately. |
| Unsolicited balances | The current proposal leaves them unbooked, without rescue. Explicitly accept that consequence or approve a separately specified adoption policy; no silent public sweep. |
| Asset metadata | Pin cached versus live decimals reporting. Correct canonical SY arithmetic no longer needs a `10^d` normalization. |

Removing dead shares does not itself approve every rounding/donation outcome;
nor may an acceptance test silently restore a dead/virtual sink.

## 7. Disagreement and corrections preserved

The council did not approve a replacement zap equation, an exact gas budget,
an exit-liveness guarantee, or a new oracle. Advisory agreement is qualified.

Several claims were rejected after source checks, and MiniMax withdrew many:
the inherited-interface-ID calculation; the alleged baseline refund-release
defect; a mandatory full SY redeem override; universally disabled zero-tick
zaps; and an implication that tick-crossing previews are inherently impossible.
Sequential mulDiv operations also do not automatically prove one-floor
equivalence or unrestricted intermediate safety.

The final does not adopt terminal asset forfeiture, blanket rejection of
wrapped-native donations when the wrapper is itself a configured ERC-20 leg,
or a new “18-decimal baseline deviation”: PairToken already uses 18 decimals.
Wings' different share-decimal convention is context, not this family's
economic authority.

Solidity interface-ID semantics were checked against the official Type
Information documentation, retrieved 2026-10-28:
`https://docs.soliditylang.org/en/latest/units-and-global-variables.html`.
Only a generalized public-language query/document retrieval was used; no
private source was submitted to public search.

For full original-to-final traceability, use frozen synthesis section 6 and
`coordinator/resolution.md`. Original files and feedback remain unchanged.

## 8. Next action

Resolve Q1-Q3 and the smaller explicit policies, then separately authorize a
target-PRD revision incorporating the technical corrections and complete
equations. Only after that revision is implementation-ready should stage-one
contract work begin. This report itself authorizes neither PRD edits nor code.
