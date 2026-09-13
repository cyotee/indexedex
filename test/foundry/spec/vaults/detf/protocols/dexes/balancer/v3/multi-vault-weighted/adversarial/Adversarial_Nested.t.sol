// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_MultiVaultWeightedDetf_Adversarial
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/adversarial/TestBase_MultiVaultWeightedDetf_Adversarial.sol";
import {IMultiVaultWeightedDetfInfo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/IMultiVaultWeightedDetfInfo.sol";
import {IMultiVaultWeightedDetfBonding} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/IMultiVaultWeightedDetfBonding.sol";
import {ISingleStandardExchangeDETFInfo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/ISingleStandardExchangeDETFInfo.sol";

/// @notice G1: outer mint/burn does not brick nested inner DETF for third users.
/// @dev Deferred P2: G2 (inner activity does not inflate outer free inventory - residual asserts on outer),
///      G3 (structural opacity: outer sources do not import concrete inner protocol types).
contract Adversarial_Nested_Test is TestBase_MultiVaultWeightedDetf_Adversarial {
    function test_G1_outerActivity_doesNotBrickInner() public {
        address nested_ = _deployNestedSingleSeDetfLive(alice, 1_000e18);
        assertTrue(ISingleStandardExchangeDETFInfo(nested_).isReserveLive(), "nested live");

        address outer_ = _deployOuterOverNested(nested_, 1, type(uint256).max);
        _goLiveOuterWithNested(outer_, nested_, bob, 30e18, 400e18);
        _assertLive(outer_);

        // Outer mint with nested shares
        uint256 nestedIn_ = _fundNestedDetfShares(nested_, attacker, 20e18);
        nestedIn_ = _capNestedInput(outer_, nested_, nestedIn_);
        vm.startPrank(attacker);
        IERC20(nested_).approve(outer_, nestedIn_);
        uint256 outerOut_ = IStandardExchangeIn(outer_)
            .exchangeIn(IERC20(nested_), nestedIn_, IERC20(outer_), 0, attacker, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertTrue(outerOut_ > 0, "outer minted");

        // Outer partial burn
        uint256 burnAmt_ = outerOut_ / 2;
        if (burnAmt_ == 0) burnAmt_ = outerOut_;
        vm.startPrank(attacker);
        IERC20(outer_).approve(outer_, burnAmt_);
        IStandardExchangeIn(outer_)
            .exchangeIn(IERC20(outer_), burnAmt_, IERC20(nested_), 0, attacker, false, block.timestamp + 1 hours);
        vm.stopPrank();

        // Third user still mints on inner
        uint256 seShares_ = _fundSeSharesLeg(0, victim, 15e18);
        vm.startPrank(victim);
        seShares[0].approve(nested_, seShares_);
        uint256 direct_ = IStandardExchangeIn(nested_)
            .exchangeIn(seShares[0], seShares_, IERC20(nested_), 0, victim, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertTrue(direct_ > 0, "G1: nested still mints for third user");
        assertTrue(ISingleStandardExchangeDETFInfo(nested_).isReserveLive(), "nested still live");

        _assertNoFreeInventoryStrict(outer_);
    }

    function _goLiveOuterWithNested(address outer_, address nested_, address user, uint256 nestedLp, uint256 seLp)
        internal
    {
        uint256 nestedShares_ = _fundNestedDetfShares(nested_, user, nestedLp);
        uint256 seSharesAmt_ = _fundSeSharesLeg(1, user, seLp);
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = nestedShares_;
        amounts_[1] = seSharesAmt_;

        vm.startPrank(user);
        IERC20(nested_).approve(outer_, nestedShares_);
        seShares[1].approve(outer_, seSharesAmt_);
        IMultiVaultWeightedDetfBonding(outer_)
            .initializeReserve(amounts_, DEFAULT_MIN_LOCK, user, block.timestamp + 1 hours);
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
