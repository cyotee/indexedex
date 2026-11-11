// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ReentrancyLockRepo} from "@crane/contracts/access/reentrancy/ReentrancyLockRepo.sol";
import {UniswapV4DetfCommon} from "../detf/UniswapV4DetfCommon.sol";
import {UniswapV4DetfTarget} from "../detf/UniswapV4DetfTarget.sol";
import {UniswapV4DetfRepo as ParentRepo} from "../detf/UniswapV4DetfRepo.sol";
import {UniswapV4DetfMigrationPolicy} from "./UniswapV4DetfMigrationPolicy.sol";
import {UniswapV4DetfMigrationRepo as Repo} from "./UniswapV4DetfMigrationRepo.sol";
import {IUniswapV4DetfMigrationAccounting as Accounting} from "./interfaces/IUniswapV4DetfMigration.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IDETFStakingPreview, IDETFStandardizedYield} from "contracts/interfaces/IDETFStandardizedYield.sol";
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {
    IUniswapV4DetfSelfCall
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4DetfSelfCall.sol";




import {UniswapV4DetfFacet} from "../detf/UniswapV4DetfFacet.sol";
import {UniswapV4DetfQueryTarget} from "../detf/UniswapV4DetfQueryTarget.sol";

/// @notice Migration policy composed with the actual ordinary query implementation.
contract UniswapV4DetfMigrationQueryFacet is UniswapV4DetfFacet, UniswapV4DetfQueryTarget, UniswapV4DetfMigrationPolicy {
    function facetName() public pure override returns (string memory) { return "UniswapV4DetfMigrationQueryFacet"; }

    function _pendingExpansionDetf() internal view override(UniswapV4DetfCommon, UniswapV4DetfMigrationPolicy) returns (uint256) { return UniswapV4DetfMigrationPolicy._pendingExpansionDetf(); }
    function _realizeExpansionIfNeeded() internal override(UniswapV4DetfCommon, UniswapV4DetfMigrationPolicy) returns (uint256) { return UniswapV4DetfMigrationPolicy._realizeExpansionIfNeeded(); }
    function _isMintingAllowedToken(IERC20 token_) internal view override(UniswapV4DetfCommon, UniswapV4DetfMigrationPolicy) returns (bool) { return UniswapV4DetfMigrationPolicy._isMintingAllowedToken(token_); }
    function _residualBalance(address token_) internal view override(UniswapV4DetfCommon, UniswapV4DetfMigrationPolicy) returns (uint256) { return UniswapV4DetfMigrationPolicy._residualBalance(token_); }
    function _sweepDustBody() internal override(UniswapV4DetfCommon, UniswapV4DetfMigrationPolicy) { UniswapV4DetfMigrationPolicy._sweepDustBody(); }

    function _entryPreviewMint(IERC20 token_, uint256 amount_) internal view override returns (uint256, uint256) {
        if (!Repo._layoutStruct().activated) return (0, 0);
        return super._entryPreviewMint(token_, amount_);
    }
    function facetFuncs() public pure override returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](35);
        funcs_[0] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs_[1] = IUniswapV4Detf.hook.selector;
        funcs_[2] = IUniswapV4Detf.reservePool.selector;
        funcs_[3] = IUniswapV4Detf.isReserveLive.selector;
        funcs_[4] = IUniswapV4Detf.isReserveWired.selector;
        funcs_[5] = IUniswapV4Detf.mintRoutes.selector;
        funcs_[6] = IUniswapV4Detf.burnRoutes.selector;
        funcs_[7] = IUniswapV4Detf.bondRoutes.selector;
        funcs_[8] = IUniswapV4Detf.donateRoutes.selector;
        funcs_[9] = IUniswapV4Detf.mintRouteMode.selector;
        funcs_[10] = IUniswapV4Detf.burnRouteMode.selector;
        funcs_[11] = IUniswapV4Detf.bondRouteMode.selector;
        funcs_[12] = IUniswapV4Detf.donateRouteMode.selector;
        funcs_[13] = IUniswapV4Detf.creationPairPerDetfWad.selector;
        funcs_[14] = IUniswapV4Detf.openingPairPerDetfWad.selector;
        funcs_[15] = IUniswapV4Detf.mintThreshold.selector;
        funcs_[16] = IUniswapV4Detf.burnThreshold.selector;
        funcs_[17] = IUniswapV4Detf.syntheticPrice.selector;
        funcs_[18] = IUniswapV4Detf.pendingExpansionDetf.selector;
        funcs_[19] = IUniswapV4Detf.bondNftVault.selector;
        funcs_[20] = IUniswapV4Detf.detfNFTVault.selector;
        funcs_[21] = IUniswapV4Detf.rebasingClaimToken.selector;
        funcs_[22] = IUniswapV4Detf.acceptedBondTokens.selector;
        funcs_[23] = bytes4(keccak256("isMintingAllowed()"));
        funcs_[24] = bytes4(keccak256("isMintingAllowed(address)"));
        funcs_[25] = bytes4(keccak256("isBurningAllowed()"));
        funcs_[26] = bytes4(keccak256("isBurningAllowed(address)"));
        funcs_[27] = IUniswapV4Detf.previewJoinDonatedCapital.selector;
        funcs_[28] = IUniswapV4DetfSelfCall.peekPairEq.selector;
        funcs_[29] = IDETFStakingPreview.previewStakingGonsPerUnit.selector;
        funcs_[30] = IDETFStandardizedYield.rawSY.selector;
        funcs_[31] = IDETFStandardizedYield.stakingSY.selector;
        funcs_[32] = IUniswapV4Detf.previewFirstBondPayments.selector;
        funcs_[33] = IUniswapV4Detf.ownerOnlyLiquidity.selector;
        funcs_[34] = IUniswapV4Detf.previewBond.selector;
    }
}
