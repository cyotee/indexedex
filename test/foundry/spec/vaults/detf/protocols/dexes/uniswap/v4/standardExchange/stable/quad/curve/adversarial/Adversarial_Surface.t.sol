// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {
    TestBase_UniswapV4StandardExchangeCurveQuadStableDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableDETF.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableDETF.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableDETFRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableDETFRepo.sol";

/// @notice J1–J3 + F1 on curve-quad DETF proxy (exact-out stubs present).
contract Adversarial_CurveQuad_Surface is TestBase_UniswapV4StandardExchangeCurveQuadStableDETF {
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
        assertTrue(
            _contains(xfuncs_, IUniswapV4StandardExchangeCurveQuadStableDETF.mintExactDetfOut.selector),
            "mintExactDetfOut"
        );
        assertTrue(
            _contains(xfuncs_, IUniswapV4StandardExchangeCurveQuadStableDETF.burnExactTokenOut.selector),
            "burnExactTokenOut"
        );

        bytes4[] memory cfuncs_ = detfCompoundFacet.facetFuncs();
        assertTrue(
            _contains(cfuncs_, IUniswapV4StandardExchangeCurveQuadStableDETF.depositClaim.selector), "depositClaim"
        );
        assertTrue(
            _contains(cfuncs_, IUniswapV4StandardExchangeCurveQuadStableDETF.redeemClaim.selector), "redeemClaim"
        );
    }

    function test_J2_facetFuncs_subseteq_loupe_onProxy() public {
        _assertFacetOnLoupe(detf, detfExchangeInFacet);
        _assertFacetOnLoupe(detf, detfBondingFacet);
        _assertFacetOnLoupe(detf, detfCompoundFacet);
        _assertFacetOnLoupe(detf, detfInfoFacet);
        assertEq(
            IDiamondLoupe(detf).facetAddress(bytes4(keccak256("diamondCut((address,uint8,bytes4[])[],address,bytes)"))),
            address(0),
            "diamondCut absent"
        );
    }

    function test_J3_proxySmoke_loupeRoutedCalls() public {
        address instance_ = _deployDetfInstance(_openArgsUnique("j3"));
        IUniswapV4StandardExchangeCurveQuadStableDETF info_ =
            IUniswapV4StandardExchangeCurveQuadStableDETF(instance_);
        address p0_ = info_.pairToken(0);
        uint256[] memory amts = new uint256[](3);
        amts[0] = 200 ether;
        amts[1] = 200 ether;
        amts[2] = 200 ether;
        _firstBondOn(instance_, amts, p0_);

        assertTrue(info_.isReserveLive(), "proxy live");

        SimpleMintableERC20(p0_).mint(detfUser, 25 ether);
        vm.startPrank(detfUser);
        IERC20(p0_).approve(instance_, 25 ether);
        uint256 out_ = IStandardExchangeIn(instance_).exchangeIn(
            IERC20(p0_), 25 ether, IERC20(instance_), 0, detfUser, false, _dl()
        );
        vm.expectRevert(abi.encodeWithSelector(Repo.InvalidRoute.selector, IERC20(p0_), IERC20(instance_)));
        info_.mintExactDetfOut(IERC20(p0_), 1 ether, 1 ether, detfUser, false, _dl());
        vm.expectRevert(abi.encodeWithSelector(Repo.InvalidRoute.selector, IERC20(instance_), IERC20(p0_)));
        info_.burnExactTokenOut(IERC20(p0_), 1 ether, 1 ether, detfUser, false, _dl());
        vm.stopPrank();
        assertTrue(out_ > 0, "proxy mint");

        address xFacet_ = IDiamondLoupe(instance_).facetAddress(IStandardExchangeIn.exchangeIn.selector);
        assertEq(xFacet_, address(detfExchangeInFacet), "exchangeIn loupe");
        assertTrue(xFacet_ != instance_, "not impl");
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
