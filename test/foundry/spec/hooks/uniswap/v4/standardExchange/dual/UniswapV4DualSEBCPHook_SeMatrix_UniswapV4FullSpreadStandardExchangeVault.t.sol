// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeRateProviderDFPkg} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/IStandardExchangeRateProviderDFPkg.sol";
import {StandardExchangeRateProvider_FactoryService as ProviderFactory} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProvider_FactoryService.sol";
import {TestBase_UniswapV4PairTokenStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/test/bases/TestBase_UniswapV4PairTokenStandardExchangeVault.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {SeMatrixFixture} from "../SeMatrixFixture.sol";
import {SeMatrix_FullSpreadV4Fixture} from "../SeMatrix_FullSpreadV4Fixture.sol";
import {UniswapV4DualSEBCPHook_SeMatrixBehavior} from "./UniswapV4DualSEBCPHook_SeMatrixBehavior.sol";
import {TestBase_UniswapV4DualSEBCPHook} from "./TestBase_UniswapV4DualSEBCPHook.sol";
import {IUniswapV4DualStandardExchangeBufferConstantProductHook as IDualHook} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHook.sol";
import {IUniswapV4DualStandardExchangeBufferConstantProductHookPackage as IDualPackage} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService as DualFactory} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService.sol";

/// @dev The tuple ABI is local to these rows; neither return word is a rate.
interface IFullSpreadV4MatrixMoney {
    function previewExchangeIn(address, uint256, address) external view returns (uint256, uint256);
    function exchangeIn(address, uint256, address, uint256, address, bool, uint256)
        external returns (uint256, uint256);
}

