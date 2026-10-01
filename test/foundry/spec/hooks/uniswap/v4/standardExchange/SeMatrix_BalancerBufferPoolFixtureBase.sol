// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultMain} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IVaultMain.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";

/**
 * @title ISeMatrixBalancerHarness
 * @notice Uniform view over one Balancer V3 buffer-pool TestBase. A `SeMatrix_<Family>Fixture`
 *         deploys the harness with `new` and drives it through `matrixProtocol` (WP6; PRD M6, M10,
 *         section 11).
 * @dev Every member is prefixed `matrix` so it cannot collide with a TestBase state variable or
 *      helper (`pool`, `router`, `vault`, `bufferToken(uint256)`, ...).
 */
interface ISeMatrixBalancerHarness {
    /// @notice Runs the family TestBase `setUp` in full, in this order: Balancer V3 VaultMock +
    ///         RouterMock + permit2 (`_deployVault`), nested IndexedEx manager (`IndexedexTest.setUp`),
    ///         Aerodrome SE legs (`_deploySEVault`), rate provider, pool facets + package + pool
    ///         (`_deployBufferPool`; the package `postDeploy` registers the pool), then
    ///         `router.initialize` (`_initPool`, M10). Returns with the pool live.
    /// @param existingPkg Optional pool package to reuse instead of deploying one; address(0) deploys.
    function matrixProtocol(address existingPkg) external;

    function matrixPool() external view returns (address);

    function matrixPkg() external view returns (address);

    /// @notice Leg-0 Aerodrome Standard Exchange. Its share token is the face token.
    function matrixLegSe() external view returns (address);

    /// @notice Leg-0 buffer token (the DAI test token). It is a virtual pool token on the pool's
    ///         native BPT route, so it is not an SE input; exposed for diagnostics only.
    function matrixBufferToken() external view returns (address);

    function matrixBalancerVault() external view returns (address);

    function matrixBalancerRouter() external view returns (address);

    /// @notice Mint leg-0 SE shares to `recipient` through the real Aerodrome LP -> SE deposit path
    ///         (`mintShares` / `mintSharesForVault(0, ..)` / `mintSharesForPair(0, ..)`).
    function matrixMintLegShares(address recipient, uint256 tokenAmount) external returns (uint256 sharesOut);

    /// @notice The pool's booked buffer view (`virtualTTA()` / `virtualBuffer()`), Vault scaled18.
    function matrixBufferBooked() external view returns (uint256);
}

/**
 * @title SeMatrix_BalancerBufferPoolFixtureBase
 * @notice Shared body of the six Balancer V3 buffer-pool SE fixtures (WP6). The SE is the pool
 *         diamond itself: its own BPT is the SE share (D38) and its native Standard Exchange route
 *         (`BalancerV3PoolStandardExchangeTarget`) joins and exits through the real Vault
 *         `addLiquidity` / `removeLiquidity`.
 *
 * @dev Face token. `BalancerV3PoolStandardExchangeTarget.getTokensIn()` excludes the virtual buffer
 *      token (`ttaToken()` / `bufferToken()` / `bufferToken(i)`), so the buffer token (DAI) is not a
 *      valid `tokenIn` for `tokenOut == pool` and `previewExchangeIn(dai, x, pool)` reverts
 *      `InvalidRoute`. The face is therefore the leg-0 Aerodrome SE share, which is a physical pool
 *      token, 18 decimals (Aerodrome SE shares keep the LP decimals with offset 0), and a member of
 *      the pool's `vaultTokens()`.
 *
 *      Deployment order (M10 / section 11). The harness runs the family TestBase `setUp` inside this
 *      fixture's constructor, i.e. inside the hook test's `setUp`, with no Vault or PoolManager lock
 *      held: Vault + router, nested IndexedEx manager, Aerodrome SE legs, rate provider, package,
 *      pool, `router.initialize`. Only after that does the hook TestBase deploy the hook.
 *
 *      Handles. The harness is a `new`-deployed TestBase, so `InitDevService.initEnv(address(this))`
 *      gives it its own CREATE3 factory and IndexedEx manager (the shared factory's `deployFacet` is
 *      `onlyOwnerOrOperator`, and the hook test contract owns it). `Ctx.owner` equals the harness
 *      owner (`makeAddr("owner")`). The single-CP package validates the SE by arguments and decimals,
 *      not by registry membership (`_validateArgs`), so a pool registered on the harness manager binds.
 *
 *      R14. No partial case: the native BPT route takes exactly the input or reverts
 *      (`PoolLiquidityFundingMismatch`), and `pretransferred = true` is rejected
 *      (`UnsupportedPoolPretransfer`); the hook uses the pull route. `seBooked()` is 0 because the
 *      pool keeps no face-token book; the buffer-token view is exposed as `bufferBooked()`.
 *
 *      Operative failure. `armOperativeRevert` mocks two pool dependencies, never the pool, hook,
 *      package or registry: the leg-0 Aerodrome SE `exchangeIn` (the fold the pool hooks perform on
 *      buffer reconciliation) and the Balancer VaultMock `addLiquidity` / `removeLiquidity` (the
 *      calls `executePoolLiquidity` makes inside `Vault.unlock`). `Vault.unlock` uses
 *      `Address.functionCall`, which bubbles the callback revert bytes unchanged, so the pool and
 *      then the hook revert with `rejectBytes()`. Previews touch neither selector.
 */
