# Fee-accrual DETF composition PRD

- Created: 2026-09-08
- Last updated: 2026-09-11
- Status: Draft specification of the agreed composition; implementation and deployment validation pending.
- Scope: Fee-free SY/SE ERC4626 wrapper used for custody, existing unified V4 DETF composition, and cross-pool Universal Router swap interface.
- Deployment and existing staking migration: [deployment, migration and UI rehearsal plan](../../../../../../../../docs/FEE_ACCRUAL_DETF_DEPLOYMENT_AND_STAKING_MIGRATION_PLAN.md). Requested on 2026-09-11; use the existing staking migration functions and reuse the deployed core on a latest-at-start Robinhood fork. The owner confirmed that deposits and remaining reward reserves migrate together through `migrateToClaimVault`; do not rescue or donate those migration funds. The other listed deployment decisions remain to be resolved.
- Research context: [NET/Morpho/Pendle research](../../../../../../../../docs/detf/NET_MORPHO_PENDLE_STRATEGY_RESEARCH.md) and [deferred fee-accrual Pendle/Morpho candidate](../../../../../../../../docs/detf/FEE_ACCRUAL_DETF_PENDLE_MORPHO_RESEARCH.md).

## 1. Purpose

Compose a simple fee-accrual DETF that receives capital from liquidated fees of other DETFs, builds exposure to the Pons-launched DTF/ETH Uniswap V4 base pool, and holds additional DTF through a custody SE. Provide a swap interface that can execute routes between the base pool and the DETF's weighted reserve pairings.

This is a management-automation composition built from common components. It is not a new DETF lifecycle or a special token-specific implementation. A package must allow other users to deploy the same architecture with different compatible tokens, SE instances, pool keys, and configuration.

The existing unified V4 DETF package is the intended deployment mechanism. Implement missing reusable components and prove the exact composition through integration tests rather than creating a parallel fee-DETF issuance, donation, staking, or bond system.

## 2. Authority and terminology

The current [DETF alignment PRD](../../../../../DETF_ALIGNMENT_PRD.md), especially D32-D66 and section 24, and [instance I/O routing PRD](../../../../../DETF_INSTANCE_IO_ROUTING_PRD.md) remain authoritative for the shared lifecycle. This document specifies a composition, not exceptions to those rules. Conflicting historical LP-backed staking or bond-owned reserve descriptions must not be reintroduced.

| Term | Meaning in this instance |
|---|---|
| DTF | The base ERC-20 token launched using the Pons Family factory |
| DETF | This fee-accrual DETF's own share ERC-20 |
| sDETF | This DETF's funded staking receipt, not a staking token for DTF |
| Base pool | The graduated Pons DTF/ETH Uniswap V4 pool; exact deployed PoolKey must be verified |
| Reserve hook | The SE-buffered weighted hook backing this DETF |
| Liquidity SE | Existing Uniswap V4 position SE bound to the base pool |
| Custody SE | Reusable single-asset SE holding DTF in this deployment |
| WETH | ERC-20 settlement face used by the reserve and configured SE routes |

Use generic role names in production interfaces and code. DTF and WETH are this deployment's choices, not hardcoded package assumptions. Apply existing token policy: no configured fee-on-transfer or rebasing underlyings, and correct scaling for supported decimals.

## 3. Accepted requirements

| ID | Requirement |
|---|---|
| F01 | Use common DETF components and the existing unified Uniswap V4 hook-based DETF package. |
| F02 | Use the existing SE-buffered weighted hook with three reserve tokens: DETF, WETH, and DTF. |
| F03 | Bind WETH to the existing DTF/ETH liquidity SE and DTF to a distinct Custody SE. The DETF self-leg is raw DETF. |
| F04 | Accept WETH and DTF as configured mint inputs. WETH uses the liquidity SE; DTF uses custody. |
| F05 | Configure DTF as the burn output through the Custody SE. Preserve mandatory primary price gates and reserve-swap fallback. |
| F06 | WETH donations use the liquidity SE; DTF donations use the Custody SE. Use existing donation configuration and execution. |
| F07 | Regular fee proceeds from other DETFs arrive as ETH economically and use wrapping into an accepted ERC-20 input where required. No donation frequency or amount is guaranteed. |
| F08 | Do not add a fee splitter. Each donation follows its configured token-to-SE mapping. WETH donations need not fund custody as well as LP. |
| F09 | Provide explicit Universal Router routes involving our weighted hook and the Pons hook, including ETH/WETH conversion within the transaction. |
| F10 | Retain WETH inside the reserve for this version. Native-ETH support inside the weighted hook is not required. |
| F11 | Keep Morpho borrowing, Pendle splitting, self-lending, and additional DTF staking outside this implementation scope. |
| F12 | Validate actual quote, trade, inventory, and donation behavior. Do not represent price increases, perpetual liquidity availability, or profitability as guaranteed. |

