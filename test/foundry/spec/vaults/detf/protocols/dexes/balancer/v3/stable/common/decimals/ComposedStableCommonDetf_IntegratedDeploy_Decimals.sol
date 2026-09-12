// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    IComposedStableCommonDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/IComposedStableCommonDetfInfo.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IDETF} from "contracts/interfaces/IDETF.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {
    TestBase_ComposedStableCommonDetf_Decimals
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/TestBase_ComposedStableCommonDetf_Decimals.sol";

/// @dev Gold IntegratedDeploy is standalone on the Balancer router TestBase. Decimals clone
///      inherits the family decimals TestBase (token construction + `_pairDecimals`) and keeps
///      the one IntegratedDeploy case that TestBase does not declare.
abstract contract ComposedStableCommonDetf_IntegratedDeploy_Decimals is TestBase_ComposedStableCommonDetf_Decimals {
    function test_deployVault_surfacesRealCompanionReferences() public view {
        assertTrue(IVaultRegistryVaultQuery(address(indexedexManager)).isVault(deployedDetfVault), "vault registered");
        assertEq(IDETF(deployedDetfVault).bondNftVault(), address(bondNFTVault), "bond vault wired");
        assertEq(IDetfBondNFT(address(bondNFTVault)).detf(), deployedDetfVault, "funded bond parent");
        assertEq(
            IComposedStableCommonDetfInfo(deployedDetfVault).rebasingClaimToken(),
            address(rebasingDetfToken),
            "rebasing token wired"
        );
        assertEq(IDETF(deployedDetfVault).reservePool(), address(reservePool), "reserve pool wired");
    }
}
