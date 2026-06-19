# Buffer Pool Comparative Tests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Keep the "Progress log" section below updated after every task so work can resume after a failure.

**Goal:** Add A/B comparative tests proving the Standard Exchange Buffer Pool produces the same swap outputs and spot price as a real Balancer V3 constant-product pool of the same `(TTA, shares)` tokens sharing the same rate provider — at the initial rate and after the underlying Uniswap V2 pool is traded.

**Architecture:** A new abstract test base extends the existing `TestBase_StandardExchangeBufferPool_UniswapV2` fixture and additionally deploys a real `BalancerV3ConstantProductPoolStandardVaultPkg` pool over the same `(DAI, seVault-shares)` tokens, registering the shares side `WITH_RATE` against the same `seRateProvider`. Both pools are initialized to identical effective (rate-scaled) reserves, both fees are forced to 0, and swaps are compared from identical pre-states using `vm.snapshotState()` / `vm.revertToState()`. A behavior library holds the comparison assertions; a spec runner exposes the individual test cases.

**Tech Stack:** Solidity 0.8.30, Foundry (forge), Crane Diamond/DFPkg framework, Balancer V3 VaultMock + RouterMock test harness.

## Global Constraints

- Solc `0.8.30`; license header `// SPDX-License-Identifier: BUSL-1.1`; `pragma solidity ^0.8.0;` (match sibling test files).
- Import `IERC20` from `@crane/contracts/interfaces/IERC20.sol` (Crane's IERC20 is canonical — NOT OpenZeppelin's).
- Test paths live under `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/comparative/`.
- No production contracts change — additive test-only work.
- Reference pool uses the **same** `seRateProvider`, `bv3Vault`, `diamondPackageFactory`, shared facets, and `shares` token as the buffer pool fixture.
- Tolerances (declare as constants on the base): `REL_TOL = 1e12` (1e-6 in `assertApproxEqRel`, where 1e18 = 100%), `ABS_TOL = 1e3` wei.
- Run a single test file with: `forge test --match-path "<path>" -vvv`.

---

## Key fixture facts (inherited from `TestBase_StandardExchangeBufferPool_UniswapV2` → `TestBase_StandardExchangeBufferPool` → `TestBase_BalancerV3Vault` + `IndexedexTest`)

State available to subclasses:
- `IVaultMock internal vault;` — the BV3 VaultMock (exposes `manualSetStaticSwapFeePercentage`, `getCurrentLiveBalances`, `getPoolTokenInfo`).
- `IVault public bv3Vault;` — `= IVault(address(vault))`.
- `RouterMock router;` — exposes `initialize`, `swapSingleTokenExactIn`, `addLiquidity*`.
- `IStandardExchangeProxy public seVault; IERC20 public tta /*DAI*/, ttb /*USDC*/, shares /*=IERC20(address(seVault))*/;`
- `IRateProvider public seRateProvider;`
- `address public bufferPool;`
- `IUniswapV2Pair internal uniV2DaiUsdcPair; IUniswapV2Router internal uniV2Router;`
- `ERC20TestToken dai; ERC20TestToken usdc;` (have `.mint(addr, amount)`).
- `address alice, bob, lp, owner; address[] users;`
- `ICreate3FactoryProxy create3Factory; IDiamondPackageCallBackFactory diamondPackageFactory; IIndexedexManagerProxy indexedexManager; IPermit2 permit2;`
- Shared BV3 pool facets already deployed: `multiAssetBasicVaultFacet`, `multiAssetStandardVaultFacet`, `balancerV3VaultAwareFacet`, `betterBalancerV3PoolTokenFacet`, `defaultPoolInfoFacet`, `standardSwapFeePercentageBoundsFacet`, `unbalancedLiquidityInvariantRatioBoundsFacet`, `balancerV3AuthenticationFacet`.

Helpers available:
- `mintTTA(address recipient, uint256 amount)` — mints DAI.
- `mintShares(address recipient, uint256 daiAmount) returns (uint256 sharesOut)` — V2 addLiquidity → SE deposit (V2 override).
- `swapTTAforShares(address user, uint256 amountIn) returns (uint256)` — EXACT_IN swap on `bufferPool`.
- `swapSharesForTTA(address user, uint256 amountIn) returns (uint256)` — EXACT_IN swap on `bufferPool`.
- `approveForPool(IERC20 bpt) internal` — BPT approvals for all users.

Buffer pool getters (`IStandardExchangeBufferPool(bufferPool)`): `virtualTTA()`, `ttaIndex()`, `sharesIndex()`.

