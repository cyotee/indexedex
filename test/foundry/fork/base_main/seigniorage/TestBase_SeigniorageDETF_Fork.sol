// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IRouter} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRouter.sol";
import {
    WeightedPool8020Factory
} from "@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPool8020Factory.sol";
import {RateProviderMock} from "contracts/test/balancer/v3/RateProviderMock.sol";

// Crane IERC20 imported below

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {
    IERC20PermitMintBurnLockedOwnableDFPkg,
    ERC20PermitMintBurnLockedOwnableDFPkg
} from "@crane/contracts/tokens/ERC20/ERC20PermitMintBurnLockedOwnableDFPkg.sol";
import {ERC20MintBurnOwnableFacet} from "@crane/contracts/tokens/ERC20/ERC20MintBurnOwnableFacet.sol";
import {BetterAddress} from "@crane/contracts/utils/BetterAddress.sol";
import {
    IWeightedPool8020Factory
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool8020Factory.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {
    TestBase_BalancerV3Fork_StrategyVault
} from "test/foundry/fork/base_main/balancer/v3/TestBase_BalancerV3Fork_StrategyVault.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultRegistryVaultPackageManager} from "contracts/interfaces/IVaultRegistryVaultPackageManager.sol";
import {IVaultRegistryVaultPackageQuery} from "contracts/interfaces/IVaultRegistryVaultPackageQuery.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";

import {ISeigniorageDETF} from "contracts/interfaces/ISeigniorageDETF.sol";
import {ISeigniorageNFTVault} from "contracts/interfaces/ISeigniorageNFTVault.sol";
import {ISeigniorageDETFUnderwriting} from "contracts/vaults/seigniorage/SeigniorageDETFUnderwritingTarget.sol";

import {ISeigniorageDETFDFPkg, SeigniorageDETFDFPkg} from "contracts/vaults/seigniorage/SeigniorageDETFDFPkg.sol";

import {
    ISeigniorageNFTVaultDFPkg,
    SeigniorageNFTVaultDFPkg
} from "contracts/vaults/seigniorage/SeigniorageNFTVaultDFPkg.sol";

import {
    Seigniorage_Component_FactoryService
} from "contracts/vaults/seigniorage/Seigniorage_Component_FactoryService.sol";

import {
    IStandardExchangeRateProviderDFPkg,
    StandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/StandardExchangeRateProviderDFPkg.sol";
import {
    StandardExchangeRateProviderFacet
} from "contracts/protocols/dexes/balancer/v3/rateProviders/StandardExchangeRateProviderFacet.sol";

/* -------------------------------------------------------------------------- */
/*                               Test-Only Mock                               */
/* -------------------------------------------------------------------------- */

contract ForkMockSeigniorageNFTVaultDFPkg is SeigniorageNFTVaultDFPkg {
    constructor(PkgInit memory pkgInit) SeigniorageNFTVaultDFPkg(pkgInit) {}

    function processArgs(bytes memory pkgArgs) public pure override returns (bytes memory) {
        return pkgArgs;
    }
}

/**
 * @title TestBase_SeigniorageDETF_Fork
 * @notice Base test fixture for Seigniorage DETF fork tests on Base mainnet.
 * @dev Deploys a full Seigniorage DETF vault wired to:
 *      - live Base Balancer V3 Vault/Router bytecode
 *      - a fork-local Aerodrome DAI/USDC pool + StandardExchange reserve vault
 */
contract TestBase_SeigniorageDETF_Fork is TestBase_BalancerV3Fork_StrategyVault {
    using Seigniorage_Component_FactoryService for *;
    using BetterAddress for address;

    uint256 internal constant UNDERWRITE_AMOUNT = 1_000e18;
    uint256 internal constant LOCK_DURATION = 30 days;
    uint256 internal constant DEFAULT_SWAP_FEE = 1e16;

    WeightedPool8020Factory internal weighted8020Factory;
    RateProviderMock internal reserveVaultRateProvider;

    ISeigniorageDETFDFPkg internal detfDFPkg;
    ISeigniorageDETF internal detf;
    address internal reservePoolAddress;

    struct DeploymentScenario {
        address detfPredicted;
        ISeigniorageDETFDFPkg.PkgArgs pkgArgs;
    }

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager))
            .setDefaultDexSwapFeeOfTypeId(type(ISeigniorageDETFUnderwriting).interfaceId, DEFAULT_SWAP_FEE);
        vm.stopPrank();

        _deployWeightedPool8020Factory();
        _deploySeigniorageDetf();
    }

    function _deployWeightedPool8020Factory() internal {
        bytes32 salt = keccak256("SeigniorageWeightedPool8020Factory");
        bytes memory initCode = type(WeightedPool8020Factory).creationCode;
        bytes memory initArgs = abi.encode(IVault(address(vault)), uint32(365 days), "Factory v1", "8020Pool v1");

        address factoryAddr = create3Factory.create3WithArgs(initCode, initArgs, salt);
        weighted8020Factory = WeightedPool8020Factory(factoryAddr);
        vm.label(factoryAddr, "WeightedPool8020Factory");

        bytes32 rpSalt = keccak256("SeigniorageReserveVaultRateProvider");
        address rpAddr = create3Factory.create3(type(RateProviderMock).creationCode, rpSalt);
        reserveVaultRateProvider = RateProviderMock(rpAddr);
        vm.label(rpAddr, "ReserveVaultRateProvider");
    }

    function _deploySeigniorageDetf() internal {
        (IFacet exchangeInFacet, IFacet exchangeOutFacet, IFacet underwritingFacet, IFacet nftVaultFacet) =
            _deploySeigniorageFacets();
        IFacet erc721Facet = _deployERC721Facet();
        ISeigniorageNFTVaultDFPkg nftVaultPkg = _deployMockNftVaultPkg(erc721Facet, nftVaultFacet);
        IERC20PermitMintBurnLockedOwnableDFPkg seigniorageTokenPkg = _deploySeigniorageTokenPkg();
        IStandardExchangeRateProviderDFPkg reserveVaultRateProviderPkg = _deployStandardExchangeRateProviderPkg();

        detfDFPkg = _deployDetfPkg(
            exchangeInFacet,
            exchangeOutFacet,
            underwritingFacet,
            seigniorageTokenPkg,
            nftVaultPkg,
            reserveVaultRateProviderPkg
        );
        vm.label(address(detfDFPkg), "SeigniorageDETFDFPkg_Fork");

        vm.startPrank(owner);
        IVaultRegistryVaultPackageManager(address(indexedexManager))
            .registerPackage(address(detfDFPkg), IStandardVaultPkg(address(detfDFPkg)).vaultDeclaration());
        vm.stopPrank();

        assertTrue(
            IVaultRegistryVaultPackageQuery(address(indexedexManager)).isPackage(address(detfDFPkg)),
            "DETF package not registered"
        );

        DeploymentScenario memory s = _computeDeploymentScenario();

        vm.startPrank(owner);
        address detfAddr = IVaultRegistryDeployment(address(indexedexManager))
            .deployVault(IStandardVaultPkg(address(detfDFPkg)), abi.encode(s.pkgArgs));
        vm.stopPrank();

        assertEq(detfAddr, s.detfPredicted, "DETF predicted address mismatch");

        detf = ISeigniorageDETF(detfAddr);
        vm.label(detfAddr, "SeigniorageDETF_Fork");

        reservePoolAddress = weighted8020Factory.getPool(IERC20(detfAddr), IERC20(address(daiUsdcVault)));
        vm.label(reservePoolAddress, "SeigniorageReservePool8020_Fork");

        assertEq(detf.reservePool(), reservePoolAddress, "DETF reservePool mismatch");
        assertTrue(reservePoolAddress.isContract(), "Reserve pool not deployed");
    }

    function _deploySeigniorageFacets()
        internal
        returns (IFacet exchangeInFacet, IFacet exchangeOutFacet, IFacet underwritingFacet, IFacet nftVaultFacet)
    {
        exchangeInFacet = create3Factory.deploySeigniorageDETFExchangeInFacet();
        exchangeOutFacet = create3Factory.deploySeigniorageDETFExchangeOutFacet();
        underwritingFacet = create3Factory.deploySeigniorageDETFUnderwritingFacet();
        nftVaultFacet = create3Factory.deploySeigniorageNFTVaultFacet();
    }

    function _deployERC721Facet() internal returns (IFacet erc721Facet) {
        bytes32 facetSalt = keccak256("SeigniorageERC721Facet");
        erc721Facet = IFacet(create3Factory.deployFacet(type(ERC721Facet).creationCode, facetSalt));
    }

    function _deployERC20MintBurnOwnableFacet() internal returns (IFacet facet) {
        bytes32 facetSalt = keccak256("SeigniorageERC20MintBurnOwnableFacet");
        facet = IFacet(create3Factory.deployFacet(type(ERC20MintBurnOwnableFacet).creationCode, facetSalt));
        vm.label(address(facet), "ERC20MintBurnOwnableFacet");
    }

    function _deployMockNftVaultPkg(IFacet erc721Facet, IFacet seigniorageNFTVaultFacet)
        internal
        returns (ISeigniorageNFTVaultDFPkg nftVaultPkg)
    {
        ISeigniorageNFTVaultDFPkg.PkgInit memory nftPkgInit = ISeigniorageNFTVaultDFPkg.PkgInit({
            erc721Facet: erc721Facet,
            erc4626BasicVaultFacet: erc4626BasicVaultFacet,
            erc4626StandardVaultFacet: erc4626StandardVaultFacet,
            seigniorageNFTVaultFacet: seigniorageNFTVaultFacet,
            feeOracle: IVaultFeeOracleQuery(address(indexedexManager)),
            vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager))
        });

        bytes memory initArgs = abi.encode(nftPkgInit);
        bytes memory initCode = type(ForkMockSeigniorageNFTVaultDFPkg).creationCode;

        address pkgAddr =
            create3Factory.create3WithArgs(initCode, initArgs, keccak256("ForkMockSeigniorageNFTVaultDFPkg"));
        nftVaultPkg = ISeigniorageNFTVaultDFPkg(pkgAddr);
        vm.label(pkgAddr, "ForkMockSeigniorageNFTVaultDFPkg");

        vm.startPrank(owner);
        IVaultRegistryVaultPackageManager(address(indexedexManager))
            .registerPackage(pkgAddr, IStandardVaultPkg(pkgAddr).vaultDeclaration());
        vm.stopPrank();

        assertTrue(
            IVaultRegistryVaultPackageQuery(address(indexedexManager)).isPackage(pkgAddr),
            "NFT vault package not registered"
        );
    }

    function _deploySeigniorageTokenPkg()
        internal
        returns (IERC20PermitMintBurnLockedOwnableDFPkg seigniorageTokenPkg)
    {
        bytes32 pkgSalt = keccak256("ERC20PermitMintBurnLockedOwnableDFPkg");

        IFacet mintBurnFacet = _deployERC20MintBurnOwnableFacet();

        IERC20PermitMintBurnLockedOwnableDFPkg.PkgInit memory pkgInit = IERC20PermitMintBurnLockedOwnableDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            erc20MintBurnOwnableFacet: mintBurnFacet,
            diamondFactory: diamondPackageFactory
        });

        seigniorageTokenPkg = IERC20PermitMintBurnLockedOwnableDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(ERC20PermitMintBurnLockedOwnableDFPkg).creationCode, abi.encode(pkgInit), pkgSalt
                )
            )
        );

        vm.label(address(seigniorageTokenPkg), "ERC20PermitMintBurnLockedOwnableDFPkg");
    }

    function _deployDetfPkg(
        IFacet exchangeInFacet,
        IFacet exchangeOutFacet,
        IFacet underwritingFacet,
        IERC20PermitMintBurnLockedOwnableDFPkg seigniorageTokenPkg,
        ISeigniorageNFTVaultDFPkg nftVaultPkg,
        IStandardExchangeRateProviderDFPkg reserveVaultRateProviderPkg
    ) internal returns (ISeigniorageDETFDFPkg) {
        ISeigniorageDETFDFPkg.PkgInit memory pkgInit;
        pkgInit.erc20Facet = erc20Facet;
        pkgInit.erc5267Facet = erc5267Facet;
        pkgInit.erc2612Facet = erc2612Facet;
        pkgInit.erc4626BasicVaultFacet = erc4626BasicVaultFacet;
        pkgInit.erc4626StandardVaultFacet = erc4626StandardVaultFacet;
        pkgInit.seigniorageDETFExchangeInFacet = exchangeInFacet;
        pkgInit.seigniorageDETFExchangeOutFacet = exchangeOutFacet;
        pkgInit.seigniorageDETFUnderwritingFacet = underwritingFacet;
        pkgInit.feeOracle = IVaultFeeOracleQuery(address(indexedexManager));
        pkgInit.vaultRegistryDeployment = IVaultRegistryDeployment(address(indexedexManager));
        pkgInit.permit2 = permit2;
        pkgInit.balancerV3Vault = IVault(address(vault));
        pkgInit.balancerV3Router = IRouter(address(balancerRouter));
        pkgInit.balancerV3PrepayRouter = seRouter;
        pkgInit.weightedPool8020Factory = IWeightedPool8020Factory(address(weighted8020Factory));
        pkgInit.diamondFactory = diamondPackageFactory;
        pkgInit.seigniorageTokenPkg = seigniorageTokenPkg;
        pkgInit.seigniorageNFTVaultPkg = nftVaultPkg;
        pkgInit.reserveVaultRateProviderPkg = reserveVaultRateProviderPkg;

        vm.startPrank(owner);
        ISeigniorageDETFDFPkg pkg = Seigniorage_Component_FactoryService.deploySeigniorageDETFDFPkg(
            IVaultRegistryDeployment(address(indexedexManager)), pkgInit
        );
        vm.stopPrank();

        return pkg;
    }

    function _deployStandardExchangeRateProviderPkg() internal returns (IStandardExchangeRateProviderDFPkg pkg) {
        IFacet rateProviderFacet = IFacet(
            create3Factory.deployFacet(
                type(StandardExchangeRateProviderFacet).creationCode, keccak256("StandardExchangeRateProviderFacet")
            )
        );
        vm.label(address(rateProviderFacet), "StandardExchangeRateProviderFacet");

        IStandardExchangeRateProviderDFPkg.PkgInit memory pkgInit = IStandardExchangeRateProviderDFPkg.PkgInit({
            rateProviderFacet: rateProviderFacet, diamondFactory: diamondPackageFactory
        });

        bytes32 pkgSalt = keccak256("StandardExchangeRateProviderDFPkg");
        pkg = IStandardExchangeRateProviderDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(StandardExchangeRateProviderDFPkg).creationCode, abi.encode(pkgInit), pkgSalt
                )
            )
        );
        vm.label(address(pkg), "StandardExchangeRateProviderDFPkg");
    }

    function _computeDeploymentScenario() internal view returns (DeploymentScenario memory s) {
        ISeigniorageDETFDFPkg.PkgArgs memory pkgArgs;
        pkgArgs.name = "Seigniorage DETF";
        pkgArgs.symbol = "RBT";
        pkgArgs.reserveVault = daiUsdcVault;
        pkgArgs.reserveVaultRateTarget = IERC20Metadata(address(dai));

        address detfPredicted =
            diamondPackageFactory.calcAddress(IDiamondFactoryPackage(address(detfDFPkg)), abi.encode(pkgArgs));

        s = DeploymentScenario({detfPredicted: detfPredicted, pkgArgs: pkgArgs});
    }

    function _reserveAsset() internal view returns (IERC20) {
        return IERC20(address(aeroDaiUsdcPool));
    }

    function _reserveVaultShares() internal view returns (IERC20) {
        return IERC20(address(daiUsdcVault));
    }

    function _mintReserveAssetTo(address user, uint256 tokenAmount) internal returns (uint256 liquidity) {
        dai.mint(user, tokenAmount);
        usdc.mint(user, tokenAmount);

        vm.startPrank(user);
        dai.approve(address(aerodromeRouter), tokenAmount);
        usdc.approve(address(aerodromeRouter), tokenAmount);

        (,, liquidity) = aerodromeRouter.addLiquidity(
            address(dai), address(usdc), false, tokenAmount, tokenAmount, 1, 1, user, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function _approvePermit2ToSeRouter(address user, address token) internal {
        vm.startPrank(user);
        IERC20(token).approve(address(permit2), type(uint256).max);
        permit2.approve(token, address(seRouter), type(uint160).max, type(uint48).max);
        vm.stopPrank();
    }
}
