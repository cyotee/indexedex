# PairToken Standard Exchange Vault: stage one PRD

Date: 2026-10-29
Revision: Owner-approved bounded-execution amendment, 2026-10-29.

Status: The owner authorized applying the bounded-execution recommendation to
this PRD, its plan, implementation and tests. Deployment, migration, commits and
replacement of existing vaults remain unauthorized. The original council draft
and admitted snapshots remain historical artifacts; this amendment is not a new
council-reviewed revision.

## 1. Goal and stage boundary

Implement a simple Uniswap V4 Standard Exchange vault using the proportional
basket ownership logic of `contracts/pairtoken-baseline/PairToken.sol`, packaged
as an IndexedEx registry-deployed Crane Diamond Package and exposing the
standard vault, Standard Exchange, share-token, and native SY interfaces.

Stage one has **one public ERC-20 share supply**. The diamond owns one full-range
V4 position and the associated idle currencies. Public shares represent
proportional ownership of that basket. There is no separate PairToken deployment,
no second internal share supply, and no shares-of-shares wrapper yet.

The working implementation, its production-first TestBase, and its accounting
tests are intended to become the concrete reference for later stages. Do not
prebuild later-stage reserve abstractions.

### 1.1 Confirmed owner decisions

| ID | Decision |
| --- | --- |
| S1-D01 | Deliver a PRD for a simple Standard Exchange implementation first. Implementation is a subsequent task. |
| S1-D02 | Use PairToken's full-range strategy, not upper/lower wings. |
| S1-D03 | Carry forward the earlier **ownership logic only** choice: do not inherit PairToken's permanent dead shares, 10-basis-point redemption retention, or protocol-fee routing. The owner reconfirmed this choice specifically for stage one. |
| S1-D04 | Use Diamond Package and standard Standard Exchange Vault conventions. |
| S1-D05 | The longer-term objective is internal reserve accounting, not a separate external PairToken investment. Stage one does not implement the second share layer. |
| S1-P01 | **Confirmed 2026-10-28:** Keep baseline compounding: automatic collection, ratio-swap, and reinvestment before entries/exits, plus permissionless `compound()`. Retain all collected fees for shareholders; S1-D03 still excludes protocol-fee routing. The original decision ID is retained for traceability. |
| S1-P02 | **Confirmed 2026-10-28:** Retain native ETH support, including native-currency pools and actual ETH entry/payout. Wrapped-native adaptation at the nonpayable Standard Exchange boundary must not replace or remove native operation support. |
| S1-P03 | **Confirmed 2026-10-28:** Exact output is explicitly unsupported. Install `IStandardExchangeOut`; both methods revert `ExchangeOutNotAvailable()` without receiving funds or changing state. |
| S1-P04 | **Confirmed 2026-10-28:** Correct reserve and fee attribution rather than preserve baseline attribution limitations. Specify complete equations before coding. |
| S1-P05 | **Confirmed 2026-10-28:** Require stronger exit availability using **conditional fallback**: normally compound fully; when preflight identifies a specified maintenance obstacle, collect fees but skip ratio swap/reinvestment before withdrawal. This expressly qualifies S1-P01 for withdrawals only. |
| S1-P06 | **Confirmed 2026-10-28:** SY reports spot-marked basket accounting value, separate from withdrawal-and-sale proceeds, using canonical raw-unit SY scaling. It is not an issuance input. |
| S1-P07 | **Confirmed 2026-10-29:** Preserve economics and atomic routes while imposing conservative crossing, bitmap and whole-candidate budgets. Exhaust expensive maintenance early so eligible paired withdrawals use affordable collection-only fallback. Single-token conversion is conditional on the complete supported budget and never silently becomes a paired payout. Use a 12M-gas engineering transaction ceiling across Ethereum, Base and Robinhood; independently bound previews. |

### 1.2 Decision status

The owner authorized applying the council's suggested PRD changes after
confirming S1-P04 through S1-P06 and selecting conditional rather than
unconditional collection-only withdrawals. All S1-P IDs are retained for
traceability, not provisional status. The detailed equations and fallback
predicates below are this revision's engineering specification, not a claim
that the council reviewed this revised text or that contracts were implemented.
The owner subsequently authorized implementation and, on 2026-10-29, applying
S1-P07 after the original A70 measurements failed. S1-P07 amends the operational
domain only; the ownership, fee, rounding and native-custody equations remain.

## 2. Authority and source map

Paths below are relative to the repository root. The checked-in standalone
baseline is the behavioral reference, not an external deployment or a historical
council recommendation. Where this PRD deliberately changes it, the deviation
register in section 3 controls the proposed new family only.

| Source | Purpose |
| --- | --- |
| `contracts/pairtoken-baseline/PairToken.sol` | Basket ownership, paired entry, zap entry, proportional exit, zap exit, compounding, and settlement sequencing. |
| `contracts/pairtoken-baseline/PairTokenMath.sol` | Integer arithmetic and rounding reference. |
| `contracts/pairtoken-baseline/interfaces/IPairTokenDependencies.sol` | Baseline dependency contract; not a requirement to introduce a second factory/configuration service. |
| `CLAUDE.md` | Current supported-family scope, factory workflow, token policy, compiler/test rules. |
| `docs/agent/INDEXEDEX_AGENT_LAW.md` | Registry integration, token policy, native SY expectations, production-first testing. |
| `.github/ASSISTANT_CODING.md` | Repository-first reuse and naming. |
| `.github/ASSISTANT_DEPLOYMENT.md` | Package deployment and metadata initialization. |
| `.github/ASSISTANT_TESTS.md` | Required implementation validation. |
| `lib/crane/contracts/interfaces/IStandardExchangeIn.sol` | Exact-input ABI and pretransfer contract. |
| `lib/crane/contracts/interfaces/IStandardExchangeOut.sol` | Exact-output ABI and unsupported-operation error. |
| `lib/crane/contracts/interfaces/IStandardExchangeErrors.sol` | Standard route, deadline, and output-limit errors. |
| `contracts/interfaces/IStandardExchange.sol` | Combined In/Out interface declaration. |
| `contracts/interfaces/IStandardExchangeInMulti.sol` | Existing many-to-one exact-input extension; not the baseline's maximum-input paired deposit contract. |
| `contracts/interfaces/IStandardExchangeOutMulti.sol` | Existing exact-output dual exit; not the baseline's proportional share-input redemption. |
| `contracts/interfaces/IStandardExchangeMultiAssetLiquidity.sol` | Existing broader liquidity extension, reviewed before choosing the narrow paired surface. |
| `contracts/vaults/basic/IBasicVault.sol` | Token and reserve discovery. |
| `contracts/interfaces/IStandardVault.sol` | Vault configuration/type discovery. |
| `contracts/interfaces/IStandardVaultPkg.sol` | Package declaration. |
| `contracts/interfaces/IVaultRegistryDeployment.sol` | Registered package and instance deployment. |
| `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol` | Shared SY execution/reward behavior. |
| `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol` | SY discovery and rate requirements. |
| `contracts/vaults/standard/sy/NativeStandardYieldPreviewTarget.sol` | SY previews and invalid-token behavior. |
| `lib/crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol` | Canonical wrapped-native deposit/withdraw interface for ERC-20-facing SE routes. |
| `contracts/utils/LocalCreditLib.sol` | Contract-only pretransfer guard and unbooked-credit arithmetic. |
| `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.sol` | Current registered V4 package lifecycle reference, not economic logic to inherit. |
| `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/test/bases/TestBase_UniswapV4UpperLowerWingsStandardExchangeVault.sol` | Real PoolManager, facets, package, and registry test-deployment pattern. |
| `test/foundry/spec/pairtoken-baseline/harness/PairTokenTestBase.sol` | Existing baseline characterization fixture. |
| `test/foundry/spec/pairtoken-baseline/harness/ScriptedDependencies.sol` | Existing baseline dependency scripting API. |
| `docs/research/pairtoken-se-stage-one-council-20261028-01a1810f/REPORT.md` | Council recommendations, followed by the owner's decisions recorded above. |
| `docs/research/pairtoken-se-stage-one-council-20261028-01a1810f/coordinator/resolution.md` | Advisory dispositions; rejected claims are not requirements. |

The retired V4 legacy SE and FullSpread families are not templates to restore.
Stage one is a new family with a new type identity. The existing Wings package,
its deployments, and its tests remain untouched.

## 3. Explicit deviation register

“Same logic” means the baseline algorithms with the following named changes,
not byte-for-byte ABI or revert-data equivalence.

