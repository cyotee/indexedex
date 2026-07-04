# DualLiquidityLinkedDETF Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the DualLiquidityLinkedDETF family per `contracts/vaults/detf/composed/dual-liquidity-linked/DualLiquidityLinkedDetf_PRD.md`: a share-based DETF whose Balancer V3 Weighted Pool reserve composes two commonToken/linked-token Uniswap V4 Standard Exchange Vaults and one tokenA/tokenB Uniswap V2 vault, with quote-and-pick-best routing, usage-fee share inflation, and an immutable diamond deployment.

**Architecture:** The diamond proxy is the DETF share token (Crane `ERC20Repo`), holds only reserve BPT, and exposes one uniform `IStandardExchangeIn`/`IStandardExchangeOut` surface where DETF shares participate as tokenIn/tokenOut: `tokenOut == shares` is a deposit, `tokenIn == shares` is a redemption, anything else is a swap routed through the legs. All quoting is delegated to the legs' own `previewExchangeIn`/`previewExchangeOut`; the DETF's only owned math is share↔BPT proportion and the usage-fee split.

**Tech Stack:** Solidity ^0.8.0, Foundry, Crane Diamond framework (Repo/Common/Target/Facet/DFPkg/FactoryService), Balancer V3, existing `UniswapV4StandardExchange*` and Uniswap V2 strategy vaults.

---

## STATUS UPDATE — 2026-07-07 (read this first)

The original tasks below are **implemented and superseded by several design changes**. This section is the source of truth for current state and remaining work; the File Structure / task list further down reflects the *original* design and is retained for history only.

**Branch:** `feat/dual-liquidity-linked-detf` · **Last commit:** `6fd2c05` (green, family suite 22/22; chain `a90ae04` → `26456be` → `6fd2c05`) · **Companion plan:** `docs/superpowers/plans/2026-07-07-dual-liquidity-linked-detf-demock-and-bootstrap.md` · **Tests:** `forge test --match-path "test/foundry/spec/vaults/detf/composed/dual-liquidity-linked/*" -vv` (whole tree recompiles ~140s; the family test tree is all-or-nothing — one non-compiling suite blocks every suite, so finish a suite before running).

### Design changes since the original plan (all DONE)
- **Reserve integration is direct** — no `IProportionalExit.sol` / `BalancerV3ProportionalExitAdapter.sol` (those files were never kept). Reserve join/exit use the Standard-Exchange router + Balancer Vault via aware repos, `prepay*` ops, and `BasePoolMath` quotes. See PRD "Reserve Integration".
- **`IDualLiquidityLinkedDetf.sol` deleted** — the bespoke family interface is gone. Errors moved into `DualLiquidityLinkedDetfRepo`; config is read from the standard vault surface (`IBasicVault.vaultTokens()` + BPT balance); USAGE fee tagged by `type(IStandardExchangeIn).interfaceId`.
- **Inert deploy + 1:1 first deposit** — the DFPkg no longer pre-mints dust shares. Deploy is inert (`totalSupply == 0`, reserve pool created but uninitialized). The reserve is bootstrapped by a **manual post-deploy procedure**; the first reserve-BPT deposit mints 1:1. Liveness split into `_requireActive` + `_requireReserveLive`. See PRD "Bootstrap".
- **Reentrancy guard** added (`nonReentrant` on `exchangeIn`/`exchangeOut`); **accrual invariant tightened to zero tolerance**.
- **Tests run on real production code** — protocol mocks removed from the deploy/bootstrap path. `MockVaultFeeOracle` and the mock `TestBase`/harness are deleted; `MockStandardExchange` is kept (shared by other families, no longer used here). Role tokens are real `ERC20PermitDFPkg` diamonds.

### Currently green (real-code suites, 22 tests)
`DualLiquidityLinkedDetf_ProductionDeploy`, `..._BootstrapDeposit`, `..._Deposits`, `..._DFPkg_Registry`, `..._MathLib` — all pass over real Uniswap V4/V2 + Balancer legs.

### Base API & gotchas for rebuilding suites (READ before writing a suite)

The abstract base is `DualLiquidityLinkedDetfProductionBase` (in `DualLiquidityLinkedDetf_ProductionDeploy.t.sol`). A route suite: `contract X is DualLiquidityLinkedDetfProductionBase`, `setUp() public override { super.setUp(); _bootstrapReserve(); }`, then real deposits. Use `DualLiquidityLinkedDetf_Deposits.t.sol` as the copy-paste template.

