// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {HermeticWeETH} from "contracts/protocols/staking/etherfi/test/hermetic/HermeticEtherFiPorts.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {TestBase_EtherFiWeETHStandardExchange} from "contracts/test/bases/TestBase_EtherFiWeETHStandardExchange.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";

contract EtherFiWeETHStandardExchange_NonUnitPretransfer is TestBase_EtherFiWeETHStandardExchange {
    HermeticWeETH internal wrapped;
    address internal vault;
    AtomicPretransferCaller internal integrator;

    function setUp() public override {
        super.setUp();
        wrapped = hermeticWeEth;
        wrapped.setRate(1.5 ether);
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);
        vault = seVault;
        vm.stopPrank();
        integrator = new AtomicPretransferCaller();
        _fund(IERC20(address(wrapped)), 2 ether);
        wrapped.approve(vault, 2 ether);
        uint256 issued = IStandardExchangeIn(vault)
            .exchangeIn(IERC20(address(wrapped)), 2 ether, IERC20(vault), 1, address(this), false, block.timestamp);
        assertEq(issued, 3 ether * 1000, "initial receipt value with package virtual offset");
    }

    function _fund(IERC20 token_, uint256 amount_) internal {
        if (address(token_) == address(wrapped)) {
            uint256 assets = Math.mulDiv(amount_, 1.5 ether, 1 ether, Math.Rounding.Ceil);
            hermeticEEth.mint(address(this), assets);
            hermeticEEth.approve(address(wrapped), assets);
            assertGe(wrapped.wrap(assets), amount_, "real receipt funding");
        } else {
            hermeticEEth.mint(address(this), amount_);
        }
    }

    function _required(IERC20 token_, uint256 desired_) internal view returns (uint256) {
        uint256 nav = wrapped.getEETHByWeETH(wrapped.balanceOf(vault));
        uint256 ethRequired = Math.mulDiv(desired_, nav + 1, IERC20(vault).totalSupply() + 1000, Math.Rounding.Ceil);
        uint256 receiptRequired = Math.mulDiv(ethRequired, 1 ether, 1.5 ether, Math.Rounding.Ceil);
        return address(token_) == address(wrapped)
            ? receiptRequired
            : Math.mulDiv(receiptRequired, 1.5 ether, 1 ether, Math.Rounding.Ceil);
    }

    function _mint(IERC20 token_, uint256 maximum_, uint256 desired_, bool prepaid_) internal returns (uint256) {
        _fund(token_, maximum_);
        if (!prepaid_) {
            token_.approve(vault, maximum_);
            return IStandardExchangeOut(vault)
                .exchangeOut(token_, maximum_, IERC20(vault), desired_, address(this), false, block.timestamp);
        }
        token_.approve(address(integrator), maximum_);
        bytes memory data = abi.encodeCall(
            IStandardExchangeOut.exchangeOut,
            (token_, maximum_, IERC20(vault), desired_, address(this), true, block.timestamp)
        );
        return abi.decode(integrator.consumePretransfer(token_, address(this), vault, maximum_, data), (uint256));
    }

    function _assertExactOut(IERC20 token_) internal {
        uint256 desired = 1001; // needs 2 wei ETH, whose floor wrapped inverse would underfund by one wei.
        uint256 expected = _required(token_, desired);
        assertGt(expected, 0);
        assertEq(
            IStandardExchangeOut(vault).previewExchangeOut(token_, IERC20(vault), desired),
            expected,
            "independent ceil inverse"
        );
        uint256 snapshot = vm.snapshotState();
        assertEq(_mint(token_, expected, desired, false), expected, "funded pull accepts exact quote");
        assertTrue(vm.revertToState(snapshot));
        uint256 beforeShares = IERC20(vault).balanceOf(address(this));
        uint256 maximum = expected + 7;
        assertEq(_mint(token_, maximum, desired, true), expected, "atomic quote matches prior pull");
        assertEq(IERC20(vault).balanceOf(address(this)) - beforeShares, desired, "only exact shares issued");
        assertEq(token_.balanceOf(address(integrator)), maximum - expected, "only bounded unused credit refunded");
    }

    function test_APEX_nonUnitWrappedExactOutCeilAndPretransfer() public {
        _assertExactOut(IERC20(address(wrapped)));
    }

    function test_APEX_nonUnitUnderlyingWrapExactOutCeilAndPretransfer() public {
        // Fund before quoting: a native deposit itself changes the global share ratio.
        hermeticEEth.mint(address(this), 30);
        hermeticEEth.approve(vault, 30);
        hermeticEEth.approve(address(integrator), 30);
        uint256 desired = 1001;
        uint256 required = _required(IERC20(address(hermeticEEth)), desired);
        assertEq(required, 3, "2 wrapped shares need3 nominal eETH at the native rate");
        assertEq(
            IStandardExchangeOut(vault).previewExchangeOut(IERC20(address(hermeticEEth)), IERC20(vault), desired),
            required
        );
        uint256 snapshot = vm.snapshotState();
        assertEq(
            IStandardExchangeOut(vault)
                .exchangeOut(
                    IERC20(address(hermeticEEth)),
                    required,
                    IERC20(vault),
                    desired,
                    address(this),
                    false,
                    block.timestamp
                ),
            required
        );
        assertTrue(vm.revertToState(snapshot));
        uint256 beforeShares = IERC20(vault).balanceOf(address(this));
        uint256 maximum = 13;
        uint256 paid = abi.decode(
            integrator.consumePretransfer(
                IERC20(address(hermeticEEth)),
                address(this),
                vault,
                15,
                abi.encodeCall(
                    IStandardExchangeOut.exchangeOut,
                    (
                        IERC20(address(hermeticEEth)),
                        maximum,
                        IERC20(vault),
                        desired,
                        address(this),
                        true,
                        block.timestamp
                    )
                )
            ),
            (uint256)
        );
        assertEq(paid, required, "prepaid native credit wraps the required shares");
        assertEq(IERC20(vault).balanceOf(address(this)) - beforeShares, desired);
        uint256 returnedNativeShares = hermeticEEth.balanceToShares(maximum - required);
        assertEq(
            hermeticEEth.shares(address(integrator)),
            returnedNativeShares,
            "refund transfers floor native shares of bounded surplus"
        );
        assertEq(hermeticEEth.balanceOf(address(integrator)), hermeticEEth.sharesToBalance(returnedNativeShares));
        assertEq(
            hermeticEEth.shares(vault),
            hermeticEEth.balanceToShares(15) - wrapped.getWeETHByeETH(required) - returnedNativeShares,
            "excess delivery and unrepresentable refund remain held"
        );
    }

    function _exactIn(IERC20 token_, uint256 amount_, uint256 minimum_, bool prepaid_) internal returns (uint256) {
        _fund(token_, amount_);
        if (!prepaid_) {
            token_.approve(vault, amount_);
            return IStandardExchangeIn(vault)
                .exchangeIn(token_, amount_, IERC20(vault), minimum_, address(this), false, block.timestamp);
        }
        token_.approve(address(integrator), amount_);
        bytes memory data = abi.encodeCall(
            IStandardExchangeIn.exchangeIn,
            (token_, amount_, IERC20(vault), minimum_, address(this), true, block.timestamp)
        );
        return abi.decode(integrator.consumePretransfer(token_, address(this), vault, amount_, data), (uint256));
    }

    function _assertExactIn(IERC20 token_, uint256 amount_, uint256 credited_) internal {
        uint256 expected = Math.mulDiv(
            credited_, IERC20(vault).totalSupply() + 1000, wrapped.getEETHByWeETH(wrapped.balanceOf(vault)) + 1
        );
        uint256 quote = IStandardExchangeIn(vault).previewExchangeIn(token_, amount_, IERC20(vault));
        uint256 snapshot = vm.snapshotState();
        assertEq(_exactIn(token_, amount_, expected, false), expected, "funded pull credits native wrapped value");
        assertTrue(vm.revertToState(snapshot));
        assertEq(quote, expected, "exact-in preview normalizes wrap floor");
        uint256 beforeShares = IERC20(vault).balanceOf(address(this));
        assertEq(_exactIn(token_, amount_, quote, true), quote, "prior exact-in quote survives atomic delivery");
        assertEq(IERC20(vault).balanceOf(address(this)) - beforeShares, quote, "exact-in recipient issuance");
        assertEq(token_.balanceOf(address(integrator)), 0, "exact-in never refunds residual credit");
    }

    function test_APEX_nonUnitUnderlyingExactInPreviewAndPretransfer() public {
        hermeticEEth.mint(address(this), 30);
        hermeticEEth.approve(vault, 30);
        hermeticEEth.approve(address(integrator), 30);
        uint256 nominal = 11;
        uint256 delivered = hermeticEEth.sharesToBalance(hermeticEEth.balanceToShares(nominal));
        uint256 credited = wrapped.getEETHByWeETH(wrapped.getWeETHByeETH(delivered));
        assertEq(delivered, 10, "native input transfer floor");
        assertEq(credited, 9, "wrap credits retained native value");
        uint256 expected = Math.mulDiv(
            credited, IERC20(vault).totalSupply() + 1000, wrapped.getEETHByWeETH(wrapped.balanceOf(vault)) + 1
        );
        assertEq(
            IStandardExchangeIn(vault).previewExchangeIn(IERC20(address(hermeticEEth)), nominal, IERC20(vault)),
            expected
        );
        uint256 snapshot = vm.snapshotState();
        assertEq(
            IStandardExchangeIn(vault)
                .exchangeIn(
                    IERC20(address(hermeticEEth)),
                    nominal,
                    IERC20(vault),
                    expected,
                    address(this),
                    false,
                    block.timestamp
                ),
            expected
        );
        assertTrue(vm.revertToState(snapshot));
        uint256 beforeShares = IERC20(vault).balanceOf(address(this));
        uint256 minted = abi.decode(
            integrator.consumePretransfer(
                IERC20(address(hermeticEEth)),
                address(this),
                vault,
                nominal,
                abi.encodeCall(
                    IStandardExchangeIn.exchangeIn,
                    (
                        IERC20(address(hermeticEEth)),
                        delivered,
                        IERC20(vault),
                        expected,
                        address(this),
                        true,
                        block.timestamp
                    )
                )
            ),
            (uint256)
        );
        assertEq(minted, expected, "prepaid execution consumes actually delivered credit");
        assertEq(IERC20(vault).balanceOf(address(this)) - beforeShares, expected);
        assertEq(hermeticEEth.balanceOf(address(integrator)), 0, "exact input does not refund");
        assertEq(
            hermeticEEth.shares(vault),
            hermeticEEth.balanceToShares(nominal) - wrapped.getWeETHByeETH(delivered),
            "native wrapping remainder remains held"
        );
    }

    function test_APEX_nonUnitWrappedExactInPreviewAndPretransfer() public {
        _assertExactIn(IERC20(address(wrapped)), 2, 3);
    }
}