| ID | Baseline | Stage-one requirement |
| --- | --- | --- |
| S1-X01 | Monolithic ERC-20 contract with ordinary storage. | Diamond proxy, canonical share facets, namespaced family storage, registry deployment. |
| S1-X02 | Mint 1,000 shares to `DEAD` at genesis. | No permanent sink. Mint all computed genesis shares to the recipient. |
| S1-X03 | Redeem only `floor(shares * 9990 / 10000)` effective shares. | Redeem the full submitted share amount proportionally. |
| S1-X04 | Factory-configured protocol fee and external fee-manager notification. | No stage-one vault-level entry, exit, performance, or protocol fee. All LP fees remain in the basket; pool trading fees still apply. No fee-manager calls or allowances. |
| S1-X05 | Mutable external factory getters for zap limits. | Immutable instance parameters for the same limits, validated and included in instance identity. |
| S1-X06 | Native currency and arbitrary supplied pool key. | Retain native currency under S1-P02; require an initialized, hookless pool and validated currency-to-ERC-20-face mapping under S1-NATIVE-01. |
| S1-X07 | Standalone convenience methods only. | Standard vault, SE, ERC-20 permit/domain, and native SY surfaces, plus necessary paired entry/exit methods. |
| S1-X08 | Baseline previews do not simulate the full mandatory compound. | Execution-equivalent standard and paired previews, including projected compounding, fees, swaps, and integer settlement. |
| S1-X09 | Raw local balances are immediately considered basket inventory. | Booked shareholder inventory is isolated from unbooked pretransfers and pending caller input. Explicit donation adoption replaces automatic absorption. |
| S1-X10 | Permanent dead shares prevent a true last-share exit. | Specify zero-supply reset, complete paired terminal withdrawal, and rebootstrap. |
| S1-X11 | Callback authenticates the PoolManager address. | Authenticate the PoolManager plus an active operation and its expected callback payload. |
| S1-X12 | `redeemZap` can leave unswapped input in custody after a partial swap. | A single-token exit must consume its entire unwanted-token allocation or revert atomically. Paired exit remains the fallback. |
| S1-X13 | Endpoint basket math does not clamp price to the full-range boundaries. | Basket inventory must match removable principal at and beyond usable range boundaries; use canonical clamped V4 amount math there. Preserve interior rounding. |
| S1-X14 | Positive supply with both reserves zero falls into geometric-mean issuance. | Reject this invalid accounting state; geometric-mean issuance is reserved for zero supply. |
| S1-X15 | Zap issuance uses gross deployment from all idle inventory against a pre-swap basket. | Caller-only entry inventory; final issuance uses attributable reserve growth at the post-swap incumbent snapshot under S1-ACC-07. |
| S1-X16 | Compound-generated fees may be realized by an add or remain uncollected. | A final nonrecursive fee checkpoint includes all earned incumbent fees before entry/exit allocation; later entry-swap fees belong to incumbents until mint. |
| S1-X17 | A failed compound blocks its triggering withdrawal. | Preflight-selected collection-only withdrawal for the exact maintenance obstacles in S1-EXIT-01; unexpected execution failures still revert. |
| S1-X18 | Native settlement omits an explicit native sync. | Reset native sync immediately before value settlement, independent of prior synced-currency state. |
| S1-X19 | No bounded full-operation projection domain. | Deterministic step, initialized-crossing and distinct-bitmap budgets under S1-QUOTE-01/S1-GAS-01, with exact economic previews and identical conditional fallback. |

S1-X08 through S1-X19 are explicit integration/correctness requirements, not
claims that the standalone baseline already provides those guarantees. They
must appear explicitly in implementation review and comparative test results.
Do not alter the baseline or its tests to make comparisons pass.

## 4. Scope and architecture

### S1-ARCH-01: New family and placement

Proposed production directory:

`contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/`

Use the `UniswapV4PairTokenStandardExchangeVault` type prefix. Keep this PRD
beside the baseline's `se-version` staging area until an approved implementation
places or references it next to the new package; do not create duplicate
normative PRDs.

The implementation shall follow Facet -> Target -> Repo conventions. Reuse
canonical ERC-20, ERC-2612, ERC-5267, basic-vault, and standard-vault components.
Keep shared accounting/settlement logic internal to the family rather than
self-calling public proxy methods with changed caller semantics.

Split family execution, quote, callback, and SY facets only as needed for
cohesion and the normal deployed-code-size limit. No alternate share ERC-20,
external reserve contract, generic strategy framework, or future-stage wrapper.

### S1-ARCH-02: Share and position identity

- The diamond is the ERC-20 and the owner used in the PoolManager position key.
- Shares have 18 decimals, matching PairToken; currency amounts remain native
  units even when either currency has different decimals.
- Exactly one position uses the full usable tick range and salt `bytes32(0)`.
  Use canonical `TickMath.minUsableTick/maxUsableTick`, `PoolIdLibrary.toId`,
  and `StateLibrary`; position identity is
  `(diamond, tickLower, tickUpper, bytes32(0))`.
- Do not conflate pool active liquidity with this position's owned liquidity.
- Pool manager, key, valuation currency, and zap limits are immutable after
  initialization. No operational owner, strategy setter, rescue of backing,
  or upgrade surface is installed by this family.
- Use a family-specific ERC1967-form storage namespace. Never place PairToken's
  ordinary storage layout into a facet or reuse Wings storage.

### S1-ARCH-03: Configuration and validation

Define `PkgInit` and `PkgArgs` on the package **interface**. Package bindings
include real facet addresses, PoolManager, registry, and the canonical
infrastructure dependencies actually used. Instance arguments include:

1. Pool key.
2. `rateAsset`, equal to one of the two declared ERC-20 currency faces
   (wrapped native when selecting the native pool leg).
3. Share name and symbol.
4. `maxZapBps`, positive and at most 10,000.
5. `maxZapTickMove`, nonnegative and representable as the baseline tick bound.

Do not silently invent defaults for these two zap parameters. The configured
values govern baseline zap sizing and the compounding quarter-cap.

For native-pool support, bind the canonical wrapped-native contract at package
initialization and expose its address through the family query interface.
Its identity participates in package binding/deployment identity; it is not
caller-selectable per operation.

Validate ordered, distinct pool currencies: currency0 may be `address(0)` for
native ETH; every nonzero currency must have deployed code and currency1 must
be nonzero. Validate legal positive tick spacing and static pool fee; zero hook
address; initialized pool; valid rate-asset membership; valid wrapped-native
binding when used; and required nonzero infrastructure/facets. Do not add a
token-decimals allowlist, token-behavior allowlist, or issuer-blacklist detector.
Reject self-referential pool currencies.
Require `currency0 < currency1`, `0 < tickSpacing <= 32767`, static
`fee <= 1_000_000`, and initialized nonzero sqrt price. Zero pool fee is valid;
dynamic-fee flags are not. Validate the bound native wrapper's 18-decimal
one-to-one interface; cache rate-asset decimals at initialization for
`assetInfo`, without using them to normalize the raw-unit SY rate.

No stage-one fee switches or fee-manager arguments are exposed. Use truthful
zero fee-type declarations for this family rather than registering a fee that
execution ignores. Registry disabling remains applicable to inbound issuance.

### S1-ARCH-04: Required reusable package facets

Use the following five existing facets unchanged. This is the **package-owned
reuse list**, not the complete set of facets ultimately present on the diamond.
Select the split ERC-20/permit/domain composition used by the current Wings
package; do not substitute a new token implementation.

| Facet source path | Declared interfaces | Selectors installed by this package |
| --- | --- | --- |
| `lib/crane/contracts/tokens/ERC20/ERC20Facet.sol` | `IERC20`, `IERC20Metadata`, and the additional XOR interface ID declared by the canonical facet. | `name`, `symbol`, `decimals`, `totalSupply`, `balanceOf`, `allowance`, `approve`, `transfer`, `transferFrom` (9). |
| `lib/crane/contracts/tokens/ERC2612/ERC2612Facet.sol` | `IERC20Permit`. | `permit`, `nonces`, `DOMAIN_SEPARATOR` (3). |
| `lib/crane/contracts/utils/cryptography/ERC5267/ERC5267Facet.sol` | `IERC5267`. | `eip712Domain` (1). |
| `contracts/vaults/basic/MultiAssetBasicVaultFacet.sol` | `IBasicVault`. | `vaultTokens`, `reserveOfToken`, `reserves` (3). |
| `contracts/vaults/standard/MultiAssetStandardVaultFacet.sol` | `IStandardVault`. | `vaultFeeTypeIds`, `contentsId`, `vaultTypes`, `vaultConfig` (4). |

These contribute 20 distinct selectors. Resolve/deploy the canonical facets
through the existing CREATE3/FactoryService infrastructure and pass their real
addresses into the package configuration. Preserve their declared interface
IDs and selector sets; do not hand-copy their implementations into family
facets. Do not additionally install `ERC20PermitFacet`: its combined
ERC-20/permit/domain selectors overlap the three selected token facets.

The package must also supply the family-specific SE In/Out, paired liquidity,
query, maintenance/donation, native-capable SY, and authenticated PoolManager
callback behavior specified elsewhere in this PRD. Those are new-family
responsibilities, not permissions to reuse Wings economic/execution facets.
Their grouping may follow S1-ARCH-01, but they must not redeclare the 20 shared
selectors in another cut. In particular, SY inherits the token interfaces
without reinstalling their selectors.

**Exclude all factory-provided facets from the package facet inputs, component
deployment list, `facetAddresses()`, `facetCuts()`, and package-owned interface
aggregation.** The existing diamond factory supplies ERC-165, diamond loupe,
ERC-8109 introspection, and its temporary post-deploy hook. Do not redeploy,
recut, replace, or independently initialize those factory components here.
The factory owns the temporary hook's lifecycle. Their persistent interfaces
remain available on the final proxy; exclusion from this package does not mean
removing them from the diamond.

### S1-ARCH-05: Initialization required by reused facets

Initialize shared storage once in the diamond's `initAccount` delegatecall:

- `ERC20Repo`: configured share name, symbol, and 18 decimals, with zero initial
  supply. Only the defined deposit logic creates shares.
- `EIP712Repo`: the same share name and domain version `"1"`. Both permit and
  domain discovery must resolve the diamond as verifying contract, with the
  current chain ID. Use canonical `ERC2612Repo` nonce storage; fresh-account
  nonces start at zero and must not be seeded in facets or package storage.
- `MultiAssetBasicVaultRepo`: ordered ERC-20 currency faces `[C0, C1]`.
  Initialize empty reserves and synchronize both booked local reserve values
  after successful money/maintenance operations, including the wrapped-native
  reporting mapping. Do not report raw unbooked balances as shareholder reserves.
- `StandardVaultRepo`: the bound canonical fee-oracle reference, zero stage-one
  fee-type IDs, deduplicated package-owned vault interface declarations, and
  `contentsId = keccak256(abi.encode(sortedFaces))`, where `sortedFaces` is an
  address-sorted copy of `[C0, C1]`, matching registry `calcContentsId`.
  Keep `vaultTokens`, `vaultConfig.tokens`, and reserve arrays in PoolKey face
  order; do not reorder their stored list to calculate registry identity.
  Binding shared configuration does not enable fees excluded by S1-D03.

Reuse the existing Repo entrypoints and storage namespaces for these shared
facets. Family-specific storage stays in its own namespace. Do not initialize
shared state on a facet address or overwrite factory-owned introspection state.

## 5. Reserve ownership and arithmetic

### S1-ACC-01: State and basket

Let:

- `S` be public ERC-20 total supply.
- `L` be owned full-range position liquidity.
- `B0`, `B1` be booked local balances attributable to shareholders.
- `P` be live pool square-root price.
- `N_i(P,L)` be canonical removable principal of currency `i`, rounded down,
  at the clamped full-range price and owned liquidity `L`.