- **Inherited state/fields:** `address detf` (the inert-then-bootstrapped diamond); `IERC20 commonToken/tokenA/tokenB` (real `ERC20PermitDFPkg` diamonds, full supply held by the test); Balancer `vault`, `router`, `permit2`, `indexedexManager`, `owner`, `create3Factory`, `diamondPackageFactory` (from `TestBase_BalancerV3StandardExchangeRouter`).
- **Helpers:** `_bootstrapReserve()` (inert → live; returns pool-init BPT); `_reservePool()` (discovers the reserve pool via `IBasicVault.vaultTokens()` + `vault.getPoolTokens` — there is NO config getter on the diamond); `_acquireLegShare(address legVault, address to)` (mints `to` a leg share by zapping whichever underlying the leg accepts); `_deployTestToken(name,symbol,salt)`; `_fund(token,to,amount)` (transfer from the test's supply — ERC20Permit tokens have NO `.mint()`); `LEG_SEED` (1_000e18).
- **Read reserve BPT** as `IERC20(_reservePool()).balanceOf(detf)` — NOT `IBasicVault.reserveOfToken(...)` (that returns 0; the DETF tracks reserve by BPT balance, not the multi-asset reserve accounting).
- **preview == execution is EXACT on real pricing** — assert with `assertEq` (confirmed for all deposit routes). Magnitudes are real-WeightedMath-priced, so assert those relationally (`assertGt`).
- **Dust goes to `feeTo()`**, not the caller. A test asserting exact proxy/recipient balances must account for `feeTo()` receiving swept dust on multi-hop routes.
- **`alice` is already declared** by a Balancer base test (`address payable alice`) — name your actors something else (e.g. `depositor`, `redeemer`).
- **Errors** are on the `DualLiquidityLinkedDetfRepo` library: `DualLiquidityLinkedDetfRepo.ZeroAmount.selector`, `.DeadlineExpired.selector`, `.ReservePoolNotInitialized.selector`, `.UnsupportedRoute`; slippage errors are `IStandardExchangeErrors.MinAmountNotMet` / `MaxAmountExceeded`.
- **Redemptions/ExactOut** need shares first — deposit to obtain them (no `seedShares`). Recall exact-out shares→asset reverts `UnsupportedRoute` (nonlinear; use exact-in).
- **Best-route selection tests** must create a real price difference by swapping to skew a V4 pool or the V2 pair (there is no `setRate`).
- **Usage fee is the REAL oracle** (`indexedexManager.usageFeeOfVault(detf)`), not a 5% mock. Before writing fee-accounting assertions, check what it returns / how to configure it (it may be 0 by default) — otherwise fee-split tests are meaningless.
- **Reentrancy suite:** the hostile actor is `ReentrantMockERC20` (kept at `contracts/test/stubs/`). To attack, `tokenB` must BE that mock — the base deploys `tokenB` via `_deployTestToken`, so add a `virtual` tokenB seam to the base (mirroring the old `_deployTokenB()` hook) and override it in the reentrancy suite. Guard is `nonReentrant` → expect `IReentrancyLock.IsLocked`.

### DONE since this status note
- **Residual dust → `feeTo()`.** Every route now sweeps grown intermediate balances to the fee oracle's `feeTo()` (`DualLiquidityLinkedDetfCommon._sweepResidual`) instead of reverting `ResidualInventory` (not refunded to the caller, which may be a contract that can't handle a partial refund). Linked/common deposit routes work on real pricing.
- **Abstract `DualLiquidityLinkedDetfProductionBase`** extracted (in `DualLiquidityLinkedDetf_ProductionDeploy.t.sol`): setup + bootstrap/config/deposit helpers, no tests. `ProductionDeploy` (2 assertion tests), `BootstrapDeposit`, and route suites extend it.
- **Deposits suite** rebuilt on real code (`DualLiquidityLinkedDetf_Deposits.t.sol`, 7/7 green): vault-share / linked-token / common-token deposits with exact preview==execution over real pricing, pretransferred path, and guards.

### REMAINING WORK (start a new session here)
1. **Rebuild the remaining deleted suites on the real base** (each must fully compile before it can run — the family tree is all-or-nothing). Follow `DualLiquidityLinkedDetf_Deposits.t.sol` as the template (extend `DualLiquidityLinkedDetfProductionBase`, `_bootstrapReserve()` in `setUp`, real deposits + `_acquireLegShare`, relational magnitude asserts + exact preview==execution):
   - Swaps, Redemptions, ExactOut
   - Invariant (retain zero-drop ratio check), ShareInflation (1:1-first-deposit model — no genesis dust), Reentrancy (keep `ReentrantMockERC20` in the tokenB slot over the real deployment)
   - Cover explicit **and** Permit2 approval paths where the surface allows (note: the DETF pulls `tokenIn` via `safeTransferFrom`, so Permit2 applies at the leg/Balancer layer and via the `pretransferred` path, not a Permit2 signature on the DETF surface).
2. **Fork tests** against real Balancer/Uniswap on Base, and **independent audit** (the deployment is immutable and unowned).

---

## Global Constraints

- License header: `// SPDX-License-Identifier: BUSL-1.1`, pragma `^0.8.0`.
- **Naming Rule (PRD):** role names only — `commonToken`, `tokenA`, `tokenB`. The strings `WETH`, `RICH`, `RICHAI` must not appear in any contract, interface, storage name, or normative NatSpec.
- **Fresh codepath:** other DETF families are behavioral references only. Do not import their concrete contracts (shared libs `DETFUsageFeeLib`, `ERC20Repo`, interfaces are fine).
- **Immutable deployment:** the DFPkg must not install ownership or diamond-cut facets. No pause, no admin setters.
- **Usage fee on every share-minting route** (incl. direct BPT and vault-share deposits); **no DETF-level fee on swap routes**.
- **Delegated quoting:** never reimplement leg vault or pool math; compose `previewExchangeIn`/`previewExchangeOut` and reserve-router previews.
- **Preview/execution symmetry:** every state-mutating route has a preview that matches execution within rounding.
- Crane code style: storage libs bind slots via assembly; facets implement `IFacet` (`facetName`, `facetInterfaces`, `facetFuncs`, `facetMetadata`); no `new` in deployment paths (tests may use `new` for mocks); avoid viaIR — keep stack pressure low with helper functions.
- Run tests from `daosys/lib/indexedex/`: `forge test --match-path "test/foundry/spec/vaults/detf/composed/dual-liquidity-linked/*" -vv`.
- Commit after each task inside `daosys/lib/indexedex` on branch `feat/dual-liquidity-linked-detf`. End commit messages with:
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`

## File Structure

```
contracts/interfaces/
  IDualLiquidityLinkedDetf.sol                      # family interface + config getters
