// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/**
 * @title LoopPositionRepo
 * @author cyotee doge <doge.cyotee>
 * @notice Mutable local state for the cross-version carry loop: the configured pair, the
 *         current loop orientation, and rebalance bookkeeping (hysteresis / min-interval and
 *         the usage/performance-fee growth baseline).
 * @dev Per-version supplied/borrowed are mirrored here for composability ONLY. They are caches:
 *      all gating and accounting reconcile live from Aave on each call (PRD decision 2). The
 *      canonical net position is always recomputed, never read from these mirrors.
 */
library LoopPositionRepo {
    bytes32 internal constant STORAGE_SLOT =
        keccak256(abi.encode("indexedex.protocols.lending.aave.cross-version.loop.position"));

    /// @notice Loop orientation. `A_FIRST` supplies tokenA on V3.6 first; `B_FIRST` mirrors it.
    /// `FLAT` means fully unwound / no leverage (PRD decisions 8, 25).
    enum Direction {
        FLAT,
        A_FIRST,
        B_FIRST
    }

    struct Storage {
        IERC20 tokenA;
        IERC20 tokenB;
        Direction direction;
        // Timestamp of the last rebalance, for the min-interval gate (PRD decision 7).
        uint256 lastRebalanceTimestamp;
        // Net-reserve value baseline (common unit) for usage/performance-fee growth (PRD decision 19).
        uint256 feeReserveValueBaseline;
        // --- caches / mirrors only (not trusted; PRD decision 2) ---
        mapping(address token => uint256 supplied) v36SuppliedMirror;
        mapping(address token => uint256 borrowed) v36BorrowedMirror;
        mapping(address token => uint256 supplied) v4SuppliedMirror;
        mapping(address token => uint256 borrowed) v4BorrowedMirror;
    }

    function _layout(bytes32 slot) internal pure returns (Storage storage layoutStruct) {
        assembly {
            layoutStruct.slot := slot
        }
    }

    function _layout() internal pure returns (Storage storage layoutStruct) {
        return _layout(STORAGE_SLOT);
    }

    function _initialize(Storage storage layoutStruct, IERC20 tokenA_, IERC20 tokenB_) internal {
        layoutStruct.tokenA = tokenA_;
        layoutStruct.tokenB = tokenB_;
        layoutStruct.direction = Direction.FLAT;
    }

    function _initialize(IERC20 tokenA_, IERC20 tokenB_) internal {
        _initialize(_layout(), tokenA_, tokenB_);
    }

    function _tokenA() internal view returns (IERC20) {
        return _layout().tokenA;
    }

    function _tokenB() internal view returns (IERC20) {
        return _layout().tokenB;
    }

    function _direction() internal view returns (Direction) {
        return _layout().direction;
    }

    function _setDirection(Direction direction_) internal {
        _layout().direction = direction_;
    }

    function _lastRebalanceTimestamp() internal view returns (uint256) {
        return _layout().lastRebalanceTimestamp;
    }

    function _setLastRebalanceTimestamp(uint256 timestamp_) internal {
        _layout().lastRebalanceTimestamp = timestamp_;
    }

    function _feeReserveValueBaseline() internal view returns (uint256) {
        return _layout().feeReserveValueBaseline;
    }

    function _setFeeReserveValueBaseline(uint256 value_) internal {
        _layout().feeReserveValueBaseline = value_;
    }
}
