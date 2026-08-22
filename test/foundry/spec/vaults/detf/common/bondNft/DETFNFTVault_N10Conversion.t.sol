// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitDFPkg, IERC20PermitDFPkg} from "@crane/contracts/tokens/ERC20/ERC20PermitDFPkg.sol";

import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {
    DETF_CREATOR_BOND_NFT_ID,
    DETF_FEE_TO_BOND_NFT_ID,
    DETF_FIRST_USER_BOND_NFT_ID,
    DETF_PROTOCOL_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultRegistryVaultPackageManager} from "contracts/interfaces/IVaultRegistryVaultPackageManager.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";

import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";

import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/common/factory/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IDETFNFTVaultDFPkg} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultDFPkg.sol";
import {DetfComponentFactoryService} from "contracts/vaults/detf/common/factory/DetfComponentFactoryService.sol";
import {DetfFacetFactoryService} from "contracts/vaults/detf/common/factory/DetfFacetFactoryService.sol";
import {DetfPkgFactoryService} from "contracts/vaults/detf/common/factory/DetfPkgFactoryService.sol";

/**
 * @title DETFNFTVault_N10Conversion
 * @notice Alignment N10: 4626 uses physical LP / totalOriginalShares; no protocol-effective haircut.
 * @dev Production Bond NFT DFPkg via manager registry. LP token is a Crane ERC20Permit diamond
 *      (not the SUT). Dummy DETF is never called on the physical-LP path.
 */
