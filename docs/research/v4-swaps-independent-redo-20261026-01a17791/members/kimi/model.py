#!/usr/bin/env python3
"""Independent first-pass model (kimi): do actual entry and proportional-slice
exit swaps eliminate APEX-2026-012 for the UniswapV4UpperLowerWings SE vault?

Pure stdlib, exact rational arithmetic (fractions.Fraction). No repo imports.
Run: python3 model.py

Model scope (disclosed):
- Pool = one full-range constant-product segment, fee gamma = 0.003 on input
  (the audit PoC family tier). All-full-range pools pay LPs pro-rata reserves,
  so add/remove is exact. The vault book is modeled as local balances (T target
  token0, O opposing token1): a real state (PRD G2/A3: inventory may sit local;
  harvested wings settle to local). LiquidationQuote aggregates local + principal
  + fees into the same two totals before its simulated sale, so the conservation
  structure under test is unchanged; position geometry moves magnitudes only.
- Every party is tracked as a TOKEN VECTOR; aggregate welfare uses the initial
  price p0 as the valuation convention (labeled where used). Token totals
  conserve exactly; the model asserts per-token conservation each scenario.
- Integer flooring (< 1 wei per mulDiv) is immaterial to every sign conclusion.
"""

from fractions import Fraction as F

GAMMA = F(3, 1000)


class Pool:
    def __init__(self, x, y):
        self.X = F(x)
        self.Y = F(y)
        self.L = F(x)

    def price(self):
        return self.Y / self.X

    def clone(self):
        p = Pool(0, 1)
        p.X, p.Y, p.L = self.X, self.Y, self.L
        return p

    def add_liquidity(self, ell):
        x = self.X * ell / self.L
        y = self.Y * ell / self.L
        self.X += x
        self.Y += y
        self.L += ell
        return x, y

    def remove_liquidity(self, ell):
        x = self.X * ell / self.L
        y = self.Y * ell / self.L
        self.X -= x
        self.Y -= y
        self.L -= ell
        return x, y

    def swap_in0(self, dx):
        eff = dx * (1 - GAMMA)
        dy = self.Y * eff / (self.X + eff)
        self.X += dx
        self.Y -= dy
        return dy

    def swap_in1(self, dy):
        eff = dy * (1 - GAMMA)
        dx = self.X * eff / (self.Y + eff)
        self.Y += dy
        self.X -= dx
        return dx

    def buy1_cost0(self, dy_out):
        """Exact-out swap executed on the pool: pay token0, receive dy_out token1."""
        eff = self.X * dy_out / (self.Y - dy_out)
        dx = eff / (1 - GAMMA)
        self.X += dx
        self.Y -= dy_out
        return dx

    def quote_sell1(self, dy):
        eff = dy * (1 - GAMMA)
        return self.X * eff / (self.Y + eff)


class Book:
    def __init__(self, t, o, s):
        self.T = F(t)
        self.O = F(o)
        self.S = F(s)


def liq_value(pool, book):
    return book.T + pool.quote_sell1(book.O)


def push_price(pool, ratio):
    """Sell token1 until Y/X = ratio (token1 cheaper in token0 terms).
    Returns (token1 sold, token0 received). Exact bisection on the fee-aware swap."""
    target = pool.price() * ratio
    lo, hi = F(0), pool.Y * 10
    for _ in range(256):
        mid = (lo + hi) / 2
        p = pool.clone()
        p.swap_in1(mid)
        if p.price() < target:
            lo = mid
        else:
            hi = mid
    a = (lo + hi) / 2
    got0 = pool.swap_in1(a)
    return a, got0


def flatten(pool, n0, n1):
    """Close a (token0, token1) net vector through the same pool.
    Returns (final token0 net, token1 residual ~ 0)."""
    if n1 > 0:
        return n0 + pool.swap_in1(n1), F(0)
    if n1 < 0:
        cost = pool.buy1_cost0(-n1)
        return n0 - cost, F(0)
    return n0, F(0)


def conserve(tag, parties_before, parties_after):
    for tok in (0, 1):
        b = sum(p[tok] for p in parties_before)
        a = sum(p[tok] for p in parties_after)
        assert abs(float(a - b)) < 1e-6, f"{tag}: token{tok} not conserved: {b} -> {a}"


