// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MigrationLegacyHandler} from "./MigrationLegacyHandler.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IUniswapV4DetfMigration as Migration} from "../interfaces/IUniswapV4DetfMigration.sol";

/// @notice All surrendered positions retain independent holders, principal debits and fresh clocks.
abstract contract MigrationLegacyClaimHandler is MigrationLegacyHandler {
    uint256 public principalPaid;
    uint256 public claimActions;
    uint256 public bondTransfers;

    constructor(Migration m_, OriginalNft[2] memory n_, uint256 c_, uint256 protectedDtf_)
        MigrationLegacyHandler(m_, n_, c_, protectedDtf_) {}

    function positionCount() external view returns (uint256) { return funded.length; }
    function positionStart(uint256 i_) external view returns (uint256) { return funded[i_].start; }

    /// @notice Time only advances to exercise economic clocks, never as a synchronization wait.
    function advanceTime(uint256 seed_) public {
        vm.warp(vm.getBlockTimestamp() + (seed_ % 45 + 1) * 1 days);
        assertEq(parent.pendingExpansionDetf(), 0, "bounded parent expansion domain");
        assertAll();
    }

    function transferBond(uint256 seed_) public {
        Funded storage f_ = funded[seed_ % funded.length];
        if (f_.retired) {
            vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", f_.id));
            bonds.positionOf(f_.id);
            ++rejections;
        } else {
            address next_ = f_.wallet == OTHER ? address(0x2488) : OTHER;
            vm.prank(f_.wallet);
            IERC721(address(bonds)).transferFrom(f_.wallet, next_, f_.id);
            f_.wallet = next_;
            ++bondTransfers; ++successes;
        }
        assertAll();
    }

    function claimPrincipal(uint256 seed_) public { _claim(seed_, false); }
    function claimRewards(uint256 seed_) public { _claim(seed_, true); }

    function _claim(uint256 seed_, bool rewards_) private {
        Funded storage f_ = funded[seed_ % funded.length];
        if (f_.retired) {
            vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", f_.id));
            bonds.positionOf(f_.id);
            ++rejections;
        } else {
            uint256 due_ = rewards_ ? f_.gons / k - (f_.principal - f_.claimed)
                : block.timestamp >= f_.start + 90 days ? f_.principal - f_.claimed : 0;
            uint256 before_ = receipt.gonsOf(f_.wallet);
            vm.prank(f_.wallet);
            uint256 paid_ = rewards_ ? bonds.claimRewards(f_.id, f_.wallet)
                : bonds.claimPrincipal(f_.id, f_.wallet);
            assertEq(paid_, due_, "independent surrendered-position claim");
            assertEq(receipt.gonsOf(f_.wallet), before_ + due_ * k, "exact current-holder receipt");
            f_.gons -= due_ * k; newGons -= due_ * k;
            if (!rewards_) { f_.claimed += due_; principalPaid += due_; }
            if (f_.claimed == f_.principal && f_.gons < k) {
                newGons -= f_.gons; f_.gons = 0; f_.retired = true;
            }
            if (paid_ != 0) ++successes;
            ++claimActions;
        }
        assertAll();
    }
}
