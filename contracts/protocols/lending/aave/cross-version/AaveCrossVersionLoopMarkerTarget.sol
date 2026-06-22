// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPool} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPool.sol";
import {ISpoke} from "@crane/contracts/protocols/lending/aave/v4/spoke/interfaces/ISpoke.sol";

import {IAaveCrossVersionLoopVault} from "contracts/interfaces/IAaveCrossVersionLoopVault.sol";
import {LoopPositionRepo} from "contracts/protocols/lending/aave/cross-version/LoopPositionRepo.sol";
import {AaveV36PoolAwareRepo} from "contracts/protocols/lending/aave/cross-version/AaveV36PoolAwareRepo.sol";
import {AaveV4SpokeAwareRepo} from "contracts/protocols/lending/aave/cross-version/AaveV4SpokeAwareRepo.sol";
import {AaveV36Service} from "contracts/protocols/lending/aave/cross-version/AaveV36Service.sol";
import {AaveV4Service} from "contracts/protocols/lending/aave/cross-version/AaveV4Service.sol";

/**
 * @title AaveCrossVersionLoopMarkerTarget
 * @author cyotee doge <doge.cyotee>
 * @notice Marker implementation for the cross-version loop vault. Exposes the pair + sources and a
 *         live-reconciled `netBalanceOf` (PRD decisions 2, 10). Its interfaceId is the vault fee
 *         type key (PRD decisions 19, 26).
 */
contract AaveCrossVersionLoopMarkerTarget is IAaveCrossVersionLoopVault {
    using AaveV36Service for IPool;
    using AaveV4Service for ISpoke;

    /// @inheritdoc IAaveCrossVersionLoopVault
    function tokenA() public view returns (IERC20) {
        return LoopPositionRepo._tokenA();
    }

    /// @inheritdoc IAaveCrossVersionLoopVault
    function tokenB() public view returns (IERC20) {
        return LoopPositionRepo._tokenB();
    }

    /// @inheritdoc IAaveCrossVersionLoopVault
    function aaveV36Pool() public view returns (address) {
        return address(AaveV36PoolAwareRepo._pool());
    }

    /// @inheritdoc IAaveCrossVersionLoopVault
    function aaveV4Spoke() public view returns (address) {
        return address(AaveV4SpokeAwareRepo._spoke());
    }

    /// @inheritdoc IAaveCrossVersionLoopVault
    function aaveV4Hub() public view returns (address) {
        return address(AaveV4SpokeAwareRepo._hub());
    }

    /// @inheritdoc IAaveCrossVersionLoopVault
    /// @dev net = (V3.6 supplied + V4 supplied) - (V3.6 debt + V4 debt), reconciled live from Aave;
    ///      floored at 0 (PRD decisions 2, 10, 16). Repos are not consulted for position values.
    function netBalanceOf(IERC20 token) public view returns (uint256) {
        IPool pool = AaveV36PoolAwareRepo._pool();
        ISpoke spoke = AaveV4SpokeAwareRepo._spoke();
        uint256 reserveId = AaveV4SpokeAwareRepo._reserveIdOf(address(token));

        uint256 supplied =
            pool.suppliedOf(address(token), address(this)) + spoke.suppliedOf(reserveId, address(this));
        uint256 debt = pool.debtOf(address(token), address(this)) + spoke.debtOf(reserveId, address(this));

        return supplied >= debt ? supplied - debt : 0;
    }
}
