# NetNet–Pendle DETF — Implementation and Test Plan

## Document control

| Field | Value |
| --- | --- |
| Version | 0.10 — owner closes creator binding and L4: creator PkgArgs, inherited late-excess unlock, no NFT retirement operation |
| Authored | 2026-09-27 |
| Product authority | [NETNET_PENDLE_DETF_PRD.md](./NETNET_PENDLE_DETF_PRD.md), v0.33; current operative requirements supersede historical narratives |
| Source analysis | [All-item council closure audit](../../../research/netnet-prd-closure-audit-2026-09-27/COUNCIL_CONSOLIDATION.md), including attributed originals/cross-reviews |
| Tracking | [PRD_OPEN_QUESTIONS.md](./PRD_OPEN_QUESTIONS.md) |
| Status | **Expanded in place after completed plan-completion council review. Not yet an unconditional executable handoff: §2 separates actual external prerequisites from specifically demonstrated unresolved paths. No implementation or tests executed.** |
| Authorization | This document authorizes no code, shell/tests, deployment, transactions, migration, instruction changes or production operation. Execution requires a separate authorized task. |
| Scope | Custom DETF, funded staking token, NFT, per-NFT native-bond holder Package, shared Pendle custody/Weighted HLP hook, full-feature tax-aware V2 SE, reusable SY rate provider, two arithmetic TWAPs, integration and tests |

This plan contains the technical decisions that survived source/mathematical review. **No implementer may decide economics, omit a required route or invent an unresolved algorithm.** The former G2–G5 requests for future annexes are removed as blanket gates. Their correct derivations appear inline below; specifically unresolved representation, retained-caller, configured-conversion and terminal-rights cases are identified in §2 instead of mislabeled complete. They block the affected path, not unrelated specification work. No new general owner questionnaire is introduced.

The plan uses existing accounting and calculation references. It does not introduce another reserve model, a replacement external Pendle SY, a general FoT framework, new governance, emergency administration, a fee model, or different market-risk guarantees.

**Owner clarification 2026-09-29 — overrides older open-item wording throughout this plan:** PRD v0.34 adds `address creator` to PkgArgs; late excess principal inherits the old NFT's existing/satisfied unlock; NFT “retirement” means inactivity only, with no explicit operation, burn, terminal state or forfeiture. The creator configuration and L4 questions are closed. Older L3 “missing mechanism/composition” labels identify implementation and test work, not new product decisions: use existing credit-before-sync/native-claim/accounting rules, provider/host rounding and selected routes. Pendle documentation supplies addresses; use the Robinhood mainnet library's standard default fork block and verify behavior with fork tests. No independent address-pinning research gate. G0 remains instruction maintenance, not another product approval. No implementation or test execution is authorized by this document update.

## 1. Fixed implementation contract

### 1.1 Non-negotiable product behavior

| Area | Required behavior |
| --- | --- |
| Custody/HLP | Hook directly manages raw DETF, raw custom SE shares, accounted held/net-claimable SY and internal PLP/YT subshares. Public LPs and multiple DETFs share the same hook. DETF owns only its actual HLP. |
| Liquidity math | Actual Balancer V3 Weighted proportional/unbalanced liquidity accounting; inner PLP/YT allocation remains proportional. No h/H shortcut for selected-leg exits and no wrapper approximate fee formula in place of BasePoolMath. |
| Weights | NET-DETF `5e17`, NET `2e17`, sNET `1e17`, USDG `2e17`, bound by leg identity; sum `1e18`. |
| Pricing | NET derives from the specified joint PLP/YT zap-out valuation; sNET from the SY book/rate; USDG from SE shares/rate; self-leg from held DETF. |
| Inputs | NET and sNET use Keep-YT; USDG deposits into the configured tax-aware canonical V2 SE. Direct HLP admission of DETF/SE shares/SY remains distinct. |
| Ordinary outputs | NET and sNET share one eligible SY budget, held first, claim if short, then redeem; no ordinary position-liquidation fallback or complete eligible-inventory drainage. USDG output redeems SE inventory. |
| HLP output units | DETF directly; SE shares directly; SY directly or obtained by realizing allocated PLP/YT subshares. No HLP-user SE-underlying unwrap. |
| DETF compatibility routes | DETF itself is the share token; ERC4626 asset is sNET. Liquid deposit-side acquisition buys existing DETF. Standard DETF-input NET/sNET/USDG routes use synthetic TWAP: below1 burns; equality/above1 swaps; unavailable history selects swap. |
| Contraction | Quote only actual protocol-owned book using `floor(q*(WAD+p)/WAD)`; receive/burn q only; fund actual net output or revert everything. |
| Dedicated reinvestment | Use q without contraction bonus at every peg regime; consume actual old funded claim/backing once and fund a new bond under its own destination-type lock. |
| Synthetic | Existing Universal Weighted calculation with NET numeraire, actual owned HLP and fee-diluted HLP supply; native DETF9→WAD once; creation1 NET versus opening1000 NET. |
| Expansion | One `floor(S0*n/200)` for completed unconsumed processed NET epochs if current hook spot TWAP>1 or unavailable; otherwise zero. Consume completed epochs once. No replay, cap, premium multiplier or second clock. |
| TWAP | Two distinct 3600-second arithmetic price-time series; hook spot gates expansion, DETF synthetic gates standard burn/swap. Capture synthetic on every state-changing expansion check, including zero/no-due/warm-up. |
| Staking | Nine-decimal funded-gons receipt using existing allocation/rebase/top-up/dust mechanics. Positive incoming backing transfers/mints notify the child in the same transaction; principal contexts prevent reward misclassification. No extra user distribution call or holder enumeration. |
| Native wrapper | One intended native note per dedicated NFT-owned holder. Standard hash of encoded PkgArgs containing owner/providedSalt; providedSalt is `bytes32(tokenId)`. Register returned noteId, never assume zero/tokenId. |
| Native proceeds | Actual installments and attributable excess atomically contribute/mint/stake principal under the same old NFT. No advance credit, raw-NET escape or successful deferred principal harvest. |
| Partial reinvestment | Consume requested already-funded old principal, create a new bond/new tokenId, retain old NFT/holder/note, remainder/rewards/future proceeds. Zero current principal does not imply retirement. |
| Locks | Purchase-epoch check is distinct. Intermediate collection does not reset old lock; successful final intended contribution in processed epoch E sets ordinary withdrawal unlock to E+1. New bonds do not inherit old locks. Unlock epoch0 means assigned Pendle maturity. |
| Rewards | Hold market interest token. Other attributable Pendle rewards go to current feeTo; failed outgoing forwarding retains excluded payable and does not block an otherwise valid operation. |
| Failure scope | Normal authorization/accounting/limit failures revert atomically. Arbitrary broken essential market/balance interfaces need not remain usable. No quarantine/stale-balance recovery subsystem is required. |
| Rollover | Hook-local, permissionless, expired source, factory-first validated compatible unexpired target; new SY allowed; required migration atomic; locks/ownership/history preserved. |

### 1.2 Repository and execution constraints

- Use Facet→Target/Service→Repo architecture and interface-declared PkgInit/PkgArgs. Production names use roles, not brand-specific token variables.
- Reuse shared libraries/facets where behavior matches; do not subclass a concrete unrelated DETF family as the new family implementation.
- Facets/packages use required CREATE3/FactoryServices; registered SE/DETF/hook packages use the IndexedEx manager/registry path. Hook instances use the actual V4 hook factory/flag-mining path, not ordinary vault deployment.
- Holder callback proxies follow the actual Package factory mechanism. Do not call a proxy CREATE3 merely because its facets/package use CREATE3.
- Product instances are unowned/immutable to humans. The NFT's permanent programmatic control of holders does not authorize ownership transfer, diamondCut, arbitrary execution or human pause.
- Read `.github/ASSISTANT_RULES.md` and then-current coding/deployment/test documents before separately authorized source edits.
- Current configuration: Solidity0.8.35, optimizer runs1, `via_ir=false`; default/fork product profiles only. Root CLAUDE overrides obsolete package-profile skill examples.
- Build concrete runtime artifacts before tests consuming FactoryService artifact bytecode. Never rely on a test graph to refresh an unimported production artifact.
- D60 excludes functional Balancer-hosted DETF work; those sources are read-only behavioral references here. No Slipstream release work, frontend rollout, existing-hook TWAP retrofit, deployment or migration.

## 2. Actual prerequisites and narrowly blocked paths

### 2.1 External prerequisites retained

| ID | Requirement | Scope |
| --- | --- | --- |
| G0 | Separately authorized maintainer reconciliation of this family's selected exceptions with applicable implementation instructions. Product approval is already recorded; this document cannot override higher-priority instructions. | Production implementation authorization |
| G1 | Required configured dependency/source/implementation identity, observations, decimals/relationships, SY conversions and oracle terms. Preserve PRD §8's pair token/factory/code/live-fee verification **before implementation**. New custom components need no deployed address before design. | Work relying on the unverified binding/capability; preserve any explicit earlier deadline |

No tests, current-chain observations or missing references have been fabricated to pass these prerequisites.

### 2.2 Technical review findings replacing broad G2–G5 gates

| ID | Exact remaining issue | Affected work / resolution needed |
| --- | --- | --- |
| L1 — RESOLVED by owner-authorized model change | PRD v0.31 replaces literal live-B/U with existing funded-gons mechanics and immediate backing-movement notification. Native x credits/debits x*K units at settled K; §9 defines source reuse and adapter behavior. | No further staking-model choice pending. W7/W8/W9 must implement and test notification coverage, principal contexts, source allocation/dust and exact native claims; resolution is not a passing-test claim. |
| L2 — RESOLVED by explicit caller-responsibility policy | Supported public pretransfer uses max(actual raw held−booked reserve,0) regardless of origin. Caller handles transfer/consume integration; no payer proof, authenticated receipt or donation exclusion is required. | Reuse existing supported caller/route/amount/refund checks and booked-reserve protection. Implement §6.1 and A05; do not reopen provenance as a prerequisite. Staking's internal principal/reward context remains a separate mechanism. |
| L3 — SY conversion mapped; local YTv1 claim composition recorded; configured composition pending | §6.5 specifies the extracted SY branches/inverses/custody. §6.6 now maps local YTv1 interest, market incentives, fees, cache/expiry, receipts and claim→redeem ordering; it is conditional on the actual configured implementation. | Verify deployed YT V1/V2 and use its actual body; finish prior-force-claim role reconciliation, provider/caller rounding, full owned-HLP/Keep-YT chronology and exact-output residual/domain proof. G1 observations remain separate. No repeated SY extraction or new Weighted solver. |
| L4 — RESOLVED by owner clarification | Late excess inherits the existing unlock, including an already satisfied unlock. Retirement is only a user's inactivity, not an on-chain lifecycle transition. | No retire method, retirement burn/terminal flag/forfeiture or new late-principal lock. Preserve NFT/holder mapping and current-owner collection rights. Implement/test existing behavior. |

These are not new requests to write annexes. L1 is resolved by the explicit funded-gons switch; L2 is resolved by origin-independent public surplus credit and caller responsibility. §9's internal funding classification prevents principal from being distributed as rewards, not arbitrary public pretransfer claiming. L3 is source-specific conversion engineering and L4 the terminal edge. Do not recreate closed provenance or staking-model questions, or claim the new notification adapter already exists unchanged.

**Implementation sequencing:** after G0/G1 and separate execution authorization, implement unblocked, specified work in §12's dependency order. Do not ship a feature whose required L1–L4 transition remains unresolved. Keep failures and validation in the owning work package; do not block unrelated work behind one general “write the design later” stage. The exact selector/configuration inventory and child-initialization choreography are source-mapping work in §5/W10, not falsely certified complete by this version.

## 3. Component and source layout

Paths below are planned destinations, not claims that files already exist. Use full descriptive role-based names; keep the family custom behavior isolated from Universal instances.

| Component | Planned source root / principal artifacts | Responsibility |
| --- | --- | --- |
| DETF coordinator | `contracts/vaults/detf/protocols/dexes/uniswap/v4/pendle/`; `PendleWeightedDetfDFPkg`, interface, Repo, Targets/Facets, FactoryService, TestBase | DETF ERC20, standard routes, owned-HLP policy, expansion, orchestration |
| Shared hook/vault | `contracts/hooks/uniswap/v4/pendle/weighted/`; `PendleMarketWeightedHookDFPkg`, interface, book/liquidity/swap/rollover/reward/TWAP Targets/Facets | Physical Pendle custody, HLP, native/rated snapshots, shared inventory and market lifecycle |
| Funded staking child | Family `staking/`; `PendleFundedStakedDetf` Repo/Target/Facet/Package and interfaces | Reuse funded-gons core, principal/received-reward contexts, NFT-attributed gons and recipient receipts |
| Custom NFT child | Family `bondNft/`; `PendleBondNft` Repo/Target/Facet/Package and interfaces | Principal/reward claims, locks, tokenId rights, old/new bond linkage, native-holder orchestration |
| Native holder | `contracts/vaults/detf/common/nativeBondHolder/`; `NativeBondHolderDFPkg`, interface, immutable-configuration Repo/Target/Facet | One intended native purchase, registered note and NFT-only collection; reusable without another NFT contract |
| Tax-aware V2 SE | `contracts/protocols/dexes/uniswap/v2/taxAware/`; `TaxAwareUniswapV2StandardExchange` package/quote/execute services/targets | Full V2 SE parity plus configured NetNet tax/exemption-aware net execution |
| SY target provider | `contracts/protocols/perps/pendle/rateProviders/`; `PendleStandardizedYieldRateProvider` package/facet/Repo | Per-share SY→configured-target rate, independent of hook-held inventory |
| Arithmetic observation utility | `contracts/oracles/twap/arithmetic/`; library/Repo/interface and declaration tests | Price-time accumulator/checkpoints shared structurally by two separate series |
| Integration tests | `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/pendle/` and mirrored hook/SE/provider suites; fork rows under `test/foundry/fork/robinhood_4663/` | Registered production components, state-machine and differential/invariant coverage |

Only genuinely reusable mechanics belong in common directories. No generic strategy release, token-policy framework or unrelated reference refactor is included.

### 3.1 Mandatory reuse map

