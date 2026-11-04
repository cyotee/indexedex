# Uniswap V4 full-spread Standard Exchange vault PRD

Frozen council draft **fullspread-se-prd-draft-r1**, 2026-10-30. This is the coordinator synthesis of four independent originals. It is not member-approved text, not an implementation, and not a safety or legal clearance. Advisory review of this exact file comes next. The publication target, after resolution, is `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`.

## 1. Goal

Build one IndexedEx family, `UniswapV4FullSpreadStandardExchangeVault`.

One registry-deployed Crane diamond owns one Uniswap V4 pool key, one full-range position, the idle currencies of that position, and one ERC-20 share supply. Public shares are proportional claims on that basket. The diamond is the position owner.

This is the Standard Exchange form of the shape the owner clarified. It is not WeirVaults. WeirVaults is one manager of many virtual vaults and an internal share ledger. This family is one token, one pool, one position.

It is a sibling of PairToken stage one, not a rename and not an amendment of `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md`. PairToken stage one is the packaging and economics exemplar. This PRD inherits that economics by ID and specifies only the deltas required to use the share in the existing custom Uniswap V4 Standard Exchange buffer hooks.

### 1.1 What this family is not

- Not a Weir source copy, and not "add ERC-20 to WeirVaults."
- Not Upper/Lower Wings. No second range, no rebalance facet, no wings economic target.
- Not a singleton of many pools.
- Not a second share ledger or a shares-of-shares wrapper.
- Not an ERC-4626-only product. Standard Exchange, standard vault, and SY surfaces stay.
- Not a hook-package redesign. A hook change is a separate requirement, raised only with a cited rejecting function.

### 1.2 Deltas from PairToken stage one

| ID | Delta | Not a delta |
| --- | --- | --- |
| FS-X01 | Exact-input routes that current buffer hooks call must execute while the bound PoolManager is already unlocked, without a nested `unlock`. | Ordinary user entry still opens its own unlock. |
| FS-X02 | `queryFacet` exposes canonical `IRateProvider.getRate()` as the executable normalized one-share exit into `rateAsset`. | Issuance and SY `exchangeRate` are unchanged. |
| FS-X03 | Tests must place this share and another SE vault share in the current buffer-hook families. | Those hook packages are not edited by this PRD. |

Economics, native custody, exact-output rejection, conditional withdrawal fallback, gas budgets, and fee attribution stay the inherited PairToken rules. Do not write a second equation set.

## 2. Inherited authority

Read and follow these. If this draft and the stage-one PRD disagree on an inherited ID, the stage-one PRD controls that ID. This draft controls only FS- IDs.

| Source | Role |
| --- | --- |
| `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md` | Economics, package law, and inherited acceptance. |
| `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVaultDFPkg.sol` | Current 12-field `PkgInit` shape. Re-read before coding. |
| `contracts/hooks/uniswap/v4/standardExchange/` | Current hook bindings. Do not redesign them here. |
| `CLAUDE.md`, `docs/agent/INDEXEDEX_AGENT_LAW.md`, `.github/ASSISTANT_CODING.md`, `.github/ASSISTANT_TESTS.md` | Registry, token, and test law. |
| `.agents/skills/crane-architecture/SKILL.md`, `.agents/skills/indexedex-testing/SKILL.md`, `.agents/skills/indexedex-uniswap-v4-hook-packages/SKILL.md` | Packaging and production-first tests. |

### 2.1 Inherited decisions

Inherit, do not restate as new economics:

- S1-D01 through S1-D05.
- S1-P01 through S1-P07.
- S1-ARCH-01 through S1-ARCH-05, except the family name, directory, and the two deltas in section 1.2.
- S1-ACC-01 through S1-ACC-07.
- S1-OP-01 through S1-OP-05 and S1-EXIT-01.
- S1-NATIVE-01.
- S1-API-01 through S1-API-05, plus the `getRate` selector added by FS-RATE-01.
- S1-QUOTE-01, S1-QUOTE-02, and S1-GAS-01.
- S1-PKG-01, S1-SEC-01, S1-SEC-02, and S1-OBS-01.
- S1-TEST-01's fixture discipline.

