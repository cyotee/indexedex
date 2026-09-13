// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IDetfReserveDonation, IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IComposedStableCommonDetfBonding} from "contracts/interfaces/IComposedStableCommonDetfBonding.sol";
import {ComposedStableCommonDetfCommon} from "./ComposedStableCommonDetfCommon.sol";
import {ComposedStableCommonDetfRepo as Repo} from "./ComposedStableCommonDetfRepo.sol";
contract ComposedStableCommonDetfBondingFacet is ComposedStableCommonDetfCommon, ReentrancyLockModifiers, IFacet {
    using BetterSafeERC20 for IERC20;
    using Repo for Repo.Storage;
    function bond(IERC20 in_, uint256 amount_, uint256 duration_, address to_, uint256 deadline_)
        external nonReentrant returns (uint256 id_, uint256 principal_)
    {
        _requireActive(deadline_, amount_); _requireReservePoolInitialized();
        _updateExpansionMintOnRewards();
        uint256 lock_ = _effectiveLockDuration(duration_);
        (RoutedPoolSelection memory path_, uint256 bpt_) = _collectRoutedBpt(in_, amount_, false, deadline_);
        uint256 g_ = _quoteBondJoinDetf(bpt_, path_.depositToStablePool);
        MintSplit memory split_ = _splitBondAmount(_quoteBondPurchase(bpt_, path_.depositToStablePool, lock_), g_);
        _mintDetf(address(this), g_);
        uint256 lp_ = _joinReserve(g_, path_.depositToStablePool ? bpt_ : 0, path_.depositToStablePool ? 0 : bpt_, false);
        id_ = _completeBond(split_, lock_, to_, lp_);
        principal_ = split_.userDetfOut;
        _syncAllExpectedHoldReserves();
    }
    /// @notice First bond supplies both existing inner-pool capital legs and creates the reserve's DETF leg.
    function initializeReserve(uint256 stable_, uint256 common_, uint256 duration_, address to_, uint256 deadline_)
        external nonReentrant returns (uint256 id_, uint256 principal_)
    {
        _requireActive(deadline_, stable_); if (common_ == 0) revert ZeroAmount();
        if (_isReserveLive()) revert Repo.ReserveAlreadyInitialized();
        Repo.Storage storage s_ = Repo._layoutStruct();
        uint256 lock_ = _effectiveLockDuration(duration_);
        _secureTokenTransfer(s_._stablePoolBpt(), stable_, false);
        _secureTokenTransfer(s_._commonPoolBpt(), common_, false);
        (MintSplit memory split_, uint256 g_) = _firstBondSplit(stable_, common_, lock_);
        _mintDetf(address(this), g_);
        uint256 lp_ = _joinReserve(g_, stable_, common_, true);
        Repo._markLive();
        id_ = _completeBond(split_, lock_, to_, lp_); principal_ = split_.userDetfOut;
        _syncAllExpectedHoldReserves();
    }
    function _firstBondSplit(uint256 stable_, uint256 common_, uint256 lock_) internal view returns (MintSplit memory split_, uint256 g_) {
        g_ = _firstBondLiquidity(stable_, common_);
        split_ = _splitBondAmount(_quoteBondPurchase(stable_, true, lock_) + _quoteBondPurchase(common_, false, lock_), g_);
    }
    function _completeBond(MintSplit memory split_, uint256 duration_, address to_, uint256 lp_) internal returns (uint256 id_) {
        if (lp_ == 0 || split_.userDetfOut == 0) revert ZeroAmount();
        if (to_ == address(0)) to_ = msg.sender;
        address nft_ = address(Repo._layoutStruct().bondNftVault);
        _mintDetf(address(this), split_.userDetfOut);
        IERC20(address(this)).forceApprove(nft_, split_.userDetfOut);
        id_ = IDetfBondNFT(nft_).createFundedPosition(split_.userDetfOut, duration_, to_);
        IERC20(address(this)).forceApprove(nft_, 0);
        _fundStakingRewards(split_.inventoryDetfOut);
    }
    function previewBond(IERC20 in_, uint256 amount_, uint256 duration_) external view returns (uint256 principal_, uint256 liquidity_, uint256 pot_) {
        _requireReservePoolInitialized();
        (RoutedPoolSelection memory path_,, uint256 bpt_) = _previewRoutedPoolBpt(in_, amount_);
        liquidity_ = _quoteBondJoinDetf(bpt_, path_.depositToStablePool);
        MintSplit memory split_ = _splitBondAmount(_quoteBondPurchase(bpt_, path_.depositToStablePool, _effectiveLockDuration(duration_)), liquidity_);
        return (split_.userDetfOut, liquidity_, split_.inventoryDetfOut);
    }
    function previewInitializeReserve(uint256 stable_, uint256 common_, uint256 duration_) external view returns (uint256 principal_, uint256 liquidity_, uint256 pot_) {
        if (_isReserveLive()) revert Repo.ReserveAlreadyInitialized();
        if (stable_ == 0 || common_ == 0) revert ZeroAmount();
        (MintSplit memory split_, uint256 g_) = _firstBondSplit(stable_, common_, _effectiveLockDuration(duration_));
        return (split_.userDetfOut, g_, split_.inventoryDetfOut);
    }
    function acceptedBondTokens() external view returns (address[] memory) { return _tokensIn(); }
    function isAcceptedBondToken(IERC20 in_) external view returns (bool) {
        address[] memory tokens_ = _tokensIn();
        for (uint256 i_; i_ < tokens_.length; ++i_) if (address(in_) == tokens_[i_]) return true;
        return false;
    }
    function facetName() public pure returns (string memory) { return type(ComposedStableCommonDetfBondingFacet).name; }
    function facetInterfaces() public pure returns (bytes4[] memory a_) {
        a_ = new bytes4[](1);
        a_[0] = type(IComposedStableCommonDetfBonding).interfaceId;
    }
    function facetFuncs() public pure returns (bytes4[] memory a_) {
        a_ = new bytes4[](9);
        a_[0] = IComposedStableCommonDetfBonding.bond.selector;
        a_[1] = IComposedStableCommonDetfBonding.initializeReserve.selector;
        a_[2] = IComposedStableCommonDetfBonding.previewBond.selector;
        a_[3] = IComposedStableCommonDetfBonding.previewInitializeReserve.selector;
        a_[4] = IComposedStableCommonDetfBonding.acceptedBondTokens.selector;
        a_[5] = IComposedStableCommonDetfBonding.isAcceptedBondToken.selector;
        a_[6] = IDetfReserveDonation.joinDonatedCapital.selector;
        a_[7] = IDetfReserveDonation.notifyReserveDonated.selector;
        a_[8] = bytes4(keccak256("donate(address,uint256,bool)"));
    }
    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }

    function joinDonatedCapital(IERC20 token_, uint256 amount_, uint256 deadline_) external nonReentrant returns (uint256 lp_) {
        _requireDonationCaller();
        _requireActive(deadline_, amount_);
        _requireReservePoolInitialized();
        if (address(token_) == address(this)) lp_ = _joinReserve(_secureTokenTransfer(token_, amount_, false), 0, 0, false);
        else {
            (RoutedPoolSelection memory path_, uint256 bpt_) = _collectRoutedBpt(token_, amount_, false, deadline_);
            lp_ = _joinReserve(0, path_.depositToStablePool ? bpt_ : 0, path_.depositToStablePool ? 0 : bpt_, false);
        }
        if (lp_ == 0) revert ZeroAmount();
        _syncAllExpectedHoldReserves();
    }
    function notifyReserveDonated() external { _requireDonationCaller(); _syncAllExpectedHoldReserves(); }
    function _requireDonationCaller() private view {
        if (msg.sender != address(Repo._layoutStruct().bondNftVault)) revert Repo.NotAuthorized(msg.sender);
    }
    function donate(IERC20 token_, uint256 amount_, bool prepaid_) external {
        IDetfNftReserveDonation(address(Repo._layoutStruct().bondNftVault)).donate(msg.sender, token_, amount_, 0, prepaid_, block.timestamp);
    }

}
