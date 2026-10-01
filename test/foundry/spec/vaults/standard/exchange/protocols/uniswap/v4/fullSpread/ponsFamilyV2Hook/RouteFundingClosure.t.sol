// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance.sol";
import {TestBase_UniswapV4FullSpreadG3RouteFunding as Routes, TestBase_UniswapV4FullSpreadG3LinearFunding as Linear, IFullSpreadG3Reserve} from "contracts/test/bases/TestBase_UniswapV4FullSpreadG3RouteFunding.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IUniswapV4FullSpreadPonsFamilyHookLiquidReserve as Reserve} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/interfaces/IUniswapV4FullSpreadPonsFamilyHookLiquidReserve.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";

// tag::PonsRouteFundingClosureTest[]
/// @notice P G3 routes retain real registered Pons hook fee ledgers and registry proxies.
contract PonsRouteFundingClosureTest is Acceptance, Routes {
    using PoolIdLibrary for *;
    function setUp() public override(Acceptance) {
        Acceptance.setUp();
        _gStart(vault, token0, token1, address(poolManager), permit2);
    }
    function _gBootstrap() internal override { _bootstrap(); }
    function _gPoolKey() internal view override returns (PoolKey memory) { return poolKey; }
    function _gBlocked(bytes memory data_) internal override returns (bytes memory) { return _nested(data_); }
    function _gFees() internal view override returns (bytes32) {
        return keccak256(abi.encode(
            ponsHook.pendingFees(poolKey.toId(), Currency.unwrap(poolKey.currency0)),
            ponsHook.pendingFees(poolKey.toId(), Currency.unwrap(poolKey.currency1)),
            ponsHook.pendingCreatorTax(poolKey.toId(), Currency.unwrap(poolKey.currency0)),
            ponsHook.pendingCreatorTax(poolKey.toId(), Currency.unwrap(poolKey.currency1))));
    }
}
// end::PonsRouteFundingClosureTest[]

// tag::PonsLinearRouteFundingClosureTest[]
/// @notice P linear R6 domains are created through real exact-basket placement and core trades.
contract PonsLinearRouteFundingClosureTest is Acceptance, Linear {
    using PoolIdLibrary for *;
    function _decimalsA() internal pure override returns (uint8) { return 6; }
    function _decimalsB() internal pure override returns (uint8) { return 6; }
    function _gBlocked(bytes memory data_) internal override returns (bytes memory) { return _nested(data_); }
    function _gFees() internal view override returns (bytes32) {
        return keccak256(abi.encode(
            ponsHook.pendingFees(poolKey.toId(), Currency.unwrap(poolKey.currency0)),
            ponsHook.pendingFees(poolKey.toId(), Currency.unwrap(poolKey.currency1)),
            ponsHook.pendingCreatorTax(poolKey.toId(), Currency.unwrap(poolKey.currency0)),
            ponsHook.pendingCreatorTax(poolKey.toId(), Currency.unwrap(poolKey.currency1))));
    }
    function _gOneSided(uint256 face_) internal override {
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultLiquidReservePercentageOfTypeId(type(Reserve).interfaceId, 0);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultLiquidReservePercentage(0);
        vm.stopPrank();
        poolKey.tickSpacing = 20;
        ponsHook.registerPool(poolKey, address(token1), address(this), address(this),
            _creatorTaxBps(), false, ponsHook.currentFeePolicy());
        uint160 price = TickMath.getSqrtPriceAtTick(face_ == 0 ? int24(-60) : int24(60));
        poolManager.initialize(poolKey, price);
        _seedPool(1e12);
        vault = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(poolKey));
        token0.approve(address(vault), type(uint256).max);
        token1.approve(address(vault), type(uint256).max);
        _gStart(vault, token0, token1, address(poolManager), permit2);
        _gFundLinearBasket(face_, price, poolKey.tickSpacing);
        _externalSwap(face_ == 0, 5e31);
        IFullSpreadG3Reserve(address(vault)).rebalanceLiquidReserve();
        _assertBooked();
    }
}
// end::PonsLinearRouteFundingClosureTest[]