contracts/vaults/detf/composed/dual-liquidity-linked/
  DualLiquidityLinkedDetf_PRD.md                    # (exists)
  DualLiquidityLinkedDetfMathLib.sol                # pure share<->BPT proportion math
  DualLiquidityLinkedDetfRepo.sol                   # diamond storage
  DualLiquidityLinkedDetfCommon.sol                 # storage-bound helpers (mint w/ fee, join, exit, classify)
  IProportionalExit.sol                             # minimal proportional-exit seam
  BalancerV3ProportionalExitAdapter.sol             # IProportionalExit over the Balancer V3 router proxy
  DualLiquidityLinkedDetfExchangeInTarget.sol       # exchangeIn routes (deposits, swaps, exact-in redemptions)
  DualLiquidityLinkedDetfExchangeInFacet.sol
  DualLiquidityLinkedDetfExchangeInQueryTarget.sol  # previewExchangeIn
  DualLiquidityLinkedDetfExchangeInQueryFacet.sol
  DualLiquidityLinkedDetfExchangeOutTarget.sol      # exchangeOut (exact-out redemptions + exact-out swaps)
  DualLiquidityLinkedDetfExchangeOutFacet.sol
  DualLiquidityLinkedDetfExchangeOutQueryTarget.sol # previewExchangeOut
  DualLiquidityLinkedDetfExchangeOutQueryFacet.sol
  DualLiquidityLinkedDetfDFPkg.sol                  # package: facetCuts + initAccount + dust init
  DualLiquidityLinkedDetf_Facet_FactoryService.sol
  DualLiquidityLinkedDetf_Pkg_FactoryService.sol
  DualLiquidityLinkedDetf_Component_FactoryService.sol
  TestBase_DualLiquidityLinkedDetf.sol              # family test base (mock-leg harness + real-component harness)
contracts/test/stubs/
  MockStandardExchange.sol                          # configurable-rate IStandardExchangeIn/Out leg stub
  MockReservePool.sol                               # BPT ERC20 + join router + IProportionalExit stub
test/foundry/spec/vaults/detf/composed/dual-liquidity-linked/
  DualLiquidityLinkedDetfMathLib.t.sol
  DualLiquidityLinkedDetfExchangeIn_Deposits.t.sol
  DualLiquidityLinkedDetfExchangeIn_Swaps.t.sol
  DualLiquidityLinkedDetfExchangeIn_Redemptions.t.sol
  DualLiquidityLinkedDetfExchangeOut_ExactOut.t.sol
  DualLiquidityLinkedDetfDFPkg_Deploy.t.sol
  DualLiquidityLinkedDetf_Invariants.t.sol
```

Key existing code consumed (verified paths/signatures):

- `@crane/contracts/interfaces/IStandardExchangeIn.sol` — `previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut) → uint256 amountOut`; `exchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut, uint256 minAmountOut, address recipient, bool pretransferred, uint256 deadline) → uint256 amountOut`.
- `@crane/contracts/interfaces/IStandardExchangeOut.sol` — `previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut) → uint256 amountIn`; `exchangeOut(IERC20 tokenIn, uint256 maxAmountIn, IERC20 tokenOut, uint256 amountOut, address recipient, bool pretransferred, uint256 deadline) → uint256 amountIn`.
- `contracts/interfaces/proxies/IStandardExchangeProxy.sol` — combined In+Out proxy interface (leg vault type).
- `contracts/interfaces/IVaultFeeOracleQuery.sol` — `usageFeeOfVault(address vault) → uint256`; `feeTo() → IFeeCollectorProxy`.
- `contracts/vaults/detf/core/DETFUsageFeeLib.sol` — `_splitUsageFee(uint256 gross, uint256 feeWad) → (uint256 user, uint256 fee)`.
- `@crane/contracts/tokens/ERC20/ERC20Repo.sol` — diamond ERC20 storage/mint/burn (as used by `RebasingDETFTokenTarget.sol`).
- `@crane/contracts/factories/diamondPkg/IFacet.sol` — `facetName()`, `facetInterfaces()`, `facetFuncs()`, `facetMetadata()`.
- Behavioral references (read, do not import concretes): `contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfDFPkg.sol` (DFPkg shape), `ComposedStableCommonDetfExchangeOutQueryFacet.sol` (Balancer proportional-exit call shape), `Seigniorage_Component_FactoryService.sol` (rate-provider wiring via `StandardExchangeRateProviderDFPkg`).

---

### Task 1: Branch, family interface, and math library

**Files:**
- Create: `contracts/interfaces/IDualLiquidityLinkedDetf.sol`
- Create: `contracts/vaults/detf/composed/dual-liquidity-linked/DualLiquidityLinkedDetfMathLib.sol`
- Test: `test/foundry/spec/vaults/detf/composed/dual-liquidity-linked/DualLiquidityLinkedDetfMathLib.t.sol`

**Interfaces:**
- Consumes: `IStandardExchangeIn`, `IStandardExchangeOut`, `IERC20` (crane).
- Produces: `IDualLiquidityLinkedDetf` (extends both exchange interfaces + config getters below); `DualLiquidityLinkedDetfMathLib._sharesForBpt(uint256 bptIn, uint256 totalShares, uint256 totalBpt) → uint256`; `._bptForShares(uint256 sharesIn, uint256 totalShares, uint256 totalBpt) → uint256`.

- [ ] **Step 1: Create branch**

```bash
cd daosys/lib/indexedex && git checkout -b feat/dual-liquidity-linked-detf
```

- [ ] **Step 2: Write the failing math test**

```solidity
// test/foundry/spec/vaults/detf/composed/dual-liquidity-linked/DualLiquidityLinkedDetfMathLib.t.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {DualLiquidityLinkedDetfMathLib} from
    "contracts/vaults/detf/composed/dual-liquidity-linked/DualLiquidityLinkedDetfMathLib.sol";

