// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721Errors} from "@crane/contracts/interfaces/IERC721Errors.sol";
import {ERC721Repo} from "@crane/contracts/tokens/ERC721/ERC721Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {IAllowanceTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {ISignatureTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDetfBondNFT, IDetfStakingToken} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF, IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {DETFBondNFTMathLib} from "contracts/vaults/detf/common/core/DETFBondNFTMathLib.sol";
import {DETFFundedStakingMath as StakingMath} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {DETFFundedBondRepo as Repo} from "contracts/vaults/detf/common/bondNft/DETFFundedBondRepo.sol";
import {IDetfReserveDonation, IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";

/// @title DETFFundedBondTarget
/// @notice One funded vesting ledger for every DETF reserve family.
contract DETFFundedBondTarget is ReentrancyLockModifiers, IDetfNftReserveDonation {
    using BetterSafeERC20 for IERC20;

    error NotAuthorized(address caller);
    error ReservedBond(uint256 tokenId);
    error AlreadyInitialized();
    error RolesNotInitialized();
    error ZeroAmount();
    error InvalidDuration();
    error ProtectedStakingAsset();
    error DeadlineExceeded(uint256 deadline, uint256 nowTimestamp);
    error ReserveNotLive();
    error InvalidPermit2Data();

    modifier onlyDetf() {
        if (msg.sender != Repo._layoutStruct().detf) revert NotAuthorized(msg.sender);
        _;
    }

    modifier synchronized() {
        IDETFFundedRewards(Repo._layoutStruct().detf).synchronizeRewards();
        _;
    }

    /// @notice Owning DETF.
    function detf() external view returns (address) { return Repo._layoutStruct().detf; }

    /// @notice Custodied reserve LP, entirely owned by the DETF.
    function lpToken() external view returns (IERC20) { return Repo._layoutStruct().lpToken; }

    /// @notice Reserved roles are wired independently of the valid protocol ID zero.
    function reservedBondNftsWired() external view returns (bool) { return Repo._layoutStruct().reservedIdsWired; }

    /// @notice Registered fee classification.
    function vaultFeeTypeIds() external view returns (bytes32) { return StandardVaultRepo._vaultFeeTypeIds(); }

    /// @notice Stable identity of the custodied reserve asset.
    function contentsId() external view returns (bytes32) { return StandardVaultRepo._contentsId(); }

    /// @notice Actual registered interfaces, without an ERC-4626 bond ledger.
    function vaultTypes() external view returns (bytes4[] memory) { return StandardVaultRepo._vaultTypes(); }

    /// @notice Registry metadata uses the actual LP custody token.
    function vaultConfig() external view returns (IStandardVault.VaultConfig memory config_) {
        address[] memory tokens_ = new address[](1);
        tokens_[0] = address(Repo._layoutStruct().lpToken);
        config_ = IStandardVault.VaultConfig({
            vaultFeeTypeIds: StandardVaultRepo._vaultFeeTypeIds(),
            contentsId: StandardVaultRepo._contentsId(),
            vaultTypes: StandardVaultRepo._vaultTypes(),
            tokens: tokens_
        });
    }

    /// @notice Create protocol, fee and creator roles before any purchased position.
    function initializeReservedBondNfts(address feeTo_, address creator_) external onlyDetf returns (uint256) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (s_.reservedIdsWired || ERC721Repo._layoutStruct().nextTokenId != 0) revert AlreadyInitialized();
        if (feeTo_ == address(0)) revert NotAuthorized(feeTo_);
        s_.reservedIdsWired = true;
        ERC721Repo._mint(address(this));
        ERC721Repo._mint(feeTo_);
        ERC721Repo._mint(creator_ == address(0) ? feeTo_ : creator_);
        return 0;
    }

    /// @notice Pull and stake only this purchase's DETF; no existing escrow surplus can fund it.
    function createFundedPosition(uint256 principal_, uint256 duration_, address recipient_)
        external onlyDetf synchronized nonReentrant returns (uint256 tokenId_)
    {
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (!s_.reservedIdsWired) revert RolesNotInitialized();
        if (principal_ == 0) revert ZeroAmount();
        if (duration_ == 0) revert InvalidDuration();
        _checkRecipient(recipient_);
        (uint256 creditedGons_, uint256 heldGons_) = _fundPrincipal(principal_);
        tokenId_ = ERC721Repo._mint(recipient_);
        Repo._open(s_, tokenId_, principal_, creditedGons_, duration_, heldGons_);
        emit IDetfBondNFT.BondPurchased(tokenId_, recipient_, principal_, block.timestamp, duration_);
    }

    function _fundPrincipal(uint256 principal_) internal returns (uint256 creditedGons_, uint256 heldGons_) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        IERC20 backing_ = IERC20(s_.detf);
        uint256 before_ = backing_.balanceOf(address(this));
        backing_.safeTransferFrom(msg.sender, address(this), principal_);
        uint256 received_ = backing_.balanceOf(address(this)) - before_;
        if (received_ != principal_) revert ISecurePullErrors.TransferDeltaInsufficient(principal_, received_);
        IStakedDETF staking_ = _staking();
        uint256 beforeGons_ = staking_.gonsOf(address(this));
        backing_.forceApprove(address(staking_), principal_);
        staking_.exchangeIn(backing_, principal_, IERC20(address(staking_)), principal_, address(this), false, block.timestamp);
        backing_.forceApprove(address(staking_), 0);
        heldGons_ = staking_.gonsOf(address(this));
        creditedGons_ = heldGons_ - beforeGons_;
        uint256 requiredGons_ = StakingMath._toGons(principal_, staking_.stakingState().gonsPerUnit);
        if (creditedGons_ != requiredGons_) {
            revert Repo.UnfundedEscrow(heldGons_, beforeGons_ + requiredGons_);
        }
    }

    /// @notice Fixed purchase terms and remaining attributed gons.
    function positionOf(uint256 tokenId_) external view returns (StakingMath.BondPosition memory) {
        _requireExists(tokenId_);
        return Repo._layoutStruct().positions[tokenId_];
    }

    /// @notice Funded claims at the stored staking index; unminted expansion is excluded.
    function previewClaim(uint256 tokenId_) public view returns (StakingMath.BondClaim memory claim_) {
        _requireExists(tokenId_);
        if (tokenId_ < 3) return claim_;
        return StakingMath._claim(
            Repo._layoutStruct().positions[tokenId_], block.timestamp, _staking().stakingState().gonsPerUnit
        );
    }

    /// @notice Claim vested principal as sDETF without claiming its separate staking rewards.
    function claimPrincipal(uint256 tokenId_, address recipient_)
        external synchronized nonReentrant returns (uint256 principal_)
    {
        (principal_,) = _claim(tokenId_, recipient_, true, false);
    }

    /// @notice Claim funded sDETF growth while keeping all remaining principal staked.
    function claimRewards(uint256 tokenId_, address recipient_)
        external synchronized nonReentrant returns (uint256 rewards_)
    {
        (, rewards_) = _claim(tokenId_, recipient_, false, true);
    }

    /// @notice Claim both available components; retire a fully paid purchased position.
    function claimBond(uint256 tokenId_, address recipient_)
        external synchronized nonReentrant returns (uint256 principal_, uint256 rewards_)
    {
        return _claim(tokenId_, recipient_, true, true);
    }

    function _claim(uint256 tokenId_, address recipient_, bool principalClaim_, bool rewardClaim_)
        internal returns (uint256 principal_, uint256 rewards_)
    {
        if (tokenId_ < 3) revert ReservedBond(tokenId_);
        address owner_ = _requireExists(tokenId_);
        if (msg.sender != owner_ && ERC721Repo._getApproved(tokenId_) != msg.sender
            && !ERC721Repo._isApprovedForAll(owner_, msg.sender)) revert NotAuthorized(msg.sender);
        if (recipient_ == address(0)) recipient_ = owner_;
        _checkRecipient(recipient_);
        Repo.Storage storage s_ = Repo._layoutStruct();
        StakingMath.BondPosition storage position_ = s_.positions[tokenId_];
        IStakedDETF staking_ = _staking();
        uint256 k_ = staking_.stakingState().gonsPerUnit;
        StakingMath.BondClaim memory claim_ = StakingMath._claim(position_, block.timestamp, k_);
        principal_ = principalClaim_ ? claim_.principalDue : 0;
        rewards_ = rewardClaim_ ? claim_.rewardsDue : 0;
        uint256 amount_ = principal_ + rewards_;
        uint256 debit_ = StakingMath._toGons(amount_, k_);
        position_.claimedPrincipal += principal_;
        position_.stakingGons -= debit_;
        s_.attributedGons -= debit_;
        if (amount_ != 0) IERC20(address(staking_)).safeTransfer(recipient_, amount_);
        _retireIfPaid(tokenId_, staking_, k_);
        Repo._requireFunded(s_, staking_.gonsOf(address(this)));
        emit IDetfBondNFT.BondClaimed(tokenId_, recipient_, principal_, rewards_);
    }

    function _retireIfPaid(uint256 tokenId_, IStakedDETF staking_, uint256 k_) internal {
        Repo.Storage storage s_ = Repo._layoutStruct();
        StakingMath.BondPosition storage position_ = s_.positions[tokenId_];
        if (position_.claimedPrincipal == position_.principal && position_.stakingGons < k_) {
            uint256 fraction_ = position_.stakingGons;
            s_.attributedGons -= fraction_;
            delete s_.positions[tokenId_];
            if (fraction_ != 0) staking_.retireEscrowDust(fraction_);
            ERC721Repo._burn(tokenId_);
        }
    }

    /// @notice Reserve custody cannot spend funded bond principal or its staking receipts.
    function transferHeldToken(IERC20 token_, address to_, uint256 amount_) external onlyDetf nonReentrant {
        if (address(token_) == Repo._layoutStruct().detf || address(token_) == address(_staking())) {
            revert ProtectedStakingAsset();
        }
        token_.safeTransfer(to_, amount_);
    }

    /// @notice Settle the old owner's due rewards before conveying the entire remaining bond.
    function transferFrom(address from_, address to_, uint256 tokenId_) external synchronized nonReentrant {
        _checkRecipient(to_);
        ERC721Repo._transferFrom(from_, to_, tokenId_);
    }

    /// @notice Guarded safe transfer, including receiver acceptance.
    function safeTransferFrom(address from_, address to_, uint256 tokenId_) external synchronized nonReentrant {
        _checkRecipient(to_);
        ERC721Repo._safeTransferFrom(from_, to_, tokenId_);
    }

    /// @notice Guarded safe transfer with receiver data.
    function safeTransferFrom(address from_, address to_, uint256 tokenId_, bytes calldata data_)
        external synchronized nonReentrant
    {
        _checkRecipient(to_);
        ERC721Repo._safeTransferFrom(from_, to_, tokenId_, data_);
    }

    function _staking() internal view returns (IStakedDETF) {
        return IStakedDETF(address(IDetfStakingToken(Repo._layoutStruct().detf).rebasingClaimToken()));
    }

    function _requireExists(uint256 tokenId_) internal view returns (address owner_) {
        owner_ = ERC721Repo._ownerOf(tokenId_);
        if (owner_ == address(0)) revert IERC721Errors.ERC721NonexistentToken(tokenId_);
    }

    function _checkRecipient(address recipient_) internal view {
        if (recipient_ == address(0) || recipient_ == Repo._layoutStruct().detf || recipient_ == address(this)) {
            revert IERC721Errors.ERC721InvalidReceiver(recipient_);
        }
    }

    address private constant _PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    uint8 private constant _PULL_TRANSFER = 0;
    uint8 private constant _PULL_PERMIT2_ALLOWANCE = 1;
    uint8 private constant _PULL_PERMIT2_SIGNATURE = 2;

    /// @inheritdoc IDetfNftReserveDonation
    function donate(IERC20 token, uint256 amount, uint256 minLpOut, bool pretransferred, uint256 deadline)
        external
        nonReentrant
        returns (uint256 lpOut)
    {
        lpOut = _donate(
            msg.sender, token, amount, minLpOut, pretransferred, deadline, _PULL_TRANSFER, bytes("")
        );
    }

    /// @inheritdoc IDetfNftReserveDonation
    function donate(
        address donor,
        IERC20 token,
        uint256 amount,
        uint256 minLpOut,
        bool pretransferred,
        uint256 deadline
    ) external nonReentrant returns (uint256 lpOut) {
        if (msg.sender != Repo._layoutStruct().detf) {
            revert NotAuthorized(msg.sender);
        }
        if (donor == address(0)) revert NotAuthorized(address(0));
        lpOut = _donate(
            donor, token, amount, minLpOut, pretransferred, deadline, _PULL_TRANSFER, bytes("")
        );
    }

    /// @inheritdoc IDetfNftReserveDonation
    function donateWithPermit2Allowance(IERC20 token, uint256 amount, uint256 minLpOut, uint256 deadline)
        external
        nonReentrant
        returns (uint256 lpOut)
    {
        lpOut = _donate(
            msg.sender, token, amount, minLpOut, false, deadline, _PULL_PERMIT2_ALLOWANCE, bytes("")
        );
    }

    /// @inheritdoc IDetfNftReserveDonation
    function donateWithPermit2Signature(
        IERC20 token,
        uint256 amount,
        uint256 minLpOut,
        uint256 deadline,
        bytes calldata permit2Data
    ) external nonReentrant returns (uint256 lpOut) {
        lpOut = _donate(
            msg.sender, token, amount, minLpOut, false, deadline, _PULL_PERMIT2_SIGNATURE, permit2Data
        );
    }

    /// @inheritdoc IDetfNftReserveDonation
    function previewDonate(IERC20 token, uint256 amount) external view returns (uint256 lpOut) {
        if (amount == 0) return 0;
        address detf_ = Repo._layoutStruct().detf;
        if (!_staticIsReserveLive(detf_)) return 0;
        if (address(token) == address(Repo._layoutStruct().lpToken)) {
            return amount;
        }
        (bool ok_, bytes memory ret_) =
            detf_.staticcall(abi.encodeCall(IDetfReserveDonation.previewJoinDonatedCapital, (token, amount)));
        if (!ok_ || ret_.length < 32) return 0;
        return abi.decode(ret_, (uint256));
    }

    function _donate(
        address donor_,
        IERC20 token_,
        uint256 amount_,
        uint256 minLpOut_,
        bool pretransferred_,
        uint256 deadline_,
        uint8 pullMode_,
        bytes memory permit2Data_
    ) private returns (uint256 lpOut_) {
        if (amount_ == 0) revert ZeroAmount();
        if (address(token_) == address(_staking())) revert ProtectedStakingAsset();
        if (DETFBondNFTMathLib._isDeadlineExceeded(deadline_, block.timestamp)) {
            revert DeadlineExceeded(deadline_, block.timestamp);
        }
        IDetf detf_ = IDetf(Repo._layoutStruct().detf);
        _requireDetfLiveAndEnabled(detf_);

        IERC20 lp_ = Repo._layoutStruct().lpToken;
        uint256 lpBefore_ = lp_.balanceOf(address(this));
        uint256 amountIn_;

        if (address(token_) == address(lp_)) {
            if (pretransferred_) {
                revert ISecurePullErrors.TransferDeltaInsufficient(amount_, 0);
            }
            amountIn_ = _pullDonate(token_, amount_, donor_, false, pullMode_, permit2Data_);
            lpOut_ = lp_.balanceOf(address(this)) - lpBefore_;
            if (lpOut_ == 0) revert ZeroAmount();
            if (lpOut_ < minLpOut_) {
                revert IStandardExchangeErrors.MinAmountNotMet(minLpOut_, lpOut_);
            }
            IDetfReserveDonation(address(detf_)).notifyReserveDonated();
            emit IDetfNftReserveDonation.ReserveDonated(donor_, address(token_), amountIn_, lpOut_);
            return lpOut_;
        }

        amountIn_ = _pullDonate(token_, amount_, donor_, pretransferred_, pullMode_, permit2Data_);
        token_.forceApprove(address(detf_), amountIn_);
        lpOut_ = IDetfReserveDonation(address(detf_)).joinDonatedCapital(token_, amountIn_, deadline_);
        token_.forceApprove(address(detf_), 0);
        if (lpOut_ == 0) revert ZeroAmount();
        uint256 inboundLp_ = lp_.balanceOf(address(this)) - lpBefore_;
        if (inboundLp_ < lpOut_) {
            lpOut_ = inboundLp_;
        }
        if (lpOut_ == 0) revert ZeroAmount();
        if (lpOut_ < minLpOut_) {
            revert IStandardExchangeErrors.MinAmountNotMet(minLpOut_, lpOut_);
        }
        IDetfReserveDonation(address(detf_)).notifyReserveDonated();
        emit IDetfNftReserveDonation.ReserveDonated(donor_, address(token_), amountIn_, lpOut_);
    }

    function _requireDetfLiveAndEnabled(IDetf detf_) private view {
        address detfAddr_ = address(detf_);
        address oracle_ = address(StandardVaultRepo._feeOracle());
        if (oracle_ != address(0)) {
            try IVaultRegistryDisableQuery(oracle_).isDisabled(detfAddr_) returns (bool disabled_) {
                if (disabled_) revert IVaultRegistryDisableQuery.VaultDisabled(detfAddr_);
            } catch {}
        }
        if (!_staticIsReserveLive(detfAddr_)) revert ReserveNotLive();
    }

    function _staticIsReserveLive(address detfAddr_) private view returns (bool) {
        if (detfAddr_ == address(0) || detfAddr_.code.length == 0) return false;
        (bool ok_, bytes memory ret_) =
            detfAddr_.staticcall(abi.encodeWithSelector(IDetfReserveDonation.isReserveLive.selector));
        if (!ok_ || ret_.length < 32) return false;
        return abi.decode(ret_, (bool));
    }

    function _pullDonate(
        IERC20 token_,
        uint256 amount_,
        address from_,
        bool pretransferred_,
        uint8 pullMode_,
        bytes memory permit2Data_
    ) private returns (uint256 actual_) {
        if (pretransferred_) {
            uint256 bal_ = token_.balanceOf(address(this));
            uint256 surplus_ = bal_;
            if (surplus_ == 0) revert ZeroAmount();
            if (amount_ > surplus_) {
                revert ISecurePullErrors.TransferDeltaInsufficient(amount_, surplus_);
            }
            return amount_;
        }
        uint256 before_ = token_.balanceOf(address(this));
        if (pullMode_ == _PULL_PERMIT2_ALLOWANCE) {
            if (amount_ > type(uint160).max) revert InvalidPermit2Data();
            IAllowanceTransfer(_PERMIT2).transferFrom(from_, address(this), uint160(amount_), address(token_));
        } else if (pullMode_ == _PULL_PERMIT2_SIGNATURE) {
            _pullPermit2Signature(token_, amount_, from_, permit2Data_);
        } else {
            token_.safeTransferFrom(from_, address(this), amount_);
        }
        actual_ = token_.balanceOf(address(this)) - before_;
        if (actual_ == 0) revert ZeroAmount();
    }

    function _pullPermit2Signature(
        IERC20 token_,
        uint256 amount_,
        address from_,
        bytes memory permit2Data_
    ) private {
        (ISignatureTransfer.PermitTransferFrom memory permit_, bytes memory signature_) =
            abi.decode(permit2Data_, (ISignatureTransfer.PermitTransferFrom, bytes));
        if (permit_.permitted.token != address(token_)) revert InvalidPermit2Data();
        ISignatureTransfer.SignatureTransferDetails memory details_ = ISignatureTransfer
            .SignatureTransferDetails({to: address(this), requestedAmount: amount_});
        ISignatureTransfer(_PERMIT2).permitTransferFrom(permit_, details_, from_, signature_);
    }


}