## 4. Reserve composition

**Owner-confirmed instance metadata:** both the ERC20 name and symbol are exactly `DTF-DETF`. Deployment arguments and frontend exports must preserve those values. This selects metadata for this fee-accrual instance; reusable packages continue to accept generic token names and symbols.

| Exposed reserve token | Hook inventory | SE binding | Provider target |
|---|---|---|---|
| DETF | Raw DETF | None | No provider |
| WETH | Liquidity SE shares | DTF/ETH Uniswap V4 SE | WETH per whole SE share |
| DTF | Custody SE shares | DTF Custody SE | DTF per whole SE share |

The weighted hook creates three pair doors over one shared inventory:

- DETF/WETH.
- DETF/DTF.
- DTF/WETH.

These are not three independently funded reserves. All doors must use the correct shared hook instance and initialized PoolKeys. Sort token addresses and all corresponding SE, provider, decimal, and weight entries consistently at deployment.

The hook supports three tokens and requires distinct nonzero SE bindings. The unified DETF package additionally requires every non-self leg to have an SE; a raw DTF leg is therefore not a substitute for the Custody SE in this composition. See `storeHookSetsAndRates` in [UniswapV4DetfProcessArgsLib](UniswapV4DetfProcessArgsLib.sol).

Use the existing immutable normalized weight model. The owner selected **60% DETF, 20% WETH, 20% DTF** on 2026-09-11. Assign weights by token role before sorting; normalized WAD values are `0.6e18`, `0.2e18`, `0.2e18`. The owner also requires a very rich opening state with minimal initial liquidity, aiming for months or years of expansion. Concrete creation/opening prices, bootstrap budget and expansion rate require a measured configuration; do not infer a fixed DTF/ETH price. Validate the runway after pooled staking migration and under trading, fee-inflow and no-inflow scenarios; opening richness alone does not guarantee a duration.

## 5. User and donation routes

Configure custom route tables to express the following intended external-token surface:

| Operation | Token | Selected SE |
|---|---|---|
| Mint input | WETH | Liquidity SE |
| Mint input | DTF | Custody SE |
| Burn output | DTF | Custody SE |
| Donation input | WETH | Liquidity SE |
| Donation input | DTF | Custody SE |

Use `mintRouteMode`, `burnRouteMode`, `donateRouteMode`, and their route arrays on [IUniswapV4Detf.PkgArgs](interfaces/IUniswapV4Detf.sol). Both donation rows match mint rows, satisfying the existing custom donation-subset rule. Bond routes, bootstrap inputs, and any optional SE-share input rows must be finalized consistently with the shared lifecycle; this document does not remove existing first-bond funding requirements.

Donation flow:

```text
Liquidated fees -> ETH -> WETH where required
    -> existing WETH donation route
    -> liquidity SE / reserve join

DTF donation
    -> existing DTF donation route
    -> custody SE / reserve join
```

Existing donation processing acquires protocol-owned reserve LP without issuing donor DETF or sDETF. Do not invent a second reward allocation or direct donation-to-staking conversion. Donations can affect subsequent synthetic pricing and funded expansion under existing rules.

Mint and burn labels identify configured routes, not unconditional primary issuance/redemption. When a primary price gate fails, the ordinary reserve-swap fallback must select and execute the supported route without an extra fee-DETF-specific branch.

## 6. Reusable Custody SE

**Owner decision, 2026-09-11:** reuse a separate instance of the fee-free `RebasingAwareERC4626DFPkg` with the implemented SY, SE and transition-quote facets. Deploy it through the IndexedEx manager's Vault Registry. Do not create a standalone custody package. Its asset is DTF; it is distinct from the existing staking contract's migration claim vault, whose asset is sDETF and whose package is already fixed.

