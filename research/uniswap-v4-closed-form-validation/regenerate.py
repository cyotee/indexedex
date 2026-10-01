#!/usr/bin/env python3

from __future__ import annotations

import json
import math
from pathlib import Path

from candidates import (
    cf_b_candidate,
    cf_g_candidate,
    cf_r_coefficients,
    forward_repair_error_bps,
    integer_ratio_error_bps,
    pre_swap_shortcut_error_bps,
    quadratic_roots,
    select_repair_root,
)
from integer_core import Q96, compute_swap_step, price_impact_wad, single_exit, target_free

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "counterexamples"
SEED = 20260927


def u160(x: int) -> int:
    return max(MIN_SQRT := 4295128739, min(x, 1461446703485210103287273052203988822378723970342))


def check_cf_r() -> dict:
    sqrt_start = Q96
    lower = (Q96 * 3) // 4
    upper = (Q96 * 5) // 4
    active = 1_000_000
    cases = []
    for fee in (0, 100, 500, 3000, 10000):
        for owned_pct in (0, 1, 50, 100):
            owned = active * owned_pct // 100
            f0, f1 = 50_000, 5_000
            try:
                q2, q1, q0 = cf_r_coefficients(f0, f1, active, owned, sqrt_start, lower, upper, fee)
                root = select_repair_root(quadratic_roots(q2, q1, q0), sqrt_start, lower, upper)
            except Exception as exc:
                cases.append({"fee": fee, "owned_pct": owned_pct, "status": f"solver-failed:{exc}"})
                continue
            if root is None:
                cases.append({"fee": fee, "owned_pct": owned_pct, "status": "no-physical-root"})
                continue
            sqrt_target = u160(int(root * Q96))
            result = forward_repair_error_bps(f0, f1, active, owned, sqrt_start, sqrt_target, lower, upper, fee)
            result.update({"fee": fee, "owned_pct": owned_pct, "sqrt_target": sqrt_target})
            cases.append(result)
    executed = [case for case in cases if case.get("status") == "executed"]
    within = [case for case in executed if case["error_bps"] <= 1]
    return {
        "attempted": len(cases),
        "executed": len(executed),
        "within_1bp": len(within),
        "max_error_bps": max((case["error_bps"] for case in executed), default=None),
        "cases": cases,
    }


def check_cf_b() -> dict:
    failures = []
    attempted = 0
    bracketed = 0
    for supply in (100, 1_000, 10_000, 1_000_000):
        for reserve_out, reserve_other in ((1_000_000, 1_000_000), (1_000_000, 250_000), (50, 50), (10**18, 10**6)):
            for output_pct in (1, 10, 25, 50, 90):
                amount_out = reserve_out * output_pct // 100
                if amount_out == 0:
                    continue
                attempted += 1
                try:
                    candidate = cf_b_candidate(reserve_out, amount_out, supply)
                    got = single_exit(reserve_out, reserve_other, candidate, supply)
                    previous = single_exit(reserve_out, reserve_other, max(candidate - 1, 0), supply) if candidate else 0
                except Exception as exc:
                    failures.append({"supply": supply, "amount_out": amount_out, "error": str(exc)})
                    continue
                if got >= amount_out and (candidate == 0 or previous < amount_out):
                    bracketed += 1
                else:
                    failures.append(
                        {
                            "supply": supply,
                            "reserve_out": reserve_out,
                            "reserve_other": reserve_other,
                            "amount_out": amount_out,
                            "candidate": candidate,
                            "forward": got,
                            "previous": previous,
                        }
                    )
    return {"attempted": attempted, "bracketed": bracketed, "failures": len(failures), "samples": failures[:12]}


def check_cf_g() -> dict:
    failures = []
    attempted = 0
    passed = 0
    for supply in (1_000, 1_000_000):
        reserve_out = reserve_other = 1_000_000
        for output_pct in (1, 10, 50):
            amount_out = reserve_out * output_pct // 100
            attempted += 1
            shares = cf_g_candidate(reserve_out, amount_out, supply)
            outputs = []
            for candidate in (shares, shares + 1):
                if 0 < candidate < supply:
                    outputs.append((candidate, single_exit(reserve_out, reserve_other, candidate, supply)))
            if any(output >= amount_out for _, output in outputs):
                passed += 1
            else:
                failures.append({"supply": supply, "amount_out": amount_out, "shares": shares, "outputs": outputs})
    return {"attempted": attempted, "forward_hit": passed, "failures": failures}


def check_shortcut() -> dict:
    sqrt_start = Q96
    sqrt_target = (Q96 * 99) // 100
    active = 1_000_000
    _, amount_in, amount_out, fee_amount = compute_swap_step(sqrt_start, sqrt_target, active, -(10**30), 3000)
    reserve0, reserve1, supply, shares = 1_000_000, 1_000_000, 1_000_000, 10_000
    error = pre_swap_shortcut_error_bps(reserve0, reserve1, amount_in + fee_amount, amount_out, supply, shares)
    return {
        "amount_in_with_fee": amount_in + fee_amount,
        "amount_out": amount_out,
        "pre_swap_shortcut_error_bps": error,
        "price_impact_wad": price_impact_wad(sqrt_start, sqrt_target),
    }


def check_target_free() -> dict:
    total = 120
    p = 2 * 10**17
    approved = target_free(total, p)
    old = (total * p) // 10**18
    return {"total": total, "p": p, "approved": approved, "old_percent_of_total": old, "distinct": approved != old}


def check_fee_identity() -> dict:
    sqrt_start = Q96
    sqrt_target = (Q96 * 995) // 1000
    active = 1_000_000
    sqrt_next, amount_in, amount_out, fee_amount = compute_swap_step(sqrt_start, sqrt_target, active, -(10**30), 3000)
    continuous_input = (active * (Q96 // sqrt_target - Q96 // sqrt_start))
    return {
        "sqrt_next": sqrt_next,
        "integer_amount_in": amount_in,
        "integer_fee": fee_amount,
        "integer_amount_out": amount_out,
        "continuous_input_ignores_rounding": continuous_input,
        "input_gap": abs((amount_in) - continuous_input),
    }


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    report = {
        "seed": SEED,
        "CF-R": check_cf_r(),
        "CF-B": check_cf_b(),
        "CF-G": check_cf_g(),
        "CF-M-shortcut": check_shortcut(),
        "sleeve": check_target_free(),
        "fee-rounding": check_fee_identity(),
        "CF-Q": {
            "status": "REFUTED",
            "reason": "MiniMax WP-C sizes the route with UniswapV4Quoter.quoteExactOutput. The pinned quoter loops in UniswapV4Quoter.sol:172-176.",
        },
    }
    (OUT / "summary.json").write_text(json.dumps(report, indent=2, default=str))
    print(json.dumps({key: {k: v for k, v in value.items() if k != "cases"} if isinstance(value, dict) else value for key, value in report.items()}, indent=2, default=str))


if __name__ == "__main__":
    main()