Reference pool package API (`contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPoolStandardVaultPkg.sol`):
- `IBalancerV3ConstantProductPoolStandardVaultPkg.PkgInit { IFacet basicVaultFacet; IFacet standardVaultFacet; IFacet balancerV3VaultAwareFacet; IFacet betterBalancerV3PoolTokenFacet; IFacet defaultPoolInfoFacet; IFacet standardSwapFeePercentageBoundsFacet; IFacet unbalancedLiquidityInvariantRatioBoundsFacet; IFacet balancerV3AuthenticationFacet; IFacet balancerV3ConstProdPoolFacet; IVaultRegistryDeployment vaultRegistry; IVaultFeeOracleQuery vaultFeeOracle; IVault balancerV3Vault; IDiamondPackageCallBackFactory diamondFactory; }`
- `deployVault(TokenConfig[] calldata tokenConfigs, address hooksContract) returns (address)`

Factory service (`contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPool_FactoryService.sol`):
- `deployBalancerV3ConstantProductPoolFacet(ICreate3FactoryProxy) returns (IFacet)`
- `deployBalancerV3ConstantProductPoolStandardVaultPkg(IVaultRegistryDeployment, IBalancerV3ConstantProductPoolStandardVaultPkg.PkgInit memory) returns (IBalancerV3ConstantProductPoolStandardVaultPkg)`

`TokenConfig`/`TokenType` from `@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol`:
```solidity
struct TokenConfig { IERC20 token; TokenType tokenType; IRateProvider rateProvider; bool paysYieldFees; }
enum TokenType { STANDARD, WITH_RATE }
```
`IRateProvider` for `TokenConfig.rateProvider` and `seRateProvider`: `@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol`.

---

## File structure

- Create: `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/comparative/bases/TestBase_StandardExchangeBufferPool_Comparative.sol` — fixture + reference pool + helpers.
- Create: `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/comparative/behaviors/Behavior_StandardExchangeBufferPool_Comparative.sol` — comparison assertions.
- Create: `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/comparative/StandardExchangeBufferPool_Comparative.spec.t.sol` — spec runner / test cases.

---

## Progress log (update after each task)

- [x] Task 1 — Comparative base scaffold + reference pool deployment (compiles, registered)
- [x] Task 2 — Matched init + fee equalization + init live-balance match test
- [ ] Task 3 — Behavior library + reference swap helper + initial-rate swap comparison (both directions)
- [ ] Task 4 — `tradeUnderlyingV2` + after-rate-change swap comparison (both directions)
- [ ] Task 5 — Spot-price / getRate after rate change
- [ ] Task 6 — Full build + spec run green + final commit

**Resume point / notes:**
- Working on branch `test/buffer-pool-comparative` (branched off `main`; main had unrelated uncommitted changes left untouched).
- Verification command is `forge test --match-path ...`, NOT `forge build`: `forge build` fails at the end on a pre-existing `solar` lint "file not found" error in unrelated crane launchpad files (`contracts/external/solady/...`). Compilation itself succeeds; lint is a post-compile gate. `forge test` does not run that linter.
- Task 1 base compiled successfully (confirmed via sibling-spec `forge test` reporting "compilation skipped" after a full `forge build` compile pass).
- Task 2 DEVIATION from plan §6: `vault.manualSetStaticSwapFeePercentage(pool, 0)` reverts `SwapFeePercentageTooLow()` — the mock setter DOES validate against the pool's min-fee bound (1e12). Used the documented fallback: both pools set to the shared minimum `1e12` (new constant `EQUALIZED_SWAP_FEE`). `test_compare_init_liveBalancesMatch` PASS — matched effective reserves (virtualTTA + rate-scaled shares) confirmed equal across both pools.
- Compile is slow (~200s for the comparative tree). Run tests in the background and wait for the monitor.

**Open items resolved during research (no longer risks):**
- Fee setter: `vault.manualSetStaticSwapFeePercentage(pool, value)` (IVaultMainMock, bypasses bounds/auth) — confirmed.
- Live balances: `vault.getCurrentLiveBalances(pool)` (IVaultExtension) — confirmed.
- Const-prod `PkgInit` shape — confirmed (13 fields above).
- Snapshot cheatcodes: `vm.snapshotState()` / `vm.revertToState()` — dominant in repo (39 uses).

---

### Task 1: Comparative base scaffold + reference pool deployment

**Files:**
- Create: `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/comparative/bases/TestBase_StandardExchangeBufferPool_Comparative.sol`
- Test (temporary smoke): same file is exercised by a throwaway test added to the spec file in Task 2; for this task verify via `forge build`.

**Interfaces:**
- Consumes: all inherited fixture state/helpers listed above.
- Produces (for later tasks):
  - `address public referencePool;`
  - `IFacet internal balancerV3ConstProdPoolFacet;`
  - `IBalancerV3ConstantProductPoolStandardVaultPkg internal refPoolPkg;`
  - `function _deployReferencePool() internal virtual;` (called from `setUp`)
  - `function _buildReferenceTokenConfigs() internal view returns (TokenConfig[] memory);`

- [ ] **Step 1: Create the base file with reference-pool deployment wired into `setUp`**