The wrapper's approved accounting and interface rules apply: proportional actual backing, virtual asset/share offsets, donation-sensitive previews, no fees or reward tokens, rejected deposit pretransfers, supported withdrawal share pretransfers/internal-balance burning, zero previews and explicit zero-execution reverts. Use its actual metadata and backing-dependent rate; a constant provider is not valid. Test full redemption, dust, donated assets, authorization and minimum outputs through the real DETF buffer routes.

**Owner-confirmed decimal compatibility:** retain asset decimals +10 (28 for DTF) and extend/test the weighted hook's SE-share decimal support through 36. Keep the existing 6–18 range for ordinary pair tokens, and validate declared pair/share decimals against live metadata. Preserve distinct rated-asset and share-inventory scales; never relabel the shares.

Custody is not an irreversible lock. DTF exposed as a reserve output can be purchased through swaps, and supported redemption can release it. No time lock, burn mechanism, or prohibition on ordinary trading is required here.

## 7. Rate providers and valuation

### 7.1 Liquidity SE

The initial provider candidate is the existing `StandardExchangeRateProvider`, configured with the liquidity SE as subject and WETH as target. Its rate is a WAD-normalized WETH redemption quote per whole SE token, obtained through the SE's share-to-WETH preview.

This is not a claim that the provider implements proportional ETH NAV. The current implementation samples an amount and may adapt the sample; fees, price impact, and SE execution context can affect the result. Multiplying its rate by a large holding need not equal executable whole-position redemption proceeds.

Validate behavior under ordinary and locked-PoolManager contexts, since the liquidity SE can be used by a hook while the same PoolManager is already unlocked. Any alternative proportional valuation provider requires its own explicit price source, units, and semantics. Do not silently substitute the V4 SE's geometric liquidity-unit SY rate and label it WETH per share.

### 7.2 Custody SE

Use the existing StandardExchangeRateProvider with the custody wrapper as subject and DTF as target. Derive DTF backing per whole custody share from its share-to-DTF preview, normalized to WAD. ERC4626 virtual offsets govern raw share scaling; whole-token rate normalization must use the actual share decimals. Donations can change this rate, so do not hardcode `1e18`.

Do not ETH-rate the custody slot. Its mapped pair token is DTF. Relative DTF/WETH and DETF prices are determined by the reserve's concrete curve and inventory.

### 7.3 Shared requirements

- No provider on the raw DETF self-leg.
- Keep swap-rated balances distinct from native inventory used for liquidity accounting in the selected weighted implementation.
- Normalize token and SE decimals at the documented boundaries; test mixed-decimal configurations.
- No utilization-driven or cross-vault policy multipliers are selected for this simple version.
- Do not assume increasing a provider rate has the same directional effect across hook families or input/output routes. Validate the actual weighted implementation, including exact-input/exact-output consistency.
- Prevent recursive valuation of the DETF self-leg through its own reserve.

## 8. Base liquidity and economic interpretation

The liquidity SE owns additional strategy-controlled liquidity in the Pons pool. It does not acquire withdrawal rights over Pons's permanently locked launch position.

The local Pons V2 factory requires zero core LP fees. Hook fee recipient rights are separate from LP ownership. This composition's identified fee source is liquidated fees from other DETFs, not an assumed pro-rata Pons LP fee entitlement.

Distinguish:

- DTF acquired into the custody SE.
- DTF represented by strategy-owned base LP.
- DTF released from custody through swaps or redemptions.
- WETH deployed or held as liquidity-SE working inventory.
- Actual base liquidity added or removed.

WETH-funded liquidity entry can involve a DTF purchase, but proportional liquidity addition need not move price. DTF custody can reduce inventory available in the base pool while making that DTF available through the alternate reserve market. Neither mechanism guarantees a price increase.

Research and UI must describe the actual state changes rather than promise permanent removal, guaranteed appreciation, or guaranteed arbitrage profits.

## 9. Universal Router swap interface

### 9.1 Initial supported venues

Support the configured weighted reserve pairings and the graduated Pons base pool. The application's supported-hook list is its own integration scope, not an onchain permission requirement or a copy of an assumed Uniswap approval list.

Uniswap frontend or routing-service inclusion is not required to submit an explicitly encoded Universal Router route. Inclusion in external routing services remains separate work and is not guaranteed by compatibility alone.

Verify actual deployment addresses, router ABI/version, WETH, Permit2, PoolManager, PoolKeys, hook addresses, tick spacings, and fee fields. Symbols are not identifiers. The one-V4-path compositions below assume both pools share the router's PoolManager and the same DTF address.

### 9.2 Required route shapes