contract DualLiquidityLinkedDetfMathLibTest is Test {
    function test_sharesForBpt_proportional() public pure {
        // 100 BPT into a reserve of 1000 BPT backing 2000 shares -> 200 shares
        assertEq(DualLiquidityLinkedDetfMathLib._sharesForBpt(100e18, 2000e18, 1000e18), 200e18);
    }

    function test_bptForShares_proportional() public pure {
        assertEq(DualLiquidityLinkedDetfMathLib._bptForShares(200e18, 2000e18, 1000e18), 100e18);
    }

    function test_sharesForBpt_roundsDown() public pure {
        assertEq(DualLiquidityLinkedDetfMathLib._sharesForBpt(1, 3, 2), 1); // 1*3/2 = 1.5 -> 1
    }

    function test_bptForShares_roundsDown() public pure {
        assertEq(DualLiquidityLinkedDetfMathLib._bptForShares(1, 3, 2), 0); // 1*2/3 = 0.66 -> 0
    }

    function testFuzz_roundTrip_neverProfits(uint128 bptIn, uint128 totalShares, uint128 totalBpt) public pure {
        vm.assume(totalShares > 0 && totalBpt > 0 && bptIn > 0);
        uint256 shares = DualLiquidityLinkedDetfMathLib._sharesForBpt(bptIn, totalShares, totalBpt);
        uint256 back = DualLiquidityLinkedDetfMathLib._bptForShares(shares, totalShares, totalBpt);
        assertLe(back, bptIn); // depositor can never round-trip into free BPT
    }
}
```

- [ ] **Step 3: Run to verify failure**

Run: `forge test --match-path "test/foundry/spec/vaults/detf/composed/dual-liquidity-linked/DualLiquidityLinkedDetfMathLib.t.sol" -vv`
Expected: compilation failure — `DualLiquidityLinkedDetfMathLib` not found.

- [ ] **Step 4: Implement the math library**

```solidity
// contracts/vaults/detf/composed/dual-liquidity-linked/DualLiquidityLinkedDetfMathLib.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Math} from "@crane/contracts/utils/Math.sol";

library DualLiquidityLinkedDetfMathLib {
    /// @notice Shares minted for BPT deposited, quoted BEFORE the BPT enters the reserve.
    function _sharesForBpt(uint256 bptIn_, uint256 totalShares_, uint256 totalBpt_)
        internal
        pure
        returns (uint256 shares_)
    {
        shares_ = Math.mulDiv(bptIn_, totalShares_, totalBpt_);
    }

    /// @notice BPT owed for shares burned, quoted BEFORE the shares are burned.
    function _bptForShares(uint256 sharesIn_, uint256 totalShares_, uint256 totalBpt_)
        internal
        pure
        returns (uint256 bpt_)
    {
        bpt_ = Math.mulDiv(sharesIn_, totalBpt_, totalShares_);
    }
}
```

- [ ] **Step 5: Write the family interface**

```solidity
// contracts/interfaces/IDualLiquidityLinkedDetf.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IWeightedPool} from
    "@crane/contracts/external/balancer/v3/interfaces/contracts/pool-weighted/IWeightedPool.sol";

interface IDualLiquidityLinkedDetf is IStandardExchangeIn, IStandardExchangeOut {
    error UnsupportedRoute(IERC20 tokenIn, IERC20 tokenOut);
    error ZeroAmount();
    error DeadlineExpired(uint256 deadline);
    error ReservePoolNotInitialized();
    error ResidualInventory(IERC20 token, uint256 amount);

    function commonToken() external view returns (IERC20);
    function tokenA() external view returns (IERC20);
    function tokenB() external view returns (IERC20);
    function vaultA() external view returns (IStandardExchangeProxy);
    function vaultB() external view returns (IStandardExchangeProxy);
    function pairVault() external view returns (IStandardExchangeProxy);
    function vaultAShare() external view returns (IERC20);
    function vaultBShare() external view returns (IERC20);
    function pairVaultShare() external view returns (IERC20);
    function reservePool() external view returns (IWeightedPool);
    function reserveBpt() external view returns (IERC20);
    function feeOracle() external view returns (IVaultFeeOracleQuery);
    /// @notice Total reserve BPT backing all shares (proxy's BPT balance).
    function totalReserveBpt() external view returns (uint256);
}
```

- [ ] **Step 6: Run tests to verify pass**

Run: `forge test --match-path "test/foundry/spec/vaults/detf/composed/dual-liquidity-linked/DualLiquidityLinkedDetfMathLib.t.sol" -vv`
Expected: 5 tests PASS. Also run `forge build` — the interface must compile.

- [ ] **Step 7: Commit**

```bash
git add contracts/interfaces/IDualLiquidityLinkedDetf.sol \
  contracts/vaults/detf/composed/dual-liquidity-linked/DualLiquidityLinkedDetfMathLib.sol \
  test/foundry/spec/vaults/detf/composed/dual-liquidity-linked/DualLiquidityLinkedDetfMathLib.t.sol
git commit -m "feat(detf): add DualLiquidityLinkedDetf interface and share math lib

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Repo storage, proportional-exit seam, and Common helpers

**Files:**
- Create: `contracts/vaults/detf/composed/dual-liquidity-linked/IProportionalExit.sol`
- Create: `contracts/vaults/detf/composed/dual-liquidity-linked/DualLiquidityLinkedDetfRepo.sol`
- Create: `contracts/vaults/detf/composed/dual-liquidity-linked/DualLiquidityLinkedDetfCommon.sol`
- Create: `contracts/test/stubs/MockStandardExchange.sol`
- Create: `contracts/test/stubs/MockReservePool.sol`