```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {
    TokenConfig,
    TokenType
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    IBalancerV3ConstantProductPoolStandardVaultPkg
} from "contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPoolStandardVaultPkg.sol";
import {
    BalancerV3ConstantProductPool_FactoryService
} from "contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPool_FactoryService.sol";

import {
    TestBase_StandardExchangeBufferPool_UniswapV2
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/uniswapV2/bases/TestBase_StandardExchangeBufferPool_UniswapV2.sol";

/**
 * @title TestBase_StandardExchangeBufferPool_Comparative
 * @notice Extends the Uniswap V2 buffer-pool fixture with a real Balancer V3 constant-product pool
 *         over the same (TTA, shares) tokens and the same rate provider, for A/B comparison.
 */
abstract contract TestBase_StandardExchangeBufferPool_Comparative is
    TestBase_StandardExchangeBufferPool_UniswapV2
{
    /// @dev Relative tolerance for swap-output comparison (1e18 == 100%); 1e12 == 1e-6.
    uint256 internal constant REL_TOL = 1e12;
    /// @dev Absolute tolerance (wei) for swap-output comparison.
    uint256 internal constant ABS_TOL = 1e3;

    IFacet internal balancerV3ConstProdPoolFacet;
    IBalancerV3ConstantProductPoolStandardVaultPkg internal refPoolPkg;
    address public referencePool;

    function setUp() public virtual override {
        super.setUp();
        _deployReferencePool();
    }

    /* ----------------------------- Reference pool ----------------------------- */

    function _deployReferencePool() internal virtual {
        // 1. Deploy the constant-product pool facet (shared facets already deployed by parent).
        balancerV3ConstProdPoolFacet =
            BalancerV3ConstantProductPool_FactoryService.deployBalancerV3ConstantProductPoolFacet(create3Factory);

        // 2. Build PkgInit reusing parent's shared facets + same vault/factory/registry.
        IBalancerV3ConstantProductPoolStandardVaultPkg.PkgInit memory pkgInit;
        pkgInit.basicVaultFacet = multiAssetBasicVaultFacet;
        pkgInit.standardVaultFacet = multiAssetStandardVaultFacet;
        pkgInit.balancerV3VaultAwareFacet = balancerV3VaultAwareFacet;
        pkgInit.betterBalancerV3PoolTokenFacet = betterBalancerV3PoolTokenFacet;
        pkgInit.defaultPoolInfoFacet = defaultPoolInfoFacet;
        pkgInit.standardSwapFeePercentageBoundsFacet = standardSwapFeePercentageBoundsFacet;
        pkgInit.unbalancedLiquidityInvariantRatioBoundsFacet = unbalancedLiquidityInvariantRatioBoundsFacet;
        pkgInit.balancerV3AuthenticationFacet = balancerV3AuthenticationFacet;
        pkgInit.balancerV3ConstProdPoolFacet = balancerV3ConstProdPoolFacet;
        pkgInit.vaultRegistry = IVaultRegistryDeployment(address(indexedexManager));
        pkgInit.vaultFeeOracle = IVaultFeeOracleQuery(address(indexedexManager));
        pkgInit.balancerV3Vault = bv3Vault;
        pkgInit.diamondFactory = diamondPackageFactory;

        // 3. Deploy the package via the vault registry (owner-gated, mirrors buffer pool pkg deploy).
        vm.startPrank(owner);
        refPoolPkg = BalancerV3ConstantProductPool_FactoryService
            .deployBalancerV3ConstantProductPoolStandardVaultPkg(
                IVaultRegistryDeployment(address(indexedexManager)),
                pkgInit
            );
        vm.stopPrank();
        vm.label(address(refPoolPkg), "RefConstProdPkg");

        // 4. Deploy the reference pool over (TTA, shares) with the same rate provider on shares.
        referencePool = refPoolPkg.deployVault(_buildReferenceTokenConfigs(), address(0));
        vm.label(referencePool, "ReferenceConstProdPool");
        approveForPool(IERC20(referencePool));
    }

    function _buildReferenceTokenConfigs() internal view returns (TokenConfig[] memory tc) {
        tc = new TokenConfig[](2);
        (uint256 ttaIdx, uint256 sharesIdx) = address(tta) < address(shares) ? (0, 1) : (1, 0);
        tc[ttaIdx] = TokenConfig({
            token: tta,
            tokenType: TokenType.STANDARD,
            rateProvider: IRateProvider(address(0)),
            paysYieldFees: false
        });
        tc[sharesIdx] = TokenConfig({
            token: shares,
            tokenType: TokenType.WITH_RATE,
            rateProvider: seRateProvider,
            paysYieldFees: false
        });
    }
}
```

- [ ] **Step 2: Compile**

Run: `forge build`
Expected: compiles clean (the new abstract base is unused by any concrete test yet, but must type-check). If `multiAssetBasicVaultFacet`/`multiAssetStandardVaultFacet` are zero at this point, that's fine for compile — they're consumed at runtime in later tasks.

