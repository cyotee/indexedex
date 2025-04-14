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
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {ICamelotV2Router} from "@crane/contracts/interfaces/protocols/dexes/camelot/v2/ICamelotV2Router.sol";
import {ICamelotFactory} from "@crane/contracts/interfaces/protocols/dexes/camelot/v2/ICamelotFactory.sol";
import {ICamelotPair} from "@crane/contracts/interfaces/protocols/dexes/camelot/v2/ICamelotPair.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {EIP712Repo} from "@crane/contracts/utils/cryptography/EIP712/EIP712Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";
import {CamelotV2RouterAwareRepo} from "@crane/contracts/protocols/dexes/camelot/v2/CamelotV2RouterAwareRepo.sol";
import {CamelotV2FactoryAwareRepo} from "@crane/contracts/protocols/dexes/camelot/v2/CamelotV2FactoryAwareRepo.sol";
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

interface ICamelotV2StandardExchangeDFPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    error NotCalledByRegistry(address caller);

    error PoolMustNotBeStable(ICamelotPair pool);

    error ZeroAmountForNonZeroRecipient();

    error InsufficientLiquidity();

    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc2612Facet;
        IFacet erc5267Facet;
        IFacet erc4626Facet;
        IFacet erc4626BasicVaultFacet;
        IFacet erc4626StandardVaultFacet;
        IFacet camelotV2StandardExchangeInFacet;
        IFacet camelotV2StandardExchangeOutFacet;
        IVaultFeeOracleQuery vaultFeeOracleQuery;
        IVaultRegistryDeployment vaultRegistryDeployment;
        IPermit2 permit2;
        ICamelotFactory camelotV2Factory;
        ICamelotV2Router camelotV2Router;
    }

    struct PkgArgs {
        ICamelotPair reserveAsset;
    }

    struct PreviewDeployVaultResult {
        bool pairExists;
        uint256 proportionalA;
        uint256 proportionalB;
        /// @dev Upper-bound estimate; actual LP minted will be slightly less due to Camelot's `_mintFee()`.
        uint256 expectedLP;
    }

    event PairCreated(address indexed tokenA, address indexed tokenB, address pair);

    event VaultDeployedWithDeposit(
        address indexed vault, address indexed pair, address indexed recipient, uint256 lpAmount, uint256 vaultShares
    );

    function deployVault(ICamelotPair pool) external returns (address vault);

    function deployVault(IERC20 tokenA, uint256 tokenAAmount, IERC20 tokenB, uint256 tokenBAmount, address recipient)
        external
        returns (address vault);

    function previewDeployVault(IERC20 tokenA, uint256 tokenAAmount, IERC20 tokenB, uint256 tokenBAmount)
        external
        view
        returns (PreviewDeployVaultResult memory result);
}