S1-API-04's optional surfaces are not silently installed. `IStandardExchangeTransitionQuote`, `IStandardExchangeExternalQuote`, and `IStandardExchangeRateQuote` are out of this PRD unless a cited hook path rejects without one. That rejection is FS-HOOK-04, not a placeholder implementation.

### 2.2 Coordinator dispositions

These were not unanimous. They are draft choices, open to the advisory round. They are not owner approvals beyond the brief.

| Topic | Draft choice | Not adopted |
| --- | --- | --- |
| `getRate` | Install it on `queryFacet`. | Grok: omit it. MiniMax: a thirteenth `RateFacet`. |
| Supply below one whole share | Revert `InsufficientRateSupply`. Do not extrapolate and do not return zero. | Kimi: return zero. |
| Unlocked surface | Only the canonical exact-input `exchangeIn` routes the current hooks call. | Grok: the same branch on compound, donate, and paired methods. |
| Unlocked authority | Self-funded caller, recipient is caller, `pretransferred` is false. No hook allowlist. | A `PkgArgs` allowlist. It is circular with hook deployment. |
| Entry remainder | Inherit booked zap credit. Full consumption means the selected swap input is spent or the call reverts. | A new rule that every input wei must become liquidity. |

## 3. Facets

### FS-FACET-01 — Twelve package inputs

`PkgInit` has the same twelve explicit facet fields as the current PairToken package, in the same order. It is not an open `IFacet[]`. Factory-owned introspection and temporary-hook facets are not inputs, not `facetAddresses` entries, and not package cuts.

Shared, reused unchanged:

| Field | Role |
| --- | --- |
| `erc20Facet` | Share token. |
| `erc2612Facet` | Permit. |
| `erc5267Facet` | EIP-712 domain. |
| `basicVaultFacet` | Basic vault surface. |
| `standardVaultFacet` | Standard vault surface. |

Family-owned, same split as PairToken, with the one selector delta below:

| Field | Role |
| --- | --- |
| `moneyFacet` | Paired deposit, paired redeem, donate, compound. |
| `quoteFacet` | Previews. |
| `outFacet` | `IStandardExchangeOut`. Both methods revert `ExchangeOutNotAvailable()` without taking funds or changing state. |
| `queryFacet` | Family queries plus `getRate()`. |
| `syMoneyFacet` | SY deposit and redeem. |
| `syQueryFacet` | SY `exchangeRate` and previews. |
| `callbackFacet` | Authenticated `unlockCallback` for the vault-started unlock only. |

`getRate()` is the only new package-owned selector. It lives on `queryFacet`. Do not add a thirteenth facet. One selector does not need a second rate authority, and a separate facet would change `bindingHash` order without a selector the query facet cannot carry.

### FS-FACET-02 — Excluded factory components

Do not put these in `PkgInit`, `facetCuts`, or the package interface aggregation:

- ERC-165 introspection under `lib/crane/contracts/introspection/ERC165/`.
- Diamond loupe under `lib/crane/contracts/introspection/ERC2535/`.
- The factory-owned temporary-hook facet named by the current factory. The PairToken interface excludes it. This draft does not invent its filename. Implementation must cite that file before naming it in code.

The finished proxy still exposes the factory-installed introspection. Exclusion from `PkgInit` is not removal from the diamond.

## 4. Files and package

### FS-ARCH-01 — Files

Create the family under `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`. Do not edit PairToken or Wings files to host it.

Proposed production files, mirroring the PairToken split:

