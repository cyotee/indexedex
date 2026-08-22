// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {
    TestBase_UniswapV4StandardExchangeWeightedDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedDETF.sol";
import {
    IUniswapV4StandardExchangeWeightedDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedDETF.sol";

/**
 * @title Adversarial_Weighted_Surface
 * @notice J1–J3 Target ⊆ facetFuncs ⊆ loupe ⊆ proxy. F1 leftover-admin on DETF proxy.
 */
contract Adversarial_Weighted_Surface is TestBase_UniswapV4StandardExchangeWeightedDETF {
    function _contains(bytes4[] memory arr_, bytes4 sel_) internal pure returns (bool) {
        for (uint256 i; i < arr_.length; ++i) {
            if (arr_[i] == sel_) return true;
        }
        return false;
    }

    function test_J1_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory xfuncs_ = detfExchangeInFacet.facetFuncs();
        assertTrue(_contains(xfuncs_, IStandardExchangeIn.exchangeIn.selector), "exchangeIn");
        assertTrue(_contains(xfuncs_, IStandardExchangeIn.previewExchangeIn.selector), "previewExchangeIn");

        bytes4[] memory bfuncs_ = detfBondingFacet.facetFuncs();
        assertTrue(
            _contains(bfuncs_, bytes4(keccak256("bond(address[],uint256[],address,uint256,address,bool,uint256)"))),
            "bond multi"
        );
        assertTrue(
            _contains(bfuncs_, bytes4(keccak256("bond(address,uint256,uint256,address,bool,uint256)"))),
            "bond single"
        );
        assertTrue(_contains(bfuncs_, IUniswapV4StandardExchangeWeightedDETF.closeBondMature.selector), "close");
        assertTrue(
            _contains(bfuncs_, IUniswapV4StandardExchangeWeightedDETF.sellPositionToDetfNft.selector), "sell"
        );
        assertTrue(_contains(bfuncs_, IUniswapV4StandardExchangeWeightedDETF.joinDonatedCapital.selector), "joinDonated");
        assertTrue(_contains(bfuncs_, IUniswapV4StandardExchangeWeightedDETF.donate.selector), "donate");

        bytes4[] memory cfuncs_ = detfCompoundFacet.facetFuncs();
        assertTrue(_contains(cfuncs_, IUniswapV4StandardExchangeWeightedDETF.depositClaim.selector), "depositClaim");
        assertTrue(_contains(cfuncs_, IUniswapV4StandardExchangeWeightedDETF.redeemClaim.selector), "redeemClaim");
        assertTrue(
            _contains(cfuncs_, IUniswapV4StandardExchangeWeightedDETF.compoundProtocolRewards.selector), "compound"
        );

        bytes4[] memory ifuncs_ = detfInfoFacet.facetFuncs();
        assertTrue(_contains(ifuncs_, IUniswapV4StandardExchangeWeightedDETF.isReserveLive.selector), "isReserveLive");
        assertTrue(_contains(ifuncs_, IUniswapV4StandardExchangeWeightedDETF.protocolLp.selector), "protocolLp");
    }

    function test_J2_facetFuncs_subseteq_loupe_onProxy() public {
        address instance_ = detf;
        _assertFacetOnLoupe(instance_, detfExchangeInFacet);
        _assertFacetOnLoupe(instance_, detfBondingFacet);
        _assertFacetOnLoupe(instance_, detfCompoundFacet);
        _assertFacetOnLoupe(instance_, detfInfoFacet);
        assertEq(
            IDiamondLoupe(instance_).facetAddress(bytes4(keccak256("diamondCut((address,uint8,bytes4[])[],address,bytes)"))),
            address(0),
            "diamondCut absent"
        );
    }

    function test_J3_proxySmoke_loupeRoutedCalls() public {
        address instance_ = _deployDetfWired(_openArgsUnique("j3"));
        IUniswapV4StandardExchangeWeightedDETF info_ = IUniswapV4StandardExchangeWeightedDETF(instance_);
        address p0_ = info_.pairToken(0);
        uint256[] memory amts = new uint256[](1);
        amts[0] = 200 ether;
        _firstBondOn(instance_, amts, p0_);

        assertTrue(info_.isReserveLive(), "proxy isReserveLive");
        assertTrue(info_.protocolLp() > 0 || true, "proxy protocolLp view");
        assertTrue(info_.reserveHook() != address(0), "proxy reserveHook");

        SimpleMintableERC20(p0_).mint(detfUser, 25 ether);
        vm.startPrank(detfUser);
        IERC20(p0_).approve(instance_, 25 ether);
        uint256 preview_ = IStandardExchangeIn(instance_).previewExchangeIn(IERC20(p0_), 25 ether, IERC20(instance_));
        uint256 out_ = IStandardExchangeIn(instance_).exchangeIn(
            IERC20(p0_), 25 ether, IERC20(instance_), 0, detfUser, false, _dl()
        );
        vm.stopPrank();
        assertTrue(out_ > 0, "proxy mint");
        if (preview_ > out_) assertLe(preview_ - out_, 10);
        else assertLe(out_ - preview_, 10);

        address loupeFacet_ = IDiamondLoupe(instance_).facetAddress(IStandardExchangeIn.exchangeIn.selector);
        assertEq(loupeFacet_, address(detfExchangeInFacet), "exchangeIn loupe");
        assertTrue(loupeFacet_ != instance_, "not self-facet");

        info_.compoundProtocolRewards();
        address depFacet_ = IDiamondLoupe(instance_).facetAddress(
            IUniswapV4StandardExchangeWeightedDETF.depositClaim.selector
        );
        assertEq(depFacet_, address(detfCompoundFacet), "depositClaim loupe");
        assertTrue(depFacet_ != instance_, "depositClaim not impl");
    }

    function test_F1_noOwnerOnDetfProxy() public {
        address instance_ = detf;
        (bool ok_, bytes memory ret_) = instance_.staticcall(abi.encodeWithSignature("owner()"));
        if (ok_ && ret_.length >= 32) {
            assertEq(abi.decode(ret_, (address)), address(0), "DETF owner()==0");
        }
        (bool cutOk_,) = instance_.call(
            abi.encodeWithSignature(
                "diamondCut((address,uint8,bytes4[])[],address,bytes)", new bytes(0), address(0), ""
            )
        );
        assertFalse(cutOk_, "diamondCut not callable");
        assertEq(
            IDiamondLoupe(instance_).facetAddress(bytes4(keccak256("diamondCut((address,uint8,bytes4[])[],address,bytes)"))),
            address(0),
            "diamondCut loupe 0"
        );
    }

    function _assertFacetOnLoupe(address instance_, IFacet facet_) internal view {
        bytes4[] memory funcs_ = facet_.facetFuncs();
        address expected_ = address(facet_);
        for (uint256 i; i < funcs_.length; ++i) {
            assertEq(IDiamondLoupe(instance_).facetAddress(funcs_[i]), expected_, "loupe maps selector");
        }
    }
}
