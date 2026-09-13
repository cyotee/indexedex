// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";


import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Adversarial_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Adversarial_Decimals.sol";

/// @dev Hostile pair: transferFrom reenters target, then completes (records nested error).
///      Copied from family CP DETF mint-only reentrancy harness. Not a new hostile token.
contract HostilePairTokenDecimals is MintableERC20Decimals {
    address public target;
    bytes public reentryCall;
    bool public armed;
    uint256 private _depth;
    uint256 public reentryAttempts;
    bool public nestedCallSucceeded;
    bytes4 public nestedErrorSelector;

    constructor(uint8 decimals_) MintableERC20Decimals("HostilePair", "HPAIR", decimals_) {}

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

/**
 * @title Adversarial_Reentrancy
 * @notice Mint reentrancy during pair transferFrom hits IsLocked.
 * @dev reentrancy burn/bond N/A family had mint only
 */
abstract contract Adversarial_Reentrancy_Decimals_DexUniV4Det is TestBase_UniswapV4Detf_Adversarial_Decimals {
    HostilePairTokenDecimals internal hostilePair;
    address internal hostileSe;
    address internal hostileDetf;
    IUniswapV4Detf internal hostileInfo;

    function setUp() public override {
        super.setUp();

        hostilePair = new HostilePairTokenDecimals(_pairDecimals());
        SimpleYieldERC4626 hostileVault = new SimpleYieldERC4626(hostilePair);
        hostileSe = _deployERC4626SE(address(hostileVault));

        IUniswapV4Detf.PkgArgs memory args = _uniqueDetfArgs("hRe");
        hostileDetf = _deployHookThenDetfForPair(args, address(hostilePair), hostileSe);
        hostileInfo = IUniswapV4Detf(hostileDetf);

        hostilePair.mint(detfUser, _uPair(10_000_000));
        vm.startPrank(detfUser);
        hostilePair.approve(hostileDetf, type(uint256).max);
        hostileInfo.bond(
            IERC20(address(hostilePair)),
            _uPair(400),
            DEFAULT_MIN_LOCK,
            detfUser,
            false,
            _deadline()
        );
        vm.stopPrank();
        assertTrue(hostileInfo.isReserveLive(), "hostile detf live");
    }

    function test_reentrancy_mint_hitsIsLocked() public {
        bytes memory reentry = abi.encodeWithSelector(
            IUniswapV4Detf.bond.selector,
            IERC20(address(hostilePair)),
            uint256(_uPair(1)),
            DEFAULT_MIN_LOCK,
            detfUser,
            false,
            _deadline()
        );
        // Prove the exact callback succeeds when the DETF is unlocked and
        // leave a second funded payment available for the nested attempt.
        hostilePair.mint(address(hostilePair), 2 * _uPair(1));
        vm.prank(address(hostilePair));
        hostilePair.approve(hostileDetf, 2 * _uPair(1));
        vm.prank(address(hostilePair));
        (bool controlOk,) = hostileDetf.call(reentry);
        assertTrue(controlOk, "funded callback succeeds outside the lock");
        hostilePair.arm(hostileDetf, reentry);

        vm.startPrank(detfUser);
        uint256 out_ = IStandardExchangeIn(hostileDetf).exchangeIn(
            IERC20(address(hostilePair)),
            _uPair(50),
            IERC20(hostileDetf),
            0,
            detfUser,
            false,
            _deadline()
        );
        vm.stopPrank();

        assertGt(out_, 0, "outer mint completed");
        assertGe(hostilePair.reentryAttempts(), 1, "reentry attempted during transferFrom");
        assertFalse(hostilePair.nestedCallSucceeded(), "nested bond blocked");
        assertEq(hostilePair.nestedErrorSelector(), IReentrancyLock.IsLocked.selector, "IsLocked");
        assertEq(hostilePair.balanceOf(address(hostilePair)), _uPair(1), "locked callback cannot spend its payment");
        hostilePair.disarm();
    }
}