- `interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol`
- `interfaces/IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol`
- `UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol`
- `UniswapV4FullSpreadStandardExchangeVaultComponent_FactoryService.sol`
- `UniswapV4FullSpreadStandardExchangeVaultComponentBindings.sol`
- `UniswapV4FullSpreadStandardExchangeVaultTypes.sol`
- `UniswapV4FullSpreadStandardExchangeVaultRepo.sol`
- `UniswapV4FullSpreadStandardExchangeVaultMath.sol`
- `UniswapV4FullSpreadStandardExchangeVaultProjection.sol`
- `UniswapV4FullSpreadStandardExchangeVaultPlanner.sol`
- `UniswapV4FullSpreadStandardExchangeVaultExecution.sol`
- `UniswapV4FullSpreadStandardExchangeVaultMoneyFacet.sol` and `MoneyTarget.sol`
- `UniswapV4FullSpreadStandardExchangeVaultQuoteFacet.sol` and `QuoteTarget.sol`
- `UniswapV4FullSpreadStandardExchangeVaultOutFacet.sol` and `OutTarget.sol`
- `UniswapV4FullSpreadStandardExchangeVaultQueryFacet.sol` and `QueryTarget.sol`
- `UniswapV4FullSpreadStandardExchangeVaultSYMoneyFacet.sol` and `SYMoneyTarget.sol`
- `UniswapV4FullSpreadStandardExchangeVaultSYQueryFacet.sol` and `SYQueryTarget.sol`
- `UniswapV4FullSpreadStandardExchangeVaultCallbackFacet.sol` and `CallbackTarget.sol`

Tests live under `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`, with the TestBase beside the family only if that is the current PairToken harness pattern. Follow the current harness. Do not invent a second base style.

Storage uses a new namespaced slot, `keccak256(abi.encode(namespace)) - 1`, not PairToken's slot and not Wings' slot. The inequality is an acceptance check. Do not copy a slot constant from memory.

### FS-PKG-01 — `PkgInit` and `PkgArgs`

`PkgInit` fields, in binding order:

1. `erc20Facet`
2. `erc2612Facet`
3. `erc5267Facet`
4. `basicVaultFacet`
5. `standardVaultFacet`
6. `moneyFacet`
7. `quoteFacet`
8. `outFacet`
9. `queryFacet`
10. `syMoneyFacet`
11. `syQueryFacet`
12. `callbackFacet`
13. `poolManager`
14. `registry`
15. `oracle`
16. `wrappedNative`
17. `diamondFactory`
18. `linkedLibraries` as `address[6]`: Math, Projection, SwapProjection, Planner, Execution, ExecutionPreparation

`PkgArgs` is the PairToken argument set. No silent zap default and no hook allowlist:

- `PoolKey poolKey`
- `address rateAsset`
- `string name`
- `string symbol`
- `uint16 maxZapBps`
- `int24 maxZapTickMove`

`bindingHash` covers every `PkgInit` field, including the twelve facets and six libraries. `calcSalt` and `processArgs` run by delegatecall in the factory and must use immutable bindings and self calls, not foreign package storage.

`deployVault(PkgArgs) returns (address)` goes through the bound IndexedEx vault registry. No CREATE3 of the PoolManager. No second factory.

### FS-PKG-02 — Validation

Reject, without a partial diamond:

- A missing or code-empty component, or a family facet whose linked-component hash does not match the package libraries. `InvalidComponent`.
- A pool key that is not initialized on the bound manager, has a nonzero hook, or is otherwise outside the inherited supported domain. `InvalidPoolKey`.
- A `rateAsset` that is not a declared ERC-20 currency face. `InvalidRateAsset`.
- Zap limits that are not a positive in-range fee bound and a nonnegative tick bound. `InvalidZapLimits`.
- A wrapped-native address that is incompatible or collides with the other currency face. `InvalidWrappedNative`.
- `processArgs` not entered through the bound registry. `NotCalledByRegistry`.
- Proxy initialization that does not match the bound package and arguments. `InvalidInitializationContext`.
- A second initialization. `AlreadyInitialized`.

Do not invent selector hex in this PRD. Compute selectors in the repository's later verification step. The PairToken comments are observations, not a fresh computation for this family.

Initialization installs the inherited vault metadata, the pool key, the full-range ticks, and the rate asset. The first depositor creates the position. There is no permanent dead-share mint and no vault-level performance fee.

