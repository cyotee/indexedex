// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IUniswapV4ProtocolAware} from "@crane/contracts/interfaces/IUniswapV4ProtocolAware.sol";
import {IUniswapV4SinglePositionAware} from "@crane/contracts/interfaces/IUniswapV4SinglePositionAware.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {IUniswapV4FullSpreadStandardExchangeVaultDFPkg as IFullSpreadPackage} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol";
import {IStandardExchangeRateProvider} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/IStandardExchangeRateProvider.sol";
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

/// @dev A second real FullSpread vault. Its member face and its share are separate assets.
contract FullSpreadV4MatrixSibling {
    address public share;
    address public p0;
    address public p1;
    address public provider;
    address public otherProvider;
    PoolKey internal backing_;
    bool public sideMatched;

    function load(SeMatrix_FullSpreadV4Fixture fx_, address face_, bool faceAtZero_) external {
        require(share == address(0), "already initialized");
        SeMatrix_FullSpreadV4Fixture.Sibling memory sib_ = fx_.deploySibling(face_, faceAtZero_);
        share = sib_.share;
        p0 = sib_.face0;
        p1 = sib_.face1;
        provider = sib_.provider;
        otherProvider = sib_.otherProvider;
        backing_ = sib_.poolKey;
        sideMatched = (face_ < p0) == faceAtZero_;
        uint256 bal_ = IERC20(share).balanceOf(address(this));
        if (bal_ != 0) IERC20(share).transfer(msg.sender, bal_);
    }

    function backingKey() external view returns (PoolKey memory) {
        return backing_;
    }
}

