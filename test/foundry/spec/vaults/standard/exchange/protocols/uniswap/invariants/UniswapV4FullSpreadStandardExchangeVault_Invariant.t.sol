// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {TestBase_UniswapV4FullSpreadStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol";
import {StandardExchangeMarketTrader} from "../remediation/StandardExchangeMarketTrader.sol";
import {StandardExchangeHandler, ISequenceEnvironment} from "./StandardExchangeHandler.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {FullRangeBookSeederFullSpread} from "../release/v4/UniswapV4FullSpreadStandardExchangeVault_FullRangeBook.t.sol";

contract UniswapV4FullSpreadStandardExchangeVault_Invariant is TestBase_UniswapV4FullSpreadStandardExchangeVault, ISequenceEnvironment {
    IStandardExchangeProxy internal vault;
    IERC20 internal asset0;
    IERC20 internal asset1;
    StandardExchangeMarketTrader internal trader;
    StandardExchangeHandler internal handler;
    address internal poolCustodian;
    address internal seedCustodian;
    PoolKey internal market;
    function setUp() public override {
        super.setUp();
        address a = address(new ERC20PermitMintableStub("A", "A", 18, address(this), 0));
        address b = address(new ERC20PermitMintableStub("B", "B", 18, address(this), 0));
        (asset0, asset1) = a < b ? (IERC20(a), IERC20(b)) : (IERC20(b), IERC20(a));
        trader = new StandardExchangeMarketTrader();
        market = PoolKey({currency0: Currency.wrap(address(asset0)), currency1: Currency.wrap(address(asset1)),
            fee: 3000, tickSpacing: 60, hooks: IHooks(address(0))});
        poolManager.initialize(market, uint160(1 << 96));
        FullRangeBookSeederFullSpread seeder = new FullRangeBookSeederFullSpread(poolManager);
        ERC20PermitMintableStub(address(asset0)).mint(address(seeder), 1000 ether);
        ERC20PermitMintableStub(address(asset1)).mint(address(seeder), 1000 ether);
        seeder.addLiquidity(market, -887220, 887220, 1000 ether);
        poolCustodian = address(poolManager); seedCustodian = address(seeder);
        vault = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(market));
        address[] memory tokens = new address[](2); tokens[0] = address(asset0); tokens[1] = address(asset1);
        uint256[] memory amounts = new uint256[](2); amounts[0] = 1000 ether; amounts[1] = 1000 ether;
        for (uint256 i; i < 2; ++i) {
            ERC20PermitMintableStub(tokens[i]).mint(address(this), amounts[i]);
            IERC20(tokens[i]).approve(address(vault), amounts[i]);
        }
        IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(tokens, amounts, IERC20(address(vault)), 0, address(this), false, block.timestamp);
        handler = new StandardExchangeHandler(this, vault, asset0, asset1);
        vault.transfer(address(handler), vault.totalSupply() / 2);
        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = StandardExchangeHandler.deposit.selector;
        selectors[1] = StandardExchangeHandler.withdraw.selector;
        selectors[2] = StandardExchangeHandler.marketTrade.selector;
        selectors[3] = StandardExchangeHandler.donate.selector;
        selectors[4] = StandardExchangeHandler.rebalance.selector;
        selectors[5] = StandardExchangeHandler.sleeve.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }
    function fund(IERC20 token, address recipient, uint256 amount) external {
        require(msg.sender == address(handler));
        ERC20PermitMintableStub(address(token)).mint(recipient, amount);
    }
    function configureSleeve(uint256 percentage) external {
        require(msg.sender == address(handler));
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setLiquidReservePercentageOfVault(address(vault), percentage);
    }
    function trade(bool zeroForOne, uint256 amount) external {
        require(msg.sender == address(handler));
        ERC20PermitMintableStub(address(zeroForOne ? asset0 : asset1)).mint(address(trader), amount);
        trader.tradeV4(poolManager, market, zeroForOne, amount);
    }

    /// forge-config: default.invariant.runs = 64
    /// forge-config: default.invariant.depth = 96
    /// forge-config: default.invariant.fail-on-revert = true
    function invariant_allInputsSharesAndCustodyReconcile() public {
        handler.assertNoUnfundedCredit();
        assertEq(vault.totalSupply(), vault.balanceOf(address(this)) + vault.balanceOf(address(handler)) + vault.balanceOf(address(0xdEaD)));
        _assertCustody(asset0); _assertCustody(asset1);
    }
    function _assertCustody(IERC20 token) internal view {
        uint256 custody = token.balanceOf(address(this)) + token.balanceOf(address(vault))
            + token.balanceOf(address(handler)) + token.balanceOf(address(trader))
            + token.balanceOf(poolCustodian) + token.balanceOf(seedCustodian);
        assertEq(custody, token.totalSupply(), "every minted test asset accounted for");
    }
    function test_deterministicSequenceExercisesEveryHandler() public {
        handler.deposit(false, 10 ether, true);
        handler.marketTrade(true, 1 ether);
        handler.donate(true, 1 ether);
        handler.withdraw(true, 10, true);
        handler.sleeve(3);
        handler.deposit(true, 1 ether, false);
        handler.withdraw(false, 15, false);
        handler.rebalance();
        for (uint256 i; i < 6; ++i) assertGt(handler.calls(i), 0, "nonvacuous handler coverage");
        invariant_allInputsSharesAndCustodyReconcile();
    }
}