| Existing source | Reuse / do not copy |
| --- | --- |
| `BasePoolMath.sol:50–107,126–397` in vendored Balancer vault tree, with Vault scaled caller context | Actual proportional/unbalanced/BPT calculations; do not use the Weighted wrapper's whole-output approximate imbalance fee |
| `lib/crane/contracts/protocols/dexes/balancer/v3/utils/BalancerV3WeightedPoolQuote.sol:14–49` | Existing fee-inclusive exact-input/output swap quotes. Preserve caller scaling and do not gross up the exact-output fee twice. V4 wrapper supplies its native boundary rounding. |
| Weighted hook Target/Math/JoinCore/ExitQueryTarget | Source-mapped invariant/swap/usage-fee/synthetic behavior; adapt custody, not selected economics |
| `UniswapV4DetfCommon.sol:104–135,175–211,258–289` and `DETFMintSplitLib.sol:19–53` | Existing duration calculation, synthetic context and G/U/bond split; not Universal clock, reserve custody or linear release |
| `UniV2Pair.sol:215–224,255–323` | Arithmetic cumulative and proportional inner-share patterns; not an extra AMM or silent unequal-input donation |
| Pendle `ActionAddRemoveLiqV3.sol:236–303`, `ActionMiscV3.sol:129–240`, `MarketMathCore` | Keep-YT and joint-position quote/execution; actual configured version must match |
| `BasicVaultRepo`, `MultiAssetBasicVaultRepo`, `BasicVaultCommon` | Shared-slot raw custody and post-refund synchronization; not receivable/provenance classification by itself |
| `StakedDETFTarget`, `DETFFundedStakingRepo`, `DETFFundedStakingMath`, `DETFSeigniorageShareLib` | Exact native/gon principal arithmetic, source allocation/rebase/recipient/top-up/dust. Add no-pull notification adapter; do not copy linear release, stock NetNet premint/cap/clock. |
| `UniswapV2StandardExchangeDFPkg.sol` and installed surfaces | Full parity; do not reduce to zap-only adapter |
| `FeeCollectorDFPkg.sol:153–155`, callback factory `:201–232` | Standard hash/actual deployment semantics; not FeeCollector's human ownership/upgrade configuration |

Complete trace and exact paths are in PRD §16.2 and the closure audit. Pin reference revisions with G1's source manifest; line ranges describe inspected local snapshots.

## 4. Configuration, deployment and dependency graph

### 4.1 Binding sources

Preserve the main Package's selected configuration:

- **PkgInit fixed external bindings:** existing fee oracle, NET, sNET, USDG, canonical NET/USDG V2 pair, trusted Pendle Market Factory, custom tax-aware V2 SE.
- **PkgArgs instance bindings:** initial Pendle market, native bond depository, NetNet staking, and `address creator`. Propagate creator through the existing creator-role initializer; do not substitute the deployment caller.
- **Validated discovery:** market PT/YT/SY and expiry; factory recognition precedes token relationship checks. SY is not Package-immutable.
- **Supporting implementation bindings:** facet/child Package references and fixed execution router/static helper are Package construction dependencies, not user-variable market/token/depository overrides. Provider instances are bound to discovered SY and configured target. Creator comes from the explicit main PkgArgs.creator and uses existing creator-role initialization semantics; no creator-source gap remains.
- **Dynamic external values:** oracle fees/recipient/bond terms, active tax predicates and live conversion/index state are resolved at the required operation snapshot; published observations are not constants.

Use the newly recorded chain constants for discovery infrastructure; do not add a perpetual current-market/PT/YT/SY constant. A current candidate must be unexpired and compatible when selected. Factory enumeration/validation and caller market choice are distinct.

### 4.2 Construction sequence

1. Deploy/reuse shared facets and generic libraries through required FactoryServices.
2. Register the full-feature custom V2 SE Package through the manager, create its canonical pair-bound instance and verify `asset()==canonicalPair` plus trusted provenance/capabilities.
3. Prepare the holder, staking, NFT, provider, hook and DETF Packages and facet addresses; register vault-style Packages through the manager.
4. Predict the fixed single DETF instance using its existing `"NET-DETF"` salt policy; bind child ownership to that address, never to the deployment EOA. Use authenticated factory initialization and reject any ordinary entry until the coordinator's complete initialized flag is set.
5. Mine required V4 hook-address flags and deploy through registry→hook factory using the hook-specific salt/nonce convention. This is not the holder Package's ordinary callback-factory salt.
6. Initialize proxy Repos and permanent inter-component authority, discovery and oracle identities in one protected deployment flow; verify actual returned instances. No human upgrade or later replacement setter.
7. Leave reserve **inert** until the first successful full-book bond transaction. No synthetic price history is fabricated before activation.

Use Package/factory initialization for permanent owner/configuration, followed by parent-only one-time child binding while the parent remains inactive; publish liveness only after all references reciprocally match. Existing-proxy returns must pass the same configuration checks as newly deployed children. W10 must trace the chosen factory's actual callback permissions and demonstrate no unguarded public interim phase; a predicted address alone is not an initialization proof. This version does not claim that every reference-package callback restriction has been verified against the new child graph.

### 4.3 Holder Package

Holder PkgArgs includes `owner` and `providedSalt`; the NFT supplies its own contract address and `bytes32(tokenId)`. Follow the reference `abi.encode(pkgArgs)._hash()` convention over encoded arguments. Do not replace it with hash-of-salt-only or a different encoding of decoded fields.

The callback factory namespaces with Package and may return an existing proxy before processing arguments. On both creation and reuse, validate package/behavior, initialized owner, salt/configuration and one-purchase state. Safe identical predeployment may be adopted; wrong configuration or reinitialization must fail. Do not permit a second intended native purchase.

After holder deployment, the owning NFT invokes its one-time binding with the depository obtained from its already-bound parent DETF. The holder accepts that call only from its permanent NFT owner, only before its first authorized native purchase, and never permits rebinding. Owner and providedSalt determine identity under the selected standard hash; depository propagation is not a caller-provided replacement option or a global Package depository. A previously deployed holder with a mismatched binding cannot be adopted.

## 5. State ownership and interface contract

### 5.1 State tables

| State | Owning component | Required meaning |
| --- | --- | --- |
| Raw expected-held token set and balances | Every custody component's BasicVaultRepo slot | Physical local custody only; post-refund full-set sync on successful routes |
| Current market/factory/router/token relationships | Hook configuration/series Repo | Validated references; active pointer changes only after atomic rollover |
| Series registry and residual state | Hook series Repo | Old YT/SY/market locators and obligations; no loss of late claims or authoritative clone of Pendle indexes |
| Eligible SY, receivable attribution and fee liabilities | Hook accounting Repo | Separate economic roles; no double inclusion of held cash and a redeemed receivable |
| Position subshares and PLP/YT backing | Hook position Repo | One HLP custody leg representing a proportional two-asset reserve |
| HLP supply/allowances/permit | Shared ERC20/EIP712 Repos on hook | Shared public LP ownership; all accrued value travels with LP |
| Fee-growth checkpoint | Hook fee Repo | Reference invariant/mode checkpoint; protocol dilution counted once |
| Actual DETF supply and owned HLP | DETF ERC20/custody | Includes pooled/staked DETF in supply; excludes public HLP from owned backing |
| Last consumed processed NET epoch | DETF epoch Repo | No elapsed-time replacement clock; once-only aggregate expansion |
| Spot and synthetic histories | Separate oracle Repos on hook/DETF | Independent price-time series/readiness; no shared average |
| Staking gons/divisor/accounted backing and dust | Staking child Repo | Actual funded liability floor(Q/K), per-owner/position gons, distinct standing weights/allocation dust/staking dust. Internal divisor updates on authenticated funded rewards. |
| Position principal/shares, purchase epoch, unlock target, assigned maturity, completion flag/epoch | NFT position Repo | Distinct principal/reward and timing semantics; unlock target0 means Pendle maturity, not unset |
| tokenId↔holder and registered native noteId/payout/end | NFT/holder authenticated state | One intended native note; actual returned index, including zero where valid |

No new global per-user native-note loop. A snapshot tuple must state raw units, asset identity, series, ownership fraction and snapshot time; a number without its role/unit is not an accounting input.

### 5.2 Surfaces and call authority

Reuse every current standard SE, ERC20/permit, ERC4626 and Pendle `IStandardizedYield` signature selected by the reference package. Build controls from the interfaces/Targets rather than copying incomplete `facetFuncs`; no numeric selector is invented here. The reference V2 package advertises fourteen interface entries and nine facet cuts (`UniswapV2StandardExchangeDFPkg.sol:401–417,431–518`), enumerated below as the fixed parity source.

| Surface | Caller / effect |
| --- | --- |
| DETF ERC4626 deposit/mint, SY deposit, SE input | Authorized source funds NET/sNET/USDG route; acquire existing DETF, no fresh liquid user issuance |
| DETF redeem/withdraw, SY/SE outputs | Owner/allowance/internal-balance checks; single centralized synthetic-TWAP branch and quote/funding implementation |
| Hook liquidity | Public funded joins and owned/approved HLP exits; preserves selected modes and delivery units |
| Hook V4 callbacks | Authenticate PoolManager and active operation context; never accept arbitrary callback caller/input credit |
| Hook rollover/rewards | Permissionless public caller; configured recipients/ownership preserved, no arbitrary recipient or sweep authority |
| Staking entry/exit | Actual received DETF backing, equal native-unit payout, resolved share conversion; no LP redemption |
| NFT purchase/claim/reinvestment | Current owner/approved operator; settle before participation changes; no original-purchaser entitlement |
| Native holder purchase/collection | Owning NFT contract only, authenticated note registration and recipient/call context; no arbitrary external-call facility |

### 5.3 Surface inventory and operation-context contract

The tax-aware SE retains the reference cuts: ERC20, ERC5267, ERC2612, ERC4626, MultiAssetBasicVault, MultiAssetStandardVault, UniswapV2StandardExchangeIn, UniswapV2StandardExchangeOut and UniswapV2StandardExchangeQuery. Its advertised interface entries are IERC20, IERC20Metadata, their combined interface ID, IERC20Permit, IERC5267, IERC4626, IBasicVault, IStandardVault, IStandardExchangeIn, IStandardExchangeOut, IVaultFeeOracleQueryAware, IStandardExchangeTransitionQuote, IStandardizedYield and IStandardExchangeExternalQuote. Preserve every inherited selector from these cuts and the actual reference Targets; tax-aware replacements must expose the same applicable surface. No optional feature subset is assigned to the implementer.

Custom operation records must carry the following typed fields; they are data contracts for one implementation, not separate economic ledgers:

- `FundingReceipt`: internal staking/callback funding record containing nonce, authorized component, payer/source, token, funding kind, opening balance, credited/consumed amount and phase. This is **not required to claim public pretransfer surplus**; public pretransfer keeps only its local available/credited/used budget.
- `ExecutionLimits`: deadline, per-input maximums, per-output minima, maximum HLP debit, destination/recipient and exact-side indicator. No arbitrary external target or arbitrary calldata forwarding.
- `PositionSnapshot`: tokenId, old native principal, attributed staking gons, settled gonsPerUnit/accounted backing/total gons, purchase epoch, completion-valid flag/epoch, unlock target and assigned maturity.
- `ReserveSnapshot`: registered token identities/decimals, raw physical balances, economic role amounts, net receivables, position L/Y/S, actual owned HLP, fee-projected HLP supply, native/rated vectors, effective oracle terms and current series identity.

Oracle signatures are fixed in §8.1. Native holder management consists of owner-only one-time dependency binding, one intended purchase returning `(noteId,payout)`, owner-only collection returning operation-attributable received NET, and read-only owner/configuration/intended-note inspection. No native-note ID supplied by the user may replace the registered returned index. Standard fungible routes retain their source signatures; NFT-specific operations identify tokenId, requested funded principal/rewards, supported destination type/token and the limits record. Do not add a public contraction endpoint.

The custom operational surface is fixed in §§5.4–5.6. These signatures specify the new component contract; inherited standard selectors remain exactly their reference definitions. Creator is supplied by PkgArgs.creator (§4.1). Numeric selector/interface-ID generation and independent surface controls belong to implementation validation. No retirement selector is required.

### 5.4 Custom interface declarations

Use the following enum ordering and struct field ordering. Solidity field names use generic asset roles; symbol labels in the PRD do not become alternate storage identifiers.

```text
enum BondKind { PendleMaturity, NextProcessedEpoch, NativeNote }
enum LiquidityMode { Proportional, Unbalanced, SingleToken }

struct RouteLimits {
    uint256 deadline;
    uint256 maxTokenIn;
    uint256 minTokenOut;
    uint256 maxHlpIn;
    uint256 minHlpOut;
    uint256 minPendleLpOut;
    uint256 minYtOut;
}

struct RolloverLimits {
    uint256 deadline;
    uint256 minOldSyOut;
    uint256 minNewSyOut;
    uint256 minPendleLpOut;
    uint256 minYtOut;
}
```

The structs carry execution protections, not a new economic configuration surface. Set a field to zero only where the corresponding stage does not exist; it is not permission to skip a required user bound. Position identities, reward recipients, market tokens and addresses derivable from validated dependencies are never caller-overridden through these records.

**Native holder interface:**

```text
owner() -> address
providedSalt() -> bytes32
nativeDepository() -> address
intendedNote() -> (bool purchased, uint256 noteId,
                  uint256 payout, uint64 endTimestamp)
bindDepository(address depository)
purchase(uint256 marketId, uint256 paymentAmount,
         uint256 maxPriceWad, uint256 minPayout,
         uint256 deadline) -> (uint256 noteId, uint256 payout)
collect(address receiver, uint256 deadline) -> uint256 netReceived
```

All state-changing holder methods are owner-only; bind is once-only, purchase is once-only. `purchase` uses the validated depository's quote-token discovery and pays from this operation's measured funded input. `collect` snapshots the configured rateAsset at the fixed orchestration receiver and returns its actual received delta, not the receiver's old balance or a nominal native return. The NFT fixes the receiver to its registered coordinator/contribution path and never exposes arbitrary recipient selection to an end user. Full-note scanning remains the upstream call's behavior; no note-ID-selective write is implied.

**NFT-specific operations:**

```text
bond(BondKind kind, address tokenIn, uint256 amountIn,
     address receiver, RouteLimits limits) -> uint256 tokenId
purchaseNativeBond(uint256 marketId, address tokenIn, uint256 amountIn,
                   uint256 maxPriceWad, uint256 minNativePayout,
                   address receiver, RouteLimits limits) -> uint256 tokenId
collectNative(uint256 tokenId, RouteLimits limits)
claimRewards(uint256 tokenId, uint256 amount, address receiver)
claimPrincipal(uint256 tokenId, uint256 amount, address receiver)
reinvest(uint256 tokenId, uint256 principalIn, BondKind destinationKind,
         address reinvestmentAsset, RouteLimits limits) -> uint256 newTokenId
holderOf(uint256 tokenId) -> address
positionOf(uint256 tokenId) -> PositionSnapshot
claimable(uint256 tokenId) -> (uint256 principal, uint256 rewards)
```

`bond` handles ordinary bond routes; `purchaseNativeBond` is the distinct native-note composition. `reinvest` funds a new supported bond/tokenId; choosing `NativeNote` does not reuse the old holder or bypass once-only purchase. Authenticate current owner/operator, not original purchaser. Claims use funded sDETF entitlements and settled x*K gon transfers (§9), not raw reserve assets. There is no retire operation: inactivity changes no rights, holder ownership, tokenId mapping or future collection capability.

**Hook-specific liquidity/management operations:**

