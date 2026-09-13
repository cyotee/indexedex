// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IBasicVault} from "contracts/vaults/basic/IBasicVault.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IStandardExchangeTransitionQuote,
    IStandardExchangeExternalQuote,
    IStandardExchangeRateQuote
} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IRebasingAwareERC4626} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626.sol";
import {IRebasingAwareERC4626DFPkg} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626DFPkg.sol";
import {RebasingAwareERC4626Repo} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareERC4626Repo.sol";
import {RebasingAwareERC4626Common} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareERC4626Common.sol";

contract RebasingAwareERC4626DFPkg is IRebasingAwareERC4626DFPkg {
    using BetterEfficientHashLib for bytes;
    using BetterSafeERC20 for IERC20Metadata;

    string internal constant RELEASE_ID = "indexedex.rebasing-aware-erc4626.sy-se.v1";

    IRebasingAwareERC4626DFPkg public immutable SELF;
    IFacet immutable ERC20_FACET;
    IFacet immutable REBASING_AWARE_ERC4626_FACET;
    IFacet immutable STANDARD_EXCHANGE_FACET;
    IFacet immutable STANDARD_YIELD_FACET;
    IFacet immutable VAULT_METADATA_FACET;
    IFacet immutable TRANSITION_QUOTE_FACET;
    IVaultRegistryDeployment immutable VAULT_REGISTRY;

    constructor(PkgInit memory pkgInit) {
        _requireCode(address(pkgInit.erc20Facet));
        _requireCode(address(pkgInit.rebasingAwareErc4626Facet));
        _requireCode(address(pkgInit.diamondFactory));
        _requireCode(address(pkgInit.standardExchangeFacet));
        _requireCode(address(pkgInit.standardYieldFacet));
        _requireCode(address(pkgInit.vaultMetadataFacet));
        _requireCode(address(pkgInit.transitionQuoteFacet));
        _requireCode(address(pkgInit.vaultRegistry));
        SELF = this;
        ERC20_FACET = pkgInit.erc20Facet;
        REBASING_AWARE_ERC4626_FACET = pkgInit.rebasingAwareErc4626Facet;
        STANDARD_EXCHANGE_FACET = pkgInit.standardExchangeFacet;
        STANDARD_YIELD_FACET = pkgInit.standardYieldFacet;
        VAULT_METADATA_FACET = pkgInit.vaultMetadataFacet;
        TRANSITION_QUOTE_FACET = pkgInit.transitionQuoteFacet;
        VAULT_REGISTRY = pkgInit.vaultRegistry;
    }

    function releaseIdentifier() public pure returns (string memory) {
        return RELEASE_ID;
    }

    function deployVault(IERC20Metadata asset) external returns (IERC4626 vault) {
        return deployVault(asset, 10, bytes32(0));
    }

    function deployVault(IERC20Metadata asset, uint8 decimalOffset, bytes32 optionalSalt)
        public
        returns (IERC4626 vault)
    {
        _requireCode(address(asset));
        string memory assetName = asset.safeName();
        string memory assetSymbol = asset.safeSymbol();
        vault = IERC4626(
            VAULT_REGISTRY.deployVault(
                IStandardVaultPkg(address(this)),
                abi.encode(
                    PkgArgs({
                        asset: asset,
                        name: string.concat("Wrapped ", assetName),
                        symbol: string.concat("w", assetSymbol),
                        decimalOffset: decimalOffset,
                        optionalSalt: optionalSalt
                    })
                )
            )
        );
    }

    function name() public pure returns (string memory) {
        return "RebasingAwareERC4626";
    }

    function vaultFeeTypeIds() public pure returns (bytes32) {
        return bytes32(0);
    }

    function vaultTypes() public pure returns (bytes4[] memory typeIDs) {
        typeIDs = new bytes4[](6);
        typeIDs[0] = type(IERC4626).interfaceId;
        typeIDs[1] = type(IStandardExchangeIn).interfaceId;
        typeIDs[2] = type(IStandardExchangeOut).interfaceId;
        typeIDs[3] = type(IStandardizedYield).interfaceId;
        typeIDs[4] = type(IStandardExchangeTransitionQuote).interfaceId;
        typeIDs[5] = type(IStandardExchangeExternalQuote).interfaceId;
    }

    function vaultDeclaration() public pure returns (VaultPkgDeclaration memory declaration) {
        return VaultPkgDeclaration({name: name(), vaultFeeTypeIds: bytes32(0), vaultTypes: vaultTypes()});
    }

    function packageName() public pure returns (string memory name_) {
        return "RebasingAwareERC4626";
    }

    function facetAddresses() public view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](6);
        facetAddresses_[0] = address(ERC20_FACET);
        facetAddresses_[1] = address(REBASING_AWARE_ERC4626_FACET);
        facetAddresses_[2] = address(STANDARD_EXCHANGE_FACET);
        facetAddresses_[3] = address(STANDARD_YIELD_FACET);
        facetAddresses_[4] = address(VAULT_METADATA_FACET);
        facetAddresses_[5] = address(TRANSITION_QUOTE_FACET);
    }

    function facetInterfaces() public view returns (bytes4[] memory interfaces) {
        bytes4[] memory erc20Ifaces = ERC20_FACET.facetInterfaces();
        interfaces = new bytes4[](erc20Ifaces.length + 9);
        uint256 i;
        for (; i < erc20Ifaces.length; ++i) {
            interfaces[i] = erc20Ifaces[i];
        }
        interfaces[i++] = type(IERC4626).interfaceId;
        interfaces[i++] = type(IStandardExchangeIn).interfaceId;
        interfaces[i++] = type(IStandardExchangeOut).interfaceId;
        interfaces[i++] = type(IStandardizedYield).interfaceId;
        interfaces[i++] = type(IStandardExchangeTransitionQuote).interfaceId;
        interfaces[i++] = type(IStandardExchangeExternalQuote).interfaceId;
        interfaces[i++] = type(IBasicVault).interfaceId;
        interfaces[i++] = type(IStandardVault).interfaceId;
        interfaces[i] = type(IStandardExchangeRateQuote).interfaceId;
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
        facetCuts_ = new IDiamond.FacetCut[](6);
        facetCuts_[0] = IDiamond.FacetCut({
            facetAddress: address(ERC20_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC20_FACET.facetFuncs()
        });
        facetCuts_[1] = IDiamond.FacetCut({
            facetAddress: address(REBASING_AWARE_ERC4626_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: REBASING_AWARE_ERC4626_FACET.facetFuncs()
        });
        facetCuts_[2] = IDiamond.FacetCut({
            facetAddress: address(STANDARD_EXCHANGE_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: STANDARD_EXCHANGE_FACET.facetFuncs()
        });
        facetCuts_[3] = IDiamond.FacetCut({
            facetAddress: address(STANDARD_YIELD_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: STANDARD_YIELD_FACET.facetFuncs()
        });
        facetCuts_[4] = IDiamond.FacetCut({
            facetAddress: address(VAULT_METADATA_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: VAULT_METADATA_FACET.facetFuncs()
        });
        facetCuts_[5] = IDiamond.FacetCut({
            facetAddress: address(TRANSITION_QUOTE_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: TRANSITION_QUOTE_FACET.facetFuncs()
        });
    }

    function diamondConfig() public view returns (DiamondConfig memory config) {
        config = IDiamondFactoryPackage.DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    function calcSalt(bytes memory pkgArgs) public view returns (bytes32 salt) {
        return processArgs(pkgArgs)._hash();
    }

    function processArgs(bytes memory pkgArgs) public view returns (bytes memory) {
        PkgArgs memory decodedArgs = abi.decode(pkgArgs, (PkgArgs));
        if (address(decodedArgs.asset) == address(0)) {
            revert NoAsset();
        }
        _requireCode(address(decodedArgs.asset));
        if (bytes(decodedArgs.name).length == 0 && bytes(decodedArgs.symbol).length == 0) {
            revert NoNameAndSymbol();
        }
        uint8 requested = decodedArgs.decimalOffset;
        if (requested > RebasingAwareERC4626Common.MAX_OFFSET) {
            revert IRebasingAwareERC4626.UnsupportedDecimalOffset(requested);
        }
        if (requested < RebasingAwareERC4626Common.MIN_OFFSET) {
            decodedArgs.decimalOffset = RebasingAwareERC4626Common.MIN_OFFSET;
        }
        uint8 assetDecimals = decodedArgs.asset.safeDecimals();
        if (uint256(assetDecimals) + uint256(decodedArgs.decimalOffset) > RebasingAwareERC4626Common.MAX_DECIMALS_SUM)
        {
            revert IRebasingAwareERC4626.UnsupportedDecimals(assetDecimals, decodedArgs.decimalOffset);
        }
        return abi.encode(decodedArgs);
    }

    function updatePkg(address, bytes memory) public pure returns (bool) {
        return true;
    }

    function initAccount(bytes memory initArgs) public {
        PkgArgs memory decodedArgs = abi.decode(initArgs, (PkgArgs));
        uint8 assetDecimals = decodedArgs.asset.safeDecimals();
        ERC20Repo._initialize(
            decodedArgs.name, decodedArgs.symbol, assetDecimals + decodedArgs.decimalOffset
        );
        RebasingAwareERC4626Repo._initialize(
            IERC20(address(decodedArgs.asset)),
            decodedArgs.decimalOffset,
            assetDecimals,
            address(VAULT_REGISTRY)
        );
    }

    function postDeploy(address) public pure returns (bool) {
        return true;
    }

    function _requireCode(address dependency) private view {
        if (dependency == address(0) || dependency.code.length == 0) {
            revert IRebasingAwareERC4626.MissingDependency(dependency);
        }
    }
}
