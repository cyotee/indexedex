// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                   Foundry                                  */
/* -------------------------------------------------------------------------- */

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";

/**
 * @title ArtifactCreationCode
 * @notice Foundry-only helper: load creation bytecode from `out/` via `vm.getCode`.
 * @dev Artifact id is `File.sol:ContractName`. Reverts if bytecode contains `__$` placeholders.
 */
library ArtifactCreationCode {
    Vm internal constant VM = Vm(VM_ADDRESS);

    function creationCode(string memory artifactId_) internal returns (bytes memory) {
        bytes memory bytecode_ = VM.getCode(artifactId_);
        if (_containsUnlinkedPlaceholder(bytecode_)) {
            revert(string.concat("ArtifactCreationCode: unlinked bytecode ", artifactId_));
        }
        return bytecode_;
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

    function _containsUnlinkedPlaceholder(bytes memory bytecode_) private pure returns (bool) {
        uint256 n_ = bytecode_.length;
        if (n_ < 3) {
            return false;
        }
        for (uint256 i_; i_ < n_ - 2; ++i_) {
            if (bytecode_[i_] == 0x5f && bytecode_[i_ + 1] == 0x24 && bytecode_[i_ + 2] == 0x5f) {
                return true;
            }
        }
        return false;
    }
}
