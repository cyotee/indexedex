// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {
    TestBase_UniswapV4StandardExchangeWeightedDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedDETF.sol";
import {
    IUniV4DetfBondNft
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/nft/IUniV4DetfBondNft.sol";
import {
    IUniV4DetfBondNftDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/nft/UniV4DetfBondNftDFPkg.sol";
import {
    UniV4DetfBondNft_FactoryService
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/nft/UniV4DetfBondNft_FactoryService.sol";
import {
    UniV4DetfBondNftRepo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/nft/UniV4DetfBondNftRepo.sol";
import {
    IUniV4DetfRebasingClaim
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/rebasing/IUniV4DetfRebasingClaim.sol";
import {
    IUniV4DetfRebasingClaimDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/rebasing/UniV4DetfRebasingClaimDFPkg.sol";
import {
    UniV4DetfRebasingClaim_FactoryService
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/rebasing/UniV4DetfRebasingClaim_FactoryService.sol";
import {
    UniV4DetfRebasingClaimRepo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/rebasing/UniV4DetfRebasingClaimRepo.sol";

/**
 * @title Adversarial_LocalNftClaim
 * @notice Leftover-admin + I/A0/J on unused Uni V4 local NFT/claim packages (WP-SEC-DETF-UV4-NFT-001).
 */
contract Adversarial_LocalNftClaim is TestBase_UniswapV4StandardExchangeWeightedDETF {
    IFacet internal nftFacet;
    IFacet internal claimFacet;
    IUniV4DetfBondNftDFPkg internal nftPkg;
    IUniV4DetfRebasingClaimDFPkg internal claimPkg;
    address internal attacker;

    function setUp() public override {
        super.setUp();
        attacker = makeAddr("attacker");
        nftFacet = UniV4DetfBondNft_FactoryService.deployUniV4DetfBondNftFacet(create3Factory);
        nftPkg = UniV4DetfBondNft_FactoryService.deployUniV4DetfBondNftDFPkg(
            create3Factory,
            IUniV4DetfBondNftDFPkg.PkgInit({bondNftFacet: nftFacet, diamondFactory: diamondPackageFactory})
        );
        claimFacet = UniV4DetfRebasingClaim_FactoryService.deployUniV4DetfRebasingClaimFacet(create3Factory);
        claimPkg = UniV4DetfRebasingClaim_FactoryService.deployUniV4DetfRebasingClaimDFPkg(
            create3Factory,
            IUniV4DetfRebasingClaimDFPkg.PkgInit({
                erc20Facet: erc20Facet,
                erc5267Facet: erc5267Facet,
                erc2612Facet: erc2612Facet,
                rebasingClaimFacet: claimFacet,
                diamondFactory: diamondPackageFactory
            })
        );
    }

    function _deployNft() internal returns (address nft_) {
        nft_ = nftPkg.deployBondNft(
            IUniV4DetfBondNftDFPkg.PkgArgs({
                detf: detf,
                poolManager: pm,
                poolKey: poolKey01,
                pairToken: IERC20(address(token0)),
                detfToken: IERC20(address(token1)),
                widthMultiplier: 1,
                owner: attacker,
                optionalSalt: keccak256(abi.encodePacked("uv4-nft", block.timestamp, gasleft()))
            })
        );
    }

    function _deployClaim() internal returns (address claim_) {
        claim_ = claimPkg.deployClaim(
            IUniV4DetfRebasingClaimDFPkg.PkgArgs({
                name: "Uv4Claim",
                symbol: "uC",
                poolManager: pm,
                poolKey: poolKey01,
                pairToken: IERC20(address(token0)),
                detfToken: IERC20(address(token1)),
                widthMultiplier: 1,
                owner: attacker,
                optionalSalt: keccak256(abi.encodePacked("uv4-claim", block.timestamp, gasleft()))
            })
        );
    }

    function test_F1_localNft_ownerZero_afterDeploy() public {
        address nft_ = _deployNft();
        assertEq(IUniV4DetfBondNft(nft_).owner(), address(0), "NFT owner()==0");
    }

    function test_F1_localClaim_ownerZero_afterDeploy() public {
        address claim_ = _deployClaim();
        assertEq(IUniV4DetfRebasingClaim(claim_).owner(), address(0), "claim owner()==0");
    }

    function test_I1_openBond_bookedInventory_revertsUnowned() public {
        address nft_ = _deployNft();
        uint256 donate_ = 10 ether;
        SimpleMintableERC20(address(token0)).mint(attacker, donate_);
        vm.prank(attacker);
        IERC20(address(token0)).transfer(nft_, donate_);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(UniV4DetfBondNftRepo.NotOwner.selector, attacker));
        IUniV4DetfBondNft(nft_).openBond(
            attacker, donate_, donate_, 0, donate_, block.timestamp + 30 days, -60, 60, -120, 120
        );
        assertEq(IERC20(address(token0)).balanceOf(nft_), donate_, "inventory unmoved");
    }

    function test_I1_absorb_bookedInventory_revertsUnowned() public {
        address claim_ = _deployClaim();
        uint256 donate_ = 10 ether;
        SimpleMintableERC20(address(token0)).mint(attacker, donate_);
        vm.prank(attacker);
        IERC20(address(token0)).transfer(claim_, donate_);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(UniV4DetfRebasingClaimRepo.NotOwner.selector, attacker));
        IUniV4DetfRebasingClaim(claim_).absorbBondProceeds(donate_, 0, attacker);
        assertEq(IERC20(address(token0)).balanceOf(claim_), donate_, "inventory unmoved");
    }

    function test_A0_donateThenFirstDeposit_noFreeMint() public {
        address claim_ = _deployClaim();
        uint256 donate_ = 50 ether;
        SimpleMintableERC20(address(token0)).mint(attacker, donate_ + 1 ether);
        vm.prank(attacker);
        IERC20(address(token0)).transfer(claim_, donate_);

        uint256 supplyBefore_ = IERC20(claim_).totalSupply();
        vm.startPrank(attacker);
        IERC20(address(token0)).approve(claim_, 1 ether);
        try IUniV4DetfRebasingClaim(claim_).deposit(IERC20(address(token0)), 1 ether, 0, attacker) returns (
            uint256 minted_
        ) {
            assertLe(minted_, 2 ether, "first deposit must not mint donated inventory");
            assertEq(IERC20(claim_).totalSupply(), supplyBefore_ + minted_, "only inbound minted");
        } catch {
            assertEq(IERC20(claim_).totalSupply(), supplyBefore_, "revert must not mint");
        }
        vm.stopPrank();

        assertGe(IERC20(address(token0)).balanceOf(claim_), donate_, "donation stays idle");
    }

    function test_I1_deposit_noInbound_reverts() public {
        address claim_ = _deployClaim();
        uint256 donate_ = 10 ether;
        SimpleMintableERC20(address(token0)).mint(attacker, donate_);
        vm.prank(attacker);
        IERC20(address(token0)).transfer(claim_, donate_);

        vm.prank(attacker);
        vm.expectRevert();
        IUniV4DetfRebasingClaim(claim_).deposit(IERC20(address(token0)), donate_, 0, attacker);
        assertEq(IERC20(address(token0)).balanceOf(claim_), donate_, "no free absorb");
    }

    function test_J1_nft_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory funcs_ = nftFacet.facetFuncs();
        bool foundOpen_;
        bool foundOwner_;
        for (uint256 i; i < funcs_.length; ++i) {
            if (funcs_[i] == IUniV4DetfBondNft.openBond.selector) foundOpen_ = true;
            if (funcs_[i] == IUniV4DetfBondNft.owner.selector) foundOwner_ = true;
        }
        assertTrue(foundOpen_, "openBond");
        assertTrue(foundOwner_, "owner");
    }

    function test_J3_nft_proxy_ownerView() public {
        address nft_ = _deployNft();
        assertEq(IUniV4DetfBondNft(nft_).owner(), address(0), "proxy owner view");
        address loupeFacet_ = IDiamondLoupe(nft_).facetAddress(IUniV4DetfBondNft.owner.selector);
        assertEq(loupeFacet_, address(nftFacet), "owner loupe");
        assertTrue(loupeFacet_ != nft_, "not impl address");
    }
}
