// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";

import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDetfErrors} from "contracts/interfaces/IDetfErrors.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {
    IRebasingClaimTokenDFPkg
} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {DetfFacetFactoryService} from "contracts/vaults/detf/common/factory/DetfFacetFactoryService.sol";
import {DetfPkgFactoryService} from "contracts/vaults/detf/common/factory/DetfPkgFactoryService.sol";
import {DetfComponentFactoryService} from "contracts/vaults/detf/common/factory/DetfComponentFactoryService.sol";

/**
 * @title RebasingClaimToken_Surface_Test
 * @notice Catalog J1–J3 for shared RebasingClaimToken (WP-SEC-DETF-COM-J-001 / SEC-DETF-COM-004).
 * @dev Control list is built from Target/interfaces, not Facet source.
 *      J3 smokes the CREATE3-deployed **proxy** (`pkg.deployToken`), never the facet impl address.
 */
contract RebasingClaimToken_Surface_Test is TestBase_VaultComponents {
    using DetfFacetFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for ICreate3FactoryProxy;

    bytes4 internal constant MINT_FROM_NFT_SALE_2 =
        bytes4(keccak256("mintFromNFTSale(uint256,address)"));
    bytes4 internal constant MINT_FROM_NFT_SALE_3 =
        bytes4(keccak256("mintFromNFTSale(uint256,uint256,address)"));

    IFacet internal claimFacet;
    IRebasingClaimTokenDFPkg internal pkg;
    IRebasingClaimToken internal token;

    IERC20 internal rateAsset;
    address internal nftVault;
    address internal attacker;

    uint256 internal constant PROTOCOL_NFT_ID = 1;

    function setUp() public override {
        super.setUp();

        attacker = makeAddr("attacker");
        claimFacet = create3Factory.deployRebasingClaimTokenFacet();
        pkg = create3Factory.deployRebasingClaimTokenDFPkg(
            DetfComponentFactoryService.buildRebasingClaimTokenPkgInit(
                erc20Facet, erc5267Facet, erc2612Facet, claimFacet, diamondPackageFactory
            )
        );

        rateAsset = IERC20(address(_mintableRateAsset()));
        nftVault = makeAddr("nftVault");
        _stubNftViews(0);

        token = IRebasingClaimToken(
            pkg.deployToken(
                IDetf(address(0xBEEF)), IDETFNFTVault(nftVault), rateAsset, PROTOCOL_NFT_ID, owner
            )
        );
    }

    /// @dev Target/product API (IRebasingClaimToken + IERC20/metadata + SE in/out + both mints).
    function _controlSelectors() internal pure returns (bytes4[] memory sels_) {
        sels_ = new bytes4[](29);
        sels_[0] = IERC20.totalSupply.selector;
        sels_[1] = IERC20.balanceOf.selector;
        sels_[2] = IERC20.transfer.selector;
        sels_[3] = IERC20.allowance.selector;
        sels_[4] = IERC20.approve.selector;
        sels_[5] = IERC20.transferFrom.selector;
        sels_[6] = IERC20Metadata.name.selector;
        sels_[7] = IERC20Metadata.symbol.selector;
        sels_[8] = IERC20Metadata.decimals.selector;
        sels_[9] = IRebasingClaimToken.sharesOf.selector;
        sels_[10] = IRebasingClaimToken.totalShares.selector;
        sels_[11] = IRebasingClaimToken.redemptionRate.selector;
        sels_[12] = IRebasingClaimToken.detf.selector;
        sels_[13] = IRebasingClaimToken.setDetf.selector;
        sels_[14] = IRebasingClaimToken.detfNFTId.selector;
        sels_[15] = IRebasingClaimToken.rateAsset.selector;
        sels_[16] = IRebasingClaimToken.convertToShares.selector;
        sels_[17] = IRebasingClaimToken.convertToClaim.selector;
        sels_[18] = IRebasingClaimToken.previewRedeem.selector;
        sels_[19] = MINT_FROM_NFT_SALE_2;
        sels_[20] = IRebasingClaimToken.redeem.selector;
        sels_[21] = IRebasingClaimToken.burnShares.selector;
        sels_[22] = IStandardExchangeIn.previewExchangeIn.selector;
        sels_[23] = IStandardExchangeIn.exchangeIn.selector;
        sels_[24] = IStandardExchangeOut.previewExchangeOut.selector;
        sels_[25] = IStandardExchangeOut.exchangeOut.selector;
        sels_[26] = IRebasingClaimToken.transferHeldToken.selector;
        sels_[27] = IRebasingClaimToken.updateRedemptionRate.selector;
        sels_[28] = MINT_FROM_NFT_SALE_3;
    }

    function _contains(bytes4[] memory arr_, bytes4 sel_) internal pure returns (bool) {
        for (uint256 i; i < arr_.length; ++i) {
            if (arr_[i] == sel_) return true;
        }
        return false;
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

    /// @notice J1: Target/interface product selectors ⊆ CREATE3 Facet.facetFuncs().
    function test_J1_claim_targetEqualsFacetFuncs() public view {
        bytes4[] memory funcs_ = claimFacet.facetFuncs();
        bytes4[] memory controls_ = _controlSelectors();
        assertEq(funcs_.length, controls_.length, "J1 facetFuncs length vs Target control");
        for (uint256 i; i < controls_.length; ++i) {
            assertTrue(
                _contains(funcs_, controls_[i]),
                string.concat("J1 missing Target selector idx ", vm.toString(i))
            );
        }
    }

    /// @notice J2: each Target selector is in package facetCuts and loupe-routed on the proxy.
    function test_J2_claim_loupeWired() public view {
        IDiamond.FacetCut[] memory cuts_ = pkg.facetCuts();
        IDiamondLoupe loupe_ = IDiamondLoupe(address(token));
        bytes4[] memory controls_ = _controlSelectors();
        for (uint256 i; i < controls_.length; ++i) {
            assertTrue(_cutsContain(cuts_, controls_[i]), "J2 selector omitted from facetCuts");
            address facetAddr_ = loupe_.facetAddress(controls_[i]);
            assertTrue(facetAddr_ != address(0), "J2 loupe zero facet");
            assertTrue(facetAddr_ != address(token), "J2 facet != proxy");
            assertEq(facetAddr_, address(claimFacet), "J2 product sel maps to claim facet");
        }
    }

    /// @notice J3: smoke every money/view selector on the **proxy**, never the facet impl.
    function test_J3_claim_proxySmoke_eachSelector() public {
        address proxy_ = address(token);
        address facetImpl_ = IDiamondLoupe(proxy_).facetAddress(IRebasingClaimToken.redeem.selector);
        assertEq(facetImpl_, address(claimFacet), "J3 redeem loupe");
        assertTrue(facetImpl_ != proxy_ && facetImpl_ != address(0), "J3 proxy cut");

        // --- Views on proxy ---
        assertEq(keccak256(bytes(token.name())), keccak256("RebasingClaim"));
        assertEq(keccak256(bytes(token.symbol())), keccak256("RebasingClaim"));
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 0);
        assertEq(token.balanceOf(attacker), 0);
        assertEq(token.allowance(attacker, owner), 0);
        assertEq(token.sharesOf(attacker), 0);
        assertEq(token.totalShares(), 0);
        assertEq(token.redemptionRate(), 1e18);
        assertEq(token.detf(), address(0xBEEF));
        assertEq(token.detfNFTId(), PROTOCOL_NFT_ID);
        assertEq(address(token.rateAsset()), address(rateAsset));
        token.convertToShares(1 ether);
        token.convertToClaim(1);
        token.previewRedeem(1 ether);
        IStandardExchangeIn(proxy_).previewExchangeIn(IERC20(proxy_), 1 ether, rateAsset);
        IStandardExchangeOut(proxy_).previewExchangeOut(IERC20(proxy_), rateAsset, 1 ether);
        token.updateRedemptionRate();

        // --- Money / auth on proxy (product revert, not missing selector) ---
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, uint256(1 ether), uint256(0))
        );
        token.redeem(1 ether, attacker, true);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, uint256(1 ether), uint256(0))
        );
        IStandardExchangeIn(proxy_).exchangeIn(
            IERC20(proxy_), 1 ether, rateAsset, 0, attacker, true, block.timestamp + 1
        );

        vm.prank(attacker);
        vm.expectRevert(IDetfErrors.ZeroAmount.selector);
        IStandardExchangeOut(proxy_).exchangeOut(
            IERC20(proxy_), 1 ether, rateAsset, 0, attacker, true, block.timestamp + 1
        );

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, attacker));
        token.setDetf(attacker);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, attacker));
        token.mintFromNFTSale(1 ether, attacker);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, attacker));
        token.mintFromNFTSale(1 ether, 0, attacker);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, attacker));
        token.burnShares(1 ether, attacker, false);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, attacker));
        token.transferHeldToken(rateAsset, attacker, 1);

        vm.prank(attacker);
        token.approve(owner, 1);
        assertEq(token.allowance(attacker, owner), 1, "J3 approve on proxy");

        assertTrue(facetImpl_ != proxy_, "J3 primary target is proxy");
    }

    function _stubNftViews(uint256 originalShares_) internal {
        IDETFNFTVault.Position memory position = IDETFNFTVault.Position({
            originalShares: originalShares_,
            effectiveShares: originalShares_,
            bonusMultiplier: 1e18,
            unlockTime: 0,
            rewardDebt: 0
        });
        vm.mockCall(
            nftVault, abi.encodeWithSelector(IDETFNFTVault.getPosition.selector, PROTOCOL_NFT_ID), abi.encode(position)
        );
        vm.mockCall(
            nftVault,
            abi.encodeWithSelector(IDETFNFTVault.originalSharesOf.selector, PROTOCOL_NFT_ID),
            abi.encode(originalShares_)
        );
    }

    function _mintableRateAsset() internal returns (address token_) {
        token_ = address(new ClaimSurfaceRateAsset());
    }
}

contract ClaimSurfaceRateAsset is IERC20 {
    string public constant name = "Mock Rate Asset";
    string public constant symbol = "mRATE";
    uint8 public constant decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}
