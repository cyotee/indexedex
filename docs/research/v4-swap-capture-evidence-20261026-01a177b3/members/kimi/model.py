# Kimi independent member model: swap-capture evidence for APEX-2026-012

# Standalone exact-arithmetic ledger for the council question:
# do actual swaps during deposit and exit eliminate APEX-2026-012 when the
# target token's only liquidity is the underlying pool?
#
# Model: one Uniswap V3/V4 tick interval with liquidity L (virtual reserves
# Xv = target/token0, Yv = opposing/token1, k = Xv*Yv invariant, spot
# p = Yv/Xv = opposing per target). All arithmetic is exact rational
# (fractions.Fraction); V3/V4 per-step integer rounding (<1 unit per step,
# conservative direction in production SwapMath) is omitted. LP fee on input,
# V3 style: a_eff = a*(1 - fee). No protocol fee. All sales stay inside the
# interval (parameters chosen so no tick crossing occurs).
#
# Conservation harness Ledger: attacker wallet delta + vault idle + pool
# custody (curve reserves + uncollected fees) is constant per token, checked
# exactly after every scenario. Attacker profit is reported only after a full
# flatten to target (leftover opposing bought back or sold at real slippage);
# shares, LP inventory and debt are all closed.
#
# Production reachability: idle book (no core/wing positions) corresponds to a
# 100% liquid sleeve or geometrically unavailable wings; the scripted
# production sleeve is 0% (fully deployed). The mint/payout equations and the
# quote mechanics are identical with positions; positions add price-dependent
# book composition, self-fill on vault swaps, and fee accrual, which are
# unmodeled attack-surface-increasing channels, not hole-closing ones.
# Harvest, both-wing activation, hooks, multi-interval bitmap walks and the
# marketLimited (unsold-valued-at-zero) haircut are unmodeled.

from fractions import Fraction as F


class Pool:
    def __init__(self, Xv, Yv, fee_pips=3000):
        self.Xv = F(Xv); self.Yv = F(Yv)
        self.k = self.Xv * self.Yv
        self.fee = F(fee_pips, 10 ** 6)
        self.fee0 = F(0); self.fee1 = F(0)   # uncollected LP fees, in pool custody
        self.jit_frac = F(0)                 # share of active liquidity that is the attacker's
        self.jit_fee0 = F(0); self.jit_fee1 = F(0)

    def p(self):
        return self.Yv / self.Xv             # opposing per target

    def swap_in0(self, a):                   # exact-input target -> opposing
        a = F(a); a_eff = a * (1 - self.fee); fee = a - a_eff
        out = self.Yv - self.k / (self.Xv + a_eff)
        self.Xv += a_eff; self.Yv -= out
        self.fee0 += fee; self.jit_fee0 += fee * self.jit_frac
        return out

    def swap_in1(self, b):                   # exact-input opposing -> target
        b = F(b); b_eff = b * (1 - self.fee); fee = b - b_eff
        out = self.Xv - self.k / (self.Yv + b_eff)
        self.Yv += b_eff; self.Xv -= out
        self.fee1 += fee; self.jit_fee1 += fee * self.jit_frac
        return out

    def jit_add(self, c):
        """Add settled liquidity = c * current L, proportional at current price."""
        c = F(c)
        c0, c1 = c * self.Xv, c * self.Yv
        self.Xv += c0; self.Yv += c1; self.k = self.Xv * self.Yv
        self.jit_frac = c / (1 + c)
        self.jit_fee0 = F(0); self.jit_fee1 = F(0)
        return c0, c1

    def jit_remove(self):
        """Remove exactly the added share; returns principal at current price + accrued fees."""
        s = self.jit_frac
        o0, o1 = s * self.Xv, s * self.Yv
        self.Xv -= o0; self.Yv -= o1; self.k = self.Xv * self.Yv
        f0, f1 = self.jit_fee0, self.jit_fee1
        self.fee0 -= f0; self.fee1 -= f1
        self.jit_frac = F(0); self.jit_fee0 = F(0); self.jit_fee1 = F(0)
        return o0, o1, f0, f1

    def quote_sell_opposing(self, amount, depth_scale=F(1)):
        """Production LiquidationQuote shape: simulate exact-input sale of `amount`
        opposing at current price against depth scaled by depth_scale (the vault's own
        liquidity is already absent in the idle book; attacker depth counts)."""
        b = F(amount); b_eff = b * (1 - self.fee)
        Xq = self.Xv * depth_scale; Yq = self.Yv * depth_scale; kq = Xq * Yq
        return Xq - kq / (Yq + b_eff)


