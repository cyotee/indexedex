#!/usr/bin/env python3
"""Generate Step 21 Uni V4 DETF CP decimal clones. Does not edit gold TestBase_UniswapV4Detf.sol."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DETF = ROOT / "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf"
GOLD = ROOT / "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf"
DEC = GOLD / "decimals"
ADV_DEC = DEC / "adversarial"

COMBOS = [
    ("H6", 6, 6),
    ("H9", 9, 9),
    ("P6_R18", 6, 18),
    ("P18_R6", 18, 6),
    ("P9_R18", 9, 18),
    ("P18_R9", 18, 9),
    ("P6_R9", 6, 9),
    ("P9_R6", 9, 6),
]

ETHER_RE = re.compile(r"(?<![\w.])(\d+(?:_\d+)*(?:\.\d+)?)\s+ether\b")

KEEP_ETHER_MARKERS = (
    "skewSyntheticDownAmt",
    "dump_",
    "deal(d, detfUser",
    "deal(detf,",
    "mintFromNFTSale",
    "junk_",
    "left_ > 8 ether",
    "chunk_ <= 1 ether",
    "chunk_ = left_ > 8 ether",
)


def scale_ether(src: str) -> str:
    out_lines = []
    for line in src.splitlines(True):
        if any(m in line for m in KEEP_ETHER_MARKERS):
            out_lines.append(line)
            continue
        out_lines.append(ETHER_RE.sub(r"_uPair(\1)", line))
    return "".join(out_lines)


def rewrite_imports_and_names(src: str) -> str:
    repls = [
        (
            "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Adversarial.sol",
            "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Adversarial_Decimals.sol",
        ),
        (
            "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Policy.sol",
            "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Policy_Decimals.sol",
        ),
        (
            "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol",
            "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Decimals.sol",
        ),
        ("TestBase_UniswapV4Detf_Adversarial", "TestBase_UniswapV4Detf_Adversarial_Decimals"),
        ("TestBase_UniswapV4Detf_Policy", "TestBase_UniswapV4Detf_Policy_Decimals"),
        ("TestBase_UniswapV4Detf", "TestBase_UniswapV4Detf_Decimals"),
    ]
    # Restore over-replacements of the decimals filenames themselves.
    src_out = src
    for a, b in repls:
        src_out = src_out.replace(a, b)
    src_out = src_out.replace(
        "TestBase_UniswapV4Detf_Decimals_Decimals", "TestBase_UniswapV4Detf_Decimals"
    )
    src_out = src_out.replace(
        "TestBase_UniswapV4Detf_Decimals_Policy_Decimals",
        "TestBase_UniswapV4Detf_Policy_Decimals",
    )
    src_out = src_out.replace(
        "TestBase_UniswapV4Detf_Decimals_Adversarial_Decimals",
        "TestBase_UniswapV4Detf_Adversarial_Decimals",
    )
    src_out = src_out.replace(
        "TestBase_UniswapV4Detf_Policy_Decimals_Decimals",
        "TestBase_UniswapV4Detf_Policy_Decimals",
    )
    # Abstract gold names living next to gold suites → decimals copies.
    for name in (
        "UniswapV4Detf_IoTablesOpenBase",
        "UniswapV4Detf_IoTablesGoldBase",
        "UniswapV4Detf_ClaimBase",
        "UniswapV4Detf_ClaimOpenBase",
        "UniswapV4Detf_Alignment_CloseD25Base",
        "UniswapV4Detf_Alignment_CloseD25OpenBase",
        "UniswapV4Detf_Alignment_RedeemD15OpenBase",
        "UniswapV4Detf_Alignment_RedeemD15PolicyBase",
        "UniswapV4Detf_Alignment_RedeemD15Base",
        "UniswapV4Detf_Alignment_FeeCreatorClaimBase",
        "UniswapV4Detf_Alignment_FeeCreatorClaimPolicyBase",
        "UniswapV4Detf_ReserveDonationOpenBase",
        "UniswapV4Detf_ReserveDonationBase",
        "UniswapV4Detf_OwnerOnlyLiquidityOpenBase",
        "UniswapV4Detf_OwnerOnlyLiquidityBase",
        "UniswapV4Detf_PolicyLayerBase",
        "UniswapV4Detf_PolicyBase",
        "UniswapV4Detf_OpeningPriceBase",
        "UniswapV4Detf_OpeningPriceLayerBase",
        "UniswapV4Detf_AdversarialOpenBase",
    ):
        src_out = src_out.replace(
            f"test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/{name}.sol",
            f"test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/{name}_Decimals.sol",
        )
        src_out = src_out.replace(f"contract {name} ", f"contract {name}_Decimals ")
        src_out = src_out.replace(f"contract {name}\n", f"contract {name}_Decimals\n")
        src_out = src_out.replace(f"contract {name} is", f"contract {name}_Decimals is")
        src_out = src_out.replace(f"abstract contract {name} ", f"abstract contract {name}_Decimals ")
        src_out = src_out.replace(f"abstract contract {name}\n", f"abstract contract {name}_Decimals\n")
        src_out = src_out.replace(f"abstract contract {name} is", f"abstract contract {name}_Decimals is")
        src_out = src_out.replace(f"{name}_Decimals_Decimals", f"{name}_Decimals")
    return src_out


def transform(src: str, *, scale: bool = True) -> str:
    text = rewrite_imports_and_names(src)
    if scale:
        text = scale_ether(text)
    return text


def strip_functions(src: str, names: set[str]) -> str:
    """Remove named function definitions (brace-matched)."""
    lines = src.splitlines(True)
    out = []
    i = 0
    while i < len(lines):
        line = lines[i]
        m = re.search(r"function\s+(\w+)\s*\(", line)
        if m and m.group(1) in names:
            depth = line.count("{") - line.count("}")
            i += 1
            while i < len(lines) and depth > 0:
                depth += lines[i].count("{") - lines[i].count("}")
                i += 1
            # drop following blank
            if i < len(lines) and lines[i].strip() == "":
                i += 1
            continue
        out.append(line)
        i += 1
    return "".join(out)


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)
    print(f"wrote {path.relative_to(ROOT)}")


def combo_natspec(combo: str, pair_d: int, rate_d: int) -> str:
    return (
        f"/// @notice Combo `{combo}`. pairToken {pair_d}-dec mint/bond input; "
        f"other/rate role {rate_d}-dec.\n"
        "/// @dev Gold CP has one ERC-4626 SE underlying (`pairToken`). "
        "vaultShare / detfToken / rebasingClaimToken / Bond NFT stay 18. "
        "Do not invent a non-18 vaultShare. After PoolKey sort, pairToken is still the pair role."
    )


def thin_combo(contract_stem: str, abstract_name: str, abstract_import: str, extra_setup: str = "") -> None:
    for combo, pair_d, rate_d in COMBOS:
        body = extra_setup
        content = f"""// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {{TestBase_UniswapV4Detf_{combo}}} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_{combo}.sol";
