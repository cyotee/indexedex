# Rebasing-aware ERC4626: Standard Yield and Standard Exchange interfaces

**Status:** Draft for owner review; not approved for implementation.  
**Date:** 2026-09-11  
**Owner decisions:** No vault fees; deployment through IndexedEx Manager/Vault Registry; reject asset-input pretransfers; support share-input withdrawal pretransfers and SY internal-balance redemption; preserve share decimals as asset decimals plus the default immutable offset of 10; support use as underlying Standard Exchanges in DETF buffers.  
**Product:** General-purpose, fee-free wrapper for rebasing ERC20 assets, implemented by `RebasingAwareERC4626DFPkg` and its vault diamonds.  
**Implementation plan:** [Separate implementation and test plan](./REBASING_AWARE_ERC4626_SY_SE_IMPLEMENTATION_AND_TEST_PLAN.md), prepared at the owner's request for review. Review its technical specifications and resolve its §8 buffer-topology conflict before delegation. This document does not authorize implementation, agent delegation, or deployment.

## 1. Problem and desired outcome

The rebasing-aware ERC4626 package currently creates static ERC20 shares backed directly by a configured token. Its live asset balance drives ERC4626 conversions, so changes in backing accrue to share value. Its diamonds expose ERC20 and ERC4626, but no Standard Exchange (SE) or Standardized Yield (SY) interface.

Users and integrations should be able to deposit and redeem through ERC4626, SE, or SY on the **same vault address, with the same shares and backing**. Adding the standard interfaces must not create another wrapper token, another supply ledger, or another claim on the yield.

This is a general-purpose wrapper for making rebasing tokens compatible with other protocols, not a product restricted to protocol-issued claims. Wrapping `rebasingClaimToken` / sDETF is one required integration. The generic wrapper remains distinct from the dedicated DETF staking SY product: this work does not replace `DETFSYDFPkg`, alter funded staking economics, or automatically add DETF/reserve-swap routes.

## 2. Evidence and governing references

The following source files establish the current behavior; their presence is not evidence that the requested feature or its tests are complete.

| Reference | Relevance |
|---|---|
| [RebasingAwareERC4626DFPkg.sol](./RebasingAwareERC4626DFPkg.sol) | Two installed facets; package arguments, initialization, metadata, deployment helpers |
| [IRebasingAwareERC4626DFPkg.sol](./IRebasingAwareERC4626DFPkg.sol) | Existing `PkgInit`, `PkgArgs`, and `deployVault` overloads |
| [RebasingAwareERC4626Target.sol](./RebasingAwareERC4626Target.sol), [Repo](./RebasingAwareERC4626Repo.sol), [Facet](./RebasingAwareERC4626Facet.sol) | Live-balance accounting, virtual offset, ERC4626 routes and selectors |
| [ERC4626StandardExchangeDFPkg.sol](../../../vaults/standard/erc4626/ERC4626StandardExchangeDFPkg.sol) | Existing IndexedEx package exposing ERC4626, SE and SY |
| [ERC4626StandardYieldTarget.sol](../../../vaults/standard/erc4626/ERC4626StandardYieldTarget.sol) | Comparison only: this product wraps an external ERC4626 vault, whereas the rebasing-aware wrapper holds its asset directly |
| [NativeStandardYieldTarget.sol](../../../vaults/standard/sy/NativeStandardYieldTarget.sol), [selectors](../../../vaults/standard/sy/NativeStandardYieldSelectors.sol) | Existing native SY routing, caller context, discovery and reward behavior |
| [IStandardExchangeIn](../../../../lib/crane/contracts/interfaces/IStandardExchangeIn.sol), [IStandardExchangeOut](../../../../lib/crane/contracts/interfaces/IStandardExchangeOut.sol), [IStandardizedYield](../../../../lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol) | Canonical signatures and semantics |
| [TokenStakingTarget.sol](../token/TokenStakingTarget.sol), [FactoryService](../token/TokenStaking_Component_FactoryService.sol), [TestBase](../token/TestBase_TokenStaking.sol) | Existing package consumer and deployment path |
| [Funded staking repo](../../../vaults/detf/common/claimToken/DETFFundedStakingRepo.sol), [staking target](../../../vaults/detf/common/claimToken/StakedDETFTarget.sol) | Real protocol claim-token accounting and settlement integration |
| [DETF alignment PRD](../../../vaults/detf/DETF_ALIGNMENT_PRD.md), [agent law](../../../../docs/agent/INDEXEDEX_AGENT_LAW.md) | Funded rewards, token policy, standard-interface and decimal requirements |
| [4663 architecture PRD](../../../../docs/ANVIL_ROBINHOOD_MAIN_ARCHITECTURE_PHASE_STAGE_PRD.md) | Default stage 06-10, optional TokenStaking and future deployment integration |
| [Crane testing](../../../../lib/crane/.claude/skills/crane-testing/SKILL.md), [IndexedEx testing](../../../../.claude/skills/indexedex-testing/SKILL.md), [adversarial testing](../../../../.claude/skills/indexedex-adversarial-testing/SKILL.md), [definition of done](../../../../lib/crane/.claude/skills/crane-adversarial-testing/references/implementation-test-dod.md) | Production-first tests, diamond surface coverage and attack categories |

## 3. Scope and draft decisions

### 3.1 Required scope

- Add canonical `IStandardExchangeIn`, `IStandardExchangeOut`, and the complete `IStandardizedYield` surface to new rebasing-aware vault instances.
- Preserve ERC20/ERC4626 entrypoints and one shared accounting model across all interfaces.
- Support use as an underlying SE in current in-scope DETF buffers, including required transition/external quote interfaces and production integration tests.
- Include facets, package declarations, FactoryService, affected package consumers, deployment/export integration and documentation in the eventual implementation scope.
- Require functional, adversarial, fuzz, stateful invariant and integration evidence through real factory-created diamonds.
- Preserve existing instances and document how new code receives distinct deterministic deployment addresses.

### 3.2 Confirmed requirements and retained scope

The owner has confirmed general-purpose rebasing-token support, no fees, registry deployment, directional pretransfer behavior, SE withdrawal refunds, SY internal-balance redemption, no reward tokens, the decimal convention, zero-value behavior, zero-reserve deposit protection, explicit SY rate-underflow errors and DETF-buffer compatibility. The PRD remains a draft until reviewed as a whole. The later plan must specify all remaining technical details for owner review before delegation; none are delegated as implementer choices.