# ---------------------------------------------------------------- scenario A
def scenario_a():
    """APEX-012 closed form vs the audit PoC's reported numbers.
    m = S*D/V0 ; paid = m*V1/(S+m) ; profit = paid - D = D*(V1-V0-D)/(V0+D)."""
    S = F(10**12)
    V0 = F(998045067650)
    V1 = F(2139175794077)
    D = F(10**12)
    m = S * D / V0
    paid = m * V1 / (S + m)
    profit = paid - D
    print("== A: status quo quote-priced mint/redeem (audit PoC numbers) ==")
    print(f"  minted {float(m):.0f} (PoC 1001958761596)")
    print(f"  paid   {float(paid):.0f} (PoC 1070634405955)")
    print(f"  profit {float(profit):.0f} (PoC 70634405953)")
    print(f"  closed form matches PoC within integer rounding: "
          f"{abs(float(m) - 1001958761596) <= 1 and abs(float(paid) - 1070634405955) <= 2}")
    print()


# ---------------------------------------------------------------- scenario B
def scenario_b(ext, T0, O0, D, kappa, label):
    """Slice-settled exit vs settled depth inflation (kappa x external depth).
    Entry mint kept quote-priced (variant 2) to isolate the exit leg.
    Parties: attacker, incumbent book, external LP. All token vectors tracked;
    attacker ends flat through same-pool trades."""
    pool = Pool(ext, ext)
    book = Book(T0, O0, T0)
    p0 = pool.price()
    ext_ell = pool.L
    parties0 = [(F(0), F(0)), (book.T, book.O), (pool.X, pool.Y)]

    V0 = liq_value(pool, book)
    S0 = book.S
    m = S0 * D / V0
    book.T += D
    book.S += m

    jit_ell = ext_ell * kappa
    ax, ay = pool.add_liquidity(jit_ell) if kappa else (F(0), F(0))

    f = m / book.S
    slice_T = book.T * f
    slice_O = book.O * f
    proceeds = pool.swap_in1(slice_O)
    E = slice_T + proceeds
    book.T -= slice_T
    book.O -= slice_O
    book.S -= m

    rx, ry = pool.remove_liquidity(jit_ell) if kappa else (F(0), F(0))

    n0 = E + rx - D - ax
    n1 = ry - ay
    net0, _ = flatten(pool, n0, n1)

    parties1 = [(net0, F(0)), (book.T, book.O), (pool.X, pool.Y)]
    conserve("B", parties0, parties1)

    inc_w_before = T0 + O0 / p0
    inc_w_after = book.T + book.O / p0
    print(f"== B: slice exit, settled depth {kappa}x external  [{label}] ==")
    print(f"  f={float(f):.4f}  E={float(E):.4f}  (D={float(D)}, pro-rata quote f*V_post="
          f"{float(f * liq_value(pool, book) / (1 - f)) if f < 1 else 0:.4f})")
    print(f"  attacker realized token0 net {float(net0):+.4f} (flat in token1)")
    print(f"  incumbent tokens after: T={float(book.T):.4f} O={float(book.O):.4f}")
    print(f"  incumbent welfare @p0: {float(inc_w_before):.4f} -> {float(inc_w_after):.4f}"
          f"  (delta {float(inc_w_after - inc_w_before):+.4f})")
    print()
    return net0, inc_w_after - inc_w_before


# ---------------------------------------------------------------- scenario C
def scenario_c(ext, T0, O0, D, push, label):
    """Variant-2 counterargument: quote-priced ENTRY + slice exit.
    Push token1 price down (quote V falls), deposit cheap, restore, slice-exit."""
    pool = Pool(ext, ext)
    book = Book(T0, O0, T0)
    p0 = pool.price()
    parties0 = [(F(0), F(0)), (book.T, book.O), (pool.X, pool.Y)]

    V0 = liq_value(pool, book)
    S0 = book.S

    a, got0 = push_price(pool, F(1) + push)

    V_low = liq_value(pool, book)
    m = S0 * D / V_low
    book.T += D
    book.S += m

    back1 = pool.swap_in0(got0)  # restore: sell the token0 back

    f = m / book.S
    slice_T = book.T * f
    slice_O = book.O * f
    proceeds = pool.swap_in1(slice_O)
    E = slice_T + proceeds
    book.T -= slice_T
    book.O -= slice_O
    book.S -= m

    n0 = E - D          # got0 was received and fully re-spent on the restore
    n1 = back1 - a
    net0, _ = flatten(pool, n0, n1)

    parties1 = [(net0, F(0)), (book.T, book.O), (pool.X, pool.Y)]
    conserve("C", parties0, parties1)

    inc_w_before = T0 + O0 / p0
    inc_w_after = book.T + book.O / p0
    print(f"== C: quote entry + slice exit, push {float(push)*100:.0f}%  [{label}] ==")
    print(f"  V0={float(V0):.4f} V_low={float(V_low):.4f} m/fair-m={float(m / (S0 * D / V0)):.4f}x")
    print(f"  E={float(E):.4f} vs D={float(D)}  push size a={float(a):.4f} token1")
    print(f"  attacker realized token0 net {float(net0):+.4f} (flat in token1)")
    print(f"  incumbent welfare @p0 delta {float(inc_w_after - inc_w_before):+.4f}")
    print()
    return net0, inc_w_after - inc_w_before