**Interfaces:**
- Consumes: Task 1 outputs; `ERC20Repo`; `DETFUsageFeeLib`; `IVaultFeeOracleQuery`.
- Produces:
  - `IProportionalExit.exitProportional(uint256 bptIn, address recipient) → uint256[] memory amounts` (ordered [vaultAShare, vaultBShare, pairVaultShare]).
  - `DualLiquidityLinkedDetfRepo.Storage` fields: `commonToken, tokenA, tokenB : IERC20`; `vaultA, vaultB, pairVault : IStandardExchangeProxy`; `vaultAShare, vaultBShare, pairVaultShare : IERC20`; `reservePool : IWeightedPool`; `reserveBpt : IERC20`; `reserveRouter : IStandardExchangeProxy` (vault-share ↔ BPT joins); `reserveExit : IProportionalExit`; `feeOracle : IVaultFeeOracleQuery`. Plus `_layoutStruct()` slot binding (slot string `"detf.composed.dual-liquidity-linked.repo"`) and `_initialize(...)` setter callable once (reverts `AlreadyInitialized()` if `address(reserveBpt) != 0`).
  - `DualLiquidityLinkedDetfCommon` internal helpers (all `internal`, operating on `_layoutStruct()`):
    - `_totalReserveBpt() → uint256` (reserveBpt.balanceOf(address(this)))
    - `_mintSharesForBpt(uint256 bptIn, address recipient) → uint256 userShares` — computes gross via MathLib **before** join settles, splits via `DETFUsageFeeLib._splitUsageFee(gross, feeOracle.usageFeeOfVault(address(this)))`, mints user slice to recipient and fee slice to `address(feeOracle.feeTo())` via `ERC20Repo` mint.
    - `_burnSharesForBpt(uint256 sharesIn, address from) → uint256 bptOut`
    - `_joinReserve(IERC20 vaultShareToken, uint256 amount) → uint256 bptOut` — `reserveRouter.exchangeIn(vaultShareToken, amount, reserveBpt, 0, address(this), false, block.timestamp)`
    - `_quoteJoinReserve(IERC20 vaultShareToken, uint256 amount) → uint256 bptOut` — `reserveRouter.previewExchangeIn(...)`
    - `_exitReserveProportional(uint256 bptIn) → uint256[] memory amounts` — `reserveExit.exitProportional(...)`
    - `_classify(IERC20 token) → TokenKind` enum `{ None, Shares, ReserveBpt, CommonToken, TokenA, TokenB, VaultAShare, VaultBShare, PairVaultShare }`
    - `_requireLive(uint256 deadline, uint256 amount)` — reverts `ZeroAmount`, `DeadlineExpired`, `ReservePoolNotInitialized` (when `_totalReserveBpt() == 0` or `totalSupply() == 0`).
- Mocks: `MockStandardExchange` — constructor takes `(IERC20[] tokensIn, IERC20[] tokensOut)` support matrix; `setRate(IERC20 tokenIn, IERC20 tokenOut, uint256 rateWad)`; preview returns `amountIn * rate / 1e18`; exchangeIn pulls tokenIn (unless pretransferred), mints/transfers tokenOut (mock holds pre-minted balances); exchangeOut inverse. `MockReservePool` — is itself an ERC20 ("mock BPT") + `IStandardExchangeIn` join router (mints BPT at configurable rate per vault-share token) + `IProportionalExit` (burns BPT, pays out three share tokens at configurable proportional rates).

**Steps:** (test-first against a lightweight harness contract that exposes the internal helpers)

- [ ] **Step 1: Write failing Common tests** in `DualLiquidityLinkedDetfExchangeIn_Deposits.t.sol` (started here, extended in Task 3): deploy a `CommonHarness is DualLiquidityLinkedDetfCommon` test contract exposing `initialize/mintSharesForBpt/burnSharesForBpt/classify`; assert: fee split mints `gross * fee / 1e18` shares to `feeTo` and remainder to recipient (use a `MockVaultFeeOracle` stub with settable `usageFeeOfVault=5e16` (5%) and `feeTo`); classification returns correct kinds for all nine token identities; `_requireLive` reverts on zero amount, past deadline, uninitialized reserve.
- [ ] **Step 2: Run to verify failure** (compilation: contracts missing).
- [ ] **Step 3: Implement `IProportionalExit`, `Repo`, `Common`, and the two mocks** per the Produces block. Repo mirrors the slot-binding pattern of `ComposedStableCommonDetfRepo.sol` (`bytes32 internal constant STORAGE_SLOT = keccak256("detf.composed.dual-liquidity-linked.repo");` + assembly `layoutStruct_.slot := slot_`). Common's ERC20 mint/burn goes through `ERC20Repo` exactly as `RebasingDETFTokenTarget.sol` does (read it first; import path `@crane/contracts/tokens/ERC20/ERC20Repo.sol`).
- [ ] **Step 4: Run tests to verify pass.**
- [ ] **Step 5: Commit** — `feat(detf): add DualLiquidityLinkedDetf storage, common helpers, and test mocks` (+ trailer).

---

### Task 3: Deposit routes (`exchangeIn` → shares) + previews

**Files:**
- Create: `DualLiquidityLinkedDetfExchangeInTarget.sol`, `DualLiquidityLinkedDetfExchangeInFacet.sol`, `DualLiquidityLinkedDetfExchangeInQueryTarget.sol`, `DualLiquidityLinkedDetfExchangeInQueryFacet.sol` (family dir)
- Create: `TestBase_DualLiquidityLinkedDetf.sol` (family dir) — mock-leg harness: deploys the Common harness diamond-less (plain contract inheriting the Targets), three `MockStandardExchange` legs, `MockReservePool`, `MockVaultFeeOracle`, nine ERC20 stubs, and wires `Repo._initialize`.
- Test: `DualLiquidityLinkedDetfExchangeIn_Deposits.t.sol` (extend)

**Interfaces:**
- Consumes: Task 2 helpers.
- Produces: `exchangeIn`/`previewExchangeIn` handling the four deposit routes. Route dispatch in `DualLiquidityLinkedDetfExchangeInTarget._exchangeIn` by `(kindIn, kindOut)`:
  1. `(ReserveBpt, Shares)`: pull BPT, `_mintSharesForBpt`.
  2. `(VaultAShare|VaultBShare|PairVaultShare, Shares)`: pull shares, `_joinReserve`, `_mintSharesForBpt`.
  3. `(TokenA|TokenB, Shares)`: quote candidate1 = leg V4 vault (`token → its vault share`) then `_quoteJoinReserve`; candidate2 = `pairVault` (`token → pairVaultShare`) then `_quoteJoinReserve`; execute max-BPT candidate; `_mintSharesForBpt`.
  4. `(CommonToken, Shares)`: candidateX (X∈{A,B}) = `vaultX.previewExchangeIn(common → tokenX)` → `pairVault.previewExchangeIn(tokenX → pairVaultShare)` → `_quoteJoinReserve`; execute the max-BPT chain; `_mintSharesForBpt`.
  - All routes: `_requireLive`, `minAmountOut` on final shares, residual-inventory check (`ResidualInventory` if any intermediate token balance of the proxy grew), respect `pretransferred`.