- `R_i = N_i(P,L) + B_i` after the operation's defined fee checkpoint.
- `E_i` be current caller input reserved outside the incumbent book.

Before an entry or exit snapshot, collect/project all fees earned through the
selected maintenance plan, including its ratio swap. If a positive addition
has not already realized those fees, perform one final zero-liquidity-delta
collection on a nonempty position. Do not recursively compound the resulting
fees; leave them booked idle. Never poke an empty position.

Before zap issuance, checkpoint again after the caller's swap and before its
liquidity addition. All fees earned by the pre-mint position through that swap
belong to incumbent supply. A raw `basket()` observation reports principal plus
booked idle and is distinct from a fee-inclusive accounting rate or a prepared
execution preview.

All conversions use full-precision multiplication/division, explicit floor or
ceiling rules, and safe liquidity/delta casts. Reuse Crane arithmetic where its
behavior matches; use baseline math vectors to prove that match. Do not copy
raw PoolManager storage offsets when canonical state libraries provide the
same read.
For all principal/cost uses, clamp `P` to the lower/upper sqrt boundaries:
below/equal lower is token0-only, above/equal upper is token1-only, interior
uses both. Removal rounds down; required addition costs round up. Apply this
to `N_i`, basket principal, additions, compound leftovers, and projection.
Preserve baseline interior results only where equivalent to canonical manager
math. An affordable addition must also pass signed-delta and per-tick capacity
limits; no silent capacity clamping.

### S1-ACC-02: Paired issuance

For maximum contributions `a0`, `a1`, compute a candidate `qQuote` and accepted
amounts as below. For positive supply, final minted `q` is capped by actual
attributable reserve growth under S1-ACC-07; previews return that final `q`.

| State | Candidate `qQuote` | Accepted input |
| --- | --- | --- |
| `S == 0` | `floor(sqrt(a0 * a1))` | Both specified amounts. Checked genesis product as in the baseline. |
| `S > 0`, `R0 > 0`, `R1 > 0` | `min(floor(a0*S/R0), floor(a1*S/R1))` | `used_i = min(a_i, ceil(qQuote*R_i/S))`. |
| `S > 0`, `R0 == 0`, `R1 > 0` | `floor(a1*S/R1)` | Only token1. |
| `S > 0`, `R1 == 0`, `R0 > 0` | `floor(a0*S/R0)` | Only token0. |

Reject zero issuance. If supply is positive and both reserves are zero, reject
as an invalid accounting state rather than issuing against a nonexistent
denominator. This is a named validity restriction on the baseline's combined
zero-supply/empty-basket branch.

At genesis require both accepted amounts positive, `q > 0`, and a positive
fundable position addition. Mint exactly `q` shares to the recipient; no
1,000-share subtraction, virtual shares, virtual assets, or hidden minimum
liquidity sink. Enforce the caller's minimum against actual recipient shares.
At genesis `q = qQuote`; there are no incumbent shares to protect. Do not add
an unstated genesis minimum. In one-sided positive-supply branches consume the
full specified maximum of the live leg and zero of the other, as in the baseline.

### S1-ACC-03: Proportional withdrawal

After the preflight-selected full or collection-only maintenance and final fee
checkpoint, snapshot `S`, `L`, `B0`, and `B1`. For `s`
shares, require `0 < s <= S` and valid holder authority:

```text
liquidityRemoved = floor(L * s / S)
idle0Allocated   = floor(B0 * s / S)
idle1Allocated   = floor(B1 * s / S)
```

Burn `s` before removal. Allocate actual **principal** removal proceeds plus
the two idle allocations to the withdrawing holder. Split manager
`callerDelta = principalDelta + feesAccrued`; never treat a whole-position fee
receipt as the partial holder's principal. The preceding checkpoint has already
booked all fees at the snapshot. Unexpected later fee growth or pool mutation
before removal is a state-change failure, not permission to allocate it to the
exiter. Revert and requote rather than executing a stale plan.

Reject a positive-share burn with zero total actual payout, even when minima
are zero. A positive payout in only one currency is valid. For single-token
exits apply this check to the final requested-currency payout.

Partial-withdrawal rounding remains with the live basket. No retention is
applied. Shareholders do not receive a guaranteed target-token value before
their unwanted-token conversion executes.

### S1-ACC-04: Donations and pending inputs

The standard pretransfer contract cannot coexist with treating every raw
token balance as already-owned basket inventory. Maintain separate booked
balances and operation reservations.

- False-flag pulls use observed balance deltas and require exact supported-token
  delivery. Do not credit an earlier balance or a caller-supplied amount alone.
- True-flag exact-input routes use `LocalCreditLib.requirePretransferCaller`
  and available unbooked credit; reserve exactly the declared amount before
  compounding. Never use booked backing to satisfy a claim.
- Excess unbooked funds are not refunded, automatically compounded, or counted
  as this operation's contribution.
- Add a permissionless `donate(token, amount)` pull operation for either pool
  token. It requires positive supply and amount, credits the observed supported
  token delta to booked reserves, mints no shares, and does not adopt unrelated
  unbooked balances. It may leave the new donation idle for the next compound.
  Make this method payable for native pools: `token == address(0)` requires
  `msg.value == amount`; ERC-20 or wrapped-native donation requires zero value.
  Wrapped-native input is unwrapped only when it is the alias for an actual
  native leg. If the wrapper itself is a configured ERC-20 currency in an
  ERC-20-only pool, treat it as an ordinary ERC-20 donation. Credit same-call
  receipt, never `raw balance - booked` from an earlier transfer. No second
  donation credit is created by the unwrap callback.
- Unsolicited transfers stay unbooked. As with the canonical SE contract,
  cross-transaction pretransfers have no ownership guarantee; do not advertise
  them as a safe donation mechanism.
- Reserve credited input and exit allocations across every callback. A swap or
  liquidity addition cannot spend another operation's refund or payout.

### S1-ACC-05: Terminal withdrawal and restart

When `s == S`, remove all owned liquidity and pay all booked basket assets to
the last holder through paired redemption. After successful payout, `S`, `L`,
and both booked balances are zero. Unbooked unsolicited balances are not
assigned to the last holder or the next bootstrap.
Every owned receipt generated by the terminal operation is booked/allocated
and paid to that holder. Never reclassify it as unsolicited, sweep it to a dead
address, or strand it outside the ledger.

A terminal single-token exit succeeds only if its complete opposing-token
allocation can actually be sold after removal. If the vault was the pool's
only effective liquidity, that may be impossible: revert. Paired redemption
avoids that sale and can use S1-EXIT-01's maintenance fallback; it still requires
successful fee collection, removal, settlement, and payout. Never simulate
liquidity that has already been removed or promise exits despite token freezes.

The next paired deposit uses the genesis branch. No terminal recovery owner,
dead-share account, or automatic assignment of old unbooked assets is added.

### S1-ACC-06: Operation ledger and fee ownership

For each actual pool currency, classify every locally held unit exactly once:

```text
raw custody = incumbent booked idle
            + pending caller inventory
            + reserved exit allocation
            + reserved refund
            + unbooked excess
```

These categories are disjoint; moving a payout out of the book also removes it
from `B_i`. A temporary wrapped representation replaces its native category,
never adds another asset. At successful external return, operation reservations
are zero and raw custody covers the final booked idle. The shared basic-vault
Repo is a published snapshot of that book, not an extra accounting category.

| Transition | Required ownership change |
| --- | --- |
| Pull or authenticated pretransfer | Increase caller inventory by the exact authorized receipt; do not change incumbent book. |
| Compound collection | Increase incumbent `B_i` by realized fees exactly once. |
| Compound swap/add | Spend only incumbent book; book actual swap credits, debit actual principal costs, and separately book realized fees. |
| Entry swap | Spend and receive only caller inventory; fees accruing to the existing position remain incumbent claims. |
| Entry addition | Principal costs consume caller inventory only. Existing booked idle is not a funding source. Attribute growth by S1-ACC-07. |
| Mint | Create only the computed `q`; merge the accepted caller principal/residual into shared backing at the specified checkpoint. |
| Exit allocation/removal | Reduce incumbent idle by allocated idle; removed principal belongs to the exit allocation. Burned shares cannot receive later fee growth of remaining liquidity. |
| Exit sale | Spend only the exit allocation; output remains its property. Fees earned by remaining position liquidity belong to remaining holders. |
| Native unwrap/wrap | Replace the reserved representation one-for-one after validating receipt; never mint or book a second credit. |
| Payout/refund | Spend the matching reservation, not unbooked excess or remaining-holder backing. |
| Final commit | Publish both booked local reserves after external payouts/refunds; clear reservations and guard. |

Fee-growth differences use V4 modular subtraction and checkpoint rounding.
Unexpected receipts are not silently treated as caller input. Keep actual
principal, manager fee deltas, and locally paid/received amounts distinct.

### S1-ACC-07: Attributable entry credit and non-dilution equation

This section replaces gross-deployed baseline issuance where existing supply
is nonzero. It applies to both paired entries and zaps.

Freeze incumbent supply `S`, price `P*`, owned liquidity `L`, and book `B_i`
after the final incumbent-fee checkpoint immediately preceding the caller-only
addition. For zaps this is **after the caller's swap**, not the earlier price
used for the zap size limit. Define `R_i = N_i(P*,L) + B_i`.

Use only the current caller's inventory to fund the addition. Let `dL` be the
actual added liquidity and `J_i` the caller inventory remaining after paying
its actual principal costs. No swaps occur between this checkpoint and mint;
unexpected pool/fee state changes during external interactions revert.

```text
G_i = N_i(P*, L + dL) - N_i(P*, L)

paired entry: C_i = G_i + J_i
zap entry:    C_i = G_i

qCredit = min over i with R_i > 0 of floor(S * C_i / R_i)
paired q = min(qQuote, qCredit)
zap q    = qCredit
```

Reject if both `R_i` are zero, either contribution is invalid, or final `q` is
zero. A zero-reserve leg imposes no denominator constraint and gives no separate
share credit. Use full-precision division and comparisons.

