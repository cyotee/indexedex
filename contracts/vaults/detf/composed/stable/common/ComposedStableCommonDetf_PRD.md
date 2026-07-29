# Product Requirements Document (PRD)

## Title
Stable Composed DETF (Composable Stable-Equivalent Vault Index)

**Threshold modes:** Conforms to [`DETF_Threshold_Modes_PRD.md`](../../../DETF_Threshold_Modes_PRD.md) (formal LOCKED) — deploy-time Policy (default ±5% synthetic deadband) vs Open; gates always synthetic; trailing `PkgArgs.thresholdMode`.

## Purpose
Enable users to deploy a DETF (Decentralized ETF) that composes 2–5 Standard Exchange vaults, each containing tokens considered of equivalent value and paired with a common asset. The DETF itself holds only a Weighted Pool token, abstracting away the underlying vaults and pools. The definition of “equivalent value” tokens and groupings is user-defined at deployment.

## Scope
- Contracts implemented in `contracts/vaults/detf/composed/stable/common/`
- DETF supports 2–5 user-specified Standard Exchange vaults
- Supports arbitrary ERC20 tokens as long as groupings are valid
- Integrates with Balancer V3 Stable Pools and Weighted Pools
- Follows protocol DETF patterns for seigniorage, bonding, NFT, and rebasing token
- This vault family must be implemented as a fresh codepath in `contracts/vaults/detf/composed/stable/common/` and must not reuse the concrete implementation contracts from Single Vault DETF or other DETF families.
- Existing DETFs may be used as behavioral references only; they are not the implementation base for this vault family.

## Implementation Progress Checklist

- [x] PRD decisions have been incorporated for fresh-implementation scope, mint semantics, bond-NFT requirements, rebasing-token requirements, and test strategy.
- [x] Fresh DETF-side pricing interface `IDETF` has been defined for composed-stable rebasing-aware valuation.
- [x] Fresh DETF-side pricing storage and logic have been implemented for reserve decomposition, stable/common BPT valuation, and synthetic DETF pricing.
- [x] `RebasingDETFTokenPricingFacet` has been implemented and validated as the canonical DETF-side pricing surface.
- [x] Fresh `RebasingDETFToken` implementation, package wiring, and factory services have been implemented.
- [x] Fresh `ComposedStableCommonDetfBondNFTVault` implementation, package wiring, and factory services have been implemented.
- [x] Shared component test bases for the composed-stable family have been added.
- [x] A fresh route-aware `ComposedStableCommonDetfExchangeIn` slice has been implemented for mint-path routing.
- [x] The mint-path routing now supports:
   - [x] selecting the eligible underlying vault for shared base tokens by lowest current rated liquidity
   - [x] selecting between Stable Pool and Common Pool by lowest current rated liquidity for the minted vault token
   - [x] applying threshold gating as availability only
   - [x] applying the seigniorage boost to the composed-pool BPT input before DETF quote math
   - [x] using live Weighted Pool balances and weights for DETF mint quoting
   - [x] reverting mint attempts when the reserve weighted pool is uninitialized
- [x] The top-level mint flow now applies the Protocol DETF-style split-mint behavior used by the other DETF families, so user minting, protocol-owned reserve principal, and Bond-NFT reward accrual stay behaviorally aligned with the rest of the product line.
- [x] The composed-stable DFPkg and component factory helper now initialize the new exchange-in route configuration.
- [x] Focused tests have been added for the new exchange-in route selection and mint quote behavior.
- [x] A preview-only composed-stable unwind query slice has been implemented via `ComposedStableCommonDetfExchangeOutQueryFacet` and shared reserve-exit helpers.
- [x] The composed-stable DFPkg, component factory helper, and deploy test wiring now include the new unwind query facet.
- [x] Focused tests validate max-liquidity exact-out preview selection, burn-threshold gating, unsupported token-in rejection, and package metadata/deploy wiring for the new unwind query facet.
- [x] The composed-stable package args now explicitly carry the Balancer V3 router proxy needed for future stateful reserve exits, instead of leaving unwind execution dependent on a narrow exact-in-only router type.
- [x] The composed-stable package args now explicitly carry Permit2 alongside the Balancer V3 router proxy so DETF-owned exact-out reserve swaps do not depend on hidden router state.
- [x] All currently-known composed-stable harnesses and deploy wiring have been updated to the new Balancer router proxy dependency shape.
- [x] The stable/common Foundry folder is currently green after these additions (`60 passed, 0 failed`).
- [x] Current focused validation status is green for the latest unwind/package slices:
   - [x] `ComposedStableCommonDetfExchangeOutQueryFacet.t.sol` passes after broadening the stateful exchange-out coverage (`15 passed, 0 failed`)
   - [x] `ComposedStableCommonDetfDFPkg_Deploy.t.sol` passes (`2 passed, 0 failed`)
- [x] `ComposedStableCommonDetfExchangeOutQueryFacet` has been extended from preview-only quoting to a first stateful `exchangeOut(...)` implementation for the composed-stable exact-out unwind path.
- [x] The focused deploy-spec harness was refactored to keep package-arg construction compile-safe after the new Permit2 plus exchange-out wiring, and package deployment validation remains green.
- [x] Focused unwind execution coverage now includes recipient fallback, refund-of-unused DETF input, and slippage rejection for the new stateful `exchangeOut(...)` path.
- [x] The exact-match vault-token unwind case is now supported in both preview and execution, so DETF holders can redeem directly into a routed vault token without forcing an additional underlying-vault exit.
- [x] The top-level DETF burn path now supports both `exchangeIn(...)` and `exchangeOut(...)` entrypoints where the route is feasible under gas and precision constraints.
- [x] Focused exact-in burn coverage now lives in a dedicated `ComposedStableCommonDetfBurnExchangeIn.t.sol` spec instead of being mixed into the exchange-out suite.
- [x] Focused unwind guard coverage now validates unsupported `tokenOut` handling, zero-amount rejection, expired-deadline rejection, burn-closed rejection during execution, and runtime failure when the Permit2/router dependency is missing.
- [x] The stateful unwind path now explicitly rejects residual underlying-vault token state after exact-out execution, so partial-unwind execution cannot silently leave DETF-owned vault-token inventory stranded on the proxy.
- [x] The focused unwind helpers and Foundry harness setup were refactored to stay compile-safe under Solc 0.8.35 without enabling `viaIR`, including reduced stack pressure in shared unwind selection helpers and smaller test-harness initialization surfaces.
- [x] The fresh rebasing-token exchange surface now supports canonical `exchangeIn(...)` and `exchangeOut(...)` redemptions to the configured common-token boundary, while retaining compatibility `previewRedeem(...)` and `redeem(...)` wrappers.
- [x] The top-level DETF now exposes shared `previewClaimLiquidity(...)` and `claimLiquidity(...)` reserve-unwind helpers for protocol-owned reserve exits used by rebasing redemption.
- [x] Legacy protocol `RICHIR` compatibility has been updated to satisfy the expanded shared `IRebasingClaimToken` interface, removing the repo-wide compile blocker introduced by the new standard exchange surface.
- [x] Focused rebasing validation now covers the rebasing token exchange surface across behavior, facet metadata, and package deploy wiring.
- [x] A first fresh composed-stable bonding facet has been added and wired into the top-level DETF package.
- [x] Focused bonding validation now covers accepted bond-token discovery, reserve-building bond entry, and sale-to-protocol rebasing mint orchestration (`ComposedStableCommonDetfBondingFacet.t.sol`: `5 passed, 0 failed`).
- [x] The Bond NFT deployment flow now mints a dedicated fee-recipient NFT to `feeTo()` from the Vault Fee Oracle, with deployment-time unlock semantics and bond-share accrual from `usageFeeOfVault(address(this))`.
- [ ] Implement the remaining top-level DETF execution surface beyond mint routing:
   - [ ] define the remaining top-level callable DETF surface beyond `previewExchangeIn(...)` and `exchangeIn(...)`, including the exact query and state-mutating entrypoints this family must expose for unwind, bond, and rebasing-driven flows
   - [ ] implement the DETF-side common helper layer for reserve exits so top-level execution does not duplicate pool-selection, quote, threshold, and token-transfer logic across unwind call sites
   - [ ] implement the top-level reserve-pool exit path that burns or redeems reserve BPT into the correct composed-pool leg using live reserve balances and weights
   - [ ] implement the top-level composed-pool unwind path that exits Stable Pool BPT or Common Pool BPT into the correct underlying vault token using the family-owned routing rules
   - [ ] implement the top-level underlying-vault unwind path that exits a selected Standard Exchange vault position back into the requested payout token or canonical redemption asset
   - [ ] define and implement the canonical DETF-owned payout path so end-user redemptions, Bond NFT redemption, and rebasing-token redemption all terminate through the same reserve-owned unwind execution graph
   - [ ] implement top-level accounting and guard behavior for those new execution paths, including deadline checks, recipient handling, token-in/token-out constraints, and any protocol-only caller restrictions
   - [x] expose and validate preview-style query functions for the unwind graph so each top-level state transition has a deterministic quote path paired with it
