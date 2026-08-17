// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FixtureEconomics} from "./FixtureEconomics.sol";
import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {DetfComponentFactoryService} from "contracts/vaults/detf/common/factory/DetfComponentFactoryService.sol";
import {DetfFacetFactoryService} from "contracts/vaults/detf/common/factory/DetfFacetFactoryService.sol";
import {DetfPkgFactoryService} from "contracts/vaults/detf/common/factory/DetfPkgFactoryService.sol";
import {IDETFNFTVaultDFPkg} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/common/factory/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IUniswapV4StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol";
import {
    UniswapV4_Component_FactoryService
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4_Component_FactoryService.sol";

import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage as ICpHookPkg
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg as CpHookDFPkg
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService as CpHookFS
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol";

import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage as IOrbHookPkg
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookDFPkg as OrbHookDFPkg
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookDFPkg.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHook_FactoryService as OrbHookFS
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_FactoryService.sol";

import {
    IUniswapV4StandardExchangeWeightedBufferHookPackage as IWgtHookPkg
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookDFPkg as WgtHookDFPkg
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHook_FactoryService as WgtHookFS
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_FactoryService.sol";

import {
    IUniswapV4SingleStandardExchangeBufferHookPackage as ISingleHookPkg
} from "contracts/hooks/uniswap/v4/standardExchange/single/interfaces/IUniswapV4SingleStandardExchangeBufferHookPackage.sol";
import {
    UniswapV4SingleStandardExchangeBufferHookDFPkg as SingleHookDFPkg
} from "contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookDFPkg.sol";
import {
    UniswapV4SingleStandardExchangeBufferHook_FactoryService as SingleHookFS
} from "contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHook_FactoryService.sol";

import {
    IUniswapV4SingleStandardExchangeDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";
import {
    UniswapV4SingleStandardExchangeDETF_Component_FactoryService as CpDetfFS
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeDETF_Component_FactoryService.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";
import {
    UniswapV4StandardExchangeOrbitalDETF_Component_FactoryService as OrbDetfFS
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalDETF_Component_FactoryService.sol";
import {
    IUniswapV4StandardExchangeWeightedDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedDETF.sol";
import {
    UniswapV4StandardExchangeWeightedDETF_Component_FactoryService as WgtDetfFS
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETF_Component_FactoryService.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage as IQuadHookPkg
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg as QuadHookDFPkg
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHook_FactoryService as QuadHookFS
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_FactoryService.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableDETF.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableDETF_Component_FactoryService as QuadDetfFS
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableDETF_Component_FactoryService.sol";
import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";

/// @title Stage_03_UniV4Packages
/// @notice Uni V4 hook + SE + DETF packages (no instances).
library Stage_03_UniV4Packages {
    using BetterEfficientHashLib for bytes;
    using VaultComponentFactoryService for ICreate3FactoryProxy;
    using DetfFacetFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for IVaultRegistryDeployment;
    using UniswapV4_Component_FactoryService for ICreate3FactoryProxy;
    using UniswapV4_Component_FactoryService for IIndexedexManagerProxy;
    using CpDetfFS for ICreate3FactoryProxy;
    using CpDetfFS for IVaultRegistryDeployment;
    using OrbDetfFS for ICreate3FactoryProxy;
    using OrbDetfFS for IVaultRegistryDeployment;
    using WgtDetfFS for ICreate3FactoryProxy;
    using WgtDetfFS for IVaultRegistryDeployment;
    using QuadDetfFS for ICreate3FactoryProxy;
    using QuadDetfFS for IVaultRegistryDeployment;

    function execute(LaunchState storage s) internal {
        _deployHookPackages(s);
        _deployUniV4SePkg(s);
        _deployDetfChildren(s);
        _deployDetfPackages(s);
    }

    function _deployHookPackages(LaunchState storage s) private {
        IVaultRegistryDeployment reg = IVaultRegistryDeployment(address(s.indexedexManager));
        IVaultFeeOracleQuery feeOracle = IVaultFeeOracleQuery(address(s.indexedexManager));

        {
            IFacet seFacet = CpHookFS.deploySeFacet(s.create3Factory);
            IFacet depositFacet = CpHookFS.deployDepositFacet(s.create3Factory);
            IFacet withdrawFacet = CpHookFS.deployWithdrawFacet(s.create3Factory);
            ICpHookPkg.PkgInit memory init_;
            init_.vaultRegistryDeployment = reg;
            init_.vaultFeeOracleQuery = feeOracle;
            init_.seFacet = seFacet;
            init_.depositFacet = depositFacet;
            init_.withdrawFacet = withdrawFacet;
            init_.erc20Facet = s.erc20Facet;
            init_.erc5267Facet = s.erc5267Facet;
            init_.erc2612Facet = s.erc2612Facet;
            init_.multiAssetBasicVaultFacet = s.multiAssetBasicVaultFacet;
            init_.multiAssetStandardVaultFacet = s.multiAssetStandardVaultFacet;
            s.cpHookPkg = reg.deployPkg(
                type(CpHookDFPkg).creationCode,
                abi.encode(init_),
                abi.encode(type(ICpHookPkg).name, FixtureEconomics.SALT_NS)._hash()
            );
        }

        {
            IFacet depositFacet = OrbHookFS.deployDepositFacet(s.create3Factory);
            IFacet withdrawFacet = OrbHookFS.deployWithdrawFacet(s.create3Factory);
            IFacet seFacet = OrbHookFS.deploySeFacet(s.create3Factory);
            IFacet hooksFacet = OrbHookFS.deployHooksFacet(s.create3Factory);
            IOrbHookPkg.PkgInit memory init_;
            init_.vaultRegistryDeployment = reg;
            init_.vaultFeeOracleQuery = feeOracle;
            init_.depositFacet = depositFacet;
            init_.withdrawFacet = withdrawFacet;
            init_.seFacet = seFacet;
            init_.hooksFacet = hooksFacet;
            init_.erc20Facet = s.erc20Facet;
            init_.erc5267Facet = s.erc5267Facet;
            init_.erc2612Facet = s.erc2612Facet;
            init_.multiAssetBasicVaultFacet = s.multiAssetBasicVaultFacet;
            init_.multiAssetStandardVaultFacet = s.multiAssetStandardVaultFacet;
            s.orbitalHookPkg = reg.deployPkg(
                type(OrbHookDFPkg).creationCode,
                abi.encode(init_),
                abi.encode(type(IOrbHookPkg).name, FixtureEconomics.SALT_NS)._hash()
            );
        }

        {
            IFacet joinFacet = WgtHookFS.deployJoinFacet(s.create3Factory);
            IFacet exitFacet = WgtHookFS.deployExitFacet(s.create3Factory);
            IFacet seFacet = WgtHookFS.deploySeFacet(s.create3Factory);
            IFacet hooksFacet = WgtHookFS.deployHooksFacet(s.create3Factory);
            IWgtHookPkg.PkgInit memory init_;
            init_.vaultRegistryDeployment = reg;
            init_.vaultFeeOracleQuery = feeOracle;
            init_.joinFacet = joinFacet;
            init_.exitFacet = exitFacet;
            init_.seFacet = seFacet;
            init_.hooksFacet = hooksFacet;
            init_.erc20Facet = s.erc20Facet;
            init_.erc5267Facet = s.erc5267Facet;
            init_.erc2612Facet = s.erc2612Facet;
            init_.multiAssetBasicVaultFacet = s.multiAssetBasicVaultFacet;
            init_.multiAssetStandardVaultFacet = s.multiAssetStandardVaultFacet;
            s.weightedHookPkg = reg.deployPkg(
                type(WgtHookDFPkg).creationCode,
                abi.encode(init_),
                abi.encode(type(IWgtHookPkg).name, FixtureEconomics.SALT_NS)._hash()
            );
        }

        {
            IFacet productFacet = SingleHookFS.deployProductFacet(s.create3Factory);
            ISingleHookPkg.PkgInit memory init_;
            init_.vaultRegistryDeployment = reg;
            init_.productFacet = productFacet;
            init_.multiAssetBasicVaultFacet = s.multiAssetBasicVaultFacet;
            init_.multiAssetStandardVaultFacet = s.multiAssetStandardVaultFacet;
            s.singleSeBufferHookPkg = reg.deployPkg(
                type(SingleHookDFPkg).creationCode,
                abi.encode(init_),
                abi.encode(type(ISingleHookPkg).name, FixtureEconomics.SALT_NS)._hash()
            );
        }

        {
            IFacet joinFacet = QuadHookFS.deployJoinFacet(s.create3Factory);
            IFacet exitFacet = QuadHookFS.deployExitFacet(s.create3Factory);
            IFacet seFacet = QuadHookFS.deploySeFacet(s.create3Factory);
            IFacet hooksFacet = QuadHookFS.deployHooksFacet(s.create3Factory);
            IQuadHookPkg.PkgInit memory init_;
            init_.vaultRegistryDeployment = reg;
            init_.vaultFeeOracleQuery = feeOracle;
            init_.liquidityFacet = joinFacet;
            init_.exitFacet = exitFacet;
            init_.seFacet = seFacet;
            init_.hooksFacet = hooksFacet;
            init_.erc20Facet = s.erc20Facet;
            init_.erc5267Facet = s.erc5267Facet;
            init_.erc2612Facet = s.erc2612Facet;
            init_.multiAssetBasicVaultFacet = s.multiAssetBasicVaultFacet;
            init_.multiAssetStandardVaultFacet = s.multiAssetStandardVaultFacet;
            s.curveQuadHookPkg = reg.deployPkg(
                type(QuadHookDFPkg).creationCode,
                abi.encode(init_),
                abi.encode(type(IQuadHookPkg).name, FixtureEconomics.SALT_NS)._hash()
            );
        }
    }

    function _deployUniV4SePkg(LaunchState storage s) private {
        IUniswapV4StandardExchangeDFPkg.PkgInit memory pkgInit;
        pkgInit.erc20Facet = s.erc20Facet;
        pkgInit.erc5267Facet = s.erc5267Facet;
        pkgInit.erc2612Facet = s.erc2612Facet;
        pkgInit.multiAssetBasicVaultFacet = s.multiAssetBasicVaultFacet;
        pkgInit.multiAssetStandardVaultFacet = s.multiAssetStandardVaultFacet;
        pkgInit.uniswapV4StandardExchangeInFacet = s.create3Factory.deployUniswapV4StandardExchangeInFacet();
        pkgInit.uniswapV4StandardExchangeInQueryFacet = s.create3Factory.deployUniswapV4StandardExchangeInQueryFacet();
        pkgInit.uniswapV4StandardExchangePositionImportFacet =
            s.create3Factory.deployUniswapV4StandardExchangePositionImportFacet();
        pkgInit.uniswapV4StandardExchangeOutFacet = s.create3Factory.deployUniswapV4StandardExchangeOutFacet();
        pkgInit.uniswapV4StandardExchangeOutQueryFacet = s.create3Factory.deployUniswapV4StandardExchangeOutQueryFacet();
        pkgInit.uniswapV4StandardExchangeLiquidReserveFacet =
            s.create3Factory.deployUniswapV4StandardExchangeLiquidReserveFacet();
        pkgInit.vaultFeeOracleQuery = IVaultFeeOracleQuery(address(s.indexedexManager));
        pkgInit.vaultRegistryDeployment = IVaultRegistryDeployment(address(s.indexedexManager));
        pkgInit.permit2 = IPermit2(RobinhoodCanonicalLib.permit2());
        pkgInit.poolManager = IPoolManager(RobinhoodCanonicalLib.poolManager());
        pkgInit.positionManager = IPositionManager(RobinhoodCanonicalLib.positionManagerV4());

        s.uniV4SePkg = s.indexedexManager.deployUniswapV4StandardExchangeDFPkg(pkgInit);
    }

    function _deployDetfChildren(LaunchState storage s) private {
        IFacet claimFacet_ = s.create3Factory.deployRebasingClaimTokenFacet();
        s.rebasingClaimTokenPkg = address(
            s.create3Factory.deployRebasingClaimTokenDFPkg(
                DetfComponentFactoryService.buildRICHIRPkgInit(
                    s.erc20Facet, s.erc5267Facet, s.erc2612Facet, claimFacet_, s.diamondPackageFactory
                )
            )
        );

        IFacet detfNFTVaultFacet = s.create3Factory.deployDETFNFTVaultFacet();
        IFacet erc721FacetDetf = IFacet(
            s.create3Factory.deployFacet(type(ERC721Facet).creationCode, keccak256("RhTestnet_ERC721Facet"))
        );
        IDETFNFTVaultDFPkg.PkgInit memory nftPkgInit = DetfComponentFactoryService.buildDETFNFTVaultPkgInit(
            erc721FacetDetf,
            s.erc4626BasicVaultFacet,
            s.erc4626StandardVaultFacet,
            detfNFTVaultFacet,
            IVaultFeeOracleQuery(address(s.indexedexManager)),
            IVaultRegistryDeployment(address(s.indexedexManager))
        );
        s.bondNftVaultPkg =
            address(IVaultRegistryDeployment(address(s.indexedexManager)).deployDETFNFTVaultDFPkg(nftPkgInit));

    }

    function _deployDetfPackages(LaunchState storage s) private {
        IVaultRegistryDeployment reg = IVaultRegistryDeployment(address(s.indexedexManager));
        IPoolManager pm = IPoolManager(RobinhoodCanonicalLib.poolManager());
        IFacet multiAssetBasic = s.create3Factory.deployMultiAssetBasicVaultFacet();
        IFacet multiAssetStd = s.create3Factory.deployMultiAssetStandardVaultFacet();

        {
            IFacet exchangeInFacet = CpDetfFS.deployExchangeInFacet(s.create3Factory);
            IUniswapV4SingleStandardExchangeDETDFPkg.PkgInit memory init_;
            init_.erc20Facet = s.erc20Facet;
            init_.erc5267Facet = s.erc5267Facet;
            init_.erc2612Facet = s.erc2612Facet;
            init_.multiAssetBasicVaultFacet = multiAssetBasic;
            init_.multiAssetStandardVaultFacet = multiAssetStd;
            init_.exchangeInFacet = exchangeInFacet;
            init_.feeOracle = IVaultFeeOracleQuery(address(s.indexedexManager));
            init_.vaultRegistryDeployment = reg;
            init_.poolManager = pm;
            init_.hookPkg = ICpHookPkg(s.cpHookPkg);
            init_.bondNftVaultPkg = IDetfSelfNftInventoryDFPkg(s.bondNftVaultPkg);
            init_.rebasingClaimTokenPkg = IRebasingClaimTokenDFPkg(s.rebasingClaimTokenPkg);
            init_.diamondFactory = s.diamondPackageFactory;
            s.cpDetfPkg = address(CpDetfFS.deployPkg(reg, init_));
        }

        {
            IFacet exchangeInFacet = OrbDetfFS.deployExchangeInFacet(s.create3Factory);
            IFacet bondingFacet = OrbDetfFS.deployBondingFacet(s.create3Factory);
            IFacet infoFacet = OrbDetfFS.deployInfoFacet(s.create3Factory);
            IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgInit memory init_;
            init_.erc20Facet = s.erc20Facet;
            init_.erc5267Facet = s.erc5267Facet;
            init_.erc2612Facet = s.erc2612Facet;
            init_.multiAssetBasicVaultFacet = multiAssetBasic;
            init_.multiAssetStandardVaultFacet = multiAssetStd;
            init_.exchangeInFacet = exchangeInFacet;
            init_.bondingFacet = bondingFacet;
            init_.infoFacet = infoFacet;
            init_.feeOracle = IVaultFeeOracleQuery(address(s.indexedexManager));
            init_.vaultRegistryDeployment = reg;
            init_.poolManager = pm;
            init_.hookPkg = IOrbHookPkg(s.orbitalHookPkg);
            init_.bondNftVaultPkg = IDetfSelfNftInventoryDFPkg(s.bondNftVaultPkg);
            init_.rebasingClaimTokenPkg = IRebasingClaimTokenDFPkg(s.rebasingClaimTokenPkg);
            init_.diamondFactory = s.diamondPackageFactory;
            s.orbitalDetfPkg = address(OrbDetfFS.deployPkg(reg, init_));
        }

        {
            IFacet exchangeInFacet = WgtDetfFS.deployExchangeInFacet(s.create3Factory);
            IFacet bondingFacet = WgtDetfFS.deployBondingFacet(s.create3Factory);
            IFacet compoundFacet = WgtDetfFS.deployCompoundFacet(s.create3Factory);
            IFacet infoFacet = WgtDetfFS.deployInfoFacet(s.create3Factory);
            IUniswapV4StandardExchangeWeightedDETDFPkg.PkgInit memory init_;
            init_.erc20Facet = s.erc20Facet;
            init_.erc5267Facet = s.erc5267Facet;
            init_.erc2612Facet = s.erc2612Facet;
            init_.multiAssetBasicVaultFacet = multiAssetBasic;
            init_.multiAssetStandardVaultFacet = multiAssetStd;
            init_.exchangeInFacet = exchangeInFacet;
            init_.bondingFacet = bondingFacet;
            init_.compoundFacet = compoundFacet;
            init_.infoFacet = infoFacet;
            init_.feeOracle = IVaultFeeOracleQuery(address(s.indexedexManager));
            init_.vaultRegistryDeployment = reg;
            init_.poolManager = pm;
            init_.hookPkg = IWgtHookPkg(s.weightedHookPkg);
            init_.bondNftVaultPkg = IDetfSelfNftInventoryDFPkg(s.bondNftVaultPkg);
            init_.rebasingClaimTokenPkg = IRebasingClaimTokenDFPkg(s.rebasingClaimTokenPkg);
            init_.diamondFactory = s.diamondPackageFactory;
            s.weightedDetfPkg = address(WgtDetfFS.deployPkg(reg, init_));
        }

        {
            IFacet exchangeInFacet = QuadDetfFS.deployExchangeInFacet(s.create3Factory);
            IFacet bondingFacet = QuadDetfFS.deployBondingFacet(s.create3Factory);
            IFacet compoundFacet = QuadDetfFS.deployCompoundFacet(s.create3Factory);
            IFacet infoFacet = QuadDetfFS.deployInfoFacet(s.create3Factory);
            IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgInit memory init_;
            init_.erc20Facet = s.erc20Facet;
            init_.erc5267Facet = s.erc5267Facet;
            init_.erc2612Facet = s.erc2612Facet;
            init_.multiAssetBasicVaultFacet = multiAssetBasic;
            init_.multiAssetStandardVaultFacet = multiAssetStd;
            init_.exchangeInFacet = exchangeInFacet;
            init_.bondingFacet = bondingFacet;
            init_.compoundFacet = compoundFacet;
            init_.infoFacet = infoFacet;
            init_.feeOracle = IVaultFeeOracleQuery(address(s.indexedexManager));
            init_.vaultRegistryDeployment = reg;
            init_.poolManager = pm;
            init_.hookPkg = IQuadHookPkg(s.curveQuadHookPkg);
            init_.bondNftVaultPkg = IDetfSelfNftInventoryDFPkg(s.bondNftVaultPkg);
            init_.rebasingClaimTokenPkg = IRebasingClaimTokenDFPkg(s.rebasingClaimTokenPkg);
            init_.diamondFactory = s.diamondPackageFactory;
            s.curveQuadDetfPkg = address(QuadDetfFS.deployPkg(reg, init_));
        }
    }
}
