// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MigrationSourceUnitsHandler} from "./MigrationSourceUnitsHandler.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation}
    from "../interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationRecovery as Recovery} from "../interfaces/IUniswapV4DetfMigrationRecovery.sol";
import {IMigrationWeightedReceipt, IMigrationWeightedSynchronization, IMigrationEarlierReceipt} from "../legacy/IMigrationLegacyRecovery.sol";
import {IMigrationEarlierNft} from "../legacy/IMigrationLegacyNft.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {MigrationLegacyRecoveryLib as Legacy} from "../legacy/MigrationLegacyRecoveryLib.sol";

interface ISourceUnitsRedeemQuote {
    function previewRedeem(uint256 shares_) external view returns (uint256);
}

/// @notice Fixed admitted recovery stages and all-position fresh cliff/holder accounting.
/// @dev Earlier liquid/receipt and held SE/LP conversions remain unsupported.
contract MigrationSourceUnitsRecoveryHandler is MigrationSourceUnitsHandler {
    uint256 public batchRollbacks;
    uint256 public sourceRateChanges;
    mapping(address => uint256) internal paidGons;
    constructor(Migration m_) MigrationSourceUnitsHandler(m_) {}

    /// @notice Actual admitted source-backing donation moves ER display rate, never its original units/credit.
    function changeEarlierRate(uint256 seed_) public {
        uint256 before_ = IMigrationEarlierReceipt(Legacy.EARLIER_RECEIPT).redemptionRate();
        assertTrue(IERC20(Legacy.DTF).transfer(
            0xb7D4Bb379D361AD442CddEE53eA71a33957826A7, (seed_ % 5 + 1) * 1 ether));
        assertGt(IMigrationEarlierReceipt(Legacy.EARLIER_RECEIPT).redemptionRate(), before_);
        ++sourceRateChanges;
        assertAll();
    }

    /// @notice Real issued history remains excluded after its recipient configuration is replaced.
    function independentOriginWitness() external {
        require(independentHistory == bytes32(0), "one independent-origin fixture");
        Migration.IndependentAllocationInput[] memory a_ = new Migration.IndependentAllocationInput[](1);
        a_[0].recipient = OTHER; a_[0].evidenceId = bytes32("independent original fixture");
        a_[0].entitlements = new Migration.OriginalEntitlement[](1);
        bytes32 original_ = keccak256("stateful independently issued origin");
        a_[0].entitlements[0] = Migration.OriginalEntitlement(original_, 0.01 ether, 0, bytes32("fixture"));
        bytes32 config_ = keccak256(abi.encode(block.chainid, address(parent), parent.migrationSnapshot().id, a_[0]));
        vm.prank(currentOwner); Allocation(address(parent)).configureIndependentAllocations(a_);
        Migration.IndependentIssuanceRequest[] memory requests_ = new Migration.IndependentIssuanceRequest[](1);
        requests_[0] = Migration.IndependentIssuanceRequest(OTHER, config_);
        vm.prank(currentOwner);
        uint256[] memory ids_ = Allocation(address(parent)).issueIndependentAllocations(requests_);
        assertEq(ids_[0], 4, "fresh first allocation after paid owner bond");
        uint256 credit_ = creditAnchors[0];
        issued += credit_; positionGons += credit_ * k;
        positions.push(Position(ids_[0], credit_, 0, credit_ * k, block.timestamp, OTHER, false));
        independentHistory = keccak256(abi.encode(Migration.IndependentIssuance(
            true, config_, credit_, ids_[0], block.timestamp)));
        bytes32 replacement_ = keccak256("stateful replacement canonical origin");
        a_[0].entitlements[0].entitlementId = replacement_;
        a_[0].entitlements[0].originalEth = 0.02 ether;
        vm.prank(currentOwner); Allocation(address(parent)).configureIndependentAllocations(a_);
        independentConfiguration = keccak256(abi.encode(
            block.chainid, address(parent), parent.migrationSnapshot().id, a_[0]));
        for (uint256 i_; i_ < 10; ++i_) {
            Migration.WeightedLiquidEntitlementInput[] memory inputs_ = new Migration.WeightedLiquidEntitlementInput[](1);
            inputs_[0] = _input(i_, 0);
            inputs_[0].originalId = original_;
            vm.prank(currentOwner);
            _reject(abi.encodeWithSelector(configSelector(i_), inputs_),
                abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, original_));
            inputs_[0].originalId = replacement_;
            vm.prank(currentOwner);
            _reject(abi.encodeWithSelector(configSelector(i_), inputs_),
                abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, replacement_));
            enrollmentRejections += 2;
        }
        assertAll();
    }

    /// @notice Actual distinct whole NFT original; its recovered shares never enlarge standalone ER credit.
    function takeEarlier(address wallet_, uint256 credit_) external {
        require(!earlierTaken, "one canonical earlier NFT fixture");
        vm.startPrank(wallet_);
        IERC721(EARLIER_NFT).approve(address(parent), 3);
        (uint256 id_, uint256 paid_) = parent.surrenderMigrationNft(EARLIER_NFT, 3, credit_, block.timestamp);
        vm.stopPrank();
        assertEq(paid_, credit_);
        earlierTaken = true;
        issued += credit_; positionGons += credit_ * k;
        positions.push(Position(id_, credit_, 0, credit_ * k, block.timestamp, wallet_, false));
        assertAll();
    }

    /// @notice Mature sale books external E separately from internal B and protected fractions.
    function sellEarlier() public {
        Recovery.Step[] memory steps_ = new Recovery.Step[](1);
        steps_[0] = Recovery.Step(Recovery.Stage.EarlierSale, 3, 0, 0);
        if (earlierSold) {
            vm.prank(currentOwner);
            _reject(abi.encodeCall(Recovery.recoverMigrationNfts, (steps_, block.timestamp)),
                abi.encodeWithSelector(Recovery.InvalidRecoveryCustody.selector, EARLIER_NFT, 3));
        } else {
            uint256 unlock_ = IMigrationEarlierNft(EARLIER_NFT).getPosition(3).unlockTime;
            if (block.timestamp < unlock_) vm.warp(unlock_);
            uint256 before_ = IMigrationEarlierReceipt(Legacy.EARLIER_RECEIPT).sharesOf(address(parent));
            uint256 rewardsBefore_ = IERC20(Legacy.EARLIER_DETF).balanceOf(address(parent));
            uint256 physicalLp_ = IERC20(Legacy.EARLIER_LP).balanceOf(EARLIER_NFT);
            bytes32 beneficiaries_ = _beneficiaries();
            vm.prank(currentOwner); recovery.recoverMigrationNfts(steps_, block.timestamp);
            earlierExternalShares = IMigrationEarlierReceipt(Legacy.EARLIER_RECEIPT).sharesOf(address(parent)) - before_;
            earlierRewards = IERC20(Legacy.EARLIER_DETF).balanceOf(address(parent)) - rewardsBefore_;
            assertGt(earlierExternalShares, 0, "actual external receipt mint");
            assertEq(IERC20(Legacy.EARLIER_LP).balanceOf(EARLIER_NFT), physicalLp_);
            assertEq(_beneficiaries(), beneficiaries_);
            rows[1].inventory += earlierRewards;
            earlierSold = true; ++recoveries;
        }
        assertAll();
    }

    /// @notice C-derived SY recovery mixes with W-R gons but never with its eligible Q/C.
    function redeemRecoveredSy(uint256 seed_) public {
        if (syRecovered == 0) { recover(2, seed_); return; }
        uint256 q_ = syRecovered / (seed_ % 4 + 1);
        if (q_ == 0) q_ = 1;
        IMigrationWeightedSynchronization(Legacy.WEIGHTED_DETF).synchronizeRewards();
        uint256 divisor_ = IMigrationWeightedReceipt(Legacy.WEIGHTED_RECEIPT).stakingState().gonsPerUnit;
        uint256 out_ = Math.mulDiv(q_, Math.mulDiv(1e36, 1e18, divisor_), 1e18);
        Recovery.Step[] memory steps_ = new Recovery.Step[](1);
        steps_[0] = Recovery.Step(Recovery.Stage.WeightedSyRedeem, 0, q_, 0);
        vm.prank(currentOwner); recovery.recoverMigrationNfts(steps_, block.timestamp);
        syRecovered -= q_; rows[2].inventory += out_ * divisor_;
        wsNative = rows[2].inventory / divisor_; ++recoveries;
        assertAll();
    }

    function recover(uint256 selection_, uint256 seed_) public {
        uint256[4] memory selected_ = [uint256(0), 2, 4, 5];
        uint256 i_ = selected_[selection_ % 4];
        _settleSource(i_);
        uint256 divisor_ = i_ == 2 ? IMigrationWeightedReceipt(source(i_)).stakingState().gonsPerUnit : 1;
        uint256 available_ = rows[i_].inventory / divisor_;
        if (available_ == 0) { surrender(i_, seed_); return; }
        uint256 n_ = available_ / (seed_ % 4 + 1);
        if (n_ == 0) n_ = 1;
        Recovery.Stage stage_ = i_ == 0 ? Recovery.Stage.WeightedConvert
            : i_ == 2 ? Recovery.Stage.WeightedUnstake
            : i_ == 4 ? Recovery.Stage.ClaimVaultRedeem : Recovery.Stage.DtfCustodySeRedeem;
        address output_ = i_ == 2 ? Legacy.WEIGHTED_DETF : i_ == 4 ? Legacy.WEIGHTED_SY : Legacy.DTF;
        uint256 before_ = IERC20(output_).balanceOf(address(parent));
        uint256 expected_ = i_ == 2 ? n_
            : i_ == 4 || i_ == 5 ? ISourceUnitsRedeemQuote(source(i_)).previewRedeem(n_) : 0;
        bytes32 beneficiaries_ = _beneficiaries();
        Recovery.Step[] memory steps_ = new Recovery.Step[](1);
        steps_[0] = Recovery.Step(stage_, 0, n_, 0);
        vm.prank(currentOwner); recovery.recoverMigrationNfts(steps_, block.timestamp);
        uint256 received_ = IERC20(output_).balanceOf(address(parent)) - before_;
        if (i_ != 0) assertEq(received_, expected_, "external source redemption, not parent inventory");
        assertEq(_beneficiaries(), beneficiaries_, "no alternative recovery beneficiary");
        rows[i_].inventory -= n_ * divisor_;
        if (i_ == 2) { rows[0].inventory += received_; wsNative = rows[2].inventory / divisor_; }
        else if (i_ == 4) syRecovered += received_;
        else dtfRecovered += received_;
        assertEq(IERC20(source(i_)).allowance(address(parent), source(i_)), 0);
        ++recoveries;
        assertAll();
    }

    function failedRecoveryBatch() public {
        if (rows[4].inventory == 0) { surrender(4, 1); return; }
        Recovery.Step[] memory steps_ = new Recovery.Step[](2);
        steps_[0] = Recovery.Step(Recovery.Stage.ClaimVaultRedeem, 0, rows[4].inventory, 0);
        steps_[1] = Recovery.Step(Recovery.Stage.WeightedConvert, 0, type(uint256).max, 0);
        bytes32 before_ = economicState();
        vm.prank(currentOwner);
        _reject(abi.encodeCall(Recovery.recoverMigrationNfts, (steps_, block.timestamp)),
            abi.encodeWithSelector(Recovery.RecoveryInventoryInsufficient.selector,
                Legacy.WEIGHTED_DETF, type(uint256).max, rows[0].inventory));
        assertEq(economicState(), before_);
        ++batchRollbacks;
        assertAll();
    }

    function advanceTime(uint256 seed_) public {
        vm.warp(vm.getBlockTimestamp() + (seed_ % 45 + 1) * 1 days);
        assertEq(parent.pendingExpansionDetf(), 0, "bounded native parent; no unmodeled expansion");
        assertAll();
    }

    function transferBond(uint256 seed_) public {
        Position storage p_ = positions[seed_ % positions.length];
        if (p_.retired) {
            vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", p_.id));
            bonds.positionOf(p_.id);
        } else {
            address next_ = p_.holder == OTHER ? address(this) : OTHER;
            vm.prank(p_.holder); IERC721(address(bonds)).transferFrom(p_.holder, next_, p_.id);
            p_.holder = next_; ++transfers;
        }
        assertAll();
    }

    function claimPrincipal(uint256 seed_) public {
        Position storage p_ = positions[seed_ % positions.length];
        if (p_.retired) {
            vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", p_.id));
            bonds.positionOf(p_.id);
        } else {
            uint256 due_ = block.timestamp >= p_.start + 90 days ? p_.principal - p_.claimed : 0;
            vm.prank(p_.holder); assertEq(bonds.claimPrincipal(p_.id, p_.holder), due_);
            p_.claimed += due_; p_.gons -= due_ * k; positionGons -= due_ * k;
            paidGons[p_.holder] += due_ * k; principalPaid += due_;
            if (p_.claimed == p_.principal && p_.gons < k) {
                positionGons -= p_.gons; p_.gons = 0; p_.retired = true;
            }
        }
        assertEq(receipt.gonsOf(address(this)), paidGons[address(this)]);
        assertEq(receipt.gonsOf(OTHER), paidGons[OTHER]);
        assertAll();
    }

    function changeOwner() public {
        address previous_ = currentOwner;
        address next_ = previous_ == address(0x24DD) ? address(0x24EE) : address(0x24DD);
        vm.prank(previous_); parent.initiateOwnershipTransfer(next_);
        vm.prank(next_); parent.acceptOwnershipTransfer();
        currentOwner = next_;
        Recovery.Step[] memory steps_ = new Recovery.Step[](1);
        steps_[0] = Recovery.Step(Recovery.Stage.ClaimVaultRedeem, 0, 1, 0);
        bytes32 before_ = economicState();
        vm.prank(previous_);
        _reject(abi.encodeCall(Recovery.recoverMigrationNfts, (steps_, block.timestamp)),
            abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, previous_));
        assertEq(economicState(), before_);
        assertAll();
    }

    function _beneficiaries() private view returns (bytes32) {
        return keccak256(abi.encode(IERC20(Legacy.DTF).balanceOf(currentOwner),
            IERC20(Legacy.DTF).balanceOf(address(this)), IERC20(Legacy.DTF).balanceOf(OTHER),
            IERC20(Legacy.WEIGHTED_SY).balanceOf(currentOwner), IERC20(Legacy.WEIGHTED_SY).balanceOf(address(this)),
            IERC20(Legacy.WEIGHTED_SY).balanceOf(OTHER), IERC20(Legacy.WEIGHTED_DETF).balanceOf(currentOwner),
            IERC20(Legacy.WEIGHTED_DETF).balanceOf(address(this)), IERC20(Legacy.WEIGHTED_DETF).balanceOf(OTHER)));
    }
}
