// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
import {OrbitalRawLiquidityRef as Ref} from "./rawLiquidity/OrbitalRawLiquidityRef.sol";

/// @dev Non-SUT rate. Immutable so a rate-only difference is the package binding, not a hook mock.
contract StaticRawRate {
    uint256 public immutable rate;

    constructor(uint256 rate_) {
        rate = rate_;
    }

    function getRate() external view returns (uint256) {
        return rate;
    }
}

/// @notice Subsequent full-book and zap terminal ownership against an independent raw reference.
contract UniswapV4StandardExchangeOrbitalBufferHook_RawLiquidityPolicyTest is
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
{
    function _defaultPkgArgs()
        internal
        override
        returns (IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args)
    {
        args = super._defaultPkgArgs();
        args.rp0 = address(new StaticRawRate(1.5e18));
    }

    function setUp() public override {
        super.setUp();
        _setDexFee(0);
        _setUsageFee(0);
    }

    function test_subsequentFullBook_matchesRawReference_andBacks() public {
        _seedThreeLeg(200 ether);
        _assertSubsequentRaw(50 ether);
    }

    function _assertSubsequentRaw(uint256 face) internal {
        uint256 supply = IERC20(hook).totalSupply();
        uint256 expected = _expectedMint(supply, face);
        assertGt(expected, 0, "reference mint");
        (uint256 preview,,,) = orbital.previewAddLiquidity(face, face, face);
        uint256 b0 = _rawBook(0);
        uint256 localBefore = orbital.rawReserve(0);
        uint256 b1 = _rawBook(1);
        uint256 b2 = _rawBook(2);
        (uint256 minted, uint256 u0, uint256 u1, uint256 u2) = _addLiquidity(face, face, face);
        assertEq(minted, preview, "preview==exec");
        assertEq(minted, expected, "raw reference");
        uint256 gross = IERC20(hook).totalSupply() - supply;
        _assertBacks(supply, gross, b0, b1, b2);
        assertEq(orbital.rawReserve(0) - localBefore, (gross * localBefore + supply - 1) / supply, "independent local ceil");
        assertLe(u0, face);
        assertLe(u1, face);
        assertLe(u2, face);
        assertEq(orbital.effectiveReserve(0), orbital.rawReserve(0) + orbital.seBalance(0) * 1.5e18 / 1e18, "rated view preserved");
    }

    function _expectedMint(uint256 supply, uint256 face) internal view returns (uint256) {
        uint256 held = orbital.seBalance(0);
        uint256 local = orbital.rawReserve(0);
        (uint256 full,) = IStandardExchangeIn(se0).previewExchangeIn(IERC20(address(token0)), face, IERC20(se0));
        uint256 localNeeded = (full * local + held - 1) / held;
        uint256 deposited = face * face / (face + localNeeded);
        (uint256 acquired, uint256 refunded) = IStandardExchangeIn(se0).previewExchangeIn(IERC20(address(token0)), deposited, IERC20(se0));
        uint256 availableLocal = face - deposited + refunded;
        uint256 gross = Ref.min3(supply * acquired / held, supply * availableLocal / local,
            Ref.min3(supply * face / _rawBook(1), supply * face / _rawBook(2), type(uint256).max));
        uint256 fee = orbital.usageFee();
        if (orbital.feeTo() != address(0) && fee != 0 && fee < 1e18) return gross - gross * fee / 1e18;
        return gross;
    }

    function _assertBacks(uint256 supply, uint256 minted, uint256 b0, uint256 b1, uint256 b2) internal view {
        assertTrue(Ref.backs(_delivered(0, b0), supply, minted, b0), "leg0 backs");
        assertTrue(Ref.backs(_delivered(1, b1), supply, minted, b1), "leg1 backs");
        assertTrue(Ref.backs(_delivered(2, b2), supply, minted, b2), "leg2 backs");
    }

    function test_zap_paidPreparationPreservesNativeBookCustody() public {
        _seedThreeLeg(200 ether);
        uint256 amount = 30 ether;
        uint256 preview = orbital.previewDepositSingle(address(token1), amount);
        assertGt(preview, 0);
        uint256 beforeLp = IERC20(hook).balanceOf(user);
        uint256 beforeInput = token1.balanceOf(user);
        vm.prank(user);
        uint256 minted = orbital.depositSingle(address(token1), amount, user, preview, block.timestamp + 1 hours, "");
        assertEq(minted, preview);
        assertEq(IERC20(hook).balanceOf(user) - beforeLp, minted);
        assertGt(beforeInput - token1.balanceOf(user), 0);
        assertLe(beforeInput - token1.balanceOf(user), amount);
        assertEq(orbital.seBalance(0), IERC20(se0).balanceOf(hook));
        assertEq(orbital.rawReserve(0), token0.balanceOf(hook));
        assertEq(orbital.rawReserve(1), token1.balanceOf(hook));
        assertEq(orbital.rawReserve(2), token2.balanceOf(hook));
    }

    function _rawBook(uint8 i) internal view returns (uint256) {
        return orbital.isBuffered(i) ? orbital.seBalance(i) : orbital.rawReserve(i);
    }

    function _delivered(uint8 i, uint256 before) internal view returns (uint256) {
        return _rawBook(i) - before;
    }

    function _faceContribution(uint8 i, uint256 face) internal view returns (uint256) {
        address se = i == 0 ? se0 : address(0);
        address token = i == 0 ? address(token0) : i == 1 ? address(token1) : address(token2);
        if (se == address(0)) return face;(uint256 quotedAmountOut,) = IStandardExchangeIn(se).previewExchangeIn(IERC20(token), face, IERC20(se));
        return quotedAmountOut;
    }
}