```text
joinLiquidity(LiquidityMode mode, address[] tokensIn, uint256[] amountsIn,
              address receiver, RouteLimits limits) -> uint256 hlpOut
exitLiquidity(LiquidityMode mode, uint256 hlpIn,
              uint256[] amountsOut, address receiver,
              RouteLimits limits) -> uint256[] actualOut
rollover(address targetMarket, RolloverLimits limits)
collectRewards(address historicalMarket)
activeMarket() -> address
seriesOf(address market) -> SeriesSnapshot
```

The canonical four-leg order is the Package's fixed identity mapping, exposed by discovery getters and used consistently by custody/output arrays. Join token/amount pairs identify actual supported funding tokens: DETF, raw SE shares, direct SY and NET/sNET Keep-YT funding; they never permit caller-minted internal subshares or a new loose-PLP/YT route. Aggregate actual acquired amounts once into the four-leg book. Do not infer identities from weight position. For proportional exits, `hlpIn` is exact and `amountsOut` supplies per-leg minima; for unbalanced/exact-output mode, `hlpIn` is zero, `amountsOut` specifies requested custody-leg outputs and `limits.maxHlpIn` limits the computed debit. Exactly one nonzero requested output is required for single-token exact-output mode. Existing standard-exchange and V4 swap selectors retain their interfaces; these HLP operations add no DETF contraction endpoint. Each nonapplicable field has canonical zero encoding checked at entry.

Historical reward collection accepts only a retained validated market identity. `historicalMarket==activeMarket()` permits current collection; it is not an arbitrary external claim target or token sweep. Interest retention/other-reward forwarding remains fixed by the configured source and oracle recipient.

### 5.5 Internal calls and authority phases

Use a stored or transient operation phase with values `Idle`, `Funding`, `Executing`, `Committing`; choose the repository's supported guard storage primitive, but preserve these semantics. A user entry is allowed only from Idle. Cross-component callbacks require the expected peer, tokenId/operation nonce, route kind and phase. A second public entry cannot become valid merely because an internal callback is expected.

- NFT→coordinator: fund an ordinary/new bond, consume a funded position for reinvestment, or contribute a collected native installment. The coordinator verifies the NFT configured at initialization.
- Coordinator→staking: credit funded position shares, distribute funded rewards and debit authorized position entitlement. Neither a holder nor a wallet calls these privileged credit/debit methods.
- NFT→holder: bind, purchase and collect under the immutable NFT owner; sibling holders cannot invoke them.
- Hook→Pendle/SE/PoolManager: fixed validated dependency calls with typed parameters and fixed custodial recipients. Expected protocol callbacks verify dependency identity and the active context; no arbitrary `target.call(data)` surface.
- Failed required execution unwinds phase, ledger, allowance and token effects atomically. Only outgoing fee-forwarding is caught under the selected exception; catching it does not leave an Executing phase visible after return.

View functions used by external callbacks must either return a coherent committed/precomputed snapshot explicitly intended for that phase or reject consultation during an inconsistent transition. Do not expose half-funded balances as spendable claims.

### 5.6 Events, errors and immutable initialization transitions

In addition to inherited ERC20/ERC721/SE events, emit typed custom events for `BondOpened`, `NativeNoteRegistered`, `NativeProceedsContributed`, `PrincipalReinvested`, `PrincipalClaimed`, `RewardsClaimed`, `IntendedNoteCompleted`, `MarketRolled`, `RewardForwardFailed` and `RewardForwarded`. No PositionRetired event or retirement transition is required. Include tokenId/old-new tokenIds, holder/market/token identities, actual native amounts, share amounts where relevant, and epoch/unlock fields needed to reconstruct ownership. No event should report a quote-only amount as actual mint, burn or payment.

Use distinct typed errors for unauthorized component, wrong operation phase, incompatible instance, already initialized/bound/purchased, invalid tokenId/note/series, insufficient actual receipt, excessive input/insufficient output, incompatible market, active-source rollover, invalid liquidity mode and arithmetic domain. Reuse existing source errors where the retained interface specifies them. Do not assign guessed selector hex values; declaration tests compute them from the actual signatures.

Initialization state is `Uninitialized -> Configured -> Wired -> Ready`, each transition once-only under the actual factory/Package initialization caller. Configure immutable parent and own data first; wire child addresses only from the parent while it is inactive; Ready requires reciprocal identity/configuration assertions for every child and valid hook flags/registry registration. Public money routes require Ready, and reserve-dependent routes additionally require actual first-bond liveness. Remove or permanently disable initialization capabilities after wiring; no deployer EOA retains mutation power. An existing-instance return must satisfy these same final invariants before use.

## 6. Accounting and mathematical implementation

### 6.1 Three distinct books

1. **Physical book:** raw held token snapshots, including PLP/YT and fee-owned tokens.
2. **Ownership/liability book:** HLP components, internal position shares, net claims and exclusive/payable obligations.
3. **Pricing book:** rated-WAD DETF/NET/sNET/USDG coordinates used by selected pricing and synthetic algorithms.

Convert once at documented boundaries. Never add raw quantities of different units; never count an SE share plus its underlying LP, or a position subshare plus the same complete PLP/YT position.

| Movement | Required accounting |
| --- | --- |
| NET/sNET ingress | Actual Keep-YT LP/YT receipts increase position backing/subshares; intermediate SY spent on acquisition is not interest cash |
| Ordinary NET/sNET egress | Debit one eligible SY budget; do not fabricate a PLP/YT debit or mechanically decrement its NET valuation |
| Interest collection | Replace attributable net receivable by held SY once; no profit solely from claim settlement |
| Position exit | Debit allocated subshares/PLP/YT; temporary realized SY belongs to that exit, not a second SY-book claim |
| USDG ingress/egress | Add/debit actual custom SE shares and execute net SE operations; hook does not recompute tax |
| Fee reward receipt | Record physical custody plus excluded payable once; failed forward does not convert it into backing |
| HLP transfer | Transfer current managed-book rights; no historical coupon retained by seller |

**Public pretransfer — specified algorithm:** on a route that already supports the true flag, apply its existing caller/route guards, read raw live balance B and booked R, and compute `available=LocalCreditLib.available(B,R)=max(B−R,0)`. Require the declared credit to fit available and snapshot that credited amount for this call. Credit has no payer/source-of-funds condition. Previously unbooked user transfers, donations and externally forced protocol receipts are equally available. The caller is responsible for transferring and consuming without an intervening claimant; the vault does not guarantee the original sender retains that surplus.

Do not add a caller registry, begin-receipt handshake, witness or proof of atomic transfer solely for this mode. Preserve the existing contract-only check where present; its lack of origin proof is intentional, not a missing requirement. Protect booked R and consumed credit. Do not indiscriminately sync before calculating available to remove the very pretransfer being claimed.

**Pull mode:** snapshot before allowance/Permit2 transfer and credit its actual incoming delta, not unrelated pre-existing surplus. **Refunds:** exact-input pretransfer does not refund unused maximums; exact-output refunds at most credited-minus-used and the remaining available surplus, following the retained reference helper. False-flag exact output pulls only quoted required input. Refund first, then full expected-set synchronization. A successful route cannot leave the consumed units claimable again. Reverts restore all credit/book/token state.

Maintain once-only native receivable, held-asset and payable accounting. A force-claim clears native entitlement; do not retain a second receivable or simultaneously treat caller-consumed units as separate held backing. Protocol-controlled inflows during the current operation are booked according to that operation rather than credited a second time. These conservation checks do not filter historical origin of public unbooked surplus. Staking §9's transfer notification is separate: its controlled parent marks principal before movement so it is not rebased as rewards, and plain notified reward transfers are already accounted—not public unbooked stake credit.

### 6.2 Outer and inner share math

Use actual BasePoolMath modes and scaled caller context. Required direction: token inputs and HLP required for exact output round conservatively up; paid outputs and issued HLP round conservatively down, with each reference intermediate preserved. Implement differential comparisons against the selected source math rather than a second independently invented formula.

For full proportional HLP exit h/H, preserve nested floors:

```text
detfOut = floor(h*D/H)
seSharesOut = floor(h*V/H)
syOut = floor(h*C/H)
positionShares = floor(h*K/H)
lpIn = floor(positionShares*L/S)
ytIn = floor(positionShares*Y/S)
positionSyOut = exitAllocatedPositionToSy(lpIn, ytIn)
```

Selected-leg mode uses the invariant-derived HLP debit, not these h/H fractions applied independently. Position allocation remains proportional after its outer subshare amount is determined.

**Inner-share arithmetic:** use raw verified PLP/YT units consistently. For an empty inner reserve, compute `root=sqrtFloor(L0*Y0)` with a full-width product/square-root or a proved arithmetic domain; require root>1000. Total S=root includes1000 permanently locked internal minimum shares; admitted ownership is root−1000. Do not apply the later min-ratio formula to zero reserves/supply. This applies the selected V2-like issuance reference, not an additional trading pool or fee.

For existing positive L,Y,S and isolated actual ingress x,y:

```text
m = min(floor(x*S/L), floor(y*S/Y))
acceptedL = ceil(m*L/S)
acceptedY = ceil(m*Y/S)
residualL = x - acceptedL
residualY = y - acceptedY
```

Reject zero issuance. Accepted quantities cannot exceed ingress; upward acceptance prevents underfunding m. Add accepted assets and m to the backing/share book. Residuals belong to this operation, not existing LPs. For Keep-YT entry, convert the allocated residual through the selected position-to-SY and supported input-denomination return path under limits; credit only accepted contribution. If the required residual conversion cannot execute, revert the entry atomically. This is not loose-PLP/YT public admission or a persistent residual coupon. Do not label a retained mismatched surplus “priced drift” without proving its ownership and valuation.

Example L100,Y200,S100,x30,y40 gives m20, accepted20/40, residual10/0. Initial L1,000,000,Y4,000,000 gives total S2,000,000, locked1000 and admitted1,999,000. Exits preserve nested floors; permanently locked shares prevent the last circulating holder sweeping all raw backing. Rollover preserves continuing subshare ownership while replacing its assets and keeping historical claims separately attributed. Residual conversion is subject to L3's configured route proof; no unsupported route is fabricated.

### 6.3 Reused synthetic and fees

Implement PRD §7.1.4 unchanged. For NET numeraire j:

```text
M = ratedNET + sum(floor(ratedNET*w[i]/wNET))
    over other positive non-self coordinates
ownedNET = floor(M*ownedHlp/projectedHlpSupply)
mid = floor(ownedNET*WAD/detfSupplyWad)
synthetic = floor(mid*WAD/creationNET)
```

Use `creationNET=1e18`, separate opening=`1000e18`; normalize DETF supply from native9 by ×1e9 exactly once. Include pending expansion once in settlement previews. HLP denominator includes projected protocol fee. Do not import `_highestSyntheticPrice` expansion policy or assume first-array-token is NET without identity binding.

Hook fee reference: `a=floor(usageWad*100000/WAD)` and, subject to source guards/matching modes/positive growth, `protocolHlp=floor(H*(K−Klast)/(floor(K*100000/a)+K−Klast))`. K is native-inventory invariant, not sqrt and not the rated swap book. Realize before user LP calculation and snapshot afterward; no duplicate deposit haircut. SE/swap/imbalance fees remain their separate reference paths.

DETF bond split: `principal=floor(U*(WAD−p)/WAD)`, `pot=floor(U*p/WAD)+floor(G*p/WAD)`, separately mint G. Preserve independent floors and dynamic oracle identities/fallback. No hard-coded effective fee percentage.

### 6.4 Owned-reserve burn and exact output

**No new Weighted quote/inverse implementation:** use the existing source functions:

| Helper | Source behavior |
| --- | --- |
| `BalancerV3WeightedPoolQuote.computeOutGivenExactInAfterFee(balanceIn,weightIn,balanceOut,weightOut,amountIn,fee)` | Zero input or zero fee-adjusted input returns0; net input is `mulDown(amountIn,ONE-fee)`; call WeightedMath exact-input output calculation |
| `BalancerV3WeightedPoolQuote.computeInGivenExactOutBeforeFee(balanceIn,weightIn,balanceOut,weightOut,amountOut,fee)` | Zero output returns0; call WeightedMath exact-output input calculation; gross input is `divUp(netInput,ONE-fee)` |

All balances/amounts at this helper boundary must use consistent selected scaled/rated units and WAD weights/fee. The helper itself does not discover decimals, rates, ownership or physical funding. Preserve the underlying WeightedMath max-in/max-out/domain checks and supported fee domain. Public route zero-amount behavior follows its retained wrapper/entrypoint; the pure helper's zero return does not silently override it.

For the selected V4 native boundary, reuse `UniswapV4StandardExchangeWeightedBufferHookMath.quoteExactIn/quoteExactOut:186–227`: exact output scales requested output up, calls the existing inverse, descales input up and applies its fee gross-up once. Applying a scaled-unit fee before descaling can differ at integer boundaries, so do not silently replace wrapper ordering or add another fee to already-gross helper output. Existing Balancer caller examples at `ComposedStableCommonDetfCommon.sol:728–738,754–767` and `MultiVaultWeightedDetfCommon.sol:404–421` supply reference unit boundaries; read them, do not modify those excluded families.

Build the owned reserve snapshot from actual owned HLP and withdrawable components **before** quotation. Exclude public LP, staking backing, fee payables and exclusive native notes. Standard eligible burn uses qQuote=`floor(q*(WAD+p)/WAD)`; reinvestment uses qQuote=q. Consume actual q only.

Build a fixed-state route graph from the selected execution calls, with the token/unit and ownership of each intermediate. Walk that graph backward from requested output, then replay every forward fee, rounding and projected reserve mutation. Required HLP debits must be calculated by the actual BasePoolMath mode and remain within owned HLP. The self-leg received by a position exit remains explicitly accounted DETF inventory; do not silently burn extra self-leg tokens or add them to actual-q burn. Whole-pool quotation capped afterward and an invented off-pool cash sleeve remain forbidden.

| Forward stage | Exact local inverse/requirement |
| --- | --- |
| `floor(x*a/b)`, positive a,b | `ceil(y*b/a)`, then verify the forward integer result |
| Native NET transfer `g−floor(g*t/D)`, y>0,0≤t<D | Minimum gross `floor((y−1)*D/(D−t))+1`; y=0 gives0; resolve actual hop exemption before applying |
| Weighted exact output | Scale output up, call `computeInGivenExactOut`, descale required input up, apply the source fee gross-up once |
| HLP selected-token exact output | Actual BasePoolMath invariant/taxable-imbalance calculation and upward HLP debit in its proper scaled context |
| Contraction quotation uplift | `ceil(qQuoteRequired*WAD/(WAD+p))`, forward-check the floor; reinvestment has no uplift |

For floor-tax example D10000,t500,y19, gross19 already yields19; generic ceil(19/0.95)=20 is not the minimal inverse. Do not multiply Weighted required input by another quantity with token units or gross up the same fee twice.