- [ ] **Step 3: Commit**

```bash
git add test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/comparative/bases/TestBase_StandardExchangeBufferPool_Comparative.sol docs/superpowers/plans/2026-06-19-buffer-pool-comparative-tests.md
git commit -m "test(buffer-pool): scaffold comparative base with reference const-prod pool deployment"
```

Update the Progress log: check Task 1, note any deviations.

---

### Task 2: Matched init + fee equalization + init live-balance match test

**Files:**
- Modify: `comparative/bases/TestBase_StandardExchangeBufferPool_Comparative.sol` (add init + helpers).
- Create: `comparative/StandardExchangeBufferPool_Comparative.spec.t.sol` (spec runner with first test).

**Interfaces:**
- Consumes: `referencePool`, `bufferPool`, `vault`, `router`, `IStandardExchangeBufferPool(bufferPool).virtualTTA()`, `mintTTA`, `mintShares`.
- Produces (for later tasks):
  - `function bufferEffectiveReserves() public view returns (uint256 ttaReserve, uint256 sharesReserve);`
  - `function referenceReserves() public view returns (uint256 ttaReserve, uint256 sharesReserve);`
  - `function _poolTokenIndices(address pool) internal view returns (uint256 ttaIdx, uint256 sharesIdx);`
  - reference pool initialized to match buffer pool effective reserves; both pools' static swap fee == 0.

- [ ] **Step 1: Add reserve readers, matched init, and fee equalization to the base**

Add these imports at the top of the base (alongside existing ones):

```solidity
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
```

Append inside the contract:

```solidity
    /* --------------------------- Index / reserve reads --------------------------- */

    /// @dev Returns (ttaIndex, sharesIndex) for any 2-token pool by matching the TTA address.
    function _poolTokenIndices(address pool) internal view returns (uint256 ttaIdx, uint256 sharesIdx) {
        (IERC20[] memory tokens,,,) = bv3Vault.getPoolTokenInfo(pool);
        if (address(tokens[0]) == address(tta)) {
            (ttaIdx, sharesIdx) = (0, 1);
        } else {
            (ttaIdx, sharesIdx) = (1, 0);
        }
    }

    /// @dev Buffer pool's EFFECTIVE curve reserves: virtualTTA on the TTA side and the
    ///      rate-scaled live shares balance on the shares side (the values its onSwap math sees).
    function bufferEffectiveReserves() public view returns (uint256 ttaReserve, uint256 sharesReserve) {
        (, uint256 sharesIdx) = _poolTokenIndices(bufferPool);
        uint256[] memory live = vault.getCurrentLiveBalances(bufferPool);
        ttaReserve = IStandardExchangeBufferPool(bufferPool).virtualTTA();
        sharesReserve = live[sharesIdx];
    }

    /// @dev Reference pool live (rate-scaled, 18-dec) reserves, reindexed to (tta, shares).
    function referenceReserves() public view returns (uint256 ttaReserve, uint256 sharesReserve) {
        (uint256 ttaIdx, uint256 sharesIdx) = _poolTokenIndices(referencePool);
        uint256[] memory live = vault.getCurrentLiveBalances(referencePool);
        ttaReserve = live[ttaIdx];
        sharesReserve = live[sharesIdx];
    }

    /* ----------------------------- Matched init ----------------------------- */

    /// @dev Reference pool RAW init amounts that reproduce the buffer pool's effective reserves:
    ///      raw TTA = virtualTTA (STANDARD ⇒ raw == live); raw shares = buffer pool RAW shares
    ///      (WITH_RATE, same provider ⇒ identical scaled live balance).
    function _referenceInitAmounts()
        internal
        view
        returns (uint256 rawTTA, uint256 rawShares)
    {
        (, uint256 bufSharesIdx) = _poolTokenIndices(bufferPool);
        (,, uint256[] memory bufRaw,) = bv3Vault.getPoolTokenInfo(bufferPool);
        rawTTA = IStandardExchangeBufferPool(bufferPool).virtualTTA();
        rawShares = bufRaw[bufSharesIdx];
    }
```

- [ ] **Step 2: Add `_initReferencePool()` + fee equalization, call them from `_deployReferencePool()`**

Append to the base:

```solidity
    function _initReferencePool() internal virtual {
        (uint256 rawTTA, uint256 rawShares) = _referenceInitAmounts();

        // Acquire tokens for alice: DAI for the TTA side, SE shares for the shares side.
        mintTTA(alice, rawTTA);
        // Acquire comfortably more shares than needed (identical conditions to the buffer seed),
        // then initialize with the exact target amount.
        uint256 sharesAcquired = mintShares(alice, INITIAL_SHARES_RAW * 3);
        require(sharesAcquired >= rawShares, "ref init: insufficient shares acquired");

        (uint256 ttaIdx, uint256 sharesIdx) = _poolTokenIndices(referencePool);
        (IERC20[] memory poolTokens,,,) = bv3Vault.getPoolTokenInfo(referencePool);
        uint256[] memory amounts = new uint256[](2);
        amounts[ttaIdx] = rawTTA;
        amounts[sharesIdx] = rawShares;

        vm.startPrank(alice);
        IERC20(address(dai)).approve(address(router), type(uint256).max);
        IERC20(address(seVault)).approve(address(router), type(uint256).max);
        router.initialize(referencePool, poolTokens, amounts, 0, false, bytes(""));
        vm.stopPrank();
    }

    /// @dev Force both pools to the same (zero) static swap fee so swap outputs compare on curve alone.
    function _equalizeFees() internal virtual {
        vault.manualSetStaticSwapFeePercentage(bufferPool, 0);
        vault.manualSetStaticSwapFeePercentage(referencePool, 0);
    }
```

Then in `_deployReferencePool()` add, after the `approveForPool(IERC20(referencePool));` line:

```solidity
        _initReferencePool();
        _equalizeFees();
```

- [ ] **Step 3: Create the spec runner with the init live-balance match test**

Create `comparative/StandardExchangeBufferPool_Comparative.spec.t.sol`:

```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_StandardExchangeBufferPool_Comparative
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/comparative/bases/TestBase_StandardExchangeBufferPool_Comparative.sol";

/**
 * @title StandardExchangeBufferPool_Comparative_Spec
 * @notice A/B tests: the Standard Exchange Buffer Pool vs a real BV3 constant-product pool of the
 *         same (TTA, shares) tokens sharing the same rate provider.
 */
contract StandardExchangeBufferPool_Comparative_Spec is
    TestBase_StandardExchangeBufferPool_Comparative
{
    /// @notice Both pools expose the same effective reserves immediately after matched init.
    function test_compare_init_liveBalancesMatch() public view {
        (uint256 bufTTA, uint256 bufShares) = bufferEffectiveReserves();
        (uint256 refTTA, uint256 refShares) = referenceReserves();
        assertApproxEqAbs(refTTA, bufTTA, ABS_TOL, "init TTA reserve mismatch");
        assertApproxEqAbs(refShares, bufShares, ABS_TOL, "init shares reserve mismatch");
    }
}
```

- [ ] **Step 4: Run the init test — verify it passes**

Run: `forge test --match-path "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/comparative/StandardExchangeBufferPool_Comparative.spec.t.sol" -vvv`
Expected: `test_compare_init_liveBalancesMatch` PASS.

If reserves mismatch: most likely the buffer pool's effective TTA side is not `virtualTTA` at init, or the shares index mapping is wrong. Debug by `emit log_named_uint` on `bufferEffectiveReserves()` and `referenceReserves()` and the raw `getPoolTokenInfo` arrays; do NOT loosen tolerances to force a pass — fix the matching. Record findings in the Progress log.

- [ ] **Step 5: Commit**

```bash
git add -A test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/comparative/ docs/superpowers/plans/2026-06-19-buffer-pool-comparative-tests.md
git commit -m "test(buffer-pool): matched reference-pool init, fee equalization, init reserve-match test"
```

Update the Progress log: check Task 2.

---

### Task 3: Behavior library + reference swap helper + initial-rate swap comparison

**Files:**
- Modify: `comparative/bases/TestBase_StandardExchangeBufferPool_Comparative.sol` (add `swapReferenceExactIn`).
- Create: `comparative/behaviors/Behavior_StandardExchangeBufferPool_Comparative.sol`.
- Modify: `comparative/StandardExchangeBufferPool_Comparative.spec.t.sol` (add two swap tests).

**Interfaces:**
- Consumes: `swapTTAforShares`, `swapSharesForTTA`, `referencePool`, `tta`, `shares`, `mintTTA`, `mintShares`.
- Produces:
  - `function swapReferenceExactIn(address user, IERC20 tokenIn, IERC20 tokenOut, uint256 amountIn) public returns (uint256)`
  - `Behavior_StandardExchangeBufferPool_Comparative` abstract contract with:
    - `function _base() internal view virtual returns (TestBase_StandardExchangeBufferPool_Comparative);`
    - `function behavior_compare_swap_TTAtoShares_exactIn(uint256 amountIn) public;`
    - `function behavior_compare_swap_sharesToTTA_exactIn(uint256 amountIn) public;`

- [ ] **Step 1: Add the reference swap helper and tolerance getters to the base**

Append to the base contract:

