// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    TestBase_UniswapV4StandardExchangeCurveQuadStableDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableDETF.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableDETF,
    IUniswapV4StandardExchangeCurveQuadStableDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableDETF.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableDETFRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableDETFRepo.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol";

/// @dev Hostile pair: transferFrom reenters target, then completes (records nested error).
contract HostileQuadPairToken is SimpleMintableERC20 {
    address public target;
    bytes public reentryCall;
    bool public armed;
    uint256 private _depth;
    uint256 public reentryAttempts;
    bool public nestedCallSucceeded;
    bytes4 public nestedErrorSelector;

    constructor() SimpleMintableERC20("HostileQuadPair", "HQAD") {}

    function arm(address target_, bytes memory reentryCall_) external {
        target = target_;
        reentryCall = reentryCall_;
        armed = true;
        reentryAttempts = 0;
        nestedCallSucceeded = false;
        nestedErrorSelector = bytes4(0);
    }

    function disarm() external {
        armed = false;
    }

    function transfer(address to_, uint256 value_) public override returns (bool) {
        _maybeReenter();
        _transfer(msg.sender, to_, value_);
        return true;
    }

    function transferFrom(address from_, address to_, uint256 value_) public override returns (bool) {
        _maybeReenter();
        uint256 allowed = allowance[from_][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= value_, "allowance");
            allowance[from_][msg.sender] = allowed - value_;
        }
        _transfer(from_, to_, value_);
        return true;
    }

    function _maybeReenter() private {
        if (armed && _depth == 0) {
            _depth = 1;
            unchecked {
                ++reentryAttempts;
            }
            (bool ok_, bytes memory ret_) = target.call(reentryCall);
            nestedCallSucceeded = ok_;
            if (!ok_ && ret_.length >= 4) {
                bytes4 sel;
                assembly {
                    sel := mload(add(ret_, 0x20))
                }
                nestedErrorSelector = sel;
            }
            _depth = 0;
        }
    }
}

/// @dev Records transfer-to-hook order so residual sells can be asserted address-ascending.
contract QuadResidualOrderLog {
    address[] public tokens;

    function record() external {
        tokens.push(msg.sender);
    }

    function length() external view returns (uint256) {
        return tokens.length;
    }

    function tokenAt(uint256 i) external view returns (address) {
        return tokens[i];
    }
}

contract QuadLoggedPairToken is SimpleMintableERC20 {
    QuadResidualOrderLog public immutable log;
    address public hook;

    constructor(QuadResidualOrderLog log_, string memory name_, string memory symbol_)
        SimpleMintableERC20(name_, symbol_)
    {
        log = log_;
    }

    function setHook(address hook_) external {
        hook = hook_;
    }

    function transfer(address to_, uint256 value_) public override returns (bool) {
        if (hook != address(0) && to_ == hook) {
            log.record();
        }
        _transfer(msg.sender, to_, value_);
        return true;
    }
}

