# PRD: Correct the SE Balancer Stable Buffer Hook to support 2–5 tokens

- Created: 2026-09-06
- Last updated: 2026-09-06
- Status: Required product correction; implementation and execution evidence pending.
- Existing package: `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/`.
- Existing production type prefix: `UniswapV4StandardExchangeBalancerQuadStableBufferHook`.
- Requirement authority: the user's clarification on 2026-09-06 that this hook must support 2 through 5 tokens and reproduce Balancer Stable Pool math.
- Parent specification: [SE Balancer Stable Buffer Hook PRD](UNISWAP_V4_SE_BALANCER_QUAD_STABLE_BUFFER_HOOK_PRD.md).

## 1. Problem and intended outcome

The current hook requires exactly four currencies throughout deployment, storage, initialization, liquidity accounting, and its wrapper around Balancer StableMath. That restriction is a bug relative to the intended product. It prevents a valid two-token DETF/USDG reserve and valid three- or five-token stable reserves from using the same hook package.

Correct the existing package so a deployment binds **exactly 2, 3, 4, or 5 distinct currencies**, with at least one Standard Exchange (SE) binding. Every supported token count must work through the production deployment path, staged pair initialization, swaps, liquidity operations, valuation, and SE buffering. Use one shared reserve book and Balancer V3 StableMath across all active currencies.

Token count is selected at deployment and remains immutable for the instance. Supporting five tokens does not mean padding smaller pools to five slots or adding currencies after deployment.

The `quad` directory and existing type names are historical identifiers. Keep the fix in this package; a directory rename, separate two-token hook, and separate five-token hook are not required. Names must not determine runtime token count.

## 2. Authority and superseded requirements

This correction supersedes the parent PRD's former D4 (`n=4`, six pairs), its four-asset descriptions, and fixed-six requirements in the co-located [staged initialization PRD](UNISWAP_V4_STANDARD_EXCHANGE_BALANCER_QUAD_STABLE_BUFFER_HOOK_STAGED_INIT_PRD.md) and [staged implementation plan](UNISWAP_V4_STANDARD_EXCHANGE_BALANCER_QUAD_STABLE_BUFFER_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md).

The user has settled the supported range. Do not treat the old planning lock as a reason to preserve four-token behavior or request approval of the range again. Count-dependent ABI, storage, math adapters, and initialization logic must be corrected together.

Continue to apply the existing requirements for Balancer pricing identity, SE opacity, pair/share LP inputs and outputs, buffering and valuation, fee attribution, token policy, shared facets, registry deployment, hook permission flags, and immutable instances. The unbuffered Balancer and SE Curve sibling packages are outside this correction.

## 3. Reference behavior and code evidence

The local Balancer [StableMath library](../../../../../../../../lib/crane/contracts/external/balancer/v3/solidity-utils/contracts/math/StableMath.sol) operates on the supplied balance-array length and declares `MAX_STABLE_TOKENS = 5`. Its [StablePoolFactory](../../../../../../../../lib/crane/contracts/external/balancer/v3/pool-stable/contracts/StablePoolFactory.sol) enforces that maximum. Balancer's Vault supplies the two-token minimum. These are distinct validation layers; the hook must enforce the complete 2–5 range itself.