The backward pass is valid only for the actual configured conversion functions at the same projected state. A one-share sample and one-unit fix-up do not prove nonlinear SY or PLP/YT inverse bounds. `previewRedeem` existence is not an exact-output API. L3 remains explicit until that source composition and owned-book realization are completed; no generic search, new SY, repeated redeem-loop solver or silent unsupported ERC4626 withdrawal is allowed.

For ordinary NET/sNET, quoted raw SY expenditure d must be less than the coherent eligible held+net-claimable budget before expenditure, leaving a positive native SY-unit remainder after actual claim fees/redemption. Use held first, claim only for shortfall and recheck actual delivery; no new percentage reserve floor or economic cap. Required principal/interest/fee attribution and actual net output must agree in the forward pass. A claim returning less than required causes full rollback, not partial payout.

### 6.5 Actual PendleStakedNetSY conversion, execution ordering and funding

**Reviewed 2026-09-28:** [post-extraction council consolidation](../../../research/netnet-sy-conversion-post-extraction/COUNCIL_CONSOLIDATION.md), four independent originals and four same-session combined cross-reviews. The earlier [source-acquisition consultation](../../../research/netnet-sy-conversion-2026-09-27/COUNCIL_CONSOLIDATION.md) is historical pre-extraction evidence, not the current analysis status.

In this section **E** denotes line numbers in [VERIFIED_SY_SOURCE_EXTRACTS.md](../../../research/netnet-sy-conversion-2026-09-27/VERIFIED_SY_SOURCE_EXTRACTS.md), not original Solidity line numbers. **N** denotes `lib/crane/contracts/protocols/pol/net/src/`; those local bodies are references, not independently verified deployed implementations.

| Identity | Value |
| --- | --- |
| Chain / SY proxy | 4663 / `0x5d446a2be952f4f9ba241b382a73ad3b1819aaf5` |
| Service-resolved implementation | `0xAdAb46E7024d34E18BeBB058D374aa1069DB461E` |
| Compilation target | `lib/pendle-sy/contracts/core/StandardizedYield/implementations/NET/PendleStakedNetSY.sol:PendleStakedNetSY` |
| Verification record | 47105638; creation/runtime exact_match; verified2026-09-04T08:05:04Z |
| External build | Solidity0.8.30+commit.73712a01; optimizer1,000,000; Cancun; viaIR=true. These are not local compilation settings. |

Primary source URL: `https://sourcify.dev/server/v2/contract/4663/0xAdAb46E7024d34E18BeBB058D374aa1069DB461E?fields=sources`, accessed through the supplied local extract on **2026-09-28**, not freshly fetched in this round. E:3–25 reports 25 decoded sources, content round-trip checks and target UTF-8 keccak256 `0xb0183ce8e725d1541d8f58795f6142e8b0d7b98c5db3793e638d2061744b966b`. These checks are attributed to the extraction manifest, not rerun here. Target/base/helper bodies are now read. Source fidelity and verification-service matching do not establish current proxy implementation, market binding or live state.

#### 6.5.1 Supported branches and units

Let `D = DECIMALS_OFFSET * INDEX_BASE = 10^18`, `Ic = sNET.index()` and `Ip = _syncedIndex()`. Amounts below are **native integers**: x is NET/sNET input, q is SY shares. Local NET/sNET use 9 decimals; SY construction requests an 18-decimal sNET wrapper and copies its returned `decimals()`. Verify actual bound decimals before using the intended NET9/sNET9/SY18 normalization. The SY share token is the proxy's own ERC20, **not** `yieldToken` or `scaledNet` (E:58–66,204–214,679–692).

| Branch | Preview | Actual execution | Unit boundary when metadata is verified |
| --- | --- | --- | --- |
| NET deposit | `floor(x*D/Ip)` | Pull x NET from caller to SY; call `stake(SY,x)`; read post-stake index Ia; mint `floor(x*D/Ia)` SY to explicit receiver | NET9 → SY18 |
| sNET deposit | `floor(x*D/Ic)` | Pull x sNET to SY; no staking call; mint at current index to receiver | sNET9 → SY18 |
| NET redeem | `floor(q*Ip/D)` | Burn q shares; compute nominal amount at Ip; call `unstake(receiver,amount)` | SY18 → nominal NET9 |
| sNET redeem | `floor(q*Ic/D)` | Burn q shares; compute at current index; transfer sNET directly SY→receiver; no staking call | SY18 → sNET9 |
| Any other token, including scaled wrappers/native token | Invalid | Rejected by token validation | No wrapper-conversion route |

Source: E:80–102,131–168,231–270. Zero stateful deposit/redeem inputs revert; positive inputs can round to zero if the minimum permits. `exchangeRate() = Ip*10^9` uses scaled-NET accounting units, whereas `pricingInfo()=(sNet,false)`. It is **not** the current-sNET executable quote when Ip differs from Ic. The missing decimal-wrapper implementation is not a blocker for these raw-token money paths: they never wrap/unwrap. Its returned identities/metadata still require G1 evidence.

#### 6.5.2 Exact projection and call chronology

Preserve the source's nested floors, checked intermediates and short-circuit ordering (E:44–51,113–125):

```text
F = 5_000_000_000 * 10^9
G = uint256.max - (uint256.max mod F)
J = 10^9 * floor(G/F)
M = uint128.max
read epoch end e, queued profit p, current index Ic
if now < e or p == 0: Ip = Ic
else:
    T = sNET.totalSupply(); C = T - sNET.balanceOf(staking)
    if C == 0: Ip = Ic
    else:
        Tnext = min(T + floor(p*T/C), M)
        Ip = floor(J / floor(G/Tnext))
```

The cap is **after** checked p*T and addition; it does not prevent overflow before the clamp. This projects one rebase, not all elapsed epochs. In local `N/Staking.sol:88–104,119–151`, stake/unstake rebase before principal transfers, process at most one overdue epoch, then checkpoint the oracle and queue new distributor output. C=0 skips the sNET rebase, retains old queued profit and still advances end/number. p=0 can leave index unchanged while epoch/queue state changes. `N/StakedNET.sol:25–48,68–99` matches the mirrored constants/nested floors; deployed equivalence remains unproved.

Consequently NET deposit's post-stake index can equal its pre-call projected index even with multiple overdue epochs. The different getter expressions are **not evidence of a preview bug**. Warmup>0 can preserve numerical parity while delivering no immediate sNET backing; verify immediate delivery for NET ingress. A prior sync followed by stake/unstake may process another epoch if still due. Model every actual call in order; do not add a pre-rebase as a supposed parity repair or a catch-up loop. Existing required settlement (§7.1) remains; the full composed route must pin its calls and subsequent index reads.

#### 6.5.3 Fixed-state inverses, bounds and exact-output limitation

For a **fixed positive execution index I**, define:

```text
deposit(x) = floor(x*D/I)       xMin(s) = ceil(s*I/D)
redeem(q)  = floor(q*I/D)       qMin(y) = ceil(y*D/I)
```

These are exact **minimum-sufficient** integer inverses: `floor(q*I/D)>=y` iff `q*I>=y*D`. Check the forward result and, for a positive inverse, check that its predecessor is below target. The projection's nested floors only determine I; they do not invalidate this proof. Zero mathematical inverse is not permission to call a zero-rejecting endpoint. No sampled-rate inverse, guessed +1 share, saturation or redeem/search loop.

Use overflow-safe inverse arithmetic, then enforce the external forward domain: `x <= floor(uint256.max/D)` for deposit; `q <= floor(uint256.max/I)` for redeem; valid projection subtraction/divisors and checked p*T/addition; `Ip*10^9` representable for exchangeRate; mint amount/resulting total supply within uint248 and the **current** owner-set SY cap (E:175–184,426–443,687,877–915). Initial cap=uint256.max is not a live-cap observation. Balance/allowance, transfer-gon and external staking bounds also apply. A backing-based tighter bound needs a proved backing invariant; do not replace these exact guards with disputed approximate exponents or assume all uint248 balances fit.

For `0<I<=D`, qMin reaches y **exactly**, where its forward multiplication is valid. I=D is identity. For I>D, some targets have gaps: I=2D,y=1 gives qMin=1 and nominal output2. Minimum-sufficient is not exact final delivery. A direct exact-output payout must meet the required final net amount and input bounds; this round does **not** select gifting/warehousing excess or blanket removal of unrepresentable ERC4626 withdrawals. Prove the operative domain or finish an existing-rights-compatible delivery/residual route for a reachable gap; the latter is the narrow remaining L3 composition item, not permission to invent economics. Genuine inability to fund required delivery still reverts.

#### 6.5.4 Custody, minimums, fees and actual receipts

- Deposit pulls from msg.sender and mints to the explicit receiver, which need not be the payer. The SY holds sNET backing; the receiver holds **SY shares**. Neither TokenHelper nor `_deposit` measures received deltas, and the target ignores stake's return (E:231–246,1414–1417).
- Ordinary eligible inventory stays hook-held. The hook, as caller, uses `redeem(receiver,q,tokenOut,minNominal,false)`. False burns caller-held shares without pulling another owner's shares; true burns SY's own share balance (E:252–270). True is not an authenticated per-depositor account. Do not park persistent hook reserves at SY for anyone to redeem. Any separately mapped atomic internal-balance router flow must fund/consume only its intended shares in the same operation.
- Redemption order is validation → burn → `_redeem` including payout → compare **nominal computed amount** with minTokenOut → event. The comparison is after payout, but is not a receiver-delta check. A failed downstream call or minimum comparison rolls back the burn. Propagate required failure to roll back earlier outer funding too; no compensating burn-recovery mechanism. Sequential completed calls are not nested reentrancy (E:703–715).
- SY conversion has no fee term. Native Pendle claim fees, any actual NET transfer tax and the existing Weighted/SE fees remain separate hops. Resolve local NET's predicate `taxEnabled && !exempt[from] && !exempt[to] && (taxedPair[from] || taxedPair[to])` against actual endpoints (`N/NET.sol:121–145`); no blanket 500-bps haircut or invented exemption. Where the ordinary non-aliasing hop is `g-floor(g*t/B)`, positive net y minimally needs `floor((y-1)*B/(B-t))+1`; then apply the SY inverse and replay forward. Check sender/receiver/collector aliases. Never charge canonical SE tax twice.
- Measure actual final recipient delivery and actual funding at their hops. A narrow sNET-transfer window excludes rebases of the receiver's old holdings. NET-deposit sNET growth across stake includes the SY's old-inventory rebase: use a rebase-adjusted baseline/gon reconciliation, not total balance growth as new principal. Taxed ingress may consume pre-existing SY NET rather than necessarily reverting; nominal success is not backing proof. Final BasicVault sync records balances, not receipt attribution or minOut proof.

#### 6.5.5 Held-first ordinary-output call sequence

1. Authenticate limits/route/callback phase, capture supported public pretransfer credit, and perform the operation's required epoch/TWAP/expansion settlement. Construct a coherent state after those calls.
2. Let H be **recognized eligible held SY**, C remaining eligible **net-claimable SY**, excluding payables, exclusive principal, transient Keep-YT and allocated principal-exit SY. H is not `max(raw-booked,0)`; that is the separate origin-independent public-credit rule. Do not count a settled receivable beside its received cash.
3. Quote NET/sNET output with §6.4's existing Weighted/native wrapper in the selected pricing coordinate, fee once. NET pricing remains PLP/YT-derived; sNET pricing uses the validated provider. Independently derive raw SY debit d from the actual final-delivery hops and branch inverse. Require `d < H+C` and valid arithmetic/custody.
4. If H>=d, use held inventory without a funding claim. H=d,C=1 is valid for the retained-inventory test; H=d,C=0 is not. If H<d, invoke the configured Pendle market/YT claim phase mapped conditionally in §6.6. `SY.claimRewards` and its other reward methods return empty arrays (E:309–333). Claim-only-if-short is a trigger, not a fictitious partial-shortfall selector; the actual API may claim more.
5. Measure received SY, deduct the settled receivable once, reconcile actual claim fees and remaining C; retain eligible SY and attempt other-token forwarding to dynamic feeTo under its existing best-effort rule. Recompute affected pricing, branch index and d after claim/ingress/other state-changing steps. At redemption require now-held H>=d and `H+C-d>=1` raw SY unit. If insufficient, revert; no retry solver, ordinary PLP/YT liquidation or partial payout.
6. Redeem once from hook-held shares, with nominal minimum plus outer net-delivery protections. Check actual SY debit, actual final recipient delivery, input/HLP maxima, and coherent post-redemption eligible H+C>=1. Recompute remaining claims if the redemption changed relevant state. NET and sNET do not have separate cash budgets.
7. Commit economic debits/receipts once, perform authorized refunds, then full expected-token synchronization. Any required claim/conversion/delivery failure reverts all input, claim, burn, epoch, ledger and observation effects. Only the selected outgoing fee-forwarding exception is caught.

Owned-HLP burn/reinvestment and allocated position exits remain **distinct**: construct the actual owned reserve book first, use the selected BasePoolMath mode, realize only allocated PLP/YT, and feed its resulting SY into this final edge. This edge does not prove the upstream realization inverse. No universal h/H shortcut, public-LP appropriation or ordinary-output principal fallback.

#### 6.5.6 Provider specification and rounding boundary

Use token-specific current-sNET conversion, not projected `exchangeRate()`. PRD §4.5 normalization remains `floor(a*10^syDecimals*10^18/(q*10^targetDecimals))`, with `a=previewRedeem(target,q)`. For verified SY18/sNET9 and this compilation, a **one-whole-SY sample q=10^18** yields a=Ic and rate=Ic*10^9 exactly, subject to source domain checks. A one-raw-unit sample can return zero at the initial index and is unsuitable. Invalid target, zero/invalid index, metadata mismatch or failed source reads must not fabricate a rate.

This provides the source-derived sample for this binding, not a universal sample for every external SY. Pin the provider/caller scaling and rounding chain before plan freeze: multiplying a raw SY book by this per-share rate can differ from first flooring the whole book to native sNET and then scaling. Do not silently replace the selected provider valuation with a whole-book redeem floor. Full-size executable funding always uses §6.5.3 independently.

#### 6.5.7 Finite remaining dependencies and separate statuses

