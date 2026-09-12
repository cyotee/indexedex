// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IDetfErrors} from "contracts/interfaces/IDetfErrors.sol";
import {
    DETF_CREATOR_BOND_NFT_ID,
    DETF_FEE_TO_BOND_NFT_ID,
    DETF_FIRST_USER_BOND_NFT_ID,
    DETF_PROTOCOL_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {UniswapV4Detf_ClaimBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_ClaimBase.sol";

import {FundedRewardAssertions} from "contracts/test/bases/FundedRewardAssertions.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF, IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {DETFFundedStakingMath} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {DETFFundedBondTarget} from "contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol";

/// @notice Current funded replacements for FC1-FC12, shared by each actual reserve/provider fixture.
abstract contract V4FundedFeeBehavior is FundedRewardAssertions {
    function _fundedFeeSubject() internal view virtual returns (IUniswapV4Detf);
    function _fundedFeeOracle() internal view virtual returns (address);
    function _fundedFeeAdmin() internal view virtual returns (address);
    function _fundedFeeBoot() internal virtual returns (uint256);
    function _fundedFeeBond(address d_, uint256 amount_) internal virtual returns (uint256 id_, uint256 lpOut_);
    function _fundedFeeLead(address d_) internal view virtual returns (IERC20);
    function _fundedFeeUnits(uint256 whole_) internal view virtual returns (uint256);
    function _fundedFeeDeploy(address creator_) internal virtual returns (address);
    function _fundedFeeLock() internal view virtual returns (uint256);

    function _fundedFeeWave(IUniswapV4Detf d_, uint256 amount_) internal returns (uint256 id_) {
        IDETFFundedRewards(address(d_)).synchronizeRewards();
        IStakedDETF stake_ = IStakedDETF(d_.rebasingClaimToken());
        IDetfBondNFT nft_ = IDetfBondNFT(d_.bondNftVault());
        (, uint256 principal_, uint256 reward_,) = d_.previewBond(
            _fundedFeeLead(address(d_)), amount_, _fundedFeeLock()
        );
        assertGt(principal_, 0, "actual later bond principal");
        assertGt(reward_, 0, "new issuance funds rewards");
        FundingExpectation memory expected_ = _expectedBondFunding(
            address(d_), stake_, nft_, _fundedFeeOracle(), principal_, reward_
        );
        (id_,) = _fundedFeeBond(address(d_), amount_);
        assertEq(nft_.positionOf(id_).principal, principal_, "funded principal quote");
        _assertBondFunding(address(d_), stake_, nft_, id_, expected_);
        assertEq(nft_.previewClaim(1).rewardsDue, 0, "fee income already paid to staking wallet");
        assertEq(nft_.previewClaim(2).rewardsDue, 0, "creator income already paid to staking wallet");
    }

    function test_FC_fundedTwoWavesMatchIndependentFloors() public {
        uint256 oldId_ = _fundedFeeBoot();
        IUniswapV4Detf d_ = _fundedFeeSubject();
        IDetfBondNFT nft_ = IDetfBondNFT(d_.bondNftVault());
        DETFFundedStakingMath.BondPosition memory old_ = nft_.positionOf(oldId_);
        _fundedFeeWave(d_, _fundedFeeUnits(4));
        _fundedFeeWave(d_, _fundedFeeUnits(2));
        DETFFundedStakingMath.BondPosition memory after_ = nft_.positionOf(oldId_);
        assertEq(after_.principal, old_.principal, "later bonds cannot dilute earlier fixed principal");
        assertEq(after_.stakingGons, old_.stakingGons, "later purchases preserve earlier reward ownership");
        assertGt(nft_.previewClaim(oldId_).rewardsDue, 0, "old bond keeps funded staking income");
    }

    function test_FC_fullExitAndFeeToRotationPreserveStandingIncome() public {
        _fundedFeeBoot();
        IUniswapV4Detf d_ = _fundedFeeSubject();
        IStakedDETF stake_ = IStakedDETF(d_.rebasingClaimToken());
        IDetfBondNFT nft_ = IDetfBondNFT(d_.bondNftVault());
        _exitStandingReceiptsAndChangeOracle(
            address(d_), stake_, nft_, _fundedFeeOracle(), _fundedFeeAdmin()
        );
        _fundedFeeWave(d_, _fundedFeeUnits(4));
        address current_ = address(IVaultFeeOracleQuery(_fundedFeeOracle()).feeTo());
        assertEq(stake_.balanceOf(current_), 0, "reserve collector rotation does not redirect existing standing staking rights");
    }

    function test_FC_reservedRolesCannotClaimEscrowAgain() public {
        _fundedFeeBoot();
        IUniswapV4Detf d_ = _fundedFeeSubject();
        IDetfBondNFT nft_ = IDetfBondNFT(d_.bondNftVault());
        IStakedDETF stake_ = IStakedDETF(d_.rebasingClaimToken());
        bytes32 state_ = keccak256(abi.encode(stake_.stakingState()));
        for (uint256 id_ = 1; id_ <= 2; ++id_) {
            assertEq(nft_.positionOf(id_).principal, 0, "standing role is not purchased principal");
            assertEq(nft_.positionOf(id_).stakingGons, 0, "standing role owns no bond escrow");
            vm.expectRevert(abi.encodeWithSelector(DETFFundedBondTarget.ReservedBond.selector, id_));
            nft_.claimRewards(id_, address(this));
            address beneficiary_ = nft_.ownerOf(id_);
            vm.expectRevert(abi.encodeWithSelector(DETFFundedBondTarget.ReservedBond.selector, id_));
            vm.prank(beneficiary_);
            nft_.claimBond(id_, beneficiary_);
        }
        assertEq(keccak256(abi.encode(stake_.stakingState())), state_, "rejected second claims cannot move backing or gons");
    }

    function test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner() public {
        _fundedFeeBoot();
        address d_ = _fundedFeeDeploy(address(0));
        _fundedFeeBond(d_, _fundedFeeUnits(20));
        IDetfBondNFT nft_ = IDetfBondNFT(IUniswapV4Detf(d_).bondNftVault());
        address fee_ = address(IVaultFeeOracleQuery(_fundedFeeOracle()).feeTo());
        assertEq(nft_.ownerOf(1), fee_, "fee role initial owner");
        assertEq(nft_.ownerOf(2), fee_, "zero creator fallback");
        _fundedFeeWave(IUniswapV4Detf(d_), _fundedFeeUnits(4));
    }

    function test_FC_explicitCreatorReceivesSeparateFundedIncome() public {
        _fundedFeeBoot();
        address creator_ = makeAddr("fundedFeeExplicitCreator");
        address d_ = _fundedFeeDeploy(creator_);
        _fundedFeeBond(d_, _fundedFeeUnits(20));
        IDetfBondNFT nft_ = IDetfBondNFT(IUniswapV4Detf(d_).bondNftVault());
        assertEq(nft_.ownerOf(2), creator_, "explicit creator role owner");
        assertTrue(nft_.ownerOf(1) != creator_, "separate standing beneficiaries");
        _fundedFeeWave(IUniswapV4Detf(d_), _fundedFeeUnits(4));
    }

    function test_FC_noNewFundingCannotRepeatStandingPayout() public {
        _fundedFeeBoot();
        IUniswapV4Detf d_ = _fundedFeeSubject();
        IDetfBondNFT nft_ = IDetfBondNFT(d_.bondNftVault());
        IStakedDETF stake_ = IStakedDETF(d_.rebasingClaimToken());
        bytes32 state_ = keccak256(abi.encode(stake_.stakingState()));
        uint256 feeGons_ = stake_.gonsOf(nft_.ownerOf(1));
        uint256 creatorGons_ = stake_.gonsOf(nft_.ownerOf(2));
        assertEq(IDETFFundedRewards(address(d_)).synchronizeRewards(), 0);
        assertEq(IDETFFundedRewards(address(d_)).synchronizeRewards(), 0);
        assertEq(keccak256(abi.encode(stake_.stakingState())), state_, "no duplicate reward allocation");
        assertEq(stake_.gonsOf(nft_.ownerOf(1)), feeGons_);
        assertEq(stake_.gonsOf(nft_.ownerOf(2)), creatorGons_);
    }
}

/**
 * @title UniswapV4Detf_Alignment_FeeCreatorClaimBase
 * @notice D28 FC1–FC12 on unified CP gold. NFT `claimRewards`. FC4 is a later `bond`.
 */
abstract contract UniswapV4Detf_Alignment_FeeCreatorClaimBase is UniswapV4Detf_ClaimBase, V4FundedFeeBehavior {
    address internal alice;
    address internal bob;

    function _fcActors() internal {
        if (alice == address(0)) {
            alice = makeAddr("alice");
            bob = makeAddr("bob");
        }
        _setPfc(detf);
        _setFeeOraclePfc(detf);
        _setBondTermsOn(detf);
    }

    function _feeToOf(address) internal view returns (address) {
        return address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
    }





    function _bootAlice(uint256 amt) internal returns (uint256 tokenId, uint256 shares) {
        _fcActors();
        return _bondOn(detf, alice, amt);
    }


    function _fundedFeeSubject() internal view override returns (IUniswapV4Detf) { return detfInfo; }
    function _fundedFeeOracle() internal view override returns (address) { return address(indexedexManager); }
    function _fundedFeeAdmin() internal view override returns (address) { return owner; }
    function _fundedFeeBoot() internal override returns (uint256 id_) {
        (id_,) = _bootAlice(_fundedFeeUnits(20));
    }
    function _fundedFeeBond(address d_, uint256 amount_) internal override returns (uint256, uint256) {
        return _bondOn(d_, bob, amount_);
    }
    function _fundedFeeLead(address d_) internal view override returns (IERC20) { return _leadPairOf(d_); }
    function _fundedFeeUnits(uint256 whole_) internal view override returns (uint256) { return whole_ * 1 ether; }
    function _fundedFeeLock() internal view override returns (uint256) { return DEFAULT_MIN_LOCK; }
    function _fundedFeeDeploy(address creator_) internal override returns (address d_) {
        IUniswapV4Detf.PkgArgs memory args_ = _openArgsPolicy();
        args_.creator = creator_;
        d_ = _deployTagged(args_, string.concat("funded-fc", _nextTag()));
        _setPfc(d_); _setFeeOraclePfc(d_); _setBondTermsOn(d_);
    }
}
