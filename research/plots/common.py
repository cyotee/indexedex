"""Shared helpers for IndexedEx research plots."""

from __future__ import annotations

import json
from pathlib import Path


def load_series(path: Path) -> list[dict]:
    rows: list[dict] = []
    with path.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            rows.append(json.loads(line))
    return rows


def load_meta(run_dir: Path) -> dict:
    p = run_dir / "meta.json"
    return json.loads(p.read_text()) if p.exists() else {}


def parse_int(s: str | int) -> int:
    s = str(s)
    if s.startswith("-"):
        return -int(s[1:])
    return int(s)


def w18(x: str | int) -> float:
    """Scale 1e18 fixed-point to float (token units if 18 decimals)."""
    return parse_int(x) / 1e18


def market_bought_asset(meta: dict, rows: list[dict]) -> str:
    bought = meta.get("marketBoughtAsset") or meta.get("demandAsset")
    if bought in ("WETH", "USDC"):
        return bought
    traded = meta.get("tradedAsset", "")
    if traded == "WETH":
        return "USDC"
    if traded == "USDC":
        return "WETH"
    if rows and "tradedIsWeth" in rows[0]:
        return "USDC" if rows[0]["tradedIsWeth"] else "WETH"
    return "?"


def demand_title(market_bought: str) -> tuple[str, str]:
    if market_bought == "WETH":
        return (
            "Mode A: market buys WETH from our Uni liquidity",
            "External flow USDC → WETH on Uni (our LP is the seller of WETH)",
        )
    if market_bought == "USDC":
        return (
            "Mode A: market buys USDC from our Uni liquidity",
            "External flow WETH → USDC on Uni (our LP is the seller of USDC)",
        )
    return ("Mode A", "Market demand against our Uni liquidity")
