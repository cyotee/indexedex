// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {
    StandardExchangeRateProviderRepo
} from "contracts/protocols/dexes/balancer/v3/rateProviders/StandardExchangeRateProviderRepo.sol";

interface IStandardExchangeRateProviderDFPkg is IDiamondFactoryPackage {
    struct PkgInit {
        IFacet rateProviderFacet;
        IDiamondPackageCallBackFactory diamondFactory;
    }

    struct PkgArgs {
        IStandardExchange reserveVault;
        IERC20 rateTarget;
    }

    function deployRateProvider(IStandardExchange reserveVault, IERC20 rateTarget)
        external
        returns (IRateProvider rateProviderAddress);
}

contract StandardExchangeRateProviderDFPkg is IStandardExchangeRateProviderDFPkg {
    using BetterEfficientHashLib for bytes;
    using BetterSafeERC20 for IERC20Metadata;

    IFacet immutable RATE_PROVIDER_FACET;

    IDiamondPackageCallBackFactory immutable DIAMOND_FACTORY;

    constructor(PkgInit memory pkgInit) {
        RATE_PROVIDER_FACET = pkgInit.rateProviderFacet;
        DIAMOND_FACTORY = pkgInit.diamondFactory;
    }

    function deployRateProvider(IStandardExchange reserveVault, IERC20 rateTarget)
        external
        returns (IRateProvider rateProviderAddress)
    {
        return IRateProvider(
            DIAMOND_FACTORY.deploy(this, abi.encode(PkgArgs({reserveVault: reserveVault, rateTarget: rateTarget})))
        );
    }

    function packageName() public pure returns (string memory name_) {
        return type(StandardExchangeRateProviderDFPkg).name;
    }

    function facetAddresses() public view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](1);
        facetAddresses_[0] = address(RATE_PROVIDER_FACET);
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IRateProvider).interfaceId;
    }

    function packageMetadata()
        public
        view
        returns (string memory name_, bytes4[] memory interfaces_, address[] memory facets_)
    {
        name_ = packageName();
        interfaces_ = facetInterfaces();
        facets_ = facetAddresses();
    }

    function facetCuts() public view returns (IDiamond.FacetCut[] memory facetCuts_) {
        facetCuts_ = new IDiamond.FacetCut[](1);
        facetCuts_[0] = IDiamond.FacetCut({
            facetAddress: address(RATE_PROVIDER_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: RATE_PROVIDER_FACET.facetFuncs()
        });
    }

    function diamondConfig() public view returns (DiamondConfig memory config) {
        config = DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    function calcSalt(bytes memory pkgArgs) public pure returns (bytes32 salt) {
        return abi.encode(pkgArgs)._hash();
    }

    function processArgs(bytes memory pkgArgs) public pure returns (bytes memory processedPkgArgs) {
        return pkgArgs;
    }

    function updatePkg(address, bytes memory) public pure virtual returns (bool) {
        return true;
    }

    function initAccount(bytes memory initArgs) public {
        PkgArgs memory decoded = abi.decode(initArgs, (PkgArgs));

        uint8 targetDecimals = IERC20Metadata(address(decoded.rateTarget)).safeDecimals();

        StandardExchangeRateProviderRepo._initialize(decoded.reserveVault, decoded.rateTarget, targetDecimals);
    }

    function postDeploy(address) public pure returns (bool) {
        return true;
    }
}
