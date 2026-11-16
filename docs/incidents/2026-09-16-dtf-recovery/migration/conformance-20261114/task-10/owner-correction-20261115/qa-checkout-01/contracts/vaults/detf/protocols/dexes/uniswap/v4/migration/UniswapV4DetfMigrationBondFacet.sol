// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ReentrancyLockRepo} from "@crane/contracts/access/reentrancy/ReentrancyLockRepo.sol";
import {MultiStepOwnableRepo} from "@crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol";
import {UniswapV4DetfCommon} from "../detf/UniswapV4DetfCommon.sol";
import {UniswapV4DetfTarget} from "../detf/UniswapV4DetfTarget.sol";
import {UniswapV4DetfRepo as ParentRepo} from "../detf/UniswapV4DetfRepo.sol";
import {UniswapV4DetfMigrationPolicy} from "./UniswapV4DetfMigrationPolicy.sol";
import {UniswapV4DetfMigrationRepo as Repo} from "./UniswapV4DetfMigrationRepo.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAccounting as Accounting}
    from "./interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";




import {UniswapV4DetfFacet} from "../detf/UniswapV4DetfFacet.sol";
import {UniswapV4DetfBondTarget} from "../detf/UniswapV4DetfBondTarget.sol";

/// @notice Migration policy composed with the actual ordinary bond implementation.
contract UniswapV4DetfMigrationBondFacet is UniswapV4DetfFacet, UniswapV4DetfBondTarget, UniswapV4DetfMigrationPolicy {
    function facetName() public pure override returns (string memory) { return "UniswapV4DetfMigrationBondFacet"; }
    function _openBondNft(uint256 principal_, uint256 duration_, address recipient_)
        internal override returns (uint256 id_)
    {
        Repo._layoutStruct().expectedSynchronizer = address(ParentRepo._layoutStruct().bondNftVault);
        id_ = super._openBondNft(principal_, duration_, recipient_);
        delete Repo._layoutStruct().expectedSynchronizer;
    }

    function _pendingExpansionDetf() internal view override(UniswapV4DetfCommon, UniswapV4DetfMigrationPolicy) returns (uint256) { return UniswapV4DetfMigrationPolicy._pendingExpansionDetf(); }
    function _realizeExpansionIfNeeded() internal override(UniswapV4DetfCommon, UniswapV4DetfMigrationPolicy) returns (uint256) { return UniswapV4DetfMigrationPolicy._realizeExpansionIfNeeded(); }
    function _isMintingAllowedToken(IERC20 token_) internal view override(UniswapV4DetfCommon, UniswapV4DetfMigrationPolicy) returns (bool) { return UniswapV4DetfMigrationPolicy._isMintingAllowedToken(token_); }
    function _residualBalance(address token_) internal view override(UniswapV4DetfCommon, UniswapV4DetfMigrationPolicy) returns (uint256) { return UniswapV4DetfMigrationPolicy._residualBalance(token_); }
    function _sweepDustBody() internal override(UniswapV4DetfCommon, UniswapV4DetfMigrationPolicy) { UniswapV4DetfMigrationPolicy._sweepDustBody(); }

    function _entryBond(IERC20 input_, uint256 amount_, uint256 duration_, address recipient_, bool pretransferred_, uint256 deadline_) internal override returns (uint256 id_, uint256 shares_) {
        _admit(false, false);
        bool firstOwnerPurchase_ = !Repo._layoutStruct().activated;
        if (firstOwnerPurchase_) {
            MultiStepOwnableRepo._onlyOwner();
            if (Repo._layoutStruct().ownerFirstBondTokenId != 0) revert Accounting.MigrationRewardsClosed();
            // This exception requires a fresh authorized pull, never existing recovery/donation inventory.
            if (pretransferred_) revert ParentRepo.NotAuthorized(msg.sender);
        }
        if (ReentrancyLockRepo._isLocked()) revert ParentRepo.NotAuthorized(msg.sender);
        _beginBudget();
        (id_, shares_) = super._entryBond(input_, amount_, duration_, recipient_, pretransferred_, deadline_);
        _endBudget();
        // The inherited path rejects zero principal and funds it before distributing actual rewards.
        // Publish only after all payment, child funding and settlement has returned successfully.
        if (firstOwnerPurchase_) {
            Repo._layoutStruct().ownerFirstBondTokenId = id_;
            emit Migration.MigrationOwnerFirstBondPurchased(msg.sender, id_);
        }
    }
    function facetFuncs() public pure override returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](1);
        funcs_[0] = IUniswapV4Detf.bond.selector;
    }
}
