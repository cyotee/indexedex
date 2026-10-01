"""One-shot adaptation of the newly copied P tests and real launch fixture."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
P = "UniswapV4FullSpreadPonsFamilyHook"
BASE = ROOT / "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook"
TEST = ROOT / "test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook"

for path in TEST.glob("*.sol"):
    text = re.sub(r"\bHookless", P, path.read_text())
    path.write_text(text)

old = (ROOT / "contracts/test/bases/TestBase_UniswapV4StandardExchange_PonsV2.sol").read_text()
old = old.replace("TestBase_UniswapV4StandardExchange_PonsV2", "TestBase_" + P + "_Launch")
old = old.replace("contracts/protocols/dexes/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchange.sol",
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_" + P + ".sol")
old = old.replace("TestBase_UniswapV4StandardExchange", "TestBase_" + P)
old = old.replace("        _deployPonsV2OnIndexedExPoolManager();\n        _approveWethPairAndGraduate();", "        _approveWethPairAndGraduate();")
old = old.replace("    /// @dev Activate the SE", "    function _initializePonsHook() internal override {\n        _deployPonsV2OnIndexedExPoolManager();\n        ponsHook = ponsV2MemeHook;\n    }\n\n    function _positionManagerForTests() internal view override returns (IPositionManager) {\n        return ponsPositionManager;\n    }\n\n    /// @dev Activate the SE")
old = old.replace("creatorTaxBps: 0,", "creatorTaxBps: 100,")
target = BASE / "test/bases" / ("TestBase_" + P + "_Launch.sol")
assert not target.exists()
target.write_text(old)

path = TEST / "CoreSettlement.t.sol"
text = path.read_text()
text = text.replace('import {CraneTest} from "@crane/contracts/test/CraneTest.sol";',
    'import {TestBase_' + P + '} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_' + P + '.sol";')
text = text.replace("is CraneTest, IUnlockCallback", "is TestBase_" + P + ", IUnlockCallback")
start = text.index("        manager = IPoolManager(create3Factory.create3WithArgs(")
end = text.index("        ERC20PermitMintableStub a", start)
text = text[:start] + "        manager = poolManager;\n" + text[end:]
text = text.replace("fee: 3_000, tickSpacing: 60, hooks: IHooks(address(0))", "fee: 0, tickSpacing: 60, hooks: IHooks(address(ponsHook))")
text = text.replace("        manager.initialize(key, TickMath.getSqrtPriceAtTick(120));", "        _registerKey();\n        manager.initialize(key, TickMath.getSqrtPriceAtTick(120));", 1)
text = text.replace("key.fee = 500;", "_freshKey(60);")
text = text.replace("key.tickSpacing = 1;\n        _freshKey(60);", "_freshKey(1);")
text = text.replace("Pool.tickSpacingToMaxLiquidityPerTick(60)", "Pool.tickSpacingToMaxLiquidityPerTick(key.tickSpacing)")
text = text.replace("uint256 feePips = uint256(500) + 3_000 - uint256(500) * 3_000 / 1_000_000;", "uint256 feePips = 500;")
pos = text.index("    function _compositionSettlement(")
text = text[:pos] + '''    function _registerKey() internal {
        ponsHook.registerPool(key, Currency.unwrap(key.currency1), address(this), address(this),
            100, false, ponsHook.currentFeePolicy());
    }

    function _freshKey(int24 spacing_) internal {
        ERC20PermitMintableStub a = new ERC20PermitMintableStub("Fresh A", "A", 18, address(this), 1e32);
        ERC20PermitMintableStub b = new ERC20PermitMintableStub("Fresh B", "B", 18, address(this), 1e32);
        key = PoolKey(Currency.wrap(address(a) < address(b) ? address(a) : address(b)),
            Currency.wrap(address(a) < address(b) ? address(b) : address(a)), 0, spacing_, IHooks(address(ponsHook)));
        lower = TickMath.minUsableTick(spacing_); upper = TickMath.maxUsableTick(spacing_);
        _registerKey();
    }

''' + text[pos:]
path.write_text(text)
print("Adapted P test names, core settlement controls, and independent real launch fixture.")