contract CamelotV2StandardExchangeDFPkg is ICamelotV2StandardExchangeDFPkg {
    using BetterEfficientHashLib for bytes;
    using BetterSafeERC20 for IERC20;
    using BetterSafeERC20 for IERC20Metadata;

    CamelotV2StandardExchangeDFPkg SELF;

    IFacet immutable ERC20_FACET;
    IFacet immutable ERC5267_FACET;
    IFacet immutable ERC2612_FACET;
    IFacet immutable ERC4626_FACET;
    IFacet immutable ERC4626_BASIC_VAULT_FACET;
    IFacet immutable ERC4626_STANDARD_VAULT_FACET;
    IFacet immutable CAMELOT_V2_STANDARD_EXCHANGE_IN_FACET;
    IFacet immutable CAMELOT_V2_STANDARD_EXCHANGE_OUT_FACET;
    IVaultFeeOracleQuery immutable VAULT_FEE_ORACLE_QUERY;
    IVaultRegistryDeployment immutable VAULT_REGISTRY_DEPLOYMENT;
    IPermit2 immutable PERMIT2;
    ICamelotFactory immutable CAMELOT_V2_FACTORY;
    ICamelotV2Router immutable CAMELOT_V2_ROUTER;

    constructor(PkgInit memory pkgInit) {
        SELF = this;
        ERC20_FACET = pkgInit.erc20Facet;
        ERC5267_FACET = pkgInit.erc5267Facet;
        ERC2612_FACET = pkgInit.erc2612Facet;
        ERC4626_FACET = pkgInit.erc4626Facet;
        ERC4626_BASIC_VAULT_FACET = pkgInit.erc4626BasicVaultFacet;
        ERC4626_STANDARD_VAULT_FACET = pkgInit.erc4626StandardVaultFacet;
        CAMELOT_V2_STANDARD_EXCHANGE_IN_FACET = pkgInit.camelotV2StandardExchangeInFacet;
        CAMELOT_V2_STANDARD_EXCHANGE_OUT_FACET = pkgInit.camelotV2StandardExchangeOutFacet;
        VAULT_FEE_ORACLE_QUERY = pkgInit.vaultFeeOracleQuery;
        VAULT_REGISTRY_DEPLOYMENT = pkgInit.vaultRegistryDeployment;
        PERMIT2 = pkgInit.permit2;
        CAMELOT_V2_FACTORY = pkgInit.camelotV2Factory;
        CAMELOT_V2_ROUTER = pkgInit.camelotV2Router;
    }

    /* -------------------------------------------------------------------------- */
    /*                      ICamelotV2StandardExchangeInDFPkg                     */
    /* -------------------------------------------------------------------------- */

    function deployVault(ICamelotPair pool) public returns (address vault) {
        vault = VAULT_REGISTRY_DEPLOYMENT.deployVault(SELF, abi.encode(PkgArgs({reserveAsset: pool})));
    }

    /**
     * @dev Internal struct to hold deployment state and reduce stack depth
     */
    struct DeployState {
        address pairAddress;
        uint256 lpMinted;
        uint256 proportionalA;
        uint256 proportionalB;
    }

    /**
     * @notice Deploys a vault for a Camelot V2 pair, creating the pair if it doesn't exist,
     *         and optionally providing initial liquidity.
     * @param tokenA The first token of the pair
     * @param tokenAAmount The amount of tokenA to deposit (0 for no deposit)
     * @param tokenB The second token of the pair
     * @param tokenBAmount The amount of tokenB to deposit (0 for no deposit)
     * @param recipient The address to receive vault shares (address(0) for no deposit)
     * @return vault The address of the deployed vault
     */
    function deployVault(IERC20 tokenA, uint256 tokenAAmount, IERC20 tokenB, uint256 tokenBAmount, address recipient)
        public
        returns (address vault)
    {
        DeployState memory state;

        // Step 1: Get or create the pair
        state.pairAddress = CAMELOT_V2_FACTORY.getPair(address(tokenA), address(tokenB));

        if (state.pairAddress == address(0)) {
            state.pairAddress = CAMELOT_V2_FACTORY.createPair(address(tokenA), address(tokenB));
            emit PairCreated(address(tokenA), address(tokenB), state.pairAddress);
        }

        // Step 2: Calculate proportional amounts and handle initial deposit if requested
        if (recipient != address(0)) {
            // Deposit is requested
            if (tokenAAmount == 0 || tokenBAmount == 0) {
                revert ZeroAmountForNonZeroRecipient();
            }

            // Calculate proportional amounts
            (state.proportionalA, state.proportionalB) = _calculateProportionalAmounts(
                ICamelotPair(state.pairAddress), tokenA, tokenAAmount, tokenB, tokenBAmount
            );

            if (state.proportionalA == 0 || state.proportionalB == 0) {
                revert InsufficientLiquidity();
            }

            // Transfer and mint LP tokens
            state.lpMinted =
                _transferAndMintLP(state.pairAddress, tokenA, tokenB, state.proportionalA, state.proportionalB);
        }

        // Step 3: Deploy the vault
        vault = VAULT_REGISTRY_DEPLOYMENT.deployVault(
            SELF, abi.encode(PkgArgs({reserveAsset: ICamelotPair(state.pairAddress)}))
        );

        // Step 4: If LP tokens were minted, deposit them to the vault for the recipient
        if (state.lpMinted > 0) {
            _depositLPToVault(vault, state.pairAddress, state.lpMinted, recipient);
        }

        return vault;
    }

    /**
     * @dev Transfer tokens to pair and mint LP tokens
     */
    function _transferAndMintLP(
        address pairAddress,
        IERC20 tokenA,
        IERC20 tokenB,
        uint256 proportionalA,
        uint256 proportionalB
    ) internal returns (uint256 lpMinted) {
        ICamelotPair pair = ICamelotPair(pairAddress);
        address token0 = pair.token0();

        // Order tokens correctly for the pair
        if (address(tokenA) == token0) {
            tokenA.safeTransferFrom(msg.sender, pairAddress, proportionalA);
            tokenB.safeTransferFrom(msg.sender, pairAddress, proportionalB);
        } else {
            tokenB.safeTransferFrom(msg.sender, pairAddress, proportionalB);
            tokenA.safeTransferFrom(msg.sender, pairAddress, proportionalA);
        }

        // Mint LP tokens to this contract
        return pair.mint(address(this));
    }

    /**
     * @dev Deposit LP tokens to vault for recipient
     */
    function _depositLPToVault(address vault, address pairAddress, uint256 lpMinted, address recipient) internal {
        // Approve vault for LP tokens
        IERC20(pairAddress).safeApprove(vault, lpMinted);

        // Exchange LP tokens for vault shares
        uint256 vaultShares = IStandardExchangeIn(vault)
            .exchangeIn(
                IERC20(pairAddress), // tokenIn: LP token
                lpMinted, // amountIn: LP amount
                IERC20(vault), // tokenOut: vault shares
                0, // minAmountOut: accept any amount
                recipient, // recipient
                false, // pretransferred: we're approving, not pre-transferring
                block.timestamp + 1 // deadline
            );
        IERC20(pairAddress).forceApprove(vault, 0);

        emit VaultDeployedWithDeposit(vault, pairAddress, recipient, lpMinted, vaultShares);
    }

    /**
     * @notice Preview the results of calling deployVault with the given parameters.
     * @dev The `expectedLP` value is an upper-bound estimate intended for UI display only.
     *      It does not account for Camelot's internal `_mintFee()`, which increases the pair's
     *      `totalSupply` before the depositor's liquidity share is calculated. As a result, the
     *      actual LP tokens minted will be slightly less than the value returned here.
     * @param tokenA The first token of the pair
     * @param tokenAAmount The maximum amount of tokenA to deposit
     * @param tokenB The second token of the pair
     * @param tokenBAmount The maximum amount of tokenB to deposit
     * @return result The preview result containing pair existence and proportional amounts
     */
    function previewDeployVault(IERC20 tokenA, uint256 tokenAAmount, IERC20 tokenB, uint256 tokenBAmount)
        public
        view
        returns (PreviewDeployVaultResult memory result)
    {
        address pairAddress = CAMELOT_V2_FACTORY.getPair(address(tokenA), address(tokenB));
        result.pairExists = pairAddress != address(0);

        if (!result.pairExists) {
            // For a new pair, use provided amounts as-is
            result.proportionalA = tokenAAmount;
            result.proportionalB = tokenBAmount;
            // Expected LP for new pair: sqrt(tokenAAmount * tokenBAmount) - MINIMUM_LIQUIDITY
            // MINIMUM_LIQUIDITY is typically 1000
            if (tokenAAmount > 0 && tokenBAmount > 0) {
                result.expectedLP = _sqrt(tokenAAmount * tokenBAmount) - 1000;
            }
        } else {
            ICamelotPair pair = ICamelotPair(pairAddress);
            (uint112 reserve0, uint112 reserve1,,) = pair.getReserves();

            // Determine token order
            address token0 = pair.token0();
            bool tokenAIsToken0 = address(tokenA) == token0;
            uint256 reserveA = tokenAIsToken0 ? uint256(reserve0) : uint256(reserve1);
            uint256 reserveB = tokenAIsToken0 ? uint256(reserve1) : uint256(reserve0);

            // Calculate proportional amounts using shared helper
            (result.proportionalA, result.proportionalB) =
                _proportionalDeposit(reserveA, reserveB, tokenAAmount, tokenBAmount);

            // Calculate expected LP tokens
            if (result.proportionalA > 0 && result.proportionalB > 0) {
                uint256 totalSupply = pair.totalSupply();

                (uint256 amount0, uint256 amount1) = tokenAIsToken0
                    ? (result.proportionalA, result.proportionalB)
                    : (result.proportionalB, result.proportionalA);

                if (totalSupply == 0) {
                    result.expectedLP = _sqrt(amount0 * amount1) - 1000;
                } else {
                    uint256 lpFromAmount0 = (amount0 * totalSupply) / reserve0;
                    uint256 lpFromAmount1 = (amount1 * totalSupply) / reserve1;
                    result.expectedLP = lpFromAmount0 < lpFromAmount1 ? lpFromAmount0 : lpFromAmount1;
                }
            }
        }

        return result;
    }

    /**
     * @dev Calculate proportional amounts based on pair reserves.
     *      Isolated from deployment logic to avoid stack-too-deep.
     */
    function _calculateProportionalAmounts(
        ICamelotPair pair,
        IERC20 tokenA,
        uint256 tokenAAmount,
        IERC20 tokenB,
        uint256 tokenBAmount
    ) internal view returns (uint256 proportionalA, uint256 proportionalB) {
        tokenB;

        (uint112 reserve0, uint112 reserve1,,) = pair.getReserves();

        // Determine token ordering and map reserves
        address token0 = pair.token0();
        (uint256 reserveA, uint256 reserveB) =
            address(tokenA) == token0 ? (uint256(reserve0), uint256(reserve1)) : (uint256(reserve1), uint256(reserve0));

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

        uint256 optimalB = ConstProdUtils._equivLiquidity(amountA, reserveA, reserveB);
        if (optimalB <= amountB) {
            return (amountA, optimalB);
        }
        return ((amountB * reserveA) / reserveB, amountB);
    }

    /**
     * @dev Babylonian method for computing square root
     */
    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
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
        return type(CamelotV2StandardExchangeDFPkg).name;
    }

    function facetAddresses() public view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](8);
        facetAddresses_[0] = address(ERC20_FACET);
        facetAddresses_[1] = address(ERC5267_FACET);
        facetAddresses_[2] = address(ERC2612_FACET);
        facetAddresses_[3] = address(ERC4626_FACET);
        facetAddresses_[4] = address(ERC4626_BASIC_VAULT_FACET);
        facetAddresses_[5] = address(ERC4626_STANDARD_VAULT_FACET);
        facetAddresses_[6] = address(CAMELOT_V2_STANDARD_EXCHANGE_IN_FACET);
        facetAddresses_[7] = address(CAMELOT_V2_STANDARD_EXCHANGE_OUT_FACET);
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
            facetAddress: address(CAMELOT_V2_STANDARD_EXCHANGE_IN_FACET),
            // FacetCutAction action;
            action: IDiamond.FacetCutAction.Add,
            // bytes4[] functionSelectors;
            functionSelectors: CAMELOT_V2_STANDARD_EXCHANGE_IN_FACET.facetFuncs()
        });
        facetCuts_[7] = IDiamond.FacetCut({
            // address facetAddress;
            facetAddress: address(CAMELOT_V2_STANDARD_EXCHANGE_OUT_FACET),
            // FacetCutAction action;
            action: IDiamond.FacetCutAction.Add,
            // bytes4[] functionSelectors;
            functionSelectors: CAMELOT_V2_STANDARD_EXCHANGE_OUT_FACET.facetFuncs()
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
        if (decodedArgs.reserveAsset.stableSwap()) {
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
        string memory name_ = "Pachira Vault of (";
        name_ = string.concat(name_, IERC20Metadata(token0).safeSymbol(), " / ");
        name_ = string.concat(name_, IERC20Metadata(token1).safeSymbol(), ") via ");
        name_ = string.concat(name_, IERC20Metadata(address(decodedArgs.reserveAsset)).safeSymbol());
        uint8 reserveDecimals = IERC20Metadata(address(decodedArgs.reserveAsset)).safeDecimals();
        uint8 decimals = reserveDecimals + 9;
        ERC20Repo._initialize(
            // string memory name,
            name_,
            // string memory symbol,
            "PACHIRA",
            // uint8 decimals,
            decimals
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
        CamelotV2RouterAwareRepo._initialize(CAMELOT_V2_ROUTER);
        CamelotV2FactoryAwareRepo._initialize(CAMELOT_V2_FACTORY);
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
