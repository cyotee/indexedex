// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {IUniswapV4DetfBondNFTVaultDFPkg} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft/UniswapV4DetfBondNFTVaultDFPkg.sol";

/**
 * @title IUniswapV4Detf
 * @notice Unified Uni V4 DETF PkgArgs and user surface. PRD DETF_INSTANCE_IO_ROUTING §3.2 / §16.
 */
interface IUniswapV4Detf {
    enum RouteTableMode {
        Default,
        Custom
    }

    struct IoRoute {
        IERC20 token;
        IStandardExchange vault;
    }

    struct PkgArgs {
        string name;
        string symbol;
        address hook;
        uint256[] creationPairPerDetfWad;
        uint256[] openingPairPerDetfWad;
        uint256 mintThreshold;
        uint256 burnThreshold;
        ThresholdMode thresholdMode;
        uint256 expansionEpochLength;
        uint256 expansionClosureRatePerYearWad;
        uint256 expansionMaxCatchUpEpochs;
        address creator;
        string claimName;
        string claimSymbol;
        string bondName;
        string bondSymbol;
        RouteTableMode mintRouteMode;
        IoRoute[] mintRoutes;
        RouteTableMode burnRouteMode;
        IoRoute[] burnRoutes;
        RouteTableMode bondRouteMode;
        IoRoute[] bondRoutes;
        RouteTableMode closeRouteMode;
        IoRoute[] closeRoutes;
        RouteTableMode donateRouteMode;
        IoRoute[] donateRoutes;
    }

    event ThresholdModeSet(ThresholdMode mode, uint256 mintThreshold, uint256 burnThreshold);
    event ProtocolRewardsCompounded(uint256 detfIn, uint256 lpOut);
    event NaturalSupplyExpanded(uint256 mintAmount, uint256 syntheticPrice, uint256 timestamp);
    event ReserveLive(uint256 firstBondTokenId, uint256 lpPrincipal);
    event ReserveBondNftWired(
        address indexed reserveHook, address bondNftVault, uint256 detfNftId, uint256 feeRecipientNftId
    );
    event ReserveClaimWired(address indexed reserveHook, address rebasingClaimToken);

    function hook() external view returns (address);

    function reservePool() external view returns (address);

    function isReserveLive() external view returns (bool);

    function isReserveWired() external view returns (bool);

    function mintRoutes() external view returns (IoRoute[] memory);

    function burnRoutes() external view returns (IoRoute[] memory);

    function bondRoutes() external view returns (IoRoute[] memory);

    function closeRoutes() external view returns (IoRoute[] memory);

    function donateRoutes() external view returns (IoRoute[] memory);

    function mintRouteMode() external view returns (RouteTableMode);

    function burnRouteMode() external view returns (RouteTableMode);

    function bondRouteMode() external view returns (RouteTableMode);

    function closeRouteMode() external view returns (RouteTableMode);

    function donateRouteMode() external view returns (RouteTableMode);

    function creationPairPerDetfWad() external view returns (uint256[] memory);

    function openingPairPerDetfWad() external view returns (uint256[] memory);

    function mintThreshold() external view returns (uint256);

    function burnThreshold() external view returns (uint256);

    function thresholdMode() external view returns (ThresholdMode);

    function syntheticPrice() external view returns (uint256);

    function pendingExpansionDetf() external view returns (uint256);

    function bondNftVault() external view returns (address);

    function detfNFTVault() external view returns (IDETFNFTVault);

    function rebasingClaimToken() external view returns (address);

    function acceptedBondTokens() external view returns (address[] memory);

    function previewMint(IERC20 tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 grossDetf, uint256 userDetf, uint256 lpOut);

    function mint(
        IERC20 tokenIn,
        uint256 amountIn,
        uint256 minUserDetf,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 userDetf);

    function previewBurn(uint256 detfIn, IERC20 tokenOut) external view returns (uint256 amountOut);

    function burn(
        uint256 detfIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        uint256 deadline
    ) external returns (uint256 amountOut);

    function bond(
        IERC20 tokenIn,
        uint256 amountIn,
        uint256 lockDuration,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 tokenId, uint256 shares);

    function closeBondMature(
        uint256 tokenId,
        uint256[] calldata minAmountsOut,
        address recipient,
        uint256 deadline
    ) external returns (uint256[] memory amountsOut);

    function previewCloseBondMature(uint256 tokenId) external view returns (uint256[] memory amountsOut);

    function donate(IERC20 token, uint256 amount, bool pretransferred) external;

    function sweepDust() external;

    function isMintingAllowed() external view returns (bool);

    function isMintingAllowed(IERC20 tokenIn) external view returns (bool);

    function isBurningAllowed() external view returns (bool);

    function isBurningAllowed(IERC20 tokenOut) external view returns (bool);

    function compoundProtocolRewards() external returns (uint256 detfIn, uint256 lpOut);

    /// @notice Preview DETF paid if `lpAmount` of hook LP is unwound (claim/NFT path).
    function previewClaimLiquidity(uint256 lpAmount) external view returns (uint256 detfOut);

    /// @notice Unwind hook LP and pay DETF to `recipient`. Bond NFT and claim token only.
    /// @dev Selector must match `IDetf.claimLiquidity` (`0xcaaf4702`). Claim-token redeem
    ///      harvests pending DETF first and skips LP withdraw when pending covers owed.
    function claimLiquidity(uint256 lpAmount, address recipient) external returns (uint256 detfOut);

    function joinDonatedCapital(IERC20 token, uint256 amount, uint256 deadline)
        external
        returns (uint256 lpOut);

    function previewJoinDonatedCapital(IERC20 token, uint256 amount)
        external
        view
        returns (uint256 lpOut);

    function notifyReserveDonated() external;

    function completeReserveBondNft() external returns (address bondNftVault);

    function completeReserveClaim() external returns (address rebasingClaimToken);
}

/**
 * @title IUniswapV4DetfDFPkg
 * @notice DFPkg interface — PkgInit / PkgArgs live HERE (Crane rule).
 */
interface IUniswapV4DetfDFPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    error NotCalledByRegistry(address caller);
    error ZeroAddress();
    error InvalidHook();
    error DetfNotInHookTokens();
    error HookOwnerMismatch();
    error BarePairForbidden();
    error InvalidCloseRoutes();
    error DuplicateRoute(address token);
    error InvalidCreationRate();
    error InvalidRouteTable();

    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;
        IFacet productFacet;
        IVaultFeeOracleQuery feeOracle;
        IVaultRegistryDeployment vaultRegistryDeployment;
        IUniswapV4DetfBondNFTVaultDFPkg bondNftVaultPkg;
        IRebasingClaimTokenDFPkg rebasingClaimTokenPkg;
    }

    function deployVault(IUniswapV4Detf.PkgArgs memory args) external returns (address vault);
}
