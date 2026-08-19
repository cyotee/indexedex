// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";

import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitDFPkg, IERC20PermitDFPkg} from "@crane/contracts/tokens/ERC20/ERC20PermitDFPkg.sol";

import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IDetfErrors} from "contracts/interfaces/IDetfErrors.sol";
import {
    DETF_CREATOR_BOND_NFT_ID,
    DETF_FEE_TO_BOND_NFT_ID,
    DETF_FIRST_USER_BOND_NFT_ID,
    DETF_PROTOCOL_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultRegistryVaultPackageManager} from "contracts/interfaces/IVaultRegistryVaultPackageManager.sol";
import {IVaultRegistryVaultPackageQuery} from "contracts/interfaces/IVaultRegistryVaultPackageQuery.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";

import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";

import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/common/factory/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IDETFNFTVaultDFPkg} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultDFPkg.sol";
import {DetfComponentFactoryService} from "contracts/vaults/detf/common/factory/DetfComponentFactoryService.sol";
import {DetfFacetFactoryService} from "contracts/vaults/detf/common/factory/DetfFacetFactoryService.sol";
import {DetfPkgFactoryService} from "contracts/vaults/detf/common/factory/DetfPkgFactoryService.sol";

contract DETFNFTVaultDFPkg_Deploy_Test is TestBase_VaultComponents {
    using DetfFacetFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for IVaultRegistryDeployment;

    IDetfSelfNftInventoryDFPkg internal pkg;
    ERC20PermitDFPkg internal erc20PermitPkg;

    function setUp() public override {
        super.setUp();

        IFacet erc721Facet = IFacet(
            create3Factory.deployFacet(type(ERC721Facet).creationCode, keccak256("DETFNFTVault_ERC721Facet"))
        );
        IFacet detfNFTVaultFacet = create3Factory.deployDETFNFTVaultFacet();

        IDETFNFTVaultDFPkg.PkgInit memory pkgInit = DetfComponentFactoryService.buildDETFNFTVaultPkgInit(
            erc721Facet,
            erc4626BasicVaultFacet,
            erc4626StandardVaultFacet,
            detfNFTVaultFacet,
            IVaultFeeOracleQuery(address(indexedexManager)),
            IVaultRegistryDeployment(address(indexedexManager))
        );

        vm.startPrank(owner);
        pkg = IVaultRegistryDeployment(address(indexedexManager)).deployDETFNFTVaultDFPkg(pkgInit);

        IVaultRegistryVaultPackageManager(address(indexedexManager))
            .registerPackage(address(pkg), IStandardVaultPkg(address(pkg)).vaultDeclaration());
        vm.stopPrank();

        erc20PermitPkg = _deployTestTokenPkg();

        assertTrue(
            IVaultRegistryVaultPackageQuery(address(indexedexManager)).isPackage(address(pkg)),
            "DETFNFTVaultDFPkg not registered"
        );
    }

    function test_deployVault_success() public {
        // Deploy two simple ERC20s via CREATE3 for lpToken and rewardToken.
        address lpToken = address(_deployTestToken("LP Token", "LP", keccak256("DETFNFTVault_LP_Token")));
        address rewardToken =
            address(_deployTestToken("Reward Token", "RWD", keccak256("DETFNFTVault_Reward_Token")));

        vm.startPrank(owner);
        address vaultAddr = pkg.deployVault(
            "Protocol NFT Vault",
            "pNFT",
            IDetf(address(0xBEEF)),
            IERC20(lpToken),
            IERC20(rewardToken),
            9,
            owner
        );
        vm.stopPrank();

        assertGt(vaultAddr.code.length, 0, "DETFNFTVault proxy not deployed");

        // The Protocol NFT vault package currently only registers the LP token as "contents".
        // Avoid asserting selectors that are not routed by the deployed diamond.
        IStandardVault.VaultConfig memory cfg = IStandardVault(vaultAddr).vaultConfig();
        assertEq(cfg.tokens.length, 1, "vaultConfig.tokens length");
        assertEq(cfg.tokens[0], lpToken, "vaultConfig.tokens[0] (lpToken)");

        // Still validate the interface exists at compile-time.
        assertEq(address(IDETFNFTVault(vaultAddr).rewardToken()), rewardToken, "configured reward token");
        rewardToken; // silence unused local warning if assertions change later
    }

    function test_initializeDETFNFT_zeroPrincipal_and_addRemoveOneToOne() public {
        IDETFNFTVault vault_ = _deployNftVault();
        address alice_ = makeAddr("alice");

        vm.startPrank(owner);
        vault_.initializeDETFNFT();
        vm.stopPrank();
        uint256 protocolId_ = vault_.detfNFTId();
        // Token id 0 is a valid protocol NFT (some ERC721 counters start at 0).
        assertEq(vault_.originalSharesOf(protocolId_), 0, "deploy principal 0");
        assertEq(vault_.effectiveSharesOf(protocolId_), 0, "deploy effective 0");
        assertEq(vault_.effectiveSharesOf(protocolId_), vault_.originalSharesOf(protocolId_), "1:1 at deploy");

        vm.startPrank(owner);
        uint256 userId_ = vault_.createPosition(100e18, 30 days, alice_);
        vault_.addToDETFNFT(protocolId_, 40e18);
        vm.stopPrank();

        assertTrue(userId_ != protocolId_, "protocol != user tokenId");
        assertEq(vault_.originalSharesOf(protocolId_), 40e18, "add original");
        assertEq(vault_.effectiveSharesOf(protocolId_), 40e18, "add 1:1 effective");

        vm.prank(owner);
        vault_.removeFromDETFNFT(protocolId_, 15e18);
        assertEq(vault_.originalSharesOf(protocolId_), 25e18, "remove original");
        assertEq(vault_.effectiveSharesOf(protocolId_), 25e18, "remove 1:1 effective");
    }

    function test_sellPositionToDetfNft_revertsBondNotMature_untilUnlock() public {
        IDETFNFTVault vault_ = _deployNftVault();
        address alice_ = makeAddr("alice");

        vm.startPrank(owner);
        vault_.initializeDETFNFT();
        uint256 tokenId_ = vault_.createPosition(50e18, 30 days, alice_);
        uint256 unlock_ = vault_.unlockTimeOf(tokenId_);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("BondNotMature(uint256)")), unlock_));
        vault_.sellPositionToDetfNft(tokenId_, alice_, alice_);
        vm.stopPrank();

        vm.warp(unlock_ + 1);
        vm.prank(owner);
        (uint256 principal_,) = vault_.sellPositionToDetfNft(tokenId_, alice_, alice_);
        assertEq(principal_, 50e18, "principal moved");
        uint256 protocolId_ = vault_.detfNFTId();
        assertEq(vault_.originalSharesOf(protocolId_), 50e18, "protocol credited");
        assertEq(vault_.effectiveSharesOf(protocolId_), vault_.originalSharesOf(protocolId_), "1:1 after sell");
    }

    function test_redeemPosition_onlyOwner_and_eoaReverts() public {
        IDETFNFTVault vault_ = _deployNftVault();
        address alice_ = makeAddr("alice");

        vm.startPrank(owner);
        vault_.initializeDETFNFT();
        uint256 tokenId_ = vault_.createPosition(10e18, 30 days, alice_);
        vm.stopPrank();

        vm.prank(alice_);
        vm.expectRevert();
        vault_.redeemPosition(tokenId_, alice_, block.timestamp + 1 hours);
    }

    function _deployNftVault() internal returns (IDETFNFTVault vault_) {
        address lpToken = address(_deployTestToken("LP Token", "LP", keccak256("DETFNFTVault_LP_Token_law")));
        address rewardToken =
            address(_deployTestToken("Reward Token", "RWD", keccak256("DETFNFTVault_Reward_Token_law")));

        vm.startPrank(owner);
        address vaultAddr = pkg.deployVault(
            "Protocol NFT Vault",
            "pNFT",
            IDetf(address(0xBEEF)),
            IERC20(lpToken),
            IERC20(rewardToken),
            9,
            owner
        );
        vm.stopPrank();
        vault_ = IDETFNFTVault(vaultAddr);
    }

    function test_reservedIds_wire_0_1_2_userStartsAt3() public {
        IDETFNFTVault vault_ = _deployNftVault();
        address feeTo_ = makeAddr("feeTo");
        address creator_ = makeAddr("creator");

        vm.prank(owner);
        uint256 protocolId_ = vault_.initializeReservedBondNfts(feeTo_, creator_);

        assertTrue(vault_.reservedBondNftsWired(), "wired sentinel");
        assertEq(protocolId_, DETF_PROTOCOL_BOND_NFT_ID, "id 0 protocol");
        assertEq(vault_.detfNFTId(), DETF_PROTOCOL_BOND_NFT_ID, "detfNftId is 0");
        assertEq(vault_.ownerOf(DETF_PROTOCOL_BOND_NFT_ID), address(vault_), "id 0 owner vault");
        assertEq(vault_.ownerOf(DETF_FEE_TO_BOND_NFT_ID), feeTo_, "id 1 feeTo");
        assertEq(vault_.ownerOf(DETF_CREATOR_BOND_NFT_ID), creator_, "id 2 creator");

        address alice_ = makeAddr("alice");
        vm.prank(owner);
        uint256 userId_ = vault_.createPosition(10e18, 30 days, alice_);
        assertEq(userId_, DETF_FIRST_USER_BOND_NFT_ID, "user starts at 3");
        assertEq(vault_.ownerOf(userId_), alice_, "user owns 3");
    }

    function test_creatorZero_mints_id2_to_feeTo() public {
        IDETFNFTVault vault_ = _deployNftVault();
        address feeTo_ = makeAddr("feeTo");

        vm.prank(owner);
        vault_.initializeReservedBondNfts(feeTo_, address(0));
        assertEq(vault_.ownerOf(DETF_FEE_TO_BOND_NFT_ID), feeTo_, "id 1");
        assertEq(vault_.ownerOf(DETF_CREATOR_BOND_NFT_ID), feeTo_, "id 2 D21");
    }

    function test_addEffectiveSharesOnly_noOriginalShares_ids1and2() public {
        IDETFNFTVault vault_ = _deployNftVault();
        address feeTo_ = makeAddr("feeTo");
        address creator_ = makeAddr("creator");

        vm.startPrank(owner);
        vault_.initializeReservedBondNfts(feeTo_, creator_);
        vault_.addEffectiveSharesOnly(DETF_FEE_TO_BOND_NFT_ID, 11e18);
        vault_.addEffectiveSharesOnly(DETF_CREATOR_BOND_NFT_ID, 5e18);
        vm.stopPrank();

        assertEq(vault_.originalSharesOf(DETF_FEE_TO_BOND_NFT_ID), 0, "FC9 id1 original 0");
        assertEq(vault_.originalSharesOf(DETF_CREATOR_BOND_NFT_ID), 0, "FC9 id2 original 0");
        assertEq(vault_.effectiveSharesOf(DETF_FEE_TO_BOND_NFT_ID), 11e18, "id1 effective");
        assertEq(vault_.effectiveSharesOf(DETF_CREATOR_BOND_NFT_ID), 5e18, "id2 effective");
        assertEq(vault_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), 0, "id0 original still 0");
    }

    function test_sellAndRedeem_revert_ids1and2() public {
        IDETFNFTVault vault_ = _deployNftVault();
        address feeTo_ = makeAddr("feeTo");
        address creator_ = makeAddr("creator");

        vm.startPrank(owner);
        vault_.initializeReservedBondNfts(feeTo_, creator_);

        vm.expectRevert(abi.encodeWithSelector(IDetfErrors.DETFNFTRestricted.selector, DETF_FEE_TO_BOND_NFT_ID));
        vault_.sellPositionToDetfNft(DETF_FEE_TO_BOND_NFT_ID, feeTo_, feeTo_);

        vm.expectRevert(abi.encodeWithSelector(IDetfErrors.DETFNFTRestricted.selector, DETF_CREATOR_BOND_NFT_ID));
        vault_.sellPositionToDetfNft(DETF_CREATOR_BOND_NFT_ID, creator_, creator_);

        vm.expectRevert(abi.encodeWithSelector(IDetfErrors.DETFNFTRestricted.selector, DETF_FEE_TO_BOND_NFT_ID));
        vault_.redeemPosition(DETF_FEE_TO_BOND_NFT_ID, feeTo_, block.timestamp + 1 hours);

        vm.expectRevert(abi.encodeWithSelector(IDetfErrors.DETFNFTRestricted.selector, DETF_CREATOR_BOND_NFT_ID));
        vault_.redeemPosition(DETF_CREATOR_BOND_NFT_ID, creator_, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function test_initializeDETFNFT_id0_is_valid_not_unwired() public {
        IDETFNFTVault vault_ = _deployNftVault();
        vm.prank(owner);
        uint256 protocolId_ = vault_.initializeDETFNFT();
        assertEq(protocolId_, DETF_PROTOCOL_BOND_NFT_ID, "first mint is 0");
        vm.prank(owner);
        uint256 again_ = vault_.initializeDETFNFT();
        assertEq(again_, protocolId_, "L6 sentinel not id==0");
        assertEq(vault_.ownerOf(protocolId_), address(vault_), "protocol still id 0");
        assertFalse(vault_.reservedBondNftsWired(), "reserved wire is separate");
    }

    function test_addEffectiveSharesOnly_reverts_on_protocol_or_user() public {
        IDETFNFTVault vault_ = _deployNftVault();
        address feeTo_ = makeAddr("feeTo");
        address alice_ = makeAddr("alice");

        vm.startPrank(owner);
        vault_.initializeReservedBondNfts(feeTo_, feeTo_);
        uint256 userId_ = vault_.createPosition(10e18, 30 days, alice_);
        vm.expectRevert(abi.encodeWithSelector(IDetfErrors.DETFNFTRestricted.selector, DETF_PROTOCOL_BOND_NFT_ID));
        vault_.addEffectiveSharesOnly(DETF_PROTOCOL_BOND_NFT_ID, 1e18);
        vm.expectRevert(abi.encodeWithSelector(IDetfErrors.DETFNFTRestricted.selector, userId_));
        vault_.addEffectiveSharesOnly(userId_, 1e18);
        vm.stopPrank();
    }

    function test_processArgs_reverts_whenNotRegistry() public {
        vm.expectRevert(abi.encodeWithSelector(IDETFNFTVaultDFPkg.NotCalledByRegistry.selector, address(this)));
        pkg.processArgs(
            abi.encode(
                IDETFNFTVaultDFPkg.PkgArgs({
                    name: "x",
                    symbol: "y",
                    detf: IDetf(address(0xBEEF)),
                    lpToken: IERC20(address(0xCAFE)),
                    rewardToken: IERC20(address(0xF00D)),
                    decimalOffset: 9,
                    owner: owner
                })
            )
        );
    }

    function _deployTestTokenPkg() internal returns (ERC20PermitDFPkg pkg_) {
        IERC20PermitDFPkg.PkgInit memory pkgInit = IERC20PermitDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet
        });

        pkg_ = ERC20PermitDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(ERC20PermitDFPkg).creationCode,
                    abi.encode(pkgInit),
                    keccak256(abi.encode(type(ERC20PermitDFPkg).name, pkgInit, "DETFNFTVaultDeploy"))
                )
            )
        );
    }

    function _deployTestToken(string memory name_, string memory symbol_, bytes32 salt_) internal returns (IERC20 token_) {
        IERC20PermitDFPkg.PkgArgs memory pkgArgs = IERC20PermitDFPkg.PkgArgs({
            name: name_,
            symbol: symbol_,
            decimals: 18,
            totalSupply: 0,
            recipient: address(0),
            optionalSalt: salt_
        });

        token_ = IERC20(diamondPackageFactory.deploy(IDiamondFactoryPackage(address(erc20PermitPkg)), abi.encode(pkgArgs)));
    }
}
