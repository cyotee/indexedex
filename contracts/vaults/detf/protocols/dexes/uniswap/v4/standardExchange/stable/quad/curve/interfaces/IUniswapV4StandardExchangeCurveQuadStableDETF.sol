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
    IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.sol";

/// @title IUniswapV4StandardExchangeCurveQuadStableDETF
/// @notice Info + bonding + claim surface for Uni V4 Curve Quad Stable SE Buffer true DETF.
/// @dev Role names only. No whole-DETF rateAsset. Bond principal = fungible hook LP.
///      Mature-only sell/close (DETF gate). Per-route syntheticVs(pair).
///      Phase 0: exact-out mint/burn selectors revert InvalidRoute (not closed-form).
interface IUniswapV4StandardExchangeCurveQuadStableDETF {
    event ThresholdModeSet(ThresholdMode mode, uint256 mintThreshold, uint256 burnThreshold);
    event ProtocolRewardsCompounded(uint256 detfIn, uint256 lpOut);
    event NaturalSupplyExpanded(uint256 mintAmount, uint256 syntheticPrice, uint256 timestamp);
    event ReserveLive(uint256 firstBondTokenId, uint256 lpPrincipal);

    function isReserveLive() external view returns (bool);
    function n() external view returns (uint8);
    function m() external view returns (uint8);
    function pairTokens() external view returns (address[] memory);
    function pairToken(uint256 productIndex) external view returns (address);
    function pairToken0() external view returns (address);
    function pairToken1() external view returns (address);
    function pairToken2() external view returns (address);
    function standardExchanges() external view returns (address[] memory);
    function standardExchange(uint256 productIndex) external view returns (address);
    function vaultShares() external view returns (address[] memory);
    function vaultShare(uint256 productIndex) external view returns (address);
    function rateProviders() external view returns (address[] memory);
    function rateProvider(uint256 productIndex) external view returns (address);
    function baseAmp() external view returns (uint256);
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

    /// @notice Multi-leg bond. First: all 3 externals + capitalToken; later: exactly one external.
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

    /// @notice Mature-only: sell bond NFT → protocol LP + rebasing claim.
    function sellPositionToDetfNft(uint256 tokenId, address recipient)
        external
        returns (uint256 principalShares);

    /// @notice D25 + L2: mature close, proportional withdraw, burn DETF self-leg, pay remaining legs.
    /// @dev `minAmountsOut` length = n (binding order). DETF self-leg slot must be 0.
    function closeBondMature(
        uint256 tokenId,
        uint256[] calldata minAmountsOut,
        address recipient,
        uint256 deadline
    ) external returns (uint256[] memory amountsOut);

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

    /// @notice Redeem rebasing claim → pair | vaultShare | SE token. tokenOut=DETF → InvalidRoute.
    function redeemClaim(
        uint256 claimAmount,
        IERC20 tokenOut,
        uint256 minOut,
        address recipient,
        uint256 deadline
    ) external returns (uint256 amountOut);

    /// @notice NFT vault / claim package: unwind protocol/bond LP principal.
    function claimLiquidity(uint256 lpAmount, address recipient) external returns (uint256 amountOut);

    /// @notice Phase 0: not closed-form. Always reverts InvalidRoute.
    function mintExactDetfOut(
        IERC20 tokenIn,
        uint256 detfOut,
        uint256 maxTokenIn,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 tokenInUsed);

    /// @notice Phase 0: not closed-form through prop+redeposit+residual. Always reverts InvalidRoute.
    function burnExactTokenOut(
        IERC20 tokenOut,
        uint256 amountOut,
        uint256 maxDetfIn,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 detfInUsed);

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

/// @title IUniswapV4StandardExchangeCurveQuadStableDETDFPkg
/// @notice DFPkg interface — PkgInit / PkgArgs live HERE (Crane rule).
interface IUniswapV4StandardExchangeCurveQuadStableDETDFPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    error NotCalledByRegistry(address caller);
    error ZeroAddress();
    error InvalidCreationRate();
    error AllExternalBareForbidden();
    error SameStandardExchange();
    error RateProviderWithoutSE();
    error PairTokenNotInSeTokens();
    error DetfInSeTokens();
    error InvalidN();
    error SamePairTokens();
    error ArrayLengthMismatch();
    error InvalidCapitalToken();
    error InvalidBaseAmp();

    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;
        IFacet exchangeInFacet;
        IFacet bondingFacet;
        IFacet compoundFacet;
        IFacet infoFacet;
        IVaultFeeOracleQuery feeOracle;
        IVaultRegistryDeployment vaultRegistryDeployment;
        IPoolManager poolManager;
        IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage hookPkg;
        IDetfSelfNftInventoryDFPkg bondNftVaultPkg;
        IRebasingClaimTokenDFPkg rebasingClaimTokenPkg;
        IDiamondPackageCallBackFactory diamondFactory;
    }

    /// @dev Product-order pair legs: exactly 3. DETF binding free via address sort after diamond exists.
    /// @dev standardExchanges / rateProviders / vaultShares: product-order length 3 (0 = bare).
    /// @dev creationPairPerDetfWad: product-order length 3; each must be > 0.
    /// @dev openingPairPerDetfWad: empty or length 3; 0 per slot → that slot's creation.
    /// @dev baseAmp: hook D7 0 < baseAmp < 1_000_000.
    /// @dev Trailing expansion: zeros resolve via DETFEpochNaturalExpansionLib.
    /// @dev thresholdMode: 0 = Policy (default), 1 = Open.
    /// @dev NO whole-DETF rateAsset field.
    struct PkgArgs {
        string name;
        string symbol;
        IERC20[] pairTokens; // product order, length 3
        IStandardExchangeProxy[] standardExchanges; // product order; address(0) = bare
        IERC20[] vaultShares; // product order; address(0) → SE diamond is share when SE set
        address[] rateProviders; // product order; optional; only if SE set
        uint256[] creationPairPerDetfWad; // product order; each > 0
        /// @notice Pair per DETF on first bond. 0 → use creation (open at peg). Empty array → all creation.
        uint256[] openingPairPerDetfWad;
        uint256 baseAmp; // hook D7
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
