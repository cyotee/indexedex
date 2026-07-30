#!/usr/bin/env python3
"""Plot Single SE DETF Phase 3 figures F1–F4, F7–F9 from research/out/detf/singleSe/."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

from common import load_series, w18

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "out" / "detf" / "singleSe"
FIG = OUT / "figures"

RUN = {
    "D0": OUT / "D0_inert",
    "D1": OUT / "D1_firstBond",
    "D2": OUT / "D2_policyDeadband",
    "D3": OUT / "D3_policyMintAllowed",
    "D4": OUT / "D4_policyBurnGate",
    "D5": OUT / "D5_openControl",
    "D6": OUT / "D6_capitalSeigniorage",
    "D7": OUT / "D7_bondVsMint",
    "D8": OUT / "D8_naturalExpansion",
    "D9": OUT / "D9_protocolCompound",
}


def _rows(key: str) -> list[dict]:
    p = RUN[key] / "series.jsonl"
    if not p.exists():
        print(f"warn: missing {p}", file=sys.stderr)
        return []
    return load_series(p)


def plot_f1() -> None:
    """Lifecycle: live flag + supply from D0+D1."""
    fig, ax1 = plt.subplots(figsize=(8, 4.5))
    steps, lives, supplies = [], [], []
    for key in ("D0", "D1"):
        for r in _rows(key):
            steps.append(f"{key}:{r.get('tag', r.get('step'))}")
            lives.append(1 if r.get("isReserveLive") else 0)
            supplies.append(w18(r.get("totalSupply", 0)))
    x = range(len(steps))
    ax1.step(x, lives, where="mid", label="isReserveLive", color="C0")
    ax1.set_ylabel("live (0/1)")
    ax1.set_xticks(list(x))
    ax1.set_xticklabels(steps, rotation=45, ha="right", fontsize=7)
    ax2 = ax1.twinx()
    ax2.plot(x, supplies, "o-", color="C1", label="totalSupply")
    ax2.set_ylabel("totalSupply (tokens)")
    ax1.set_title("F1 DETF lifecycle (D0 inert -> D1 first bond)")
    fig.tight_layout()
    FIG.mkdir(parents=True, exist_ok=True)
    fig.savefig(FIG / "F1_lifecycle.png", dpi=140)
    plt.close(fig)
    print(f"wrote {FIG / 'F1_lifecycle.png'}")


def plot_f2() -> None:
    """Synthetic + thresholds from D2–D4."""
    fig, ax = plt.subplots(figsize=(8, 4.5))
    for key, color in (("D2", "C0"), ("D3", "C1"), ("D4", "C2")):
        rows = _rows(key)
        if not rows:
            continue
        xs = [r.get("step", i) for i, r in enumerate(rows)]
        ax.plot(xs, [w18(r.get("syntheticPrice", 0)) for r in rows], "o-", color=color, label=f"{key} synth")
        if rows:
            ax.axhline(w18(rows[0].get("mintThreshold", "1050000000000000000")), color=color, ls="--", alpha=0.4)
            ax.axhline(w18(rows[0].get("burnThreshold", "950000000000000000")), color=color, ls=":", alpha=0.4)
    ax.set_xlabel("step")
    ax.set_ylabel("price (1e18 peg scale)")
    ax.set_title("F2 synthetic vs mint/burn thresholds (D2–D4)")
    ax.legend(fontsize=8)
    fig.tight_layout()
    FIG.mkdir(parents=True, exist_ok=True)
    fig.savefig(FIG / "F2_synthetic_thresholds.png", dpi=140)
    plt.close(fig)
    print(f"wrote {FIG / 'F2_synthetic_thresholds.png'}")


def plot_f3() -> None:
    """Uni spot index + synthetic from D3."""
    rows = _rows("D3")
    fig, ax1 = plt.subplots(figsize=(8, 4.5))
    if rows:
        xs = [r.get("step", i) for i, r in enumerate(rows)]
        ax1.plot(xs, [w18(r.get("syntheticPrice", 0)) for r in rows], "o-", color="C0", label="synthetic")
        ax2 = ax1.twinx()
        ax2.plot(xs, [w18(r.get("uniSpotIndex", 0)) for r in rows], "s-", color="C1", label="uniSpot USDC/WETH")
        ax2.set_ylabel("uni spot")
    ax1.set_xlabel("step")
    ax1.set_ylabel("synthetic")
    ax1.set_title("F3 demand (Uni trades) to synthetic (D3)")
    fig.tight_layout()
    FIG.mkdir(parents=True, exist_ok=True)
    fig.savefig(FIG / "F3_demand_to_synthetic.png", dpi=140)
    plt.close(fig)
    print(f"wrote {FIG / 'F3_demand_to_synthetic.png'}")


def plot_f4() -> None:
    """Preview vs execution from D3 mint rows."""
    rows = _rows("D3")
    previews, execs = [], []
    for r in rows:
        p = r.get("previewOut", "0")
        e = r.get("execOut", "0")
        if str(p) not in ("0", "") and str(e) not in ("0", ""):
            previews.append(w18(p))
            execs.append(w18(e))
    fig, ax = plt.subplots(figsize=(6, 5))
    if previews:
        ax.scatter(previews, execs, c="C0")
        lo = min(min(previews), min(execs))
        hi = max(max(previews), max(execs))
        ax.plot([lo, hi], [lo, hi], "k--", alpha=0.5, label="y=x")
    ax.set_xlabel("previewOut")
    ax.set_ylabel("execOut")
    ax.set_title("F4 preview vs execution (D3 mint)")
    ax.legend()
    fig.tight_layout()
    FIG.mkdir(parents=True, exist_ok=True)
    fig.savefig(FIG / "F4_preview_vs_execution.png", dpi=140)
    plt.close(fig)
    print(f"wrote {FIG / 'F4_preview_vs_execution.png'}")


def plot_f7() -> None:
    """Bond vs mint books from D7."""
    rows = _rows("D7")
    fig, ax = plt.subplots(figsize=(8, 4.5))
    alice_p, bob_steps, bob_free = [], [], []
    for r in rows:
        actor = r.get("actorLabel", "")
        if actor == "alice_bonder" or "pendingRewards" in r:
            if actor == "alice_bonder" or r.get("tag", "").startswith("post_books"):
                alice_p.append((r.get("step", 0), w18(r.get("pendingRewards", 0))))
        # free balance not in series — use pending 0 for bob and totalSupply proxy not ideal
        # Plot pendingRewards over steps; bob free is asserted equal in NOTES
        bob_steps.append(r.get("step", 0))
        if actor == "bob_free":
            bob_free.append((r.get("step", 0), 0.0))  # no airdrop marker
    if rows:
        xs = [r.get("step", i) for i, r in enumerate(rows)]
        ax.plot(xs, [w18(r.get("pendingRewards", 0)) for r in rows], "o-", label="pendingRewards (bonder path)")
    ax.set_xlabel("step")
    ax.set_ylabel("pendingRewards (DETF)")
    ax.set_title("F7 bond vs mint books (D7) — free holder no expansion airdrop")
    ax.legend(fontsize=8)
    fig.tight_layout()
    FIG.mkdir(parents=True, exist_ok=True)
    fig.savefig(FIG / "F7_bond_vs_mint.png", dpi=140)
    plt.close(fig)
    print(f"wrote {FIG / 'F7_bond_vs_mint.png'}")


def plot_f8() -> None:
    """Expansion Policy vs Open from D5+D8."""
    fig, ax = plt.subplots(figsize=(8, 4.5))
    for key, label in (("D8", "Policy D8"), ("D5", "Open D5")):
        rows = _rows(key)
        if not rows:
            continue
        xs = [r.get("step", i) for i, r in enumerate(rows)]
        ax.plot(xs, [w18(r.get("pendingRewards", 0)) for r in rows], "o-", label=f"{label} pending")
        ax.plot(xs, [w18(r.get("totalSupply", 0)) for r in rows], "s--", alpha=0.6, label=f"{label} supply")
    ax.set_xlabel("step")
    ax.set_ylabel("amount")
    ax.set_title("F8 expansion: Policy vs Open (D5+D8)")
    ax.legend(fontsize=7)
    fig.tight_layout()
    FIG.mkdir(parents=True, exist_ok=True)
    fig.savefig(FIG / "F8_expansion_policy_vs_open.png", dpi=140)
    plt.close(fig)
    print(f"wrote {FIG / 'F8_expansion_policy_vs_open.png'}")


def plot_f9() -> None:
    """Protocol BPT before/after compound from D9."""
    rows = _rows("D9")
    fig, ax = plt.subplots(figsize=(8, 4.5))
    if rows:
        xs = [r.get("step", i) for i, r in enumerate(rows)]
        ax.plot(xs, [w18(r.get("protocolBpt", 0)) for r in rows], "o-", color="C0", label="protocolBpt")
    ax.set_xlabel("step")
    ax.set_ylabel("protocol BPT principal")
    ax.set_title("F9 protocol compound (D9)")
    ax.legend()
    fig.tight_layout()
    FIG.mkdir(parents=True, exist_ok=True)
    fig.savefig(FIG / "F9_protocol_compound.png", dpi=140)
    plt.close(fig)
    print(f"wrote {FIG / 'F9_protocol_compound.png'}")


PLOTTERS = {
    "F1": plot_f1,
    "F2": plot_f2,
    "F3": plot_f3,
    "F4": plot_f4,
    "F7": plot_f7,
    "F8": plot_f8,
    "F9": plot_f9,
}


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--fig", action="append", choices=list(PLOTTERS.keys()), help="Plot specific figure(s)")
    args = p.parse_args()
    figs = args.fig or list(PLOTTERS.keys())
    for f in figs:
        PLOTTERS[f]()


if __name__ == "__main__":
    main()
