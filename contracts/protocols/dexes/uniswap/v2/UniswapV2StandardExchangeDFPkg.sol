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
import {IUniswapV2Router} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Router.sol";
import {IUniswapV2Factory} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {EIP712Repo} from "@crane/contracts/utils/cryptography/EIP712/EIP712Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";
import {
    UniswapV2FactoryAwareRepo
} from "@crane/contracts/protocols/dexes/uniswap/v2/aware/UniswapV2FactoryAwareRepo.sol";
import {UniswapV2RouterAwareRepo} from "@crane/contracts/protocols/dexes/uniswap/v2/aware/UniswapV2RouterAwareRepo.sol";
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

interface IUniswapV2StandardExchangeDFPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet erc4626Facet;
        IFacet erc4626BasicVaultFacet;
        IFacet erc4626StandardVaultFacet;
        IFacet uniswapV2StandardExchangeInFacet;
        IFacet uniswapV2StandardExchangeOutFacet;
        IVaultFeeOracleQuery vaultFeeOracleQuery;
        IVaultRegistryDeployment vaultRegistryDeployment;
        IPermit2 permit2;
        IUniswapV2Factory uniswapV2Factory;
        IUniswapV2Router uniswapV2Router;
    }

    struct PkgArgs {
        IUniswapV2Pair reserveAsset;
    }

    struct DeployWithPoolResult {
        bool pairExists;
        uint256 proportionalA;
        uint256 proportionalB;
        uint256 expectedLP;
    }

    struct DeployWithPoolParams {
        IERC20 tokenA;
        uint256 tokenAAmount;
        IERC20 tokenB;
        uint256 tokenBAmount;
        address recipient;
    }

    error NotCalledByRegistry(address caller);

    error PairCreationFailed();

    error RecipientRequiredForDeposit();

    function deployVault(IUniswapV2Pair pool) external returns (address vault);

    function deployVault(IERC20 tokenA, uint256 tokenAAmount, IERC20 tokenB, uint256 tokenBAmount, address recipient)
        external
        returns (address vault);

    function previewDeployVault(IERC20 tokenA, uint256 tokenAAmount, IERC20 tokenB, uint256 tokenBAmount)
        external
        view
        returns (DeployWithPoolResult memory result);
}

