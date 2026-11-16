// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {TestBase_ComposedFundedRoutes} from "contracts/test/bases/TestBase_ComposedFundedRoutes.sol";
import {
    ComposedStableCommonDetfRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfRepo.sol";

contract ComposedStableCommonDetfBondingFacet_Test is TestBase_ComposedFundedRoutes {
    function test_acceptedBondTokens_deduplicatesRouteBaseTokens() public view {
        address[] memory tokens_ = composedBonding.acceptedBondTokens();
        assertEq(tokens_.length, 3, "two reserve BPT inputs and one route base");
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            assertTrue(composedBonding.isAcceptedBondToken(IERC20(tokens_[i_])));
            for (uint256 j_ = i_ + 1; j_ < tokens_.length; ++j_) {
                assertTrue(tokens_[i_] != tokens_[j_]);
            }
        }
    }

    function test_bond_routesToReserveAndFundsBondPosition() public {
        uint256 id_ = _buyBond(alice, 10e18);
        assertEq(_bondNft().ownerOf(id_), alice);
        assertEq(IERC20(address(composedStable)).balanceOf(composedDetf), 0);
        assertEq(IERC20(composedDetf).balanceOf(alice), 0);
    }

    function test_bond_revertsForUnsupportedToken() public {
        _live();
        vm.expectRevert(abi.encodeWithSignature("InvalidToken(address)", address(0xBEEF)));
        composedBonding.previewBond(IERC20(address(0xBEEF)), 1e18, DEFAULT_MIN_LOCK);
    }

    function test_matureBond_paysFundedStaking_withoutMovingProtocolLp() public {
        uint256 id_ = _buyBond(alice, 10e18);
        _assertBondMaturePreviewEqualsPayment(composedDetf, id_, alice);
        _assertFundedUnstake(composedDetf, alice, _staked().balanceOf(alice));
    }

    function test_newBond_hasNoUnvestedPrincipalPayout() public {
        uint256 id_ = _buyBond(alice, 10e18);
        _assertBondPrincipalStillLocked(composedDetf, id_, alice);
        _assertBondPartialVesting(composedDetf, id_, alice);
    }
}
