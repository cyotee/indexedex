// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_MultiVaultWeightedDetf_Decimals
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf_Decimals.sol";

import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IMultiVaultWeightedDetfInfo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/IMultiVaultWeightedDetfInfo.sol";
import {IMultiVaultWeightedDetfBonding} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/IMultiVaultWeightedDetfBonding.sol";
import {ISingleStandardExchangeDETFInfo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/ISingleStandardExchangeDETFInfo.sol";

/// @notice Nested production SingleStandardExchangeDETF as one multi-vault weighted leg.
abstract contract MultiVaultWeightedDetf_Nested_Decimals is TestBase_MultiVaultWeightedDetf_Decimals {
    struct OuterSeFunding {
        address tokenA;
        address tokenB;
        uint256 amountA;
        uint256 amountB;
    }

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
        nestedIn_ = _capNestedInput(outer_, nested_, nestedIn_);
        uint256 preview_ = IStandardExchangeIn(outer_).previewExchangeIn(IERC20(nested_), nestedIn_, IERC20(outer_));
        vm.startPrank(nestedUser);
        IERC20(nested_).approve(outer_, nestedIn_);
        uint256 outerOut_ = IStandardExchangeIn(outer_)
            .exchangeIn(IERC20(nested_), nestedIn_, IERC20(outer_), 0, nestedUser, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertEq(preview_, outerOut_, "outer mint nested leg preview==exec");
        assertTrue(outerOut_ > 0, "outer minted");

        // Outer burn back to nested shares
        uint256 burnAmt_ = outerOut_ / 2;
        if (burnAmt_ == 0) burnAmt_ = outerOut_;
        uint256 previewB_ = IStandardExchangeIn(outer_).previewExchangeIn(IERC20(outer_), burnAmt_, IERC20(nested_));
        vm.startPrank(nestedUser);
        IERC20(outer_).approve(outer_, burnAmt_);
        uint256 nestedBack_ = IStandardExchangeIn(outer_)
            .exchangeIn(IERC20(outer_), burnAmt_, IERC20(nested_), 1, nestedUser, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertApproxEqAbs(previewB_, nestedBack_, 10, "outer burn nested leg");
        assertTrue(nestedBack_ > 0, "got nested shares back");

        // Nested still serves direct users
        uint256 seShares_ = _fundSeSharesLeg(0, directUser, 15e18);
        vm.startPrank(directUser);
        seShares[0].approve(nested_, seShares_);
        uint256 direct_ = IStandardExchangeIn(nested_)
            .exchangeIn(seShares[0], seShares_, IERC20(nested_), 0, directUser, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertTrue(direct_ > 0, "nested still mints directly");

        _assertNoFreeInventory(outer_);
    }

    function _goLiveOuterWithNested(address outer_, address nested_, address user, uint256 nestedLp, uint256 seLp)
        internal
    {
        uint256 nestedShares_ = _fundNestedDetfShares(nested_, user, nestedLp);
        // The unrated nested leg is valued at one per token. Size the other
        // seed from its actual nine-decimal quantity so a proportional exit
        // retains payable native units across the decimal matrix.
        uint256 seValueWad_ = nestedShares_ * 1e9;
        if (seValueWad_ > seLp) seValueWad_ = seLp;
        uint256 seShares_ = _fundOuterSeLeg(user, seValueWad_);
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = nestedShares_;
        amounts_[1] = seShares_;

        vm.startPrank(user);
        IERC20(nested_).approve(outer_, nestedShares_);
        seShares[1].approve(outer_, seShares_);
        IMultiVaultWeightedDetfBonding(outer_)
            .initializeReserve(amounts_, DEFAULT_MIN_LOCK, user, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function _fundOuterSeLeg(address user_, uint256 wadAmount_) internal returns (uint256 shares_) {
        OuterSeFunding memory funding_ = OuterSeFunding({
            tokenA: legTokenA[1],
            tokenB: legTokenB[1],
            amountA: _from18(legTokenA[1], wadAmount_),
            amountB: _from18(legTokenB[1], wadAmount_)
        });
        _mintToken(funding_.tokenA, user_, funding_.amountA);
        _mintToken(funding_.tokenB, user_, funding_.amountB);
        vm.startPrank(user_);
        IERC20(funding_.tokenA).approve(address(aerodromeRouter), funding_.amountA);
        IERC20(funding_.tokenB).approve(address(aerodromeRouter), funding_.amountB);
        (,, uint256 liquidity_) = aerodromeRouter.addLiquidity(
            funding_.tokenA,
            funding_.tokenB,
            legStable[1],
            funding_.amountA,
            funding_.amountB,
            1,
            1,
            user_,
            block.timestamp + 1 hours
        );
        IERC20(seVaults[1].asset()).approve(address(seVaults[1]), liquidity_);
        shares_ = seVaults[1].deposit(liquidity_, user_);
        vm.stopPrank();
    }

    /// @dev Bound the trade to the actual nine-decimal reserve balance. A
    /// fixed 5e18 cap is larger than the entire nested leg after the refactor.
    function _capNestedInput(address outer_, address nested_, uint256 funded_) internal view returns (uint256) {
        address pool_ = IMultiVaultWeightedDetfInfo(outer_).reservePool();
        (IERC20[] memory tokens_,, uint256[] memory raw_,) = IVault(address(vault)).getPoolTokenInfo(pool_);
        for (uint256 i; i < tokens_.length; ++i) {
            if (address(tokens_[i]) == nested_) {
                uint256 limit_ = raw_[i] / 10;
                assertGt(limit_, 0, "nested reserve supports a funded trade");
                return funded_ < limit_ ? funded_ : limit_;
            }
        }
        revert("nested reserve leg missing");
    }
}
