// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/common/factory/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";

/// @title IUniswapV4StandardExchangeWeightedDETF
/// @notice Info + bonding + claim surface for Uni V4 Weighted SE Buffer true DETF.
/// @dev Role names only. No whole-DETF rateAsset. Bond principal = fungible hook LP.
///      Mature-only sell/close (DETF gate). Per-route syntheticVs(pair).
interface IUniswapV4StandardExchangeWeightedDETF {
    event ThresholdModeSet(ThresholdMode mode, uint256 mintThreshold, uint256 burnThreshold);
    event ProtocolRewardsCompounded(uint256 detfIn, uint256 lpOut);
    event NaturalSupplyExpanded(uint256 mintAmount, uint256 syntheticPrice, uint256 timestamp);
    event ReserveLive(uint256 firstBondTokenId, uint256 lpPrincipal);

    function isReserveLive() external view returns (bool);
    function n() external view returns (uint8);
    function m() external view returns (uint8);
    function pairTokens() external view returns (address[] memory);
    function pairToken(uint256 productIndex) external view returns (address);
    function standardExchanges() external view returns (address[] memory);
    function standardExchange(uint256 productIndex) external view returns (address);
    function vaultShares() external view returns (address[] memory);
    function vaultShare(uint256 productIndex) external view returns (address);
    function rateProviders() external view returns (address[] memory);
    function rateProvider(uint256 productIndex) external view returns (address);
    function weights() external view returns (uint256[] memory);
    function weight(uint256 bindingIndex) external view returns (uint256);
    function detfBindingIndex() external view returns (uint8);
    function pairBindingIndex(uint256 productIndex) external view returns (uint8);
    function reserveHook() external view returns (address);
    /// @notice Alias of reserveHook for RebasingClaimToken rate calc (`detf.reservePool()`).
    function reservePool() external view returns (address);

    /// @notice Debt-inclusive whole-reserve synthetic vs pair unit (1e18 peg = creation rate).
    function syntheticVs(address pair) external view returns (uint256);
    /// @notice Spot (no pending expansion debt) whole-reserve synthetic vs pair.
    function syntheticSpotVs(address pair) external view returns (uint256);
    function pendingExpansionDetf() external view returns (uint256);
    function mintThreshold() external view returns (uint256);
    function burnThreshold() external view returns (uint256);
    function thresholdMode() external view returns (ThresholdMode);
    function isMintingAllowed(address pair) external view returns (bool);
    function isBurningAllowed(address pair) external view returns (bool);
    function isAllLegsMintRich() external view returns (bool);
    function bondNftVault() external view returns (address);
    function rebasingClaimToken() external view returns (address);
    function feeRecipientNftId() external view returns (uint256);
    function creationPairPerDetfWad(uint256 productIndex) external view returns (uint256);
    function creationPairPerDetfWads() external view returns (uint256[] memory);
    /// @notice Pair per DETF on first bond for product index. Resolved storage (0 at init → creation).
    function openingPairPerDetfWad(uint256 productIndex) external view returns (uint256);
    function openingPairPerDetfWads() external view returns (uint256[] memory);
    function lastExpansionTimestamp() external view returns (uint256);
    function expansionEpochLength() external view returns (uint256);
    function expansionClosureRatePerYearWad() external view returns (uint256);
    function expansionMaxCatchUpEpochs() external view returns (uint256);
    function acceptedBondTokens() external view returns (address[] memory);
    function protocolLp() external view returns (uint256);
    function userBondedLp() external view returns (uint256);

    /// @notice Single capitalToken recorded at bond open (maturity close pays only this).
    function capitalTokenOf(uint256 tokenId) external view returns (address);

    function compoundProtocolRewards() external returns (uint256 detfIn, uint256 lpOut);

    /// @notice Multi-leg bond. First bond: all m externals + capitalToken; later: exactly one external.
    /// @param tokenIns Product-order capital tokens (length m for first; length 1 after live).
    /// @param amountsIn Parallel amounts.
    /// @param capitalToken Required on first bond (∈ pairTokens); ignored after live (derived).
    function bond(
        IERC20[] calldata tokenIns,
        uint256[] calldata amountsIn,
        address capitalToken,
        uint256 lockDuration,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 tokenId, uint256 shares);

    /// @notice Single-token convenience bond (after live: single external only; first bond reverts).
    function bond(
        IERC20 tokenIn,
        uint256 amountIn,
        uint256 lockDuration,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 tokenId, uint256 shares);

    /// @notice Mature-only: sell bond NFT → transfer originalShares to id 0 + rebasing claim (D10).
    function sellPositionToDetfNft(uint256 tokenId, address recipient)
        external
        returns (uint256 principalShares);

    /// @notice D25+L2: proportional reserve withdraw, burn DETF leg, send remaining tokens.
    /// @dev `minAmountsOut` length = `n` binding order. DETF self-leg slot must be 0.
    function closeBondMature(
        uint256 tokenId,
        uint256[] calldata minAmountsOut,
        address recipient,
        uint256 deadline
    ) external returns (uint256[] memory amountsOut);

