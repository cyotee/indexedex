// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {
    TestBase_MultiVaultWeightedDetf
} from "contracts/vaults/detf/composed/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";
import {
    IMultiVaultWeightedDetfDFPkg
} from "contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetfDFPkg.sol";
import {
    IMultiVaultWeightedDetfInfo
} from "contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetfInfoTarget.sol";

contract MultiVaultWeightedDetf_Deploy_Test is TestBase_MultiVaultWeightedDetf {
    function test_deploy_inert_n1() public view {
        _assertInert(detf);
        assertEq(detfInfo.vaultCount(), 1, "vault count");
        assertTrue(detfInfo.reservePool() != address(0), "reserve pool");
        assertEq(detfInfo.underlyingVaults()[0], address(seVault0), "vault0");
        (uint256 wDetf_, uint256[] memory vw_) = detfInfo.weights();
        assertEq(wDetf_, 80e16, "detf weight");
        assertEq(vw_[0], 20e16, "vault weight");
        assertEq(detfInfo.mintThreshold(), 1.05e18, "default mint threshold");
        assertEq(detfInfo.burnThreshold(), 0.95e18, "default burn threshold");
    }

    function test_deploy_n2_disparate_rateAssets() public {
        address d2 = _deployDetfN2(0, 0);
        assertFalse(IMultiVaultWeightedDetfInfo(d2).isReserveLive(), "inert");
        assertEq(IMultiVaultWeightedDetfInfo(d2).vaultCount(), 2, "n=2");
        address[] memory ras = IMultiVaultWeightedDetfInfo(d2).rateAssets();
        assertEq(ras[0], address(rateAsset0), "rate0");
        assertEq(ras[1], address(rateAsset1), "rate1");
    }

    function test_deploy_reverts_invalid_weights() public {
        IStandardExchangeProxy[] memory vaults_ = new IStandardExchangeProxy[](1);
        IERC20[] memory shares_ = new IERC20[](1);
        IRateProvider[] memory rps_ = new IRateProvider[](1);
        IERC20[] memory ras_ = new IERC20[](1);
        uint256[] memory weights_ = new uint256[](1);
        vaults_[0] = seVault0;
        shares_[0] = IERC20(address(0));
        ras_[0] = rateAsset0;
        weights_[0] = 10e16;

        IMultiVaultWeightedDetfDFPkg.PkgArgs memory args = IMultiVaultWeightedDetfDFPkg.PkgArgs({
            name: "bad",
            symbol: "bad",
            vaults: vaults_,
            vaultShares: shares_,
            rateProviders: rps_,
            rateAssets: ras_,
            weightDetf: 80e16,
            vaultWeights: weights_,
            mintThreshold: 0,
            burnThreshold: 0
        });

        vm.startPrank(owner);
        vm.expectRevert();
        indexedexManager.deployVault(IStandardVaultPkg(address(multiVaultWeightedDetfPkg)), abi.encode(args));
        vm.stopPrank();
    }

    function test_deploy_reverts_duplicate_vault() public {
        IStandardExchangeProxy[] memory vaults_ = new IStandardExchangeProxy[](2);
        IERC20[] memory shares_ = new IERC20[](2);
        IRateProvider[] memory rps_ = new IRateProvider[](2);
        IERC20[] memory ras_ = new IERC20[](2);
        uint256[] memory weights_ = new uint256[](2);
        vaults_[0] = seVault0;
        vaults_[1] = seVault0;
        shares_[0] = IERC20(address(0));
        shares_[1] = IERC20(address(0));
        ras_[0] = rateAsset0;
        ras_[1] = rateAsset0;
        weights_[0] = 10e16;
        weights_[1] = 10e16;

        IMultiVaultWeightedDetfDFPkg.PkgArgs memory args = IMultiVaultWeightedDetfDFPkg.PkgArgs({
            name: "dup",
            symbol: "dup",
            vaults: vaults_,
            vaultShares: shares_,
            rateProviders: rps_,
            rateAssets: ras_,
            weightDetf: 80e16,
            vaultWeights: weights_,
            mintThreshold: 0,
            burnThreshold: 0
        });

        vm.startPrank(owner);
        vm.expectRevert();
        indexedexManager.deployVault(IStandardVaultPkg(address(multiVaultWeightedDetfPkg)), abi.encode(args));
        vm.stopPrank();
    }
}