- [ ] Add the composed-stable exchange-out and redemption unwind path so the DETF owns reserve exits end-to-end:
   - [~] define the canonical `previewExchangeOut(...)` and `exchangeOut(...)` semantics for this family, including supported token-in/token-out pairs, recipient/refund behavior, and which caller paths are user-facing versus protocol-only
      - [x] the user-facing burn path should prefer `exchangeIn(...)` implementations when feasible, and only rely on `exchangeOut(...)` where the exact-out math remains practical under acceptable gas and precision constraints
      - [x] the current exact-out route selector chooses the eligible vault plus pool leg with the most available unrated liquidity instead of searching for the cheapest DETF input quote
   - [x] make the Balancer V3 router proxy an explicit package/runtime dependency so the future stateful reserve-exit path has the correct execution boundary
   - [x] make Permit2 an explicit package/runtime dependency so DETF-owned exact-out reserve swaps can approve and fund the Balancer router directly
   - [~] implement reserve-pool BPT exit quote logic for exact-in and any required exact-out style flows, using live reserve composition rather than static assumptions
   - [~] implement composed-pool exit selection and quote logic for Stable Pool BPT versus Common Pool BPT unwind legs, including the rules for choosing the correct leg for a requested asset
      - [x] the current exact-out selector uses the most-liquid eligible vault plus pool leg heuristic instead of cheapest-path search
   - [~] implement underlying-vault exit execution from vault token back to base asset, including the shared-common-token case and exact-match vault-token case
   - [x] support the exact-match vault-token payout case without routing through an unnecessary underlying-vault exchange
   - [ ] define the canonical payout asset behavior for user-facing exchange-out so DETF redemptions have one consistent unwind target and fallback policy
   - [~] add explicit revert conditions and guard rails for unsupported payout assets, closed burn paths, invalid reserves, and partial-unwind states
      - [x] unsupported payout assets currently fail the unwind preview/execution surface with `ExchangeOutNotAvailable()` when no canonical route exists
      - [x] closed burn-path execution currently reverts with `BurningNotAllowed(...)`
      - [x] invalid reserve state now reverts explicitly with `ReservePoolNotInitialized()` before unwind quoting or execution
      - [x] residual vault-token state after underlying exact-out execution now reverts with `ExchangeOutNotAvailable()` instead of leaving a partial unwind stranded on the DETF
      - [ ] broader product-level partial-unwind policy still needs to cover any future multi-leg or protocol-owned redemption extensions beyond the current exact-out path
   - [~] broaden focused unwind tests beyond the first happy-path execution to cover refund behavior, route selection edge cases, direct vault-token payouts, unsupported unwind combinations, and runtime dependency failures
      - [x] focused unwind coverage now includes reserve-uninitialized rejection and residual-underlying-token partial-unwind rejection (`18 passed, 0 failed` in `ComposedStableCommonDetfExchangeOutQueryFacet.t.sol`)
      - [x] focused exact-in burn coverage now validates most-liquid eligible route selection and exact-in execution in a dedicated `ComposedStableCommonDetfBurnExchangeIn.t.sol` spec (`2 passed, 0 failed`)
      - [x] focused exact-out route-selection validation remains green after the dedicated burn-test extraction and harness refactor (`test_previewExchangeOut_selectsMostLiquidEligibleRouteAndPoolLeg` passed)
- [ ] Implement DETF-owned rebasing-token redemption orchestration using the composed-stable reserve unwind path:
   - [x] define the DETF-owned redemption entrypoint that accepts rebasing-token burn intent and routes through the same reserve unwind graph instead of bypassing the DETF
   - [x] integrate `burnShares(...)` or equivalent rebasing-token accounting hooks so supply changes occur atomically with reserve exits and payout settlement
   - [~] source protocol-owned reserve principal from the fresh Bond NFT vault's protocol NFT state rather than duplicating reserve accounting inside the DETF
      - [x] the current rebasing quote path derives protocol-owned reserve sizing from the Bond NFT vault's protocol NFT state through `originalSharesOf(protocolNFTId)`-backed pricing helpers
   - [~] focused rollback coverage now validates that `exchangeIn(...)` and `exchangeOut(...)` revert cleanly without burning shares when the DETF-owned `claimLiquidity(...)` path fails at execution time
   - [~] full execution-time hardening for insufficient or stale protocol-owned reserve inventory is still pending across the broader redemption graph
      - [x] the shared DETF-owned `claimLiquidity(...)` boundary now fails early with `InsufficientBalance(...)` when the proxy does not hold enough reserve BPT for the requested claim
   - [x] the top-level DETF now persists and exposes its Bond NFT vault plus protocol NFT source through `IDETF.bondNftVault()` and `IDETF.protocolNFTId()`
   - [x] the DETF pricing surface now exposes `previewRebasingDetfTokenReserveBpt(...)` so rebasing-redemption flows can quote the protocol-owned reserve-BPT slice from rebasing supply using the Bond NFT vault as the source of truth
   - [x] define recipient, slippage, deadline, and payout-asset semantics for rebasing redemption so they align with the top-level DETF unwind surface
   - [ ] handle edge cases where protocol-owned reserve inventory is insufficient, stale, or partially composed across reserve legs at redemption time
- [~] Implement the top-level bonding target/orchestration for this family so the fresh Bond NFT vault is used in the full reserve-building path, not only as an isolated component:
   - [~] define the family-owned bond entrypoints and preview helpers that mirror approved existing bond semantics while targeting the fresh composed-stable codepath
      - [x] `acceptedBondTokens()`, `isAcceptedBondToken(...)`, `bond(...)`, and `sellNFT(...)` now exist on the fresh composed-stable bonding surface
      - [ ] preview-style bond helpers are still pending
   - [x] route accepted bond assets through the canonical reserve-building graph so bond creation and normal mint routing share the same reserve-entry semantics where intended
   - [x] mint reserve-position shares into `ComposedStableCommonDetfBondNFTVault.createPosition(...)` with the correct lock-duration, bonus, and recipient semantics
   - [x] implement sale-to-protocol orchestration so sold bond NFTs move principal into the protocol NFT and trigger the matching rebasing-token mint path
   - [ ] wire donation, protocol reward reallocation, and protocol-owned-NFT top-up flows through the family-specific Bond NFT vault rather than through isolated component tests only
- [ ] Wire the fresh rebasing token into the full composed-stable DETF lifecycle, including Bond NFT sale-to-protocol and protocol-owned reserve accounting flows:
   - [~] initialize and persist the rebasing-token dependency graph at the top-level DETF, including DETF proxy, fresh Bond NFT vault, WETH pricing boundary, and protocol NFT tokenId
      - [x] the top-level composed-stable DETF package/runtime wiring now persists and exposes its dedicated rebasing token dependency through `IDETF.rebasingDetfToken()`
      - [x] the top-level composed-stable DETF package/runtime wiring now also persists and exposes its Bond NFT vault plus protocol NFT source through `IDETF.bondNftVault()` and `IDETF.protocolNFTId()`
      - [x] the DETF pricing boundary now includes a canonical helper for converting rebasing-token amount into protocol-owned reserve BPT via `previewRebasingDetfTokenReserveBpt(...)`
      - [ ] WETH pricing-boundary and protocol-NFT lifecycle orchestration still needs to be unified into the top-level DETF execution flow
   - [x] connect Bond NFT sale-to-protocol completion to `mintFromNFTSale(...)` or the family-equivalent mint hook so rebasing supply tracks protocol-owned principal exactly once
   - [ ] define how protocol-owned reserve principal updates propagate into rebasing-rate queries after bond sales, donations, redemptions, and protocol reallocations
   - [ ] ensure top-level DETF flows that mutate protocol-owned reserve state cannot leave rebasing supply, protocol NFT shares, and reserve inventory out of sync
   - [ ] document and implement any protocol-only permissions required for the DETF to call rebasing-token mint and burn primitives safely

### Rebasing Redemption Decisions
- Rebasing redemption is the inverse of the mint-under-price reserve-building path.
- The payout asset for rebasing redemption is the deployment-configured common token boundary. WETH is only the current example deployment, not a protocol-wide requirement.
- The rebasing token is the user-facing redemption surface. It should support both `exchangeIn(...)` and `exchangeOut(...)` semantics for rebasing-token to common-token exits.
- The legacy `previewRedeem(...)` and `redeem(...)` functions may remain as compatibility wrappers, but canonical routing should use the standard exchange surface.
- Rebasing redemption must support the same `pretransferred` option used by the standard exchange entrypoints.
- The source of truth for reserve principal is the Bond NFT vault's exact `originalSharesOf(protocolNFTId)` value.
- Redemption flow:
   1. Convert apparent rebasing balance to internal rebasing shares.
   2. Convert those shares into the proportional protocol-owned Bond NFT reserve shares / reserve-pool BPT claim.
   3. Proportionally remove that reserve-pool BPT from the reserve pool.
   4. Burn the withdrawn DETF leg.
   5. Unwind both composed Stable Pool legs into the configured common token.
   6. Deliver the resulting common token to the recipient.
