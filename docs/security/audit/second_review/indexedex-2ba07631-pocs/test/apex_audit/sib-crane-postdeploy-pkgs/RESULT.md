# sib-crane-postdeploy-pkgs: the Crane PostDeployAccountHookFacet hijack does not reach any sibling DFPkg (REFUTED by execution, 10 suites, 14/14 PASS)

**Parent finding:** r3 h3-crane-postdeploy-hook-unauth-delegatecall (hunt3 NEW-1, MEDIUM). It is confirmed only on `BalancerV3ConstantProductPoolStandardVaultPkg`, because that package passes a deployer-chosen `hooksContract` to `registerPool`, so `onRegister` is a non-static CALL into attacker code. That finding stands as before. This task checked every other family.

## How the window works and how it was tested

**When the hijack is possible.** The facet stays mounted from the moment the proxy's code exists until the factory's final `postDeploy()`. A hijack needs two things:
- some attacker-substitutable address must receive a **non-static CALL** inside the `factory.deploy` frame;
- that address must then call `proxy.postDeploy()`.

**Calls that cannot open the window:**
- Calls made during `initAccount` happen while the proxy is being constructed. The proxy has no code yet, so nothing runs.
- Calls made during `updatePkg` happen before the proxy exists.

**The oracle: `WindowProbe.sol`.** It records `vm.startStateDiffRecording` around each deploy. For each top-level factory `deploy` / `deployWithMineNonce` frame it counts:
- (a) `postDeploy()` CALLs from anything other than the factory or a package;
- (b) DELEGATECALLs of `postDeploy(address)` into code that is not the factory or a package. This is the actual hijack;
- (c) non-reverted CALLs into an address that was STATIC-probed as a token, vault, rate provider or hook (`decimals`, `name`, `getRate`, `previewExchange*`, `vaultTokens`, `tokens`, `owner`, `getHookFlags`, …). These are the slots a deployer can fill;
- (d) every distinct external CALL edge.

**Oracle validation.** `test_oracleControl_constProdHijackIsFlagged` replays the known ConstProd attack. The backdoor lands, and the oracle reports foreign=1, hijackDelegatecalls=1 and callsIntoSubst=1 (`vault -> EvilHooks.onRegister`).

## Per-family results (all executed on t4, local Balancer / Aerodrome / V4 test stacks)

| Family (pkg) | Test | External CALL edges in window | Foreign postDeploy / hijack DC / CALLs into substitutable | Verdict |
|---|---|---|---|---|
| Balancer ConstProd (`BalancerV3ConstantProductPoolStandardVaultPkg`) | r3 + oracle control | Balancer vault, fee controller, **attacker hooks.onRegister** | 1 / 1 / 1 | CONFIRMED (dup of r3) |
| ConstProd SE buffer (`StandardExchangeBufferPoolStandardVaultPkg`) | SibSEBufferWindow, honest + **adversarial** | vault.registerPool, feeController.registerPool | 0 / 0 / 0. Adversarial run: 10 attempts, 2 reached the facet but reverted under STATICCALL | refuted |
| MultiPair weighted buffer | SibMultiPairWindow | same 2 | 0 / 0 / 0 | refuted |
| CommonBuffer stable | SibCommonStableWindow | same 2 | 0 / 0 / 0 | refuted |
| CommonBuffer weighted | SibCommonWeightedWindow | same 2 | 0 / 0 / 0 | refuted |
| MixedBuffer stable | SibMixedStableWindow | same 2 | 0 / 0 / 0 | refuted |
| MixedLeg weighted | SibMixedLegWindow | same 2 | 0 / 0 / 0 | refuted |
| DETF MultiVaultWeighted (nested postDeploy) | SibDetfMVWWindow | registry, vault, fee controller, WeightedPoolFactory | 0 / 0 / 0 (7 legitimate postDeploy calls) | refuted |
| DETF MixedBuffer (nested pool deploy) | SibDetfMixedWindow | registry, vault, fee controller | 0 / 0 / 0 (8 legitimate) | refuted |
| DETF SingleSE | SibDetfSingleSEWindow, honest + **adversarial** (evil `rateTarget` targeting the predicted DETF) | registry, vault, fee controller, WeightedPoolFactory | 0 / 0 / 0. Adversarial run: 1 attempt reached the DETF facet but reverted under STATICCALL; deploy succeeded with no backdoor | refuted |
| DETF UniswapV4 (+ hook factory window) | SibDetfV4Window | registry only | 0 / 0 / 0 (3 windows, 7 legitimate) | refuted |
| DETF ComposedStable | static only (no full-deploy fixture: the test base uses a mock DETF) | `WEIGHTED_POOL_FACTORY.create` (hooks=0), trusted child packages, `FEE_ORACLE.feeTo()` (view) | n/a | refuted (static) |
| Every other DFPkg: hooks, SE vaults, staking, Aave, Morpho, router, fee collector, manager, rate providers, SY/claim/bond, TWAP | static | `postDeploy` is `pure`/`return true`. TWAP reads only its own proxy | n/a | no window code |

## Why the window holds in every other family
- Every attacker-choosable address is reached only through `view` interfaces (STATICCALL):
  - `decimals`, `name` and `safeDecimals` (BetterSafeERC20 uses an explicit `staticcall`);
  - `previewExchange*` and `vaultTokens` / `vaultConfig`;
  - the V4 hook `tokens` / `standardExchangeOf` / `owner`;
  - all buffer-pool `onRegister` implementations, which are `view` on the pool itself.
- The `hooksContract` is always the pool proxy itself, except in ConstProd.
- Weighted reserves use hooks=0.
- Balancer `registerPool` does not call `getRate`.
- **Fragility:** the adversarial runs show the facet is reachable from attacker code during the window. Only STATICCALL prevents the hijack. A future non-view callback in any `postDeploy` path would reopen it, so the Crane fix (`require(msg.sender == factory)`) remains the right remediation.

## Live 4663 (read-only cast; registry 0x09682b00…)
- `vaultPackages()` lists 17 packages: UniswapV4 SE (x4), MorphoBlue SE, DETFNFTVault, V4 CP / Weighted (x2) / CurveQuad hooks, legacy V4 SingleSE / Weighted / CurveQuad DETDFPkgs, UniswapV4DetfBondNFTVault, DETFSY, UniswapV4DetfDFPkg (0x3d1FEf43), RebasingAwareERC4626.
- **No Balancer pool package of any kind (ConstProd or buffer) is registered.**
- The live UniswapV4DetfDFPkg source (aca16198) has the same `postDeploy` as HEAD, and that path was refuted above.
- Live exposure: nil.
