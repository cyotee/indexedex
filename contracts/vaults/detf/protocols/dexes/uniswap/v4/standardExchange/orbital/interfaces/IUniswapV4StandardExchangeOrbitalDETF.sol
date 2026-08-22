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
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/common/factory/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";

/// @title IUniswapV4StandardExchangeOrbitalDETF
/// @notice Info + bonding + claim surface for Uni V4 Orbital SE Buffer true DETF.
/// @dev Role names only. Bond principal = fungible hook LP. Mature-only sell/close (DETF gate).
interface IUniswapV4StandardExchangeOrbitalDETF {
    enum CapitalMode {
        None,
        Single,
        Dual
    }

    event ThresholdModeSet(ThresholdMode mode, uint256 mintThreshold, uint256 burnThreshold);
    event ProtocolRewardsCompounded(uint256 detfIn, uint256 lpOut);
    event NaturalSupplyExpanded(uint256 mintAmount, uint256 syntheticPrice, uint256 timestamp);
    event ReserveLive(uint256 firstBondTokenId, uint256 lpPrincipal);

    function isReserveLive() external view returns (bool);
    function pairToken0() external view returns (address);
    function pairToken1() external view returns (address);
    function standardExchange0() external view returns (address);
    function standardExchange1() external view returns (address);
    function vaultShare0() external view returns (address);
    function vaultShare1() external view returns (address);
    function rateProvider0() external view returns (address);
    function rateProvider1() external view returns (address);
    function rateAsset() external view returns (address);
    function detfBindingIndex() external view returns (uint8);
    function reserveHook() external view returns (address);
    /// @notice Alias of reserveHook for RebasingClaimToken rate calc (`detf.reservePool()`).
    function reservePool() external view returns (address);
    function syntheticPrice() external view returns (uint256);
    function pendingExpansionDetf() external view returns (uint256);
    function mintThreshold() external view returns (uint256);
    function burnThreshold() external view returns (uint256);
    function thresholdMode() external view returns (ThresholdMode);
    function isMintingAllowed() external view returns (bool);
    function isBurningAllowed() external view returns (bool);
    function bondNftVault() external view returns (address);
    function rebasingClaimToken() external view returns (address);
    function feeRecipientNftId() external view returns (uint256);
    function creationPair0PerDetfWad() external view returns (uint256);
    function creationPair1PerDetfWad() external view returns (uint256);
    /// @notice Pair per DETF on first bond. Resolved storage (0 at init → creation).
    function openingPair0PerDetfWad() external view returns (uint256);
    function openingPair1PerDetfWad() external view returns (uint256);
    function lastExpansionTimestamp() external view returns (uint256);
    function expansionEpochLength() external view returns (uint256);
    function expansionClosureRatePerYearWad() external view returns (uint256);
    function expansionMaxCatchUpEpochs() external view returns (uint256);
    function acceptedBondTokens() external view returns (address[] memory);
    function protocolLp() external view returns (uint256);
    function userBondedLp() external view returns (uint256);
    /// @notice Full FD residual → rateAsset WAD (includes DETF self-leg). Q21.
    function fdRateAssetWad() external view returns (uint256);
    /// @notice Pairs-only residual → rateAsset WAD (excludes DETF). For FD comparison tests.
    function fdPairsOnlyRateAssetWad() external view returns (uint256);

    /// @notice Bond capital mode for tokenId (Single/Dual).
    function capitalModeOf(uint256 tokenId) external view returns (CapitalMode);
    function capitalToken0Of(uint256 tokenId) external view returns (address);
    function capitalToken1Of(uint256 tokenId) external view returns (address);

    function compoundProtocolRewards() external returns (uint256 detfIn, uint256 lpOut);

    /// @notice Dual-leg first bond / live bond. tokenIn1 may be address(0) for single-leg after live.
    function bond(
        IERC20 tokenIn0,
        uint256 amountIn0,
        IERC20 tokenIn1,
        uint256 amountIn1,
        uint256 lockDuration,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 tokenId, uint256 shares);

    /// @notice Single-token convenience bond (after live: single-leg OK; first bond reverts both-pairs).
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

    /// @notice D25+L2: mature close. `minAmountsOut` length 3: DETF slot 0 must be 0, then pair0, pair1.
    function closeBondMature(
        uint256 tokenId,
        uint256[] calldata minAmountsOut,
        address recipient,
        uint256 deadline
    ) external returns (uint256[] memory amountsOut);

