"""
MiniMax council member model - run v4-swap-capture-evidence-20261026-01a177b3.

Exact rational (fractions.Fraction) model of the Uniswap V4 UpperLowerWings vault
money path, used to test the APEX-2026-012 mitigation candidates.

MODEL DOMAIN:
  token0 = TARGET, token1 = OPPOSING.  Pool = single range, constant-product
  equivalent: a full-range V4 position has x = L/sqrt(P), y = L*sqrt(P), hence
  x*y = L^2, so the pool is exactly CP with k = L_total^2.  All arithmetic exact.
  f = the V4 LP fee charged on the INPUT token.  No hooks (the production quote
  requires key.hooks == address(0)).  No external price of any kind.
  psi = the vault's share of pool liquidity (full-range equivalent); psi = 0 is
  Model A (vault holds idle inventory only), psi > 0 is Model B (vault holds LP).
  Adding/removing liquidity at the CURRENT price scales BOTH reserves by the same
  factor and leaves the price unchanged - the exact V4 "JIT liquidity" mechanic.
  Fees never enter the pool's virtual reserves; they accrue to a separate LP fee
  pot, as in V3/V4.

LEDGERS: token0 and token1 are conserved across
  attacker wallet + vault idle + pool reserves + LP fee pot.
"""

from fractions import Fraction as F

E = 10 ** 18


def sell0(x, y, s, f):
    """Exact input: sell s token0 (TARGET) into pool, receive token1 (OPPOSING)."""
    a = s * (1 - f)
    x2 = x + a
    y2 = x * y / x2
    return x2, y2, y - y2


def sell1(x, y, u, f):
    """Exact input: sell u token1 (OPPOSING) into pool, receive token0 (TARGET)."""
    a = u * (1 - f)
    y2 = y + a
    x2 = x * y / y2
    return x2, y2, x - x2


def proceeds1(x, y, u, f):
    """token0 that would be received for selling u token1; state unchanged."""
    a = u * (1 - f)
    return x - x * y / (y + a)


def add_liq(x, y, psi, sigma):
    return x * sigma, y * sigma, psi / sigma


def remove_liq(x, y, psi, sigma):
    return x / sigma, y / sigma, psi * sigma


def quote_value(x, y, psi, a_t, a_o, f):
    """PRODUCTION whole-book liquidation quote: remove ALL owned liquidity, then
    simulate selling the whole opposing side into the remaining external depth.
    Returns (value_in_TARGET, external_x, external_y)."""
    xe, ye = x * (1 - psi), y * (1 - psi)
    return (a_t + psi * x) + proceeds1(xe, ye, a_o + psi * y, f), xe, ye


def production_control(a_t, a_o, x, y, psi, supply, d, f, sigma_jit=1):
    """RULE 1 (current production): no entrant swap; mint and payout use the live
    whole-book quote.  Auditor order: deposit at the honest quote, then add free
    JIT depth, then redeem at the inflated quote, then remove the depth."""
    v0, _, _ = quote_value(x, y, psi, a_t, a_o, f)
    xa, ya, pa = add_liq(x, y, psi, sigma_jit)
    m = supply * d / v0
    v1, _, _ = quote_value(xa, ya, pa, a_t, a_o, f)
    payout = v1 * m / (supply + m)
    return dict(v0=v0, v1=v1, m=m, payout=payout, profit=payout - d,
                audit_algebra=d * (v1 - v0 - d) / (v0 + d))


def rule2(a_t, a_o, x, y, psi, supply, d, f, s_frac=1, sigma_jit=1):
    """RULE 2: a real deposit-side swap is added, but mint AND payout still use the
    live whole-book quote."""
    v_t, v_o = a_t, a_o
    px, py = x, y
    att = F(0)
    att -= d
    v_t += d
    s = s_frac * d
    if s > 0:
        px, py, w = sell0(px, py, s, f)
        v_t -= s
        v_o += w
    v0, _, _ = quote_value(px, py, psi, v_t, v_o, f)
    m = supply * d / v0
    px, py = px * sigma_jit, py * sigma_jit
    v1, _, _ = quote_value(px, py, psi, v_t, v_o, f)
    payout = v1 * m / (supply + m)
    return dict(v0=v0, v1=v1, payout=payout, profit=payout - d)


