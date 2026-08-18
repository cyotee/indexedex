// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalDETF.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETF,
    IUniswapV4StandardExchangeOrbitalDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";
import {
    UniswapV4StandardExchangeOrbitalDETFRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalDETFRepo.sol";

/// @dev Hostile pair: transferFrom reenters target, then completes (records nested error).
contract HostileOrbitalPairToken is SimpleMintableERC20 {
    address public target;
    bytes public reentryCall;
    bool public armed;
    uint256 private _depth;
    uint256 public reentryAttempts;
    bool public nestedCallSucceeded;
    bytes4 public nestedErrorSelector;

    constructor() SimpleMintableERC20("HostileOrbPair", "HORB") {}

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

    function transferFrom(address from_, address to_, uint256 value_) public override returns (bool) {
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
        uint256 allowed = allowance[from_][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= value_, "allowance");
            allowance[from_][msg.sender] = allowed - value_;
        }
        _transfer(from_, to_, value_);
        return true;
    }
}

/// @notice Nested reentrancy -> IsLocked; empty protocol burn; redeposit path integrity.
contract UniswapV4StandardExchangeOrbitalDETF_AdversarialTest is TestBase_UniswapV4StandardExchangeOrbitalDETF {
    HostileOrbitalPairToken internal hostilePair;
    address internal hostileDetf;
    IUniswapV4StandardExchangeOrbitalDETF internal hostileDetfInfo;
    IStandardExchangeIn internal hostileDetfX;

    function setUp() public override {
        super.setUp();

        // Hostile bare pair1 + real SE on pair0 (token0/se0).
        hostilePair = new HostileOrbitalPairToken();
        IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgArgs memory args = _openArgs();
        args.name = "Hostile Orb DETF";
        args.symbol = "hOrb";
        args.pairToken0 = IERC20(address(token0));
        args.pairToken1 = IERC20(address(hostilePair));
        args.standardExchange0 = IStandardExchangeProxy(se0);
        args.standardExchange1 = IStandardExchangeProxy(address(0));
        args.thresholdMode = ThresholdMode.Open;

        hostileDetf = _deployDetfWired(args);
        hostileDetfInfo = IUniswapV4StandardExchangeOrbitalDETF(hostileDetf);
        hostileDetfX = IStandardExchangeIn(hostileDetf);

        hostilePair.mint(detfUser, 10_000_000 ether);
        token0.mint(detfUser, 10_000_000 ether);
        vm.startPrank(detfUser);
        hostilePair.approve(hostileDetf, type(uint256).max);
        token0.approve(hostileDetf, type(uint256).max);
        vm.stopPrank();
        _setBondTermsFor(hostileDetf);

        // Dual first bond -> live
        vm.startPrank(detfUser);
        hostileDetfInfo.bond(
            IERC20(address(token0)),
            400 ether,
            IERC20(address(hostilePair)),
            400 ether,
            DEFAULT_MIN_LOCK,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(hostileDetfInfo.isReserveLive(), "hostile detf live");
    }

    function _setBondTermsFor(address vault_) internal {
        try IVaultFeeOracleManager(address(indexedexManager)).setVaultBondTerms(
            vault_,
            BondTerms({
                minLockDuration: DEFAULT_MIN_LOCK,
                maxLockDuration: DEFAULT_MAX_LOCK,
                minBonusPercentage: 0,
                maxBonusPercentage: 0.5e18
            })
        ) {} catch {}
    }

    function test_reentrancy_mint_hitsIsLocked() public {
        // Nested exchangeIn reentry during hostile pair transferFrom of primary mint.
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
        // Fresh Open instance: first bond only -> protocol LP empty.
        address d2 = _deployDetfWired(_openArgs());
        IUniswapV4StandardExchangeOrbitalDETF info2 = IUniswapV4StandardExchangeOrbitalDETF(d2);
        IStandardExchangeIn ex2 = IStandardExchangeIn(d2);
        address p0 = info2.pairToken0();
        address p1 = info2.pairToken1();
        SimpleMintableERC20(p0).mint(detfUser, 1000 ether);
        SimpleMintableERC20(p1).mint(detfUser, 1000 ether);
        vm.startPrank(detfUser);
        IERC20(p0).approve(d2, type(uint256).max);
        IERC20(p1).approve(d2, type(uint256).max);
        info2.bond(
            IERC20(p0), 100 ether, IERC20(p1), 100 ether, DEFAULT_MIN_LOCK, detfUser, false, block.timestamp + 1 hours
        );
        assertEq(info2.protocolLp(), 0);
        deal(d2, detfUser, 1 ether);
        IERC20(d2).approve(d2, type(uint256).max);
        vm.expectRevert(Repo.EmptyProtocolLp.selector);
        ex2.exchangeIn(IERC20(d2), 1 ether, IERC20(p0), 0, detfUser, false, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function test_burn_redeposit_atomicity_or_success() public {
        // After mint, protocol LP exists; burn fully succeeds (redeposit + pay) or would full-revert.
        uint256 userDetf = _mintPairOn(hostileDetf, address(hostilePair), 30 ether);
        uint256 before = IERC20(address(hostilePair)).balanceOf(detfUser);
        vm.startPrank(detfUser);
        IERC20(hostileDetf).approve(hostileDetf, type(uint256).max);
        uint256 out_ = hostileDetfX.exchangeIn(
            IERC20(hostileDetf),
            userDetf / 3,
            IERC20(address(hostilePair)),
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(out_, 0);
        assertEq(IERC20(address(hostilePair)).balanceOf(detfUser) - before, out_);
    }

    function _mintPairOn(address detf_, address pair_, uint256 amount_) internal returns (uint256 userDetf) {
        vm.startPrank(detfUser);
        userDetf = IStandardExchangeIn(detf_).exchangeIn(
            IERC20(pair_), amount_, IERC20(detf_), 0, detfUser, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }
}
