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
import {AddressSet} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";
import {AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";
import {IRICHIR} from "contracts/interfaces/IRICHIR.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IProtocolDETFErrors} from "contracts/interfaces/IProtocolDETFErrors.sol";
import {
    IBalancerV3StandardExchangeRouterPrepay
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";

/**
 * @title BaseProtocolDETFRepo
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Storage library for Protocol DETF vault state.
 * @dev Follows the Crane Repo pattern with dual _layout() functions.
 *
 *      Key differences from SeigniorageDETF:
 *      - WETH-only minting (not reserve vault token)
 *      - Two underlying vaults: CHIR/WETH and RICH/CHIR
 *      - RICHIR rebasing token instead of sRBT
 *      - Protocol-owned NFT for accumulating sold positions
 */
library BaseProtocolDETFRepo {
    using AddressSetRepo for AddressSet;

    error TokenNotSupported();
    error NotAllowedRichirRedeem(address caller);

    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.vaults.protocol.detf");

    struct ProtocolConfig {
        address richToken;
        uint256 richInitialDepositAmount;
        uint256 richMintChirPercent; // 1e18 == 100%
        address wethToken;
        uint256 wethInitialDepositAmount;
        uint256 wethMintChirPercent; // 1e18 == 100%
    }

    struct Storage {
        /// @notice Whether the reserve pool has been initialized
        bool isReservePoolInitialized;

        /// @notice The RICH token (static supply reward token)
        IERC20 richToken;

        /// @notice Full protocol deployment config (copied from PkgArgs)
        ProtocolConfig protocolConfig;

        /// @notice The RICHIR token (rebasing redemption token)
        IRICHIR richirToken;

        /// @notice The WETH token (chain's wrapped gas token)
        IERC20 wethToken;

        /// @notice The CHIR/WETH Standard Exchange Vault (80% in reserve pool)
        IStandardExchange chirWethVault;

        /// @notice The RICH/CHIR Standard Exchange Vault (20% in reserve pool)
        IStandardExchange richChirVault;

        /// @notice Rate target token for the CHIR/WETH vault.
        IERC20 chirWethRateTarget;

        /// @notice Rate target token for the RICH/CHIR vault.
        IERC20 richChirRateTarget;

        /// @notice Index of CHIR/WETH vault in the reserve pool token array
        uint256 chirWethVaultIndex;

        /// @notice Weight of CHIR/WETH vault in the reserve pool (80%)
        uint256 chirWethVaultWeight;

        /// @notice Index of RICH/CHIR vault in the reserve pool token array
        uint256 richChirVaultIndex;

        /// @notice Weight of RICH/CHIR vault in the reserve pool (20%)
        uint256 richChirVaultWeight;

        /// @notice The NFT vault that holds bonded positions
        IProtocolNFTVault protocolNFTVault;

        /// @notice The protocol-owned NFT token ID
        uint256 protocolNFTId;

        /// @notice The fee oracle for seigniorage incentive lookups
        IVaultFeeOracleQuery feeOracle;

        /// @notice The Balancer V3 prepay router for liquidity operations
        IBalancerV3StandardExchangeRouterPrepay balancerV3PrepayRouter;

        /// @notice Upper deadband bound; minting is enabled only above this value
        uint256 mintThreshold;

        /// @notice Lower deadband bound; burning is enabled only below this value
        uint256 burnThreshold;

        /// @notice AddressSet of addresses allowed to use the RICHIR→RICH exchange route
        AddressSet allowedRichirRedeemAddresses;

        /// @notice AddressSet of tokens accepted by the unified bond entry point
        AddressSet acceptedBondTokens;
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
        IVaultFeeOracleQuery feeOracle_,
        IBalancerV3StandardExchangeRouterPrepay balancerV3PrepayRouter_,
        ProtocolConfig memory protocolConfig_,
        uint256 mintThreshold_,
        uint256 burnThreshold_
    ) internal {
        layout_.feeOracle = feeOracle_;
        layout_.balancerV3PrepayRouter = balancerV3PrepayRouter_;
        layout_.protocolConfig = protocolConfig_;
        layout_.richToken = IERC20(protocolConfig_.richToken);
        layout_.wethToken = IERC20(protocolConfig_.wethToken);
        layout_.mintThreshold = mintThreshold_;
        layout_.burnThreshold = burnThreshold_;
        layout_.acceptedBondTokens._add(protocolConfig_.richToken);
        layout_.acceptedBondTokens._add(protocolConfig_.wethToken);
    }

    function _initialize(
        IVaultFeeOracleQuery feeOracle_,
        IBalancerV3StandardExchangeRouterPrepay balancerV3PrepayRouter_,
        ProtocolConfig memory protocolConfig_,
        uint256 mintThreshold_,
        uint256 burnThreshold_
    ) internal {
        _initialize(_layout(), feeOracle_, balancerV3PrepayRouter_, protocolConfig_, mintThreshold_, burnThreshold_);
    }

    function _initializeExchangeVaults(
        Storage storage layout_,
        IStandardExchange chirWethVault_,
        IStandardExchange richChirVault_,
        IERC20 chirWethRateTarget_,
        IERC20 richChirRateTarget_
    ) internal {
        layout_.chirWethVault = chirWethVault_;
        layout_.richChirVault = richChirVault_;
        layout_.chirWethRateTarget = chirWethRateTarget_;
        layout_.richChirRateTarget = richChirRateTarget_;
    }

    function _initializeExchangeVaults(
        IStandardExchange chirWethVault_,
        IStandardExchange richChirVault_,
        IERC20 chirWethRateTarget_,
        IERC20 richChirRateTarget_
    ) internal {
        _initializeExchangeVaults(_layout(), chirWethVault_, richChirVault_, chirWethRateTarget_, richChirRateTarget_);
    }

    function _initializeReservePool(
        Storage storage layout_,
        uint256 chirWethVaultIndex_,
        uint256 chirWethVaultWeight_,
        uint256 richChirVaultIndex_,
        uint256 richChirVaultWeight_,
        IProtocolNFTVault protocolNFTVault_,
        IRICHIR richirToken_,
        uint256 protocolNFTId_
    ) internal {
        // Validate that indices are valid for a 2-token Balancer pool:
        // - Both must be 0 or 1
        // - They must be different (one is 0, one is 1)
        // This prevents catastrophic fund loss from inverted indices
        if (chirWethVaultIndex_ > 1 || richChirVaultIndex_ > 1 || chirWethVaultIndex_ == richChirVaultIndex_) {
            revert IProtocolDETFErrors.InvalidReservePoolIndices(chirWethVaultIndex_, richChirVaultIndex_);
        }

        layout_.chirWethVaultIndex = chirWethVaultIndex_;
        layout_.chirWethVaultWeight = chirWethVaultWeight_;
        layout_.richChirVaultIndex = richChirVaultIndex_;
        layout_.richChirVaultWeight = richChirVaultWeight_;
        layout_.protocolNFTVault = protocolNFTVault_;
        layout_.richirToken = richirToken_;
        layout_.protocolNFTId = protocolNFTId_;
        layout_.isReservePoolInitialized = true;
    }

    function _initializeReservePool(
        uint256 chirWethVaultIndex_,
        uint256 chirWethVaultWeight_,
        uint256 richChirVaultIndex_,
        uint256 richChirVaultWeight_,
        IProtocolNFTVault protocolNFTVault_,
        IRICHIR richirToken_,
        uint256 protocolNFTId_
    ) internal {
        _initializeReservePool(
            _layout(),
            chirWethVaultIndex_,
            chirWethVaultWeight_,
            richChirVaultIndex_,
            richChirVaultWeight_,
            protocolNFTVault_,
            richirToken_,
            protocolNFTId_
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                         Reserve Pool State                             */
    /* ---------------------------------------------------------------------- */

    function _isReservePoolInitialized(Storage storage layout_) internal view returns (bool) {
        return layout_.isReservePoolInitialized;
    }

    function _isReservePoolInitialized() internal view returns (bool) {
        return _isReservePoolInitialized(_layout());
    }

    /* ---------------------------------------------------------------------- */
    /*                              Tokens                                    */
    /* ---------------------------------------------------------------------- */

    function _richToken(Storage storage layout_) internal view returns (IERC20) {
        return layout_.richToken;
    }

    function _richToken() internal view returns (IERC20) {
        return _richToken(_layout());
    }

    function _richirToken(Storage storage layout_) internal view returns (IRICHIR) {
        return layout_.richirToken;
    }

    function _richirToken() internal view returns (IRICHIR) {
        return _richirToken(_layout());
    }

    function _wethToken(Storage storage layout_) internal view returns (IERC20) {
        return layout_.wethToken;
    }

    function _wethToken() internal view returns (IERC20) {
        return _wethToken(_layout());
    }

    function _protocolConfig(Storage storage layout_) internal view returns (ProtocolConfig memory) {
        return layout_.protocolConfig;
    }

    function _protocolConfig() internal view returns (ProtocolConfig memory) {
        return _protocolConfig(_layout());
    }

    /* ---------------------------------------------------------------------- */
    /*                         Accepted Bond Tokens                           */
    /* ---------------------------------------------------------------------- */

    function _acceptedBondTokens(Storage storage layout_) internal view returns (address[] memory) {
        return layout_.acceptedBondTokens._asArray();
    }

    function _acceptedBondTokens() internal view returns (address[] memory) {
        return _acceptedBondTokens(_layout());
    }

    function _isAcceptedBondToken(Storage storage layout_, address token_) internal view returns (bool) {
        return layout_.acceptedBondTokens._contains(token_);
    }

    function _isAcceptedBondToken(address token_) internal view returns (bool) {
        return _isAcceptedBondToken(_layout(), token_);
    }

    function _addAcceptedBondToken(Storage storage layout_, address token_) internal returns (bool) {
        return layout_.acceptedBondTokens._add(token_);
    }

    function _addAcceptedBondToken(address token_) internal returns (bool) {
        return _addAcceptedBondToken(_layout(), token_);
    }

    function _removeAcceptedBondToken(Storage storage layout_, address token_) internal {
        layout_.acceptedBondTokens._remove(token_);
    }

    function _removeAcceptedBondToken(address token_) internal {
        _removeAcceptedBondToken(_layout(), token_);
    }

    /* ---------------------------------------------------------------------- */
    /*                              Vaults                                    */
    /* ---------------------------------------------------------------------- */

    function _chirWethVault(Storage storage layout_) internal view returns (IStandardExchange) {
        return layout_.chirWethVault;
    }

    function _chirWethVault() internal view returns (IStandardExchange) {
        return _chirWethVault(_layout());
    }

    function _richChirVault(Storage storage layout_) internal view returns (IStandardExchange) {
        return layout_.richChirVault;
    }

    function _richChirVault() internal view returns (IStandardExchange) {
        return _richChirVault(_layout());
    }

    function _chirWethRateTarget(Storage storage layout_) internal view returns (IERC20) {
        return layout_.chirWethRateTarget;
    }

    function _chirWethRateTarget() internal view returns (IERC20) {
        return _chirWethRateTarget(_layout());
    }

    function _richChirRateTarget(Storage storage layout_) internal view returns (IERC20) {
        return layout_.richChirRateTarget;
    }

    function _richChirRateTarget() internal view returns (IERC20) {
        return _richChirRateTarget(_layout());
    }

    /* ---------------------------------------------------------------------- */
    /*                         Pool Indices & Weights                         */
    /* ---------------------------------------------------------------------- */

    function _chirWethVaultIndex(Storage storage layout_) internal view returns (uint256) {
        return layout_.chirWethVaultIndex;
    }

    function _chirWethVaultIndex() internal view returns (uint256) {
        return _chirWethVaultIndex(_layout());
    }

    function _chirWethVaultWeight(Storage storage layout_) internal view returns (uint256) {
        return layout_.chirWethVaultWeight;
    }

    function _chirWethVaultWeight() internal view returns (uint256) {
        return _chirWethVaultWeight(_layout());
    }

    function _richChirVaultIndex(Storage storage layout_) internal view returns (uint256) {
        return layout_.richChirVaultIndex;
    }

    function _richChirVaultIndex() internal view returns (uint256) {
        return _richChirVaultIndex(_layout());
    }

    function _richChirVaultWeight(Storage storage layout_) internal view returns (uint256) {
        return layout_.richChirVaultWeight;
    }

    function _richChirVaultWeight() internal view returns (uint256) {
        return _richChirVaultWeight(_layout());
    }

    /* ---------------------------------------------------------------------- */
    /*                              NFT Vault                                 */
    /* ---------------------------------------------------------------------- */

    function _protocolNFTVault(Storage storage layout_) internal view returns (IProtocolNFTVault) {
        return layout_.protocolNFTVault;
    }

    function _protocolNFTVault() internal view returns (IProtocolNFTVault) {
        return _protocolNFTVault(_layout());
    }

    function _protocolNFTId(Storage storage layout_) internal view returns (uint256) {
        return layout_.protocolNFTId;
    }

    function _protocolNFTId() internal view returns (uint256) {
        return _protocolNFTId(_layout());
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

    /* ---------------------------------------------------------------------- */
    /*                          Price Thresholds                              */
    /* ---------------------------------------------------------------------- */

    function _mintThreshold(Storage storage layout_) internal view returns (uint256) {
        return layout_.mintThreshold;
    }

    function _mintThreshold() internal view returns (uint256) {
        return _mintThreshold(_layout());
    }

    function _burnThreshold(Storage storage layout_) internal view returns (uint256) {
        return layout_.burnThreshold;
    }

    function _burnThreshold() internal view returns (uint256) {
        return _burnThreshold(_layout());
    }

    function _seigniorageIncentivePercentagePPM(Storage storage layout_) internal view returns (uint256) {
        return layout_.feeOracle.seigniorageIncentivePercentageOfVault(address(this));
    }

    function _seigniorageIncentivePercentagePPM() internal view returns (uint256) {
        return _seigniorageIncentivePercentagePPM(_layout());
    }
}