```solidity
    /// @dev EXACT_IN single-token swap through the BV3 RouterMock against the REFERENCE pool.
    function swapReferenceExactIn(
        address user,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 amountIn
    ) public returns (uint256 amountOut) {
        vm.startPrank(user);
        amountOut = router.swapSingleTokenExactIn(
            referencePool,
            tokenIn,
            tokenOut,
            amountIn,
            0,               // minAmountOut
            block.timestamp, // deadline
            false,           // wethIsEth
            bytes("")        // userData
        );
        vm.stopPrank();
    }

    // Public getters so behavior libraries can read the internal-constant tolerances.
    function ABS_TOL_() public pure returns (uint256) { return ABS_TOL; }
    function REL_TOL_() public pure returns (uint256) { return REL_TOL; }
```

- [ ] **Step 2: Write the behavior library (the failing test logic)**

The swap actor is `getAlice()` — she is the pool initializer and is guaranteed to have DAI + shares
permit2/router approvals set during `setUp` (this mirrors the existing passing swap behaviors, which
all use `tb.getAlice()`). Do NOT switch to `getBob()` — bob's approval membership in `users` is not
guaranteed.

Create `comparative/behaviors/Behavior_StandardExchangeBufferPool_Comparative.sol`:

```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_StandardExchangeBufferPool_Comparative
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/comparative/bases/TestBase_StandardExchangeBufferPool_Comparative.sol";

/**
 * @title Behavior_StandardExchangeBufferPool_Comparative
 * @notice Reusable A/B assertions comparing buffer-pool swaps to the reference const-prod pool.
 * @dev Each comparison runs the SAME swap on each pool from an identical pre-state via
 *      vm.snapshotState()/vm.revertToState(), so neither swap perturbs the other's comparison.
 */
abstract contract Behavior_StandardExchangeBufferPool_Comparative is Test {
    function _base() internal view virtual returns (TestBase_StandardExchangeBufferPool_Comparative);

    function behavior_compare_swap_TTAtoShares_exactIn(uint256 amountIn) public {
        TestBase_StandardExchangeBufferPool_Comparative tb = _base();
        address user = tb.getAlice();

        // Fund once; both branches start from the same snapshot so funding is shared.
        tb.mintTTA(user, amountIn);

        uint256 snap = vm.snapshotState();
        uint256 outBuffer = tb.swapTTAforShares(user, amountIn);
        vm.revertToState(snap);
        uint256 outRef = tb.swapReferenceExactIn(user, tb.tta(), tb.shares(), amountIn);

        _assertClose(outRef, outBuffer, "TTA->shares output mismatch");
    }

    function behavior_compare_swap_sharesToTTA_exactIn(uint256 sharesIn) public {
        TestBase_StandardExchangeBufferPool_Comparative tb = _base();
        address user = tb.getAlice();

        // Acquire comfortably more than sharesIn (mintShares input is a DAI amount, not a share
        // amount, so the share output ratio is not 1:1) and assert sufficiency before swapping.
        uint256 acquired = tb.mintShares(user, sharesIn * 3);
        require(acquired >= sharesIn, "compare: insufficient shares for swap");

        uint256 snap = vm.snapshotState();
        uint256 outBuffer = tb.swapSharesForTTA(user, sharesIn);
        vm.revertToState(snap);
        uint256 outRef = tb.swapReferenceExactIn(user, tb.shares(), tb.tta(), sharesIn);

        _assertClose(outRef, outBuffer, "shares->TTA output mismatch");
    }

    function _assertClose(uint256 a, uint256 b, string memory label) internal {
        // Tolerances are read from the base via public getters (ABS_TOL/REL_TOL are internal const).
        assertApproxEqAbs(a, b, _base().ABS_TOL_(), label);
        if (b > _base().ABS_TOL_()) {
            assertApproxEqRel(a, b, _base().REL_TOL_(), label);
        }
    }
}
```

- [ ] **Step 3: Wire the two swap tests into the spec runner**

Edit `StandardExchangeBufferPool_Comparative.spec.t.sol`:
- Change the contract declaration to inherit the behavior and implement `_base()`:

```solidity
import {
    Behavior_StandardExchangeBufferPool_Comparative
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/comparative/behaviors/Behavior_StandardExchangeBufferPool_Comparative.sol";

contract StandardExchangeBufferPool_Comparative_Spec is
    TestBase_StandardExchangeBufferPool_Comparative,
    Behavior_StandardExchangeBufferPool_Comparative
{
    function _base()
        internal
        view
        override
        returns (TestBase_StandardExchangeBufferPool_Comparative)
    {
        return TestBase_StandardExchangeBufferPool_Comparative(address(this));
    }

    function test_compare_init_liveBalancesMatch() public view {
        (uint256 bufTTA, uint256 bufShares) = bufferEffectiveReserves();
        (uint256 refTTA, uint256 refShares) = referenceReserves();
        assertApproxEqAbs(refTTA, bufTTA, ABS_TOL, "init TTA reserve mismatch");
        assertApproxEqAbs(refShares, bufShares, ABS_TOL, "init shares reserve mismatch");
    }

    /// @notice TTA->shares EXACT_IN output matches between both pools at the initial rate.
    function test_compare_swap_TTAtoShares_atInitialRate() public {
        behavior_compare_swap_TTAtoShares_exactIn(10e18);
    }

    /// @notice shares->TTA EXACT_IN output matches between both pools at the initial rate.
    function test_compare_swap_sharesToTTA_atInitialRate() public {
        behavior_compare_swap_sharesToTTA_exactIn(10e18);
    }
}
```

