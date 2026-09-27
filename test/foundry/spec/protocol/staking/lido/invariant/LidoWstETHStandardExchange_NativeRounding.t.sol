// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {WstETH} from "@crane/contracts/external/lido/WstETH.sol";
import {IStETH as IPortStETH} from "@crane/contracts/external/lido/IStETH.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeTransitionQuote, IStandardExchangeExternalQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {TestBase_LidoWstETHStandardExchange} from "contracts/test/bases/TestBase_LidoWstETHStandardExchange.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";

/// @dev External dependency port of vendored Lido0.4.24/StETH.sol balanceOf,
/// getSharesByPooledEth, getPooledEthByShares, _transfer and transferFrom.
/// Solidity0.4.24 cannot be inherited by the production0.8.x suite. All custody
/// is real shares, including transfer rounding; WstETH below is the vendored port.
contract NativeRoundingStETH {
    string public constant name = "Native rounding stETH";
    string public constant symbol = "stETH";
    uint8 public constant decimals = 18;
    mapping(address => uint256) public sharesOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 internal internalShares;
    uint256 internal internalPooled;
    function getTotalShares() public view virtual returns (uint256) { return internalShares; }
    function getTotalPooledEther() public view virtual returns (uint256) { return internalPooled; }
    bool public shortDelivery;

    function mintShares(address to, uint256 shares) external {
        require(shares % 2 == 0, "exact 3/2 funding");
        sharesOf[to] += shares;
        internalShares += shares;
        internalPooled += shares * 3 / 2;
    }

    function getSharesByPooledEth(uint256 assets) public view returns (uint256) {
        return Math.mulDiv(assets, internalShares, internalPooled);
    }

    function getPooledEthByShares(uint256 shares) public view returns (uint256) {
        return Math.mulDiv(shares, internalPooled, internalShares);
    }

    function balanceOf(address holder) public view returns (uint256) {
        return getPooledEthByShares(sharesOf[holder]);
    }

    function totalSupply() external view returns (uint256) {
        return getTotalPooledEther();
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 approved = allowance[from][msg.sender];
        require(approved >= amount, "allowance");
        if (approved != type(uint256).max) allowance[from][msg.sender] = approved - amount;
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        uint256 moved = getSharesByPooledEth(amount);
        sharesOf[from] -= moved;
        if (shortDelivery && moved > 0) {
            sharesOf[to] += moved - 1;
            sharesOf[address(0xfee)] += 1;
        } else {
            sharesOf[to] += moved;
        }
    }

    function setShortDelivery(bool enabled) external {
        shortDelivery = enabled;
    }

    function setPooledEther(uint256 pooled) external {
        internalPooled = pooled;
    }

    function isStakingPaused() external pure returns (bool) {
        return false;
    }

    function getCurrentStakeLimit() external pure returns (uint256) {
        return type(uint256).max;
    }

    function submit(address) external payable returns (uint256 shares) {
        shares = getSharesByPooledEth(msg.value);
        sharesOf[msg.sender] += shares;
        internalShares += shares;
        internalPooled += msg.value;
    }
}

/// @dev Native Lido.sol:1058-1085 separates externally backed shares. The
/// canonical conversion denominator/numerator remain internal shares/ether.
contract ExternalSharesNativeStETH is NativeRoundingStETH {
    uint256 public getExternalShares;
    bool public failExternalEther;
    error NativeRateFailure(uint256 detail);
    function mintExternalShares(uint256 amount) external {
        getExternalShares += amount;
        sharesOf[address(0xe57)] += amount;
    }
    function setExternalEtherFailure(bool enabled) external { failExternalEther = enabled; }
    function getExternalEther() public view returns (uint256) {
        if (failExternalEther) revert NativeRateFailure(7);
        return Math.mulDiv(getExternalShares, internalPooled, internalShares);
    }
    function getTotalShares() public view override returns (uint256) { return internalShares + getExternalShares; }
    function getTotalPooledEther() public view override returns (uint256) { return internalPooled + Math.mulDiv(getExternalShares, internalPooled, internalShares); }
}