- Neither the rebasing token nor the DETF token should expose user-facing redemption into intermediate pool tokens or vault tokens.
- DETF-token burning for common-token payout remains a separate gate-controlled route; rebasing-token redemption uses protocol-owned reserve accounting instead.
- The DETF-owned reserve-claim path should be shared by Bond NFT redemption and rebasing-token redemption wherever possible.
- [ ] Expand package-level deployment wiring for a full composed-stable DETF instance, including the final top-level dependency graph for underlying vaults, composed pools, reserve pool, and route config:
   - [ ] finalize the remaining `PkgInit` and `PkgArgs` requirements for the top-level DETF package once exchange-out, bond, and rebasing lifecycle dependencies are fully known
   - [ ] wire the final facet/package set so the deployed DETF proxy exposes mint, unwind, bond, pricing, and rebasing-owned lifecycle surfaces as one coherent instance
   - [ ] ensure deployment ordering is correct for underlying vaults, rate providers, Stable Pool, Common Pool, reserve Weighted Pool, Bond NFT vault, rebasing token, and any protocol-owned NFT initialization step
   - [ ] make the component and package factory-service helpers construct this full dependency graph deterministically from typed inputs
   - [ ] add deployment-time assertions that the instantiated DETF, Bond NFT vault, rebasing token, pools, and route config all point at each other consistently
- [ ] Add package/runtime validation for grouping and route correctness:
   - [ ] stable grouping uniqueness
   - [ ] common-token consistency
   - [ ] vault/token pairing validation
   - [ ] route-config structural validation
- [ ] Add integration tests for:
   - [ ] full deposit -> vault -> composed pool -> reserve pool -> DETF mint flow on deployed instances
   - [~] bond creation -> Bond NFT mint -> sale-to-protocol -> RebasingDETFToken mint
      - [x] focused bonding harness coverage now validates this lifecycle on the fresh composed-stable codepath
      - [~] a first real deployed-instance wiring slice now exists via `ComposedStableCommonDetf_IntegratedDeploy.t.sol`, but full deployed-instance lifecycle coverage is still pending
   - [ ] rebasing-token redemption through DETF-owned unwind execution
   - [ ] reserve/accounting deltas across DETF, pools, Bond NFT vault, and rebasing token
- [ ] Add broader fuzz and invariant coverage for the composed-stable DETF accounting model.
- [ ] Resolve and document deterministic tie-break behavior if equal rated-liquidity routes or pool targets occur.

### Current Milestone Interpretation
- [x] Support infrastructure for the composed-stable family is substantially in place.
- [x] The first real top-level DETF behavior slice, mint-path routing and quote execution, is implemented and tested.
- [x] A first stateful exact-out unwind path is now implemented and validated together with package/deploy wiring.
- [x] A dedicated exact-in DETF burn validation slice is now implemented and green, separate from the exact-out unwind suite.
- [x] The current exact-out unwind slice now has explicit guard rails for unsupported payout assets, invalid reserve state, and residual-token partial unwinds in the implemented path.
- [x] The rebasing-token redemption prerequisite slice is now implemented through the shared DETF-owned `claimLiquidity(...)` reserve-unwind graph and the focused rebasing behavior suite is green.
- [x] Rebasing validation has been broadened beyond the behavior harness into facet-metadata and deploy-spec coverage for the same claim-liquidity-backed redemption path.
- [x] Focused rebasing rollback coverage now confirms failed DETF-owned reserve claims do not burn or strand user shares (`RebasingDETFTokenBehavior.t.sol`: `9 passed, 0 failed`; focused failure-path subset: `2 passed, 0 failed`).
- [x] A first top-level bonding slice is now implemented and green, including reserve-building bond entry and Bond NFT sale-to-protocol rebasing mint orchestration.
- [x] Bond NFT redemption already terminates through the shared DETF-owned `claimLiquidity(...)` path, so Bond NFT and rebasing redemption now share the same reserve-claim boundary.
- [ ] The family is not yet feature-complete as a full DETF product.
- [ ] The largest remaining gap is end-to-end redemption hardening and the remaining bonding lifecycle flows through the top-level DETF proxy.
- [x] The earlier unrelated repo-wide compile blocker from legacy `RICHIR` drift has been resolved; the focused rebasing behavior suite now passes (`7 passed, 0 failed`).
- [~] The current next concrete code step after the bonding slice is broader deployed-instance lifecycle coverage and the remaining redemption-orchestration hardening beyond the already-shared Bond NFT plus rebasing `claimLiquidity(...)` path.

### Refactor Execution Plan
- The remaining Stable DETF refactor should be executed in small, behavior-scoped slices so each change can be validated locally before the next one lands.

#### Slice 1: Bond NFT vault model
- Extend `ComposedStableCommonDetfBondNFTVault` storage and target logic to support three position classes:
   - ordinary user bond NFTs
   - the DETF-owned protocol NFT
   - the fee-recipient Protocol NFT minted to `feeTo()`
- Persist separate token IDs for the DETF-owned protocol NFT and the fee-recipient Protocol NFT.
- Persist the deployment timestamp used as the unlock time for the fee-recipient Protocol NFT.
- Keep user-position accounting semantics unchanged apart from the explicit gross-to-net share split applied before user crediting.

#### Slice 2: Deployment-time special NFTs
- Update the Bond NFT vault package and initialization flow so both special NFTs are minted deterministically during deployment or first initialization.
- Mint order must be deterministic:
   - first the DETF-owned protocol NFT
   - second the fee-recipient Protocol NFT
- The fee-recipient Protocol NFT owner must be sourced from `feeTo()` on the Vault Fee Oracle.
- The fee-recipient Protocol NFT unlock time must equal the DETF deployment timestamp.

#### Slice 3: Bond fee skim
- Refactor the top-level stable bonding flow so reserve-pool BPT produced by a new bond is treated as gross shares.
- Query `usageFeeOfVault(address(this))` from the Vault Fee Oracle during bond creation.
- Split gross bond shares into:
   - net user shares
   - fee-recipient shares
- Credit net user shares to the newly minted user bond NFT.
- Credit fee-recipient shares to the fee-recipient Protocol NFT.
- Do not merge fee-recipient shares into the DETF-owned protocol NFT.

#### Slice 4: Mint split math
- Preserve current route selection and seigniorage-boosted gross mint quote behavior.
- Add a stable-side mint calculation helper that splits the gross DETF quote into:
   - net user DETF output
   - protocol-side DETF reward allocation
- Keep this split separate from the seigniorage input boost.

#### Slice 5: Protocol reserve updates during mint
- Refactor the state-mutating mint path so ordinary user minting performs all Protocol DETF-style post-quote actions:
   - mint net DETF to the user
   - mint the protocol-side DETF allocation to the Bond NFT vault as reward-token accrual inventory
   - add the reserve-pool BPT created during the mint route to the DETF-owned protocol NFT principal position
- Do not create a new user bond NFT during ordinary minting.

#### Slice 6: Preview semantics
- Update all mint preview surfaces so they return the post-split net user DETF amount rather than the gross pre-split DETF quote.
- Preserve the current threshold-gating semantics: thresholds gate availability only and do not directly determine mint output.

#### Slice 7: Package and deployment wiring
- Extend top-level package wiring so deployment-time assertions cover:
   - protocol NFT token ID
   - fee-recipient Protocol NFT token ID
   - fee-recipient ownership sourced from `feeTo()`
   - fee-recipient unlock time equals DETF deployment timestamp
   - Bond NFT vault reward token equals the DETF token
- Keep rebasing-token wiring anchored to the DETF-owned protocol NFT as the source of protocol-owned reserve principal.

#### Slice 8: Focused tests
- Add or extend focused tests in this order:
   - Bond NFT vault component tests for both special NFTs and deterministic mint order
   - Bonding tests for `usageFeeOfVault(address(this))` share-skimming behavior
   - Mint preview tests for net-user output semantics
   - Mint execution tests for protocol-side DETF reward accrual and DETF-owned reserve-principal updates
   - Deploy-spec tests for the expanded package wiring

#### Slice 9: Validation order
- After the first substantive Bond NFT vault edit, run the narrowest Bond NFT and bonding specs.
- After the first substantive mint-path edit, run the narrowest composed-stable mint spec before widening scope.
- After package/deploy wiring changes, run the composed-stable deploy spec.
- Finish with the focused stable/common Foundry folder once all slices are in place.

### Refactor Acceptance Criteria
- New bonds deduct `usageFeeOfVault(address(this))` from gross shares before user-crediting.
- The deducted shares accrue to the fee-recipient Protocol NFT owned by `feeTo()`.
- The DETF-owned protocol NFT remains the source of protocol-owned reserve principal for rebasing-token valuation and redemption.
- Ordinary user mint previews return net user DETF, not gross DETF.
- Ordinary user mint execution both accrues protocol-side DETF rewards to the Bond NFT vault and adds reserve principal to the DETF-owned protocol NFT.

## Actors
- **Deployer:** User deploying a new DETF instance, specifying vaults and groupings
- **Liquidity Providers:** Users bonding initial and subsequent liquidity
- **End Users:** Holders of DETF tokens, interacting with the index

## Functional Requirements
1. **Vault Composition**
   - Accept 2–5 Standard Exchange vaults as input
   - Vaults and tokens are user-specified (not fixed)
   - User provides two groupings:
     - **Stable Grouping:** Each vault paired with a unique “stable” token
     - **Common Grouping:** All vaults paired with a single “common” token
   - User must specify which vault is paired with which token for both groupings

