// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceFixture as Fixture} from "./UniswapV4UpperLowerWingsStandardExchangeVaultRebalance.t.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVault as Vault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVault.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance as Rebalance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance.sol";

import {UniswapV4UpperLowerWingsStandardExchangeVaultPoolActor as Actor} from "./reference/UniswapV4UpperLowerWingsStandardExchangeVaultPoolActor.sol";

contract UniswapV4UpperLowerWingsStandardExchangeVaultInvariantHandler {
    Vault public immutable vault;
    IERC20 public immutable target;
    Actor public market;
    address private immutable controller;
    uint256 public deposits;
    uint256 public withdrawals;
    uint256 public paid;
    uint256 public funded;
    constructor(Vault vault_, address controller_) {
        controller = controller_;
        vault = vault_; target = IERC20(vault_.targetToken());
        target.approve(address(vault_), type(uint256).max);
    }
    function configureMarket(Actor market_) external {
        require(msg.sender == controller && address(market) == address(0), "handler controller");
        market = market_;
    }
    function trade(uint64 seed_, bool zeroForOne_) external {
        try market.swap(vault.poolKey(), zeroForOne_, uint256(seed_) % 1e19 + 1) returns (BalanceDelta) {} catch {}
    }
    function deposit(uint64 seed_) external {
        uint256 amount = uint256(seed_) % 1e10 + 1;
        if (amount > target.balanceOf(address(this))) return;
        try IStandardExchangeIn(address(vault)).exchangeIn(target, amount, IERC20(address(vault)), 0, address(this), false, block.timestamp)
            returns (uint256) { ++deposits; funded += amount; } catch {}
    }
    function redeem(uint16 seed_) external {
        uint256 balance = IERC20(address(vault)).balanceOf(address(this));
        uint256 shares = balance * (uint256(seed_) % 10000 + 1) / 10000;
        if (shares == 0) return;
        try IStandardExchangeIn(address(vault)).exchangeIn(IERC20(address(vault)), shares, target, 0, address(this), false, block.timestamp)
            returns (uint256 assets) { ++withdrawals; paid += assets; } catch {}
    }
    function rebalance() external {
        try Rebalance(address(vault)).rebalance(0, block.timestamp) returns (uint256) {} catch {}
    }
}

contract UniswapV4UpperLowerWingsStandardExchangeVaultInvariantTest is Fixture {
    using StateLibrary for IPoolManager;
    UniswapV4UpperLowerWingsStandardExchangeVaultInvariantHandler internal handler;
    function setUp() public override {
        super.setUp();
        handler = UniswapV4UpperLowerWingsStandardExchangeVaultInvariantHandler(create3Factory.create3WithArgs(
            type(UniswapV4UpperLowerWingsStandardExchangeVaultInvariantHandler).creationCode, abi.encode(wings0, address(this)), keccak256("Wings.InvariantHandler")));
        token0.mint(address(handler), 1e18);
        handler.deposit(1e9);
        Actor market = Actor(create3Factory.create3WithArgs(type(Actor).creationCode,
            abi.encode(pool, address(handler)), keccak256("Wings.InvariantMarket")));
        token0.mint(address(market), 1e25); token1.mint(address(market), 1e25);
        handler.configureMarket(market);
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = handler.deposit.selector;
        selectors[1] = handler.redeem.selector;
        selectors[2] = handler.rebalance.selector;
        selectors[3] = handler.trade.selector;
        targetSelector(FuzzSelector(address(handler), selectors));
        targetContract(address(handler));
    }
    function invariant_custodyAndPositiveValueAndIssuedSupply() public view {
        (uint256 local0, uint256 local1) = wings0.localReserves();
        assertEq(token0.balanceOf(address(wings0)), local0);
        assertEq(token1.balanceOf(address(wings0)), local1);
        uint256 supply = IERC20(address(wings0)).totalSupply();
        assertEq(supply, IERC20(address(wings0)).balanceOf(address(handler)));
        if (supply != 0) { assertGe(local0, 1); assertGt(wings0.liquidationValue().value, 0); }
        assertEq(token0.balanceOf(address(handler)), 1e18 - handler.funded() + handler.paid());
        for (uint8 i; i < 3; ++i) {
            (int24 lower, int24 upper, uint128 liquidity, bytes32 salt) = wings0.position(i);
            if (liquidity == 0) continue;
            (uint128 actual,,) = pool.getPositionInfo(key.toId(), address(wings0), lower, upper, salt);
            assertEq(actual, liquidity);
        }
    }
}