```text
ETH -> base pool -> DTF -> reserve -> WETH -> unwrap -> ETH

ETH -> wrap -> WETH -> reserve -> DTF -> base pool -> ETH

DTF -> base pool -> ETH -> wrap -> WETH -> reserve -> DTF

DTF -> reserve -> WETH -> unwrap -> ETH -> base pool -> DTF
```

The first two can place both swaps in one V4 multihop action with wrapping outside that action. The DTF round trips require separate `V4_SWAP` commands around the wrap/unwrap operation, within one outer `execute` transaction.

Each `V4_SWAP` must close its PoolManager deltas before completing. Collect intermediate outputs into router custody when later commands need them; do not pay them to the user prematurely. Use explicit amounts or the deployed router's supported balance sentinels correctly, not guessed sentinel values or ABI layouts.

### 9.3 Settlement and quote compatibility

The weighted hook takes physical input from PoolManager during `beforeSwap`. When it is the first hop, test pre-settling the explicit input from the appropriate payer before swapping so execution does not rely on incidental PoolManager inventory. Wrapping WETH into router custody requires router-pays settlement rather than pulling WETH from the user's wallet.

The local V4Quoter simulates swaps without prepaying input. Establish a quoting/simulation path that works for this custom-accounting hook even when a standard unfunded quote cannot. Do not infer hook prices from ordinary V4 slot0 alone.

Also validate liquidity-SE buffering and output availability while the shared PoolManager is unlocked. A router route can be structurally supported while a particular trade is unavailable in a particular state; quote and execution must expose that truthfully.

### 9.4 Interface and transaction requirements

- Present input, output, complete route, price impact or applicable quote information, fees, minimum output, and deadline.
- Support native ETH at the wallet boundary through Universal Router wrapping, without adding native ETH to the weighted hook.
- Use Permit2 appropriately for user-funded ERC-20 inputs.
- Include both venues' actual hook economics in quotes; a zero Pons core LP fee is not zero total trading cost.
- Keep required commands atomic by not enabling allow-revert on required route steps.
- Return all residual ETH and ERC-20 balances; do not intentionally leave user assets on the router.
- For arbitrage round trips, allow a final minimum-output constraint; distinguish token surplus from profit after gas.
- Provide direct encoded transaction execution independent of Uniswap's interface. A new onchain router is not assumed necessary; add an adapter only if integration evidence requires one.

## 10. Packaging and implementation boundaries

Use the registered package/factory deployment paths for new Custody SE components. Reuse the existing unified DETF package, weighted-hook package, V4 SE, and suitable provider components.

Deploy-time configuration includes token/SE bindings, provider configuration, weights, creation/opening prices, ordinary thresholds, creator metadata, liquidity permission mode, and route tables. Preserve immutable instance behavior and the shared funded-staking lifecycle.

No new fee splitter, owner-operated DETF policy, custom seigniorage mechanism, or duplicate donation entry point is required. Wrapping incoming ETH to WETH is a boundary operation, not fee-allocation logic.

The present scope authorizes this PRD as a design record, not automatic contract edits or deployment. Implementation planning must identify any discovered incompatibility in existing components instead of silently changing shared law.

## 11. Acceptance criteria

### Custody SE

1. Registered deployment, metadata, installed interfaces, and directional routes work with production components.
2. Deposits and redemptions conserve underlying assets and proportional ownership, with documented rounding and donation handling.
3. Unauthorized redemption, false pretransfer claims, reentrancy, unsupported routes, and slippage/deadline failures are covered.
4. Provider and SY units agree with custody accounting for supported decimal combinations.

### DETF composition

1. Deploy the three-leg composition through the existing package and registry path; verify sorted bindings, weights, providers, and pair creation.
2. Prove initial bootstrap with actual capital and required reserve legs.
3. Prove WETH mint input reaches the liquidity SE and DTF mint input reaches custody in the relevant primary path; verify reserve-swap fallback separately.
4. Prove configured DETF burn and fallback output routes pay DTF with correct actual reserve accounting.
5. Prove WETH and DTF donations use their configured SEs, acquire protocol-owned reserve LP, and do not mint donor DETF or sDETF.
6. Prove ordinary staking, bond, reward, expansion, and reserve ownership behavior remains unchanged.
7. Measure inventory and quote changes after donations and trades, including routes that release custody DTF.
8. Verify the selected rate providers in normal and locked contexts and reconcile exact-input/exact-output quotes and execution.

