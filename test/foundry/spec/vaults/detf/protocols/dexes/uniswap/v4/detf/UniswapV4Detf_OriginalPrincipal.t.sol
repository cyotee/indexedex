// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {StakedDETFTarget} from "contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF, IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {DETFFundedStakingMath} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Orbital} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital.sol";
import {TestBase_UniswapV4Detf_Weighted} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted.sol";
import {TestBase_UniswapV4Detf_Quad} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad.sol";

/// @notice N10 funded replacements: principal is fixed DETF, independent of reserve LP ownership.
/// @dev Existing four production fixtures share the assertions; no fabricated DETF or product storage.
abstract contract UniswapV4Detf_OriginalPrincipalBase is Test {
    address internal constant BONDER = address(0xA110CE);

    function _principalDetf() internal view virtual returns (IUniswapV4Detf);
    function _principalEnableProtocolFees() internal virtual;
    function _principalFeeTo() internal view virtual returns (address);

    struct DonationBook { uint256 ownedLp; uint256 feeLp; uint256 totalLp; }

    function _principalDonationBook() private view returns (DonationBook memory book_) {
        IUniswapV4Detf d_ = _principalDetf();
        IERC20 lp_ = IERC20(d_.hook());
        book_.ownedLp = lp_.balanceOf(d_.bondNftVault()) + lp_.balanceOf(address(d_));
        book_.feeLp = lp_.balanceOf(_principalFeeTo());
        book_.totalLp = lp_.totalSupply();
    }
    function _principalMatureClaim(uint256 id_) internal virtual;

    function _principalNft() internal view returns (IDetfBondNFT) {
        return IDetfBondNFT(_principalDetf().bondNftVault());
    }

    function _principalStaking() internal view returns (IStakedDETF) {
        return IStakedDETF(_principalDetf().rebasingClaimToken());
    }

    function _principalLead() internal view returns (IERC20) {
        address[] memory tokens_ = IUniswapV4SeBufferHook(_principalDetf().hook()).tokens();
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            if (tokens_[i_] != address(_principalDetf())) return IERC20(tokens_[i_]);
        }
        revert("missing pair");
    }

    function _principalApprovePair(uint256 amount_) internal {
        IERC20 lead_ = _principalLead();
        SimpleMintableERC20(address(lead_)).mint(BONDER, amount_);
        vm.prank(BONDER);
        lead_.approve(address(_principalDetf()), amount_);
    }

    function _principalBond(uint256 amount_, uint256 duration_) internal returns (uint256 id_, uint256 allocation_) {
        IUniswapV4Detf d_ = _principalDetf();
        if (!d_.isReserveLive()) {
            (address[] memory tokens_, uint256[] memory amounts_) = d_.previewFirstBondPayments(_principalLead(), amount_);
            for (uint256 i_; i_ < tokens_.length; ++i_) {
                SimpleMintableERC20(tokens_[i_]).mint(BONDER, amounts_[i_]);
                vm.prank(BONDER);
                IERC20(tokens_[i_]).approve(address(d_), amounts_[i_]);
            }
        } else {
            _principalApprovePair(amount_);
        }
        IERC20 lead_ = _principalLead();
        vm.prank(BONDER);
        return d_.bond(lead_, amount_, duration_, BONDER, false, block.timestamp + 1 hours);
    }

    function _principalDonate() internal {
        IUniswapV4Detf d_ = _principalDetf();
        IERC20 lead_ = _principalLead();
        SimpleMintableERC20(address(lead_)).mint(BONDER, 40 ether);
        uint256 backing_ = _principalStaking().stakingState().accountedBacking;
        DonationBook memory before_ = _principalDonationBook();
        vm.startPrank(BONDER);
        lead_.approve(d_.bondNftVault(), 40 ether);
        uint256 joined_ = IDetfNftReserveDonation(d_.bondNftVault()).donate(
            lead_, 40 ether, 0, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(joined_, 0, "actual donation supplies reserve LP");
        DonationBook memory after_ = _principalDonationBook();
        assertGe(after_.ownedLp - before_.ownedLp, joined_, "returned join and swept residual LP are protocol inventory");
        assertEq(after_.totalLp - before_.totalLp, after_.ownedLp - before_.ownedLp + after_.feeLp - before_.feeLp, "all new LP reconciles to protocol and actual fee recipient");
        assertEq(_principalStaking().stakingState().accountedBacking, backing_, "reserve gift does not fabricate staking rewards");
    }

    function test_P1_fundedPrincipalSurvivesDonationAndLaterBond() public {
        (uint256 survivor_,) = _principalBond(100 ether, 30 days);
        DETFFundedStakingMath.BondPosition memory old_ = _principalNft().positionOf(survivor_);
        _principalDonate();
        IUniswapV4Detf d_ = _principalDetf();
        (, uint256 expected_, uint256 rewards_,) = d_.previewBond(_principalLead(), 10 ether, 180 days);
        uint256 backing_ = IERC20(address(d_)).balanceOf(address(_principalStaking()));
        (uint256 id_,) = _principalBond(10 ether, 180 days);
        DETFFundedStakingMath.BondPosition memory next_ = _principalNft().positionOf(id_);
        assertEq(next_.principal, expected_, "duration bonus included once in purchased DETF quote");
        assertEq(next_.vestingDuration, 180 days, "selected vesting duration");
        assertEq(IERC20(address(d_)).balanceOf(address(_principalStaking())), backing_ + expected_ + rewards_, "principal and immediate seigniorage funded exactly");
        assertEq(keccak256(abi.encode(_principalNft().positionOf(survivor_))), keccak256(abi.encode(old_)), "old fixed principal and attributed gons unchanged");
        assertGt(_principalNft().previewClaim(survivor_).rewardsDue, 0, "old funded position participates in new rewards");
        assertEq(_principalNft().previewClaim(id_).principalDue, 0, "new principal remains locked");
        assertEq(IDETFFundedRewards(address(d_)).synchronizeRewards(), 0, "seigniorage already distributed in this epoch");
    }

    function test_P1_matureClaimRetainsDonatedProtocolLiquidity() public {
        (uint256 id_,) = _principalBond(100 ether, 30 days);
        _principalDonate();
        _principalBond(20 ether, 30 days);
        _principalMatureClaim(id_);
    }

    function _principalBuyRaw() internal returns (uint256 received_) {
        IUniswapV4Detf d_ = _principalDetf();
        IERC20 lead_ = _principalLead();
        SimpleMintableERC20(address(lead_)).mint(BONDER, 1 ether);
        vm.startPrank(BONDER);
        lead_.approve(d_.hook(), 1 ether);
        received_ = IStandardExchangeIn(d_.hook()).exchangeIn(
            lead_, 1 ether, IERC20(address(d_)), 1, BONDER, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(received_, 0, "public pool swap funds actual DETF");
    }

    function _principalStake(uint256 amount_, uint256 minimum_) internal returns (uint256 paid_) {
        IStakedDETF staking_ = _principalStaking();
        IERC20 raw_ = IERC20(address(_principalDetf()));
        vm.startPrank(BONDER);
        raw_.approve(address(staking_), amount_);
        paid_ = staking_.exchangeIn(raw_, amount_, IERC20(address(staking_)), minimum_, BONDER, false, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function _principalAssertStake(uint256 amount_) internal {
        IStakedDETF staking_ = _principalStaking();
        IERC20 raw_ = IERC20(address(_principalDetf()));
        IStakedDETF.StakingState memory before_ = staking_.stakingState();
        uint256 gons_ = staking_.gonsOf(BONDER);
        uint256 lp_ = IERC20(_principalDetf().hook()).balanceOf(_principalDetf().bondNftVault());
        assertEq(staking_.previewExchangeIn(raw_, amount_, IERC20(address(staking_))), amount_, "funded stake always quotes exact raw units");
        assertEq(_principalStake(amount_, amount_), amount_, "exact issued receipt");
        assertEq(staking_.gonsOf(BONDER) - gons_, amount_ * before_.gonsPerUnit, "gons credited at funded index");
        assertEq(staking_.stakingState().accountedBacking, before_.accountedBacking + amount_, "held backing credited once");
        assertEq(IERC20(_principalDetf().hook()).balanceOf(_principalDetf().bondNftVault()), lp_, "staking does not buy or redeem LP");
    }

    function test_P1_stakingQuoteIgnoresLpFeesAndUsesFundedIndex() public {
        _principalBond(100 ether, 30 days);
        _principalEnableProtocolFees();
        _principalBond(20 ether, 30 days);
        uint256 raw_ = _principalBuyRaw();
        _principalAssertStake(raw_ / 4);
        uint256 oldGons_ = _principalStaking().gonsOf(BONDER);
        uint256 oldBalance_ = _principalStaking().balanceOf(BONDER);
        _principalDonate();
        _principalBond(20 ether, 180 days);
        assertEq(_principalStaking().gonsOf(BONDER), oldGons_, "funded rewards preserve ownership units");
        assertGe(_principalStaking().balanceOf(BONDER), oldBalance_, "funded rebase never reduces balance");
        _principalAssertStake(raw_ / 4);
    }

    function _principalBookHash() internal view returns (bytes32) {
        IUniswapV4Detf d_ = _principalDetf();
        IStakedDETF staking_ = _principalStaking();
        return keccak256(abi.encode(
            staking_.stakingState(), staking_.gonsOf(BONDER), IERC20(address(d_)).balanceOf(BONDER),
            IERC20(address(d_)).totalSupply(), IERC20(d_.hook()).totalSupply(),
            IERC20(d_.hook()).balanceOf(d_.bondNftVault()), _principalNft().balanceOf(BONDER)
        ));
    }

    function test_P1_stakeMinimumRollsBackAllFundedAccounting() public {
        _principalBond(100 ether, 30 days);
        _principalDonate();
        uint256 amount_ = _principalBuyRaw() / 2;
        IStakedDETF staking_ = _principalStaking();
        IERC20 raw_ = IERC20(address(_principalDetf()));
        vm.prank(BONDER);
        raw_.approve(address(staking_), amount_);
        bytes32 before_ = _principalBookHash();
        vm.prank(BONDER);
        vm.expectRevert(abi.encodeWithSelector(StakedDETFTarget.MinimumOutputNotMet.selector, amount_ + 1, amount_));
        staking_.exchangeIn(raw_, amount_, IERC20(address(staking_)), amount_ + 1, BONDER, false, block.timestamp + 1 hours);
        assertEq(_principalBookHash(), before_, "minimum failure preserves custody, funding, gons and NFT count");
    }
}

contract UniswapV4Detf_OriginalPrincipal is TestBase_UniswapV4Detf, UniswapV4Detf_OriginalPrincipalBase {
    function _principalDetf() internal view override returns (IUniswapV4Detf) {
        return detfInfo;
    }

    function _principalEnableProtocolFees() internal override {
        address hook_ = detfInfo.hook();
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(hook_, 2e15);
    }

    function _principalFeeTo() internal view override returns (address) {
        return address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
    }

    function _principalMatureClaim(uint256 id_) internal override {
        _assertFundedMatureClaim(detf, id_, BONDER);
    }

    function test_P1_oneNativeUnitStakeRedeemsExactly() public {
        _principalBond(100 ether, 30 days);
        _principalDonate();
        _principalBuyRaw();
        uint256 before_ = IERC20(detf).balanceOf(BONDER);
        uint256 backing_ = _principalStaking().stakingState().accountedBacking;
        _principalAssertStake(1);
        _assertFundedUnstake(detf, BONDER, 1);
        assertEq(IERC20(detf).balanceOf(BONDER), before_, "single native unit round trip");
        assertEq(_principalStaking().stakingState().accountedBacking, backing_, "funded liability round trip");
    }

    function test_P1_zeroNativePrincipalBondRevertsAtomically() public {
        _principalBond(100 ether, 30 days);
        _principalDonate();
        IERC20 lead_ = _principalLead();
        (bool quoted_, bytes memory result_) = detf.staticcall(abi.encodeCall(IUniswapV4Detf.previewBond, (lead_, 1, 30 days)));
        if (quoted_) {
            (, uint256 principal_,,) = abi.decode(result_, (uint256, uint256, uint256, uint256));
            assertEq(principal_, 0, "sub-native purchased DETF is unrepresentable");
        }
        _principalApprovePair(1);
        uint256 payment_ = lead_.balanceOf(BONDER);
        bytes32 before_ = _principalBookHash();
        vm.prank(BONDER);
        vm.expectRevert();
        detfInfo.bond(lead_, 1, 30 days, BONDER, false, block.timestamp + 1 hours);
        assertEq(_principalBookHash(), before_, "no new zero-principal NFT, supply or LP");
        assertEq(lead_.balanceOf(BONDER), payment_, "unrepresentable bond cannot take payment");
    }
}

contract UniswapV4Detf_Orbital_OriginalPrincipal is TestBase_UniswapV4Detf_Orbital, UniswapV4Detf_OriginalPrincipalBase {
    function _principalDetf() internal view override returns (IUniswapV4Detf) {
        return detfInfo;
    }

    function _principalEnableProtocolFees() internal override {
        address hook_ = detfInfo.hook();
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(hook_, 2e15);
    }

    function _principalFeeTo() internal view override returns (address) {
        return address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
    }

    function _principalMatureClaim(uint256 id_) internal override {
        _assertFundedMatureClaim(detf, id_, BONDER);
    }
}

contract UniswapV4Detf_Weighted_OriginalPrincipal is TestBase_UniswapV4Detf_Weighted, UniswapV4Detf_OriginalPrincipalBase {
    function _principalDetf() internal view override returns (IUniswapV4Detf) {
        return detfInfo;
    }

    function _principalEnableProtocolFees() internal override {
        address hook_ = detfInfo.hook();
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(hook_, 2e15);
    }

    function _principalFeeTo() internal view override returns (address) {
        return address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
    }

    function _principalMatureClaim(uint256 id_) internal override {
        _assertFundedMatureClaim(detf, id_, BONDER);
    }
}

contract UniswapV4Detf_Quad_OriginalPrincipal is TestBase_UniswapV4Detf_Quad, UniswapV4Detf_OriginalPrincipalBase {
    function _principalDetf() internal view override returns (IUniswapV4Detf) {
        return detfInfo;
    }

    function _principalEnableProtocolFees() internal override {
        address hook_ = detfInfo.hook();
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(hook_, 2e15);
    }

    function _principalFeeTo() internal view override returns (address) {
        return address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
    }

    function _principalMatureClaim(uint256 id_) internal override {
        _assertFundedMatureClaim(detf, id_, BONDER);
    }
}
