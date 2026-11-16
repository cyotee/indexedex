// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {ReentrancyLockRepo} from "@crane/contracts/access/reentrancy/ReentrancyLockRepo.sol";
import {UniswapV4DetfCommon} from "../detf/UniswapV4DetfCommon.sol";
import {UniswapV4DetfTarget} from "../detf/UniswapV4DetfTarget.sol";
import {UniswapV4DetfRepo as ParentRepo} from "../detf/UniswapV4DetfRepo.sol";
import {UniswapV4DetfMigrationPolicy} from "./UniswapV4DetfMigrationPolicy.sol";
import {UniswapV4DetfMigrationRepo as Repo} from "./UniswapV4DetfMigrationRepo.sol";
import {IUniswapV4DetfMigrationAccounting as Accounting} from "./interfaces/IUniswapV4DetfMigration.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";




import {UniswapV4DetfFacet} from "../detf/UniswapV4DetfFacet.sol";
import {UniswapV4DetfExchangeTarget} from "../detf/UniswapV4DetfExchangeTarget.sol";

/// @notice Migration policy composed with the actual ordinary exchange implementation.
contract UniswapV4DetfMigrationExchangeFacet is UniswapV4DetfFacet, UniswapV4DetfExchangeTarget, UniswapV4DetfMigrationPolicy {
    using BetterSafeERC20 for IERC20;
    function facetName() public pure override returns (string memory) { return "UniswapV4DetfMigrationExchangeFacet"; }
    function _stakeHeld(uint256 amount_, uint256 minimum_, address recipient_, uint256 deadline_)
        internal override returns (uint256 out_)
    {
        Repo._layoutStruct().expectedSynchronizer = address(ParentRepo._layoutStruct().rebasingClaimToken);
        out_ = super._stakeHeld(amount_, minimum_, recipient_, deadline_);
        delete Repo._layoutStruct().expectedSynchronizer;
    }
    function _unstakePath(uint256 amount_, IERC20 output_, uint256 minimum_, address recipient_, uint256 deadline_)
        internal override returns (uint256 out_)
    {
        _realizeExpansionIfNeeded();
        address receipt_ = address(ParentRepo._layoutStruct().rebasingClaimToken);
        Repo._layoutStruct().expectedSynchronizer = receipt_;
        IERC20(receipt_).safeTransferFrom(msg.sender, address(this), amount_);
        bool direct_ = address(output_) == address(this);
        (out_,) = IStakedDETF(receipt_).exchangeIn(
            IERC20(receipt_), amount_, IERC20(address(this)), direct_ ? minimum_ : 0,
            direct_ ? recipient_ : address(this), false, deadline_
        );
        delete Repo._layoutStruct().expectedSynchronizer;
        if (!direct_) out_ = _burnHeld(out_, output_, minimum_, recipient_, deadline_);
        _syncAllExpectedHoldReserves();
    }

    function _pendingExpansionDetf() internal view override(UniswapV4DetfCommon, UniswapV4DetfMigrationPolicy) returns (uint256) { return UniswapV4DetfMigrationPolicy._pendingExpansionDetf(); }
    function _realizeExpansionIfNeeded() internal override(UniswapV4DetfCommon, UniswapV4DetfMigrationPolicy) returns (uint256) { return UniswapV4DetfMigrationPolicy._realizeExpansionIfNeeded(); }
    function _isMintingAllowedToken(IERC20 token_) internal view override(UniswapV4DetfCommon, UniswapV4DetfMigrationPolicy) returns (bool) { return UniswapV4DetfMigrationPolicy._isMintingAllowedToken(token_); }
    function _residualBalance(address token_) internal view override(UniswapV4DetfCommon, UniswapV4DetfMigrationPolicy) returns (uint256) { return UniswapV4DetfMigrationPolicy._residualBalance(token_); }
    function _sweepDustBody() internal override(UniswapV4DetfCommon, UniswapV4DetfMigrationPolicy) { UniswapV4DetfMigrationPolicy._sweepDustBody(); }

    function _entryExchangeIn(IERC20 input_, uint256 amount_, IERC20 output_, uint256 minimum_, address recipient_, bool pretransferred_, uint256 deadline_) internal override returns (uint256 out_) {
        _admit(false, false);
        if (!Repo._layoutStruct().activated && address(input_) != address(this) && address(input_) != address(ParentRepo._layoutStruct().rebasingClaimToken)) revert Accounting.MigrationRewardsClosed();
        if (ReentrancyLockRepo._isLocked()) revert ParentRepo.NotAuthorized(msg.sender);
        _beginBudget();
        out_ = super._entryExchangeIn(input_, amount_, output_, minimum_, recipient_, pretransferred_, deadline_);
        _endBudget();
    }
    function facetFuncs() public pure override returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](1);
        funcs_[0] = IStandardExchangeIn.exchangeIn.selector;
    }
}
