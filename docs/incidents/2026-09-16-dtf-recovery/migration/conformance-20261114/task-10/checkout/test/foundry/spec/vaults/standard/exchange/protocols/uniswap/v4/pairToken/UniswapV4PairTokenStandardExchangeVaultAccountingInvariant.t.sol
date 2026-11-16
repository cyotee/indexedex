// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ModifyLiquidityParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TestBase_UniswapV4PairTokenStandardExchangeVault} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/test/bases/TestBase_UniswapV4PairTokenStandardExchangeVault.sol";
import {IUniswapV4PairTokenStandardExchangeVaultDFPkg as IPackage} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVaultDFPkg.sol";
import {IUniswapV4PairTokenStandardExchangeVault as IVault} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVault.sol";
import {Handler_UniswapV4PairTokenStandardExchangeVault as Handler} from
    "./harness/Handler_UniswapV4PairTokenStandardExchangeVault.sol";

// tag::UniswapV4PairTokenStandardExchangeVaultAccountingInvariantTest[]
/// @notice S1-A15/A41/A46/A65 through public routes on registered real diamonds.
/// @dev Uses the repository's unchanged invariant runs=16/depth=8 and fuzz runs=16.
/// The random domain is a healthy 18/18 ERC20 pool with real external full-range
/// liquidity. Deterministic fee-zero endpoint vectors separately admit large idle
/// contributions/partial entry fills. Native representation, other decimals,
/// work/capacity fallback reachability and hostile token callbacks belong to the
/// adjacent suites, not this ownership invariant domain.
contract UniswapV4PairTokenStandardExchangeVaultAccountingInvariantTest is
    TestBase_UniswapV4PairTokenStandardExchangeVault
{
    Handler internal handler;

    /// @notice Use the actual family fixture; every share is issued by depositPair.
    function setUp() public override {
        super.setUp();
        _fund(address(poolActor), 2e20, 2e20);
        poolActor.modifyLiquidity(key, ModifyLiquidityParams(
            vault.tickLower(), vault.tickUpper(), int256(1e20), bytes32(0)
        ));
        handler = new Handler(vault, poolActor);
        handler.scenario(Handler.Action.Pair, 0, 1e18, 1e18);
        handler.scenario(Handler.Action.Pair, 1, 1e17, 1e17);
        handler.scenario(Handler.Action.Pair, 2, 2e17, 2e17);
        handler.assertStable();

        bytes4[] memory selectors = new bytes4[](10);
        selectors[0] = Handler.pairedEntry.selector;
        selectors[1] = Handler.zap.selector;
        selectors[2] = Handler.pairedExit.selector;
        selectors[3] = Handler.singleExit.selector;
        selectors[4] = Handler.donate.selector;
        selectors[5] = Handler.unsolicited.selector;
        selectors[6] = Handler.transferShares.selector;
        selectors[7] = Handler.trade.selector;
        selectors[8] = Handler.compound.selector;
        selectors[9] = Handler.closeAndRestart.selector;
        targetContract(address(handler));
        string[] memory artifacts = new string[](1);
        artifacts[0] = "Handler_UniswapV4PairTokenStandardExchangeVault.sol:Handler_UniswapV4PairTokenStandardExchangeVault";
        targetInterface(FuzzInterface(address(handler), artifacts));
        targetSelector(FuzzSelector(address(handler), selectors));
    }

    /// @notice Exact sum of four actual holder balances equals independently tracked shares.
    function invariant_INV_SupplyAndIndependentHolderGhosts() public view {
        assertFalse(handler.handlerFailed(), string(handler.failureData()));
        uint256 sum;
        for (uint256 i; i < 4; ++i) {
            address holder = handler.holders(i);
            uint256 balance = IERC20(address(vault)).balanceOf(holder);
            assertEq(balance, handler.ghostHolderShares(holder));
            sum += balance;
        }
        assertEq(sum, IERC20(address(vault)).totalSupply());
        assertEq(sum, handler.ghostSupply());
        assertEq(IERC20(address(vault)).balanceOf(address(0xdead)), 0);
        assertEq(IERC20(address(vault)).balanceOf(address(0)), 0);
    }

    /// @notice Every admitted operation satisfies exact custody, manager and position equations.
    function invariant_INV_CustodyAndPositionStableLedger() public view {
        assertFalse(handler.handlerFailed(), string(handler.failureData()));
        handler.assertStable();
    }

    /// @notice A15/A46 controls execute inside every successful entry/exit assertion frame.
    /// @dev This latch makes arbitrary reverts and arithmetic/event assertion failures
    /// falsifiable even when Foundry discards reverting handler calls by default.
    function invariant_INV_EntryNonDilutionAndPreSaleAllocation() public view {
        assertFalse(handler.handlerFailed(), string(handler.failureData()));
        assertGe(handler.genesisCount(), 1);
        handler.assertStable();
    }

    /// @notice Every operation family succeeds in one fee-bearing, multi-holder sequence.
    function test_INV_AdversarialOwnershipSequences() public {
        handler.scenario(Handler.Action.Unsolicited, 3, 123_457, 765_431);
        handler.scenario(Handler.Action.Donation, 1, 0, 1e15 + 123);
        handler.scenario(Handler.Action.Donation, 2, 1, 1001);
        handler.scenario(Handler.Action.Trade, 0, 0, 1e16 + 7);
        handler.scenario(Handler.Action.Pair, 3, 3e15 + 11, 5e15 + 13);
        handler.scenario(Handler.Action.Zap, 1, 0, 1e14 + 1);
        handler.scenario(Handler.Action.Zap, 2, 1, 1e14 + 3);
        handler.scenario(Handler.Action.Transfer, 3, 1, 1e12);
        handler.scenario(Handler.Action.PairExit, 1, 1e13, 0);
        handler.scenario(Handler.Action.SingleExit, 2, 0, 1e13);
        handler.scenario(Handler.Action.SingleExit, 1, 1, 1e13);
        handler.scenario(Handler.Action.Trade, 0, 1, 2e16 + 9);
        handler.scenario(Handler.Action.Compound, 0, 0, 0);
        handler.scenario(Handler.Action.Restart, 3, 0, 0);
        for (uint256 i; i < 10; ++i) assertGt(handler.successes(i), 0, "missing operation family");
        assertGt(handler.roundingEntries(), 0, "addition rounding not exercised");
        assertGt(handler.zapResidual0() + handler.zapResidual1(), 0, "zap donations not exercised");
        assertGt(handler.entrySwapFees0() + handler.entrySwapFees1(), 0, "incumbent entry-swap fees not exercised");
        assertEq(handler.unsolicited0(), 123_457);
        assertEq(handler.unsolicited1(), 765_431);
        handler.assertStable();
    }

    /// @notice Fuzz operation amounts/directions without lowering the configured 16 runs.
    function testFuzz_INV_PublicRouteOwnershipSequence(uint256 seed, uint64 amount0, uint64 amount1) public {
        handler.unsolicited(seed, amount0, amount1);
        handler.donate(seed, seed, amount0);
        handler.trade(seed, amount1);
        handler.pairedEntry(seed, amount0, amount1);
        handler.zap(seed, seed, amount0);
        handler.transferShares(seed, seed >> 8, amount1);
        handler.pairedExit(seed, amount0);
        handler.singleExit(seed, seed >> 1, amount1);
        handler.compound();
        handler.closeAndRestart(seed);
        assertFalse(handler.handlerFailed(), string(handler.failureData()));
        handler.assertStable();
        assertEq(handler.ghostSupply(), 1e18);
    }

    /// @notice Terminal fees/removal receipts reach the last holder, not an excess ledger.
    function test_INV_StableLedgerTerminalReceiptsAndRestart() public {
        handler.scenario(Handler.Action.Unsolicited, 0, 37, 91);
        handler.scenario(Handler.Action.Donation, 1, 0, 1e16);
        handler.scenario(Handler.Action.Trade, 0, 1, 1e16);
        uint256 genesisBefore = handler.genesisCount();
        handler.scenario(Handler.Action.Restart, 2, 0, 0);
        assertEq(handler.genesisCount(), genesisBefore + 1);
        assertEq(handler.ghostHolderShares(handler.holders(2)), 1e18);
        assertEq(handler.ghostSupply(), 1e18);
        assertEq(handler.terminalResets(), 1);
        assertEq(handler.unsolicited0(), 37);
        assertEq(handler.unsolicited1(), 91);
        handler.assertStable();
    }

    /// @notice The exact qQuote=6/q=5 manager rounding vector is capped, not tolerated.
    function test_INV_EntryNonDilutionCappedAndUncappedPairs() public {
        Handler h = _freshZeroFee("Invariant rounding cap", false);
        h.scenario(Handler.Action.Pair, 0, 1_000_000, 1_000_000);
        h.scenario(Handler.Action.Trade, 0, 0, 10_000);
        h.scenario(Handler.Action.Pair, 1, 7, 7);
        assertEq(h.ghostHolderShares(h.holders(1)), 5);
        assertEq(h.cappedPairs(), 1);
        assertGt(handler.uncappedPairs(), 0, "main fixture uncapped entry control");
        h.assertStable();
    }

    /// @notice Both real partial half-swap fills obey the same independent per-leg inequality.
    function test_INV_EntryNonDilutionPartialFillsBothDirections() public {
        _partialFill(true);
        _partialFill(false);
    }

    /// @notice Exact ZeroShares/ZeroPayout classifications preserve balances, pool and book.
    function test_INV_TinyEconomicRejectionsAreAtomicAndClassified() public {
        Handler h = _freshZeroFee("Invariant tiny rollback", false);
        h.scenario(Handler.Action.Pair, 0, 1e18, 1e18);
        h.scenario(Handler.Action.Zap, 1, 0, 1);
        assertEq(h.rejectedZeroCredit(), 1);
        h.scenario(Handler.Action.PairExit, 0, 0, 0);
        assertEq(h.rejectedZeroPayout(), 1);
        assertEq(h.ghostSupply(), 1e18);
        h.assertStable();
    }

    /// @notice An out-of-domain failure persists instead of becoming a discarded fuzz call.
    function test_INV_UnexpectedHandlerFailureCannotDisappear() public {
        Handler h = _freshZeroFee("Invariant failure latch", false);
        // The invariant domain always bootstraps first. Deliberately omit genesis
        // here to prove an unclassified InvalidAccountingState remains observable.
        h.donate(0, 0, 1);
        assertTrue(h.handlerFailed());
        assertEq(h.failureData(), abi.encodeWithSelector(IVault.InvalidAccountingState.selector));
        assertEq(h.ghostSupply(), 0);
        assertEq(IERC20(address(h.vault())).totalSupply(), 0);
    }

    function _partialFill(bool zeroForOne) private {
        Handler h = _freshZeroFee(zeroForOne ? "Invariant partial zero" : "Invariant partial one", true);
        h.scenario(Handler.Action.Pair, 0, 1e12, 1e12);
        h.scenario(Handler.Action.Unsolicited, 3, 97, 193);
        h.scenario(Handler.Action.Donation, 0, zeroForOne ? 0 : 1, 1e34);
        h.scenario(Handler.Action.Zap, 1, zeroForOne ? 0 : 1, 1e33);
        assertEq(h.partialEntryFills(), 1, "real half-swap must partially fill");
        assertGt(h.ghostHolderShares(h.holders(1)), 0, "positive endpoint credit");
        assertGt(zeroForOne ? h.zapResidual1() : h.zapResidual0(), 0, "opposing residue donation");
        assertEq(h.unsolicited0(), 97);
        assertEq(h.unsolicited1(), 193);
        h.assertStable();
    }

    function _freshZeroFee(string memory name, bool wideTickDomain) private returns (Handler h) {
        // The active fixture handles change; existing registered instances are not mutated.
        _deployPool(false, 18, 18);
        key.fee = 0;
        if (wideTickDomain) key.tickSpacing = 32767;
        pool.initialize(key, uint160(1) << 96);
        IPackage.PkgArgs memory args = _defaultArgs(key, address(token0), name);
        if (wideTickDomain) {
            args.maxZapBps = 10_000;
            args.maxZapTickMove = 1_000_000;
        }
        h = new Handler(_deployVault(args), poolActor);
    }
}
// end::UniswapV4PairTokenStandardExchangeVaultAccountingInvariantTest[]