| Dependency | Exact affected branch / deliverable |
| --- | --- |
| Current SY proxy/code/immutables, market binding and token decimals with observation block | All paths; source compilation identity is not current deployment evidence. Wrapper money-path bodies are unnecessary for these raw branches; metadata/identity evidence is necessary. |
| Deployed sNET/Staking mirror constants, epoch tuple/rebase ordering, enabled/oracle/distributor behavior | NET preview/deposit/redeem projection and every composed operation that actually invokes staking. Local references alone cannot prove equivalence. |
| Warmup/immediate backing, live NET/sNET approvals and backing balances | NET ingress instant sNET delivery; NET redemption backing pull and staking NET payout. Warmup is not an additional dependency of an isolated direct-sNET transfer branch. |
| Live index, SY pause/current cap, supported tokens and balances/allowances | Current-index sNET branches; mint cap affects deposits, not redemption. Source arithmetic limits remain regardless of current capacity. |
| Actual endpoint tax/exemption/collector state and receipt windows | Caller→SY, SY→staking, staking→receiver and any actual intermediate NET delivery; no generic tax assumption. |
| Configured market/YT claim implementation, entitlement and prior receipts | Local **YTv1** claim/fee/cache/expiry graph is mapped in §6.6. Deployed V1/V2 binding is unknown; V2 getter differs and its body has not been reviewed. Prior-force-claim role reconciliation needs a source-backed on-chain mechanism, not event monitoring or automatic surplus appropriation. G1 fees/cache/treasury/gauge observations remain. |
| Full Keep-YT/owned-HLP/rollover call graph and provider/caller rounding | Earlier realization edges, epoch order, exact-input/output limits and accounting; final SY inverse alone does not close them. |
| Exact-output representation/domain and conversion residual rights | I>D or other composed-rounding gaps: prove reachable domain or source-map delivery under existing rights; do not assign a new residual beneficiary or silently drop required routes. |

**Status:** source-level conversion mapping is **resolved**; complete L3 composition is **pending** on the concrete rows above, not on extraction. G1 deployment/state evidence is **pending** and separate from specification work and later tests. G0/L4 unchanged; L1/L2 resolved; NN-03 closed. No new economics, alternate external SY or execution authorization.

#### 6.5.8 Additional verification cases — planned, not executed

Use production-first proxy/TestBase validation under a separate authorized task; distinguish local-reference differentials from block-pinned deployed equivalence. Preserve existing §11 acceptance cases and add:

| Case | Required result |
| --- | --- |
| Four branches and metadata | Only NET/sNET accepted; distinguish SY share/underlying/wrapper addresses and native9/SY18 boundaries. |
| Initial and dust vectors | I=1e9,x=1e9 →1e18 SY. I=1.5e9,y=1 →q=666666667; predecessor outputs0. At that I deposit x=1 →666666666 SY →0 native on redeem. |
| Projection boundaries | now=end−1 vs end; positive/zero profit, C=0, below/at/above cap; reproduce both index floors and pre-cap overflow reverts. |
| Multi-overdue sequence | One stake/unstake advances at most one epoch; a preceding required sync plus later call may advance two. C=0 skips sNET rebase, retains queue and advances epoch. |
| Conditional preview parity | Post-stake index equals prior Ip for matched reference state; warmup>0 can preserve nominal parity but fails immediate-backing assumptions. No invented preview multiplier. |
| Custody and atomicity | Explicit receiver gets SY shares; hook uses false. True consumes SY-owned shares only, without depositor authentication. Downstream revert and post-payout min failure restore burn and whole required route. |
| Actual receipts/taxes | Nominal min passes but net receiver short → full revert; taxed ingress with/without prior SY inventory; no old sNET rebase credited as receipt; no duplicated SE/Weighted fee. |
| Shared budget | H=d+1,C=0 and H=d,C=1 succeed without claim; H=d,C=0 fails. H<d triggers claim; after partial claim H=d,Cremaining=1 is valid. Fees/short delivery may invalidate funding; rollback, no principal fallback. |
| Source domains | Forward x*D/q*I, projection intermediates, uint248 mint and current cap boundaries; no saturating inverse or assumption that all storage-representable balances fit. |
| Exact-output gap | I=D is identity; I=2D,y=1 distinguishes minimum-sufficient from exact. Required-route domain/residual proof must be explicit, not a test that silently drops ERC4626 withdrawal. |
| Provider versus funding | q=1 raw gives zero at initial I; q=1e18 gives Ic under verified decimals. Compare selected rate/caller rounding separately from full-size redemption; never use projected NET rate as overdue sNET rate. |
| Composition/interleavings | NET/sNET sequential outputs and HLP/claim interleavings share one eligible budget; realized principal, fee payables and public pretransfer credit are not counted twice. |

### 6.6 Pendle claim phase composed with SY redemption — local reference, conditional binding

**Source review 2026-09-28:** [claim-funding consolidation](../../../research/netnet-pendle-claim-funding/COUNCIL_CONSOLIDATION.md). Four originals and four same-session reviews were returned; one reviewer explicitly did not finish one peer original, so this is a moderator-source-checked specification, not a claim of complete four-way review coverage or unanimity. No tests executed.

In this section **P** = `lib/crane/contracts/protocols/perps/pendle/`. Paths/lines refer to the inspected local reference, **not verified chain4663 bytecode**. `PendleYieldToken` / `InterestManagerYT` use pragma ^0.8.17; gauge/reward/math helpers ^0.8.0. No upstream commit/build pin was established. Existing §6.5's external SY compilation evidence does not establish YT/market equivalence.

**Version gate:** the following equations apply to the inspected **YTv1** body. `P/interfaces/IPInterestManagerYTV2.sol:4–8` instead exposes `(uint128 lastInterestIndex,uint128 accruedInterest,uint256 lastPYIndex)`, while V1 stores `(uint128 index,uint128 accrued)`. V2 retains the same claim signature (`IPYieldTokenV2.sol:36–38`); selector compatibility does not prove interest-formula compatibility. Establish the configured YT code/version before adopting these equations; if V2, obtain and review that actual body. This is a concrete missing source/binding proof, not a new economics question.

#### 6.6.1 Calls, entitlement owners and recipients

| Call | Actual local behavior and source |
| --- | --- |
| `YT.redeemDueInterestAndRewards(address user,bool redeemInterest,bool redeemRewards) -> (uint256 interestOut,uint256[] rewardsOut)` | Permissionless; pays user, not caller; both flags false reverts. Updates reward accounting, optionally pays rewards, then accrues/pays interest. No partial-amount parameter. `P/core/YieldContracts/PendleYieldToken.sol:166–193`. |
| `market.redeemRewards(address user) -> uint256[]` | Permissionless LP-incentive claim to user; update accrued using old activeBalance, refresh activeBalance, then pay. No LP burn or PT/SY reserve withdrawal. `P/core/Market/v3/PendleMarketV3.sol:237–244`; `P/core/Market/PendleGauge.sol:43–83`. |
| Router `redeemDueInterestAndRewards(address user,address[] sys,address[] yts,address[] markets)` | Ordered SY claims, YT(user,true,true), market(user); returns no amounts. Cannot express an interest-only YT claim. `P/router/ActionMiscV3.sol:67–84`. |
| `SY.claimRewards(user)` for the extracted SY | Empty; does not fund the shortfall. §6.5 E:309–333. |
| `redeemPY`, LP burn/position exit, `skim`, post-expiry treasury collection | Not ordinary-output interest funding. Principal realization remains its separately authorized route; skim sends excess PT/SY to market treasury, not hook. `PendleYieldToken.sol:124–153,199–226,317–355`; `PendleMarketV3.sol:224–230`. |

Use the hook as beneficiary and its retained YT balance/claims. No YT/LP transfer, approval or router custody is necessary merely to claim. A third party can claim for the hook, but cannot change the payout recipient within that claim. Market normally accounts PT+SY reserves; donated/transferred YT **can** sit at market and earn as user=market. That claim pays market, not hook, and is excluded from hook C. The interest-distribution exclusion for `address(this)` means the **YT contract**, not market.

For the inspected SY, YT reward tokens are empty (`PendleYieldToken.sol:417–419`); market reward list appends its controller-derived PENDLE address (`PendleGauge.sol:31–35,102–106`). Prove that address differs from reserve SY before declaring no collision. Same-token retention alone never grants spendability. No deployed collision was observed or invented.

#### 6.6.2 Exact V1 net-claimable SY

Let W=1e18, b=raw hook YT balance, j=stored user interest index, a=stored **gross** accrued SY, k=the index the claim actually uses, and f=current YT-factory interestFeeRate. Compute per YT:

```text
delta = 0                              if j == k or j == 0
delta = floor(b*(k-j)*W/(j*k))           otherwise
gross = a + delta
fee = floor(gross*f/W)
C_i = gross - fee
```

Source: `P/core/YieldContracts/InterestManagerYT.sol:26–80`; `P/core/libraries/math/PMath.sol:34–53`. j=0 initializes index without retroactive accrual; j=k adds no new accrual, but neither condition erases stored a. Claim clears gross accrued, pays fee SY to **Pendle factory treasury**, then net SY to hook. Do not forward that fee again to hook feeTo. `floor(gross*(W-f)/W)` is **not** the net formula: gross19,f=0.05W yields fee0/net19, not18. Nor is accrual a difference of separately floored principal equivalents.

`userInterest.accrued` alone is stale and gross. C includes current delta and is net-of-fee, with one fee floor per source's total gross at the actual claim. Fee rates/treasury are mutable local-factory state; its 20% setter cap is not a live rate (`PendleYieldContractFactory.sol:58–73,169–191`). Preserve checked b*(k−j), multiplication by W, j*k, uint128 index/accrued casts/additions and gross*f. Wider view arithmetic must not certify an external execution that would revert.

Index rules (`PendleYieldToken.sol:52–56,373–407`):

- Pre-expiry: if doCacheIndexSameBlock and this block was already updated, use stored PY index **without a new SY exchangeRate read**. Otherwise use checked uint128 `max(SY.exchangeRate(),storedPYIndex)` and update its block/cache. A second pyIndexCurrent call cannot bypass an active cache.
- After expiry: initialize postExpiry on first applicable post-expiry touch, including external reward collection; freeze firstPYIndex at that touch's max/cache value. This is not a reconstruction at the exact expiry timestamp. Later user accrual uses that frozen index. Unpaid accrued remains payable, including after the user's YT balance becomes zero; later growth is not continuing user C.
- YT transfers checkpoint rewards then interest for both parties **before** moving balances (`:499–503`). They do not pay or zero accrued claims; sender retains its accrued rights and recipient retains its own prior rights. No new ban on selected YT transfers/exits is introduced. Post-expiry mint restrictions do not themselves prohibit ERC20 transfers.

YT reward payouts, if any, use their own gross-minus-floor(rewardFee) before and after expiry (`:421–469`). Market incentive payouts use `RewardManager.sol:61–76` and **do not apply this YT factory fee**. Market indexing uses active reward shares, not an h/H claim on reserve assets: accrue before ve-weight refresh; once-per-block indexing of newly received reward balances; zero totalActiveSupply absorbs receipts into lastBalance without retroactive allocation (`RewardManager.sol:16–76`; `RewardManagerAbstract.sol:44–64`). A permissionless claim can refresh future gauge weight; fixed recipient is not a timing-neutrality guarantee.

#### 6.6.3 Required collection versus isolated forwarding

For the shortfall phase, preserve PRD §6.2's collection of available interest/rewards and §13's **outgoing-forwarding-only** exception. The concrete direct reference sequence for one validated series is:

```text
YT.redeemDueInterestAndRewards(hook, true, true)
market.redeemRewards(hook)
book measured interest and incentive receipts separately
attempt hook -> current feeTo forwarding of fee-destined receipts
```

Direct calls retain return values and separate measurement windows. A mapped router batch `(hook,[],[YT],[market])` has the same beneficiaries/flags, but no returns; it is not required. Historical permissionless collection uses the explicitly supplied retained validated series, not an implicit unbounded history scan. An interest-only `YT(hook,true,false)` is a supported subcall, **not permission to omit the phase's required reward collection, delay it to another transaction, or catch upstream claim failure**. If splitting the calls for measurement, keep the complete required phase and atomic failure behavior. No economics decision is left to the implementer here.

All required YT/market/controller, fee-treasury and claim-to-hook failures propagate. Only the hook's later transfer of already received fee-owned tokens to feeTo is isolated; failed delivery retains its excluded payable. Splitting two uncaught external calls in the same transaction does not make the second failure nonblocking. Do not use router allowFailure or try/catch around upstream incentive collection as a forwarding exception.

Even true,false always updates reward accounting; pre-expiry it can invoke SY.rewardIndexesCurrent, and first post-expiry initialization invokes SY.claimRewards before the body. Thus that flag is not a general upstream-reward-dependency bypass. With this exact empty-reward SY those methods are no-ops, but true,true additionally reads factory reward parameters; do not claim universal gas/failure equivalence.

#### 6.6.4 Once-only ledger and force-claims

H is recognized eligible held SY; C is the sum of **current net** eligible hook claims in the **same SY token**. Keep excluded payables, allocated principal and transient Keep-YT separate. Different historical SYs cannot be added as raw units without an independently mapped conversion.

For an in-operation claim of source A with expected net n, actual receipt c, and other remaining claims Cother:

```text
before: C = n + Cother
after:  H' = H + c
        C' = recomputed remaining native claims (Cother if otherwise unchanged)
same coherent state: (H'+C') - (H+C) = c - n
```

Clear the extinguished **net** entitlement; do not subtract c+fee from net C or leave n−c as a phantom receivable after the native claim cleared. Check actual SY delta against returned interestOut for the named ordinary-transfer SY, with explicit endpoint aliases: if factory treasury equals hook, its separate fee receipt is not automatically hook-owned interest. Attribute known fee/reward legs separately or leave that binding unvalidated; do not silently misbook a combined delta. Recompute remaining claims after later state changes rather than assuming the just-claimed series or whole portfolio stays zero forever.

A prior force-claim updates native accrual and raw hook balance without notifying hook accounting. Capture valid declared public pretransfer credit from `max(raw-booked,0)` **before** sync/recognition erases it; origin-independent L2 remains unchanged. Refresh native C immediately. Units consumed/refunded as that caller's credit are not also inherited H or an outstanding receivable. Reconcile only still-attributable, unconsumed receipts once; do not auto-classify every surplus or donation as interest.

**Remaining implementation-specification detail:** current raw surplus plus a zero upstream accrued balance does not alone identify which historical receipt was interest, an incentive or an unrelated donation. Ordinary on-chain execution cannot “monitor past events” as a contract primitive. The operation-state/retained-series accounting must specify source-backed reconciliation without requiring public payer provenance, fabricating lost receivables or appropriating declared credit. This round fixes ordering and conservation, not an unimplemented notification mechanism. A validated absence of same-token incentive simplifies this case, but does not establish arbitrary historical receipt provenance.

#### 6.6.5 Claim → redemption sequence and chronology

