// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IUniswapV4DetfMigration as Migration} from "../interfaces/IUniswapV4DetfMigration.sol";

/// @notice Raw actual deployed bytes, including populated immutables and linked library addresses.
/// @dev Evidence only: no artifact mask, reconstructed deployment, storage write or replacement code.
library MigrationStatefulBindings {
    function capture(Migration m_, address package_, address registry_) internal view {
        console2.log("STATEFUL_SUBJECT");
        console2.logBytes(abi.encode(address(m_), m_.hook(), m_.bondNftVault(), m_.rebasingClaimToken(),
            m_.rawSY(), m_.stakingSY(), m_.migrationSyRewardToken(), package_, registry_, m_.migrationSnapshot().id));
        address[8] memory roots_ = [address(m_), m_.hook(), m_.bondNftVault(), m_.rebasingClaimToken(),
            m_.rawSY(), m_.stakingSY(), m_.migrationSyRewardToken(), registry_];
        for (uint256 i_; i_ < roots_.length; ++i_) {
            _runtime(roots_[i_]);
            address[] memory facets_ = IDiamondLoupe(roots_[i_]).facetAddresses();
            for (uint256 j_; j_ < facets_.length; ++j_) _runtime(facets_[j_]);
        }
        _runtime(package_);
    }

    function _runtime(address subject_) private view {
        console2.log("STATEFUL_RUNTIME");
        console2.logBytes(abi.encode(subject_, subject_.code));
    }
}