    /// @notice Preview D25 close. DETF binding slot is 0; other slots are non-DETF payouts.
    function previewCloseBondMature(uint256 tokenId) external view returns (uint256[] memory amountsOut);

    function claimRewards(uint256 tokenId, address recipient) external returns (uint256 rewards);

    /// @notice Direct claim deposit (pair/share/SE/free DETF). Reverts if not single-asset eligible.
    function depositClaim(
        IERC20 tokenIn,
        uint256 amountIn,
        uint256 minClaimOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 claimOut);

    /// @notice D15: redeem rebasing claim for DETF only. Other tokenOut → InvalidRoute.
    function redeemClaim(
        uint256 claimAmount,
        IERC20 tokenOut,
        uint256 minOut,
        address recipient,
        uint256 deadline
    ) external returns (uint256 amountOut);

    /// @notice NFT vault / claim package: unwind protocol/bond LP principal.
    function claimLiquidity(uint256 lpAmount, address recipient) external returns (uint256 amountOut);

    event ReserveBondNftWired(
        address indexed reserveHook,
        address bondNftVault,
        uint256 detfNftId,
        uint256 feeRecipientNftId
    );
    event ReserveClaimWired(address indexed reserveHook, address rebasingClaimToken);

    error ReserveNotWired();
    error ReserveHookNotFinalized();
    error ReserveBondNftNotWired();
    error ReserveBondNftAlreadyWired();
    error ReserveClaimAlreadyWired();

    function isReserveHookFinalized() external view returns (bool);
    function isReserveWired() external view returns (bool);
    function completeReserveBondNft() external returns (address bondNftVault);
    function completeReserveClaim() external returns (address rebasingClaimToken);
}

/// @title IUniswapV4StandardExchangeWeightedDETDFPkg
/// @notice DFPkg interface — PkgInit / PkgArgs live HERE (Crane rule).
interface IUniswapV4StandardExchangeWeightedDETDFPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    error NotCalledByRegistry(address caller);
    error ZeroAddress();
    error InvalidCreationRate();
    error AllExternalBareForbidden();
    error SameStandardExchange();
    error RateProviderWithoutSE();
    error PairTokenNotInSeTokens();
    error DetfInSeTokens();
    error InvalidN();
    error InvalidWeights();
    error SamePairTokens();
    error ArrayLengthMismatch();
    error InvalidCapitalToken();

    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;
        IFacet exchangeInFacet; // Option 1e: exchange-only Facet
        IFacet bondingFacet; // Option 1e: bond/sell/close Facet
        IFacet compoundFacet; // Option 1e: claim/compound Facet
        IFacet infoFacet; // view/info surface
        IVaultFeeOracleQuery feeOracle;
        IVaultRegistryDeployment vaultRegistryDeployment;
        IPoolManager poolManager;
        IUniswapV4StandardExchangeWeightedBufferHookPackage hookPkg;
        IDetfSelfNftInventoryDFPkg bondNftVaultPkg;
        IRebasingClaimTokenDFPkg rebasingClaimTokenPkg;
        IDiamondPackageCallBackFactory diamondFactory;
    }

    /// @dev Product-order pair legs (m∈[1,7]); DETF binding free via address sort after diamond exists.
    /// @dev detfWeight + pairWeights (product order length m): remapped to binding order in postDeploy.
    ///      Sum(detfWeight + pairWeights) must be 1e18; each weight ≥ 1%.
    /// @dev standardExchanges / rateProviders / vaultShares: product-order length m (0 = bare).
    /// @dev creationPairPerDetfWad: product-order length m; each must be > 0.
    /// @dev openingPairPerDetfWad: empty or length m; 0 per slot → that slot's creation.
    /// @dev Trailing expansion: zeros resolve via DETFEpochNaturalExpansionLib.
    /// @dev thresholdMode: 0 = Policy (default), 1 = Open.
    /// @dev NO whole-DETF rateAsset field.
    struct PkgArgs {
        string name;
        string symbol;
        IERC20[] pairTokens; // product order, length m
        IStandardExchangeProxy[] standardExchanges; // product order; address(0) = bare
        IERC20[] vaultShares; // product order; address(0) → SE diamond is share when SE set
        address[] rateProviders; // product order; optional; only if SE set
        uint256 detfWeight; // DETF self-leg weight (WAD)
        uint256[] pairWeights; // product order length m
        uint256[] creationPairPerDetfWad; // product order; each > 0
        /// @notice Pair per DETF on first bond. 0 → use creation (open at peg). Empty array → all creation.
        uint256[] openingPairPerDetfWad;
        uint256 mintThreshold; // 0 → 1.05e18
        uint256 burnThreshold; // 0 → 0.95e18
        ThresholdMode thresholdMode; // 0 = Policy
        uint256 expansionEpochLength; // 0 → 8 hours
        uint256 expansionClosureRatePerYearWad; // 0 → 0.10e18
        uint256 expansionMaxCatchUpEpochs; // 0 = unlimited
        address creator; // D26; 0 → feeTo owns id 2 (D21)
        string claimName;
        string claimSymbol;
        string bondName;
        string bondSymbol;
    }

    function deployVault(PkgArgs memory args, uint256 mineNonce) external returns (address vault);
}