2. **Pool Structure**
   - For each grouping, deploy a Balancer V3 Stable Pool:
     - **Stable Pool:** Each vault rated as its unique stable token
     - **Common Pool:** Each vault rated as the common token
   - Deploy a Weighted Pool containing:
     - DETF token (60%)
     - Stable Pool BPT (20%)
     - Common Pool BPT (20%)
   - DETF contract holds only the Weighted Pool token

3. **Rate Providers**
   - DETF Package deploys 4–10 rate providers:
     - One for each vault in the Stable grouping (rated to the stable token)
     - One for each vault in the Common grouping (rated to the common token)
   - User must specify pairings for each vault

4. **Liquidity Routing**
   - When a user deposits a base token, the DETF must route the deposit into an underlying Standard Exchange vault, then into one of the two composed Stable Pools, and then deposit the resulting Stable Pool BPT into the Weighted Pool.
   - If the deposited base token is paired to exactly one configured Standard Exchange vault in the Stable Grouping, the deposit must be routed to that vault.
   - If the deposited base token is accepted by multiple configured Standard Exchange vaults, such as the shared common token, the deposit must be routed into the eligible vault whose rated liquidity is currently the lowest.
   - Rated liquidity must use Balancer V3 Vault live balance reads after decimal scaling and rate application.
   - After the underlying vault mints its vault token, the DETF must compare that vault token's rated liquidity in the Stable Pool and in the Common Pool.
   - The vault token must always be deposited into the pool where that vault currently has the least rated liquidity, even if there was only one eligible vault for the original base token.
   - After the vault token is deposited into the selected Stable Pool, the resulting Stable Pool BPT must be deposited into the Weighted Pool.

5. **Liquidity & Bonding**
   - Initial liquidity for pools is provided by the first user to bond
   - DETF uses protocol DETF’s seigniorage, bonding, NFT, and rebasing token logic
   - The bonding process itself should remain behaviorally unchanged from the existing Single Vault DETF flow.
    - Bonding should continue to: collect an accepted bond token, route into the canonical reserve-building path, receive reserve-pool BPT, and create a time-locked bond NFT position representing the bonded BPT shares.
   - Bonding must also preserve the vault-fee skim model for user-created bond positions:
      - when a user bonds and the route produces reserve-pool BPT shares, the DETF must query `usageFeeOfVault(address(this))` from the Vault Fee Oracle
      - that fee percentage must be deducted from the shares that would otherwise be credited to the user bond NFT
      - the deducted share amount must instead be credited to a dedicated fee-recipient NFT owned by `feeTo()` from the same Vault Fee Oracle
    - Accepted bond token behavior, lock-duration handling, seigniorage capture, NFT sale into protocol inventory, and donation flows should remain behaviorally compatible with the existing Single Vault DETF bonding surface.
   - This vault should reimplement the Bond NFT as a vault-specific NFT vault rather than reusing the generic Protocol NFT Vault package directly.
    - The replacement Bond NFT implementation must preserve compatibility with the current bonding target so the bonding flow can remain unchanged.
    - At minimum, the replacement Bond NFT must preserve the current `IProtocolNFTVault` callable surface and semantics used by bonding logic, including:
       - `createPosition(uint256 shares, uint256 lockDuration, address recipient)`
       - `initializeProtocolNFT()`
       - `addToProtocolNFT(uint256 tokenId, uint256 lpAmount)`
       - `sellPositionToProtocol(uint256 tokenId, address seller, address rewardsRecipient)`
       - `reallocateProtocolRewards(address recipient)`
       - `originalSharesOf(uint256 tokenId)` and `getPosition(uint256 tokenId)`
       - `redeemPosition(uint256 tokenId, address recipient, uint256 deadline)` and `claimRewards(uint256 tokenId, address recipient)`
    - The replacement Bond NFT must preserve the same accounting model:
       - each user NFT tracks original shares, effective shares, bonus multiplier, unlock time, and reward debt
       - the protocol-owned NFT accumulates principal shares from sold user NFTs
       - selling a user bond NFT into the protocol NFT must harvest pending rewards to the chosen recipient, move principal-only shares into the protocol NFT, and burn the sold user NFT
    - The replacement Bond NFT may change metadata, naming, token URI generation, and package composition, but must not change the economic semantics of bonding positions.
    - Routing decisions for deposits must be based on current rated liquidity at execution time.
    - "Rated liquidity" here means the Balancer live token balance after decimal scaling and rate application. The least-liquidity target must always be chosen using that post-rate balance, not the raw underlying token balance.
   - Minting must follow the existing Single Vault DETF behavior rather than a NAV-style `deposit value / mint price` formula.
    - The DETF mint threshold is a gating condition only. Minting is allowed only when the current reserve spot price is above the configured mint threshold, but the threshold does not directly determine the amount minted.
    - Once minting is allowed, the gross DETF output must be determined by Balancer weighted-pool quote math against the live Weighted Pool balances, using the routed Stable Pool BPT leg as the token-in side and the DETF token as the token-out side.
    - After the gross DETF mint amount is known, the mint flow must apply the same Protocol DETF-style split used by the other DETF families.
    - Concretely, the gross DETF quote is not the user payout. The user-facing mint result must be the post-split user allocation, and preview surfaces should report that net user amount rather than the gross pre-split amount.
    - The protocol-side portion of the split must not create a new user bond position. Instead, it must be handled the same way as Protocol DETF mint-side inventory incentives:
       - a protocol-owned reserve-principal increment is recorded by adding the newly minted reserve-pool BPT from the mint route into the protocol-owned Bond NFT position
       - the protocol-side DETF mint slice is minted to the fresh Bond NFT vault itself as reward-token accrual inventory
    - The protocol-side DETF slice therefore belongs to the Bond NFT vault reward-accounting model, not to a newly created or separately locked Bond NFT position.
    - The PRD requirement above is separate from the seigniorage input boost. The user-facing quote should still be based on the boosted Stable Pool BPT input, but the final state-mutating mint flow must also perform the post-quote user/protocol split and protocol-owned reserve update that existing DETFs already apply.
    - If the reserve weighted pool is not initialized, mint attempts must revert with the reserve-pool initialization error instead of falling back to bootstrap mint math.
   - The seigniorage incentive used by the Single Vault DETF must also apply here.
   - The incentive must be applied by boosting the routed Stable Pool BPT input before the DETF mint quote is computed:
     `boostedStablePoolBptIn = stablePoolBptIn + stablePoolBptIn * seigniorageIncentivePercentageOfVault(address(this))`.
   - The DETF mint quote must use `boostedStablePoolBptIn` as the token-in amount against the live Weighted Pool balances.
    - This incentive must follow Single Vault DETF semantics exactly: boost the effective input before quoting DETF out. That boost step must not be conflated with the separate protocol-side DETF allocation, which still needs to happen after mint sizing is known.

6. **Validation & Safety**
   - Package validates groupings and pairings
   - Ensures vaults’ tokens() match groupings
   - Ensures Stable Grouping pairings are unique and Common Grouping uses the shared common token consistently
   - Uses Balancer V3 Vault reads as the canonical source for live rated liquidity
   - Does not handle initial liquidity provisioning

## Bond NFT Vault Definition

### Fresh Implementation Constraint
- `ComposedStableCommonDetfBondNFTVault` must be implemented as a fresh vault-family-specific contract set.
- It must not inherit from, alias, or simply wrap the existing protocol-generic Bond NFT vault implementation as its primary implementation.
- The existing Protocol NFT vault may be used as a semantic reference only.
- Reuse of shared framework primitives from Crane and generic standards facets is allowed, but DETF-family-specific business logic must live in the new composed stable implementation.

### Canonical Name
- The vault-specific bond NFT implementation should be named `ComposedStableCommonDetfBondNFTVault`.
- Its package should be named `ComposedStableCommonDetfBondNFTVaultDFPkg`.
- It should remain a dedicated vault owned by the composed stable DETF instance, not a shared system-wide NFT vault.

### Purpose
- `ComposedStableCommonDetfBondNFTVault` is the canonical ledger for bonded positions in a single composed stable DETF instance.
- Each NFT represents a time-locked claim on reserve shares contributed through the DETF bonding flow.
- The vault exists only to track, reward, transfer, redeem, and protocol-internalize bonded reserve exposure; it does not decide routing, pool composition, mint quoting, or seigniorage policy.
- In addition to ordinary user bond NFTs and the protocol-owned NFT, the vault must also maintain a dedicated fee-recipient NFT that accumulates usage-fee shares skimmed from newly created user bond positions.

### Owned Assets And Reward Token
- `lpToken` for this vault must be the composed stable DETF reserve token, meaning the final reserve-pool BPT produced by the unchanged bonding path.
- Because this DETF holds only the Weighted Pool token at the top level, the expected bonded asset is the Weighted Pool BPT held as reserve inventory by the DETF.
- `rewardToken` must be the DETF token for this vault family so the protocol-side DETF mint slice can accrue through the Bond NFT vault's existing reward-accounting surface.
- The composed stable DETF should not introduce a second mint-side reward asset for this flow. The Bond NFT vault reward inventory for mint-side incentives is the protocol-side DETF allocation itself.