| Topic | Requirement |
|---|---|
| Routes | Direct configured asset ↔ wrapper share only, in both directions |
| Shares — owner confirmed | Keep the existing static wrapper token and virtual-offset accounting; share decimals equal asset decimals plus the default offset of 10, immutable per vault |
| Fees — owner confirmed | This vault is an exception to protocol fee-taking: no deposit, withdrawal, wrapping, unwrapping, performance or other vault fee through ERC4626, SE or SY |
| Pretransfer — owner confirmed | Reject `pretransferred=true` for asset→share deposits/mints. Support it for share→asset redemptions/withdrawals through both SE entrypoints |
| SY internal balance — owner confirmed | Support `burnFromInternalBalance=true`, consuming only the requested static shares already held by the vault |
| SY rewards — owner confirmed | No separately claimable reward-token support, harvesting or distribution. Empty SY reward lists; only live rebasing-asset backing drives share value |
| SE withdrawal refunds — owner confirmed | Burn only required pretransferred static shares and refund unused supplied shares to the initiating caller |
| Zero value — owner confirmed | Zero-amount previews return zero; all zero-value vault executions revert, including positive input producing zero output |
| Zero reserve — owner confirmed | Reject new deposits/mints while live reserve is zero and outstanding shares remain |
| SY rate precision — owner confirmed | If the calculated WAD rate rounds to zero, revert with an explicit custom error |
| Registry — owner confirmed | Deploy the enhanced package/vaults through the canonical IndexedEx Manager/Vault Registry path and expose created vaults through registry discovery; preserve existing consumer compatibility |
| DETF buffers — owner confirmed | Support wrapper shares as underlying SE inventory; include transition/external quote interfaces and the consumer integration needed for buffer use |
| Other APIs | Multi-token SE, permit additions and new composed routes on the wrapper itself are not implicitly included |

### 3.3 Exclusions

No new frontend flows, Pendle market deployment, public-mainnet transactions, core factory redeployment, token launch, staking reward changes, unrelated DETF family refactors, or automatic upgrades/migrations of existing vaults are authorized by this PRD. Necessary integration changes for current in-scope DETF buffers are included, without reopening excluded Balancer-hosted DETF or deferred Slipstream functionality. The later plan must identify any integration dependency that requires expanding scope rather than silently implementing it.

This wrapper is an owner-approved exception permitting general rebasing ERC20 assets as its direct backing. Its static shares are the interface exposed to downstream protocols. This does not authorize raw rebasing assets as direct underlying tokens in unrelated SE/DETF products. Do not restrict this wrapper to sDETF, add a protocol-token allowlist, or require an underlying to expose DETF-specific methods. Fee-on-transfer support remains forbidden; no token allowlist or blacklist detector is to be introduced. Real sDETF and non-protocol rebasing-ERC20 harnesses are both mandatory test inputs. Malicious callback behavior remains adversarial scope, not a promise that every arbitrarily programmed ERC20 is safe.

## 4. Shared accounting requirements

**ACC-01 — Single book.** ERC4626, SE and SY must read and modify the same ERC20 supply, balances, asset reference and virtual-offset configuration. A user can deposit through one interface and exit through either of the others without changing economic entitlement.

**ACC-02 — Live backing.** Preserve `totalAssets() = configuredAsset.balanceOf(vault)` for the configured rebasing ERC20 asset. Settled positive rebases and donations change share value without minting wrapper shares. Losses or negative rebases reduce redeemable value; the wrapper must not promise principal preservation. Unfunded future rewards must not enter backing.

**ACC-03 — Explicit units and rounding.** For the existing zero-fee model, use the following reference quantities at one coherent accounting boundary:

- `A`: actual raw backing units; `S`: actual raw wrapper shares.
- `d`: effective decimal offset; `V = 10^d` virtual shares and one virtual asset unit.
- Deposit exact assets: `floor(assets * (S + V) / (A + 1))` shares.
- Mint exact shares: `ceil(shares * (A + 1) / (S + V))` assets.
- Redeem exact shares: `floor(shares * (A + 1) / (S + V))` assets.
- Withdraw exact assets: `ceil(assets * (S + V) / (A + 1))` shares.

Use full-precision arithmetic. The test oracle must be independent of the production conversion helper. These are fee-free operations: no protocol/collector payment, fee-share mint, reward skim or retained fee accrual may be added. The exception is a property of this vault product, not a mutable zero fee setting that a later global, family or per-vault fee update can override. Virtual-offset rounding residuals are accounting dust, not fees payable to the protocol.

**ACC-04 — Payment attribution.** Existing asset backing, asset donations, accrued rebases and another user's asset transfers are not this caller's deposit payment. Static wrapper shares held by the vault are separately consumable under the approved withdrawal custody semantics in API-07/API-12. A raw balance increase during `transferFrom` is insufficient if the underlying can settle a global rebase during that call. The implementation must establish a settlement-consistent boundary or equivalent unit accounting for supported general rebasing-token transfers, including the intended claim-token integration. No generic route may depend unconditionally on a DETF-specific settlement selector. Hostile mid-call unit changes must revert atomically or be handled without shifting existing holders' value to the depositor.

**ACC-05 — No cached-balance regression.** Do not replace live-balance accounting with stale `lastTotalAssets` merely to implement SE pretransfer. Rebase income cannot become publicly claimable deposit credit.

**ACC-06 — Backing and dust.** No route pays more assets than held or burns more shares than owned/authorized. Residual backing caused by virtual shares and rounding is expected, must be quantified, and must not be exposed through a public sweep/refund. Do not require the last redeemer to receive all assets when the virtual-offset model does not grant them that entitlement.

**ACC-07 — Economic equivalence.** At the same state, supported routes produce the same asset/share deltas, subject only to specified rounding; this vault takes no fee. Repeated conversions cannot produce net profit absent external yield or donated capital; attack profit calculations must include the attacker's donations and all cooperating accounts.

**ACC-08 — Metadata.** Preserve `Wrapped <asset name>` and `w<asset symbol>`. The owner-approved default is asset decimals plus an immutable decimal offset of 10. This generic wrapper must not be silently relabeled as the dedicated nine-decimal DETF staking SY.

