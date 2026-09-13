// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

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