`G_i` is the increase in **removable owned principal at the same price**, not
gross tokens spent and not all liquidity deployed by earlier compounding.
Thus addition rounding costs are borne by the entrant rather than hidden in
incumbent reserves. For paired entry, accepted input left idle is credited via
`J_i`. Do not rerun accepted-input selection after the final rounding cap.
Unused maxima remain with the caller or are refunded as specified.

For zaps, mint only against `G_i`, then book `J_i` as an explicit no-extra-shares
contribution to the resulting basket. This retains the baseline's no-refund
residual policy; previews and events must expose the uncredited remainder.
It may benefit all holders, including the new holder, but never creates extra
shares from incumbent inventory. Do not assume the entrant receives NAV credit
for every input unit.

The exact acceptance predicate, for each positive `R_i`, is:

```text
q * R_i <= S * C_i
equivalently: (R_i + C_i) / (S + q) >= R_i / S
```

Compare these rationals without truncating displayed per-share balances.
This proves the issuance step cannot dilute incumbent per-share ownership at
`P*`; it is not a guarantee against price movement during swaps, ordinary LP
exposure, or external market manipulation. Entry-swap fees and pool price
effects are measured separately, not reclassified as new deposited principal.

## 6. Operations

### S1-OP-01: Paired deposit

Provide a family-specific `depositPair(amount0Max, amount1Max, minShares,
recipient, deadline)` payable method with a corresponding execution-equivalent
preview that returns `(shares, used0, used1)`.

Order: validate -> lock -> isolate pending credit -> preflight complete plan ->
compound incumbent book and checkpoint fees -> compute candidate/accepted input ->
pull exact accepted ERC-20 amounts -> add from caller inventory only ->
compute final S1-ACC-07 credit and validate minimum -> mint/book accepted
residual -> refund unused native maximum -> commit shared reserves/unlock.

This paired operation has no pretransfer flag. Pull only accepted ERC-20
amounts; unused ERC-20 maxima remain with the caller. For a native pool,
require `msg.value == amount0Max`, reserve all incoming ETH before compounding,
and refund `amount0Max - used0` to `msg.sender` after successful accounting.
For a two-ERC-20 pool require zero value. Refund failure reverts the complete
operation. The first deposit must use this operation; do not invent a
one-token bootstrap.

### S1-OP-02: Single-token deposit

Map exact-input SE/SY deposits to the corrected caller-attributed zap:

1. Validate, guard, isolate pending input, and preflight the complete plan.
2. Compound the pre-entry book and complete the fee checkpoint; exclude input.
3. Snapshot supply and the pre-entry-swap reserves for the size test. Require
   positive supply and both reserves positive, and
   `0 < amountIn <= floor(inputReserve * maxZapBps / 10000)`.
4. Receive/authenticate the declared input into caller-only inventory.
5. Swap `floor(received / 2)` from that inventory through the same pool.
   Use `TickMath.MIN_SQRT_PRICE + 1` or `MAX_SQRT_PRICE - 1` by direction.
   Entry partial fills are allowed; actual unspent input stays caller inventory.
6. Enforce `abs(tickAfter - tickBefore) <= maxZapTickMove` around that swap
   only. This is not a bound on every square-root-price change.
7. Collect/project entry-swap fees belonging to incumbents, without another
   ratio swap, and freeze the post-swap incumbent snapshot under S1-ACC-07.
8. Add affordable full-range liquidity using **only caller inventory**.
9. Compute actual `G_i` and `q` under S1-ACC-07. Enforce positive output and
   the minimum, mint, book uncredited residual `J_i`, and finalize.

Neither gross compound deployment nor incumbent idle may enter the new-share
numerator. The SY reporting value is not an issuance input. No “optimal zap,”
off-pool price source, or manipulation-resistance claim is introduced.

### S1-OP-03: Paired redemption

Provide `redeemPair(shares, min0, min1, recipient, deadline)` and a preview
returning the two actual projected payouts. It uses S1-ACC-03 and transfers both
actual pool currencies, including raw ETH for a native pool. Reject invalid
recipients, missing shares, expired deadlines, and
unmet minima atomically.
The holder is `msg.sender`; there is no paired pretransfer flag or third-party
allowance-burn path. Select full/collection-only maintenance by S1-EXIT-01.

The paired methods are necessary additional product methods: the scalar SE and
SY interfaces cannot express two-input genesis or two-output redemption.
The existing many-to-one interface declares exact input rather than the
baseline's accepted portion of two maxima; the existing one-to-many interface
declares exact output rather than proportional share-input redemption. Do not
mislabel those semantics merely to reuse their names. The broader
`IStandardExchangeMultiAssetLiquidity` also includes unbalanced/exact-output
operations beyond this stage. Use the narrow paired interface specified here,
not a second implementation of the same accounting behind additional aliases.

### S1-OP-04: Single-token redemption

Map SE/SY share-to-currency exact-input routes to proportional withdrawal
followed by sale of only that withdrawal's unwanted currency:

1. Preflight S1-EXIT-01's maintenance choice and the complete final sale within
   every S1-QUOTE-01 budget, then
   perform S1-ACC-03 into a reserved exit allocation.
2. Disable liquidity re-addition for the exit sale.
3. Sell the complete unwanted allocation through remaining pool liquidity.
4. Payout equals allocated desired currency plus actual swap output.
5. Require full unwanted-input consumption and the final user minimum.
6. Transfer to recipient and finalize. Revert the complete transaction on any
   failure, including partial sale. If the selected candidate exceeds a work
   budget, return its exact budget error before burn or manager execution.
   Do not change the requested output form; the caller may choose paired withdrawal.

Remaining shareholders' assets cannot be sold merely to meet a withdrawing
holder's minimum. Swap-generated fees belonging to the remaining position
remain that position's fees; never credit them twice to the exiting holder.

### S1-OP-05: Compound

Under confirmed decision S1-P01, preserve the baseline sequence:

- Collect the position's accrued fees.
- Retain the full collection; no protocol split or external notify call.
- If either eligible idle balance exceeds `DUST = 1000` native units, compute
  the baseline affordable paired addition and the resulting leftovers.
- Convert token0 leftovers to token1 units with the baseline sequential floor
  operations; ties choose token0 as the sale input.
- Swap half the chosen leftover, capped by the baseline active-pool reserve
  estimate times `maxZapBps / 10000 / 4`.
- Preserve the zero-active-liquidity and small-leftover branches.
- Reinvest affordable paired inventory and leave residual amounts booked idle.
- Do not mint or burn shares.
- Complete S1-ACC-01's nonrecursive final fee checkpoint. This addition to the
  baseline sequence must be covered in the comparison ledger.

For `S = L = B0 = B1 = 0`, explicit compound is a successful no-op. Do not
collect an empty position or adopt unbooked assets. `DUST` is in raw units,
not decimals-normalized. `maxZapBps` controls both entry size and the
quarter-sized compound cap; `maxZapTickMove` governs only entry swaps.

The baseline's entry tick-movement guard is not automatically a compounding
guard. This PRD does not add a TWAP, independent oracle, keeper restriction,
new compounding slippage rule, or profitable-compound guarantee.

Explicit `compound()` and the mandatory pre-operation compound share one engine.
Deposits and standalone compound do not get the withdrawal-only fallback.
Calls while the manager is already unlocked fail explicitly before any nested
unlock; stage one does not inherit Wings' local-sleeve execution mode.

### S1-EXIT-01: Preflight-selected conditional withdrawal fallback

Withdrawal maintenance has two modes: `FullCompound` (default) and `CollectOnly`.
The latter collects all currently owed fees, performs no ratio swap or
reinvestment, and then redeems from the existing position and booked idle.
It is selected only by a deterministic view plan **before any manager mutation**.

The only permitted maintenance-obstacle reasons are:

| Reason | Exact preflight predicate |
| --- | --- |
| `MaintenanceWorkLimit` | The normal complete withdrawal would exceed any step, initialized-crossing or distinct-bitmap budget in S1-QUOTE-01, and the fresh collection-only candidate can be fully planned within all its budgets. This includes exhaustion during the final sale. |
| `MaintenancePriceLimit` | The planned nonzero maintenance ratio swap has no legal directional price interval at the current protocol boundary. A baseline zero-swap branch is not a failure. |
| `MaintenanceLiquidityLimit` | The calculated maintenance addition exceeds owned signed-liquidity, per-tick gross-liquidity capacity, or manager principal-delta limits. |
| `MaintenanceDeltaLimit` | A planned maintenance ratio-swap quantity or computed settlement delta does not fit the manager's supported amount/delta types. |

For the last three reasons, recompute the complete collection-only candidate
from the **original** state and use it only if valid. A failure of that candidate
is returned, not masked. Do not modify the normal compound amount or silently
clamp capacity instead of selecting the documented mode.

These are classified planner results, not caught external-call exceptions.
Insufficient custody, invalid accounting/configuration, inability to collect
fees, an already-unlocked manager, unexpected price/fee changes, transfer/
wrapper/payout failure, or actual manager revert is **not** a fallback trigger.
No retry after a partially executed compound; all unexpected failures revert.

Unmet caller minima and an unavailable final single-token sale do not by
themselves trigger a different maintenance mode. The caller may choose the
paired route. The collection-only candidate must satisfy the same final
sale/full-consumption constraints when single-token output is requested.

Expose the selected mode and reason in `previewWithdrawalMode` and emit
`WithdrawalMaintenanceSelected(mode, reason)` on successful withdrawals.
Standard and SY previews use that identical choice. There is no user flag
to bypass a valid full-compound plan.

This provides a bounded collection/removal path for paired exits blocked by
the listed maintenance obstacles, not an unconditional guarantee under token
freezes, corrupted custody, or unavailable PoolManager execution.

### S1-NATIVE-01: Native custody and interface adaptation

Keep the PoolKey unchanged: native ETH is `address(0)` in currency0. Positions,
swaps, basket arithmetic, and fee accounting use actual pool currencies.
Internally, native booked reserves are ETH measured in wei, not a fictitious
ERC-20 balance at address zero.

