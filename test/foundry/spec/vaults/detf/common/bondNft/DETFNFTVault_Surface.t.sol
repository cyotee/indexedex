// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IERC721Metadata} from "@crane/contracts/interfaces/IERC721Metadata.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {ERC20PermitDFPkg, IERC20PermitDFPkg} from "@crane/contracts/tokens/ERC20/ERC20PermitDFPkg.sol";

import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
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
 * @title DETFNFTVault_Surface_Test
 * @notice Catalog J1–J3 for shared DETFNFTVault (WP-SEC-DETF-COM-J-001 / SEC-DETF-COM-004).
 * @dev Control list is built from IDETFNFTVault + tokenURI + guarded transfers, not Facet source.
 *      J3 smokes the registry-deployed **proxy**, never the facet impl address.
 */
contract DETFNFTVault_Surface_Test is TestBase_VaultComponents {
    using DetfFacetFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for IVaultRegistryDeployment;

    bytes4 internal constant SAFE_TRANSFER_FROM_DATA =
        bytes4(keccak256("safeTransferFrom(address,address,uint256,bytes)"));
    bytes4 internal constant SAFE_TRANSFER_FROM =
        bytes4(keccak256("safeTransferFrom(address,address,uint256)"));

    IFacet internal nftFacet;
    IDetfSelfNftInventoryDFPkg internal pkg;
    ERC20PermitDFPkg internal erc20PermitPkg;
    IDETFNFTVault internal vault;

    address internal attacker;

    function setUp() public override {
        super.setUp();

        attacker = makeAddr("attacker");
        IFacet erc721Facet = IFacet(
            create3Factory.deployFacet(type(ERC721Facet).creationCode, keccak256("DETFNFTVault_Surface_ERC721Facet"))
        );
        nftFacet = create3Factory.deployDETFNFTVaultFacet();

        IDETFNFTVaultDFPkg.PkgInit memory pkgInit = DetfComponentFactoryService.buildDETFNFTVaultPkgInit(
            erc721Facet,
            erc4626BasicVaultFacet,
            erc4626StandardVaultFacet,
            nftFacet,
            IVaultFeeOracleQuery(address(indexedexManager)),
            IVaultRegistryDeployment(address(indexedexManager))
        );

        vm.startPrank(owner);
        pkg = IVaultRegistryDeployment(address(indexedexManager)).deployDETFNFTVaultDFPkg(pkgInit);
        IVaultRegistryVaultPackageManager(address(indexedexManager))
            .registerPackage(address(pkg), IStandardVaultPkg(address(pkg)).vaultDeclaration());
        vm.stopPrank();

        erc20PermitPkg = _deployTestTokenPkg();

        address lpToken = address(_deployTestToken("LP Token", "LP", keccak256("DETFNFTVault_Surface_LP")));
        address rewardToken = address(_deployTestToken("Reward Token", "RWD", keccak256("DETFNFTVault_Surface_RWD")));

        vm.prank(owner);
        vault = IDETFNFTVault(
            pkg.deployVault(
                "Protocol NFT Vault",
                "pNFT",
                IDetf(address(0xBEEF)),
                IERC20(lpToken),
                IERC20(rewardToken),
                9,
                owner
            )
        );
    }

    /// @dev Target/product API: IDETFNFTVault + IERC721Metadata.tokenURI + guarded ERC721 transfers.
    function _controlSelectors() internal pure returns (bytes4[] memory sels_) {
        sels_ = new bytes4[](35);
        sels_[0] = IDETFNFTVault.initializeDETFNFT.selector;
        sels_[1] = IDETFNFTVault.createPosition.selector;
        sels_[2] = IDETFNFTVault.redeemPosition.selector;
        sels_[3] = IDETFNFTVault.claimRewards.selector;
        sels_[4] = IDETFNFTVault.addToDETFNFT.selector;
        sels_[5] = IDETFNFTVault.sellPositionToDetfNft.selector;
        sels_[6] = IDETFNFTVault.getPosition.selector;
        sels_[7] = IDETFNFTVault.pendingRewards.selector;
        sels_[8] = IDETFNFTVault.totalShares.selector;
        sels_[9] = IDETFNFTVault.detf.selector;
        sels_[10] = IDETFNFTVault.lpToken.selector;
        sels_[11] = IDETFNFTVault.rewardToken.selector;
        sels_[12] = IDETFNFTVault.detfNFTId.selector;
        sels_[13] = IDETFNFTVault.positionOf.selector;
        sels_[14] = IDETFNFTVault.originalSharesOf.selector;
        sels_[15] = IDETFNFTVault.effectiveSharesOf.selector;
        sels_[16] = IDETFNFTVault.unlockTimeOf.selector;
        sels_[17] = IDETFNFTVault.isUnlocked.selector;
        sels_[18] = IDETFNFTVault.convertToShares.selector;
        sels_[19] = IDETFNFTVault.convertToAssets.selector;
        sels_[20] = IDETFNFTVault.reallocateDetfNftRewards.selector;
        sels_[21] = IERC721Metadata.tokenURI.selector;
        sels_[22] = IDETFNFTVault.transferHeldToken.selector;
        sels_[23] = IDETFNFTVault.createPositionWithEffectiveBase.selector;
        sels_[24] = IDETFNFTVault.lockInfoOf.selector;
        sels_[25] = IDETFNFTVault.rewardPerShares.selector;
        sels_[26] = IDETFNFTVault.removeFromDETFNFT.selector;
        sels_[27] = IDETFNFTVault.totalOriginalShares.selector;
        sels_[28] = IDETFNFTVault.initializeReservedBondNfts.selector;
        sels_[29] = IDETFNFTVault.reservedBondNftsWired.selector;
        sels_[30] = IDETFNFTVault.addEffectiveSharesOnly.selector;
        sels_[31] = IDETFNFTVault.retireMaturePosition.selector;
        sels_[32] = IERC721.transferFrom.selector;
        sels_[33] = SAFE_TRANSFER_FROM;
        sels_[34] = SAFE_TRANSFER_FROM_DATA;
    }

    function _contains(bytes4[] memory arr_, bytes4 sel_) internal pure returns (bool) {
        for (uint256 i; i < arr_.length; ++i) {
            if (arr_[i] == sel_) return true;
        }
        return false;
    }

    /// @dev Success or a product/auth revert both prove the selector is cut. Empty revert is missing-fn.
    function _assertProxyNotFunctionNotFound(address proxy_, bytes memory data_) internal {
        (bool ok_, bytes memory ret_) = proxy_.call(data_);
        if (ok_) return;
        assertTrue(ret_.length >= 4, "J3 empty revert / FunctionNotFound");
    }

    function _cutsContain(IDiamond.FacetCut[] memory cuts_, bytes4 sel_) internal pure returns (bool) {
        for (uint256 i; i < cuts_.length; ++i) {
            bytes4[] memory sels_ = cuts_[i].functionSelectors;
            for (uint256 j; j < sels_.length; ++j) {
                if (sels_[j] == sel_) return true;
            }
        }
        return false;
    }

    /// @notice J1: Target/interface product selectors ⊆ CREATE3 Facet.facetFuncs() (transfers via replace cut).
    function test_J1_bond_targetEqualsFacetFuncs() public view {
        bytes4[] memory funcs_ = nftFacet.facetFuncs();
        bytes4[] memory controls_ = _controlSelectors();
        for (uint256 i; i < controls_.length; ++i) {
            bytes4 sel_ = controls_[i];
            bool onProductFacet_ = _contains(funcs_, sel_);
            bool guardedTransfer_ =
                sel_ == IERC721.transferFrom.selector || sel_ == SAFE_TRANSFER_FROM || sel_ == SAFE_TRANSFER_FROM_DATA;
            if (guardedTransfer_) {
                // Guarded transfers are Target entrypoints; DFPkg Replace cut wires them to this facet.
                assertTrue(onProductFacet_ || _cutsContain(pkg.facetCuts(), sel_), "J1 guarded transfer cut");
            } else {
                assertTrue(onProductFacet_, string.concat("J1 missing Target selector idx ", vm.toString(i)));
            }
        }
    }

    /// @notice J2: each Target selector is in package facetCuts and loupe-routed on the registry proxy.
    function test_J2_bond_loupeWired() public view {
        IDiamond.FacetCut[] memory cuts_ = pkg.facetCuts();
        IDiamondLoupe loupe_ = IDiamondLoupe(address(vault));
        bytes4[] memory controls_ = _controlSelectors();
        for (uint256 i; i < controls_.length; ++i) {
            assertTrue(_cutsContain(cuts_, controls_[i]), "J2 selector omitted from facetCuts");
            address facetAddr_ = loupe_.facetAddress(controls_[i]);
            assertTrue(facetAddr_ != address(0), "J2 loupe zero facet");
            assertTrue(facetAddr_ != address(vault), "J2 facet != proxy");
            assertEq(facetAddr_, address(nftFacet), "J2 product sel maps to NFT vault facet");
        }
    }

    /// @notice J3: smoke money + views on the **proxy** (registry deploy), never the facet impl.
    function test_J3_bond_proxySmoke_eachSelector() public {
        address proxy_ = address(vault);
        address facetImpl_ = IDiamondLoupe(proxy_).facetAddress(IDETFNFTVault.sellPositionToDetfNft.selector);
        assertEq(facetImpl_, address(nftFacet), "J3 sell loupe");
        assertTrue(facetImpl_ != proxy_ && facetImpl_ != address(0), "J3 proxy cut");

        // --- Views on proxy ---
        assertEq(address(vault.detf()), address(0xBEEF));
        assertTrue(address(vault.lpToken()) != address(0));
        assertTrue(address(vault.rewardToken()) != address(0));
        assertEq(vault.totalShares(), 0);
        assertEq(vault.totalOriginalShares(), 0);
        assertEq(vault.rewardPerShares(), 0);
        vault.detfNFTId();
        assertFalse(vault.reservedBondNftsWired(), "J3 reserved not wired at deploy");
        vault.getPosition(0);
        vault.positionOf(0);
        vault.pendingRewards(0);
        vault.originalSharesOf(0);
        vault.effectiveSharesOf(0);
        vault.unlockTimeOf(0);
        vault.isUnlocked(0);
        vault.lockInfoOf(0);
        // Dummy DETF is not a contract; stub reserveOfToken so convert views execute on proxy.
        vm.mockCall(
            address(vault.detf()),
            abi.encodeWithSignature("reserveOfToken(address)", address(vault.lpToken())),
            abi.encode(uint256(0))
        );
        vault.convertToShares(1e18);
        vault.convertToAssets(1e18);
        IERC721(proxy_).balanceOf(owner);
        IERC721(proxy_).isApprovedForAll(owner, attacker);
        _assertProxyNotFunctionNotFound(proxy_, abi.encodeWithSelector(IERC721Metadata.tokenURI.selector, uint256(0)));

        // --- Money / auth on proxy (product revert or success, never missing selector) ---
        vm.prank(attacker);
        _assertProxyNotFunctionNotFound(proxy_, abi.encodeWithSelector(IDETFNFTVault.initializeDETFNFT.selector));
        vm.prank(attacker);
        _assertProxyNotFunctionNotFound(
            proxy_, abi.encodeWithSelector(IDETFNFTVault.createPosition.selector, uint256(1e18), uint256(30 days), attacker)
        );
        vm.prank(attacker);
        _assertProxyNotFunctionNotFound(
            proxy_,
            abi.encodeWithSelector(
                IDETFNFTVault.createPositionWithEffectiveBase.selector,
                uint256(1e18),
                uint256(1e18),
                uint256(30 days),
                attacker
            )
        );
        vm.prank(attacker);
        _assertProxyNotFunctionNotFound(
            proxy_,
            abi.encodeWithSelector(
                IDETFNFTVault.redeemPosition.selector, uint256(1), attacker, block.timestamp + 1
            )
        );
        vm.prank(attacker);
        _assertProxyNotFunctionNotFound(
            proxy_, abi.encodeWithSelector(IDETFNFTVault.claimRewards.selector, uint256(1), attacker)
        );
        vm.prank(attacker);
        _assertProxyNotFunctionNotFound(
            proxy_, abi.encodeWithSelector(IDETFNFTVault.addToDETFNFT.selector, uint256(0), uint256(1e18))
        );
        vm.prank(attacker);
        _assertProxyNotFunctionNotFound(
            proxy_, abi.encodeWithSelector(IDETFNFTVault.addEffectiveSharesOnly.selector, uint256(1), uint256(1e18))
        );
        vm.prank(attacker);
        _assertProxyNotFunctionNotFound(
            proxy_,
            abi.encodeWithSelector(IDETFNFTVault.initializeReservedBondNfts.selector, attacker, attacker)
        );
        vm.prank(attacker);
        _assertProxyNotFunctionNotFound(
            proxy_, abi.encodeWithSelector(IDETFNFTVault.removeFromDETFNFT.selector, uint256(0), uint256(1e18))
        );
        vm.prank(attacker);
        _assertProxyNotFunctionNotFound(
            proxy_, abi.encodeWithSelector(IDETFNFTVault.sellPositionToDetfNft.selector, uint256(1), attacker, attacker)
        );
        vm.prank(attacker);
        _assertProxyNotFunctionNotFound(
            proxy_,
            abi.encodeWithSelector(IDETFNFTVault.transferHeldToken.selector, vault.lpToken(), attacker, uint256(1))
        );
        vm.prank(attacker);
        _assertProxyNotFunctionNotFound(
            proxy_, abi.encodeWithSelector(IDETFNFTVault.reallocateDetfNftRewards.selector, attacker)
        );

        vm.prank(attacker);
        _assertProxyNotFunctionNotFound(
            proxy_, abi.encodeWithSelector(IERC721.transferFrom.selector, owner, attacker, uint256(0))
        );
        vm.prank(attacker);
        _assertProxyNotFunctionNotFound(proxy_, abi.encodeWithSelector(SAFE_TRANSFER_FROM, owner, attacker, uint256(0)));
        vm.prank(attacker);
        _assertProxyNotFunctionNotFound(
            proxy_, abi.encodeWithSelector(SAFE_TRANSFER_FROM_DATA, owner, attacker, uint256(0), bytes(""))
        );

        // Owner initialize proves selector executes on proxy (not facet impl).
        vm.prank(owner);
        uint256 protocolId_ = vault.initializeDETFNFT();
        assertEq(vault.originalSharesOf(protocolId_), 0, "J3 protocol NFT on proxy");
        assertTrue(facetImpl_ != proxy_, "J3 primary target is proxy");
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
                    keccak256(abi.encode(type(ERC20PermitDFPkg).name, pkgInit, "DETFNFTVaultSurface"))
                )
            )
        );
    }

    function _deployTestToken(string memory name_, string memory symbol_, bytes32 salt_)
        internal
        returns (IERC20 token_)
    {
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