/// @dev Shared assertion primitives kept inside a row file, not a new matrix behavior.
library FullSpreadV4MatrixChecks {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    event FS_HOOK_04(address consumer, bytes4 selector, bytes arguments, bytes revertData);
    event FixtureSeedLp(address hook, uint256 lockedFloor, uint256 grossLp, uint256 feeLp, uint256 netLp);

    struct Seed {
        uint256[] amounts;
        bool[] isShare;
        uint256[] shareSupply;
        uint256[] hookShares;
        uint256[] hookPairs;
        uint256[] callerShares;
        uint256 callerLp;
    }

    /// @notice Prepare shares outside the hook call, in the hook's complete leg order.
    function prepareSeed(
        SeMatrix_FullSpreadV4Fixture fixture_, address[] memory tokens_, address[] memory ses_,
        address hook_, address caller_, uint256 budget_
    ) internal returns (Seed memory seed_) {
        uint256 n_ = tokens_.length;
        require(n_ == ses_.length, "seed leg count");
        require(IERC20(hook_).totalSupply() == 0, "genesis only");
        seed_.amounts = new uint256[](n_);
        seed_.isShare = new bool[](n_);
        seed_.shareSupply = new uint256[](n_);
        seed_.hookShares = new uint256[](n_);
        seed_.hookPairs = new uint256[](n_);
        seed_.callerShares = new uint256[](n_);
        seed_.callerLp = IERC20(hook_).balanceOf(caller_);
        for (uint256 i_; i_ < n_; ++i_) {
            seed_.hookPairs[i_] = IERC20(tokens_[i_]).balanceOf(hook_);
            if (ses_[i_] == address(0)) {
                seed_.amounts[i_] = budget_;
                continue;
            }
            seed_.isShare[i_] = true;
            seed_.amounts[i_] = fixture_.acquireShares(ses_[i_], tokens_[i_], caller_, budget_);
            seed_.shareSupply[i_] = IERC20(ses_[i_]).totalSupply();
            seed_.hookShares[i_] = IERC20(ses_[i_]).balanceOf(hook_);
            seed_.callerShares[i_] = IERC20(ses_[i_]).balanceOf(caller_);
            vm.prank(caller_);
            IERC20(ses_[i_]).approve(hook_, seed_.amounts[i_]);
        }
    }

    /// @notice Observe actual 5% redemption, retained shares, local receipts and LP allocation.
    function assertSeed(
        Seed memory seed_, address[] memory tokens_, address[] memory ses_,
        address hook_, address caller_, uint256 netLp_
    ) internal {
        require(netLp_ > 0 && IERC20(hook_).balanceOf(caller_) - seed_.callerLp == netLp_, "net LP receipt");
        uint256 floor_ = IERC20(hook_).balanceOf(address(0));
        uint256 gross_ = IERC20(hook_).totalSupply() - floor_;
        require(floor_ > 0, "locked genesis floor");
        require(gross_ >= netLp_, "floor counted once");
        emit FixtureSeedLp(hook_, floor_, gross_, gross_ - netLp_, netLp_);
        for (uint256 i_; i_ < ses_.length; ++i_) {
            if (ses_[i_] == address(0)) {
                require(IERC20(tokens_[i_]).balanceOf(hook_) - seed_.hookPairs[i_] == seed_.amounts[i_], "raw seed receipt");
                continue;
            }
            uint256 redeem_ = seed_.amounts[i_] / 20;
            require(redeem_ > 0, "positive bootstrap spend");
            require(seed_.shareSupply[i_] - IERC20(ses_[i_]).totalSupply() == redeem_, "actual five percent burn");
            require(IERC20(ses_[i_]).balanceOf(hook_) - seed_.hookShares[i_] == seed_.amounts[i_] - redeem_, "retained seed shares");
            require(seed_.callerShares[i_] - IERC20(ses_[i_]).balanceOf(caller_) == seed_.amounts[i_], "caller funded shares");
            require(IERC20(tokens_[i_]).balanceOf(hook_) > seed_.hookPairs[i_], "positive actual local seed");
        }
    }

    /// @notice Measure a cold, isolated router transaction, including intrinsic gas.
    /// @dev Every concrete gas test enables isolation via its inline Forge configuration.
    /// A separate EVM transaction commits the seed first and resets warmth and dirty-slot
    /// accounting. No preview or execution probe warms the measured transaction.
    function coldSwap(
        WrapperExactOutRouter router_,
        PoolKey memory key_,
        SwapParams memory params_,
        address payer_,
        address share_
    ) internal returns (uint256 totalGas_) {
        return coldSwap(router_, key_, params_, payer_, share_, true);
    }

    /// @notice Require a genuine primary SE mint or burn, never just local output.
    function coldSwap(
        WrapperExactOutRouter router_,
        PoolKey memory key_,
        SwapParams memory params_,
        address payer_,
        address share_,
        bool mint_
    ) internal returns (uint256 totalGas_) {
        require(params_.amountSpecified < 0, "cold route is exact input");
        require(vm.isIsolateMode(), "G03 requires isolated transactions");
        bytes memory calldata_ = abi.encodeCall(router_.swapExactIn, (key_, params_, bytes("")));
        uint256 intrinsic_ = 21_000;
        for (uint256 i_; i_ < calldata_.length; ++i_) {
            intrinsic_ += calldata_[i_] == 0 ? 4 : 16;
        }
        uint256 supply_ = IERC20(share_).totalSupply();
        vm.prank(payer_);
        router_.swapExactIn(key_, params_, "");
        totalGas_ = intrinsic_ + vm.lastFrameGas().gasTotalUsed;
        if (mint_) require(IERC20(share_).totalSupply() > supply_, "measured transaction must mint FullSpread shares");
        else require(IERC20(share_).totalSupply() < supply_, "measured transaction must burn FullSpread shares");
        require(totalGas_ <= 12_000_000, "G03: cold whole transaction exceeds ceiling");
    }

    function record(address consumer_, bytes memory args_, bytes memory reason_) internal {
        emit FS_HOOK_04(consumer_, bytes4(keccak256("processArgs(bytes)")), abi.encode(args_), reason_);
    }

    /// @notice Check the actual vault-to-hook refund during a real composed mint.
    function hookRefund(address face_, address se_, address hook_, uint256 before_) internal {
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        uint256 refund_;
        for (uint256 i; i < logs_.length; ++i) {
            if (
                logs_[i].emitter == face_ && logs_[i].topics.length == 3
                    && logs_[i].topics[0] == keccak256("Transfer(address,address,uint256)")
                    && logs_[i].topics[1] == bytes32(uint256(uint160(se_)))
                    && logs_[i].topics[2] == bytes32(uint256(uint160(hook_)))
            ) refund_ += abi.decode(logs_[i].data, (uint256));
        }
        require(refund_ != 0, "composed mint must exercise a real input refund");
        require(IERC20(face_).balanceOf(hook_) == before_ + refund_, "refund stays on calling hook");
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
            token_, 10 ether, IERC20(tokenOut_), hookOut_ + 1, address(caller_), pretransferred_, block.timestamp
        ));
        vm.expectRevert();
        if (pretransferred_) caller_.consumePretransfer(token_, address(this), hook_, 10 ether, data_);
        else caller_.consumePull(token_, address(this), hook_, 10 ether, data_);
        require(token_.balanceOf(address(this)) == input_, "exact-out input unchanged");
        require(IERC20(tokenOut_).balanceOf(address(caller_)) == output_, "exact-out no payout");
        require(token_.balanceOf(hook_) == hookIn_, "exact-out hook input unchanged");
        require(IERC20(tokenOut_).balanceOf(hook_) == hookOut_, "exact-out hook output unchanged");
    }

    /// @dev Select an already-deployed raw record; neither token nor vault addresses are mined.
    function raw(SeMatrix_FullSpreadV4Fixture fx_, bool faceAtZero_, uint256 index_)
        internal view returns (address token_)
    {
        token_ = fx_.rawToken(faceAtZero_, index_);
        require((fx_.faceToken() < token_) == faceAtZero_, "face product index");
        require((fx_.otherToken() < token_) == faceAtZero_, "other face product index");
    }

    /// @dev Member-token addresses select product placement; the vault address is never mined.
    function pair(SeMatrix_FullSpreadV4Fixture fx_, address face_, bool faceAtZero_)
        internal returns (FullSpreadV4MatrixSibling record_)
    {
        record_ = new FullSpreadV4MatrixSibling();
        record_.load(fx_, face_, faceAtZero_);
        require(record_.p0() < record_.p1(), "sibling faces sorted");
        require(record_.p0() != fx_.faceToken() && record_.p1() != fx_.faceToken(), "disjoint faces");
        require(record_.p0() != fx_.otherToken() && record_.p1() != fx_.otherToken(), "disjoint other face");
        require(keccak256(abi.encode(record_.backingKey())) != keccak256(abi.encode(fx_.key())), "disjoint backing keys");
        membership(record_.share(), record_.p0());
        membership(fx_.se(), fx_.faceToken());
        return record_;
    }

    function membership(address se_, address pair_) internal view {
        address[] memory members_ = IBasicVault(se_).vaultTokens();
        require(members_.length == 2 && (pair_ == members_[0] || pair_ == members_[1]), "valid paired member");
        require(se_ != members_[0] && se_ != members_[1], "own share is implicit");
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
        address otherFace_ = face_ == fx_.faceToken() ? fx_.otherToken() : fx_.faceToken();
        uint256 other_ = IERC20(otherFace_).balanceOf(se_);
        uint256 recipientShares_ = IERC20(se_).balanceOf(address(this));
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.AmountOutNotMet.selector, quote_ + 1, quote_));
        IFullSpreadV4MatrixMoney(se_).exchangeIn(face_, 10 ether, se_, quote_ + 1, address(this), false, block.timestamp);
        require(IERC20(se_).totalSupply() == shares_, "rollback shares");
        require(IERC20(face_).balanceOf(address(this)) == caller_, "rollback caller");
        require(IERC20(face_).balanceOf(se_) == vault_, "rollback vault face");
        require(IERC20(otherFace_).balanceOf(se_) == other_, "rollback other face");
        require(IERC20(se_).balanceOf(address(this)) == recipientShares_, "rollback recipient shares");
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
        (uint256 q_,) = IFullSpreadV4MatrixMoney(se_).previewExchangeIn(face_, 3 ether, se_);
        uint256 recipient_ = IERC20(se_).balanceOf(address(this));
        (uint256 e_,) = IFullSpreadV4MatrixMoney(se_).exchangeIn(
            face_, 3 ether, se_, q_, address(this), false, block.timestamp
        );
        require(e_ == q_ && e_ != 0, "mint amountOut parity");
        require(IERC20(se_).balanceOf(address(this)) - recipient_ == e_, "mint recipient parity");
        IERC20(se_).approve(se_, e_);
        (q_,) = IFullSpreadV4MatrixMoney(se_).previewExchangeIn(se_, e_, face_);
        recipient_ = IERC20(face_).balanceOf(address(this));
        (e_,) = IFullSpreadV4MatrixMoney(se_).exchangeIn(
            se_, e_, face_, q_, address(this), false, block.timestamp
        );
        require(e_ == q_ && e_ != 0, "exit amountOut parity");
        require(IERC20(face_).balanceOf(address(this)) - recipient_ == e_, "exit recipient parity");
        absentOut(se_, face_);
    }

    function _fund(SeMatrix_FullSpreadV4Fixture fx_, address face_, address to_, uint256 amount_) private {
        if (face_ == fx_.faceToken()) fx_.fund(to_, amount_);
        else fx_.fundOther(to_, amount_);
    }
}

