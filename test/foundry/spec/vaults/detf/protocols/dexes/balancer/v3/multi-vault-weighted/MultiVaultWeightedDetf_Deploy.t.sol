// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {TestBase_MultiVaultWeightedDetf} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";
import {IMultiVaultWeightedDetfDFPkg} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfDFPkg.sol";
import {IMultiVaultWeightedDetfInfo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfInfoTarget.sol";
import {DETFThresholdPolicy} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

contract MultiVaultWeightedDetf_Deploy_Test is TestBase_MultiVaultWeightedDetf {
    function test_deploy_inert_n1() public view {
        _assertInert(detf);
        assertEq(detfInfo.vaultCount(), 1, "vault count");
        assertTrue(detfInfo.reservePool() != address(0), "reserve pool");
        assertEq(detfInfo.underlyingVaults()[0], address(seVaults[0]), "vault0");
        (uint256 weight_, uint256[] memory weights_) = detfInfo.weights();
        assertGt(weight_, 0, "detf weight");
        assertGt(weights_[0], 0, "vault weight");
        assertEq(weight_ + weights_[0], 1e18, "weights sum");
        assertEq(detfInfo.mintThreshold(), DETFThresholdPolicy.DEFAULT_MINT_THRESHOLD);
        assertEq(detfInfo.burnThreshold(), DETFThresholdPolicy.DEFAULT_BURN_THRESHOLD);
        assertFalse(detfInfo.isMintingAllowed());
        assertFalse(detfInfo.isBurningAllowed());
        assertEq(IERC20Metadata(detf).decimals(), 9);
        assertEq(IERC20Metadata(detfInfo.rebasingClaimToken()).decimals(), 9);
        assertEq(IERC20Metadata(detfInfo.rawSY()).decimals(), 9);
        assertEq(IERC20Metadata(detfInfo.stakingSY()).decimals(), 9);
    }

    function test_deploy_n2_disparate_rateAssets() public {
        address instance_ = _deployDetfN(2, 0, 0, true);
        IMultiVaultWeightedDetfInfo info_ = IMultiVaultWeightedDetfInfo(instance_);
        _assertInert(instance_);
        assertEq(info_.vaultCount(), 2);
        address[] memory assets_ = info_.rateAssets();
        assertEq(assets_[0], address(rateAssets[0]));
        assertEq(assets_[1], address(rateAssets[1]));
        assertTrue(assets_[0] != assets_[1], "actual disparate rate assets");
    }

    function test_deploy_reverts_invalid_weights() public {
        IMultiVaultWeightedDetfDFPkg.PkgArgs memory args_ = _buildPkgArgs(1, 0, 0, true);
        args_.weightDetf = 0.8e18;
        args_.vaultWeights[0] = 0.1e18;
        vm.expectRevert();
        _deployWithArgs(args_);
    }

    function test_deploy_reverts_duplicate_vault() public {
        IMultiVaultWeightedDetfDFPkg.PkgArgs memory args_ = _buildPkgArgs(2, 0, 0, true);
        args_.vaults[1] = args_.vaults[0];
        args_.vaultShares[1] = args_.vaultShares[0];
        args_.rateAssets[1] = args_.rateAssets[0];
        vm.expectRevert();
        _deployWithArgs(args_);
    }
}
