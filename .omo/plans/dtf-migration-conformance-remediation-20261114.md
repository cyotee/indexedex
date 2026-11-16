# dtf-migration-conformance-remediation-20261114 - Work Plan

## TL;DR (For humans)
**Who this is for and what changes for them:** Original contributors retain their source-bound compensation and funded bonds. The owner can adjust complete Weighted pricing inputs until activation, while operators can safely resume records made under different prices.

**What you'll get:** Complete migration remediation, including exact pricing, stable original identities, the two bonds for weighted NFT 3, source and recovery closure, measured operation limits and all missing or previously omitted evidence.

**Why this approach:** Reuse the existing calculation, custody and activation machinery. Store pricing provenance separately from economic originals and immutable issuance, so changing prices cannot silently rewrite delivered compensation.

**What it will NOT do:** It creates no financial allocations or public transactions. It adds no early pricing lock, automatic repricing, extra lifecycle gate or replacement operator.

**Effort:** XL
**Risk:** High - pricing, configuration identity and transaction recovery must agree without changing source custody or bond obligations.
**Decisions to sanity-check:** Manual inputs remain editable until activation; loaded credit stays until explicit reload; issued bonds remain unchanged. These decisions are already approved.

Your next move: the lead binds this amended plan for native plan-reviewer review. Plan-consultant findings are addressed; execution remains a separate authorization.

---

> TL;DR (machine): XL; high risk; 15 implementation tasks, 4 final verifiers, 5 implementation waves plus 1 final wave; complete manual Weighted and inherited conformance remediation; native review pending.

## Scope
### Renewed execution after the owner's correction (2026-11-15)

The owner rejected the fixed witness-bytecode hash assertion and explicitly requested completion of this plan in `/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`. Remove `claimWitnessCodeHash`, its operator and rehearsal comparisons, and its artifact-pin test in that worktree. Do not substitute a new pin. Preserve the observation router, transaction/trace authentication, source identity, and conservation checks. The separate 193-test main-checkout result does not verify this conformance worktree.

This is a renewed run of the original tasks after the prior partial delivery, not a retry claiming that previously unmet requirements passed. Tasks 7, 10, 12-15 and F1-F4 reopen; all prior claims, failures, and reports remain historical evidence. Task 7 also owns the two substantive F2 findings: historical/current SY census separation and isolated required-original-field negatives. Previously confirmed tasks 1-6, 8, 9 and 11 retain their evidence, subject to source freshness and affected-check reruns. Complete the original rehearsal, documentation, inventory, and final-review requirements; a removed pin is not proof those requirements are met.

The retained task-10 blocker identifies an actual funded candidate in the task-2 transfer CSV, but `authorityInput` accepts only its 22 authority sources and the bundle rejects unreferenced files. Task 16 below closes this in-scope transport defect after task 7 and before task 10. The renewed run therefore has 16 implementation tasks plus F1-F4, 20 top-level rows total. It preserves all authority roles and financial boundaries; this does not approve a donor or allocation for public execution.

### Affected user and ideal state
**Affected user:** Eligible original contributors need source-bound compensation and exactly funded bonds. The current proxy owner needs adjustable Stage 1 Weighted pricing without disturbing loaded credits or delivered bonds. Operators need preparation, interruption recovery and activation that work with mixed pricing records. Maintainers need the entire original implementation and its evidence delivered.

| Row | Statement | Reason |
| --- | --- | --- |
| IS-1 | Every accepted source retains original-wallet configuration, correct units, custody and conserved credit. | A new representation must not create another economic original. |
| IS-2 | Manual Weighted inputs reproduce the supported canonical calculation with exact rounding and limits. | Owner policy may deliberately differ from live state without changing the pricing algorithm. |
| IS-3 | One current-owner setter remains available throughout Stage 1 and disappears in the existing activation cut. | No premature freeze or additional lifecycle gate was approved. |
| IS-4 | Real registry/child behavior preserves paid owner-first activation, funded fresh 90-day compensation cliffs, complete reward gates and ordinary-family behavior. | Pricing remediation cannot weaken money-path obligations. |
| IS-5 | Repeated old-NFT reward recovery retains principal and custody; other recovery dispositions are source-specific. | Maturity is not an instruction to liquidate principal. |
| IS-6 | Operators can prepare, load, verify, resume and activate A/B configurations, including one recipient's configuration B and issuance A. NFT 3 produces two bonds. | Keep-until-reloaded must work through the actual operator, not only storage. |
| IS-7 | Every original obligation and task-created file has a delivered, source-qualified result. | Historical evidence, current verification and completeness are different claims. |
| GAP-1 | Live once-only capture and the superseded external-credit proposal both conflict with manual inputs. | Replace the pricing boundary and explicitly reconcile requirements. |
| GAP-2 | The retained pricing-coupled facet/target lacks Weighted naming. | Rename actual artifacts, salts and callers together. |
| GAP-3 | NFT original identity currently includes the pricing book. | Economic identity must survive A to B and explicit reload. |
| GAP-4 | Loader signatures and selector declarations lack the expected manual book guard. | Preparation against A must not silently execute using B. |
| GAP-5 | Named NFT 3 can select the combined loader; the complete rehearsal omits its two-bond flow. | Reject the wrong mode at the existing input boundary and demonstrate the whole flow. |
| GAP-6 | Source indexes lack exact runtime/facet/schema/unit/witness links; earlier IDs 0-2 remain a source-fact question. | Recover evidence before changing source policy. |
| GAP-7 | Retained programs/records are omitted and named surrender/package records are absent. | Integrate all owned work and author substantive missing outputs. |
| GAP-8 | Current/historical route, selector and verification descriptions conflict. | Reconcile observations without cosmetic status changes. |
| GAP-9 | Deployment receipts do not establish loading, issuance and harvest batch limits. | Measure admitted operations against applicable authenticated limits. |
| GAP-10 | The named adversarial base and full original-obligation witness mapping remain incomplete. | Use real shared fixtures and final-tree validation. |

### Must have

Approval is already granted: "Yes, proceed with writing the plan." The separate owner decision is "Repricing: Keep until reloaded (Recommended)". This plan and its owned draft are the only planning writes. `review_required: true`; the three concrete findings and bounded clarity notes from native plan-consultant `st_01a1dc8e` are addressed in this 2026-11-15 amendment. Native plan-reviewer is **pending, owned by the lead**. This document records no native approval and starts no execution.

Authority, in order:

1. `.omo/drafts/hyperplan-weighted-migration-insights-20261114.md`, complete manual Weighted delta and latest owner decisions.
2. `.omo/drafts/dtf-migration-conformance-remediation-20261114.md`, approved draft, interpreted with that delta.
3. `.omo/drafts/hyperplan-dtf-conformance-insights-20261114.md`, unchanged conformance, evidence, recovery, gas and delivery obligations. Its actual-live-composition selection and compulsory frozen-capture premises are superseded.
4. `docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md` (P), all sections 1-11, all MIG-P01-P15, E1-E5, all 53 MIG-AC dispositions, section 8.1's 13 examples, section 8.2 invariants, original tasks 1-10 and F1-F4, as amended explicitly below.
5. `docs/reviews/dtf-migration-plan-execution-20261114/REMEDIATION_PRD.md`, review claims to reconcile, not a replacement specification. Its direct-pair zero-output allegation was withdrawn. Earlier NFT IDs 0-2 are unverified source facts, not an established eligibility defect.

The original and focused hyperplans each completed five members and three rounds. Do not repeat their research. Necessary execution-time source verification and changed-behavior tests remain mandatory.

Path aliases below are exact, repository-relative unless absolute:

| Alias | Expansion |
| --- | --- |
| M | `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration` |
| S | `scripts/recovery/dtf-migration` |
| FS | `scripts/foundry/recovery/dtf-migration` |
| T | `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration` |
| K | `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration` |
| D | `docs/incidents/2026-09-16-dtf-recovery/migration` |
| R | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts/docs/incidents/2026-09-16-dtf-recovery/migration` |
| E | `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114` |
| W | `contracts/hooks/uniswap/v4/standardExchange/weighted` |

`R/resumed-integration/verify-bounded-deployments.ts` is the actual retained helper location; there is no top-level `R/verify-bounded-deployments.ts`. Preserve its relative imports when delivering it at `D/resumed-integration/verify-bounded-deployments.ts`.

### Exact manual pricing ABI and arithmetic

Reshape and rename the existing `M/interfaces/IUniswapV4DetfMigrationSnapshot.sol` and `M/UniswapV4DetfMigrationSnapshotLib.sol` in place to `IUniswapV4DetfMigrationWeightedPricing.sol` and `UniswapV4DetfMigrationWeightedPricingLib.sol`. There is one evaluator, not parallel snapshot/manual implementations. Retain the existing `Result` fields (`pairEquivalent`, `boosted`, `net`, `ratedInflow`, `gross`, `user`) for internal differential diagnostics. The new interface owns these tuples, in this field order:

```solidity
enum LegMode { Raw, RawRate, DisabledBuffer, EnabledV3Buffer }

struct Leg {
    address token;
    address standardExchange;
    LegMode mode;
    uint256 rawReserve;
    uint256 seReserve;
    uint256 weight;
    uint256 invScale;
    uint256 ratedScale;
    uint256 rate;
    IStandardExchangeFrozenQuoteInputs.Inputs deposit;
}

struct Inputs {
    uint256 swapFeeWad;
    uint256 seigniorage;
    uint256 ethIndex;
    uint256 dtfIndex;
    uint256 detfIndex;
    Leg[] legs;
}

struct Book {
    uint256 version;
    uint256 chainId;
    address consumer;
    address weth;
    address originalDtf;
    bytes32 id;
    Inputs inputs;
}
```

`deposit` uses the **existing** `contracts/interfaces/IStandardExchangeFrozenQuoteInputs.sol:6-26` tuple: `Model model; address exchange; Request request; address token0; address token1; uint256 supply; uint256 reserve0; uint256 reserve1; uint256 minimumLiquidity`, with `Request = (address tokenIn,address tokenOut,address holder,Mode mode)`. Reuse the actual enum encodings: `UniswapV3PairDeposit = 1`, `OrdinaryDeposit = 1`. No refund field, RPC `Outcome`, revert bytes, capture-facet identity or observed block claim belongs in `Inputs`.

Public API:

```solidity
// On IUniswapV4DetfMigrationAllocation, implemented by the existing allocation target.
function setMigrationWeightedPricing(
    IUniswapV4DetfMigrationWeightedPricing.Inputs calldata next_
) external returns (bytes32 bookId_);

// On retained IUniswapV4DetfMigration, outside the allocation ABI.
function migrationWeightedPricing()
    external view returns (IUniswapV4DetfMigrationWeightedPricing.Book memory);
function previewOriginalCredit(uint256 originalEth_, uint256 originalDtf_)
    external view returns (uint256);
```

Replace `captureMigrationSnapshot()` with the setter; remove `migrationSnapshot()` and `migrationSnapshotSource()` rather than retaining aliases. Unset getter/preview/loaders revert `MigrationWeightedPricingNotSet()`. The setter can initialize empty storage without calling the getter. It uses existing `administration` and `nonReentrant`, validates the complete input in memory, builds the envelope and atomically overwrites the existing pricing bytes. Keep the storage slot and unrelated mappings. Renaming the `frozen` bytes member to `weightedPricing` is permitted without moving its position; `_snapshot()` becomes `_weightedPricing()`.

Use `MigrationWeightedPricingInvalid()` for malformed manual models/units, `MigrationWeightedPricingBookMismatch(bytes32 expected,bytes32 actual)` for stale loads, and `MigrationWeightedPricingSet(bytes32 indexed bookId)` for successful sets. These are declared once in the reshaped pricing interface and referenced by product interfaces/targets. Existing canonical arithmetic failures continue to bubble unchanged. Setting identical complete values emits the same deterministic ID; no revision counter or expected-old-ID argument.

Validation is mathematical and structural, never live-state authentication:

- `version = 2`, `chainId = block.chainid`, `consumer = address(this)`, `weth` and `originalDtf` from existing immutable-for-the-instance package storage. The setter cannot edit those domain fields. `Inputs` has 3-8 distinct nonzero token legs because WETH, original DTF and new DETF are distinct required roles. The three indices are distinct and in range; their tokens equal those three bound addresses. Preserve leg order.
- Every weight is at least `1e16`, weights sum exactly `1e18`, `swapFeeWad < 1e18`, and `seigniorage <= 1e18`. Do not turn `p == 1e18` into a new lifecycle prohibition: zero resulting credit still cannot be issued/surrendered. Input role `ratedScale = 1e18`; output role `ratedScale = 1e27`. Other scales are exact `10 ** (36-d)` for integer `d` in `[6,36]`, as in `W/UniswapV4StandardExchangeWeightedBufferHookMath.sol:48-68`. No arbitrary decimal multiplier.
- Raw/RawRate: `standardExchange == 0`, `seReserve == 0`, `invScale == ratedScale`, and every field of inactive `deposit` is zero. Raw has `rate == 0`; RawRate has `rate > 0`. This matches the scale binding at `W/UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol:301-318`.
- DisabledBuffer: nonzero `standardExchange != token`; inactive `deposit` entirely zero. If `seReserve > 0`, require `rate > 0`; if `seReserve == 0`, require `rate == 0` to canonicalize the unused operand. Its incoming net amount is **not** multiplied by that rate.
- EnabledV3Buffer: nonzero `standardExchange != token`, `rate > 0`; `deposit.model == UniswapV3PairDeposit`, `deposit.exchange == standardExchange`, `deposit.request.mode == OrdinaryDeposit`, `tokenOut == standardExchange`, and `tokenIn == leg.token`, one of two distinct nonzero `token0/token1`. `holder` is canonical zero: the admitted pure formula does not use it. No facet-code check or call to exchange, provider, fee oracle or hook is made. `supply/reserve0/reserve1/minimumLiquidity` are authoritative uint256 operands; retain canonical zero-supply/zero-reserve behavior instead of making an additional readiness rule. A zero result reaches the existing zero-inflow/zero-output rejection.
- Output mode is Raw or RawRate only, so enabled-buffer DETF output is not silently added. For any branch using `ratedPairUnits`, the scale-derived denominator in that existing function must be nonzero; checked arithmetic and canonical domain failures remain effective. Derive every rated balance, including the output, from the supplied raw/SE operands; accept no independently editable rated-balance field. The two input and output rated reserves must be positive. Other leg reserves may be zero where the existing calculation permits it. Do not bound real balances by made-up economic maxima.
- Validate zeroed inactive fields and all role/model constraints before storing. No requirement compares manual reserves, rate, fee, seigniorage or V3 operands with live observations. An observed-state test fixture is a differential oracle, not a required production pricing source.

Exact evaluation, preserving `M/UniswapV4DetfMigrationSnapshotLib.sol:120-181`:

1. Select ETH/WETH input with `ethIndex`, original DTF with `dtfIndex`. Pair equivalent is the original native18 amount; only the existing direct contribution routes are modeled. Zero component returns zero. Apply `Math.mulDiv(amount, 1e18 + p, 1e18)` once.
2. Deduct the fee once with `Weighted.applyTradingFeeNet`. Preserve its checked product and floor fee; do not substitute a differently rounded `mulDiv` implementation.
3. Derive inventory units per leg: Raw is `rawReserve`; RawRate is `Weighted.ratedPairUnits(rawReserve, rate, invScale, ratedScale)`; either buffer is `rawReserve + ratedPairUnits(seReserve, rate, invScale, ratedScale)` when `seReserve != 0`. Then `Weighted.scaleTo(units,ratedScale)`. Preserve checked addition/multiplication.
4. Inflow units: Raw = net; RawRate = `Math.mulDiv(net,rate,1e18)` **before** scaling; DisabledBuffer = net; EnabledV3Buffer = `Quote.evaluate(deposit,net)` followed by the existing `ExchangeInAmount.consumedInput` check and `amountRefunded + ratedPairUnits(amountOut,rate,invScale,ratedScale)` when `amountOut != 0`. `Quote.evaluate` currently returns zero refund (`contracts/utils/StandardExchangeFrozenQuoteLib.sol:39-56`); retain the handling, not a new manual refund model.
5. Scale the inflow once. Call `Claim.exactInputBudget` and `Claim.rawOutput` with the derived reserves and actual manual raw DETF output inventory. Preserve the 30% max-in check, rated reserve and native reserve caps, checked overflow, zero-output rejection and native9 floor.
6. Use `DETFMintSplitLib._splitLiveGross(gross,p).user` once. Sum separately quoted full originals; use one unchanged book for both components and all recipients. No reserve mutation between originals, chunking, partial-original nonlinear re-quote, ordinary bond-duration bonus, inventory compensation or reserve self-leg mint.

Book ID preimage is exactly:

```solidity
Book memory book = Book(2, block.chainid, address(this), storedWeth,
    storedOriginalDtf, bytes32(0), next);
