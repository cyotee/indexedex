// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondCut} from "@crane/contracts/interfaces/IDiamondCut.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IRouter} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IRouter.sol";
import {IPoolFactory} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPoolFactory.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {EIP712Repo} from "@crane/contracts/utils/cryptography/EIP712/EIP712Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";
import {
    AerodromePoolMetadataRepo
} from "@crane/contracts/protocols/dexes/aerodrome/v1/aware/AerodromePoolMetadataRepo.sol";
import {
    AerodromeRouterAwareRepo
} from "@crane/contracts/protocols/dexes/aerodrome/v1/aware/AerodromeRouterAwareRepo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVautlFeeOracleQueryAware} from "contracts/interfaces/IVautlFeeOracleQueryAware.sol";
import {

    // BondTerms,
    // DexTerms,
    // KinkLendingTerms,
    VaultFeeType,
    VaultFeeTypeIds
} from "contracts/interfaces/VaultFeeTypes.sol";
import {VaultTypeUtils} from "contracts/registries/vault/VaultTypeUtils.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {ConstProdReserveVaultRepo} from "contracts/vaults/ConstProdReserveVaultRepo.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {ConstProdUtils} from "@crane/contracts/utils/math/ConstProdUtils.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";

interface IAerodromeStandardExchangeDFPkg is IDiamondFactoryPackage, IStandardVaultPkg {

    error NotCalledByRegistry(address caller);

    error NotAerodromeV1Pool(IPool pool);

    error PoolMustNotBeStable(IPool pool);

    error PoolCreationFailed();

    error RecipientRequiredForDeposit();

    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet erc4626Facet;
        IFacet erc4626BasicVaultFacet;
        IFacet erc4626StandardVaultFacet;
        IFacet aerodromeStandardExchangeInFacet;
        IFacet aerodromeStandardExchangeOutFacet;
        IVaultFeeOracleQuery vaultFeeOracleQuery;
        IVaultRegistryDeployment vaultRegistryDeployment;
        IPermit2 permit2;
        IRouter aerodromeRouter;
        IPoolFactory aerodromePoolFactory;
    }

    struct PkgArgs {
        IPool reserveAsset;
    }

    struct DeployWithPoolResult {
        bool poolExists;
        uint256 proportionalA;
        uint256 proportionalB;
        uint256 expectedLP;
    }

    function deployVault(IPool pool) external returns (address vault);

    function deployVault(IERC20 tokenA, uint256 tokenAAmount, IERC20 tokenB, uint256 tokenBAmount, address recipient)
        external
        returns (address vault);

    function previewDeployVault(IERC20 tokenA, uint256 tokenAAmount, IERC20 tokenB, uint256 tokenBAmount)
        external
        view
        returns (DeployWithPoolResult memory result);
}