## 5. Money, callback, and unlocked entry

### FS-MONEY-01 — Inherited surface

The public money surface is the PairToken surface:

- `depositPair` and `previewDepositPair`
- `redeemPair` and `previewRedeemPair`
- `exchangeIn` and `previewExchangeIn`
- `exchangeOut` and `previewExchangeOut`, both reverting `ExchangeOutNotAvailable()`
- `donate`
- `compound`
- SY deposit, redeem, and previews
- family queries listed on the current PairToken query facet

Issuance is S1-ACC-02 and S1-ACC-07. Zap credit stays the inherited booked donation. A successful single-token call spends the selected swap input completely or reverts. It does not pay a second token, strand a residual, or burn shares and donate the unpaid exit. It does not promise that every input wei becomes liquidity. That remainder, if any, stays the inherited `J_i` booking.

Native ETH stays, including native-currency pools and actual ETH entry and payout. The wrapped-native adaptation at a nonpayable boundary does not remove native operation.

Withdrawal maintenance is S1-EXIT-01. Deposits and standalone compound do not receive the collection-only fallback. The 12,000,000 gas transaction ceiling and the 5,000,000 preview ceiling stay. A hook-combined transaction is measured and reported. It is not a new ceiling and not a waiver.

### FS-UNLOCK-01 — Two dispatch paths, one engine

Current hooks call `IStandardExchangeIn.exchangeIn` while the PoolManager is already unlocked. A new selector would not be called by those hooks. Do not add `exchangeInUnlocked`.

`exchangeIn`, after the ordinary route, deadline, amount, and authority checks, reads `TransientStateLibrary.isUnlocked` on the bound manager:

- Locked: the inherited vault-started unlock. Store the callback hash, call `unlock` once, and accept `unlockCallback` only from that manager, only with that hash, only once.
- Unlocked: FS-UNLOCK-02. Do not call `unlock`.

`isUnlocked` selects the path. It is not authorization. Allowance, recipient, minima, deadline, and share authority still apply. The PoolManager is not the depositor.

`depositPair`, `redeemPair`, `donate`, `compound`, and the SY mutators keep `ManagerAlreadyUnlocked()` on this path. The current hooks do not call them during `beforeSwap`. Widening the borrowed path to those methods is not required for the requested integration and is not adopted.

### FS-UNLOCK-02 — Borrowed unlock

When `exchangeIn` takes the unlocked path:

1. The vault is initialized and idle. The callback hash is empty. Reservations are zero. This diamond's own backing-currency deltas on the bound manager are zero. Otherwise revert `SettlementMismatch` or `ReentrantOperation`, as applicable.
2. The caller has code. `recipient == msg.sender`. `pretransferred == false`. `msg.value == 0` on this ABI. Otherwise revert `InvalidUnlockedContext`.
3. The caller pays the input and receives the output. Share exit burns only that caller's shares. No payer, callback payload, or foreign creditor is accepted on this path.
4. Run the same planner and the same settlement code as the locked path. Call `modifyLiquidity` and `swap` directly on this diamond's hookless pool key. Do not call `unlock`, and do not call `unlockCallback`.
5. The position owner remains this diamond. The only position written is this diamond's full-range salt-zero position.
6. Before return, this diamond's currency deltas for the currencies this call touched are zero. Assert that per address: `currencyDelta(manager, vault, currency) == 0`. Do not require the manager's global nonzero-delta count to be zero. Do not settle the hook's or the router's deltas.
7. A failure reverts the vault call and its descendant effects. It does not claim to relock an outer unlock that a caller caught.

`unlockCallback` remains installed and remains unusable as a deposit. An external unlock does not satisfy the committed-hash check.

The vault pool key has `hooks == address(0)`. During a hook swap the vault must not modify or swap the hook's pool key.

## 6. Rate, quote, and issuance

These three numbers stay separate. NatSpec on the query and SY query facets must say so.