contract UniswapV2StandardExchangeDFPkg is IUniswapV2StandardExchangeDFPkg {
    using BetterEfficientHashLib for bytes;
    using BetterSafeERC20 for IERC20;
    using BetterSafeERC20 for IERC20Metadata;
    using BetterSafeERC20 for IUniswapV2Pair;

    UniswapV2StandardExchangeDFPkg SELF;

    IFacet immutable ERC20_FACET;
    IFacet immutable ERC5267_FACET;
    IFacet immutable ERC2612_FACET;
    IFacet immutable ERC4626_FACET;
    IFacet immutable ERC4626_BASIC_VAULT_FACET;
    IFacet immutable ERC4626_STANDARD_VAULT_FACET;
    IFacet immutable UNISWAP_V2_STANDARD_EXCHANGE_IN_FACET;
    IFacet immutable UNISWAP_V2_STANDARD_EXCHANGE_OUT_FACET;
    IVaultFeeOracleQuery immutable VAULT_FEE_ORACLE_QUERY;
    IVaultRegistryDeployment immutable VAULT_REGISTRY_DEPLOYMENT;
    IPermit2 immutable PERMIT2;
    IUniswapV2Factory immutable UNISWAP_V2_FACTORY;
    IUniswapV2Router immutable UNISWAP_V2_ROUTER;

    constructor(PkgInit memory pkgInit) {
        SELF = this;
        ERC20_FACET = pkgInit.erc20Facet;
        ERC5267_FACET = pkgInit.erc5267Facet;
        ERC2612_FACET = pkgInit.erc2612Facet;
        ERC4626_FACET = pkgInit.erc4626Facet;
        ERC4626_BASIC_VAULT_FACET = pkgInit.erc4626BasicVaultFacet;
        ERC4626_STANDARD_VAULT_FACET = pkgInit.erc4626StandardVaultFacet;
        UNISWAP_V2_STANDARD_EXCHANGE_IN_FACET = pkgInit.uniswapV2StandardExchangeInFacet;
        UNISWAP_V2_STANDARD_EXCHANGE_OUT_FACET = pkgInit.uniswapV2StandardExchangeOutFacet;
        VAULT_FEE_ORACLE_QUERY = pkgInit.vaultFeeOracleQuery;
        VAULT_REGISTRY_DEPLOYMENT = pkgInit.vaultRegistryDeployment;
        PERMIT2 = pkgInit.permit2;
        UNISWAP_V2_FACTORY = pkgInit.uniswapV2Factory;
        UNISWAP_V2_ROUTER = pkgInit.uniswapV2Router;
    }

    /* -------------------------------------------------------------------------- */
    /*                       IUniswapV2StandardExchangeDFPkg                      */
    /* -------------------------------------------------------------------------- */

    function deployVault(IUniswapV2Pair pool) public returns (address vault) {
        vault = VAULT_REGISTRY_DEPLOYMENT.deployVault(SELF, abi.encode(PkgArgs({reserveAsset: pool})));
    }

    /**
     * @notice Deploy a vault for a token pair, optionally creating the pair and providing initial liquidity.
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
        DeployWithPoolParams memory params = DeployWithPoolParams({
            tokenA: tokenA, tokenAAmount: tokenAAmount, tokenB: tokenB, tokenBAmount: tokenBAmount, recipient: recipient
        });
        return _deployVaultWithParams(params);
    }

    /**
     * @dev Internal implementation with struct params to avoid stack-too-deep.
     */
    function _deployVaultWithParams(DeployWithPoolParams memory params) internal returns (address vault) {
        // Step 1: Get or create the pair
        IUniswapV2Pair pair = _getOrCreatePair(params.tokenA, params.tokenB);

        // Step 2: Handle initial deposit if amounts provided
        uint256 lpTokensMinted;
        {
            if (params.tokenAAmount > 0 && params.tokenBAmount > 0) {
                if (params.recipient == address(0)) {
                    revert RecipientRequiredForDeposit();
                }
                lpTokensMinted =
                    _depositLiquidity(pair, params.tokenA, params.tokenAAmount, params.tokenB, params.tokenBAmount);
            }
        }

        // Step 3: Deploy vault via existing deployVault(pair)
        vault = deployVault(pair);

        // Step 4: If LP tokens were minted, deposit them to vault for recipient
        {
            if (lpTokensMinted > 0) {
                _depositLPToVault(pair, vault, lpTokensMinted, params.recipient);
            }
        }

        return vault;
    }

    /**
     * @dev Deposit LP tokens to vault for recipient. Isolated to avoid stack-too-deep.
     */
    function _depositLPToVault(IUniswapV2Pair pair, address vault, uint256 lpAmount, address recipient) internal {
        IERC20 lpToken = IERC20(address(pair));
        lpToken.safeTransfer(vault, lpAmount);
        IStandardExchangeIn(vault)
            .exchangeIn(
                lpToken,
                lpAmount,
                IERC20(vault), // vault share token is the vault itself
                0, // no minimum - user already approved the action
                recipient,
                true, // LP tokens were transferred to the vault above
                block.timestamp + 1
            );
    }

    /**
     * @notice Preview the proportional amounts and expected LP for a deployVault call.
     * @param tokenA First token of the pair
     * @param tokenAAmount Maximum amount of tokenA willing to deposit
     * @param tokenB Second token of the pair
     * @param tokenBAmount Maximum amount of tokenB willing to deposit
     * @return result The preview result with pair existence, proportional amounts, and expected LP
     */
    function previewDeployVault(IERC20 tokenA, uint256 tokenAAmount, IERC20 tokenB, uint256 tokenBAmount)
        public
        view
        returns (DeployWithPoolResult memory result)
    {
        // Check if pair exists
        address pairAddr = UNISWAP_V2_FACTORY.getPair(address(tokenA), address(tokenB));
        result.pairExists = pairAddr != address(0);

        if (!result.pairExists || (tokenAAmount == 0 && tokenBAmount == 0)) {
            // New pair or no deposit - use amounts as provided
            result.proportionalA = tokenAAmount;
            result.proportionalB = tokenBAmount;
            // For new pair, LP = sqrt(amountA * amountB) - MINIMUM_LIQUIDITY
            // For no deposit, expectedLP = 0
            if (tokenAAmount > 0 && tokenBAmount > 0) {
                // Approximate: sqrt(a * b) for new pair
                result.expectedLP = _sqrt(tokenAAmount * tokenBAmount);
                // Subtract minimum liquidity (1000) if this is a new pair
                if (result.expectedLP > 1000) {
                    result.expectedLP -= 1000;
                } else {
                    result.expectedLP = 0;
                }
            }
            return result;
        }

        // Existing pair - calculate proportional amounts
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddr);
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();

        // Determine token order
        address token0 = pair.token0();
        bool tokenAIsToken0 = address(tokenA) == token0;
        uint256 reserveA = tokenAIsToken0 ? uint256(reserve0) : uint256(reserve1);
        uint256 reserveB = tokenAIsToken0 ? uint256(reserve1) : uint256(reserve0);

        // Calculate proportional amounts using shared helper
        (result.proportionalA, result.proportionalB) =
            _proportionalDeposit(reserveA, reserveB, tokenAAmount, tokenBAmount);

        // Calculate expected LP tokens
        uint256 totalSupply = IERC20(address(pair)).totalSupply();
        if (totalSupply == 0) {
            result.expectedLP = _sqrt(result.proportionalA * result.proportionalB);
            if (result.expectedLP > 1000) {
                result.expectedLP -= 1000;
            } else {
                result.expectedLP = 0;
            }
        } else {
            // min(proportionalA * totalSupply / reserveA, proportionalB * totalSupply / reserveB)
            uint256 lpFromA = (result.proportionalA * totalSupply) / reserveA;
            uint256 lpFromB = (result.proportionalB * totalSupply) / reserveB;
            result.expectedLP = lpFromA < lpFromB ? lpFromA : lpFromB;
        }

        return result;
    }

    /* -------------------------------------------------------------------------- */
    /*                              Internal Functions                            */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev Get or create a pair for the token pair.
     */
    function _getOrCreatePair(IERC20 tokenA, IERC20 tokenB) internal returns (IUniswapV2Pair pair) {
        address pairAddr = UNISWAP_V2_FACTORY.getPair(address(tokenA), address(tokenB));
        if (pairAddr == address(0)) {
            pairAddr = UNISWAP_V2_FACTORY.createPair(address(tokenA), address(tokenB));
            if (pairAddr == address(0)) {
                revert PairCreationFailed();
            }
        }
        return IUniswapV2Pair(pairAddr);
    }

    /**
     * @dev Deposit liquidity to pair and return amount of LP tokens minted.
     */
    function _depositLiquidity(
        IUniswapV2Pair pair,
        IERC20 tokenA,
        uint256 tokenAAmount,
        IERC20 tokenB,
        uint256 tokenBAmount
    ) internal returns (uint256 lpTokensMinted) {
        // Calculate amounts in isolated scope to reduce stack depth
        (uint256 amountA, uint256 amountB) = _calculateProportionalAmounts(pair, tokenA, tokenAAmount, tokenBAmount);

        // Transfer tokens from caller to pair
        tokenA.safeTransferFrom(msg.sender, address(pair), amountA);
        tokenB.safeTransferFrom(msg.sender, address(pair), amountB);

        // Mint LP tokens to this contract
        lpTokensMinted = pair.mint(address(this));
    }

    /**
     * @dev Calculate proportional amounts based on pair reserves.
     *      Isolated from _depositLiquidity to avoid stack-too-deep.
     */
    function _calculateProportionalAmounts(
        IUniswapV2Pair pair,
        IERC20 tokenA,
        uint256 tokenAAmount,
        uint256 tokenBAmount
    ) internal view returns (uint256 amountA, uint256 amountB) {
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();

        // Determine token ordering and map reserves
        bool tokenAIsToken0 = address(tokenA) == pair.token0();
        uint256 reserveA = tokenAIsToken0 ? uint256(reserve0) : uint256(reserve1);
        uint256 reserveB = tokenAIsToken0 ? uint256(reserve1) : uint256(reserve0);

        return _proportionalDeposit(reserveA, reserveB, tokenAAmount, tokenBAmount);
    }

    /**
     * @dev Core proportional deposit calculation. Given reserves and desired amounts,
     *      returns the maximum proportional amounts that never exceed the provided limits.
     *      Used by both _calculateProportionalAmounts (execution) and previewDeployVault (read-only).
     */
    function _proportionalDeposit(uint256 reserveA, uint256 reserveB, uint256 amountA, uint256 amountB)
        internal
        pure
        returns (uint256 depositA, uint256 depositB)
    {
        if (reserveA == 0 || reserveB == 0) {
            return (amountA, amountB);
        }

        // Use Crane's canonical helper for equivalent liquidity to reduce duplication
        uint256 optimalB = ConstProdUtils._equivLiquidity(amountA, reserveA, reserveB);
        if (optimalB <= amountB) {
            return (amountA, optimalB);
        }
        return ((amountB * reserveA) / reserveB, amountB);
    }

    /**
     * @dev Integer square root using Babylonian method.
     */
    function _sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }

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
        return type(UniswapV2StandardExchangeDFPkg).name;
    }

    function facetAddresses() public view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](8);
        facetAddresses_[0] = address(ERC20_FACET);
        facetAddresses_[1] = address(ERC5267_FACET);
        facetAddresses_[2] = address(ERC2612_FACET);
        facetAddresses_[3] = address(ERC4626_FACET);
        facetAddresses_[4] = address(ERC4626_BASIC_VAULT_FACET);
        facetAddresses_[5] = address(ERC4626_STANDARD_VAULT_FACET);
        facetAddresses_[6] = address(UNISWAP_V2_STANDARD_EXCHANGE_IN_FACET);
        facetAddresses_[7] = address(UNISWAP_V2_STANDARD_EXCHANGE_OUT_FACET);
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
            facetAddress: address(UNISWAP_V2_STANDARD_EXCHANGE_IN_FACET),
            // FacetCutAction action;
            action: IDiamond.FacetCutAction.Add,
            // bytes4[] functionSelectors;
            functionSelectors: UNISWAP_V2_STANDARD_EXCHANGE_IN_FACET.facetFuncs()
        });
        facetCuts_[7] = IDiamond.FacetCut({
            // address facetAddress;
            facetAddress: address(UNISWAP_V2_STANDARD_EXCHANGE_OUT_FACET),
            // FacetCutAction action;
            action: IDiamond.FacetCutAction.Add,
            // bytes4[] functionSelectors;
            functionSelectors: UNISWAP_V2_STANDARD_EXCHANGE_OUT_FACET.facetFuncs()
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
        string memory name_ = "Pachira Vault of (";
        name_ = string.concat(name_, IERC20Metadata(token0).safeSymbol(), " / ");
        name_ = string.concat(name_, IERC20Metadata(token1).safeSymbol(), ") via ");
        name_ = string.concat(name_, decodedArgs.reserveAsset.safeSymbol());
        // uint8 reserveDecimals = decodedArgs.reserveAsset.safeDecimals();
        // uint8 decimals = reserveDecimals + 9;
        ERC20Repo._initialize(
            // string memory name,
            name_,
            // string memory symbol,
            "PACHIRA",
            // uint8 decimals,
            18
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
            decodedArgs.reserveAsset.safeDecimals(),
            // uint8 decimalOffset
            9
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
        UniswapV2FactoryAwareRepo._initialize(UNISWAP_V2_FACTORY);
        UniswapV2RouterAwareRepo._initialize(UNISWAP_V2_ROUTER);
        ConstProdReserveVaultRepo._initialize(
            // address token0_,
            token0,
            // address token1_
            token1
        );
        Permit2AwareRepo._initialize(PERMIT2);
    }

    function postDeploy(address) public pure returns (bool) {
        return true;
    }
}