/// @notice Nested reentrancy → IsLocked; empty protocol burn; burn never calls withdrawSingle.
contract UniswapV4StandardExchangeCurveQuadStableDETF_Adversarial is
    TestBase_UniswapV4StandardExchangeCurveQuadStableDETF
{
    uint256 internal constant BOND_AMT = 100 ether;

    HostileQuadPairToken internal hostilePair;
    address internal hostileDetf;
    IUniswapV4StandardExchangeCurveQuadStableDETF internal hostileDetfInfo;
    IStandardExchangeIn internal hostileDetfX;

    function setUp() public override {
        super.setUp();

        hostilePair = new HostileQuadPairToken();
        IERC20[] memory pairs_ = new IERC20[](3);
        pairs_[0] = IERC20(address(token0));
        pairs_[1] = IERC20(address(token1));
        pairs_[2] = IERC20(address(hostilePair));
        IStandardExchangeProxy[] memory ses_ = new IStandardExchangeProxy[](3);
        ses_[0] = IStandardExchangeProxy(se0);
        IERC20[] memory shares_ = new IERC20[](3);
        address[] memory rps_ = new address[](3);
        uint256[] memory rates_ = new uint256[](3);
        rates_[0] = DEFAULT_CREATION;
        rates_[1] = DEFAULT_CREATION;
        rates_[2] = DEFAULT_CREATION;

        IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args =
        IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs({
            name: "Hostile Quad DETF",
            symbol: "hQad",
            pairTokens: pairs_,
            standardExchanges: ses_,
            vaultShares: shares_,
            rateProviders: rps_,
            creationPairPerDetfWad: rates_,
            baseAmp: DEFAULT_BASE_AMP,
            mintThreshold: 0,
            burnThreshold: 0,
            thresholdMode: ThresholdMode.Open,
            expansionEpochLength: 0,
            expansionClosureRatePerYearWad: 0,
            expansionMaxCatchUpEpochs: 0,
            creator: address(0)
        });

        hostileDetf = _deployDetfWired(args);
        hostileDetfInfo = IUniswapV4StandardExchangeCurveQuadStableDETF(hostileDetf);
        hostileDetfX = IStandardExchangeIn(hostileDetf);
        _setBondTermsFor(hostileDetf);

        hostilePair.mint(detfUser, 10_000_000 ether);
        token0.mint(detfUser, 10_000_000 ether);
        token1.mint(detfUser, 10_000_000 ether);
        vm.startPrank(detfUser);
        hostilePair.approve(hostileDetf, type(uint256).max);
        token0.approve(hostileDetf, type(uint256).max);
        token1.approve(hostileDetf, type(uint256).max);
        vm.stopPrank();

        uint256[] memory amts = new uint256[](3);
        amts[0] = 400 ether;
        amts[1] = 400 ether;
        amts[2] = 400 ether;
        _firstBondOn(hostileDetf, amts, address(token0));
        assertTrue(hostileDetfInfo.isReserveLive(), "hostile detf live");
    }

    function test_reentrancy_mint_hitsIsLocked() public {
        bytes memory reentry = abi.encodeWithSelector(
            IStandardExchangeIn.exchangeIn.selector,
            IERC20(address(hostilePair)),
            uint256(1 ether),
            IERC20(hostileDetf),
            uint256(0),
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        hostilePair.arm(hostileDetf, reentry);

        vm.startPrank(detfUser);
        uint256 out_ = hostileDetfX.exchangeIn(
            IERC20(address(hostilePair)),
            50 ether,
            IERC20(hostileDetf),
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertGt(out_, 0, "outer mint completed");
        assertGe(hostilePair.reentryAttempts(), 1, "reentry attempted during transferFrom");
        assertFalse(hostilePair.nestedCallSucceeded(), "nested mint blocked");
        assertEq(hostilePair.nestedErrorSelector(), IReentrancyLock.IsLocked.selector, "IsLocked");
        hostilePair.disarm();
    }

    function test_emptyProtocolLp_burn_reverts() public {
        _firstBondDefault(BOND_AMT);
        uint256 free_ = IERC20(detf).balanceOf(detfUser);
        if (free_ == 0) return;
        if (detfInfo.protocolLp() == 0) {
            vm.startPrank(detfUser);
            IERC20(detf).approve(detf, type(uint256).max);
            vm.expectRevert();
            detfExchangeIn.exchangeIn(
                IERC20(detf), free_ / 10, IERC20(pair0), 0, detfUser, false, block.timestamp + 1 hours
            );
            vm.stopPrank();
        }
    }

    function test_burn_neverCallsWithdrawSingle() public {
        address d = _deployDetfWired(_openArgsUnique("noWdraw"));
        IUniswapV4StandardExchangeCurveQuadStableDETF info =
            IUniswapV4StandardExchangeCurveQuadStableDETF(d);
        _setBondTermsFor(d);
        uint256[] memory amts = new uint256[](3);
        amts[0] = BOND_AMT;
        amts[1] = BOND_AMT;
        amts[2] = BOND_AMT;
        _firstBondOn(d, amts, info.pairToken(0));
        _mintOn(d, info.pairToken(0), 20 ether);

        address hook = info.reserveHook();
        uint256 bal = IERC20(d).balanceOf(detfUser);
        require(bal > 1 ether, "have detf");

        _expectNoWithdrawSingle(hook);
        _burnOn(d, info.pairToken(1), bal / 10);
    }

    function test_claim_neverCallsWithdrawSingle() public {
        address d = _deployDetfWired(_openArgsUnique("noWdrawC"));
        IUniswapV4StandardExchangeCurveQuadStableDETF info =
            IUniswapV4StandardExchangeCurveQuadStableDETF(d);
        _setBondTermsFor(d);
        uint256[] memory amts = new uint256[](3);
        amts[0] = BOND_AMT;
        amts[1] = BOND_AMT;
        amts[2] = BOND_AMT;
        _firstBondOn(d, amts, info.pairToken(0));
        _mintOn(d, info.pairToken(0), 20 ether);

        address hook = info.reserveHook();
        vm.startPrank(detfUser);
        IERC20(info.pairToken(0)).approve(d, type(uint256).max);
        uint256 claimOut = info.depositClaim(IERC20(info.pairToken(0)), 3 ether, 0, detfUser, false, _dl());
        require(claimOut > 1, "claim minted");
        IERC20(info.rebasingClaimToken()).approve(d, type(uint256).max);
        _expectNoWithdrawSingle(hook);
        uint256 paid = info.redeemClaim(claimOut / 2, IERC20(info.pairToken(2)), 0, detfUser, _dl());
        vm.stopPrank();
        assertGt(paid, 0);
    }

    function test_close_neverCallsWithdrawSingle() public {
        address d = _deployDetfWired(_openArgsUnique("noWdrawX"));
        IUniswapV4StandardExchangeCurveQuadStableDETF info =
            IUniswapV4StandardExchangeCurveQuadStableDETF(d);
        _setBondTermsFor(d);
        uint256[] memory amts = new uint256[](3);
        amts[0] = BOND_AMT;
        amts[1] = BOND_AMT;
        amts[2] = BOND_AMT;
        (uint256 tokenId,) = _firstBondOn(d, amts, info.pairToken(0));
        _mintOn(d, info.pairToken(0), 20 ether);
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);

        address hook = info.reserveHook();
        _expectNoWithdrawSingle(hook);

        vm.prank(detfUser);
        uint256[] memory out_ = info.closeBondMature(tokenId, _zeroMinOut(d), detfUser, _dl());
        uint256 paid_;
        for (uint256 i; i < out_.length; ++i) paid_ += out_[i];
        assertGt(paid_, 0);
    }

    function test_burn_residual_addressAscending() public {
        QuadResidualOrderLog log = new QuadResidualOrderLog();
        QuadLoggedPairToken loggedA = new QuadLoggedPairToken(log, "LogA", "LA");
        QuadLoggedPairToken loggedB = new QuadLoggedPairToken(log, "LogB", "LB");

        IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args = _openArgsUnique("ord");
        args.pairTokens[0] = IERC20(address(token0));
        args.pairTokens[1] = IERC20(address(loggedA));
        args.pairTokens[2] = IERC20(address(loggedB));
        args.standardExchanges[0] = IStandardExchangeProxy(se0);
        args.standardExchanges[1] = IStandardExchangeProxy(address(0));
        args.standardExchanges[2] = IStandardExchangeProxy(address(0));

        address d = _deployDetfWired(args);
        IUniswapV4StandardExchangeCurveQuadStableDETF info =
            IUniswapV4StandardExchangeCurveQuadStableDETF(d);
        _setBondTermsFor(d);

        address hook = info.reserveHook();
        loggedA.setHook(hook);
        loggedB.setHook(hook);
        loggedA.mint(detfUser, 10_000_000 ether);
        loggedB.mint(detfUser, 10_000_000 ether);
        vm.startPrank(detfUser);
        loggedA.approve(d, type(uint256).max);
        loggedB.approve(d, type(uint256).max);
        IERC20(address(token0)).approve(d, type(uint256).max);
        vm.stopPrank();

        uint256[] memory amts = new uint256[](3);
        amts[0] = BOND_AMT;
        amts[1] = BOND_AMT;
        amts[2] = BOND_AMT;
        _firstBondOn(d, amts, info.pairToken(0));
        _mintOn(d, info.pairToken(0), 20 ether);

        uint256 before_ = log.length();
        uint256 bal = IERC20(d).balanceOf(detfUser);
        require(bal > 1 ether, "have detf");
        _burnOn(d, info.pairToken(0), bal / 10);

        uint256 after_ = log.length();
        assertEq(after_, before_ + 2, "two non-out pairs sold to hook");
        address first_ = log.tokenAt(before_);
        address second_ = log.tokenAt(before_ + 1);
        assertTrue(first_ < second_, "residual sells address-ascending");
        assertTrue(
            (first_ == address(loggedA) && second_ == address(loggedB))
                || (first_ == address(loggedB) && second_ == address(loggedA)),
            "logged pairs only"
        );
    }

    function test_reentrancy_burn_hitsIsLocked() public {
        _mintOn(hostileDetf, address(token0), 20 ether);
        uint256 bal = IERC20(hostileDetf).balanceOf(detfUser);
        require(bal > 1 ether, "have detf");

        bytes memory reentry = abi.encodeWithSelector(
            IStandardExchangeIn.exchangeIn.selector,
            IERC20(hostileDetf),
            uint256(1 ether),
            IERC20(address(hostilePair)),
            uint256(0),
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        hostilePair.arm(hostileDetf, reentry);

        uint256 out_ = _burnOn(hostileDetf, address(hostilePair), bal / 10);
        assertGt(out_, 0, "outer burn completed");
        assertGe(hostilePair.reentryAttempts(), 1, "reentry during residual/payout transfer");
        assertFalse(hostilePair.nestedCallSucceeded(), "nested burn blocked");
        assertEq(hostilePair.nestedErrorSelector(), IReentrancyLock.IsLocked.selector, "IsLocked");
        hostilePair.disarm();
    }

    function test_reentrancy_bond_hitsIsLocked() public {
        bytes memory reentry = abi.encodeWithSelector(
            bytes4(keccak256("bond(address,uint256,uint256,address,bool,uint256)")),
            IERC20(address(hostilePair)),
            uint256(1 ether),
            DEFAULT_MIN_LOCK,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        hostilePair.arm(hostileDetf, reentry);

        vm.startPrank(detfUser);
        (uint256 tokenId, uint256 shares) = hostileDetfInfo.bond(
            IERC20(address(hostilePair)),
            5 ether,
            DEFAULT_MIN_LOCK,
            detfUser,
            false,
            _dl()
        );
        vm.stopPrank();

        assertGt(tokenId, 0, "outer bond completed");
        assertGt(shares, 0);
        assertGe(hostilePair.reentryAttempts(), 1, "reentry during bond transferFrom");
        assertFalse(hostilePair.nestedCallSucceeded(), "nested bond blocked");
        assertEq(hostilePair.nestedErrorSelector(), IReentrancyLock.IsLocked.selector, "IsLocked");
        hostilePair.disarm();
    }

    function test_reentrancy_claim_hitsIsLocked() public {
        vm.startPrank(detfUser);
        IERC20(address(token0)).approve(hostileDetf, type(uint256).max);
        uint256 claimOut = hostileDetfInfo.depositClaim(
            IERC20(address(token0)), 5 ether, 0, detfUser, false, _dl()
        );
        IERC20(hostileDetfInfo.rebasingClaimToken()).approve(hostileDetf, type(uint256).max);
        vm.stopPrank();
        require(claimOut > 1, "claim minted");

        bytes memory reentry = abi.encodeWithSelector(
            IUniswapV4StandardExchangeCurveQuadStableDETF.redeemClaim.selector,
            claimOut / 10,
            IERC20(address(hostilePair)),
            uint256(0),
            detfUser,
            block.timestamp + 1 hours
        );
        hostilePair.arm(hostileDetf, reentry);

        vm.prank(detfUser);
        uint256 paid = hostileDetfInfo.redeemClaim(
            claimOut / 2, IERC20(address(hostilePair)), 0, detfUser, _dl()
        );
        assertGt(paid, 0, "outer redeem completed");
        assertGe(hostilePair.reentryAttempts(), 1, "reentry during claim residual transfer");
        assertFalse(hostilePair.nestedCallSucceeded(), "nested redeem blocked");
        assertEq(hostilePair.nestedErrorSelector(), IReentrancyLock.IsLocked.selector, "IsLocked");
        hostilePair.disarm();
    }

    function test_burn_atomicRevert_leavesDetfUnburned() public {
        address d = _deployDetfWired(_openArgsUnique("atomic"));
        IUniswapV4StandardExchangeCurveQuadStableDETF info =
            IUniswapV4StandardExchangeCurveQuadStableDETF(d);
        IStandardExchangeIn ex = IStandardExchangeIn(d);
        _setBondTermsFor(d);
        uint256[] memory amts = new uint256[](3);
        amts[0] = BOND_AMT;
        amts[1] = BOND_AMT;
        amts[2] = BOND_AMT;
        _firstBondOn(d, amts, info.pairToken(0));
        _mintOn(d, info.pairToken(0), 20 ether);

        uint256 bal = IERC20(d).balanceOf(detfUser);
        require(bal > 1 ether, "have detf");
        uint256 burnAmt = bal / 10;
        uint256 preview = ex.previewExchangeIn(IERC20(d), burnAmt, IERC20(info.pairToken(1)));
        require(preview > 0, "preview");
        uint256 minOut_ = preview + 1 ether;
        vm.startPrank(detfUser);
        IERC20(d).approve(d, type(uint256).max);
        try ex.exchangeIn(
            IERC20(d), burnAmt, IERC20(info.pairToken(1)), minOut_, detfUser, false, _dl()
        ) returns (uint256 out_) {
            emit log_named_uint("unexpected burn out", out_);
            emit log_named_uint("minOut", minOut_);
            revert("burn should revert on minOut");
        } catch {
            // full tx revert after burn+redeposit+residual — user DETF restored
        }
        vm.stopPrank();
        assertEq(IERC20(d).balanceOf(detfUser), bal, "DETF unburned when burn reverts");
    }

    function test_preMaturity_sell_bondNotMature() public {
        (uint256 tokenId,) = _firstBondDefault(BOND_AMT);
        vm.startPrank(detfUser);
        vm.expectRevert();
        detfInfo.sellPositionToDetfNft(tokenId, detfUser);
        vm.stopPrank();
    }

    function _expectNoWithdrawSingle(address hook) internal {
        vm.expectCall(hook, abi.encodeWithSelector(IHook.withdrawSingle.selector), 0);
        vm.expectCall(hook, abi.encodeWithSelector(IHook.withdrawSingleExactOut.selector), 0);
        vm.expectCall(hook, abi.encodeWithSelector(IHook.exitSingleAssetExactBptIn.selector), 0);
        vm.expectCall(hook, abi.encodeWithSelector(IHook.exitSingleAssetExactTokenOut.selector), 0);
    }
}
