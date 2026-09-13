#!/usr/bin/env python3
"""Generate IndexedEx non-18-decimal clones for plan steps 24–26.

Does not edit gold 18-dec files. New TestBases next to gold; suites under decimals/.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

TWO_TOKEN = [
    ("H6", 6, 6),
    ("H9", 9, 9),
    ("P6_R18", 6, 18),
    ("P18_R6", 18, 6),
    ("P9_R18", 9, 18),
    ("P18_R9", 18, 9),
    ("P6_R9", 6, 9),
    ("P9_R6", 9, 6),
]

# pair, other, rest
BOOKS = [
    ("B_ALL6", 6, 6, 6),
    ("B_ALL9", 9, 9, 9),
    ("B_P6_R18", 6, 18, 18),
    ("B_P18_R6", 18, 6, 18),
    ("B_P9_R18", 9, 18, 18),
    ("B_P18_R9", 18, 9, 18),
    ("B_P6_R9", 6, 9, 18),
    ("B_P9_R6", 9, 6, 18),
]


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not content.endswith("\n"):
        content += "\n"
    path.write_text(content)


def combo_natspec(combo: str, pair_d: int, rate_d: int) -> str:
    return (
        f"/// @notice Combo `{combo}`. pairToken {pair_d}-dec; rateAsset {rate_d}-dec.\n"
        "/// @dev After Aerodrome pool address sort, token0/token1 may swap; roles stay pairToken vs rateAsset.\n"
        "///      vaultShare / detfToken / rebasingClaimToken / Bond NFT stay 18."
    )


def book_natspec(book: str, pair_d: int, other_d: int, rest_d: int) -> str:
    return (
        f"/// @notice Book `{book}`. pairToken {pair_d}-dec; one other raw leg {other_d}-dec; remaining {rest_d}-dec.\n"
        "/// @dev Remaining-18: B_P18_R6 is 18,6,18 not homogeneous rest. vaultShare / detfToken / claim / Bond NFT stay 18."
    )


def thin_combo_contract(name: str, parent: str, import_path: str, combo: str, pair_d: int, rate_d: int) -> str:
    return f"""// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {{{parent}}} from "{import_path}";

{combo_natspec(combo, pair_d, rate_d)}
contract {name} is {parent} {{
    function _pairDecimals() internal pure override returns (uint8) {{
        return {pair_d};
    }}

    function _rateDecimals() internal pure override returns (uint8) {{
        return {rate_d};
    }}
}}
"""


def thin_book_contract(name: str, parent: str, import_path: str, book: str, pair_d: int, other_d: int, rest_d: int) -> str:
    return f"""// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {{{parent}}} from "{import_path}";