def mitigated(a_t, a_o, x, y, psi, supply, d, f, s_frac=1, sigma_pre=1, sigma_exit=1,
              rule="mit"):
    """RULE 3: executed-price mint + pro-rata actual exit sale.
    RULE 1: production quote mint + production quote payout (control).
    Returns (attacker_profit, both_tokens_conserved, detail).

    Mint (rule='mit'): the vault swaps s = s_frac*D TARGET into the pool, receives
    w OPPOSING, and marks the book at q_exec = s/w:
        V_ref = (post-swap full inventory at q_exec) - D
              = (A_T + D - s) + q_exec*(A_O + w) - D
              = A_T + q_exec*A_O                       (pre-swap naming; equal)
    shares m = S*D/V_ref.
    Exit: the holder takes phi = m/(S+m) of every position and of both idle
    balances, the vault sells phi*A_O' OPPOSING into the pool and pays
    phi*A_T' TARGET + the actual proceeds.
    """
    v_t, v_o = a_t, a_o
    px, py = x, y
    att = F(0)
    fee0 = fee1 = F(0)
    total0 = v_t + v_o + px + py + fee0 + fee1 + att
    att -= d
    v_t += d
    if sigma_pre != 1:
        px, py = px * sigma_pre, py * sigma_pre
        psi = psi / sigma_pre
    s = s_frac * d
    if s > 0:
        px, py, w = sell0(px, py, s, f)
        fee0 += s * f
        v_t -= s
        v_o += w
        q_exec = s / w
    else:
        q_exec = px / py
    if rule == "prod":
        v_ref, _, _ = quote_value(px, py, psi, v_t, v_o, f)
        m = supply * d / v_ref
    else:
        v_ref = (v_t + psi * px) + q_exec * (v_o + psi * py) - d
        m = supply * d / v_ref
    supply2 = supply + m
    if sigma_exit != 1:
        px, py = px * sigma_exit, py * sigma_exit
        psi = psi / sigma_exit
    if rule == "prod":
        v1, _, _ = quote_value(px, py, psi, v_t, v_o, f)
        payout = v1 * m / supply2
        v_t -= payout
    else:
        phi = m / supply2
        factor = 1 - phi * psi
        p0 = phi * psi * px
        p1 = phi * psi * py
        px, py = px * factor, py * factor
        psi = psi * (1 - phi) / factor
        v_t += p0
        v_o += p1
        slice_t = phi * v_t
        slice_o = phi * v_o
        px, py, proceeds = sell1(px, py, slice_o, f)
        fee1 += slice_o * f
        v_t -= slice_t
        v_o -= slice_o
        payout = slice_t + proceeds
    att += payout
    if sigma_pre != 1:
        px, py = px / sigma_pre, py / sigma_pre
        psi = psi * sigma_pre
    if sigma_exit != 1:
        px, py = px / sigma_exit, py / sigma_exit
        psi = psi * sigma_exit
    total1 = v_t + v_o + px + py + fee0 + fee1 + att
    return att, total0 == total1, dict(v_ref=v_ref, q_exec=q_exec, m=m, payout=payout,
                                       v_t=v_t, v_o=v_o, px=px, py=py, fee0=fee0, fee1=fee1)


MAX_ABS_TICK_MOVE = 9116


def truncate(cur, prev):
    return max(min(cur, prev + MAX_ABS_TICK_MOVE), prev - MAX_ABS_TICK_MOVE)


def observe_single(t0, now, seconds_ago, tick_):
    """Faithful port of UniswapV4TruncatedTwapOracleLib.observeSingle for cardinality == 1."""
    if seconds_ago == 0:
        return 0 + tick_ * (now - t0)
    target = now - seconds_ago
    if t0 <= target:
        before_ts, before_cum = t0, 0
        at_ts, at_cum = target, 0 + tick_ * (target - t0)
    else:
        before_ts, before_cum = t0, 0
        at_ts, at_cum = now, 0 + tick_ * (now - t0)
    if target == before_ts:
        return before_cum
    if target == at_ts:
        return at_cum
    return before_cum + ((at_cum - before_cum) // (at_ts - before_ts)) * (target - before_ts)


def consult_as_written(t0, tick0, now, live_tick, window):
    """Faithful port of UniswapV4MultiPoolTwapOracleTarget.consult ->
    UniswapV4TruncatedTwapOracleLib.consult for a stale (cardinality == 1) oracle."""
    tick_ = truncate(live_tick, tick0)
    c0 = observe_single(t0, now, window, tick_)
    c1 = observe_single(t0, now, 0, tick_)
    delta = c1 - c0
    mean = delta // window
    if delta < 0 and delta % window != 0:
        mean -= 1
    return mean, tick_


def main():
    b = F(1000 * E)
    fee = F(3000, 10 ** 6)
    d = F(100 * E)
    print("== CONTROL: production rule, no manipulation ==")
    r = production_control(b, b, b, b, F(0), b, d, fee, sigma_jit=1)
    print(f"   profit={float(r['profit'])/E:+.9f}e18")
    print("== CONTROL: production rule, JIT depth 100 (auditor shape) ==")
    r = production_control(b, b, b, b, F(0), b, d, fee, sigma_jit=100)
    print(f"   profit={float(r['profit'])/E:+.9f}e18   audit algebra="
          f"{float(r['audit_algebra'])/E:+.9f}e18")
    print("== RULE 2: swap added, whole-book quote retained, JIT depth 100 ==")
    r = rule2(b, b, b, b, F(0), b, d, fee, s_frac=1, sigma_jit=100)
    print(f"   profit={float(r['profit'])/E:+.9f}e18")
    print("== RULE 3: honest round trip, zero manipulation, s_frac=1 ==")
    att, ok, det = mitigated(b, b, b, b, F(0), b, d, fee, s_frac=1)
    print(f"   profit={float(att)/E:+.9f}e18   both tokens conserved={ok}")
    print(f"   q_exec={float(det['q_exec']):.9f} V_ref={float(det['v_ref'])/E:.9f}e18")
    print("== RULE 3: exit-side free JIT depth 100 increment ==")
    base, _, _ = mitigated(b, b, b, b, F(0), b, d, fee, s_frac=1)
    jit, ok2, _ = mitigated(b, b, b, b, F(0), b, d, fee, s_frac=1, sigma_exit=100)
    print(f"   base={float(base)/E:+.9f}e18  jit={float(jit)/E:+.9f}e18  "
          f"increment={float(jit-base)/E:+.9f}e18  conserved={ok2}")
    print("== TWAP as written: stale consult == truncate(live tick, prev tick) ==")
    for live in (0, 900, 9116, -9116):
        mean, tick_ = consult_as_written(0, 0, 100000, live, 3600)
        print(f"   live={live:>6}  consult(3600)={mean:>6} ticks  truncated_live={tick_}")


if __name__ == "__main__":
    main()