### Ownership And Trust Model
- The composed stable DETF proxy must own the Bond NFT vault.
- Only the composed stable DETF may:
  - create bond positions
  - initialize the protocol-owned NFT
   - initialize the fee-recipient NFT
  - add shares to the protocol-owned NFT
  - sell user positions into the protocol-owned NFT path
  - mark the protocol-owned NFT as sold, if that flow remains enabled
  - reallocate protocol rewards
- End users may only hold, transfer subject to guard rules, claim rewards for, and redeem their own unlocked bond NFTs.
- The fee-recipient NFT must be minted to `feeTo()` from the Vault Fee Oracle and should not be user-selectable by callers during bonding.

### External Interface Requirement
- `ComposedStableCommonDetfBondNFTVault` must implement `IProtocolNFTVault` so the existing bonding target can call it without requiring a new bond-flow interface.
- The following methods are mandatory and must preserve current semantics:
  - `createPosition(uint256 shares, uint256 lockDuration, address recipient)`
  - `initializeProtocolNFT()`
  - `redeemPosition(uint256 tokenId, address recipient, uint256 deadline)`
  - `claimRewards(uint256 tokenId, address recipient)`
  - `sellPositionToProtocol(uint256 tokenId, address seller, address rewardsRecipient)`
  - `addToProtocolNFT(uint256 tokenId, uint256 lpAmount)`
  - `markProtocolNFTSold(uint256 tokenId)`
  - `reallocateProtocolRewards(address recipient)`
  - all current read methods for position, share, unlock, pending reward, and conversion state

### Position Accounting Model
- Each tokenId must store the same logical fields as the current `IProtocolNFTVault.Position` model:
  - `originalShares`
  - `effectiveShares`
  - `bonusMultiplier`
  - `unlockTime`
  - `rewardDebt`
- `originalShares` represent the principal reserve shares bonded by the user.
- `effectiveShares` represent reward-accrual weight after lock-duration bonus is applied.
- `bonusMultiplier` must be derived from lock duration using the same bonus schedule semantics as the current bond NFT vault unless explicitly changed later in the PRD.
- `rewardDebt` must support accumulated-per-share accounting so claiming and redemption do not double-count rewards.
- For ordinary user bond creation, the shares entered into this accounting model are the post-fee shares after deducting `usageFeeOfVault(address(this))` from the gross shares produced by the bond route.
- The deducted fee shares must be recorded as additional shares on the dedicated fee-recipient NFT rather than being burned, ignored, or routed into the protocol-owned NFT.

### Protocol-Owned NFT Model
- The vault must mint exactly one protocol-owned NFT and record its tokenId.
- The special-position mint order must be deterministic: the DETF-owned protocol NFT is minted first.
- The protocol-owned NFT has no user redemption lifecycle and exists to aggregate protocol-controlled principal from:
  - sold user bond NFTs
  - protocol-side seigniorage capture converted into reserve shares
  - protocol donations routed into reserve shares
- Adding reserve shares to the protocol-owned NFT must increase its principal position without resetting unrelated user positions.

### Fee-Recipient NFT Model
- The vault must also mint exactly one dedicated fee-recipient NFT and record its tokenId separately from the protocol-owned NFT.
- The fee-recipient Protocol NFT is minted after the DETF-owned protocol NFT so deployment-time token IDs remain deterministic.
- The fee-recipient NFT must be minted during deployment or initialization to `feeTo()` from the Vault Fee Oracle.
- The unlock time for the fee-recipient NFT must be the DETF deployment timestamp.
- The fee-recipient NFT exists to accumulate the usage-fee share skim from newly created user bond positions.
- Fee-recipient shares are principal shares owned by the `feeTo()` recipient and must not be silently merged into the protocol-owned NFT.
- Adding fee shares to the fee-recipient NFT must increase its position without resetting unrelated user or protocol positions.

### Lifecycle Requirements
1. Bond creation:
   - the DETF completes its normal bond route and obtains reserve-pool BPT
   - the DETF computes the vault-fee skim using `usageFeeOfVault(address(this))` from the Vault Fee Oracle
   - the fee percentage is applied to the gross shares produced by the bond route
   - the vault credits the net shares to the user NFT position and credits the deducted fee shares to the dedicated fee-recipient NFT
   - the vault mints a new NFT to the recipient for the net user shares and records principal, boosted effective shares, unlock time, and reward debt
2. Reward accrual:
   - rewards accumulate against effective shares using global reward-per-share accounting
   - users may claim rewards without redeeming principal
   - protocol-side DETF minted during ordinary user minting accrues through this same reward-token accounting surface after being minted to the Bond NFT vault
3. Redemption:
   - only the owner or approved caller for a user NFT may redeem
   - redemption is allowed only after unlock time
   - pending rewards are harvested first
   - the vault burns the NFT and instructs the owning DETF to unwind the reserve shares into the canonical redemption asset path
4. Sale to protocol:
   - pending rewards are harvested to the chosen recipient
   - only principal shares move into the protocol-owned NFT
   - the sold user NFT is burned
5. Protocol reallocation:
   - protocol-owned rewards may be reallocated out to the DETF for seigniorage capture without mutating user principal positions

### Transfer And Approval Rules
- The vault should preserve guarded ERC721 transfer semantics used by the current Protocol NFT vault package.
- In particular, transfers that would incorrectly send bond NFTs into the owning DETF or otherwise break redemption assumptions should remain blocked at the facet/package layer.
- Standard user-to-user NFT transfers may remain enabled only if they preserve ownership-based claim and redemption semantics without introducing protocol-accounting ambiguity.

### Deployment Definition
- `ComposedStableCommonDetfBondNFTVaultDFPkg` should follow the current Diamond Factory Package pattern used by `ProtocolNFTVaultDFPkg`.
- The package should initialize at minimum:
  - ERC721 metadata name and symbol
  - owner as the composed stable DETF proxy
  - `lpToken` as the reserve-pool BPT token for this DETF instance
  - `rewardToken` as the configured reward asset for this DETF instance
  - decimal offset/share math configuration
   - bond NFT specific storage for position accounting, protocol NFT bookkeeping, and fee-recipient NFT bookkeeping
   - the deployment-time fee-recipient address sourced from `feeTo()` on the Vault Fee Oracle
   - the deployment-time usage-fee basis sourced from `usageFeeOfVault(address(this))` semantics for later bond creation
- During deployment or first initialization, the package must mint both special positions:
   - the DETF-owned protocol NFT first
   - the dedicated fee-recipient Protocol NFT second, minted to `feeTo()` from the Vault Fee Oracle with unlock time equal to the DETF deployment timestamp
- The package should expose the same guarded transfer selector overrides currently used by the generic Protocol NFT vault package.

### What Is Allowed To Differ From The Generic Protocol NFT Vault
- collection name and symbol
- token URI artwork and metadata schema
- package/facet names
- storage slot namespace
- event names, if they remain semantically equivalent and the DETF integration does not depend on the old names

### What Must Not Differ
- bond creation semantics
- reward accounting semantics
- lock/unlock semantics
- fee-recipient share-skimming semantics for newly created bond positions
- sell-to-protocol semantics
- protocol-owned NFT aggregation semantics
- redemption semantics from the perspective of the owning DETF and end user

## Rebasing Token Definition

### Core Approach
- The composed stable DETF should reimplement the current `RICHIR` design as a vault-family-specific rebasing token named `RebasingDETFToken`.
- Concretely, each composed stable DETF instance should deploy its own dedicated `RebasingDETFToken` implementation using the same shares-based rebasing model, with valuation sourced from the composed stable DETF's own reserve and redemption path.
- This means the implementation plan is to preserve the current rebasing mechanics while reimplementing the token under DETF-specific naming and DETF-specific reserve-pricing logic.

### Fresh Implementation Constraint
- `RebasingDETFToken` must be a fresh implementation for this DETF family.
- It must not be implemented by directly reusing the existing `RICHIR` contract, package, or DETF-specific helper contracts from other vault families.
- Existing DETF rebasing tokens may be used as behavioral references for parity where the PRD explicitly calls for parity, but this vault family should own its own codepath and package wiring.
- Reuse of generic Crane ERC20, permit, and framework primitives is allowed; reuse of other DETF-family business-logic contracts is not part of this plan.

### Canonical Contract Shape
- The rebasing token contract should be named `RebasingDETFToken`.
- The package should be named `RebasingDETFTokenDFPkg`.
- The first implementation should remain `IRebasingClaimToken` compatible at the callable-surface level unless we later decide to introduce a dedicated `IRebasingDETFToken` alias.
- The initial goal is to reimplement the token with new naming, not to change its external rebasing semantics.
- The DETF should also expose a dedicated ETH-pricing interface for rebasing support so the rebasing token does not own pool-decomposition logic directly.
- The canonical DETF-side pricing interface should be named `IDETF`.
- The canonical DETF-side implementation facet should be named `RebasingDETFTokenPricingFacet`.
- `RebasingDETFToken` should depend on `IDETF` for reserve-to-WETH valuation rather than implementing reserve decomposition and ETH-pricing logic internally.