{book_natspec(book, pair_d, other_d, rest_d)}
contract {name} is {parent} {{
    function _pairDecimals() internal pure override returns (uint8) {{
        return {pair_d};
    }}

    function _rateDecimals() internal pure override returns (uint8) {{
        return {other_d};
    }}

    function _restDecimals() internal pure override returns (uint8) {{
        return {rest_d};
    }}
}}
"""


def rewrite_suite_source(
    src: str,
    gold_contract: str,
    abstract_name: str,
    new_base: str,
    old_bases: list[str],
    extra_replacements: list[tuple[str, str]] | None = None,
) -> str:
    """Turn a gold concrete suite into a decimals abstract that inherits `new_base`."""
    out = src
    # Drop gold TestBase imports that we replace.
    out = re.sub(
        r'import\s*\{[^}]*TestBase_SingleStandardExchangeDETF[^}]*\}\s*from\s*"[^"]+";\n',
        "",
        out,
    )
    out = re.sub(
        r'import\s*\{[^}]*TestBase_MultiVaultWeightedDetf[^}]*\}\s*from\s*"[^"]+";\n',
        "",
        out,
    )
    out = re.sub(
        r'import\s*\{[^}]*TestBase_MixedBufferMultiVaultStableDetf[^}]*\}\s*from\s*"[^"]+";\n',
        "",
        out,
    )
    out = re.sub(
        r'import\s*\{[^}]*ComposedStableCommonDetf_IntegratedDeploy_Test[^}]*\}\s*from\s*"[^"]+";\n',
        "",
        out,
    )
    out = re.sub(
        r'import\s*\{[^}]*TestBase_StandardExchangeBufferPool[^}]*\}\s*from\s*"[^"]+";\n',
        "",
        out,
    )
    out = re.sub(
        r'import\s*\{[^}]*TestBase_CommonBufferMultiVaultWeightedPool[^}]*\}\s*from\s*"[^"]+";\n',
        "",
        out,
    )
    out = re.sub(
        r'import\s*\{[^}]*TestBase_MixedLegWeightedBufferPool[^}]*\}\s*from\s*"[^"]+";\n',
        "",
        out,
    )
    out = re.sub(
        r'import\s*\{[^}]*TestBase_MultiPairStandardExchangeBufferPool[^}]*\}\s*from\s*"[^"]+";\n',
        "",
        out,
    )
    out = re.sub(
        r'import\s*\{[^}]*TestBase_CommonBufferMultiVaultStablePool[^}]*\}\s*from\s*"[^"]+";\n',
        "",
        out,
    )
    out = re.sub(
        r'import\s*\{[^}]*TestBase_MixedBufferMultiVaultStablePool[^}]*\}\s*from\s*"[^"]+";\n',
        "",
        out,
    )
    out = re.sub(
        r'import\s*\{[^}]*TestBase_MixedBufferMultiVaultStable_UniV2[^}]*\}\s*from\s*"[^"]+";\n',
        "",
        out,
    )

    # Insert new base import after pragma.
    import_line = f'import {{{new_base}}} from "__NEW_BASE_PATH__";\n'
    if "pragma solidity" in out:
        out = re.sub(
            r"(pragma solidity[^;]+;\n)",
            r"\1\n" + import_line,
            out,
            count=1,
        )

    # Contract declaration: make abstract, rename, swap bases.
    def _repl_contract(m: re.Match) -> str:
        rest_is = m.group(2) or ""
        bases = [b.strip() for b in rest_is.split(",") if b.strip()]
        filtered = []
        for b in bases:
            skip = False
            for old in old_bases:
                if b.split("{")[0].strip() == old or b.startswith(old + " ") or b == old:
                    skip = True
                    break
            if not skip:
                filtered.append(b)
        new_bases = [new_base] + filtered
        return f"abstract contract {abstract_name} is {', '.join(new_bases)} "

    out = re.sub(
        rf"(abstract\s+)?contract\s+{re.escape(gold_contract)}\s+is\s+([^{{]+)",
        _repl_contract,
        out,
        count=1,
    )

    # Role substitution: Crane dai/usdc → combo tokens. Word-boundary, skip comments already using roles.
    out = re.sub(r"\baddress\(dai\)", "address(rateAsset)", out)
    out = re.sub(r"\baddress\(usdc\)", "address(pairToken)", out)
    out = re.sub(r"\bdai\.", "rateAsset.", out)
    out = re.sub(r"\busdc\.", "pairToken.", out)
    out = re.sub(r"\bdai,", "rateAsset,", out)
    out = re.sub(r"\busdc,", "pairToken,", out)
    out = re.sub(r"\bdai\)", "rateAsset)", out)
    out = re.sub(r"\busdc\)", "pairToken)", out)
    # leftover bare dai/usdc as standalone tokens in expressions
    out = re.sub(r"(?<![\w.])dai(?![\w])", "rateAsset", out)
    out = re.sub(r"(?<![\w.])usdc(?![\w])", "pairToken", out)

    if extra_replacements:
        for a, b in extra_replacements:
            out = out.replace(a, b)
    return out


# ---------------------------------------------------------------------------
# Step 24 TestBase
# ---------------------------------------------------------------------------

SSE_TB_PATH = ROOT / "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF.sol"


def gen_sse_testbase() -> None:
    gold = SSE_TB_PATH.read_text()
    out = gold
    out = out.replace(
        "import {IRouter} from \"@crane/contracts/interfaces/protocols/dexes/aerodrome/IRouter.sol\";\n",
        "import {IRouter} from \"@crane/contracts/interfaces/protocols/dexes/aerodrome/IRouter.sol\";\n"
        "import {IPool} from \"@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol\";\n"
        "import {Pool} from \"@crane/contracts/protocols/dexes/aerodrome/v1/stubs/Pool.sol\";\n"
        "import {MintableERC20Decimals} from \"contracts/test/stubs/MintableERC20Decimals.sol\";\n"
        "import {TestBase_BalancerV3Vault} from\n"
        "    \"@crane/contracts/protocols/dexes/balancer/v3/test/bases/TestBase_BalancerV3Vault.sol\";\n"
        "import {IndexedexTest} from \"contracts/test/IndexedexTest.sol\";\n"
        "import {IERC20 as OZIERC20} from \"@crane/contracts/interfaces/IERC20.sol\";\n",
    )
    out = out.replace(
        "/// @title TestBase_SingleStandardExchangeDETF\n"
        "/// @notice Deploys production SingleStandardExchangeDETF against a production SE vault.\n"
        "/// @dev Default provider: Aerodrome Standard Exchange vault from Balancer SE router TestBase\n"
        "///      (local production packages — no MockStandardExchange).\n"
        "abstract contract TestBase_SingleStandardExchangeDETF is TestBase_BalancerV3StandardExchangeRouter {",
        "/// @title TestBase_SingleStandardExchangeDETF_Decimals\n"
        "/// @notice Single SE DETF with combo-decimal pair/rate underlyings. Does not edit gold TestBase.\n"
        "/// @dev Copy of gold setUp; does not call parent setUp that wires Crane 18-dec dai/usdc as the SE book.\n"
        "///      pairToken / rateAsset are MintableERC20Decimals. vaultShare / detfToken / claim / Bond NFT stay 18.\n"
        "///      Crane usdc 18 is not 6-dec coverage. After Aerodrome address sort, roles stay pairToken vs rateAsset.\n"
        "abstract contract TestBase_SingleStandardExchangeDETF_Decimals is TestBase_BalancerV3StandardExchangeRouter {",
    )
    out = out.replace(
        "    IERC20 internal rateTargetToken;\n\n"
        "    address internal detf;",
        "    IERC20 internal rateTargetToken;\n"
        "    MintableERC20Decimals internal pairToken;\n"
        "    MintableERC20Decimals internal rateAsset;\n\n"
        "    function _pairDecimals() internal pure virtual returns (uint8);\n"
        "    function _rateDecimals() internal pure virtual returns (uint8);\n\n"
        "    /// @dev Map an 18-dec gold wad onto `token` decimals. Floor at 1 raw unit.\n"
        "    function _from18(address token, uint256 wad) internal view returns (uint256 raw) {\n"
        "        uint8 d = MintableERC20Decimals(token).decimals();\n"
        "        if (d == 18) return wad;\n"
        "        if (d > 18) return wad * (10 ** (uint256(d) - 18));\n"
        "        raw = wad / (10 ** (18 - uint256(d)));\n"
        "        if (raw == 0) raw = 1;\n"
        "    }\n\n"
        "    function _uPair(uint256 human) internal pure returns (uint256) {\n"
        "        return human * (10 ** uint256(_pairDecimals()));\n"
        "    }\n\n"
        "    function _uRate(uint256 human) internal pure returns (uint256) {\n"
        "        return human * (10 ** uint256(_rateDecimals()));\n"
        "    }\n\n"
        "    address internal detf;",
    )
    old_setup = """    function setUp() public virtual override {
        super.setUp();

        // Production SE attachment from router base (Aerodrome dai/usdc vault).
        seVault = daiUsdcVault;
        seShare = IERC20(address(daiUsdcVault));
        rateTargetToken = IERC20(address(dai));
"""
    new_setup = """    function setUp() public virtual override {
        TestBase_BalancerV3Vault.setUp();
        IndexedexTest.setUp();

        pairToken = new MintableERC20Decimals("Pair", "PAIR", _pairDecimals());
        rateAsset = new MintableERC20Decimals("Rate", "RATE", _rateDecimals());
        vm.label(address(pairToken), "pairToken");
        vm.label(address(rateAsset), "rateAsset");

        _deployRouterFacets();
        _deployRouterPackage();
        _deployRouter();
        _approveRouterForAllUsers();
        _createTestPools();
        _deployAerodromeInfrastructure();
        _deployVaultFacets();
        _deployAerodromeVaultPackage();
        _createComboAerodromePoolAndVault();

        seVault = daiUsdcVault;
        seShare = IERC20(address(daiUsdcVault));
        rateTargetToken = IERC20(address(rateAsset));
"""
    if old_setup not in out:
        raise SystemExit("SSE setUp block not found")
    out = out.replace(old_setup, new_setup)

    fund_old = """    /// @dev Fund `to` with production SE vault shares via deposit path.
    function _fundSeShares(address to, uint256 lpAmount) internal returns (uint256 shares_) {
        shares_ = _depositToVault(to, lpAmount);
    }
"""
    fund_new = """    /// @dev Fund `to` with production SE vault shares via deposit path.
    ///      `lpAmount` is an 18-dec gold wad; pair/rate mints are native units (`human * 10**decimals`).
    function _fundSeShares(address to, uint256 lpAmount) internal returns (uint256 shares_) {
        uint256 amtPair = _from18(address(pairToken), lpAmount);
        uint256 amtRate = _from18(address(rateAsset), lpAmount);
        pairToken.mint(to, amtPair);
        rateAsset.mint(to, amtRate);
        vm.startPrank(to);
        pairToken.approve(address(aerodromeRouter), amtPair);
        rateAsset.approve(address(aerodromeRouter), amtRate);
        (,, uint256 liquidity) = aerodromeRouter.addLiquidity(
            address(pairToken), address(rateAsset), false, amtPair, amtRate, 1, 1, to, block.timestamp + 1 hours
        );
        OZIERC20(address(aeroDaiUsdcPool)).approve(address(daiUsdcVault), liquidity);
        shares_ = daiUsdcVault.deposit(liquidity, to);
        vm.stopPrank();
    }

    function _createComboAerodromePoolAndVault() internal {
        uint256 initPair = _from18(address(pairToken), AERODROME_POOL_INIT_AMOUNT);
        uint256 initRate = _from18(address(rateAsset), AERODROME_POOL_INIT_AMOUNT);
        address poolAddr = aerodromePoolFactory.createPool(address(pairToken), address(rateAsset), false);
        aeroDaiUsdcPool = Pool(poolAddr);
        vm.label(address(aeroDaiUsdcPool), "AeroPairRatePool");
        pairToken.mint(lp, initPair);
        rateAsset.mint(lp, initRate);
        vm.startPrank(lp);
        pairToken.approve(address(aerodromeRouter), initPair);
        rateAsset.approve(address(aerodromeRouter), initRate);
        aerodromeRouter.addLiquidity(
            address(pairToken),
            address(rateAsset),
            false,
            initPair,
            initRate,
            1,
            1,
            lp,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        address vaultAddr = aerodromeStandardExchangeDFPkg.deployVault(IPool(address(aeroDaiUsdcPool)));
        daiUsdcVault = IStandardExchangeProxy(vaultAddr);
        vm.label(vaultAddr, "PairRateSeVault");
        _approveVaultForAllUsers();
    }
"""
    if fund_old not in out:
        raise SystemExit("SSE _fundSeShares not found")
    out = out.replace(fund_old, fund_new)

    out = out.replace(
        "        assertEq(IERC20(address(dai)).balanceOf(instance_), 0, \"residual dai\");\n"
        "        assertEq(IERC20(address(usdc)).balanceOf(instance_), 0, \"residual usdc\");",
        "        assertEq(IERC20(address(rateAsset)).balanceOf(instance_), 0, \"residual rateAsset\");\n"
        "        assertEq(IERC20(address(pairToken)).balanceOf(instance_), 0, \"residual pairToken\");",
    )
    out = out.replace(
        """    function _shiftUnderlyingPrice(bool buyUsdc_, uint256 amountIn_) internal {
        address trader_ = bob;
        address tokenIn_ = buyUsdc_ ? address(dai) : address(usdc);
        address tokenOut_ = buyUsdc_ ? address(usdc) : address(dai);
        if (buyUsdc_) {
            dai.mint(trader_, amountIn_);
        } else {
            usdc.mint(trader_, amountIn_);
        }
""",
        """    function _shiftUnderlyingPrice(bool buyUsdc_, uint256 amountIn_) internal {
        address trader_ = bob;
        address tokenIn_ = buyUsdc_ ? address(rateAsset) : address(pairToken);
        address tokenOut_ = buyUsdc_ ? address(pairToken) : address(rateAsset);
        uint256 amtIn_ = _from18(tokenIn_, amountIn_);
        if (buyUsdc_) {
            rateAsset.mint(trader_, amtIn_);
        } else {
            pairToken.mint(trader_, amtIn_);
        }
        amountIn_ = amtIn_;
""",
    )
    dest = SSE_TB_PATH.with_name("TestBase_SingleStandardExchangeDETF_Decimals.sol")
    write(dest, out)
    for combo, pd, rd in TWO_TOKEN:
        write(
            SSE_TB_PATH.with_name(f"TestBase_SingleStandardExchangeDETF_{combo}.sol"),
            f"""// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {{TestBase_SingleStandardExchangeDETF_Decimals}} from
    "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF_Decimals.sol";

{combo_natspec(combo, pd, rd)}
abstract contract TestBase_SingleStandardExchangeDETF_{combo} is TestBase_SingleStandardExchangeDETF_Decimals {{
    function _pairDecimals() internal pure override returns (uint8) {{
        return {pd};
    }}

    function _rateDecimals() internal pure override returns (uint8) {{
        return {rd};
    }}
}}
""",
        )


def clone_suites(
    gold_files: list[Path],
    decimals_dir: Path,
    new_base: str,
    new_base_path: str,
    old_bases: list[str],
    skip_names: set[str],
    two_token: bool,
) -> None:
    for gold in gold_files:
        if gold.name in skip_names:
            continue
        src = gold.read_text()
        m = re.search(r"(?:abstract\s+)?contract\s+(\w+)\s+is\s+", src)
        if not m:
            print("skip no contract", gold)
            continue
        gold_contract = m.group(1)
        if gold_contract.endswith("_Decimals"):
            continue
        abstract_name = gold_contract
        if abstract_name.endswith("_Test"):
            abstract_name = abstract_name[: -len("_Test")] + "_Decimals"
        elif abstract_name.endswith("Invariant"):
            abstract_name = abstract_name + "_Decimals"
        else:
            abstract_name = abstract_name + "_Decimals"
        sub = ""
        if gold.parent.name in ("adversarial", "fuzz", "invariant", "sequences", "uniswapV2", "formula", "comparative"):
            sub = gold.parent.name + "/"
        file_stem = gold.name
        for suffix in (".invariant.t.sol", ".spec.t.sol", ".t.sol", ".sol"):
            if file_stem.endswith(suffix):
                file_stem = file_stem[: -len(suffix)]
                break
        dest_abstract = decimals_dir / f"{sub}{file_stem}_Decimals.sol"
        rewritten = rewrite_suite_source(src, gold_contract, abstract_name, new_base, old_bases)
        rewritten = rewritten.replace("__NEW_BASE_PATH__", new_base_path)
        # Handler files: keep as non-abstract if they are handlers without tests
        if gold.name.startswith("Handler_"):
            rewritten = rewritten.replace(f"abstract contract {abstract_name}", f"contract {abstract_name}")
            write(decimals_dir / f"{sub}{file_stem}_Decimals.sol", rewritten)
            continue
        write(dest_abstract, rewritten)
        import_path = str(dest_abstract.relative_to(ROOT)).replace("\\", "/")
        stem = file_stem
        if two_token:
            for combo, pd, rd in TWO_TOKEN:
                write(
                    decimals_dir / f"{sub}{stem}_{combo}.t.sol",
                    thin_combo_contract(
                        f"{stem}_{combo}" if not stem.endswith("_Test") else f"{stem[:-5]}_{combo}",
                        abstract_name,
                        import_path,
                        combo,
                        pd,
                        rd,
                    ),
                )
        else:
            for book, pd, od, rest in BOOKS:
                write(
                    decimals_dir / f"{sub}{stem}_{book}.t.sol",
                    thin_book_contract(
                        f"{stem}_{book}" if not stem.endswith("_Test") else f"{stem[:-5]}_{book}",
                        abstract_name,
                        import_path,
                        book,
                        pd,
                        od,
                        rest,
                    ),
                )


def list_sol_tests(folder: Path, skip: set[str]) -> list[Path]:
    out = []
    for p in sorted(folder.rglob("*.sol")):
        if "decimals" in p.parts:
            continue
        if p.name in skip:
            continue
        if p.name.endswith("Facet_IFacet_Test.t.sol"):
            continue
        if p.name == "Adversarial_Surface.t.sol":
            continue
        out.append(p)
    return out


def gen_step24() -> None:
    gen_sse_testbase()
    gold_dir = ROOT / "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single"
    decimals_dir = gold_dir / "decimals"
    skip = {
        "SingleStandardExchangeDETFExchangeInFacet_IFacet_Test.t.sol",
        "Adversarial_Surface.t.sol",
        "IStandardExchangeVaultProvider.sol",
    }
    files = [p for p in list_sol_tests(gold_dir, skip) if p.suffix == ".sol"]
    # Adversarial TestBase is abstract helper — clone it too
    clone_suites(
        files,
        decimals_dir,
        "TestBase_SingleStandardExchangeDETF_Decimals",
        "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF_Decimals.sol",
        [
            "TestBase_SingleStandardExchangeDETF",
            "TestBase_SingleStandardExchangeDETF_Adversarial",
            "ComposedStableCommonDetf_IntegratedDeploy_Test",
        ],
        skip,
        True,
    )
    # Adversarial suites inherit the gold adversarial TestBase; point them at decimal adversarial abstract.
    adv_tb_gold = gold_dir / "adversarial/TestBase_SingleStandardExchangeDETF_Adversarial.sol"
    if adv_tb_gold.exists():
        src = adv_tb_gold.read_text()
        rewritten = rewrite_suite_source(
            src,
            "TestBase_SingleStandardExchangeDETF_Adversarial",
            "TestBase_SingleStandardExchangeDETF_Adversarial_Decimals",
            "TestBase_SingleStandardExchangeDETF_Decimals",
            ["TestBase_SingleStandardExchangeDETF"],
        )
        rewritten = rewritten.replace(
            "__NEW_BASE_PATH__",
            "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF_Decimals.sol",
        )
        write(decimals_dir / "adversarial/TestBase_SingleStandardExchangeDETF_Adversarial_Decimals.sol", rewritten)
        # Fix adversarial suites to inherit decimal adversarial base
        for p in (decimals_dir / "adversarial").glob("*_Decimals.sol"):
            t = p.read_text()
            if "TestBase_SingleStandardExchangeDETF_Adversarial_Decimals" in t:
                continue
            if "TestBase_SingleStandardExchangeDETF_Adversarial" in t or "is TestBase_SingleStandardExchangeDETF_Decimals" in t:
                t = t.replace(
                    "TestBase_SingleStandardExchangeDETF_Decimals",
                    "TestBase_SingleStandardExchangeDETF_Adversarial_Decimals",
                )
                t = t.replace(
                    "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF_Decimals.sol",
                    "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/decimals/adversarial/TestBase_SingleStandardExchangeDETF_Adversarial_Decimals.sol",
                )
                p.write_text(t)


# ---------------------------------------------------------------------------
# Step 25 n-leg TestBases
# ---------------------------------------------------------------------------

MVW_TB = ROOT / "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol"
MB_TB = ROOT / "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol"


def patch_nleg_header(src: str, title: str, notice: str, contract: str) -> str:
    src = src.replace(
        "import {IRouter} from \"@crane/contracts/interfaces/protocols/dexes/aerodrome/IRouter.sol\";\n",
        "import {IRouter} from \"@crane/contracts/interfaces/protocols/dexes/aerodrome/IRouter.sol\";\n"
        "import {MintableERC20Decimals} from \"contracts/test/stubs/MintableERC20Decimals.sol\";\n"
        "import {TestBase_BalancerV3Vault} from\n"
        "    \"@crane/contracts/protocols/dexes/balancer/v3/test/bases/TestBase_BalancerV3Vault.sol\";\n"
        "import {IndexedexTest} from \"contracts/test/IndexedexTest.sol\";\n",
        1,
    )
    src = re.sub(
        r"abstract contract TestBase_\w+ is TestBase_BalancerV3StandardExchangeRouter \{",
        f"abstract contract {contract} is TestBase_BalancerV3StandardExchangeRouter {{",
        src,
        count=1,
    )
    src = re.sub(r"/// @title TestBase_\w+", f"/// @title {title}", src, count=1)
    src = re.sub(r"/// @notice [^\n]+", f"/// @notice {notice}", src, count=1)
    return src


NLEG_DEC_HELPERS = """
    MintableERC20Decimals internal pairToken;
    MintableERC20Decimals internal rateAsset;
    MintableERC20Decimals internal otherToken;
    MintableERC20Decimals internal restToken;

    function _pairDecimals() internal pure virtual returns (uint8);
    function _rateDecimals() internal pure virtual returns (uint8);
    function _restDecimals() internal pure virtual returns (uint8) {
        return 18;
    }

    function _from18(address token, uint256 wad) internal view returns (uint256 raw) {
        uint8 d = MintableERC20Decimals(token).decimals();
        if (d == 18) return wad;
        if (d > 18) return wad * (10 ** (uint256(d) - 18));
        raw = wad / (10 ** (18 - uint256(d)));
        if (raw == 0) raw = 1;
    }

    function _mintCombo(MintableERC20Decimals token, address to, uint256 wad18) internal {
        token.mint(to, _from18(address(token), wad18));
    }

    function _initComboTokens() internal {
        pairToken = new MintableERC20Decimals("Pair", "PAIR", _pairDecimals());
        rateAsset = new MintableERC20Decimals("Rate", "RATE", _rateDecimals());
        otherToken = rateAsset;
        restToken = new MintableERC20Decimals("Rest", "REST", _restDecimals());
        vm.label(address(pairToken), "pairToken");
        vm.label(address(rateAsset), "rateAsset");
        vm.label(address(restToken), "restToken");
    }
"""


def gen_mvw_testbase() -> None:
    gold = MVW_TB.read_text()
    out = patch_nleg_header(
        gold,
        "TestBase_MultiVaultWeightedDetf_Decimals",
        "Multi-vault weighted DETF with B_* book underlyings. No MockStandardExchange. Remaining-18 books are not homogeneous rest.",
        "TestBase_MultiVaultWeightedDetf_Decimals",
    )
    # Insert helpers after seVaultReady
    needle = "    uint8 internal seVaultReady; // how many legs deployed\n"
    if needle not in out:
        raise SystemExit("mvw seVaultReady not found")
    out = out.replace(needle, needle + NLEG_DEC_HELPERS)
    old_setup = """    function setUp() public virtual override {
        super.setUp();
"""
    new_setup = """    function setUp() public virtual override {
        TestBase_BalancerV3Vault.setUp();
        IndexedexTest.setUp();
        _initComboTokens();
        _deployRouterFacets();
        _deployRouterPackage();
        _deployRouter();
        _approveRouterForAllUsers();
        _createTestPools();
        _deployAerodromeInfrastructure();
        _deployVaultFacets();
        _deployAerodromeVaultPackage();
        _createComboFirstSeVault();
"""
    if old_setup not in out:
        raise SystemExit("mvw setUp not found")
    out = out.replace(old_setup, new_setup, 1)
    # Replace _deploySeVaultAt index 0 to use combo vault
    out = out.replace(
        """        if (index == 0) {
            seVaults[0] = daiUsdcVault;
            seShares[0] = IERC20(address(daiUsdcVault));
            rateAssets[0] = IERC20(address(dai));
            legTokenA[0] = address(dai);
            legTokenB[0] = address(usdc);
            legStable[0] = false;
            vm.label(address(seVaults[0]), "SeVault0_DaiUsdc");
            return;
        }
""",
        """        if (index == 0) {
            seVaults[0] = daiUsdcVault;
            seShares[0] = IERC20(address(daiUsdcVault));
            rateAssets[0] = IERC20(address(rateAsset));
            legTokenA[0] = address(pairToken);
            legTokenB[0] = address(rateAsset);
            legStable[0] = false;
            vm.label(address(seVaults[0]), "SeVault0_PairRate");
            return;
        }
""",
    )
    out = out.replace(
        """        if (address(extraToken0) == address(0)) {
            extraToken0 = new MockERC20("Extra0", "EX0", 18);
            extraToken1 = new MockERC20("Extra1", "EX1", 18);
        }
""",
        """        if (address(extraToken0) == address(0)) {
            extraToken0 = MockERC20(address(new MintableERC20Decimals("Extra0", "EX0", _restDecimals())));
            extraToken1 = MockERC20(address(new MintableERC20Decimals("Extra1", "EX1", _restDecimals())));
        }
""",
    )
    # token mapping for extra legs: avoid weth as non-18; use combo tokens
    out = out.replace(
        """        if (index == 1) {
            tokenA_ = address(dai);
            tokenB_ = address(weth);
            rate_ = IERC20(address(weth));
        } else if (index == 2) {
            tokenA_ = address(usdc);
            tokenB_ = address(weth);
            rate_ = IERC20(address(usdc));
        } else if (index == 3) {
            tokenA_ = address(extraToken0);
            tokenB_ = address(dai);
            rate_ = IERC20(address(dai));
        } else if (index == 4) {
            tokenA_ = address(extraToken0);
            tokenB_ = address(usdc);
            rate_ = IERC20(address(usdc));
        } else if (index == 5) {
            tokenA_ = address(extraToken0);
            tokenB_ = address(weth);
            rate_ = IERC20(address(weth));
        } else {
            tokenA_ = address(extraToken1);
            tokenB_ = address(dai);
            rate_ = IERC20(address(dai));
        }

        address poolAddr = aerodromePoolFactory.createPool(tokenA_, tokenB_, false);
        _seedPoolLiquidity(tokenA_, tokenB_, false, 1_000e18);
""",
        """        if (index == 1) {
            tokenA_ = address(rateAsset);
            tokenB_ = address(restToken);
            rate_ = IERC20(address(rateAsset));
        } else if (index == 2) {
            tokenA_ = address(pairToken);
            tokenB_ = address(restToken);
            rate_ = IERC20(address(pairToken));
        } else if (index == 3) {
            tokenA_ = address(extraToken0);
            tokenB_ = address(rateAsset);
            rate_ = IERC20(address(rateAsset));
        } else if (index == 4) {
            tokenA_ = address(extraToken0);
            tokenB_ = address(pairToken);
            rate_ = IERC20(address(pairToken));
        } else if (index == 5) {
            tokenA_ = address(extraToken0);
            tokenB_ = address(restToken);
            rate_ = IERC20(address(restToken));
        } else {
            tokenA_ = address(extraToken1);
            tokenB_ = address(rateAsset);
            rate_ = IERC20(address(rateAsset));
        }

        address poolAddr = aerodromePoolFactory.createPool(tokenA_, tokenB_, false);
        _seedPoolLiquidity(tokenA_, tokenB_, false, 1_000e18);
""",
    )
    out = out.replace(
        """        args.rateAssets[0] = IERC20(address(dai));
        args.rateAssets[1] = IERC20(address(dai));
""",
        """        args.rateAssets[0] = IERC20(address(rateAsset));
        args.rateAssets[1] = IERC20(address(rateAsset));
""",
    )
    helper = """
    function _createComboFirstSeVault() internal {
        uint256 initPair = _from18(address(pairToken), AERODROME_POOL_INIT_AMOUNT);
        uint256 initRate = _from18(address(rateAsset), AERODROME_POOL_INIT_AMOUNT);
        address poolAddr = aerodromePoolFactory.createPool(address(pairToken), address(rateAsset), false);
        aeroDaiUsdcPool = Pool(poolAddr);
        pairToken.mint(lp, initPair);
        rateAsset.mint(lp, initRate);
        vm.startPrank(lp);
        pairToken.approve(address(aerodromeRouter), initPair);
        rateAsset.approve(address(aerodromeRouter), initRate);
        aerodromeRouter.addLiquidity(
            address(pairToken), address(rateAsset), false, initPair, initRate, 1, 1, lp, block.timestamp + 1 hours
        );
        vm.stopPrank();
        address vaultAddr = aerodromeStandardExchangeDFPkg.deployVault(IPool(address(aeroDaiUsdcPool)));
        daiUsdcVault = IStandardExchangeProxy(vaultAddr);
        _approveVaultForAllUsers();
    }
"""
    # Pool import
    if "import {IPool}" not in out:
        out = out.replace(
            "import {IPool} from \"@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol\";\n",
            "import {IPool} from \"@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol\";\n"
            "import {Pool} from \"@crane/contracts/protocols/dexes/aerodrome/v1/stubs/Pool.sol\";\n",
            1,
        )
    out = out.rstrip() + "\n" + helper + "\n"
    write(MVW_TB.with_name("TestBase_MultiVaultWeightedDetf_Decimals.sol"), out)
    for book, pd, od, rest in BOOKS:
        write(
            MVW_TB.with_name(f"TestBase_MultiVaultWeightedDetf_{book}.sol"),
            f"""// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {{TestBase_MultiVaultWeightedDetf_Decimals}} from
    "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf_Decimals.sol";

{book_natspec(book, pd, od, rest)}
abstract contract TestBase_MultiVaultWeightedDetf_{book} is TestBase_MultiVaultWeightedDetf_Decimals {{
    function _pairDecimals() internal pure override returns (uint8) {{ return {pd}; }}
    function _rateDecimals() internal pure override returns (uint8) {{ return {od}; }}
    function _restDecimals() internal pure override returns (uint8) {{ return {rest}; }}
}}
""",
        )


def gen_mixedbuffer_testbase() -> None:
    gold = MB_TB.read_text()
    out = patch_nleg_header(
        gold,
        "TestBase_MixedBufferMultiVaultStableDetf_Decimals",
        "Mixed-buffer DETF with B_* books. Pair orientation is the documented pair buffer token. No MockStandardExchange.",
        "TestBase_MixedBufferMultiVaultStableDetf_Decimals",
    )
    needle = "    uint8 internal seVaultReady;\n"
    if needle not in out:
        raise SystemExit("mb seVaultReady not found")
    out = out.replace(needle, needle + NLEG_DEC_HELPERS)
    old_setup = """    function setUp() public virtual override {
        super.setUp();
"""
    new_setup = """    function setUp() public virtual override {
        TestBase_BalancerV3Vault.setUp();
        IndexedexTest.setUp();
        _initComboTokens();
        _deployRouterFacets();
        _deployRouterPackage();
        _deployRouter();
        _approveRouterForAllUsers();
        _createTestPools();
        _deployAerodromeInfrastructure();
        _deployVaultFacets();
        _deployAerodromeVaultPackage();
        _createComboFirstSeVault();
"""
    out = out.replace(old_setup, new_setup, 1)
    out = out.replace(
        """        seVaults[0] = daiUsdcVault;
        seShares[0] = IERC20(address(daiUsdcVault));
        legTokenA[0] = address(dai);
        legTokenB[0] = address(usdc);
""",
        """        seVaults[0] = daiUsdcVault;
        seShares[0] = IERC20(address(daiUsdcVault));
        legTokenA[0] = address(pairToken);
        legTokenB[0] = address(rateAsset);
""",
    )
    out = out.replace(
        """        address tokenA = address(dai);
        address tokenB = idx == 1 ? address(weth) : address(usdc);
        // For idx 2 use a fresh MockERC20 pair with DAI to avoid PoolAlreadyExists if usdc already used.
        if (idx == 2) {
            MockERC20 extra = new MockERC20("ExtraB", "EXB", 18);
            tokenB = address(extra);
        }
""",
        """        // Pair/buffer token is pairToken (documented mixed-buffer pair). Other legs use rate/rest.
        address tokenA = address(pairToken);
        address tokenB = idx == 1 ? address(rateAsset) : address(restToken);
        if (idx == 2) {
            tokenB = address(new MintableERC20Decimals("ExtraB", "EXB", _restDecimals()));
        }
""",
    )
    if "import {IPool}" not in out:
        out = out.replace(
            "import {IPool} from \"@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol\";\n",
            "import {IPool} from \"@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol\";\n",
            1,
        )
    helper = """
    function _createComboFirstSeVault() internal {
        uint256 initPair = _from18(address(pairToken), AERODROME_POOL_INIT_AMOUNT);
        uint256 initRate = _from18(address(rateAsset), AERODROME_POOL_INIT_AMOUNT);
        address poolAddr = aerodromePoolFactory.createPool(address(pairToken), address(rateAsset), false);
        aeroDaiUsdcPool = Pool(poolAddr);
        pairToken.mint(lp, initPair);
        rateAsset.mint(lp, initRate);
        vm.startPrank(lp);
        pairToken.approve(address(aerodromeRouter), initPair);
        rateAsset.approve(address(aerodromeRouter), initRate);
        aerodromeRouter.addLiquidity(
            address(pairToken), address(rateAsset), false, initPair, initRate, 1, 1, lp, block.timestamp + 1 hours
        );
        vm.stopPrank();
        address vaultAddr = aerodromeStandardExchangeDFPkg.deployVault(IPool(address(aeroDaiUsdcPool)));
        daiUsdcVault = IStandardExchangeProxy(vaultAddr);
        _approveVaultForAllUsers();
    }
"""
    out = out.rstrip() + "\n" + helper + "\n"
    write(MB_TB.with_name("TestBase_MixedBufferMultiVaultStableDetf_Decimals.sol"), out)
    for book, pd, od, rest in BOOKS:
        write(
            MB_TB.with_name(f"TestBase_MixedBufferMultiVaultStableDetf_{book}.sol"),
            f"""// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {{TestBase_MixedBufferMultiVaultStableDetf_Decimals}} from
    "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf_Decimals.sol";

{book_natspec(book, pd, od, rest)}
abstract contract TestBase_MixedBufferMultiVaultStableDetf_{book} is TestBase_MixedBufferMultiVaultStableDetf_Decimals {{
    function _pairDecimals() internal pure override returns (uint8) {{ return {pd}; }}
    function _rateDecimals() internal pure override returns (uint8) {{ return {od}; }}
    function _restDecimals() internal pure override returns (uint8) {{ return {rest}; }}
}}
""",
        )


def gen_composed_testbase() -> None:
    gold_path = ROOT / "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_IntegratedDeploy.t.sol"
    gold = gold_path.read_text()
    # Extract everything except the test_ functions into a TestBase next to family package.
    # Keep tests in decimals clones of this file.
    dest = ROOT / "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/TestBase_ComposedStableCommonDetf_Decimals.sol"
    out = gold
    out = out.replace(
        "contract ComposedStableCommonDetf_IntegratedDeploy_Test is TestBase_BalancerV3StandardExchangeRouter {",
        "abstract contract TestBase_ComposedStableCommonDetf_Decimals is TestBase_BalancerV3StandardExchangeRouter {",
    )
    out = out.replace(
        "import {ThresholdMode} from 'contracts/vaults/detf/common/core/DETFThresholdPolicy.sol';\n",
        "import {ThresholdMode} from 'contracts/vaults/detf/common/core/DETFThresholdPolicy.sol';\n"
        "import {MintableERC20Decimals} from 'contracts/test/stubs/MintableERC20Decimals.sol';\n"
        "import {IPool} from '@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol';\n"
        "import {Pool} from '@crane/contracts/protocols/dexes/aerodrome/v1/stubs/Pool.sol';\n"
        "import {TestBase_BalancerV3Vault} from\n"
        "    '@crane/contracts/protocols/dexes/balancer/v3/test/bases/TestBase_BalancerV3Vault.sol';\n"
        "import {IndexedexTest} from 'contracts/test/IndexedexTest.sol';\n",
    )
    # Insert combo fields after deployedDetfVault
    out = out.replace(
        "    address internal deployedDetfVault;\n",
        "    address internal deployedDetfVault;\n"
        "    MintableERC20Decimals internal pairToken;\n"
        "    MintableERC20Decimals internal rateAsset;\n"
        "    MintableERC20Decimals internal restToken;\n\n"
        "    function _pairDecimals() internal pure virtual returns (uint8);\n"
        "    function _rateDecimals() internal pure virtual returns (uint8);\n"
        "    function _restDecimals() internal pure virtual returns (uint8) { return 18; }\n\n"
        "    function _from18(address token, uint256 wad) internal view returns (uint256 raw) {\n"
        "        uint8 d = MintableERC20Decimals(token).decimals();\n"
        "        if (d == 18) return wad;\n"
        "        if (d > 18) return wad * (10 ** (uint256(d) - 18));\n"
        "        raw = wad / (10 ** (18 - uint256(d)));\n"
        "        if (raw == 0) raw = 1;\n"
        "    }\n",
    )
    out = out.replace(
        "    function setUp() public virtual override {\n        super.setUp();\n",
        "    function setUp() public virtual override {\n"
        "        TestBase_BalancerV3Vault.setUp();\n"
        "        IndexedexTest.setUp();\n"
        "        pairToken = new MintableERC20Decimals('Pair', 'PAIR', _pairDecimals());\n"
        "        rateAsset = new MintableERC20Decimals('Rate', 'RATE', _rateDecimals());\n"
        "        restToken = new MintableERC20Decimals('Rest', 'REST', _restDecimals());\n"
        "        _deployRouterFacets();\n"
        "        _deployRouterPackage();\n"
        "        _deployRouter();\n"
        "        _approveRouterForAllUsers();\n"
        "        _createTestPools();\n"
        "        _deployAerodromeInfrastructure();\n"
        "        _deployVaultFacets();\n"
        "        _deployAerodromeVaultPackage();\n"
        "        _createComboFirstSeVault();\n",
    )
    out = out.replace("baseToken: dai,", "baseToken: IERC20(address(rateAsset)),")
    out = out.replace("baseToken: dai", "baseToken: IERC20(address(rateAsset))")
    # Strip test functions from TestBase (keep helpers). Tests live in decimals clones of IntegratedDeploy.
    out = re.sub(r"\n    function test_[^\n]+\n(?:        .*\n)*?    \}\n", "\n", out)
    helper = """
    function _createComboFirstSeVault() internal {
        uint256 initPair = _from18(address(pairToken), AERODROME_POOL_INIT_AMOUNT);
        uint256 initRate = _from18(address(rateAsset), AERODROME_POOL_INIT_AMOUNT);
        address poolAddr = aerodromePoolFactory.createPool(address(pairToken), address(rateAsset), false);
        aeroDaiUsdcPool = Pool(poolAddr);
        pairToken.mint(lp, initPair);
        rateAsset.mint(lp, initRate);
        vm.startPrank(lp);
        pairToken.approve(address(aerodromeRouter), initPair);
        rateAsset.approve(address(aerodromeRouter), initRate);
        aerodromeRouter.addLiquidity(
            address(pairToken), address(rateAsset), false, initPair, initRate, 1, 1, lp, block.timestamp + 1 hours
        );
        vm.stopPrank();
        address vaultAddr = aerodromeStandardExchangeDFPkg.deployVault(IPool(address(aeroDaiUsdcPool)));
        daiUsdcVault = IStandardExchangeProxy(vaultAddr);
        _approveVaultForAllUsers();
    }
"""
    out = out.rstrip() + "\n" + helper + "\n"
    write(dest, out)
    for book, pd, od, rest in BOOKS:
        write(
            dest.with_name(f"TestBase_ComposedStableCommonDetf_{book}.sol"),
            f"""// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {{TestBase_ComposedStableCommonDetf_Decimals}} from
    "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/TestBase_ComposedStableCommonDetf_Decimals.sol";

{book_natspec(book, pd, od, rest)}
abstract contract TestBase_ComposedStableCommonDetf_{book} is TestBase_ComposedStableCommonDetf_Decimals {{
    function _pairDecimals() internal pure override returns (uint8) {{ return {pd}; }}
    function _rateDecimals() internal pure override returns (uint8) {{ return {od}; }}
    function _restDecimals() internal pure override returns (uint8) {{ return {rest}; }}
}}
""",
        )


def gen_step25() -> None:
    gen_mvw_testbase()
    gen_mixedbuffer_testbase()
    gen_composed_testbase()

    mvw_dir = ROOT / "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted"
    clone_suites(
        list_sol_tests(mvw_dir, {"MultiVaultWeightedDetfExchangeInFacet_IFacet_Test.t.sol", "Adversarial_Surface.t.sol"}),
        mvw_dir / "decimals",
        "TestBase_MultiVaultWeightedDetf_Decimals",
        "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf_Decimals.sol",
        ["TestBase_MultiVaultWeightedDetf", "TestBase_MultiVaultWeightedDetf_Adversarial"],
        set(),
        False,
    )
    mb_dir = ROOT / "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer"
    clone_suites(
        list_sol_tests(mb_dir, {"MixedBufferMultiVaultStableDetfExchangeInFacet_IFacet_Test.t.sol", "Adversarial_Surface.t.sol"}),
        mb_dir / "decimals",
        "TestBase_MixedBufferMultiVaultStableDetf_Decimals",
        "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf_Decimals.sol",
        ["TestBase_MixedBufferMultiVaultStableDetf", "TestBase_MixedBufferMultiVaultStableDetf_Adversarial"],
        set(),
        False,
    )
    cs_dir = ROOT / "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common"
    skip_cs = {
        "ComposedStableCommonDetfBondingFacet.t.sol",
        "ComposedStableCommonDetfBondNFTVaultDFPkg_Deploy.t.sol",
        "ComposedStableCommonDetfBurnExchangeIn.t.sol",
        "ComposedStableCommonDetfDFPkg_Deploy.t.sol",
        "ComposedStableCommonDetfExchangeIn.t.sol",
        "ComposedStableCommonDetfExchangeOutQueryFacet.t.sol",
        "RebasingDETFTokenBehavior.t.sol",
        "RebasingDETFTokenDFPkg_Deploy.t.sol",
        "RebasingDETFTokenFacet_IFacet_Test.t.sol",
        "RebasingDETFTokenPricingFacet_IFacet_Test.t.sol",
        "RebasingDETFTokenPricingTarget.t.sol",
        "Adversarial_Surface.t.sol",
        "E6Probe.t.sol",
    }
    clone_suites(
        [p for p in list_sol_tests(cs_dir, skip_cs) if "Mock" not in p.name and "Harness" not in p.name],
        cs_dir / "decimals",
        "TestBase_ComposedStableCommonDetf_Decimals",
        "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/TestBase_ComposedStableCommonDetf_Decimals.sol",
        [
            "ComposedStableCommonDetf_IntegratedDeploy_Test",
            "TestBase_ComposedStableCommonDetf",
            "TestBase_ComposedStableCommonDetf_Components",
        ],
        skip_cs,
        False,
    )


# ---------------------------------------------------------------------------
# Step 26 pool TestBases
# ---------------------------------------------------------------------------

CP_TB = ROOT / "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol"


def gen_cp_testbase() -> None:
    gold = CP_TB.read_text()
    out = gold
    out = out.replace(
        "import {IndexedexTest} from \"contracts/test/IndexedexTest.sol\";\n",
        "import {IndexedexTest} from \"contracts/test/IndexedexTest.sol\";\n"
        "import {MintableERC20Decimals} from \"contracts/test/stubs/MintableERC20Decimals.sol\";\n",
    )
    out = out.replace(
        "abstract contract TestBase_StandardExchangeBufferPool is TestBase_BalancerV3Vault, IndexedexTest {",
        "abstract contract TestBase_StandardExchangeBufferPool_Decimals is TestBase_BalancerV3Vault, IndexedexTest {",
    )
    out = out.replace(
        " * @title TestBase_StandardExchangeBufferPool\n",
        " * @title TestBase_StandardExchangeBufferPool_Decimals\n",
    )
    # add combo tokens after ttb
    out = out.replace(
        "    IERC20 public tta;\n    IERC20 public ttb;\n    IERC20 public shares;\n",
        "    IERC20 public tta;\n    IERC20 public ttb;\n    IERC20 public shares;\n"
        "    MintableERC20Decimals internal pairToken;\n"
        "    MintableERC20Decimals internal rateAsset;\n\n"
        "    function _pairDecimals() internal pure virtual returns (uint8);\n"
        "    function _rateDecimals() internal pure virtual returns (uint8);\n"
        "    function _restDecimals() internal pure virtual returns (uint8) { return 18; }\n\n"
        "    function _from18(address token, uint256 wad) internal view returns (uint256 raw) {\n"
        "        uint8 d = MintableERC20Decimals(token).decimals();\n"
        "        if (d == 18) return wad;\n"
        "        if (d > 18) return wad * (10 ** (uint256(d) - 18));\n"
        "        raw = wad / (10 ** (18 - uint256(d)));\n"
        "        if (raw == 0) raw = 1;\n"
        "    }\n",
    )
    # Create tokens at start of _deploySEVault
    out = out.replace(
        """    function _deploySEVault() internal virtual {
        // Deploy Aerodrome infrastructure.
        _deployAerodromeInfrastructure();
""",
        """    function _deploySEVault() internal virtual {
        pairToken = new MintableERC20Decimals("Pair", "PAIR", _pairDecimals());
        rateAsset = new MintableERC20Decimals("Rate", "RATE", _rateDecimals());
        vm.label(address(pairToken), "pairToken");
        vm.label(address(rateAsset), "rateAsset");
        _deployAerodromeInfrastructure();
""",
    )
    out = out.replace(
        "        address poolAddr = aeroPoolFactory.createPool(address(dai), address(usdc), false);\n",
        "        address poolAddr = aeroPoolFactory.createPool(address(pairToken), address(rateAsset), false);\n",
    )
    out = out.replace(
        "        tta = IERC20(address(dai));\n        ttb = IERC20(address(usdc));\n",
        "        tta = IERC20(address(pairToken));\n        ttb = IERC20(address(rateAsset));\n",
    )
    out = out.replace(
        """    function _seedAerodromeLiquidity() internal virtual {
        dai.mint(lp, AERODROME_INIT_AMOUNT);
        usdc.mint(lp, AERODROME_INIT_AMOUNT);

        vm.startPrank(lp);
        dai.approve(address(aeroRouter), AERODROME_INIT_AMOUNT);
        usdc.approve(address(aeroRouter), AERODROME_INIT_AMOUNT);
        aeroRouter.addLiquidity(
            address(dai),
            address(usdc),
            false,
            AERODROME_INIT_AMOUNT,
            AERODROME_INIT_AMOUNT,
""",
        """    function _seedAerodromeLiquidity() internal virtual {
        uint256 initPair = _from18(address(pairToken), AERODROME_INIT_AMOUNT);
        uint256 initRate = _from18(address(rateAsset), AERODROME_INIT_AMOUNT);
        pairToken.mint(lp, initPair);
        rateAsset.mint(lp, initRate);

        vm.startPrank(lp);
        pairToken.approve(address(aeroRouter), initPair);
        rateAsset.approve(address(aeroRouter), initRate);
        aeroRouter.addLiquidity(
            address(pairToken),
            address(rateAsset),
            false,
            initPair,
            initRate,
""",
    )
    # mintTTA is non-virtual on gold; this is a new contract so we can rewrite.
    out = out.replace(
        """    function mintTTA(address recipient, uint256 amount) public {
        dai.mint(recipient, amount);
    }
""",
        """    function mintTTA(address recipient, uint256 amount) public {
        pairToken.mint(recipient, _from18(address(pairToken), amount));
    }
""",
    )
    out = out.replace(
        """    function mintShares(address recipient, uint256 daiAmount) public virtual returns (uint256 sharesOut) {
        dai.mint(recipient, daiAmount);
        usdc.mint(recipient, daiAmount);

        vm.startPrank(recipient);
        dai.approve(address(aeroRouter), daiAmount);
        usdc.approve(address(aeroRouter), daiAmount);
        (,, uint256 lpOut) = aeroRouter.addLiquidity(
            address(dai),
            address(usdc),
            false,
            daiAmount,
            daiAmount,
""",
        """    function mintShares(address recipient, uint256 daiAmount) public virtual returns (uint256 sharesOut) {
        uint256 amtPair = _from18(address(pairToken), daiAmount);
        uint256 amtRate = _from18(address(rateAsset), daiAmount);
        pairToken.mint(recipient, amtPair);
        rateAsset.mint(recipient, amtRate);

        vm.startPrank(recipient);
        pairToken.approve(address(aeroRouter), amtPair);
        rateAsset.approve(address(aeroRouter), amtRate);
        (,, uint256 lpOut) = aeroRouter.addLiquidity(
            address(pairToken),
            address(rateAsset),
            false,
            amtPair,
            amtRate,
""",
    )
    write(CP_TB.with_name("TestBase_StandardExchangeBufferPool_Decimals.sol"), out)

    # Uni V2 variant: copy gold UniV2 TestBase, inherit decimals CP base
    uni = ROOT / "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/uniswapV2/bases/TestBase_StandardExchangeBufferPool_UniswapV2.sol"
    u = uni.read_text()
    u = u.replace(
        "TestBase_StandardExchangeBufferPool",
        "TestBase_StandardExchangeBufferPool_Decimals",
    )
    u = u.replace(
        "abstract contract TestBase_StandardExchangeBufferPool_Decimals_UniswapV2 is TestBase_StandardExchangeBufferPool_Decimals {",
        "abstract contract TestBase_StandardExchangeBufferPool_UniswapV2_Decimals is TestBase_StandardExchangeBufferPool_Decimals {",
    )
    # gold name after first replace becomes TestBase_StandardExchangeBufferPool_Decimals_UniswapV2 if pattern was _UniswapV2 suffix
    u = u.replace(
        "abstract contract TestBase_StandardExchangeBufferPool_Decimals_UniswapV2 is TestBase_StandardExchangeBufferPool_Decimals {",
        "abstract contract TestBase_StandardExchangeBufferPool_UniswapV2_Decimals is TestBase_StandardExchangeBufferPool_Decimals {",
    )
    if "TestBase_StandardExchangeBufferPool_UniswapV2_Decimals" not in u:
        u = u.replace(
            "abstract contract TestBase_StandardExchangeBufferPool_UniswapV2 is TestBase_StandardExchangeBufferPool_Decimals {",
            "abstract contract TestBase_StandardExchangeBufferPool_UniswapV2_Decimals is TestBase_StandardExchangeBufferPool_Decimals {",
        )
    u = u.replace(
        "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol",
        "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool_Decimals.sol",
    )
    write(uni.with_name("TestBase_StandardExchangeBufferPool_UniswapV2_Decimals.sol"), u)


def patch_pool_nleg_base(gold: Path, new_name: str, parent_old: str, parent_new: str, parent_path: str) -> None:
    src = gold.read_text()
    src = src.replace(parent_old, parent_new)
    src = src.replace(f"abstract contract {gold.stem} is {parent_new}", f"abstract contract {new_name} is {parent_new}")
    src = src.replace(
        f"abstract contract {gold.stem} is {parent_old}",
        f"abstract contract {new_name} is {parent_new}",
    )
    # After replacing parent_old globally, contract line may already use parent_new
    src = re.sub(
        rf"abstract contract {re.escape(gold.stem)} is {re.escape(parent_new)}",
        f"abstract contract {new_name} is {parent_new}",
        src,
        count=1,
    )
    write(gold.with_name(new_name + ".sol"), src)


def gen_step26() -> None:
    gen_cp_testbase()
    pools = ROOT / "test/foundry/spec/protocols/dexes/balancer/v3/pools"

    # CP listed tests only
    cp_dir = pools / "constProd/standardExchange"
    cp_files = [
        cp_dir / "StandardExchangeBufferPool.spec.t.sol",
        cp_dir / "StandardExchangeBufferPool_RateTracking.t.sol",
        cp_dir / "StandardExchangeBufferPoolTarget.t.sol",
        cp_dir / "comparative/StandardExchangeBufferPool_Comparative.spec.t.sol",
        pools / "adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol",
        cp_dir / "uniswapV2/StandardExchangeBufferPool_UniswapV2.spec.t.sol",
    ]
    clone_suites(
        [p for p in cp_files if p.exists()],
        cp_dir / "decimals",
        "TestBase_StandardExchangeBufferPool_Decimals",
        "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool_Decimals.sol",
        [
            "TestBase_StandardExchangeBufferPool",
            "TestBase_StandardExchangeBufferPool_UniswapV2",
            "TestBase_StandardExchangeBufferPool_Comparative",
        ],
        set(),
        True,
    )

    nleg_specs = [
        (
            pools / "weighted/commonBufferMultiVault",
            "TestBase_CommonBufferMultiVaultWeightedPool",
            "TestBase_CommonBufferMultiVaultWeightedPool_Decimals",
            [
                "CommonBufferMultiVault_RoutingAndWalk.spec.t.sol",
            ],
        ),
        (
            pools / "weighted/mixedLegBuffer",
            "TestBase_MixedLegWeightedBufferPool",
            "TestBase_MixedLegWeightedBufferPool_Decimals",
            [
                "MixedLegWeightedBufferPool.spec.t.sol",
                "MixedLeg_P4_Smoke.spec.t.sol",
            ],
        ),
        (
            pools / "weighted/multiPairBuffer",
            "TestBase_MultiPairStandardExchangeBufferPool",
            "TestBase_MultiPairStandardExchangeBufferPool_Decimals",
            [
                "MultiPairStandardExchangeBufferPool.spec.t.sol",
                "MultiPairBuffer_CrossPair.spec.t.sol",
            ],
        ),
        (
            pools / "stable/commonBufferMultiVault",
            "TestBase_CommonBufferMultiVaultStablePool",
            "TestBase_CommonBufferMultiVaultStablePool_Decimals",
            [
                "CommonBufferMultiVaultStable_WalkAndExhaust.spec.t.sol",
            ],
        ),
        (
            pools / "stable/mixedBufferMultiVault",
            "TestBase_MixedBufferMultiVaultStablePool",
            "TestBase_MixedBufferMultiVaultStablePool_Decimals",
            [
                "MixedBufferMultiVaultStable_WalkAndExhaust.spec.t.sol",
            ],
        ),
    ]
    for folder, gold_tb, dec_tb, specs in nleg_specs:
        tb = folder / "bases" / f"{gold_tb}.sol"
        if tb.exists():
            src = tb.read_text()
            src = src.replace(
                "TestBase_StandardExchangeBufferPool",
                "TestBase_StandardExchangeBufferPool_Decimals",
            )
            src = src.replace(
                f"abstract contract {gold_tb} is",
                f"abstract contract {dec_tb} is",
            )
            src = src.replace(
                "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol",
                "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool_Decimals.sol",
            )
            # add book decimals if missing
            if "_pairDecimals" not in src:
                src = src.replace(
                    f"abstract contract {dec_tb} is",
                    f"abstract contract {dec_tb} is",
                    1,
                )
            write(tb.with_name(dec_tb + ".sol"), src)
            for book, pd, od, rest in BOOKS:
                write(
                    tb.with_name(f"{gold_tb}_{book}.sol"),
                    f"""// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {{{dec_tb}}} from "{(tb.with_name(dec_tb + '.sol')).relative_to(ROOT).as_posix()}";

{book_natspec(book, pd, od, rest)}
abstract contract {gold_tb}_{book} is {dec_tb} {{
    function _pairDecimals() internal pure override returns (uint8) {{ return {pd}; }}
    function _rateDecimals() internal pure override returns (uint8) {{ return {od}; }}
    function _restDecimals() internal pure override returns (uint8) {{ return {rest}; }}
}}
""",
                )
        files = [folder / s for s in specs if (folder / s).exists()]
        clone_suites(
            files,
            folder / "decimals",
            dec_tb,
            (tb.with_name(dec_tb + ".sol")).relative_to(ROOT).as_posix() if tb.exists() else "",
            [gold_tb, "TestBase_StandardExchangeBufferPool"],
            set(),
            False,
        )


def main() -> None:
    gen_step24()
    gen_step25()
    gen_step26()
    print("generated steps 24–26")


if __name__ == "__main__":
    main()
