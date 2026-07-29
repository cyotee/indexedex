// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf
} from "contracts/vaults/detf/composed/stable/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {
    IMixedBufferMultiVaultStableDetfDFPkg
} from "contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetfDFPkg.sol";
import {
    IMixedBufferMultiVaultStableDetfInfo
} from "contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetfInfoTarget.sol";
import {
    MixedBufferMultiVaultStableDetfRepo
} from "contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetfRepo.sol";
import {
    IMixedBufferMultiVaultStablePool
} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/IMixedBufferMultiVaultStablePool.sol";

contract MixedBufferMultiVaultStableDetf_Deploy_Test is TestBase_MixedBufferMultiVaultStableDetf {
    function test_deploy_inert_n1() public view {
        _assertInert(detf);
        assertEq(detfInfo.vaultCount(), 1, "vault count");
        assertTrue(detfInfo.reservePool() != address(0), "reserve pool");
        assertEq(detfInfo.underlyingVaults()[0], address(seVaults[0]), "vault0");
        assertEq(detfInfo.bufferToken(), address(dai), "buffer");
        assertEq(detfInfo.mintThreshold(), 1.05e18, "default mint threshold");
        assertEq(detfInfo.burnThreshold(), 0.95e18, "default burn threshold");
        assertEq(uint8(detfInfo.thresholdMode()), uint8(0), "default mode Policy");
        assertEq(detfInfo.amplificationParameter(), MBMVS_AMP, "amp");

        // MixedBuffer layout: T=3, buffer STANDARD, DETF STANDARD
        IMixedBufferMultiVaultStablePool pool_ = IMixedBufferMultiVaultStablePool(detfInfo.reservePool());
        assertEq(pool_.tokenCount(), 3, "T=2+N");
        assertEq(pool_.vaultCount(), 1, "N");
        assertEq(pool_.unpairedCount(), 1, "U");
        assertEq(address(pool_.bufferToken()), address(dai), "pool buffer");
        assertEq(IERC20(detfInfo.reservePool()).totalSupply(), 0, "pool not initialized");
    }

    function test_deploy_n2() public {
        address d2 = _deployDetfN(2, 0, 0);
        assertFalse(IMixedBufferMultiVaultStableDetfInfo(d2).isReserveLive(), "inert");
        assertEq(IMixedBufferMultiVaultStableDetfInfo(d2).vaultCount(), 2, "n=2");
        IMixedBufferMultiVaultStablePool pool_ =
            IMixedBufferMultiVaultStablePool(IMixedBufferMultiVaultStableDetfInfo(d2).reservePool());
        assertEq(pool_.tokenCount(), 4, "T=4");
    }

    function test_deploy_n3_smoke() public {
        address d3 = _deployDetfN(3, 0, 0);
        assertEq(IMixedBufferMultiVaultStableDetfInfo(d3).vaultCount(), 3, "n=3");
        IMixedBufferMultiVaultStablePool pool_ =
            IMixedBufferMultiVaultStablePool(IMixedBufferMultiVaultStableDetfInfo(d3).reservePool());
        assertEq(pool_.tokenCount(), 5, "T=5");
    }

    function test_deploy_reverts_invalid_vault_count_zero() public {
        IMixedBufferMultiVaultStableDetfDFPkg.PkgArgs memory args;
        args.name = "bad";
        args.symbol = "bad";
        args.bufferToken = IERC20(address(dai));
        args.standardExchangeVaults = new IStandardExchange[](0);
        args.vaultShareRateProviders = new IRateProvider[](0);
        args.amplificationParameter = MBMVS_AMP;

        vm.startPrank(owner);
        vm.expectRevert();
        indexedexManager.deployVault(IStandardVaultPkg(address(mixedBufferDetfPkg)), abi.encode(args));
        vm.stopPrank();
    }

    function test_deploy_reverts_duplicate_vault() public {
        IMixedBufferMultiVaultStableDetfDFPkg.PkgArgs memory args;
        args.name = "dup";
        args.symbol = "dup";
        args.bufferToken = IERC20(address(dai));
        args.standardExchangeVaults = new IStandardExchange[](2);
        args.vaultShareRateProviders = new IRateProvider[](2);
        args.standardExchangeVaults[0] = IStandardExchange(address(seVaults[0]));
        args.standardExchangeVaults[1] = IStandardExchange(address(seVaults[0]));
        args.amplificationParameter = MBMVS_AMP;

        vm.startPrank(owner);
        vm.expectRevert();
        indexedexManager.deployVault(IStandardVaultPkg(address(mixedBufferDetfPkg)), abi.encode(args));
        vm.stopPrank();
    }

    function test_deploy_reverts_bad_amp() public {
        IMixedBufferMultiVaultStableDetfDFPkg.PkgArgs memory args = _buildPkgArgs(1, 0, 0);
        args.amplificationParameter = 0; // below MIN_AMP

        vm.startPrank(owner);
        vm.expectRevert();
        indexedexManager.deployVault(IStandardVaultPkg(address(mixedBufferDetfPkg)), abi.encode(args));
        vm.stopPrank();
    }

    function test_deploy_reverts_rp_length_mismatch() public {
        IMixedBufferMultiVaultStableDetfDFPkg.PkgArgs memory args = _buildPkgArgs(1, 0, 0);
        args.vaultShareRateProviders = new IRateProvider[](2); // != N

        vm.startPrank(owner);
        vm.expectRevert();
        indexedexManager.deployVault(IStandardVaultPkg(address(mixedBufferDetfPkg)), abi.encode(args));
        vm.stopPrank();
    }

    function test_deploy_via_registry_not_new() public view {
        // Package address is non-zero and wired through manager registry path in setUp.
        assertTrue(address(mixedBufferDetfPkg) != address(0), "pkg");
        assertTrue(detf != address(0), "instance");
        assertTrue(detfInfo.bondNftVault() != address(0), "bond nft");
        assertTrue(detfInfo.rebasingClaimToken() != address(0), "claim");
    }
}