Primary upstream references: [StableMath](https://github.com/balancer/balancer-v3-monorepo/blob/main/pkg/solidity-utils/contracts/math/StableMath.sol), [StablePoolFactory](https://github.com/balancer/balancer-v3-monorepo/blob/main/pkg/pool-stable/contracts/StablePoolFactory.sol), and [VaultStorage](https://github.com/balancer/balancer-v3-monorepo/blob/main/pkg/vault/contracts/VaultStorage.sol). The local [StablePool](../../../../../../../../lib/crane/contracts/external/balancer/v3/pool-stable/contracts/StablePool.sol) is the reference for pool-level math calls and checks. Record the local Crane revision and reference file hashes in the implementation plan; a moving upstream branch is not a reproducible differential-test target.

Source inspection on 2026-09-06 found:

| Area | Current four-token assumption | Consequence |
|---|---|---|
| [Package arguments](interfaces/IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage.sol) | Fixed-size token, SE, rate-provider, and decimal arrays | Two-, three-, and five-token configurations cannot be expressed faithfully. |
| [DFPkg](UniswapV4StandardExchangeBalancerQuadStableBufferHookDFPkg.sol) | Four-slot validation, four-token vault metadata, scale initialization, LP naming, six explicit finalization checks | Changing only `PkgArgs.tokens` cannot fix deployment or initialization. |
| [Repository](UniswapV4StandardExchangeBalancerQuadStableBufferHookRepo.sol) | `N_TOKENS = 4`, fixed arrays, count-dependent lookup | Discovery and accounting remain four-token even if a factory accepts another length. |
| [Initialization target](UniswapV4StandardExchangeBalancerQuadStableBufferHookInitTarget.sol) | Membership checks explicitly inspect indices 0–3 | A fifth currency cannot participate correctly. |
| [Pair pool library](UniswapV4StandardExchangeBalancerQuadStableBufferHookPairPoolLib.sol) | Fixed four-token/six-pair constants alongside a generic pair-count helper | The generic helper alone does not make the product variable-count. |
| [Math](UniswapV4StandardExchangeBalancerQuadStableBufferHookMath.sol) | Four-element adapters and positivity checks; `geometricMean4` in bootstrap/growth accounting | Dummy balances are invalid; LP accounting also needs a count-aware specification. |
| [Liquidity target](UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityTarget.sol) | Length-four checks, four-leg bootstrap and loops | Smaller pools cannot initialize; fifth-leg amounts cannot be accounted for. |
| Other targets, pull helpers, events, and tests | Fixed-length reserve/delta arrays and four-token fixtures | Quotes, transfers, event decoding, and test coverage can silently omit active currencies. |

These are implementation findings, not test results. No Solidity was changed and no execution tests were run while writing this PRD.

## 4. Supported configurations

| Bound currencies `n` | SE bindings allowed | Unordered pair pools `n * (n - 1) / 2` | Directed swap routes |
|---|---|---|---|
| 2 | 1–2 | 1 | 2 |
| 3 | 1–3 | 3 | 6 |
| 4 | 1–4 | 6 | 12 |
| 5 | 1–5 | 10 | 20 |

Currency count excludes the hook LP token and SE receipt tokens. A receipt represents its bound currency through existing SE accounting; it is not an additional reserve currency. PoolManager pair currencies remain the configured pair tokens.

All pairs share the same `n`-currency invariant and LP supply. A swap between two currencies in a five-token reserve must account for all five balances; it must not instantiate an independent two-token invariant for that pair.

## 5. Functional requirements

### 5.1 Binding and public representation

| ID | Requirement |
|---|---|
| R01 | Accept `n = tokens.length` only when `2 <= n <= 5`. Reject 0, 1, and every count above 5 before initializing instance state. |
| R02 | Expose deployment binding arrays with exactly `n` entries: tokens, SEs, rate providers, token decimals, and SE decimals. Reject every length mismatch; do not truncate, pad, or silently fill omissions. |
| R03 | Require distinct, nonzero currencies in canonical ascending address order. Keep each SE/provider/decimal binding associated with the same currency throughout validation, storage, and salt calculation. |
| R04 | Retain the one-SE minimum and existing binding checks: zero SE means a raw leg, duplicate SE bindings remain rejected, and any provider must satisfy the package's SE/provider rules. Apply validation to all active indices, including the fifth. |
| R05 | Report the actual `n` through token-count and discovery views. Return only active entries in token, reserve, amount, and delta arrays. Reject indices outside `[0, n)`. |
| R06 | Keep token count and bindings immutable after initialization. Maintain one authoritative active count; independently mutable count fields or inactive entries must not affect accounting. |

Dynamic external arrays are the intended ABI. Internal storage may use dynamic arrays or a bounded-capacity representation if only active entries can affect behavior. The implementation plan must specify that storage choice and all impacted selectors/events; a fixed-capacity implementation must never feed inactive slots into StableMath.

### 5.2 Staged pair initialization

| ID | Requirement |
|---|---|
| R07 | Generate exactly the unordered pairs `(i, j)` with `0 <= i < j < n`. Membership checks use the complete active binding. |
| R08 | Keep permissionless `deployPair(address,address)` and its existing idempotent behavior. Reject identical tokens, unbound tokens, invalid PoolManager callers, and invalid product PoolKeys. |
| R09 | Finalize only when every required pair pool for this instance is live. A missing final pair must prevent finalization, including a pair involving token index 4 in a five-token instance. |
| R10 | Preserve staged deployment: `postDeploy` does not initialize every pair in a loop. Pair creation can occur across transactions; finalization remains one-time and atomically installs the production surface. |
| R11 | Preserve hook flags, fee-key rules, tick spacing, callback validation, and pre-/post-finalization selector boundaries. Six initialization selectors or six facets are not six pair pools; do not rewrite unrelated constants because they happen to equal 6. |

The five-token configuration requires ten initialized pairs. Record worst-case finalization gas and facet bytecode size against the intended chain/compiler limits. No token-count-specific bypass of staging or deployment checks is allowed.

### 5.3 Balancer math identity

| ID | Requirement |
|---|---|
| R12 | Supply exactly the `n` active normalized balances to the pinned Balancer V3 StableMath functions. Remove four-element conversions and use the true token indices throughout. |
| R13 | Preserve invariant, exact-in swap, exact-out swap, and balance-solving behavior against the reference for every supported `n`, including convergence failure and rounding direction. |
| R14 | Keep amplification units explicit: `scaledAmp = baseAmp * AMP_PRECISION`, with Balancer precision `1e3`. Match the pinned reference's valid amplification endpoints; verify them from code rather than stale examples. |
| R15 | Apply corresponding StablePool domain checks where the hook exposes equivalent operations, including active-balance validity, imbalance limits, and applicable invariant-ratio bounds. A direct math-library call does not by itself establish pool-level equivalence. |
| R16 | Reject zero active reserves where the operation requires a live full reserve. A valid smaller pool has fewer active balances, not zero-valued placeholders in a larger pool. |
| R17 | Preserve native-unit scaling, SE claim valuation, fee application, and operation-specific rounding as separate, explicit layers around the invariant. Apply fees and rates once. |

The current DFPkg rejects `baseAmp >= 50_000`, while the inspected local StablePool accepts its `MAX_AMP` endpoint. Record and resolve that boundary mismatch as part of the math-conformance work. Do not substitute a different curve or amplification convention to make a new token count pass.

For pure math calls using identical normalized inputs and the same pinned reference, require exact output/revert agreement. For end-to-end routes, decompose differences into documented fee and conversion steps and establish explicit rounding bounds in native units. A broad percentage tolerance must not hide a wrong invariant or a missing reserve.

### 5.4 LP accounting and SE buffering

| ID | Requirement |
|---|---|
| R18 | First liquidity requires positive contributions for every active currency and no others. Minimum-liquidity handling and all minted/locked LP amounts must reconcile for each `n`. |
| R19 | Generalize proportional joins/exits and each supported non-proportional operation across all active legs. Amount vectors, token-address routes, transfers, fee deltas, minima/maxima, and emitted deltas must agree. |
| R20 | Preserve the parent's requirement for pair-token and SE-share liquidity units on buffered legs. Generalizing currency count must not remove a supported route or misinterpret share units as pair-token units. |
| R21 | Specify count-aware bootstrap, invariant-growth, LP-pricing, and protocol-fee accounting. Review `geometricMean4`, `rootK`, and `kLast` explicitly; removing fixed arrays while leaving four-leg LP economics is not a complete fix. |
| R22 | Preserve SE opacity, buffer-last settlement, free-pair/dust attribution, and inventory/value separation for one, several, or all buffered legs. Rate growth may reprice value; equivalent buffer reshuffling alone must not create a gain. |
| R23 | A failed SE conversion, transfer, or insufficient-liquidity settlement must revert the whole operation under existing atomicity rules, including LP/reserve accounting for every active leg. |

R21 requires a written mapping between Balancer invariant-based liquidity calculations and the hook's inventory units and protocol-fee accounting. Initial LP denomination can have an explicit normalization; it must not introduce inconsistent subsequent LP pricing. Any retained IndexedEx-specific fee/growth metric must be separately identified and proven count-aware. Do not silently replace `geometricMean4` with an arbitrary generalized geometric mean and describe that as Balancer Stable Pool math.

The current source also contains liquidity selectors that revert `InvalidRoute`. The implementation plan must list those existing gaps and distinguish them from count-induced failures. Existing parent liquidity requirements remain binding, but this correction must not report unimplemented operations as passing coverage. The separate DETF composition's requirement for executable unbalanced joins and its unified host ABI remains an additional release dependency.

## 6. Package compatibility and affected surface

The old deployment ABI uses fixed-size arrays; the corrected ABI is not binary-compatible merely because it can still describe a four-token pool. Version and document the deployment argument/event schema and update all affected encoders, FactoryServices, registry integration, deployment helpers, and test fixtures together. Preserve generic shared facets and avoid duplicating their token/vault views inside product facets.

The implementation plan must resolve:

1. **Storage layout:** layout/version for new corrected instances and explicit treatment of the old four-token layout. No mutation or upgrade of an existing immutable hook is authorized by this PRD.
2. **Salt identity:** canonical encoding includes the complete active binding and count, directly or through unambiguous dynamic-array encoding, plus all existing identity fields. Continue to exclude package/facet addresses. Document any semantic version/domain change; do not promise old instance addresses will be preserved.
3. **ABI and metadata:** variable-length deployment arguments, events, return arrays, vault contents, LP naming, and any generated ABI consumers. Existing legacy encoding must not be silently reinterpreted as a different pool.
4. **Factory compatibility:** use package → vault registry → flag-mined hook factory, with facets deployed through the current FactoryService/CREATE3 workflow. Both two- and five-token cases must use that production path in tests.
5. **Four-token regression:** preserve valid four-token functionality under the corrected schema. Record intended changes arising from an independently verified Balancer parity correction rather than silently treating old results as the oracle.

Work is centered on this package and its direct consumers. A blanket rename of `Quad` types, changes to sibling curve products, a new DETF family, mutable token membership, and new administrative controls are outside the fix.

## 7. Validation matrix

Use the existing production TestBase hierarchy and package-specific suites. Extend fixtures to select the active token count and bindings; do not validate only a pure helper or a mocked hook.

| ID | Coverage | Required result |
|---|---|---|
| T01 | Deploy 2, 3, 4, and 5 currencies | All four succeed with valid bindings through the registry/factory path; discovery and vault metadata return exact active arrays. |
| T02 | Deploy 0, 1, 6, and a larger count; mismatch each companion array | Every invalid configuration fails without a partially initialized usable instance. |
| T03 | Zero/duplicate/unordered token; invalid SE/provider/decimals at each active index | Consistent rejection, including the fifth leg; no binding drift. |
| T04 | Pair enumeration at all counts | Exactly 1, 3, 6, or 10 unique product pools; every route references the same hook reserve and LP supply. |
| T05 | Missing pair, repeated pair creation, foreign pair, premature/repeated finalize | Staged initialization invariants hold; five-token tests specifically exercise the last required pair. |
| T06 | Every directed swap at each count, exact-in and exact-out | Correct amounts and settlement across 2, 6, 12, and 20 directions; inactive or foreign indices fail. |
| T07 | Differential invariant, swap, and balance math | Pinned reference parity across balanced/imbalanced reserves, all indices, and valid amplification endpoints; invalid domains fail. |
| T08 | Cross-pair sequencing | A trade changing one leg updates later quotes on other pairs through the shared `n`-asset book; no separate pair-local invariant. |
| T09 | Bootstrap, proportional liquidity, and supported single-/multi-asset liquidity | All active amounts, LP ownership, fees, and output units reconcile; count alone cannot trigger `InvalidRoute`. |
| T10 | One SE, mixed SE/raw legs, all SEs, distinct SEs, and optional providers | Each topology preserves opacity and valuation; rotate SE placement so middle and last indices are exercised. |
| T11 | Supported mixed decimals and non-unit SE conversion rates | Correct pair/share scaling at every count, including 18-decimal DETF with 6-decimal USDG; no assumption that one SE share equals one pair-token unit. |
| T12 | Rate accrual, donations, buffer reshuffling, pretransfers, and LP fee growth | Asset attribution and economic value reconcile; no false price/fee growth from unit conversion or untouched-slot errors. |
| T13 | Liquidity exhaustion or conversion failure on any leg | Whole-operation atomicity; no partial LP burn/mint or stranded transfers. |
| T14 | Adversarial round trips and operation interleavings | No free value extraction from count, rounding, reserve omission, callback access, reentrancy, or inconsistent fee/rate application. |
| T15 | ABI, salt, flags, storage, selector, and metadata checks | Corrected deployments use the intended schema and complete facet surface; identities are deterministic and distinct for distinct bindings. |
| T16 | Existing four-token regression plus five-token resource limits | Meaningful existing coverage remains green; worst-case supported operations fit chain gas and facet-size limits. |

Test all four counts explicitly; a fuzz suite that happens to generate only four-token cases is insufficient. Pure differential tests complement production-proxy tests. Expected values must come from the pinned Balancer reference or independently justified accounting, not from repeating the hook's calculation in the assertion.

## 8. Implementation plan and completion criteria

The follow-on implementation/test plan must map R01–R23 to code changes and T01–T16 to concrete tests. It must include:

- A complete scan of count-dependent arrays, loops, membership checks, transfers, event payloads, metadata, and helper encodings across the package and direct consumers.
- The chosen argument/storage schema, salt compatibility treatment, and migration of local callers.
- A pinned math reference, the LP/fee-unit mapping required by R21, and explicit treatment of existing parity differences and unsupported liquidity selectors.
- The staged initialization matrix and updated deployment fixtures for all four counts.

Completion requires valid 2–5 token operation, invalid-count rejection, required math parity, correct LP/SE accounting, production-path evidence, and consistent canonical documentation. Updating only deployment validation, reducing the count to two, or expanding fixed arrays to five while assuming every instance has five tokens does not satisfy this PRD.

Follow current repository validation rules during implementation: run `forge build` after production edits before `forge test`; use default hermetic tests and `FOUNDRY_PROFILE=fork` for justified fork checks. Do not introduce package-specific profiles or `via_ir`. Record revisions, commands, results, and outstanding gaps. This documentation task performs no build, test, migration, or deployment.

## 9. Relationship to the NET/Morpho DETF

The [NET leverage-demand USDG stable DETF PRD](../../../../../../../vaults/detf/protocols/dexes/uniswap/v4/detf/NET_MORPHO_USDG_BALANCER_STABLE_DETF_PRD.md) uses the corrected hook with `n=2`: DETF and USDG, with USDG bound to S01. That composition is an acceptance consumer of the general fix, not the reason to limit the repaired hook to two currencies.

The S01 cash sleeve and the complete unified DETF-facing hook/lifecycle integration are separate dependencies. Passing this token-count correction does not by itself prove the Morpho strategy, its peg behavior, or the DETF's bond/claim lifecycle. Later DETFs can select three-, four-, or five-token configurations without another cardinality-specific hook.

## 10. Change log

| Date | Change |
|---|---|
| 2026-09-06 | Initial correction PRD following the user's confirmation of the intended 2–5 token behavior. Superseded the fixed-four product restriction; specified dynamic binding, shared-book pair enumeration, staged initialization, Balancer math parity, LP/SE accounting, compatibility work, and production validation for all supported counts. |