contract DETFNFTVault_N10Conversion is TestBase_VaultComponents {
    using DetfFacetFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for IVaultRegistryDeployment;

    uint8 internal constant N10_DECIMAL_OFFSET = 9;
    uint256 internal constant USER_ORIG = 100e18;
    uint256 internal constant ID0_ORIG = 40e18;
    uint256 internal constant PHYSICAL_LP = USER_ORIG + ID0_ORIG;

    IDetfSelfNftInventoryDFPkg internal pkg;
    ERC20PermitDFPkg internal erc20PermitPkg;
    IERC20 internal lpToken;
    IERC20 internal rewardToken;
    IDETFNFTVault internal vault;
    address internal alice;
    address internal feeTo;
    address internal creator;

    function setUp() public override {
        super.setUp();

        alice = makeAddr("alice");
        feeTo = makeAddr("feeTo");
        creator = makeAddr("creator");

        IFacet erc721Facet = IFacet(
            create3Factory.deployFacet(type(ERC721Facet).creationCode, keccak256("DETFNFTVault_N10_ERC721Facet"))
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
        IVaultRegistryVaultPackageManager(address(indexedexManager)).registerPackage(
            address(pkg), IStandardVaultPkg(address(pkg)).vaultDeclaration()
        );
        vm.stopPrank();

        erc20PermitPkg = _deployTestTokenPkg();
        lpToken = _deployTestToken("N10 LP", "N10LP", keccak256("DETFNFTVault_N10_LP"), 1_000_000e18);
        rewardToken = _deployTestToken("N10 RWD", "N10RWD", keccak256("DETFNFTVault_N10_RWD"), 0);

        vm.prank(owner);
        address vaultAddr = pkg.deployVault(
            "N10 Bond NFT",
            "n10nft",
            IDetf(address(0xBEEF)),
            lpToken,
            rewardToken,
            N10_DECIMAL_OFFSET,
            owner
        );
        vault = IDETFNFTVault(vaultAddr);
    }

    /// @notice Empty originalShares and empty physical LP convert 1:1 (no diamond call, no offset).
    function test_N10_emptyOL_isOneToOne() public view {
        assertEq(vault.totalOriginalShares(), 0, "empty O");
        assertEq(lpToken.balanceOf(address(vault)), 0, "empty L");
        assertEq(vault.convertToAssets(1e18), 1e18, "empty assets 1:1");
        assertEq(vault.convertToShares(2e18), 2e18, "empty shares 1:1");
        assertEq(vault.convertToAssets(0), 0, "zero assets");
        assertEq(vault.convertToShares(0), 0, "zero shares");
    }

    /// @notice User originalShares do not absorb id 0 physical LP (old haircut leaked that LP).
    function test_N10_userDoesNotAbsorbId0Share() public {
        _wireAndFundId0AndUser();

        uint256 userOrig_ = vault.originalSharesOf(DETF_FIRST_USER_BOND_NFT_ID);
        uint256 id0Orig_ = vault.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        uint256 physical_ = lpToken.balanceOf(address(vault));
        uint256 userLp_ = vault.convertToAssets(userOrig_);
        uint256 id0Lp_ = vault.convertToAssets(id0Orig_);

        assertEq(userOrig_, USER_ORIG, "user original");
        assertEq(id0Orig_, ID0_ORIG, "id 0 original");
        assertEq(physical_, PHYSICAL_LP, "physical LP");
        assertEq(vault.totalOriginalShares(), PHYSICAL_LP, "O = user + id 0");

        assertTrue(userLp_ < physical_, "user does not take all LP");
        assertTrue(id0Lp_ > 0, "id 0 has assets");
        assertTrue(userLp_ + id0Lp_ <= physical_, "sum of claims <= physical");
        // Haircut used denom = O - id0, so user convertToAssets(100e18) ≈ 140e18.
        assertTrue(userLp_ < 110e18, "user LP is not the haircut overpay");
        assertTrue(userLp_ > 90e18, "user LP is their original share of the book");
    }

    /// @notice Non-empty book applies decimalOffset (empty branch is 1:1; live is not).
    function test_N10_decimalOffsetStillOn() public {
        _wireAndFundId0AndUser();
        uint256 userLp_ = vault.convertToAssets(USER_ORIG);
        // Offset 9: assets = s * (L+1) / (O + 10^9) < s when s/O = L/O.
        assertTrue(userLp_ != USER_ORIG, "live convert is not empty 1:1");
        assertTrue(userLp_ < USER_ORIG, "floor + offset reduces user assets vs 1:1");
        uint256 mintedShares_ = vault.convertToShares(1e18);
        assertTrue(mintedShares_ != 1e18, "live convertToShares uses offset");
    }

    /// @notice Ids 1–2 effectiveShares are not 4626 input and do not change user convertToAssets.
    function test_N10_closeClaimDoNotFeedEffectiveShares() public {
        _wireAndFundId0AndUser();
        uint256 userId_ = DETF_FIRST_USER_BOND_NFT_ID;
        uint256 orig_ = vault.originalSharesOf(userId_);
        uint256 eff_ = vault.effectiveSharesOf(userId_);
        assertTrue(eff_ >= orig_, "lock bonus never shrinks original");

        uint256 fromOrig_ = vault.convertToAssets(orig_);
        uint256 fromEff_ = vault.convertToAssets(eff_);
        if (eff_ > orig_) {
            assertTrue(fromEff_ > fromOrig_, "feeding effectiveShares would overpay LP");
        }

        uint256 userBefore_ = vault.convertToAssets(orig_);
        vm.prank(owner);
        vault.addEffectiveSharesOnly(DETF_FEE_TO_BOND_NFT_ID, 11e18);
        vm.prank(owner);
        vault.addEffectiveSharesOnly(DETF_CREATOR_BOND_NFT_ID, 5e18);

        assertEq(vault.originalSharesOf(DETF_FEE_TO_BOND_NFT_ID), 0, "id1 original 0");
        assertEq(vault.convertToAssets(vault.originalSharesOf(DETF_FEE_TO_BOND_NFT_ID)), 0, "id1 no LP");
        assertEq(vault.convertToAssets(orig_), userBefore_, "D2 effective does not haircut user 4626");
        assertTrue(vault.totalShares() > vault.totalOriginalShares(), "effective > original after D2");
    }

    function _wireAndFundId0AndUser() internal {
        vm.prank(owner);
        vault.initializeReservedBondNfts(feeTo, creator);

        lpToken.transfer(address(vault), PHYSICAL_LP);
        assertEq(lpToken.balanceOf(address(vault)), PHYSICAL_LP, "LP on NFT");

        vm.startPrank(owner);
        uint256 userId_ = vault.createPosition(USER_ORIG, 30 days, alice);
        vault.addToDETFNFT(DETF_PROTOCOL_BOND_NFT_ID, ID0_ORIG);
        vm.stopPrank();

        assertEq(userId_, DETF_FIRST_USER_BOND_NFT_ID, "user id 3");
        assertEq(vault.ownerOf(userId_), alice, "alice owns user bond");
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
                    keccak256(abi.encode(type(ERC20PermitDFPkg).name, pkgInit, "DETFNFTVaultN10"))
                )
            )
        );
    }

    function _deployTestToken(string memory name_, string memory symbol_, bytes32 salt_, uint256 supply_)
        internal
        returns (IERC20 token_)
    {
        IERC20PermitDFPkg.PkgArgs memory pkgArgs = IERC20PermitDFPkg.PkgArgs({
            name: name_,
            symbol: symbol_,
            decimals: 18,
            totalSupply: supply_,
            recipient: address(this),
            optionalSalt: salt_
        });

        token_ = IERC20(
            diamondPackageFactory.deploy(IDiamondFactoryPackage(address(erc20PermitPkg)), abi.encode(pkgArgs))
        );
    }
}
