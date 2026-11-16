// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IUniswapV4DetfMigrationAccounting} from "../interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationStakedDETF} from "./IUniswapV4DetfMigrationStakedDETF.sol";
import {UniswapV4DetfMigrationStakedDETFTarget} from "./UniswapV4DetfMigrationStakedDETFTarget.sol";

/// @notice Complete Migration receipt surface; permit/EIP712 remain the generic package's separate facets.
contract UniswapV4DetfMigrationStakedDETFFacet is UniswapV4DetfMigrationStakedDETFTarget, IFacet {
    /// @inheritdoc IFacet
    function facetName() public pure returns (string memory) {
        return type(UniswapV4DetfMigrationStakedDETFFacet).name;
    }

    /// @inheritdoc IFacet
    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](7);
        interfaces_[0] = type(IERC20).interfaceId;
        interfaces_[1] = type(IERC20Metadata).interfaceId;
        interfaces_[2] = type(IStakedDETF).interfaceId;
        interfaces_[3] = type(IStandardExchangeIn).interfaceId;
        interfaces_[4] = type(IStandardExchangeOut).interfaceId;
        interfaces_[5] = type(IUniswapV4DetfMigrationStakedDETF).interfaceId;
        interfaces_[6] = type(IUniswapV4DetfMigrationAccounting).interfaceId;
    }

    /// @inheritdoc IFacet
    function facetFuncs() public pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](34);
        funcs_[0] = IERC20.totalSupply.selector;
        funcs_[1] = IERC20.balanceOf.selector;
        funcs_[2] = IERC20.transfer.selector;
        funcs_[3] = IERC20.allowance.selector;
        funcs_[4] = IERC20.approve.selector;
        funcs_[5] = IERC20.transferFrom.selector;
        funcs_[6] = IERC20Metadata.name.selector;
        funcs_[7] = IERC20Metadata.symbol.selector;
        funcs_[8] = IERC20Metadata.decimals.selector;
        funcs_[9] = IStakedDETF.detf.selector;
        funcs_[10] = IStakedDETF.gonsOf.selector;
        funcs_[11] = IStakedDETF.stakingState.selector;
        funcs_[12] = IStakedDETF.fundRewards.selector;
        funcs_[13] = IStakedDETF.retireEscrowDust.selector;
        funcs_[14] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs_[15] = IStandardExchangeIn.exchangeIn.selector;
        funcs_[16] = IStandardExchangeOut.previewExchangeOut.selector;
        funcs_[17] = IStandardExchangeOut.exchangeOut.selector;
        funcs_[18] = IStakedDETF.previewDistributions.selector;
        funcs_[19] = IUniswapV4DetfMigrationAccounting.migrationAccountingPhase.selector;
        funcs_[20] = IUniswapV4DetfMigrationStakedDETF.egressState.selector;
        funcs_[21] = IUniswapV4DetfMigrationStakedDETF.checkpointRewards.selector;
        funcs_[22] = IUniswapV4DetfMigrationStakedDETF.deferredRewardGons.selector;
        funcs_[23] = IUniswapV4DetfMigrationStakedDETF.tokenizedSyRewardGons.selector;
        funcs_[24] = IUniswapV4DetfMigrationStakedDETF.claimDeferredRewards.selector;
        funcs_[25] = IUniswapV4DetfMigrationStakedDETF.claimDeferredRoleRewards.selector;
        funcs_[26] = IUniswapV4DetfMigrationStakedDETF.transferDeferredRewardRights.selector;
        funcs_[27] = IUniswapV4DetfMigrationStakedDETF.deliverBondClaim.selector;
        funcs_[28] = IUniswapV4DetfMigrationStakedDETF.deferSyRewards.selector;
        funcs_[29] = IUniswapV4DetfMigrationStakedDETF.transferSyPrincipal.selector;
        funcs_[30] = IUniswapV4DetfMigrationStakedDETF.withdrawSyPrincipal.selector;
        funcs_[31] = IUniswapV4DetfMigrationStakedDETF.issueSyRewardTokens.selector;
        funcs_[32] = IUniswapV4DetfMigrationStakedDETF.paySyRewardRemainder.selector;
        funcs_[33] = IUniswapV4DetfMigrationStakedDETF.redeemSyRewardTokens.selector;
    }

    /// @inheritdoc IFacet
    function facetMetadata()
        external pure returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory functions_)
    {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}