**Decimal convention — approved by owner.** Keep `shareDecimals = assetDecimals + d` with default `d = 10`, immutable for each vault. Thus a nine-decimal sDETF asset produces 19-decimal shares; an 18-decimal asset produces 28-decimal shares. In the empty-vault model, one displayed asset unit mints one displayed share unit: the additional decimals add fractional precision rather than multiplying the user's displayed value. Preserve the existing virtual-share ratio and test its donation/inflation defenses. Merely relabeling the token as nine or 18 decimals while keeping the raw conversion math would change displayed units without fixing the underlying conversion model.

Validate effective offsets, exponentiation, metadata addition and full-precision conversion/rate arithmetic at deployment. Any retained custom-offset support must have explicit numeric bounds and SY rate-precision tests; preserving the default does not approve every previously accepted offset. Specify those engineering bounds in the later implementation plan; they do not reopen the approved default decimal convention. The SY exchange rate accounts for different raw share/asset units; do not additionally rescale amounts at ERC20 boundaries.

External design references supporting this convention: [OpenZeppelin ERC4626 offset documentation](https://docs.openzeppelin.com/contracts/5.x/api/token/erc20#ERC4626) explains how the decimal offset sets the virtual-share ratio and initial rate; [Pendle SY documentation](https://docs.pendle.finance/pendle-v2-dev/Contracts/StandardizedYield) describes exchange-rate accounting when token decimals differ. These support the unit model, not a claim of tested Pendle market integration for this package.

**ACC-09 — Zero-reserve deposit protection, owner confirmed.** If `A == 0` and `S > 0`, reject all deposit/mint routes before pulling assets or issuing shares, including ERC4626, both asset-input SE modes, SY and composed buffer deposits. `maxDeposit` and `maxMint` return zero in this state. A fresh empty vault (`A == 0`, `S == 0`) can still accept its first nonzero deposit. Existing shares retain their identity and supply after loss; do not reset the vault or erase holders. New deposits become eligible again only when external backing restoration makes `A > 0`, subject to the normal controls. A depositor cannot bypass the guard by funding the reserve inside the same guarded deposit. Zero-output withdrawals still revert under API-03; positive-output exits after restoration remain available.

## 5. Public interface requirements

### 5.1 ERC4626 compatibility

**API-01.** Retain all existing ERC4626 and ERC20 selectors and their documented ownership/allowance semantics. `deposit`/`mint` charge the caller; `withdraw`/`redeem` can spend an explicit owner only with authorization. ERC20 transfers between holders do not move backing or change total supply.

**API-02.** Existing `deployVault` overloads must remain source/API compatible or receive an explicit, reviewed migration specification covering every caller. The TokenStaking consumer must still create and use a claim vault successfully.

**API-03 — Owner-confirmed zero-value policy.** All vault money-execution paths—ERC4626 deposit/mint/withdraw/redeem, both SE operations and SY deposit/redeem—must revert on a zero operation amount or on positive input producing zero output. No shares may be destroyed for zero assets, and no assets may be accepted for zero shares. A caller-specified zero minimum is a slippage setting, not a zero-value operation; it does not permit a zero actual payout. Apply this rule before economic mutation and assert complete rollback if zero output is established only during settlement.

Amount-based previews and conversion views return `0` for a zero amount. Valid positive-amount previews that round to zero return `0`; the corresponding execution reverts. This does not suppress invalid-route/state errors for positive inputs or the explicitly required SY rate-underflow error. ERC20 approval changes, standard ERC20 transfer semantics and empty SY reward compatibility methods are not vault deposit/withdrawal operations. Pin exact errors and validation precedence in the reviewed implementation plan; do not preserve a zero-value ERC4626 money-execution exception.

### 5.2 Standard Exchange

SE **In** means exact input, and SE **Out** means exact output; both include entry and exit directions.

| Interface | Input → output | Economic operation | Result |
|---|---|---|---|
| `exchangeIn` / preview | Asset → share | Deposit exact assets | Shares received |
| `exchangeIn` / preview | Share → asset | Redeem exact shares | Assets received |
| `exchangeOut` / preview | Asset → share | Mint exact shares | Assets consumed |
| `exchangeOut` / preview | Share → asset | Withdraw exact assets | Shares consumed |

**API-04.** All four routes are required, with direct algebraic exact-output calculations. Reject unsupported assets, asset→asset, share→share, invalid receivers and expired deadlines using precise errors. Share transfers remain available through ERC20.

**API-05.** Exact-input execution enforces final `minAmountOut`. Exact-output execution enforces `maxAmountIn` and returns actual input consumed. Pull only the calculated required input on pull routes. For pretransferred share withdrawals, burn the required shares and return the unused public share prepayment to the initiating caller under API-07. Refunds never come from asset reserves or the caller's unspent allowance.

**API-06.** Preview/execution equivalence is required with no intervening state change. A rebase between transactions can change a quote; execution must use current backing and the caller's limits. Tests must not assert stale previews are binding prices.

**API-07 — Owner-confirmed directional pretransfer policy.** Route classification follows `tokenIn`/`tokenOut`, not the names `exchangeIn`/`exchangeOut`:

| Route | `pretransferred=false` | `pretransferred=true` |
|---|---|---|
| Asset → share, exact-input deposit | Supported pull | Reject |
| Asset → share, exact-output mint | Supported pull | Reject |
| Share → asset, exact-input redemption | Supported holder burn | Supported burn of vault-held shares |
| Share → asset, exact-output withdrawal | Supported holder burn | Supported burn of vault-held shares |

**Deposit rejection.** Asset-input pretransfers must revert before any mint, burn, token transfer, reward settlement or other economic mutation, even for exact/excess prior transfers or otherwise authorized callers. There is no reliable pretransfer reserve baseline for rebasing assets. Use a specific pretransfer-rejection error, selected from canonical errors where suitable and pinned in the later plan. Assert that error on otherwise valid calls, and document validation precedence for zero amounts, unsupported routes and expired deadlines.

**Withdrawal support.** Wrapper shares are static ERC20 units. Pretransferred withdrawals burn shares actually held by the vault, never infer payment from the asset reserve, never burn an external holder's balance, and never pull a second payment from the caller. Exact-input redemption burns `amountIn`; exact-output withdrawal burns the computed `amountIn <= maxAmountIn`. Check sufficient self-held shares before mutation and apply normal receiver, deadline and final-output limits. Calculate the rate with total supply still including those self-held shares before burning them.

**Custody and refunds — owner-confirmed refund requirement.** Burn only what is required and refund the rest of the pretransferred static shares to the initiating caller (`msg.sender`), separately from the requested asset payout to `recipient`. Following the existing [regular SE share-pretransfer model](../../../vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol), define `P` as the unassigned self-held wrapper-share balance at the operation boundary before any external settlement/transfer, and `B` as the required share burn. Require `B <= P`, and for exact output also `B <= maxAmountIn`. Burn `B`; transfer `P - B` wrapper shares back to the caller. Zero refund needs no transfer. This refund changes holder balances, not supply; only `B` is burned. Never substitute `maxAmountIn - B` for actual funded excess, refund backing assets, or include shares that arrive later during a callback.

Unassigned self-held shares form a public prepaid balance; an earlier separate transfer does not establish an exclusive claim for its sender. Integrations must transfer and withdraw atomically to protect that input. Previously donated/unassigned wrapper shares are governed by this same public custody model, not treated as authenticated sender deposits. The refund budget is the snapshotted static-share balance, not the rebasing reserve. Test this behavior explicitly and document it for callers. Failed withdrawals roll back burns, asset payments and refunds together.

SY `burnFromInternalBalance=true` is supported. Its route may share the approved static-share withdrawal logic, but must burn exactly the requested shares and must not inherit a residual-refund behavior that changes canonical SY semantics. Neither SE nor SY may enable asset-input pretransfer deposits.

### 5.3 Standardized Yield

**API-08.** Install all functions of the repository's canonical `IStandardizedYield`, including overloaded money/preview functions, discovery, validity checks, metadata, exchange rate and reward methods. Advertising an interface ID without its executable selectors fails acceptance.

**API-09.** SY `deposit(receiver, tokenIn, amount, minShares)` accepts only the configured asset; SY `redeem(receiver, shares, tokenOut, minAssets, internalBalance)` pays only that asset. Discovery lists must be unique and agree exactly with validation and execution. Native ETH input is unsupported and nonzero `msg.value` reverts.

**API-10.** Proposed metadata: `yieldToken() = asset()`, `assetInfo() = (TOKEN, asset(), assetDecimals)`. SY is the existing wrapper share. Do not copy the regular ERC4626 SE adapter's external-protocol-vault assumptions.

**API-11.** Report a WAD raw-asset-per-raw-share rate consistent with ACC-03. Proposed rate:

`exchangeRate = floor(10^18 * (A + 1) / (S + V))`.

For raw shares `q`, `floor(q * exchangeRate / 10^18)` must approximate `convertToAssets(q)` within a derived rate-quantization bound; a conservative bound is `ceil(q / 10^18) + 1` raw asset units. Compare values at the same accounting boundary. Do not assume the initial rate is `1e18`: with offset 10, the empty-vault rate is `1e8`. Do not apply an additional decimal normalization that double-counts the offset.

**Owner-confirmed underflow behavior:** If the calculated WAD exchange rate is zero, `exchangeRate()` must revert with the custom error `SYExchangeRateUnderflow()`. Do not return zero, clamp to one, fabricate value or change decimals. This includes positive backing whose entitlement lies below WAD-rate resolution. The rate query is not an amount-based preview, so API-03's zero-preview rule does not override this error. Valid positive-output ERC4626/SE exits must remain available without routing through this failing rate query. The implementation plan must pin overflow/bounds errors separately and tests must hit the last representable nonzero rate and the first underflowing rate.

**API-12.** Normal SY redemption burns the caller's shares. `burnFromInternalBalance=true` burns exactly the requested shares already held by the vault, as the canonical SY interface specifies. It must never burn another holder's shares, consume asset backing as proof of share ownership, or refund all remaining vault-held shares.

Internal SY shares are an unassigned public balance, not authenticated caller deposits. A separate transfer transaction followed by internal redemption can be consumed by another caller. Documentation and tests must distinguish this specified behavior from theft of an attributed user balance; integrations relying on this mode must transfer and redeem atomically. No cross-transaction ownership promise may be invented.

**API-13 — Owner-confirmed no-reward-token scope.** This product only converts rebasing-asset backing into static shares. It must not claim, harvest, reinvest or distribute separate underlying reward tokens. SY reward-token, index and accrual arrays are empty; `claimRewards` returns an empty array with the canonical empty reward event and cannot transfer assets, mint shares or call an underlying reward distributor. Rebase income already reflected in backing is not a separately claimable reward. Tests must verify these empty methods and prove that a reward-bearing underlying does not activate a harvesting path.

### 5.4 Shared execution and events

**API-14.** Reuse shared accounting operations; do not maintain independent implementations of the same mint/burn economics. Reuse native SY routing only where it preserves the original payer, receiver, allowances, lock and internal-balance semantics. Fixed internal selector routing must not become arbitrary user-directed call/delegatecall.

**API-15.** Each logical operation changes supply and backing once. Emit correct ERC20/ERC4626 and applicable SY events; distinguish overloaded events by their full topics. Multiple standard events must not mean duplicate issuance, settlement or payouts.

### 5.5 DETF-buffer compatibility — owner confirmed

**API-16 — Quote surface.** Implement the canonical `IStandardExchangeTransitionQuote` and `IStandardExchangeExternalQuote` interfaces defined in [IStandardExchangeTransitionQuote.sol](../../../interfaces/IStandardExchangeTransitionQuote.sol). Include them in the ABI/Target/facet/package/live-proxy matrix. If an applicable buffer requires a rate adapter or additional basic/standard vault metadata, identify and include the minimal canonical integration in the implementation plan; interface names alone are not compatibility evidence.

**API-17 — Sequential accounting.** Quote snapshots must capture the live backing, issued supply, effective virtual offset and holder share balance needed to project operations in the configured accounting asset. Each transition consumes the projected state produced by its predecessor, not a fresh live book that discards prior projected changes. `ReceiveShares` changes the projected holder balance without minting supply or adding backing. External-deposit/exchange quotes retain the selected holder's inventory while projecting the other actor's effects. All calculations preserve zero wrapper fees and ACC-03 rounding. Reject unsupported quote assets and malformed states; quote data must never authorize spending or substitute for execution-time validation.

**API-18 — Rebase and routing integration.** Rebase income changes the wrapper's live asset entitlement, not the number of wrapper shares held by the buffer. New snapshots must reflect actual settled backing; stale snapshots do not guarantee execution after a rebase. Preview/execute comparisons must use coherent settlement boundaries and include mid-call claim-token settlement. Buffer deposit routes must pull the rebasing asset with `pretransferred=false`; pretransfer optimization is permitted only for withdrawing against static wrapper shares. Existing callers that assume all SE input tokens support pretransfer must use a compatible route rather than weakening API-07. Wrapper fee exemption does not exempt the surrounding DETF/buffer from its existing fees.

The implementation plan must enumerate the current in-scope buffer bindings and map each applicable one to real end-to-end tests. Any topology that cannot support the wrapper's asset, decimals or route constraints must be surfaced explicitly before claiming compatibility; a single successful standalone wrapper test is insufficient.

## 6. Architecture, registration and release compatibility

**PKG-01.** Follow Crane Repo/Target/Facet patterns and existing storage slots. Keep `PkgInit`/`PkgArgs` on the interface. Add no owner, upgrade, arbitrary execution or public asset-recovery power to vault instances.

**PKG-02.** Produce an ABI-derived matrix: product interface/Target → facet declarations → package cuts → live diamond loupe → successful calls. Include every overloaded selector, interfaces, metadata, errors and events. Duplicate selectors, missing selectors, incomplete facet lists and advertised-but-absent interfaces fail the release gate.

**PKG-03 — Owner-confirmed requirement.** Deploy the enhanced package and vault instances through the canonical IndexedEx Manager/Vault Registry path. Created vaults must appear in registry discovery with their actual interfaces and asset configuration. The current direct CREATE3-package/diamond path must be adapted, including `deployVault` helpers and TokenStaking consumers, rather than retained as an unregistered bypass. Use real manager/registry infrastructure and preserve applicable inbound-disable/exit behavior. Registration does not opt this product into fee-taking; any fee-oracle references needed for standard metadata/integration must not cause charges or accrue fee liabilities.

**PKG-04.** New facets/packages use the existing factories and FactoryServices. Changed bytecode/configuration must resolve to a new versioned or implementation-sensitive deterministic address. An existing address with code is not proof of SY/SE support. Preserve old instances and document their remaining API.

**PKG-05.** Update default 4663 stage 06-10 and optional 06-08 consumer wiring, stage skip/freshness checks, architecture quote, rehearsal inventory and export records for the approved new package. Resuming from old manifests must not silently export the old ERC4626-only package as the enhanced release. Repeated runs of the same release must reuse its deployment.

**PKG-06.** All deployed facets/packages must satisfy the target chain's runtime size limit. Use configured compiler/optimizer settings; `via_ir` and disabled EIP-170 are not release fixes. Build creation-code artifacts before tests/scripts that load them.

## 7. Functional and integration testing requirements

Use actual facets, packages, factories, manager/registry, fee oracle and vault diamonds. Reuse the existing TestBase hierarchy. Mintable and hostile underlying harnesses are allowed; mocks of the product or protocol claim-token SUT are not. Test the deployed proxy, not just implementation addresses.

| ID | Required coverage and pass condition |
|---|---|
| F-01 | Deploy, initialize, predict and replay the enhanced package; correct asset, metadata, decimal offset and immutable configuration; invalid arguments fail atomically |
| F-02 | Full J surface matrix, ERC165 declarations and executable ERC20/ERC4626/SE/SY routes; overloaded ABI calls resolve correctly |
| F-03 | All four ERC4626 and four SE operations; SY deposit/redeem; previews, balances, supply, allowances, return values and events agree with the independent model |
| F-04 | Pairwise cross-interface deposit/exit matrix, with caller/receiver/owner distinct, finite/infinite allowances and ERC20 share transfers between operations |
| F-05 | Empty vault, first deposit, donated empty vault, populated vault, full exit, residual backing and redeposit; virtual-share dust reconciles |
| F-06 | Positive rebase, negative rebase/loss, no rebase and repeated rebases between operations; balances remain static for wrapper holders and backing/rate move correctly |
| F-07 | Decimals include 6, 8, 9 and 18 plus numeric boundaries rather than a token-decimals allowlist; effective offset normalization, maximum safe arithmetic and zero-rate boundary behavior are explicit |
| F-08 | Exact-input minimum and exact-output maximum at equality and one unit across the boundary; deadline equal to current time, expired deadline and future deadline |
| F-09 | SY discovery/metadata/rate/reward methods, caller-balance redemption and atomic internal-balance redemption; partial internal burns preserve remaining shares |
| F-10 | Intended real sDETF backing: acquire funded shares, wrap, distribute/settle real rewards, transfer wrapper shares and unwrap; no duplicate rewards or principal, including when settlement occurs during token operations |
| F-11 | TokenStaking's existing claim-vault creation, migration and user withdrawal paths continue to work with the enhanced package; test partial and complete migration |
| F-12 | Stage/export freshness and deterministic reuse; old ERC4626-only manifests cannot falsely satisfy new interface requirements; existing instances remain usable |
| F-13 | Registry discovery, deployment authorization and disabled-inbound-but-live-exit behavior work through all interfaces. Nonzero global/family/per-vault fee settings and subsequent updates still produce zero vault fees, fee-share issuance and collector payments |
| F-14 | Asset-input `pretransferred=true` rejection matrix: both SE entrypoints × empty/funded/rebased/donated vaults × zero/short/exact/excess prior asset transfers × caller classes. Otherwise valid calls return the exact pretransfer error with no mutation; corresponding supported pull calls succeed |
| F-15 | Share-input `pretransferred=true` success matrix: exact-input redemption and exact-output withdrawal, exact/excess vault-held shares, distinct receivers and intervening rebases. Burn only the requested/required shares, refund the snapshotted unused SE share prepayment to the caller, enforce limits and fail on insufficient shares. Compare with pull/holder-burn routes and SY internal redemption |
| F-16 | Real registered wrapper used as SE inventory in each applicable current DETF-buffer binding: deploy/configure, join, quote, swap where supported, exit and use DETF issuance/redemption paths that consume the buffer. Verify rebase-aware valuation, 19-/28-decimal share handling, zero wrapper fees and supported pull-deposit/pretransfer-withdrawal routing |
| F-17 | Transition/external quote sequences agree with equivalent executed operations from the same snapshot, including ReceiveShares, partial/full exits, distinct external depositors, donations and reward-settlement boundaries. Quotes never mutate live state |
| F-18 | General rebasing ERC20s with no DETF-specific API, positive/negative rebases and loss/recovery work under the declared model; a token with a separate reward distributor triggers no wrapper harvesting or reward payout |
| F-19 | Every vault execution rejects zero amount/zero actual output; zero-amount previews return zero and valid positive previews rounded to zero return zero. Test all ERC4626/SE/SY overloads and preserve the distinction from zero slippage minima |
| F-20 | At zero backing with outstanding shares all new deposit/mint routes reject and maximum entry views return zero; first deposit into a fresh vault and re-entry after external backing restoration work |
| F-21 | SY rate quantization boundary returns the last positive rate or reverts with `SYExchangeRateUnderflow()` as specified; valid positive-output ERC4626/SE exits remain usable |

The existing `test_rebasing_vault_live_balance` donation test is a useful baseline, but does not prove real rebasing-token settlement or any SY/SE behavior. Reuse existing native SY and TokenStaking suites where appropriate without treating their current results as coverage of the new package.

## 8. Adversarial testing requirements

Every row is a required attack family. Map exact Crane IDs to tests in the later plan. Conditional categories may be marked inapplicable only with a concrete surface-based explanation in the suite and evidence matrix; applicable critical failures cannot be waived by renaming them expected behavior.

| ID / category | Attack | Required result |
|---|---|---|
| ADV-01 / A0, A, K | Donate before first deposit, donate between quotes and execution, seed empty-supply residuals, first-depositor inflation and repeated dust deposits | No unearned credit or profitable victim-value extraction; donation cost included; specified virtual-offset rounding holds |
| ADV-02 / I1–I3 | Asset-input pretransfer with no/short/exact/excess payment, replayed payment, donated/rebased reserves or a privileged caller; share-input withdrawal with no/insufficient self-held shares or attempted reuse of already burned shares | All asset-input pretransfer calls revert. Withdrawal pretransfer succeeds only against sufficient static shares held by the vault and burns only the required amount; backing alone never authorizes withdrawal, and consumed shares cannot be reused |
| ADV-03 / C, N1 | Reenter each ERC4626/SE/SY mutation from token transfer/transferFrom, including cross-interface and SY self-call paths | Shared protection or proven safe sequencing; no double mint/burn, allowance misuse or partial settlement |
| ADV-04 / N1, K | Trigger positive/negative rebase or reward settlement during inbound/outbound transfer | No rebase income credited to the depositing caller, no stale-denominator advantage, no overpayment; safe revert or proven consistent settlement |
| ADV-05 / D, F, M3 | Arbitrary owner/receiver; third-party allowance abuse; direct internal-route calls; burn from victim; abuse self-held share context | Only caller/authorized shares consumed; bounded SY public internal balance semantics; context cleared after success and failure |
| ADV-06 / E6, F5 | Large max input with small actual input, prior backing, residual shares and forced ETH; try excess refund/sweep | Return only the specified unused static-share prepayment budget; never refund asset reserves, external holders' balances or callback-added shares. Public unassigned self-held shares follow the documented SE refund model |
| ADV-07 / E, H | Failed transfer, failed minimum/maximum, expired deadline, invalid route, paused/blacklisting token | Exact expected error where specified; complete rollback of balances, supply, allowances, transient context and accounting |
| ADV-08 / L2 | Real fee-on-transfer token configured in adversarial harness; short inbound and taxed outbound | No claim of FoT support or phantom credit; detect/reject measurable shortfalls without token allowlists; recipient-output guarantees cannot pass on nominal amounts alone |
| ADV-09 / J, F | Missing/colliding selectors, mismatched package metadata, direct initialization, unauthorized diamond cut, package reinitialization | Complete callable surface; no mutation of a deployed vault's asset/configuration or authority escalation |
| ADV-10 / E, N2 | One-unit rounding, near-zero backing, huge balances/supply/offset, rate quantization, repeated exact-in/out cycles | No free gain, wraparound or overdraw; full-precision bounds and deliberate rejection outside the approved domain |
| ADV-11 / G | Multiple vaults sharing facets/package, nested production consumers and attacker-controlled receiver | No cross-vault storage/balance leakage; supported consumers remain solvent and callable |
| ADV-12 / M, O (conditional) | Router calldata/allowance abuse and invalid, expired, replayed or wrong-domain signatures if those surfaces are added | Only explicitly authorized transfers and fixed routes; no arbitrary call path; all applicable signature negatives pass |
| ADV-13 / CROPS | Disable registered vault after users hold shares | Approved inbound restriction applies consistently; ordinary exits remain available through ERC4626/SE/SY |
| ADV-14 / SE and SY custody | Transfer shares to vault, consume public internal balance through SE/SY, partially redeem, attempt to consume external holder balances, interleave or replay calls | Public static-share custody and atomic integration documented; no attribution falsely inferred from a separate prior transaction; no cross-interface double burn or consumption of shares held by external accounts |
| ADV-15 / G, N, K | Malformed/stale quote states, mixed projected/live books, donation/rebase between composed operations, incorrect decimal scaling, or buffer caller attempting asset pretransfer | No false entitlement, fee bypass outside the wrapper, free issuance or overpayment; unsupported deposit pretransfer still rejects and compatible buffer routes succeed |
| ADV-16 / E, H, N | Zero amount/zero payout, complete reserve loss, attempted recapitalization through each deposit route, SY rate underflow and failed share refunds | Exact specified failure with atomic rollback; no donation disguised as a deposit, no zero-payout burn, no fabricated rate, and no partial burn/payment when refund fails |

The wrapper itself does not introduce AMM-based valuation. Because DETF-buffer use is required, applicable composed buffer/AMM manipulation and stale-valuation attacks must be covered at the integration boundary; they cannot all be dismissed as inapplicable to the direct wrapper. Loss of backing caused by the underlying issuer is an external risk; tests must still prove proportional accounting and no fabricated assets after the loss.

## 9. Fuzz and stateful invariant requirements

### 9.1 Fuzz properties

Parameterize amounts, supply/backing ratios, decimals/offsets, actor/receiver/owner combinations, allowances, limits, deadlines, donation sizes, rebase factors and operation ordering. Exercise zero/one-unit values, near-empty/full balances, decimal transitions and overflow boundaries explicitly. Do not bound away the adversarial cases or use unbounded assumptions that reject almost all generated inputs.

| ID | Property |
|---|---|
| FUZZ-01 | Preview/execution and ERC4626/SE/SY equivalence from the same snapshot, for every supported direction and exactness mode |
| FUZZ-02 | Exact-output minimality: the quoted input suffices; one less does not satisfy the requested output under the same state; maximum input is never exceeded |
| FUZZ-03 | Closed conversion cycles cannot increase attacker wealth without separately accounted rebase income/donations; splitting an operation cannot exploit accumulated rounding |
| FUZZ-04 | Donation/rebase sequencing cannot mint new shares for free; the next depositor does not capture previous holders' rebase income |
| FUZZ-05 | Rate conversion and decimal scaling satisfy the derived quantization bound; no silent zero-rate or exponent-overflow boundary |
| FUZZ-06 | Share transfers/allowances/receivers preserve entitlement and authorization, including partial SY internal-balance redemption |
| FUZZ-07 | Every invalid input/limit/flag failure is atomic; exact failure selectors distinguish intended validation from unrelated setup failure |
| FUZZ-08 | Multi-user loss/recovery, full exit/redeposit, and settlement during transfer preserve the reference accounting equations |
| FUZZ-09 | Across arbitrary amounts, limits, callers and backing/rebase/donation states, both SE entrypoints reject asset-input `pretransferred=true`; otherwise valid cases assert the dedicated error and complete state preservation |
| FUZZ-10 | Share-input pretransfer through both SE entrypoints succeeds when funded and within limits, consumes precisely the independently calculated shares, refunds unused snapshotted SE share prepayment to the caller, and rejects insufficient shares without consuming asset reserves or external holder balances |
| FUZZ-11 | Generated transition/external quote sequences match independent-model and live buffer execution from the same starting state across rebase boundaries, decimal combinations and multiple holders |
| FUZZ-12 | Random public share-prepayment budgets, required burns, max inputs and recipients produce `burned + refunded = snapshotted prepayment`; no reserve asset is refunded, and refund failure reverts the entire operation |
| FUZZ-13 | Across amount, supply/backing and rate boundaries, zero-value executions always revert, zero-amount previews return zero, zero-reserve deposits cannot recapitalize old shares, and zero calculated SY rates produce the exact custom error |

### 9.2 Stateful handler model

Use at least three independent holders plus an attacker and a separate receiver, with at least two vault instances sharing production facets. Actions must include ERC20 transfer/approval, all ERC4626 operations, both SE exactness modes in both directions, SY deposit/redeem (including atomic internal balance), donation, rebase/loss, real reward settlement, time advance, expected invalid calls and full exits. Include registry disable/enable actions and nonzero fee configuration updates to prove the fee exception. Explicitly generate successful share-pretransfer withdrawals and rejected asset-pretransfer deposits.

Maintain independent ghost accounting for each actor's assets/shares, authenticated deposits, withdrawals, donations, rebase gains/losses, fee-recipient deltas (required to remain zero), vault-held shares, actual supply and rounding residuals. Virtual shares belong in pricing only and must not be counted as issued ERC20 supply. For rebasing actors, normalize external gains/losses in the economic oracle so a real rebase is not misclassified as an exploit.

| ID | Invariant after every successful action and each intentionally reverted action |
|---|---|
| INV-01 | Actual ERC20 supply equals the sum of tracked holder shares, including the vault and all modeled recipients; transfers/rebases alone do not change wrapper supply |
| INV-02 | `totalAssets` equals live approved-asset backing; independent flow accounting reconciles initial backing + authenticated inflows + donations + rebase changes − paid outflows |
| INV-03 | Aggregate independently computed redeemable holder claims do not exceed backing; virtual accounting does not create spendable assets |
| INV-04 | No actor consumes another holder's shares/allowance without authorization; only the specified public vault-held static share balance is available to SE pretransfer withdrawal and SY internal redemption |
| INV-05 | Cross-interface quotes and execution preserve ACC-03/ACC-07; the same action cannot settle/mint/burn twice |
| INV-06 | No deposit credits prior asset reserves, asset donations or rebases as caller payment; rejected calls leave no reusable deposit credit. Approved withdrawals consume actual static shares held by the caller/authorized owner or the public vault balance |
| INV-07 | Rate/discovery/interfaces remain consistent with the immutable asset, decimals and selected numeric domain; positive backing changes at fixed supply cannot reduce the mathematical rate, and losses cannot increase it |
| INV-08 | Absent external gains/losses and accounting for attacker-funded donations, attacker-controlled closed cycles cannot extract other holders' value beyond a derived, documented rounding bound |
| INV-09 | Failed operations preserve all economic state; locks and temporary caller context do not leak into the next action |
| INV-10 | Vault instances remain isolated; one instance's actions do not alter another's asset/configuration/share ledger |
| INV-11 | No asset→share SE call with `pretransferred=true` succeeds. Funded share→asset pretransfer withdrawals succeed, burning only required available shares once and refunding unused snapshotted SE share prepayment. The handler must cover successful and rejected cases across both entrypoints after rebases/donations |
| INV-12 | Vault operations charge/accrue no fees, issue no fee shares and transfer nothing to fee recipients regardless of manager fee configuration; registry membership and entry/exit disable behavior remain correct |
| INV-13 | Successful SE pretransfer withdrawals burn and refund precisely the snapshotted public share budget; internal SY redemption burns only its requested amount under its separate canonical behavior; no input is counted twice |
| INV-14 | No vault money execution succeeds with zero input/output; no new shares are issued by deposits while the pre-operation reserve is zero and supply is nonzero |
| INV-15 | SY rate queries either return the correct positive quantized rate or revert with `SYExchangeRateUnderflow()`; no clamping, hidden harvest or separate reward liability is introduced |

Include a composed invariant campaign with the real wrapper attached to a supported production DETF buffer. Exercise joins/exits, supported swaps, DETF routes, reward settlement and rebase changes; reconcile wrapper backing, buffer-held shares and outer claims without double-counting. Keep all applicable deposit-pretransfer rejection and fee-exemption properties active.

Invariant handlers must report attempted, successful and expected-revert counts per action. Require nonzero successful coverage of every supported money route and rebase/loss/exit transitions in deterministic seeded campaigns. Broad `try/catch` swallowing unexpected errors or an all-reverting campaign is a failed run. Preserve minimized counterexamples as deterministic regressions.

### 9.3 Required campaign evidence

Proposed release minimum: **10,000 fuzz cases per property** and **1,000 invariant runs at depth 100**, repeated with at least three recorded seeds. Focused developer runs may be smaller. These values are reviewable minimums, not a claim of formal proof.

The current repository defaults (`fuzz.runs=16`, invariant `runs=16`, `depth=8`) are smoke settings and do not satisfy this PRD's release evidence. Use supported command/environment overrides in the existing default profile; do not introduce a package-specific profile or change global settings merely for this feature. Record compiler, optimizer, commands, seeds, run/depth counts, handler statistics and failures/shrinks.

## 10. Acceptance and handoff gates

| Gate | Completion evidence |
|---|---|
| AC-01 | §11 decisions resolved, approved PRD revision identified, and subsequent implementation plan maps each ACC/API/PKG/test ID to owned work |
| AC-02 | One static share token exposes working ERC20/ERC4626/SE/SY; full proxy surface and interface declarations verified |
| AC-03 | All route, arithmetic, payment-attribution, metadata, rate and reward requirements pass independent-oracle functional tests |
| AC-04 | Applicable adversarial rows pass on production deployments; no unresolved value-theft, free-mint, overdraw or authorization failure. API-07/F-14/F-15/ADV-02/FUZZ-09/FUZZ-10/INV-11 prove asset-input pretransfer rejection and safe share-input pretransfer withdrawals |
| AC-05 | Fuzz and invariant campaigns meet §9 with recorded seeds, non-vacuous handler coverage and replayable regressions |
| AC-06 | Real sDETF settlement, TokenStaking and current in-scope DETF-buffer integration pass; transition/external quotes match execution and relevant existing ERC4626/native SY/buffer suites remain green |
| AC-07 | Factories, registry decision, release identity, old-manifest handling, deterministic replay, ABI/export records and runtime sizes are verified |
| AC-08 | `forge build` precedes tests after production changes; focused and required hermetic regression checks pass without `via_ir`, mock SUTs or hidden compile failures |
| AC-09 | Residual numeric/economic limitations and intentionally unsupported flags/routes are documented; no unsupported compatibility claims |
| AC-10 | General-purpose rebasing support, no reward harvesting, SE refund conservation, zero-value rejection/zero previews, zero-reserve entry protection and explicit SY rate-underflow errors have functional, adversarial, fuzz and invariant evidence |

A later isolated Robinhood-fork rehearsal may validate the approved deployment path after explicit deployment authorization. Record fork block/hash and reused addresses at that time. Hermetic validation does not require sending transactions to the existing local node or to public mainnet. No test pass or PRD approval itself authorizes public deployment.

## 11. Owner-confirmed decision register

| Decision | Confirmed answer | Why it matters |
|---|---|---|
| D-01 — Fee policy — **resolved by owner** | No vault fees through any interface; explicit exception to standard protocol fee-taking | Manager/fee-oracle configuration must not override the exception |
| D-02 — Registration — **resolved by owner** | Deploy through IndexedEx Manager/Vault Registry and list created vaults there | Adapt existing helpers/TokenStaking and version changed initialization; registry registration must preserve the fee exception |
| D-03 — Directional pretransfer and SY custody — **resolved by owner** | Reject asset-input deposit/mint pretransfers; support static-share-input withdrawal/redemption pretransfers and SY internal-balance burns | A rebasing reserve lacks a trustworthy pretransfer deposit baseline. Static shares can be held and burned; require rejection and successful-withdrawal tests in all four testing layers |
| D-04 — Decimals — **resolved by owner** | Keep `shareDecimals = assetDecimals + d`, default immutable offset `d = 10`; document and test numeric safety bounds in the implementation plan | Preserves existing conversion precision and virtual-share accounting: nine-decimal sDETF yields 19-decimal wrapper shares, with one displayed share initially representing one displayed asset unit |
| D-05 — General-purpose wrapper — **resolved by owner** | Support general rebasing ERC20 assets; sDETF is one integration, not the only permitted input | Expose static shares for other protocols; no protocol-token allowlist or unconditional DETF-specific settlement calls; test generic rebasing assets and real sDETF |
| D-06 — DETF-buffer compatibility — **resolved by owner** | Vaults can serve as underlying SEs in DETF buffers; include canonical transition/external quote APIs, required consumer wiring and production integration tests | Prove rebase-aware sequential valuation and valid deposit/withdrawal routing, preserving zero wrapper fees and the approved decimal convention |
| D-07 — Withdrawal refunds — **resolved by owner** | Burn required pretransferred shares and refund unused supplied shares to the initiating caller | Pin public static-share custody/refund accounting; never refund the rebasing reserve; canonical SY internal redemption remains a separate exact-burn route |
| D-08 — Separate reward tokens — **resolved by owner** | No support, harvesting or distribution; empty SY reward methods | General wrapping compatibility does not add a reward-management product |
| D-09 — Zero value — **resolved by owner** | Zero-value vault executions revert; zero-amount previews return zero | Includes positive-input/zero-output execution failures; zero slippage minima are not zero operation amounts |
| D-10 — Zero reserve — **resolved by owner** | Stop deposits/mints when backing is zero and shares remain outstanding; allow fresh initialization and later external restoration | New depositors must not unintentionally recapitalize old holders |
| D-11 — Unrepresentable SY rate — **resolved by owner** | Revert with `SYExchangeRateUnderflow()` when the calculated WAD rate rounds to zero | Preserve correctly computed positive-output ERC4626/SE exits; never invent a nonzero rate |

The separate implementation plan has been written at the owner's request. Approve the complete PRD, resolve and review the plan's exact technical specifications and buffer-topology conflict, and only then delegate that approved scope to another agent. The implementer must not choose unresolved product behavior or silently defer required tests. Do not mark these drafts or their test matrices as implemented evidence.