    function previewCloseBondMature(uint256 tokenId) external view returns (uint256[] memory amountsOut);

    /// @notice D18: move free DETF into reserve LP; 4626 credit on id 0; mint rebasing claim. No new DETF mint.
    function buyClaim(
        uint256 detfAmount,
        uint256 minClaimOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 claimMinted);

    function previewBuyClaim(uint256 detfAmount) external view returns (uint256 claimMinted);

    /// @notice Bond NFT only. Settle `token` and single-sided join LP to the Bond NFT. No DETF mint. No expansion.
    function joinDonatedCapital(IERC20 token, uint256 amount, uint256 deadline)
        external
        returns (uint256 lpOut);

    function previewJoinDonatedCapital(IERC20 token, uint256 amount)
        external
        view
        returns (uint256 lpOut);

    /// @notice Bond NFT only. D2 top-up after donate credits id 0.
    function notifyReserveDonated() external;

    /// @notice Forwards to Bond NFT donate with `minLpOut = 0`. Pretransfer destination is the NFT.
    function donate(IERC20 token, uint256 amount, bool pretransferred) external;

    function claimRewards(uint256 tokenId, address recipient) external returns (uint256 rewards);

    /// @notice Direct claim deposit (pair/share/SE/free DETF). Reverts if not zap-eligible.
    function depositClaim(
        IERC20 tokenIn,
        uint256 amountIn,
        uint256 minClaimOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 claimOut);

    /// @notice Redeem rebasing claim → rateAsset | other pair | vaultShare | SE token. Else InvalidRoute.
    function redeemClaim(
        uint256 claimAmount,
        IERC20 tokenOut,
        uint256 minOut,
        address recipient,
        uint256 deadline
    ) external returns (uint256 amountOut);

    /// @notice NFT vault / claim package: unwind protocol/bond LP principal (DETF-orchestrated residual).
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

/// @title IUniswapV4StandardExchangeOrbitalDETDFPkg
/// @notice DFPkg interface — PkgInit / PkgArgs live HERE (Crane rule).
interface IUniswapV4StandardExchangeOrbitalDETDFPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    error NotCalledByRegistry(address caller);
    error ZeroAddress();
    error InvalidCreationRate();
    error BothBareForbidden();
    error SameStandardExchange();
    error RateProviderWithoutSE();
    error PairTokenNotInSeTokens();
    error DetfInSeTokens();
    error InvalidDetfBindingIndex();
    error InvalidRateAsset();
    error SamePairTokens();

    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;
        IFacet exchangeInFacet; // Option 1e: exchange-only Facet
        IFacet bondingFacet; // Option 1e: bond/claim/compound Facet
        IFacet infoFacet; // view/info surface
        IVaultFeeOracleQuery feeOracle;
        IVaultRegistryDeployment vaultRegistryDeployment;
        IPoolManager poolManager;
        IUniswapV4StandardExchangeOrbitalBufferHookPackage hookPkg;
        IDetfSelfNftInventoryDFPkg bondNftVaultPkg;
        IRebasingClaimTokenDFPkg rebasingClaimTokenPkg;
        IDiamondPackageCallBackFactory diamondFactory;
    }

    /// @dev External product legs: pair0 / pair1; DETF binding free (0/1/2). ≥1 SE required.
    /// @dev Trailing expansion: zeros resolve via DETFEpochNaturalExpansionLib.
    /// @dev thresholdMode: 0 = Policy (default), 1 = Open.
    struct PkgArgs {
        string name;
        string symbol;
        IERC20 pairToken0;
        IERC20 pairToken1;
        IStandardExchangeProxy standardExchange0; // address(0) = bare
        IStandardExchangeProxy standardExchange1;
        IERC20 vaultShare0; // address(0) → SE diamond is share when SE set
        IERC20 vaultShare1;
        address rateProvider0; // optional; only if SE0 set
        address rateProvider1;
        IERC20 rateAsset; // address(0) → pairToken0; must be pair0 or pair1
        uint8 detfBindingIndex; // 0, 1, or 2
        uint256 creationPair0PerDetfWad; // required > 0
        uint256 creationPair1PerDetfWad; // required > 0
        /// @notice Pair per DETF on first bond. 0 → use creation (open at peg).
        uint256 openingPair0PerDetfWad;
        uint256 openingPair1PerDetfWad;
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
