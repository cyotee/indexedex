// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";

import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {
	IWrappedStandardExchangeRateProvider
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/wrapped/WrappedStandardExchangeRateProviderTarget.sol";
import {
	WrappedStandardExchangeRateProviderRepo
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/wrapped/WrappedStandardExchangeRateProviderRepo.sol";

interface IWrappedStandardExchangeRateProviderDFPkg is IDiamondFactoryPackage {
	struct PkgInit {
		IFacet rateProviderFacet;
		IDiamondPackageCallBackFactory diamondFactory;
	}

	struct PkgArgs {
		IERC4626 rateSubject;
		IStandardExchangeIn standardExchange;
		IERC20 rateTarget;
	}

	function deployRateProvider(IERC4626 rateSubject, IStandardExchangeIn standardExchange, IERC20 rateTarget)
		external
		returns (IRateProvider rateProviderAddress);

}

contract WrappedStandardExchangeRateProviderDFPkg is IWrappedStandardExchangeRateProviderDFPkg {
	using BetterEfficientHashLib for bytes;
	using BetterSafeERC20 for IERC20Metadata;

	error WrappedAssetDoesNotSupportIERC165(address asset);
	error WrappedAssetDoesNotSupportIStandardExchangeIn(address asset);

	IFacet immutable RATE_PROVIDER_FACET;

	IDiamondPackageCallBackFactory immutable DIAMOND_FACTORY;

	constructor(PkgInit memory pkgInit) {
		RATE_PROVIDER_FACET = pkgInit.rateProviderFacet;
		DIAMOND_FACTORY = pkgInit.diamondFactory;
	}

	function deployRateProvider(IERC4626 rateSubject, IStandardExchangeIn standardExchange, IERC20 rateTarget)
		external
		returns (IRateProvider rateProviderAddress)
	{
		return IRateProvider(
			DIAMOND_FACTORY.deploy(
				this,
				abi.encode(PkgArgs({rateSubject: rateSubject, standardExchange: standardExchange, rateTarget: rateTarget}))
			)
		);
	}

	function packageName() public pure returns (string memory name_) {
		return type(WrappedStandardExchangeRateProviderDFPkg).name;
	}

	function facetAddresses() public view returns (address[] memory facetAddresses_) {
		facetAddresses_ = new address[](1);
		facetAddresses_[0] = address(RATE_PROVIDER_FACET);
	}

	function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
		interfaces_ = new bytes4[](2);
		interfaces_[0] = type(IRateProvider).interfaceId;
		interfaces_[1] = type(IWrappedStandardExchangeRateProvider).interfaceId;
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

	function updatePkg(address, bytes memory) public pure returns (bool) {
		return true;
	}

	function initAccount(bytes memory initArgs) public {
		PkgArgs memory decoded = abi.decode(initArgs, (PkgArgs));

		IERC20 reserveVaultToken = IERC20(decoded.rateSubject.asset());
		if (!_supportsInterface(address(reserveVaultToken), type(IERC165).interfaceId)) {
			revert WrappedAssetDoesNotSupportIERC165(address(reserveVaultToken));
		}
		if (!_supportsInterface(address(reserveVaultToken), type(IStandardExchangeIn).interfaceId)) {
			revert WrappedAssetDoesNotSupportIStandardExchangeIn(address(reserveVaultToken));
		}

		uint8 assetDecimals = IERC20Metadata(address(reserveVaultToken)).safeDecimals();
		uint8 targetDecimals = IERC20Metadata(address(decoded.rateTarget)).safeDecimals();

		WrappedStandardExchangeRateProviderRepo._initialize(
			decoded.rateSubject,
			reserveVaultToken,
			decoded.standardExchange,
			decoded.rateTarget,
			assetDecimals,
			targetDecimals
		);
	}

	function _supportsInterface(address subject_, bytes4 interfaceId_) internal view returns (bool supports_) {
		(bool ok, bytes memory data) =
			subject_.staticcall(abi.encodeWithSelector(IERC165.supportsInterface.selector, interfaceId_));
		if (!ok || data.length < 32) {
			return false;
		}
		supports_ = abi.decode(data, (bool));
	}

	function postDeploy(address) public pure returns (bool) {
		return true;
	}

}