The canonical SE methods are nonpayable and accept ERC-20 addresses. Define
their currency faces in PoolKey order: `C0 = wrappedNative` when currency0 is
native, otherwise `C0 = currency0`; `C1 = currency1`. Preserve this order even
when the wrapper's address would sort differently. This is an interface mapping,
not a change to the underlying pool or share accounting.

- SE `C0 -> V` pulls or authenticates wrapped-native credit, unwraps exactly
  that credit, and applies the native-side zap. SE `V -> C0` performs the
  native-side withdrawal/sale and wraps exactly the allocated ETH payout.
- Standard SE methods reject raw `address(0)` routes and remain nonpayable.
  They do not consume resting ETH as input or claim to accept `msg.value`.
- Direct native single-token entry/exit uses the family's payable SY deposit
  and native-capable SY redemption described in S1-API-03. Paired methods use
  actual pool currencies under S1-OP-01 and S1-OP-03.
- `vaultTokens()` and registry contents use `[C0, C1]`; a native leg's local
  reserve is reported under its wrapped-native face in the same 18-decimal
  units. Family pool/basket/local queries retain raw-currency identity.
  Never count ETH and its temporary wrapped representation as two reserves.
  Registry pair identity hashes a sorted copy under S1-ARCH-05 independently
  of this view/accounting order.
- Require the two declared ERC-20 faces to be distinct. Consequently a
  native/that-same-wrapper pool is outside this mapping's supported domain;
  reject that collision explicitly rather than silently choosing a leg.
  This restriction does not prohibit ordinary native/ERC-20 pools.
- At each payable entry, reserve the complete `msg.value` before any compound
  or balance-derived quote. During wrapping/unwrapping, preserve the input,
  refund, and payout reservations. Receive callbacks are not fresh deposits.
- The diamond must accept ETH returned by the configured wrapper and the
  PoolManager during an authorized operation. Receiving ETH alone never mints
  shares or books a donation. Unsolicited or forced ETH remains unbooked.
- Empty-calldata ETH executes the proxy's receive path, not a facet receive
  selector. The active engine measures and attributes expected receipts.
- Immediately before every native debt, call `sync(Currency.wrap(address(0)))`,
  then `settle{value: exactDebt}()`, and validate the reported amount.
  Receive native credits through `take`. Never call ERC-20
  methods on address zero. Use the canonical ERC-20 settlement branch for
  the other currency.
- Native payouts/refunds use a checked value transfer without a fixed
  2,300-gas stipend. A rejecting or reentrant receiver cannot escape the
  shared operation guard; a failed transfer rolls back the operation.

The wrapper is an I/O adapter only. Do not leave a separate managed wrapped
inventory, introduce wrapper exchange-rate economics, or mint extra shares
for wrapping. Apply the same integer accounting and preview rules to native
and wrapped faces.

## 7. Standard proxy interface contract

### S1-API-01: Required surfaces

| Surface | Required behavior |
| --- | --- |
| ERC-20 + metadata | Canonical share supply, balances, allowances, transfers, 18 decimals, configured name/symbol. |
| ERC-2612 / ERC-5267 | Canonical permit and EIP-712 domain initialized for the diamond, not the facet/package address. |
| ERC-165 / diamond loupe / ERC-8109 introspection | Supplied by the diamond factory, not included in package-owned facet cuts; verify availability on the final proxy. |
| `IBasicVault` | `vaultTokens`, `reserveOfToken`, `reserves`; both ERC-20 currency faces in PoolKey order under S1-NATIVE-01. |
| `IStandardVault` | `vaultFeeTypeIds`, `contentsId`, `vaultTypes`, `vaultConfig`; real initialized Repo-backed values. |
| `IStandardExchangeIn` | Both exact-input methods and all four currency/share routes below. |
| `IStandardExchangeOut` | Both canonical selectors; under S1-P03, explicit `ExchangeOutNotAvailable()` with no transfer or state mutation. |
| `IStandardExchange` | Solidity aggregate type only. Declare concrete In and Out interface IDs; do not advertise an inheritance-only empty ID as a separate capability. Installed Out methods intentionally revert; interface presence is not route availability. |
| `IStandardizedYield` | All 16 native SY methods listed below, backed by the same public shares and execution engine. |
| Family query/operation interface | Pool identity, wrapped-native binding, `rateAsset`, ticks, owned liquidity, booked local reserves, raw basket, zap parameters, paired entry/exit and previews, donation, compound. |
| PoolManager callback | Authenticated `unlockCallback`; installed but not a public money-entry route. |

Basic-vault reserve queries report **booked local custody**, consistently with
the shared Repo-backed implementation, not whole-position liquidation value.
The family basket/position queries report deployed ownership. Unknown reserve
queries return zero, matching the canonical basic-vault implementation.
During a family operation these unchanged shared selectors return the last
committed snapshot, not live executable quotes; see S1-SEC-01.

Do not install the empty `StandardVaultTarget` implementation. The functional
shared implementation is `MultiAssetStandardVaultTarget` via its facet.

### S1-API-02: Route table

Here `V` is the diamond/share token and `C0`, `C1` are the ERC-20 currency
faces defined in S1-NATIVE-01. The native face wraps/unwraps at the boundary.

| Input | Output | Exact-input meaning | Empty supply |
| --- | --- | --- | --- |
| C0 | V | Token0 zap deposit. | Revert; paired bootstrap required. |
| C1 | V | Token1 zap deposit. | Revert; paired bootstrap required. |
| V | C0 | Proportional withdrawal then token1 sale. | No valid redemption. |
| V | C1 | Proportional withdrawal then token0 sale. | No valid redemption. |

Currency-to-currency swaps, V-to-V, identical-currency routes, and unrelated
tokens are unsupported. Token discovery describes structurally supported
currencies, not a promise that every amount or unbootstrapped state is executable.

Standard exact-input minima and deadlines apply in addition to baseline zap
limits. Input share authority is the caller for ordinary SE redemption, or
authenticated vault-held share credit for supported pretransfer/SY paths.
No caller can burn another holder's shares.

### S1-API-03: Native SY mapping

Install `deposit`, `redeem`, `previewDeposit`, `previewRedeem`, `getTokensIn`,
`getTokensOut`, `yieldToken`, `assetInfo`, `exchangeRate`, `isValidTokenIn`,
`isValidTokenOut`, `getRewardTokens`, `accruedRewards`, `rewardIndexesCurrent`,
`rewardIndexesStored`, and `claimRewards`.

- For two-ERC-20 pools, `getTokensIn/Out` return `[C0, C1]`. For native pools
  return `[address(0), C0, C1]`: raw ETH and its wrapped face are alternative
  I/O forms of the same reserve, not additional basket assets.
- Derive validity from these lists. Raw address zero is valid only for native
  pools; a wrapper configured as an actual ERC-20 pool currency remains an
  ordinary ERC-20, not a native alias.
- `yieldToken()` returns the diamond address. SY uses the same public shares;
  do not deploy a wrapper or mint a second receipt.
- Deposits/redemptions execute the same exact-input engine as SE routes with
  an explicit native-versus-wrapped settlement mode.
- `redeem(..., burnFromInternalBalance=true)` uses canonical contract-only,
  vault-held share validation. False-flag redemption burns the caller's shares.
- Unsupported-token previews retain the shared SY behavior of returning zero;
  unsupported-token execution reverts. Valid-token previews do not disguise
  genuine execution failures as successful zero outputs.
- Native `deposit(receiver, address(0), amount, minimum)` is supported only
  for native pools and requires `msg.value == amount`. Reserve it before the
  mandatory compound. ERC-20/wrapped-native deposits require zero value.
  Native `redeem(..., address(0), ...)` pays raw ETH; the wrapped face pays
  wrapped native. Native previews use the same amounts and economic engine
  as the wrapped face without requiring value in a view call.
- Override the current shared SY implementation's blanket nonzero-value
  rejection in this family only. Route native operations internally rather
  than self-calling a nonpayable SE selector. Preserve caller identity,
  shared guards, internal-share validation, minima, and canonical SY events.
  Other families' native-payment policy remains unchanged.
- Use the shared virtual `_standardRoute` and `_redeemVaultHeld` seams where
  suitable; native support does not require duplicating the entire public
  redeem method. Native and equivalent wrapped previews return the same
  economic amounts, differing only in delivery representation.
- External reward arrays are empty. LP fees are auto-compounded backing, not
  separately claimable rewards. Use the shared empty reward semantics/events.

### S1-API-04: Optional integration surfaces

Do not claim `IERC4626`: there is no single underlying token representing this
two-currency reserve.

Stateful transition-quote interfaces, external-state projection adapters, and
unlock-context quote extensions are not required merely because Wings exposes
them. They are out of stage one unless an identified consumer is explicitly
added to scope. No fake state blobs, zero-value success implementations, or
unsupported advertised interface IDs.

`IRateProvider.getRate()` is also not implied by `IStandardExchangeIn/Out`.
Stage one does not install a Balancer rate provider or migrate rate consumers.
Any later such adapter must explicitly define its normalized single-share
withdrawal-and-sale quote; it must not equate that exit quote with issuance
accounting or silently reuse SY's accounting rate.

### S1-API-05: Family ABI and execution signals

Use these typed signatures. Amount pairs follow actual PoolKey currency order.
Define the enums on the family interface:
`WithdrawalMode { FullCompound, CollectOnly }`;
`MaintenanceReason { None, MaintenanceWorkLimit, MaintenancePriceLimit,
MaintenanceLiquidityLimit, MaintenanceDeltaLimit }`.