interface INativeLidoExchange {
    function exchangeInEth(IERC20 output, uint256 minimum, address recipient, uint256 deadline)
        external
        payable
        returns (uint256);
}

contract LidoWstETHStandardExchange_NativeRounding is TestBase_LidoWstETHStandardExchange {
    NativeRoundingStETH internal nativeSt;
    WstETH internal nativeWst;
    address internal vault;
    AtomicPretransferCaller internal integrator;
    address internal recipient = address(0x12345);

    function setUp() public override {
        super.setUp();
        _resetNativePort(new NativeRoundingStETH());
    }

    function _resetNativePort(NativeRoundingStETH port) internal {
        nativeSt = port;
        nativeSt.mintShares(address(this), 1_000_000 ether);
        nativeWst = new WstETH(IPortStETH(address(nativeSt)));
        nativeSt.approve(address(nativeWst), type(uint256).max);
        nativeWst.wrap(60 ether);
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);
        vault =
            lidoSeDFPkg.deployVault(
            address(nativeSt), address(nativeWst), address(hermeticWeth), address(hermeticQueue)
        );
        vm.stopPrank();
        integrator = new AtomicPretransferCaller();
        nativeSt.approve(vault, type(uint256).max);
        nativeWst.approve(vault, type(uint256).max);
        _dealWeth(address(this), 3 ether);
        hermeticWeth.approve(vault, 3 ether);
        IStandardExchangeIn(vault)
            .exchangeIn(
                IERC20(address(hermeticWeth)),
                3 ether,
                IERC20(vault),
                3 ether * 1000,
                address(this),
                false,
                block.timestamp
            );
    }

    function _state() internal view returns (bytes32 state) {
        address[5] memory holders = [address(this), vault, recipient, address(integrator), address(nativeWst)];
        IERC20[4] memory tokens =
            [IERC20(address(nativeSt)), IERC20(address(nativeWst)), IERC20(address(hermeticWeth)), IERC20(vault)];
        bytes32 reserveSlot = bytes32(uint256(keccak256(abi.encode("indexedex.vaults.basic"))) + 2);
        for (uint256 i; i < tokens.length; ++i) {
            state = keccak256(
                abi.encode(
                    state,
                    tokens[i].totalSupply(),
                    vm.load(vault, keccak256(abi.encode(address(tokens[i]), reserveSlot)))
                )
            );
            for (uint256 j; j < holders.length; ++j) {
                state =
                    keccak256(
                    abi.encode(state, tokens[i].balanceOf(holders[j]), tokens[i].allowance(holders[j], vault))
                );
            }
        }
        for (uint256 j; j < holders.length; ++j) {
            state = keccak256(abi.encode(state, nativeSt.sharesOf(holders[j])));
        }
        state = keccak256(
            abi.encode(
                state,
                nativeSt.getTotalPooledEther(),
                nativeSt.getTotalShares(),
                nativeSt.allowance(vault, address(nativeWst))
            )
        );
    }

    function _in(IERC20 input, uint256 amount, IERC20 output, uint256 minimum) internal returns (uint256) {
        return IStandardExchangeIn(vault).exchangeIn(input, amount, output, minimum, recipient, false, block.timestamp);
    }

    function test_APEX_nativeStEth_exactInMint_creditsWrappedDelivery() public {
        uint256 quote = IStandardExchangeIn(vault).previewExchangeIn(IERC20(address(nativeSt)), 11, IERC20(vault));
        assertEq(quote, 9000, "11 nominal delivers10, wraps6, credits9");
        assertEq(_in(IERC20(address(nativeSt)), 11, IERC20(vault), quote), quote);
        assertEq(nativeWst.balanceOf(vault), 6);
        assertEq(nativeSt.sharesOf(vault), 1);
    }

    function test_APEX_nativeStEth_exactOutMint_invertsBothFloors() public {
        uint256 quote = IStandardExchangeOut(vault).previewExchangeOut(IERC20(address(nativeSt)), IERC20(vault), 10000);
        assertEq(quote, 12, "fund incoming and wrapping floors");
        uint256 paid = IStandardExchangeOut(vault)
            .exchangeOut(IERC20(address(nativeSt)), quote, IERC20(vault), 10000, recipient, false, block.timestamp);
        assertEq(paid, 12);
        assertEq(IERC20(vault).balanceOf(recipient), 10000);
        assertEq(nativeWst.balanceOf(vault), 8);
    }

    function test_APEX_nativeStEth_exactInWrap_matchesRecipient() public {
        uint256 quote =
            IStandardExchangeIn(vault).previewExchangeIn(IERC20(address(nativeSt)), 11, IERC20(address(nativeWst)));
        assertEq(quote, 6);
        assertEq(_in(IERC20(address(nativeSt)), 11, IERC20(address(nativeWst)), quote), 6);
        assertEq(nativeWst.balanceOf(recipient), 6);
    }

    function test_APEX_nativeStEth_exactInWeth_conservesWrappedValue() public {
        assertEq(_in(IERC20(address(nativeSt)), 11, IERC20(address(hermeticWeth)), 9), 9);
        assertEq(hermeticWeth.balanceOf(recipient), 9);
        assertEq(nativeWst.balanceOf(vault), 6);
        assertEq(hermeticWeth.balanceOf(vault) + nativeWst.getStETHByWstETH(nativeWst.balanceOf(vault)), 3 ether);
    }

    function test_APEX_nativeStEth_exactInUnwrap_checksActualRecipient() public {
        uint256 quote =
            IStandardExchangeIn(vault).previewExchangeIn(IERC20(address(nativeWst)), 7, IERC20(address(nativeSt)));
        assertEq(quote, 9, "unwrap transfers6 shares, final transfer delivers9");
        assertEq(_in(IERC20(address(nativeWst)), 7, IERC20(address(nativeSt)), quote), 9);
        assertEq(nativeSt.balanceOf(recipient), 9);
    }

    function test_APEX_nativeStEth_exactOutUnwrap_fundsActualRecipient() public {
        uint256 quote =
            IStandardExchangeOut(vault).previewExchangeOut(IERC20(address(nativeWst)), IERC20(address(nativeSt)), 10);
        assertEq(quote, 8);
        uint256 paid = IStandardExchangeOut(vault)
            .exchangeOut(
                IERC20(address(nativeWst)), quote, IERC20(address(nativeSt)), 10, recipient, false, block.timestamp
            );
        assertEq(paid, 8);
        assertGe(nativeSt.balanceOf(recipient), 10);
    }

    function test_APEX_nativeStEth_minOutput_rejectsRoundedShortDelivery() public {
        uint256 beforeShares = nativeSt.sharesOf(address(nativeWst));
        bytes32 beforeState = _state();
        vm.expectRevert(bytes4(keccak256("Slippage()")));
        _in(IERC20(address(nativeWst)), 7, IERC20(address(nativeSt)), 10);
        assertEq(_state(), beforeState, "full failed-route rollback");
        assertEq(nativeSt.sharesOf(address(nativeWst)), beforeShares);
        assertEq(nativeSt.balanceOf(recipient), 0);
        assertEq(_in(IERC20(address(nativeWst)), 7, IERC20(address(nativeSt)), 9), 9);
    }

    function test_APEX_nativeStEth_shortShareDelivery_stillRejects() public {
        uint256 beforeShares = nativeSt.sharesOf(address(this));
        nativeSt.setShortDelivery(true);
        bytes32 beforeState = _state();
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 11, 9));
        _in(IERC20(address(nativeSt)), 11, IERC20(vault), 0);
        assertEq(_state(), beforeState, "native-share shortfall rolls back all state");
        assertEq(nativeSt.sharesOf(address(this)), beforeShares);
        assertEq(nativeSt.sharesOf(vault), 0);
        nativeSt.setShortDelivery(false);
        assertEq(_in(IERC20(address(nativeSt)), 11, IERC20(vault), 9000), 9000);
    }

    function test_APEX_nativeStEth_prepaidRefund_preservesNativeShares() public {
        assertEq(IStandardExchangeOut(vault).previewExchangeOut(IERC20(address(nativeSt)), IERC20(vault), 10000), 12,
            "public pull quote includes incoming floor");
        nativeSt.mintShares(address(integrator), 20);
        integrator.execute(address(nativeSt), abi.encodeCall(nativeSt.transfer, (vault, 20)));
        assertEq(nativeSt.sharesOf(vault), 13);
        assertEq(nativeSt.balanceOf(vault), 19);
        bytes memory result = integrator.execute(
            vault,
            abi.encodeCall(
                IStandardExchangeOut.exchangeOut,
                (IERC20(address(nativeSt)), 19, IERC20(vault), 10000, recipient, true, block.timestamp)
            )
        );
        assertEq(abi.decode(result, (uint256)), 11);
        assertEq(nativeWst.balanceOf(vault), 7);
        assertEq(nativeSt.sharesOf(vault), 1, "unrepresentable remainder stays booked");
        assertEq(nativeSt.sharesOf(address(integrator)), 12, "7 original plus5 returned shares");
        assertEq(IERC20(vault).balanceOf(recipient), 10000);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1, 0));
        integrator.execute(
            vault,
            abi.encodeCall(
                IStandardExchangeIn.exchangeIn,
                (IERC20(address(nativeSt)), 1, IERC20(vault), 0, recipient, true, block.timestamp)
            )
        );
    }

    function _seedWrapped() internal {
        IStandardExchangeIn(vault)
            .exchangeIn(IERC20(address(nativeWst)), 20, IERC20(vault), 30000, address(this), false, block.timestamp);
    }

    function test_APEX_nativeStEth_exactInRedeem_usesFundedWrappedAmount() public {
        _seedWrapped();
        uint256 quote = IStandardExchangeIn(vault).previewExchangeIn(IERC20(vault), 10000, IERC20(address(nativeSt)));
        assertEq(quote, 9);
        assertEq(_in(IERC20(vault), 10000, IERC20(address(nativeSt)), quote), 9);
        assertEq(nativeSt.balanceOf(recipient), 9);
        assertEq(nativeWst.balanceOf(vault), 14);
    }

    function test_APEX_nativeStEth_exactOutRedeem_fundsRecipientDelivery() public {
        _seedWrapped();
        uint256 quote = IStandardExchangeOut(vault).previewExchangeOut(IERC20(vault), IERC20(address(nativeSt)), 10);
        assertEq(quote, 12000);
        uint256 paid = IStandardExchangeOut(vault)
            .exchangeOut(IERC20(vault), quote, IERC20(address(nativeSt)), 10, recipient, false, block.timestamp);
        assertEq(paid, quote);
        assertEq(nativeSt.balanceOf(recipient), 12);
        assertEq(nativeWst.balanceOf(vault), 12);
    }

    function test_APEX_nativeStEth_wethStakeQuotes_matchActualNativeDelivery() public {
        _dealWeth(address(this), 100);
        hermeticWeth.approve(vault, 100);
        uint256 quote =
            IStandardExchangeIn(vault).previewExchangeIn(IERC20(address(hermeticWeth)), 11, IERC20(address(nativeSt)));
        assertEq(quote, 9);
        assertEq(_in(IERC20(address(hermeticWeth)), 11, IERC20(address(nativeSt)), quote), quote);
        assertEq(nativeSt.balanceOf(recipient), quote);
    }

    function test_APEX_nativeStEth_wethExactOut_stakeRatioTransition() public {
        _dealWeth(address(this), 100);
        hermeticWeth.approve(vault, 100);
        uint256 quote =
            IStandardExchangeOut(vault).previewExchangeOut(IERC20(address(hermeticWeth)), IERC20(address(nativeSt)), 10);
        assertEq(quote, 12);
        uint256 paid = IStandardExchangeOut(vault)
            .exchangeOut(
                IERC20(address(hermeticWeth)), quote, IERC20(address(nativeSt)), 10, recipient, false, block.timestamp
            );
        assertEq(paid, quote);
        assertGe(nativeSt.balanceOf(recipient), 10);
    }

    function testFuzz_APEX_nativeStEth_pullAndOutput_nativeRounding(uint96 amountSeed, uint96 idleSeed) public {
        uint256 amount = bound(uint256(amountSeed), 3, 1e18);
        uint256 idle = bound(uint256(idleSeed), 0, 1000);
        if (idle > 0) nativeSt.transfer(vault, idle);
        uint256 beforeShares = nativeSt.sharesOf(vault);
        uint256 received =
            nativeSt.getPooledEthByShares(beforeShares + nativeSt.getSharesByPooledEth(amount))
                - nativeSt.balanceOf(vault);
        uint256 expectedWrapped = nativeSt.getSharesByPooledEth(received);
        uint256 quote =
            IStandardExchangeIn(vault).previewExchangeIn(IERC20(address(nativeSt)), amount, IERC20(address(nativeWst)));
        assertEq(quote, expectedWrapped);
        uint256 delivered = _in(IERC20(address(nativeSt)), amount, IERC20(address(nativeWst)), quote);
        assertEq(delivered, expectedWrapped);
        assertEq(nativeWst.balanceOf(recipient), expectedWrapped);
        assertEq(nativeSt.sharesOf(vault) + expectedWrapped, beforeShares + nativeSt.getSharesByPooledEth(amount));
    }

    function test_APEX_nativeStEth_wrappedExactOutWeth_roundsUp() public {
        uint256 quote =
            IStandardExchangeOut(vault)
            .previewExchangeOut(IERC20(address(nativeWst)), IERC20(address(hermeticWeth)), 10);
        assertEq(quote, 7);
        uint256 paid = IStandardExchangeOut(vault)
            .exchangeOut(
                IERC20(address(nativeWst)), quote, IERC20(address(hermeticWeth)), 10, recipient, false, block.timestamp
            );
        assertEq(paid, 7);
        assertEq(hermeticWeth.balanceOf(recipient), 10);
    }

    function testFuzz_APEX_nativeStEth_exactOutStake_rates(uint96 amountSeed, uint64 rateSeed, bool wrappedOutput)
        public
    {
        uint256 amount = bound(uint256(amountSeed), 3, 1e18);
        uint256 rate = bound(uint256(rateSeed), 0.5 ether, 3 ether);
        nativeSt.setPooledEther(Math.mulDiv(nativeSt.getTotalShares(), rate, 1 ether));
        nativeSt.transfer(vault, 5);
        nativeSt.transfer(recipient, 7);
        IERC20 output = wrappedOutput ? IERC20(address(nativeWst)) : IERC20(address(nativeSt));
        uint256 beforeRecipient = output.balanceOf(recipient);
        uint256 quote = IStandardExchangeOut(vault).previewExchangeOut(IERC20(address(hermeticWeth)), output, amount);
        _dealWeth(address(this), quote);
        hermeticWeth.approve(vault, quote);
        uint256 paid = IStandardExchangeOut(vault)
            .exchangeOut(IERC20(address(hermeticWeth)), quote, output, amount, recipient, false, block.timestamp);
        assertEq(paid, quote);
        assertGe(output.balanceOf(recipient) - beforeRecipient, amount);
    }

    function test_APEX_nativeStEth_nativeEth_minimumUsesRecipientDelivery() public {
        vm.deal(address(this), 100);
        bytes32 beforeState = _state();
        vm.expectRevert(bytes4(keccak256("Slippage()")));
        INativeLidoExchange(vault).exchangeInEth{value: 11}(IERC20(address(nativeSt)), 10, recipient, block.timestamp);
        assertEq(_state(), beforeState, "native submit and transfer rollback");
        uint256 delivered =
            INativeLidoExchange(vault).exchangeInEth{value: 11}(
            IERC20(address(nativeSt)), 9, recipient, block.timestamp
        );
        assertEq(delivered, 9);
        assertEq(nativeSt.balanceOf(recipient), 9);
        assertEq(nativeSt.balanceOf(vault), 1, "native transfer leaves one pooled unit");
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1, 0));
        integrator.execute(vault, abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (IERC20(address(nativeSt)), 1, IERC20(vault), 0, recipient, true, block.timestamp)));
    }

    function test_APEX_nativeStEth_zeroNativeReceipt_cannotInventCredit() public {
        vm.deal(address(this), 100);
        bytes32 beforeState = _state();
        vm.expectRevert(bytes4(keccak256("Slippage()")));
        INativeLidoExchange(vault).exchangeInEth{value: 1}(IERC20(vault), 0, recipient, block.timestamp);
        assertEq(_state(), beforeState, "no minted native shares means no invented credit");
        assertGt(INativeLidoExchange(vault).exchangeInEth{value: 12}(IERC20(vault), 1, recipient, block.timestamp), 0);
    }
    function test_APEX_nativeStEth_externalShares_preservesCanonicalRate() public {
        ExternalSharesNativeStETH port = new ExternalSharesNativeStETH();
        _resetNativePort(port);
        port.mintExternalShares(1);
        uint256 quote = IStandardExchangeOut(vault).previewExchangeOut(IERC20(address(hermeticWeth)), IERC20(address(nativeSt)), 12);
        assertEq(quote, 12, "external total rounding must not change native share rate");
        _dealWeth(address(this), quote);
        hermeticWeth.approve(vault, quote);
        assertEq(IStandardExchangeOut(vault).exchangeOut(IERC20(address(hermeticWeth)), quote, IERC20(address(nativeSt)), 12, recipient, false, block.timestamp), quote);
        assertEq(nativeSt.balanceOf(recipient), 12);
    }

    function test_APEX_nativeStEth_externalShares_transitionUsesInternalRatio() public {
        ExternalSharesNativeStETH port = new ExternalSharesNativeStETH();
        _resetNativePort(port);
        port.mintExternalShares(1);
        (bytes memory state,) = IStandardExchangeTransitionQuote(vault).quoteState(address(nativeWst), recipient);
        (, uint256 quote,) = IStandardExchangeExternalQuote(vault).quoteExternalExchange(state, address(hermeticWeth), 12);
        assertEq(quote, 8, "stateful quote uses actual native numerator/denominator");
        _dealWeth(address(this), 12);
        hermeticWeth.approve(vault, 12);
        assertEq(_in(IERC20(address(hermeticWeth)), 12, IERC20(address(nativeWst)), quote), quote);
        assertEq(nativeWst.balanceOf(recipient), quote);
    }

    function test_APEX_nativeStEth_externalRateFailure_bubbles() public {
        ExternalSharesNativeStETH port = new ExternalSharesNativeStETH();
        _resetNativePort(port);
        port.setExternalEtherFailure(true);
        vm.expectRevert(abi.encodeWithSelector(ExternalSharesNativeStETH.NativeRateFailure.selector, 7));
        IStandardExchangeIn(vault).previewExchangeIn(IERC20(address(hermeticWeth)), 12, IERC20(address(nativeSt)));
        port.setExternalEtherFailure(false);
        assertEq(IStandardExchangeIn(vault).previewExchangeIn(IERC20(address(hermeticWeth)), 12, IERC20(address(nativeSt))), 12);
    }

}