| Surface | Meaning | Forbidden substitute |
| --- | --- | --- |
| Issuance and `previewZapCredit` | S1-ACC-02 and S1-ACC-07 attributable credit. | Not `exchangeRate`. Not `getRate`. |
| SY `exchangeRate()` | S1-QUOTE-02 spot-marked basket accounting value. Raw rate-asset units per `1e18` raw shares. Zero at zero supply. | Not an exit quote. Not a WAD oracle. Not an issuance input. |
| `previewExchangeIn(share, amount, currency)` | Amount-specific executable exit, including maintenance choice and full unwanted-leg consumption. | Not `amount * getRate`. Not whole-book value divided by supply. |
| `getRate()` | Normalized executable exit of one whole share into `rateAsset` only. | Not NAV. Not SY accounting. Not the external full-book provider formula. |

### FS-RATE-01 — `getRate`

`queryFacet` implements canonical `IRateProvider.getRate()`.

```text
oneShare = 1e18
E = the previewExchangeIn planner result for oneShare shares into rateAsset
d = the cached decimals of rateAsset
getRate = floor(E * 1e18 / 10^d)
```

Use the same planner as execution, including the selected maintenance and the integer rules. Do not scale a smaller redemption. Do not divide a whole-book liquidation by supply. Do not cache a previous rate. Do not publish a 1:1 bootstrap.

Normalization must not overflow an intermediate `10^d` when a smaller exponent will do. For `d <= 18`, multiply by `10^(18-d)`. For `d > 18`, divide by `10^(d-18)`. A result that cannot fit `uint256` reverts `RateNormalizationOverflow`. A mathematically zero normalization reverts `RateUnavailable`.

If total supply is below `1e18`, including zero supply, revert `InsufficientRateSupply(available, required)`. Do not extrapolate. Do not return zero. A zero return is not used, because a caller can treat zero as a price.

A genuine planner or budget failure propagates. A busy family operation reverts `ReentrantOperation`. An idle vault may answer while the manager is unlocked. A busy vault must not return a half-updated rate.

`getRate` is a current, endogenous, one-share reference. It is nonlinear in size. It is not a manipulation-resistant oracle. No Chainlink, peg, or second pool is required. This PRD does not add a TWAP hook on the backing pool. A same-pool TWAP, if later supplied, is not an independent price.

The existing `StandardExchangeRateProviderFacet._getRate` prices the entire book and, at zero supply, inverts a unit deposit. Do not point this family's exposed rate at that formula. A hook that needs `IRateProvider` for a non-identity full-spread leg binds a provider whose `getRate` is this vault's `getRate`, or binds this vault when the interface matches. It does not bind the full-book provider and call the result a one-share rate.

## 7. Hook integration

### FS-HOOK-01 — Families

The current tree has these buffer-hook families. Tests use the package interface in each family's `interfaces/` directory.

| Family | Binding the test must use |
| --- | --- |
| `single/` | `standardExchange` and `pairToken`. |
| `constantProduct/single/` | `standardExchange`, `pairToken`, and `rawToken`. |
| `dual/` | `standardExchange0/1` and `token0/1`. |
| `orbital/` | `se0/1/2` and `rp0/1/2`, plus the token and decimal fields. |
| `weighted/` | `standardExchanges` and `rateProviders` arrays, `n` in the package's supported range. |
| `stable/quad/curve/` | The fixed four-leg arrays. |
| `stable/quad/balancer/` | The dynamic arrays, within the package's supported length. Do not assume a fixed four. |

No new hook-package field is authorized by the interfaces read for this draft. If a family's validation rejects a full-spread share, record the function and the revert. That record is FS-HOOK-04. It is not a silent hook edit.

### FS-HOOK-02 — Two configurations

Identity: the pool token is this vault's share, and the share is also the `standardExchange` argument where the package uses that field. Trading the share does not by itself prove underlying entry or exit inside the unlock.

