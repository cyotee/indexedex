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
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";

/// @title IUniswapV4SingleStandardExchangeDETF
/// @notice Info + bonding + claim surface for Uni V4 Single SE CP-buffer true DETF.
interface IUniswapV4SingleStandardExchangeDETF {
    event ThresholdModeSet(ThresholdMode mode, uint256 mintThreshold, uint256 burnThreshold);
    event ProtocolRewardsCompounded(uint256 detfIn, uint256 lpOut);
    event NaturalSupplyExpanded(uint256 mintAmount, uint256 syntheticPrice, uint256 timestamp);
    event ReserveLive(uint256 firstBondTokenId, uint256 lpPrincipal);

    function isReserveLive() external view returns (bool);
    function standardExchangeVault() external view returns (address);
    function standardExchangeVaultShare() external view returns (address);
    function pairToken() external view returns (address);
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
    function creationPairPerDetfWad() external view returns (uint256);
    /// @notice Pair per DETF on first bond. Resolved storage (0 at init → creation; never 0 if creation was valid).
    function openingPairPerDetfWad() external view returns (uint256);
    function lastExpansionTimestamp() external view returns (uint256);
    function expansionEpochLength() external view returns (uint256);
    function expansionClosureRatePerYearWad() external view returns (uint256);
    function expansionMaxCatchUpEpochs() external view returns (uint256);
    function acceptedBondTokens() external view returns (address[] memory);
    function protocolLp() external view returns (uint256);
    function userBondedLp() external view returns (uint256);

    function compoundProtocolRewards() external returns (uint256 detfIn, uint256 lpOut);

    function bond(
        IERC20 tokenIn,
        uint256 amountIn,
        uint256 lockDuration,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 tokenId, uint256 shares);

    /// @notice Sell bond NFT to protocol; mint rebasing claim to recipient (when claim package wired).
    function sellPositionToDetfNft(uint256 tokenId, address recipient)
        external
        returns (uint256 principalShares);

    function claimRewards(uint256 tokenId, address recipient) external returns (uint256 rewards);

    /// @notice D18: move provided DETF into liquidity; 4626 to id 0; mint claim. No new DETF mint.
    function buyClaim(
        uint256 detfAmount,
        uint256 minClaimOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 claimMinted);

    function previewBuyClaim(uint256 detfAmount) external view returns (uint256 claimMinted);

    /// @notice D25 + L2: mature close. `minAmountsOut[0]` is the DETF self-leg and must be 0.
    function closeBondMature(
        uint256 tokenId,
        uint256[] calldata minAmountsOut,
        address recipient,
        uint256 deadline
    ) external returns (uint256[] memory amountsOut);

    function previewCloseBondMature(uint256 tokenId) external view returns (uint256[] memory amountsOut);

    /// @notice D15: redeem rebasing claim → DETF only. Else InvalidRoute.
    function redeemClaim(
        uint256 claimAmount,
        IERC20 tokenOut,
        uint256 minOut,
        address recipient,
        uint256 deadline
    ) external returns (uint256 amountOut);

    function previewRedeemClaim(uint256 claimAmount, IERC20 tokenOut) external view returns (uint256 amountOut);

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

    /// @notice Forwards to Bond NFT donate with `minLpOut = 0`. Pretransfer destination is the NFT. Void ABI freeze.
    function donate(IERC20 token, uint256 amount, bool pretransferred) external;

    /// @notice NFT vault / claim package: unwind protocol LP principal to pair for recipient.
    function claimLiquidity(uint256 lpAmount, address recipient) external returns (uint256 pairOut);

    /// @notice Zapout quote of `lpAmount` reserve LP to pairToken (claim rebase).
    function previewClaimLiquidity(uint256 lpAmount) external view returns (uint256 pairOut);

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

/// @title IUniswapV4SingleStandardExchangeDETDFPkg
/// @notice DFPkg interface — PkgInit / PkgArgs live HERE (Crane rule).
interface IUniswapV4SingleStandardExchangeDETDFPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    error NotCalledByRegistry(address caller);
    error PairTokenNotInSeTokens();
    error DetfInSeTokens();
    error InvalidCreationRate();
    error ZeroAddress();

    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;
        IFacet exchangeInFacet;
        IVaultFeeOracleQuery feeOracle;
        IVaultRegistryDeployment vaultRegistryDeployment;
        IPoolManager poolManager;
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage hookPkg;
        IDetfSelfNftInventoryDFPkg bondNftVaultPkg;
        IRebasingClaimTokenDFPkg rebasingClaimTokenPkg;
        IDiamondPackageCallBackFactory diamondFactory;
    }

    /// @dev Trailing expansion: zeros resolve via DETFEpochNaturalExpansionLib (epoch 8h, 10%/yr, unlimited catch-up).
    /// @dev thresholdMode: 0 = Policy (default), 1 = Open. Never infer Open from zero thresholds.
    struct PkgArgs {
        string name;
        string symbol;
        IStandardExchangeProxy standardExchangeVault;
        IERC20 standardExchangeVaultShare; // address(0) → vault diamond is share
        IERC20 pairToken;
        uint256 creationPairPerDetfWad; // required non-zero; pair per DETF at 1e18 scale (peg)
        /// @notice Pair per DETF on first bond. 0 → use creation (open at peg).
        uint256 openingPairPerDetfWad;
        uint256 mintThreshold; // 0 → 1.05e18
        uint256 burnThreshold; // 0 → 0.95e18
        ThresholdMode thresholdMode; // 0 = Policy
        uint256 expansionEpochLength; // 0 → 8 hours
        uint256 expansionClosureRatePerYearWad; // 0 → 0.10e18
        uint256 expansionMaxCatchUpEpochs; // 0 = unlimited (kept)
        address creator; // D26; 0 → feeTo owns id 2 (D21)
        /// @notice Rebasing claim ERC-20 name. Empty → DETF name + " Claim".
        string claimName;
        /// @notice Rebasing claim ERC-20 symbol. Empty → DETF symbol + "IR".
        string claimSymbol;
        /// @notice Bond NFT name. Empty → DETF name + " Bond".
        string bondName;
        /// @notice Bond NFT symbol. Empty → DETF symbol + "-BOND".
        string bondSymbol;
    }

    function deployVault(PkgArgs memory args, uint256 mineNonce) external returns (address vault);
}