import {{{abstract_name}}} from
    "{abstract_import}";

{combo_natspec(combo, pair_d, rate_d)}
contract {contract_stem}_{combo} is TestBase_UniswapV4Detf_{combo}, {abstract_name} {{
{body}}}
"""
        write(DEC / f"{contract_stem}_{combo}.t.sol", content)


def thin_adv(contract_stem: str, abstract_name: str, abstract_import: str, extra_setup: str = "") -> None:
    for combo, pair_d, rate_d in COMBOS:
        content = f"""// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {{TestBase_UniswapV4Detf_{combo}}} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_{combo}.sol";
import {{{abstract_name}}} from
    "{abstract_import}";

{combo_natspec(combo, pair_d, rate_d)}
contract {contract_stem}_{combo} is TestBase_UniswapV4Detf_{combo}, {abstract_name} {{
{extra_setup}}}
"""
        write(ADV_DEC / f"{contract_stem}_{combo}.t.sol", content)


def patch_policy_decimals(text: str) -> str:
    text = text.replace(
        "uint256 internal constant FIRST_BOND_AMT = _uPair(100);\n"
        "    uint256 internal constant LIVE_MINT_AMT = _uPair(10);",
        "function _firstBondAmt() internal view returns (uint256) { return _uPair(100); }\n"
        "    function _liveMintAmt() internal view returns (uint256) { return _uPair(10); }",
    )
    # If scale_ether didn't hit constants because we already replaced... handle gold constants:
    text = text.replace(
        "uint256 internal constant FIRST_BOND_AMT = 100 ether;\n"
        "    uint256 internal constant LIVE_MINT_AMT = 10 ether;",
        "function _firstBondAmt() internal view returns (uint256) { return _uPair(100); }\n"
        "    function _liveMintAmt() internal view returns (uint256) { return _uPair(10); }",
    )
    text = text.replace("FIRST_BOND_AMT", "_firstBondAmt()")
    text = text.replace("LIVE_MINT_AMT", "_liveMintAmt()")
    # undo function-name damage
    text = text.replace("function _firstBondAmt()()", "function _firstBondAmt()")
    text = text.replace("function _liveMintAmt()()", "function _liveMintAmt()")
    text = text.replace("return _uPair(100)()", "return _uPair(100)")
    text = text.replace("return _uPair(10)()", "return _uPair(10)")
    text = text.replace(
        "function _expectedJoinDetf(uint256 pairAmount_, uint256 opening_) internal pure returns (uint256) {\n"
        "        return pairAmount_ * ONE_WAD / opening_;\n"
        "    }",
        "function _expectedJoinDetf(uint256 pairAmount_, uint256 opening_) internal view returns (uint256) {\n"
        "        uint8 d_ = _pairDecimals();\n"
        "        uint256 pairWad_ = d_ >= 18 ? pairAmount_ : pairAmount_ * (10 ** (18 - uint256(d_)));\n"
        "        return pairWad_ * ONE_WAD / opening_;\n"
        "    }",
    )
    text = text.replace("SimpleMintableERC20(token_).mint", "MintableERC20Decimals(token_).mint")
    if "import {MintableERC20Decimals}" not in text and "MintableERC20Decimals" in text:
        text = text.replace(
            'import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";',
            'import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";\n'
            'import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";',
        )
    text = text.replace(
        "function setUp() public virtual override {\n        TestBase_UniswapV4Detf_Decimals.setUp();",
        "function setUp() public virtual override {\n        TestBase_UniswapV4Detf_Decimals.setUp();",
    )
    return text


def main() -> None:
    DEC.mkdir(parents=True, exist_ok=True)
    ADV_DEC.mkdir(parents=True, exist_ok=True)

    # --- Policy / Adversarial TestBases ---
    policy = transform((DETF / "TestBase_UniswapV4Detf_Policy.sol").read_text())
    policy = patch_policy_decimals(policy)
    policy = policy.replace(
        "@title TestBase_UniswapV4Detf_Policy_Decimals",
        "@title TestBase_UniswapV4Detf_Policy_Decimals",
    )
    write(DETF / "TestBase_UniswapV4Detf_Policy_Decimals.sol", policy)

    adv = transform((DETF / "TestBase_UniswapV4Detf_Adversarial.sol").read_text())
    adv = adv.replace(
        "function setUp() public virtual override {\n        TestBase_UniswapV4Detf_Decimals.setUp();",
        "function setUp() public virtual override {\n        TestBase_UniswapV4Detf_Decimals.setUp();",
    )
    write(DETF / "TestBase_UniswapV4Detf_Adversarial_Decimals.sol", adv)

    abstracts = [
        "UniswapV4Detf_IoTablesOpenBase.sol",
        "UniswapV4Detf_IoTablesGoldBase.sol",
        "UniswapV4Detf_ClaimBase.sol",
        "UniswapV4Detf_ClaimOpenBase.sol",
        "UniswapV4Detf_Alignment_CloseD25Base.sol",
        "UniswapV4Detf_Alignment_CloseD25OpenBase.sol",
        "UniswapV4Detf_Alignment_RedeemD15OpenBase.sol",
        "UniswapV4Detf_Alignment_RedeemD15PolicyBase.sol",
        "UniswapV4Detf_Alignment_RedeemD15Base.sol",
        "UniswapV4Detf_Alignment_FeeCreatorClaimBase.sol",
        "UniswapV4Detf_Alignment_FeeCreatorClaimPolicyBase.sol",
        "UniswapV4Detf_ReserveDonationOpenBase.sol",
        "UniswapV4Detf_ReserveDonationBase.sol",
        "UniswapV4Detf_OwnerOnlyLiquidityOpenBase.sol",
        "UniswapV4Detf_OwnerOnlyLiquidityBase.sol",
        "UniswapV4Detf_PolicyLayerBase.sol",
        "UniswapV4Detf_PolicyBase.sol",
        "UniswapV4Detf_OpeningPriceBase.sol",
        "UniswapV4Detf_OpeningPriceLayerBase.sol",
        "UniswapV4Detf_AdversarialOpenBase.sol",
    ]
    for name in abstracts:
        text = transform((GOLD / name).read_text())
        if name == "UniswapV4Detf_IoTablesGoldBase.sol":
            text = strip_functions(text, {"test_T7_16_exactOut_absent", "test_T7_18_noFamilyGetters"})
        if name == "UniswapV4Detf_ClaimBase.sol":
            text = text.replace(
                "try SimpleMintableERC20(toks_[i]).mint(who, amt)",
                "try MintableERC20Decimals(toks_[i]).mint(who, amt)",
            )
            if "MintableERC20Decimals" in text and "import {MintableERC20Decimals}" not in text:
                text = text.replace(
                    'import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";',
                    'import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";\n'
                    'import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";',
                )
        if name == "UniswapV4Detf_ReserveDonationOpenBase.sol":
            text = text.replace(
                "try SimpleMintableERC20(address(tok_)).mint(to_, amount_)",
                "try MintableERC20Decimals(address(tok_)).mint(to_, amount_)",
            )
            if "MintableERC20Decimals" in text and "import {MintableERC20Decimals}" not in text:
                text = text.replace(
                    'import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";',
                    'import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";\n'
                    'import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";',
                )
        dest = DEC / name.replace(".sol", "_Decimals.sol")
        write(dest, text)

    # --- Gold-only concrete bodies as abstracts ---
    mint = transform((GOLD / "UniswapV4Detf_Mint.t.sol").read_text())
    mint = mint.replace("contract UniswapV4Detf_Mint is", "abstract contract UniswapV4Detf_Mint_Decimals is")
    mint = mint.replace("TestBase_UniswapV4Detf_Decimals {", "TestBase_UniswapV4Detf_Decimals {")
    write(DEC / "UniswapV4Detf_Mint_Decimals.sol", mint)

    bond = transform((GOLD / "UniswapV4Detf_Bond.t.sol").read_text())
    bond = bond.replace("contract UniswapV4Detf_Bond is", "abstract contract UniswapV4Detf_Bond_Decimals is")
    write(DEC / "UniswapV4Detf_Bond_Decimals.sol", bond)

    burn = transform((GOLD / "UniswapV4Detf_Burn.t.sol").read_text())
    burn = burn.replace("contract UniswapV4Detf_Burn is", "abstract contract UniswapV4Detf_Burn_Decimals is")
    write(DEC / "UniswapV4Detf_Burn_Decimals.sol", burn)

    close = transform((GOLD / "UniswapV4Detf_Close.t.sol").read_text())
    close = close.replace("contract UniswapV4Detf_Close is", "abstract contract UniswapV4Detf_Close_Decimals is")
    write(DEC / "UniswapV4Detf_Close_Decimals.sol", close)

    deploy = transform((GOLD / "UniswapV4Detf_Deploy.t.sol").read_text())
    deploy = strip_functions(deploy, {"test_T7_1_dualHook_reverts"})
    deploy = deploy.replace("contract UniswapV4Detf_Deploy is", "abstract contract UniswapV4Detf_Deploy_Decimals is")
    write(DEC / "UniswapV4Detf_Deploy_Decimals.sol", deploy)

    donate = transform((GOLD / "UniswapV4Detf_Donate.t.sol").read_text())
    donate = donate.replace("contract UniswapV4Detf_Donate is", "abstract contract UniswapV4Detf_Donate_Decimals is")
    write(DEC / "UniswapV4Detf_Donate_Decimals.sol", donate)

    dust = transform((GOLD / "UniswapV4Detf_Dust.t.sol").read_text())
    dust = dust.replace("contract UniswapV4Detf_Dust is", "abstract contract UniswapV4Detf_Dust_Decimals is")
    write(DEC / "UniswapV4Detf_Dust_Decimals.sol", dust)

    # IoTables concrete extras (T7.11). Skip T7.15 FoT.
    io_t = transform((GOLD / "UniswapV4Detf_IoTables.t.sol").read_text())
    io_t = strip_functions(io_t, {"test_T7_15_L2_FoT_forbidden"})
    io_t = io_t.replace(
        "contract UniswapV4Detf_IoTables is",
        "abstract contract UniswapV4Detf_IoTables_Decimals is",
    )
    write(DEC / "UniswapV4Detf_IoTables_Decimals.sol", io_t)

    owner = transform((GOLD / "UniswapV4Detf_OwnerOnlyLiquidity.t.sol").read_text())
    owner = owner.replace(
        "contract UniswapV4Detf_OwnerOnlyLiquidity is",
        "abstract contract UniswapV4Detf_OwnerOnlyLiquidity_Decimals is",
    )
    write(DEC / "UniswapV4Detf_OwnerOnlyLiquidity_Decimals.sol", owner)

    rd = transform((GOLD / "UniswapV4Detf_ReserveDonation.t.sol").read_text())
    rd = rd.replace(
        "contract UniswapV4Detf_ReserveDonation is",
        "abstract contract UniswapV4Detf_ReserveDonation_Decimals is",
    )
    write(DEC / "UniswapV4Detf_ReserveDonation_Decimals.sol", rd)

    # Policy / OpeningPrice / Claim / Alignments already have _Decimals abstracts that include tests.
    # Adversarial gold concretes:
    a0 = transform((GOLD / "adversarial/Adversarial_A0Crops.t.sol").read_text())
    a0 = a0.replace("contract Adversarial_A0Crops is", "abstract contract Adversarial_A0Crops_Decimals is")
    write(ADV_DEC / "Adversarial_A0Crops_Decimals.sol", a0)

    tf = transform((GOLD / "adversarial/Adversarial_TrustFlags.t.sol").read_text())
    tf = tf.replace("contract Adversarial_TrustFlags is", "abstract contract Adversarial_TrustFlags_Decimals is")
    write(ADV_DEC / "Adversarial_TrustFlags_Decimals.sol", tf)

    nest = transform((GOLD / "adversarial/Adversarial_NestedSe.t.sol").read_text())
    nest = nest.replace("contract Adversarial_NestedSe is", "abstract contract Adversarial_NestedSe_Decimals is")
    write(ADV_DEC / "Adversarial_NestedSe_Decimals.sol", nest)

    reent = (GOLD / "adversarial/Adversarial_Reentrancy.t.sol").read_text()
    reent = reent.replace(
        "contract HostilePairToken is SimpleMintableERC20 {",
        "contract HostilePairTokenDecimals is MintableERC20Decimals {",
    )
    reent = reent.replace(
        'constructor() SimpleMintableERC20("HostilePair", "HPAIR") {}',
        'constructor(uint8 decimals_) MintableERC20Decimals("HostilePair", "HPAIR", decimals_) {}',
    )
    reent = reent.replace("HostilePairToken", "HostilePairTokenDecimals")
    reent = transform(reent)
    reent = reent.replace(
        "contract Adversarial_Reentrancy_Decimals is",
        "abstract contract Adversarial_Reentrancy_Decimals is",
    )
    # gold file is Adversarial_Reentrancy not _Decimals in contract name until transform
    reent = reent.replace(
        "contract Adversarial_Reentrancy is",
        "abstract contract Adversarial_Reentrancy_Decimals is",
    )
    reent = reent.replace("hostilePair = new HostilePairTokenDecimals();", "hostilePair = new HostilePairTokenDecimals(_pairDecimals());")
    reent = reent.replace(
        'import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";',
        'import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";\n'
        'import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";',
    )
    write(ADV_DEC / "Adversarial_Reentrancy_Decimals.sol", reent)

    # Thin combo contracts
    abs_dir = "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals"
    thin_combo("UniswapV4Detf_Mint", "UniswapV4Detf_Mint_Decimals", f"{abs_dir}/UniswapV4Detf_Mint_Decimals.sol")
    thin_combo("UniswapV4Detf_Bond", "UniswapV4Detf_Bond_Decimals", f"{abs_dir}/UniswapV4Detf_Bond_Decimals.sol")
    thin_combo("UniswapV4Detf_Burn", "UniswapV4Detf_Burn_Decimals", f"{abs_dir}/UniswapV4Detf_Burn_Decimals.sol")
    thin_combo("UniswapV4Detf_Close", "UniswapV4Detf_Close_Decimals", f"{abs_dir}/UniswapV4Detf_Close_Decimals.sol")
    thin_combo("UniswapV4Detf_Deploy", "UniswapV4Detf_Deploy_Decimals", f"{abs_dir}/UniswapV4Detf_Deploy_Decimals.sol")
    thin_combo("UniswapV4Detf_Donate", "UniswapV4Detf_Donate_Decimals", f"{abs_dir}/UniswapV4Detf_Donate_Decimals.sol")
    thin_combo("UniswapV4Detf_Dust", "UniswapV4Detf_Dust_Decimals", f"{abs_dir}/UniswapV4Detf_Dust_Decimals.sol")
    thin_combo("UniswapV4Detf_IoTables", "UniswapV4Detf_IoTables_Decimals", f"{abs_dir}/UniswapV4Detf_IoTables_Decimals.sol")
    thin_combo(
        "UniswapV4Detf_OpeningPrice",
        "UniswapV4Detf_OpeningPriceLayerBase_Decimals",
        f"{abs_dir}/UniswapV4Detf_OpeningPriceLayerBase_Decimals.sol",
    )
    thin_combo(
        "UniswapV4Detf_Policy",
        "UniswapV4Detf_PolicyBase_Decimals",
        f"{abs_dir}/UniswapV4Detf_PolicyBase_Decimals.sol",
    )
    thin_combo(
        "UniswapV4Detf_Claim",
        "UniswapV4Detf_ClaimOpenBase_Decimals",
        f"{abs_dir}/UniswapV4Detf_ClaimOpenBase_Decimals.sol",
    )
    thin_combo(
        "UniswapV4Detf_OwnerOnlyLiquidity",
        "UniswapV4Detf_OwnerOnlyLiquidity_Decimals",
        f"{abs_dir}/UniswapV4Detf_OwnerOnlyLiquidity_Decimals.sol",
    )
    thin_combo(
        "UniswapV4Detf_ReserveDonation",
        "UniswapV4Detf_ReserveDonation_Decimals",
        f"{abs_dir}/UniswapV4Detf_ReserveDonation_Decimals.sol",
    )
    thin_combo(
        "UniswapV4Detf_Alignment_CloseD25",
        "UniswapV4Detf_Alignment_CloseD25OpenBase_Decimals",
        f"{abs_dir}/UniswapV4Detf_Alignment_CloseD25OpenBase_Decimals.sol",
    )
    thin_combo(
        "UniswapV4Detf_Alignment_RedeemD15",
        "UniswapV4Detf_Alignment_RedeemD15Base_Decimals",
        f"{abs_dir}/UniswapV4Detf_Alignment_RedeemD15Base_Decimals.sol",
    )
    thin_combo(
        "UniswapV4Detf_Alignment_FeeCreatorClaim",
        "UniswapV4Detf_Alignment_FeeCreatorClaimBase_Decimals",
        f"{abs_dir}/UniswapV4Detf_Alignment_FeeCreatorClaimBase_Decimals.sol",
    )
    thin_adv(
        "Adversarial_A0Crops",
        "Adversarial_A0Crops_Decimals",
        f"{abs_dir}/adversarial/Adversarial_A0Crops_Decimals.sol",
    )
    thin_adv(
        "Adversarial_TrustFlags",
        "Adversarial_TrustFlags_Decimals",
        f"{abs_dir}/adversarial/Adversarial_TrustFlags_Decimals.sol",
    )
    thin_adv(
        "Adversarial_NestedSe",
        "Adversarial_NestedSe_Decimals",
        f"{abs_dir}/adversarial/Adversarial_NestedSe_Decimals.sol",
    )
    thin_adv(
        "Adversarial_Reentrancy",
        "Adversarial_Reentrancy_Decimals",
        f"{abs_dir}/adversarial/Adversarial_Reentrancy_Decimals.sol",
    )

    # Combo TestBase NatSpec enrichment
    for combo, pair_d, rate_d in COMBOS:
        p = DETF / f"TestBase_UniswapV4Detf_{combo}.sol"
        text = p.read_text()
        if "Do not invent a non-18 vaultShare" not in text:
            text = re.sub(
                r"/// @notice Combo `[^`]+`\.[^\n]*\n",
                combo_natspec(combo, pair_d, rate_d) + "\n",
                text,
                count=1,
            )
            p.write_text(text)
            print(f"natspec {p.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
