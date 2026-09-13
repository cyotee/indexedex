// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                   Foundry                                  */
/* -------------------------------------------------------------------------- */

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";

/**
 * @title ArtifactCreationCode
 * @notice Foundry-only artifact loading without Solidity implementation imports.
 * @dev Build artifacts before calling. Read JSON directly so focused builds need not
 *      import implementations merely to populate Foundry's checked artifact lookup.
 *      Artifact IDs use `File.sol:ContractName`; full source paths are also accepted.
 */
library ArtifactCreationCode {
    Vm internal constant VM = Vm(VM_ADDRESS);

    // parseJson encodes object members alphabetically: length precedes start.
    struct LinkReference {
        uint256 length;
        uint256 start;
    }

    function creationCode(string memory artifactId_) internal returns (bytes memory) {
        return _creationCode(ICreate3FactoryProxy(address(0)), artifactId_, 0);
    }

    /// @notice Load bytecode and deploy/link external libraries through the same CREATE3 factory.
    /// @dev Library salts include the fully linked initcode hash, so a changed library
    ///      cannot silently reuse an older deployment. Requires normal factory authorization.
    function creationCode(ICreate3FactoryProxy factory_, string memory artifactId_) internal returns (bytes memory) {
        return _creationCode(factory_, artifactId_, 0);
    }

    /// @notice Bind a type-name namespace to the implementation and constructor.
    /// @dev CREATE3 itself reuses occupied salts without checking their code.
    ///      Product component deployments use this salt; instance salts do not.
    function releaseSalt(bytes32 namespace_, bytes memory initCode_, bytes memory initArgs_)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(namespace_, keccak256(initCode_), keccak256(initArgs_)));
    }

    function _creationCode(ICreate3FactoryProxy factory_, string memory artifactId_, uint256 depth_)
        private
        returns (bytes memory code_)
    {
        require(depth_ < 32, "ArtifactCreationCode: cyclic or excessive library dependencies");
        string memory json_ = _artifactJson(artifactId_);
        bytes memory hexCode_ = bytes(VM.parseJsonString(json_, ".bytecode.object"));
        require(hexCode_.length > 2, string.concat("ArtifactCreationCode: empty bytecode ", artifactId_));
        string[] memory sources_ = VM.parseJsonKeys(json_, ".bytecode.linkReferences");
        if (sources_.length != 0) {
            require(
                address(factory_) != address(0),
                string.concat("ArtifactCreationCode: linking requires factory ", artifactId_)
            );
            for (uint256 i_; i_ < sources_.length; ++i_) {
                _linkSource(factory_, json_, hexCode_, sources_[i_], depth_);
            }
        }
        // parseBytes rejects malformed hex and any unresolved solc placeholders.
        code_ = VM.parseBytes(string(hexCode_));
        require(code_.length != 0, string.concat("ArtifactCreationCode: empty bytecode ", artifactId_));
    }

    function _linkSource(
        ICreate3FactoryProxy factory_,
        string memory json_,
        bytes memory hexCode_,
        string memory source_,
        uint256 depth_
    ) private {
        string memory sourceKey_ = string.concat('.bytecode.linkReferences["', source_, '"]');
        string[] memory names_ = VM.parseJsonKeys(json_, sourceKey_);
        for (uint256 i_; i_ < names_.length; ++i_) {
            string memory id_ = string.concat(source_, ":", names_[i_]);
            bytes memory initCode_ = _creationCode(factory_, id_, depth_ + 1);
            bytes32 salt_ = keccak256(abi.encode("IndexedEx.ArtifactLibrary", id_, keccak256(initCode_)));
            address library_ = factory_.create3(initCode_, salt_);
            require(library_.code.length != 0, "ArtifactCreationCode: library deployment failed");
            VM.label(library_, names_[i_]);
            LinkReference[] memory refs_ =
                abi.decode(VM.parseJson(json_, string.concat(sourceKey_, '["', names_[i_], '"]')), (LinkReference[]));
            _patchReferences(hexCode_, refs_, library_);
        }
    }

    function _patchReferences(bytes memory hexCode_, LinkReference[] memory refs_, address library_) private pure {
        bytes16 digits_ = "0123456789abcdef";
        uint256 prefix_ = hexCode_.length >= 2 && hexCode_[0] == "0" && hexCode_[1] == "x" ? 2 : 0;
        for (uint256 i_; i_ < refs_.length; ++i_) {
            require(refs_[i_].length == 20, "ArtifactCreationCode: invalid link length");
            uint256 offset_ = prefix_ + refs_[i_].start * 2;
            require(offset_ + 40 <= hexCode_.length, "ArtifactCreationCode: invalid link offset");
            for (uint256 j_; j_ < 40; ++j_) {
                hexCode_[offset_ + j_] = digits_[(uint160(library_) >> ((39 - j_) * 4)) & 0xf];
            }
        }
    }

    function _artifactJson(string memory artifactId_) private view returns (string memory) {
        bytes memory id_ = bytes(artifactId_);
        uint256 separator_;
        bool fullSource_;
        for (uint256 i_; i_ < id_.length; ++i_) {
            if (id_[i_] == ":") {
                separator_ = i_;
                break;
            }
            if (id_[i_] == "/") fullSource_ = true;
        }
        require(separator_ != 0 && separator_ + 1 < id_.length, "ArtifactCreationCode: expected File.sol:Contract");
        bytes memory name_ = new bytes(id_.length - separator_ - 1);
        for (uint256 i_; i_ < name_.length; ++i_) {
            name_[i_] = id_[separator_ + 1 + i_];
        }
        // Foundry disambiguates duplicate filenames with source-directory suffixes.
        // Try the most specific suffix first when a full source ID is supplied.
        for (uint256 start_; start_ < separator_; ++start_) {
            if (start_ != 0 && id_[start_ - 1] != "/") continue;
            bytes memory file_ = new bytes(separator_ - start_);
            for (uint256 i_; i_ < file_.length; ++i_) {
                file_[i_] = id_[start_ + i_];
            }
            string memory path_ = string.concat(VM.projectRoot(), "/out/", string(file_), "/", string(name_), ".json");
            if (VM.exists(path_)) {
                string memory json_ = VM.readFile(path_);
                if (!fullSource_ || _matchesSource(json_, id_, separator_)) return json_;
            }
        }
        revert(string.concat("ArtifactCreationCode: missing artifact ", artifactId_));
    }

    function _matchesSource(string memory json_, bytes memory id_, uint256 separator_) private pure returns (bool) {
        bytes memory source_ = new bytes(separator_);
        for (uint256 i_; i_ < separator_; ++i_) {
            source_[i_] = id_[i_];
        }
        string[] memory targets_ = VM.parseJsonKeys(json_, ".metadata.settings.compilationTarget");
        return targets_.length == 1 && keccak256(bytes(targets_[0])) == keccak256(source_);
    }
}