book.id = keccak256(abi.encode("IndexedEx.manual-weighted-original-credit", book));
```

ABI-encode the string and complete typed Book with zero `id`, never packed encoding, JSON or an independently invented config hash. TS uses the generated getter's tuple components in precisely that order, zeros the `id` field, and recomputes this same preimage. A/B denote two such IDs, not a revision number.

### Loaders, stable originals and rename/cut contract

Each of these twelve existing loaders becomes `(ExistingInput[] calldata inputs_, bytes32 expectedBookId_)`; put the scalar **last**, preserving the existing tuple and array order:

| Method | Existing input type on `IUniswapV4DetfMigration` |
| --- | --- |
| `configureIndependentAllocations` | `IndependentAllocationInput` |
| `configureNftEntitlements` | `NftEntitlementInput` |
| `configureNftContributionEntitlements` | `NftEntitlementInput` |
| `configureWeightedLiquidEntitlements` | `WeightedLiquidEntitlementInput` |
| `configureWeightedSyEntitlements` | `WeightedSyEntitlementInput` |
| `configureClaimedSyEntitlements` | `ClaimedSyEntitlementInput` |
| `configureDtfCustodySeEntitlements` | `DtfCustodySeEntitlementInput` |
| `configureClaimVaultEntitlements` | `ClaimVaultEntitlementInput` |
| `configureWeightedReceiptEntitlements` | `WeightedReceiptEntitlementInput` |
| `configureEarlierReceiptEntitlements` | `EarlierReceiptEntitlementInput` |
| `configureEarlierLiquidEntitlements` | `EarlierLiquidEntitlementInput` |
| `configureHeldSeLpEntitlements` | `HeldSeLpEntitlementInput` |

Read and compare the current book ID after authority/lifecycle/idle guards but before repricing, clearing an origin index, or changing any record. Check even an empty batch. Both NFT entrypoints perform the check before their shared internal routine. Mismatch reverts the whole call. No new parameter is added to source-only bootstrap, independent issuance, ordinary owner-bond purchase or activation.

Keep configuration preimages exactly `keccak256(abi.encode(chainId,proxy,bookId,input))`; separate NFT contributions retain the extra trailing `true`. Claimed SY retains its nested `(original, originalWeight, eligibleWeight)` tuple. The book ID binds replaceable configuration; stable NFT original ID becomes exactly `keccak256(abi.encode("migration.nft",chainId,proxy,collection,tokenId))`. Update `MigrationLegacyNftLib.originalId`, `S/payloads.ts:nftOrigin`, candidate/exposure generation, active fixtures and overlap consumers together. Preserve collection/token consumed maps, configured/issued-original exclusions and historical archived IDs. No live proxy upgrade or reinterpretation of historical configuration is promised.

One setter changes previews and later explicit loads only. It does not touch any credit, configuration ID, origin index, Q/C balance, issued-original fact, bond or custody record. Explicit reload uses the existing full replacement semantics. In particular, an independently issued recipient may receive configuration B while its once-only issuance remains A; B neither enlarges that bond nor permits another issuance.

Rename only:

- `M/UniswapV4DetfMigrationFacet.sol` -> `M/UniswapV4DetfMigrationWeightedHookFacet.sol`.
- `M/UniswapV4DetfMigrationTarget.sol` -> `M/UniswapV4DetfMigrationWeightedHookTarget.sol`.
- The pricing interface/library named above.

Update all active imports, inheritance, `facetName`, artifact name strings, `ArtifactCreationCode` lookups, name-derived release salts, PkgInit references, deployment predictions, scripts, fixtures and ABI bindings. `M/UniswapV4DetfMigration_Component_FactoryService.sol:15-20` binds both artifact and salt to the supplied name. Keep `UniswapV4DetfMigrationDFPkg`, other facets, adapters and children named as they are. Keep archived source hashes/artifacts as historical records with qualifications.

Replace the capture selector in the real allocation facet declaration and `_administrationSelectors`; update all changed loader selectors on both removable facets. Reconcile their declared functions, package cuts, current owning facets, ERC-165 support and `S/execution-domain.ts`'s allocation-ABI removability calculation. The retained facet replaces two old snapshot reads with one book getter; derive counts from the real ABI/cuts, never pin an old 8+8 or 29 count. All reads survive activation. The setter works after the paid owner-first bond and is removed only by successful activation. Activation still requires the completed paid purchase and idle children; it does not require pricing to be set or all rows to be current. A funded/purchased instance with no entitlements may activate with an unset book.

### Exact mixed-record operator format and verification

Extend the existing files and reconciler, not a new operator or provenance service. Version preparation, prepared manifest, execution manifest and signed intents to `dtf-operator-*-v2` for the changed ABI (`preparation`, `manifest`, `execution`, `intent`). The authority bundle format may remain v1 because its roles do not change. Active v1 execution against the new release fails explicitly; archived v1 bytes are retained and are not silently reinterpreted.

Replace pricing-only `snapshotId/snapshotArtifact` naming with `bookId/pricingArtifact`; retain chain/proxy/purpose/RPC/code-bindings and pinned block/hash authentication. `domain` additionally binds the real proxy deployment receipt's `deploymentBlockNumber` and `deploymentBlockHash` through an existing source-file proof. Verify that receipt creates/registers the bound instance; use that block as the configured-origin log census start, not the latest pricing-set block. An unset pre-pricing execution has `pricing: null`; funding and owner-bond verification obtain bound WETH/original DTF from validated package arguments/deployment evidence, not a getter that requires an initialized book. For a deployment with no configured entitlements or issuance, owner-bond and activation accept `preparedManifest: null`: authenticate the deployment/complete empty configuration census and paid purchase directly, without calling `requirePrepared`, preparing an empty quote manifest or reading an unset book. A nonempty census requires its exact record evidence; null is not permission to skip it.

The v2 input extends the existing category arrays with an explicit pricing directive per row. This is the exact logical shape; decimal quantities remain canonical integer strings, addresses lower-case, SHA-256 hashes 64 hex digits and EVM hashes `0x`-prefixed:

```typescript
type FileRef = { readonly path: string; readonly sha256: string; readonly bytes: string };
type AcceptedConfiguration = {
  readonly manifest: FileRef;       // original prepared v2 manifest bytes
  readonly executionManifest: FileRef; // original configure execution manifest bytes
  readonly journalDomain: FileRef;  // original configure checkpoint domain.json bytes
  readonly configurationId: string;
  readonly intent: FileRef;         // exact signed configure intent
  readonly completion: FileRef | null; // null permits mined-before-checkpoint recovery
};
type PricingDirective =
  | { readonly kind: "load"; readonly bookId: string;
      readonly replaces: AcceptedConfiguration | null }
  | { readonly kind: "retain"; readonly bookId: string;
      readonly accepted: AcceptedConfiguration };
