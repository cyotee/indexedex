// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {V4FundedD25Behavior} from "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_CloseD25Base.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IDetfErrors} from "contracts/interfaces/IDetfErrors.sol";
import {
    DETF_CREATOR_BOND_NFT_ID,
    DETF_FEE_TO_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {TestBase_UniswapV4Detf_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Decimals.sol";

/// @notice Shared funded D25 fixtures; deployment and native funding stay in the gold TestBase.
/// @dev OpenBase and later Stage 11 Open call these internals (R-7 / R-24).
abstract contract UniswapV4Detf_Alignment_CloseD25Base_Decimals is TestBase_UniswapV4Detf_Decimals, V4FundedD25Behavior {
    address internal d25Alice;
    address internal d25Bob;

    function _nft() internal view virtual returns (IDETFNFTVault) {
        return IDETFNFTVault(detfInfo.bondNftVault());
    }

    function _deadline() internal view virtual returns (uint256) {
        return block.timestamp + 1 hours;
    }

    function _minOut() internal view virtual returns (uint256[] memory m) {
        m = new uint256[](IUniswapV4SeBufferHook(detfInfo.hook()).tokens().length);
    }

    function _ensureActors() internal {
        if (d25Alice != address(0)) return;
        d25Alice = makeAddr("d25alice");
        d25Bob = makeAddr("d25bob");
    }

    function _bondAs(address bonder_, uint256 pairAmount_)
        internal
        virtual
        returns (uint256 tokenId_, uint256 shares_)
    {
        _fundBondLegs(bonder_, pairAmount_);
        vm.startPrank(bonder_);
        IERC20(address(pairToken)).approve(detf, type(uint256).max);
        (tokenId_, shares_) = detfInfo.bond(
            IERC20(address(pairToken)),
            pairAmount_,
            DEFAULT_MIN_LOCK,
            bonder_,
            false,
            _deadline()
        );
        vm.stopPrank();
    }

    function _liveAliceBob() internal returns (uint256 aliceId_, uint256 bobId_) {
        _ensureActors();
        (aliceId_,) = _bondAs(d25Alice, _uPair(40));
        (bobId_,) = _bondAs(d25Bob, _uPair(4));
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
    }

    function _liveAliceOnly() internal returns (uint256 aliceId_) {
        _ensureActors();
        (aliceId_,) = _bondAs(d25Alice, _uPair(40));
        _d25SeedHook();
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
    }

    /// @dev Retain provider-specific live reserve seeding before the final funded claim.
    function _d25SeedHook() internal virtual {}

}