- Preview mirrors execution paths exactly, including the fee split (`previewExchangeIn` returns the **user** share slice).

**Steps:**

- [ ] **Step 1: Write failing tests** — for each of the four routes: preview == executed userShares; feeTo received the fee slice; `minAmountOut` violation reverts; route 3 & 4 pick the better candidate (set mock rates so each candidate wins in one test: e.g. `vaultA` rate 1.0 vs `pairVault` rate 1.1, then invert); zero-amount / expired-deadline / unsupported tokenIn (`UnsupportedRoute`) reverts; residual-inventory revert (configure `MockStandardExchange` to over-deliver an intermediate token).
- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement Targets + Facets.** Facets are thin: inherit Target, implement `IFacet` (`facetName() = "DualLiquidityLinkedDetfExchangeInFacet"`, `facetInterfaces() = [type(IStandardExchangeIn).interfaceId]`, `facetFuncs() = [IStandardExchangeIn.exchangeIn.selector]`; query facet exposes `previewExchangeIn`). Keep per-route logic in private helpers (`_depositBpt`, `_depositVaultShares`, `_depositLinkedToken`, `_depositCommonToken`) to control stack depth.
- [ ] **Step 4: Run tests to verify pass.**
- [ ] **Step 5: Commit** — `feat(detf): add DualLiquidityLinkedDetf deposit routes with best-of quoting` (+ trailer).

---

### Task 4: Swap routes (token ↔ token through the legs)

**Files:**
- Modify: `DualLiquidityLinkedDetfExchangeInTarget.sol`, `DualLiquidityLinkedDetfExchangeInQueryTarget.sol`
- Test: `DualLiquidityLinkedDetfExchangeIn_Swaps.t.sol`

**Interfaces:**
- Consumes: Task 3 dispatch.
- Produces: swap handling in the same `exchangeIn` surface:
  - `(TokenA, TokenB)` / `(TokenB, TokenA)`: candidate1 = `pairVault.previewExchangeIn(tokenIn → tokenOut)` direct; candidate2 = two hops `vaultIn.previewExchangeIn(tokenIn → common)` then `vaultOut.previewExchangeIn(common → tokenOut)`; execute max-output candidate.
  - `(CommonToken, TokenA|TokenB)` and `(TokenA|TokenB, CommonToken)`: single hop through that token's V4 vault.
  - **No DETF-level fee**; output goes directly to `recipient`; `minAmountOut` enforced on final output; deadline forwarded to leg calls.

**Steps:**

- [ ] **Step 1: Write failing tests** — direct-vs-two-hop selection both ways (rates arranged so each wins once); common↔token single hop; preview == execution; no share supply change during swaps (`totalSupply` unchanged); no fee shares minted; `minAmountOut` revert; `UnsupportedRoute` for (vaultShare → token) pairs not in the table.
- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement** `_swapLinked` and `_swapCommon` helpers wired into dispatch.
- [ ] **Step 4: Run tests to verify pass.**
- [ ] **Step 5: Commit** — `feat(detf): add swap aggregation routes through leg vaults` (+ trailer).

---

### Task 5: Exact-in redemption routes (shares → assets)

**Files:**
- Modify: `DualLiquidityLinkedDetfExchangeInTarget.sol`, `DualLiquidityLinkedDetfExchangeInQueryTarget.sol`
- Test: `DualLiquidityLinkedDetfExchangeIn_Redemptions.t.sol`

**Interfaces:**
- Consumes: `_burnSharesForBpt`, `_exitReserveProportional`, `_joinReserve`, leg `exchangeIn`.
- Produces: redemption handling in `exchangeIn` where `kindIn == Shares`:
  1. `(Shares, ReserveBpt)`: `_burnSharesForBpt`, transfer BPT to recipient. **Canonical full-value exit.**
  2. `(Shares, VaultAShare|VaultBShare|PairVaultShare)`: burn → `_exitReserveProportional` → transfer requested leg's amount to recipient → `_joinReserve` the other two legs' amounts back (redeposit **accrues to the reserve**: no shares minted for the re-join).
  3. `(Shares, CommonToken|TokenA|TokenB)`: burn → proportional exit → quote each leg's `previewExchangeIn(legShare → requested asset)`, redeem the **max-return** leg via its vault, send proceeds to recipient → re-join the remaining two legs' amounts.
  - `minAmountOut` applies to the user payout; previews return the actual payout (PRD disclosure rule); residual-inventory check after re-joins.

**Steps:**

- [ ] **Step 1: Write failing tests** — shares→BPT full-value round trip (deposit BPT then redeem: `back ≤ in`, equality within 1 wei rounding); shares→vault-share route pays exactly the requested leg's proportional slice and re-joins the rest (assert reserve BPT after > naive `totalBpt - bptDue`, i.e. accrual happened; assert remaining holders' BPT-per-share strictly increased); shares→asset route picks max-return leg (arrange rates so each leg wins once); preview == payout; `minAmountOut` revert; redemption while reserve uninitialized reverts.
- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement** `_redeemBpt`, `_redeemVaultShares`, `_redeemAsset` helpers.
- [ ] **Step 4: Run tests to verify pass.**
- [ ] **Step 5: Commit** — `feat(detf): add exact-in redemption routes with reserve-accruing redeposit` (+ trailer).

---

### Task 6: Exact-out surface (`exchangeOut` + preview)

