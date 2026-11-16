// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IUniswapV4DetfMigrationAccounting} from "../../interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationRewardToken} from "./IUniswapV4DetfMigrationRewardToken.sol";
import {UniswapV4DetfMigrationRewardTokenTarget} from "./UniswapV4DetfMigrationRewardTokenTarget.sol";

/// @notice All native ERC20, metadata and fixed-receipt RT selectors, without an initializer or updater.
contract UniswapV4DetfMigrationRewardTokenFacet is UniswapV4DetfMigrationRewardTokenTarget, IFacet {
    /// @inheritdoc IFacet
    function facetName() public pure returns (string memory) {
        return type(UniswapV4DetfMigrationRewardTokenFacet).name;
    }

    /// @inheritdoc IFacet
    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](4);
        interfaces_[0] = type(IERC20).interfaceId;
        interfaces_[1] = type(IERC20Metadata).interfaceId;
        interfaces_[2] = type(IUniswapV4DetfMigrationRewardToken).interfaceId;
        interfaces_[3] = type(IUniswapV4DetfMigrationAccounting).interfaceId;
    }

    /// @inheritdoc IFacet
    function facetFuncs() public pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](16);
        funcs_[0] = IERC20.totalSupply.selector;
        funcs_[1] = IERC20.balanceOf.selector;
        funcs_[2] = IERC20.transfer.selector;
        funcs_[3] = IERC20.allowance.selector;
        funcs_[4] = IERC20.approve.selector;
        funcs_[5] = IERC20.transferFrom.selector;
        funcs_[6] = IERC20Metadata.name.selector;
        funcs_[7] = IERC20Metadata.symbol.selector;
        funcs_[8] = IERC20Metadata.decimals.selector;
        funcs_[9] = IUniswapV4DetfMigrationAccounting.migrationAccountingPhase.selector;
        funcs_[10] = IUniswapV4DetfMigrationRewardToken.mintByReceipt.selector;
        funcs_[11] = IUniswapV4DetfMigrationRewardToken.burnByReceipt.selector;
        funcs_[12] = IUniswapV4DetfMigrationRewardToken.redeem.selector;
        funcs_[13] = IUniswapV4DetfMigrationRewardToken.previewRedeem.selector;
        funcs_[14] = IUniswapV4DetfMigrationRewardToken.receipt.selector;
        funcs_[15] = IUniswapV4DetfMigrationRewardToken.parent.selector;
    }

    /// @inheritdoc IFacet
    function facetMetadata()
        external pure returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory functions_)
    {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}
