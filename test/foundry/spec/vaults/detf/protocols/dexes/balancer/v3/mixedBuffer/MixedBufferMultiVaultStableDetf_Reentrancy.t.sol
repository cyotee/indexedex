// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {MockERC20} from "@crane/contracts/test/mocks/MockERC20.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {
    IMixedBufferMultiVaultStableDetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfDFPkg.sol";
import {
    IMixedBufferMultiVaultStableDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfBondingTarget.sol";
import {
    IMixedBufferMultiVaultStableDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfInfoTarget.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

/// @dev Hostile share that is also a 1:1 buffer wrapper SE (accept+produce buffer for MixedBuffer validation).
///      transferFrom re-enters DETF then ALWAYS completes transfer so probe state persists.
contract HostileBufferShareSE is MockERC20, IStandardExchange {
    IERC20 public immutable bufferToken;
    address public target;
    bytes public reentryCall;
    bool public armed;
    uint256 private _depth;

    uint256 public reentryAttempts;
    bool public nestedCallSucceeded;
    bytes4 public nestedErrorSelector;

    constructor(IERC20 buffer_) MockERC20("HostileShareSE", "HSE", 18) {
        bufferToken = buffer_;
    }

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
        return super.transferFrom(from_, to_, value_);
    }

    // --- Minimal IStandardExchange / vault surface for MixedBuffer accept+produce ---

    function vaultTokens() external view returns (address[] memory toks) {
        toks = new address[](2);
        toks[0] = address(bufferToken);
        toks[1] = address(this);
    }

    function previewExchangeIn(IERC20 tokenIn_, uint256 amountIn_, IERC20 tokenOut_)
        external
        view
        returns (uint256)
    {
        if (amountIn_ == 0) return 0;
        if (address(tokenIn_) == address(bufferToken) && address(tokenOut_) == address(this)) return amountIn_;
        if (address(tokenIn_) == address(this) && address(tokenOut_) == address(bufferToken)) return amountIn_;
        return 0;
    }

    function previewExchangeOut(IERC20 tokenIn_, IERC20 tokenOut_, uint256 amountOut_)
        external
        view
        returns (uint256)
    {
        if (amountOut_ == 0) return 0;
        if (address(tokenIn_) == address(this) && address(tokenOut_) == address(bufferToken)) return amountOut_;
        if (address(tokenIn_) == address(bufferToken) && address(tokenOut_) == address(this)) return amountOut_;
        return 0;
    }

    function exchangeIn(
        IERC20 tokenIn_,
        uint256 amountIn_,
        IERC20 tokenOut_,
        uint256 minAmountOut_,
        address recipient_,
        bool pretransferred_,
        uint256 /* deadline_ */
    ) external returns (uint256 amountOut_) {
        if (recipient_ == address(0)) recipient_ = msg.sender;
        if (address(tokenIn_) == address(bufferToken) && address(tokenOut_) == address(this)) {
            if (!pretransferred_) {
                bufferToken.transferFrom(msg.sender, address(this), amountIn_);
            }
            _mint(recipient_, amountIn_);
            amountOut_ = amountIn_;
        } else if (address(tokenIn_) == address(this) && address(tokenOut_) == address(bufferToken)) {
            if (!pretransferred_) {
                transferFrom(msg.sender, address(this), amountIn_);
            }
            _burn(address(this), amountIn_);
            bufferToken.transfer(recipient_, amountIn_);
            amountOut_ = amountIn_;
        } else {
            revert("HostileSE: route");
        }
        require(amountOut_ >= minAmountOut_, "min");
    }

    function exchangeOut(
        IERC20 /* tokenIn_ */,
        uint256 /* maxAmountIn_ */,
        IERC20 /* tokenOut_ */,
        uint256 /* amountOut_ */,
        address /* recipient_ */,
        bool /* pretransferred_ */,
        uint256 /* deadline_ */
    ) external pure returns (uint256) {
        revert("HostileSE: exactOut");
    }
}

contract DetfReentryTarget {
    function reenterExchangeIn(
        address detf_,
        IERC20 tokenIn_,
        uint256 amountIn_,
        IERC20 tokenOut_,
        address recipient_
    ) external {
        IStandardExchangeIn(detf_).exchangeIn(
            tokenIn_, amountIn_, tokenOut_, 0, recipient_, false, block.timestamp + 1 hours
        );
    }

    function reenterBond(address detf_, IERC20 share_, uint256 amountIn_, uint256 lock_, address recipient_)
        external
    {
        IMixedBufferMultiVaultStableDetfBonding(detf_).bond(
            share_, amountIn_, lock_, recipient_, false, block.timestamp + 1 hours
        );
    }
}

/// @notice Proves nonReentrant via nested exchangeIn during hostile share transferFrom.
/// @dev Control mint succeeds unarmed; armed path: reentryAttempts==1, nested IsLocked.
contract MixedBufferMultiVaultStableDetf_Reentrancy_Test is TestBase_MixedBufferMultiVaultStableDetf {
    HostileBufferShareSE internal hostileShare;
    DetfReentryTarget internal reentryTarget;
    address internal outerDetf;
    IMixedBufferMultiVaultStableDetfInfo internal outerInfo;
    IStandardExchangeIn internal outerEx;
    IMixedBufferMultiVaultStableDetfBonding internal outerBonding;

    function setUp() public virtual override {
        super.setUp();

        hostileShare = new HostileBufferShareSE(IERC20(address(dai)));
        reentryTarget = new DetfReentryTarget();
        // Seed hostile share inventory for alice/bob (and buffer for 1:1 wrapper).
        _fundBuffer(address(hostileShare), 10_000_000e18);
        hostileShare.mint(alice, 1_000_000e18);
        hostileShare.mint(bob, 1_000_000e18);
        // Fund wrapper with buffer so share→buffer exchange works.
        _fundBuffer(address(hostileShare), 2_000_000e18);

        IMixedBufferMultiVaultStableDetfDFPkg.PkgArgs memory args;
        args.name = "Reentrancy Outer MBMV";
        args.symbol = "rMBMV";
        args.bufferToken = IERC20(address(dai));
        args.standardExchangeVaults = new IStandardExchange[](1);
        args.vaultShareRateProviders = new IRateProvider[](1);
        args.standardExchangeVaults[0] = IStandardExchange(address(hostileShare));
        args.amplificationParameter = MBMVS_AMP;
        // Product Open (mint=1/burn=max illegal under mint>burn validation).
        args.mintThreshold = 0;
        args.burnThreshold = 0;
        args.thresholdMode = ThresholdMode.Open;

        vm.startPrank(owner);
        outerDetf = indexedexManager.deployVault(
            IStandardVaultPkg(address(mixedBufferDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();
        outerInfo = IMixedBufferMultiVaultStableDetfInfo(outerDetf);
        outerEx = IStandardExchangeIn(outerDetf);
        outerBonding = IMixedBufferMultiVaultStableDetfBonding(outerDetf);

        // Bootstrap with hostile shares (permissionless).
        uint256 bufferAmt_ = 1_000e18;
        uint256 shareAmt_ = 1_000e18;
        _fundBuffer(alice, bufferAmt_);
        // alice already has minted hostile shares
        uint256[] memory shares_ = new uint256[](1);
        shares_[0] = shareAmt_;
        vm.startPrank(alice);
        IERC20(address(dai)).approve(outerDetf, bufferAmt_);
        hostileShare.approve(outerDetf, shareAmt_);
        outerBonding.bootstrapFirstBond(
            bufferAmt_, shares_, DEFAULT_MIN_LOCK, alice, block.timestamp + 1 hours
        );
        vm.stopPrank();
        require(outerInfo.isReserveLive(), "outer live");
    }

    function test_control_path_mint_succeeds() public {
        uint256 amountIn_ = 50e18;
        vm.startPrank(bob);
        hostileShare.approve(outerDetf, amountIn_);
        uint256 out_ = outerEx.exchangeIn(
            IERC20(address(hostileShare)), amountIn_, IERC20(outerDetf), 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(out_ > 0, "control mint works");
    }

    function test_reentrancy_mintSharePath_nestedHitsIsLocked() public {
        uint256 amountIn_ = 50e18;

        // Control: unarmed mint succeeds.
        vm.startPrank(bob);
        hostileShare.approve(outerDetf, amountIn_);
        uint256 okOut_ = outerEx.exchangeIn(
            IERC20(address(hostileShare)), amountIn_, IERC20(outerDetf), 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(okOut_ > 0, "control mint works");

        // Arm: re-enter exchangeIn mid-transferFrom.
        bytes memory reentry = abi.encodeCall(
            DetfReentryTarget.reenterExchangeIn,
            (outerDetf, IERC20(address(hostileShare)), uint256(1e18), IERC20(outerDetf), bob)
        );
        hostileShare.arm(address(reentryTarget), reentry);

        uint256 balBefore_ = IERC20(outerDetf).balanceOf(bob);
        vm.startPrank(bob);
        hostileShare.approve(outerDetf, amountIn_);
        outerEx.exchangeIn(
            IERC20(address(hostileShare)), amountIn_, IERC20(outerDetf), 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertEq(hostileShare.reentryAttempts(), 1, "nested reentry attempted exactly once");
        assertFalse(hostileShare.nestedCallSucceeded(), "nested exchangeIn must not succeed");
        assertEq(
            hostileShare.nestedErrorSelector(),
            IReentrancyLock.IsLocked.selector,
            "nested exchangeIn must revert IsLocked (nonReentrant)"
        );
        assertGe(IERC20(outerDetf).balanceOf(bob), balBefore_, "outer path continued after blocked reentry");
    }

    function test_reentrancy_crossFunction_bond_nestedHitsIsLocked() public {
        uint256 amountIn_ = 50e18;
        bytes memory reentry = abi.encodeCall(
            DetfReentryTarget.reenterBond,
            (outerDetf, IERC20(address(hostileShare)), uint256(1e18), DEFAULT_MIN_LOCK, bob)
        );
        hostileShare.arm(address(reentryTarget), reentry);

        vm.startPrank(bob);
        hostileShare.approve(outerDetf, amountIn_);
        outerEx.exchangeIn(
            IERC20(address(hostileShare)), amountIn_, IERC20(outerDetf), 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertEq(hostileShare.reentryAttempts(), 1, "nested reentry attempted exactly once");
        assertFalse(hostileShare.nestedCallSucceeded(), "nested bond must not succeed");
        assertEq(
            hostileShare.nestedErrorSelector(),
            IReentrancyLock.IsLocked.selector,
            "nested bond must revert IsLocked (nonReentrant)"
        );
    }
}