contract AerodromeStandardExchangeDFPkg is IAerodromeStandardExchangeDFPkg {
    using BetterEfficientHashLib for bytes;
    using BetterMath for uint256;
    using BetterSafeERC20 for IERC20;
    using BetterSafeERC20 for IERC20Metadata;
    // using BetterSafeERC20 for IPool;

    AerodromeStandardExchangeDFPkg SELF;

    IFacet immutable ERC20_FACET;
    IFacet immutable ERC5267_FACET;
    IFacet immutable ERC2612_FACET;
    IFacet immutable ERC4626_FACET;
    IFacet immutable ERC4626_BASIC_VAULT_FACET;
    IFacet immutable ERC4626_STANDARD_VAULT_FACET;
    IFacet immutable AERODROME_STANDARD_EXCHANGE_IN_FACET;
    IFacet immutable AERODROME_STANDARD_EXCHANGE_OUT_FACET;
    IVaultFeeOracleQuery immutable VAULT_FEE_ORACLE_QUERY;
    IVaultRegistryDeployment immutable VAULT_REGISTRY_DEPLOYMENT;
    IPermit2 immutable PERMIT2;
    IRouter immutable AERODROME_ROUTER;
    IPoolFactory immutable AERODROME_POOL_FACTORY;

    constructor(PkgInit memory pkgInit) {
        SELF = this;
        ERC20_FACET = pkgInit.erc20Facet;
        ERC5267_FACET = pkgInit.erc5267Facet;
        ERC2612_FACET = pkgInit.erc2612Facet;
        ERC4626_FACET = pkgInit.erc4626Facet;
        ERC4626_BASIC_VAULT_FACET = pkgInit.erc4626BasicVaultFacet;
        ERC4626_STANDARD_VAULT_FACET = pkgInit.erc4626StandardVaultFacet;
        AERODROME_STANDARD_EXCHANGE_IN_FACET = pkgInit.aerodromeStandardExchangeInFacet;
        AERODROME_STANDARD_EXCHANGE_OUT_FACET = pkgInit.aerodromeStandardExchangeOutFacet;
        VAULT_FEE_ORACLE_QUERY = pkgInit.vaultFeeOracleQuery;
        VAULT_REGISTRY_DEPLOYMENT = pkgInit.vaultRegistryDeployment;
        PERMIT2 = pkgInit.permit2;
        AERODROME_ROUTER = pkgInit.aerodromeRouter;
        AERODROME_POOL_FACTORY = pkgInit.aerodromePoolFactory;
    }

    /* -------------------------------------------------------------------------- */
    /*                      IAerodromeStandardExchangeDFPkg                       */
    /* -------------------------------------------------------------------------- */

    function deployVault(IPool pool) public returns (address vault) {
        vault = VAULT_REGISTRY_DEPLOYMENT.deployVault(SELF, abi.encode(PkgArgs({reserveAsset: pool})));
    }

    /**
     * @notice Deploy a vault for a token pair, optionally creating the pool and providing initial liquidity.
     * @param tokenA First token of the pair
     * @param tokenAAmount Amount of tokenA to deposit (0 for no deposit)
     * @param tokenB Second token of the pair
     * @param tokenBAmount Amount of tokenB to deposit (0 for no deposit)
     * @param recipient Address to receive vault shares (address(0) for no deposit)
     * @return vault Address of the deployed vault
     */
    function deployVault(IERC20 tokenA, uint256 tokenAAmount, IERC20 tokenB, uint256 tokenBAmount, address recipient)
        public
        returns (address vault)
    {
        // Step 1: Get or create the volatile pool
        IPool pool = _getOrCreatePool(tokenA, tokenB);

        // Step 2: Handle initial deposit if amounts provided
        uint256 lpTokensMinted = 0;
        if (tokenAAmount > 0 && tokenBAmount > 0) {
            if (recipient == address(0)) {
                revert RecipientRequiredForDeposit();
            }
            lpTokensMinted = _depositLiquidity(pool, tokenA, tokenAAmount, tokenB, tokenBAmount);
        }

        // Step 3: Deploy vault via existing deployVault(pool)
        vault = deployVault(pool);

        // Step 4: If LP tokens were minted, deposit them to vault for recipient
        if (lpTokensMinted > 0) {
            IERC20 lpToken = IERC20(address(pool));
            lpToken.safeTransfer(vault, lpTokensMinted);
            IStandardExchangeIn(vault)
                .exchangeIn(
                    lpToken,
                    lpTokensMinted,
                    IERC20(vault), // vault share token is the vault itself
                    0, // no minimum - user already approved the action
                    recipient,
                    true, // pretransferred - tokens already sent to vault
                    block.timestamp + 1
                );
        }

        return vault;
    }

    /**
     * @notice Preview the proportional amounts and expected LP for a deployVault call.
     * @param tokenA First token of the pair
     * @param tokenAAmount Maximum amount of tokenA willing to deposit
     * @param tokenB Second token of the pair
     * @param tokenBAmount Maximum amount of tokenB willing to deposit
     * @return result The preview result with pool existence, proportional amounts, and expected LP
     */
    function previewDeployVault(IERC20 tokenA, uint256 tokenAAmount, IERC20 tokenB, uint256 tokenBAmount)
        public
        view
        returns (DeployWithPoolResult memory result)
    {
        // Check if pool exists
        address poolAddr = AERODROME_POOL_FACTORY.getPool(address(tokenA), address(tokenB), false);
        result.poolExists = poolAddr != address(0);

        if (!result.poolExists || (tokenAAmount == 0 && tokenBAmount == 0)) {
            // New pool or no deposit - use amounts as provided
            result.proportionalA = tokenAAmount;
            result.proportionalB = tokenBAmount;
            // For new pool, LP = sqrt(amountA * amountB) - MINIMUM_LIQUIDITY
            // For no deposit, expectedLP = 0
            if (tokenAAmount > 0 && tokenBAmount > 0) {
                result.expectedLP = _calcNewPoolLP(tokenAAmount, tokenBAmount);
            }
            return result;
        }

        // Existing pool - calculate proportional amounts in scoped block
        IPool pool = IPool(poolAddr);
        uint256 reserveA;
        uint256 reserveB;

        {
            (uint256 reserve0, uint256 reserve1,) = pool.getReserves();
            bool tokenAIsToken0 = address(tokenA) == pool.token0();
            reserveA = tokenAIsToken0 ? reserve0 : reserve1;
            reserveB = tokenAIsToken0 ? reserve1 : reserve0;
        }

        // Calculate proportional amounts based on reserves
        (result.proportionalA, result.proportionalB) =
            _proportionalDeposit(reserveA, reserveB, tokenAAmount, tokenBAmount);

        // Calculate expected LP tokens in scoped block
        {
            uint256 totalSupply = IERC20(address(pool)).totalSupply();
            if (totalSupply == 0) {
                result.expectedLP = _calcNewPoolLP(result.proportionalA, result.proportionalB);
            } else {
                // min(proportionalA * totalSupply / reserveA, proportionalB * totalSupply / reserveB)
                uint256 lpFromA = (result.proportionalA * totalSupply) / reserveA;
                uint256 lpFromB = (result.proportionalB * totalSupply) / reserveB;
                result.expectedLP = lpFromA < lpFromB ? lpFromA : lpFromB;
            }
        }

        return result;
    }

    /**
     * @dev Calculate expected LP for a new pool (sqrt(a*b) - MINIMUM_LIQUIDITY).
     */
    function _calcNewPoolLP(uint256 amountA, uint256 amountB) internal pure returns (uint256 expectedLP) {
        expectedLP = BetterMath._sqrt(amountA * amountB);
        // Subtract minimum liquidity (1000)
        if (expectedLP > 1000) {
            expectedLP -= 1000;
        } else {
            expectedLP = 0;
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                              Internal Functions                            */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev Get or create a volatile pool for the token pair.
     */
    function _getOrCreatePool(IERC20 tokenA, IERC20 tokenB) internal returns (IPool pool) {
        address poolAddr = AERODROME_POOL_FACTORY.getPool(address(tokenA), address(tokenB), false);
        if (poolAddr == address(0)) {
            poolAddr = AERODROME_POOL_FACTORY.createPool(address(tokenA), address(tokenB), false);
            if (poolAddr == address(0)) {
                revert PoolCreationFailed();
            }
        }
        return IPool(poolAddr);
    }

    /**
     * @dev Deposit liquidity to pool and return amount of LP tokens minted.
     * Uses block scoping to avoid stack-too-deep errors.
     */
    function _depositLiquidity(IPool pool, IERC20 tokenA, uint256 tokenAAmount, IERC20 tokenB, uint256 tokenBAmount)
        internal
        returns (uint256 lpTokensMinted)
    {
        uint256 amountA;
        uint256 amountB;

        // Calculate proportional amounts
        {
            (uint256 reserve0, uint256 reserve1,) = pool.getReserves();
            bool tokenAIsToken0 = address(tokenA) == pool.token0();
            uint256 reserveA = tokenAIsToken0 ? reserve0 : reserve1;
            uint256 reserveB = tokenAIsToken0 ? reserve1 : reserve0;

            (amountA, amountB) = _proportionalDeposit(reserveA, reserveB, tokenAAmount, tokenBAmount);
        }

        // Transfer tokens and mint LP in a separate scope
        {
            address poolAddr = address(pool);
            tokenA.safeTransferFrom(msg.sender, poolAddr, amountA);
            tokenB.safeTransferFrom(msg.sender, poolAddr, amountB);
            lpTokensMinted = pool.mint(address(this));
        }
    }

    /**
     * @dev Core proportional deposit calculation. Given reserves and desired amounts,
     *      returns the maximum proportional amounts that never exceed the provided limits.
     *      Used by both _depositLiquidity (execution) and previewDeployVault (read-only).
     */
    function _proportionalDeposit(uint256 reserveA, uint256 reserveB, uint256 amountA, uint256 amountB)
        internal
        pure
        returns (uint256 depositA, uint256 depositB)
    {
        if (reserveA == 0 || reserveB == 0) {
            return (amountA, amountB);
        }

        uint256 optimalB = ConstProdUtils._equivLiquidity(amountA, reserveA, reserveB);
        if (optimalB <= amountB) {
            return (amountA, optimalB);
        }
        return ((amountB * reserveA) / reserveB, amountB);
    }

    // /**
    //  * @dev Integer square root using Babylonian method.
    //  */
    // function _sqrt(uint256 x) internal pure returns (uint256) {
    //     if (x == 0) return 0;
    //     uint256 z = (x + 1) / 2;
    //     uint256 y = x;
    //     while (z < y) {
    //         y = z;
    //         z = (x / z + z) / 2;
    //     }
    //     return y;
    // }

    /* -------------------------------------------------------------------------- */
    /*                              IStandardVaultPkg                             */
    /* -------------------------------------------------------------------------- */

    function name() public pure returns (string memory) {
        return packageName();
    }

    function vaultFeeTypeIds() public pure returns (bytes32 vaultFeeTypeIds_) {
        return VaultTypeUtils._insertFeeTypeId(vaultFeeTypeIds_, VaultFeeType.USAGE, type(IStandardVault).interfaceId);
    }

    function vaultTypes() public pure returns (bytes4[] memory typeIDs) {
        return facetInterfaces();
    }

    function vaultDeclaration() public pure returns (VaultPkgDeclaration memory declaration) {
        return VaultPkgDeclaration({name: name(), vaultFeeTypeIds: vaultFeeTypeIds(), vaultTypes: vaultTypes()});
    }

    /* -------------------------------------------------------------------------- */
    /*                           IDiamondFactoryPackage                           */
    /* -------------------------------------------------------------------------- */

    function packageName() public pure returns (string memory name_) {
        return type(AerodromeStandardExchangeDFPkg).name;
    }

    function facetAddresses() public view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](8);
        facetAddresses_[0] = address(ERC20_FACET);
        facetAddresses_[1] = address(ERC5267_FACET);
        facetAddresses_[2] = address(ERC2612_FACET);
        facetAddresses_[3] = address(ERC4626_FACET);
        facetAddresses_[4] = address(ERC4626_BASIC_VAULT_FACET);
        facetAddresses_[5] = address(ERC4626_STANDARD_VAULT_FACET);
        facetAddresses_[6] = address(AERODROME_STANDARD_EXCHANGE_IN_FACET);
        facetAddresses_[7] = address(AERODROME_STANDARD_EXCHANGE_OUT_FACET);
        return facetAddresses_;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](11);

        interfaces[0] = type(IERC20).interfaceId;
        interfaces[1] = type(IERC20Metadata).interfaceId;
        interfaces[2] = type(IERC20Metadata).interfaceId ^ type(IERC20).interfaceId;
        interfaces[3] = type(IERC20Permit).interfaceId;
        interfaces[4] = type(IERC5267).interfaceId;
        interfaces[5] = type(IERC4626).interfaceId;
        interfaces[6] = type(IBasicVault).interfaceId;
        interfaces[7] = type(IStandardVault).interfaceId;
        interfaces[8] = type(IStandardExchangeIn).interfaceId;
        interfaces[9] = type(IStandardExchangeOut).interfaceId;
        interfaces[10] = type(IVautlFeeOracleQueryAware).interfaceId;
        return interfaces;
    }

    function packageMetadata()
        public
        view
        returns (string memory name_, bytes4[] memory interfaces, address[] memory facets)
    {
        name_ = packageName();
        interfaces = facetInterfaces();
        facets = facetAddresses();
    }

    function facetCuts() public view returns (IDiamond.FacetCut[] memory facetCuts_) {
        facetCuts_ = new IDiamond.FacetCut[](8);

        facetCuts_[0] = IDiamond.FacetCut({
            // address facetAddress;
            facetAddress: address(ERC20_FACET),
            // FacetCutAction action;
            action: IDiamond.FacetCutAction.Add,
            // bytes4[] functionSelectors;
            functionSelectors: ERC20_FACET.facetFuncs()
        });
        facetCuts_[1] = IDiamond.FacetCut({
            // address facetAddress;
            facetAddress: address(ERC5267_FACET),
            // FacetCutAction action;
            action: IDiamond.FacetCutAction.Add,
            // bytes4[] functionSelectors;
            functionSelectors: ERC5267_FACET.facetFuncs()
        });
        facetCuts_[2] = IDiamond.FacetCut({
            // address facetAddress;
            facetAddress: address(ERC2612_FACET),
            // FacetCutAction action;
            action: IDiamond.FacetCutAction.Add,
            // bytes4[] functionSelectors;
            functionSelectors: ERC2612_FACET.facetFuncs()
        });
        facetCuts_[3] = IDiamond.FacetCut({
            // address facetAddress;
            facetAddress: address(ERC4626_FACET),
            // FacetCutAction action;
            action: IDiamond.FacetCutAction.Add,
            // bytes4[] functionSelectors;
            functionSelectors: ERC4626_FACET.facetFuncs()
        });
        facetCuts_[4] = IDiamond.FacetCut({
            // address facetAddress;
            facetAddress: address(ERC4626_BASIC_VAULT_FACET),
            // FacetCutAction action;
            action: IDiamond.FacetCutAction.Add,
            // bytes4[] functionSelectors;
            functionSelectors: ERC4626_BASIC_VAULT_FACET.facetFuncs()
        });
        facetCuts_[5] = IDiamond.FacetCut({
            // address facetAddress;
            facetAddress: address(ERC4626_STANDARD_VAULT_FACET),
            // FacetCutAction action;
            action: IDiamond.FacetCutAction.Add,
            // bytes4[] functionSelectors;
            functionSelectors: ERC4626_STANDARD_VAULT_FACET.facetFuncs()
        });
        facetCuts_[6] = IDiamond.FacetCut({
            // address facetAddress;
            facetAddress: address(AERODROME_STANDARD_EXCHANGE_IN_FACET),
            // FacetCutAction action;
            action: IDiamond.FacetCutAction.Add,
            // bytes4[] functionSelectors;
            functionSelectors: AERODROME_STANDARD_EXCHANGE_IN_FACET.facetFuncs()
        });
        facetCuts_[7] = IDiamond.FacetCut({
            // address facetAddress;
            facetAddress: address(AERODROME_STANDARD_EXCHANGE_OUT_FACET),
            // FacetCutAction action;
            action: IDiamond.FacetCutAction.Add,
            // bytes4[] functionSelectors;
            functionSelectors: AERODROME_STANDARD_EXCHANGE_OUT_FACET.facetFuncs()
        });
    }

    /**
     * @return config Unified function to retrieved `facetInterfaces()` AND `facetCuts()` in one call.
     */
    function diamondConfig() public view returns (DiamondConfig memory config) {
        config = IDiamondFactoryPackage.DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    function calcSalt(bytes memory pkgArgs) public pure returns (bytes32 salt) {
        // return keccak256(abi.encode(pkgArgs));
        return abi.encode(pkgArgs)._hash();
    }

    function processArgs(bytes memory pkgArgs) public view returns (bytes memory processedPkgArgs) {
        if (msg.sender != address(VAULT_REGISTRY_DEPLOYMENT)) {
            revert NotCalledByRegistry(msg.sender);
        }
        (PkgArgs memory decodedArgs) = abi.decode(pkgArgs, (PkgArgs));
        if (!AERODROME_POOL_FACTORY.isPool(address(decodedArgs.reserveAsset))) {
            revert NotAerodromeV1Pool(decodedArgs.reserveAsset);
        }
        if (decodedArgs.reserveAsset.stable()) {
            revert PoolMustNotBeStable(decodedArgs.reserveAsset);
        }
        return pkgArgs;
    }

    function updatePkg(
        address, // expectedProxy,
        bytes memory // pkgArgs
    )
        public
        pure
        virtual
        returns (bool)
    {
        return true;
    }

    function initAccount(bytes memory initArgs) public {
        (PkgArgs memory decodedArgs) = abi.decode(initArgs, (PkgArgs));
        address token0 = decodedArgs.reserveAsset.token0();
        address token1 = decodedArgs.reserveAsset.token1();
        string memory name_ = "Pachira Vault (";
        name_ = string.concat(name_, IERC20Metadata(token0).safeSymbol(), " / ");
        name_ = string.concat(name_, IERC20Metadata(token1).safeSymbol(), ") via ");
        name_ = string.concat(name_, IERC20Metadata(address(decodedArgs.reserveAsset)).safeSymbol());
        uint8 reserveDecimals = IERC20Metadata(address(decodedArgs.reserveAsset)).safeDecimals();
        // Balancer V3 only supports tokens with <= 18 decimals.
        // This vault can be used as a pool token, so we keep share decimals equal to the reserve asset.
        ERC20Repo._initialize(
            // string memory name,
            name_,
            // string memory symbol,
            "PACHIRA",
            // uint8 decimals,
            reserveDecimals
        );
        EIP712Repo._initialize(
            // string memory name,
            name_,
            // string memory version
            "1"
        );
        ERC4626Repo._initialize(
            // IERC20Metadata reserveAsset,
            IERC20(address(decodedArgs.reserveAsset)),
            reserveDecimals,
            // uint8 decimalOffset
            0
        );
        address[] memory vaultTokens = new address[](1);
        vaultTokens[0] = address(decodedArgs.reserveAsset);
        bytes32 contentsId = abi.encode(vaultTokens)._hash();
        StandardVaultRepo._initialize(
            // IVaultFeeOracleQuery feeOracle,
            VAULT_FEE_ORACLE_QUERY,
            // bytes32 vaultFeeTypeIds,
            vaultFeeTypeIds(),
            // bytes4[] memory vaultTypes,
            vaultTypes(),
            // bytes32 contentsId
            contentsId
        );
        VaultFeeOracleQueryAwareRepo._initialize(VAULT_FEE_ORACLE_QUERY);
        AerodromeRouterAwareRepo._initialize(AERODROME_ROUTER);
        ConstProdReserveVaultRepo._initialize(
            // address token0_,
            token0,
            // address token1_
            token1
        );
        AerodromePoolMetadataRepo._initialize(IPoolFactory(decodedArgs.reserveAsset.factory()), false);
        Permit2AwareRepo._initialize(PERMIT2);
    }

    function postDeploy(address) public pure returns (bool) {
        return true;
    }
}
