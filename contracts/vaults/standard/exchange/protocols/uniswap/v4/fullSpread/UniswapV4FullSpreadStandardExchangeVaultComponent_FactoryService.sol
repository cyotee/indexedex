// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {IUniswapV4FullSpreadStandardExchangeVaultDFPkg as IPackage} from "./interfaces/IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol";
import {IUniswapV4FullSpreadStandardExchangeVaultComponentBindings as IBindings} from "./UniswapV4FullSpreadStandardExchangeVaultComponentBindings.sol";

library UniswapV4FullSpreadStandardExchangeVaultComponent_FactoryService {
    using BetterEfficientHashLib for bytes;
    Vm private constant VM = Vm(VM_ADDRESS);
    error RuntimeArtifactMismatch(address component);
    error PackageBindingMismatch(address package);
    struct Reference { uint256 length; uint256 start; }

    function deployMoneyFacet(ICreate3FactoryProxy factory_) internal returns (IFacet) {
        return _deployFamily(factory_, "UniswapV4FullSpreadStandardExchangeVaultMoneyFacet");
    }

    function deployQuoteFacet(ICreate3FactoryProxy factory_) internal returns (IFacet) {
        return _deployFamily(factory_, "UniswapV4FullSpreadStandardExchangeVaultQuoteFacet");
    }

    function deployOutFacet(ICreate3FactoryProxy factory_) internal returns (IFacet) {
        return _deployFamily(factory_, "UniswapV4FullSpreadStandardExchangeVaultOutFacet");
    }

    function deployQueryFacet(ICreate3FactoryProxy factory_) internal returns (IFacet) {
        return _deployFamily(factory_, "UniswapV4FullSpreadStandardExchangeVaultQueryFacet");
    }

    function deployCallbackFacet(ICreate3FactoryProxy factory_) internal returns (IFacet) {
        return _deployFamily(factory_, "UniswapV4FullSpreadStandardExchangeVaultCallbackFacet");
    }

    function deployProtocolAwareFacet(ICreate3FactoryProxy factory_) internal returns (IFacet) {
        return _deployPlain(factory_, "UniswapV4ProtocolAwareFacet");
    }

    function deploySinglePositionAwareFacet(ICreate3FactoryProxy factory_) internal returns (IFacet) {
        return _deployPlain(factory_, "UniswapV4SinglePositionAwareFacet");
    }

    function deployUniswapV4FullSpreadStandardExchangeVaultDFPkg(IVaultRegistryDeployment registry_, IPackage.PkgInit memory init_)
        internal
        returns (IPackage instance_)
    {
        if (address(registry_) != address(init_.registry)) revert IPackage.InvalidComponent();
        bytes memory code_ = ArtifactCreationCode.creationCode(
            "UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol:UniswapV4FullSpreadStandardExchangeVaultDFPkg"
        );
        instance_ = IPackage(registry_.deployPkg(code_, abi.encode(init_), abi.encode("UniswapV4FullSpreadStandardExchangeVaultDFPkg")._hash()));
        if (instance_.bindingHash() != keccak256(abi.encode(init_))) revert PackageBindingMismatch(address(instance_));
        VM.label(address(instance_), "UniswapV4FullSpreadStandardExchangeVaultDFPkg");
    }

    function _deployFamily(ICreate3FactoryProxy factory_, string memory name_) private returns (IFacet instance_) {
        bytes memory creation_ = ArtifactCreationCode.creationCode(factory_, string.concat(name_, ".sol:", name_));
        instance_ = factory_.deployFacet(creation_, abi.encode(name_)._hash());
        _verifyLibraries(factory_, IBindings(address(instance_)).linkedComponents());
        VM.label(address(instance_), name_);
    }

    function _deployPlain(ICreate3FactoryProxy factory_, string memory name_) private returns (IFacet instance_) {
        bytes memory creation_ = ArtifactCreationCode.creationCode(factory_, string.concat(name_, ".sol:", name_));
        instance_ = factory_.deployFacet(creation_, abi.encode(name_)._hash());
        VM.label(address(instance_), name_);
    }

    function _verifyLibraries(ICreate3FactoryProxy factory_, address[6] memory bindings_) private {
        string[6] memory names_ = [
            "UniswapV4FullSpreadStandardExchangeVaultMath",
            "UniswapV4FullSpreadStandardExchangeVaultProjection",
            "UniswapV4FullSpreadStandardExchangeVaultSwapProjection",
            "UniswapV4FullSpreadStandardExchangeVaultPlanner",
            "UniswapV4FullSpreadStandardExchangeVaultExecution",
            "UniswapV4FullSpreadStandardExchangeVaultExecutionPreparation"
        ];
        for (uint256 i_; i_ < bindings_.length; ++i_) {
            string memory id_ = string.concat(
                "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/",
                names_[i_],
                ".sol:",
                names_[i_]
            );
            bytes memory creation_ = ArtifactCreationCode.creationCode(factory_, id_);
            if (creation_.length == 0 || bindings_[i_].code.length == 0) revert RuntimeArtifactMismatch(bindings_[i_]);
        }
    }
}