1. Apply §6.5.5 authentication, callback guard, public-credit capture and required epoch/TWAP/expansion pre-steps. Reconcile known receipts and current source claims. Fix validated addresses/series; never accept arbitrary claim targets/beneficiaries.
2. Compute current net C_i using the verified implementation's cache/max/expiry/fee rules. Construct the selected Weighted pricing snapshot and independently derive raw SY debit d by §6.5's branch inverse/actual output hops. Require d<H+C and source domains. If H>=d, skip funding collection; H=d,C>=1 is valid.
3. If H<d, execute the selected series' complete direct collection phase (§6.6.3), measuring each token/interest leg. Claims collect all selected accrued entitlement, not just d−H. Book eligible interest H and excluded reward payables separately, clear only settled sources, preserve other valid C. Do not count unrelated/different-SY historical claims as available for this redemption or scan all history implicitly.
4. Attempt only downstream feeTo forwarding under isolation. Refresh affected H/C, fees, provider/pricing and branch index/d; source-compatible calculation may prove individual values unchanged, but do not assume neutrality from the word “claim.” Require actual H>=d and H+C−d>=1. If the bounded phase cannot fund the output, revert rather than retry, liquidate ordinary PLP/YT, or pay partially.
5. Call `SY.redeem(receiver,d,tokenOut,minNominal,false)` as hook. Enforce actual SY debit, actual recipient delivery, all user input/output maxima/minima, and existing exact-output residual/domain requirements. Source nominal min alone is insufficient.
6. Recompute affected post-redemption C and require Hafter+Cafter>=1. Do not use speculative accrual generated by redemption to satisfy the earlier held-funding/pre-redemption remainder test. Commit once, apply only the route's already-authorized refunds, then full expected-token sync. Required failure rolls back all input, claim, cache, epoch, ledger, burn and payout effects.

**Chronology fact, conditional on bindings:** YT claims may write PY index using the extracted SY's projected `exchangeRate()` but do not call NetNet stake/unstake/rebase. Market's inspected empty-SY-reward/controller graph likewise has no direct NetNet staking call; configured controller/ve/token behavior still needs verification. A later NET SY redemption invokes unstake and can process one overdue epoch; direct sNET redemption uses current index and does not. Subsequent uncached YT accrual can therefore change after NET redemption. Never use PY index as the sNET redemption index.

PY is a high-water/cache/frozen index, not necessarily current executable SY rate. Accurate same-state net C→measured H replacement is conservative accounting, **not an unconditional no-loss, claim-valuation-neutrality or economic-soundness proof**. Projection inputs, prior index ratchets, force-claim timing, fees and expiry can invalidate a stale estimate; source receipts and final budget checks remain mandatory. No extra pre-rebase/parity repair or catch-up loop is added.

#### 6.6.6 Verification vectors and remaining binding proof

All rows are **planned and unexecuted**, using production-first proxy/TestBase paths under separate authorization. W=1e18; toy fee/index values are not observations.

| Vector | Required result |
| --- | --- |
| b1000,j=W,k=2W,a0,f=0.1W | delta500,fee50,net C450 raw SY; missing W would be wrong. |
| b1,j=0.75W,k=1.5W | source delta0, whereas difference of floored principal equivalents gives1. |
| j=k,a7,f0 | no new accrual but claim pays7; j0 initializes without a retrospective grant. |
| gross19 vs20 at f=0.05W | fees0 vs1, both net19; two gross10 claims net20 versus one gross20 claim net19. |
| H100,C450,d549 | claim→H550,C0; redeem549 leaves1. d550 rejects complete drainage. |
| H8,C_A3,C_B4,d10; settle A | H11,C_B4 remains; no global C reset. H=d,C1 skips funding claim. |
| Expected n450, receipt449,H100,d549 | source cleared; no fake C1; mismatch/remainder failure rolls back. |
| Force-claim receipt450 then declared public credit450 | snapshot credit first, refresh C; no duplicate inherited H/receivable; test unrelated same-token surplus separately. |
| Cached W vs live2W in same block | repeated pyIndexCurrent cannot force refresh; later uncached computation can differ. |
| Stored PY2W vs live1.5W, b1000,jW | max gives delta500, not333; not a proof of a reachable profitable attack. |
| First post-expiry index2W vs later live3W | user delta500 for b1000,jW; no retroactive exact-expiry reconstruction; later growth excluded. |
| Transfer YT after accrual | mappings checkpoint; no payout/zeroing; sender may claim with zero remaining balance; selected post-expiry transfers not banned by mint restriction. |
| Required market/controller or treasury transfer failure | whole collection/redemption route rolls back. Hook→feeTo failure alone retains excluded payable and may succeed. |
| Market totalActive0 receives10 | lastBalance absorbs10 without index increment; no retroactive next-LP grant. Claims refresh active weights after prior accrual. |
| YT donated to market | claims pay market, not hook; no ordinary-output principal/skim fallback. |
| Claim then NET/sNET redemption | claim leaves NetNet epoch unchanged; NET can process one, sNET none; post C respects cache/freeze. |
| V1 versus V2/aliases | incompatible userInterest layout cannot silently use V1 formula; PENDLE==SY or treasury==hook requires explicit accounting/binding proof. |

**Next binding task:** identify actual configured market/YT implementation, code identity and factory-recognized SY/PT/YT relationships at an observation block; establish V1/V2 and acquire its actual body if different. Observe cache/expiry/postExpiry state, factory fees/treasury, controller/PENDLE/ve identities and reward list, balances/allowances and existing SY/NetNet equivalence. No version is inferred from a V6 factory address or a matching selector. `ActionInfoStatic.getUserPYInfo/getUserMarketInfo` actually invoke claims (`P/offchain-helpers/router-static/base/ActionInfoStatic.sol:56–95`); do not use their names to justify state-changing calls in a read-only quote path.

**Status:** local V1 claim graph and conditional claim→SY sequence are mapped; configured deployment/source applicability, prior-receipt reconciliation mechanism and full L3 composition remain pending. Provider/caller rounding, owned-HLP/Keep-YT realization and exact-output residual/domain work are not closed here. L1/L2/NN-03 remain resolved; G0/L4 unchanged. No product implementation authorization follows.

## 7. State transitions and ordering

### 7.1 Common money-route skeleton

1. Authenticate caller/owner/operator, token/route, deadlines, pretransfer mode and supplied limits.
2. Acquire the relevant component/operation guards; authenticate cross-component callback context.
3. Accumulate elapsed oracle time at the prior mark before any relevant price/state change.
4. Settle required NET processed-epoch state and due expansion before participation changes; always checkpoint/store synthetic readiness/TWAP on a state-changing expansion check.
5. Reconcile required claims/payables/actual receipts and construct one coherent projected quote snapshot. A preview projects the same transition without writing.
6. Select the allowed route; execute under limits and measure actual receipts/costs. Do not expose intermediate backing through nested views/money routes.
7. Update economic ownership, token/share supply and principal/reward ledgers exactly once. Record post-state marks for subsequent time intervals.
8. Apply authorized this-call refunds, then full expected-held reserve synchronization; emit operation events with actual amounts and branch.
9. Any required failure reverts the entire operation. Only outgoing fee-reward forwarding has the selected best-effort exception; required asset/conversion/funding failure does not.

Apply §6.1's caller-responsibility pretransfer algorithm and capture its available/credited budget before internal movements can be confused with a second input. No payer/provenance authentication is required for pre-existing unbooked surplus. Preserve normal allowance/position/callback authority and once-only protocol claim bookkeeping; internal staking funding contexts remain as specified in §9.

### 7.2 Operation matrix

| Operation | Funding / action | Supply and ownership outcome |
| --- | --- | --- |
| Liquid NET/sNET→DETF | Keep-YT acquisition, buy existing hook DETF | No user issuance; position backing changes; existing DETF transferred |
| Liquid USDG→DETF | Deposit custom SE, buy existing hook DETF | No user issuance; actual SE shares enter book |
| Ordinary DETF→NET/sNET | Shared eligible held SY first, claim only if needed, redeem net requested token | DETF becomes reserve inventory; no burn attributable to swap |
| Ordinary output→USDG | Debit applicable SE shares, net SE redemption | No HLP-user underlying unwrap alias |
| Eligible standard burn | Owned-book incentive quote, actual asset realization, actual-q burn | Supply decreases by q, apart from separately settled expansion; no virtual bonus token |
| HLP add/remove | BasePoolMath mode, actual custody units and limits | Only HLP supply changes; no unlocked DETF issuance or omitted-leg coupon |
| Liquid DETF stake/unstake | Actual DETF custody transfer and resolved share conversion | No reserve claim; native payout1:1, no new bond lock |
| Fresh bond | Actual capital plus G into full/live book, separate purchased principal and reward funding | Bond/NFT receives funded stake; HLP belongs to DETF |
| Dedicated reinvestment | Old principal backing debit, no-bonus owned-book burn, supported asset→new bond | Old claim reduced once; new funded principal once; other positions untouched |
| Native wrapper purchase | Deploy/validate holder; authorized native deposit; record returned index | Old/new NFT creation coherent; no DETF against uncollected note |
| Native harvest | Holder collects; actual NET including attributable excess contributes/mints/stakes | Credit same tokenId; no intermediate principal harvest succeeds alone |
| Rollover | Factory-first validation, old realization, SY conversion, successor Keep-YT, commit | No fresh DETF required; HLP proportions and NFT rights preserved |

### 7.3 Native holder and NFT lifecycle

Use explicit lifecycle validity fields, not a zero nativeNoteId or zero purchaseEpoch as an existence test. Record purchase epoch from NetNet's exposed processed counter. The holder stores/returns the intended purchase's actual native noteId/payout/end; NFT maps it to tokenId.

- **Purchase:** tokenId/holder association, initialization, payment conversion, native purchase and NFT issuance are atomic. Pre-existing unsolicited notes are not adopted as intended notes.
- **Partial native collection:** reconcile intended increment plus aggregate excess, contribute/mint/stake under old tokenId. Do not reset its purchase lock on intermediate collection.
- **Final intended collection:** completion requires successful contribution/funding and intended claimed==payout. Record resulting processed epoch E and final unlock target E+1; an earlier same-transaction epoch advancement is not the later epoch. Reverted collection sets no marker. Do not wait for gifted notes to finish or reset completion on no-op harvests.
- **Early reward claim:** release only funded reward entitlement; locked principal remains backed. TokenId transfer carries all remaining rights and timestamps/checkpoints.
- **Pre-maturity rebond:** debit requested q≤actual funded principal and its corresponding staking shares. New tokenId has its own destination-type lock. Old NFT/holder/note remains for remainder/rewards/future proceeds, even when current principal becomes zero. Do not require another native redeem solely to use funded DETF.
- **Final principal withdrawal:** processed epoch≥unlock target, or assigned maturity for the applicable epoch0 class; settle required expansion first. Native-wrapper final E+1 does not impose a new eight-hour elapsed timer or positive-reward condition.
- **Late excess principal:** successful post-completion native-redemption excess contributes/mints/stakes under the same NFT and inherits its existing unlock target. If that unlock is already satisfied, it remains satisfied; do not set a fresh E′+1 or relock old principal. Ordinary settlement, funding and authorization checks still apply.
- **Inactive/empty NFT:** a zero-principal/reward balance or a user ceasing activity causes no terminal transition. No explicit retirement process, selector, retirement burn or terminal flag. Preserve NFT/holder/native-note mappings and future receipt rights under current tokenId ownership. Position-local gon/dust cleanup is accounting only, not NFT destruction or abandonment of future rights.

The selected isolation reduces legitimate aggregation but does not bound one holder's upstream native-note loop. Report measured cost/limits later; do not fabricate a selective native selector, prune, sweep or attack-impossibility claim.

## 8. Oracle and expansion design

### 8.1 Arithmetic observation contract

Use one declared arithmetic-observation interface implemented separately by the hook spot series and DETF synthetic series:

```text
seriesInfo() -> (bytes32 kind, address baseToken, address quoteToken,
                 uint8 priceDecimals, uint32 windowSeconds)
consult() -> (bool ready, uint256 priceWad, uint64 timestamp)
latestObservation() -> (uint64 timestamp, uint256 cumulativeHi,
                        uint256 cumulativeLo, uint256 postPriceWad)
```

Both return base=DETF, quote=NET, priceDecimals18, windowSeconds3600; kind distinguishes spot from synthetic. Checkpoint updates are internal or authenticated component calls, never caller-supplied prices. Emit `PriceCheckpointed(kind,timestamp,cumulativeHi,cumulativeLo,postPriceWad)` and expose normal declaration/loupe tests; selectors/interface IDs are derived from the declarations, not hand-written hex.

**History:** store an activation-valid flag/time and a 3601-entry circular buffer of `(uint64 timestamp, uint256 cumulativeHi, uint256 cumulativeLo, uint256 postPriceWad)`, with count and next-write index. Require monotone uint64 timestamps; checked conversion rejects timestamps outside that domain. Use two-limb cumulative arithmetic, not unchecked uint256 truncation.

**Write:** before the price-affecting transition, extend prior C by prior recorded price×elapsed seconds. After the transition, set the new authoritative mark. If timestamp is unchanged, preserve cumulative and replace only the newest post-price; never allocate another slot or average same-second samples. Reverts restore both writes and all operation state. First valid activation starts C=0 with no earlier observation.

**Consult at t:** project Cnow from the latest point without writing. If valid history is younger than3600s, return ready=false and a non-measurement placeholder0. Otherwise binary-search the chronologically indexed ring for the latest point j with `tj<=t−3600`, set `Cboundary=Cj+pj*(t−3600−tj)`, and return `floor((Cnow−Cboundary)/3600)`. This is a history-index search, not a forbidden exact-output amount solver. If the predecessor is absent despite sufficient valid history, signal an invariant fault rather than fabricate warm-up.

**Retention proof:** at most one record exists per distinct integer second. Any3601 retained distinct timestamps span at least3600s. Hence the oldest retained point is no later than `latestTimestamp−3600`, which is no later than `consultTime−3600`; the latest predecessor for the consultation boundary is retained. Before the ring fills all points are kept. Quiet intervals require counterfactual extension, not synthetic entries. This proof depends on same-timestamp coalescing and establishes retention, not gas sufficiency.

**Arithmetic bound:** uint256 price integrated across a monotone uint64 timestamp horizon is below2^320; a two-limb512-bit cumulative suffices. Compute the wide 3600s difference before dividing; the average is bounded by the maximum represented price and fits uint256. Addition/multiplication carry and wide division require independently checked tests.

The integrand is the recorded piecewise-constant observed price. External-only valuation changes are observed at the next valid checkpoint, not replayed into unobserved history. Every state-changing expansion check records synthetic observations/readiness, including n=0/zero mint. Hook swaps and relevant non-swap book changes capture spot; supply/owned-reserve/valuation changes capture synthetic before/after. A consultation extends the last recorded price and does not invent prior external marks.

Separate no-history from invalid/no-live valuation and dependency failure. A failure is not a measured below-peg zero and must not be caught as warm-up to force the above-1 branch. Preview and stateful processing project the same observations and readiness.

### 8.2 Expansion state machine

Read actual processed NET epoch number from the configured staking dependency. Let n be completed unconsumed epochs and S0 actual native DETF total supply at settlement entry. Settle before adding/removing/transferring participation.

```text
capture synthetic observations/readiness on every check
if n == 0: minted = 0
else if hook TWAP unavailable or hook TWAP > 1 NET/DETF:
    minted = floor(S0*n/200)
else:
    minted = 0
consume n once on successful settlement
mint actual reward to staking custody
the notified reward receipt applies §9's funded allocation/rebase/recipient receipts once
process triggering operation using resulting state
```

