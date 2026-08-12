// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_MultiVaultWeightedDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";
import {
    IMultiVaultWeightedDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfInfoTarget.sol";
import {
    IMultiVaultWeightedDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfBondingTarget.sol";
import {
    ISingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFInfoTarget.sol";

/// @notice Nested production SingleStandardExchangeDETF as one multi-vault weighted leg.
contract MultiVaultWeightedDetf_Nested_Test is TestBase_MultiVaultWeightedDetf {
    address internal nestedUser;
    address internal directUser;

    function setUp() public override {
        super.setUp();
        nestedUser = makeAddr("nestedUser");
        directUser = makeAddr("directUser");
    }

    function test_nestedDetf_asLeg_outerMintBurn() public {
        address nested_ = _deployNestedSingleSeDetfLive(alice, 1_000e18);
        assertTrue(ISingleStandardExchangeDETFInfo(nested_).isReserveLive(), "nested live");

        address outer_ = _deployOuterOverNested(nested_, 1, type(uint256).max);
        IMultiVaultWeightedDetfInfo outerInfo_ = IMultiVaultWeightedDetfInfo(outer_);
        assertEq(outerInfo_.vaultCount(), 2, "two legs");
        assertEq(outerInfo_.underlyingVaults()[0], nested_, "leg0 nested");
        assertEq(outerInfo_.vaultShares()[0], nested_, "nested share is diamond");

        _assertInert(outer_);
        // Custom go-live: small nested mint into reserve (MaxInRatio on nested) + normal SE leg.
        _goLiveOuterWithNested(outer_, nested_, bob, 30e18, 400e18);
        _assertLive(outer_);

        // Outer mint using nested DETF shares (leg 0)
        uint256 nestedIn_ = _fundNestedDetfShares(nested_, nestedUser, 20e18);
        assertTrue(nestedIn_ > 0, "nested shares for outer mint");
        if (nestedIn_ > 5e18) nestedIn_ = 5e18;
        uint256 preview_ =
            IStandardExchangeIn(outer_).previewExchangeIn(IERC20(nested_), nestedIn_, IERC20(outer_));
        vm.startPrank(nestedUser);
        IERC20(nested_).approve(outer_, nestedIn_);
        uint256 outerOut_ = IStandardExchangeIn(outer_).exchangeIn(
            IERC20(nested_), nestedIn_, IERC20(outer_), 0, nestedUser, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(preview_, outerOut_, "outer mint nested leg preview==exec");
        assertTrue(outerOut_ > 0, "outer minted");

        // Outer burn back to nested shares
        uint256 burnAmt_ = outerOut_ / 2;
        if (burnAmt_ == 0) burnAmt_ = outerOut_;
        uint256 previewB_ =
            IStandardExchangeIn(outer_).previewExchangeIn(IERC20(outer_), burnAmt_, IERC20(nested_));
        vm.startPrank(nestedUser);
        IERC20(outer_).approve(outer_, burnAmt_);
        uint256 nestedBack_ = IStandardExchangeIn(outer_).exchangeIn(
            IERC20(outer_), burnAmt_, IERC20(nested_), 0, nestedUser, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertApproxEqAbs(previewB_, nestedBack_, 10, "outer burn nested leg");
        assertTrue(nestedBack_ > 0, "got nested shares back");

        // Nested still serves direct users
        uint256 seShares_ = _fundSeSharesLeg(0, directUser, 15e18);
        vm.startPrank(directUser);
        seShares[0].approve(nested_, seShares_);
        uint256 direct_ = IStandardExchangeIn(nested_).exchangeIn(
            seShares[0], seShares_, IERC20(nested_), 0, directUser, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(direct_ > 0, "nested still mints directly");

        _assertNoFreeInventory(outer_);
    }

    function _goLiveOuterWithNested(
        address outer_,
        address nested_,
        address user,
        uint256 nestedLp,
        uint256 seLp
    ) internal {
        uint256 nestedShares_ = _fundNestedDetfShares(nested_, user, nestedLp);
        uint256 seShares_ = _fundSeSharesLeg(1, user, seLp);
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = nestedShares_;
        amounts_[1] = seShares_;

        vm.startPrank(user);
        IERC20(nested_).approve(outer_, nestedShares_);
        seShares[1].approve(outer_, seShares_);
        uint256 bpt_ = IMultiVaultWeightedDetfBonding(outer_).initializeReserve(
            amounts_, block.timestamp + 1 hours
        );
        address pool_ = IMultiVaultWeightedDetfInfo(outer_).reservePool();
        IERC20(pool_).approve(outer_, bpt_);
        IMultiVaultWeightedDetfBonding(outer_).bond(
            IERC20(pool_), bpt_, DEFAULT_MIN_LOCK, user, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }
}
