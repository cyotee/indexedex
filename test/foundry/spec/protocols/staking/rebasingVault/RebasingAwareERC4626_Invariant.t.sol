// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IERC20Errors} from "@crane/contracts/tokens/ERC20/IERC20Errors.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {
    TestBase_RebasingAwareERC4626
} from "contracts/protocols/staking/rebasingVault/TestBase_RebasingAwareERC4626.sol";
import {IRebasingAwareERC4626} from "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";

/// @notice Independent two-vault ledger; expected values never come from production previews.
/// @dev Amounts and 100-step campaigns keep direct integer oracle products below uint256.
/// Full-width arithmetic is exercised separately with arbitrary-precision quote vectors.
contract RebasingAwareHandler is Test {
    uint256 private constant V = 1e10;
    IERC4626[2] public vaults;
    ERC20PermitMintableStub public asset;
    address[] public actors;
    address public recipient;
    address private manager;
    address private managerOwner;
    address private collector;
    uint256[2] public backing;
    uint256[2] public issued;
    mapping(uint256 => mapping(address => uint256)) public shares;
    mapping(address => uint256) public wallet;
    bool[2] public disabled;
    uint256[10] public attempts;
    uint256[10] public successes;
    uint256[10] public expectedReverts;
    uint256[10] public skips;
    uint256[3] public publicBurns;
    uint256 public rebases;
    uint256 public recoveries;
    uint256 public cycles;
    uint256 public negativeCalls;
    uint256 public feeUpdates;

    constructor(
        IERC4626 first,
        IERC4626 second,
        ERC20PermitMintableStub token,
        address[] memory holders,
        address receiver_,
        address manager_,
        address owner_,
        address collector_
    ) {
        vaults = [first, second];
        asset = token;
        actors = holders;
        recipient = receiver_;
        manager = manager_;
        managerOwner = owner_;
        collector = collector_;
        for (uint256 i; i < holders.length; ++i) {
            wallet[holders[i]] = token.balanceOf(holders[i]);
        }
        wallet[receiver_] = token.balanceOf(receiver_);
        wallet[collector_] = token.balanceOf(collector_);
    }

    /// @notice Exercise all ten ERC4626/SE/SY money routes, both vaults and public-share modes.
    function money(uint8 vaultSeed, uint8 routeSeed, uint8 actorSeed, uint96 amountSeed, bool prepaid) public {
        uint256 v = vaultSeed % 2;
        uint256 route = routeSeed % 10;
        address actor = actors[actorSeed % actors.length];
        attempts[route]++;
        uint256 amount;
        if (route < 5) {
            amount = bound(uint256(amountSeed), 1, 5e18);
            if (route == 1 || route == 3) amount *= V;
            if (disabled[v]) {
                vm.expectRevert(
                    abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, address(vaults[v]))
                );
                vm.prank(actor);
                _enter(v, route, actor, amount);
                expectedReverts[route]++;
                assertLedger();
                return;
            }
            uint256 cost = route == 1 || route == 3 ? _ceil(amount * (backing[v] + 1), issued[v] + V) : amount;
            if (cost > wallet[actor]) {
                skips[route]++;
                return;
            }
            uint256 mintShares = route == 1 || route == 3 ? amount : amount * (issued[v] + V) / (backing[v] + 1);
            if (mintShares == 0) {
                vm.expectRevert(IRebasingAwareERC4626.ZeroOperationOutput.selector);
                vm.prank(actor);
                _enter(v, route, actor, amount);
                expectedReverts[route]++;
                assertLedger();
                return;
            }
            _deposit(v, route, actor, amount, cost, mintShares);
        } else {
            uint256 owned = shares[v][actor];
            if (owned == 0) {
                skips[route]++;
                return;
            }
            uint256 available = route == 6 || route == 8 ? owned * (backing[v] + 1) / (issued[v] + V) : owned;
            if (available == 0) {
                skips[route]++;
                return;
            }
            amount = bound(uint256(amountSeed), 1, available);
            _withdraw(v, route, actor, amount, prepaid);
        }
        assertLedger();
    }

    function _deposit(uint256 v, uint256 route, address actor, uint256 amount, uint256 cost, uint256 minted) private {
        vm.prank(actor);
        uint256 actual = _enter(v, route, actor, amount);
        assertEq(actual, route == 1 || route == 3 ? cost : minted);
        backing[v] += cost;
        issued[v] += minted;
        shares[v][actor] += minted;
        wallet[actor] -= cost;
        successes[route]++;
    }

    function _enter(uint256 v, uint256 route, address actor, uint256 amount) private returns (uint256) {
        IERC4626 vault = vaults[v];
        if (route == 0) return vault.deposit(amount, actor);
        if (route == 1) return vault.mint(amount, actor);
        if (route == 2) {
            return IStandardExchangeIn(address(vault))
                .exchangeIn(IERC20(address(asset)), amount, IERC20(address(vault)), 0, actor, false, block.timestamp);
        }
        if (route == 3) {
            return IStandardExchangeOut(address(vault))
                .exchangeOut(
                    IERC20(address(asset)),
                    type(uint256).max,
                    IERC20(address(vault)),
                    amount,
                    actor,
                    false,
                    block.timestamp
                );
        }
        return IStandardizedYield(address(vault)).deposit(actor, address(asset), amount, 0);
    }

    function _withdraw(uint256 v, uint256 route, address actor, uint256 amount, bool prepaid) private {
        bool exactOut = route == 6 || route == 8;
        uint256 burned = exactOut ? _ceil(amount * (issued[v] + V), backing[v] + 1) : amount;
        uint256 paid = exactOut ? amount : amount * (backing[v] + 1) / (issued[v] + V);
        if (paid == 0) {
            vm.expectRevert(IRebasingAwareERC4626.ZeroOperationOutput.selector);
            vm.prank(actor);
            _exit(v, route, actor, amount, false);
            expectedReverts[route]++;
            return;
        }
        IERC20 share = IERC20(address(vaults[v]));
        bool internalShares = prepaid && route >= 7;
        if (internalShares) {
            uint256 prepayment = burned + (shares[v][actor] - burned) / 3;
            vm.prank(actor);
            share.transfer(address(share), prepayment);
            shares[v][actor] -= prepayment;
            shares[v][address(share)] += prepayment;
        }
        uint256 publicBefore = shares[v][address(share)];
        vm.prank(actor);
        uint256 actual = _exit(v, route, actor, amount, internalShares);
        assertEq(actual, exactOut ? burned : paid);
        if (internalShares) {
            shares[v][address(share)] -= burned;
            if (route != 9) {
                shares[v][actor] += publicBefore - burned;
                shares[v][address(share)] = 0;
            }
            publicBurns[route - 7]++;
        } else {
            shares[v][actor] -= burned;
        }
        issued[v] -= burned;
        backing[v] -= paid;
        wallet[recipient] += paid;
        successes[route]++;
    }

    function _exit(uint256 v, uint256 route, address actor, uint256 amount, bool prepaid) private returns (uint256) {
        IERC4626 vault = vaults[v];
        if (route == 5) return vault.redeem(amount, recipient, actor);
        if (route == 6) return vault.withdraw(amount, recipient, actor);
        if (route == 7) {
            return IStandardExchangeIn(address(vault))
                .exchangeIn(
                    IERC20(address(vault)), amount, IERC20(address(asset)), 0, recipient, prepaid, block.timestamp
                );
        }
        if (route == 8) {
            return IStandardExchangeOut(address(vault))
                .exchangeOut(
                    IERC20(address(vault)),
                    type(uint256).max,
                    IERC20(address(asset)),
                    amount,
                    recipient,
                    prepaid,
                    block.timestamp
                );
        }
        return IStandardizedYield(address(vault)).redeem(recipient, amount, address(asset), 0, prepaid);
    }

    /// @notice Donations are paid from an actor's wallet and never recorded as deposit credit.
    function donate(uint8 vaultSeed, uint8 actorSeed, uint96 amountSeed) public {
        uint256 v = vaultSeed % 2;
        address actor = actors[actorSeed % actors.length];
        if (wallet[actor] == 0) return;
        uint256 amount = bound(uint256(amountSeed), 1, wallet[actor] < 1e19 ? wallet[actor] : 1e19);
        vm.prank(actor);
        asset.transfer(address(vaults[v]), amount);
        wallet[actor] -= amount;
        backing[v] += amount;
        assertLedger();
    }

    /// @notice Settled gains/losses alter backing while static share ledgers remain unchanged.
    function rebase(uint8 vaultSeed, uint96 amountSeed, bool loss) public {
        uint256 v = vaultSeed % 2;
        if (loss && backing[v] < 4) return;
        uint256 amount = bound(uint256(amountSeed), 1, loss ? backing[v] / 4 : 1e19);
        if (loss) {
            asset.burn(address(vaults[v]), amount);
            backing[v] -= amount;
        } else {
            asset.mint(address(vaults[v]), amount);
            backing[v] += amount;
        }
        rebases++;
        assertLedger();
    }

    /// @notice Full reserve loss closes all entry routes until an external restoration.
    function lossAndRecovery(uint8 vaultSeed) public {
        uint256 v = vaultSeed % 2;
        if (issued[v] == 0 || backing[v] == 0 || disabled[v]) return;
        uint256 restore = backing[v];
        asset.burn(address(vaults[v]), restore);
        backing[v] = 0;
        assertEq(vaults[v].maxDeposit(actors[0]), 0);
        assertEq(vaults[v].maxMint(actors[0]), 0);
        for (uint256 r; r < 5; ++r) {
            vm.expectRevert(IRebasingAwareERC4626.ZeroReserveWithOutstandingShares.selector);
            vm.prank(actors[0]);
            _enter(v, r, actors[0], 1e18);
            expectedReverts[r]++;
        }
        assertLedger();
        asset.mint(address(vaults[v]), restore);
        backing[v] = restore;
        recoveries++;
        assertLedger();
    }

    /// @notice Transfer shares and spend a finite, explicit owner allowance for a third-party exit.
    function transferAndApprovedExit(uint8 vaultSeed, uint8 actorSeed, uint96 amountSeed) public {
        uint256 v = vaultSeed % 2;
        address from = actors[actorSeed % actors.length];
        address to = actors[(actorSeed % actors.length + 1) % actors.length];
        uint256 bal = shares[v][from];
        if (bal < 2) return;
        uint256 amount = bound(uint256(amountSeed), 1, bal / 2);
        IERC20 share = IERC20(address(vaults[v]));
        vm.prank(from);
        share.transfer(to, amount);
        shares[v][from] -= amount;
        shares[v][to] += amount;
        uint256 paid = amount * (backing[v] + 1) / (issued[v] + V);
        if (paid != 0) {
            vm.prank(to);
            share.approve(from, amount);
            vm.prank(from);
            assertEq(vaults[v].redeem(amount, recipient, to), paid);
            shares[v][to] -= amount;
            issued[v] -= amount;
            backing[v] -= paid;
            wallet[recipient] += paid;
            assertEq(share.allowance(to, from), 0);
        }
        assertLedger();
    }

    /// @notice Rejected flags, zero calls and unauthorized burns preserve every modeled balance.
    function invalidCalls(uint8 vaultSeed, uint8 actorSeed) public {
        uint256 v = vaultSeed % 2;
        address actor = actors[actorSeed % actors.length];
        IERC20 share = IERC20(address(vaults[v]));
        vm.expectRevert(IRebasingAwareERC4626.AssetPretransferNotSupported.selector);
        vm.prank(actor);
        IStandardExchangeIn(address(share))
            .exchangeIn(IERC20(address(asset)), 1, share, 0, actor, true, block.timestamp);
        vm.expectRevert(IRebasingAwareERC4626.AssetPretransferNotSupported.selector);
        vm.prank(actor);
        IStandardExchangeOut(address(share))
            .exchangeOut(IERC20(address(asset)), type(uint256).max, share, 1, actor, true, block.timestamp);
        vm.expectRevert(IRebasingAwareERC4626.ZeroOperationAmount.selector);
        vm.prank(actor);
        vaults[v].deposit(0, actor);
        uint256 burnAmount = shares[v][actor] / 2;
        if (burnAmount > 0 && burnAmount * (backing[v] + 1) / (issued[v] + V) != 0) {
            vm.expectRevert(
                abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(this), 0, burnAmount)
            );
            vaults[v].redeem(burnAmount, recipient, actor);
        }
        negativeCalls++;
        assertLedger();
    }

    /// @notice Disable/enable entry and vary fee policy without changing wrapper economics.
    function policy(uint8 vaultSeed, bool disable, uint96 feeSeed) public {
        uint256 v = vaultSeed % 2;
        vm.startPrank(managerOwner);
        IVaultRegistryDisableManager(manager).setVaultAddressDisabled(address(vaults[v]), disable);
        IVaultFeeOracleManager(manager).setUsageFeeOfVault(address(vaults[v]), bound(uint256(feeSeed), 1, 1e16));
        vm.stopPrank();
        disabled[v] = disable;
        feeUpdates++;
        assertLedger();
    }

    /// @notice A closed ERC4626 cycle includes its rounding loss and cannot extract existing holders' backing.
    function closedCycle(uint8 vaultSeed, uint8 actorSeed, uint96 amountSeed) public {
        uint256 v = vaultSeed % 2;
        address actor = actors[actorSeed % actors.length];
        if (disabled[v] || wallet[actor] == 0) return;
        uint256 amount = bound(uint256(amountSeed), 1, wallet[actor] < 1e18 ? wallet[actor] : 1e18);
        uint256 minted = amount * (issued[v] + V) / (backing[v] + 1);
        if (minted == 0) return;
        _deposit(v, 0, actor, amount, amount, minted);
        uint256 paid = minted * (backing[v] + 1) / (issued[v] + V);
        if (paid == 0) {
            assertLedger();
            return;
        }
        vm.prank(actor);
        assertEq(vaults[v].redeem(minted, actor, actor), paid);
        issued[v] -= minted;
        shares[v][actor] -= minted;
        backing[v] -= paid;
        wallet[actor] += paid;
        assertLe(paid, amount);
        cycles++;
        assertLedger();
    }

    /// @notice Check exact assets, shares, supply, custody and rates for both production proxies.
    function assertLedger() public view {
        for (uint256 v; v < 2; ++v) {
            IERC4626 vault = vaults[v];
            uint256 sum = shares[v][address(vault)];
            assertEq(IERC20(address(vault)).balanceOf(address(vault)), sum);
            for (uint256 a; a < actors.length; ++a) {
                address actor = actors[a];
                sum += shares[v][actor];
                assertEq(IERC20(address(vault)).balanceOf(actor), shares[v][actor]);
                assertEq(asset.balanceOf(actor), wallet[actor]);
            }
            assertEq(sum, issued[v]);
            assertEq(IERC20(address(vault)).totalSupply(), issued[v]);
            assertEq(asset.balanceOf(address(vault)), backing[v]);
            assertEq(vault.totalAssets(), backing[v]);
            assertEq(vault.asset(), address(asset));
            assertEq(IERC20Metadata(address(vault)).decimals(), 28);
            assertEq(vault.convertToAssets(issued[v]), issued[v] * (backing[v] + 1) / (issued[v] + V));
            assertLe(vault.convertToAssets(issued[v]), backing[v]);
            uint256 expectedRate = 1e18 * (backing[v] + 1) / (issued[v] + V);
            (bool ok, bytes memory data) =
                address(vault).staticcall(abi.encodeCall(IStandardizedYield.exchangeRate, ()));
            if (expectedRate == 0) {
                assertFalse(ok);
                assertEq(data, abi.encodeWithSelector(IRebasingAwareERC4626.SYExchangeRateUnderflow.selector));
            } else {
                assertTrue(ok);
                assertEq(abi.decode(data, (uint256)), expectedRate);
            }
            assertEq(IStandardVault(address(vault)).vaultFeeTypeIds(), bytes32(0));
            assertEq(IERC20(address(vault)).balanceOf(collector), 0);
            assertEq(IERC20(address(vault)).balanceOf(recipient), 0);
        }
        assertEq(asset.balanceOf(recipient), wallet[recipient]);
        assertEq(asset.balanceOf(collector), wallet[collector]);
    }

    function _ceil(uint256 n, uint256 d) private pure returns (uint256) {
        return n / d + (n % d == 0 ? 0 : 1);
    }
}