### DETF Pricing Interface
- `IDETF` should live with the DETF-side interfaces, not inside the rebasing token package.
- The purpose of this interface is to keep pricing logic coupled to the DETF implementation that knows the reserve composition, Stable Pool integration, Common Pool integration, and endogenous DETF pricing rules.
- `IDETF` should be the canonical DETF-family interface that the composed stable DETF proxy exposes for rebasing-aware pricing queries.
- At minimum, the interface should expose a canonical rebasing valuation entrypoint:
   - `previewRebasingDetfTokenEthValue(uint256 reserveBptAmount) external view returns (uint256 wethValue)`
- The interface may also expose lower-level helpers if useful for testing and query UX, but the rebasing token should only need one canonical aggregate pricing call.
- Optional DETF-side helper methods that may be exposed for diagnostics and tests:
   - `previewStablePoolBptEthValue(uint256 stablePoolBptAmount) external view returns (uint256 wethValue)`
   - `previewCommonPoolBptEthValue(uint256 commonPoolBptAmount) external view returns (uint256 wethValue)`
   - `syntheticDetfEthPrice() external view returns (uint256 wethPerDetf)`
   - `previewReservePoolDecomposition(uint256 reserveBptAmount) external view returns (uint256 detfAmount, uint256 stablePoolBptAmount, uint256 commonPoolBptAmount)`
- These helper functions are optional from the rebasing token's perspective but recommended for implementation clarity and testing.

### Why Reimplement From `RICHIR`
- The current `RICHIR` implementation is already structured around generic inputs:
   - owning DETF address
   - bond NFT vault address
   - WETH token
   - protocol-owned NFT tokenId
- The current redemption-rate calculation already asks the DETF to preview the WETH value of reserve BPT through `previewExchangeIn(...)`, which is the correct abstraction boundary for the composed stable DETF as well.
- Because of that, the composed stable DETF does not need a new rebasing share model; it needs a dedicated `RebasingDETFToken` implementation against its own reserve stack.
- This section is a behavioral justification only. It should not be interpreted as permission to reuse the existing `RICHIR` implementation directly.

### Supply Model
- The token must remain a true rebasing ERC20 backed by constant internal shares.
- User balances must not be stored as fixed ERC20 balances.
- Instead:
   - `sharesOf[user]` changes only on mint, burn, and transfer
   - `totalShares` changes only on mint and burn
   - `balanceOf(user)` is computed live from `sharesOf(user) * redemptionRate`
   - `totalSupply()` is computed live from `totalShares * redemptionRate`
- This preserves the current economic model where the apparent token balance floats as the protocol-owned reserve claim changes in value.

### Minting Model
- Rebasing tokens should be minted only when reserve principal is moved into the protocol-owned Bond NFT position through the canonical Bond NFT sale path.
- The mint source of truth remains principal reserve shares, not spot NAV and not a separate treasury accounting ledger.
- The canonical mint path remains:
   - user sells bond NFT into protocol-owned NFT
   - protocol-owned NFT receives principal shares
   - rebasing token mints matching internal shares to the recipient
- The first implementation should preserve the current one-share-per-reserve-share minting model used by `mintFromNFTSale(...)`.

### Redemption Rate Source
- The redemption rate must be computed from the current WETH redemption value of the protocol-owned Bond NFT principal position.
- The source of truth should be:
   - read `originalShares` from the protocol-owned Bond NFT position
   - treat those shares as reserve-pool BPT held on behalf of rebasing token holders
- `RebasingDETFToken` should call `IDETF(address(detf)).previewRebasingDetfTokenEthValue(protocolNftReserveBpt)` to obtain the WETH value of the protocol-owned reserve position.
- The implementation should continue to use the DETF as the valuation oracle boundary, and the three-token reserve pricing logic should live inside `RebasingDETFTokenPricingFacet` rather than inside the rebasing token.
- Inside the DETF pricing facet, the pricing path must be augmented for the three-token reserve structure instead of relying on a naive one-hop `reserveBpt -> WETH` quote.
- Concretely, DETF-side rebasing pricing should use a reserve decomposition model:
   - `protocolOwnedDetf = reserveDetfBalance * protocolNftReserveBpt / reservePoolTotalSupply`
   - `protocolOwnedStableBpt = reserveStableBptBalance * protocolNftReserveBpt / reservePoolTotalSupply`
   - `protocolOwnedCommonBpt = reserveCommonBptBalance * protocolNftReserveBpt / reservePoolTotalSupply`
- The Stable Pool BPT leg must be explicitly repriced into WETH inside the DETF pricing facet using the composed stable DETF's canonical exit preview path for Stable Pool BPT.
- The Common Pool BPT leg must be valued in WETH inside the DETF pricing facet using the composed stable DETF's canonical exit preview path for Common Pool BPT.
- The DETF leg must not be valued by recursively calling the same reserve-BPT redemption path. That would double count the self-referential DETF inventory inside the reserve pool.
- Instead, the DETF pricing facet must value the DETF leg with a synthetic DETF price solved from the external reserve backing.
- The planned DETF-side synthetic DETF price formula is:
   - `syntheticDetfPrice = (stableLegValueInWeth + commonLegValueInWeth) / (detfTotalSupply - reserveOwnedDetf)`
- Here `reserveOwnedDetf` means the amount of DETF token owned by the reserve inventory being used as backing for the DETF supply.
- This fixed-point style formulation is the augmentation required by the three-token reserve: it removes circular self-valuation and prices only the externally redeemable part of the reserve directly.
- Once `syntheticDetfPrice` is known inside the DETF pricing facet, the protocol-owned reserve position value is:
   - `protocolNftValueInWeth = protocolOwnedStableBptValueInWeth + protocolOwnedCommonBptValueInWeth + protocolOwnedDetf * syntheticDetfPrice`
- The rebasing token redemption rate is then:
   - `redemptionRate = protocolNftValueInWeth / totalRebasingShares`
- If no shares exist, or if the protocol-owned NFT position is empty, the rate should default to `1e18` exactly as current `RICHIR` does.

### Three-Token Reserve Pricing Rationale
- The reserve pool for this DETF is not a two-token reserve; it contains:
   - DETF token
   - Stable Pool BPT
   - Common Pool BPT
- The Stable Pool BPT and Common Pool BPT legs are externally priced legs because they can be unwound into underlying assets and then repriced into WETH through canonical preview routes.
- The DETF leg is an endogenous leg because it is the protocol's own synthetic asset sitting inside its own reserve structure.
- That endogenous DETF leg is why the current rebasing pricing must be augmented for this vault family.
- The correct implementation is therefore:
   - decompose reserve BPT into all three pool legs inside the DETF pricing facet
   - price the two external legs directly in WETH inside the DETF pricing facet
   - price the DETF leg using the synthetic-price equation above inside the DETF pricing facet
   - return the aggregate WETH value to `RebasingDETFToken`
   - let `RebasingDETFToken` derive only the rebasing rate from that returned value
- This is the main pricing difference between `RICHIR` on the simpler reserve structure and `RebasingDETFToken` on the composed stable DETF reserve structure.

### Redemption Flow
- The composed stable DETF should own the full redemption unwind path.
- The rebasing token should support the same two current modes:
   - direct `redeem(...)` for a self-contained path when appropriate
   - `burnShares(...)` so the DETF can orchestrate the unwind externally
- For the composed stable DETF implementation, the preferred path is to keep the DETF responsible for the actual reserve exit and WETH payout, and use `burnShares(...)` as the accounting primitive when the DETF executes redemption.
- This keeps reserve-unwind logic centralized in the DETF, where the composed stable routing and exit semantics already belong.

### Transfer Semantics
- ERC20 transfers must continue to move internal shares, not fixed token balances.
- Transfer amounts presented by users in rebasing-token units must be converted to shares using the current redemption rate at execution time.
- This means ordinary ERC20 transfer UX remains intact while preserving the rebasing share ledger.

### Safety And Composability Restrictions
- The token should preserve the same intentional non-composability assumptions as `RICHIR`.
- It should be treated as a redemption-claim asset, not as a normal DeFi primitive.
- The PRD should assume the same restrictions remain in force:
   - not intended for AMM pools
   - not intended for lending markets
   - not intended for vault strategies that assume stable `balanceOf()` behavior
- If transfer restrictions are enforced in the current DETF stack, the composed stable version should preserve those restrictions.

### Deployment Wiring
- Each composed stable DETF instance should deploy exactly one dedicated rebasing token instance.
- Initialization inputs should mirror the current `RebasingClaimTokenDFPkg.PkgArgs` shape, but for `RebasingDETFTokenDFPkg`:
   - owning composed stable DETF proxy
   - composed stable Bond NFT vault
   - WETH token
   - protocol-owned NFT tokenId
   - owner address set to the DETF proxy
- This should be deployed as part of the DETF package initialization sequence after the Bond NFT vault exists and after the protocol-owned NFT tokenId is known.

### Planned Implementation Delta Versus Existing `RICHIR`
- Keep behaviorally unchanged:
   - `IRebasingClaimToken`-compatible interface semantics
   - shares-based accounting model
   - mint-from-NFT-sale semantics
   - redemption-rate caching strategy
   - EIP-2612 / EIP-712 support
