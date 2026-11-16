// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IRebasingAwareERC4626DFPkg} from "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626DFPkg.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {IVaultRegistryVaultPackageQuery} from "contracts/interfaces/IVaultRegistryVaultPackageQuery.sol";

/// @notice A distinct DTF custody instance of the registered, fee-free SY/SE wrapper.
library Phase_07_Stage_02_FeeAccrualCustodySe {
    function execute(
        address manager,
        IDiamondPackageCallBackFactory factory,
        IRebasingAwareERC4626DFPkg pkg,
        IERC20Metadata asset,
        uint8 decimalOffset,
        bytes32 salt
    ) internal returns (address vault) {
        require(IVaultRegistryVaultPackageQuery(manager).isPackage(address(pkg)), "Custody: package not registered");
        require(keccak256(bytes(pkg.releaseIdentifier())) == keccak256("indexedex.rebasing-aware-erc4626.sy-se.v1"), "Custody: wrong wrapper release");
        require(pkg.vaultFeeTypeIds() == bytes32(0), "Custody: fees forbidden");
        IRebasingAwareERC4626DFPkg.PkgArgs memory args = IRebasingAwareERC4626DFPkg.PkgArgs({
            asset: asset,
            name: string.concat("Wrapped ", asset.name()),
            symbol: string.concat("w", asset.symbol()),
            decimalOffset: decimalOffset,
            optionalSalt: salt
        });
        vault = factory.calcAddress(IDiamondFactoryPackage(address(pkg)), abi.encode(args));
        if (vault.code.length == 0) {
            require(address(pkg.deployVault(asset, decimalOffset, salt)) == vault, "Custody: prediction mismatch");
        }
        require(IVaultRegistryVaultQuery(manager).isVault(vault), "Custody: vault not registered");
        require(IERC4626(vault).asset() == address(asset), "Custody: wrong asset");
        require(uint256(IERC20Metadata(vault).decimals()) == uint256(asset.decimals()) + decimalOffset, "Custody: wrong decimals");
    }
}