/// @notice Stateful production-proxy coverage for INV-01–15, with compulsory successful route bootstrap.
contract RebasingAwareERC4626_Invariant is TestBase_RebasingAwareERC4626 {
    RebasingAwareHandler internal handler;

    function setUp() public override {
        super.setUp();
        IERC4626 second = pkg.deployVault(IERC20Metadata(address(asset)), 10, bytes32(uint256(7)));
        address[] memory actors = new address[](4);
        actors[0] = alice;
        actors[1] = bob;
        actors[2] = makeAddr("charlie");
        actors[3] = attacker;
        asset.mint(actors[2], 1_000_000e18);
        for (uint256 a; a < actors.length; ++a) {
            vm.startPrank(actors[a]);
            asset.approve(address(vault), type(uint256).max);
            asset.approve(address(second), type(uint256).max);
            vm.stopPrank();
        }
        handler = new RebasingAwareHandler(
            vault, second, asset, actors, receiver, address(indexedexManager), owner, address(feeCollector)
        );
        for (uint8 v; v < 2; ++v) {
            for (uint8 a; a < 4; ++a) {
                handler.money(v, 0, a, 5e18, false);
            }
            for (uint8 r; r < 10; ++r) {
                handler.money(v, r, 0, 1e18, true);
            }
            handler.rebase(v, 1e18, false);
            handler.rebase(v, 1e18, true);
            handler.lossAndRecovery(v);
            handler.invalidCalls(v, 0);
            handler.closedCycle(v, 0, 1e18);
            handler.policy(v, false, 1e15);
        }
        bytes4[] memory selectors = new bytes4[](9);
        selectors[0] = handler.money.selector;
        selectors[1] = handler.donate.selector;
        selectors[2] = handler.rebase.selector;
        selectors[3] = handler.lossAndRecovery.selector;
        selectors[4] = handler.transferAndApprovedExit.selector;
        selectors[5] = handler.invalidCalls.selector;
        selectors[6] = handler.policy.selector;
        selectors[7] = handler.closedCycle.selector;
        selectors[8] = handler.money.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_INV01_through15_independentAccounting() public view {
        handler.assertLedger();
    }

    function afterInvariant() public view {
        for (uint256 r; r < 10; ++r) {
            assertGt(handler.successes(r), 0, "missing successful money route");
        }
        for (uint256 r; r < 3; ++r) {
            assertGt(handler.publicBurns(r), 0, "missing public-share route");
        }
        assertGt(handler.rebases(), 0);
        assertGt(handler.recoveries(), 0);
        assertGt(handler.cycles(), 0);
        assertGt(handler.negativeCalls(), 0);
        assertGt(handler.feeUpdates(), 0);
        handler.assertLedger();
    }
}