/// @notice Canonical FS-A26 row with two genuine FullSpread vaults and member-pair bindings.
contract UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault is
    UniswapV4DualSEBCPHook_SeMatrixBehavior
{
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    address internal sharedPkg;
    SeMatrix_FullSpreadV4Fixture internal fullSpread;
    FullSpreadV4MatrixSibling internal pairRecord;
    /// @dev Legacy observation consumed by the inherited DualUnwrap regression.
    /// Set only after a successful, valid two-SE package deployment; never gates these rows.
    bool internal identityAccepted;
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
        address placementFace_ = faceAtZero_ ? fullSpread.otherToken() : fullSpread.faceToken();
        pairRecord = FullSpreadV4MatrixChecks.pair(fullSpread, placementFace_, faceAtZero_);
        other = pairRecord.p0();
        seUT1 = pairRecord.share();
        SimpleMintableERC20(other).mint(user, 1_000_000 ether);
        SimpleMintableERC20(other).mint(address(this), 100_000 ether);
        _bindDual(face == fullSpread.faceToken() ? fullSpread.currency0Provider() : fullSpread.currency1Provider());
    }

    function _bindDual(address provider_) internal {
        IDualPackage.PkgArgs memory args_ = IDualPackage.PkgArgs({
            poolManager: address(pm), feeOracle: address(indexedexManager),
            standardExchange0: seUT, token0: face, standardExchange1: seUT1, token1: other,
            rateProvider0: provider_, rateProvider1: pairRecord.provider()
        });
        hookPkg.processArgs(abi.encode(args_));
        uint256 nonce_ = DualFactory.findMineNonce(hookFactory, hookPkg, args_);
        hook = DualFactory.deployHook(hookPkg, args_, nonce_);
        _ensureProductDoorsAndFinalize(hook, face, other);
        dual = IDualHook(hook);
        _bindProductPoolKey();
        faceIsC0 = dual.currency0() == face;
        identityAccepted = true;
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

    /// @notice Genesis supplies pre-acquired shares on both SE-backed legs.
    function _seed() internal override returns (uint256 lp_) {
        address[] memory tokens_ = new address[](2);
        address[] memory ses_ = new address[](2);
        tokens_[0] = dual.currency0();
        tokens_[1] = dual.currency1();
        ses_[0] = faceIsC0 ? seUT : seUT1;
        ses_[1] = faceIsC0 ? seUT1 : seUT;
        FullSpreadV4MatrixChecks.Seed memory seed_ = FullSpreadV4MatrixChecks.prepareSeed(
            fullSpread, tokens_, ses_, hook, user, 100 ether
        );
        vm.prank(user);
        (lp_,,) = dual.depositFlexible(seed_.amounts[0], true, seed_.amounts[1], true, user, 1, block.timestamp);
        FullSpreadV4MatrixChecks.assertSeed(seed_, tokens_, ses_, hook, user, lp_);
    }

    function _crossVaultDirections() internal {
        FullSpreadV4MatrixChecks.preview(fullSpread, face);
        assertEq(faceIsC0, face < other, "face product index asserted before swap");
        uint256 lp_ = _seed();
        assertGt(lp_, 0, "real exact-input seed");
        uint256 vaultSupply_ = IERC20(seUT).totalSupply();
        uint256 siblingSupply_ = IERC20(seUT1).totalSupply();
        uint256 balance_ = IERC20(other).balanceOf(user);
        uint256 quote_ = dual.previewSwapExactIn(faceIsC0, 10 ether);
        uint256 hookFace_ = IERC20(face).balanceOf(hook);
        vm.recordLogs();
        _swapExactIn(face, 10 ether);
        FullSpreadV4MatrixChecks.hookRefund(face, seUT, hook, hookFace_);
        assertEq(IERC20(other).balanceOf(user) - balance_, quote_, "forward amountOut parity");
        assertGt(IERC20(other).balanceOf(user), balance_, "face to sibling pair token paid");
        assertGt(IERC20(seUT).totalSupply(), vaultSupply_, "face direction mints FullSpread shares");
        assertLt(IERC20(seUT1).totalSupply(), siblingSupply_, "forward redeems second FullSpread");
        siblingSupply_ = IERC20(seUT1).totalSupply();
        vaultSupply_ = IERC20(seUT).totalSupply();
        balance_ = IERC20(face).balanceOf(user);
        quote_ = dual.previewSwapExactIn(!faceIsC0, 10 ether);
        _swapExactIn(other, 10 ether);
        assertEq(IERC20(face).balanceOf(user) - balance_, quote_, "reverse amountOut parity");
        assertGt(IERC20(face).balanceOf(user), balance_, "sibling pair token to face paid");
        assertLt(IERC20(seUT).totalSupply(), vaultSupply_, "reverse direction burns FullSpread shares");
        assertGt(IERC20(seUT1).totalSupply(), siblingSupply_, "reverse mints second FullSpread");
        PoolKey memory backing_ = fullSpread.key();
        (uint128 liquidity_,,) = pm.getPositionInfo(
            backing_.toId(), seUT, TickMath.minUsableTick(60), TickMath.maxUsableTick(60), bytes32(0)
        );
        assertGt(liquidity_, 0, "position owned by vault at full-range ticks and zero salt");
        address[5] memory holders_ = [seUT, seUT1, hook, address(swapRouter), user];
        address[5] memory currencies_ = [fullSpread.faceToken(), fullSpread.otherToken(), other, pairRecord.p0(), pairRecord.p1()];
        for (uint256 i; i < holders_.length; ++i) {
            for (uint256 j; j < currencies_.length; ++j) {
                assertEq(TransientStateLibrary.currencyDelta(pm, holders_[i], Currency.wrap(currencies_[j])), 0,
                    "every participating address closes its currency delta");
            }
        }
    }

    function test_row_rateTarget_currency1() public {
        uint256 snapshot_ = beforePair;
        for (uint256 i; i < 2; ++i) {
            assertTrue(vm.revertToState(snapshot_));
            snapshot_ = vm.snapshotState();
            _configureDual(i == 0);
            address primaryHook_ = hook;
            address pairShare_ = other;
            face = fullSpread.otherToken();
            _bindDual(fullSpread.currency1Provider());
            assertEq(other, pairShare_, "currency1 keeps the primary FullSpread sibling record");
            assertNotEq(hook, primaryHook_, "second rate-target product pool");
            assertEq(face < other, i == 0, "currency1 product index before swap");
            _crossVaultDirections();
        }
    }

    function test_row_index0() public { assertLt(uint160(face), uint160(other)); _crossVaultDirections(); }
    function test_row_index1() public {
        assertTrue(vm.revertToState(beforePair));
        _configureDual(false);
        assertGt(uint160(face), uint160(other));
        _crossVaultDirections();
    }

    /// @notice Preserve the historical name, proving implicit own shares with valid pair bindings.
    function test_row_identity_thisVault() public {
        FullSpreadV4MatrixChecks.membership(seUT, face);
        FullSpreadV4MatrixChecks.membership(seUT1, other);
        _crossVaultDirections();
    }

    /// @notice Task 4 sanity: runs without entering not-yet-migrated hook accounting.
    function test_fixture_twoFullSpread_deploymentsAndMembership() public view {
        assertNotEq(seUT, seUT1);
        assertTrue(indexedexManager.isPackage(fullSpread.pkg()));
        assertTrue(_registry().isVault(seUT));
        assertTrue(_registry().isVault(seUT1));
        assertEq(address(IUniswapV4ProtocolAware(seUT).poolManager()), address(pm));
        assertEq(address(IUniswapV4ProtocolAware(seUT1).poolManager()), address(pm));
        PoolKey memory first_ = IUniswapV4SinglePositionAware(seUT).poolKey();
        PoolKey memory second_ = IUniswapV4SinglePositionAware(seUT1).poolKey();
        assertEq(keccak256(abi.encode(first_)), keccak256(abi.encode(fullSpread.key())));
        assertEq(keccak256(abi.encode(second_)), keccak256(abi.encode(pairRecord.backingKey())));
        assertNotEq(keccak256(abi.encode(first_)), keccak256(abi.encode(second_)));
        assertEq(address(first_.hooks), address(0));
        assertEq(address(second_.hooks), address(0));
        FullSpreadV4MatrixChecks.membership(seUT, face);
        FullSpreadV4MatrixChecks.membership(seUT1, other);
        _assertFixturePosition(seUT, first_);
        _assertFixturePosition(seUT1, second_);
        _assertFixtureProvider(fullSpread.currency0Provider(), seUT, fullSpread.faceToken());
        _assertFixtureProvider(fullSpread.currency1Provider(), seUT, fullSpread.otherToken());
        _assertFixtureProvider(pairRecord.provider(), seUT1, pairRecord.p0());
        _assertFixtureProvider(pairRecord.otherProvider(), seUT1, pairRecord.p1());
        assertGt(IERC20(seUT1).balanceOf(address(this)), 0, "sibling public bundle acquired shares");
        assertEq(IERC20(hook).totalSupply(), 0, "no Hook LP bootstrap needed");
    }

    /// @notice Task 4 sanity: public mint/redeem on both member faces of both genuine vaults.
    function test_fixture_twoFullSpread_publicSharesAndRedemption() public {
        address[2] memory vaults_ = [seUT, seUT1];
        for (uint256 i_; i_ < vaults_.length; ++i_) {
            address vault_ = vaults_[i_];
            address[] memory members_ = IBasicVault(vault_).vaultTokens();
            for (uint256 j_; j_ < members_.length; ++j_) {
                uint256 callerBefore_ = IERC20(vault_).balanceOf(address(this));
                uint256 supplyBefore_ = IERC20(vault_).totalSupply();
                uint256 shares_ = fullSpread.acquireShares(vault_, members_[j_], address(this), 10 ether);
                assertEq(IERC20(vault_).balanceOf(address(this)) - callerBefore_, shares_);
                assertGe(IERC20(vault_).totalSupply() - supplyBefore_, shares_, "public share mint");
                uint256 spend_ = shares_ / 20;
                IERC20(vault_).approve(vault_, spend_);
                uint256 recipientBefore_ = IERC20(members_[j_]).balanceOf(rowBob);
                supplyBefore_ = IERC20(vault_).totalSupply();
                callerBefore_ = IERC20(vault_).balanceOf(address(this));
                (uint256 output_, uint256 refund_) = IFullSpreadV4MatrixMoney(vault_).exchangeIn(
                    vault_, spend_, members_[j_], 1, rowBob, false, block.timestamp
                );
                assertEq(refund_, 0, "selected share quantity consumed completely");
                assertGt(output_, 0, "actual local pair proceeds");
                assertEq(IERC20(members_[j_]).balanceOf(rowBob) - recipientBefore_, output_);
                assertEq(callerBefore_ - IERC20(vault_).balanceOf(address(this)), spend_);
                assertEq(supplyBefore_ - IERC20(vault_).totalSupply(), spend_);
                _assertFixturePosition(vault_, IUniswapV4SinglePositionAware(vault_).poolKey());
            }
        }
        assertEq(IERC20(hook).totalSupply(), 0, "no Hook LP bootstrap needed");
    }

    /// @notice Both provider targets can occupy either product side without address searching.
    function test_fixture_memberOrientationsAndTargets() public {
        uint256 snapshot_ = beforePair;
        for (uint256 i_; i_ < 2; ++i_) {
            assertTrue(vm.revertToState(snapshot_));
            snapshot_ = vm.snapshotState();
            _configureDual(i_ == 0);
            assertEq(face < other, i_ == 0, "currency0 target product orientation");
            assertEq(dual.rateProvider(face), fullSpread.currency0Provider());
            address firstHook_ = hook;
            face = fullSpread.otherToken();
            _bindDual(fullSpread.currency1Provider());
            assertNotEq(firstHook_, hook, "separate rate-target product pools");
            assertEq(face < other, i_ == 0, "currency1 target product orientation");
            assertEq(dual.rateProvider(face), fullSpread.currency1Provider());
            FullSpreadV4MatrixChecks.membership(seUT, face);
            FullSpreadV4MatrixChecks.membership(seUT1, other);
            assertEq(IERC20(hook).totalSupply(), 0, "no Hook LP accounting needed");
        }
    }

    /// @notice A pool initialized on another manager is not a usable backing key on this package.
    function test_fixture_foreignManagerKey_reverts() public {
        address factoryOwner_ = IMultiStepOwnable(address(create3Factory)).owner();
        bytes memory code_ = ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager");
        vm.prank(factoryOwner_);
        IPoolManager foreign_ = IPoolManager(create3Factory.create3WithArgs(
            code_, abi.encode(factoryOwner_), keccak256("FullSpread.fixture.foreignManager")
        ));
        PoolKey memory wrong_ = fullSpread.key();
        wrong_.fee += 1;
        foreign_.initialize(wrong_, uint160(1) << 96);
        IFullSpreadPackage package_ = IFullSpreadPackage(fullSpread.pkg());
        IFullSpreadPackage.PkgArgs memory args_ = IFullSpreadPackage.PkgArgs(wrong_);
        address predicted_ = diamondFactory.calcAddress(package_, abi.encode(args_));
        assertEq(predicted_.code.length, 0);
        vm.expectRevert(IFullSpreadPackage.InvalidPoolKey.selector);
        package_.deployVault(args_);
        assertEq(predicted_.code.length, 0, "no partial usable vault");
        assertFalse(_registry().isVault(predicted_));
    }

    function _assertFixtureProvider(address provider_, address vault_, address member_) internal view {
        assertNotEq(provider_, vault_);
        assertGt(provider_.code.length, 0);
        assertEq(address(IStandardExchangeRateProvider(provider_).reserveVault()), vault_);
        assertEq(address(IStandardExchangeRateProvider(provider_).rateTarget()), member_);
    }

    function _assertFixturePosition(address vault_, PoolKey memory backing_) internal view {
        IUniswapV4SinglePositionAware position_ = IUniswapV4SinglePositionAware(vault_);
        assertEq(position_.tickLower(), TickMath.minUsableTick(60));
        assertEq(position_.tickUpper(), TickMath.maxUsableTick(60));
        assertEq(position_.positionSalt(), bytes32(0));
        (uint128 liquidity_,,) = pm.getPositionInfo(
            backing_.toId(), vault_, position_.tickLower(), position_.tickUpper(), bytes32(0)
        );
        assertGt(liquidity_, 0, "separate real vault-owned position");
        assertEq(liquidity_, position_.positionLiquidity());
        assertEq(TransientStateLibrary.currencyDelta(pm, vault_, backing_.currency0), 0);
        assertEq(TransientStateLibrary.currencyDelta(pm, vault_, backing_.currency1), 0);
    }

    /// @notice Own-share recognition does not waive pair-token membership.
    function test_row_nonmemberShareBinding_reverts() public {
        IDualPackage.PkgArgs memory args_ = IDualPackage.PkgArgs({
            poolManager: address(pm), feeOracle: address(indexedexManager),
            standardExchange0: seUT, token0: seUT, standardExchange1: seUT1, token1: other,
            rateProvider0: fullSpread.currency0Provider(), rateProvider1: pairRecord.provider()
        });
        vm.expectRevert(IDualPackage.TokenNotInVaultTokens.selector);
        hookPkg.processArgs(abi.encode(args_));
    }

    /// @notice Each pair input acquires shares before the actual five-percent redemption.
    function test_row_initialPairInput_convertsThenRedeemsFivePercent() public {
        uint256 faceBefore_ = IERC20(face).balanceOf(user);
        uint256 otherBefore_ = IERC20(other).balanceOf(user);
        (uint256 amount0_, uint256 amount1_) = _c(10 ether, 10 ether);
        vm.recordLogs();
        vm.prank(user);
        (uint256 net_, uint256 used0_, uint256 used1_) = dual.deposit(amount0_, amount1_, user, 1, block.timestamp);
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        assertGt(net_, 0);
        assertEq(used0_, amount0_);
        assertEq(used1_, amount1_);
        assertEq(IERC20(face).balanceOf(user), faceBefore_ - 10 ether);
        assertEq(IERC20(other).balanceOf(user), otherBefore_ - 10 ether);
        assertEq(IERC20(hook).balanceOf(address(0)), 1000);
        address[2] memory exchanges_ = [seUT, seUT1];
        for (uint256 i_; i_ < 2; ++i_) {
            uint256 minted_;
            uint256 burned_;
            for (uint256 j_; j_ < logs_.length; ++j_) {
                Vm.Log memory log_ = logs_[j_];
                if (log_.emitter != exchanges_[i_] || log_.topics.length != 3
                    || log_.topics[0] != keccak256("Transfer(address,address,uint256)")) continue;
                if (log_.topics[1] == bytes32(0) && log_.topics[2] == bytes32(uint256(uint160(hook))))
                    minted_ += abi.decode(log_.data, (uint256));
                if (log_.topics[1] == bytes32(uint256(uint160(hook))) && log_.topics[2] == bytes32(0))
                    burned_ += abi.decode(log_.data, (uint256));
            }
            assertGt(minted_, 0);
            assertGt(burned_, 0);
            assertEq(burned_, minted_ / 20, "five percent of actual acquired shares");
            assertEq(IERC20(exchanges_[i_]).balanceOf(hook), minted_ - burned_);
        }
        assertGt(IERC20(face).balanceOf(hook), 0);
        assertGt(IERC20(other).balanceOf(hook), 0);
    }

    /// @notice Actual receipts support ongoing pair/share zaps without a transition-quote interface.
    function test_row_singleInput_pairAndShareFundPaidSwaps() public {
        _seed();
        uint256 beforeLp_ = IERC20(hook).balanceOf(user);
        uint256 supply_ = IERC20(hook).totalSupply();
        uint256 feeLp_ = IERC20(hook).balanceOf(dual.feeTo());
        vm.prank(user);
        uint256 net_ = dual.depositSingle(face, 10 ether, user, 1, block.timestamp);
        assertGt(net_, 0);
        assertEq(IERC20(hook).balanceOf(user) - beforeLp_, net_);
        assertEq(IERC20(hook).totalSupply() - supply_,
            net_ + IERC20(hook).balanceOf(dual.feeTo()) - feeLp_, "fee is split from backed gross");
        uint256 shares_ = fullSpread.acquireShares(seUT, face, user, 10 ether);
        beforeLp_ = IERC20(hook).balanceOf(user);
        supply_ = IERC20(hook).totalSupply();
        feeLp_ = IERC20(hook).balanceOf(dual.feeTo());
        vm.startPrank(user);
        IERC20(seUT).approve(hook, shares_);
        net_ = dual.depositSingle(seUT, shares_, user, 1, block.timestamp);
        vm.stopPrank();
        assertGt(net_, 0);
        assertEq(IERC20(hook).balanceOf(user) - beforeLp_, net_);
        assertEq(IERC20(hook).totalSupply() - supply_,
            net_ + IERC20(hook).balanceOf(dual.feeTo()) - feeLp_, "share-input fee split");
    }

    // Leg 1 is a sibling vault token. Membership is vaultTokens(), not asset().
    function test_row_bind_deploysThroughPackage() public override { _crossVaultDirections(); }
    function test_row_poolManagerSwap_bothDirections_noFaceResidual() public override {
        _crossVaultDirections();
        _exactOutNegative();
    }
    function test_row_bufferFirst_restingFace_notPaidToJoiner() public override {
        uint256 joiner_ = IERC20(face).balanceOf(user);
        fullSpread.fund(hook, 500 ether);
        _seed();
        assertLe(IERC20(face).balanceOf(user), joiner_, "resting face is not paid to the joiner");
        assertGe(IERC20(face).balanceOf(hook), 500 ether, "unbooked donation stays outside caller seed");
    }
    // This vault refunds unconsumed input to its caller; it has no sleeve.
    function test_row_partialConsumption_bookedNotRefunded() public override {
        FullSpreadV4MatrixChecks.refunds(fullSpread, hook, face);
        _crossVaultDirections();
    }
    function test_row_hookSwap_exactIn_eoaPretransferRejected() public override {
        _seed();
        uint256 before_ = IERC20(face).balanceOf(rowEoa);
        vm.prank(rowEoa);
        vm.expectRevert();
        IFullSpreadV4MatrixMoney(hook).exchangeIn(other, 1 ether, face, 0, rowEoa, true, block.timestamp);
        assertEq(IERC20(face).balanceOf(rowEoa), before_);
    }
    // Exact-out is absent, not a positive zero-preview quote.
    function test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed() public override {
        _seed();
        _localExactOut(true);
    }
    function test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly() public override {
        _seed();
        _localExactOut(false);
    }
    function _exactOutNegative() internal {
        uint256 f_ = IERC20(face).balanceOf(user);
        uint256 o_ = IERC20(other).balanceOf(user);
        uint256 unavailable_ = IERC20(other).balanceOf(hook) + 1 ether;
        SwapParams memory p_ = SwapParams(face < other, int256(unavailable_), face < other ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1);
        vm.prank(user);
        vm.expectRevert();
        swapRouter.swapExactOut(poolKey, p_, 100 ether, "");
        assertEq(IERC20(face).balanceOf(user), f_, "unavailable deficit spends no face");
        assertEq(IERC20(other).balanceOf(user), o_, "unavailable deficit pays no output");
    }

    function _localExactOut(bool prepaid_) internal {
        uint256 local_ = IERC20(face).balanceOf(hook);
        uint256 wanted_ = local_ / 2;
        uint256 shares_ = IERC20(seUT).balanceOf(hook);
        uint256 supply_ = IERC20(seUT).totalSupply();
        uint256 lpSupply_ = IERC20(hook).totalSupply();
        uint256 used_ = IStandardExchangeOut(hook).previewExchangeOut(IERC20(other), IERC20(face), wanted_);
        assertGt(wanted_, 0);
        assertGt(used_, 0);
        uint256 maximum_ = used_ * 3;
        SimpleMintableERC20(other).mint(address(this), maximum_);
        if (prepaid_) {
            IERC20(other).approve(address(rowCaller), maximum_);
            bytes memory data_ = abi.encodeCall(IStandardExchangeOut.exchangeOut,
                (IERC20(other), maximum_, IERC20(face), wanted_, address(rowCaller), true, block.timestamp));
            uint256 actual_ = abi.decode(rowCaller.consumePretransfer(IERC20(other), address(this), hook, maximum_, data_), (uint256));
            assertEq(actual_, used_);
            assertEq(IERC20(other).balanceOf(address(rowCaller)), maximum_ - used_, "refund only unused caller credit");
            assertEq(IERC20(face).balanceOf(address(rowCaller)), wanted_);
        } else {
            IERC20(other).approve(hook, maximum_);
            uint256 beforeInput_ = IERC20(other).balanceOf(address(this));
            uint256 beforeOutput_ = IERC20(face).balanceOf(address(this));
            uint256 actual_ = IStandardExchangeOut(hook).exchangeOut(IERC20(other), maximum_, IERC20(face),
                wanted_, address(this), false, block.timestamp);
            assertEq(actual_, used_);
            assertEq(beforeInput_ - IERC20(other).balanceOf(address(this)), used_);
            assertEq(IERC20(face).balanceOf(address(this)) - beforeOutput_, wanted_);
        }
        assertEq(IERC20(face).balanceOf(hook), local_ - wanted_);
        assertEq(IERC20(seUT).balanceOf(hook), shares_);
        assertEq(IERC20(seUT).totalSupply(), supply_, "no unavailable FullSpread exact-out call");
        assertEq(IERC20(hook).totalSupply(), lpSupply_, "swap mints no LP");
    }
    // Force the public minimum failure instead of mocking a V3 pool mint.
    function test_row_seFailure_rollsBack() public override { FullSpreadV4MatrixChecks.rollback(fullSpread, face); }
    function test_row_previewMatchesExecution() public override { _crossVaultDirections(); }
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

    /// @notice Cold primary-target redemption must exceed local inventory and burn SE supply.
    /// forge-config: default.isolate = true
    function test_composedRouteGasFitsCeiling_currency0_redeem() public {
        _composedGas(false, true);
    }

    /// @notice Cold mint through a separate product pool using the second provider target.
    /// forge-config: default.isolate = true
    function test_composedRouteGasFitsCeiling_currency1_mint() public {
        _composedGas(true, false);
    }

    /// @notice Cold second-target redemption, including hook work and actual SE burn.
    /// forge-config: default.isolate = true
    function test_composedRouteGasFitsCeiling_currency1_redeem() public {
        _composedGas(true, true);
    }

    function _composedGas(bool currency1_, bool redeem_) internal {
        if (currency1_) {
            address primaryHook_ = hook;
            face = fullSpread.otherToken();
            _bindDual(fullSpread.currency1Provider());
            assertNotEq(hook, primaryHook_, "separate second-target product pool");
            assertEq(dual.rateProvider(face), fullSpread.currency1Provider());
        }
        _seed();
        address tokenIn_ = redeem_ ? other : face;
        address tokenOut_ = redeem_ ? face : other;
        uint256 amount_ = redeem_ ? 30 ether : 1 ether;
        uint256 preview_ = dual.previewSwapExactIn(tokenIn_ < tokenOut_, amount_);
        uint256 previewGas_ = vm.lastFrameGas().gasTotalUsed;
        assertGt(preview_, 0, "measured preview is executable");
        assertLe(previewGas_, 5_000_000, "cold preview gas ceiling");
        if (redeem_) assertGt(preview_, IERC20(face).balanceOf(hook), "output requires primary SE redemption");
        emit log_named_uint("G03.coldPreviewGas", previewGas_);
        uint256 before_ = IERC20(tokenOut_).balanceOf(user);
        bool z_ = tokenIn_ < tokenOut_;
        uint256 used_ = FullSpreadV4MatrixChecks.coldSwap(
            swapRouter, poolKey,
            SwapParams(z_, -int256(amount_), z_ ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1), user, seUT, !redeem_
        );
        assertEq(IERC20(tokenOut_).balanceOf(user) - before_, preview_, "cold route output equals preview");
        emit log_named_uint("G03.coldWholeTransactionGas", used_);
    }

    /// forge-config: default.isolate = true
    function test_composedRouteGasFitsCeiling() public {
        _seed();
        bool z_ = face < other;
        uint256 preview_ = dual.previewSwapExactIn(face < other, _f(1));
        uint256 previewGas_ = vm.lastFrameGas().gasTotalUsed;
        assertGt(preview_, 0, "measured preview is executable");
        assertLe(previewGas_, 5_000_000, "cold preview gas ceiling");
        emit log_named_uint("G03.coldPreviewGas", previewGas_);
        uint256 used_ = FullSpreadV4MatrixChecks.coldSwap(
            swapRouter, poolKey,
            SwapParams(z_, -int256(_f(1)), z_ ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1),
            user, seUT
        );
        emit log_named_uint("G03.coldWholeTransactionGas", used_);
    }
}