type ManualBookEvidence = {
  readonly bookId: string;
  readonly encodedBook: string;     // ABI encoding of Book, including its computed id
  readonly observationBlockNumber: string;
  readonly observationBlockHash: string;
  readonly setTransactionHash: string;
};
type IssuedHistory = {
  readonly recipient: string;
  readonly configuration: AcceptedConfiguration;
  readonly issuancePreparedManifest: FileRef; // issuance may use a different prepared manifest
  readonly issuanceExecutionManifest: FileRef;
  readonly issuanceJournalDomain: FileRef;
  readonly issuanceIntent: FileRef;
  readonly issuanceCompletion: FileRef | null;
};
```

Every input row keeps its existing `original`/`proof` or independent recipient/entitlements fields and adds `pricing: PricingDirective`. Top-level preparation adds `books: ManualBookEvidence[]` and `issuedHistory: IssuedHistory[]`. Prepared category rows retain `input`, `configurationId`, `quotedCredit`, NFT `originalId/contributions`, and claimed-SY `originalQuotedCredit`, and add the same `pricing` directive. A retain row's complete input/credit/origins must match its referenced accepted manifest row. Cross-file references are bundled with raw bytes/hash/length using `bundle-files.ts` and `bundle-materialize.ts`; reject cycles, duplicate identities, missing objects and unconsumed extra referenced objects. Do not resolve a reference from a path alone.

For **each historical configure and issuance intent independently**, validate its original execution-manifest and journal-domain FileRefs, resolve the original prepared manifest and every source/ABI/document binding, and recompute that preparation's normalized/input and payload hashes. Reconstruct the existing journal domain exactly as `{manifest: originalExecutionManifest, preparedHash: originalPrepared.normalizedHash, payloadHash: originalPrepared.payloadHash}`; null hashes are permitted only for operations with no preparation. Require canonical equality with the referenced original `domain.json`, then require `fingerprint(canonical(reconstructedDomain)) == intent.domainHash`. Check the execution/preparation chain, proxy, purpose, RPC alias, signer, code/source bindings and selected operation against each other, and the signer/chain/nonce/to/value/calldata against the signed transaction. The configure context is not assumed to be the issuance context. Bundle relocation must resolve original paths through lossless file mappings without rewriting the bytes or path strings in the historical hash preimage. The current B execution domain cannot authenticate A. Recomputing surrounding FileRef hashes after changing only a historical `domainHash` must still fail before signing or nonce allocation. This preserves `S/execution-domain.ts:36-60` and `S/journal.ts:24-82`.

`books` is unique and sorted by book ID; each entry's complete tuple must hash to its key and match the chain/proxy/format. Authenticate the successful setter transaction, its exact calldata and one `MigrationWeightedPricingSet` event at the canonical receipt block. Getter equality is checked at the entry's pinned observation block, with header checks before/after reads. This is proof of **owner-configured inputs**, not proof that the inputs matched a historical pool. For multiple updates in one block, use a dedicated following observation block at which that book was current, or authenticate that entry through its exact setter calldata/receipt and the subsequent accepted configuration receipt; never claim end-of-block getter state proves an overwritten intra-block value.

Configuration and issuance facts are separate. No global "latest book equals every manifest book" check remains. Operation rules are:

| Operation | Required verification |
| --- | --- |
| Prepare a new load | Validate input documents/source claims, full book hash/domain and the current book at the pinned quote block. Call retained `previewOriginalCredit` for each distinct full component pair on that same book/block; preserve separate NFT 3 components and claimed-SY weight fraction. A new explicit reload records the exact accepted configuration it replaces. |
| Rehydrate/validate a saved manifest | Recompute normalized/document/payload hashes and each configuration preimage; authenticate all referenced books and accepted facts. Do **not** call `prepareDomain` to regenerate every row at today's price. Retained/mined rows are checked against their exact original input, per-original credits, configuration event/state and origins. No current-price re-quote of old records. |
| Sign/simulate/send an unsent load | Resolve prior intents first. Verify the actual current stored configuration is absent for `replaces:null`, or exactly matches `replaces` for an explicit reload. Recheck current book equals the row's scalar expected book; compare fresh current-book previews with the prepared credit. Encode that scalar into every loader, so B mining between this preflight and the load still reverts atomically. Do not sign or resend an A load while current book is B. |
| Resume an already-mined A load after B | Reconstruct A's original journal domain and validate signed calldata, chain, signer, nonce, transaction hash and transaction-specific canonical receipt/events/evidence under the rule below. Complete its old journal before allocating any new nonce, even if B replaced the same key later in that block. A's historical completion and current B verification are separate; never require an end-of-block getter to return overwritten A. |
| Verify retained A and newly loaded B rows | Match each accepted row's current configuration ID, entire stored input, exact credit, stable original identity and applicable Q/C or consumed facts. No automatic adoption of unexpected replacements. Later Stage 2 consumption may change Q/C, not the stored original credit or provenance. |
| Issue an unissued independent recipient | Match the selected configuration ID and stored credit; current pricing may differ. Use existing `issueIndependentAllocations` with no price argument. A recipient already issued is checked through `issuedHistory`, never queued for another issue. |
| Same recipient: current configuration B, issuance A | Verify current `independentAllocation` against B. Independently reconstruct A's configure and issuance journal domains and verify `independentIssuance` against the A accepted manifest and transaction-specific issuance evidence: configuration ID, credit, bond ID and actual creation timestamp. Verify initial bond owner/funding/90-day terms at issuance, preserved principal/start/duration, and current solvency/claimed or retired facts as applicable. Never compare A issuance credit/ID with B config or reject its legitimate difference. |
| Activate, owner-bond, ordinary funding or harvest | Preserve exact package, authority, source, selected record and signed-intent checks. Activation verifies selected issued-history facts and current configurations plus paid owner purchase, not a global book equality, all-records-current gate or new pricing-ready flag. Ordinary owner-bond arguments contain no manual book ID. |

`configurationId` derivation uses the row's `bookId`; never a mutable top-level default. Group loader batches only within the same function and expected book ID. Retain rows generate no configure operation. A saved original load whose exact canonical receipt already exists generates no resend. New explicit replacement/price-setting runs use new immutable manifests and new checkpoint directories, with exact prior FileRefs; old journal domains and signed bytes are never rewritten or moved.

Historical completion is transaction-specific. Authenticate the canonical block hash and ordered transaction list; require the receipt's transaction hash/index and each log's emitter, transaction hash/index, global log index, topics/data and ordering to match that transaction. Decode its exact calldata and compare the expected ordered configuration/issuance events, full configuration preimages, credits and originals; event-name presence alone is insufficient. Gather later canonical writes to the same key in that block before using a block-tag getter. End-of-receipt-block equality is valid only when the fact being checked survives to block end. If B supersedes A later in the block, use A's calldata and exact ordered events for the facts they establish, plus authenticated transaction-local call/state evidence for required values they do not establish (for example per-original stored credits or intermediate funded gons). Bind that evidence to A's block hash, transaction hash/index and actual executing code; use the existing local trace/replay facilities, never fabricated storage or B's block-end value. Missing necessary transaction-local evidence is an explicit verification failure, not a resend or permission to retry the refused historical trace campaign. Record these observations separately from current B state in A's completion. A later valid B does not invalidate A's historical success, and authentic A does not authorize adopting an unexpected current B.

Preserve existing operation IDs exactly (`S/execution-plan.ts:18-48`): the default is `fingerprint(canonical({stage,method,transaction}))`, where `fingerprint` is SHA-256; donation approvals instead use `fingerprint(canonical({donation:donation.id,token,transaction:approval.transaction}))`, and the donation itself uses `fingerprint(canonical({id:donation.id,transaction:last.transaction}))`. Do not apply the default to those funding operations. Distinct intentional donation IDs with identical calldata must remain distinct operations, while resuming the same ID reconciles its own receipt without resending. Preserve the exact signed-intent/domain binding, resolve-all-prior-intents-before-new-nonce ordering, no-resend on missing canonical receipts/ambiguous moved nonces, live writer locks, and default read-only mode. Separate book-setting verification from later current-state verification: an old successful A setter receipt remains valid after B, but an unsent A setter is not inferred to be an intended rollback. New price changes require an explicitly selected `set-pricing` stage with the complete next Inputs. Setter idempotency does not infer new operator intent.

For same-recipient B configuration/A issuance, `issuedHistory` references A independently of B's `pricing.replaces`. Reject omitted issuance history when on-chain `issued == true`, mismatched A principal or origin sets, an unknown replacement C, mutated artifacts, wrong chain/proxy/format, fabricated receipts and noncanonical headers. Validate duplicate-origin partitions across the complete current configuration census and immutable issuance history with the existing allowed same-recipient replacement rule; history is evidence of an already-paid fact, never another new entitlement.

Claimed-SY certificates currently bind `snapshotCapture` and use its block for the origin census (`S/claimed-sy.ts:12-18,70-129`). In v2 replace that field with `pricingSet: {bookId,transactionHash,blockNumber,blockHash}`, authenticate the setter receipt/calldata/event for **that row's** book, and bind the evidence ID as `keccak256(UTF8(canonical({kind:"IndexedEx.complete-original-claimed-sy-v2",chainId,proxy,bookId,original:originalWithoutEvidenceId,certificate})))`. Different row books and setter blocks are valid. Census all configured SY origins from the authenticated deployment block, not only since B; do not remove the completeness check. Source member transactions/signatures, actual fixed source/facet hashes, transaction-local consumed weights and measured SY, excluded floors, complete eligible remainder, duplicate member rejection and non-issuable financial-review boundary remain unchanged. No pricing relaxation authenticates a raw-weight pull or historical allocation.

### Later requirements amendments, preserving IDs

Task 1 edits P only during separately authorized execution, adding section 1.10 dated 2026-11-14 with the following operative text and updating conflicting active clauses. Keep all IDs and historical owner decisions. The older `MIGRATION_DETF_DRAFT_PRD.md`, evidence archives and review report remain historical; put an explicit precedence pointer in P rather than silently rewriting them.

> The owner selects Weighted Hook compensation pricing from complete manually configured calculation inputs. Inputs may represent observed state or deliberately adjusted compensation policy. The current proxy owner may atomically replace the complete manual book throughout Stage 1, including after the paid first ordinary bond, until the existing activation transaction removes every pricing/configuration/independent-issuance selector. There is no separate pricing lock, readiness lifecycle, compare-and-swap setter or all-records-current gate.
>
> Each full economic original is quoted with the supported canonical Weighted calculation at explicit configuration time. Manual pricing changes affect new previews and subsequent explicit loads only; existing credits and configuration identities remain unchanged until explicit full replacement. Immutable issuance, consumption, custody and bond facts are never resized, reopened or repriced by either operation. Every quote-sensitive loader checks one expected book ID atomically before quotation or mutation. Economic-original identity excludes mutable pricing; replaceable configuration provenance includes the complete domain-bound book ID.
>
> Raw inventory, SE inventory, rates, scales, weights, fee, seigniorage and supported V3 deposit operands are the authoritative calculation inputs. Preserve canonical mapping, units, rounding, fee/user split and limits. Do not substitute linear output prices, flat buffered conversion rates, independently editable derived balances, live fallback, partial-input re-quotation or a universal nested-vault model. Source identity, original contributions, custody and conservation still require authenticated evidence. Manual inputs are not historical-state attestations.
>
> E3 closes when the declared supported manual models reproduce canonical supported observed-state fixtures, honor deliberately adjusted inputs and reject unsupported domains, with no live dependency during evaluation. No selected live production reserve composition or numerical award is approved by this amendment. Funding remains before dependent operational configuration and issuance; pricing correctness is not a new on-chain funding gate. All unrelated requirements and owner clarifications remain in force.

Apply that text specifically to MIG-P01 (book at explicit load), P02 (stored proportional credit), P10 (replacement independent of issuance), P11 (setter in cut), P12 and MIG-AC15 (replace the obsolete no-price-setter sentence), P13 (funding-first, no capture-finalization gate), section 1.1's pricing-role language, section 1.5's no-recapture wording, section 1.7's "same snapshot", E3, sections 4/5.1/5.3/6/6.1, original tasks 2/4/7/9, funding/snapshot test row, snapshot invariant, MIG-AC21/22/24/31/36/38/49/51/52 and section 11. MIG-AC24 now proves live independence, keep-until-reloaded, explicit Stage 1 replacement and postactivation immutability. Preserve every unrelated word-level requirement, all 53 acceptance IDs and all section 8 examples. Add the A/B and same-recipient scenarios as witnesses under existing IDs, not a new competing acceptance catalog.

### Must NOT have (guardrails, anti-slop, scope boundaries)

No implementation, product-file edits, tests/builds/installs, RPC calls, Git mutations or public action in this planning session. Later execution is confined to the listed migration/operator/tests/evidence paths plus the narrow active callers needed by the renamed ABI. No change to ordinary DETF economics, general Crane ownership behavior, shared canonical pricing math, unrelated source policy or product/package naming. Do not modify a shared math primitive merely to make the new book easier to implement.

No setter CAS, monotonic counter, extra facet, early freeze, automatic reprice/reload, price-ready flag, latest-book activation scan, arbitrary credit setter, parallel pricing evaluator, new identity registry, principal liquidation policy, generic recovery executor, source category waiver, raw-weight ERC20 pull, zero-output-return restoration, hidden chunking, invented historical stdout or financial allocation.

All task-created work must be inventoried and delivered. Preserve unrelated dirty/untracked work, submodule state, original evidence bytes and live signed journals. Do not blanket-copy a worktree, blanket-stage a directory, overwrite divergent user files, delete historical failures or silently exclude helper programs. A concrete unavailable source/QA dependency stays an explicit incomplete implementation gate, not a pass.

## Verification strategy
> Zero human intervention - all verification is agent-executed.
- Test decision: **TDD/regression-first**, Foundry Solar and existing Bun/TypeScript tests. Add observable behavior checks before fixing each changed behavior, then run their positive and rollback paths. API replacement may initially fail to compile against the old API; record that separately from behavioral regression. Prove stale load, origin drift, invalid NFT 3 mode and same-recipient history failures at the nearest existing executable boundary. Do not call copied inventories or prose assertions regression tests.
- Production-first: real manager/registry, CREATE3 facets, ordinary reserve, staking/SY/bond children and authenticated legacy fork sources. No mocked/etched/storage-injected SUT, no empty adversarial alias. Deployment helper artifacts must be rebuilt before tests. Use `python3 scripts/forge-artifacts.py test` for focused production changes; all compiling Forge invocations use `--use solar`, never `via_ir`.
- Evidence: each task owns `E/task-N/`, raw logs plus `commands.json` recording full command, cwd, source-content fingerprint, compiler/runtime versions, exit code, case counts and artifact paths. `N` is the literal task number in the paths below. Program-generated records use exclusive creation; retries use a new numbered attempt directory. No overwriting prior stdout. Current source manifests use content hashes and optional actual Git revision; do not invent a clean commit.
- Retained historical records are reusable only with their exact source binding. The reported 86/91 match and EOF-only differences in the prior insight bundle are historical observations to re-index, not a current verification claim. Changed pricing, ABI, original-ID or operator semantics require fresh evidence.
- Load the repository's current `CLAUDE.md`, assistant rules and canonical Crane/testing skills before execution. Seed a new task worktree's `cache_forge/` and `out/` from a warm checkout without deleting unrelated state. Serialize compilation on a shared artifact directory; long commands run asynchronously with completion subscriptions and exit evidence. Do not kill cold Solar builds for silence.
- All shell command blocks below are **future execution commands**, run from the execution checkout root after task prerequisites. Alias variables are defined literally below; they are not unresolved placeholders. Record the environment once per command worker. Diagnostic file commands are not product tests.

```bash
M=contracts/vaults/detf/protocols/dexes/uniswap/v4/migration
T=test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration
K=test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration
S=scripts/recovery/dtf-migration
D=docs/incidents/2026-09-16-dtf-recovery/migration
E="$D/conformance-20261114"
R=/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts/docs/incidents/2026-09-16-dtf-recovery/migration
```

The full-tree run in task 13 is required even when focused tests passed. Final verifiers inspect those results and actual recorded proxy/custody receipts; do not run a second identical green suite merely for another sign-off. A later source change invalidates affected evidence and requires the relevant rerun. Missing archive access is unrun, never passed; do not switch providers, purchase service or retry the explicitly refused historical trace.

## Execution strategy
### Parallel execution waves
> Target 5-8 todos per wave. Fewer than 3 (except the final) means you under-split.

Five implementation waves, followed by one final verification wave: **15 implementation tasks + 4 final verifiers = 19 tasks, 6 waves total**. Keep the shared ABI/pricing change and mixed-record algorithm cohesive instead of splitting their reasoning across simultaneous writers.

| Wave | Tasks | Ordering and allowed parallel work |
| --- | --- | --- |
| 1: Reconcile and recover | 1, 2, 3 | 1 and 2 may run in parallel; 3 follows 2's inventory. No production edits. |
| 2: Contract and source remediation | 4, 5, 6 | 4 and 5 use disjoint Solidity/TS files; 6 follows 3 and 4 before editing shared legacy guards. |
| 3: Operator and coverage closure | 7, 8, 9, 16 | 7 owns operator implementation, 8 owns adversarial/invariant fixtures, 9 owns substantive docs. Task 16 follows 7 and repairs the donor-evidence transport prerequisite. Compile jobs serialize. |
| 4: Observable workflows | 10, 11, 12 | 10 and 11 may run in parallel on disjoint files; 12 starts after both are integrated. After task 7's baseline, 10 is the sole writer of `rehearsal-proof.ts` and 11 of `execution.test.ts`; 12 sends required additions to those owners and consumes their serialized integration before its QA. Other shared operator fixes return to task 7's owner. |
| 5: Final tree and delivery | 13, 14, 15 | Sequential: final tests, source-qualified traceability, then complete delivery audit. |
| 6: Final verification | F1, F2, F3, F4 | Independent read-only verdicts over the same final tree and evidence after task 15, followed by the coordinator's additive delivery inventory of all four reports. |

### Dependency matrix
| Todo | Depends on | Blocks | Can parallelize with |
| --- | --- | --- | --- |
| 1 | None | 4, 5, 6, 14 | 2 |
| 2 | None | 3, 9, 11, 13, 15 | 1 |
| 3 | 2 | 6, 9 | No concurrent writer to recovered indexes |
| 4 | 1 | 6, 7, 8, 9, 10, 11 | 5 |
| 5 | 1 | 7, 10 | 4 |
| 6 | 1, 3, 4 | 8, 9, 10, 11, 13 | Disjoint task 5 tests |
| 7 | 4, 5 | 10, 11, 12, 13 | 8, 9 |
| 8 | 4, 6 | 10, 13 | 7, 9 |
| 9 | 2, 3, 4, 6 | 14 | 7, 8 |
| 10 | 7, 8, 16 | 12, 13, 14 | 11 with separate nodes/worktrees |
| 11 | 2, 4, 6, 7 | 12, 13, 14 | 10 with separate nodes/worktrees |
| 12 | 7, 10, 11 | 13, 14 | None until both shared-file owners integrate |
| 13 | 8, 10, 11, 12 | 14, 15 | None on the final artifact tree |
| 14 | 1, 9, 10, 11, 12, 13 | 15 | None |
| 15 | 2, 13, 14 | F1-F4 | None |
| 16 | 7 | 10 | No concurrent bundle/schema writer |

No commits, merges, PR creation or public transactions are authorized by writing this plan. Execution permissions must be supplied separately. Every task's commit disposition below is `N`; suggested future commit boundaries become usable only with explicit commit authorization and green dependent checks.

## Todos
> Implementation + Test = ONE todo. Never separate.
<!-- APPEND TASK BATCHES BELOW THIS LINE WITH edit/apply_patch - never rewrite the headers above. -->
- [x] 1. Reconcile original requirements with approved manual pricing.
  - Recommended task executor category: writing. This is a bounded requirements amendment with settled owner decisions.
  - Dependencies: none. Wave 1; blocks 4, 5, 6 and 14.
  - Closes: GAP-1, GAP-8, GAP-10.
  - Allowed writes: P only, plus `E/task-1/requirements-reconciliation.md` and its QA records. Read the older PRD for referenced IDs only if needed; do not edit it or historical review/evidence files.
  - Work: apply the exact section 1.10 text and amendment targets above. Preserve original sections 1.1-1.9, MIG-P01-P15, E1-E5, all 53 MIG-AC IDs, all 13 arithmetic examples and unrelated section 11 obligations. Add cross-references at obsolete active capture/no-setter clauses so an executor cannot choose the superseded rule. Explicitly replace the in-scope artifact names and E3 acceptance, without authorizing allocations or deployment. Explain why review F2's live composition prerequisite is superseded and why F1/F3-F6 still require closure.
  - References: P:13-119,182-222,239-301,387-419,444-548,575-725; delta bundle sections Hard Constraints/Decisions; approved draft:105-152; review PRD:48-55,93-111. The exact amendment text in this plan is the operative replacement, not an invitation to reopen pricing.
  - Acceptance criteria: one unambiguous active specification; manual inputs/keep-until-reloaded/activation removal and stable originals are consistent across every cited clause. No acceptance ID or unrelated requirement disappears. The reconciliation maps every amended location to its owner decision and future witness.
  - Happy QA: agent `read` of the complete amended P and `git diff -- docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md` after loading git-master; inspect each hunk against section 1.10 and the complete old document. Record the review at `E/task-1/requirements-reconciliation.md`.
  - Failure QA: run `tool.grep({pattern:"no contribution-price setter|no price setter|capture once|Capture once|captureMigrationSnapshot|snapshot immutability",path:"docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md",context:2})`; any remaining active contradictory instruction fails this task. Historical statements must be explicitly labeled superseded. This is a document consistency inspection, not a source/prose unit test. Record exact remaining hits and dispositions at `E/task-1/obsolete-clause-check.md`.
  - Commit: N. If later authorized, `docs(migration): reconcile manual Weighted pricing requirements`; keep this scope separate from historical financial evidence.

- [x] 2. Recover every retained artifact and verification program.
  - Recommended task executor category: deep-low. Byte provenance and integration decisions follow existing files and recorded ownership.
  - Dependencies: none. Wave 1; blocks 3, 9, 11, 13 and 15.
  - Closes: GAP-7, GAP-8, GAP-10.
  - Allowed writes: missing or explicitly reconciled task-owned files under D; `E/task-2/`; extend the delivered `D/resumed-integration/record-verification.ts` for the inventory/delivery modes below. Never alter R, frozen incident inputs or unrelated workspace changes.
  - Work: enumerate every file and symlink under R, the task-created migration evidence already present in the primary tree, and other migration task outputs named by their existing execution manifests. Record source path, destination, size, raw-byte SHA-256, source revision/content binding, ownership, status and all differences. Integrate missing files at the same relative D path. Preserve conflicting historical/current versions with explicit source qualification and a lossless archived copy under `E/task-2/retained-originals/`; do not overwrite a divergent user file. Distinguish identical, EOF-only and semantic differences. Account for every candidate; an unknown/conflicting ownership row blocks delivery until resolved from existing evidence or, only if truly unavailable, by the owner.
  - Required delivered programs: `D/resumed-integration/record-verification.ts` and `D/resumed-integration/verify-bounded-deployments.ts`. Required retained families include source-manifest/matrix, recovery-route-disposition, final-source, final-hermetic-r2/final-fork/final-operator records, resumed-integration/bounded-remediation, recovery-receipts, b1 source-local iterations, b2-public-exit-probe, remaining-SY and deployment-gas-resumed. Retain failures, command sidecars, logs and existing reviewer outputs; do not manufacture absent stdout.
  - Extend `record-verification.ts` with `inventory <new-output-directory> <retained-root> <destination-root>` and `delivery <inventory-json> <new-output-directory>` modes. Inventory walks every entry without following symlinks out of scope, hashes raw files and records both trees; it emits `inventory.json` and a human differences report. Delivery checks every recorded task-owned destination exists with the expected bytes or an explicit source-qualified superseding record, every newly created task artifact is added to the manifest, and every divergent/excluded row has a recorded disposition. Missing task-owned files are failures, not a skip option. The helper must not copy, delete, stage or commit files itself.
  - References: R directory and `R/resumed-integration/record-verification.ts:1-51`; `R/resumed-integration/verify-bounded-deployments.ts:12-100`; prior conformance bundle:29-39; P:453,474,536,546,696-725; review PRD:39-45. `R/final-source-20261113.json` is a historical manifest, not authority to revert current dependency/workspace changes.
  - Acceptance criteria: all retained task-owned bytes are present or losslessly preserved with explicit updated destination; both helpers retain working relative imports and their original verification modes. All omissions are resolved before completion, with no four-Markdown-file scope reduction.
  - Happy QA: `bun "$D/resumed-integration/record-verification.ts" inventory "$E/task-2/inventory" "$R" "$D"`; inspect `E/task-2/inventory/inventory.json` and each divergent row. Compile-check delivered helpers using the existing TypeScript invocation in task 13, without running their network modes yet.
  - Failure QA: exercise inventory/delivery on two temporary **fixture directories** created beneath `E/task-2/inventory-negative/`: one source-only file, one byte-tampered destination and one outward symlink. `delivery` must return nonzero and name each missing/different/unresolved entry; the source and destination remain unchanged. Save command/exit/output in `E/task-2/inventory-negative/`. This tests file-integrity behavior, not a copied expected file list.
  - Commit: N. If later authorized, `docs(migration): restore source-qualified recovery evidence and helpers`; do not commit unrelated dirty or untracked work.

- [x] 3. Complete authenticated source and recovery evidence indexes.
  - Recommended task executor category: deep-low. Recover exact source facts rather than infer policy from current tests.
  - Dependencies: 2. Wave 1; blocks 6 and 9.
  - Closes: GAP-6, GAP-8.
  - Allowed writes: `D/source-manifest.json`, `D/source-route-matrix.md`, `D/recovery-route-disposition.md`, `E/task-3/`; source-only fork observations may extend `K/MigrationLegacySources.t.sol` and `K/MigrationLegacyLpExit.t.sol`. No financial allocation changes.
  - Work: complete one row per required category/generation: weighted/earlier DETF, weighted fixed-principal/earlier LP-lock NFT, weighted/earlier receipts, SY, TokenStaking prepared remainder, direct claim-vault rights, W-SD, W-SW, E-S, W-P, E-P. Index exact contract and runtime identity, proxy route selector, resolved facet/code hash, ABI input/return schema, ownership/current-unit read, original/remaining unit, receipt/conversion equation, disabled behavior, actual surrender and rollback witness, and conditional recovery evidence. Shared proxy bytecode is legitimate but does not identify the delegated facet.
  - Recover null hashes for weighted NFT and weighted/earlier receipts from existing raw `eth_getCode`/loupe/receipt archives and their pinned headers. Use the existing chain 4663/block 108944663 evidence and recorded hash `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`. A missing raw fact alone permits a narrow pinned read during later execution, not a broad audit or historical trace retry.
  - Resolve earlier collection IDs 0, 1 and 2 from authenticated deployed source initialization/reserved roles, ownership/position reads and original acquisition evidence. Record each as reserved/nonexistent or qualifying source position. Do not infer their roles from `tokenId < 3` in current Solidity/TS or from the new bond child's reserved IDs. This produces the deterministic guard input for task 6; it does not invent eligibility.
  - For E-P permanent custody, bind the exact source withdrawal facet and immutable owner-only methods, parent accepted intake/claimLiquidity, NFT forwarding roles and collector paths. Preserve current-fee-recipient exception only for W-P. Temporary disablement, present dust and lack of incoming rewards are conditional availability, not proof of permanent inability. Source authority stays external to Migration.
  - References: P:87-119,164-196,444-453; `R/source-route-matrix.md:5-22`; `R/recovery-route-disposition.md:5-41`; `M/legacy/MigrationLegacyNftLib.sol:14-64`; `S/claimed-sy-source.ts:3-37`; review PRD:57-64,101-111.
  - Acceptance criteria: every required row has an exact evidence-backed route or a concrete unresolved source fact; any unresolved actual source/custody/conservation gate blocks task 6 and final implementation completion. Proving no exposure requires approved dataset evidence; no dataset is invented here. A reserved-ID finding is a fact, not a new owner decision.
  - Happy QA: first inspect raw archived identities/receipts and link their file hashes. Where a missing fact needs execution, run `FOUNDRY_PROFILE=fork python3 scripts/forge-artifacts.py test "$M/legacy/MigrationLegacyNftLib.sol" --test-root "$K/MigrationLegacySources.t.sol" --test-root "$K/MigrationLegacyLpExit.t.sol" -- -vv`; emit pinned header/source/schema observations to `E/task-3/source-observations.json` and capture logs there.
  - Failure QA: the same real-source suites must show wrong wallet, invalid/nonexistent source ID and unauthorized E-P exit rejection without changed holdings/supply. Validate that a deliberately wrong archived runtime hash is reported as an integrity failure by the inventory helper without changing the archive. Evidence: `E/task-3/source-negative.log` and source matrix witness links.
  - Commit: N. If authorized later, `docs(migration): bind source units and recovery witnesses`.

- [x] 4. Replace capture with exact manual Weighted pricing.
  - Recommended task executor category: deep-high. One cohesive ABI/storage/math boundary must preserve invariants across pricing, configuration and activation.
  - Dependencies: 1. Wave 2; blocks 6, 7, 8, 9, 10 and 11.
  - Closes: GAP-1, GAP-2, GAP-3, GAP-4.
  - Allowed writes: M's pricing interface/library rename, retained facet/target rename, repo, both allocation targets/facets, migration interface, package/factory wiring, TestBases and active Solidity imports/call sites; related T/K/FS callers needed to compile the changed ABI. Shared canonical math remains unchanged. Keep an exact touched-file list; widen only to an actual compiler/reference consumer of these symbols.
  - Work: implement every field, validation, preimage, branch, setter, getter, expected-book loader and rename/cut rule in Scope. Delete obsolete active capture acquisition/decode/live-auth code from the migration library; retain ordinary capture support in shared Weighted components for ordinary consumers and differential fixture acquisition. No duplicate evaluator. Adapt production TestBases and compile consumers to manually supplied supported inputs. Never call live providers during setter validation/evaluation. Preserve owner-first purchase, all funding/reward gates, stored credit and issuance.
  - Complete stable economic ID changes in Solidity, including all origin collision guards. Update actual artifact strings/salts, library linking and prediction inputs together; rename does not promise old addresses. Replace old snapshot interfaces/events/errors in active migration-facing surfaces. Getter/domain reads stay retained; source recovery getters and package arguments still work before pricing is set.
  - Add focused `T/MigrationWeightedPricing.t.sol` using the real production fixture; reshape the existing `T/UniswapV4DetfMigrationSnapshot.t.sol` and pricing TestBase into manual supported-state differential coverage rather than retain dead capture semantics. Keep useful live oracle comparisons in tests. Update each existing configuration suite for both expected-book success and A-prepared/B-current revert.
  - Required cases: empty initial book; complete A then B then identical B; owner/current/pending/former roles; setter after paid owner bond; unauthorized/malformed set rollback; all four leg modes; raw provider floor before scale; disabled-buffer inventory rate without inflow rate; enabled V3 amount dependence; zero components, grouping and no reserve mutation; fee/seigniorage once; 6/18/24/36-decimal SE operands within the admitted mapping; checked overflow, unsupported model/output, mapped max-in boundary, native/rated output limits and zero output. Observed supported-state fixtures equal the canonical primary mint branch, not its threshold swap fallback. Deliberately adjusted manual inputs alter new quotes even if live state differs.
  - A-to-B tests retain stored A credit/ID, Q/C, original ID and issued bond. Explicit B replacement updates configuration only; same-recipient issuance A remains unchanged. NFT origins remain stable across books and collide with other representations as before. An activation test with no configured entitlements and unset book succeeds after real funding and paid owner purchase, proving no accidental readiness gate. An actual proxy loupe test proves every writer is removed, old aliases absent and getter/preview retained.
  - References: current pricing interface:9-60; `M/UniswapV4DetfMigrationSnapshotLib.sol:25-89,120-181`; `M/UniswapV4DetfMigrationAllocationTarget.sol:37-179,215-240`; `M/UniswapV4DetfMigrationClaimVaultAllocationTarget.sol:15-105`; `M/UniswapV4DetfMigrationRepo.sol:18-79`; migration interface:670-785; `MigrationLegacyNftLib.sol:20-24`; `W/UniswapV4StandardExchangeWeightedBufferHookMath.sol:48-104,197-216`; ClaimLib:151-163; `contracts/utils/StandardExchangeFrozenQuoteLib.sol:39-56`; `contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol:30-65`; `DETFMintSplitLib.sol:19-26`; existing pricing test:38-150; component factory:15-20.
  - Acceptance criteria: canonical branches and failures match; every loader checks the scalar before mutation; A/B economics and exact IDs follow Scope; real proxy declaration/cut tests and affected configuration tests pass with rebuilt artifacts. New pricing/rename behavior has fresh proof, not relabeled old receipts.
  - Happy QA: `python3 scripts/forge-artifacts.py test "$M/UniswapV4DetfMigrationWeightedPricingLib.sol" "$M/UniswapV4DetfMigrationWeightedHookFacet.sol" "$M/UniswapV4DetfMigrationAllocationTarget.sol" "$M/UniswapV4DetfMigrationClaimVaultAllocationTarget.sol" --test-root "$T" -- -vv`; record differential input/intermediate/output vectors and actual proxy selector lists in `E/task-4/`.
  - Failure QA: run the same rebuilt suites with `--match-test 'test.*(StaleBook|InvalidManual|UnsetPricing|UnauthorizedPricing|PricingRollback|OriginCollision|MaxIn|ZeroOutput|ActivationCut)' -vvvv` after creating these behavior-named cases in the specified suites. Assert the expected errors and exact unchanged configuration, custody, supply, bond and selector state; at least one executed test per named failure family. Evidence: `E/task-4/failures.log` and `E/task-4/proxy-census.json`.
  - Commit: N. If later authorized, keep the ABI change with its adapted callers and tests; do not commit an intermediate tree that breaks operator typechecking. Suggested eventual subject: `feat(migration): configure exact manual Weighted pricing`.

- [x] 5. Require separate contributions for weighted NFT three.
  - Recommended task executor category: deep-low. The exact owner-decided identity and behavior belong at an existing input boundary.
  - Dependencies: 1. Wave 2; blocks 7 and 10.
  - Closes: GAP-5.
  - Allowed writes: `S/schema.ts`, `S/payloads.ts`, `S/nft-contributions.test.ts`, `S/preparation.test.ts` and their existing fixtures. Do not change the Solidity eligibility policy or ordinary NFT issuance loop.
  - Work: for chain 4663, weighted collection `0xfe4cc6d5faafdf210af4e728f4108fcaad9bb65e`, token `"3"`, reject absent/false/combined contribution mode at schema/payload preparation before quote/RPC/signing. Require exact agreed raw18 originals `"999999000000000"` WETH and `"362893857600000000000"` DTF with explicit source proof; only quoted credits remain computed from the selected book. Other configured NFTs retain their existing one/two-original options. Keep ETH then DTF ordering and two nonzero components.
  - References: P:95-101; `S/schema.ts:36-48`; `S/payloads.ts:55-64,114-126`; `S/execution-plan.ts:59-62`; `M/UniswapV4DetfMigrationClaimVaultAllocationTarget.sol:57-77`; prior conformance bundle:26-27.
  - Acceptance criteria: omitted/combined/wrong-amount NFT 3 data never creates a load plan; the accepted row preserves two independently quoted originals without merging; other NFT identities are unaffected. Source proof and same-wallet requirements remain.
  - Happy QA: `bun test --timeout 15000 ./scripts/recovery/dtf-migration/nft-contributions.test.ts ./scripts/recovery/dtf-migration/preparation.test.ts`; assert generated separate loader, component order and exact raw amounts. Evidence: `E/task-5/happy.log`.
  - Failure QA: in those existing suites, pass NFT 3 without `separateContributions`, a combined false mode, a missing component and altered original amount; assert controlled `INPUT`/`PROVENANCE` rejection before quote transport and zero transaction creation. Keep a non-NFT-3 combined row as a positive control. Evidence: `E/task-5/rejection.log`.
  - Commit: N. If later authorized, `fix(migration): enforce NFT three separate originals`.

- [x] 6. Close evidenced source and recovery behavior gaps.
  - Recommended task executor category: deep-low. Make only changes demanded by authenticated source facts and existing owner rules.
  - Dependencies: 1, 3, 4. Wave 2; blocks 8, 9, 10, 11 and 13.
  - Closes: GAP-6, GAP-8, GAP-10.
  - Allowed writes: source-specific M/legacy adapters and migration recovery/claim targets only where task 3 demonstrates a mismatch; `K/MigrationLegacySources.t.sol`, `K/MigrationNftLifecycle.t.sol`, `K/MigrationOriginalWallet.t.sol`, the existing K source/recovery suites, and corresponding S source guard only if required. All affected source rows receive evidence under `E/task-6/`.
  - Work: use task 3's per-collection reserved-ID facts. If earlier 0-2 are reserved/nonexistent, retain its existing guard and add the source witness. If any is a qualifying historical position, replace the blanket rule with that collection's exact authenticated reserved-role rule in both Solidity and TS; retain the weighted reserved-ID rule. Never infer a qualifying original from current balances alone.
  - Preserve original-wallet/configured Stage 2 surrender for every admitted category, exact custody and source-unit accounting. TokenStaking remains one full original across complete/remainder preparation and measured SY, with distinct originalWeight/eligibleWeight/originalUnits, excluded disposed/paid portions, no competing representation and final Q/C residue. Direct claim-vault shares remain native19, W-SD native28, weighted receipt original gons, earlier receipt internal shares and NFT external shares/remainder distinct. No raw-weight approved pull.
  - Close actual missing typed recovery behavior only if task 3 identifies it. Preserve current working fixed conversions and zero-output rejection. Demonstrate repeated reward-only weighted/earlier harvests after maturity and after a prior harvest, genuine new source income, conversion/donation, unchanged principal/claimed-principal/NFT custody and protected unbooked units. Principal-bearing calls stay separate explicit selections. E-P permanent custody remains conditional on the exact immutable/alternative-path evidence, never generalized to earlier liquid/NFT/receipt or W-P. Do not grant Migration external governance authority.
  - References: P:47-119,188-196,303-385,497-525; `M/legacy/MigrationLegacyNftLib.sol:28-78`; `S/schema.ts:61-139`; `S/claimed-sy.ts:22-56,89-129`; retained source matrix:7-22 and recovery disposition:9-37. The apparent default `WeightedClaim` in rehearsal data is not proof the routine helper withdrew principal; follow the actual call path.
  - Acceptance criteria: E1/E2 and recovery route rows have actual positive, atomic rejection and conservation witnesses, or an explicit factual blocker that prevents completion. No required category is silently deferred. A no-code-change result is valid when authenticated witnesses close the claim; an empty alias or prose-only pass is not.
  - Happy QA: `FOUNDRY_PROFILE=fork python3 scripts/forge-artifacts.py test "$M/UniswapV4DetfMigrationRecoveryTarget.sol" "$M/legacy/MigrationLegacyNftLib.sol" --test-root "$K" -- -j 1 --compute-units-per-second 10 --rpc-timeout 120 -vv`; record per-source successful custody, remaining units, exact bond funding and recovery deltas in `E/task-6/source-results.json`.
  - Failure QA: use that K run's wrong-wallet/unconfigured/Stage1, source-identity, second-bond-failure, principal race, wrapper overlap, zero-credit, unauthorized exit and middle-batch failure cases. Assert complete selected-transaction rollback while earlier stages remain in custody. Task 3's source facts determine the earlier-ID test expectation. Evidence: `E/task-6/rollback-and-custody.log`.
  - Commit: N. If later authorized, `fix(migration): close authenticated source recovery gaps`; omit a production-fix commit when only evidence/tests changed.

- [x] 7. Implement book-aware preparation and mixed-record reconciliation.
  - Recommended task executor category: deep-high. This is one cross-file operator contract whose correctness depends on distinct configuration and immutable issuance identities.
  - Dependencies: 4, 5. Wave 3; blocks 10, 11, 12 and 13.
  - Closes: GAP-3, GAP-4, GAP-5, GAP-8.
  - Allowed writes: S schema/payload/preparation/quotes/provenance, claimed-SY evidence consumers, execution schema/domain/plan/state/rpc/journal, CLI, bundle readers/materializers and the existing TS fixtures/tests; FS staged execution caller and existing rehearsal data/call sites required by the ABI. Task 10 owns new lifecycle scenarios and task 12 owns new portable scenario cases.
  - Work: implement the exact v2 format and operation table in Scope, all twelve loader scalars, stable NFT/exposure identity and full manual-book preimage. Replace global snapshot equality with operation-sensitive checks while retaining chain/proxy/purpose/format, code relationships, input-file hashes, complete tuple hashes, source claim authentication and exact transaction/receipt checks.
  - Split `prepareDomain` new-load quotation from saved-manifest rehydration. `validateManifest` must validate saved fields/proofs and per-record accepted state without regenerating retained rows at current pricing. Independently reconstruct each historical configure/issuance domain from its original execution/prepared/journal FileRefs, including both preparation hashes and all bindings; compare the canonical domain and `intent.domainHash` before accepting that intent. `loadExecution` first validates immutable bytes/domain; `execute` then loads fixed checkpoint intents and reconciles canonical receipts before any latest-book restriction on an unsent operation. `captureCompletion` decodes the **original intent's** array plus final expectedBookId and uses transaction-specific ordered events/local evidence, consulting receipt-block state only for facts proven to survive block end. It must not look up old A by recipient in a newer B manifest or mistake B's end-of-block state for A. `verifyConfiguration` separately checks current complete stored configs and `issuedHistory`, not only `issued:true`.
  - Replace CLI stage `capture` with `set-pricing`; `executionManifest.pricing` is `Inputs | null`, and an explicit price stage encodes one setter. No constructor or ordinary owner-bond price argument. Replace public confirmation `--confirm-snapshot` with `--confirm-book` for quote-sensitive configure/set-pricing operations: it equals the selected load book or the computed next book, respectively. Other operations retain the existing chain/proxy/purpose/signer and immutable-manifest/journal checks without a current-book confirmation. No additional public confirmation flag is introduced. This plan never executes broadcast. Default remains read-only, synthetic inputs loopback-only. Fresh setters need no old book to initialize.
  - Prepare and export generated ABI bindings from actual renamed artifacts; update bundle traversal for all referenced manifests/intents/completions/books, preserving bytes. `issuedHistory` and retained rows require authentic prior intent/canonical receipt, not merely an internally consistent uploaded number. Full configured SY census starts at authenticated deployment, so a B-only scan cannot hide previously configured A originals. Source signature/member validation and untouched historical archives remain intact.
  - Journal recovery: old A receipts remain checkable after B and even after an authorized B replacement; unexpected replacement C fails current-record verification. Existing journal domain cannot be rebased onto B. Reject stale unmined A before a send, but let the on-chain expected-book comparison protect races after preflight. A confirmed A load missing its checkpoint is reconciled before any fresh nonce. No duplicate funding, issuance or owner-bond purchase.
  - Preserve both donation-specific operation-ID preimages in Scope rather than replacing them with the default formula. Make owner-bond/activation planning and verification bypass `requirePrepared` only for the authenticated no-entitlement/no-issuance case described in Scope; no setter, empty preparation or quote getter is a prerequisite.
  - References: `S/schema.ts:140-209`; `S/preparation.ts:35-119,166-172`; `S/quotes.ts:42-110`; `S/payloads.ts:40-64,92-125,210-215`; `S/execution-domain.ts:19-60,64-112`; `S/execution-plan.ts:15-100`; `S/execution-state.ts:25-129,394-495`; `S/execution.ts:26-62,65-185`; `S/journal.ts:21-101`; `S/claimed-sy.ts:12-18,70-129`; `S/cli.ts:16-74,137-185`. Use the generated ABI, not hand-copied stale selectors.
  - Acceptance criteria: deterministic v2 preparation; no arbitrary output credit accepted on-chain; row-specific A/B verification; legitimate B-config/A-issuance works; wrong books/domains/documents/receipts and unexpected replacements fail. Every active code/fixture/exposure producer uses stable NFT IDs and no live pricing capture assertion remains.
  - Happy QA: `bun test --timeout 15000 ./scripts/recovery/dtf-migration/preparation.test.ts ./scripts/recovery/dtf-migration/execution.test.ts ./scripts/recovery/dtf-migration/nft-contributions.test.ts ./scripts/recovery/dtf-migration/remaining-claimed-sy.test.ts ./scripts/recovery/dtf-migration/claimed-sy-state.test.ts ./scripts/recovery/dtf-migration/claimed-sy-witness.test.ts`; add retained A/new B, same-recipient B/A, same-block A/B completion, unset-pricing/no-preparation owner-bond/activation, and two distinct donation IDs with identical calldata. Assert their approval/donation IDs differ by the exact existing preimages and each same-ID resume sends nothing twice. Run the task 13 strict TypeScript command on the changed operator. Evidence: `E/task-7/`.
  - Failure QA: the same suites must reject tampered encoded book/id/input doc, wrong chain/proxy/version, omitted old SY origin, forged accepted/completion reference, duplicate member or economic origin, stale unsent A, unknown replacement C, altered A issuance principal and missing issuance history. Change a historical intent's `domainHash` and recompute all surrounding file/manifest/completion-reference hashes without changing its original execution/preparation/journal domain: rejection must occur before signing or nonce allocation. Independently tamper same-block transaction/log order or event contents and reject rather than read B as A. Verify no signer/nonce changes on rejection and exact signed-intent equality. Unit transport fixtures test parser/reconciler branches; task 10 supplies real-chain proof. Evidence: `E/task-7/mixed-record-negatives.log`.
  - Commit: N. If later authorized, combine ABI-dependent changes with the green contract/operator increment; suggested subject `fix(migration): reconcile mixed pricing records without repricing`.

- [x] 16. Carry authenticated donor evidence through bundles.
  - Recommended task executor category: deep-high. One transport contract spans authority input validation, bundle traversal and portable materialization.
  - Dependencies: 7. Wave 3; blocks 10. Discovered during the owner-corrected run from `E/task-10/funding-blocker.json` and current bundle/schema source.
  - Allowed writes: `S/bundle.ts`, `S/bundle-files.ts`, `S/bundle-materialize.ts`, narrow related `S/schema.ts`/CLI authority-input consumers if required, existing `S/bundle.test.ts`, and `E/task-16/`. Task 7 must finish its shared operator work first. Do not edit historical authority bytes, transfer CSVs, configured compensation data or unrelated files.
  - Work: carry the already retained DTF transfer/holdings evidence as an explicitly declared, hash/size/provenance-bound rehearsal funding reference. Preserve every one of the 22 existing authority roles and their exact source bytes. Use the existing content-addressed bundle and mapping machinery; do not introduce a separate provenance system, hidden filesystem fallback, unchecked extra file, financial eligibility rule or public funding approval. A schema extension must reject malformed/unbound references and keep existing admitted inputs explicitly compatible.
  - The source lead is `E/task-10/funding-blocker.json` `outsideBundleEvidence`, which names the retained task-2 `transfers.csv` and its recorded hash. This is a source lead, not permission to select a financial allocation. Task 10 still performs pinned balance checks, exclusions, deterministic selection and an actual local-fork transfer.
  - Acceptance criteria: export, relocate and load the declared raw evidence from two fresh bundle locations without native-path access; all 22 authority roles remain intact. Reject a byte change, missing declared source, unreferenced added source, forged identity and wrong-purpose use. No live transaction or donor balance is invented by this task.
  - Happy QA: `bun test --timeout 15000 ./scripts/recovery/dtf-migration/bundle.test.ts`, strict TypeScript on affected operator files, and the real CLI `bundle-export`/materialization path with the retained source. Record exact argv, source hashes, exits and byte comparisons under `E/task-16/owner-correction-20261115/`.
  - Failure QA: exercise the named corruptions against isolated copies, assert controlled rejection before nonce allocation/signing, and show the original authority/CSV bytes remain unchanged. A new passing wrapper around an unreferenced source does not pass this gate.
  - Commit: N.

- [x] 8. Deliver substantive adversarial fixtures and invariants.
  - Recommended task executor category: deep-low. Reuse and extend the real test architecture with independently observable assertions.
  - Dependencies: 4, 6. Wave 3; blocks 10 and 13.
  - Closes: GAP-10, GAP-3, GAP-4.
  - Allowed writes: new `M/TestBase_UniswapV4DetfMigration_Adversarial.sol`; existing T hostile/administration/surface/owner-callback cases, T and K invariant handlers/suites and minimal shared fixture factoring. Do not subclass/patch the SUT.
  - Work: extract reusable hostile actor/callback setup and before/after custody, credit, supply, funding/gons and selector assertions from the existing real fixture and hostile suites into the named base. At least two substantive suites must use its shared setup/assertions. Keep real registry deployment and external hostile actors; no empty inheritance alias. Use successful-action counters in stateful handlers to prove set A/B, configuration, independent issuance, owner purchase, activation, surrender, reward and harvest paths actually occur.
  - Add invariants for stable originals across pricing edits, no configuration mutation on set, preserved immutable issuance on reload, expected-book rollback and no restoration after cut. Retain P's entire invariant set and actual 333/334/334 residue example, full-original proportional NFT credit, zero issuance on load, separate 90-day clocks, prolonged Stage 1 principal/reward policy, fee/creator accrual preservation and ordinary-family isolation. Repricing only changes predictions/new loads, never old credit or mint supply.
  - Cover A0, I1-I3, J1-J3, K1, E6 where applicable, N1, source spoofing, cross-representation double credit, claim/surrender races, activation reentrancy and whole-batch failure. Cite a concrete reason for an inapplicable inherited catalog case; do not waive a source category. Every test must state the observable failure it would catch and use a distinct oracle, not copied prose or a literal selector inventory.
  - References: P:218,550-608; `M/TestBase_UniswapV4DetfMigration.sol:61-100`; `T/MigrationHostileContribution.t.sol`, `T/MigrationOwnerBondCallbacks.t.sol`, `T/MigrationSurface.t.sol`, `T/invariant/MigrationNativeInvariant.t.sol`, `K/invariant/MigrationLegacyInvariant.t.sol`, `K/invariant/MigrationSourceUnitsInvariant.t.sol` (read before editing); review PRD:75-81; canonical indexedex-testing and crane-testing skills.
  - Acceptance criteria: named reusable base has real shared behavior and actual consumers; old and new invariants have successful-action witnesses; callback failures roll back all affected domains; no weakened/skipped old tests.
  - Happy QA: `python3 scripts/forge-artifacts.py test "$M/TestBase_UniswapV4DetfMigration_Adversarial.sol" --test-root "$T/MigrationHostileContribution.t.sol" --test-root "$T/MigrationOwnerBondCallbacks.t.sol" --test-root "$T/MigrationSurface.t.sol" --test-root "$T/invariant" -- -vv`; save action counts and the invariant seed/config with results under `E/task-8/`.
  - Failure QA: run the same actual proxy hostile suites with their malicious callback, booked-inventory/pretransfer, source spoofing and failed-child-funding cases; require exact errors and unchanged custody/credit/supply/gons/cuts. Exercise an unauthorized pricing update during a callback and stale-book configuration in the stateful handler. Evidence: `E/task-8/hostile-rollback.log`. A handler that never reaches successful issuance/activation is not a passing invariant witness.
  - Commit: N. If later authorized, `test(migration): share adversarial setup and preserve pricing invariants`.

- [x] 9. Author substantive surrender and package evidence records.
  - Recommended task executor category: writing. The missing records must explain observed contracts and source facts.
  - Dependencies: 2, 3, 4, 6. Wave 3; blocks 14.
  - Closes: GAP-7, GAP-8, GAP-10.
  - Allowed writes: new `D/surrender-spec.md`, new `D/package-evidence.md`, `E/task-9/`; update existing source-index links only with the task 3 owner.
  - Work: surrender spec documents each source's exact configured-wallet/Stage2 entry, arguments, unit equation, live remaining-unit read, expected custody/control transition, source and economic identity, consumed/remainder accounting, rounding, zero-credit rejection, callbacks, errors, atomic rollback and recovery condition. Include NFT 3's two originals, earlier reserved-role conclusion, complete/remainder claimed SY and cross-representation exclusion. It is a description of actual implemented behavior with witnesses, not a new source-admission framework.
  - Package evidence documents real registry/CREATE3 deployment, explicit owner/current/pending/former roles, name-derived artifacts/salts, actual facet/interface/cut declarations, real children, bootstrap receipts, external capital versus reserve self-mint, donation/refund inventories, zero issuance on configuration, paid first ordinary bond, funded compensation supply/gons and postactivation retained routes. Include the new setter/expected-book selectors and lack of restoration paths. Bind every state/receipt to a source fingerprint.
  - References: P:125-150,188-222,303-421,453,474,495-516; task 3 source indexes, task 4 rebuilt proxy census/vectors, task 6 source conservation receipts; `M/UniswapV4DetfMigrationRepo.sol:82-92`; `M/UniswapV4DetfMigrationFacet.sol:8-40` before rename; component factory:15-20 and package factory:18-55.
  - Acceptance criteria: both named files are substantive and link all categories and actual controls; no empty placeholders, duplicate acceptance catalog or claim that documentation alone closes a gate.
  - Happy QA: agent `read` both complete new files and their cited `E/task-4/proxy-census.json`, `E/task-6/source-results.json` and raw task 3 observations. Compare each claimed source/unit and selector against its actual witness. Record result at `E/task-9/evidence-review.md`; reuse the exact successful commands from tasks 4/6 instead of repeating unchanged green checks.
  - Failure QA: run `tool.grep({pattern:"11 selectors|12 selectors|no price setter|captureMigrationSnapshot|TODO|TBD",path:["docs/incidents/2026-09-16-dtf-recovery/migration/surrender-spec.md","docs/incidents/2026-09-16-dtf-recovery/migration/package-evidence.md"],context:2})`. Inspect any match and all referenced artifact paths with the read tool. An unsupported claim, stale active selector count or missing artifact fails the document task. Save `E/task-9/reference-failures.md`; this is evidence review, not a prose test.
  - Commit: N. If later authorized, `docs(migration): document verified surrender and package behavior`.

- [~] 10. Rehearse mixed pricing and both NFT-three bonds.
  - Bounded-stop gap: the original four-hour checkpoint expired at 2026-11-15T18:55:25.715Z without complete A/B recovery, same-block replacement, unset-pricing activation, NFT 3 dual-bond/rollback and post-activation lifecycle evidence. See `E/task-10/owner-correction-20261115/checkpoint-bound-observation.json`; cleanup and the final incomplete claim preserve the last run. This row is closed unmet, not passed, and is not re-queued in this run.
  - Current readiness sequencing: issuance, empty-census and prepared-census production repairs are independently confirmed, and the corrected fixture snapshot reports 336 passing tests. The remaining fixture-only review may run concurrently with real Anvil QA once the rehearsal executor confirms that fixture is outside its runtime imports. This supersedes earlier sequential release wording for this final fixture check only. All runtime inputs stay frozen; task-10 acceptance still requires the combined independent unit/CLI verdict and independent real-lifecycle verdict. The original checkpoint time bound remains unchanged.
  - Blocking fixture adaptation after A1: `E/task-12/mixed-fixture.ts` keys its prepared-census response with the obsolete suffix-derived topic list. The integration executor may replace only that response-key construction with the shared configuration-topic selector, retaining all response rows, omission assertions and the 15-second test limit. Preserve the failed 333-pass/3-fail run, rerun the affected full suite and operator types, and obtain independent failure classification and combined confirmation. The isolated timeout pass alone is not acceptance evidence.
  - Prepared-census counterpart A1 is admitted in this checkpoint after independent source and authentic deployment-log review: `S/execution-state.ts` also applies suffix classification across the prepared deployment-to-latest range, so mandatory initialization cannot match a compensation row and blocks prepared verify/activate. The census executor temporarily owns domain/state implementations and their two tests to share the existing explicit compensation classification, retain complete origin coverage and authentication, and prove this exact prepared path. The transaction-local configure receipt branch is unchanged. The completed 305-test snapshot is preserved; one sole-writer fix and affected full tests/types precede independent combined acceptance and the existing parent readiness marker.
  - Empty-census repair in this same checkpoint: `E/task-10/owner-correction-20261115/operator-empty-census-blocker.json` records mandatory real deployment `ThresholdsConfigured` being mistaken for compensation configuration. The prior census executor owns only `S/execution-domain.ts` and `S/execution-domain.test.ts` to classify actual compensation history explicitly while retaining complete current census checks and the authenticated historical boundary. These files are disjoint from the issuance decoder repair. Both writers finish before one affected shared operator/typecheck run and independent combined confirmation; the parent-owned issuance readiness marker gates both fixes.
  - Further blocking decoder repair in this same checkpoint: `E/task-10/owner-correction-20261115/operator-issuance-event-blocker.json` retains a successful real issuance whose bond-child ERC-721 `Transfer` was incorrectly decoded with an ERC-20 event ABI. The operator repair executor owns only `S/execution-state.ts` and `S/execution-state.test.ts` to select and verify the required event correctly, preserve malformed-required-event rejection, and cover the actual mixed receipt. Confirm the affected full operator/type checks independently before releasing the main rehearsal. The separate unset-pricing run may finish against its frozen snapshot; historical signed evidence remains immutable.
  - Recommended task executor category: deep-low. Extend the existing operator's real local lifecycle and receipt witnesses.
  - Dependencies: 7, 8, 16. Wave 4; blocks 12, 13 and 14.
  - Closes: GAP-3, GAP-4, GAP-5, GAP-8, GAP-10.
  - Blocking operator repairs admitted during the renewed checkpoint: the real successful setter receipt in `E/task-10/owner-correction-20261115/operator-setter-blocker.json` emits the expected book ID, but operator event decoding lacks the separately declared pricing event. A scoped operator executor owns `S/execution-domain.ts`, `S/execution-state.ts`, their existing domain/state tests, and the narrow `S/rehearsal-data.ts` producer binding for the generated pricing ABI in new manifests. Historical signed domains and receipts stay unchanged; the repaired producer starts a new execution. A separate executor owns `S/execution.ts` and `S/execution.test.ts` to reproduce and repair missing `--fault-after-mined` support for actual configuration operations while preserving synthetic-local enforcement and nonce/receipt recovery. These fixes block task-10 acceptance and join this checkpoint; no other contract, economic rule or validation is waived. The rehearsal writer pauses source changes until the repairs are integrated and independently confirmed.
  - Allowed writes: `S/rehearse.ts`, `S/rehearsal-data.ts`, `S/rehearsal-proof.ts`, `S/rehearsal-recovery.ts`, existing per-source rehearsal modules, a narrow `S/rehearsal-nft-contributions.ts` only if the existing NFT flow needs separation, FS environment/execution consumers and `E/task-10/`. This task is the sole Wave 4 writer of `S/rehearsal-proof.ts`, including serialized integration of task 12's requested additions. Reuse `MigrationNftHolder` in K for the second-receiver negative; no second operator framework.
  - Work: build `E/task-10/authorities-input.json` from all exact existing `authorityRoles` in `S/bundle.ts:11-25`, resolving their delivered task-2 source bytes and updated P without inventing financial inputs. Export the complete authority bundle. Use the existing portable 18575 mode in a fresh task-owned checkout, so its fixed checkpoint path does not overwrite an earlier run.
  - Fix the setup conflict at `S/rehearse.ts:113-125`: it currently claims weighted NFT 3 to obtain 10,000 DTF. The positive NFT 3 witness must leave its source principal untouched before surrender. Fund synthetic setup from a separate genuinely held DTF balance: enumerate holder candidates from the authority bundle's existing DTF transfer/holdings evidence, exclude admitted source contracts, configured compensation wallets and recovery custody, sort addresses, and select the first whose pinned on-chain balance covers the exact setup budget. Record its address, balance, actual transfer receipt and exclusion from compensation. Do not mint/etch historical DTF, duplicate tokens through a snapshot reset, or pretend this local donor is an approved operational funder. If no witnessed donor covers the budget, report the missing fixture acquisition as a concrete blocker rather than consuming NFT 3 or fabricating a balance.
  - Positive lifecycle: deploy/fund/bootstrap; set A; prepare and load A rows, interrupt immediately after an actual configure transaction mines; set B through a separate owner run; resume A's original journal and recover that receipt without resend. Keep one recipient configured under A, load another under B. Issue an independent recipient under A, explicitly replace that same recipient's configuration with B, and verify B configuration plus the immutable A issuance/history. Complete a paid owner-first ordinary bond, change pricing again before activation to prove the setter remains usable, and activate while accepted records still use mixed books. Verify all removable selectors disappear and retained getter/claims/surrender work.
  - Add a same-block replacement subcase with local automining disabled: mine actual signed A configure then B full replacement of the same key in one canonical block, preserving each original execution/preparation/journal context. The independent owner action B is queued by the local race fixture; do not weaken the production operator's rule against allocating a new nonce before reconciling prior intents. Use the same valid book for both configurations to isolate ordering, with distinct complete inputs/configuration IDs. Omit A's completion checkpoint, then recover it once from its transaction-specific proof; assert no resend/new nonce, current B unchanged, and independent verification of accepted B. Tampered transaction indices, ordered logs, credits or events fail. Save `same-block-config-a-then-b.json`.
  - Add a separate real-proxy CLI scenario with `pricing: null`, `preparedManifest: null` and an authenticated empty entitlement/issuance census: fund/bootstrap, buy the genuine paid owner-first ordinary bond, resume its mined receipt, and activate without ever setting pricing or preparing quotes. Check the setter is removed, the getter still reports unset and no quote/preparation prerequisite was invoked. Before purchase activation fails; a nonempty unbound census cannot use this branch. Save `unset-pricing-owner-bond-activation.json`.
  - Add two explicit donation IDs with identical approval and donation calldata to the real funding sequence. Interrupt after the first donation mines but before its checkpoint, recover that exact operation once, and execute the second distinct donation once. Assert both distinct approval/donation operation IDs, exact receipt/balance deltas and no additional send on either ID's completed resume. Save `donation-identity-resume.json`.
  - Include exact NFT 3 quantities and separate mode in preparation, replacement and exported payloads. Surrender from its authenticated original wallet once after activation; record one source custody/consumption, two distinct new bond IDs, separate component credits/principals/gons, actual creation timestamps and 90-day cliffs. Verify both bond principals separately and the aggregate supply delta, not merely bond count. Preserve later delayed-surrender clocks and repeated reward-only recovery for other selected source positions.
  - Negative lifecycle: A prepare -> B set -> unsent A configure rejects without nonce/custody/config mutation; a signed A transaction submitted after B reverts atomically on-chain; omitted/combined NFT 3 mode rejects before sending; unexpected C replacement, wrong-book artifact, missing A issuance history and wrong chain/proxy reject. Reuse the existing `MigrationNftHolder.rejectSecond` behavior from `K/MigrationNftLifecycle.t.sol:160-205` in a separately labeled synthetic-local receiver scenario on a distinct real Migration proxy. Transfer the actual source NFT into that explicit test receiver and configure that synthetic test wallet with genuine source units; do not label it historical original-wallet evidence. Route configure/activate through the operator, attempt surrender, prove the second callback was reached and both issuances/source custody roll back, then allow the second callback and succeed. Preserve the genuine original-wallet positive scenario independently.
  - Preserve all existing per-source, funding, owner-bond, interruption, ordinary-deposit, recovery and portability witnesses; no removal to make NFT 3 fit. `--fault-after-mined` extends to actual configuration methods while retaining synthetic-local-only enforcement and exact receipt subscriptions. Save raw signed intents and canonical receipt/header checks for each branch.
  - References: P:67-119,527-546,575-608; `S/rehearse.ts:51-77,108-149,247-383`; `S/rehearsal-data.ts:133-186`; `S/rehearsal-chain.ts:29-75`; `S/execution.ts:112-183`; `K/MigrationNftLifecycle.t.sol:65-129,160-205`; task 7 operation table.
  - Acceptance criteria: all A/B and same-recipient scenarios pass on actual proxies; no stale load is silently repriced; no old issuance is replayed or resized; NFT 3 has one consumption and two exactly funded clocks; source funds and synthetic fixture distinctions are explicit.
  - Happy QA:
    ```bash
    bun "$S/cli.ts" bundle-export --input "$E/task-10/authorities-input.json" --output "$E/task-10/authorities-bundle"
    bun "$S/cli.ts" rehearse --bundle "$E/task-10/authorities-bundle/bundle.json" --rpc-alias robinhood_mainnet_alchemy --fork-block 108944663 --port 18575 --checkpoint .omo-runtime/dtf-migration-portable/checkpoints --evidence "$E/task-10/runtime"
    ```
    The rehearsal emits its exact timestamped child directory in the final JSON; save that returned path in `E/task-10/rehearsal-location.json`, not a guessed timestamp. Required records there: `mixed-pricing.json`, `same-recipient-config-b-issuance-a.json`, `same-block-config-a-then-b.json`, `unset-pricing-owner-bond-activation.json`, `donation-identity-resume.json`, `nft-three-two-bonds.json`, `nft-three-rollback.json`, and existing lifecycle/recovery/receipt records.
  - Failure QA: the same invocation must execute the negative scenarios above and assert controlled errors/status-0 receipts plus unchanged economic state. Fault recovery must show the original transaction hash, nonce and one canonical completion, not a second successful send. The second-bond callback trace and two-bond rollback are required in `nft-three-rollback.json`; a first-bond failure is insufficient.
  - Commit: N. If later authorized, `test(migration): rehearse mixed books and NFT three end to end`.

- [x] 11. Measure admitted batches and signed gas envelopes.
  - Recommended task executor category: deep-low. Select limits from authenticated policy and actual measured operations.
  - Dependencies: 2, 4, 6, 7. Wave 4; blocks 12, 13 and 14.
  - Closes: GAP-9.
  - Allowed writes: delivered `D/resumed-integration/verify-bounded-deployments.ts`, existing `FS/MigrationDeploymentGasResumedQA.s.sol`, existing T/K deployment/recovery gas suites, new `T/MigrationOperationGas.t.sol` if needed for loader/issuance measurements, `S/execution.ts`, `S/execution-schema.ts` only for measured signing/resume constraints, and `E/task-11/`. After task 7's baseline, this task is the sole Wave 4 writer of `S/execution.test.ts` for its gas cases and serialized integration of task 12's requested provenance/portability cases.
  - Work: preserve two-step `prepareSyChildren`/`deployVault`. Retain the historical signed 32m receipts (19,746,568/19,595,700 preparation and 29,905,302/29,344,006 publication) as their original-source evidence; do not substitute the obsolete 44,353,454 figure. Renamed artifacts/new code require a new signed-envelope witness for two distinct owners/parents.
  - Recover the recorded target `getMaxTxGasLimit() == 32000000` proof and applicable block/transaction gas policy, checking exact source/chain/block. For loading and independent issuance, test 1, 8, 16, 32 and 64 selected records at both small and large unrelated populations; also test recipient-original-array sizes 1, 8, 16, 32 and 64. Never split a full economic original or merge originals to meet gas. For recovery, respect the existing bound of at most eight weighted claim stages or one other typed step; measure 1 and 8 where admitted and prove selected work does not scale with total custody.
  - Determine the largest **tested** operational batch shape whose estimated and signed gas envelope fits the applicable minimum of authenticated transaction/block limits. Record that shape and all measured sample results; it is not a promise for arbitrary calldata. A larger shape fails preflight before signing and is regrouped only at complete-record boundaries. Existing one-row operator operations remain valid if they are the measured admitted shape.
  - Only if measurement exposes an actual signing/resume mismatch, apply the same derived applicable ceiling to simulation, estimation, signed `gasLimit` and `validateIntent`; reject an estimate above the ceiling and bound the existing 3/2 safety envelope at that ceiling. Do not create a mutable gas registry or assume every network/stage has a universal 32m limit. Persist the evidence binding for the selected target policy in the execution source manifest; signed resume validation cannot accept an over-limit old intent.
  - Extend the retained helper to record admitted nondeployment samples by reusing existing deployment/fixture/operator code, not a new broadcaster. Record transaction input size, selected/unrelated population, estimate, signed limit, actual gasUsed, canonical receipt and expected result for every sample. Local permissive 100m block settings are not proof of target feasibility.
  - References: P:525,542,546; prior conformance bundle:33-34; `S/execution.ts:26-30,136-168`; `S/execution-schema.ts:4-6`; `R/resumed-integration/verify-bounded-deployments.ts:18-100`; `R/resumed-integration/bounded-remediation-20261113/constrained-receipts.json`; review PRD:84-91.
  - Acceptance criteria: two new bounded constructions and admitted loading/issuance/recovery shapes have actual signed/mined witnesses; measured limits and exact policy provenance are recorded; oversized and tampered-resume requests fail before economic changes.
  - Happy QA:
    ```bash
    python3 scripts/forge-artifacts.py test "$M/UniswapV4DetfMigrationAllocationTarget.sol" --test-root "$T/MigrationOperationGas.t.sol" --test-root "$T/MigrationDeploymentGas.t.sol" -- -vv
    bun "$D/resumed-integration/verify-bounded-deployments.ts" "$E/task-11/signed-envelopes"
    bun test --timeout 15000 ./scripts/recovery/dtf-migration/execution.test.ts
    ```
    Evidence: `E/task-11/signed-envelopes/{transactions.json,constrained-receipts.json,operation-gas.json,cleanup.json}` and `E/task-11/batch-limits.md`.
  - Failure QA: run actual boundary-above-limit simulation and an over-limit saved-intent negative; assert no signing/sending or nonce movement for rejected preflight, and full rollback for a deliberately underfunded local gas transaction. Preserve the two-deployment helper's parent/owner count and 32m signed-transaction assertions. Evidence: `E/task-11/gas-negatives.json`.
  - Commit: N. If later authorized, `test(migration): verify target gas for deployment and batches`; include a signing fix only when its measured mismatch is recorded.

- [~] 12. Preserve portable bundles and exact journal provenance.
  - Bounded-stop gap: blocked by 10. Passing synthetic relocation and raw-byte proofs remain recorded, but required complete real lifecycle portability is not established.
  - Recommended task executor category: deep-low. Prove existing bundle relocation with the new per-record references and immutable histories.
  - Dependencies: 7, 10, 11. Wave 4; blocks 13 and 14.
  - Closes: GAP-4, GAP-7, GAP-8.
  - Allowed writes: `S/bundle.test.ts`, `S/preparation.test.ts`, `S/rehearsal-portable.ts` and `E/task-12/`. Do not write `S/rehearsal-proof.ts` or `S/execution.test.ts`: task 10 and task 11 respectively integrate this task's requested cases, one writer at a time, before task 12 QA. Fixes in existing bundle readers/materializers coordinate through task 7.
  - Work: exercise export/materialize/rehydrate of a complete mixed A/B preparation and same-recipient B-config/A-issuance history. Include all transitive original execution manifests, journal domains, prepared manifests, books, input documents, intents and completion references as raw bytes, with exact size/hash and no cycles. Recompute both historical configure and issuance domain hashes from their own complete contexts after relocation. A fresh materialized execution may use new filesystem paths for validated artifacts; historical preimages and live signed journals retain their immutable original domain and location. Do not make path relocation a way to rebind a signature or replace a prior accepted row.
  - Ensure default validate/verify on a relocated bundle remains read-only and does not call today's price for retained A. Wrong network/purpose, unknown facet, altered referenced intent/receipt, duplicate/missing file and v1-on-v2 execution reject. Restore no old capture aliases. Existing current-owner purchase receipts and donation checkpoints remain reconcilable and are never repeated.
  - References: `S/bundle.ts:11-35,62-149`; `S/preparation.ts:35-43,112-119,166-172`; `S/execution-domain.ts:19-60`; `S/journal.ts:24-94`; `S/rehearse.ts:247-315`; P:527-536; task 7 mixed-record format.
  - Acceptance criteria: byte-identical books/inputs and exact accepted configuration/issuance facts survive relocation into two distinct fresh directories; copied/moved live journal rejection stays effective; transitive references cannot be silently dropped.
  - Happy QA: `bun test --timeout 15000 ./scripts/recovery/dtf-migration/bundle.test.ts ./scripts/recovery/dtf-migration/preparation.test.ts ./scripts/recovery/dtf-migration/execution.test.ts`; task 10's real portable mode consumes these same routines and produces current-chain proof. Store deterministic fixture outputs and byte-comparison report in `E/task-12/portable-integrity.json`.
  - Failure QA: those suites mutate one byte in A's book, a B input, A issuance intent and one receipt independently; also alter a historical `domainHash` while recomputing surrounding FileRef hashes, omit its original execution/journal reference, omit an old configured SY row, introduce a cyclic reference and relocate an active checkpoint. Each rejects before signing/nonce allocation without replacing the accepted files. Save `E/task-12/tamper-rejections.log`; do not weaken bundle equality to permit a passing resume.
  - Commit: N. If later authorized, `test(migration): preserve mixed-book bundle and journal integrity`.

- [~] 13. Run final-tree contract and operator verification.
  - Bounded-stop gap: blocked by 10 and 12. Prior Forge/fork results and the confirmed 336-test operator gate remain qualified evidence, not this complete final-tree acceptance.
  - Recommended task executor category: deep-low. Execute and interpret the repository's mandatory full checks on the resulting tree.
  - Dependencies: 8, 10, 11, 12. Wave 5; blocks 14 and 15.
  - Closes: GAP-10 and verifies GAP-1 through GAP-9 on the final source.
  - Allowed writes: `E/task-13/` and test-generated local artifacts; cause fixes only in the responsible earlier task's allowed scope, followed by affected reruns. Never suppress or weaken a failing test.
  - Work: capture exact final file-content hashes, dependency/compiler/runtime versions and commands. Run full production build, all hermetic tests, all migration pinned forks and all operator tests/typechecking, plus explicit ordinary weighted DETF/common bond-staking coverage. Reuse task 10's complete rehearsal and task 11's signed receipts only if no affecting source changed afterward; otherwise rerun the affected real surface once. Full hermetic checks include ordinary suites; explicitly record their test summaries rather than claiming they were covered from a filename.
  - References: P:672-725; `CLAUDE.md` items 7-10; `.github/ASSISTANT_TESTS.md:5-25`; retained `record-verification.ts:13-51`; tasks 4-12 source/evidence manifests.
  - Acceptance criteria: actual exit 0 for required build/type/test commands; real tests selected and nonzero case counts; all changed behavior/rehearsal/gas evidence binds the final tree. Independently establish any pre-existing failure; an in-scope source/custody/quote/payout failure remains incomplete. No stale artifact, no unrelated forced cleanup, no broad archive retry.
  - Happy QA: use the delivered recorder and preserve its full command output:
    ```bash
    bun "$D/resumed-integration/record-verification.ts" hermetic "$E/task-13/hermetic"
    bun "$D/resumed-integration/record-verification.ts" fork "$E/task-13/fork"
    bun "$D/resumed-integration/record-verification.ts" operator "$E/task-13/operator"
    ```
    These modes must retain their observed commands: `forge build --use solar`; full `forge test --use solar -vv --no-match-path '**/fork/**' --no-match-contract Fork`; the fork artifact-helper run against all K; and the following operator commands:
    ```bash
    bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node scripts/recovery/dtf-migration/*.ts
    bun test --timeout 15000 ./scripts/recovery/dtf-migration/*.test.ts
    bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node "$D/resumed-integration/record-verification.ts" "$D/resumed-integration/verify-bounded-deployments.ts"
    ```
    The full hermetic log must include `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/` and `test/foundry/spec/vaults/detf/common/`; if the runner's selection excludes either, execute its explicit P section 10 `--match-path` command and report the gap. Evidence: task-13 `environment.json`, raw numbered logs and `results.json` for each mode.
  - Failure QA: recorder exits nonzero and `completed:false` on any command failure; inspect each raw failure, classify by source, repair caused failures in scope and keep the original failed attempt. Fail if zero selected cases, missing fork capability, stale artifacts or a changed source hash is presented as a passing result. Evidence: `E/task-13/failure-dispositions.md`, with no manufactured successful stdout.
  - Commit: N. If later authorized, verification-only records accompany the verified implementation increment; no code commit solely to force a green status.

- [~] 14. Complete traceability and reconcile current operator documentation.
  - Bounded-stop gap: blocked by 10, 12 and 13. Complete observed-behavior traceability and a full conformance sentence are unavailable.
  - Recommended task executor category: writing. Bind the entire amended original specification to observed final results.
  - Dependencies: 1, 9, 10, 11, 12, 13. Wave 5; blocks 15.
  - Closes: GAP-7, GAP-8, GAP-9, GAP-10.
  - Allowed writes: `D/operator-runbook.md`, `D/quote-evidence.md`, `D/verification.md`, source/recovery/surrender/package records for final links, applicable existing migration coverage records, and `E/task-14/`. Do not alter frozen inputs, original allocations or historical raw records.
  - Work: record actual manual-book tuple/hash, integer units, four branch domains, explicit set-pricing and expected-book loading, replacement/retained A/B workflows, same-recipient B/A history, NFT 3, claimed-SY source proofs, paid owner purchase and activation removal. Distinguish supported manual model evidence from any unapproved live production reserve or financial dataset. Update all stale active capture/blocked-route descriptions, artifact names and selector counts; retain dated historical claims as superseded.
  - Map **every** row in the acceptance tables below, every original task and final-verifier obligation, all 13 arithmetic examples, each invariant and owner clarification 1.1-1.10 to exact current command/case/receipt/file hashes. Reuse old exact-matching evidence with clear dates; changed behavior points to fresh task 4-13 evidence. Include complete unit/source/custody, funding/gons, fee/creator reward gating, registry disabled behavior and no-restoration witnesses. Any unresolved actual gate forbids a completion sentence.
  - Explain that generic stage receipts and `bounded-rehearsal-complete` do not certify the entire implementation. Do not add a new status machine or close `fullTask9` by changing a literal. The final verification record may certify full task 9 only when all mapped behaviors actually passed; historical and bounded status outputs remain qualified.
  - References: P:444-548,550-725; complete review PRD F1-F6 and withdrawn findings; `R/verification.md`, `R/recovery-route-disposition.md:39-41` as historical reports; tasks 1-13 actual outputs. All acceptance IDs in the tables below are inherited, not new policy.
  - Acceptance criteria: reader can reproduce each claimed behavior from its named source and command; all required named records and helper programs are linked; no missing categories, implied financial approval, stale-source claim or undocumented exclusion.
  - Happy QA: agent `read` the complete current `D/verification.md`, runbook, quote evidence and task-13 `results.json` files, then follow each acceptance/evidence link. Record `E/task-14/traceability-review.md`, with each MIG-P/E/MIG-AC/example/invariant assigned an actual witness.
  - Failure QA: inspect every nonzero/unrun command and unresolved source row before marking completion. Run `tool.grep({pattern:"pending|blocked|unsupported|fullTask9|eleven|twelve|captureMigrationSnapshot|no price setter",path:"docs/incidents/2026-09-16-dtf-recovery/migration",glob:"*.md",context:2})` and classify each current versus historical occurrence. An active unclosed required behavior fails; a documented external deployment/financial authorization boundary is not a missing implementation. Evidence: `E/task-14/current-versus-historical.md`.
  - Commit: N. If later authorized, `docs(migration): record complete amended conformance evidence`.

- [~] 15. Audit complete delivery and preserve unrelated workspace work.
  - Bounded-stop gap: blocked by 13 and 14. The final wave must inventory the bounded partial delivery and all final reports without representing this full-conformance boundary as passed.
  - Recommended task executor category: quick. The decision is a deterministic file/evidence comparison after all work is complete.
  - Dependencies: 2, 13, 14. Wave 5; blocks F1-F4.
  - Closes: GAP-7, GAP-10.
  - Allowed writes: `E/task-15/`, final inventory/disposition updates and missing **task-owned** deliverables already authorized by earlier tasks. Do not alter unrelated files, dependencies, historical archives or live journals.
  - Work: reconcile the task 2 origin inventory against final D and all task-created source/script/test/doc/evidence paths, including both helper programs and new surrender/package/adversarial files. Record every rename and every task artifact, including untracked files and prior failed attempts. Any proposed exclusion must be explicit and authorized; absent that authorization, include the in-scope file. Preserve divergent historical bytes and unrelated user work. If commits are separately authorized, inspect the exact staged path list and deliver the whole authorized change set through verified linear increments; never blanket-stage, amend or force-push.
  - Complete the inventory before its own final receipt is emitted. The inventory and final receipt list themselves as generated audit records without attempting a recursive self-hash; all other files have raw hashes. This explicit self-reference exception is not an artifact exclusion.
  - References: P:453,474,536,546,548,718-725; prior conformance bundle:21,29-30,38-39; task 2 inventory and task 13 source/results manifests.
  - Acceptance criteria: zero unresolved missing/divergent task-owned files at the pre-verifier delivery boundary, no unreported exclusions, all final behavior records match delivered sources, unrelated dirty/untracked content unchanged. The final wave adds F1-F4 reports to delivery after they exist. No extra user acknowledgement is required to close this task or report the verified implementation complete; separate execution, commit and public-action authorizations remain in force. Native plan approval and later execution evidence are never conflated.
  - Happy QA: `bun "$D/resumed-integration/record-verification.ts" delivery "$E/task-2/inventory/inventory.json" "$E/task-15/delivery"`; compare actual source hashes and final file set, producing `E/task-15/delivery/{inventory.json,delivery.json}`. After loading git-master, use read-only `git status --short --untracked-files=all` and `git diff --stat` to reconcile touched versus unrelated work. Do not create a commit without explicit authorization.
  - Failure QA: run delivery against a temporary copy with one omitted helper and one altered evidence file; it must return nonzero and name both while leaving the real tree untouched. Check the real final report has no unresolved omission rows. Evidence: `E/task-15/negative-delivery.log`.
  - Commit: N. If later authorized, commit only the inspected complete task-owned changes; otherwise hand over the exact files and their checks without claiming a commit.

## Final verification wave
> Bounded execution disposition: tasks 10 and 12-15 are known unmet rows. Under the explicitly requested ulw-execute continuation rules, F1-F4 still review the verified delivered scope and report those gaps; the known gaps alone do not fail a final-wave row, authorize re-queuing them, or permit a full-success claim. Unverified rehearsal work remains isolated and explicitly identified. Final bookkeeping must create a usable partial-delivery inventory and include all four reports even though task 15's full-conformance inventory is unavailable; it must not repeat the earlier missing-input closeout.
> Runs in parallel after ALL todos. ALL must APPROVE. After their reports exist, perform the additive delivery closeout below and report the result without an extra user-acknowledgement gate. Separate execution and public-action authorization still apply.
- [x] F1. Plan compliance audit
  - Bounded verdict: independently confirmed for truthful partial-delivery compliance only; full goal remains unmet. See `E/final/owner-correction-20261115/F1-compliance.md` and the renewed F1 verdict.
  - Recommended task executor category: deep-high.
  - Depends on: 15. Read P as amended, this complete plan, both hyperplan bundles and `D/verification.md`. Check all MIG-P01-P15, E1-E5, 53 acceptance IDs, original tasks/F rows, 13 examples, invariants and owner clarifications against actual witnesses.
  - Execute agent reads of `E/task-14/traceability-review.md` and `E/task-15/delivery/delivery.json`; follow every unresolved or changed-behavior row. Positive: all mapped obligations hold. Negative: any required source/category, source conservation, manual quote or payout gate remains unsupported. Report APPROVE only with no such gap at `E/final/F1-compliance.md`.
- [x] F2. Code quality review
  - Bounded verdict: independently confirmed for the stated verified scope and isolated WIP boundary only; no full-conformance or strict-delivery pass. See `E/final/owner-correction-20261115/F2-quality.md`.
  - Recommended task executor category: deep-high.
  - Depends on: 15. Review exact delivered source changes and task-13 diagnostics; source-only read of new ABI/tuple, hash preimages, canonical math reuse, raw versus rated branches, all loader guards, stable original collisions, real selector removal, operator per-record proofs and authority boundaries.
  - Execute read-only `git diff --check` and inspect the task-owned diff after loading git-master, plus actual final TypeScript/Forge outputs. Positive: minimal coherent change and no hidden alternate price/authority path. Negative: a stale overload, output alias, unchecked loader, fresh-price re-quote of old records, B/A comparison bug or dropped source authentication is a blocker. Report at `E/final/F2-quality.md`; no implementation by the reviewer.
- [x] F3. Real manual QA
  - Bounded verdict: independently confirmed for accurate retained real-evidence and cleanup claims only; the full real lifecycle remains unaccepted. See `E/final/owner-correction-20261115/F3-real-qa.md`.
  - Recommended task executor category: deep-low.
  - Depends on: 15. Inspect the actual task-10 real-chain records, task-11 signed gas envelopes and task-13 suite outputs. Reconcile raw setter/configuration/issuance/activation/surrender receipts and on-chain state captured there, including NFT 3's second callback rollback and two funded bonds.
  - The exact real-surface command is task 10's `cli.ts rehearse` invocation. Reuse its final-tree result; rerun only if source changed or evidence is incomplete. Positive: A/B resume, B-config/A-issuance, correct owner-first activation and source/recovery lifecycle. Negative: merely synthetic transport tests, aggregate counts, absent canonical receipts or a first-bond-only failure cannot close this verifier. Report at `E/final/F3-real-qa.md`.
- [x] F4. Ideal-state fidelity
  - Bounded verdict: independently confirmed for truthful partial fidelity and explicit IS gaps only; full ideal state remains unmet. See `E/final/owner-correction-20261115/F4-fidelity.md`.
  - Recommended task executor category: deep-high.
  - Depends on: 15. Read each IS row and its proving scenarios below, final delivery inventory and raw receipts. Verify the full outcome for contributors, owner/operator and maintainers, not just the pricing delta.
  - Execute agent reads of `D/surrender-spec.md`, `D/package-evidence.md`, `D/quote-evidence.md`, `D/verification.md` and `E/task-15/delivery/delivery.json`; inspect strongest counter-case: the same recipient has current configuration B and immutable issuance A while other stored rows still use A at activation.
  - Positive: all seven ideal-state rows and complete task-created delivery hold. Negative: forced reload, global freshness, changed original identity, waived source category, omitted program, principal-withdrawing routine harvest or missing current-source evidence fails. Report at `E/final/F4-fidelity.md`. A real gap returns to its owning implementation task; no "complete with missing required behavior" verdict.

Final-wave delivery closeout is coordinator bookkeeping within this wave, not another task or a dependency back to task 15. After all four reports exist, run `bun "$D/resumed-integration/record-verification.ts" delivery "$E/task-15/delivery/inventory.json" "$E/final/delivery"`. Preserve the task-15 inventory and emit a new additive inventory/receipt containing raw hashes for `E/final/F1-compliance.md`, `F2-quality.md`, `F3-real-qa.md`, `F4-fidelity.md` and any other task-created final records. Check prior delivered hashes remain unchanged, every report is included and no unresolved omission remains; retain the explicit audit self-reference exception. Missing reports or changed prior bytes fail closeout. Deliver the reports and `E/final/delivery/{inventory.json,delivery.json}` together; no extra acknowledgement or product test rerun is required for this additive evidence-only step.

## Commit strategy

Planning creates no commit. Every executable task is marked `Commit: N` until the user separately authorizes commits. If authorized during execution, load git-master, use the repository's actual log convention, keep a linear series of independently buildable verified increments and include each ABI change with its callers/tests. Do not amend, rewrite history, force-push or stage unrelated work. The final delivery includes all in-scope records and helper programs; evidence is not silently excluded to make the diff smaller.

No deployment, real reserve funding, public price setting, activation, compensation execution, external role change or governance action is authorized by this document. Those require a reviewed operational dataset and separate explicit authorization. Local test fixtures are labeled synthetic and do not approve financial awards.

## Success criteria
> One row per IS row. The plan is complete only when every IS row has a delivering todo and a proving QA scenario; F4 checks the delivered behavior against these rows 1:1, and a shortfall becomes new `- [ ] N.` rows, never a note.
| IS | Delivering todo(s) | Proving QA scenario | Evidence |
| --- | --- | --- | --- |
| IS-1 | 3, 4, 6, 8, 13 | Every-source original-wallet custody/conservation and stable-origin negatives | `E/task-3/source-observations.json`, `E/task-6/source-results.json`, `E/task-13/fork/results.json` |
| IS-2 | 1, 4, 7, 13 | Canonical raw/rated/disabled/V3 differential vectors and deliberately adjusted manual values | `E/task-4/`, `D/quote-evidence.md`, `E/task-13/hermetic/results.json` |
| IS-3 | 4, 7, 8, 10 | Initial setter, post-purchase setter, actual complete cut and CLI owner-bond/activation with unset pricing and no preparation | `E/task-4/proxy-census.json`, task-10 `unset-pricing-owner-bond-activation.json` |
| IS-4 | 4, 6, 8, 9, 10, 13 | Real bootstrap, paid purchase, exact gons, fresh cliffs, all reward paths and ordinary regressions | `D/package-evidence.md`, task-10 bond records, task-13 full logs |
| IS-5 | 3, 6, 10, 11 | Repeated reward-only maturity cycles, typed recovery rollback and bounded external-authority dispositions | `D/recovery-route-disposition.md`, task-6/task-10 recovery receipts, `E/task-11/batch-limits.md` |
| IS-6 | 5, 7, 10, 12 | A mined resume after same-block B; own historical domains; unsent A rejection; B-config/A-issuance; distinct donation IDs; NFT 3; portable proofs | task-10 `mixed-pricing.json`, `same-block-config-a-then-b.json`, `same-recipient-config-b-issuance-a.json`, `donation-identity-resume.json`, `nft-three-two-bonds.json`, `E/task-12/portable-integrity.json` |
| IS-7 | 1, 2, 9, 13, 14, 15; final-wave closeout | Complete amended traceability and no omitted task-owned files, including F1-F4 reports | `D/verification.md`, `E/task-14/traceability-review.md`, `E/task-15/delivery/delivery.json`, `E/final/delivery/delivery.json` |

### Complete inherited obligation ownership

The tables allocate responsibility; a row closes only with the actual case/receipt recorded by task 14. They do not replace P's full acceptance descriptions.

| Original obligation | Remediation owner and proof |
| --- | --- |
| MIG-P01, P02 | 4/7/10: full originals on selected manual book; stored proportional credit |
| MIG-P03, P04, P05 | 3/6/8: actual remaining principal, burned/empty rejection, whole identity and cross-representation consumption |
| MIG-P06, P07 | 6/8/10: custody/issuance atomicity and fresh exactly funded clocks, including NFT 3 exception |
| MIG-P08 | 8/10/13: complete instance reward closure and preserved accrued rights |
| MIG-P09, P10 | 4/7/10: independent path, replacement, B-config/A-issuance and disjoint originals |
| MIG-P11, P12 | 4/8/10: current owner, paid purchase prerequisite and complete irreversible cut including pricing |
| MIG-P13, P14 | 4/6/10/11: funding-first operation, no new gate, bounded repeatable recovery |
| MIG-P15 | 3/6/10: every category, original wallet, actual custody and no ancestry gate |
| E1 | 3/6/9/13: exact authenticated source matrix, every source/generation and source-specific recovery |
| E2 | 6/8/10/13: configured original-wallet Stage 2 surrender and source conservation |
| E3, as amended | 4/7/10/13: supported manual models, canonical differential math and no live evaluation |
| E4 | 4/8/9/10/13: real empty-reserve donation/bootstrap and separate self-leg accounting |
| E5 | 8/10/13: all parent/child/direct/indirect payout gates and ordinary regression |
| Original tasks 1-2 | 3/4/6/9: source/custody closure and exact pricing |
| Original tasks 3-4 | 4/7/9/10: package/bootstrap/authority and separate configuration/execution |
| Original tasks 5-7 | 4/6/8/10/13: funded bonds, surrender, ordinary gates and activation |
| Original task 8 | 3/6/10/11: bounded staged recovery and repeated rewards |
| Original task 9 | 5/7/10/12/14: reproducible preparation and full resumable operator |
| Original task 10 | 8/10/11/13/14: integration, invariants, adversarial/forks, gas and final tree |
| Original F1-F4 and section 11 | 14/15 and this plan's F1-F4: complete policy, real money paths, reproducibility, delivery and authorization limits |
| Owner sections 1.1-1.5 | 1/4/6/8/10: precedence, actual surrender, original wallet, Stage2, paid owner purchase |
| Owner sections 1.6-1.8 | 3/5/6/7/10: TokenStaking, NFT 3 two originals and one conserved remainder |
| Owner section 1.9 | 3/6/10/11: iterative reward-only harvest and source-specific permanent custody |
| Owner section 1.10 | 1/4/7/10: complete manual Weighted inputs and keep-until-reloaded |
| Section 8.1 examples 1-3 | 6/8: original quote times remaining fraction, empty rejection, no partial nonlinear re-quote |
| Section 8.1 examples 4-6 | 4/6/8: 333/334/334 residue, grouping, zero component/zero-credit atomicity |
| Section 8.1 examples 7-9 | 6/8/10: no mint on load, exact issuance, separate clocks and prolonged Stage1 principal/rewards |
| Section 8.1 examples 10-11 | 8/10/13: delayed first issuance, no backdating, fee/creator rights held until activation |
| Section 8.1 examples 12-13 | 6/8/10: missing config/wrong wallet rollback and actual controlled assets |
| Section 8.2, every invariant/catalog row | 8/13: real successful-action witnesses, conservation, solvency, guards, live independence and recovery destinations |

| Acceptance ID | Remediation tasks and required witness |
| --- | --- |
| MIG-AC01 | 4, 8, 10: ordinary mint/bond closed at deployment except the exact paid owner-first purchase |
| MIG-AC02 | 6, 8, 10: all surrender rejects Stage1 and works after atomic activation |
| MIG-AC03 | 4, 8, 13: indirect/mislabeled issuance bypass negatives |
| MIG-AC04 | 4, 7, 11: bounded full replacements, replay and cutoff |
| MIG-AC05 | 4, 8, 10: current-owner authorization and rollback |
| MIG-AC06 | 6, 8, 10: exact custody/credit/bond atomicity |
| MIG-AC07 | 4, 6, 8: full original quote times actual remaining fraction; empty fails |
| MIG-AC08 | 4, 6, 10: old rewards do not increase compensation |
| MIG-AC09 | 3, 6, 8: cross-representation and recovery duplicate prevention |
| MIG-AC10 | 6, 10: recovery never resizes the compensation bond |
| MIG-AC11 | 3, 6, 9: LP-lock, funded principal and fungible units distinct |
| MIG-AC12 | 4, 8, 13: ordinary package isolation |
| MIG-AC13 | 4, 6, 7, 10: independent and surrender paths remain distinct |
| MIG-AC14 | 6, 8, 10: compensation cliff class and reward gate |
| MIG-AC15 | 1, 4, 8: owner authority plus explicitly amended manual pricing permission |
| MIG-AC16 | 4, 9, 10: closed-stage all-leg funding and backing |
| MIG-AC17 | 6, 10: recovered assets donate; no ordinary bond purchase |
| MIG-AC18 | 3, 6, 9, 13: every source category, no silent deferral |
| MIG-AC19 | 8, 10, 13: cliff minus one/exact/plus one principal checks |
| MIG-AC20 | 6, 8, 10: accrued reward preservation and no repeated payout |
| MIG-AC21 | 1, 4, 7: full original canonical fee/split at explicit load |
| MIG-AC22 | 4, 6, 7: stored quote and fraction determine award; no live/partial re-quote |
| MIG-AC23 | 3, 6, 8: routed inputs/claims/recoveries never duplicate originals |
| MIG-AC24 | 1, 4, 7, 10: live independence, keep-until-reloaded and postactivation immutability |
| MIG-AC25 | 6, 8, 10: actual per-surrender creation clocks |
| MIG-AC26 | 4, 8, 10: actual cut/stage atomicity |
| MIG-AC27 | 4, 8, 10: all administration selectors gone, including restoration attempts |
| MIG-AC28 | 4, 8: repeated activation cannot modify state |
| MIG-AC29 | 6, 8, 10: retained donation/surrender/claim/recovery operations |
| MIG-AC30 | 4, 8, 13: no migration pause and preserved registry semantics |
| MIG-AC31 | 1, 7, 10: funding-first resumability with no new pricing/finalization gate |
| MIG-AC32 | 6, 8, 10: current owner alone harvests |
| MIG-AC33 | 6, 11: measured selected work independent of total custody |
| MIG-AC34 | 6, 10: repeat/overlap reward and recovery reconciliation |
| MIG-AC35 | 3, 6, 10: configured original wallet and actual surrender |
| MIG-AC36 | 1, 4, 6: remaining principal changes fraction, not stored quote |
| MIG-AC37 | 4, 8, 10: no Stage2 source/config/root/approval/pricing mutation |
| MIG-AC38 | 4, 7, 10: full replacement preserves issuance A and custody |
| MIG-AC39 | 3, 6, 8: wallet-bound proportional credit conservation without ancestry |
| MIG-AC40 | 6, 8, 10: final surrender and complete failure rollback |
| MIG-AC41 | 6, 8, 10: partial fungibles and whole NFTs |
| MIG-AC42 | 6, 8, 10: same surrendering eligible wallet receives bonds |
| MIG-AC43 | 8, 10, 13: permitted transfers preserve lock and timestamps |
| MIG-AC44 | 6, 8, 11: whole selected harvest rollback |
| MIG-AC45 | 6, 10: staged custody and fixed eventual donation destination |
| MIG-AC46 | 4, 9, 11: two proxy owners and isolated initialization |
| MIG-AC47 | 4, 6, 8: current/pending/former owner behavior |
| MIG-AC48 | 4, 8, 9, 13: composition reuse and actual declarations/routing |
| MIG-AC49 | 4, 5, 6, 10: configure without minting; live principal fraction and two NFT 3 bonds |
| MIG-AC50 | 3, 4, 6, 7: collection/token stable identity, original wallet and actual ownership |
| MIG-AC51 | 4, 7, 10: distinct-original consolidation, held-exposure exclusion and immutable issuance history |
| MIG-AC52 | 4, 7, 10, 12: overwrite/replay/cut and mixed-book journal recovery |
| MIG-AC53 | 8, 10, 13: every Stage1 new-instance reward payout path closed |

### Planning handoff and limits

No owner product decision remains. Earlier reserved-ID facts, available source evidence, actual gas bounds and runtime success are execution obligations, not unapproved economic choices. There is no current numerical compensation allocation or live deployment approval.

Plan-consultant `st_01a1dc8e` findings are addressed: independently recomputable historical domains, transaction-specific same-block completion and preserved donation IDs, plus unset-pricing operator coverage, serialized shared-file ownership, additive final-report delivery and removal of the extra acknowledgement gate. Native plan-reviewer remains pending. The lead binds the amended bytes and runs one native plan-reviewer per round, recording receipts in the owned draft. The dedicated planner launches neither reviewer. After native review and separate execution authorization, the execution command is `/ulw-execute dtf-migration-conformance-remediation-20261114`. Plan creation and this amendment start no execution.
