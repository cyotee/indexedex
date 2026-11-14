// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MigrationNativeLedger} from "./MigrationNativeLedger.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IRateProvider} from "@crane/contracts/protocols/dexes/balancer/common/interfaces/IRateProvider.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IUniswapV4StandardExchangeWeightedBufferHook as Hook} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation,
    IUniswapV4DetfMigrationAccounting as Accounting} from "../interfaces/IUniswapV4DetfMigration.sol";

/// @notice Bounded native lifecycle actions over real proxies with an independent ledger.
/// @dev Market inputs are bounded and the fixture's mint threshold is 100 WAD.
/// This is not an arbitrary-expansion model. Claims have real per-position clocks.
// allow: SIZE_OK - One bounded thirteen-action state machine; accounting is a separate ledger.
contract MigrationNativeHandler is MigrationNativeLedger {
    uint256[6] internal configured;
    uint256[6] internal delivered;
    bytes32[6] internal issuedConfiguration;
    uint256[6] internal issuedId;
    uint256[6] internal issuedTime;
    uint256 public marketActions;
    uint256 public ownershipActions;

    constructor(Seed memory s_) MigrationNativeLedger(s_) {
        for (uint256 i_; i_ < 6; ++i_) configured[i_] = i_ % 3;
        delivered[0] = s_.firstCredit;
        delivered[1] = s_.secondCredit;
        issuedId[0] = 3; issuedId[1] = 4;
        issuedTime[0] = block.timestamp; issuedTime[1] = block.timestamp;
        issuedConfiguration[0] = _configuration(0);
        issuedConfiguration[1] = _configuration(1);
        IERC20(s_.pair).approve(address(parent), type(uint256).max);
        IERC20(s_.pair).approve(parent.hook(), type(uint256).max);
    }

    function _input(uint256 i_) internal view returns (Migration.IndependentAllocationInput memory a_) {
        a_.recipient = actors[i_];
        a_.evidenceId = keccak256("external fixture; not historical provenance");
        a_.entitlements = new Migration.OriginalEntitlement[](1);
        uint256 amount_ = (configured[i_] + 1) * 1e15;
        a_.entitlements[0] = Migration.OriginalEntitlement(
            keccak256(abi.encode("stateful-original", i_)), amount_, amount_, bytes32("fixture")
        );
    }

    function _configuration(uint256 i_) internal view returns (bytes32) {
        return keccak256(abi.encode(block.chainid, address(parent), snapshotId, _input(i_)));
    }

    function configure(uint256 actor_, uint256 amount_) public {
        uint256 i_ = actor_ % 6;
        uint256 previous_ = configured[i_];
        configured[i_] = amount_ % 3;
        Migration.IndependentAllocationInput[] memory a_ = new Migration.IndependentAllocationInput[](1);
        a_[0] = _input(i_);
        vm.prank(currentOwner);
        if (active) vm.expectRevert(abi.encodeWithSignature("NoTargetFor(bytes4)", Allocation.configureIndependentAllocations.selector));
        Allocation(address(parent)).configureIndependentAllocations(a_);
        if (active) { configured[i_] = previous_; ++rejections; }
        else ++successes;
        _count(this.configure.selector);
        assertAll();
    }

    function issue(uint256 actor_) public {
        uint256 i_ = actor_ % 6;
        Migration.IndependentIssuanceRequest[] memory r_ = new Migration.IndependentIssuanceRequest[](1);
        r_[0] = Migration.IndependentIssuanceRequest(actors[i_], _configuration(i_));
        vm.prank(currentOwner);
        if (active) vm.expectRevert(abi.encodeWithSignature("NoTargetFor(bytes4)", Allocation.issueIndependentAllocations.selector));
        else if (delivered[i_] != 0) vm.expectRevert(abi.encodeWithSelector(
            Migration.IndependentAllocationAlreadyIssued.selector, actors[i_]
        ));
        uint256[] memory ids_ = Allocation(address(parent)).issueIndependentAllocations(r_);
        if (active || delivered[i_] != 0) ++rejections;
        else {
            uint256 credit_ = frozenQuotes[configured[i_]];
            delivered[i_] = credit_;
            issuedConfiguration[i_] = _configuration(i_);
            issuedId[i_] = ids_[0];
            issuedTime[i_] = block.timestamp;
            _recordPosition(ids_[0], actors[i_], credit_, true);
            expectedSupply += credit_;
            ++successes;
        }
        _count(this.issue.selector);
        assertAll();
    }

    /// @notice Exact failing second entry must undo the first funded issuance.
    function failedBatch() public {
        Migration.IndependentIssuanceRequest[] memory r_ = new Migration.IndependentIssuanceRequest[](2);
        r_[0] = Migration.IndependentIssuanceRequest(actors[4], _configuration(4));
        r_[1] = Migration.IndependentIssuanceRequest(actors[5], bytes32("stale"));
        bytes32 before_ = keccak256(abi.encode(parent.independentIssuance(actors[4]), staking.stakingState(),
            IERC20(address(parent)).totalSupply(), IERC20(address(parent)).balanceOf(address(staking))));
        vm.prank(currentOwner);
        if (active) vm.expectRevert(abi.encodeWithSignature("NoTargetFor(bytes4)", Allocation.issueIndependentAllocations.selector));
        else if (delivered[4] != 0) vm.expectRevert(abi.encodeWithSelector(
            Migration.IndependentAllocationAlreadyIssued.selector, actors[4]));
        else if (delivered[5] != 0) vm.expectRevert(abi.encodeWithSelector(
            Migration.IndependentAllocationAlreadyIssued.selector, actors[5]));
        else vm.expectRevert(abi.encodeWithSelector(Migration.IndependentConfigurationMismatch.selector,
            actors[5], bytes32("stale"), _configuration(5)));
        Allocation(address(parent)).issueIndependentAllocations(r_);
        assertEq(keccak256(abi.encode(parent.independentIssuance(actors[4]), staking.stakingState(),
            IERC20(address(parent)).totalSupply(), IERC20(address(parent)).balanceOf(address(staking)))), before_);
        ++rejections;
        _count(this.failedBatch.selector);
        assertAll();
    }

    function activate() public {
        vm.prank(currentOwner);
        if (active) vm.expectRevert(abi.encodeWithSignature("NoTargetFor(bytes4)", Allocation.activateMigration.selector));
        Allocation(address(parent)).activateMigration();
        if (active) ++rejections;
        else { active = true; ++successes; }
        _count(this.activate.selector);
        assertAll();
    }

    function transferOwner() public {
        address next_ = currentOwner == seed.owner ? address(0x24A0) : seed.owner;
        vm.prank(currentOwner);
        parent.initiateOwnershipTransfer(next_);
        if (!active) {
            vm.prank(next_);
            vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, next_));
            Allocation(address(parent)).activateMigration();
            ++rejections;
        }
        vm.prank(next_);
        parent.acceptOwnershipTransfer();
        currentOwner = next_;
        ++successes; ++ownershipActions;
        _count(this.transferOwner.selector);
        assertAll();
    }

    function transferBond(uint256 index_) public {
        Position storage p_ = positions[index_ % positions.length];
        if (p_.retired) {
            transferOwner();
            return;
        }
        address next_ = p_.holder == actors[6] ? actors[7] : actors[6];
        vm.prank(p_.holder);
        IERC721(address(child)).transferFrom(p_.holder, next_, p_.id);
        p_.holder = next_;
        ++successes;
        _count(this.transferBond.selector);
        assertAll();
    }

    function claimPrincipal(uint256 index_) public {
        _positionClaim(index_ % positions.length, false);
        _count(this.claimPrincipal.selector);
        assertAll();
    }

    function claimRewards(uint256 index_) public {
        uint256 i_ = index_ % positions.length;
        if (!active) {
            vm.prank(positions[i_].holder);
            vm.expectRevert(Accounting.MigrationRewardsClosed.selector);
            child.claimRewards(positions[i_].id, positions[i_].holder);
            ++rejections;
        } else _positionClaim(i_, true);
        _count(this.claimRewards.selector);
        assertAll();
    }

    /// @notice Real postactivation payment funds a new ordinary position and a nonzero rebase.
    /// @dev Public pre-purchase quote supplies terms, never the post-funding staking value under test.
    function paidBond(uint256 amount_) public {
        if (!active) activate();
        uint256 q_ = 1e14 + amount_ % 1e15;
        address buyer_ = actors[3];
        (, uint256 principal_, uint256 reward_, uint256 self_) =
            parent.previewBond(IERC20(seed.pair), q_, 90 days);
        assertGt(principal_, 0);
        assertGt(reward_, 0);
        uint256 previousK_ = book.gonsPerUnit;
        IERC20(seed.pair).transfer(buyer_, q_);
        uint256 before_ = IERC20(seed.pair).balanceOf(buyer_);
        vm.startPrank(buyer_);
        IERC20(seed.pair).approve(address(parent), q_);
        (uint256 id_,) = parent.bond(IERC20(seed.pair), q_, 90 days, buyer_, false, block.timestamp);
        vm.stopPrank();
        assertEq(before_ - IERC20(seed.pair).balanceOf(buyer_), q_, "actual later paid capital");
        _recordPosition(id_, buyer_, principal_, false);
        expectedSupply += principal_ + reward_ + self_;
        _fundReward(reward_);
        assertLt(book.gonsPerUnit, previousK_, "nonzero later funded index growth");
        ++laterPaidBonds; laterFundedRewards += reward_; ++successes;
        _count(this.paidBond.selector);
        assertAll();
    }

    function advanceTime(uint256 days_) public {
        vm.warp(vm.getBlockTimestamp() + (days_ % 45 + 1) * 1 days);
        assertEq(parent.pendingExpansionDetf(), 0, "bounded no-expansion domain");
        _count(this.advanceTime.selector);
        assertAll();
    }

    /// @notice Both ordinary and role rewards are genuinely funded before this negative.
    function rejectRoleRewards() public {
        address fee_ = IERC721(address(child)).ownerOf(1);
        uint256 available_ = feeGons;
        if (fee_ == IERC721(address(child)).ownerOf(2)) available_ += creatorGons;
        if (!active) {
            vm.expectRevert(Accounting.MigrationRewardsClosed.selector);
            staking.claimDeferredRoleRewards(fee_);
            ++rejections;
        } else {
            uint256 amount_ = available_ / book.gonsPerUnit;
            assertEq(staking.claimDeferredRoleRewards(fee_), amount_);
            uint256 debit_ = amount_ * book.gonsPerUnit;
            roleGons -= debit_;
            if (fee_ == IERC721(address(child)).ownerOf(2)) { feeGons = available_ - debit_; creatorGons = 0; }
            else feeGons -= debit_;
            walletGons[fee_] += debit_;
            if (amount_ != 0) ++successes; else ++zeroClaims;
        }
        _count(this.rejectRoleRewards.selector);
        assertAll();
    }

    function market(uint256 amount_) public {
        uint256 q_ = (amount_ % 100 + 1) * 1e12;
        address hook_ = parent.hook();
        uint256 outBefore_ = IERC20(seed.otherPair).balanceOf(address(this));
        (uint256 out_,) = IStandardExchangeIn(parent.hook()).exchangeIn(
            IERC20(seed.pair), q_, IERC20(seed.otherPair), 1, address(this), false, block.timestamp
        );
        assertEq(IERC20(seed.otherPair).balanceOf(address(this)) - outBefore_, out_);
        assertGt(out_, 0, "real successful pool trade");
        vm.prank(seed.registryOwner);
        IVaultFeeOracleManager(seed.registry).setVaultDexSwapFee(hook_, (amount_ % 10 + 1) * 1e14);
        assertEq(IVaultFeeOracleQuery(seed.registry).dexSwapFeeOfVault(parent.hook()), (amount_ % 10 + 1) * 1e14);
        IERC20[] memory ts_ = new IERC20[](1); ts_[0] = IERC20(seed.pair);
        uint256[] memory qs_ = new uint256[](1); qs_[0] = q_;
        parent.donateMigrationCapital(ts_, qs_, 0, 1, block.timestamp);
        ++marketActions; successes += 3;
        _count(this.market.selector);
        assertAll();
    }

    /// @notice A real SE backing donation changes its actual provider, never a mock rate setter.
    function providerRateChange(uint256 amount_) public {
        Hook hook_ = Hook(parent.hook());
        address provider_;
        for (uint256 i_; i_ < hook_.numTokens(); ++i_) {
            if (hook_.token(i_) == seed.pair) provider_ = hook_.rateProvider(i_);
        }
        assertNotEq(provider_, address(0));
        uint256 before_ = IRateProvider(provider_).getRate();
        assertTrue(IERC20(seed.pair).transfer(seed.se, (amount_ % 10 + 1) * 1e15));
        assertNotEq(IRateProvider(provider_).getRate(), before_, "actual provider change");
        ++successes;
        _count(this.providerRateChange.selector);
        assertAll();
    }

    /// @notice Interface-derived administration set, not copied facet output.
    function administrationSelectors() public pure returns (bytes4[16] memory) {
        return [Allocation.bootstrapMigrationReserve.selector, Allocation.captureMigrationSnapshot.selector,
            Allocation.configureIndependentAllocations.selector, Allocation.issueIndependentAllocations.selector,
            Allocation.activateMigration.selector, Allocation.configureNftEntitlements.selector,
            Allocation.configureWeightedSyEntitlements.selector, Allocation.configureDtfCustodySeEntitlements.selector,
            Allocation.configureWeightedLiquidEntitlements.selector, Allocation.configureClaimVaultEntitlements.selector,
            Allocation.configureWeightedReceiptEntitlements.selector, Allocation.configureEarlierReceiptEntitlements.selector,
            Allocation.configureEarlierLiquidEntitlements.selector, Allocation.configureHeldSeLpEntitlements.selector,
            Allocation.configureNftContributionEntitlements.selector, Allocation.configureClaimedSyEntitlements.selector];
    }

    function assertAll() public view {
        assertAccounting();
        assertEq(parent.owner(), currentOwner);
        assertEq(IMultiStepOwnable(seed.registry).owner(), seed.registryOwner);
        assertEq(parent.migrationActivated(), active);
        assertEq(keccak256(abi.encode(parent.migrationSnapshot())), snapshotHash);
        assertEq(isolatedBook(seed.isolated), seed.isolatedBook, "separate proxy book");
        for (uint256 i_; i_ < 3; ++i_) assertEq(parent.previewOriginalCredit((i_ + 1) * 1e15, (i_ + 1) * 1e15), frozenQuotes[i_]);
        for (uint256 i_; i_ < 6; ++i_) {
            Migration.IndependentAllocation memory a_ = parent.independentAllocation(actors[i_]);
            assertEq(a_.configurationId, _configuration(i_));
            assertEq(a_.totalCredit, frozenQuotes[configured[i_]]);
            Migration.IndependentIssuance memory x_ = parent.independentIssuance(actors[i_]);
            assertEq(x_.credit, delivered[i_]);
            assertEq(x_.bondTokenId, issuedId[i_]);
            assertEq(x_.configurationId, issuedConfiguration[i_]);
            assertEq(x_.issuedAt, issuedTime[i_]);
        }
        bytes4[16] memory ss_ = administrationSelectors();
        for (uint256 i_; i_ < ss_.length; ++i_) {
            if (active) assertEq(IDiamondLoupe(address(parent)).facetAddress(ss_[i_]), address(0));
            else assertNotEq(IDiamondLoupe(address(parent)).facetAddress(ss_[i_]), address(0));
        }
        assertEq(staking.deferredRewardGons(1, IERC721(address(child)).ownerOf(1)),
            feeGons + (IERC721(address(child)).ownerOf(1) == IERC721(address(child)).ownerOf(2) ? creatorGons : 0));
    }
}