- [ ] **Step 4: Run the swap tests — verify pass**

Run: `forge test --match-path "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/comparative/StandardExchangeBufferPool_Comparative.spec.t.sol" -vvv`
Expected: all three tests PASS.

If outputs diverge beyond tolerance: confirm both pools' static fee is 0 (`vault.getStaticSwapFeePercentage(pool)` for each), confirm effective reserves still match pre-swap, and check the shares index mapping per pool. Fix the cause — do not widen tolerances. Record findings.

- [ ] **Step 5: Commit**

```bash
git add -A test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/comparative/ docs/superpowers/plans/2026-06-19-buffer-pool-comparative-tests.md
git commit -m "test(buffer-pool): comparative EXACT_IN swap parity at initial rate (both directions)"
```

Update the Progress log: check Task 3.

---

### Task 4: `tradeUnderlyingV2` + after-rate-change swap comparison

**Files:**
- Modify: `comparative/bases/TestBase_StandardExchangeBufferPool_Comparative.sol` (add `tradeUnderlyingV2`).
- Modify: `comparative/StandardExchangeBufferPool_Comparative.spec.t.sol` (two new tests).

**Interfaces:**
- Consumes: `uniV2Router`, `uniV2DaiUsdcPair`, `dai`, `usdc`, `seRateProvider`.
- Produces: `function tradeUnderlyingV2(uint256 daiIn) public returns (uint256 rateBefore, uint256 rateAfter);`

- [ ] **Step 1: Add the underlying-trade helper to the base**

Append to the base contract:

```solidity
    /// @dev Trade DAI->USDC on the underlying Uniswap V2 pair to shift per-LP value, moving the
    ///      rate the shared `seRateProvider` reports (seen by BOTH pools). Returns rate before/after.
    function tradeUnderlyingV2(uint256 daiIn) public returns (uint256 rateBefore, uint256 rateAfter) {
        rateBefore = seRateProvider.getRate();

        address trader = makeAddr("v2RateTrader");
        dai.mint(trader, daiIn);

        address[] memory path = new address[](2);
        path[0] = address(dai);
        path[1] = address(usdc);

        vm.startPrank(trader);
        dai.approve(address(uniV2Router), daiIn);
        uniV2Router.swapExactTokensForTokens(
            daiIn,
            1,
            path,
            trader,
            block.timestamp + 1 hours
        );
        vm.stopPrank();

        rateAfter = seRateProvider.getRate();
    }
```

NOTE: confirm the `IUniswapV2Router` interface method name is `swapExactTokensForTokens` (it is the standard V2 router signature: `swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] path, address to, uint deadline)`). If the Crane stub differs, adjust to the available swap method.

- [ ] **Step 2: Add the after-rate-change tests to the spec runner**

Append to the spec contract:

```solidity
    /// @notice After trading the underlying V2 pool, TTA->shares output still matches.
    function test_compare_swap_TTAtoShares_afterRateChange() public {
        (uint256 before_, uint256 after_) = tradeUnderlyingV2(50_000e18);
        assertTrue(after_ != before_, "rate did not move");
        behavior_compare_swap_TTAtoShares_exactIn(10e18);
    }

    /// @notice After trading the underlying V2 pool, shares->TTA output still matches.
    function test_compare_swap_sharesToTTA_afterRateChange() public {
        (uint256 before_, uint256 after_) = tradeUnderlyingV2(50_000e18);
        assertTrue(after_ != before_, "rate did not move");
        behavior_compare_swap_sharesToTTA_exactIn(10e18);
    }
```

NOTE on the trade size: the V2 pair was seeded with `V2_SEED_AMOUNT = 10_000_000e18` DAI/USDC. `50_000e18` is ~0.5% of reserves — enough to move the rate measurably while keeping both pools well within bounds. If `assertTrue(after_ != before_)` fails, increase the trade size; if a downstream swap reverts on invariant-ratio bounds, decrease it.

- [ ] **Step 3: Run the after-rate-change tests — verify pass**

Run: `forge test --match-path "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/comparative/StandardExchangeBufferPool_Comparative.spec.t.sol" -vvv`
Expected: the two new tests PASS and the rate actually moved.

- [ ] **Step 4: Commit**

```bash
git add -A test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/comparative/ docs/superpowers/plans/2026-06-19-buffer-pool-comparative-tests.md
git commit -m "test(buffer-pool): comparative swap parity after underlying V2 rate change"
```

Update the Progress log: check Task 4.

