// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {ERC20PermitDFPkg, IERC20PermitDFPkg} from "@crane/contracts/tokens/ERC20/ERC20PermitDFPkg.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
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
import {IRebasingClaimTokenDFPkg, RebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {DETFNFTVaultFacet} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultFacet.sol";
import {RebasingClaimTokenFacet} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenFacet.sol";

/// @notice T01 / L-FACET-*: diamond exposes product views via facet cut (not only Target bytecode).
contract T01_FacetSelectors_Test is TestBase_VaultComponents {
    using BetterEfficientHashLib for bytes;
    using DetfFacetFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for IVaultRegistryDeployment;

    IDetfSelfNftInventoryDFPkg internal bondPkg;
    IRebasingClaimTokenDFPkg internal claimPkg;
    ERC20PermitDFPkg internal erc20PermitPkg;
    address internal bondDiamond;
    address internal claimDiamond;
    IERC20 internal lpToken;
    IERC20 internal rewardToken;
    IERC20 internal rateAsset;

    function setUp() public override {
        super.setUp();

        IFacet erc721Facet = IFacet(
            create3Factory.deployFacet(type(ERC721Facet).creationCode, keccak256("SAF_T01_ERC721Facet"))
        );
        IFacet detfNFTVaultFacet = create3Factory.deployDETFNFTVaultFacet();

        IDETFNFTVaultDFPkg.PkgInit memory bondInit = DetfComponentFactoryService.buildDETFNFTVaultPkgInit(
            erc721Facet,
            erc4626BasicVaultFacet,
            erc4626StandardVaultFacet,
            detfNFTVaultFacet,
            IVaultFeeOracleQuery(address(indexedexManager)),
            IVaultRegistryDeployment(address(indexedexManager))
        );

        vm.startPrank(owner);
        bondPkg = IVaultRegistryDeployment(address(indexedexManager)).deployDETFNFTVaultDFPkg(bondInit);
        IVaultRegistryVaultPackageManager(address(indexedexManager))
            .registerPackage(address(bondPkg), IStandardVaultPkg(address(bondPkg)).vaultDeclaration());
        vm.stopPrank();

        IFacet claimFacet = create3Factory.deployRebasingClaimTokenFacet();
        IRebasingClaimTokenDFPkg.PkgInit memory claimInit =
            DetfComponentFactoryService.buildRebasingClaimTokenPkgInit(
                erc20Facet, erc5267Facet, erc2612Facet, claimFacet, diamondPackageFactory
            );
        claimPkg = IRebasingClaimTokenDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(RebasingClaimTokenDFPkg).creationCode,
                    abi.encode(claimInit),
                    abi.encode(type(RebasingClaimTokenDFPkg).name, "SAF_T01")._hash()
                )
            )
        );

        erc20PermitPkg = _deployTestTokenPkg();
        lpToken = _deployTestToken("LP", "LP", keccak256("SAF_T01_LP"));
        rewardToken = _deployTestToken("RWD", "RWD", keccak256("SAF_T01_RWD"));
        rateAsset = _deployTestToken("RATE", "RATE", keccak256("SAF_T01_RATE"));

        vm.prank(owner);
        bondDiamond = bondPkg.deployVault(
            "Bond NFT", "bNFT", IDetf(address(0xBEEF)), lpToken, rewardToken, 9, owner
        );

        claimDiamond = claimPkg.deployToken(
            IDetf(address(0xBEEF)), IDETFNFTVault(bondDiamond), rateAsset, 1, owner
        );
    }

    function test_bondDiamond_exposesLockInfoOf_andRewardPerShares() public {
        // Facet cut must route these selectors; empty position returns zeros / no phantom sold API.
        IDETFNFTVault.LockInfo memory info = IDETFNFTVault(bondDiamond).lockInfoOf(0);
        assertEq(info.sharesAwarded, 0, "empty lockInfo");
        uint256 rps = IDETFNFTVault(bondDiamond).rewardPerShares();
        assertEq(rps, 0, "fresh rewardPerShares");
    }

    function test_bondDiamond_soldSurface_notRegistered() public {
        // markDETFNFTSold / detfNFTSold retired — low-level call must not succeed as product API.
        (bool okMark,) = bondDiamond.call(abi.encodeWithSignature("markDETFNFTSold(uint256)", 1));
        assertFalse(okMark, "markDETFNFTSold must not be cut");
        (bool okSold,) = bondDiamond.call(abi.encodeWithSignature("detfNFTSold()"));
        assertFalse(okSold, "detfNFTSold must not be cut");
    }

    function test_claimDiamond_exposesUpdateRedemptionRate() public {
        // Live diamond call (L-FACET-3).
        IRebasingClaimToken(claimDiamond).updateRedemptionRate();
        assertEq(IRebasingClaimToken(claimDiamond).redemptionRate(), 1e18, "default rate");
    }

    function test_claimFacetFuncs_includeUpdateRedemptionRate() public {
        RebasingClaimTokenFacet facet = RebasingClaimTokenFacet(address(create3Factory.deployRebasingClaimTokenFacet()));
        bytes4[] memory funcs = facet.facetFuncs();
        bool found;
        for (uint256 i; i < funcs.length; ++i) {
            if (funcs[i] == IRebasingClaimToken.updateRedemptionRate.selector) found = true;
        }
        assertTrue(found, "updateRedemptionRate in facetFuncs");
    }

    function test_bondFacetFuncs_includeNewViews_notSold() public {
        DETFNFTVaultFacet facet = DETFNFTVaultFacet(address(create3Factory.deployDETFNFTVaultFacet()));
        bytes4[] memory funcs = facet.facetFuncs();
        assertTrue(_contains(funcs, IDETFNFTVault.lockInfoOf.selector), "lockInfoOf cut");
        assertTrue(_contains(funcs, IDETFNFTVault.rewardPerShares.selector), "rewardPerShares cut");
        assertFalse(_contains(funcs, bytes4(keccak256("markDETFNFTSold(uint256)"))), "no mark sold");
        assertFalse(_contains(funcs, bytes4(keccak256("detfNFTSold()"))), "no detfNFTSold");
    }

    function _contains(bytes4[] memory funcs, bytes4 sel) internal pure returns (bool) {
        for (uint256 i; i < funcs.length; ++i) {
            if (funcs[i] == sel) return true;
        }
        return false;
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
                    keccak256(abi.encode(type(ERC20PermitDFPkg).name, pkgInit, "SAF_T01"))
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
