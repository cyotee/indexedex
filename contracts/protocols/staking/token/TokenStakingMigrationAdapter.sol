// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {ERC20} from "@crane/contracts/external/openzeppelin-contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {IDetfClaimPurchase} from "contracts/interfaces/IDetfClaimPurchase.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IDETFStandardizedYield} from "contracts/interfaces/IDETFStandardizedYield.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {ITokenStaking} from "contracts/interfaces/ITokenStaking.sol";

/// @title TokenStakingMigrationAdapter
/// @notice Bridges historical TokenStaking mint/approve/exchangeIn calls to canonical DETF and static staking SY routes.
/// @dev Owner-approved exception: standalone constructor deployment with `new`, no diamond/package/CREATE3.
///      Only the pinned staking contract can mint or consume nontransferable DETF-backed receipts.
///      A native migrateToClaimVault call creates and consumes the entire receipt supply atomically,
///      then wraps static staking SY. Users withdraw SY and redeem it for real sDETF. No fee, owner, rescue or arbitrary call path.
///      Donations are never credited as migration input and cannot be recovered through this adapter.
contract TokenStakingMigrationAdapter is ERC20, ReentrancyLockModifiers {
    using BetterSafeERC20 for IERC20;

    address public immutable staking;
    IERC20 public immutable stakingToken;
    IERC20 public immutable detfToken;
    /// @notice Historical discovery getter; intentionally returns STATIC staking SY, the claim-vault asset.
    address public immutable rebasingClaimToken;
    /// @notice Actual funded, rebasing sDETF backing the canonical staking SY.
    address public immutable fundedStakingToken;

    error InvalidConfiguration();
    error Unauthorized(address caller);
    error InvalidRoute();
    error InvalidRecipient();
    error PretransferUnsupported();
    error ZeroAmount();
    error DeadlineExpired(uint256 deadline);
    error PendingReceipts();
    error InvalidReceiptAmount();
    error NontransferableReceipt();
    error InvalidApproval();
    error UnexpectedBalanceDelta(address token, uint256 expected, uint256 actual);
    error MinimumOutputNotMet(uint256 minimum, uint256 actual);

    event MigrationReceiptsMinted(uint256 tokenIn, uint256 detfOut);
    event MigrationReceiptsConsumed(uint256 detfIn, uint256 claimOut);

    constructor(address staking_, IERC20 stakingToken_, IERC20 detfToken_, address rebasingClaimToken_)
        ERC20("Token Staking Migration Receipt", "TSMR")
    {
        if (
            staking_.code.length == 0 || address(stakingToken_).code.length == 0 || address(detfToken_).code.length == 0
                || rebasingClaimToken_.code.length == 0 || address(stakingToken_) == address(detfToken_)
                || staking_ == address(detfToken_) || address(stakingToken_) == rebasingClaimToken_
                || address(stakingToken_) == staking_ || staking_ == rebasingClaimToken_
                || address(detfToken_) == rebasingClaimToken_
                || address(ITokenStaking(staking_).stakingToken()) != address(stakingToken_)
                || IDetfClaimPurchase(address(detfToken_)).rebasingClaimToken() != rebasingClaimToken_
                || IStakedDETF(rebasingClaimToken_).detf() != address(detfToken_)
                || IERC20Metadata(address(detfToken_)).decimals() != 9
                || IERC20Metadata(rebasingClaimToken_).decimals() != 9
        ) revert InvalidConfiguration();
        staking = staking_;
        stakingToken = stakingToken_;
        detfToken = detfToken_;
        address stakingSY_ = IDETFStandardizedYield(address(detfToken_)).stakingSY();
        if (
            stakingSY_.code.length == 0 || stakingSY_ == staking_ || stakingSY_ == address(stakingToken_)
                || stakingSY_ == address(detfToken_) || stakingSY_ == rebasingClaimToken_
                || IERC20Metadata(stakingSY_).decimals() != 9
                || IStandardizedYield(stakingSY_).yieldToken() != rebasingClaimToken_
        ) revert InvalidConfiguration();
        (IStandardizedYield.AssetType type_, address asset_, uint8 decimals_) =
            IStandardizedYield(stakingSY_).assetInfo();
        if (type_ != IStandardizedYield.AssetType.TOKEN || asset_ != address(detfToken_) || decimals_ != 9) {
            revert InvalidConfiguration();
        }
        fundedStakingToken = rebasingClaimToken_;
        rebasingClaimToken = stakingSY_;
    }

    /// @notice Historical six-argument mint ABI; returns one uint256 as expected by deployed staking.
    function mint(
        IERC20 tokenIn_,
        uint256 amountIn_,
        uint256 minAmountOut_,
        address recipient_,
        bool pretransfer_,
        uint256 deadline_
    ) external nonReentrant returns (uint256 amountOut_) {
        _validateCall(amountIn_, recipient_, pretransfer_, deadline_);
        if (address(tokenIn_) != address(stakingToken)) revert InvalidRoute();
        if (totalSupply() != 0) revert PendingReceipts();
        uint256 tokenBefore_ = stakingToken.balanceOf(address(this));
        stakingToken.safeTransferFrom(staking, address(this), amountIn_);
        _requireDelta(stakingToken, tokenBefore_, amountIn_);
        uint256 detfBefore_ = detfToken.balanceOf(address(this));
        stakingToken.forceApprove(address(detfToken), amountIn_);
        amountOut_ = IStandardExchangeIn(address(detfToken))
            .exchangeIn(stakingToken, amountIn_, detfToken, minAmountOut_, address(this), false, deadline_);
        stakingToken.forceApprove(address(detfToken), 0);
        _requireDelta(stakingToken, tokenBefore_, 0);
        _requireDelta(detfToken, detfBefore_, amountOut_);
        _requireOutput(amountOut_, minAmountOut_);
        _mint(staking, amountOut_);
        emit MigrationReceiptsMinted(amountIn_, amountOut_);
    }

    /// @notice Consume the entire approved receipt batch and deliver static staking SY directly to staking.
    /// @dev Minimum and returned output are SY units; receipt/input units are DETF.
    function exchangeIn(
        IERC20 tokenIn_,
        uint256 amountIn_,
        IERC20 tokenOut_,
        uint256 minAmountOut_,
        address recipient_,
        bool pretransfer_,
        uint256 deadline_
    ) external nonReentrant returns (uint256 amountOut_) {
        _validateCall(amountIn_, recipient_, pretransfer_, deadline_);
        if (address(tokenIn_) != address(this) || address(tokenOut_) != rebasingClaimToken) revert InvalidRoute();
        if (amountIn_ != totalSupply() || amountIn_ != balanceOf(staking)) revert InvalidReceiptAmount();
        _spendAllowance(staking, address(this), amountIn_);
        _burn(staking, amountIn_);
        uint256 detfBefore_ = detfToken.balanceOf(address(this));
        uint256 claimBefore_ = tokenOut_.balanceOf(staking);
        detfToken.forceApprove(rebasingClaimToken, amountIn_);
        amountOut_ =
            IStandardizedYield(rebasingClaimToken).deposit(staking, address(detfToken), amountIn_, minAmountOut_);
        detfToken.forceApprove(rebasingClaimToken, 0);
        _requireDelta(detfToken, detfBefore_ - amountIn_, 0);
        uint256 claimAfter_ = tokenOut_.balanceOf(staking);
        uint256 received_ = claimAfter_ >= claimBefore_ ? claimAfter_ - claimBefore_ : 0;
        if (received_ != amountOut_) revert UnexpectedBalanceDelta(rebasingClaimToken, amountOut_, received_);
        _requireOutput(amountOut_, minAmountOut_);
        emit MigrationReceiptsConsumed(amountIn_, amountOut_);
    }

    /// @notice Receipt units match native DETF units.
    function decimals() public pure override returns (uint8) {
        return 9;
    }

    /// @notice Only the legacy self-approval, bounded by the outstanding receipt balance, is supported.
    function approve(address spender_, uint256 amount_) public override returns (bool) {
        if (msg.sender != staking) revert Unauthorized(msg.sender);
        if (spender_ != address(this) || amount_ > balanceOf(staking)) revert InvalidApproval();
        return super.approve(spender_, amount_);
    }

    function _validateCall(uint256 amount_, address recipient_, bool pretransfer_, uint256 deadline_) internal view {
        if (msg.sender != staking) revert Unauthorized(msg.sender);
        if (recipient_ != staking) revert InvalidRecipient();
        if (pretransfer_) revert PretransferUnsupported();
        if (amount_ == 0) revert ZeroAmount();
        if (block.timestamp > deadline_) revert DeadlineExpired(deadline_);
    }

    function _requireDelta(IERC20 token_, uint256 before_, uint256 expected_) internal view {
        uint256 after_ = token_.balanceOf(address(this));
        if (after_ < before_ || after_ - before_ != expected_) {
            revert UnexpectedBalanceDelta(address(token_), expected_, after_ >= before_ ? after_ - before_ : 0);
        }
    }

    function _requireOutput(uint256 amount_, uint256 minimum_) internal pure {
        if (amount_ == 0) revert ZeroAmount();
        if (amount_ < minimum_) revert MinimumOutputNotMet(minimum_, amount_);
    }

    /// @dev Receipts cannot leave staking or be transferred into an internal balance.
    function _update(address from_, address to_, uint256 amount_) internal override {
        if (!((from_ == address(0) && to_ == staking) || (from_ == staking && to_ == address(0)))) {
            revert NontransferableReceipt();
        }
        super._update(from_, to_, amount_);
    }
}