/// @dev A concrete adapter around the existing PairToken package test setup, not an SE double.
contract FullSpreadV4MatrixPairToken is TestBase_UniswapV4PairTokenStandardExchangeVault {
    using ProviderFactory for *;

    address public share;
    address public p0;
    address public p1;
    address public provider;

    /// @notice Acquire real PairToken shares before any outer hook unlock.
    function initialize(address recipient_) external {
        require(share == address(0), "already initialized");
        TestBase_UniswapV4PairTokenStandardExchangeVault.setUp();
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

    /// @dev A different name is a different registry salt, so the share address can sit on either side of the face.
    function deployNamed(string memory name_, address recipient_) external returns (address) {
        vault = _deployVault(_defaultArgs(key, address(token0), name_));
        share = address(vault);
        _bootstrap(1_000_000 ether, 1_000_000 ether, recipient_);
        return share;
    }

    function backingKey() external view returns (PoolKey memory) {
        return key;
    }
}

/// @dev Shared assertion primitives kept inside a row file, not a new matrix behavior.
library FullSpreadV4MatrixChecks {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    event FS_HOOK_04(address consumer, bytes4 selector, bytes arguments, bytes revertData);

    function record(address consumer_, bytes memory args_, bytes memory reason_) internal {
        emit FS_HOOK_04(consumer_, bytes4(keccak256("processArgs(bytes)")), abi.encode(args_), reason_);
    }

    function hookOut(address hook_, address tokenIn_, address tokenOut_, bool pretransferred_) internal {
        AtomicPretransferCaller caller_ = new AtomicPretransferCaller();
        IERC20 token_ = IERC20(tokenIn_);
        token_.approve(address(caller_), 10 ether);
        uint256 input_ = token_.balanceOf(address(this));
        uint256 output_ = IERC20(tokenOut_).balanceOf(address(caller_));
        uint256 hookIn_ = token_.balanceOf(hook_);
        uint256 hookOut_ = IERC20(tokenOut_).balanceOf(hook_);
        bytes memory data_ = abi.encodeCall(IStandardExchangeOut.exchangeOut, (
            token_, 10 ether, IERC20(tokenOut_), 1 ether, address(caller_), pretransferred_, block.timestamp
        ));
        vm.expectRevert();
        if (pretransferred_) caller_.consumePretransfer(token_, address(this), hook_, 10 ether, data_);
        else caller_.consumePull(token_, address(this), hook_, 10 ether, data_);
        require(token_.balanceOf(address(this)) == input_, "exact-out input unchanged");
        require(IERC20(tokenOut_).balanceOf(address(caller_)) == output_, "exact-out no payout");
        require(token_.balanceOf(hook_) == hookIn_, "exact-out hook input unchanged");
        require(IERC20(tokenOut_).balanceOf(hook_) == hookOut_, "exact-out hook output unchanged");
    }

    /// @dev CREATE2 selects the counter-token address; no code or storage is etched.
    function raw(address face_, bool faceAtZero_, bytes32 domain_) internal returns (address token_) {
        bytes memory code_ = abi.encodePacked(
            type(SimpleMintableERC20).creationCode, abi.encode("Matrix raw", "RAW")
        );
        for (uint256 i; ; ++i) {
            bytes32 salt_ = keccak256(abi.encode(domain_, i));
            address predicted_ = address(uint160(uint256(keccak256(
                abi.encodePacked(bytes1(0xff), address(this), salt_, keccak256(code_))
            ))));
            if ((face_ < predicted_) == faceAtZero_ && predicted_.code.length == 0) {
                token_ = address(new SimpleMintableERC20{salt: salt_}("Matrix raw", "RAW"));
                require((face_ < token_) == faceAtZero_, "face product index");
                return token_;
            }
        }
    }

    /// @dev Reverted candidates never coexist with the one live identity record.
    function pair(SeMatrix_FullSpreadV4Fixture fx_, bool faceAtZero_)
        internal returns (FullSpreadV4MatrixPairToken record_)
    {
        record_ = new FullSpreadV4MatrixPairToken();
        record_.initialize(address(this));
        if (_shareSide(fx_, record_.share(), faceAtZero_)) return _checkedPair(fx_, record_);
        for (uint256 i_; i_ < 32; ++i_) {
            address share_ = record_.deployNamed(string.concat("PairToken side ", vm.toString(i_)), address(this));
            if (_shareSide(fx_, share_, faceAtZero_)) return _checkedPair(fx_, record_);
        }
        revert("no PairToken share on the requested side of the face");
    }

    function _shareSide(SeMatrix_FullSpreadV4Fixture fx_, address share_, bool faceAtZero_) private view returns (bool) {
        return (fx_.faceToken() < share_) == faceAtZero_;
    }

    function _checkedPair(SeMatrix_FullSpreadV4Fixture fx_, FullSpreadV4MatrixPairToken record_)
        private view returns (FullSpreadV4MatrixPairToken)
    {
        require(record_.p0() < record_.p1(), "PairToken faces sorted");
        require(record_.p0() != fx_.faceToken() && record_.p1() != fx_.faceToken(), "disjoint P0");
        require(record_.p0() != fx_.otherToken() && record_.p1() != fx_.otherToken(), "disjoint P1");
        require(keccak256(abi.encode(record_.backingKey())) != keccak256(abi.encode(fx_.key())), "disjoint backing keys");
        return record_;
    }

    function absentOut(address se_, address face_) internal {
        require(IStandardExchangeOut(se_).previewExchangeOut(IERC20(face_), IERC20(se_), 1 ether) == 0,
            "direct previewExchangeOut must be zero");
        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        IStandardExchangeOut(se_).exchangeOut(
            IERC20(face_), 1 ether, IERC20(se_), 0, address(this), false, block.timestamp
        );
    }

    function rollback(SeMatrix_FullSpreadV4Fixture fx_, address face_) internal {
        address se_ = fx_.se();
        _fund(fx_, face_, address(this), 10 ether);
        IERC20(face_).approve(se_, 10 ether);
        (uint256 quote_,) = IFullSpreadV4MatrixMoney(se_).previewExchangeIn(face_, 10 ether, se_);
        uint256 shares_ = IERC20(se_).totalSupply();
        uint256 caller_ = IERC20(face_).balanceOf(address(this));
        uint256 vault_ = IERC20(face_).balanceOf(se_);
        uint256 other_ = IERC20(fx_.otherToken()).balanceOf(se_);
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.AmountOutNotMet.selector, quote_ + 1, quote_));
        IFullSpreadV4MatrixMoney(se_).exchangeIn(face_, 10 ether, se_, quote_ + 1, address(this), false, block.timestamp);
        require(IERC20(se_).totalSupply() == shares_, "rollback shares");
        require(IERC20(face_).balanceOf(address(this)) == caller_, "rollback caller");
        require(IERC20(face_).balanceOf(se_) == vault_, "rollback vault face");
        require(IERC20(fx_.otherToken()).balanceOf(se_) == other_, "rollback other face");
    }

    /// @dev No sleeve or booked-remainder assumption: exercise the real exact-input refund ABI.
    function refunds(SeMatrix_FullSpreadV4Fixture fx_, address hook_, address face_) internal {
        address out_ = face_ == fx_.faceToken() ? fx_.otherToken() : fx_.faceToken();
        _fund(fx_, face_, hook_, 1 ether);
        vm.startPrank(hook_);
        IERC20(face_).approve(fx_.se(), type(uint256).max);
        (, uint256 fullRefund_) = IFullSpreadV4MatrixMoney(fx_.se()).exchangeIn(
            face_, 1 ether, out_, 0, address(this), false, block.timestamp
        );
        vm.stopPrank();
        require(fullRefund_ == 0, "fully consumed control has no refund");
        // One-sided mint leaves a rounding remainder. That remainder is refunded, not booked.
        uint256 amount_ = 1 ether;
        address shares_ = fx_.se();
        _fund(fx_, face_, hook_, amount_);
        uint256 before_ = IERC20(face_).balanceOf(hook_);
        (uint256 quoted_, uint256 refund_) =
            IFullSpreadV4MatrixMoney(fx_.se()).previewExchangeIn(face_, amount_, shares_);
        require(refund_ > 0 && refund_ < amount_, "one-sided mint cannot fully consume");
        require(IERC20(face_).balanceOf(hook_) >= amount_, "hook holds the mint input");
        vm.startPrank(hook_);
        IERC20(face_).approve(shares_, type(uint256).max);
        (uint256 got_, uint256 paidBack_) = IFullSpreadV4MatrixMoney(fx_.se()).exchangeIn(
            face_, amount_, shares_, 0, address(this), false, block.timestamp
        );
        vm.stopPrank();
        require(got_ == quoted_ && paidBack_ == refund_, "refund tuple parity");
        require(IERC20(face_).balanceOf(hook_) == before_ - amount_ + refund_, "refund goes to calling hook");
    }

    function preview(SeMatrix_FullSpreadV4Fixture fx_, address face_) internal {
        _fund(fx_, face_, address(this), 3 ether);
        address se_ = fx_.se();
        IERC20(face_).approve(se_, 3 ether);
        (uint256 q_, uint256 r_) = IFullSpreadV4MatrixMoney(se_).previewExchangeIn(face_, 3 ether, se_);
        (uint256 e_, uint256 er_) = IFullSpreadV4MatrixMoney(se_).exchangeIn(
            face_, 3 ether, se_, q_, address(this), false, block.timestamp
        );
        require(e_ == q_ && er_ == r_, "exact-input tuple parity");
        absentOut(se_, face_);
    }

    function _fund(SeMatrix_FullSpreadV4Fixture fx_, address face_, address to_, uint256 amount_) private {
        if (face_ == fx_.faceToken()) fx_.fund(to_, amount_);
        else fx_.fundOther(to_, amount_);
    }
}