Use full-precision `mulDiv(S0,n,200)` with one final floor. Require the result and `S0+minted` to fit the native supply representation before writing markers; if they do not, revert the whole settlement with an arithmetic-domain error. This is an explicit representability failure, not a cap, discarded epoch or demonstrated recovery. No epoch loop, premium multiplier, Universal highest-leg policy or smaller unrelated integer supply ceiling. W12 must report the operating horizon for actual starting supply/processed-epoch assumptions and expose any practical incompatibility; no unexamined unlimited-liveness claim.

**Concrete first-bond arithmetic:** in the actual lead-payment denomination, `Q(x)=floor(nativeToWad(pair,x)*1e9/P0)`, `G=Q(A)`, `Uquote=Q(floor(A*M/WAD))`, `principal=floor(Uquote*(WAD−p)/WAD)`, `reward=floor(Uquote*p/WAD)+floor(G*p/WAD)`. Mint G+principal+reward only. Additional required legs follow reference opening-rate input sizing, using independently bound real conversions; do not assign sNET=NET or a USDG price from their names. NET P0=1000e18 and creation=1e18 are separate. Actual SY capital fills the SY leg while earned interest is zero. Full native book, inner geometric minimum and positive outer invariant-minus-minimum issuance are required in the same atomic transaction. No partial-book bypass or separately committed seed. Exact other-leg values remain a G1-supported configuration/unit mapping, not guessed token ratios.

Fee/creator issuance and previews must agree on resulting K, total gons and dust. The triggering deposit participates only after prior expansion/recipient receipts; stake already present participates regardless of age. A notified expansion mint performs distribution once, not an additional pull-based fundRewards call.

## 9. Funded-gons staking with transfer-triggered reward distribution

### 9.1 Selected source and state

PRD v0.31 expressly replaces the literal live-B/U/no-divisor-refresh requirement. Reuse `DETFFundedStakingMath`, `DETFFundedStakingRepo` and `StakedDETFTarget` mechanics; add a custom received-funding adapter and parent-token notification. Neither that adapter nor full movement coverage exists unchanged in the current reference. Do not import stock NetNet preminted inventory, MAX_SUPPLY, epoch clock or source NFT linear vesting.

State: `gonsPerUnit K` initialized1e36, `totalGons Q`, per-account gons, accountedBacking, allocationDust, stakingDust, persistent feeWeight/creatorWeight, and synchronization/funding-context state. Each bond records native remaining principal and its attributed staking gons. Standing weights are not redeemable gons. Actual DETF custody must cover accountedBacking, which covers funded liabilities and their dust. Previously unexplained surplus is not current-operation funding.

```text
balance(a) = floor(gonsOf[a]/K)
totalSupply = floor(Q/K)
native x credit/transfer/partial debit = x*K gons
```

At unchanged K, adding/subtracting x*K changes the displayed native balance exactly by x. The token performs no holder enumeration. Bond reward value is current attributed staking value minus remaining native principal; moving that native reward in sDETF transfers the corresponding gons and leaves principal exactly represented. Prior L1 live-ratio counterexamples concern a different representation and are historical, not operative tests requiring the old formula.

### 9.2 Existing funded allocation, rebase and dust

Apply standing-weight top-ups from `DETFSeigniorageShareLib._topUpDeltas` to funded ordinary weight Q after the relevant ownership-changing event. Previously issued fee/creator receipts are ordinary gons for subsequent distributions; persistent standing weights are separate and never shrink merely because a recipient unstakes.

For new received reward A, reuse the exact reference sequence:

1. Increment accountedBacking by the authenticated received A once and assert actual custody covers it.
2. Allocate `A+allocationDust` using `DETFFundedStakingMath._allocate` with Q,feeWeight,creatorWeight and source REWARD_SCALE1e54. Store its new allocationDust. Do not replace weight allocation with constant F=fA/C=cA.
3. Let S be allocated ordinary reward plus prior stakingDust. For Q>0 and S>0, `oldLiability=floor(Q/K)`, `target=oldLiability+S`, `newK=ceil(Q/target)`, `growth=floor(Q/newK)-oldLiability`, `stakingDust=target-floor(Q/newK)`. Otherwise retain the source no-rebase/dust branch. Never reset K when supply becomes empty.
4. Issue fee/creator funded receipts using their allocated native F/C times the resulting K, increasing their gons and Q without adding backing again.
5. Top up standing weights for future distributions. Emit the source-equivalent funded reward amounts/growth/K/dust.

Rebase ordinary stake before issuing new recipient receipts so those receipts do not earn their own distribution. Zero ordinary Q with standing weights still allocates funded receipts; all-zero total weight retains the explicit positive-reward `MissingRewardWeight` failure. Do not invent an orphan beneficiary or queue that enriches the next depositor. Source allocation dust and ordinary rebase dust enter their own stages once, not both.

Principal pull/credit increases accountedBacking and issues x*K gons but never calls reward allocation. Unstaking debits accountedBacking before paying x. Ordinary full-account exit may retire its final subnative remainder under the source rule. For pooled NFT escrow, retire only the finished position's own fraction after all its principal/whole rewards are paid; never zero the pooled NFT account's gons or another tokenId's remainder.

### 9.3 Immediate ordinary-transfer funding protocol

**Public behavior:** after initialization, an ordinary positive `NET-DETF.transfer(stakingChild,A)` or transferFrom into that child, with no active principal/legacy-pull context, is a reward donation to existing participants. When it returns successfully, the child has applied the distribution. Sender receives no staking principal. No second user transaction/function call is needed. Zero amounts and child→itself movements do not generate funding. Required accounting failure reverts the transfer atomically.

**Parent coverage:** all custom DETF public transfer/transferFrom selectors and internal Repo mint/transfer paths must call a single funding-aware movement service. Take the actual child balance before/after the movement, validate its exact delta and produce one monotonically identified parent-authenticated receipt. For direct mint, from=zero is descriptive, not classification. Raw reference `ERC20Repo._mint` bypasses external transfer selectors; no internal staking-credit path may omit notification. Preserve the ordinary ERC20 event/allowance behavior and once-only totalSupply changes.

**New child entry, no pull:**

```text
onDetfFunding(uint256 receiptId, address from, address operator,
              uint256 amount) -> (uint256 stakingGrowth,
                                   uint256 feeReceipt,
                                   uint256 creatorReceipt)
```

Only the configured DETF parent may call it. The child validates the active parent movement/nonce and its own expected funding context, consumes the receipt once, verifies actual backing, and either acknowledges principal/legacy-pull receipt or runs the already-received reward transition of §9.2. It does not call transferFrom, `fundRewards` or `_synchronize`. Do not derive amount from the whole `held−accountedBacking` surplus, which may contain pending principal or old funds.

**Principal funding context:** before an allowance/Permit2 pull into staking or a direct principal mint, the authorized staking flow installs exactly one context containing kind=`Principal`, payer/from, operator, amount, recipient/position and nonce. Only that matching movement may acknowledge it. The initiating flow credits principal once after the movement returns; notification performs no rebase for it. A random user cannot install a principal context to convert a donation into somebody else's stake or suppress a reward distribution.

**Legacy fundRewards:** existing `fundRewards(amount)` is DETF-only and pulls; do not invoke it after transferring the same funds. Custom expansion/issuance uses notified transfer/direct mint instead. If retaining the legacy pull entry for interface compatibility, open a distinct `LegacyRewardPull` context before its transferFrom; the nested callback only acknowledges that receipt, and the outer fundRewards distributes once. Never allow both layers to distribute or pull twice.

### 9.4 Synchronization and guard phases

Entry synchronization precedes the child's principal-transfer lock as in the reference. Parent synchronization may itself deliver expansion rewards to the child; permit only its authenticated reward receipt. Notification must never recursively synchronize the parent.

During a locked principal pull, the only admitted nested callback is acknowledgment of that exact expected principal receipt. A previously established operation context prevents resettling expansion through a nested token transport path during the same principal movement. Do not release/reset a general nonReentrant guard to admit arbitrary callbacks. Any mismatched amount/source/operator/nonce or sibling call reverts.

Distribution core is gons bookkeeping, but still performs backing, oracle and NFT-role reads. Protect state-changing reentry and incoherent claim/price views across those calls. Only the parent/child operation-specific read paths required for backing and role resolution are permitted; no public money path may consume an intermediate ledger.

Preserve the existing settle-before-participation-change policy, current Net processed clock and single aggregate expansion. First-bond principal is funded before its own immediate bond reward; ordinary stake arrives after prior expansion. Direct reward donation does not mint additional DETF, change bond locks, charge a recursive issuance fee or add another epoch clock.

### 9.5 Required integration tests and resolution status

- Direct donor transfer updates funded balances/recipient receipts before return and grants donor no principal.
- Parent transferFrom, direct expansion mint, bond reward mint and every internal movement path produce one receipt and one distribution.
- Principal pull/direct mint acknowledges without rebase, credits exactly x native units at settled K, and cannot be replayed or matched by a sibling.
- Existing fundRewards pull, if exposed, does not double-pull or double-distribute when token notification is installed.
- Zero/self transfers create no growth; old surplus is not swept into current receipt.
- Zero ordinary stake with standing recipients receives source allocations; all-zero weights reject positive rewards; tiny quantized growth retains source dust.
- Reward-only claim preserves native P using x*K gons; partial rebond decreases P exactly by q and leaves old rewards/native rights; full account/NFT dust retirement never clears another position.
- Parent→child reward callback during synchronization succeeds only in the expected context; recursive synchronization, unauthorized callbacks and inconsistent reentry fail atomically.
- One-step balance growth, recipient allocation, events and previews match source functions. No tests have been run by this authoring round.

L1 is **resolved as a specification/model issue** through the owner-permitted switch. Reference correctness does not certify the new callback adapter; W7/W8/W9 must implement and validate it. Prior B/U investigations remain historical research, not proof of formula equivalence. Source evidence and attributed corrections are in the [transfer-funded staking consultation](../../../research/netnet-transfer-funded-staking-2026-09-27/COUNCIL_CONSOLIDATION.md).

## 10. Rollover, rewards and history

For hook-local rollover use validated targetMarket plus a typed limits record containing deadline, maximum old-position inputs where caller protections require them, minimum realized/intermediate SY and minimum successor LP/YT. Recipients, factories, token identities, balances and series configuration are derived, never arbitrary caller overrides. Apply the following sequence:

1. Reject active source, identical/incompatible/expired target; verify configured trusted factory recognition before token relationships.
2. Discover new PT/YT/SY/expiry; validate NetNet backing/conversion and executable seeded entry. New SY address is allowed.
3. Checkpoint observations and reconcile old interest/rewards, including earlier force-claims. Keep principal, interest and fee payables distinct.
4. Remove old LP, realize mature PT, and preserve expired YT/historical claims without face-value payout.
5. If SY differs, execute the verified supported old-SY→new-SY route under limits. No metadata-only relabel or unselected conversion path.
6. Acquire successor Keep-YT with minLP/minYT and actual receipt accounting. Reconcile internal subshares and custody roles.
7. Commit active-series pointer after all required steps; retain historical references/residual state and synchronize local balances.

Failure at any required step reverts the entire migration. Standalone outgoing fee forwarding is isolated under the selected exception; retain undelivered payable. Do not require native wrappers to finish, reset matured locks or introduce a staged committed migration.

Permissionless rewards collection uses verified reward lists and dynamic feeTo. Hold the market's interest token; route other attributable rewards, including previously force-claimed balances, once. Do not make generic sweep permissions from reward handling. Normal historical processing must be bounded/source-addressable rather than every route replaying all series. Complete token registration and raw held balances remain mandatory; NN-03 adds no arbitrary broken-token survival requirement.

## 11. Test architecture and expected-value controls

### 11.1 Fixtures

Reuse `CraneTest`→`IndexedexTest`→vault/protocol TestBase chains. Start the custom SE tests from `contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2StandardExchange.sol`; use existing decimals/multipool bases where relevant. NetNet protocol-faithful and fork bases are under `lib/crane/contracts/protocols/pol/net/test/bases/`. Use real supported Pendle sources/ports or pinned fork instances; do not replace the SUT, fee oracle, manager, registry or attached SE with mocks.

New family TestBase deploys through the real manager/registry/hook factories with full initialization. Include two LP-holding DETF participants and a public LP; no exclusive-first-DETF assumption. Token harnesses may control funding/callback behavior outside the SUT under repository rules. Do not impersonate the DETF to fabricate bootstrap state.

### 11.2 Required numeric vectors

| Vector | Expected result |
| --- | --- |
| Expansion S0=1000 whole DETF, n=3, gate qualifying | 15 whole DETF minted; native result `15e9`; no loop |
| Two epochs batch vs sequential | Batch10; sequential5 then5.025 whole DETF at increased supply |
| Hook TWAP exactly1 | No expansion mint; completed epochs consumed |
| Synthetic TWAP exactly1 | Standard DETF-input route swaps, not burns |
| Missing histories | Hook allows due expansion; synthetic chooses swap; measured value not fabricated |
| Weights | Identity mapping50/20/10/20; with all positive external coordinates synthetic mark `2*rNET+floor(rNET/2)` before owned fraction/supply normalization |
| Full proportional exit | Match each nested floor in §6.2 exactly; no flattening into one different rounding step |
| Illustrative bond split | PRD example G1000,U1100,p10% gives principal990,pot210,actual issuance2200; U not minted again; example percentages not defaults |
| Wrapped reinvestment | Old principal100, requested40→old principal60 plus calculated new bond; future native rights/rewards stay old |
| Reinvest all current principal | Old principal0 with future native claim→old NFT remains; no duplicate principal credit |
| Epoch timing | Purchase100, passed101, intermediate collection105→no restart; final contribution106→ordinary final unlock107 |
| Fee fallback | Vault0 falls through type/global; effective result and lookup identity match source |
| Preloaded native note | Authorized deposit's returned index may be nonzero; zero is also valid; never assume tokenId equality |
| Funded-gons native exactness | For initialized K and g, credit/debit x*K changes floor(g/K) exactly by x; K changes only through funded reward application, not a principal deposit ratio |
| Reward-claim principal isolation | Position g=5*K+remainder (remainder<K), native P4: reward1 transfers K gons and leaves displayed principal4; retire only its own final fraction |
| Standing allocation and funding | Ordinary/fee standing weights in80:20 ratio and reward100 allocate80/20 under source floors; issue fee receipt20 at post-ordinary-rebase K, not20% of pre-existing backing. Zero ordinary Q with surviving20:30 weights and reward100 allocates40/60 |
| Inner geometric and residual | Seed1,000,000/4,000,000→S2,000,000 including locked1000; later L100/Y200/S100 plus30/40→m20, accepted20/40, residual10/0 belongs to ingress operation |
| Floor-tax inverse | D10000,t500,net requested19→minimum gross19; source forward verification exact |
| Existing Weighted helper | Differentially compare both helper directions and V4 native wrapper on zero/boundary amounts, non-18-decimal scales, nontrivial rates/fees and maximum ratio domains; preserve per-stage rounding and exactly one fee gross-up |
| Arithmetic ring | Warm-up3599 versus ready3600;3601 distinct-second retention; same-second writes consume no extra slot; sparse history extends counterfactually |
| Public surplus claiming | Booked100/live110, declared7→credit7 regardless of who sent the10; declared11→shortfall revert. Booked100/live100→no credit. Positive donation/force-claim surplus is accepted by the next eligible caller, then booked/consumed once; no payer witness |

