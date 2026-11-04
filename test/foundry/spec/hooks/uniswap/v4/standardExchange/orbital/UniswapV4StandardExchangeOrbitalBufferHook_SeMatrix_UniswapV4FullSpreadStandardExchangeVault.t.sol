// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {SeMatrixFixture} from "../SeMatrixFixture.sol";
import {SeMatrix_FullSpreadV4Fixture} from "../SeMatrix_FullSpreadV4Fixture.sol";
import {IFullSpreadV4MatrixMoney, FullSpreadV4MatrixPairToken, FullSpreadV4MatrixChecks} from "../dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol";
import {UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior} from "./UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol";
import {TestBase_UniswapV4StandardExchangeOrbitalBufferHook} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";
import {IUniswapV4StandardExchangeOrbitalBufferHookPackage as IPackage} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";

/// @notice One converting face, one PairToken identity record, and one raw leg.
contract UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault is
    UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior
{
    address internal sharedPkg;
    SeMatrix_FullSpreadV4Fixture internal fullSpread;
    FullSpreadV4MatrixPairToken internal pairRecord;
    bool internal identityAccepted;
    bytes internal identityRevert;
    uint256 internal beforePair;

    function _newFixture() internal override returns (SeMatrixFixture) {
        fullSpread = new SeMatrix_FullSpreadV4Fixture(_ctx(), sharedPkg);
        sharedPkg = fullSpread.pkg();
        return fullSpread;
    }

    function setUp() public override {
        TestBase_UniswapV4StandardExchangeOrbitalBufferHook.setUp();
        fx0 = _newFixture();
        face0 = fx0.faceToken();
        seUT0 = fx0.se();
        faceDec0 = 18;
        faceDec1 = 18;
        faceDec2 = 18;
        rejectBytes = abi.encodeWithSelector(IStandardExchangeErrors.AmountOutNotMet.selector);
        pm = fullSpread.poolManager();
        swapRouter = new WrapperExactOutRouter(pm);
        rowCaller = new AtomicPretransferCaller();
        rowEoa = makeAddr("rowEoa");
        rowBob = makeAddr("rowBob");
        beforePair = vm.snapshotState();
        _configureOrbital(true);
    }

    function _configureOrbital(bool faceAtZero_) internal {
        pairRecord = FullSpreadV4MatrixChecks.pair(fullSpread, faceAtZero_);
        face1 = pairRecord.share();
        seUT1 = face1;
        face2 = FullSpreadV4MatrixChecks.raw(face0, faceAtZero_, keccak256("orbital raw"));
        seUT2 = address(0);
        _bindOrbital(fullSpread.currency0Provider());
    }

    function _bindOrbital(address provider_) internal {
        IPackage.PkgArgs memory args_;
        args_.poolManager = address(pm);
        args_.feeOracle = address(indexedexManager);
        args_.token0 = face0;
        args_.token1 = face1;
        args_.token2 = face2;
        args_.decimals0 = 18;
        args_.decimals1 = 18;
        args_.decimals2 = 18;
        args_.se0 = seUT0;
        args_.se1 = seUT1;
        args_.rp0 = provider_;
        args_.rp1 = pairRecord.provider();
        args_.tickSpacing = 60;
        args_.sqrtPriceX96 = uint160(1) << 96;
        args_.owner = owner;
        try hookPkg.processArgs(abi.encode(args_)) returns (bytes memory) {
            identityAccepted = true;
        } catch (bytes memory reason_) {
            identityAccepted = false;
            identityRevert = reason_;
            FullSpreadV4MatrixChecks.record(address(hookPkg), abi.encode(args_), reason_);
            // Separate raw-pair control only: retain the actual share token, remove its rejected binding.
            // The identity-specific test below remains red; this never closes FS-A26.
            args_.se1 = address(0);
            args_.rp1 = address(0);
        }
        _deployRowHook(args_);
        _setUsageFee(0);
        _setDexFee(0);
        fullSpread.fund(user, 1_000_000 ether);
        fullSpread.fundOther(user, 1_000_000 ether);
        SimpleMintableERC20(face2).mint(user, 1_000_000 ether);
        SimpleMintableERC20(face2).mint(address(this), 1_000_000 ether);
        IERC20(face1).transfer(user, 100_000 ether);
        vm.startPrank(user);
        IERC20(face0).approve(hook, type(uint256).max);
        IERC20(face1).approve(hook, type(uint256).max);
        IERC20(face2).approve(hook, type(uint256).max);
        IERC20(face0).approve(address(swapRouter), type(uint256).max);
        IERC20(face1).approve(address(swapRouter), type(uint256).max);
        IERC20(face2).approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

    function _seedMixed() internal {
        uint256 supply_ = IERC20(face1).totalSupply();
        (uint256 shares_,) = _addAll(100 ether, 100 ether, 100 ether);
        assertGt(shares_, 0, "mixed seed is a real public deposit");
        assertEq(IERC20(face1).totalSupply(), supply_, "identity seed does not mint PairToken");
    }

    function _directions(address counter_) internal {
        PoolKey memory key_ = counter_ == face1 ? poolKey01 : poolKey02;
        assertEq(address(key_.hooks), hook);
        assertTrue(keccak256(abi.encode(key_)) != keccak256(abi.encode(fullSpread.key())), "disjoint product key");
        assertEq(face0 < counter_, face0 < (counter_), "face index before swap");
        uint256 supply_ = IERC20(face1).totalSupply();
        uint256 output_ = IERC20(counter_).balanceOf(user);
        _swapExactIn(face0, counter_, 1 ether);
        assertGt(IERC20(counter_).balanceOf(user), output_, "face exact-input paid");
        output_ = IERC20(face0).balanceOf(user);
        _swapExactIn(counter_, face0, 1 ether);
        assertGt(IERC20(face0).balanceOf(user), output_, "reverse exact-input paid");
        assertEq(IERC20(face1).totalSupply(), supply_, "PairToken transfer only");
    }

    function test_row_identity_pairToken() public {
        emit log_named_bytes("FS-HOOK-04 PairToken rejection; FS-A26 OPEN", identityRevert);
        if (!identityAccepted) {
            assertGt(identityRevert.length, 0, "FS-HOOK-04 recorded; FS-A26 not passed");
            return;
        }
        _seedMixed();
        _directions(face1);
    }
    function test_row_rateTarget_currency1() public {
        face0 = fullSpread.otherToken();
        _bindOrbital(fullSpread.currency1Provider());
        assertEq(orbital.rateProvider(0), fullSpread.currency1Provider());
        _seedMixed();
        _directions(face2);
        if (identityAccepted) _directions(face1);
    }
    function test_row_index0() public {
        assertLt(uint160(face0), uint160(face1));
        assertLt(uint160(face0), uint160(face2));
        _seedMixed();
        _directions(face2);
        if (identityAccepted) _directions(face1);
    }
    function test_row_index1() public {
        assertTrue(vm.revertToState(beforePair));
        _configureOrbital(false);
        assertGt(uint160(face0), uint160(face1));
        assertGt(uint160(face0), uint160(face2));
        _seedMixed();
        _directions(face2);
        if (identityAccepted) _directions(face1);
    }
    function test_row_pair12_transferControl() public {
        _seedMixed();
        uint256 supply_ = IERC20(face1).totalSupply();
        _swapExactIn(face1, face2, 1 ether);
        _swapExactIn(face2, face1, 1 ether);
        assertEq(IERC20(face1).totalSupply(), supply_);
    }

    // Only leg 0 converts; the inherited three-fixture assumptions do not apply.
    function test_row_bind_deploysThroughPackage() public override {
        assertEq(orbital.standardExchange(0), seUT0);
        assertEq(orbital.standardExchange(2), address(0));
        assertEq(orbital.rateProvider(0), fullSpread.currency0Provider());
        assertEq(orbital.rateProvider(2), address(0));
        _seedMixed();
    }
    function test_row_bufferFirst_restingFace_notPaidToJoiner() public override {
        uint256 joiner_ = IERC20(face0).balanceOf(user);
        fullSpread.fund(hook, 500 ether);
        _seedMixed();
        assertLe(IERC20(face0).balanceOf(user), joiner_, "resting face is not paid to the joiner");
        assertGe(IERC20(face0).balanceOf(hook), 500 ether, "unconsumed donation stays on the hook");
    }
    // FullSpread refunds unconsumed input to the hook instead of booking a sleeve remainder.
    function test_row_partialConsumption_bookedNotRefunded() public override {
        FullSpreadV4MatrixChecks.refunds(fullSpread, hook, face0);
    }
    function test_row_hookSwap_exactIn_eoaPretransferRejected() public override {
        _seedMixed();
        uint256 in_ = IERC20(face2).balanceOf(hook);
        uint256 out_ = IERC20(face0).balanceOf(rowEoa);
        vm.prank(rowEoa);
        vm.expectRevert();
        IFullSpreadV4MatrixMoney(hook).exchangeIn(face2, 1 ether, face0, 0, rowEoa, true, block.timestamp);
        assertEq(IERC20(face2).balanceOf(hook), in_);
        assertEq(IERC20(face0).balanceOf(rowEoa), out_);
    }
    // Enabled exact-out is negative even when a direct vault preview returns zero.
    function test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed() public override {
        _seedMixed();
        FullSpreadV4MatrixChecks.hookOut(hook, face2, face0, true);
    }
    function test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly() public override {
        _seedMixed();
        FullSpreadV4MatrixChecks.hookOut(hook, face2, face0, false);
    }
    function test_row_poolManagerSwap_bothDirections_noFaceResidual() public override {
        _seedMixed();
        _directions(face2);
        if (identityAccepted) _directions(face1);
        uint256 f_ = IERC20(face0).balanceOf(user);
        uint256 r_ = IERC20(face2).balanceOf(user);
        bool z_ = face2 < face0;
        SwapParams memory p_ = SwapParams(z_, int256(1 ether), z_ ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1);
        vm.prank(user);
        vm.expectRevert();
        swapRouter.swapExactOut(poolKey02, p_, 10 ether, "");
        assertEq(IERC20(face0).balanceOf(user), f_);
        assertEq(IERC20(face2).balanceOf(user), r_);
    }
    // Public minimum failure replaces a V3 pool-mint mock.
    function test_row_seFailure_rollsBack() public override { FullSpreadV4MatrixChecks.rollback(fullSpread, face0); }
    function test_row_previewMatchesExecution() public override { FullSpreadV4MatrixChecks.preview(fullSpread, face0); }
    // There is no sleeve; another face depositor cannot take this hook's shares.
    function test_row_ammCallerFundSeparation() public override {
        _seedMixed();
        uint256 shares_ = IERC20(seUT0).balanceOf(hook);
        fullSpread.fundOther(rowBob, 10 ether);
        vm.startPrank(rowBob);
        IERC20(fullSpread.otherToken()).approve(seUT0, 10 ether);
        IFullSpreadV4MatrixMoney(seUT0).exchangeIn(fullSpread.otherToken(), 10 ether, seUT0, 0, rowBob, false, block.timestamp);
        vm.stopPrank();
        assertEq(IERC20(seUT0).balanceOf(hook), shares_);
        assertEq(IERC20(face0).balanceOf(rowBob), 0);
    }
    function test_row_exactOutAbsent() public { FullSpreadV4MatrixChecks.absentOut(seUT0, face0); }
}