Buffered: `standardExchange` is this vault, and the pool token is its `rateAsset`. The hook mints or burns through `exchangeIn` while the manager is unlocked. This is the path FS-UNLOCK-02 exists for. The rate provider, when the package requires one because the token is not the share, must be the one-share provider in FS-RATE-01.

The primary cross-vault proof uses two vaults with different backing pool keys, even if they share a currency and the same manager. A route in which two vaults modify the same backing pool key in one swap is not covered by that proof. Report it as unverified. Do not call it impossible, and do not count it as passed.

### FS-HOOK-03 — Exact output

`exchangeOut` reverts. A hook path that calls it against this vault fails closed. An identity-share route that never calls `exchangeOut` is not forbidden by that sentence.

### FS-HOOK-04 — Separate hook-change gate

If a required route cannot run on the current hook:

1. A full-spread money, preview, or context defect is fixed in this family.
2. An intentional exact-output or budget rejection stays a rejection.
3. A missing stateful quote or an incompatible denomination is a separate requirement. Name the consumer, the selector, the arguments, and the revert. Do not implement that change in this PRD, and do not stub a transition quote that returns live values for a projected state.

## 8. Testing

### FS-TEST-01 — Harness

Production-first. `CraneTest`, then the current IndexedEx vault component base, then a family TestBase. Deploy a real `PoolManager` with `new PoolManager(address(this))` after `CraneTest.setUp()`. Deploy the real facets, package, registry, fee oracle, wrapper, and tokens through production paths.

No mock, etch, `vm.mockCall`, storage injection, or scripted manager delta of this vault or the PoolManager. Do not subclass the system under test. Do not extend a concrete PairToken or Wings test as the system under test. Shared harness code may be reused.

`recordLogs` is not a receipt. A snapshot restore asserts pre-state and post-state equality before restore.

### FS-TEST-02 — Files

- `UniswapV4FullSpreadStandardExchangeVaultPackage.t.sol`
- `UniswapV4FullSpreadStandardExchangeVaultMoney.t.sol`
- `UniswapV4FullSpreadStandardExchangeVaultNative.t.sol`
- `UniswapV4FullSpreadStandardExchangeVaultQuotesAndRate.t.sol`
- `UniswapV4FullSpreadStandardExchangeVaultCallbacks.t.sol`
- `UniswapV4FullSpreadStandardExchangeVaultAlreadyUnlocked.t.sol`
- `UniswapV4FullSpreadStandardExchangeVaultBufferHookIntegration.t.sol`

Inherited PairToken acceptance rows S1-A01 through S1-A70 apply to the inherited behavior, mapped to this family's files. A row that depends on a PairToken-only name is mapped, not dropped. The new rows below are additional.

### FS-TEST-03 — New acceptance rows

