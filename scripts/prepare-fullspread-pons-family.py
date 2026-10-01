"""One-shot mechanical family split; refuses to overwrite existing P files."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
H = "UniswapV4FullSpreadHooklessStandardExchangeVault"
P = "UniswapV4FullSpreadPonsFamilyHook"
BASE = "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/"
PURE = ("InventoryMath", "ProtectionMath", "RouteTypes")

def transform(text):
    text = text.replace(H, P).replace("fullSpread/hookless/", "fullSpread/ponsFamilyV2Hook/")
    for suffix in PURE:
        text = text.replace(P + suffix, H + suffix)
        text = text.replace('"./' + H + suffix + '.sol"', '"../hookless/' + H + suffix + '.sol"')
        text = text.replace(BASE + "ponsFamilyV2Hook/" + H + suffix, BASE + "hookless/" + H + suffix)
    text = text.replace("fullspread.hookless", "fullspread.ponsFamilyV2Hook")
    return text

def main():
    source = ROOT / BASE / "hookless"
    destination = ROOT / BASE / "ponsFamilyV2Hook"
    files = []
    for path in sorted(source.rglob("*.sol")):
        if path.stem in {H + suffix for suffix in PURE}:
            continue
        target = destination / str(path.relative_to(source)).replace(H, P)
        files.append((target, transform(path.read_text())))
    tests = ROOT / "test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread"
    for path in sorted((tests / "hookless").glob("*.sol")):
        files.append((tests / "ponsFamilyV2Hook" / path.name, transform(path.read_text())))
    for target, _ in files:
        if target.exists():
            raise SystemExit(f"Refusing overwrite: {target}")
    for target, text in files:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text)
    print(f"Prepared {len(files)} independent P source/test files; Pons-specific adaptation required.")

if __name__ == "__main__":
    main()