class Ledger:
    """Exact two-token conservation: attacker delta + vault idle + pool custody constant."""

    def __init__(self, pool, A_T, A_O, S):
        self.pool = pool
        self.vT = F(A_T); self.vO = F(A_O)
        self.S = F(S)
        self.aT = F(0); self.aO = F(0)
        self.T0 = self.vT + pool.Xv + pool.fee0
        self.O0 = self.vO + pool.Yv + pool.fee1

    def check(self, label):
        totT = self.vT + self.aT + self.pool.Xv + self.pool.fee0
        totO = self.vO + self.aO + self.pool.Yv + self.pool.fee1
        assert totT == self.T0, (label, "target leak", totT - self.T0)
        assert totO == self.O0, (label, "opposing leak", totO - self.O0)


def flatten(pool, lg):
    """Close the attacker's residual opposing position at real slippage; ends holding
    only target. Surplus opposing is sold; a shortfall is bought back exactly."""
    if lg.aO > 0:
        lg.aT += pool.swap_in1(lg.aO); lg.aO = F(0)
    elif lg.aO < 0:
        need = -lg.aO
        a_eff = pool.k / (pool.Yv - need) - pool.Xv
        a = a_eff / (1 - pool.fee)
        got = pool.swap_in0(a)
        assert got >= need
        lg.aT -= a; lg.aO += got; lg.aO = F(0)
    return lg.aT


def quote_value(pool, A_T, A_O):
    return F(A_T) + pool.quote_sell_opposing(A_O)


def fl(x):
    return float(F(x))


# --- Rule 1: production. No entrant swap; mint and payout use the live whole-book quote.

def scenario_rule1(D, A_T, A_O, S, L, fee_pips=3000, jit_c=None, label="rule1"):
    pool = Pool(L, L, fee_pips)
    lg = Ledger(pool, A_T, A_O, S)
    V0 = quote_value(pool, lg.vT, lg.vO)
    m = S * D / V0                              # Accounting.issue = mulDiv(supply, credit, value)
    lg.aT -= D; lg.vT += D
    if jit_c is not None:                       # attacker adds settled depth (audit settled variant)
        c0, c1 = pool.jit_add(jit_c); lg.aT -= c0; lg.aO -= c1
    V1 = quote_value(pool, lg.vT, lg.vO)
    payout = m * V1 / (S + m)                   # Accounting.entitlement = mulDiv(shares, value, supply)
    lg.vT -= payout; lg.aT += payout            # paid from the local target sleeve
    if jit_c is not None:
        o0, o1, f0, f1 = pool.jit_remove(); lg.aT += o0 + f0; lg.aO += o1 + f1
    lg.check(label)
    V_after = quote_value(pool, lg.vT, lg.vO)
    return dict(V0=V0, V1=V1, m=m, payout=payout, att_net_T=lg.aT, att_net_O=lg.aO,
                inc_before=V0 / S, inc_after=V_after / S)


