#!/usr/bin/env python3
"""Summarize ordered Forge logs; later results replace the same test case."""
import json
import re
import sys
from pathlib import Path

cases = {}
runs = []
for name in sys.argv[1:]:
    path = Path(name)
    source = contract = None
    summary = None
    for line in path.read_text().splitlines():
        header = re.match(r"^Ran \d+ tests? for (.+\.sol):([^\s]+)$", line)
        if header:
            source, contract = header.groups()
        if re.match(r"^Ran \d+ test suites? in ", line):
            summary = line
            break
        case = re.match(r"^\[(PASS|FAIL.*)\] (\w+\([^)]*\))", line)
        if case and source:
            status, signature = case.groups()
            cases[(source, contract, signature)] = {
                "source": source, "contract": contract, "test": signature,
                "passed": status == "PASS", "result": line, "log": str(path),
            }
    runs.append({"log": str(path), "summary": summary})
result = {
    "runs": runs, "unique_tests": len(cases),
    "passed": sum(case["passed"] for case in cases.values()),
    "failures": [case for case in cases.values() if not case["passed"]],
    "cases": list(cases.values()),
}
print(json.dumps(result, indent=2))
