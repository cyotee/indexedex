// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {TestBase_LidoWstETHStandardExchange} from "contracts/test/bases/TestBase_LidoWstETHStandardExchange.sol";
import {TestBase_EtherFiWeETHStandardExchange} from "contracts/test/bases/TestBase_EtherFiWeETHStandardExchange.sol";
import {TestBase_RocketPoolRETHStandardExchange} from "contracts/test/bases/TestBase_RocketPoolRETHStandardExchange.sol";
import {TestBase_RebasingAwareERC4626} from "contracts/protocols/staking/rebasingVault/TestBase_RebasingAwareERC4626.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";

interface IEthIn { function exchangeInEth(IERC20 tokenOut, uint256 minAmountOut, address recipient, uint256 deadline) external payable returns (uint256); }
interface ISYDep { function deposit(address receiver, address tokenIn, uint256 amount, uint256 minSharesOut) external payable returns (uint256); }

/// Shared probe logic: after registry disable, an unprivileged user tries every inbound route.
library Probe {
    function sy(address se, address weth, uint256 amt, address who) internal returns (bool ok, uint256 out) {
        (bool s, bytes memory r) = se.call(abi.encodeCall(ISYDep.deposit, (who, weth, amt, 0)));
        ok = s; if (s && r.length >= 32) out = abi.decode(r, (uint256));
        if (!s) { console2.log("  SY.deposit reverted, selector:"); console2.logBytes(r); }
    }
    function erc4626(address se, uint256 amt, address who) internal returns (bool ok, uint256 out) {
        (bool s, bytes memory r) = se.call(abi.encodeCall(IERC4626.deposit, (amt, who)));
        ok = s; if (s && r.length >= 32) out = abi.decode(r, (uint256));
        if (!s) { console2.log("  ERC4626.deposit reverted, data:"); console2.logBytes(r); }
    }
}

abstract contract NoKillCommon {
    function _report(string memory fam, uint256 inS, uint256 outPaid, bool syOk, uint256 syS, bool d4626Ok, uint256 d4626S) internal pure {
        console2.log("==", fam, "SE: registry.isDisabled(se)==true; inbound routes as unprivileged user ==");
        console2.log("  exchangeIn(WETH->share) shares:", inS);
        console2.log("  exchangeOut(WETH->1e18 share) WETH paid:", outPaid);
        console2.log("  SY.deposit ok:", syOk, "shares:", syS);
        console2.log("  ERC4626.deposit ok:", d4626Ok, "shares:", d4626S);
    }
}

contract Lido_NoKill_Test is TestBase_LidoWstETHStandardExchange, NoKillCommon {
    address lp = makeAddr("honestLP");
    address user = makeAddr("postDisableUser");

    function _in(address who, uint256 amt) internal returns (uint256 s) {
        _dealWeth(who, amt);
        vm.startPrank(who);
        hermeticWeth.approve(seVault, amt);s = seIn.exchangeIn(IERC20(address(hermeticWeth)), amt, IERC20(seVault), 0, who, false, block.timestamp + 1);
        vm.stopPrank();
    }

    function test_lido_killSwitchIgnored() public {
        _in(lp, 100 ether); // honest pre-existing depositor
        vm.startPrank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(seVault, true);
        IVaultRegistryDisableManager(address(indexedexManager)).setPackageDisabled(address(lidoSeDFPkg), true);
        vm.stopPrank();
        assertTrue(IVaultRegistryDisableQuery(address(indexedexManager)).isDisabled(seVault), "registry disabled");
        uint256 supply0 = IERC20(seVault).totalSupply();

        uint256 s = _in(user, 10 ether);
        _dealWeth(user, 30 ether);
        vm.startPrank(user);
        hermeticWeth.approve(seVault, type(uint256).max);
        uint256 paid = seOut.exchangeOut(IERC20(address(hermeticWeth)), 10 ether, IERC20(seVault), 1 ether, user, false, block.timestamp + 1);
        (bool syOk, uint256 syS) = Probe.sy(seVault, address(hermeticWeth), 5 ether, user);
        (bool dOk, uint256 dS) = Probe.erc4626(seVault, 5 ether, user);
        vm.stopPrank();

        vm.deal(user, 5 ether);
        vm.prank(user);
        uint256 e = IEthIn(seVault).exchangeInEth{value: 5 ether}(IERC20(seVault), 0, user, block.timestamp + 1);

        _report("Lido wstETH", s, paid, syOk, syS, dOk, dS);
        console2.log("  exchangeInEth(5 ETH) shares:", e);
        console2.log("  totalSupply before/after:", supply0, IERC20(seVault).totalSupply());
        assertGt(s, 0, "exchangeIn not gated");
        assertGt(paid, 0, "exchangeOut not gated");
        assertGt(e, 0, "exchangeInEth not gated");
        assertTrue(syOk && syS > 0, "SY deposit not gated");
        assertGt(IERC20(seVault).totalSupply(), supply0, "supply grew while disabled");
    }
}