```solidity
function depositPair(uint256 amount0Max, uint256 amount1Max, uint256 minShares,
    address recipient, uint256 deadline) external payable returns (uint256 shares);
function previewDepositPair(uint256 amount0Max, uint256 amount1Max)
    external view returns (uint256 shares, uint256 used0, uint256 used1);
function redeemPair(uint256 shares, uint256 min0, uint256 min1,
    address recipient, uint256 deadline) external returns (uint256 amount0, uint256 amount1);
function previewRedeemPair(uint256 shares)
    external view returns (uint256 amount0, uint256 amount1);
function donate(address token, uint256 amount) external payable;
function compound() external returns (uint256 fees0, uint256 fees1);
function poolManager() external view returns (IPoolManager);
function poolKey() external view returns (PoolKey memory);
function wrappedNative() external view returns (address);
function rateAsset() external view returns (address);
function tickLower() external view returns (int24);
function tickUpper() external view returns (int24);
function positionLiquidity() external view returns (uint128);
function localReserves() external view returns (uint256 amount0, uint256 amount1);
function basket() external view returns (uint256 amount0, uint256 amount1);
function maxZapBps() external view returns (uint16);
function maxZapTickMove() external view returns (int24);
function previewWithdrawalMode(uint256 shares, bool paired, address tokenOut)
    external view returns (WithdrawalMode mode, MaintenanceReason reason);
function previewZapCredit(address tokenIn, uint256 amountIn)
    external view returns (uint256 shares, uint256 credit0, uint256 credit1,
        uint256 uncredited0, uint256 uncredited1);
```

For paired mode query require `tokenOut == address(0)` as a sentinel; otherwise
accept a supported raw-native/SY or ERC-20-face output. The boolean disambiguates
paired output from single-token ETH output. Return a mode only for a valid
complete economic plan, not a promise about caller-specific funding.

`previewZapCredit` accepts SY input forms and uses the same planner. It exposes
final share credit and uncredited residual, not an additional deposit route.
Emit a corresponding `ZapCredit` event with actual input, credit pair,
residual pair, and minted shares. Emit `WithdrawalMaintenanceSelected(mode,
reason)` once on each successful withdrawal.

Pin selectors through the canonical verification workflow, not handwritten
hex values. Build a final selector/interface-to-facet-to-Repo manifest. The
complete 16-method SY surface and 20 reused selectors remain unchanged.

## 8. Quotes and SY accounting value

### S1-QUOTE-01: Execution-equivalent previews

The four standard exact-input routes, paired previews, and SY previews must
project the same operation from the same initial state and return the actual
integer output. Include:

1. Fee checkpoints and the full/collection-only maintenance choice.
2. Compounding ratio swap, actual pool fee, tick crossings, and resulting price.
3. Position liquidity added by compounding.
4. Caller-only entry credit or removal allocation and all floor/ceiling operations.
5. Entry zap tick/size bounds.
6. Exit sale against liquidity remaining after the holder's removal.
7. Partial-fill failure and zero-supply/terminal branches.

The original `previewDeposit`/`previewRedeem` are not sufficient for these
requirements. Do not use a spot quote, whole-book liquidation divided by supply,
or an off-chain quoter as a substitute for an on-chain view.

Use canonical V4 tick/swap math and one shared economic model for execution and
projection. Project slot0, active liquidity, tick bitmap/boundaries, LP and
directional protocol fees, global/inside/outside fee growth, owned liquidity,
position checkpoints, and categorized local inventories. Later simulated swaps
see preceding additions/removals and fee changes, not untouched live state.
No quote-only storage mutation or unauthorized callback simulation.

Apply all three fixed, family-wide candidate limits:

| Metric | Limit | Counting and failure |
| --- | ---: | --- |
| `QUOTE_MAX_SWAP_STEPS` | 64 | Every canonical swap-loop iteration, including empty-word/zero-liquidity progress. Reject required iteration 65 before executing it with `QuoteWorkExceeded(65,64)`. |
| `QUOTE_MAX_INITIALIZED_TICK_CROSSINGS` | 12 | Every actual projected initialized-tick crossing, including crossing the same tick again in another swap. Reject required crossing 13 before reading/mutating its tick overlay with `QuoteTickCrossingsExceeded(13,12)`. |
| `QUOTE_MAX_BITMAP_WORDS` | 16 | Distinct bitmap-word keys in the candidate cache, including the owned full-range boundary words. A repeated read does not increment it. Reject a required seventeenth key before fetching it with `QuoteBitmapWordsExceeded(17,16)`. |

Counters are shared across maintenance and the entry/final-sale suffix, never
reset between swaps in one candidate. Equality is permitted for every metric.
Iteration exhaustion takes precedence before a new iteration; within an
iteration, bitmap admission precedes swap arithmetic and initialized-crossing
admission. Count a crossing only when the price actually reaches that initialized
tick, not merely when its bitmap bit is observed. The two boundary tick records
are additional fixed cache entries, not crossings. A valid candidate therefore
needs at most 14 distinct tick records and 16 bitmap records.

These are deterministic operation-domain limits, not branches on gasleft or
caller-supplied transaction gas. Measured gas acceptance remains separately
required by S1-GAS-01. Tightening a proposed bound to satisfy that acceptance
must be reflected here and in its tests before shipping, never hidden in code.

Entry and standalone compound have one full-compound candidate and reject on
exhaustion. Withdrawals have at most two candidates: full and, only under
S1-EXIT-01, collection-only from original state. Each gets fresh counters for
all three limits; at most 128 iterations, 24 crossings and 32 distinct-word
admissions occur across both attempted candidates. A failed full candidate
yields no state/output to the second. If collection-only planning fails, return
its economic-domain error; never return a partial quote. A paired
collection-only candidate has no swaps.

Preflight the complete plan before any compound or ERC-20 pull. Native value
received on entry stays reserved outside the pre-operation book. Actual
execution validates the selected mode and settles actual manager deltas.
Unexpected pool/fee changes during token/wrapper interactions invalidate the
plan: revert `EconomicStateChanged()` rather than consuming a stale quote,
changing mode mid-execution, or reallocating unexpected fees.

Parity concerns economic outputs/domain failures from unchanged
pool/book/configuration state. It does not predict caller authorization,
allowances, staged-credit availability, receiver acceptance, attached value,
or deadline validity. Execution checks those separately. User minima/deadlines
remain mandatory; views need not simulate arbitrary receiver code.

### S1-GAS-01: Shared supported execution envelope

The release engineering ceiling is 12,000,000 gas for each supported public
money/maintenance call, including conservative transaction overhead, on Ethereum,
Base and Robinhood. Local cold-call tests reserve 100,000 gas for intrinsic and
the fixed money-method calldata, so their measured call bodies must not exceed
11,900,000. This is not a gasprice constraint or permission to raise chain limits.
Deployment components retain their separate normal code/initcode checks; a
multi-transaction deployment script is not one money-operation budget.

Use 5,000,000 gas as the local preview acceptance ceiling, including mode and
paired-exit queries and both attempted candidates. This is an engineering limit,
not a claim that every third-party RPC permits it; name any unverified provider
cap in the release report. Execution and preview must make the same deterministic
admission decision regardless of the caller's supplied gas.

Measure supported boundary combinations, not only empty or ordinary pools:
initialized crossings with both fee-growth currencies, empty-word progress,
maintenance plus entry/final-sale work, failed full plus successful fallback,
both rejected candidates, native/wrapped delivery, and terminal exits.
Reject over-budget operations during preflight before executing manager actions,
pulling ERC-20 input or burning shares. Rejected previews return the same exact
work error, not a successful zero or partial quote.

Paired withdrawals must remain affordable when only swap complexity blocks full
maintenance: its bounded rejected candidate is followed by a fresh collection-only
plan with no swaps. Token freezes, failed receipts/payouts, invalid accounting and
unavailable manager execution remain real failures. No unbounded receiver/token
program can be guaranteed a fixed gas cost; use supported reference tokens and
legitimate boundary receivers in the engineering tests without adding an allowlist.

All routes remain atomic. No pending claim, cancellation state, delayed settlement,
keeper authorization or multi-transaction withdrawal is introduced. A caller that
requests one currency receives that currency or a revert, never an implicit pair.

### S1-QUOTE-02: SY asset identity and accounting rate

This is the confirmed S1-P06 valuation policy for a basket without one fungible
underlying LP token:

- `assetInfo()` reports `TOKEN`, configured ERC-20-face `rateAsset`, and its
  validated initialization-time decimals. A native reserve leg is denominated in the bound wrapped
  native with 18 decimals; no metadata call is made to address zero.
- Define `A_i = N_i(P,L) + B_i + F_i`, with `F_i` the current claimable position
  fee from canonical fee-growth-inside minus the stored position checkpoint,
  using modular subtraction and floor rounding. Include each fee once before
  simulated compounding; exclude unbooked funds and pending/reserved input.
- `exchangeRate()` reports **raw rate-asset units per 1e18 raw share units**,
  not a human-normalized whole-token/whole-share WAD price.
- With `r = P / 2^96`, value in raw token1 units is
  `A1 + floor(A0 * r^2)`; value in raw token0 units is
  `A0 + floor(A1 / r^2)`. These are exact rational definitions: floor once
  after complete currency conversion, then floor once at the final rate.
  Use full-precision/multiword arithmetic or a proven equivalent decomposition;
  two sequential floors are not assumed equivalent. Avoid intermediate
  `P*P` overflow; a mathematically unrepresentable final value reverts explicitly.
- For target raw value `Vraw` and positive raw share supply `S`,
  `exchangeRate = floor(Vraw * 1e18 / S)`.
  Asset decimals affect metadata/rendering, not this formula. Canonical
  `SYUtils.syToAsset(rate, shares)` must return raw asset units.
- Example: `Vraw = 1e6`, `S = 1e18`, and six-decimal rate asset gives rate
  `1e6`; one whole share converts to `1e6` raw asset units, not `1e18`.
- At zero supply return zero: no established share-to-asset conversion exists
  before paired genesis. Do not invent a 1:1 target-token bootstrap price for
  geometric-mean shares.

This rate is price-sensitive and is neither an execution guarantee nor a
manipulation-resistant oracle. It is never an input to S1-ACC-02 or S1-OP-02
issuance. SE/SY redemption previews remain actual withdrawal-and-sale quotes.
Document the distinction on the public query interface.

## 9. Deployment, security, and observable behavior

### S1-PKG-01: Package lifecycle

Implement `IDiamondFactoryPackage` and `IStandardVaultPkg` using current
canonical signatures. Include package metadata, facet addresses/interfaces/
cuts, diamond configuration, argument processing, deterministic salt,
initialization, and lifecycle callbacks.

