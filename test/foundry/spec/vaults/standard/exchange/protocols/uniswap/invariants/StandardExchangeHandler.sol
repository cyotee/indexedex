// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangePretransfer as IPretransfer} from "contracts/vaults/standard/exchange/protocols/uniswap/IStandardExchangePretransfer.sol";

interface ISequenceEnvironment {
    function fund(IERC20 token, address recipient, uint256 amount) external;
    function trade(bool zeroForOne, uint256 amount) external;
    function configureSleeve(uint256 percentage) external;
}
interface ISequenceReserve { function rebalanceLiquidReserve() external; }

contract UnfundedSequenceActor {
    function invoke(address vault, bytes calldata data) external returns (bytes memory result) {
        (bool ok, bytes memory returned) = vault.call(data);
        if (!ok) assembly ("memory-safe") { revert(add(returned, 32), mload(returned)) }
        return returned;
    }
    function prepareAndInvoke(address vault, address token, uint256 amount, bytes calldata data) external {
        address[] memory tokens = new address[](1); tokens[0] = token;
        uint256[] memory amounts = new uint256[](1); amounts[0] = amount;
        IPretransfer(vault).preparePretransfer(tokens, amounts, keccak256(data));
        (bool ok, bytes memory returned) = vault.call(data);
        if (!ok) assembly ("memory-safe") { revert(add(returned, 32), mload(returned)) }
    }
}

/// @notice Stateful actor driving only the real public vault/protocol interfaces.
/// @dev Every successful operation probes zero-input claims; expected attack failures
/// are caught explicitly. Unexpected handler reverts fail the invariant campaign.
contract StandardExchangeHandler is Test {
    ISequenceEnvironment public immutable environment;
    IStandardExchangeProxy public immutable vault;
    IERC20 public immutable token0;
    IERC20 public immutable token1;
    UnfundedSequenceActor public immutable attacker;
    uint256 public immutable initialSupply;
    uint256 public issued;
    uint256 public burned;
    uint256[6] public calls;

    constructor(ISequenceEnvironment env, IStandardExchangeProxy vault_, IERC20 a, IERC20 b) {
        environment = env; vault = vault_; token0 = a; token1 = b;
        initialSupply = vault_.totalSupply(); attacker = new UnfundedSequenceActor();
    }
    modifier checked() { _; assertNoUnfundedCredit(); }

    function deposit(bool side, uint96 raw, bool prepared) external checked {
        IERC20 token = side ? token1 : token0;
        uint256 amount = bound(uint256(raw), 1e14, 25 ether);
        environment.fund(token, address(this), amount);
        uint256 supplyBefore = vault.totalSupply();
        bytes memory data = abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (token, amount, IERC20(address(vault)), 0, address(this), prepared, block.timestamp));
        if (prepared) _prepareAndTransfer(token, amount, data);
        else token.approve(address(vault), amount);
        uint256 received = _call(data);
        assertGt(received, 0);
        assertEq(vault.totalSupply(), supplyBefore + received);
        issued += received; ++calls[0];
        assertEq(token.balanceOf(address(this)), 0, "new input fully delivered");
    }
    function withdraw(bool side, uint16 raw, bool prepared) external checked {
        uint256 balance = vault.balanceOf(address(this));
        if (balance < 1e12) return;
        uint256 shares = balance / bound(uint256(raw), 4, 20);
        IERC20 output = side ? token1 : token0;
        bytes memory data = abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (IERC20(address(vault)), shares, output, 0, address(this), prepared, block.timestamp));
        uint256 beforeBalance = output.balanceOf(address(this));
        if (prepared) _prepareAndTransfer(IERC20(address(vault)), shares, data);
        else vault.approve(address(vault), shares);
        uint256 paid = _call(data);
        assertEq(output.balanceOf(address(this)) - beforeBalance, paid);
        burned += shares; ++calls[1];
        // Return the paid tokens to the fixture so a later deposit has a clean input ledger.
        output.transfer(address(environment), paid);
    }
    function marketTrade(bool side, uint96 raw) external checked {
        environment.trade(side, bound(uint256(raw), 1e14, 2 ether)); ++calls[2];
    }
    function donate(bool side, uint96 raw) external checked {
        uint256 supply = vault.totalSupply();
        environment.fund(side ? token1 : token0, address(vault), bound(uint256(raw), 1, 2 ether));
        assertEq(vault.totalSupply(), supply); ++calls[3];
    }
    function rebalance() external checked {
        uint256 supply = vault.totalSupply();
        ISequenceReserve(address(vault)).rebalanceLiquidReserve();
        assertEq(vault.totalSupply(), supply); ++calls[4];
    }
    function sleeve(uint8 raw) external checked {
        uint256[4] memory choices = [uint256(0.02e18), 0.2e18, 0.5e18, 1e18];
        environment.configureSleeve(choices[raw % 4]);
        ISequenceReserve(address(vault)).rebalanceLiquidReserve(); ++calls[5];
    }
    function assertNoUnfundedCredit() public {
        for (uint256 i; i < 2; ++i) {
            IERC20 token = i == 0 ? token0 : token1;
            bytes memory data = abi.encodeCall(IStandardExchangeIn.exchangeIn,
                (token, 1, IERC20(address(vault)), 0, address(attacker), true, block.timestamp));
            (bool ok, bytes memory reason) = address(attacker).call(abi.encodeCall(UnfundedSequenceActor.invoke, (address(vault), data)));
            assertFalse(ok); assertEq(reason, abi.encodeWithSelector(IPretransfer.PretransferNotPrepared.selector));
            (ok, reason) = address(attacker).call(abi.encodeCall(UnfundedSequenceActor.prepareAndInvoke,
                (address(vault), address(token), 1, data)));
            assertFalse(ok); assertEq(reason, abi.encodeWithSelector(IPretransfer.PretransferAmountMismatch.selector, address(token), 1, 0));
            assertEq(token.balanceOf(address(attacker)), 0);
        }
        assertEq(vault.balanceOf(address(attacker)), 0);
        assertEq(vault.balanceOf(address(vault)), 0, "no orphan input shares");
        assertEq(vault.totalSupply(), initialSupply + issued - burned, "all supply changes attributed");
    }
    function _prepareAndTransfer(IERC20 token, uint256 amount, bytes memory data) private {
        address[] memory tokens = new address[](1); tokens[0] = address(token);
        uint256[] memory amounts = new uint256[](1); amounts[0] = amount;
        IPretransfer(address(vault)).preparePretransfer(tokens, amounts, keccak256(data));
        token.transfer(address(vault), amount);
    }
    function _call(bytes memory data) private returns (uint256) {
        (bool ok, bytes memory result) = address(vault).call(data);
        if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        return abi.decode(result, (uint256));
    }
}