**Files:**
- Create: `DualLiquidityLinkedDetfExchangeOutTarget.sol`, `DualLiquidityLinkedDetfExchangeOutFacet.sol`, `DualLiquidityLinkedDetfExchangeOutQueryTarget.sol`, `DualLiquidityLinkedDetfExchangeOutQueryFacet.sol`
- Test: `DualLiquidityLinkedDetfExchangeOut_ExactOut.t.sol`

**Interfaces:**
- Consumes: all Task 3–5 route helpers and the legs' `previewExchangeOut`/`exchangeOut`.
- Produces: `previewExchangeOut(tokenIn, tokenOut, amountOut) → amountIn` and `exchangeOut(tokenIn, maxAmountIn, tokenOut, amountOut, recipient, pretransferred, deadline) → amountIn` for every route category:
  - Deposits exact-out (`tokenOut == Shares`): invert the deposit chain with the legs' `previewExchangeOut` composed leg-by-leg; gross-up for the usage fee (`grossShares = ceil(userShares * 1e18 / (1e18 - feeWad))`); pull exactly `amountIn`, refund any pretransferred excess.
  - Redemptions exact-out (`tokenIn == Shares`): compute shares to burn for the requested payout by inverting the payout leg's `previewExchangeOut` and the proportional-exit fraction; burn computed shares (`maxAmountIn` = max shares), refund unused pretransferred shares.
  - Swaps exact-out: pick the candidate whose `previewExchangeOut` composition needs the **least** input.
- Preview/execution symmetry identical to exact-in.

**Steps:**

- [ ] **Step 1: Write failing tests** — one exact-out case per route category (deposit, vault-share redemption, asset redemption, direct swap, two-hop swap): `previewExchangeOut == executed amountIn`; recipient receives exactly `amountOut`; `maxAmountIn` violation reverts; pretransferred excess refunded to caller; fee gross-up: `feeTo` shares equal `gross - user` and user gets exactly `amountOut` shares on exact-out deposits.
- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement** the Out targets/facets (`facetInterfaces() = [type(IStandardExchangeOut).interfaceId]`), reusing Task 3–5 private helpers where execution overlaps; add inverse-quote helpers (`_quoteDepositExactOut`, `_quoteRedeemExactOut`, `_quoteSwapExactOut`).
- [ ] **Step 4: Run tests to verify pass.**
- [ ] **Step 5: Commit** — `feat(detf): add exact-out exchange surface with fee gross-up and refunds` (+ trailer).

---### Task 7: Balancer proportional-exit adapter

**Files:**
- Create: `BalancerV3ProportionalExitAdapter.sol` (family dir)
- Test: covered by Task 8's deploy/integration spec (the adapter has no mock-testable logic of its own; unit test only its ordering guarantee if constructor validation added)

**Interfaces:**
- Consumes: `IBalancerV3StandardExchangeRouterProxy` (`contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol`), `IPermit2`, `IWeightedPool`.
- Produces: `IProportionalExit.exitProportional(uint256 bptIn, address recipient) → uint256[] memory amounts` returning amounts ordered `[vaultAShare, vaultBShare, pairVaultShare]` regardless of Balancer's internal token ordering (constructor stores the index mapping).

**Steps:**

- [ ] **Step 1: Read the behavioral reference** — `contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfExchangeOutQueryFacet.sol` and its shared reserve-exit helpers, plus `contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfCommon.sol` `claimLiquidity` path, to copy the exact Balancer V3 router-proxy call shape (`removeLiquidityProportional`-equivalent, Permit2 approvals). Do not import their contracts; replicate the call pattern.
- [ ] **Step 2: Implement the adapter** — constructor `(IBalancerV3StandardExchangeRouterProxy router, IPermit2 permit2, IWeightedPool pool, IERC20[3] memory orderedShares)`; `exitProportional` pulls BPT from caller, executes the proportional exit via the router, reorders outputs to `[vaultAShare, vaultBShare, pairVaultShare]`, transfers to `recipient`, returns amounts. Reverts `ResidualInventory` if any BPT or share dust remains on the adapter.
- [ ] **Step 3: Build** — `forge build` clean.
- [ ] **Step 4: Commit** — `feat(detf): add Balancer V3 proportional exit adapter` (+ trailer).

---

### Task 8: DFPkg, factory services, and deploy spec

**Files:**
- Create: `DualLiquidityLinkedDetfDFPkg.sol`, `DualLiquidityLinkedDetf_Facet_FactoryService.sol`, `DualLiquidityLinkedDetf_Pkg_FactoryService.sol`, `DualLiquidityLinkedDetf_Component_FactoryService.sol` (family dir)
- Modify: `TestBase_DualLiquidityLinkedDetf.sol` — add real-component harness path
- Test: `DualLiquidityLinkedDetfDFPkg_Deploy.t.sol`

**Interfaces:**
- Consumes: `IDiamondFactoryPackage` (`@crane/contracts/interfaces/IDiamondFactoryPackage.sol`); DFPkg shape of `ComposedStableCommonDetfDFPkg.sol` (`PkgInit` = facet addresses injected at package construction; `PkgArgs` = per-deployment config; `facetCuts()`; `initAccount(bytes)`); `StandardExchangeRateProviderDFPkg` wiring per `Seigniorage_Component_FactoryService.sol`; weighted-pool creation via the same Balancer V3 pool factory service the seigniorage family uses.
- Produces:
  - `PkgInit { erc20Facet, exchangeInFacet, exchangeInQueryFacet, exchangeOutFacet, exchangeOutQueryFacet }` (addresses; **no ownable facet, no cut facet** — PRD immutability).
  - `PkgArgs { IERC20 commonToken; IERC20 tokenA; IERC20 tokenB; IStandardExchangeProxy vaultA; IStandardExchangeProxy vaultB; IStandardExchangeProxy pairVault; uint256[3] weights; IVaultFeeOracleQuery feeOracle; IBalancerV3StandardExchangeRouterProxy balancerV3Router; IPermit2 permit2; string name; string symbol; uint256 dustBptInit; }` — default weights `[20e16, 20e16, 60e16]` when zeroed.
  - `initAccount`: initializes ERC20 metadata, deploys the three `StandardExchangeRateProvider` instances (legs A/B denominated in `commonToken`, pair leg in `tokenA`), creates + registers the Weighted Pool with those rate providers, deploys the `BalancerV3ProportionalExitAdapter`, calls `Repo._initialize`, performs dust initialization (joins `dustBptInit` of pre-seeded vault shares and mints the resulting dust shares to the factory caller), and registers the vault with the Vault Registry + Fee Oracle exactly as the composed-stable DFPkg does.

