#!/usr/bin/env python3
"""DualLiquidity Research v2 plots: volume_by_leg + share_book_pnl."""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

os.environ.setdefault("MPLBACKEND", "Agg")
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

from common import load_meta, load_series, parse_int


def si(x) -> int:
    return parse_int(x) if x is not None else 0


def cumsum(vals: list[int]) -> list[int]:
    out = []
    s = 0
    for v in vals:
        s += v
        out.append(s)
    return out


def plot_volume(rows: list[dict], out_path: Path, title: str) -> None:
    steps = [r.get("step", i) for i, r in enumerate(rows)]
    # Prefer absolute live balances; also show cumulative deltas
    la = [si(r.get("liveVaultA")) for r in rows]
    lb = [si(r.get("liveVaultB")) for r in rows]
    lp = [si(r.get("livePairVault")) for r in rows]
    db = [si(r.get("balDiamondBpt") or r.get("reserveBpt")) for r in rows]

    d_la = cumsum([si(r.get("dLiveVaultA")) for r in rows])
    d_lb = cumsum([si(r.get("dLiveVaultB")) for r in rows])
    d_lp = cumsum([si(r.get("dLivePairVault")) for r in rows])
    d_db = cumsum([si(r.get("dBalDiamondBpt")) for r in rows])

    fig, axes = plt.subplots(2, 1, figsize=(12, 8), sharex=True)
    ax = axes[0]
    ax.plot(steps, la, label="liveVaultA", lw=2)
    ax.plot(steps, lb, label="liveVaultB", lw=2)
    ax.plot(steps, lp, label="livePairVault", lw=2)
    ax.plot(steps, db, label="balDiamondBpt", lw=2, ls="--")
    ax.set_ylabel("absolute (wei)")
    ax.set_title(f"{title} — volume_by_leg (absolute)")
    ax.legend(fontsize=8)
    ax.grid(True, alpha=0.3)

    ax = axes[1]
    ax.axhline(0, color="gray", ls="--")
    ax.plot(steps, d_la, label="cum dLiveVaultA", lw=2)
    ax.plot(steps, d_lb, label="cum dLiveVaultB", lw=2)
    ax.plot(steps, d_lp, label="cum dLivePairVault", lw=2)
    ax.plot(steps, d_db, label="cum dBalDiamondBpt", lw=2, ls="--")
    ax.set_xlabel("step")
    ax.set_ylabel("cumulative Δ (wei)")
    ax.set_title("cumulative volume attribution")
    ax.legend(fontsize=8)
    ax.grid(True, alpha=0.3)

    fig.tight_layout()
    fig.savefig(out_path, dpi=120)
    plt.close(fig)


def plot_share_book(rows: list[dict], out_path: Path, title: str) -> None:
    steps = [r.get("step", i) for i, r in enumerate(rows)]
    p0 = max(si(rows[0].get("portfolio0Bpt") or 1), 1)
    # Prefer pnlNorm (1e18 fixed); fall back to totalPnlBpt/p0
    pnl_pct = []
    for r in rows:
        if r.get("pnlNorm") is not None and str(r.get("pnlNorm")) != "":
            pnl_pct.append(si(r["pnlNorm"]) / 1e18 * 100)
        else:
            pnl_pct.append(si(r.get("totalPnlBpt") or 0) / p0 * 100)
    mark = [si(r.get("markFullExit") or r.get("portfolioExitBpt")) for r in rows]

    fig, axes = plt.subplots(2, 1, figsize=(12, 8), sharex=True)
    ax = axes[0]
    ax.axhline(0, color="gray", ls="--")
    ax.plot(steps, pnl_pct, "b-", lw=2, label="pnlNorm %")
    ax.set_ylabel("normalized P&L %")
    ax.set_title(f"{title} — share_book_pnl")
    ax.legend(fontsize=8)
    ax.grid(True, alpha=0.3)

    ax = axes[1]
    ax.plot(steps, mark, "k-", lw=2, label="markFullExit (BPT)")
    ax.set_xlabel("step")
    ax.set_ylabel("BPT wei")
    ax.legend(fontsize=8)
    ax.grid(True, alpha=0.3)

    fig.tight_layout()
    fig.savefig(out_path, dpi=120)
    plt.close(fig)


def main() -> None:
    p = argparse.ArgumentParser(description="Plot DualLiquidity v2 volume + share-book charts")
    p.add_argument("run_dir", type=Path, help="Directory with series.jsonl + meta.json")
    args = p.parse_args()

    run_dir: Path = args.run_dir
    series_path = run_dir / "series.jsonl"
    if not series_path.exists():
        raise SystemExit(f"missing {series_path}")

    rows = load_series(series_path)
    if not rows:
        raise SystemExit("empty series")
    meta = load_meta(run_dir)
    route = meta.get("runId") or run_dir.name
    title = f"DualLiquidity v2 — {route}"

    has_vol = any("liveVaultA" in r or "dLiveVaultA" in r for r in rows)
    if has_vol:
        out_v = run_dir / "volume_by_leg.png"
        plot_volume(rows, out_v, title)
        print(f"wrote {out_v}")

    out_p = run_dir / "share_book_pnl.png"
    plot_share_book(rows, out_p, title)
    print(f"wrote {out_p}")

    # also write pnl_normalized alias name for graph-map consistency
    out_n = run_dir / "pnl_normalized.png"
    if not out_n.exists():
        plot_share_book(rows, out_n, title)
        print(f"wrote {out_n}")


if __name__ == "__main__":
    main()