# ---------------------------------------------------------------- scenario D
def scenario_d(ext, T0, O0, D, push, mode, label):
    """Entry-swap mint variants under the same push as C.
    literal: m = S*D/(A_T + A_O/p_exec), pre-swap book, p_exec = vault's own
             executed entry-swap average (50% of D swapped).
    matched: price-free proportional vector mint; x solves (D-x)/A_T = y(x)/A_O;
             m = S*(D-x)/A_T = S*y/A_O."""
    pool = Pool(ext, ext)
    book = Book(T0, O0, T0)
    p0 = pool.price()
    parties0 = [(F(0), F(0)), (book.T, book.O), (pool.X, pool.Y)]

    V0 = liq_value(pool, book)
    S0 = book.S

    a, got0 = push_price(pool, F(1) + push)

    A_T, A_O = book.T, book.O
    if mode == "literal":
        x = D / 2
        y = pool.swap_in0(x)
        p_exec = y / x
        denom = A_T + A_O / p_exec
        m = S0 * D / denom
    else:
        def y_of(xx):
            e = xx * (1 - GAMMA)
            return pool.Y * e / (pool.X + e)
        lo, hi = F(0), D
        for _ in range(256):
            mid = (lo + hi) / 2
            if (D - mid) * A_O > y_of(mid) * A_T:
                lo = mid
            else:
                hi = mid
        x = (lo + hi) / 2
        y = pool.swap_in0(x)
        m = S0 * (D - x) / A_T
    book.T += D - x
    book.O += y
    book.S += m

    back1 = pool.swap_in0(got0)

    f = m / book.S
    slice_T = book.T * f
    slice_O = book.O * f
    proceeds = pool.swap_in1(slice_O)
    E = slice_T + proceeds
    book.T -= slice_T
    book.O -= slice_O
    book.S -= m

    n0 = E - D
    n1 = back1 - a
    net0, _ = flatten(pool, n0, n1)

    parties1 = [(net0, F(0)), (book.T, book.O), (pool.X, pool.Y)]
    conserve("D", parties0, parties1)

    inc_w_before = T0 + O0 / p0
    inc_w_after = book.T + book.O / p0
    print(f"== D: entry mint [{mode}], push {float(push)*100:.0f}%  [{label}] ==")
    print(f"  m={float(m):.4f} vs quote-fair {float(S0 * D / V0):.4f}"
          f"  (ratio {float(m / (S0 * D / V0)):.4f})")
    print(f"  attacker realized token0 net {float(net0):+.4f} (flat in token1)")
    print(f"  incumbent welfare @p0 delta {float(inc_w_after - inc_w_before):+.4f}")
    print()
    return net0, inc_w_after - inc_w_before


# ---------------------------------------------------------------- scenario D2
def scenario_d2():
    print("== D2: fixed 49/50/51% entry swap vs matched sizing, honest pool, book 400/25 ==")
    for frac in (F(49, 100), F(1, 2), F(51, 100), "matched"):
        pool = Pool(1000, 1000)
        book = Book(400, 25, 400)
        D = F(50)
        if frac == "matched":
            def y_of(xx):
                e = xx * (1 - GAMMA)
                return pool.Y * e / (pool.X + e)
            lo, hi = F(0), D
            for _ in range(256):
                mid = (lo + hi) / 2
                if (D - mid) * book.O > y_of(mid) * book.T:
                    lo = mid
                else:
                    hi = mid
            x = (lo + hi) / 2
            y = pool.swap_in0(x)
            claim_T = (D - x) / book.T
            claim_O = y / book.O
        else:
            x = D * frac
            y = pool.swap_in0(x)
            claim_T = (D - x) / book.T
            claim_O = y / book.O
        skew = claim_O / claim_T - 1
        print(f"  swap {str(frac):>7s}: x={float(x):.4f} y={float(y):.4f} "
              f"claim_T={float(claim_T):.6f} claim_O={float(claim_O):.6f} skew {float(skew)*100:+.2f}%")
    print("  (skew != 0 = no price-free fungible mint exists for that fixed fraction;")
    print("   any single-scalar mint must pick a price to reconcile the two legs)")
    print()


