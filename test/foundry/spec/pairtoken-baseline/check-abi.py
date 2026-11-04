# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
# How to run: python3 test/foundry/spec/pairtoken-baseline/check-abi.py
"""Check the compiled public surface against the PRD's machine-facing tables."""

import json
from pathlib import Path
from typing import Final

ROOT: Final = Path(__file__).resolve().parents[4]


def main() -> None:
    """Reject extra functions, missing errors, wrong mutability or event layout."""
    artifact = json.loads((ROOT / "out/PairToken.sol/PairToken.json").read_text())
    abi = artifact["abi"]
    getters = {
        "name": "string", "symbol": "string", "decimals": "uint8",
        "totalSupply": "uint256", "balanceOf": "uint256", "allowance": "uint256",
        "BPS": "uint256", "DEAD_SHARES": "uint256", "RETENTION_BPS": "uint256",
        "DUST": "uint256", "DEAD": "address", "factory": "address",
        "poolManager": "address", "poolId": "bytes32", "tickLower": "int24",
        "tickUpper": "int24", "initialized": "bool",
    }
    methods = {
        "initialize": ("nonpayable", ["address", "tuple", "string", "string"], []),
        "approve": ("nonpayable", ["address", "uint256"], ["bool"]),
        "transfer": ("nonpayable", ["address", "uint256"], ["bool"]),
        "transferFrom": ("nonpayable", ["address", "address", "uint256"], ["bool"]),
        "poolKey": ("view", [], ["tuple"]),
        "token0": ("view", [], ["address"]),
        "token1": ("view", [], ["address"]),
        "positionLiquidity": ("view", [], ["uint128"]),
        "basket": ("view", [], ["uint256", "uint256"]),
        "previewDeposit": ("view", ["uint256", "uint256"], ["uint256"] * 3),
        "previewRedeem": ("view", ["uint256"], ["uint256", "uint256"]),
        "deposit": ("payable", ["uint256", "uint256", "uint256", "address"], ["uint256"]),
        "zapDeposit": ("payable", ["address", "uint256", "uint256", "address"], ["uint256"]),
        "redeem": ("nonpayable", ["uint256", "uint256", "uint256", "address"], ["uint256", "uint256"]),
        "redeemZap": ("nonpayable", ["uint256", "address", "uint256", "address"], ["uint256"]),
        "compound": ("nonpayable", [], ["uint256", "uint256"]),
        "unlockCallback": ("nonpayable", ["bytes"], ["bytes"]),
    }
    for name, output in getters.items():
        inputs = ["address"] * (2 if name == "allowance" else int(name == "balanceOf"))
        methods[name] = ("view", inputs, [output])
    functions = [entry for entry in abi if entry["type"] == "function"]
    assert len(functions) == len(methods), "extra or missing function"
    assert {entry["name"] for entry in functions} == set(methods), "function names"
    for entry in functions:
        actual = (
            entry["stateMutability"],
            [arg["type"] for arg in entry["inputs"]],
            [arg["type"] for arg in entry["outputs"]],
        )
        assert actual == methods[entry["name"]], entry["name"]
        for arg in entry["inputs"] + entry["outputs"]:
            if arg["type"] == "tuple":
                assert [part["type"] for part in arg["components"]] == [
                    "address", "address", "uint24", "int24", "address",
                ], "pool key"
    assert not any(entry["type"] == "fallback" for entry in abi), "fallback"
    receivers = [entry for entry in abi if entry["type"] == "receive"]
    assert len(receivers) == 1 and receivers[0]["stateMutability"] == "payable"
    errors = {
        name: [] for name in (
            "AlreadyInitialized", "NotFactory", "NotPoolManager", "Reentrancy",
            "BadGenesis", "MinShares", "MinOut", "ZapTooLarge", "ZapMovesPrice",
            "BadToken", "NativeMismatch", "TransferFailed", "ZeroAddress",
            "NativeTransferFailed", "ERC20TransferFailed", "InvalidPrice", "SafeCastOverflow",
        )
    }
    errors["WrappedError"] = ["address", "bytes4", "bytes", "bytes"]
    errors["InvalidTick"] = ["int24"]
    compiled_errors = {
        entry["name"]: [arg["type"] for arg in entry["inputs"]]
        for entry in abi if entry["type"] == "error"
    }
    assert compiled_errors == errors, "error signatures"
    events = {
        "Transfer": (["address", "address", "uint256"], [True, True, False]),
        "Approval": (["address", "address", "uint256"], [True, True, False]),
        "Deposit": (["address", "address"] + ["uint256"] * 3, [True, True, False, False, False]),
        "Redeem": (["address", "address"] + ["uint256"] * 3, [True, True, False, False, False]),
        "Compounded": (["uint256"] * 4 + ["uint128"], [False] * 5),
    }
    compiled_events = [entry for entry in abi if entry["type"] == "event"]
    assert len(compiled_events) == len(events), "event count"
    for entry in compiled_events:
        assert not entry["anonymous"]
        assert (
            [arg["type"] for arg in entry["inputs"]],
            [arg["indexed"] for arg in entry["inputs"]],
        ) == events[entry["name"]], entry["name"]
    print("0x" + "00" * 31 + "01")


if __name__ == "__main__":
    main()
