// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";

import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultRegistryVaultPackageManager} from "contracts/interfaces/IVaultRegistryVaultPackageManager.sol";
import {IVaultRegistryVaultPackageQuery} from "contracts/interfaces/IVaultRegistryVaultPackageQuery.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";

import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {DetfComponentFactoryService} from "contracts/vaults/detf/common/factory/DetfComponentFactoryService.sol";
import {DetfFacetFactoryService} from "contracts/vaults/detf/common/factory/DetfFacetFactoryService.sol";
import {DetfPkgFactoryService} from "contracts/vaults/detf/common/factory/DetfPkgFactoryService.sol";
import {IUniswapV4DetfBondNFTVaultDFPkg} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft/UniswapV4DetfBondNFTVaultDFPkg.sol";
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";

contract UniswapV4DetfBondNftDetfLiveStub {
    function isReserveLive() external pure returns (bool) {
        return true;
    }

    function notifyReserveDonated() external {}
}

contract UniswapV4DetfBondNFTVaultDFPkg_Deploy_Test is TestBase_VaultComponents {
    using DetfFacetFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for IVaultRegistryDeployment;

    IUniswapV4DetfBondNFTVaultDFPkg internal pkg;

    function setUp() public override {
        super.setUp();

        IFacet erc721Facet = IFacet(
            create3Factory.deployFacet(
                type(ERC721Facet).creationCode, keccak256("UniswapV4DetfBondNFT_ERC721Facet")
            )
        );
        IFacet detfNFTVaultFacet = create3Factory.deployUniswapV4DetfBondNFTVaultFacet();

        IUniswapV4DetfBondNFTVaultDFPkg.PkgInit memory pkgInit = DetfComponentFactoryService
            .buildUniswapV4DetfBondNFTVaultPkgInit(
            erc721Facet,
            erc4626BasicVaultFacet,
            erc4626StandardVaultFacet,
            detfNFTVaultFacet,
            IVaultFeeOracleQuery(address(indexedexManager)),
            IVaultRegistryDeployment(address(indexedexManager))
        );

        vm.startPrank(owner);
        pkg = IVaultRegistryDeployment(address(indexedexManager)).deployUniswapV4DetfBondNFTVaultDFPkg(pkgInit);
        IVaultRegistryVaultPackageManager(address(indexedexManager)).registerPackage(
            address(pkg), IStandardVaultPkg(address(pkg)).vaultDeclaration()
        );
        vm.stopPrank();

        assertTrue(
            IVaultRegistryVaultPackageQuery(address(indexedexManager)).isPackage(address(pkg)),
            "UniswapV4DetfBondNFTVaultDFPkg not registered"
        );
    }

    function test_pkgArgs_fieldOrder_compiles() public pure {
        IUniswapV4Detf.IoRoute[] memory emptyRoutes = new IUniswapV4Detf.IoRoute[](0);
        IUniswapV4Detf.PkgArgs memory args;
        args.name = "d";
        args.symbol = "D";
        args.hook = address(1);
        args.creationPairPerDetfWad = new uint256[](1);
        args.creationPairPerDetfWad[0] = 1e18;
        args.openingPairPerDetfWad = new uint256[](0);
        args.thresholdMode = ThresholdMode.Policy;
        args.mintRouteMode = IUniswapV4Detf.RouteTableMode.Default;
        args.mintRoutes = emptyRoutes;
        args.burnRouteMode = IUniswapV4Detf.RouteTableMode.Default;
        args.burnRoutes = emptyRoutes;
        args.bondRouteMode = IUniswapV4Detf.RouteTableMode.Default;
        args.bondRoutes = emptyRoutes;
        args.closeRouteMode = IUniswapV4Detf.RouteTableMode.Custom;
        IUniswapV4Detf.IoRoute[] memory closeRoutes = new IUniswapV4Detf.IoRoute[](1);
        closeRoutes[0] = IUniswapV4Detf.IoRoute({token: IERC20(address(2)), vault: IStandardExchange(address(3))});
        args.closeRoutes = closeRoutes;
        args.donateRouteMode = IUniswapV4Detf.RouteTableMode.Default;
        args.donateRoutes = emptyRoutes;
        assertEq(args.closeRoutes.length, 1);
        assertEq(uint256(args.mintRouteMode), uint256(IUniswapV4Detf.RouteTableMode.Default));
    }

    function test_deployVault_success() public {
        address lpToken = address(new ERC20PermitMintableStub("LP Token", "LP", 18, address(this), 0));
        address rewardToken = address(new ERC20PermitMintableStub("Reward Token", "RWD", 18, address(this), 0));

        vm.startPrank(owner);
        address vaultAddr = pkg.deployVault(
            "Uni V4 DETF Bond NFT", "uNFT", IDetf(address(0xBEEF)), IERC20(lpToken), IERC20(rewardToken), 9, owner
        );
        vm.stopPrank();

        assertGt(vaultAddr.code.length, 0, "proxy not deployed");
        IStandardVault.VaultConfig memory cfg = IStandardVault(vaultAddr).vaultConfig();
        assertEq(cfg.tokens.length, 1);
        assertEq(cfg.tokens[0], lpToken);
        assertEq(address(IDETFNFTVault(vaultAddr).rewardToken()), rewardToken);
        assertEq(IDETFNFTVault(vaultAddr).totalOriginalShares(), 0);
    }

    function test_R12a_donateLp_Oeq0_creditsId0() public {
        UniswapV4DetfBondNftDetfLiveStub stub = new UniswapV4DetfBondNftDetfLiveStub();
        ERC20PermitMintableStub lp = new ERC20PermitMintableStub("LP0", "LP0", 18, address(this), 0);
        ERC20PermitMintableStub reward = new ERC20PermitMintableStub("R0", "R0", 18, address(this), 0);
        vm.prank(owner);
        address vaultAddr = pkg.deployVault(
            "Uni V4 DETF Bond NFT", "uNFT", IDetf(address(stub)), IERC20(address(lp)), IERC20(address(reward)), 9, owner
        );
        IDETFNFTVault vault_ = IDETFNFTVault(vaultAddr);
        vm.prank(owner);
        vault_.initializeDETFNFT();
        uint256 id0 = vault_.detfNFTId();
        assertEq(vault_.totalOriginalShares(), 0, "O==0");

        uint256 gift = 5e18;
        lp.mint(address(this), gift);
        lp.approve(vaultAddr, gift);
        uint256 lpOut = IDetfNftReserveDonation(vaultAddr).donate(
            IERC20(address(lp)), gift, 0, false, block.timestamp + 1 hours
        );
        assertEq(lpOut, gift, "lp inbound");
        assertEq(vault_.originalSharesOf(id0), gift, "O==0 credits id 0 1:1");
        assertEq(vault_.totalOriginalShares(), gift, "O now gift");
    }

    function test_R12a_donateLp_Ogt0_unassignedNoOriginalSharesMint() public {
        UniswapV4DetfBondNftDetfLiveStub stub = new UniswapV4DetfBondNftDetfLiveStub();
        ERC20PermitMintableStub lp = new ERC20PermitMintableStub("LP1", "LP1", 18, address(this), 0);
        ERC20PermitMintableStub reward = new ERC20PermitMintableStub("R1", "R1", 18, address(this), 0);
        vm.prank(owner);
        address vaultAddr = pkg.deployVault(
            "Uni V4 DETF Bond NFT", "uNFT", IDetf(address(stub)), IERC20(address(lp)), IERC20(address(reward)), 9, owner
        );
        IDETFNFTVault vault_ = IDETFNFTVault(vaultAddr);
        vm.prank(owner);
        vault_.initializeDETFNFT();
        uint256 id0 = vault_.detfNFTId();
        lp.mint(address(this), 2e18);
        lp.transfer(vaultAddr, 2e18);
        vm.prank(owner);
        vault_.addToDETFNFT(id0, 1e18);
        uint256 origBefore = vault_.originalSharesOf(id0);
        uint256 o = vault_.totalOriginalShares();
        uint256 assetsBefore = vault_.convertToAssets(origBefore);
        assertGt(o, 0, "O>0");

        uint256 gift = 3e18;
        lp.mint(address(this), gift);
        lp.approve(vaultAddr, gift);
        IDetfNftReserveDonation(vaultAddr).donate(
            IERC20(address(lp)), gift, 0, false, block.timestamp + 1 hours
        );
        assertEq(vault_.originalSharesOf(id0), origBefore, "no originalShares mint");
        assertEq(vault_.totalOriginalShares(), o, "O unchanged");
        assertGt(vault_.convertToAssets(origBefore), assetsBefore, "convertToAssets rises");
    }
}
