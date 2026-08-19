// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalDETF.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";

/// @notice J1–J3 + F1 on orbital DETF proxy. J must include depositClaim after ORB-CLAIM.
contract Adversarial_Orbital_Surface is TestBase_UniswapV4StandardExchangeOrbitalDETF {
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
        assertTrue(_contains(bfuncs_, IUniswapV4StandardExchangeOrbitalDETF.depositClaim.selector), "depositClaim");
        assertTrue(_contains(bfuncs_, IUniswapV4StandardExchangeOrbitalDETF.redeemClaim.selector), "redeemClaim");
        assertTrue(_contains(bfuncs_, IUniswapV4StandardExchangeOrbitalDETF.closeBondMature.selector), "close");
        assertTrue(_contains(bfuncs_, IUniswapV4StandardExchangeOrbitalDETF.buyClaim.selector), "buyClaim");
        assertTrue(_contains(bfuncs_, IUniswapV4StandardExchangeOrbitalDETF.previewCloseBondMature.selector), "previewClose");
        assertTrue(_contains(bfuncs_, IUniswapV4StandardExchangeOrbitalDETF.compoundProtocolRewards.selector), "compound");

        bytes4[] memory ifuncs_ = detfInfoFacet.facetFuncs();
        assertTrue(_contains(ifuncs_, IUniswapV4StandardExchangeOrbitalDETF.isReserveLive.selector), "isReserveLive");
    }

    function test_J2_facetFuncs_subseteq_loupe_onProxy() public {
        _assertFacetOnLoupe(detf, detfExchangeInFacet);
        _assertFacetOnLoupe(detf, detfBondingFacet);
        _assertFacetOnLoupe(detf, detfInfoFacet);
        assertEq(
            IDiamondLoupe(detf).facetAddress(bytes4(keccak256("diamondCut((address,uint8,bytes4[])[],address,bytes)"))),
            address(0),
            "diamondCut absent"
        );
    }

    function test_J3_proxySmoke_loupeRoutedCalls() public {
        address instance_ = _deployDetfWired(_openArgsUnique("j3"));
        IUniswapV4StandardExchangeOrbitalDETF info_ = IUniswapV4StandardExchangeOrbitalDETF(instance_);
        _firstBondOn(instance_, 200 ether, 200 ether);

        assertTrue(info_.isReserveLive(), "proxy live");
        assertTrue(info_.reserveHook() != address(0), "proxy hook");

        address p0_ = info_.pairToken0();
        SimpleMintableERC20(p0_).mint(detfUser, 25 ether);
        vm.startPrank(detfUser);
        IERC20(p0_).approve(instance_, 25 ether);
        uint256 out_ = IStandardExchangeIn(instance_).exchangeIn(
            IERC20(p0_), 25 ether, IERC20(instance_), 0, detfUser, false, _dl()
        );
        vm.stopPrank();
        assertTrue(out_ > 0, "proxy mint");

        address xFacet_ = IDiamondLoupe(instance_).facetAddress(IStandardExchangeIn.exchangeIn.selector);
        assertEq(xFacet_, address(detfExchangeInFacet), "exchangeIn loupe");
        assertTrue(xFacet_ != instance_, "not impl");

        address depFacet_ = IDiamondLoupe(instance_).facetAddress(
            IUniswapV4StandardExchangeOrbitalDETF.depositClaim.selector
        );
        assertEq(depFacet_, address(detfBondingFacet), "depositClaim loupe");
        assertTrue(depFacet_ != instance_, "depositClaim not facet impl");

        info_.compoundProtocolRewards();
    }

    function test_F1_noOwnerOnDetfProxy() public {
        (bool ok_, bytes memory ret_) = detf.staticcall(abi.encodeWithSignature("owner()"));
        if (ok_ && ret_.length >= 32) {
            assertEq(abi.decode(ret_, (address)), address(0), "DETF owner()==0");
        }
        (bool cutOk_,) = detf.call(
            abi.encodeWithSignature(
                "diamondCut((address,uint8,bytes4[])[],address,bytes)", new bytes(0), address(0), ""
            )
        );
        assertFalse(cutOk_, "diamondCut not callable");
    }

    function _assertFacetOnLoupe(address instance_, IFacet facet_) internal view {
        bytes4[] memory funcs_ = facet_.facetFuncs();
        for (uint256 i; i < funcs_.length; ++i) {
            assertEq(IDiamondLoupe(instance_).facetAddress(funcs_[i]), address(facet_), "loupe maps selector");
        }
    }
}