def scenario_rule1_deflation(D, A_T, A_O, S, L, attacker_depth_c, fee_pips=3000):
    """Opposite direction: attacker owns standing depth, pulls it to crash the quote,
    deposits at the crashed quote, restores depth, redeems at the honest quote."""
    pool = Pool(L, L, fee_pips)
    lg = Ledger(pool, A_T, A_O, S)
    c0, c1 = pool.jit_add(attacker_depth_c); lg.aT -= c0; lg.aO -= c1     # standing depth
    V_honest = quote_value(pool, lg.vT, lg.vO)
    o0, o1, f0, f1 = pool.jit_remove(); lg.aT += o0 + f0; lg.aO += o1 + f1
    V_crash = quote_value(pool, lg.vT, lg.vO)
    lg.aT -= D; lg.vT += D
    m = S * D / V_crash
    c0, c1 = pool.jit_add(attacker_depth_c); lg.aT -= c0; lg.aO -= c1     # restore
    V1 = quote_value(pool, lg.vT, lg.vO)
    payout = m * V1 / (S + m)
    lg.vT -= payout; lg.aT += payout
    o0, o1, f0, f1 = pool.jit_remove(); lg.aT += o0 + f0; lg.aO += o1 + f1  # unwind fully
    lg.check("rule1-deflation")
    return dict(V_honest=V_honest, V_crash=V_crash, V1=V1, m=m, payout=payout,
                att_net_T=lg.aT, att_net_O=lg.aO)


# --- Rule 2: real entry/exit swaps execute, but mint and payout still use the live
# --- whole-book quote.

def scenario_rule2(D, A_T, A_O, S, L, alpha, fee_pips=3000, jit_c=F(9), label="rule2"):
    pool = Pool(L, L, fee_pips)
    lg = Ledger(pool, A_T, A_O, S)
    V_init = quote_value(pool, lg.vT, lg.vO)
    lg.aT -= D
    dO = pool.swap_in0(alpha * D)           # mandatory entry swap, realized
    lg.vO += dO
    V0 = quote_value(pool, lg.vT, lg.vO)    # quote reads post-swap book, pending deposit excluded
    m = S * D / V0                          # mint STILL the live whole-book quote
    lg.vT += D - alpha * D
    if jit_c is not None:
        c0, c1 = pool.jit_add(jit_c); lg.aT -= c0; lg.aO -= c1
    V1 = quote_value(pool, lg.vT, lg.vO)
    payout = m * V1 / (S + m)               # payout STILL the live whole-book quote
    f = m / (S + m)
    slice_O = f * lg.vO
    proceeds = pool.swap_in1(slice_O)       # exit slice sale executes; proceeds retained by book
    lg.vO -= slice_O; lg.vT += proceeds
    lg.vT -= payout; lg.aT += payout
    if jit_c is not None:
        o0, o1, f0, f1 = pool.jit_remove(); lg.aT += o0 + f0; lg.aO += o1 + f1
    netT = flatten(pool, lg)
    lg.check(label)
    V_after = quote_value(pool, lg.vT, lg.vO)
    return dict(m=m, payout=payout, att_net_T=netT,
                inc_before=V_init / S, inc_after=V_after / S)


# --- Rule 3: literal executed-price mint, realized slice exit.
# --- Attack: buy t1 target (price up) -> deposit with mandatory entry swap (vault sells
# --- alpha*D target at elevated prices, p_exec = target per opposing falls) -> sell t1 back
# --- (price restored toward/below p0) -> redeem slice at realized prices.

def scenario_rule3(D, A_T, A_O, S, L, alpha, t1, fee_pips=3000, post_swap=False):
    pool = Pool(L, L, fee_pips)
    lg = Ledger(pool, A_T, A_O, S)
    V_init = quote_value(pool, lg.vT, lg.vO)
    if t1:
        b_eff = pool.k / (pool.Xv - F(t1)) - pool.Yv
        b = b_eff / (1 - pool.fee)
        got = pool.swap_in1(b)              # attacker buys t1 target
        lg.aO -= b; lg.aT += got
    lg.aT -= D
    dO = pool.swap_in0(alpha * D)
    p_exec = (alpha * D) / dO               # executed target per opposing
    if post_swap:
        # fee-aware post-swap variant: retained book incl. deposit remainder and swap proceeds.
        # Identity: p_exec * dO == alpha * D, so denom = A_T + D + p_exec * A_O exactly.
        denom = (A_T + D - alpha * D) + p_exec * (A_O + dO)
    else:
        denom = A_T + p_exec * A_O          # pre-entry book
    m = S * D / denom
    lg.vT += D - alpha * D; lg.vO += dO
    if t1:
        back = pool.swap_in0(F(t1))         # attacker sells the t1 target back
        lg.aT -= F(t1); lg.aO += back
    f = m / (S + m)
    slice_T = f * lg.vT; slice_O = f * lg.vO
    proceeds = pool.swap_in1(slice_O)       # realized sale of the slice only
    lg.vT -= slice_T; lg.vO -= slice_O
    lg.aT += slice_T + proceeds             # payout = slice target + realized proceeds, no top-up
    netT = flatten(pool, lg)
    lg.check("rule3")
    V_after = quote_value(pool, lg.vT, lg.vO)
    return dict(p_exec=p_exec, m=m, f=f, att_net_T=netT,
                inc_before=V_init / S, inc_after=V_after / S)