| ID | Assertion |
| --- | --- |
| FS-A01 | Package inputs are the twelve fields in FS-PKG-01. Factory introspection and the temporary-hook facet are absent from cuts. |
| FS-A02 | `bindingHash` changes if any facet, library, manager, registry, oracle, wrapper, or factory binding changes. |
| FS-A03 | Invalid component, pool key, rate asset, zap limits, wrapper, caller, and double initialization revert the named errors and leave no usable vault. |
| FS-A04 | Storage slot is not PairToken's and not Wings'. |
| FS-A05 | First deposit creates one full-range position owned by the diamond. No dead-share mint. No performance fee. |
| FS-A06 | Paired deposit and redeem match S1-ACC-02 and S1-ACC-03 on a fresh real manager. |
| FS-A07 | Single-token entry spends the selected swap input or reverts. No second token is paid. |
| FS-A08 | Single-token exit pays only the selected token or reverts. Shares are not burned if the exit reverts. |
| FS-A09 | `exchangeOut` and `previewExchangeOut` revert `ExchangeOutNotAvailable` with unchanged balances. |
| FS-A10 | Native pool entry and payout move ETH, not a surprise WETH balance, except the inherited wrapper boundary. |
| FS-A11 | Withdrawal fallback follows S1-EXIT-01. Deposit and compound do not take that fallback. |
| FS-A12 | `exchangeRate` matches S1-QUOTE-02 and is not equal to `getRate` on a fixture where decimals or idle make them differ. |
| FS-A13 | `getRate` equals the normalized `previewExchangeIn` of `1e18` shares into `rateAsset` when supply is at least one share. |
| FS-A14 | Supply below `1e18` makes `getRate` revert `InsufficientRateSupply`. It does not return zero and does not scale a smaller exit. |
| FS-A15 | A planner failure on the one-share exit propagates from `getRate`. It does not become NAV. |
| FS-A16 | Issuance does not read `getRate` or `exchangeRate`. |
| FS-A17 | Locked `exchangeIn` uses one `unlock` and one accepted callback. A second callback reverts. |
| FS-A18 | `unlockCallback` from any caller but the bound manager reverts and moves no tokens. |
| FS-A19 | While the manager is unlocked, `exchangeIn` does not call `unlock`. The diamond's touched currency deltas are zero before return. The global delta count may be nonzero. |
| FS-A20 | An unlocked `exchangeIn` with `recipient != msg.sender`, `pretransferred == true`, or `msg.value != 0` reverts `InvalidUnlockedContext`. |
| FS-A21 | An unlocked caller who does not hold the input or the shares reverts. The unlocked flag does not mint. |
| FS-A22 | `depositPair`, `redeemPair`, `donate`, `compound`, and SY mutators revert `ManagerAlreadyUnlocked` while the manager is unlocked. |
| FS-A23 | A reverting unlocked `exchangeIn` restores the vault's shares, position liquidity, and token balances. |
| FS-A24 | Identity hook configuration trades this share without calling the vault's underlying zap. |
| FS-A25 | Buffered hook configuration, token equal to `rateAsset`, mints and burns through `exchangeIn` while the manager is unlocked. |
| FS-A26 | Two vaults with different backing pool keys, this family and another SE family, complete one exact-input hook swap in both directions that the hook supports. |
| FS-A27 | The same two-vault proof is specified for each family in FS-HOOK-01, or the row records the cited validation reject under FS-HOOK-04. |
| FS-A28 | A hook path that calls `exchangeOut` on this vault reverts and pays neither token. |
| FS-A29 | The rate provider bound for a non-identity leg returns this vault's `getRate`, not the full-book provider's value, on a fixture where those differ. |
| FS-A30 | A same-backing-pool sequential composition is not reported as passed by FS-A26. |

A skipped row, `assertTrue(true)`, or a success flag alone does not close FS-A27. An unreachable hook branch records the stage and the gap.

## 9. Non-goals and limits

This PRD does not authorize implementation, deployment, a registry migration, a hook edit, a Weir copy, a wings range, a second pool, or a transition-quote facet.

No audit is claimed. Hook integration on disjoint backing pools does not prove same-pool sequential safety. `getRate` does not prove a consuming pool is manipulation-safe. Compiler, gas, and fork results are future evidence, not claims of this draft.

Member dissent preserved: Grok would omit `getRate`; MiniMax would add `RateFacet`; Kimi would return zero below one share; Grok would also unlock compound, donate, and paired methods. Those alternatives are not silent edits. Advisory may require a change. Until then, section 2.2 is the draft.

## 10. Participation so far

| Member | Route requested | Original | Status |
| --- | --- | --- | --- |
| Astra | `chatgpt-subscription/gpt-6-astra:high` | `members/astra/response.md` | Settled. `st_01a18d05`. |
| Grok | `xai/grok-4.7:xhigh` | `members/grok/response.md` | Settled. `st_01a18d06`. |
| MiniMax | `minimax/MiniMax-M3` | `members/minimax/response.md` | Settled. `st_01a18d07`. |
| Kimi | `kimi-coding/k3.1-pro:high` | `members/kimi/response.md` | Settled. `st_01a18d08`. |

Coordinator mode is invoking-agent. This draft is not a fifth vote. Feedback has not been requested in the text of this file. The advisory message identifies this path and revision.