abstract contract SeMatrix_BalancerBufferPoolFixtureBase is SeMatrixFixture {
    ISeMatrixBalancerHarness public harness;
    address internal poolDiamond;
    address internal legShare;
    address internal poolPkg;
    address public balancerVault;
    address public balancerRouter;

    /// @dev Holds minted leg shares so `fund` can hand out exact raw amounts.
    address internal constant SHARE_TREASURY = address(uint160(uint256(keccak256("SeMatrix.balancer.share-treasury"))));

    constructor(Ctx memory c) SeMatrixFixture(c) {}

    /// @dev Stand the pool up (full TestBase order, `router.initialize` included) and record handles.
    function _bind(ISeMatrixBalancerHarness h, address existingPkg) internal {
        h.matrixProtocol(existingPkg);
        harness = h;
        poolDiamond = h.matrixPool();
        legShare = h.matrixLegSe();
        poolPkg = h.matrixPkg();
        balancerVault = h.matrixBalancerVault();
        balancerRouter = h.matrixBalancerRouter();
    }

    /* ------------------------------ handles ------------------------------- */

    function pkg() external view returns (address) {
        return poolPkg;
    }

    /// @notice Leg-0 Aerodrome SE (a dependency of the pool, not the SUT); equals `faceToken()`.
    function legStandardExchange() external view returns (address) {
        return legShare;
    }

    /// @notice Leg-0 buffer token (DAI). Virtual on the native BPT route; not the face.
    function bufferToken() external view returns (address) {
        return harness.matrixBufferToken();
    }

    /// @notice Pool booked buffer view (`virtualTTA()` / `virtualBuffer()`), Vault scaled18.
    function bufferBooked() external view returns (uint256) {
        return harness.matrixBufferBooked();
    }

    /* ------------------------------ identity ------------------------------ */

    function faceToken() public view override returns (address) {
        return legShare;
    }

    function se() public view override returns (address) {
        return poolDiamond;
    }

    /* ------------------------------- funding ------------------------------ */

    /// @notice Give `to` exactly `amount` raw leg-0 SE shares, minted through the real Aerodrome
    ///         LP -> SE deposit path into a treasury and then transferred.
    function fund(address to, uint256 amount) external override {
        uint256 bal = IERC20(legShare).balanceOf(SHARE_TREASURY);
        uint256 rounds;
        while (bal < amount) {
            uint256 need = amount - bal;
            harness.matrixMintLegShares(SHARE_TREASURY, need + need / 10 + 1e18);
            bal = IERC20(legShare).balanceOf(SHARE_TREASURY);
            if (++rounds > 8) revert("balancer fixture: leg share mint did not converge");
        }
        vm.prank(SHARE_TREASURY);
        IERC20(legShare).transfer(to, amount);
    }

    /* ---------------------------- R14 partial case ------------------------ */

    function hasPartialCase() external pure override returns (bool) {
        return false;
    }

    function limitCapacity(uint256) external pure override {
        revert("balancer pool: no partial case (D38 native BPT route takes exact input)");
    }

    function openCapacity() external override {}

    /// @notice 0: the pool keeps no face-token book. See `bufferBooked()` for the buffer view.
    function seBooked() external view override returns (uint256) {
        return 0;
    }

    /* --------------------------- operative failure ------------------------ */

    function armOperativeRevert() external override {
        bytes memory reason = rejectBytes();
        vm.mockCallRevert(legShare, abi.encodeWithSelector(IStandardExchangeIn.exchangeIn.selector), reason);
        vm.mockCallRevert(balancerVault, abi.encodeWithSelector(IVaultMain.addLiquidity.selector), reason);
        vm.mockCallRevert(balancerVault, abi.encodeWithSelector(IVaultMain.removeLiquidity.selector), reason);
    }

    function disarmOperativeRevert() external override {
        vm.clearMockedCalls();
    }

    /* --------------------------------- AMM -------------------------------- */

    /// @dev A single-token exit of more than ~30% of the pool trips Balancer's minimum invariant ratio
    ///      (`InvariantRatioBelowMin(0, 0.7e18)` on the hook's full-claim valuation); keep the hook small.
    function seedFaceUnits() external pure override returns (uint256) {
        return 5;
    }

    function isAmm() external pure override returns (bool) {
        return false;
    }
}
