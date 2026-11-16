// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";

import {TestBase_RebasingAwareERC4626} from
    "contracts/protocols/staking/rebasingVault/TestBase_RebasingAwareERC4626.sol";
import {IRebasingAwareERC4626} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626.sol";
import {RebasingAwareOracle} from
    "test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareOracle.sol";
import {RebasingERC20Harness} from "contracts/test/stubs/RebasingERC20Harness.sol";
import {TaxedERC20Harness} from "contracts/test/stubs/TaxedERC20Harness.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";

contract RebasingAwareERC4626_Accounting is TestBase_RebasingAwareERC4626 {
    function test_ACC01_depositMintsOracleShares() public {
        uint256 assets = 100e18;
        uint256 V = _virtualShares(DEFAULT_OFFSET);
        uint256 expected = RebasingAwareOracle.sharesForDeposit(assets, 0, 0, V);
        vm.prank(alice);
        uint256 shares = vault.deposit(assets, alice);
        assertEq(shares, expected);
        assertEq(IERC20(address(vault)).balanceOf(alice), shares);
        assertEq(vault.totalAssets(), assets);
    }

    function test_ACC03_mintRedeemWithdrawMatchOracle() public {
        vm.prank(alice);
        vault.deposit(100e18, alice);
        uint256 A = vault.totalAssets();
        uint256 S = IERC20(address(vault)).totalSupply();
        uint256 V = _virtualShares(DEFAULT_OFFSET);
        uint256 mintShares = 5e18;
        uint256 mintAssets = RebasingAwareOracle.assetsForMint(mintShares, A, S, V);
        vm.prank(alice);
        uint256 paid = vault.mint(mintShares, alice);
        assertEq(paid, mintAssets);

        A = vault.totalAssets();
        S = IERC20(address(vault)).totalSupply();
        uint256 redeemShares = 3e18;
        uint256 expectedAssets = RebasingAwareOracle.assetsForRedeem(redeemShares, A, S, V);
        vm.prank(alice);
        uint256 got = vault.redeem(redeemShares, alice, alice);
        assertEq(got, expectedAssets);

        A = vault.totalAssets();
        S = IERC20(address(vault)).totalSupply();
        uint256 withdrawAssets = 2e18;
        uint256 expectedShares = RebasingAwareOracle.sharesForWithdraw(withdrawAssets, A, S, V);
        vm.prank(alice);
        uint256 burned = vault.withdraw(withdrawAssets, alice, alice);
        assertEq(burned, expectedShares);
    }

    function test_ACC08_shareDecimalsAreAssetPlusOffset() public {
        assertEq(IERC20Metadata(address(vault)).decimals(), 28);
        assertEq(IERC20Metadata(address(vault)).name(), "Wrapped Asset");
        assertEq(IERC20Metadata(address(vault)).symbol(), "wAST");
    }

    function test_ACC03_zeroAmountPreviewIsZero() public {
        assertEq(vault.previewDeposit(0), 0);
        assertEq(vault.previewMint(0), 0);
        assertEq(vault.previewRedeem(0), 0);
        assertEq(vault.previewWithdraw(0), 0);
        assertEq(vault.convertToShares(0), 0);
        assertEq(vault.convertToAssets(0), 0);
    }

    function test_API03_zeroDepositReverts() public {
        vm.prank(alice);
        vm.expectRevert(IRebasingAwareERC4626.ZeroOperationAmount.selector);
        vault.deposit(0, alice);
    }

    function test_ACC09_zeroReserveWithSharesRejectsDeposit() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(10e18, alice);
        asset.burn(address(vault), 10e18);
        assertEq(vault.totalAssets(), 0);
        assertGt(IERC20(address(vault)).totalSupply(), 0);
        assertEq(vault.maxDeposit(alice), 0);
        assertEq(vault.maxMint(alice), 0);
        vm.prank(alice);
        vm.expectRevert(IRebasingAwareERC4626.ZeroReserveWithOutstandingShares.selector);
        vault.deposit(1e18, alice);
        vm.prank(alice);
        vm.expectRevert(IRebasingAwareERC4626.ZeroOperationAmount.selector);
        vault.redeem(0, alice, alice);
        shares;
    }

    function test_ACC02_donationIncreasesShareValue() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(100e18, alice);
        asset.mint(address(vault), 50e18);
        assertEq(vault.totalAssets(), 150e18);
        vm.prank(alice);
        uint256 assets = vault.redeem(shares, alice, alice);
        uint256 V = _virtualShares(DEFAULT_OFFSET);
        uint256 expected = RebasingAwareOracle.assetsForRedeem(shares, 150e18, shares, V);
        assertEq(assets, expected);
    }

    function test_genericRebasingTokenNoDetfApi() public {
        RebasingERC20Harness rebasing = new RebasingERC20Harness("Rebase", "RBS", 18);
        IERC4626 wrapped = pkg.deployVault(IERC20Metadata(address(rebasing)));
        rebasing.mint(alice, 200e18);
        vm.startPrank(alice);
        rebasing.approve(address(wrapped), type(uint256).max);
        uint256 shares = wrapped.deposit(100e18, alice);
        vm.stopPrank();
        rebasing.rebase(address(wrapped), int256(25e18));
        assertEq(wrapped.totalAssets(), 125e18);
        vm.prank(alice);
        uint256 out = wrapped.redeem(shares, alice, alice);
        assertGt(out, 100e18);
    }

    function test_taxedTokenFailsClosed() public {
        TaxedERC20Harness taxed = new TaxedERC20Harness("Tax", "TAX", 18, 100);
        IERC4626 wrapped = pkg.deployVault(IERC20Metadata(address(taxed)));
        taxed.mint(alice, 100e18);
        vm.startPrank(alice);
        taxed.approve(address(wrapped), type(uint256).max);
        vm.expectRevert();
        wrapped.deposit(50e18, alice);
        vm.stopPrank();
    }

    function test_transferTriggeredRebaseFailsClosedThenSettledRebaseWorks() public {
        RebasingERC20Harness rebasing = new RebasingERC20Harness("Rebase", "RBS", 18);
        IERC4626 wrapped = pkg.deployVault(IERC20Metadata(address(rebasing)));
        rebasing.mint(alice, 200e18);
        rebasing.setRebaseOnTransfer(int256(1e18), address(wrapped));
        vm.startPrank(alice);
        rebasing.approve(address(wrapped), type(uint256).max);
        vm.expectRevert();
        wrapped.deposit(50e18, alice);
        vm.stopPrank();
        rebasing.setRebaseOnTransfer(0, address(0));
        rebasing.rebase(address(wrapped), int256(1e18));
        vm.prank(alice);
        uint256 shares = wrapped.deposit(50e18, alice);
        assertGt(shares, 0);
    }

    function test_offsetBounds() public {
        ERC20PermitMintableStub t = new ERC20PermitMintableStub("T", "T", 18, address(this), 0);
        IERC4626 v0 = pkg.deployVault(IERC20Metadata(address(t)), 0, bytes32(uint256(1)));
        assertEq(IERC20Metadata(address(v0)).decimals(), 28);
        IERC4626 v10 = pkg.deployVault(IERC20Metadata(address(t)), 10, bytes32(uint256(2)));
        assertEq(IERC20Metadata(address(v10)).decimals(), 28);
        IERC4626 v18 = pkg.deployVault(IERC20Metadata(address(t)), 18, bytes32(uint256(3)));
        assertEq(IERC20Metadata(address(v18)).decimals(), 36);
        vm.expectRevert(
            abi.encodeWithSelector(IRebasingAwareERC4626.UnsupportedDecimalOffset.selector, uint8(19))
        );
        pkg.deployVault(IERC20Metadata(address(t)), 19, bytes32(uint256(4)));
    }

    function test_emptyVaultExchangeRate() public {
        uint256 rate = IStandardizedYield(address(vault)).exchangeRate();
        assertEq(rate, RebasingAwareOracle.wadRate(0, 0, _virtualShares(DEFAULT_OFFSET)));
        assertEq(rate, 1e8);
    }

    function test_pythonOracleVectors() public view {
        string memory raw = vm.readFile(
            "test/foundry/spec/protocols/staking/rebasingVault/oracle/vectors.json"
        );
        for (uint256 i; i < 8; ++i) {
            string memory p = string.concat("$[", vm.toString(i), "]");
            uint256 A = vm.parseUint(vm.parseJsonString(raw, string.concat(p, ".A")));
            uint256 S = vm.parseUint(vm.parseJsonString(raw, string.concat(p, ".S")));
            uint256 V = vm.parseUint(vm.parseJsonString(raw, string.concat(p, ".V")));
            uint256 x = vm.parseUint(vm.parseJsonString(raw, string.concat(p, ".x")));
            uint256 depositShares =
                vm.parseUint(vm.parseJsonString(raw, string.concat(p, ".depositShares")));
            uint256 mintAssets = vm.parseUint(vm.parseJsonString(raw, string.concat(p, ".mintAssets")));
            uint256 redeemAssets =
                vm.parseUint(vm.parseJsonString(raw, string.concat(p, ".redeemAssets")));
            uint256 withdrawShares =
                vm.parseUint(vm.parseJsonString(raw, string.concat(p, ".withdrawShares")));
            uint256 wadRate = vm.parseUint(vm.parseJsonString(raw, string.concat(p, ".wadRate")));
            // Solidity oracle uses native mul; skip rows whose intermediates overflow uint256.
            if (!_fitsMul(x, S + V) || !_fitsMul(x, A + 1) || !_fitsMul(1e18, A + 1)) continue;
            assertEq(RebasingAwareOracle.sharesForDeposit(x, A, S, V), depositShares);
            assertEq(RebasingAwareOracle.assetsForMint(x, A, S, V), mintAssets);
            assertEq(RebasingAwareOracle.assetsForRedeem(x, A, S, V), redeemAssets);
            assertEq(RebasingAwareOracle.sharesForWithdraw(x, A, S, V), withdrawShares);
            assertEq(RebasingAwareOracle.wadRate(A, S, V), wadRate);
        }
    }

    function test_F07_assetDecimalsSixEightNine() public {
        uint8[3] memory decs = [uint8(6), 8, 9];
        for (uint256 i; i < decs.length; ++i) {
            ERC20PermitMintableStub t =
                new ERC20PermitMintableStub("T", "T", decs[i], address(this), 0);
            IERC4626 wrapped = pkg.deployVault(IERC20Metadata(address(t)), 10, bytes32(uint256(10 + i)));
            assertEq(IERC20Metadata(address(wrapped)).decimals(), uint8(decs[i] + 10));
            t.mint(alice, 1_000 * (10 ** decs[i]));
            vm.startPrank(alice);
            t.approve(address(wrapped), type(uint256).max);
            uint256 shares = wrapped.deposit(10 ** decs[i], alice);
            vm.stopPrank();
            assertGt(shares, 0);
        }
    }

    function test_F07_offsetNineNormalizesToTen_offset255Reverts() public {
        ERC20PermitMintableStub t = new ERC20PermitMintableStub("T", "T", 18, address(this), 0);
        IERC4626 v9 = pkg.deployVault(IERC20Metadata(address(t)), 9, bytes32(uint256(20)));
        assertEq(IERC20Metadata(address(v9)).decimals(), 28);
        vm.expectRevert(
            abi.encodeWithSelector(IRebasingAwareERC4626.UnsupportedDecimalOffset.selector, uint8(255))
        );
        pkg.deployVault(IERC20Metadata(address(t)), 255, bytes32(uint256(21)));
    }

    function test_ACC09_oneUnitDepositAndDustResidual() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(1, alice);
        assertEq(shares, _virtualShares(DEFAULT_OFFSET));
        vm.prank(alice);
        uint256 out = vault.redeem(shares, alice, alice);
        assertLe(out, 1);
    }

    function test_F21_exchangeRateUnderflowThenExitStillWorks() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(1e18, alice);
        asset.burn(address(vault), 1e18);
        vm.expectRevert(IRebasingAwareERC4626.SYExchangeRateUnderflow.selector);
        IStandardizedYield(address(vault)).exchangeRate();
        asset.mint(address(vault), 1e18);
        uint256 rate = IStandardizedYield(address(vault)).exchangeRate();
        assertGt(rate, 0);
        vm.prank(alice);
        uint256 out = vault.redeem(shares / 2, alice, alice);
        assertGt(out, 0);
    }

    function test_maxViewsZeroWhenDisabledOrInsolvent() public {
        assertGt(vault.maxDeposit(alice), 0);
        vm.prank(alice);
        vault.deposit(5e18, alice);
        asset.burn(address(vault), 5e18);
        assertEq(vault.maxDeposit(alice), 0);
        assertEq(vault.maxMint(alice), 0);
    }

    function _fitsMul(uint256 a, uint256 b) private pure returns (bool) {
        if (a == 0 || b == 0) return true;
        return a <= type(uint256).max / b;
    }
}
