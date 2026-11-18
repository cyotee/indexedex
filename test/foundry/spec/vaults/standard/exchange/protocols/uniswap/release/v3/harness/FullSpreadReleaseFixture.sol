// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {SqrtPriceMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/SqrtPriceMath.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IUniswapV3FullSpreadStandardExchangeVault as Family} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVault.sol";
import {IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve as FeeIdentity} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.sol";
import {IStandardExchangeBundleIn, IStandardExchangeBundleOut} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";
import {TestBase_UniswapV3FullSpreadStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadStandardExchangeVault.sol";

/// @notice Real registry/pool fixture shared by migrated release regressions.
/// @dev V3-ACC-02/03/09/11: expectations read pool positions, not the vault planner.
abstract contract FullSpreadReleaseFixture is TestBase_UniswapV3FullSpreadStandardExchangeVault {
    IUniswapV3Pool internal pool;
    IStandardExchangeProxy internal vault;
    IERC20 internal token0;
    IERC20 internal token1;
    address internal alice;
    address internal bob;

    function setUp() public virtual override {
        super.setUp();
        alice = makeAddr("release alice");
        bob = makeAddr("release bob");
        ERC20PermitMintableStub a = new ERC20PermitMintableStub("Token A", "A", 18, address(this), 0);
        ERC20PermitMintableStub b = new ERC20PermitMintableStub("Token B", "B", 18, address(this), 0);
        pool = _createPoolOneToOne(address(a), address(b), FEE_MEDIUM);
        _seedExternalLiquidity(pool, 50_000_000e18);
        vault = _deployVault(pool);
        token0 = IERC20(pool.token0());
        token1 = IERC20(pool.token1());
        vm.startPrank(owner);
        IVaultFeeOracleManager fees = IVaultFeeOracleManager(address(indexedexManager));
        fees.setDefaultUsageFee(0);
        fees.setDefaultUsageFeeOfTypeId(type(FeeIdentity).interfaceId, 0);
        fees.setUsageFeeOfVault(address(vault), 0);
        vm.stopPrank();
    }

    function _amounts(uint256 a0, uint256 a1) internal pure returns (uint256[] memory amounts) {
        amounts = new uint256[](2);
        amounts[0] = a0;
        amounts[1] = a1;
    }

    function _tokens() internal view returns (address[] memory tokens) {
        tokens = new address[](2);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
    }

    function _fund(IERC20 token, address account, uint256 amount) internal {
        ERC20PermitMintableStub(address(token)).mint(account, amount);
    }

    function _join(uint256 a0, uint256 a1) internal returns (uint256 shares) {
        return _joinFor(a0, a1, address(this));
    }

    function _joinFor(uint256 a0, uint256 a1, address recipient) internal returns (uint256 shares) {
        _fund(token0, address(this), a0);
        _fund(token1, address(this), a1);
        token0.approve(address(vault), a0);
        token1.approve(address(vault), a1);
        (shares,) = IStandardExchangeBundleIn(address(vault)).exchangeBundleInForSingleOut(
            _amounts(a0, a1), address(vault), 0, recipient, false, block.timestamp
        );
    }

    function _mintOne(IERC20 input, uint256 amount, address recipient)
        internal returns (uint256 shares, uint256 refund)
    {
        _fund(input, address(this), amount);
        input.approve(address(vault), amount);
        return vault.exchangeIn(input, amount, IERC20(address(vault)), 0, recipient, false, block.timestamp);
    }

    function _bundleExit(uint256 shares) internal returns (uint256[] memory output) {
        (output,) = IStandardExchangeBundleOut(address(vault)).exchangeBundleOut(
            address(vault), shares, _tokens(), _amounts(0, 0), address(this), false, block.timestamp
        );
    }

    function _ticks() internal view returns (int24 lower, int24 upper) {
        lower = TickMath.minUsableTick(pool.tickSpacing());
        upper = TickMath.maxUsableTick(pool.tickSpacing());
    }

    function _key() internal view returns (bytes32) {
        (int24 lower, int24 upper) = _ticks();
        return keccak256(abi.encodePacked(address(vault), lower, upper));
    }

    function _liquidity() internal view returns (uint128 liquidity) {
        (liquidity,,,,) = pool.positions(_key());
    }

    function _principal(uint128 liquidity) internal view returns (uint256 a0, uint256 a1) {
        return _positionAmounts(liquidity, false);
    }

    function _mintCost(uint128 liquidity) internal view returns (uint256 a0, uint256 a1) {
        return _positionAmounts(liquidity, true);
    }

    function _positionAmounts(uint128 liquidity, bool roundUp) private view returns (uint256 a0, uint256 a1) {
        (uint160 price,,,,,,) = pool.slot0();
        (int24 lower, int24 upper) = _ticks();
        uint160 low = TickMath.getSqrtRatioAtTick(lower);
        uint160 high = TickMath.getSqrtRatioAtTick(upper);
        if (price <= low) a0 = SqrtPriceMath.getAmount0Delta(low, high, liquidity, roundUp);
        else if (price >= high) a1 = SqrtPriceMath.getAmount1Delta(low, high, liquidity, roundUp);
        else {
            a0 = SqrtPriceMath.getAmount0Delta(price, high, liquidity, roundUp);
            a1 = SqrtPriceMath.getAmount1Delta(low, price, liquidity, roundUp);
        }
    }

    function _fees() internal view returns (uint256 a0, uint256 a1) {
        (int24 lower, int24 upper) = _ticks();
        (uint128 liquidity, uint256 last0, uint256 last1, uint128 owed0, uint128 owed1) = pool.positions(_key());
        (, int24 tick,,,,,) = pool.slot0();
        (,, uint256 low0, uint256 low1,,,,) = pool.ticks(lower);
        (,, uint256 high0, uint256 high1,,,,) = pool.ticks(upper);
        uint256 inside0;
        uint256 inside1;
        unchecked {
            if (tick < lower) { inside0 = low0 - high0; inside1 = low1 - high1; }
            else if (tick >= upper) { inside0 = high0 - low0; inside1 = high1 - low1; }
            else {
                inside0 = pool.feeGrowthGlobal0X128() - low0 - high0;
                inside1 = pool.feeGrowthGlobal1X128() - low1 - high1;
            }
            a0 = owed0 + FullMath.mulDiv(inside0 - last0, liquidity, uint256(1) << 128);
            a1 = owed1 + FullMath.mulDiv(inside1 - last1, liquidity, uint256(1) << 128);
        }
    }

    function _assertReserves() internal view {
        (uint256 a0, uint256 a1) = _principal(_liquidity());
        (uint256 f0, uint256 f1) = _fees();
        assertEq(vault.reserveOfToken(address(token0)), a0 + f0, "principal plus unpaid token0 fees");
        assertEq(vault.reserveOfToken(address(token1)), a1 + f1, "principal plus unpaid token1 fees");
    }

    function _state(address actor) internal view returns (bytes32) {
        uint256[9] memory custody;
        custody[0] = vault.totalSupply();
        custody[1] = vault.balanceOf(actor);
        custody[2] = vault.balanceOf(address(vault));
        custody[3] = token0.balanceOf(actor);
        custody[4] = token1.balanceOf(actor);
        custody[5] = token0.balanceOf(address(vault));
        custody[6] = token1.balanceOf(address(vault));
        custody[7] = token0.balanceOf(address(pool));
        custody[8] = token1.balanceOf(address(pool));
        bytes32 position;
        {
            (uint128 liquidity, uint256 growth0, uint256 growth1, uint128 owed0, uint128 owed1) = pool.positions(_key());
            position = keccak256(abi.encode(liquidity, growth0, growth1, owed0, owed1));
        }
        (uint160 price, int24 tick,,,,, bool unlocked) = pool.slot0();
        return keccak256(abi.encode(custody, position, price, tick, unlocked));
    }

    function _liveOwner() internal view returns (address) {
        return address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
    }

    function _compound() internal {
        vm.prank(_liveOwner());
        Family(address(vault)).compound();
    }

    function _disable(bool disabled) internal {
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(address(vault), disabled);
    }
}