**Steps:**

- [ ] **Step 1: Write failing deploy spec** — deploy the package via `DiamondPackageCallBackFactory` (mirror `ComposedStableCommonDetfDFPkg_Deploy.t.sol` harness setup); assert: proxy implements `IDualLiquidityLinkedDetf` + both exchange interfaces (ERC165/facet metadata); config getters return `PkgArgs` values; weights default to 20/20/60; dust shares minted and `totalReserveBpt() > 0`; **immutability**: proxy exposes no `owner()`, no `diamondCut` selector (loupe facet list contains only the five PkgInit facets + loupe), and `facetCuts()` contains no cut/ownable facet; a real deposit (commonToken route) works end-to-end against real vaults from `TestBase_VaultComponents` fixtures.
- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement DFPkg + factory services** following the three-file factory-service split used by the composed-stable family (`*_Facet_FactoryService` deploys facets via CREATE3, `*_Pkg_FactoryService` deploys the package, `*_Component_FactoryService` composes rate providers/pool/adapter). Never `new` — CREATE3 via `factory().create3(...)` with `keccak256(abi.encode(type(X).name))` salts.
- [ ] **Step 4: Run the deploy spec to verify pass.**
- [ ] **Step 5: Run the full family suite** — `forge test --match-path "test/foundry/spec/vaults/detf/composed/dual-liquidity-linked/*" -vv`. Expected: all green.
- [ ] **Step 6: Commit** — `feat(detf): add DualLiquidityLinkedDetf package with immutable deployment` (+ trailer).

---

### Task 9: Invariant and fuzz suite

**Files:**
- Test: `DualLiquidityLinkedDetf_Invariants.t.sol`

**Interfaces:**
- Consumes: mock-leg harness from `TestBase_DualLiquidityLinkedDetf`.
- Produces: a Foundry invariant handler driving random sequences of every route (all deposits, both swaps, all redemptions, both styles) with fuzzed amounts and mock rates.

**Steps:**

- [ ] **Step 1: Write the handler + invariants:**
  - `invariant_backingNeverDecreasesPerShare`: `totalReserveBpt() * 1e18 / totalSupply()` is monotonically non-decreasing across operations (fees + redemption accrual only push it up; equality allowed).
  - `invariant_noValueFromNothing`: any actor's cumulative withdrawals (in BPT terms) never exceed cumulative deposits (in BPT terms) plus received accruals.
  - `invariant_noResidualInventory`: proxy holds zero balance of commonToken, tokenA, tokenB, and all three vault-share tokens after every operation (only BPT).
  - `invariant_supplySolvency`: `totalSupply() > 0` implies `totalReserveBpt() > 0`.
- [ ] **Step 2: Run** — `forge test --match-contract DualLiquidityLinkedDetf_Invariants -vv` with default depth; fix any violations found (violations are implementation bugs — apply superpowers:systematic-debugging, do not weaken invariants).
- [ ] **Step 3: Commit** — `test(detf): add DualLiquidityLinkedDetf invariant suite` (+ trailer).

---

### Task 10: NatSpec, docs, and PRD closeout

**Files:**
- Modify: all family contracts (NatSpec passes), `DualLiquidityLinkedDetf_PRD.md` (checklist), `docs/CODEBASE_MAP.md` (add family entry if the map's vault section exists)

**Steps:**

- [ ] **Step 1: NatSpec pass** — every external function documented; the three redemption-cost disclosures required by the PRD (`Shares → Reserve BPT` is the canonical full-value exit; redeposit routes' payout previews return actual payout; redeposit accrues to reserve) stated in the NatSpec of `exchangeIn`/`exchangeOut` and the two payout route helpers. Follow `crane-natspec` skill conventions (`@custom:selector` tags).
- [ ] **Step 2: Update the PRD checklist** — mark implementation items complete; append a "Deployment Prerequisites" note (tokenA/tokenB V4 markets live; tokenA/tokenB V2 pair seeded; residual launch-time check of the tokenB pool's Doppler config).
- [ ] **Step 3: Full build + suite + lint** — `forge build && forge test --match-path "test/foundry/spec/vaults/detf/composed/dual-liquidity-linked/*"`; `npx cspell "contracts/vaults/detf/composed/dual-liquidity-linked/**"` clean.
- [ ] **Step 4: Commit** — `docs(detf): NatSpec and PRD closeout for DualLiquidityLinkedDetf` (+ trailer).

---

## Explicitly Out of Scope (first-deployment work, separate plan)

Launch-side deliverables from the PRD's non-normative section are **not** in this plan: RICH token deployment, CCA auction deployment, RICHAI purchase + V2 pair seeding, Base deployment scripts, and the live Doppler pool config check. These need their own plan once this family is merged.

## Self-Review Notes

- Spec coverage: route table (Tasks 3–6), redemption accounting + disclosures (Tasks 5, 10), guards (Tasks 2–6), immutability (Task 8), fee scope incl. exact-out gross-up (Tasks 3, 6), delegated quoting (all route tasks), rate providers + dust init (Task 8), testing section (Tasks 1–9 + invariants).
- Known judgment calls deferred to implementers with references instead of inline code: Balancer proportional-exit call shape (Task 7 Step 1 names the exact reference files) and DFPkg registration calls (Task 8 mirrors the composed-stable DFPkg, path given). Everything else has concrete signatures.
