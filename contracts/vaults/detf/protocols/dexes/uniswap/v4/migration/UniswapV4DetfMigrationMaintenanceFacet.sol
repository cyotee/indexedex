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
import {IUniswapV4Detf} from "../detf/interfaces/IUniswapV4Detf.sol";
import {IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {IUniswapV4DetfSelfCall} from "../detf/interfaces/IUniswapV4DetfSelfCall.sol";
import {UniswapV4DetfFacet} from "../detf/UniswapV4DetfFacet.sol";
contract UniswapV4DetfMigrationMaintenanceFacet is UniswapV4DetfFacet, UniswapV4DetfTarget, UniswapV4DetfMigrationPolicy {
function facetName() public pure override returns (string memory) { return "UniswapV4DetfMigrationMaintenanceFacet"; }

    function _pendingExpansionDetf() internal view override(UniswapV4DetfCommon, UniswapV4DetfMigrationPolicy) returns (uint256) { return UniswapV4DetfMigrationPolicy._pendingExpansionDetf(); }
    function _realizeExpansionIfNeeded() internal override(UniswapV4DetfCommon, UniswapV4DetfMigrationPolicy) returns (uint256) { return UniswapV4DetfMigrationPolicy._realizeExpansionIfNeeded(); }
    function _isMintingAllowedToken(IERC20 token_) internal view override(UniswapV4DetfCommon, UniswapV4DetfMigrationPolicy) returns (bool) { return UniswapV4DetfMigrationPolicy._isMintingAllowedToken(token_); }
    function _residualBalance(address token_) internal view override(UniswapV4DetfCommon, UniswapV4DetfMigrationPolicy) returns (uint256) { return UniswapV4DetfMigrationPolicy._residualBalance(token_); }
    function _sweepDustBody() internal override(UniswapV4DetfCommon, UniswapV4DetfMigrationPolicy) { UniswapV4DetfMigrationPolicy._sweepDustBody(); }
    /// @notice Settle completed epochs before a staking or NFT participation change.
    /// @dev Outer DETF routes settle first. Only their two wired children may compose
    ///      this no-op callback while the DETF transaction lock is held.
    ///      Record remaining custody after settlement so later pretransfer claims
    ///      cannot consume already observed idle inventory. This does not join LP.
    function synchronizeRewards() external returns (uint256 minted_) {
        if (ReentrancyLockRepo._isLocked()) {
            ParentRepo.Storage storage s_ = ParentRepo._layoutStruct();
            address expected_ = Repo._layoutStruct().expectedSynchronizer;
            bool direct_ = expected_ != address(0) && msg.sender == expected_;
            bool bondFunding_ = expected_ == address(s_.bondNftVault)
                && msg.sender == address(s_.rebasingClaimToken)
                && Accounting(expected_).migrationAccountingPhase() == uint8(Accounting.AccountingPhase.Accounting);
            if ((!direct_ && !bondFunding_) || Accounting(msg.sender).migrationAccountingPhase()
                != uint8(Accounting.AccountingPhase.Synchronizing)) {
                revert ParentRepo.NotAuthorized(msg.sender);
            }
            return 0;
        }
        _admit(true, false);
        ReentrancyLockRepo._lock();
        minted_ = _realizeExpansionIfNeeded();
        _syncAllExpectedHoldReserves();
        ReentrancyLockRepo._unlock();
    }

    /// @notice Forwards a reserve donation to the bond NFT's canonical donation entrypoint.
    function donate(IERC20 token, uint256 amount, bool pretransferred) external {
        _requireIdleChildren();
        _entryDonate(token, amount, pretransferred);
    }

    /// @notice Joins donated capital on behalf of the authorized bond NFT vault.
    function joinDonatedCapital(IERC20 token, uint256 amount, uint256 deadline) external returns (uint256 lpOut) {
        _admit(false, true);
        _beginBudget();
        lpOut = _entryJoinDonatedCapital(token, amount, deadline);
        _endBudget();
    }

    /// @notice Updates reserve accounting after an authorized bond NFT donation.
    function notifyReserveDonated() external {
        _admit(false, true);
        _entryNotifyReserveDonated();
    }

    /// @notice Joins residual diamond inventory into the live reserve under the unassigned-LP policy.
    function sweepDust() external {
        _requireIdleChildren();
        _entrySweepDust();
    }

    /// @notice Executes one atomic dust-sweep attempt; only the diamond itself may call.
    function sweepDustAtomic() external {
        _entrySweepDustAtomic();
    }

    /// @notice Performs one self-only residual join without a duplicate preview.
    function joinResidualAtomic(address token, uint256 amount, bool singleAsset) external returns (uint256 lpOut) {
        return _entryJoinResidualAtomic(token, amount, singleAsset);
    }

    /// @notice Wraps residual pair tokens through their SE vault; only the diamond itself may call.
    function sweepPairToShare(address se_, address pair_, uint256 amount_) external returns (uint256 shares_) {
        return _entrySweepPairToShare(se_, pair_, amount_);
    }
    function facetFuncs() public pure override returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](8);
        funcs_[0] = IUniswapV4Detf.donate.selector;
        funcs_[1] = IUniswapV4Detf.sweepDust.selector;
        funcs_[2] = IUniswapV4Detf.joinDonatedCapital.selector;
        funcs_[3] = IUniswapV4Detf.notifyReserveDonated.selector;
        funcs_[4] = IUniswapV4DetfSelfCall.sweepDustAtomic.selector;
        funcs_[5] = IUniswapV4DetfSelfCall.sweepPairToShare.selector;
        funcs_[6] = IDETFFundedRewards.synchronizeRewards.selector;
        funcs_[7] = IUniswapV4DetfSelfCall.joinResidualAtomic.selector;
    }
}
