// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {SeMatrixFixture} from "../SeMatrixFixture.sol";
import {SeMatrix_FullSpreadV4Fixture} from "../SeMatrix_FullSpreadV4Fixture.sol";
import {IFullSpreadV4MatrixMoney, FullSpreadV4MatrixPairToken, FullSpreadV4MatrixChecks} from "../dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol";
import {UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior} from "./UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol";
import {TestBase_UniswapV4StandardExchangeWeightedBufferHook} from "./TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";
import {IUniswapV4StandardExchangeWeightedBufferHookPackage as IPackage} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";

/// @notice Runtime-length row assertions shared by the two- and three-leg concrete rows.
/// @dev The owner's setup instruction supersedes the plan's older two-leg setup sentence.
contract UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault is
    UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior
{
    address internal sharedPkg;
    SeMatrix_FullSpreadV4Fixture internal fullSpread;
    FullSpreadV4MatrixPairToken internal pairRecord;
    address[] internal rowTokens;
    address[] internal rowSes;
    address[] internal rowProviders;
    uint256[] internal rowWeights;
    uint256 internal rowCount;
    bool internal identityAccepted;
    bytes internal identityRevert;
    uint256 internal beforeLegs;

    function _newFixture() internal override returns (SeMatrixFixture) {
        fullSpread = new SeMatrix_FullSpreadV4Fixture(_ctx(), sharedPkg);
        sharedPkg = fullSpread.pkg();
        return fullSpread;
    }

    function setUp() public virtual override {
        TestBase_UniswapV4StandardExchangeWeightedBufferHook.setUp();
        _initializeWeighted(2);
    }

    function _initializeWeighted(uint256 count_) internal {
        rowCount = count_;
        fx = _newFixture();
        face = fx.faceToken();
        seUT = fx.se();
        faceDec = 18;
        rejectBytes = abi.encodeWithSelector(IStandardExchangeErrors.AmountOutNotMet.selector);
        pm = fullSpread.poolManager();
        swapRouter = new WrapperExactOutRouter(pm);
        rowCaller = new AtomicPretransferCaller();
        rowEoa = makeAddr("rowEoa");
        rowBob = makeAddr("rowBob");
        beforeLegs = vm.snapshotState();
        _configureWeighted(true);
    }

    function _configureWeighted(bool faceAtZero_) internal {
        other = FullSpreadV4MatrixChecks.raw(face, faceAtZero_, keccak256("weighted raw"));
        delete rowTokens;
        rowTokens.push(face);
        rowTokens.push(other);
        if (rowCount == 3) {
            pairRecord = FullSpreadV4MatrixChecks.pair(fullSpread, faceAtZero_);
            rowTokens.push(pairRecord.share());
        }
        _bindWeighted(fullSpread.currency0Provider());
    }

    function _bindWeighted(address provider_) internal {
        for (uint256 i; i < rowCount; ++i) {
            for (uint256 j = i + 1; j < rowCount; ++j) {
                if (rowTokens[j] < rowTokens[i]) (rowTokens[i], rowTokens[j]) = (rowTokens[j], rowTokens[i]);
            }
        }
        delete rowSes;
        delete rowProviders;
        delete rowWeights;
        for (uint256 i; i < rowCount; ++i) {
            address token_ = rowTokens[i];
            bool isFace_ = token_ == face;
            bool isPair_ = rowCount == 3 && token_ == pairRecord.share();
            rowSes.push(isFace_ ? seUT : (isPair_ ? token_ : address(0)));
            rowProviders.push(isFace_ ? provider_ : (isPair_ ? pairRecord.provider() : address(0)));
            rowWeights.push(isFace_ || rowCount == 2 ? 0.5e18 : 0.25e18);
            if (isFace_) faceIdx = i;
            if (token_ == other) otherIdx = i;
        }
        IPackage.PkgArgs memory args_ = _pkgArgs(rowTokens, rowWeights, rowSes, rowProviders);
        identityAccepted = rowCount == 2;
        if (rowCount == 3) {
            try hookPkg.processArgs(abi.encode(args_)) returns (bytes memory) {
                identityAccepted = true;
            } catch (bytes memory reason_) {
                identityRevert = reason_;
                FullSpreadV4MatrixChecks.record(address(hookPkg), abi.encode(args_), reason_);
                // Raw-pair control is distinct from the rejected identity proof, which stays red.
                for (uint256 i; i < rowCount; ++i) {
                    if (rowTokens[i] == pairRecord.share()) {
                        args_.standardExchanges[i] = address(0);
                        args_.rateProviders[i] = address(0);
                        args_.seDecimals[i] = 0;
                    }
                }
            }
        }
        _deployHookWithArgs(args_);
        _setUsageFee(0);
        _setDexFee(0);
        fullSpread.fund(user, 1_000_000 ether);
        fullSpread.fundOther(user, 1_000_000 ether);
        SimpleMintableERC20(other).mint(user, 1_000_000 ether);
        SimpleMintableERC20(other).mint(address(this), 1_000_000 ether);
        if (rowCount == 3) IERC20(pairRecord.share()).transfer(user, 100_000 ether);
        vm.startPrank(user);
        for (uint256 i; i < rowCount; ++i) {
            IERC20(rowTokens[i]).approve(hook, type(uint256).max);
            IERC20(rowTokens[i]).approve(address(swapRouter), type(uint256).max);
        }
        vm.stopPrank();
    }

    /// @dev Never reaches the inherited length-two `_amounts` or `_seed`.
    function _seedWeighted() internal returns (uint256 shares_) {
        uint256[] memory amounts_ = new uint256[](rowCount);
        for (uint256 i; i < rowCount; ++i) amounts_[i] = 100 ether;
        vm.prank(user);
        (shares_,) = weighted.joinProportional(amounts_, user, 0, block.timestamp);
        assertGt(shares_, 0, "real runtime-length seed");
    }

    function _weightedDirections(address counter_) internal {
        bool z_ = face < counter_;
        PoolKey memory key_ = PoolKey(Currency.wrap(z_ ? face : counter_), Currency.wrap(z_ ? counter_ : face), 0, 1, IHooks(hook));
        assertEq(Currency.unwrap(z_ ? key_.currency0 : key_.currency1), face, "face product index before swap");
        assertTrue(keccak256(abi.encode(key_)) != keccak256(abi.encode(fullSpread.key())), "disjoint backing/product");
        uint256 supply_ = rowCount == 3 ? IERC20(pairRecord.share()).totalSupply() : 0;
        uint256 out_ = IERC20(counter_).balanceOf(user);
        _swapExactIn(face, counter_, 1 ether);
        assertGt(IERC20(counter_).balanceOf(user), out_, "face exact-input direction");
        out_ = IERC20(face).balanceOf(user);
        _swapExactIn(counter_, face, 1 ether);
        assertGt(IERC20(face).balanceOf(user), out_, "reverse exact-input direction");
        if (rowCount == 3) assertEq(IERC20(pairRecord.share()).totalSupply(), supply_, "PairToken transfer only");
    }

    function test_row_rateTarget_currency1() public virtual {
        rowTokens[faceIdx] = fullSpread.otherToken();
        face = fullSpread.otherToken();
        _bindWeighted(fullSpread.currency1Provider());
        assertEq(weighted.rateProvider(faceIdx), fullSpread.currency1Provider());
        _seedWeighted();
        _weightedDirections(other);
    }
    function test_row_index0() public {
        assertLt(uint160(face), uint160(other));
        if (rowCount == 3) assertLt(uint160(face), uint160(pairRecord.share()));
        _seedWeighted();
        _weightedDirections(other);
        if (rowCount == 3 && identityAccepted) _weightedDirections(pairRecord.share());
    }
    function test_row_index1() public {
        assertTrue(vm.revertToState(beforeLegs));
        _configureWeighted(false);
        assertGt(uint160(face), uint160(other));
        if (rowCount == 3) assertGt(uint160(face), uint160(pairRecord.share()));
        _seedWeighted();
        _weightedDirections(other);
        if (rowCount == 3 && identityAccepted) _weightedDirections(pairRecord.share());
    }

    // Runtime-length, mixed-leg checks replace helpers fixed at two legs.
    function test_row_bind_deploysThroughPackage() public override {
        assertEq(weighted.numTokens(), rowCount);
        assertEq(weighted.standardExchange(faceIdx), seUT);
        assertTrue(weighted.isBuffered(faceIdx));
        assertEq(weighted.standardExchange(otherIdx), address(0));
        assertFalse(weighted.isBuffered(otherIdx));
        uint256 sum_;
        for (uint256 i; i < rowCount; ++i) sum_ += rowWeights[i];
        assertEq(sum_, 1e18);
        _assertAllDoorsLive();
        _seedWeighted();
    }
    function test_row_bufferFirst_restingFace_notPaidToJoiner() public override {
        uint256 joiner_ = IERC20(face).balanceOf(user);
        fullSpread.fund(hook, 500 ether);
        _seedWeighted();
        assertLt(IERC20(face).balanceOf(hook), 500 ether, "donation is not returned as a joiner refund");
        assertLe(IERC20(face).balanceOf(user), joiner_, "resting face is not paid to the joiner");
    }
    // Refunds belong to the calling hook, not a sleeve or the swapper.
    function test_row_partialConsumption_bookedNotRefunded() public override {
        FullSpreadV4MatrixChecks.refunds(fullSpread, hook, face);
    }
    function test_row_hookSwap_exactIn_eoaPretransferRejected() public override {
        _seedWeighted();
        uint256 in_ = IERC20(other).balanceOf(hook);
        uint256 out_ = IERC20(face).balanceOf(rowEoa);
        vm.prank(rowEoa);
        vm.expectRevert();
        IFullSpreadV4MatrixMoney(hook).exchangeIn(other, 1 ether, face, 0, rowEoa, true, block.timestamp);
        assertEq(IERC20(other).balanceOf(hook), in_);
        assertEq(IERC20(face).balanceOf(rowEoa), out_);
    }
    // No positive exact-out quote or successful exact-out execution is expected.
    function test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed() public override {
        _seedWeighted();
        FullSpreadV4MatrixChecks.hookOut(hook, other, face, true);
    }
    function test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly() public override {
        _seedWeighted();
        FullSpreadV4MatrixChecks.hookOut(hook, other, face, false);
    }
    function test_row_poolManagerSwap_bothDirections_noFaceResidual() public override {
        _seedWeighted();
        _weightedDirections(other);
        if (rowCount == 3 && identityAccepted) _weightedDirections(pairRecord.share());
        uint256 f_ = IERC20(face).balanceOf(user);
        uint256 o_ = IERC20(other).balanceOf(user);
        bool z_ = other < face;
        PoolKey memory key_ = PoolKey(Currency.wrap(z_ ? other : face), Currency.wrap(z_ ? face : other), 0, 1, IHooks(hook));
        SwapParams memory p_ = SwapParams(z_, int256(1 ether), z_ ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1);
        vm.prank(user);
        vm.expectRevert();
        swapRouter.swapExactOut(key_, p_, 10 ether, "");
        assertEq(IERC20(face).balanceOf(user), f_, "no face paid");
        assertEq(IERC20(other).balanceOf(user), o_, "no raw paid");
    }
    // A real minimum-output failure replaces dependency injection; previews decode both words.
    function test_row_seFailure_rollsBack() public override { FullSpreadV4MatrixChecks.rollback(fullSpread, face); }
    function test_row_previewMatchesExecution() public override { FullSpreadV4MatrixChecks.preview(fullSpread, face); }
    function test_row_ammCallerFundSeparation() public override {
        _seedWeighted();
        uint256 shares_ = IERC20(seUT).balanceOf(hook);
        fullSpread.fundOther(rowBob, 10 ether);
        vm.startPrank(rowBob);
        IERC20(fullSpread.otherToken()).approve(seUT, 10 ether);
        IFullSpreadV4MatrixMoney(seUT).exchangeIn(fullSpread.otherToken(), 10 ether, seUT, 0, rowBob, false, block.timestamp);
        vm.stopPrank();
        assertEq(IERC20(seUT).balanceOf(hook), shares_, "other caller cannot consume hook shares");
        assertEq(IERC20(face).balanceOf(rowBob), 0);
    }
    function test_row_exactOutAbsent() public { FullSpreadV4MatrixChecks.absentOut(seUT, face); }
}