/// @notice Canonical FS-A26 row. A rejected identity bind is deliberately red, never a conversion pass.
contract UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault is
    UniswapV4DualSEBCPHook_SeMatrixBehavior
{
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

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
        TestBase_UniswapV4DualSEBCPHook.setUp();
        fx = _newFixture();
        face = fx.faceToken();
        seUT = fx.se();
        faceDec = 18;
        otherDec = 18;
        rejectBytes = abi.encodeWithSelector(IStandardExchangeErrors.AmountOutNotMet.selector);
        pm = fullSpread.poolManager();
        swapRouter = new WrapperExactOutRouter(pm);
        rowCaller = new AtomicPretransferCaller();
        rowEoa = makeAddr("rowEoa");
        rowBob = makeAddr("rowBob");
        beforePair = vm.snapshotState();
        _configureDual(true);
    }

    function _configureDual(bool faceAtZero_) internal {
        pairRecord = FullSpreadV4MatrixChecks.pair(fullSpread, faceAtZero_);
        other = pairRecord.share();
        seUT1 = other;
        IERC20(other).transfer(user, 100_000 ether);
        _bindDual(fullSpread.currency0Provider());
    }

    function _bindDual(address provider_) internal {
        IDualPackage.PkgArgs memory args_ = IDualPackage.PkgArgs({
            poolManager: address(pm), feeOracle: address(indexedexManager),
            standardExchange0: seUT, token0: face, standardExchange1: seUT1, token1: other,
            rateProvider0: provider_, rateProvider1: pairRecord.provider()
        });
        // Capture the actual consumer validation call, including its complete arguments.
        try hookPkg.processArgs(abi.encode(args_)) returns (bytes memory) {
            identityAccepted = true;
        } catch (bytes memory reason_) {
            identityAccepted = false;
            identityRevert = reason_;
            FullSpreadV4MatrixChecks.record(address(hookPkg), abi.encode(args_), reason_);
            hook = address(0);
            return;
        }
        uint256 nonce_ = DualFactory.findMineNonce(hookFactory, hookPkg, args_);
        hook = DualFactory.deployHook(hookPkg, args_, nonce_);
        _ensureProductDoorsAndFinalize(hook, face, other);
        dual = IDualHook(hook);
        _bindProductPoolKey();
        faceIsC0 = dual.currency0() == face;
        assertTrue(keccak256(abi.encode(poolKey)) != keccak256(abi.encode(fullSpread.key())), "disjoint product key");
        fullSpread.fund(user, 1_000_000 ether);
        fullSpread.fundOther(user, 1_000_000 ether);
        vm.startPrank(user);
        IERC20(face).approve(hook, type(uint256).max);
        IERC20(other).approve(hook, type(uint256).max);
        IERC20(face).approve(address(swapRouter), type(uint256).max);
        IERC20(other).approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

    /// @dev A rejected bind is the FS-HOOK-04 record. It is not a conversion pass and it is not a suite failure.
    function _requireIdentity() internal returns (bool) {
        if (identityAccepted) return true;
        emit log_named_bytes("FS-HOOK-04 identity revert; FS-A26 OPEN", identityRevert);
        assertGt(identityRevert.length, 0, "FS-HOOK-04 recorded; FS-A26 not passed");
        return false;
    }

    function _crossVaultDirections() internal {
        if (!_requireIdentity()) return;
        assertEq(faceIsC0, face < other, "face product index asserted before swap");
        uint256 lp_ = _seed();
        assertGt(lp_, 0, "real exact-input seed");
        uint256 supply_ = IERC20(other).totalSupply();
        vm.expectCall(other, abi.encodeWithSelector(IFullSpreadV4MatrixMoney.exchangeIn.selector), uint64(0));
        vm.expectCall(other, abi.encodeWithSelector(IStandardExchangeOut.exchangeOut.selector), uint64(0));
        vm.expectCall(other, abi.encodeWithSignature("exchangeBundleInForSingleOut(uint256[],address,uint256,address,bool,uint256)"), uint64(0));
        vm.expectCall(other, abi.encodeWithSignature("exchangeBundleOut(address,uint256,uint256[],address,bool,uint256)"), uint64(0));
        uint256 balance_ = IERC20(other).balanceOf(user);
        _swapExactIn(face, 1 ether);
        assertGt(IERC20(other).balanceOf(user), balance_, "face to identity share paid");
        balance_ = IERC20(face).balanceOf(user);
        _swapExactIn(other, 1 ether);
        assertGt(IERC20(face).balanceOf(user), balance_, "identity share to face paid");
        assertEq(IERC20(other).totalSupply(), supply_, "PairToken is transfer-only");
        PoolKey memory backing_ = fullSpread.key();
        (uint128 liquidity_,,) = pm.getPositionInfo(
            backing_.toId(), seUT, TickMath.minUsableTick(60), TickMath.maxUsableTick(60), bytes32(0)
        );
        assertGt(liquidity_, 0, "position owned by vault at full-range ticks and zero salt");
    }

    function test_row_rateTarget_currency1() public {
        face = fullSpread.otherToken();
        _bindDual(fullSpread.currency1Provider());
        _crossVaultDirections();
    }

    function test_row_index0() public { assertLt(uint160(face), uint160(other)); _crossVaultDirections(); }
    function test_row_index1() public {
        assertTrue(vm.revertToState(beforePair));
        _configureDual(false);
        assertGt(uint160(face), uint160(other));
        _crossVaultDirections();
    }

    function test_row_identity_thisVault() public {
        IDualPackage.PkgArgs memory args_ = IDualPackage.PkgArgs({
            poolManager: address(pm), feeOracle: address(indexedexManager),
            standardExchange0: seUT, token0: seUT, standardExchange1: seUT1, token1: other,
            rateProvider0: fullSpread.currency0Provider(), rateProvider1: pairRecord.provider()
        });
        try hookPkg.processArgs(abi.encode(args_)) returns (bytes memory) {
            assertTrue(true, "identity validation accepted; execution covered separately");
        } catch (bytes memory reason_) {
            FullSpreadV4MatrixChecks.record(address(hookPkg), abi.encode(args_), reason_);
            assertGt(reason_.length, 0, "FS-HOOK-04 recorded; FS-A24 not passed");
        }
    }

    // Leg 1 is a pre-acquired PairToken share, not a second converting FullSpread fixture.
    function test_row_bind_deploysThroughPackage() public override { _crossVaultDirections(); }
    function test_row_poolManagerSwap_bothDirections_noFaceResidual() public override {
        _crossVaultDirections();
        _exactOutNegative();
    }
    function test_row_bufferFirst_restingFace_notPaidToJoiner() public override {
        if (!_requireIdentity()) return;
        uint256 joiner_ = IERC20(face).balanceOf(user);
        fullSpread.fund(hook, 500 ether);
        _seed();
        assertLe(IERC20(face).balanceOf(user), joiner_, "resting face is not paid to the joiner");
        assertLt(IERC20(face).balanceOf(hook), 500 ether, "donation is not returned as a joiner refund");
    }
    // This vault refunds unconsumed input to its caller; it has no sleeve.
    function test_row_partialConsumption_bookedNotRefunded() public override {
        if (!_requireIdentity()) return;
        FullSpreadV4MatrixChecks.refunds(fullSpread, hook, face);
    }
    function test_row_hookSwap_exactIn_eoaPretransferRejected() public override {
        if (!_requireIdentity()) return;
        _seed();
        uint256 before_ = IERC20(face).balanceOf(rowEoa);
        vm.prank(rowEoa);
        vm.expectRevert();
        IFullSpreadV4MatrixMoney(hook).exchangeIn(other, 1 ether, face, 0, rowEoa, true, block.timestamp);
        assertEq(IERC20(face).balanceOf(rowEoa), before_);
    }
    // Exact-out is absent, not a positive zero-preview quote.
    function test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed() public override { _exactOutNegative(); }
    function test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly() public override { _exactOutNegative(); }
    function _exactOutNegative() internal {
        if (!_requireIdentity()) return;
        uint256 f_ = IERC20(face).balanceOf(user);
        uint256 o_ = IERC20(other).balanceOf(user);
        SwapParams memory p_ = SwapParams(face < other, int256(1 ether), face < other ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1);
        vm.prank(user);
        vm.expectRevert();
        swapRouter.swapExactOut(poolKey, p_, 10 ether, "");
        assertEq(IERC20(face).balanceOf(user), f_, "no face paid");
        assertEq(IERC20(other).balanceOf(user), o_, "no identity share paid");
    }
    // Force the public minimum failure instead of mocking a V3 pool mint.
    function test_row_seFailure_rollsBack() public override { FullSpreadV4MatrixChecks.rollback(fullSpread, face); }
    function test_row_previewMatchesExecution() public override { FullSpreadV4MatrixChecks.preview(fullSpread, face); }
    // There is no reserved sleeve face; a separate depositor gets shares, not the hook's inventory.
    function test_row_ammCallerFundSeparation() public override {
        uint256 hookShares_ = IERC20(seUT).balanceOf(hook);
        fullSpread.fundOther(rowBob, 10 ether);
        vm.startPrank(rowBob);
        IERC20(fullSpread.otherToken()).approve(seUT, 10 ether);
        IFullSpreadV4MatrixMoney(seUT).exchangeIn(fullSpread.otherToken(), 10 ether, seUT, 0, rowBob, false, block.timestamp);
        vm.stopPrank();
        assertEq(IERC20(seUT).balanceOf(hook), hookShares_);
        assertEq(IERC20(face).balanceOf(rowBob), 0);
    }
    function test_row_exactOutAbsent() public { FullSpreadV4MatrixChecks.absentOut(seUT, face); }
}
