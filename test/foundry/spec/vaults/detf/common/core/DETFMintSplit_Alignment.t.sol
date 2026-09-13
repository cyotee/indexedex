// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {DETFMintSplitLib} from "contracts/vaults/detf/common/core/DETFMintSplitLib.sol";
import {DETFSeigniorageShareLib} from "contracts/vaults/detf/common/core/DETFSeigniorageShareLib.sol";

/**
 * @title DETFMintSplit_Alignment_Test
 * @notice Alignment D3/D4/D27/L1 plus D2 floor formula. Drives the shipped libs.
 */
contract DETFMintSplit_Alignment_Test is Test {
    uint256 internal constant P = 5e16;
    uint256 internal constant GROSS = 100e9;

    function test_liveMint_U_is_Gross_userAndPot() public pure {
        (uint256 user_, uint256 pot_) = DETFMintSplitLib._splitLiveGross(GROSS, P);
        assertEq(user_, 95e9, "user (1-p)*Gross");
        assertEq(pot_, 5e9, "pot p*Gross");
        assertEq(user_ + pot_, GROSS, "exact on this p");
    }

    function test_bond_independentPurchasedAllocationAndLiquidity() public pure {
        (uint256 user_, uint256 pot_, uint256 join_) = DETFMintSplitLib._splitBond(120e9, GROSS, P);
        assertEq(join_, GROSS, "join G unboosted");
        assertEq(user_, 114e9, "principal (1-p)*U");
        assertEq(pot_, 11e9, "D3 pU + D4 pG");
    }

    function test_bond_equalQuotesPreserveExistingSplit() public pure {
        (uint256 user_, uint256 pot_, uint256 join_) = DETFMintSplitLib._splitBond(GROSS, GROSS, P);
        assertEq(join_, GROSS);
        assertEq(user_, 95e9);
        assertEq(pot_, 10e9);
    }

    function test_split_floors_mulDiv() public pure {
        uint256 odd_ = 1e9 + 1;
        (uint256 liveUser_, uint256 livePot_) = DETFMintSplitLib._splitLiveGross(odd_, P);
        assertEq(liveUser_, (odd_ * (1e18 - P)) / 1e18, "live user floor");
        assertEq(livePot_, (odd_ * P) / 1e18, "live pot floor");
        assertTrue(liveUser_ + livePot_ <= odd_, "live dust not over-mint");

        (uint256 bondUser_, uint256 bondPot_, uint256 join_) = DETFMintSplitLib._splitBond(odd_, odd_ + 19, P);
        assertEq(join_, odd_ + 19);
        assertEq(bondUser_, (odd_ * (1e18 - P)) / 1e18, "bond user floor");
        uint256 d3_ = (odd_ * P) / 1e18;
        assertEq(bondPot_, d3_ + ((odd_ + 19) * P) / 1e18, "bond pot independent floors");
    }

    function test_d2_topUpDeltas_workedExample() public pure {
        // PRD §3.4: O=100e18, f=0.10e18, c=0.05e18. Runtime uint256 so solc does not fold a rational.
        uint256 others_ = 100e18;
        uint256 one_ = 1e18;
        uint256 f_ = 10e16;
        uint256 c_ = 5e16;
        (uint256 dF_, uint256 dC_) = DETFSeigniorageShareLib._topUpDeltas(others_, 0, 0, f_, c_);
        uint256 impliedTotal_ = (others_ * one_) / (one_ - f_ - c_);
        assertEq(dF_, (impliedTotal_ * f_) / one_, "dF floor");
        assertEq(dC_, (impliedTotal_ * c_) / one_, "dC floor");
        uint256 newTotal_ = others_ + dF_ + dC_;
        assertLe((dF_ * one_) / newTotal_, f_, "realized f not above target");
        assertLe((dC_ * one_) / newTotal_, c_, "realized c not above target");
    }

    function test_d2_zero_when_already_at_or_above_target() public pure {
        (uint256 dF_, uint256 dC_) = DETFSeigniorageShareLib._topUpDeltas(100e18, 20e18, 10e18, 10e16, 5e16);
        assertEq(dF_, 0, "no negative dF");
        assertEq(dC_, 0, "no negative dC");
    }

    function test_d2_zero_when_f_and_c_zero() public pure {
        (uint256 dF_, uint256 dC_) = DETFSeigniorageShareLib._topUpDeltas(100e18, 0, 0, 0, 0);
        assertEq(dF_, 0);
        assertEq(dC_, 0);
    }
}