### Cross-pool routing

1. Execute all four route shapes against production-faithful Pons and weighted-hook components sharing one PoolManager.
2. Test the native-ETH Pons configuration, not only a WETH-quoted fixture.
3. Prove weighted-first execution without incidental input tokens already held by PoolManager.
4. Prove full-route quote/simulation parity and account for both hooks' deltas and fees.
5. Prove failure of a required swap or final minimum-output check reverts the complete transaction.
6. Prove intermediate custody, payer selection, allowances, residual refunds, and recipient handling.
7. Verify deployment-specific ABI and pool identities before any live release claim.

Use production-first Foundry tests, existing TestBases, and real registered components. Run `forge build` before tests after production edits because FactoryServices load artifacts. Follow the repository's default/hermetic and fork profiles; do not introduce package-specific profiles or viaIR. No test execution or completion is claimed by this document.

## 12. Open deployment and implementation decisions

| ID | Decision still required |
|---|---|
| O01 | Exact DTF/native-ETH base PoolKey and deployed router/PoolManager/WETH identities. |
| O02 | Weights resolved: 60% DETF / 20% WETH / 20% DTF. Rich opening, minimal seed liquidity and a months/years expansion objective confirmed. Opening prices are 100× creation prices on both capital legs; annual closure is 10%. Local bootstrap uses 0.001 WETH plus quoted DTF from the staking owner if funded. Absolute creation prices, quoted DTF cap and other limits remain to be measured. |
| O03 | Resolved: separate fee-free SY/SE rebasing-aware ERC4626 wrapper with its approved accounting and a proportional provider. Retain +10 and extend/test weighted-hook share decimals through 36 before deployment. |
| O04 | Exact bond/bootstrap routes and optional SE-share input routes. |
| O05 | `ownerOnlyLiquidity` deployment choice and corresponding supported LP operations. |
| O06 | Existing LP redemption-quote provider compatibility in all required contexts, or a separately specified replacement if evidence requires it. |
| O07 | Full-route quoting approach for prepaid custom-hook execution and deployed Universal Router ABI compatibility. |
| O08 | Location of the existing fee liquidation/ETH wrapping caller and the UI entry points to extend. No allocation splitter is required. |

## 13. Deferred research

Keep the previously recorded Pendle-before-Morpho proposal for later consideration. It explored splitting this DETF's staking SY into PT and YT, collateralizing PT, retaining rebase income, and using ETH financing for base liquidity. It is not part of this simple composition.

Cross-vault rate policies, deliberately scarce lending liquidity, multi-DETF financing loops, and native-ETH weighted-hook support are also outside this implementation scope. Their discussion does not authorize additional requirements here.

## 14. Source register

Local source observations were made during the 2026-09-08 discussion. They are not live-deployment certifications.

- [Unified DETF interface and PkgArgs](interfaces/IUniswapV4Detf.sol).
- [Unified DETF package route storage](UniswapV4DetfDFPkg.sol).
- [Route validation and SE requirements](UniswapV4DetfProcessArgsLib.sol).
- [Donation execution](UniswapV4DetfTarget.sol).
- [Weighted hook package](../../../../../../../hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol).
- [Weighted hook swaps and settlement ordering](../../../../../../../hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookHooksTarget.sol).
- [SE rate provider](../../../../../../../protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol).
- [Uniswap Universal Router command reference](https://docs.uniswap.org/contracts/universal-router/technical-reference).
- [Uniswap V4 routing guide](https://docs.uniswap.org/contracts/v4/guides/swap-routing).

## 15. Change log

| Date | Change |
|---|---|
| 2026-09-08 | Created the consolidated PRD from the discussion. Recorded the simple three-leg composition, accepted mint/burn/donation mappings, reusable Custody SE, provider semantics, Universal Router routes, scope exclusions, and validation requirements. No implementation or deployment performed. |

| 2026-09-11 | Owner selected fee-free SY/SE wrapper reuse for DTF custody, 60/20/20 reserve weights, and rich opening with minimal liquidity targeting months/years of expansion. Recorded the current weighted-hook share-decimal incompatibility and remaining measured economics. |

| 2026-09-11 | Owner retained +10 custody share decimals and authorized weighted-hook support; selected 100× opening/creation prices, 10% annual closure and a local 0.001 WETH bootstrap plus quoted DTF from the staking owner if funded. |