- Adapt only as needed:
   - contract name to `RebasingDETFToken`
   - package name to `RebasingDETFTokenDFPkg`
   - initialization wiring to the composed stable DETF and its Bond NFT vault
   - a new DETF-side `IDETF` pricing surface and `RebasingDETFTokenPricingFacet`
   - redemption-rate calculation so the rebasing token calls the DETF pricing facet, the Stable Pool BPT leg is explicitly repriced into WETH there, and the endogenous DETF leg is solved from the synthetic-price equation there
   - redemption execution path so the composed stable DETF unwinds its own reserve structure
- Do not add a second rebasing share model unless the composed stable reserve stack proves incompatible with the current `RICHIR`-style accounting architecture.
- This delta is behavioral, not inheritance-based. The implementation should be fresh code for this vault family even where it preserves the same external semantics.

## Test Strategy

### Testing Goals
- The primary goal is to prove that the fresh composed-stable implementation matches the approved behavior without inheriting hidden assumptions from other DETF families.
- The test suite should prioritize correctness of routing, minting, bonding, reserve pricing, and redemption before gas tuning or broad fuzzing.
- The suite should fail on economic regressions first and interface regressions second.

### Testing Layers
- The strategy should use four layers of confidence, added in order:
   - deterministic deployment and unit-style query tests
   - stateful integration tests over a fully deployed composed-stable instance
   - fuzz and invariant coverage for core accounting properties
   - optional higher-fidelity environment tests only after the deterministic suite is stable
- The first implementation milestone should not start with fork-style or multi-protocol realism tests. It should start with deterministic local composition tests that isolate the new codepath.

### Deployment Factory Service Pattern
- This vault family should have the usual deployment helpers used elsewhere in the repo rather than ad hoc deployment code embedded directly in tests.
- At minimum, define a fresh composed-stable component builder library named `ComposedStableCommonDetf_Component_FactoryService`.
- Its role should be the same as other deployment helper libraries in the repo:
   - collect freshly deployed facets into typed structs
   - collect external infrastructure and package dependencies into typed structs
   - build canonical `PkgInit` values for the composed stable DETF package
   - build canonical `PkgArgs` values for concrete test and deployment instances
- If the implementation is split the same way as other vault families, also add:
   - `ComposedStableCommonDetf_Facet_FactoryService`
   - `ComposedStableCommonDetf_Pkg_FactoryService`
- These factory-service helpers must be fresh for this vault family and must not simply reuse another DETF family's component or package factory-service library.
- Shared Crane deployment primitives and generic vault component deployment helpers may still be reused where they are not DETF-family-specific.

### TestBase Architecture
- The test plan should use a dedicated inherited base contract rather than monolithic per-spec setup.
- The canonical root base should be named `TestBase_ComposedStableCommonDetf`.
- `TestBase_ComposedStableCommonDetf` should inherit existing upstream test bases as needed instead of copying their setup inline.
- The intended inheritance style is:
   - inherit `IndexedexTest` transitively for CREATE3 and core factory infrastructure
   - inherit `TestBase_VaultComponents` for generic vault facet deployment
   - inherit Balancer V3 test infrastructure as needed for Stable Pool, Weighted Pool, and Vault behavior
   - inherit protocol-specific Standard Exchange test bases only where a spec actually needs that protocol's local stub or pool setup
- In practice, this means the composed stable DETF test stack should prefer small layered bases over a single giant setup contract.

### Recommended TestBase Split
- Use one root deployment-oriented base plus smaller specialized child bases.
- Recommended structure:
   - `TestBase_ComposedStableCommonDetf_Components`
      - deploys fresh composed-stable facets, package dependencies, Bond NFT package, rebasing token package, and rate-provider packages
      - uses `ComposedStableCommonDetf_Component_FactoryService` to build deployment inputs
   - `TestBase_ComposedStableCommonDetf_Balancer`
      - inherits Balancer V3 pool and vault setup needed for the Stable Pool, Common Pool, and Weighted Pool legs
   - `TestBase_ComposedStableCommonDetf`
      - composes the prior bases
      - deploys a full composed stable DETF test instance
      - exposes helper methods for mint, bond, redeem, pricing, routing, and reserve assertions
- If protocol-specific Standard Exchange stubs are needed for a given spec family, add child bases such as `TestBase_ComposedStableCommonDetf_Aerodrome` or similar rather than forcing all protocol setup into the root base.

### Spec Layout
- Test infrastructure should live with the contracts under `contracts/vaults/detf/composed/stable/common/` following repo conventions.
- Foundry spec files should live under a mirrored path in `test/foundry/spec/`.
- The first test files should be organized by behavior slice, not one giant end-to-end file.
- Expected initial spec groups:
   - deployment and package wiring
   - liquidity routing
   - mint quoting and seigniorage incentive application
   - bonding and Bond NFT integration
   - rebasing pricing and redemption-rate computation
   - redemption and reserve unwind behavior

### Phase Plan
- Phase 1: deployment and wiring
   - validate fresh package composition
   - validate facet registration and callable query surfaces
   - validate DETF, Bond NFT, and rebasing token deployment relationships
- Phase 2: deterministic query and routing behavior
   - validate route selection from live rated-liquidity reads
   - validate preview-style pricing and decomposition paths
   - validate tie-break behavior once defined
- Phase 3: stateful mint, bond, and redeem behavior
   - validate actual asset movement across Standard Exchange vaults, Stable Pool, Common Pool, and Weighted Pool
   - validate bond-NFT issuance and protocol-owned NFT accumulation
   - validate rebasing-rate movement after protocol-owned reserve changes
- Phase 4: fuzz and invariant coverage
   - validate accounting bounds and conservation-style properties under broader input ranges
   - validate quote/execution consistency where exact match is intended

### Unit Versus Integration Boundary
- Unit-style tests should focus on pure and view-heavy logic exposed through the fresh composed-stable codepath.
- These tests should cover:
   - reserve decomposition math
   - synthetic DETF price calculation
   - preview routing decisions
   - mint quote construction and seigniorage boost application
- Integration tests should cover full state transitions:
   - deposit token to vault to composed pool to weighted pool to DETF mint
   - bond token to reserve position to Bond NFT mint
   - Bond NFT sale to protocol to rebasing token mint
   - rebasing token redemption to reserve unwind and payout
- The strategy should avoid over-mocking business logic owned by the composed-stable contracts. Mock only external protocol mechanics when determinism or setup cost requires it.

### Fixture Strategy
- Tests should use deterministic local fixtures assembled by the fresh factory-service helpers.
- The preferred fixture model is:
   - deploy fresh facets and packages through CREATE3-backed test infrastructure
   - deploy local Standard Exchange vault instances needed for the composed stable grouping
   - deploy the Stable Pool, Common Pool, and Weighted Pool in the test environment
   - seed balances explicitly and assert expected liquidity states before each behavior test
- Fixtures should be small and purpose-built. Do not rely on a single giant fixture for every spec.
- Each spec family should set up only the minimum pools, tokens, and vaults needed to exercise that slice.

### Assertion Strategy
- Query tests should assert both returned values and the intermediate economic interpretation when the math is non-trivial.
- For routing and pricing assertions, tests should prefer exact expected values when the setup is deterministic.
- Where Balancer math or rate scaling introduces rounding, assertions should document the tolerated direction and bound of rounding.
- For stateful flows, every test should assert both:
   - the user-visible output
   - the reserve/accounting deltas across DETF, pools, Bond NFT vault, and rebasing token

### Invariant Candidates
- After deterministic integration tests are stable, add invariant coverage for the fresh composed-stable implementation.
- Initial invariant targets should include:
   - protocol-owned NFT principal is never less than the sum of shares sold into it minus shares explicitly redeemed or unwound
   - rebasing-token total shares only change on mint and burn paths
   - rebasing-token redemption rate is never computed from recursive self-valuation of reserve-owned DETF
   - reserve decomposition outputs never exceed the underlying reserve balances for the queried BPT proportion
   - mint-threshold and burn-threshold gates do not alter quote math directly; they only gate path availability

### Regression Focus Areas
- The highest-risk regressions for this vault family are:
   - routing to the wrong vault when the common token is shared across multiple vaults
   - routing to the wrong composed pool after the vault token is minted
   - double counting reserve-owned DETF during rebasing valuation
   - preserving bonding semantics while using a fresh Bond NFT implementation
   - preserving rebasing semantics while using a fresh token implementation and DETF-side pricing facet
- The suite should be organized so these regressions are covered by narrow tests before broad end-to-end scenarios.

### Exit Criteria For Initial Test Coverage
- The initial implementation should not be considered ready until all of the following are covered by executable tests:
   - package wiring and deployment succeeds through the fresh factory-service path
   - all canonical query surfaces return non-zero or structurally valid values after setup
   - exact-match routing and lowest-liquidity routing both behave as specified
   - DETF minting applies threshold gating and seigniorage boost exactly as specified
   - Bond NFT mint, claim, sell-to-protocol, and redeem flows preserve approved semantics
   - rebasing rate updates correctly from DETF-side `IDETF` pricing and reserve decomposition
   - redemption unwinds through the DETF-owned path rather than bypassing the composed-stable implementation

### Required Coverage
- Deployment tests must validate that the composed stable package wires only fresh composed-stable business logic components.
- Factory-service tests must validate that `PkgInit` and `PkgArgs` assembly is correct and deterministic for the intended deployment inputs.
- Routing tests must validate:
   - exact-match stable-token routing
   - shared common-token routing to the lowest-rated-liquidity eligible vault
   - post-vault pool selection to the lowest-rated-liquidity pool for that vault token
