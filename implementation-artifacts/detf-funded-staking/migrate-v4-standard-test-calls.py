"""Migrate only equivalent V4 test mint/burn calls; record every changed call.

This does not retire assertions or declare old economics migrated. Preview
tuples, old bond claims and gated-revert assertions require separate review.
"""
from pathlib import Path
import hashlib
import json
import re
import sys

ART = Path(__file__).resolve().parent
ROOT = ART.parent.parent
roots = [
    ROOT / "contracts/vaults/detf/protocols/dexes/uniswap/v4",
    ROOT / "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4",
]
apply = "--apply" in sys.argv
previews = "--previews" in sys.argv
gas_only = "--gas-only" in sys.argv


def code_mask(source):
    # Preserve offsets while hiding comments and literals from the call scanner.
    return re.sub(r'//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'',
                  lambda m: " " * len(m.group()), source)


def matching_left(mask, end):
    depth = 1
    for i in range(end - 1, -1, -1):
        if mask[i] == ")":
            depth += 1
        elif mask[i] == "(":
            depth -= 1
            if depth == 0:
                return i
    raise ValueError("Unbalanced receiver")


def call_args(source, mask, start):
    depth = 1
    part = start + 1
    result = []
    for i in range(start + 1, len(mask)):
        if mask[i] in "([":
            depth += 1
        elif mask[i] in ")]":
            depth -= 1
            if depth == 0:
                result.append(source[part:i].strip())
                return i + 1, result
        elif mask[i] == "," and depth == 1:
            result.append(source[part:i].strip())
            part = i + 1
    raise ValueError("Unbalanced call")


records = []
for root in roots:
    for path in sorted(root.rglob("*.sol")):
        # Production sources are never migrated by this test-only script.
        if str(path.relative_to(ROOT)).startswith("contracts/") and not path.name.startswith("TestBase_"):
            continue
        if "slipstream" in str(path).lower():
            continue
        original = path.read_text()
        mask = code_mask(original)
        typed = set(re.findall(r"\bIUniswapV4Detf\s+(\w+)", mask))
        typed.update(("detfInfo", "policyInfo"))
        edits = []
        methods = "previewMint|previewBurn" if previews else "mint|burn"
        for match in re.finditer(r"\.\s*(" + methods + r")\s*(\{[^{}]*\})?\s*\(", mask):
            if gas_only and match.group(2) is None:
                continue
            options = original[match.start(2):match.end(2)] if match.group(2) else ""
            dot = match.start()
            end_receiver = dot
            while end_receiver and mask[end_receiver - 1].isspace():
                end_receiver -= 1
            start_receiver = end_receiver
            if mask[end_receiver - 1] == ")":
                start_receiver = matching_left(mask, end_receiver - 1)
                while start_receiver and mask[start_receiver - 1].isspace():
                    start_receiver -= 1
                while start_receiver and (mask[start_receiver - 1].isalnum() or mask[start_receiver - 1] == "_"):
                    start_receiver -= 1
                receiver = original[start_receiver:end_receiver]
                if not re.fullmatch(r"IUniswapV4Detf\s*\(\s*\w+\s*\)", receiver):
                    continue
            else:
                while start_receiver and (mask[start_receiver - 1].isalnum() or mask[start_receiver - 1] == "_"):
                    start_receiver -= 1
                receiver = original[start_receiver:end_receiver]
                if receiver not in typed:
                    continue
            end, args = call_args(original, mask, match.end() - 1)
            kind = match.group(1)
            if len(args) != (2 if previews else (6 if kind == "mint" else 5)):
                continue
            cast = re.fullmatch(r"IUniswapV4Detf\s*\(\s*(\w+)\s*\)", receiver)
            address = cast.group(1) if cast else "address(" + receiver + ")"
            raw = "IERC20(" + address + ")"
            if kind == "previewMint":
                # Only migrate tuples that already discard gross and rewards.
                # Gross/split assertions need a separately reviewed economic reference.
                lhs = re.search(r"\(\s*,\s*(uint256\s+\w+)\s*,\s*\)\s*=\s*$", original[:start_receiver])
                if not lhs:
                    continue
                start_receiver = lhs.start()
                replacement = lhs.group(1) + " = IStandardExchangeIn(" + address + ").previewExchangeIn" + options + "(" + ", ".join(args + [raw]) + ")"
            elif kind == "previewBurn":
                replacement = "IStandardExchangeIn(" + address + ").previewExchangeIn" + options + "(" + ", ".join([raw, args[0], args[1]]) + ")"
            elif kind == "mint":
                new_args = args[:2] + [raw] + args[2:]
            else:
                new_args = [raw, args[0], args[1], args[2], args[3], "false", args[4]]
            if not previews:
                replacement = "IStandardExchangeIn(" + address + ").exchangeIn" + options + "(" + ", ".join(new_args) + ")"
            edits.append((start_receiver, end, replacement, {
                "line": original.count("\n", 0, start_receiver) + 1,
                "old": original[start_receiver:end],
                "new": replacement,
            }))
        if not edits:
            continue
        updated = original
        for start, end, replacement, _ in reversed(edits):
            updated = updated[:start] + replacement + updated[end:]
        if not re.search(r"import\s*\{[^}]*\bIStandardExchangeIn\b", updated):
            at = updated.index(";", updated.index("pragma solidity")) + 1
            updated = updated[:at] + '\nimport {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";\n' + updated[at:]
        records.append({
            "path": str(path.relative_to(ROOT)),
            "before_sha256": hashlib.sha256(original.encode()).hexdigest(),
            "after_sha256": hashlib.sha256(updated.encode()).hexdigest(),
            "calls": [e[3] for e in edits],
        })
        if apply:
            path.write_text(updated)

record = {
    "status": "applied; validation pending" if apply else "preview; no Solidity edits",
    "scope": "V4 test calls only. Same payer, input, recipient, minimum, pretransfer flag and deadline; raw DETF is the explicit standard route endpoint.",
    "assertions": "Retained. Obsolete economic and removed-selector expectations still need semantic migration; this is not completion evidence.",
    "files": records,
}
stem = "v4-standard-test-preview-migration" if previews else "v4-standard-test-call-migration"
if gas_only:
    stem += "-gas-options"
target = ART / (("" if apply else "pending-") + stem + ".json")
target.write_text(json.dumps(record, indent=2) + "\n")
print(json.dumps({"status": record["status"], "files": len(records), "calls": sum(len(r["calls"]) for r in records)}))
