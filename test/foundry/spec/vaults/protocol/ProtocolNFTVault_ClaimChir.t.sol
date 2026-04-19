// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IBaseProtocolDETFBonding} from "contracts/vaults/protocol/BaseProtocolDETFBondingTarget.sol";
import {
    ProtocolDETFBaseCustomFixtureHelpers,
    ProtocolDETFEthereumCustomFixtureHelpers
} from "./ProtocolDETF_CustomFixtureHelpers.t.sol";

abstract contract ProtocolNFTVaultClaimChirTestBase is Test {
    uint256 internal constant BOND_AMOUNT = 1_000e18;
    uint256 internal constant FIRST_SEIGNIORAGE_WETH = 200e18;
    uint256 internal constant SECOND_SEIGNIORAGE_WETH = 125e18;
    uint256 internal constant SHORT_LOCK = 30 days;
    uint256 internal constant LONG_LOCK = 180 days;

    struct TwoHolderScenario {
        IProtocolDETF detf;
        IProtocolNFTVault vault;
        uint256 aliceTokenId;
        uint256 bobTokenId;
        uint256 aliceShares;
        uint256 bobShares;
    }

    struct FirstTrancheSnapshot {
        uint256 alicePending;
        uint256 bobPending;
    }

    function _mintEnabledDetf() internal virtual returns (IProtocolDETF detf_);

    function _ensureMintEnabled(IProtocolDETF detf_) internal virtual;

    function _wethToken() internal view virtual returns (IERC20);

    function _alice() internal view virtual returns (address);

    function _bob() internal view virtual returns (address);

    function _bondWithWeth(IProtocolDETF detf_, address user_, uint256 amountIn_, uint256 lockDuration_)
        internal
        returns (IProtocolNFTVault vault_, uint256 tokenId_)
    {
        vault_ = detf_.protocolNFTVault();

        vm.startPrank(user_);
        _wethToken().approve(address(detf_), amountIn_);
        (tokenId_,) = IBaseProtocolDETFBonding(address(detf_)).bond(
            _wethToken(), amountIn_, lockDuration_, user_, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function _mintSeigniorage(IProtocolDETF detf_, address user_, uint256 wethAmount_)
        internal
        returns (uint256 chirMinted_)
    {
        vm.startPrank(user_);
        _wethToken().approve(address(detf_), wethAmount_);
        chirMinted_ = IStandardExchangeIn(address(detf_)).exchangeIn(
            _wethToken(), wethAmount_, IERC20(address(detf_)), 0, user_, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function _claimRewards(IProtocolNFTVault vault_, uint256 tokenId_, address user_, address recipient_)
        internal
        returns (uint256 claimed_)
    {
        vm.prank(user_);
        claimed_ = vault_.claimRewards(tokenId_, recipient_);
    }

    function _sellNftToProtocol(IProtocolDETF detf_, uint256 tokenId_, address seller_)
        internal
        returns (uint256 richirMinted_)
    {
        vm.prank(seller_);
        richirMinted_ = IBaseProtocolDETFBonding(address(detf_)).sellNFT(tokenId_, seller_);
    }

    function _assertProportional(uint256 lhsAmount_, uint256 lhsWeight_, uint256 rhsAmount_, uint256 rhsWeight_)
        internal
    {
        assertGt(lhsAmount_, 0, "lhs amount");
        assertGt(rhsAmount_, 0, "rhs amount");
        assertGt(lhsWeight_, 0, "lhs weight");
        assertGt(rhsWeight_, 0, "rhs weight");

        uint256 actualRatio = lhsAmount_ * 1e18 / rhsAmount_;
        uint256 expectedRatio = lhsWeight_ * 1e18 / rhsWeight_;
        assertApproxEqAbs(actualRatio, expectedRatio, 1e12, "proportional rewards");
    }

    function _setupTwoHolderScenario(IProtocolDETF detf_) internal returns (TwoHolderScenario memory scenario_) {
        scenario_.detf = detf_;
        (scenario_.vault, scenario_.aliceTokenId) = _bondWithWeth(detf_, _alice(), BOND_AMOUNT, SHORT_LOCK);
        (, scenario_.bobTokenId) = _bondWithWeth(detf_, _bob(), BOND_AMOUNT, LONG_LOCK);
        scenario_.aliceShares = scenario_.vault.positionOf(scenario_.aliceTokenId).effectiveShares;
        scenario_.bobShares = scenario_.vault.positionOf(scenario_.bobTokenId).effectiveShares;
    }

    function _collectFirstTranche(TwoHolderScenario memory scenario_)
        internal
        returns (FirstTrancheSnapshot memory snapshot_)
    {
        _mintSeigniorage(scenario_.detf, _bob(), FIRST_SEIGNIORAGE_WETH);

        snapshot_.alicePending = scenario_.vault.pendingRewards(scenario_.aliceTokenId);
        snapshot_.bobPending = scenario_.vault.pendingRewards(scenario_.bobTokenId);
        _assertProportional(
            snapshot_.alicePending,
            scenario_.aliceShares,
            snapshot_.bobPending,
            scenario_.bobShares
        );

        uint256 aliceClaimed = _claimRewards(scenario_.vault, scenario_.aliceTokenId, _alice(), _alice());
        assertEq(aliceClaimed, snapshot_.alicePending, "alice should receive first tranche");
        assertEq(scenario_.vault.pendingRewards(scenario_.aliceTokenId), 0, "alice should have no pending rewards after first claim");
    }

    function _assertSecondTrancheClaims(
        TwoHolderScenario memory scenario_,
        FirstTrancheSnapshot memory firstTranche_
    ) internal {
        _mintSeigniorage(scenario_.detf, _bob(), SECOND_SEIGNIORAGE_WETH);

        uint256 alicePendingSecond = scenario_.vault.pendingRewards(scenario_.aliceTokenId);
        uint256 bobPendingAfterSecond = scenario_.vault.pendingRewards(scenario_.bobTokenId);
        uint256 bobSecondTrancheOnly = bobPendingAfterSecond - firstTranche_.bobPending;
        IERC20 chir = IERC20(address(scenario_.detf));
        uint256 aliceBalanceBefore = chir.balanceOf(_alice());
        uint256 bobBalanceBefore = chir.balanceOf(_bob());

        _assertProportional(
            alicePendingSecond,
            scenario_.aliceShares,
            bobSecondTrancheOnly,
            scenario_.bobShares
        );

        uint256 aliceClaimedSecond = _claimRewards(scenario_.vault, scenario_.aliceTokenId, _alice(), _alice());
        uint256 bobClaimed = _claimRewards(scenario_.vault, scenario_.bobTokenId, _bob(), _bob());

        assertEq(aliceClaimedSecond, alicePendingSecond, "alice should receive only second tranche after early claim");
        assertEq(bobClaimed, bobPendingAfterSecond, "bob should receive both accumulated tranches");
        assertEq(chir.balanceOf(_alice()) - aliceBalanceBefore, aliceClaimedSecond, "alice second claim");
        assertEq(chir.balanceOf(_bob()) - bobBalanceBefore, bobClaimed, "bob claim");
        assertEq(scenario_.vault.pendingRewards(scenario_.aliceTokenId), 0, "alice pending should reset after second claim");
        assertEq(scenario_.vault.pendingRewards(scenario_.bobTokenId), 0, "bob pending should reset after claim");
    }

    function _runMultiTrancheClaimScenario(IProtocolDETF detf_) internal {
        TwoHolderScenario memory scenario = _setupTwoHolderScenario(detf_);
        FirstTrancheSnapshot memory firstTranche = _collectFirstTranche(scenario);
        _assertSecondTrancheClaims(scenario, firstTranche);
    }
}

contract ProtocolNFTVaultClaimChirBaseTest is ProtocolDETFBaseCustomFixtureHelpers, ProtocolNFTVaultClaimChirTestBase {
    function _mintEnabledDetf() internal override returns (IProtocolDETF detf_) {
        detf_ = _deployMintEnabledDetf();
        _assertMintEnabled(detf_);
    }

    function _ensureMintEnabled(IProtocolDETF detf_) internal view override {
        _assertMintEnabled(detf_);
    }

    function _wethToken() internal view override returns (IERC20) {
        return IERC20(address(weth9));
    }

    function _alice() internal view override returns (address) {
        return detfAlice;
    }

    function _bob() internal view override returns (address) {
        return detfBob;
    }

    function test_rewardToken_isChir() public {
        IProtocolDETF customDetf = _mintEnabledDetf();
        assertEq(address(customDetf.protocolNFTVault().rewardToken()), address(customDetf), "reward token should be CHIR");
    }

    function test_claimRewards_transfersClaimableChir() public {
        IProtocolDETF customDetf = _mintEnabledDetf();
        (IProtocolNFTVault vault, uint256 tokenId) = _bondWithWeth(customDetf, _alice(), BOND_AMOUNT, SHORT_LOCK);

        assertEq(vault.pendingRewards(tokenId), 0, "no rewards before seigniorage");

        _mintSeigniorage(customDetf, _bob(), FIRST_SEIGNIORAGE_WETH);

        uint256 pendingBefore = vault.pendingRewards(tokenId);
        uint256 chirBalanceBefore = IERC20(address(customDetf)).balanceOf(_alice());
        uint256 claimed = _claimRewards(vault, tokenId, _alice(), _alice());
        uint256 chirBalanceAfter = IERC20(address(customDetf)).balanceOf(_alice());

        assertGt(pendingBefore, 0, "expected claimable CHIR");
        assertEq(claimed, pendingBefore, "claim should match pending rewards");
        assertEq(chirBalanceAfter - chirBalanceBefore, claimed, "recipient should receive claimed CHIR");
        assertEq(vault.pendingRewards(tokenId), 0, "claim should clear pending rewards");
    }

    function test_multiTrancheClaims_preserveProportionality_whenOnlySomeHoldersClaimEarly() public {
        IProtocolDETF customDetf = _mintEnabledDetf();
        _runMultiTrancheClaimScenario(customDetf);
    }

    function test_captureSeigniorage_compoundsOnlyProtocolNftShare() public {
        IProtocolDETF customDetf = _mintEnabledDetf();
        (IProtocolNFTVault vault, uint256 tokenId) = _bondWithWeth(customDetf, _alice(), BOND_AMOUNT, LONG_LOCK);
        uint256 protocolTokenId = vault.protocolNFTId();

        _sellNftToProtocol(customDetf, tokenId, _alice());

        _mintSeigniorage(customDetf, _bob(), FIRST_SEIGNIORAGE_WETH);

        uint256 protocolPendingBefore = vault.pendingRewards(protocolTokenId);
        IProtocolNFTVault.Position memory protocolPositionBefore = vault.positionOf(protocolTokenId);

        uint256 bptReceived = IBaseProtocolDETFBonding(address(customDetf)).captureSeigniorage();

        IProtocolNFTVault.Position memory protocolPositionAfter = vault.positionOf(protocolTokenId);

        assertGt(protocolPendingBefore, 0, "protocol NFT should accrue CHIR rewards");
        assertGt(bptReceived, 0, "captureSeigniorage should compound protocol CHIR share");
        assertGt(
            protocolPositionAfter.originalShares,
            protocolPositionBefore.originalShares,
            "protocol NFT principal should increase after capture"
        );
        assertEq(vault.pendingRewards(protocolTokenId), 0, "capture should consume protocol NFT pending CHIR");
    }
}

contract ProtocolNFTVaultClaimChirEthereumTest is ProtocolDETFEthereumCustomFixtureHelpers, ProtocolNFTVaultClaimChirTestBase {
    function _mintEnabledDetf() internal override returns (IProtocolDETF detf_) {
        detf_ = _deployMintEnabledEthereumDetf();
        _driveEthereumToMintEnabled(detf_);
    }

    function _ensureMintEnabled(IProtocolDETF detf_) internal view override {
        detf_;
    }

    function _wethToken() internal view override returns (IERC20) {
        return IERC20(address(weth9));
    }

    function _alice() internal view override returns (address) {
        return detfAlice;
    }

    function _bob() internal view override returns (address) {
        return detfBob;
    }

    function test_rewardToken_isChir() public {
        IProtocolDETF customDetf = _mintEnabledDetf();
        assertEq(address(customDetf.protocolNFTVault().rewardToken()), address(customDetf), "reward token should be CHIR");
    }

    function test_claimRewards_transfersClaimableChir() public {
        IProtocolDETF customDetf = _mintEnabledDetf();
        (IProtocolNFTVault vault, uint256 tokenId) = _bondWithWeth(customDetf, _alice(), BOND_AMOUNT, SHORT_LOCK);

        assertEq(vault.pendingRewards(tokenId), 0, "no rewards before seigniorage");

        _mintSeigniorage(customDetf, _bob(), FIRST_SEIGNIORAGE_WETH);

        uint256 pendingBefore = vault.pendingRewards(tokenId);
        uint256 chirBalanceBefore = IERC20(address(customDetf)).balanceOf(_alice());
        uint256 claimed = _claimRewards(vault, tokenId, _alice(), _alice());
        uint256 chirBalanceAfter = IERC20(address(customDetf)).balanceOf(_alice());

        assertGt(pendingBefore, 0, "expected claimable CHIR");
        assertEq(claimed, pendingBefore, "claim should match pending rewards");
        assertEq(chirBalanceAfter - chirBalanceBefore, claimed, "recipient should receive claimed CHIR");
        assertEq(vault.pendingRewards(tokenId), 0, "claim should clear pending rewards");
    }

    function test_multiTrancheClaims_preserveProportionality_whenOnlySomeHoldersClaimEarly() public {
        IProtocolDETF customDetf = _mintEnabledDetf();
        _runMultiTrancheClaimScenario(customDetf);
    }

    function test_captureSeigniorage_compoundsOnlyProtocolNftShare() public {
        IProtocolDETF customDetf = _mintEnabledDetf();
        (IProtocolNFTVault vault, uint256 tokenId) = _bondWithWeth(customDetf, _alice(), BOND_AMOUNT, LONG_LOCK);
        uint256 protocolTokenId = vault.protocolNFTId();

        _sellNftToProtocol(customDetf, tokenId, _alice());

        _mintSeigniorage(customDetf, _bob(), FIRST_SEIGNIORAGE_WETH);

        uint256 protocolPendingBefore = vault.pendingRewards(protocolTokenId);
        IProtocolNFTVault.Position memory protocolPositionBefore = vault.positionOf(protocolTokenId);

        uint256 bptReceived = IBaseProtocolDETFBonding(address(customDetf)).captureSeigniorage();

        IProtocolNFTVault.Position memory protocolPositionAfter = vault.positionOf(protocolTokenId);

        assertGt(protocolPendingBefore, 0, "protocol NFT should accrue CHIR rewards");
        assertGt(bptReceived, 0, "captureSeigniorage should compound protocol CHIR share");
        assertGt(
            protocolPositionAfter.originalShares,
            protocolPositionBefore.originalShares,
            "protocol NFT principal should increase after capture"
        );
        assertEq(vault.pendingRewards(protocolTokenId), 0, "capture should consume protocol NFT pending CHIR");
    }
}