- Mint tests must validate:
   - mint-threshold gating only
   - weighted-pool quote semantics
   - reserve-pool initialization revert behavior
   - seigniorage boost application before quoting DETF out
   - preview/user quote semantics return the post-split user allocation rather than the gross pre-split DETF amount
   - ordinary user minting increases protocol-owned Bond NFT principal by the reserve-pool BPT created during the mint route
   - ordinary user minting mints the protocol-side DETF slice to the Bond NFT vault reward inventory rather than creating a new Bond NFT position
- Bonding tests must validate behavioral parity with the approved bonding flow while using the fresh composed-stable Bond NFT implementation.
- Bonding tests must also validate the fee-recipient NFT flow:
   - deployment mints the dedicated fee-recipient NFT to `feeTo()` from the Vault Fee Oracle
   - the fee-recipient NFT unlock time equals the DETF deployment timestamp
   - `usageFeeOfVault(address(this))` is deducted from gross bond shares before user-crediting
   - the deducted shares are credited to the fee-recipient NFT rather than to the user NFT or the protocol-owned NFT
- Rebasing tests must validate:
   - fresh `RebasingDETFToken` deployment
   - `IDETF` pricing entrypoint usage
   - reserve decomposition into DETF plus Stable Pool BPT plus Common Pool BPT
   - synthetic DETF pricing without recursive self-valuation
   - redemption-rate updates from protocol-owned NFT principal

### Test Philosophy
- Existing DETF tests are references for expected behavior only.
- New tests for this vault family should target the fresh composed-stable codepath directly and should not rely on another DETF family's contract under test.
- The preferred progression is:
   - deployment and wiring tests first
   - query and routing tests second
   - state-mutating mint, bond, and redeem tests third
   - invariant or fuzz coverage after the core deterministic behavior is stable

## Cross-DETF Refactor Findings

### Summary
- A cross-DETF comparison was performed against the current Stable DETF, Single Vault DETF, and Protocol DETF implementations.
- The result is that the composed-stable family does share meaningful architectural patterns with the other DETF families, but most remaining overlap is at the workflow and math-helper level rather than at the concrete contract level.
- This confirms the existing PRD direction: the composed-stable family should remain a fresh implementation and should not be collapsed into another DETF family's concrete codepath.

### Safe Reuse Boundaries
- The composed-stable family may safely reuse generic Crane and IndexedEx primitives that are not DETF-family-specific, including:
   - generic Balancer quote helpers and fixed-point math
   - generic threshold-policy helpers
   - generic fee-splitting and accounting libraries where the economic semantics are identical
   - generic deployment, factory, package, and ERC standard infrastructure
- The composed-stable family may also adopt the same workflow shape used in other DETFs where the behavior matches, for example:
   - route user input into reserve-building inventory
   - apply reserve-pool quote math and threshold gating
   - split user versus protocol output after gross quote sizing
   - keep preview and execution paths paired and behaviorally aligned

### Unsafe Reuse Boundaries
- The composed-stable family should not reuse another DETF family's concrete implementation contracts for any of the following surfaces, even if the file structure or function naming looks similar:
   - synthetic price calculation
   - reserve-pool composition and decomposition
   - top-level mint orchestration
   - top-level unwind orchestration
   - bond NFT vault business logic
   - rebasing-token pricing and redemption orchestration
   - bridge-aware or protocol-NFT-specific reserve compensation logic from Protocol DETF
- These surfaces are only superficially similar across DETF families. Their accounting invariants differ materially because the composed-stable reserve graph contains DETF token plus Stable Pool BPT plus Common Pool BPT, while the Single Vault and Protocol DETFs use different reserve assets and different unwind graphs.

### Concrete Comparison Outcome
- Stable DETF and composed-stable DETF share the strongest conceptual overlap in route selection and pool-leg selection, but composed-stable still needs its own reserve-owned unwind and pricing graph because it owns two composed pool legs plus the top-level reserve pool.
- Single Vault DETF and composed-stable DETF share the clearest economic overlap in threshold-gated minting, post-quote user/protocol split semantics, and reserve-principal updates, but they do not share the same reserve inventory or redemption graph.
- Protocol DETF and composed-stable DETF share the most obvious query-surface pattern for preview/execution parity, protocol-owned reserve accounting, and threshold-gated views, but Protocol DETF includes bridge and RICHIR-specific logic that should not be generalized into this family.

### Implementation Guidance From This Comparison
- If additional consolidation is pursued during implementation, it should target only low-level, policy-free helpers.
- The best candidates for future shared extraction are:
   - Balancer live-balance normalization and rate-application helpers
   - low-level reserve-pool quote wrappers
   - preview/execution consistency helpers that do not encode family-specific token semantics
   - threshold-gating view plumbing where the logic is truly identical
- The composed-stable DETF should continue to own its family-specific orchestration for:
   - routing through underlying Standard Exchange vaults
   - selecting Stable Pool versus Common Pool legs
   - reserve-owned mint and unwind execution
   - Bond NFT fee-skimming and protocol-NFT flows
   - rebasing-token redemption-value construction

### Future Shared-Library Candidates Checklist
- [ ] Evaluate whether Balancer live-balance normalization plus rate-application can be extracted into a DETF-agnostic helper without importing family-specific storage or token assumptions.
- [ ] Evaluate whether single-token reserve-pool quote wrappers can be shared across DETF families while keeping family-specific routing and accounting outside the helper.
- [ ] Evaluate whether preview/execution consistency helpers can be shared for paired quote/execution surfaces without coupling to composed-stable token semantics.
- [ ] Evaluate whether threshold-gating view plumbing can be shared wherever the implementation is identical and the only family-specific input is the computed synthetic price.
- [ ] Reject any proposed shared extraction that pulls in family-specific reserve decomposition, bond NFT accounting, rebasing-token pricing, or protocol-owned reserve orchestration.
- [ ] Require focused behavior tests around every future shared extraction so parity is proven locally before widening to broader DETF suites.

### Product Decision
- The composed-stable family remains a fresh DETF-family codepath.
- Cross-DETF comparison should be used to identify safe helper-level reuse and test parity expectations, not to justify reusing another family's concrete implementation contracts.

## Non-Functional Requirements
- Modular, upgradeable contracts (Diamond Pattern)
- Deterministic deployment via CREATE3
- Follows IndexedEx and Crane code style and test patterns
- Gas-efficient and secure
- DETF-family-specific logic for this vault must live in fresh composed-stable contracts rather than being imported or repackaged from existing DETF implementations.

## Out of Scope
- Automatic liquidity provisioning
- Hardcoded token lists (all tokens and vaults are user-specified)
- Governance or fee logic beyond protocol DETF

## Example Flow
1. User selects 4 vaults (e.g., WETH/DAI, WETH/USDC, WETH/USDT, WETH/PYUSD)
2. User specifies:
   - Stable Grouping: DAI, USDC, USDT, PYUSD
   - Common Grouping: WETH
   - Pairings for each vault
3. Package deploys:
   - 4 Standard Exchange vaults
   - 4 Stable Pool rate providers (rated to DAI, USDC, USDT, PYUSD)
   - 4 Common Pool rate providers (rated to WETH)
   - 2 Balancer V3 Stable Pools
   - Weighted Pool (DETF/Stable/Common)
   - DETF logic (bonding, vault-specific Bond NFT, rebasing)
4. First user bonds liquidity. The DETF routes each deposit through the eligible vault with the lowest rated liquidity after rate application, then into the composed pool leg with the lowest rated liquidity after rate application for that vault token, and finally deposits the resulting BPT into the Weighted Pool before minting DETF exposure.
5. When minting DETF, the contract first checks that the current reserve spot price is above the mint threshold, then boosts the routed Stable Pool BPT leg by the configured seigniorage incentive, and finally quotes the gross DETF output from the live Weighted Pool using that boosted BPT input so the gross quote matches existing Protocol DETF-style split-mint semantics.
6. After the gross DETF output is known, the mint flow must split that gross amount between the user allocation and the protocol allocation. The user receives only the post-split net DETF amount, while the protocol-side DETF slice is minted to the Bond NFT vault reward inventory.
7. The same mint execution must also add the reserve-pool BPT created by the mint route into the protocol-owned Bond NFT position, so ordinary user minting grows protocol-owned reserve principal without minting a new user bond NFT.
8. Bonded positions are represented by the vault-specific Bond NFT implementation, but the user-facing bonding lifecycle remains the same as Single Vault DETF: bond into a locked NFT position, accrue rewards, optionally sell the bond NFT into the protocol position, or redeem after unlock.

## Open Questions
- Should the DETF support more than 5 vaults if Balancer increases the pool limit?
- Should the DETF allow for dynamic rebalancing or vault replacement post-deployment?
- What deterministic tie-break rule should be used when two eligible vaults or two eligible pools have equal rated liquidity?

## References
- `contracts/vaults/detf/composed/single/` (SingleVaultDetf)
- `contracts/vaults/protocol/` (Protocol DETF)
- IndexedEx/Crane Diamond Pattern and FactoryService conventions
- These references are behavioral and architectural references only, not implementation dependencies for this vault family.
