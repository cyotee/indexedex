// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage as IPkg
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {HookPkgArgsDecimalsLib} from "contracts/test/libs/HookPkgArgsDecimalsLib.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_FullSpreadV4Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol";

interface IFullSpreadCpTuple {
    function previewExchangeIn(address tokenIn, uint256 amountIn, address tokenOut)
        external
        view
        returns (uint256 amountOut, uint256 amountRefunded);

    function exchangeIn(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut, uint256 amountRefunded);
}

/// @notice Constant-product single row. Does not override setUp.
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault is
    UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior
{
    address internal sharedPkg;

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_FullSpreadV4Fixture f = new SeMatrix_FullSpreadV4Fixture(_ctx(), sharedPkg);
        sharedPkg = f.pkg();
        return f;
    }

    function test_row_exactOutAbsent() public {
        assertEq(IStandardExchangeOut(seUT).previewExchangeOut(IERC20(face), IERC20(seUT), _f(1)), 0);
        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        IStandardExchangeOut(seUT).exchangeOut(
            IERC20(face), _f(1), IERC20(seUT), 0, address(this), false, block.timestamp
        );
    }

    function test_row_rateTarget_currency1() public {
        SeMatrix_FullSpreadV4Fixture v4_ = SeMatrix_FullSpreadV4Fixture(address(fx));
        IPkg.PkgArgs memory args_ = _rowPkgArgs();
        args_.pairToken = v4_.otherToken();
        args_.pairTokenDecimals = HookPkgArgsDecimalsLib.tokenDec(args_.pairToken);
        args_.rateProvider = v4_.currency1Provider();
        _deployRowHook(args_);
        assertEq(single.pairToken(), v4_.otherToken(), "second pool uses currency1");
        assertEq(single.standardExchange(), seUT, "same vault");
        assertTrue(single.standardExchangeOf(v4_.otherToken()) == seUT, "currency1 leg is this vault");
    }

    function test_row_bufferFirst_restingFace_notPaidToJoiner() public override {
        _seed();
        address donor = makeAddr("donor");
        uint256 donation = _f(500);
        fx.fund(donor, donation);
        vm.prank(donor);
        IERC20(face).transfer(hook, donation);
        uint256 userFace = IERC20(face).balanceOf(user);
        uint256 seBefore = _hookSeShares();
        (, uint256 usedFace) = _joinBoth(_f(1), 1 ether);
        assertGt(usedFace, 0, "join used face");
        assertEq(userFace - IERC20(face).balanceOf(user), usedFace, "joiner pays used face, not the resting donation");
        assertGt(_hookSeShares(), seBefore, "buffer-first: SE shares owned by the hook");
        uint256 resting = IERC20(face).balanceOf(hook);
        assertGt(resting, 0, "unused input is refunded to the hook");
        assertLt(resting, donation, "the donation is not paid to the joiner");
    }

    function test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed() public override {
        _expectHookExactOutReverts(true);
    }

    function test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly() public override {
        _expectHookExactOutReverts(false);
    }

    function test_row_poolManagerSwap_bothDirections_noFaceResidual() public override {
        _seed();
        uint256 uFace = IERC20(face).balanceOf(user);
        uint256 uRaw = IERC20(raw).balanceOf(user);
        _swapExactIn(face, raw, _f(1));
        assertGt(IERC20(raw).balanceOf(user), uRaw, "exact-in face->raw paid");
        uRaw = IERC20(raw).balanceOf(user);
        uFace = IERC20(face).balanceOf(user);
        _swapExactIn(raw, face, 1 ether);
        assertGt(IERC20(face).balanceOf(user), uFace, "exact-in raw->face paid");
        _expectPoolExactOutReverts(face, raw);
        _expectPoolExactOutReverts(raw, face);
    }

    function test_row_previewMatchesExecution() public override {
        uint256 amount = _f(1);
        (uint256 quoted, uint256 refund) = IFullSpreadCpTuple(seUT).previewExchangeIn(face, amount, seUT);
        fx.fund(address(this), amount);
        IERC20(face).approve(seUT, amount);
        (uint256 got, uint256 gotRefund) = IFullSpreadCpTuple(seUT).exchangeIn(
            face, amount, seUT, 0, address(this), false, block.timestamp
        );
        assertEq(got, quoted, "exact-in amountOut preview == execution");
        assertEq(gotRefund, refund, "refund word matches execution");
        assertEq(IStandardExchangeOut(seUT).previewExchangeOut(IERC20(face), IERC20(seUT), amount), 0);

        _seed();
        (uint256 a0, uint256 a1) = _ordered(_f(10), 10 ether);
        (uint256 pLp, uint256 pUsed0, uint256 pUsed1) = single.previewDeposit(a0, a1);
        vm.prank(user);
        (uint256 gotLp, uint256 used0, uint256 used1) =
            single.deposit(a0, a1, user, 0, block.timestamp + 1 hours);
        assertEq(used0, pUsed0, "deposit used0 preview == execution");
        assertEq(used1, pUsed1, "deposit used1 preview == execution");
        assertApproxEqRel(gotLp, pLp, 1e12, "deposit LP preview == execution");

        uint256 probe = _f(1);
        uint256 pSwap = single.previewSwapExactIn(face, raw, probe);
        uint256 rawBefore = IERC20(raw).balanceOf(user);
        _swapExactIn(face, raw, probe);
        assertEq(IERC20(raw).balanceOf(user) - rawBefore, pSwap, "exact-in swap preview == execution");
    }

    function _expectHookExactOutReverts(bool pretransferred) internal {
        _seed();
        uint256 faceBefore = IERC20(face).balanceOf(user);
        uint256 rawBefore = IERC20(raw).balanceOf(user);
        uint256 hookFace = IERC20(face).balanceOf(hook);
        uint256 hookRaw = IERC20(raw).balanceOf(hook);
        vm.expectRevert();
        vm.prank(user);
        IStandardExchangeOut(hook).exchangeOut(
            IERC20(raw), type(uint256).max, IERC20(face), _f(1), user, pretransferred, block.timestamp
        );
        assertEq(IERC20(face).balanceOf(user), faceBefore, "exact-out pays no face");
        assertEq(IERC20(raw).balanceOf(user), rawBefore, "exact-out pays no raw");
        assertEq(IERC20(face).balanceOf(hook), hookFace, "hook face unchanged");
        assertEq(IERC20(raw).balanceOf(hook), hookRaw, "hook raw unchanged");
    }

    function _expectPoolExactOutReverts(address tokenIn, address tokenOut) internal {
        bool zeroForOne = tokenIn < tokenOut;
        uint256 faceBefore = IERC20(face).balanceOf(user);
        uint256 rawBefore = IERC20(raw).balanceOf(user);
        SwapParams memory params = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: int256(_f(1) / 2),
            sqrtPriceLimitX96: _sqrtLimit(zeroForOne)
        });
        vm.expectRevert();
        vm.prank(user);
        swapRouter.swapExactOut(poolKey, params, type(uint256).max, "");
        assertEq(IERC20(face).balanceOf(user), faceBefore, "exact-out pays no face");
        assertEq(IERC20(raw).balanceOf(user), rawBefore, "exact-out pays no raw");
    }

    function test_row_seFailure_rollsBack() public override {
        uint256 amount_ = _f(10);(uint256 quoted_,) = IFullSpreadCpTuple(seUT).previewExchangeIn(face, amount_, seUT);
        uint256 supply_ = IERC20(seUT).totalSupply();
        uint256 vaultFace_ = IERC20(face).balanceOf(seUT);
        fx.fund(address(this), amount_);
        IERC20(face).approve(seUT, amount_);
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.AmountOutNotMet.selector, quoted_ + 1, quoted_));IFullSpreadCpTuple(seUT).exchangeIn(face, amount_, seUT, quoted_ + 1, address(this), false, block.timestamp);
        assertEq(IERC20(seUT).totalSupply(), supply_);
        assertEq(IERC20(face).balanceOf(seUT), vaultFace_);
    }

    function test_row_faceProductIndex0() public {
        _bindFaceIndex(true);
        assertLt(uint160(face), uint160(raw), "counter-leg is above the face");
        assertEq(single.currency0(), face, "face is product index 0");
        _seed();
        _swapExactIn(face, raw, _f(1));
    }

    function test_row_faceProductIndex1() public {
        _bindFaceIndex(false);
        assertGt(uint160(face), uint160(raw), "counter-leg is below the face");
        assertEq(single.currency1(), face, "face is product index 1");
        _seed();
        _swapExactIn(face, raw, _f(1));
    }

    function _bindFaceIndex(bool rawAboveFace) internal {
        raw = _rawOnSideOf(face, rawAboveFace);
        IPkg.PkgArgs memory args = _rowPkgArgs();
        args.rawToken = raw;
        args.rawTokenDecimals = HookPkgArgsDecimalsLib.tokenDec(raw);
        _deployRowHook(args);
        SimpleMintableERC20(raw).mint(user, 1_000_000 ether);
        vm.startPrank(user);
        IERC20(raw).approve(hook, type(uint256).max);
        IERC20(raw).approve(address(swapRouter), type(uint256).max);
        IERC20(face).approve(hook, type(uint256).max);
        IERC20(face).approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

    function _rawOnSideOf(address face_, bool above) internal returns (address token) {
        IndexTokenFactory factory = new IndexTokenFactory();
        for (uint256 salt; salt < 64; ++salt) {
            token = factory.deploy(bytes32(salt), above ? "RawAbove" : "RawBelow");
            if ((above && token > face_) || (!above && token < face_)) return token;
        }
        revert("no raw token on the requested side");
    }
}

contract IndexTokenFactory {
    function deploy(bytes32 salt, string memory name) external returns (address token) {
        token = address(new SimpleMintableERC20{salt: salt}(name, "RAW"));
    }
}