---

### Task 5: Spot-price / getRate after rate change

**Files:**
- Modify: `comparative/StandardExchangeBufferPool_Comparative.spec.t.sol` (one new test).

**Interfaces:**
- Consumes: `tradeUnderlyingV2`, `bufferEffectiveReserves`, `referenceReserves`.

- [ ] **Step 1: Add the spot-price comparison test**

The marginal (spot) price of a constant-product pool is `reserveTTA / reserveShares`. Both pools should report the same spot price after the rate moves, because their effective reserves stay matched. Append to the spec contract:

```solidity
    /// @notice After the underlying V2 trade, both pools report the same effective reserves
    ///         (hence the same marginal/spot price) without any swap between them.
    function test_compare_spotPrice_afterRateChange() public {
        (uint256 before_, uint256 after_) = tradeUnderlyingV2(50_000e18);
        assertTrue(after_ != before_, "rate did not move");

        (uint256 bufTTA, uint256 bufShares) = bufferEffectiveReserves();
        (uint256 refTTA, uint256 refShares) = referenceReserves();

        // Reserves match ⇒ spot price (ttaReserve * 1e18 / sharesReserve) matches.
        assertApproxEqAbs(refTTA, bufTTA, ABS_TOL, "post-trade TTA reserve mismatch");
        assertApproxEqAbs(refShares, bufShares, ABS_TOL, "post-trade shares reserve mismatch");

        uint256 bufSpot = (bufTTA * 1e18) / bufShares;
        uint256 refSpot = (refTTA * 1e18) / refShares;
        assertApproxEqRel(refSpot, bufSpot, REL_TOL, "post-trade spot price mismatch");
    }
```

NOTE: the buffer pool's effective TTA side (`virtualTTA`) does not change merely because the rate moved (it is stored state mutated only by swaps/LP). The shares side live balance DOES scale with the new rate. The reference pool behaves identically: raw TTA fixed, live shares scales with rate. So both stay matched — this test confirms that.

- [ ] **Step 2: Run the spot-price test — verify pass**

Run: `forge test --match-path "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/comparative/StandardExchangeBufferPool_Comparative.spec.t.sol" -vvv`
Expected: `test_compare_spotPrice_afterRateChange` PASS.

- [ ] **Step 3: Commit**

```bash
git add -A test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/comparative/ docs/superpowers/plans/2026-06-19-buffer-pool-comparative-tests.md
git commit -m "test(buffer-pool): comparative spot-price parity after underlying V2 rate change"
```

Update the Progress log: check Task 5.

---

### Task 6: Full build + spec run green + final commit

**Files:** none new — verification only.

- [ ] **Step 1: Build the whole project**

Run: `forge build`
Expected: clean compile.

- [ ] **Step 2: Run the full comparative spec**

Run: `forge test --match-path "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/comparative/*" -vvv`
Expected: all 6 tests PASS:
- `test_compare_init_liveBalancesMatch`
- `test_compare_swap_TTAtoShares_atInitialRate`
- `test_compare_swap_sharesToTTA_atInitialRate`
- `test_compare_swap_TTAtoShares_afterRateChange`
- `test_compare_swap_sharesToTTA_afterRateChange`
- `test_compare_spotPrice_afterRateChange`

- [ ] **Step 3: Confirm no regression in the sibling buffer-pool specs**

Run: `forge test --match-path "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/**" -vvv`
Expected: existing buffer-pool specs still PASS (the new base is additive; nothing else changed).

- [ ] **Step 4: Final commit + mark plan complete**

```bash
git add -A docs/superpowers/plans/2026-06-19-buffer-pool-comparative-tests.md
git commit -m "docs(plan): mark buffer-pool comparative tests complete"
```

Update the Progress log: check Task 6 and record the final commit SHA.

---

## Self-review notes (author)

- **Spec coverage:** init match (§5) → Task 2; both-direction EXACT_IN at initial rate (coverage choice) → Task 3; after-rate-change swaps (coverage choice) → Task 4; spot-price/getRate after trade (coverage choice) → Task 5; fee equalization (§6) → Task 2; reference pool with shared provider + matched reserves (§4–5) → Tasks 1–2. All approved-design items covered.
- **Deferred-by-design (out of scope per spec §11):** EXACT_OUT swaps, LP add/remove comparisons, Aerodrome variant, fuzz/invariant comparative testing.
- **Type consistency:** `referencePool` (address), `refPoolPkg` (`IBalancerV3ConstantProductPoolStandardVaultPkg`), `swapReferenceExactIn`, `tradeUnderlyingV2`, `bufferEffectiveReserves`/`referenceReserves`, `ABS_TOL_`/`REL_TOL_` getters — names consistent across tasks.
- **Known adjust-points flagged inline:** V2 router swap method name, trade size for rate movement, tolerance debugging guidance (fix cause, never widen tolerance to force green).
