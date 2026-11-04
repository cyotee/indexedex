// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {IUniswapV4PairTokenStandardExchangeVaultDFPkg as IPackage} from "./interfaces/IUniswapV4PairTokenStandardExchangeVaultDFPkg.sol";
import {IUniswapV4PairTokenStandardExchangeVaultComponentBindings as IBindings} from "./UniswapV4PairTokenStandardExchangeVaultComponentBindings.sol";

// tag::UniswapV4PairTokenStandardExchangeVaultComponent_FactoryService[]
/// @notice Fresh artifact deployment with exact occupied-identity checks, including linked runtimes.
/// @dev Foundry tooling only. Component/library salts remain names, not bytecode hashes.
library UniswapV4PairTokenStandardExchangeVaultComponent_FactoryService {
    using BetterEfficientHashLib for bytes;
    Vm private constant VM = Vm(VM_ADDRESS);
    // tag::RuntimeArtifactMismatch-f130eea1[]
    /// @custom:signature RuntimeArtifactMismatch(address)
    /// @custom:selector 0xf130eea1
    error RuntimeArtifactMismatch(address component);
    // end::RuntimeArtifactMismatch-f130eea1[]
    // tag::PackageBindingMismatch-ec284267[]
    /// @custom:signature PackageBindingMismatch(address)
    /// @custom:selector 0xec284267
    error PackageBindingMismatch(address package);
    // end::PackageBindingMismatch-ec284267[]
    struct Reference { uint256 length; uint256 start; }

    function deployMoneyFacet(ICreate3FactoryProxy factory_) internal returns (IFacet) {
        return _deployFacet(factory_,
            ArtifactCreationCode.creationCode(factory_, "UniswapV4PairTokenStandardExchangeVaultMoneyFacet.sol:UniswapV4PairTokenStandardExchangeVaultMoneyFacet"),
            "UniswapV4PairTokenStandardExchangeVaultMoneyFacet");
    }

    function deployQuoteFacet(ICreate3FactoryProxy factory_) internal returns (IFacet) {
        return _deployFacet(factory_,
            ArtifactCreationCode.creationCode(factory_, "UniswapV4PairTokenStandardExchangeVaultQuoteFacet.sol:UniswapV4PairTokenStandardExchangeVaultQuoteFacet"),
            "UniswapV4PairTokenStandardExchangeVaultQuoteFacet");
    }

    function deployOutFacet(ICreate3FactoryProxy factory_) internal returns (IFacet) {
        return _deployFacet(factory_,
            ArtifactCreationCode.creationCode(factory_, "UniswapV4PairTokenStandardExchangeVaultOutFacet.sol:UniswapV4PairTokenStandardExchangeVaultOutFacet"),
            "UniswapV4PairTokenStandardExchangeVaultOutFacet");
    }

    function deployQueryFacet(ICreate3FactoryProxy factory_) internal returns (IFacet) {
        return _deployFacet(factory_,
            ArtifactCreationCode.creationCode(factory_, "UniswapV4PairTokenStandardExchangeVaultQueryFacet.sol:UniswapV4PairTokenStandardExchangeVaultQueryFacet"),
            "UniswapV4PairTokenStandardExchangeVaultQueryFacet");
    }

    function deploySYMoneyFacet(ICreate3FactoryProxy factory_) internal returns (IFacet) {
        return _deployFacet(factory_,
            ArtifactCreationCode.creationCode(factory_, "UniswapV4PairTokenStandardExchangeVaultSYMoneyFacet.sol:UniswapV4PairTokenStandardExchangeVaultSYMoneyFacet"),
            "UniswapV4PairTokenStandardExchangeVaultSYMoneyFacet");
    }

    function deploySYQueryFacet(ICreate3FactoryProxy factory_) internal returns (IFacet) {
        return _deployFacet(factory_,
            ArtifactCreationCode.creationCode(factory_, "UniswapV4PairTokenStandardExchangeVaultSYQueryFacet.sol:UniswapV4PairTokenStandardExchangeVaultSYQueryFacet"),
            "UniswapV4PairTokenStandardExchangeVaultSYQueryFacet");
    }

    function deployCallbackFacet(ICreate3FactoryProxy factory_) internal returns (IFacet) {
        return _deployFacet(factory_,
            ArtifactCreationCode.creationCode(factory_, "UniswapV4PairTokenStandardExchangeVaultCallbackFacet.sol:UniswapV4PairTokenStandardExchangeVaultCallbackFacet"),
            "UniswapV4PairTokenStandardExchangeVaultCallbackFacet");
    }

    function _deployFacet(ICreate3FactoryProxy factory_, bytes memory creation_, string memory name_)
        private returns (IFacet instance_)
    {
        instance_ = factory_.deployFacet(creation_, abi.encode(name_)._hash());
        _verifyRuntime(address(instance_), string.concat(name_, ".sol"), name_, creation_, false);
        _verifyLibraries(factory_, IBindings(address(instance_)).linkedComponents());
        VM.label(address(instance_), name_);
    }

    function deployUniswapV4PairTokenStandardExchangeVaultDFPkg(
        IVaultRegistryDeployment registry_, IPackage.PkgInit memory init_
    ) internal returns (IPackage instance_) {
        if (address(registry_) != address(init_.registry)) revert IPackage.InvalidComponent();
        bytes memory code_ = ArtifactCreationCode.creationCode("UniswapV4PairTokenStandardExchangeVaultDFPkg.sol:UniswapV4PairTokenStandardExchangeVaultDFPkg");
        instance_ = IPackage(registry_.deployPkg(code_, abi.encode(init_), abi.encode("UniswapV4PairTokenStandardExchangeVaultDFPkg")._hash()));
        if (instance_.bindingHash() != keccak256(abi.encode(init_))) revert PackageBindingMismatch(address(instance_));
        _verifyRuntime(address(instance_), "UniswapV4PairTokenStandardExchangeVaultDFPkg.sol", "UniswapV4PairTokenStandardExchangeVaultDFPkg", code_, false);
        VM.label(address(instance_), "UniswapV4PairTokenStandardExchangeVaultDFPkg");
    }

    function _verifyLibraries(ICreate3FactoryProxy factory_, address[6] memory bindings_) private {
        string[6] memory names_ = ["UniswapV4PairTokenStandardExchangeVaultMath", "UniswapV4PairTokenStandardExchangeVaultProjection", "UniswapV4PairTokenStandardExchangeVaultSwapProjection",
            "UniswapV4PairTokenStandardExchangeVaultPlanner", "UniswapV4PairTokenStandardExchangeVaultExecution", "UniswapV4PairTokenStandardExchangeVaultExecutionPreparation"];
        string[6] memory files_ = ["UniswapV4PairTokenStandardExchangeVaultMath.sol", "UniswapV4PairTokenStandardExchangeVaultProjection.sol", "UniswapV4PairTokenStandardExchangeVaultProjection.sol",
            "UniswapV4PairTokenStandardExchangeVaultPlanner.sol", "UniswapV4PairTokenStandardExchangeVaultExecution.sol", "UniswapV4PairTokenStandardExchangeVaultExecution.sol"];
        for (uint256 i_ = 0; i_ < bindings_.length; ++i_) {
            string memory id_ = string.concat("contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/", files_[i_], ":", names_[i_]);
            bytes memory creation_ = ArtifactCreationCode.creationCode(factory_, id_);
            _verifyRuntime(bindings_[i_], files_[i_], names_[i_], creation_, true);
        }
    }

    /// @dev Desired runtime links come from freshly linked creation code, never from occupied code.
    function _verifyRuntime(address component_, string memory file_, string memory name_, bytes memory creation_, bool library_)
        private view
    {
        string memory json_ = VM.readFile(string.concat(VM.projectRoot(), "/out/", file_, "/", name_, ".json"));
        bytes memory expected_ = _runtime(json_, creation_);
        bytes memory actual_ = component_.code;
        if (expected_.length == 0 || expected_.length != actual_.length) revert RuntimeArtifactMismatch(component_);
        if (library_ && (expected_[0] == 0x73 || actual_[0] == 0x73)) {
            // solc's library deployment prologue injects its own address after PUSH20.
            // Solar emits a different prologue; the runtime hash below is the check.
            address self_;
            assembly ("memory-safe") { self_ := shr(96, mload(add(actual_, 33))) }
            if (expected_[0] != 0x73 || actual_[0] != 0x73 || self_ != component_) revert RuntimeArtifactMismatch(component_);
            for (uint256 i_ = 1; i_ <= 20; ++i_) expected_[i_] = actual_[i_];
        }
        string[] memory keys_ = VM.keyExistsJson(json_, ".deployedBytecode.immutableReferences")
            ? VM.parseJsonKeys(json_, ".deployedBytecode.immutableReferences") : new string[](0);
        for (uint256 i_ = 0; i_ < keys_.length; ++i_) {
            Reference[] memory refs_ = abi.decode(VM.parseJson(json_,
                string.concat('.deployedBytecode.immutableReferences["', keys_[i_], '"]')), (Reference[]));
            for (uint256 j_ = 0; j_ < refs_.length; ++j_) {
                uint256 end_ = refs_[j_].start + refs_[j_].length;
                for (uint256 k_ = refs_[j_].start; k_ < end_; ++k_) { expected_[k_] = 0; actual_[k_] = 0; }
            }
        }
        if (keccak256(expected_) != keccak256(actual_)) revert RuntimeArtifactMismatch(component_);
    }

    function _runtime(string memory json_, bytes memory creation_) private pure returns (bytes memory) {
        bytes memory hex_ = bytes(VM.parseJsonString(json_, ".deployedBytecode.object"));
        string[] memory sources_ = VM.parseJsonKeys(json_, ".deployedBytecode.linkReferences");
        for (uint256 i_ = 0; i_ < sources_.length; ++i_) {
            string memory runtimeKey_ = string.concat('.deployedBytecode.linkReferences["', sources_[i_], '"]');
            string[] memory names_ = VM.parseJsonKeys(json_, runtimeKey_);
            for (uint256 j_ = 0; j_ < names_.length; ++j_) {
                string memory suffix_ = string.concat('["', names_[j_], '"]');
                Reference[] memory creationRefs_ = abi.decode(VM.parseJson(json_,
                    string.concat('.bytecode.linkReferences["', sources_[i_], '"]', suffix_)), (Reference[]));
                uint256 offset_ = creationRefs_[0].start;
                address link_;
                assembly ("memory-safe") { link_ := shr(96, mload(add(add(creation_, 32), offset_))) }
                Reference[] memory refs_ = abi.decode(VM.parseJson(json_, string.concat(runtimeKey_, suffix_)), (Reference[]));
                _patchLink(hex_, refs_, link_);
            }
        }
        return VM.parseBytes(string(hex_));
    }

    function _patchLink(bytes memory hex_, Reference[] memory refs_, address link_) private pure {
        bytes16 digits_ = "0123456789abcdef";
        uint256 prefix_ = hex_.length >= 2 && hex_[0] == "0" && hex_[1] == "x" ? 2 : 0;
        for (uint256 i_ = 0; i_ < refs_.length; ++i_) {
            uint256 start_ = prefix_ + refs_[i_].start * 2;
            for (uint256 j_ = 0; j_ < 40; ++j_) hex_[start_ + j_] = digits_[(uint160(link_) >> ((39 - j_) * 4)) & 15];
        }
    }
}
// end::UniswapV4PairTokenStandardExchangeVaultComponent_FactoryService[]

