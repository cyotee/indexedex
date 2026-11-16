// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";

import {TestBase_TokenStaking} from "contracts/protocols/staking/token/TestBase_TokenStaking.sol";
import {IVaultRegistryVaultPackageQuery} from "contracts/interfaces/IVaultRegistryVaultPackageQuery.sol";
import {IRebasingAwareERC4626DFPkg} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626DFPkg.sol";

contract RebasingAwareERC4626_TokenStaking is TestBase_TokenStaking {
    function test_claimVaultPkgIsRegistered() public view {
        assertTrue(
            IVaultRegistryVaultPackageQuery(address(indexedexManager)).isPackage(address(claimVaultPkg))
        );
        assertEq(
            IRebasingAwareERC4626DFPkg(address(claimVaultPkg)).releaseIdentifier(),
            "indexedex.rebasing-aware-erc4626.sy-se.v1"
        );
    }

    function test_onDemandClaimVaultDepositWithdraw() public {
        IERC4626 claimVault = claimVaultPkg.deployVault(IERC20Metadata(address(stakeToken)));
        vm.startPrank(stakerA);
        stakeToken.approve(address(claimVault), 50e18);
        uint256 shares = claimVault.deposit(50e18, stakerA);
        uint256 assets = claimVault.redeem(shares, stakerA, stakerA);
        vm.stopPrank();
        assertGt(shares, 0);
        assertGt(assets, 0);
    }
}
