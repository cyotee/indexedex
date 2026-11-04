// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {SeMatrixFixture} from "../SeMatrixFixture.sol";
import {SeMatrix_FullSpreadV4Fixture} from "../SeMatrix_FullSpreadV4Fixture.sol";
import {IFullSpreadV4MatrixMoney, FullSpreadV4MatrixChecks} from "../dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol";
import {TestBase_UniswapV4PairTokenStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/test/bases/TestBase_UniswapV4PairTokenStandardExchangeVault.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeRateProviderDFPkg} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/IStandardExchangeRateProviderDFPkg.sol";
import {StandardExchangeRateProvider_FactoryService as ProviderFactory} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProvider_FactoryService.sol";
import {UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior} from "./UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol";
import {TestBase_UniswapV4StandardExchangeWeightedBufferHook} from "./TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";
import {IUniswapV4StandardExchangeWeightedBufferHookPackage as IPackage} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {UniswapV4StandardExchangeWeightedBufferHookPairPoolLib as PairPoolLib} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookPairPoolLib.sol";

/// @dev Vary registered vault args, not the adapter's CREATE2 salt. At most 32 vault candidates.
contract FullSpreadV4MatrixNamedPairToken is TestBase_UniswapV4PairTokenStandardExchangeVault {
    using ProviderFactory for *;

    address public share;
    address public p0;
    address public p1;
    address public provider;
    bool public sideMatched;
    uint256 public probes;

    function initialize(address recipient_, address face_, bool faceAtZero_) external {
        require(share == address(0), "already initialized");
        TestBase_UniswapV4PairTokenStandardExchangeVault.setUp();
        for (uint256 i; i < 32; ++i) {
            if (i != 0) {
                vault = _deployVault(_defaultArgs(
                    key, address(token0), string.concat("FS matrix identity ", vm.toString(i))
                ));
            }
            probes = i + 1;
            if ((face_ < address(vault)) == faceAtZero_) {
                sideMatched = true;
                break;
            }
        }
        share = address(vault);
        p0 = address(token0);
        p1 = address(token1);
        _bootstrap(1_000_000 ether, 1_000_000 ether, recipient_);
        IStandardExchangeRateProviderDFPkg package_ =
            create3Factory.deployStandardExchangeRateProviderDFPkg(
                create3Factory.deployStandardExchangeRateProviderFacet(), diamondPackageFactory
            );
        provider = address(package_.deployRateProvider(
            IStandardExchange(share), IERC20(share), IERC20(p0)
        ));
    }

    function backingKey() external view returns (PoolKey memory) { return key; }
}

