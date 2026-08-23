// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FixtureEconomics} from "./FixtureEconomics.sol";
import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/common/factory/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";

import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage as IOrbitalHookPkg
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookDFPkg as OrbitalHookDFPkg
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookDFPkg.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHook_FactoryService as OrbitalHookFS
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_FactoryService.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";
import {
    UniswapV4StandardExchangeOrbitalDETF_Component_FactoryService as OrbitalDetfFS
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalDETF_Component_FactoryService.sol";

import {
    IUniswapV4StandardExchangeWeightedBufferHookPackage as IWeightedHookPkg
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookDFPkg as WeightedHookDFPkg
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHook_FactoryService as WeightedHookFS
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_FactoryService.sol";
import {
    IUniswapV4StandardExchangeWeightedDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedDETF.sol";
import {
    UniswapV4StandardExchangeWeightedDETF_Component_FactoryService as WeightedDetfFS
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETF_Component_FactoryService.sol";

/// @title Stage_03b_OrbitalWeightedPackages
/// @notice Orbital + Weighted Uni V4 hook DFPkgs and DETF DFPkgs. No instances.
/// @dev Part of `all` / `foundation` after group 03.
library Stage_03b_OrbitalWeightedPackages {
    using BetterEfficientHashLib for bytes;
    using OrbitalDetfFS for IVaultRegistryDeployment;
    using WeightedDetfFS for IVaultRegistryDeployment;

    function execute(LaunchState storage s) internal {
        _deployOrbitalHookPkg(s);
        _deployWeightedHookPkg(s);
        _deployOrbitalDetfPkg(s);
        _deployWeightedDetfPkg(s);
    }

    function _deployOrbitalHookPkg(LaunchState storage s) private {
        if (s.orbitalHookPkg != address(0) && s.orbitalHookPkg.code.length > 0) return;
        IVaultRegistryDeployment reg = IVaultRegistryDeployment(address(s.indexedexManager));
        IVaultFeeOracleQuery feeOracle = IVaultFeeOracleQuery(address(s.indexedexManager));
        IFacet depositFacet = OrbitalHookFS.deployDepositFacet(s.create3Factory);
        IFacet withdrawFacet = OrbitalHookFS.deployWithdrawFacet(s.create3Factory);
        IFacet seFacet = OrbitalHookFS.deploySeFacet(s.create3Factory);
        IFacet hooksFacet = OrbitalHookFS.deployHooksFacet(s.create3Factory);
        IOrbitalHookPkg.PkgInit memory init_;
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
        init_.multiStepOwnableFacet = s.multiStepOwnableFacet;
        s.orbitalHookPkg = reg.deployPkg(
            type(OrbitalHookDFPkg).creationCode,
            abi.encode(init_),
            abi.encode(type(IOrbitalHookPkg).name, FixtureEconomics.SALT_NS)._hash()
        );
    }

    function _deployWeightedHookPkg(LaunchState storage s) private {
        if (s.weightedHookPkg != address(0) && s.weightedHookPkg.code.length > 0) return;
        IVaultRegistryDeployment reg = IVaultRegistryDeployment(address(s.indexedexManager));
        IVaultFeeOracleQuery feeOracle = IVaultFeeOracleQuery(address(s.indexedexManager));
        IFacet joinFacet = WeightedHookFS.deployJoinFacet(s.create3Factory);
        IFacet exitFacet = WeightedHookFS.deployExitFacet(s.create3Factory);
        IFacet seFacet = WeightedHookFS.deploySeFacet(s.create3Factory);
        IFacet hooksFacet = WeightedHookFS.deployHooksFacet(s.create3Factory);
        IWeightedHookPkg.PkgInit memory init_;
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
        init_.multiStepOwnableFacet = s.multiStepOwnableFacet;
        s.weightedHookPkg = reg.deployPkg(
            type(WeightedHookDFPkg).creationCode,
            abi.encode(init_),
            abi.encode(type(IWeightedHookPkg).name, FixtureEconomics.SALT_NS)._hash()
        );
    }

    function _deployOrbitalDetfPkg(LaunchState storage s) private {
        if (s.orbitalDetfPkg != address(0) && s.orbitalDetfPkg.code.length > 0) return;
        require(s.orbitalHookPkg != address(0) && s.orbitalHookPkg.code.length > 0, "03b: orbitalHookPkg");
        require(s.bondNftVaultPkg != address(0) && s.bondNftVaultPkg.code.length > 0, "03b: bondNftVaultPkg");
        require(s.rebasingClaimTokenPkg != address(0) && s.rebasingClaimTokenPkg.code.length > 0, "03b: claimPkg");
        IVaultRegistryDeployment reg = IVaultRegistryDeployment(address(s.indexedexManager));
        IFacet exchangeInFacet = OrbitalDetfFS.deployExchangeInFacet(s.create3Factory);
        IFacet bondingFacet = OrbitalDetfFS.deployBondingFacet(s.create3Factory);
        IFacet infoFacet = OrbitalDetfFS.deployInfoFacet(s.create3Factory);
        IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgInit memory init_;
        init_.erc20Facet = s.erc20Facet;
        init_.erc5267Facet = s.erc5267Facet;
        init_.erc2612Facet = s.erc2612Facet;
        init_.multiAssetBasicVaultFacet = s.multiAssetBasicVaultFacet;
        init_.multiAssetStandardVaultFacet = s.multiAssetStandardVaultFacet;
        init_.exchangeInFacet = exchangeInFacet;
        init_.bondingFacet = bondingFacet;
        init_.infoFacet = infoFacet;
        init_.feeOracle = IVaultFeeOracleQuery(address(s.indexedexManager));
        init_.vaultRegistryDeployment = reg;
        init_.poolManager = IPoolManager(RobinhoodCanonicalLib.poolManager());
        init_.hookPkg = IOrbitalHookPkg(s.orbitalHookPkg);
        init_.bondNftVaultPkg = IDetfSelfNftInventoryDFPkg(s.bondNftVaultPkg);
        init_.rebasingClaimTokenPkg = IRebasingClaimTokenDFPkg(s.rebasingClaimTokenPkg);
        init_.diamondFactory = s.diamondPackageFactory;
        s.orbitalDetfPkg = address(OrbitalDetfFS.deployPkg(reg, init_));
    }

    function _deployWeightedDetfPkg(LaunchState storage s) private {
        if (s.weightedDetfPkg != address(0) && s.weightedDetfPkg.code.length > 0) return;
        require(s.weightedHookPkg != address(0) && s.weightedHookPkg.code.length > 0, "03b: weightedHookPkg");
        require(s.bondNftVaultPkg != address(0) && s.bondNftVaultPkg.code.length > 0, "03b: bondNftVaultPkg");
        require(s.rebasingClaimTokenPkg != address(0) && s.rebasingClaimTokenPkg.code.length > 0, "03b: claimPkg");
        IVaultRegistryDeployment reg = IVaultRegistryDeployment(address(s.indexedexManager));
        IFacet exchangeInFacet = WeightedDetfFS.deployExchangeInFacet(s.create3Factory);
        IFacet bondingFacet = WeightedDetfFS.deployBondingFacet(s.create3Factory);
        IFacet compoundFacet = WeightedDetfFS.deployCompoundFacet(s.create3Factory);
        IFacet infoFacet = WeightedDetfFS.deployInfoFacet(s.create3Factory);
        IUniswapV4StandardExchangeWeightedDETDFPkg.PkgInit memory init_;
        init_.erc20Facet = s.erc20Facet;
        init_.erc5267Facet = s.erc5267Facet;
        init_.erc2612Facet = s.erc2612Facet;
        init_.multiAssetBasicVaultFacet = s.multiAssetBasicVaultFacet;
        init_.multiAssetStandardVaultFacet = s.multiAssetStandardVaultFacet;
        init_.exchangeInFacet = exchangeInFacet;
        init_.bondingFacet = bondingFacet;
        init_.compoundFacet = compoundFacet;
        init_.infoFacet = infoFacet;
        init_.feeOracle = IVaultFeeOracleQuery(address(s.indexedexManager));
        init_.vaultRegistryDeployment = reg;
        init_.poolManager = IPoolManager(RobinhoodCanonicalLib.poolManager());
        init_.hookPkg = IWeightedHookPkg(s.weightedHookPkg);
        init_.bondNftVaultPkg = IDetfSelfNftInventoryDFPkg(s.bondNftVaultPkg);
        init_.rebasingClaimTokenPkg = IRebasingClaimTokenDFPkg(s.rebasingClaimTokenPkg);
        init_.diamondFactory = s.diamondPackageFactory;
        s.weightedDetfPkg = address(WeightedDetfFS.deployPkg(reg, init_));
    }
}