# --- Rule 4: price-free proportional position-vector mint (idle book = two components),
# --- exact refunds, realized slice exit.

def scenario_rule4(D, A_T, A_O, S, L, alpha, t1, fee_pips=3000):
    pool = Pool(L, L, fee_pips)
    lg = Ledger(pool, A_T, A_O, S)
    inc_T0, inc_O0 = F(A_T) / S, F(A_O) / S
    if t1:
        b_eff = pool.k / (pool.Xv - F(t1)) - pool.Yv
        b = b_eff / (1 - pool.fee)
        got = pool.swap_in1(b)
        lg.aO -= b; lg.aT += got
    lg.aT -= D
    dO = pool.swap_in0(alpha * D)           # realized conversion at whatever price
    c_T = D - alpha * D; c_O = dO
    f_T = c_T / (A_T + c_T)
    f_O = c_O / (A_O + c_O) if (A_O + c_O) != 0 else F(1)
    f = min(f_T, f_O)                       # mint fraction set by the scarcest relative component
    r_T = c_T - f * (A_T + c_T)             # exact refunds to the entrant
    r_O = c_O - f * (A_O + c_O)
    lg.vT += c_T - r_T; lg.vO += c_O - r_O
    lg.aT += r_T; lg.aO += r_O
    m = f * S / (1 - f)
    if t1:
        back = pool.swap_in0(F(t1))
        lg.aT -= F(t1); lg.aO += back
    fe = m / (S + m)
    slice_T = fe * lg.vT; slice_O = fe * lg.vO
    proceeds = pool.swap_in1(slice_O)
    lg.vT -= slice_T; lg.vO -= slice_O
    lg.aT += slice_T + proceeds
    netT = flatten(pool, lg)
    lg.check("rule4")
    return dict(f=f, m=m, att_net_T=netT,
                inc_T_ratio=(lg.vT / S) / inc_T0, inc_O_ratio=(lg.vO / S) / inc_O0,
                p_final=pool.p())


