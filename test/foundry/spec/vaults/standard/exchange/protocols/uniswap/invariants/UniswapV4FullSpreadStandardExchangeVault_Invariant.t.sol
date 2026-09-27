// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {DeliveryTestToken} from "../remediation/DeliveryTestToken.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {
    TestBase_UniswapV4FullSpreadStandardExchangeVault
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol";
import {StandardExchangeMarketTrader} from "../remediation/StandardExchangeMarketTrader.sol";
import {StandardExchangeHandler, ISequenceEnvironment} from "./StandardExchangeHandler.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {
    FullRangeBookSeederFullSpread
} from "../release/v4/UniswapV4FullSpreadStandardExchangeVault_FullRangeBook.t.sol";

contract UniswapV4FullSpreadStandardExchangeVault_Invariant is
    TestBase_UniswapV4FullSpreadStandardExchangeVault,
    ISequenceEnvironment
{
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
        address a = address(new DeliveryTestToken("A", "A", 18, address(this), 0));
        address b = address(new DeliveryTestToken("B", "B", 18, address(this), 0));
        (asset0, asset1) = a < b ? (IERC20(a), IERC20(b)) : (IERC20(b), IERC20(a));
        trader = new StandardExchangeMarketTrader();
        market = PoolKey({
            currency0: Currency.wrap(address(asset0)),
            currency1: Currency.wrap(address(asset1)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
        poolManager.initialize(market, uint160(1 << 96));
        FullRangeBookSeederFullSpread seeder = new FullRangeBookSeederFullSpread(poolManager);
        DeliveryTestToken(address(asset0)).mint(address(seeder), 1000 ether);
        DeliveryTestToken(address(asset1)).mint(address(seeder), 1000 ether);
        seeder.addLiquidity(market, -887220, 887220, 1000 ether);
        poolCustodian = address(poolManager);
        seedCustodian = address(seeder);
        vault = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(market));
        address[] memory tokens = new address[](2);
        tokens[0] = address(asset0);
        tokens[1] = address(asset1);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1000 ether;
        amounts[1] = 1000 ether;
        for (uint256 i; i < 2; ++i) {
            DeliveryTestToken(tokens[i]).mint(address(this), amounts[i]);
            IERC20(tokens[i]).approve(address(vault), amounts[i]);
        }
        IStandardExchangeInMulti(address(vault))
            .exchangeInManyToOne(tokens, amounts, IERC20(address(vault)), 0, address(this), false, block.timestamp);
        handler = new StandardExchangeHandler(this, vault, asset0, asset1);
        uint256 holderShares = vault.balanceOf(address(this)) / 4;
        for (uint256 i; i < 3; ++i) {
            address actor = address(handler.actors(i));
            vault.transfer(actor, holderShares);
            DeliveryTestToken(address(asset0)).mint(actor, 10_000 ether);
            DeliveryTestToken(address(asset1)).mint(actor, 10_000 ether);
        }
        assertEq(handler.steps(), 0, "setup does not count as campaign coverage");
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = StandardExchangeHandler.step.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function configureSleeve(uint256 percentage) external {
        require(msg.sender == address(handler));
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setLiquidReservePercentageOfVault(address(vault), percentage);
    }

    function trade(bool zeroForOne, uint256 amount) external {
        require(msg.sender == address(handler));
        DeliveryTestToken(address(zeroForOne ? asset0 : asset1)).mint(address(trader), amount);
        trader.tradeV4(poolManager, market, zeroForOne, amount);
    }

    function custodyAddresses() external view returns (address[3] memory) {
        return [poolCustodian, seedCustodian, address(trader)];
    }

    function slippageError() external pure returns (bytes4) {
        return bytes4(keccak256("UniswapV4ExchangeIn_SlippageExceeded()"));
    }

    /// forge-config: default.invariant.runs = 256
    /// forge-config: default.invariant.depth = 64
    /// forge-config: default.invariant.fail-on-revert = true
    function invariant_APEX_allInputsSharesAndCustodyReconcile() public view {
        handler.assertAccounting();
        _assertCustody(asset0);
        _assertCustody(asset1);
    }

    function afterInvariant() public view {
        handler.assertCampaignCoverage();
        invariant_APEX_allInputsSharesAndCustodyReconcile();
    }

    function _assertCustody(IERC20 token) internal view {
        uint256 custody = token.balanceOf(address(this)) + token.balanceOf(address(vault))
            + token.balanceOf(address(handler)) + token.balanceOf(address(trader)) + token.balanceOf(poolCustodian)
            + token.balanceOf(seedCustodian) + token.balanceOf(address(handler.attacker()))
            + token.balanceOf(handler.EOA_ATTACKER());
        for (uint256 i; i < 3; ++i) {
            custody += token.balanceOf(address(handler.actors(i)));
        }
        assertEq(custody, token.totalSupply(), "all assets across holders, vault, pool and trader reconciled");
    }

    function test_APEX_deterministicSequenceExercisesEveryHandler() public {
        for (uint256 i; i < 64; ++i) {
            handler.step(uint256(keccak256(abi.encode("FullSpread lifecycle", i))));
            invariant_APEX_allInputsSharesAndCustodyReconcile();
        }
        afterInvariant();
        for (uint256 i; i < handler.ACTIONS(); ++i) {
            string memory action = string.concat("action ", vm.toString(i));
            emit log_named_uint(string.concat(action, " attempted"), handler.attempted(i));
            emit log_named_uint(string.concat(action, " succeeded"), handler.succeeded(i));
            emit log_named_uint(string.concat(action, " expected reverts"), handler.expectedReverts(i));
            emit log_named_uint(string.concat(action, " unexpected reverts"), handler.unexpectedReverts(i));
        }
    }
}
