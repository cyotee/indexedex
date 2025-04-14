// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IRouter} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRouter.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {ISeigniorageNFTVault} from "contracts/interfaces/ISeigniorageNFTVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    IBalancerV3StandardExchangeRouterPrepay
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";

/**
 * @title SeigniorageDETFRepo
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Storage library for Seigniorage DETF vault state.
 * @dev Follows the Crane Repo pattern with dual _layout() functions.
 */
library SeigniorageDETFRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.vaults.seigniorage.detf");

    struct Storage {
        /// @notice Whether the reserve pool has been initialized
        bool isReservePoolInitialized;
        /// @notice The Balancer V3 vault for pool operations
        // IVault balancerV3Vault;
        /// @notice The Balancer V3 router for liquidity operations
        // IRouter balancerV3Router;
        /// @notice The underlying reserve vault (e.g., LP token vault)
        IStandardExchange reserveVault;
        /// @notice The token used for rate calculations (price target)
        IERC20 reserveVaultRateTarget;
        /// @notice Index of this DETF in the reserve pool token array
        uint256 selfIndexInReservePool;
        /// @notice Weight of this DETF in the reserve pool (e.g., 80%)
        uint256 selfReservePoolWeight;
        /// @notice Index of reserve vault in the reserve pool token array
        uint256 reserveVaultIndexInReservePool;
        /// @notice Weight of reserve vault in the reserve pool (e.g., 20%)
        uint256 reserveVaultReservePoolWeight;
        /// @notice The seigniorage token (sRBT) that represents claims on profits
        IERC20MintBurn seigniorageToken;
        /// @notice The NFT vault that holds bonded positions
        ISeigniorageNFTVault seigniorageNFTVault;
        /// @notice The fee oracle for seigniorage incentive lookups
        IVaultFeeOracleQuery feeOracle;
        /// @notice The Balancer V3 prepay router for liquidity operations
        IBalancerV3StandardExchangeRouterPrepay balancerV3PrepayRouter;
    }

    /* ---------------------------------------------------------------------- */
    /*                           Layout Functions                             */
    /* ---------------------------------------------------------------------- */

    function _layout(bytes32 slot_) internal pure returns (Storage storage layout_) {
        assembly {
            layout_.slot := slot_
        }
    }

    function _layout() internal pure returns (Storage storage) {
        return _layout(STORAGE_SLOT);
    }

    /* ---------------------------------------------------------------------- */
    /*                         Initialization                                 */
    /* ---------------------------------------------------------------------- */

    function _initialize(
        Storage storage layout_,
        // IVault balancerV3Vault_,
        // IRouter balancerV3Router_,
        IVaultFeeOracleQuery feeOracle_,
        IBalancerV3StandardExchangeRouterPrepay balancerV3PrepayRouter_,
        IStandardExchange reserveVault_,
        IERC20 reserveVaultRateTarget_,
        IERC20MintBurn seigniorageToken_
        // uint256 selfIndexInReservePool_,
        // uint256 selfReservePoolWeight_,
        // uint256 reserveVaultIndexInReservePool_,
        // uint256 reserveVaultReservePoolWeight_,
        // ISeigniorageNFTVault seigniorageNFTVault_,
    ) internal {
        // layout_.balancerV3Vault = balancerV3Vault_;
        // layout_.balancerV3Router = balancerV3Router_;
        layout_.feeOracle = feeOracle_;
        layout_.balancerV3PrepayRouter = balancerV3PrepayRouter_;
        layout_.reserveVault = reserveVault_;
        layout_.reserveVaultRateTarget = reserveVaultRateTarget_;
        layout_.seigniorageToken = seigniorageToken_;
        // layout_.selfIndexInReservePool = selfIndexInReservePool_;
        // layout_.selfReservePoolWeight = selfReservePoolWeight_;
        // layout_.reserveVaultIndexInReservePool = reserveVaultIndexInReservePool_;
        // layout_.reserveVaultReservePoolWeight = reserveVaultReservePoolWeight_;
        // layout_.seigniorageNFTVault = seigniorageNFTVault_;
    }

    function _initialize(
        IVaultFeeOracleQuery feeOracle_,
        IBalancerV3StandardExchangeRouterPrepay balancerV3PrepayRouter_,
        IStandardExchange reserveVault_,
        IERC20 reserveVaultRateTarget_,
        IERC20MintBurn seigniorageToken_
    ) internal {
        _initialize(
            _layout(), feeOracle_, balancerV3PrepayRouter_, reserveVault_, reserveVaultRateTarget_, seigniorageToken_
        );
    }

    function _initialize(
        Storage storage layout_,
        uint256 selfIndexInReservePool_,
        uint256 selfReservePoolWeight_,
        uint256 reserveVaultIndexInReservePool_,
        uint256 reserveVaultReservePoolWeight_,
        ISeigniorageNFTVault seigniorageNFTVault_
    ) internal {
        // layout_.balancerV3Vault = balancerV3Vault_;
        // layout_.balancerV3Router = balancerV3Router_;
        // layout_.balancerV3PrepayRouter = balancerV3PrepayRouter_;
        // layout_.reserveVault = reserveVault_;
        // layout_.reserveVaultRateTarget = reserveVaultRateTarget_;
        // layout_.reserveVaultTokens._add(reserveVaultTokens_);
        layout_.selfIndexInReservePool = selfIndexInReservePool_;
        layout_.selfReservePoolWeight = selfReservePoolWeight_;
        layout_.reserveVaultIndexInReservePool = reserveVaultIndexInReservePool_;
        layout_.reserveVaultReservePoolWeight = reserveVaultReservePoolWeight_;
        // layout_.seigniorageToken = seigniorageToken_;
        layout_.seigniorageNFTVault = seigniorageNFTVault_;
        // layout_.feeOracle = feeOracle_;
    }

    // function _initialize(
    //     IVault balancerV3Vault_,
    //     IRouter balancerV3Router_,
    //     IBalancerV3StandardExchangeRouterPrepay balancerV3PrepayRouter_,
    //     IStandardExchange reserveVault_,
    //     IERC20 reserveVaultRateTarget_,
    //     address[] memory reserveVaultTokens_,
    //     uint256 selfIndexInReservePool_,
    //     uint256 selfReservePoolWeight_,
    //     uint256 reserveVaultIndexInReservePool_,
    //     uint256 reserveVaultReservePoolWeight_,
    //     IERC20MintBurn seigniorageToken_,
    //     ISeigniorageNFTVault seigniorageNFTVault_,
    //     IVaultFeeOracleQuery feeOracle_
    // ) internal {
    //     _initialize(
    //         _layout(),
    //         balancerV3Vault_,
    //         balancerV3Router_,
    //         balancerV3PrepayRouter_,
    //         reserveVault_,
    //         reserveVaultRateTarget_,
    //         reserveVaultTokens_,
    //         selfIndexInReservePool_,
    //         selfReservePoolWeight_,
    //         reserveVaultIndexInReservePool_,
    //         reserveVaultReservePoolWeight_,
    //         seigniorageToken_,
    //         seigniorageNFTVault_,
    //         feeOracle_
    //     );
    // }

    /* ---------------------------------------------------------------------- */
    /*                         Reserve Pool State                             */
    /* ---------------------------------------------------------------------- */

    function _isReservePoolInitialized(Storage storage layout_) internal view returns (bool) {
        return layout_.isReservePoolInitialized;
    }

    function _isReservePoolInitialized() internal view returns (bool) {
        return _isReservePoolInitialized(_layout());
    }

    function _setIsReservePoolInitialized(Storage storage layout_) internal {
        layout_.isReservePoolInitialized = true;
    }

    function _setIsReservePoolInitialized() internal {
        _setIsReservePoolInitialized(_layout());
    }

    /* ---------------------------------------------------------------------- */
    /*                          Balancer V3 Vault                             */
    /* ---------------------------------------------------------------------- */

    // function _balancerV3Vault(Storage storage layout_) internal view returns (IVault) {
    //     return layout_.balancerV3Vault;
    // }

    // function _balancerV3Vault() internal view returns (IVault) {
    //     return _balancerV3Vault(_layout());
    // }

    /* ---------------------------------------------------------------------- */
    /*                         Balancer V3 Router                             */
    /* ---------------------------------------------------------------------- */

    // function _balancerV3Router(Storage storage layout_) internal view returns (IRouter) {
    //     return layout_.balancerV3Router;
    // }

    // function _balancerV3Router() internal view returns (IRouter) {
    //     return _balancerV3Router(_layout());
    // }

    /* ---------------------------------------------------------------------- */
    /*                           Reserve Vault                                */
    /* ---------------------------------------------------------------------- */

    function _reserveVault(Storage storage layout_) internal view returns (IStandardExchange) {
        return layout_.reserveVault;
    }

    function _reserveVault() internal view returns (IStandardExchange) {
        return _reserveVault(_layout());
    }

    function _reserveVaultRateTarget(Storage storage layout_) internal view returns (IERC20) {
        return layout_.reserveVaultRateTarget;
    }

    function _reserveVaultRateTarget() internal view returns (IERC20) {
        return _reserveVaultRateTarget(_layout());
    }

    /* ---------------------------------------------------------------------- */
    /*                         Pool Indices & Weights                         */
    /* ---------------------------------------------------------------------- */

    function _selfIndexInReservePool(Storage storage layout_) internal view returns (uint256) {
        return layout_.selfIndexInReservePool;
    }

    function _selfIndexInReservePool() internal view returns (uint256) {
        return _selfIndexInReservePool(_layout());
    }

    function _selfReservePoolWeight(Storage storage layout_) internal view returns (uint256) {
        return layout_.selfReservePoolWeight;
    }

    function _selfReservePoolWeight() internal view returns (uint256) {
        return _selfReservePoolWeight(_layout());
    }

    function _reserveVaultIndexInReservePool(Storage storage layout_) internal view returns (uint256) {
        return layout_.reserveVaultIndexInReservePool;
    }

    function _reserveVaultIndexInReservePool() internal view returns (uint256) {
        return _reserveVaultIndexInReservePool(_layout());
    }

    function _reserveVaultReservePoolWeight(Storage storage layout_) internal view returns (uint256) {
        return layout_.reserveVaultReservePoolWeight;
    }

    function _reserveVaultReservePoolWeight() internal view returns (uint256) {
        return _reserveVaultReservePoolWeight(_layout());
    }

    /* ---------------------------------------------------------------------- */
    /*                         Seigniorage Components                         */
    /* ---------------------------------------------------------------------- */

    function _seigniorageToken(Storage storage layout_) internal view returns (IERC20MintBurn) {
        return layout_.seigniorageToken;
    }

    function _seigniorageToken() internal view returns (IERC20MintBurn) {
        return _seigniorageToken(_layout());
    }

    function _seigniorageNFTVault(Storage storage layout_) internal view returns (ISeigniorageNFTVault) {
        return layout_.seigniorageNFTVault;
    }

    function _seigniorageNFTVault() internal view returns (ISeigniorageNFTVault) {
        return _seigniorageNFTVault(_layout());
    }

    /* ---------------------------------------------------------------------- */
    /*                           Fee Oracle                                   */
    /* ---------------------------------------------------------------------- */

    function _feeOracle(Storage storage layout_) internal view returns (IVaultFeeOracleQuery) {
        return layout_.feeOracle;
    }

    function _feeOracle() internal view returns (IVaultFeeOracleQuery) {
        return _feeOracle(_layout());
    }

    /* ---------------------------------------------------------------------- */
    /*                       Balancer V3 Prepay Router                        */
    /* ---------------------------------------------------------------------- */

    function _balancerV3PrepayRouter(Storage storage layout_)
        internal
        view
        returns (IBalancerV3StandardExchangeRouterPrepay)
    {
        return layout_.balancerV3PrepayRouter;
    }

    function _balancerV3PrepayRouter() internal view returns (IBalancerV3StandardExchangeRouterPrepay) {
        return _balancerV3PrepayRouter(_layout());
    }

    function _swapFeeReductionPercentagePPM(Storage storage layout_) internal view returns (uint256) {
        return layout_.feeOracle.seigniorageIncentivePercentageOfVault(address(this));
    }

    function _swapFeeReductionPercentagePPM() internal view returns (uint256) {
        return _swapFeeReductionPercentagePPM(_layout());
    }
}
