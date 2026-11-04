"""Single-tick mechanism witness for the Grok independent original.

Not a production Wings trace. Reproduces the headline closed profits.
Token0 is target. Fee is on input. Own liquidity is absent from quote sales.
"""

Q96 = 1 << 96
LOWER = Q96 // 2
UPPER = Q96 * 2
MAX_FEE = 1_000_000

def mul_div(a, b, d):
    return (a * b) // d

def mul_div_up(a, b, d):
    p = a * b
    return p // d + (0 if p % d == 0 else 1)

def div_up(a, d):
    return a // d + (0 if a % d == 0 else 1)

def amount0(sa, sb, L, up=False):
    if L == 0:
        return 0
    if sa > sb:
        sa, sb = sb, sa
    n1 = L << 96
    n2 = sb - sa
    return div_up(mul_div_up(n1, n2, sb), sa) if up else mul_div(n1, n2, sb) // sa

def amount1(sa, sb, L, up=False):
    if L == 0:
        return 0
    num = abs(sa - sb)
    p = L * num
    q = p // Q96
    return q + (1 if up and p % Q96 else 0)

def swap_exact_in(sqrt, L, gross, zero_for_one, fee):
    if gross == 0 or L == 0:
        return sqrt, 0, 0, 0
    less = mul_div(gross, MAX_FEE - fee, MAX_FEE)
    if zero_for_one:
        n1 = L << 96
        nxt = mul_div_up(n1, sqrt, n1 + less * sqrt)
        out = amount1(nxt, sqrt, L, False)
    else:
        nxt = sqrt + ((less << 96) // L)
        out = amount0(sqrt, nxt, L, False)
    if not (LOWER < nxt < UPPER):
        raise RuntimeError("tick cross")
    return nxt, less, out, gross - less

class W:
    def __init__(self, Lext, Lv, l0, S, fee=3000):
        self.fee = fee
        self.sqrt = Q96
        self.ext = {"L": Lext, "f0": 0, "f1": 0}
        self.jit = {"L": 0, "f0": 0, "f1": 0}
        self.vault = {"L": Lv, "f0": 0, "f1": 0, "l0": l0, "l1": 0}
        self.S = S
        self.a0 = self.a1 = self.d0 = self.d1 = 0
        self.dust0 = self.dust1 = 0
        self.base = self.tot()

    def positions(self):
        return (self.ext, self.jit, self.vault)

    def prin(self, L, sqrt=None):
        sqrt = self.sqrt if sqrt is None else sqrt
        return amount0(sqrt, UPPER, L), amount1(LOWER, sqrt, L)

    def tot(self):
        t0 = self.a0 + self.dust0 + self.vault["l0"]
        t1 = self.a1 + self.dust1 + self.vault["l1"]
        for p in self.positions():
            a0, a1 = self.prin(p["L"])
            t0 += a0 + p["f0"]
            t1 += a1 + p["f1"]
        return t0, t1

    def chk(self, label):
        if self.tot() != self.base:
            d0 = self.tot()[0] - self.base[0]
            d1 = self.tot()[1] - self.base[1]
            raise RuntimeError(f"{label} d0={d0} d1={d1}")

    def flash(self, t0, t1):
        self.a0 += t0
        self.a1 += t1
        self.d0 += t0
        self.d1 += t1
        self.base = (self.base[0] + t0, self.base[1] + t1)

    def accrue(self, fee, zero_for_one, ps):
        L = sum(p["L"] for p in ps)
        if fee == 0 or L == 0:
            return
        claimed = 0
        for p in ps:
            c = fee * p["L"] // L
            claimed += c
            p["f0" if zero_for_one else "f1"] += c
        if zero_for_one:
            self.dust0 += fee - claimed
        else:
            self.dust1 += fee - claimed

    def swap(self, gross, zero_for_one, include_vault):
        ps = [self.ext, self.jit] + ([self.vault] if include_vault else [])
        if not include_vault and self.vault["L"] != 0:
            raise RuntimeError("external swap would reprice vault principal")
        L = sum(p["L"] for p in ps)
        before = self.sqrt
        nxt, less, out, fee = swap_exact_in(before, L, gross, zero_for_one, self.fee)
        b0 = sum(amount0(before, UPPER, p["L"]) for p in ps)
        b1 = sum(amount1(LOWER, before, p["L"]) for p in ps)
        self.sqrt = nxt
        a0 = sum(amount0(self.sqrt, UPPER, p["L"]) for p in ps)
        a1 = sum(amount1(LOWER, self.sqrt, p["L"]) for p in ps)
        if zero_for_one:
            self.dust0 += less - (a0 - b0)
            self.dust1 += (b1 - a1) - out
        else:
            self.dust1 += less - (a1 - b1)
            self.dust0 += (b0 - a0) - out
        self.accrue(fee, zero_for_one, ps)
        return out, fee

    def add_L(self, who, Ladd):
        c0 = amount0(self.sqrt, UPPER, Ladd, True)
        c1 = amount1(LOWER, self.sqrt, Ladd, True)
        self.a0 -= c0
        self.a1 -= c1
        who["L"] += Ladd
        self.dust0 += c0 - amount0(self.sqrt, UPPER, Ladd)
        self.dust1 += c1 - amount1(LOWER, self.sqrt, Ladd)

    def remove_L_to(self, who, Lrem, dest):
        b0, b1 = self.prin(who["L"])
        g0 = amount0(self.sqrt, UPPER, Lrem)
        g1 = amount1(LOWER, self.sqrt, Lrem)
        f0 = 0 if who["L"] == 0 else who["f0"] * Lrem // who["L"]
        f1 = 0 if who["L"] == 0 else who["f1"] * Lrem // who["L"]
        who["f0"] -= f0
        who["f1"] -= f1
        who["L"] -= Lrem
        a0, a1 = self.prin(who["L"])
        self.dust0 += b0 - a0 - g0
        self.dust1 += b1 - a1 - g1
        dest[0] += g0 + f0
        dest[1] += g1 + f1

    def vector(self):
        p0, p1 = self.prin(self.vault["L"])
        v = self.vault
        return v["l0"] + p0 + v["f0"], v["l1"] + p1 + v["f1"]

    def quote(self):
        t, o = self.vector()
        L = self.ext["L"] + self.jit["L"]
        if o == 0 or L == 0:
            return t, 0
        _, _, out, _ = swap_exact_in(self.sqrt, L, o, False, self.fee)
        return t + out, out

def quote_jit(Ljit, D=20_000, fee=3000, Lext=1_000_000, Lv=200_000, l0=80_000, S=100_000):
    w = W(Lext, Lv, l0, S, fee)
    V0, _ = w.quote()
    m = S * D // V0
    w.flash(D, 0)
    w.a0 -= D
    w.vault["l0"] += D
    if Ljit:
        c0 = amount0(w.sqrt, UPPER, Ljit, True)
        c1 = amount1(LOWER, w.sqrt, Ljit, True)
        w.flash(c0, c1)
        w.add_L(w.jit, Ljit)
    V1, _ = w.quote()
    payout = m * V1 // (S + m)
    if w.vault["l0"] < payout + 1:
        raise RuntimeError("sleeve")
    w.vault["l0"] -= payout
    w.a0 += payout
    if Ljit:
        box = [0, 0]
        w.remove_L_to(w.jit, Ljit, box)
        w.a0 += box[0]
        w.a1 += box[1]
    w.chk("quote")
    return {"V0": V0, "V1": V1, "m": m, "payout": payout, "profit0": w.a0 - w.d0, "profit1": w.a1 - w.d1}

def quote_plus_swap(phi_bps, Ljit=1_000_000, D=20_000):
    w = W(1_000_000, 200_000, 80_000, 100_000, 3000)
    V0, _ = w.quote()
    m = w.S * D // V0
    w.flash(D, 0)
    w.a0 -= D
    w.vault["l0"] += D
    x = D * phi_bps // 10000
    y, _ = w.swap(x, True, True)
    w.vault["l0"] -= x
    w.vault["l1"] += y
    c0 = amount0(w.sqrt, UPPER, Ljit, True)
    c1 = amount1(LOWER, w.sqrt, Ljit, True)
    w.flash(c0, c1)
    w.add_L(w.jit, Ljit)
    V1, _ = w.quote()
    payout = m * V1 // (w.S + m)
    w.vault["l0"] -= payout
    w.a0 += payout
    box = [0, 0]
    w.remove_L_to(w.jit, Ljit, box)
    w.a0 += box[0]
    w.a1 += box[1]
    if w.vault["L"]:
        parked = [w.vault["l0"], w.vault["l1"]]
        w.remove_L_to(w.vault, w.vault["L"], parked)
        w.vault["l0"], w.vault["l1"] = parked
    if w.a1 < w.d1:
        need = w.d1 - w.a1
        L = w.ext["L"]
        lo, hi, best = 0, w.a0, None
        while lo <= hi:
            mid = (lo + hi) // 2
            _, _, out, _ = swap_exact_in(w.sqrt, L, mid, True, w.fee)
            if out >= need:
                best = mid
                hi = mid - 1
            else:
                lo = mid + 1
        out, _ = w.swap(best, True, False)
        w.a0 -= best
        w.a1 += out
    w.chk("design2")
    return {"profit0": w.a0 - w.d0, "profit1": w.a1 - w.d1, "m": m, "V1": V1, "payout": payout}

def out_of_range(push, D=20_000, S=100_000, AT=100_000, AO=100_000, Lext=1_000_000, fee=3000, phi_bps=None):
    w = W(Lext, 0, AT, S, fee)
    w.vault["l1"] = AO
    w.base = w.tot()
    w.flash(D, push)
    if push:
        out, _ = w.swap(push, False, False)
        w.a1 -= push
        w.a0 += out
    if phi_bps is None:
        V = AT + (Q96 * Q96 * AO) // (w.sqrt * w.sqrt)
        w.a0 -= D
        w.vault["l0"] += D
    else:
        x = D * phi_bps // 10000
        y, _ = w.swap(x, True, False)
        w.a0 -= D
        w.vault["l0"] += D - x
        w.vault["l1"] += y
        V = AT + (x * AO) // y
    m = S * D // V
    if push and w.sqrt > Q96 and w.a0:
        L = w.ext["L"]
        lo, hi, best = 0, w.a0, 0
        while lo <= hi:
            mid = (lo + hi) // 2
            try:
                nxt, _, _, _ = swap_exact_in(w.sqrt, L, mid, True, w.fee)
            except RuntimeError:
                hi = mid - 1
                continue
            if nxt >= Q96:
                best = mid
                lo = mid + 1
            else:
                hi = mid - 1
        if best:
            back, _ = w.swap(best, True, False)
            w.a0 -= best
            w.a1 += back
    supply = S + m
    took_t = w.vault["l0"] * m // supply
    took_o = w.vault["l1"] * m // supply
    w.vault["l0"] -= took_t
    w.vault["l1"] -= took_o
    w.a0 += took_t
    w.a1 += took_o
    w.chk("oor")
    if w.a1 > w.d1:
        extra = w.a1 - w.d1
        out, _ = w.swap(extra, False, False)
        w.a1 -= extra
        w.a0 += out
    elif w.a1 < w.d1:
        need = w.d1 - w.a1
        L = w.ext["L"]
        lo, hi, best = 0, w.a0, None
        while lo <= hi:
            mid = (lo + hi) // 2
            try:
                _, _, out, _ = swap_exact_in(w.sqrt, L, mid, True, w.fee)
            except RuntimeError:
                hi = mid - 1
                continue
            if out >= need:
                best = mid
                hi = mid - 1
            else:
                lo = mid + 1
        out, _ = w.swap(best, True, False)
        w.a0 -= best
        w.a1 += out
    w.chk("oor-liq")
    return {"m": m, "V": V, "profit0": w.a0 - w.d0, "profit1": w.a1 - w.d1,
            "vault_t": w.vault["l0"], "vault_o": w.vault["l1"]}

def vector_oor(push, D=20_000, S=100_000, AT=100_000, AO=100_000, Lext=1_000_000, fee=3000):
    w = W(Lext, 0, AT, S, fee)
    w.vault["l1"] = AO
    w.base = w.tot()
    w.flash(D, push)
    if push:
        out, _ = w.swap(push, False, False)
        w.a1 -= push
        w.a0 += out
    best = None
    for bps in range(0, 10001, 50):
        x = D * bps // 10000
        if x == 0:
            continue
        try:
            _, _, y, _ = swap_exact_in(w.sqrt, w.ext["L"], x, True, w.fee)
        except RuntimeError:
            continue
        scale = min((D - x) * 10**18 // AT, y * 10**18 // AO)
        unmatched = (D - x - AT * scale // 10**18) + (y - AO * scale // 10**18)
        if best is None or unmatched < best[0]:
            best = (unmatched, x, bps)
    x = best[1]
    y, _ = w.swap(x, True, False)
    w.a0 -= D
    w.vault["l0"] += D - x
    w.vault["l1"] += y
    scale = min((D - x) * 10**18 // AT, y * 10**18 // AO)
    matched_t = AT * scale // 10**18
    matched_o = AO * scale // 10**18
    w.vault["l0"] -= (D - x - matched_t)
    w.vault["l1"] -= (y - matched_o)
    w.a0 += D - x - matched_t
    w.a1 += y - matched_o
    m = S * matched_t // AT
    supply = S + m
    took_t = w.vault["l0"] * m // supply
    took_o = w.vault["l1"] * m // supply
    w.vault["l0"] -= took_t
    w.vault["l1"] -= took_o
    w.a0 += took_t
    w.a1 += took_o
    w.chk("vector")
    if w.a1 > w.d1:
        extra = w.a1 - w.d1
        out, _ = w.swap(extra, False, False)
        w.a1 -= extra
        w.a0 += out
    elif w.a1 < w.d1:
        need = w.d1 - w.a1
        L = w.ext["L"]
        lo, hi, best_in = 0, w.a0, None
        while lo <= hi:
            mid = (lo + hi) // 2
            try:
                _, _, out, _ = swap_exact_in(w.sqrt, L, mid, True, w.fee)
            except RuntimeError:
                hi = mid - 1
                continue
            if out >= need:
                best_in = mid
                hi = mid - 1
            else:
                lo = mid + 1
        out, _ = w.swap(best_in, True, False)
        w.a0 -= best_in
        w.a1 += out
    w.chk("vector-liq")
    return {"m": m, "profit0": w.a0 - w.d0, "profit1": w.a1 - w.d1}

def main():
    expect = {
        "control": quote_jit(0)["profit0"],
        "jit1e6": quote_jit(1_000_000)["profit0"],
        "jit5e6": quote_jit(5_000_000)["profit0"],
        "design2_50": quote_plus_swap(5000)["profit0"],
        "spot20k": out_of_range(20_000)["profit0"],
        "spot100k": out_of_range(100_000)["profit0"],
        "pexec_skew": out_of_range(20_000, phi_bps=5000, Lext=100_000, AT=50_000, AO=400_000, D=20_000, S=50_000)["profit0"],
        "vector20k": vector_oor(20_000)["profit0"],
    }
    want = {
        "control": -1,
        "jit1e6": 295,
        "jit5e6": 508,
        "design2_50": 343,
        "spot20k": 125,
        "spot100k": 1014,
        "pexec_skew": 1087,
        "vector20k": -121,
    }
    for k, v in want.items():
        if expect[k] != v:
            raise SystemExit(f"{k}: got {expect[k]} want {v}")
    print(expect)

if __name__ == "__main__":
    main()
