// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {
    IMixedBufferMultiVaultStableDetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfDFPkg.sol";
import {
    IMixedBufferMultiVaultStableDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfInfoTarget.sol";
import {
    IMixedBufferMultiVaultStableDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfBondingTarget.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

contract MixedBufferMultiVaultStableDetf_RateProviders_Test is TestBase_MixedBufferMultiVaultStableDetf {
    function test_share_STANDARD_default() public view {
        // Default deploy uses address(0) share RPs → STANDARD.
        assertEq(detfInfo.rateProvider(0), address(0), "standard share rp");
    }

    function test_share_WITH_RATE_matrix() public {
        _ensureSeVaults(1);
        // Deploy a real SE rate provider for share leg.
        IRateProvider rp_ = rateProviderPkg.deployRateProvider(
            IStandardExchange(address(seVaults[0])), seShares[0], IERC20(address(dai))
        );

        // Product Open (always-allow when live); illegal mint=1/burn=max pairs fail mint>burn validation.
        IMixedBufferMultiVaultStableDetfDFPkg.PkgArgs memory args =
            _buildPkgArgs(1, 0, 0, ThresholdMode.Open);
        args.vaultShareRateProviders[0] = rp_;

        vm.startPrank(owner);
        address d = indexedexManager.deployVault(
            IStandardVaultPkg(address(mixedBufferDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();

        assertEq(IMixedBufferMultiVaultStableDetfInfo(d).rateProvider(0), address(rp_), "with_rate");
        _bootstrapDefault(d, alice);
        uint256 out_ = _mintDetfFromVaultShare(d, 0, bob, 40e18);
        assertTrue(out_ > 0, "mint with rate");
        out_ = _mintDetfFromBuffer(d, bob, 40e18);
        assertTrue(out_ > 0, "buffer mint with rated share leg");
    }
}
