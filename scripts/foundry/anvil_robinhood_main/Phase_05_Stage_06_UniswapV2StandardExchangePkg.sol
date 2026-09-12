// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IUniswapV2Factory} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Factory.sol";
import {IUniswapV2Router} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Router.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IUniswapV2StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol";
import {UniswapV2_Component_FactoryService} from "contracts/protocols/dexes/uniswap/v2/UniswapV2_Component_FactoryService.sol";

library Phase_05_Stage_06_UniswapV2StandardExchangePkg {
    using UniswapV2_Component_FactoryService for ICreate3FactoryProxy;
    using UniswapV2_Component_FactoryService for IVaultRegistryDeployment;

    function execute(LaunchState storage s) internal {
        address factory_ = RobinhoodCanonicalLib.v2Factory();
        address router_ = RobinhoodCanonicalLib.v2Router();
        require(factory_.code.length > 0 && router_.code.length > 0, "Phase 05-06: V2 pins");
        require(IUniswapV2Router(router_).factory() == factory_, "Phase 05-06: V2 router factory");
        IUniswapV2StandardExchangeDFPkg.PkgInit memory init_;
        init_.erc20Facet = s.erc20Facet;
        init_.erc5267Facet = s.erc5267Facet;
        init_.erc2612Facet = s.erc2612Facet;
        init_.erc4626Facet = s.erc4626Facet;
        init_.multiAssetBasicVaultFacet = s.multiAssetBasicVaultFacet;
        init_.multiAssetStandardVaultFacet = s.multiAssetStandardVaultFacet;
        init_.uniswapV2StandardExchangeInFacet = s.create3Factory.deployUniswapV2StandardExchangeInFacet();
        init_.uniswapV2StandardExchangeOutFacet = s.create3Factory.deployUniswapV2StandardExchangeOutFacet();
        init_.uniswapV2StandardExchangeQueryFacet = s.create3Factory.deployUniswapV2StandardExchangeQueryFacet();
        init_.vaultFeeOracleQuery = IVaultFeeOracleQuery(address(s.indexedexManager));
        init_.vaultRegistryDeployment = IVaultRegistryDeployment(address(s.indexedexManager));
        init_.permit2 = IPermit2(RobinhoodCanonicalLib.permit2());
        init_.uniswapV2Factory = IUniswapV2Factory(factory_);
        init_.uniswapV2Router = IUniswapV2Router(router_);
        s.uniV2SePkg = address(IVaultRegistryDeployment(address(s.indexedexManager)).deployUniswapV2StandardExchangeDFPkg(init_));
    }
}
