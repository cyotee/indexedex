// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {EIP712Repo} from "@crane/contracts/utils/cryptography/EIP712/EIP712Repo.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";

import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {VaultFeeType} from "contracts/interfaces/VaultFeeTypes.sol";
import {VaultTypeUtils} from "contracts/registries/vault/VaultTypeUtils.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {
    IEtherFiWeETHStandardExchangeDFPkg
} from "contracts/protocols/staking/etherfi/interfaces/IEtherFiWeETHStandardExchangeDFPkg.sol";
import {
    IEtherFiWeETHStandardVault,
    IEtherFiWeETHRebalance
} from "contracts/protocols/staking/etherfi/interfaces/IEtherFiWeETHStandardVault.sol";
import {
    EtherFiWeETHStandardExchangeRepo
} from "contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeRepo.sol";

contract EtherFiWeETHStandardExchangeDFPkg is IEtherFiWeETHStandardExchangeDFPkg {
    using BetterEfficientHashLib for bytes;

    EtherFiWeETHStandardExchangeDFPkg public immutable SELF;

    IFacet public immutable ERC20_FACET;
    IFacet public immutable ERC5267_FACET;
    IFacet public immutable ERC2612_FACET;
    IFacet public immutable ERC4626_FACET;
    IFacet public immutable ERC4626_STANDARD_VAULT_FACET;
    IFacet public immutable MULTI_ASSET_BASIC_VAULT_FACET;
    IFacet public immutable MULTI_ASSET_STANDARD_VAULT_FACET;
    IFacet public immutable EXCHANGE_IN_FACET;
    IFacet public immutable EXCHANGE_OUT_FACET;
    IFacet public immutable MARKER_FACET;
    IFacet public immutable REBALANCE_FACET;
    IVaultFeeOracleQuery public immutable VAULT_FEE_ORACLE_QUERY;
    IVaultRegistryDeployment public immutable VAULT_REGISTRY_DEPLOYMENT;
    IPermit2 public immutable PERMIT2;

    constructor(PkgInit memory pkgInit) {
        SELF = this;
        ERC20_FACET = pkgInit.erc20Facet;
        ERC5267_FACET = pkgInit.erc5267Facet;
        ERC2612_FACET = pkgInit.erc2612Facet;
        ERC4626_FACET = pkgInit.erc4626Facet;
        ERC4626_STANDARD_VAULT_FACET = pkgInit.erc4626StandardVaultFacet;
        MULTI_ASSET_BASIC_VAULT_FACET = pkgInit.multiAssetBasicVaultFacet;
        MULTI_ASSET_STANDARD_VAULT_FACET = pkgInit.multiAssetStandardVaultFacet;
        EXCHANGE_IN_FACET = pkgInit.exchangeInFacet;
        EXCHANGE_OUT_FACET = pkgInit.exchangeOutFacet;
        MARKER_FACET = pkgInit.markerFacet;
        REBALANCE_FACET = pkgInit.rebalanceFacet;
        VAULT_FEE_ORACLE_QUERY = pkgInit.vaultFeeOracleQuery;
        VAULT_REGISTRY_DEPLOYMENT = pkgInit.vaultRegistryDeployment;
        PERMIT2 = pkgInit.permit2;
    }

    function deployVault(
        address eETH_,
        address weETH_,
        address weth_,
        address liquidityPool_,
        address withdrawRequestNFT_,
        address redemptionManager_
    ) public returns (address vault) {
        if (eETH_ == address(0) || weETH_ == address(0) || weth_ == address(0) || liquidityPool_ == address(0)) {
            revert ZeroAddress();
        }
        vault = VAULT_REGISTRY_DEPLOYMENT.deployVault(
            SELF,
            abi.encode(
                PkgArgs({
                    eETH: eETH_,
                    weETH: weETH_,
                    weth: weth_,
                    liquidityPool: liquidityPool_,
                    withdrawRequestNFT: withdrawRequestNFT_,
                    redemptionManager: redemptionManager_
                })
            )
        );
    }

    function name() public pure returns (string memory) {
        return type(EtherFiWeETHStandardExchangeDFPkg).name;
    }

    function vaultFeeTypeIds() public pure returns (bytes32 vaultFeeTypeIds_) {
        vaultFeeTypeIds_ = VaultTypeUtils._insertFeeTypeId(
            vaultFeeTypeIds_, VaultFeeType.USAGE, type(IEtherFiWeETHStandardVault).interfaceId
        );
    }

    function vaultTypes() public pure returns (bytes4[] memory) {
        return facetInterfaces();
    }

    function vaultDeclaration() public pure returns (VaultPkgDeclaration memory declaration) {
        return VaultPkgDeclaration({name: name(), vaultFeeTypeIds: vaultFeeTypeIds(), vaultTypes: vaultTypes()});
    }

    function packageName() public pure returns (string memory) {
        return type(EtherFiWeETHStandardExchangeDFPkg).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](10);
        interfaces[0] = type(IERC20).interfaceId;
        interfaces[1] = type(IERC20Metadata).interfaceId;
        interfaces[2] = type(IERC20Permit).interfaceId;
        interfaces[3] = type(IERC5267).interfaceId;
        interfaces[4] = type(IERC4626).interfaceId;
        interfaces[5] = type(IStandardExchangeIn).interfaceId;
        interfaces[6] = type(IStandardExchangeOut).interfaceId;
        interfaces[7] = type(IEtherFiWeETHStandardVault).interfaceId;
        interfaces[8] = type(IEtherFiWeETHRebalance).interfaceId;
        interfaces[9] = type(IEtherFiWeETHStandardVault).interfaceId;
    }

    function facetCuts() public view returns (IDiamond.FacetCut[] memory cuts) {
        cuts = new IDiamond.FacetCut[](10);
        cuts[0] = IDiamond.FacetCut({
            facetAddress: address(ERC20_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC20_FACET.facetFuncs()
        });
        cuts[1] = IDiamond.FacetCut({
            facetAddress: address(ERC5267_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC5267_FACET.facetFuncs()
        });
        cuts[2] = IDiamond.FacetCut({
            facetAddress: address(ERC2612_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC2612_FACET.facetFuncs()
        });
        cuts[3] = IDiamond.FacetCut({
            facetAddress: address(ERC4626_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC4626_FACET.facetFuncs()
        });
        cuts[4] = IDiamond.FacetCut({
            facetAddress: address(ERC4626_STANDARD_VAULT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC4626_STANDARD_VAULT_FACET.facetFuncs()
        });
        cuts[5] = IDiamond.FacetCut({
            facetAddress: address(MULTI_ASSET_BASIC_VAULT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: MULTI_ASSET_BASIC_VAULT_FACET.facetFuncs()
        });
        cuts[6] = IDiamond.FacetCut({
            facetAddress: address(EXCHANGE_IN_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: EXCHANGE_IN_FACET.facetFuncs()
        });
        cuts[7] = IDiamond.FacetCut({
            facetAddress: address(EXCHANGE_OUT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: EXCHANGE_OUT_FACET.facetFuncs()
        });
        cuts[8] = IDiamond.FacetCut({
            facetAddress: address(MARKER_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: MARKER_FACET.facetFuncs()
        });
        cuts[9] = IDiamond.FacetCut({
            facetAddress: address(REBALANCE_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: REBALANCE_FACET.facetFuncs()
        });
    }

    function facetAddresses() external view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](0);
    }

    function diamondConfig() public view returns (DiamondConfig memory config) {
        config = IDiamondFactoryPackage.DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    function calcSalt(bytes memory pkgArgs) public pure returns (bytes32) {
        return keccak256(pkgArgs);
    }

    function initAccount(bytes memory initArgs) public {
        PkgArgs memory args = abi.decode(initArgs, (PkgArgs));

        string memory name_ = "IndexedEx ether.fi weETH SE";
        ERC20Repo._initialize(name_, "ixWeETH", 18);
        EIP712Repo._initialize(name_, "1");
        // ERC-4626 asset = weETH (primary locked reserve).
        // decimalOffset=3 enables BetterMath virtual shares inflation defense (OZ-style).
        ERC4626Repo._initialize(IERC20(args.weETH), 18, 3);
        ERC4626Repo._setLastTotalAssets(0);

        address[] memory vaultTokens = new address[](3);
        vaultTokens[0] = args.weETH;
        vaultTokens[1] = args.weth;
        vaultTokens[2] = args.eETH;
        MultiAssetBasicVaultRepo._initialize(vaultTokens);

        bytes32 contentsId = abi.encode(vaultTokens)._hash();
        StandardVaultRepo._initialize(VAULT_FEE_ORACLE_QUERY, vaultFeeTypeIds(), vaultTypes(), contentsId);
        VaultFeeOracleQueryAwareRepo._initialize(VAULT_FEE_ORACLE_QUERY);
        Permit2AwareRepo._initialize(PERMIT2);
        EtherFiWeETHStandardExchangeRepo._initialize(
            args.eETH,
            args.weETH,
            args.weth,
            args.liquidityPool,
            args.withdrawRequestNFT,
            args.redemptionManager
        );
    }

    function postDeploy(address) public pure returns (bool) {
        return true;
    }

    function packageMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces, address[] memory facets)
    {
        name_ = "EtherFiWeETHStandardExchangeDFPkg";
        interfaces = facetInterfaces();
        facets = new address[](0);
    }

    function processArgs(bytes memory pkgArgs) public pure returns (bytes memory) {
        return pkgArgs;
    }

    function updatePkg(address, bytes memory) public pure returns (bool) {
        return true;
    }
}
