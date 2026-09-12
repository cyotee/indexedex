// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IMixedBufferMultiVaultStableDetfDFPkg} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfDFPkg.sol";
import {IMixedBufferMultiVaultStableDetfInfo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfInfoTarget.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";
import {DetfReentryTarget} from "contracts/test/adversarial/DetfReentryTarget.sol";
import {TestBase_MixedBufferMultiVaultStableDetf_Adversarial} from "./adversarial/TestBase_MixedBufferMultiVaultStableDetf_Adversarial.sol";

/// @notice Real Mixed Buffer, Aerodrome SE and pool; only the underlying ERC20 is hostile.
contract MixedBufferMultiVaultStableDetf_Reentrancy_Test is TestBase_MixedBufferMultiVaultStableDetf_Adversarial {
    address internal outerDetf;
    function setUp() public virtual override {
        super.setUp(); outerDetf = _deployHostileBufferDetf();
        _bootstrapHostile(outerDetf, alice, _fixtureAmount(1_000e18), 1_000e18);
    }
    function test_control_path_mint_succeeds() public virtual {
        _executeHostileMint(outerDetf, bob, _fixtureAmount(50e18));
        assertEq(hostileBuffer.reentryAttempts(), 0);
    }
    function test_reentrancy_mintBufferPath_nestedHitsIsLocked() public virtual {
        _executeHostileMint(outerDetf, bob, _fixtureAmount(50e18));
        hostileBuffer.armForRecipient(outerDetf, address(reentryTarget), abi.encodeCall(
            DetfReentryTarget.reenterExchangeIn, (outerDetf, IERC20(address(hostileBuffer)), _fixtureAmount(1e18), IERC20(outerDetf), bob)));
        _executeHostileMint(outerDetf, bob, _fixtureAmount(50e18)); _assertNestedLock();
    }
    function test_reentrancy_crossFunction_bond_nestedHitsIsLocked() public virtual {
        hostileBuffer.armForRecipient(outerDetf, address(reentryTarget), abi.encodeCall(
            DetfReentryTarget.reenterBondGeneric, (outerDetf, IERC20(address(hostileBuffer)), _fixtureAmount(1e18), DEFAULT_MIN_LOCK, bob)));
        _executeHostileMint(outerDetf, bob, _fixtureAmount(50e18)); _assertNestedLock();
    }
    function test_primaryMint_controlFundsRewardsAndLiquidity() public virtual { _primaryCase(0); }
    function test_primaryMint_nestedExchangeHitsIsLocked() public virtual { _primaryCase(1); }
    function test_primaryMint_nestedBondHitsIsLocked() public virtual { _primaryCase(2); }

    function _primaryCase(uint256 callback_) private {
        IMixedBufferMultiVaultStableDetfDFPkg.PkgArgs memory args_ = _buildPkgArgs(1, 2, 1);
        args_.bufferToken = IERC20(address(hostileBuffer));
        args_.standardExchangeVaults[0] = IStandardExchange(address(hostileVault));
        address instance_ = _deployWithArgs(args_);
        _bootstrapHostile(instance_, alice, _fixtureAmount(1_000e18), 1_000e18);
        IMixedBufferMultiVaultStableDetfInfo info_ = IMixedBufferMultiVaultStableDetfInfo(instance_);
        assertTrue(info_.isMintingAllowed(), "exercise primary issuance after actual gate check");
        uint256 supply_ = IERC20(instance_).totalSupply();
        uint256 lp_ = IERC20(info_.reservePool()).balanceOf(info_.bondNftVault());
        IStakedDETF staking_ = IStakedDETF(info_.rebasingClaimToken());
        uint256 backing_ = staking_.stakingState().accountedBacking;
        if (callback_ != 0) {
            bytes memory nested_ = callback_ == 1
                ? abi.encodeCall(DetfReentryTarget.reenterExchangeIn, (instance_, IERC20(address(hostileBuffer)), _fixtureAmount(1e18), IERC20(instance_), bob))
                : abi.encodeCall(DetfReentryTarget.reenterBondGeneric, (instance_, IERC20(address(hostileBuffer)), _fixtureAmount(1e18), DEFAULT_MIN_LOCK, bob));
            hostileBuffer.armForRecipient(instance_, address(reentryTarget), nested_);
        }
        _executeHostileMint(instance_, bob, _fixtureAmount(50e18));
        if (callback_ != 0) _assertNestedLock(); else assertEq(hostileBuffer.reentryAttempts(), 0);
        assertGt(IERC20(instance_).totalSupply(), supply_);
        assertGt(IERC20(info_.reservePool()).balanceOf(info_.bondNftVault()), lp_);
        assertGt(staking_.stakingState().accountedBacking, backing_);
    }

    function _assertNestedLock() private view {
        assertEq(hostileBuffer.reentryAttempts(), 1);
        assertFalse(hostileBuffer.nestedCallSucceeded());
        assertEq(hostileBuffer.nestedErrorSelector(), IReentrancyLock.IsLocked.selector);
    }
}