Package facet lists and cuts contain only the reusable facets in S1-ARCH-04
and the family-specific facets. Factory-supplied facets are excluded. The final
proxy's persistent selector set is the disjoint union of factory-owned and
package-owned selectors; never require it to equal the package cut alone.

Facets and package construction use CREATE3/FactoryServices. The package is
registered through `indexedexManager.deployPkg` or a typed helper using that
path. Instances deploy through the registered package/registry `deployVault`.
Do not bypass it with a direct diamond factory call in production or tests.

Initialize ERC-20 metadata, EIP-712 domain, family state, basic vault token
declarations, and standard vault type/contents data in the proxy. All
economically relevant immutable arguments participate in deployment identity.
Validate direct package misuse, reinitialization, wrong registry callers, and
invalid components. Keep package storage and proxy storage distinct.

### S1-SEC-01: Shared operation guard and settlement

All money methods, compound, donation, and callback execution share one
cross-facet operation guard. The money sequence is validation, guard, input
isolation, complete preflight, selected maintenance, execution, reservation
settlement, shared reserve publication, then guard release.

| Read class | During a family operation |
| --- | --- |
| Family basket/position/local-book economic queries, credit/mode queries, paired/SE/SY previews, SY exchangeRate | Revert `ReentrantOperation()`. |
| Unchanged `IBasicVault` reserve queries | Return last committed shared-Repo snapshot, published after external payout/refund interactions. |
| Canonical token balances/supply/allowances/metadata/domain and static configuration/discovery | Retain canonical behavior; not a coherent in-flight NAV view. |

Do not modify reusable facets or the proxy to install a global read guard.
ERC-20 transfers cannot create reserve credit from booked backing. Vault-held
share pretransfers retain the canonical atomic-integration caveat; they are
not owner-attributed escrow across transactions.

Authenticate callbacks against the bound PoolManager, active operation,
expected operation kind, and payload commitment. Reject unsolicited, replayed,
or nested callbacks. Commit `keccak256(abi.encode(operation, payload))` before
each unlock, consume it once at callback entry, and hold the family guard
through payout/refund. Check `TransientStateLibrary.isUnlocked` before starting
a new unlock and revert `ManagerAlreadyUnlocked()`; no local-sleeve fallback.
Settle actual signed deltas with the canonical ERC-20
sync/transfer/settle and take sequence, or the native value-settlement branch
in S1-NATIVE-01; check settlement and observed receipts.
Never count collected fees separately when they are already included in the
caller delta.

### S1-SEC-02: Registry disable and token boundaries

Disabled vaults reject new paired/SE/SY issuance and explicit donation. This
revision treats disable as stopping new capital contributions, not just new
shares; it also removes donation as a possible maintenance-funding avenue.
Standalone compound remains permissionless while disabled. Neither donation
nor standalone compound is a guaranteed recovery mechanism. Existing holders retain paired
and supported single-token exits; mandatory maintenance needed by exits must
not be blocked solely by the inbound disable flag.

Reject zero amount/zero recipient and vault-self payout/mint recipients for
money operations. Enforce actual delivered minima. A failed transfer, callback,
swap, limit, or payout rolls back the whole operation.
Deadline equality is allowed; expiry means `deadline < block.timestamp`.

FoT and rebasing underlyings are forbidden under repository law. Non-18-decimal
currencies are supported. Pause/blacklist risk is accepted; no runtime issuer
policy detector or configuration allowlist is introduced.

### S1-OBS-01: Events and errors

Use canonical ERC-20 and SY events, canonical SE errors where applicable, and
family events for paired operations, donations, and compounding. Family event
payloads distinguish received input, deployed amounts, actual share output,
withdrawal allocations, swap proceeds, and actual payout where relevant.

Do not emit hypothetical protocol fees or claim success for a failed/partial
operation. Baseline compiler-generated revert payloads and permissive
initialization behavior are not compatibility requirements for the new family.
Record every deliberate error/validation change in the implementation's
comparison ledger. Derive selectors/interface IDs through the repository's
canonical verification workflow.
Both exact-output methods revert `ExchangeOutNotAvailable()` before any action.
Unsupported scalar exact-input routes use `InvalidRoute`; unbootstrapped zaps
use `ExchangeInNotAvailable`; unmet SE minima use `MinAmountNotMet`; expiry
uses `DeadlineExceeded`. Preserve shared SY-specific validation errors.
Define family errors `ReentrantOperation()`, `ManagerAlreadyUnlocked()`,
`EconomicStateChanged()`, `InvalidAccountingState()`, `ZeroPayout()`,
`QuoteWorkExceeded(uint256 steps, uint256 limit)`,
`QuoteTickCrossingsExceeded(uint256 crossings, uint256 limit)`,
`QuoteBitmapWordsExceeded(uint256 words, uint256 limit)`, and `IssuanceDisabled()`
on the family interface. A fallback reason is not an ignored execution error.
`compound()` reports total fees realized by all of its checkpoints, once.

## 10. Acceptance matrix

Each row is an independent acceptance obligation. Combine test implementations
where appropriate, but do not replace a row with a generic smoke test.