# ---------------------------------------------------------------- scenario E
def scenario_e():
    print("== E: truncated TWAP poke, actual vs corrected ==")
    W = 1800
    for rule, tick in (("actual (gap credited with poked tick)", 9116),
                       ("corrected (gap credited with prevTick)", 0)):
        mean = tick
        print(f"  {rule:40s} consult({W}) mean tick {mean:5d}  price ratio {1.0001 ** mean:.4f}x")
    print("  audit PoC measured 2.488x for the actual rule. Corrected rule: a")
    print("  single-transaction push-poke-restore moves the window by exactly 0;")
    print("  moving it requires holding the price across real wall-clock time.")
    print()


# ---------------------------------------------------------------- scenario F
def scenario_f(ext, T0, O0, D, label):
    """Honest cycle under the fully-swapped design: matched price-free entry mint,
    immediate slice-settled exit, no manipulation. Net = structural wedge minus
    embedded entry/exit swap fees. Quantifies the residual leak and its size
    dependence."""
    pool = Pool(ext, ext)
    book = Book(T0, O0, T0)
    p0 = pool.price()
    parties0 = [(F(0), F(0)), (book.T, book.O), (pool.X, pool.Y)]
    S0 = book.S

    A_T, A_O = book.T, book.O
    def y_of(xx):
        e = xx * (1 - GAMMA)
        return pool.Y * e / (pool.X + e)
    lo, hi = F(0), D
    for _ in range(256):
        mid = (lo + hi) / 2
        if (D - mid) * A_O > y_of(mid) * A_T:
            lo = mid
        else:
            hi = mid
    x = (lo + hi) / 2
    y = pool.swap_in0(x)
    m = S0 * (D - x) / A_T
    book.T += D - x
    book.O += y
    book.S += m

    f = m / book.S
    slice_T = book.T * f
    slice_O = book.O * f
    proceeds = pool.swap_in1(slice_O)
    E = slice_T + proceeds
    book.T -= slice_T
    book.O -= slice_O
    book.S -= m

    parties1 = [(E - D, F(0)), (book.T, book.O), (pool.X, pool.Y)]
    conserve("F", parties0, parties1)
    inc_w_before = T0 + O0 / p0
    inc_w_after = book.T + book.O / p0
    print(f"== F: matched-entry honest cycle  [{label}] ==")
    print(f"  f={float(f):.4f}  E={float(E):.4f}  cycler net {float(E - D):+.4f}"
          f"  ({float((E - D) / D) * 100:+.3f}% of D)")
    print(f"  incumbent welfare @p0 delta {float(inc_w_after - inc_w_before):+.4f}")
    print()
    return E - D


if __name__ == "__main__":
    scenario_a()

    print("-- B: does settled depth inflation still pay under slice settlement? --")
    for kappa in (0, 1, 9, 99):
        scenario_b(1000, 100, 100, F(190), kappa, "book 100/100 ext 1000 D=190")
    scenario_b(200, 100, 100, F(190), 9, "book 100/100 ext 200 D=190 (shallow)")

    print("-- C: variant 2 (quote entry kept) is still exploitable --")
    for push in (F(1, 10), F(1, 2), F(1, 1)):
        scenario_c(1000, 100, 100, F(50), push, "book 100/100 ext 1000 D=50")
    scenario_c(1000, 100, 100, F(150), F(1, 1), "book 100/100 ext 1000 D=150")

    print("-- D: executed-price literal mint vs matched price-free mint --")
    scenario_d(1000, 100, 100, F(50), F(1, 1), "literal", "book 100/100 ext 1000 D=50")
    scenario_d(1000, 100, 100, F(50), F(1, 1), "matched", "book 100/100 ext 1000 D=50")
    scenario_d(1000, 400, 25, F(50), F(1, 1), "literal", "book 400/25 ext 1000 D=50")
    scenario_d(1000, 400, 25, F(50), F(1, 1), "matched", "book 400/25 ext 1000 D=50")
    scenario_d(1000, 100, 400, F(50), F(1, 1), "literal", "book 100/400 ext 1000 D=50 (opposing-heavy)")
    scenario_d(1000, 100, 400, F(50), F(1, 1), "matched", "book 100/400 ext 1000 D=50 (opposing-heavy)")

    print("-- F: residual structural leak of matched entry + slice exit, no manipulation --")
    for D in (F(10), F(50), F(100), F(190), F(380)):
        scenario_f(1000, 100, 100, D, f"book 100/100 ext 1000 D={float(D):.0f}")
    scenario_f(200, 100, 100, F(190), "book 100/100 ext 200 D=190 (shallow)")

    scenario_d2()
    scenario_e()
