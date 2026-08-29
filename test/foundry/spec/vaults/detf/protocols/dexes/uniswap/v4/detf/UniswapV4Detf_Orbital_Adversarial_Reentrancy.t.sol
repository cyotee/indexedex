// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Orbital_Adversarial} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital_Adversarial.sol";

/// @dev Hostile pair: transferFrom reenters target, then completes (records nested error).
///      Copied from family CP DETF mint-only reentrancy harness. Not a new hostile token.
contract OrbitalHostilePairToken is SimpleMintableERC20 {
    address public target;
    bytes public reentryCall;
    bool public armed;
    uint256 private _depth;
    uint256 public reentryAttempts;
    bool public nestedCallSucceeded;
    bytes4 public nestedErrorSelector;

    constructor() SimpleMintableERC20("HostilePairO", "HPAIRO") {}

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
 * @title UniswapV4Detf_Orbital_Adversarial_Reentrancy
 * @notice Orbital gold mint reentrancy during pair transferFrom hits IsLocked.
 * @dev reentrancy burn/bond N/A family had mint only
 */
contract UniswapV4Detf_Orbital_Adversarial_Reentrancy is TestBase_UniswapV4Detf_Orbital_Adversarial {
    OrbitalHostilePairToken internal hostilePair;
    address internal hostileSe;
    address internal hostileDetf;
    IUniswapV4Detf internal hostileInfo;

    function setUp() public override {
        super.setUp();

        hostilePair = new OrbitalHostilePairToken();
        SimpleYieldERC4626 hostileVault = new SimpleYieldERC4626(hostilePair);
        hostileSe = _deployERC4626SE(address(hostileVault));

        IUniswapV4Detf.PkgArgs memory args = _uniqueDetfArgs("hReO");
        hostileDetf = _deployHookThenDetfForPair(args, address(hostilePair), hostileSe);
        hostileInfo = IUniswapV4Detf(hostileDetf);

        hostilePair.mint(detfUser, 10_000_000 ether);
        vm.startPrank(detfUser);
        hostilePair.approve(hostileDetf, type(uint256).max);
        pair0.approve(hostileDetf, type(uint256).max);
        pair1.approve(hostileDetf, type(uint256).max);
        hostileInfo.bond(
            IERC20(address(hostilePair)),
            400 ether,
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
            uint256(1 ether),
            DEFAULT_MIN_LOCK,
            detfUser,
            false,
            _deadline()
        );
        hostilePair.arm(hostileDetf, reentry);

        vm.startPrank(detfUser);
        uint256 out_ = hostileInfo.mint(
            IERC20(address(hostilePair)),
            50 ether,
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
        hostilePair.disarm();
    }
}