contract EtherFi_NoKill_Test is TestBase_EtherFiWeETHStandardExchange, NoKillCommon {
    address lp = makeAddr("honestLP");
    address user = makeAddr("postDisableUser");

    function _in(address who, uint256 amt) internal returns (uint256 s) {
        _dealWeth(who, amt);
        vm.startPrank(who);
        hermeticWeth.approve(seVault, amt);s = seIn.exchangeIn(IERC20(address(hermeticWeth)), amt, IERC20(seVault), 0, who, false, block.timestamp + 1);
        vm.stopPrank();
    }

    function test_etherfi_killSwitchIgnored() public {
        _in(lp, 100 ether);
        vm.startPrank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(seVault, true);
        IVaultRegistryDisableManager(address(indexedexManager)).setPackageDisabled(address(etherFiSeDFPkg), true);
        vm.stopPrank();
        assertTrue(IVaultRegistryDisableQuery(address(indexedexManager)).isDisabled(seVault), "registry disabled");
        uint256 supply0 = IERC20(seVault).totalSupply();

        uint256 s = _in(user, 10 ether);
        _dealWeth(user, 30 ether);
        vm.startPrank(user);
        hermeticWeth.approve(seVault, type(uint256).max);
        uint256 paid = seOut.exchangeOut(IERC20(address(hermeticWeth)), 10 ether, IERC20(seVault), 1 ether, user, false, block.timestamp + 1);
        (bool syOk, uint256 syS) = Probe.sy(seVault, address(hermeticWeth), 5 ether, user);
        (bool dOk, uint256 dS) = Probe.erc4626(seVault, 5 ether, user);
        vm.stopPrank();

        _report("EtherFi weETH", s, paid, syOk, syS, dOk, dS);
        console2.log("  totalSupply before/after:", supply0, IERC20(seVault).totalSupply());
        assertGt(s, 0, "exchangeIn not gated");
        assertGt(paid, 0, "exchangeOut not gated");
        assertTrue(syOk && syS > 0, "SY deposit not gated");
        assertGt(IERC20(seVault).totalSupply(), supply0, "supply grew while disabled");
    }
}

contract Rocket_NoKill_Test is TestBase_RocketPoolRETHStandardExchange, NoKillCommon {
    address lp = makeAddr("honestLP");
    address user = makeAddr("postDisableUser");

    function _in(address who, uint256 amt) internal returns (uint256 s) {
        _dealWeth(who, amt);
        vm.startPrank(who);
        hermeticWeth.approve(seVault, amt);s = seIn.exchangeIn(IERC20(address(hermeticWeth)), amt, IERC20(seVault), 0, who, false, block.timestamp + 1);
        vm.stopPrank();
    }

    function test_rocket_killSwitchIgnored() public {
        _in(lp, 100 ether);
        vm.startPrank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(seVault, true);
        IVaultRegistryDisableManager(address(indexedexManager)).setPackageDisabled(address(rocketPoolSeDFPkg), true);
        vm.stopPrank();
        assertTrue(IVaultRegistryDisableQuery(address(indexedexManager)).isDisabled(seVault), "registry disabled");
        uint256 supply0 = IERC20(seVault).totalSupply();

        uint256 s = _in(user, 10 ether);
        _dealWeth(user, 30 ether);
        vm.startPrank(user);
        hermeticWeth.approve(seVault, type(uint256).max);
        uint256 paid = seOut.exchangeOut(IERC20(address(hermeticWeth)), 10 ether, IERC20(seVault), 1 ether, user, false, block.timestamp + 1);
        (bool syOk, uint256 syS) = Probe.sy(seVault, address(hermeticWeth), 5 ether, user);
        (bool dOk, uint256 dS) = Probe.erc4626(seVault, 5 ether, user);
        vm.stopPrank();

        _report("RocketPool rETH", s, paid, syOk, syS, dOk, dS);
        console2.log("  totalSupply before/after:", supply0, IERC20(seVault).totalSupply());
        assertGt(s, 0, "exchangeIn not gated");
        assertGt(paid, 0, "exchangeOut not gated");
        assertTrue(syOk && syS > 0, "SY deposit not gated");
        assertGt(IERC20(seVault).totalSupply(), supply0, "supply grew while disabled");
    }
}

/// CONTROL: the sibling RebasingAware staking family honours the same registry switch.
contract RebasingAware_Control_Test is TestBase_RebasingAwareERC4626 {
    function test_control_rebasingAware_gated() public {
        vm.prank(alice);
        vault.deposit(100e18, alice);
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(address(vault), true);
        assertTrue(IVaultRegistryDisableQuery(address(indexedexManager)).isDisabled(address(vault)));

        vm.prank(bob);
        (bool okDep, bytes memory r1) = address(vault).call(abi.encodeCall(IERC4626.deposit, (10e18, bob)));
        vm.prank(bob);
        (bool okEx, bytes memory r2) = address(vault).call(abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (IERC20(address(asset)), 10e18, IERC20(address(vault)), 0, bob, false, block.timestamp + 1)));
        console2.log("== CONTROL RebasingAware: deposit ok:", okDep, "exchangeIn ok:", okEx);
        console2.logBytes(r1); console2.logBytes(r2);
        assertFalse(okDep, "control deposit should be gated");
        assertFalse(okEx, "control exchangeIn should be gated");
        assertEq(bytes4(r1), IVaultRegistryDisableQuery.VaultDisabled.selector);
        assertEq(bytes4(r2), IVaultRegistryDisableQuery.VaultDisabled.selector);
        // exits still open on the control (by design)
        uint256 half = IERC20(address(vault)).balanceOf(alice) / 2;
        vm.prank(alice);
        uint256 a = vault.redeem(half, alice, alice);
        assertGt(a, 0);
    }
}