Derive exact input/output vectors from pinned reference code using actual configured decimals. Expected-value controls must not call the same custom function under test as their only oracle.

### 11.3 Invariants and negative paths

- Physical assets, claims and liabilities are counted once across all components.
- Booked payable/exclusive inventory is not caller credit. Public positive unbooked surplus may intentionally fund the next eligible pretransfer regardless of donation/force-claim origin; no second receivable/held entitlement or repeated/refund credit for the same units.
- Outside HLP cannot fund DETF operations; liquid DETF cannot redeem proportional HLP entitlement.
- Preview and execution agree at the same starting snapshot within specifically justified source-rounding bounds, never an arbitrary blanket percentage tolerance.
- Compare BasePoolMath and custom operations in the same scaled context across proportional/single/unbalanced modes.
- Callback/allowance/Permit2/internal-balance modes enforce actual owner receipt and route permissions.
- Every required failure restores balances, claims, allowances where applicable, supply, markers, histories, mappings and NFT state.
- Outgoing fee-transfer failure continues under functioning required reads, records payable and retries once. No requirement to continue through broken essential balance/market interfaces.
- Stateful tests interleave deposits, swaps, public LP exits, force-claims, fee changes, NFT transfers, partial reinvestment, native maturity and market rollover.
- Declaration controls come from interfaces/Targets; verify exact Facet metadata, package cuts, loupe entries and successful/expected-guard proxy calls for every selector.
- Preserve configured fuzz/invariant depth/runs. Add boundary seeds; do not lower coverage or substitute mocks for speed.

## 12. Work packages and dependency order

Each checkbox is initially unchecked. A work package is complete only with source/spec artifacts and its stated validation evidence. No green result is claimed here.

| WP | Deliverable | Depends on | Exit criterion |
| --- | --- | --- | --- |
| W0 | G0/G1 evidence and implementation baseline; record exact L1–L4 status | Separate execution authorization where required | External prerequisites evidenced; actual blocked paths distinguished from permitted work |
| W1 | Full-feature tax-aware canonical V2 SE and package binding | G0/G1; §5.3 parity source; resolved §6.1 push mode | Untaxed reference parity and taxed net quote/execute vectors; no lost selector/route |
| W2 | Raw reserve books, operation budgets, native/rated adapters and inner-share math | G0/G1; §§5–6 | Booked-balance protection, origin-independent public credit, once-only units and explicit residual accounting |
| W3 | Pendle provider, Keep-YT and joint-position quote/execute services | W2; G1; L3 for source-specific inverse stages | Actual conversion semantics, same-state quotes and pre/post-expiry execution |
| W4 | Shared Weighted hook liquidity, swaps and fee dilution | W1/W2/W3; §§6–7 | BasePoolMath differential parity, shared-LP isolation and selected payout units |
| W5 | Two arithmetic histories, consultation and checkpoint integration | W2/W4; §8.1 |3601 coalesced-second ring, wide cumulative and exact-window/readiness tests |
| W6 | DETF activation, supply/epoch expansion and standard swap/burn routes | W1–W5/W7; §§6–8; L3 where required | Atomic full-book first bond, source splits, gates and actual funding |
| W7 | Funded-gons staking, received-reward adapter and custom NFT ordinary lifecycle | W2; §9; no explicit NFT retirement | Source exact native/gon behavior plus parent movement coverage, principal context, once-only notification and guard tests |
| W8 | Dedicated liquid/staked/position reinvestment | W4/W6/W7; L3 for affected conversions | Actual-q no-bonus burn, old q*K gon debit, new independent lock, full rollback |
| W9 | Native holder Package, NFT purchase/harvest, excess and final E+1 | W3/W6/W7/W8; §7.3; L4 resolved | One intended note, standard salt/reuse, old-NFT persistence, late excess inherits unlock, native atomic rollback |
| W10 | Complete registry/factory/child/hook-flags wiring and discovery | G0/G1; §§4–5; component packages | Immutable reciprocal initialization and complete custom/retained proxy surfaces |
| W11 | Atomic rollover, historical claims and permissionless reward retries | W3–W10; §10; L3 where applicable | Required migration failures atomic, correct new-SY conversion and once-only claim/held accounting |
| W12 | Integrated differential, invariant, lifecycle, fork/parity and size/resource validation | W1–W11 | A01–A50 complete or explicitly blocked; no unsupported closure claim |
| W13 | Documentation/ABI/manifest finalization and implementation handoff | W12 | Traceable evidence and no unresolved material choices in executable release scope |

Work-package IDs are stable labels, not a command to execute numerically. Dependency order remains W0 → W1/W2 → W3 → W4 → W5 and W7 → W6 → W8 → W9 → W10 → W11 → W12 → W13. Apply G0/G1 and each explicitly affected L1–L4 restriction; no generic future-annex approval stage remains. Shared interfaces/state contracts must precede interacting source implementations; W7 foundation does not depend on live W6 activation, and final integration must not replace the coordinator with a mock.

Build shared deployment/test fixtures alongside components so each work package is exercised through production proxy paths. W10 denotes final wiring completion, not permission to bypass registry earlier. Implement test deployment support incrementally against the same specified interfaces/configuration and guards; never claim an incomplete initialization graph production-ready.

## 13. PRD acceptance traceability — A01 through A50

| Acceptance | Work packages | Required coverage focus |
| --- | --- | --- |
| A01 | W2/W7/W9/W12 | Whole-system conservation, no double entitlement or persistent deferred native principal |
| A02 | W2/W4/W10 | Coherent hook snapshots, direct HLP ownership, authenticated children |
| A03 | W3/W4/W6 | Keep-YT/SE ingress and shared-SY ordinary egress |
| A04 | W1 | Per-hop tax/exemption/decimals/net delivery |
| A05 | W2/W12 | Booked-inventory/overclaim negatives; positive unbooked donation/force-claim credit to next eligible caller; refund and sequential once-only accounting |
| A06 | W6/W8 | Existing-token buys versus actual-input contraction; no virtual issuance |
| A07 | W5/W6/W7 | Processed epoch boundaries, zero rewards and ordinary reinvestment timing |
| A08 | W7/W9 | Intermediate no-reset, final E+1, independent new bond locks, sentinel0 |
| A09 | W9/W10/W12 | Holder namespace/reuse/provenance and native scan measurements |
| A10 | W11 | Active-source rejection, compatible target and preserved rights |
| A11 | W11/W12 | Interest retained, other rewards forwarded, failed outgoing transfer retry |
| A12 | W12 | No-deposit/zero-yield/tax/depletion/price-shock/cyclic-trade scenario accounting |
| A13 | W4/W6 | Custom Weighted behavior and standard interface unit mapping |
| A14 | W4/W6 | HLP rights distinct from liquid DETF; no duplicate claims |
| A15 | W1/W6 | Oracle fallback, incentive once, ordered fees/native rounding |
| A16 | W6/W12 | ERC4626 exact-in/out, preview/max/allowance and SY internal balance |
| A17 | W6/W12 | Owned-reserve funding through exhaustion/expiry/expansion with atomic failure |
| A18 | W2/W4 | Proportional and unbalanced HLP; nested floors and output units |
| A19 | W4/W12 | Two independent DETF participants plus public LP isolation |
| A20 | W1/W10 | Canonical asset/package/relationship validation, including empty SE |
| A21 | W1/W12 | Exhaustive retained reference V2 selectors/routes and taxed parity |
| A22 | W1 | Active versus queued exemptions; hook never duplicates tax |
| A23 | W1/W4/W6 | Correct hook/DETF oracle identity, growth fee dilution and split ordering |
| A24 | W5/W6 | Exact synthetic reference, NET identity, creation/opening and TWAP branch |
| A25 | W6/W10 | DETF itself as ERC4626/SY share, sNET asset, no extra receipt |
| A26 | W6/W12 | Owned-book quote domain, external LP majority, exact-output funding |
| A27 | W3/W4 | Shared SY held-first/claim-if-short; no double spending or principal fallback |
| A28 | W8 | No-bonus dedicated reinvestment versus independent contraction/bond composition |
| A29 | W7/W8 | Old staking-claim debit, actual backing and other-position isolation |
| A30 | W8/W9 | Partial/all wrapped-principal rebond, old NFT rights, excess and rollback |
| A31 | W7 | Early rewards, cliff principal and remaining attribution |
| A32 | W6/W7 | Source duration/bonus/split compatibility, no fabricated lock duration |
| A33 | W2/W4/W12 | Actual BasePoolMath parity and asymmetric pricing/funding conservation |
| A34 | W6 | Opening G/U/B/R floor order, additional legs and activation rollback |
| A35 | W2/W6 | Real SY bootstrap capital with zero earned interest; nonzero full-book LP |
| A36 | W11 | Historical YT/SY claims and force-claim reconciliation without full-history replay |
| A37 | W11/W12 | Required rollover failures atomic; outgoing reward failure isolated |
| A38 | W3/W11 | Keep-YT split/minima, same/different SY, empty target failure |
| A39 | W4 | Direct custody-unit joins and selected liquidity modes |
| A40 | W6 | Aggregate expansion equation, equality, once-only markers and native examples |
| A41 | W7 | Notified mint/transfer distribution, funded-gons allocation/rebase/recipients/dust, principal-context isolation and no extra user call |
| A42 | W5/W6 | Every-check capture, warm-up and settlement-before-participation |
| A43 | W5/W6/W12 | Projected versus realized supply/backing with no duplicate pending expansion |
| A44 | W5 | Two arithmetic series, history/boundaries/quiet intervals/callbacks |
| A45 | W10 | Selected config/discovery/singleton and immutable wiring |
| A46 | W3 | Pre-expiry post-burn quote state, excess branches, exact fee identity |
| A47 | W3/W11 | Post-expiry current-index PT realization, treasury exclusion and no YT payout |
| A48 | W3 | External SY target/decimals/preview parity, rates versus finite output |
| A49 | W2/W11 | Every local token physical snapshot, registration, post-refund sync and roles |
| A50 | W2/W4/W6 | Recompute actual post-movement pricing/HLP/fee state and finite-capacity views |

For every test row record exact test path, control source, input domain, expected event/state, justified tolerance and evidence link. Do not mark “covered” because a similarly named test exists.

## 14. Build, validation and evidence workflow

These instructions describe later authorized work; **none was run to author this plan**.

1. Read then-current CLAUDE and assistant rules. Satisfy G0/G1 at their stated deadlines and apply the specific L1–L4 path restrictions; no source change is authorized by this plan-writing task.
2. For a new/empty worktree, follow the required warm artifact-seeding procedure without deleting unrelated caches/artifacts. Configured directories are `out` and `cache_forge`; re-read configuration if changed.
3. After source edits, use the repository's artifact-aware build-before-test workflow (`scripts/forge-artifacts.py` with edited source and explicit test roots) or a supported complete build. Factories may read creation code from `out`; stale artifacts are not evidence of the edited implementation.
4. Run focused declaration/math/route suites first, then integrated hermetic and relevant pinned fork suites under only default/fork profiles. Cold builds can take tens of minutes; wait for real process completion under repository timeout/patience rules.
5. Validate deployed runtime/code-size constraints and registration/selector wiring; do not rely on permissive local limits for chain readiness.
6. Record actual compiler/tool versions, source revisions, runtime artifact freshness, fork chain/block/addresses, commands, exit status and results. No secrets or environment values in reports.
7. For each failed requirement, record an explicit blocked state and source/test evidence. Fix implementation against selected behavior; do not quietly weaken tests, change fee/lock policy or omit an exposed feature.

Canonical guidance read for this plan: `lib/crane/.claude/skills/crane-testing/SKILL.md:11–29,151–184`; `.claude/skills/indexedex-uniswap-v4-hook-packages/SKILL.md:16–44,63–78,110–119`; root `CLAUDE.md` and PRD source map. The skill's old `hook_factory` profile example does not override root default/fork-only law.

## 15. Tracker handoff and definition of done

| Tracker | Plan location |
| --- | --- |
| NN01 | G1; §4; evidence workflow |
| NN02 | §§5,7.3; L4 terminal boundary; W9 |
| NN03 | §§1,7.1,10,11 failure scope; no reopened policy |
| NN04 | G1 actual terms; §§7.3,8.2,9; W6/W7 |
| NN05 | §§1,6; selected unit/fee/synthetic integration |
| NN06 | §6.2; W2/W4 |
| NN07 | §6.4 local inverses and L3 composition; W6/W8 |
| NN08 | §8.2 bootstrap; W6 |
| NN09 | §8.1 explicit ring/ABI; W5 |
| NN10 | G1; W3; external SY/provider distinction |
| NN11 | §§5/6.1/7.1; L2 resolved surplus policy, ordinary internal role/claim bookkeeping |
| NN12 | §9 funded-gons reuse and new notification adapter; L1 model issue resolved |
| NN13 | G0; separately authorized maintenance |
| NN14 | §10; W11 |
| NN15 | §7.3 through drained state; L4 irreversible terminal policy; W7/W9 |
| NN16 | §5.3 retained interface/cut inventory; W1 |
| NN17 | §§3–5; W10 custom ABI/child-init completion |
| NN18 | §§8/11/14; W12 measurements |
| NN19 | §§11–14; W12 |
| NN20 | W13; artifact/citation reconciliation |

**Executable-plan freeze:** G0/G1 evidenced at their required deadlines; L1–L4 resolved for the requested implementation scope; full custom ABI/init graph and configured source compositions stated rather than left to implementer economics. No routine “write an annex later” gate substitutes for that work. A selected policy is not re-asked because its tests are unwritten; an actual unresolved transition is not hidden to declare completion.

**Implementation complete:** W1–W13 evidence, A01–A50 traceability, registered proxy surfaces, correct immutable authority, actual funding conservation, supported routes, source math parity and appropriate regression/fork validation all complete. Product activation/deployment remains separately authorized.

**Version0.5 delivery:** L1's funded-gons switch remains; the owner's direct clarification now resolves public pretransfer L2 as available raw surplus claimed without origin proof. Receipt contexts are confined to internal staking/callback funding classification, not added to the public pretransfer contract. L3/L4 and expressly recorded source/configuration evidence remain separate. No code, tests, RPC, transactions, deployment or instruction changes were performed; no execution readiness is fabricated. Stop at the human checkpoint.