def main():
    A_T = A_O = F(10) ** 12 / 2             # balanced book, mark 1e12 at p0 = 1
    A_T2, A_O2 = F(2) * 10 ** 11, F(8) * 10 ** 11   # 80%-opposing book, mark 1e12
    S = F(10) ** 12
    L = F(10) ** 12                         # standing external depth, virtual each side
    D = F(10) ** 11                         # entrant deposit = 10% of book mark

    print("== rule 1 (production): control and settled-JIT attack ==")
    ctrl = scenario_rule1(D, A_T, A_O, S, L, jit_c=None)
    jit = scenario_rule1(D, A_T, A_O, S, L, jit_c=F(9))
    formula = D * (jit["V1"] - jit["V0"] - D) / (jit["V0"] + D)
    print("control: payout =", fl(ctrl["payout"]), "attacker net =", fl(ctrl["att_net_T"]))
    print("jit: V0 %.6e V1 %.6e minted %.6e paid %.6e" %
          (fl(jit["V0"]), fl(jit["V1"]), fl(jit["m"]), fl(jit["payout"])))
    print("jit attacker profit =", fl(jit["att_net_T"]),
          "| audit formula D(V1-V0-D)/(V0+D) =", fl(formula),
          "| incumbent loss =", fl((jit["inc_before"] - jit["inc_after"]) * S))
    rd = scenario_rule1_deflation(D, A_T, A_O, S, L, F(9))
    print("deflation direction: V %.4e -> %.4e -> %.4e, attacker net = %.6f, leftover O = %.6f"
          % (fl(rd["V_honest"]), fl(rd["V_crash"]), fl(rd["V1"]),
             fl(rd["att_net_T"]), fl(rd["att_net_O"])))

    print("== rule 2 (swaps executed, quote pricing kept) ==")
    r2c = scenario_rule2(D, A_T, A_O, S, L, F(1, 2), jit_c=None)
    r2j = scenario_rule2(D, A_T, A_O, S, L, F(1, 2), jit_c=F(9))
    print("control entrant net =", fl(r2c["att_net_T"]), "(ordinary fee drag)")
    print("jit attacker net (closed) =", fl(r2j["att_net_T"]),
          "| incumbent loss =", fl((r2j["inc_before"] - r2j["inc_after"]) * S))

    print("== rule 3 (executed-price mint): boundary scan, balanced book, fee = 0, t1 = 1e11 ==")
    for a100 in range(30, 52, 2):
        r = scenario_rule3(D, A_T, A_O, S, L, F(a100, 100), F(10) ** 11, fee_pips=0)
        print("  alpha=%.2f net %+.5e" % (a100 / 100, fl(r["att_net_T"])))
    print("== rule 3 headline: 51% entry swap on the 80%-opposing book, fee = 0.3% ==")
    w = scenario_rule3(D, A_T2, A_O2, S, L, F(51, 100), F(2) * 10 ** 11, fee_pips=3000)
    print("  attacker net (closed) =", fl(w["att_net_T"]), "| p_exec =", fl(w["p_exec"]),
          "| incumbent/share quote %.6f -> %.6f" % (fl(w["inc_before"]), fl(w["inc_after"])))
    w2 = scenario_rule3(D, A_T2, A_O2, S, L, F(3, 10), F(4) * 10 ** 11, fee_pips=3000,
                        post_swap=True)
    print("== rule 3 post-swap fee-aware variant, 30% swap, same book, t1 = 4e11 ==")
    print("  attacker net (closed) =", fl(w2["att_net_T"]))
    wd = scenario_rule3(F(5) * 10 ** 11, A_T2, A_O2, S, L, F(51, 100), F(2) * 10 ** 11,
                        fee_pips=3000)
    print("== rule 3 attacker-chosen size D = 5e11, 51% swap, same book ==")
    print("  attacker net (closed) =", fl(wd["att_net_T"]))

    print("== rule 4 (price-free proportional mint): control and attacks ==")
    c4 = scenario_rule4(D, A_T, A_O, S, L, F(1, 2), 0)
    print("  control net =", fl(c4["att_net_T"]), "| inc ratios T", c4["inc_T_ratio"],
          "O", c4["inc_O_ratio"])
    for t1 in (F(5) * 10 ** 10, F(10) ** 11, F(2) * 10 ** 11, F(4) * 10 ** 11):
        r = scenario_rule4(D, A_T, A_O, S, L, F(3, 10), t1)
        print("  attack t1=%.0e: net %+.4e incT %.6f incO %.6f (exact 1: %s/%s)" %
              (fl(t1), fl(r["att_net_T"]), fl(r["inc_T_ratio"]), fl(r["inc_O_ratio"]),
               r["inc_T_ratio"] == 1, r["inc_O_ratio"] == 1))
    for t1 in (F(10) ** 11, F(2) * 10 ** 11, F(4) * 10 ** 11):
        r = scenario_rule4(D, A_T2, A_O2, S, L, F(3, 10), t1)
        print("  80%%-opp attack t1=%.0e: net %+.4e incT %.6f incO %.6f (exact 1: %s/%s)" %
              (fl(t1), fl(r["att_net_T"]), fl(r["inc_T_ratio"]), fl(r["inc_O_ratio"]),
               r["inc_T_ratio"] == 1, r["inc_O_ratio"] == 1))

    print("== rule 5 constant: 1.0001^9116 =", float(1.0001) ** 9116)


if __name__ == "__main__":
    main()