| ID | Acceptance evidence |
| --- | --- |
| S1-A01 | Registered real package deploys a usable diamond; registry finds it by both declared ERC-20 currency faces and types, including native-pool wrapped-face discovery. |
| S1-A02 | Identical deployment identity predicts the same address; each relevant immutable argument changes identity as intended. |
| S1-A03 | Invalid pool keys, uninitialized/hooked pools, invalid rate asset, invalid zap bounds, invalid wrapped-native binding, and duplicate ERC-20 currency faces reject; valid native/ERC-20 pools deploy. |
| S1-A04 | Reinitialization, direct package misuse, wrong-registry processing, and invalid facet components reject. |
| S1-A05 | Metadata, 18-decimal shares, permit, and EIP-712 domain are correct on the live proxy; domains isolate instances. |
| S1-A06 | Target/interface-derived controls equal package-owned facet declarations and cuts; every package selector is callable on the live proxy. The final persistent loupe surface equals the disjoint union of package-owned and factory-owned selectors, not the package cut alone. |
| S1-A07 | Basic and standard vault discovery are initialized, ordered, truthful, and distinguish booked local reserves from deployed principal. |
| S1-A08 | Fresh paired genesis mints the complete geometric-mean output to the recipient, with zero dead/virtual shares. |
| S1-A09 | Zero genesis inputs, zero mint, zero fundable liquidity, checked product overflow, and unmet actual-share minimum reject atomically. |
| S1-A10 | Paired candidate issuance uses the limiting reserve ratio/ceiling accepted amounts; actual shares apply the S1-ACC-07 credit cap. Unused maxima remain with caller or are refunded in native form. |
| S1-A11 | One-sided reserve branches consume only the supported leg; positive supply with both reserves zero rejects. |
| S1-A12 | Deposits compound incumbent fees before snapshot; caller input is excluded from that compound. |
| S1-A13 | Both zap directions use the half-swap, post-swap incumbent checkpoint, caller-only addition, actual removable-principal growth, and final S1-ACC-07 issuance equation. |
| S1-A14 | Empty supply/basket zap, zero input, size cap boundary, and tick-movement boundary behave exactly as specified. |
| S1-A15 | For every admitted positive-supply entry and each positive reserve, assert `q*R_i <= S*C_i` with independent wide-integer arithmetic at the same P*. Incumbent inventory/fees cannot enter C_i. Exercise imbalanced idle, partial entry fills, residuals, and addition rounding; no tolerance silently permits dilution. |
| S1-A16 | Paired redemption removes the proportional position and idle allocations without 10-basis-point retention. |
| S1-A17 | Partial redemption dust remains with holders; no second fee allocation or donated share supply appears. |
| S1-A18 | Both single-token exit directions sell only the withdrawing allocation and enforce actual output minima. |
| S1-A19 | Partial final exit sale reverts atomically. Paired exit needs no final sale and succeeds through a valid collection-only plan when a listed maintenance obstacle blocks full compounding; unexpected failures still revert. |
| S1-A20 | Last-share paired exit empties the owned position and booked basket; a later paired genesis works without capturing unbooked balances. |
| S1-A21 | Last-share single-token exit with external liquidity succeeds; insufficient remaining liquidity reverts without burning shares. |
| S1-A22 | Compound retains all LP fees, performs no external fee-manager call, and never changes share supply. |
| S1-A23 | Dust equality, leftover tie direction, zero active liquidity, quarter-cap, and no-swap compound branches are covered. |
| S1-A24 | Final checkpoints include compound-swap fees with both positive-add and zero-add branches. Entry-swap fees stay incumbent-owned; exit-sale fees stay with remaining liquidity. Whole-position fee receipts never become a partial exiter's principal. |
| S1-A25 | Four supported exact-input routes execute; unsupported directions/tokens reject. |
| S1-A26 | Both exact-output selectors are installed and explicitly reject under S1-P03 without transfer, burn, mint, or manager mutation. |
| S1-A27 | Every SE and paired preview matches execution exactly from identical state, including fees, compounding, crossing ticks, and terminal exits. |
| S1-A28 | Exact step 64/65, crossing 12/13 and distinct-word 16/17 limits, shared across every swap in a candidate, select identical preview/execution failures or fallback. At most two fresh withdrawal candidates (128 iterations, 24 crossings and 32 word admissions); rejected state never leaks. Prove the iteration guard independently when another metric necessarily rejects first in a valid whole operation. No partial valid quote. |
| S1-A29 | All 16 SY methods are installed; execution and previews agree with SE, and no second receipt token exists. |
| S1-A30 | SY internal-balance redemption validates caller class and vault-held shares; invalid token/native payment behavior matches section 7. |
| S1-A31 | Empty SY rewards arrays/events are truthful; LP fees cannot be claimed twice as external rewards. |
| S1-A32 | Canonical SY helpers convert raw shares to raw assets using `floor(Vraw*1e18/S)` for 6/8/18-decimal assets, with independent exact-rational currency valuation. No extra decimal scale or guaranteed nonzero difference from rounded exit proceeds. |
| S1-A33 | Zero-supply SY rate is zero; no synthetic 1:1 bootstrap target value is used for issuance. |
| S1-A34 | False-flag input pulls enforce exact receipt; existing reserves and unrelated transfers never fill a short delivery. |
| S1-A35 | True-flag input from a code-less or construction-time caller rejects with the canonical pretransfer error. |
| S1-A36 | Contract true-flag input without unbooked funds cannot mint or spend booked backing; short credit rejects. |
| S1-A37 | Excess pretransfer processes exactly the declared input, refunds nothing, and leaves the excess unbooked. |
| S1-A38 | Explicit donation adds backing with no shares; unsolicited balances remain separate through compound, entry, exit, and restart. |
| S1-A39 | Authentic callback succeeds; wrong manager, unsolicited payload, replay, reentrancy, and cross-facet attacks reject. |
| S1-A40 | Already-unlocked PoolManager context rejects before attempted nested unlock; no stale local-sleeve fallback is used. |
| S1-A41 | Actual manager liquidity, token custody, booked balances, share supply, and emitted amounts reconcile after every operation. |
| S1-A42 | Disabled vault rejects issuance/donation, allows public compound, and permits paired and executable single-token/SY exits with the same fallback rules. No fee/maintenance bypass caused solely by disable. |
| S1-A43 | Transfer/payout failure and unmet minima roll back earlier swaps, removals, burns, and transfers. |
| S1-A44 | Mixed 6/8/18-decimal currencies work; real forbidden FoT behavior does not produce unsupported shares or payouts. |
| S1-A45 | Interior, both exact boundaries, and outside-range principal/cost amounts agree with manager receipts. Capacity/signed limits select fallback only for listed withdrawal-maintenance failures; other invalid quantities reject. No unapproved clamping. |
| S1-A46 | Sequence tests assert exact supply conservation, no unbooked adoption, donation without mint, S1-ACC-07 per-leg issuance non-dilution, and each exiter's exact proportional allocation before sale. Report external price/fee effects and entrant residual donations separately; measured trading profit is not proof of an ownership failure or an oracle defense. |
| S1-A47 | Two instances sharing facets cannot affect each other's state, balances, approvals, position keys, or initialization. |
| S1-A48 | Normal deployed code-size limits pass, no `via_ir`, no lowered fuzz/invariant depth, and fresh artifact deployment uses the edited code. |
| S1-A49 | Native paired genesis/deposits accept exactly the native maximum, exclude it from pre-entry compound, and refund only the unused portion; wrong value and refund failure roll back. |
| S1-A50 | Native SY entry/exit and wrapped-native SE/SY routes have equal economic outputs from equal states; only the requested delivery form differs. |
| S1-A51 | Native manager settlement, wrapper callbacks, ETH receipt, and actual payable proxy selectors work through real registered diamonds; no ERC-20 call targets address zero. |
| S1-A52 | Unsolicited/forced ETH, pending value, refunds, and temporary wrapped balances never become duplicate backing or free deposit credit. |
| S1-A53 | Rejecting and reentrant native payout/refund receivers roll back the whole operation; legitimate contract receivers are not limited to a fixed stipend. |
| S1-A54 | Native last-share paired exit empties booked ETH/token reserves and owned liquidity; native rebootstrap excludes old unbooked ETH. |
| S1-A55 | Native and wrapped donation forms credit the same reserve once; wrong `msg.value`, native calls on ERC-20-only pools, and zero-address standard SE routes reject. |
| S1-A56 | The five reused facets in S1-ARCH-04 provide exactly their 20 distinct package-owned selectors and canonical interface declarations. No combined permit facet, duplicate token/SY selector, or factory-provided facet appears in package inputs, addresses, or cuts. |
| S1-A57 | Factory-installed ERC-165, loupe, and ERC-8109 remain callable without package cuts; the temporary deployment hook follows the factory lifecycle. Shared Repo initialization is correct on each proxy, and permit execution, nonce advancement, replay rejection, and domain isolation work through the reused facets. |
| S1-A58 | Native pair discovery succeeds when wrapped-native face sorts after the other currency: registry hash uses sorted copy, while token/reserve views retain PoolKey face order. |
| S1-A59 | Callback reads enforce the selector policy: new economic reads reject, unchanged basic reserves return last committed snapshot, and canonical token/domain reads retain behavior. |
| S1-A60 | Native debt after outstanding ERC-20 sync explicitly resets sync before settlement; actual manager deltas close to zero. Empty-calldata receipts bypass family facets and are attributed only by the active engine. |
| S1-A61 | Every maintenance fallback reason has a real-manager reachable case or an independently demonstrated unreachable-domain proof; mode/reason in preview, event, and execution agree. A valid full candidate always wins. |
| S1-A62 | Fallback never catches actual manager, token, wrapper, custody, fee-collection, state-change, or payout errors. Failed collection-only plans revert atomically without partial compound execution. |
| S1-A63 | Caller minima or unavailable final exit sale alone do not select fallback. Paired mode and single-token ETH mode are unambiguous in the mode-query ABI. |
| S1-A64 | Entry credit controls distinguish G_i, paired J_i, zap uncredited J_i, and incumbent fees. Accepted-input/addition costs exceed removable growth only at entrant expense; final minimum checks use q, not qQuote. |
| S1-A65 | At every stable boundary all local custody categories reconcile and reservations are zero. Terminal generated receipts are paid to the last holder; unsolicited funds are neither paid nor adopted on restart. |
| S1-A66 | Clean empty compound is a no-op. Zero-total-output burns reject; one-sided positive paired outputs succeed. Tiny genesis/donation sequences preserve the exact accounting predicates without dead/virtual shares. |
| S1-A67 | Nonzero protocol fees, initialized crossings, empty-word progress, and position checkpoint changes are modeled across compound plus entry/exit. Token/wrapper-induced plan changes cause `EconomicStateChanged`, not stale execution. |
| S1-A68 | Final proxy has no operational ownership, diamondCut, rescue, ERC-4626, or excluded integration selectors. Manifest covers all family ABI, shared selectors, IDs, and Repo initialization; package bindings participate in deterministic identity. |
| S1-A69 | Zero fee-type IDs work through the real registry without an invented fee fallback. DUST remains 1,000 raw units, zap parameters have no silent defaults, and metadata uses validated cached decimals. |
| S1-A70 | Supported worst-case candidate combinations, native/wrapped paths and collection-only paired exits satisfy the 12M transaction engineering ceiling (11.9M measured call body plus 100k overhead) and 5M local preview ceiling with normal code/initcode limits. Former 512-step dense states reject single conversion early and still permit valid paired fallback. Report provider-specific read caps not independently verified. Do not relax gas tests or hide changed work bounds. |

### S1-TEST-01: Fixture and comparison discipline

The new family's acceptance tests use real registered diamonds, real manager/
registry infrastructure, and the existing production-faithful PoolManager.
Follow `CraneTest -> IndexedexTest -> family TestBase`. Derive new reusable
fixtures from the appropriate shared bases, not a concrete Wings vault.

Keep standalone PairToken characterization separate. When comparing to it,
reuse `test/foundry/spec/pairtoken-baseline/harness/PairTokenTestBase.sol` and
the current `ScriptedDependencies.sol` API. Read them before writing test code
and coordinate shared harness changes with any active owner. Use fresh real
PairToken instances; no SUT subclassing, storage injection, or bytecode etching.
Do not rewrite this fixture or replace real new-family acceptance tests with
scripted-manager tests.

Maintain a comparison ledger with **preserved**, **intentional deviation**,
**unsupported scope**, and **new capability (no baseline counterpart)**.
Exact end-state
equality to the original cannot be assumed after removing its fees/dead shares.
Use independent arithmetic and real manager receipts for the changed economics.
Never weaken the original suite or patch expected values to disguise divergence.

Use existing Behavior libraries for facet/package/standard declarations.
Sequence tests through actual public routes; no privileged synthetic issuance.
Fuzz inputs and operation sequences with bounded valid domains. Assert exact
balances, supply, liquidity, events, and errors. No fixed sleeps or timing luck.

## 11. Implementation completion criteria

Stage one is complete only when:

1. Implement the confirmed S1-P01 through S1-P07 choices and this revision's
   explicit equations/fallback predicates. Any necessary change to them is a
   PRD revision, not an implementer-selected alternative.
2. All required surfaces are installed on registry-deployed proxies.
3. All supported operations, previews, genesis, final exit, and rebootstrap work
   against the real PoolManager, with all acceptance rows evidenced.
4. S1-A15/A46/A64 demonstrate the specified ownership predicates with independent
   controls; all fallback and fee cases have evidence. This is not a claim of
   manipulation immunity, universal exit availability, or absence of external
   trading profit. No reporting-only row substitutes for an accounting assertion.
5. Relevant diagnostics, artifact-first builds, focused family tests, and
   required hermetic integration tests pass. Explain pre-existing failures
   separately; do not change them to green.
6. The implementation report records deviations, runtime sizes, tested commands,
   remaining integration limits, and the paths later stages should reuse.

After production edits, use the current artifact workflow:
`python3 scripts/forge-artifacts.py test <edited-source.sol> --test-root <test-file-or-directory>`.
Build runtime creation artifacts before tests/scripts; do not invent a package
Foundry profile or clear shared caches. Follow repository cold-compile patience
and worktree cache-seeding rules.

The document amendment needs consistency checks, not prose-pinning tests.
Its accompanying authorized code changes require the full validation above.

## 12. Out of scope

- Deployment, migration or replacement of existing vaults in this revision.
- A second internal reserve share supply or outer SE wrapper.
- Wings, concentrated active management, target-token sleeves, or Wings rebalance.
- Changing or deleting the baseline, Wings, retired-family rules, or unrelated packages.
- Migrating existing users, deployed liquidity, consumers, or frontends.
- External PairToken investments, multi-pool routing, independent price oracles,
  TWAP construction, or a new manipulation-protection design.
- Fees excluded by S1-D03, virtual/dead shares, or administrative rescue of backing.
- Exact-output execution under confirmed S1-P03.
- DETF buffer integration, transition-quote extensions, or a Balancer rate-provider deployment.

Those are later decisions, not unfinished pieces to hide inside stage one's
implementation.
