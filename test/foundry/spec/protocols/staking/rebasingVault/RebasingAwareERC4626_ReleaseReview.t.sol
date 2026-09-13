// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IERC165} from "@crane/contracts/introspection/ERC165/IERC165.sol";
import {IReentrancyLock} from "@crane/contracts/interfaces/IReentrancyLock.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {
    TestBase_RebasingAwareERC4626
} from "contracts/protocols/staking/rebasingVault/TestBase_RebasingAwareERC4626.sol";
import {IRebasingAwareERC4626} from "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626.sol";
import {IRebasingAwareERC4626DFPkg} from "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626DFPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IBasicVault} from "contracts/vaults/basic/IBasicVault.sol";
import {
    IStandardExchangeTransitionQuote,
    IStandardExchangeExternalQuote,
    IStandardExchangeRateQuote
} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {ReentrantERC20Harness} from "contracts/test/stubs/ReentrantERC20Harness.sol";

/// @notice Production-proxy regressions discovered during the release review.
contract RebasingAwareERC4626_ReleaseReview is TestBase_RebasingAwareERC4626 {
    address private observedVault;
    bytes private observedCall;
    bool private observedLock;
    uint256 private nestedChecks;

    /// @notice Indexers receive one canonical ERC4626 event and the additional SY event only on SY routes.
    function test_API02_eventsAcrossEveryMoneyRoute() public {
        observedVault = address(vault);
        vm.prank(alice);
        vault.deposit(20e18, alice);
        for (uint256 route; route < 10; ++route) {
            vm.recordLogs();
            vm.prank(alice);
            (bool ok,) = address(vault).call(_moneyCall(route, address(asset)));
            assertTrue(ok);
            Vm.Log[] memory logs = vm.getRecordedLogs();
            uint256 canonicalCount;
            uint256 syCount;
            bytes32 canonical = route < 5 ? keccak256("Deposit(address,address,uint256,uint256)")
                : keccak256("Withdraw(address,address,address,uint256,uint256)");
            bytes32 sy = route < 5 ? keccak256("Deposit(address,address,address,uint256,uint256)")
                : keccak256("Redeem(address,address,address,uint256,uint256)");
            for (uint256 i; i < logs.length; ++i) {
                if (logs[i].emitter != address(vault)) continue;
                if (logs[i].topics[0] == canonical) {
                    canonicalCount++;
                    assertEq(logs[i].topics[1], bytes32(uint256(uint160(alice))));
                    assertEq(logs[i].topics[2], bytes32(uint256(uint160(alice))));
                    if (route >= 5) assertEq(logs[i].topics[3], bytes32(uint256(uint160(alice))));
                    assertEq(logs[i].data, abi.encode(uint256(1e18), uint256(1e28)));
                }
                if (logs[i].topics[0] == sy) {
                    syCount++;
                    assertEq(logs[i].topics[1], bytes32(uint256(uint160(alice))));
                    assertEq(logs[i].topics[2], bytes32(uint256(uint160(alice))));
                    assertEq(logs[i].topics[3], bytes32(uint256(uint160(address(asset)))));
                    assertEq(logs[i].data, route < 5 ? abi.encode(uint256(1e18), uint256(1e28))
                        : abi.encode(uint256(1e28), uint256(1e18)));
                }
            }
            assertEq(canonicalCount, 1);
            assertEq(syCount, route == 4 || route == 9 ? 1 : 0);
        }
    }

    /// @notice Every share-issuing interface rejects a zero recipient before charging the payer.
    function test_ADV07_zeroShareReceiverRejectedAcrossInterfaces() public {
        for (uint256 route; route < 5; ++route) {
            uint256 beforeAssets = asset.balanceOf(alice);
            vm.prank(alice);
            vm.expectRevert(abi.encodeWithSelector(IRebasingAwareERC4626.InvalidReceiver.selector, address(0)));
            _enter(route, address(0));
            assertEq(asset.balanceOf(alice), beforeAssets);
            assertEq(vault.totalAssets(), 0);
            assertEq(IERC20(address(vault)).totalSupply(), 0);
            assertEq(IERC20(address(vault)).balanceOf(address(0)), 0);
        }
    }

    /// @notice The wrapper itself remains a permitted share recipient for atomic internal redemption.
    function test_API12_vaultShareReceiverRemainsSupported() public {
        for (uint256 route; route < 5; ++route) {
            vm.prank(alice);
            _enter(route, address(vault));
            uint256 shares = IERC20(address(vault)).balanceOf(address(vault));
            assertGt(shares, 0);
            vm.prank(alice);
            IStandardizedYield(address(vault)).redeem(alice, shares, address(asset), 1, true);
            assertEq(IERC20(address(vault)).balanceOf(address(vault)), 0);
        }
    }

    /// @notice Receiver validation has the specified precedence over deadline and pretransfer errors.
    function test_API07_receiverValidationPrecedesDeadlineAndPretransfer() public {
        vm.warp(10);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IRebasingAwareERC4626.InvalidReceiver.selector, address(0)));
        IStandardExchangeIn(address(vault))
            .exchangeIn(IERC20(address(asset)), 1e18, IERC20(address(vault)), 0, address(0), true, 1);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IRebasingAwareERC4626.InvalidReceiver.selector, address(vault)));
        IStandardExchangeOut(address(vault))
            .exchangeOut(IERC20(address(vault)), 1e28, IERC20(address(asset)), 1e18, address(vault), true, 1);
    }

    /// @notice Direct registry deployment cannot bypass the helper's contract-asset validation.
    function test_PKG03_registryRejectsCodelessAsset() public {
        address noCode = makeAddr("not-an-asset-contract");
        IRebasingAwareERC4626DFPkg.PkgArgs memory args = IRebasingAwareERC4626DFPkg.PkgArgs({
            asset: IERC20Metadata(noCode),
            name: "Wrapped invalid",
            symbol: "wINVALID",
            decimalOffset: 10,
            optionalSalt: bytes32(0)
        });
        vm.expectRevert(abi.encodeWithSelector(IRebasingAwareERC4626.MissingDependency.selector, noCode));
        vm.prank(owner);
        IVaultRegistryDeployment(address(indexedexManager))
            .deployVault(IStandardVaultPkg(address(pkg)), abi.encode(args));
    }

    /// @notice The deployed proxy advertises the rate-quote interface installed by its quote facet.
    function test_PKG02_rateQuoteInterfaceAdvertised() public view {
        assertTrue(IERC165(address(vault)).supportsInterface(type(IStandardExchangeRateQuote).interfaceId));
    }

    /// @notice A token callback cannot observe backing between asset delivery and share issuance.
    function test_C3_liveReserveViewsRejectCallbackReads() public {
        ReentrantERC20Harness token = new ReentrantERC20Harness("Callback", "CB", 18);
        IERC4626 wrapped = pkg.deployVault(IERC20Metadata(address(token)));
        observedVault = address(wrapped);
        token.mint(alice, 10e18);
        vm.prank(alice);
        token.approve(address(wrapped), type(uint256).max);
        token.setReenter(address(this), abi.encodeCall(this.observeReserveRead, ()));
        bytes[3] memory calls = [
            abi.encodeCall(IERC4626.totalAssets, ()),
            abi.encodeCall(IBasicVault.reserves, ()),
            abi.encodeCall(IBasicVault.reserveOfToken, (address(token)))
        ];
        for (uint256 i; i < calls.length; ++i) {
            observedCall = calls[i];
            observedLock = false;
            vm.prank(alice);
            wrapped.deposit(1e18, alice);
            assertTrue(observedLock);
            assertEq(wrapped.totalAssets(), (i + 1) * 1e18);
            assertEq(wrapped.previewRedeem(1e28), 1e18);
        }
    }

    /// @notice Callback assertion runs inside the real token's transferFrom, against the production vault.
    function observeReserveRead() external {
        (bool ok, bytes memory reason) = observedVault.staticcall(observedCall);
        assertFalse(ok, "reserve read exposed unsettled backing");
        assertEq(reason, abi.encodeWithSelector(IReentrancyLock.IsLocked.selector));
        observedLock = true;
    }

    /// @notice All ten execution doors share one lock, during both incoming and outgoing transfers.
    function test_ADV03_allMoneyRoutesRejectCrossFacetReentrancy() public {
        ReentrantERC20Harness token = new ReentrantERC20Harness("Callback", "CB", 18);
        IERC4626 wrapped = pkg.deployVault(IERC20Metadata(address(token)));
        observedVault = address(wrapped);
        token.mint(alice, 100e18);
        vm.startPrank(alice);
        token.approve(address(wrapped), type(uint256).max);
        wrapped.deposit(20e18, alice);
        vm.stopPrank();
        token.setCallbackOnTransfer(true);
        token.setReenter(address(this), abi.encodeCall(this.probeAllMoneyDoors, ()));
        for (uint256 route; route < 10; ++route) {
            vm.prank(alice);
            (bool ok, bytes memory result) = address(wrapped).call(_moneyCall(route, address(token)));
            assertTrue(ok, "outer operation failed");
            assertGt(abi.decode(result, (uint256)), 0);
            assertEq(nestedChecks, (route + 1) * 10);
            assertEq(wrapped.totalAssets(), token.balanceOf(address(wrapped)));
        }
    }

    function probeAllMoneyDoors() external {
        address token = IERC4626(observedVault).asset();
        for (uint256 route; route < 10; ++route) {
            (bool ok, bytes memory reason) = observedVault.call(_moneyCall(route, token));
            assertFalse(ok);
            assertEq(reason, abi.encodeWithSelector(IReentrancyLock.IsLocked.selector));
            nestedChecks++;
        }
    }

    function _moneyCall(uint256 route, address token) private view returns (bytes memory) {
        IERC20 a = IERC20(token);
        IERC20 s = IERC20(observedVault);
        if (route == 0) return abi.encodeCall(IERC4626.deposit, (1e18, alice));
        if (route == 1) return abi.encodeCall(IERC4626.mint, (1e28, alice));
        if (route == 2) {
            return abi.encodeCall(IStandardExchangeIn.exchangeIn, (a, 1e18, s, 0, alice, false, block.timestamp));
        }
        if (route == 3) {
            return abi.encodeCall(IStandardExchangeOut.exchangeOut, (a, 1e18, s, 1e28, alice, false, block.timestamp));
        }
        if (route == 4) return abi.encodeCall(IStandardizedYield.deposit, (alice, token, 1e18, 0));
        if (route == 5) return abi.encodeCall(IERC4626.redeem, (1e28, alice, alice));
        if (route == 6) return abi.encodeCall(IERC4626.withdraw, (1e18, alice, alice));
        if (route == 7) {
            return abi.encodeCall(IStandardExchangeIn.exchangeIn, (s, 1e28, a, 0, alice, false, block.timestamp));
        }
        if (route == 8) {
            return abi.encodeCall(IStandardExchangeOut.exchangeOut, (s, 1e28, a, 1e18, alice, false, block.timestamp));
        }
        return abi.encodeCall(IStandardizedYield.redeem, (alice, 1e28, token, 0, false));
    }

    /// @notice Impossible asset additions produce the documented custom error, rather than an arithmetic panic.
    function test_API17_projectedAssetOverflowHasExplicitError() public {
        IRebasingAwareERC4626.QuoteState memory state = _quoteBook();
        state.assets = type(uint256).max - 1;
        vm.expectRevert(IRebasingAwareERC4626.NumericDomainExceeded.selector);
        IStandardExchangeTransitionQuote(address(vault))
            .quoteTransition(abi.encode(state), IStandardExchangeTransitionQuote.Operation.DepositExactIn, 2);
        vm.expectRevert(IRebasingAwareERC4626.NumericDomainExceeded.selector);
        IStandardExchangeExternalQuote(address(vault)).quoteExternalDeposit(abi.encode(state), address(asset), 2);
    }

    /// @notice Fabricated share receipts cannot overflow their projected holder balance.
    function test_API17_projectedShareReceiptOverflowHasExplicitError() public {
        IRebasingAwareERC4626.QuoteState memory state = _quoteBook();
        state.supply = 100;
        state.holderShares = 90;
        vm.expectRevert(IStandardExchangeTransitionQuote.InvalidQuoteState.selector);
        IStandardExchangeTransitionQuote(address(vault))
            .quoteTransition(
                abi.encode(state), IStandardExchangeTransitionQuote.Operation.ReceiveShares, type(uint256).max
            );
    }

    /// @notice Python big integers check the real quote facet, including 512-bit intermediates.
    function test_ACC03_productionQuotesMatchAllPythonVectors() public {
        string memory raw = vm.readFile("test/foundry/spec/protocols/staking/rebasingVault/oracle/vectors.json");
        IStandardExchangeTransitionQuote quote = IStandardExchangeTransitionQuote(address(vault));
        for (uint256 i; i < 8; ++i) {
            string memory path = string.concat("$[", vm.toString(i), "]");
            IRebasingAwareERC4626.QuoteState memory state = _quoteBook();
            state.assets = _vector(raw, path, ".A");
            state.supply = _vector(raw, path, ".S");
            state.holderShares = state.supply;
            bytes memory encoded = abi.encode(state);
            uint256 amount = _vector(raw, path, ".x");
            assertEq(quote.quoteAssets(encoded, amount), _vector(raw, path, ".redeemAssets"));
            uint256 rate = _vector(raw, path, ".wadRate");
            if (rate == 0) {
                vm.expectRevert(IRebasingAwareERC4626.SYExchangeRateUnderflow.selector);
                IStandardExchangeRateQuote(address(vault)).quoteRate(address(vault), address(asset), encoded);
            } else {
                assertEq(
                    IStandardExchangeRateQuote(address(vault)).quoteRate(address(vault), address(asset), encoded), rate
                );
            }
            uint256 minted = _vector(raw, path, ".depositShares");
            {
                (bytes memory next, uint256 paid, uint256 received,) =
                    quote.quoteTransition(encoded, IStandardExchangeTransitionQuote.Operation.DepositExactIn, amount);
                assertEq(paid, amount);
                assertEq(received, minted);
                IRebasingAwareERC4626.QuoteState memory projected = abi.decode(next, (IRebasingAwareERC4626.QuoteState));
                assertEq(projected.assets, state.assets + amount);
                assertEq(projected.supply, state.supply + minted);
            }
            uint256 burned = _vector(raw, path, ".withdrawShares");
            if (amount <= state.assets && burned <= state.supply) {
                (, uint256 used, uint256 received,) =
                    quote.quoteTransition(encoded, IStandardExchangeTransitionQuote.Operation.WithdrawExactOut, amount);
                assertEq(used, burned);
                assertEq(received, amount);
            }
        }
    }

    function _vector(string memory raw, string memory path, string memory field) private view returns (uint256) {
        return vm.parseUint(vm.parseJsonString(raw, string.concat(path, field)));
    }

    function _quoteBook() private view returns (IRebasingAwareERC4626.QuoteState memory) {
        return IRebasingAwareERC4626.QuoteState({
            version: 1,
            chainId: block.chainid,
            exchange: address(vault),
            asset: address(asset),
            holder: alice,
            assets: 0,
            supply: 0,
            holderShares: 0,
            decimalOffset: 10
        });
    }

    function _enter(uint256 route, address recipient) private {
        if (route == 0) {
            vault.deposit(1e18, recipient);
        } else if (route == 1) {
            vault.mint(1e28, recipient);
        } else if (route == 2) {
            IStandardExchangeIn(address(vault))
                .exchangeIn(IERC20(address(asset)), 1e18, IERC20(address(vault)), 0, recipient, false, block.timestamp);
        } else if (route == 3) {
            IStandardExchangeOut(address(vault))
                .exchangeOut(
                    IERC20(address(asset)), 1e18, IERC20(address(vault)), 1e28, recipient, false, block.timestamp
                );
        } else {
            IStandardizedYield(address(vault)).deposit(recipient, address(asset), 1e18, 0);
        }
    }
}
