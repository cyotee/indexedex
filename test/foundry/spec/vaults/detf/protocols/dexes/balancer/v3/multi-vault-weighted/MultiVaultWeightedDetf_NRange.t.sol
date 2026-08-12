// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_MultiVaultWeightedDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";
import {
    IMultiVaultWeightedDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfInfoTarget.sol";

/// @notice Deploy + first BPT bond → live for every N in 1..7.
contract MultiVaultWeightedDetf_NRange_Test is TestBase_MultiVaultWeightedDetf {
    function test_n1_deployAndLive() public {
        _assertNDeployLive(1);
    }

    function test_n2_deployAndLive() public {
        _assertNDeployLive(2);
    }

    function test_n3_deployAndLive() public {
        _assertNDeployLive(3);
    }

    function test_n4_deployAndLive() public {
        _assertNDeployLive(4);
    }

    function test_n5_deployAndLive() public {
        _assertNDeployLive(5);
    }

    function test_n6_deployAndLive() public {
        _assertNDeployLive(6);
    }

    function test_n7_deployAndLive() public {
        _assertNDeployLive(7);
    }

    function _assertNDeployLive(uint8 n) internal {
        address instance_ = _deployDetfN(n, 0, 0, true);
        IMultiVaultWeightedDetfInfo info_ = IMultiVaultWeightedDetfInfo(instance_);
        assertEq(info_.vaultCount(), n, "vaultCount");
        _assertInert(instance_);
        (uint256 tokenId_, uint256 bpt_) = _goLiveViaBptBond(instance_, alice, 500e18);
        _assertLive(instance_);
        assertTrue(tokenId_ > 0, "bond nft");
        assertTrue(bpt_ > 0, "bpt principal");
        assertEq(info_.underlyingVaults().length, n, "vaults len");
        assertEq(info_.vaultShares().length, n, "shares len");
        (uint256 wDetf_, uint256[] memory vw_) = info_.weights();
        uint256 sum_ = wDetf_;
        for (uint256 i; i < n; ++i) {
            assertTrue(vw_[i] > 0, "nonzero vault weight");
            sum_ += vw_[i];
        }
        assertEq(sum_, 1e18, "weights sum 1e18");
    }
}
