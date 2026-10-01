// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {Actions} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Actions.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";

interface IFullSpreadNativeImport {
    error UniswapV4ExchangeIn_SlippageExceeded();
    function importPosition(IPositionManager, uint256, uint256, address, address, uint256) external returns (uint256);
}

// tag::TestBase_UniswapV4FullSpreadNativeImport[]
/// @notice Uses an independent real NFT withdrawal to measure import funding, not vault pricing.
abstract contract TestBase_UniswapV4FullSpreadNativeImport is Test {
    using PoolIdLibrary for PoolKey;
    IStandardExchangeProxy internal importVault;
    IPoolManager internal importManager;
    IPositionManager internal importPositions;
    IPermit2 internal importPermit;
    IWETH internal importWeth;
    PoolKey internal importKey;
    IERC20 internal importToken;

    struct Funding { uint256 id; uint256 nativeAmount; uint256 tokenAmount; uint256 shares; }

    function _startImport(IStandardExchangeProxy vault_, IPoolManager manager_, IPositionManager positions_,
        IPermit2 permit_, IWETH weth_, PoolKey memory key_) internal
    {
        importVault = vault_; importManager = manager_; importPositions = positions_;
        importPermit = permit_; importWeth = weth_; importKey = key_;
        require(Currency.unwrap(key_.currency0) == address(0), "native import fixture");
        importToken = IERC20(Currency.unwrap(key_.currency1));
        assertEq(vault_.totalSupply(), 0);
    }

    function _nativeImportFundingAndDonationExclusion() internal {
        Funding memory funding = _mintAndMeasure();
        uint256 snapshot = vm.snapshotState();
        uint256 noDonation = _executeImport(funding, 0, 0);
        assertTrue(vm.revertToStateAndDelete(snapshot));
        uint256 donation0 = funding.nativeAmount / 3 + 1;
        uint256 donation1 = funding.tokenAmount / 5 + 1;
        _donateImportSleeve(donation0, donation1);
        uint256 withDonation = _executeImport(funding, donation0, donation1);
        assertEq(withDonation, noDonation, "prior sleeve cannot increase caller credit");
    }

    function _nativeImportRollback() internal {
        Funding memory funding = _mintAndMeasure();
        _donateImportSleeve(1e12, 1e12);
        uint128 liquidity = uint128(importPositions.getPositionLiquidity(funding.id));
        bytes32 beforeState = _importFingerprint(funding.id);
        vm.expectRevert(IFullSpreadNativeImport.UniswapV4ExchangeIn_SlippageExceeded.selector);
        IFullSpreadNativeImport(address(importVault)).importPosition(importPositions, funding.id,
            funding.shares + 1, address(this), address(this), block.timestamp);
        assertEq(_importFingerprint(funding.id), beforeState, "late minimum guard must roll back NFT removal and wrapping");
        assertEq(importPositions.getPositionLiquidity(funding.id), liquidity);
        assertEq(IERC721(address(importPositions)).ownerOf(funding.id), address(this));
        assertEq(importVault.totalSupply(), 0);
        _executeImport(funding, 1e12, 1e12);
    }

    function _mintAndMeasure() private returns (Funding memory funding_) {
        funding_.id = _mintNativePosition();
        uint256 liquidity = importPositions.getPositionLiquidity(funding_.id);
        assertGt(liquidity, 0);
        uint256 snapshot = vm.snapshotState();
        uint256 beforeEth = address(this).balance;
        uint256 beforeToken = importToken.balanceOf(address(this));
        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(funding_.id, liquidity, uint128(0), uint128(0), bytes(""));
        params[1] = abi.encode(importKey.currency0, importKey.currency1, address(this));
        importPositions.modifyLiquidities(abi.encode(
            abi.encodePacked(uint8(Actions.DECREASE_LIQUIDITY), uint8(Actions.TAKE_PAIR)), params), block.timestamp);
        funding_.nativeAmount = address(this).balance - beforeEth;
        funding_.tokenAmount = importToken.balanceOf(address(this)) - beforeToken;
        assertTrue(vm.revertToStateAndDelete(snapshot));
        assertGt(funding_.nativeAmount, 0); assertGt(funding_.tokenAmount, 0);
        uint256 raw = Math.sqrt(funding_.nativeAmount * funding_.tokenAmount);
        assertGt(raw, 1e15, "18/18 activation minimum");
        funding_.shares = raw - 1e15;
        IERC721(address(importPositions)).approve(address(importVault), funding_.id);
    }

    function _mintNativePosition() private returns (uint256 id_) {
        uint128 nativeBudget = 0.01 ether;
        uint128 tokenBudget = 1_000 ether;
        importToken.approve(address(importPermit), tokenBudget);
        importPermit.approve(address(importToken), address(importPositions), tokenBudget, type(uint48).max);
        (uint160 price, int24 tick,,) = StateLibrary.getSlot0(importManager, importKey.toId());
        int24 spacing = importKey.tickSpacing;
        int24 aligned = tick / spacing;
        if (tick < 0 && tick % spacing != 0) --aligned;
        aligned *= spacing;
        int24 lower = aligned - 2 * spacing;
        int24 upper = aligned + 2 * spacing;
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(price,
            TickMath.getSqrtPriceAtTick(lower), TickMath.getSqrtPriceAtTick(upper), nativeBudget - 10, tokenBudget - 10);
        id_ = importPositions.nextTokenId();
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(importKey, lower, upper, uint256(liquidity), nativeBudget, tokenBudget, address(this), bytes(""));
        params[1] = abi.encode(importKey.currency0, importKey.currency1);
        params[2] = abi.encode(Currency.wrap(address(0)), address(this));
        uint256 beforeEth = address(this).balance;
        uint256 beforeToken = importToken.balanceOf(address(this));
        importPositions.modifyLiquidities{value: nativeBudget}(abi.encode(
            abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR), uint8(Actions.SWEEP)), params), block.timestamp);
        assertGt(beforeEth - address(this).balance, 0); assertLe(beforeEth - address(this).balance, nativeBudget);
        assertGt(beforeToken - importToken.balanceOf(address(this)), 0); assertLe(beforeToken - importToken.balanceOf(address(this)), tokenBudget);
        assertEq(address(importPositions).balance, 0);
        assertEq(IERC721(address(importPositions)).ownerOf(id_), address(this));
        assertEq(importPositions.getPositionLiquidity(id_), liquidity);
    }

    function _donateImportSleeve(uint256 nativeFace_, uint256 token_) private {
        importWeth.deposit{value: nativeFace_}();
        importWeth.transfer(address(importVault), nativeFace_);
        importToken.transfer(address(importVault), token_);
    }

    function _executeImport(Funding memory funding_, uint256 donation0_, uint256 donation1_) private returns (uint256 received_) {
        uint256 sink0 = Math.mulDiv(donation0_, funding_.shares, funding_.nativeAmount, Math.Rounding.Ceil);
        uint256 sink1 = Math.mulDiv(donation1_, funding_.shares, funding_.tokenAmount, Math.Rounding.Ceil);
        uint256 sink = 1e15 + Math.max(sink0, sink1);
        received_ = IFullSpreadNativeImport(address(importVault)).importPosition(importPositions, funding_.id,
            funding_.shares, address(this), address(this), block.timestamp);
        assertEq(received_, funding_.shares);
        assertEq(importVault.balanceOf(address(this)), funding_.shares);
        assertEq(importVault.balanceOf(address(0xdEaD)), sink);
        assertEq(importVault.totalSupply(), funding_.shares + sink);
        assertEq(importPositions.getPositionLiquidity(funding_.id), 0);
        assertEq(IERC721(address(importPositions)).ownerOf(funding_.id), address(importVault));
        (uint128 liquidity,,) = StateLibrary.getPositionInfo(importManager, importKey.toId(), address(importVault),
            TickMath.minUsableTick(importKey.tickSpacing), TickMath.maxUsableTick(importKey.tickSpacing), bytes32(0));
        assertGt(liquidity, 0, "full-range backing must exist");
        assertEq(importVault.reserveOfToken(address(importWeth)), importWeth.balanceOf(address(importVault)));
        assertEq(importVault.reserveOfToken(address(importToken)), importToken.balanceOf(address(importVault)));
        assertEq(importVault.reserveOfToken(address(importVault)), importVault.balanceOf(address(importVault)));
        assertEq(address(importVault).balance, 0);
    }

    function _importFingerprint(uint256 id_) private view returns (bytes32) {
        (uint160 price, int24 tick, uint24 protocolFee, uint24 lpFee) = StateLibrary.getSlot0(importManager, importKey.toId());
        return keccak256(abi.encode(price, tick, protocolFee, lpFee, StateLibrary.getLiquidity(importManager, importKey.toId()),
            importPositions.getPositionLiquidity(id_), IERC721(address(importPositions)).ownerOf(id_),
            importWeth.balanceOf(address(importVault)), importToken.balanceOf(address(importVault)),
            address(importVault).balance, address(importPositions).balance, importVault.totalSupply()));
    }
}
// end::TestBase_UniswapV4FullSpreadNativeImport[]