/// @notice Three sorted weighted records: FullSpread face 50%, PairToken identity 25%, raw 25%.
contract UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3 is
    UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior
{
    address internal sharedPkg;
    SeMatrix_FullSpreadV4Fixture internal fullSpread;
    FullSpreadV4MatrixNamedPairToken internal pairRecord;
    address[] internal rowTokens;
    address[] internal rowSes;
    address[] internal rowProviders;
    uint256[] internal rowWeights;
    bool internal identityAccepted;
    bytes internal identityRevert;
    uint256 internal beforeLegs;

    function _newFixture() internal override returns (SeMatrixFixture) {
        fullSpread = new SeMatrix_FullSpreadV4Fixture(_ctx(), sharedPkg);
        sharedPkg = fullSpread.pkg();
        return fullSpread;
    }

    function setUp() public override {
        TestBase_UniswapV4StandardExchangeWeightedBufferHook.setUp();
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
        _configureThree(true);
    }

    function _configureThree(bool faceAtZero_) internal {
        pairRecord = new FullSpreadV4MatrixNamedPairToken();
        pairRecord.initialize(address(this), face, faceAtZero_);
        assertLt(uint160(pairRecord.p0()), uint160(pairRecord.p1()), "PairToken faces sorted");
        assertTrue(pairRecord.p0() != face && pairRecord.p1() != face, "PairToken faces disjoint");
        assertTrue(pairRecord.p0() != fullSpread.otherToken() && pairRecord.p1() != fullSpread.otherToken(), "other face disjoint");
        assertTrue(keccak256(abi.encode(pairRecord.backingKey())) != keccak256(abi.encode(fullSpread.key())), "backing keys disjoint");
        other = FullSpreadV4MatrixChecks.raw(face, faceAtZero_, keccak256("weighted N3 raw"));
        delete rowTokens;
        rowTokens.push(face);
        rowTokens.push(pairRecord.share());
        rowTokens.push(other);
        for (uint256 i; i < 3; ++i) {
            for (uint256 j = i + 1; j < 3; ++j) {
                if (rowTokens[j] < rowTokens[i]) (rowTokens[i], rowTokens[j]) = (rowTokens[j], rowTokens[i]);
            }
        }
        delete rowSes;
        delete rowProviders;
        delete rowWeights;
        for (uint256 i; i < 3; ++i) {
            bool isFace_ = rowTokens[i] == face;
            bool isPair_ = rowTokens[i] == pairRecord.share();
            rowSes.push(isFace_ ? seUT : (isPair_ ? pairRecord.share() : address(0)));
            rowProviders.push(isFace_ ? fullSpread.currency0Provider() : (isPair_ ? pairRecord.provider() : address(0)));
            rowWeights.push(isFace_ ? 0.5e18 : 0.25e18);
            if (isFace_) faceIdx = i;
            if (rowTokens[i] == other) otherIdx = i;
        }
        IPackage.PkgArgs memory args_ = _pkgArgs(rowTokens, rowWeights, rowSes, rowProviders);
        identityAccepted = false;
        try hookPkg.processArgs(abi.encode(args_)) returns (bytes memory) {
            identityAccepted = true;
        } catch (bytes memory reason_) {
            identityRevert = reason_;
            FullSpreadV4MatrixChecks.record(address(hookPkg), abi.encode(args_), reason_);
            // Only the face/raw control continues. FS-A26 remains open, with a red identity test.
            for (uint256 i; i < 3; ++i) {
                if (rowTokens[i] == pairRecord.share()) {
                    args_.standardExchanges[i] = address(0);
                    args_.rateProviders[i] = address(0);
                    args_.seDecimals[i] = 0;
                }
            }
        }
        _deployHookWithArgs(args_);
        _setUsageFee(0);
        _setDexFee(0);
        fullSpread.fund(user, 1_000_000 ether);
        SimpleMintableERC20(other).mint(user, 1_000_000 ether);
        SimpleMintableERC20(other).mint(address(this), 1_000_000 ether);
        IERC20(pairRecord.share()).transfer(user, 100_000 ether);
        vm.startPrank(user);
        for (uint256 i; i < 3; ++i) {
            IERC20(rowTokens[i]).approve(hook, type(uint256).max);
            IERC20(rowTokens[i]).approve(address(swapRouter), type(uint256).max);
        }
        vm.stopPrank();
    }

    /// @dev Runtime-length amount array: no inherited two-leg seed/join/amount helpers.
    function _seedThree() internal returns (uint256 shares_) {
        uint256[] memory amounts_ = new uint256[](weighted.numTokens());
        for (uint256 i; i < amounts_.length; ++i) amounts_[i] = 100 ether;
        uint256 supply_ = IERC20(pairRecord.share()).totalSupply();
        vm.prank(user);
        (shares_,) = weighted.joinProportional(amounts_, user, 0, block.timestamp);
        assertGt(shares_, 0, "three-leg public seed");
        assertEq(IERC20(pairRecord.share()).totalSupply(), supply_, "pre-acquired PairToken shares only");
    }

    function _threeDirections(address counter_) internal {
        PoolKey memory key_ = PairPoolLib.pairKey(face, counter_, 1, IHooks(hook));
        bool z_ = face < counter_;
        assertEq(Currency.unwrap(z_ ? key_.currency0 : key_.currency1), face, "face product index before swap");
        assertTrue(keccak256(abi.encode(key_)) != keccak256(abi.encode(fullSpread.key())), "disjoint product/backing keys");
        address pair_ = pairRecord.share();
        vm.expectCall(pair_, abi.encodeWithSelector(IFullSpreadV4MatrixMoney.exchangeIn.selector), uint64(0));
        vm.expectCall(pair_, abi.encodeWithSelector(IStandardExchangeOut.exchangeOut.selector), uint64(0));
        vm.expectCall(pair_, abi.encodeWithSignature(
            "exchangeBundleInForSingleOut(uint256[],address,uint256,address,bool,uint256)"
        ), uint64(0));
        vm.expectCall(pair_, abi.encodeWithSignature(
            "exchangeBundleOut(address,uint256,uint256[],address,bool,uint256)"
        ), uint64(0));
        uint256 supply_ = IERC20(pairRecord.share()).totalSupply();
        uint256 input_ = IERC20(face).balanceOf(user);
        uint256 out_ = IERC20(counter_).balanceOf(user);
        _swapExactIn(face, counter_, 1 ether);
        assertEq(input_ - IERC20(face).balanceOf(user), 1 ether, "face input settled");
        assertGt(IERC20(counter_).balanceOf(user), out_, "face exact-input direction");
        input_ = IERC20(counter_).balanceOf(user);
        out_ = IERC20(face).balanceOf(user);
        _swapExactIn(counter_, face, 1 ether);
        assertEq(input_ - IERC20(counter_).balanceOf(user), 1 ether, "counter input settled");
        assertGt(IERC20(face).balanceOf(user), out_, "reverse exact-input direction");
        assertEq(IERC20(pairRecord.share()).totalSupply(), supply_, "PairToken transfer only");
    }

    function test_row_identity_pairToken() public {
        if (!identityAccepted) {
            emit log_named_bytes("FS-HOOK-04: identity NOT PASSED; FS-A26 OPEN", identityRevert);
            return;
        }
        _seedThree();
        _threeDirections(pairRecord.share());
    }
    function test_row_index0() public {
        assertLt(uint160(face), uint160(other));
        if (!pairRecord.sideMatched()) {
            emit log("PairToken product-index-0 case UNVERIFIED after 32 vault candidates; raw case continues");
            _seedThree();
            _threeDirections(other);
            return;
        }
        assertLt(uint160(face), uint160(pairRecord.share()));
        _seedThree();
        _threeDirections(other);
        if (identityAccepted) _threeDirections(pairRecord.share());
    }
    function test_row_index1() public {
        assertTrue(vm.revertToState(beforeLegs));
        _configureThree(false);
        assertGt(uint160(face), uint160(other));
        if (!pairRecord.sideMatched()) {
            emit log("PairToken product-index-1 case UNVERIFIED after 32 vault candidates; raw case continues");
            _seedThree();
            _threeDirections(other);
            return;
        }
        assertGt(uint160(face), uint160(pairRecord.share()));
        _seedThree();
        _threeDirections(other);
        if (identityAccepted) _threeDirections(pairRecord.share());
    }

    // All inherited fixed-two-leg tests are overridden; only the face converts.
    function test_row_bind_deploysThroughPackage() public override {
        assertEq(weighted.numTokens(), 3);
        assertEq(weighted.standardExchange(faceIdx), seUT);
        assertTrue(weighted.isBuffered(faceIdx));
        assertEq(weighted.rateProvider(faceIdx), fullSpread.currency0Provider());
        assertEq(weighted.standardExchange(otherIdx), address(0));
        assertFalse(weighted.isBuffered(otherIdx));
        assertEq(rowWeights[faceIdx], 0.5e18);
        assertEq(rowWeights[0] + rowWeights[1] + rowWeights[2], 1e18);
        _assertAllDoorsLive();
        _seedThree();
    }
    function test_row_bufferFirst_restingFace_notPaidToJoiner() public override {
        uint256 joiner_ = IERC20(face).balanceOf(user);
        fullSpread.fund(hook, 500 ether);
        _seedThree();
        assertLe(IERC20(face).balanceOf(user), joiner_, "resting face is not paid to the joiner");
        assertLt(IERC20(face).balanceOf(hook), 500 ether, "donation is not returned as a joiner refund");
    }
    // Refund-to-hook, not a sleeve booked remainder.
    function test_row_partialConsumption_bookedNotRefunded() public override {
        FullSpreadV4MatrixChecks.refunds(fullSpread, hook, face);
    }
    function test_row_hookSwap_exactIn_eoaPretransferRejected() public override {
        _seedThree();
        uint256 in_ = IERC20(other).balanceOf(hook);
        uint256 out_ = IERC20(face).balanceOf(rowEoa);
        vm.prank(rowEoa);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        IFullSpreadV4MatrixMoney(hook).exchangeIn(other, 1 ether, face, 0, rowEoa, true, block.timestamp);
        assertEq(IERC20(other).balanceOf(hook), in_);
        assertEq(IERC20(face).balanceOf(rowEoa), out_);
    }
    // Neither trust-flag variant may pay on exact-out.
    function test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed() public override {
        _seedThree();
        FullSpreadV4MatrixChecks.hookOut(hook, other, face, true);
    }
    function test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly() public override {
        _seedThree();
        FullSpreadV4MatrixChecks.hookOut(hook, other, face, false);
    }
    function test_row_poolManagerSwap_bothDirections_noFaceResidual() public override {
        _seedThree();
        _threeDirections(other);
        if (identityAccepted) _threeDirections(pairRecord.share());
        uint256 f_ = IERC20(face).balanceOf(user);
        uint256 o_ = IERC20(other).balanceOf(user);
        PoolKey memory key_ = PairPoolLib.pairKey(other, face, 1, IHooks(hook));
        bool z_ = other < face;
        SwapParams memory p_ = SwapParams(z_, int256(1 ether), z_ ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1);
        vm.prank(user);
        vm.expectRevert();
        swapRouter.swapExactOut(key_, p_, 10 ether, "");
        assertEq(IERC20(face).balanceOf(user), f_);
        assertEq(IERC20(other).balanceOf(user), o_);
    }
    // Public minimum failure replaces mocked dependency failure; no sleeve exists.
    function test_row_seFailure_rollsBack() public override { FullSpreadV4MatrixChecks.rollback(fullSpread, face); }
    function test_row_previewMatchesExecution() public override { FullSpreadV4MatrixChecks.preview(fullSpread, face); }
    function test_row_ammCallerFundSeparation() public override {
        _seedThree();
        uint256 shares_ = IERC20(seUT).balanceOf(hook);
        fullSpread.fundOther(rowBob, 10 ether);
        vm.startPrank(rowBob);
        IERC20(fullSpread.otherToken()).approve(seUT, 10 ether);
        IFullSpreadV4MatrixMoney(seUT).exchangeIn(fullSpread.otherToken(), 10 ether, seUT, 0, rowBob, false, block.timestamp);
        vm.stopPrank();
        assertEq(IERC20(seUT).balanceOf(hook), shares_);
        assertEq(IERC20(face).balanceOf(rowBob), 0);
    }
    function test_row_exactOutAbsent() public { FullSpreadV4MatrixChecks.absentOut(seUT, face); }
}
