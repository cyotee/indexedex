// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {MockERC20} from "@crane/contracts/test/mocks/MockERC20.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {DetfReentryTarget} from "contracts/test/adversarial/DetfReentryTarget.sol";
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

/// @dev Hostile vault share that is a 1:1 buffer wrapper SE (accept+produce buffer for MixedBuffer).
///      transferFrom re-enters DETF then ALWAYS completes transfer so probe state persists.
contract AdvHostileBufferShareSE is MockERC20, IStandardExchange {
    IERC20 public immutable bufferToken;
    address public target;
    bytes public reentryCall;
    bool public armed;
    uint256 private _depth;

    uint256 public reentryAttempts;
    bool public nestedCallSucceeded;
    bytes4 public nestedErrorSelector;

    constructor(IERC20 buffer_) MockERC20("AdvHostileShareSE", "AHSE", 18) {
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
            revert("AdvHostileSE: route");
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
        revert("AdvHostileSE: exactOut");
    }
}

/// @title TestBase_MixedBufferMultiVaultStableDetf_Adversarial
/// @notice Production MixedBuffer DETF + hostile share harness (WP-ADV-DETF-MB-001 A–H residual).
/// @dev I CODE (I1–I3 trust-flag / secure pull) lives in Adversarial_MixedBuffer_TrustFlag.t.sol.
abstract contract TestBase_MixedBufferMultiVaultStableDetf_Adversarial is TestBase_MixedBufferMultiVaultStableDetf {
    address internal attacker;
    address internal victim;

    AdvHostileBufferShareSE internal hostileShare;
    DetfReentryTarget internal reentryTarget;

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("attacker");
        victim = makeAddr("victim");
        hostileShare = new AdvHostileBufferShareSE(IERC20(address(dai)));
        reentryTarget = new DetfReentryTarget();
        // Seed hostile share inventory + buffer inventory for 1:1 wrapper SE.
        _fundBuffer(address(hostileShare), 12_000_000e18);
        hostileShare.mint(attacker, 2_000_000e18);
        hostileShare.mint(victim, 2_000_000e18);
        hostileShare.mint(alice, 2_000_000e18);
        hostileShare.mint(bob, 2_000_000e18);
    }

    function _bufferOf(address instance_) internal view returns (IERC20) {
        return IERC20(IMixedBufferMultiVaultStableDetfInfo(instance_).bufferToken());
    }

    function _openLiveOpenThreshold() internal returns (address instance_) {
        instance_ = _deployOpenThresholdDetfN(1);
        _bootstrapDefault(instance_, alice);
        _assertLive(instance_);
    }

    function _openLiveOpenThresholdN(uint8 n) internal returns (address instance_) {
        instance_ = _deployOpenThresholdDetfN(n);
        _bootstrapDefault(instance_, alice);
        _assertLive(instance_);
    }

    /// @dev Deploy MixedBuffer DETF with hostile share as sole SE leg (Open thresholds).
    function _deployHostileShareDetf() internal returns (address instance_) {
        IMixedBufferMultiVaultStableDetfDFPkg.PkgArgs memory args;
        args.name = "Adv Hostile MBMV";
        args.symbol = "advHMB";
        args.bufferToken = IERC20(address(dai));
        args.standardExchangeVaults = new IStandardExchange[](1);
        args.vaultShareRateProviders = new IRateProvider[](1);
        args.standardExchangeVaults[0] = IStandardExchange(address(hostileShare));
        args.amplificationParameter = MBMVS_AMP;
        args.mintThreshold = 0;
        args.burnThreshold = 0;
        args.thresholdMode = ThresholdMode.Open;

        vm.startPrank(owner);
        instance_ = indexedexManager.deployVault(
            IStandardVaultPkg(address(mixedBufferDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();
    }

    function _bootstrapHostile(address instance_, address user, uint256 bufferAmt_, uint256 shareAmt_)
        internal
        returns (uint256 tokenId_)
    {
        uint256[] memory shares_ = new uint256[](1);
        shares_[0] = shareAmt_;
        _fundBuffer(user, bufferAmt_);
        // user already has hostile shares from setUp mint
        vm.startPrank(user);
        IERC20(address(dai)).approve(instance_, bufferAmt_);
        hostileShare.approve(instance_, shareAmt_);
        (tokenId_,,) = IMixedBufferMultiVaultStableDetfBonding(instance_).bootstrapFirstBond(
            bufferAmt_, shares_, DEFAULT_MIN_LOCK, user, block.timestamp + 1 hours
        );
        vm.stopPrank();
        require(IMixedBufferMultiVaultStableDetfInfo(instance_).isReserveLive(), "hostile live");
    }

    function _claimOf(address instance_) internal view returns (address) {
        return IMixedBufferMultiVaultStableDetfInfo(instance_).rebasingClaimToken();
    }

    /// @dev Outer MixedBuffer over nested live MixedBuffer (leg0) + production SE (leg1).
    function _deployOuterOverNested(address nested_) internal returns (address outer_) {
        _ensureSeVaults(2);
        IMixedBufferMultiVaultStableDetfDFPkg.PkgArgs memory outerArgs;
        outerArgs.name = "Adv Outer MBMV Nested";
        outerArgs.symbol = "advOMV";
        outerArgs.bufferToken = IERC20(address(dai));
        outerArgs.standardExchangeVaults = new IStandardExchange[](2);
        outerArgs.vaultShareRateProviders = new IRateProvider[](2);
        outerArgs.standardExchangeVaults[0] = IStandardExchange(nested_);
        outerArgs.standardExchangeVaults[1] = IStandardExchange(address(seVaults[1]));
        outerArgs.amplificationParameter = MBMVS_AMP;
        outerArgs.mintThreshold = 0;
        outerArgs.burnThreshold = 0;
        outerArgs.thresholdMode = ThresholdMode.Open;

        vm.startPrank(owner);
        outer_ = indexedexManager.deployVault(
            IStandardVaultPkg(address(mixedBufferDetfPkg)), abi.encode(outerArgs)
        );
        vm.stopPrank();
    }

    function _bootstrapOuterWithNested(address outer_, address nested_, address user) internal {
        uint256 nestedShares_ = _mintDetfFromBuffer(nested_, user, 400e18);
        nestedShares_ += _mintDetfFromVaultShare(nested_, 0, user, 200e18);
        require(nestedShares_ > 50e18, "nested shares for bootstrap");

        uint256 se1Shares_ = _fundVaultShares(1, user, 500e18);
        _fundBuffer(user, BOOTSTRAP_BUFFER);

        uint256[] memory amts_ = new uint256[](2);
        amts_[0] = nestedShares_;
        amts_[1] = se1Shares_;

        vm.startPrank(user);
        IERC20(nested_).approve(outer_, nestedShares_);
        seShares[1].approve(outer_, se1Shares_);
        IERC20(address(dai)).approve(outer_, BOOTSTRAP_BUFFER);
        IMixedBufferMultiVaultStableDetfBonding(outer_).bootstrapFirstBond(
            BOOTSTRAP_BUFFER, amts_, DEFAULT_MIN_LOCK, user, block.timestamp + 1 hours
        );
        vm.stopPrank();
        _assertLive(outer_);
    }
}
