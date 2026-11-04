from __future__ import annotations
import json
from copy import deepcopy
Q96 = 1 << 96
MAX_FEE = 1000000
WAD = 10 ** 18
SQRT_LO = Q96 // 2
SQRT_HI = Q96 * 2
SQRT_MID = Q96
FEE = 3000
L_EXT = 10 ** 18
VAULT_T = 5 * 10 ** 17
VAULT_O = 10 ** 17
SUPPLY = 5 * 10 ** 17
DEPOSIT = 10 ** 17
L_JIT = 10 * L_EXT
BUFFER = 10 ** 6
FEE_FLOAT = 10 ** 16
ENDOW = 1000

def muldiv(a: int, b: int, d: int) -> int:
    return a * b // d

def muldiv_up(a: int, b: int, d: int) -> int:
    return (a * b + d - 1) // d

def div_up(a: int, d: int) -> int:
    return (a + d - 1) // d

def get_amount0_delta(sqrt_a: int, sqrt_b: int, liquidity: int, round_up: bool) -> int:
    if sqrt_a > sqrt_b:
        sqrt_a, sqrt_b = (sqrt_b, sqrt_a)
    if sqrt_a == 0:
        raise ValueError('InvalidPrice')
    numerator1 = liquidity << 96
    numerator2 = sqrt_b - sqrt_a
    if round_up:
        return div_up(muldiv_up(numerator1, numerator2, sqrt_b), sqrt_a)
    return muldiv(numerator1, numerator2, sqrt_b) // sqrt_a

def get_amount1_delta(sqrt_a: int, sqrt_b: int, liquidity: int, round_up: bool) -> int:
    numerator = abs(sqrt_a - sqrt_b)
    amount = muldiv(liquidity, numerator, Q96)
    if round_up and liquidity * numerator % Q96:
        amount += 1
    return amount

def get_next_sqrt_price_from_amount0_rounding_up(sqrt_p: int, liquidity: int, amount: int, add: bool) -> int:
    if amount == 0:
        return sqrt_p
    numerator1 = liquidity << 96
    if add:
        product = amount * sqrt_p
        if product // amount == sqrt_p:
            denominator = numerator1 + product
            if denominator >= numerator1:
                return muldiv_up(numerator1, sqrt_p, denominator)
        return div_up(numerator1, numerator1 // sqrt_p + amount)
    product = amount * sqrt_p
    if product // amount != sqrt_p or numerator1 <= product:
        raise OverflowError('PriceOverflow')
    return muldiv_up(numerator1, sqrt_p, numerator1 - product)

def get_next_sqrt_price_from_amount1_rounding_down(sqrt_p: int, liquidity: int, amount: int, add: bool) -> int:
    if add:
        quotient = (amount << 96) // liquidity if amount <= (1 << 160) - 1 else muldiv(amount, Q96, liquidity)
        return sqrt_p + quotient
    quotient = div_up(amount << 96, liquidity) if amount <= (1 << 160) - 1 else muldiv_up(amount, Q96, liquidity)
    if sqrt_p <= quotient:
        raise OverflowError('NotEnoughLiquidity')
    return sqrt_p - quotient

def get_next_sqrt_price_from_input(sqrt_p: int, liquidity: int, amount_in: int, zero_for_one: bool) -> int:
    if sqrt_p == 0 or liquidity == 0:
        raise ValueError('InvalidPriceOrLiquidity')
    if zero_for_one:
        return get_next_sqrt_price_from_amount0_rounding_up(sqrt_p, liquidity, amount_in, True)
    return get_next_sqrt_price_from_amount1_rounding_down(sqrt_p, liquidity, amount_in, True)

def get_next_sqrt_price_from_output(sqrt_p: int, liquidity: int, amount_out: int, zero_for_one: bool) -> int:
    if sqrt_p == 0 or liquidity == 0:
        raise ValueError('InvalidPriceOrLiquidity')
    if zero_for_one:
        return get_next_sqrt_price_from_amount1_rounding_down(sqrt_p, liquidity, amount_out, False)
    return get_next_sqrt_price_from_amount0_rounding_up(sqrt_p, liquidity, amount_out, False)

def compute_swap_step(sqrt_current: int, sqrt_target: int, liquidity: int, amount_remaining: int, fee_pips: int):
    fee_pips = int(fee_pips)
    zero_for_one = sqrt_current >= sqrt_target
    exact_in = amount_remaining < 0
    if liquidity == 0 or amount_remaining == 0 or sqrt_current == sqrt_target:
        return (sqrt_current, 0, 0, 0)
    if exact_in:
        remaining = -amount_remaining
        less_fee = muldiv(remaining, MAX_FEE - fee_pips, MAX_FEE)
        amount_in = get_amount0_delta(sqrt_target, sqrt_current, liquidity, True) if zero_for_one else get_amount1_delta(sqrt_current, sqrt_target, liquidity, True)
        if less_fee >= amount_in:
            sqrt_next = sqrt_target
            fee_amount = amount_in if fee_pips == MAX_FEE else muldiv_up(amount_in, fee_pips, MAX_FEE - fee_pips)
        else:
            amount_in = less_fee
            sqrt_next = get_next_sqrt_price_from_input(sqrt_current, liquidity, less_fee, zero_for_one)
            fee_amount = remaining - amount_in
        amount_out = get_amount1_delta(sqrt_next, sqrt_current, liquidity, False) if zero_for_one else get_amount0_delta(sqrt_current, sqrt_next, liquidity, False)
        return (sqrt_next, amount_in, amount_out, fee_amount)
    amount_out = get_amount1_delta(sqrt_target, sqrt_current, liquidity, False) if zero_for_one else get_amount0_delta(sqrt_current, sqrt_target, liquidity, False)
    if amount_remaining >= amount_out:
        sqrt_next = sqrt_target
    else:
        amount_out = amount_remaining
        sqrt_next = get_next_sqrt_price_from_output(sqrt_current, liquidity, amount_out, zero_for_one)
    amount_in = get_amount0_delta(sqrt_next, sqrt_current, liquidity, True) if zero_for_one else get_amount1_delta(sqrt_next, sqrt_current, liquidity, True)
    fee_amount = muldiv_up(amount_in, fee_pips, MAX_FEE - fee_pips)
    return (sqrt_next, amount_in, amount_out, fee_amount)

def principal_amounts(sqrt_p: int, lower: int, upper: int, liquidity: int, round_up: bool):
    if liquidity == 0:
        return (0, 0)
    if sqrt_p <= lower:
        return (get_amount0_delta(lower, upper, liquidity, round_up), 0)
    if sqrt_p >= upper:
        return (0, get_amount1_delta(lower, upper, liquidity, round_up))
    return (get_amount0_delta(sqrt_p, upper, liquidity, round_up), get_amount1_delta(lower, sqrt_p, liquidity, round_up))

def mark_token1_in_token0(sqrt_p: int, amount1: int) -> int:
    if amount1 == 0:
        return 0
    return muldiv(1 << 192, amount1, sqrt_p * sqrt_p)

def issue(supply: int, value: int, credit: int) -> int:
    if credit == 0:
        raise ValueError('ZeroIssue')
    if supply != 0 and value == 0:
        raise ValueError('InvalidAccountingState')
    shares = credit if supply == 0 else muldiv(supply, credit, value)
    if shares == 0:
        raise ValueError('ZeroIssue')
    return shares

def entitlement(supply: int, value: int, shares: int) -> int:
    if supply == 0 or shares > supply:
        raise ValueError('InvalidAccountingState')
    return muldiv(shares, value, supply)

class Position:

    def __init__(self, lower: int, upper: int, liquidity: int, owner: str):
        self.lower = lower
        self.upper = upper
        self.liquidity = liquidity
        self.owner = owner
        self.fee0 = 0
        self.fee1 = 0

    def active(self, sqrt_p: int) -> bool:
        return self.liquidity > 0 and self.lower <= sqrt_p < self.upper

class World:

    def __init__(self, l_ext: int, vault0: int, vault1: int, fee: int, supply: int, vault_lp: int=0):
        self.sqrt = SQRT_MID
        self.lower = SQRT_LO
        self.upper = SQRT_HI
        self.fee = fee
        self.vault0 = vault0
        self.vault1 = vault1
        self.supply = supply
        self.attacker0 = 0
        self.attacker1 = 0
        self.attacker_shares = 0
        self.debt0 = 0
        self.debt1 = 0
        self.lender0 = 10 ** 40
        self.lender1 = 10 ** 40
        self.house0 = 10 ** 12
        self.house1 = 10 ** 12
        self.positions: list[Position] = []
        self.pool0 = 0
        self.pool1 = 0
        self.log: list[dict] = []
        if l_ext:
            self._seed_position('ext', l_ext)
        if vault_lp:
            self._seed_position('vault', vault_lp)
        self.t0, self.t1 = self.totals()
        self.initial_vault0 = vault0
        self.initial_vault1 = vault1
        self.initial_lender0 = self.lender0
        self.initial_lender1 = self.lender1
        self.check('init')

    def _seed_position(self, owner: str, liquidity: int) -> None:
        pos = Position(self.lower, self.upper, liquidity, owner)
        a0, a1 = principal_amounts(self.sqrt, self.lower, self.upper, liquidity, False)
        self.positions.append(pos)
        self.pool0 += a0
        self.pool1 += a1

    def totals(self):
        return (self.attacker0 + self.vault0 + self.pool0 + self.lender0 + self.house0, self.attacker1 + self.vault1 + self.pool1 + self.lender1 + self.house1)

    def endow(self, amount0: int, amount1: int) -> None:
        self.house0 -= amount0
        self.house1 -= amount1
        self.attacker0 += amount0
        self.attacker1 += amount1
        self.check('endow')

    def claims(self):
        c0 = c1 = 0
        for pos in self.positions:
            if pos.liquidity == 0 and pos.fee0 == 0 and (pos.fee1 == 0):
                continue
            a0, a1 = principal_amounts(self.sqrt, pos.lower, pos.upper, pos.liquidity, False)
            c0 += a0 + pos.fee0
            c1 += a1 + pos.fee1
        return (c0, c1)

    def check(self, step: str) -> None:
        t0, t1 = self.totals()
        if t0 != self.t0 or t1 != self.t1:
            raise AssertionError(f'conservation broken at {step}: d0={t0 - self.t0} d1={t1 - self.t1}')
        c0, c1 = self.claims()
        if c0 > self.pool0 or c1 > self.pool1:
            raise AssertionError(f'claims exceed pool at {step}: pool-claims=({self.pool0 - c0}, {self.pool1 - c1})')

    def snap(self, step: str, **extra) -> dict:
        quote, sold, unsold = self.liquidation()
        row = {'step': step, 'attacker0': self.attacker0, 'attacker1': self.attacker1, 'debt0': self.debt0, 'debt1': self.debt1, 'shares': self.attacker_shares, 'supply': self.supply, 'vault0': self.vault0, 'vault1': self.vault1, 'sqrt': self.sqrt, 'quote': quote, 'sold': sold, 'unsold': unsold, 'jit_L': self.liquidity_of('jit'), 'vault_L': self.liquidity_of('vault'), 'ext_L': self.liquidity_of('ext')}
        row.update(extra)
        self.log.append(row)
        return row

    def liquidity_of(self, owner: str) -> int:
        return sum((p.liquidity for p in self.positions if p.owner == owner))

    def borrow(self, amount0: int, amount1: int) -> None:
        if amount0 < 0 or amount1 < 0:
            raise ValueError('negative borrow')
        self.lender0 -= amount0
        self.lender1 -= amount1
        self.attacker0 += amount0
        self.attacker1 += amount1
        self.debt0 += amount0
        self.debt1 += amount1
        self.check('borrow')

    def repay_all(self) -> None:
        pay0 = min(self.attacker0, self.debt0)
        pay1 = min(self.attacker1, self.debt1)
        self.attacker0 -= pay0
        self.attacker1 -= pay1
        self.lender0 += pay0
        self.lender1 += pay1
        self.debt0 -= pay0
        self.debt1 -= pay1
        self.check('repay')

    def _debit(self, who: str, token: int, amount: int) -> None:
        if amount == 0:
            return
        if who == 'attacker':
            if token == 0:
                if self.attacker0 < amount:
                    raise AssertionError('attacker token0 short')
                self.attacker0 -= amount
            else:
                if self.attacker1 < amount:
                    raise AssertionError('attacker token1 short')
                self.attacker1 -= amount
        elif who == 'vault':
            if token == 0:
                if self.vault0 < amount:
                    raise AssertionError('vault token0 short')
                self.vault0 -= amount
            else:
                if self.vault1 < amount:
                    raise AssertionError('vault token1 short')
                self.vault1 -= amount
        else:
            raise ValueError(who)

    def _credit(self, who: str, token: int, amount: int) -> None:
        if amount == 0:
            return
        if who == 'attacker':
            if token == 0:
                self.attacker0 += amount
            else:
                self.attacker1 += amount
        elif who == 'vault':
            if token == 0:
                self.vault0 += amount
            else:
                self.vault1 += amount
        else:
            raise ValueError(who)

    def active_L(self, owner: str | None=None, exclude: str | None=None) -> int:
        total = 0
        for pos in self.positions:
            if not pos.active(self.sqrt):
                continue
            if owner is not None and pos.owner != owner:
                continue
            if exclude is not None and pos.owner == exclude:
                continue
            total += pos.liquidity
        return total

    def accrue(self, fee_amount: int, token0: bool, at_sqrt: int) -> int:
        active = [p for p in self.positions if p.active(at_sqrt)]
        total = sum((p.liquidity for p in active))
        if fee_amount == 0 or total == 0:
            return fee_amount
        credited = 0
        for pos in active:
            share = fee_amount * pos.liquidity // total
            if token0:
                pos.fee0 += share
            else:
                pos.fee1 += share
            credited += share
        return fee_amount - credited

    def swap_exact_in(self, zero_for_one: bool, amount_in: int, trader: str) -> tuple[int, int, int]:
        if amount_in == 0:
            return (0, 0, 0)
        liquidity = self.active_L()
        limit = self.lower if zero_for_one else self.upper
        sqrt_next, amount_in_used, amount_out, fee_amount = compute_swap_step(self.sqrt, limit, liquidity, -amount_in, self.fee)
        spent = amount_in_used + fee_amount
        if spent > amount_in:
            raise AssertionError(f'spent {spent} > input {amount_in}')
        start = self.sqrt
        if zero_for_one:
            self._debit(trader, 0, spent)
            self.pool0 += spent
            if self.pool1 < amount_out:
                raise AssertionError('pool token1 short')
            self.pool1 -= amount_out
            self._credit(trader, 1, amount_out)
        else:
            self._debit(trader, 1, spent)
            self.pool1 += spent
            if self.pool0 < amount_out:
                raise AssertionError('pool token0 short')
            self.pool0 -= amount_out
            self._credit(trader, 0, amount_out)
        self.accrue(fee_amount, token0=zero_for_one, at_sqrt=start)
        self.sqrt = sqrt_next
        self.check('swap')
        return (amount_in_used, amount_out, fee_amount)

    def swap_exact_out(self, zero_for_one: bool, amount_out_wanted: int, trader: str) -> tuple[int, int, int]:
        if amount_out_wanted == 0:
            return (0, 0, 0)
        liquidity = self.active_L()
        limit = self.lower if zero_for_one else self.upper
        sqrt_next, amount_in, amount_out, fee_amount = compute_swap_step(self.sqrt, limit, liquidity, amount_out_wanted, self.fee)
        spent = amount_in + fee_amount
        start = self.sqrt
        if zero_for_one:
            self._debit(trader, 0, spent)
            self.pool0 += spent
            self.pool1 -= amount_out
            self._credit(trader, 1, amount_out)
        else:
            self._debit(trader, 1, spent)
            self.pool1 += spent
            self.pool0 -= amount_out
            self._credit(trader, 0, amount_out)
        self.accrue(fee_amount, token0=zero_for_one, at_sqrt=start)
        self.sqrt = sqrt_next
        self.check('swap-out')
        return (amount_in, amount_out, fee_amount)

    def add_liquidity(self, owner: str, liquidity: int, payer: str) -> tuple[Position, int, int]:
        pos = Position(self.lower, self.upper, liquidity, owner)
        a0, a1 = principal_amounts(self.sqrt, self.lower, self.upper, liquidity, True)
        self._debit(payer, 0, a0)
        self._debit(payer, 1, a1)
        self.pool0 += a0
        self.pool1 += a1
        self.positions.append(pos)
        self.check(f'add-{owner}')
        return (pos, a0, a1)

    def remove_liquidity(self, pos: Position, liquidity: int, receiver: str) -> tuple[int, int, int, int]:
        if liquidity <= 0 or liquidity > pos.liquidity:
            raise ValueError('bad liquidity removal')
        a0, a1 = principal_amounts(self.sqrt, pos.lower, pos.upper, liquidity, False)
        fee0 = pos.fee0 * liquidity // pos.liquidity
        fee1 = pos.fee1 * liquidity // pos.liquidity
        pay0 = a0 + fee0
        pay1 = a1 + fee1
        if self.pool0 < pay0 or self.pool1 < pay1:
            raise AssertionError('pool cannot pay removal')
        self.pool0 -= pay0
        self.pool1 -= pay1
        self._credit(receiver, 0, pay0)
        self._credit(receiver, 1, pay1)
        pos.liquidity -= liquidity
        pos.fee0 -= fee0
        pos.fee1 -= fee1
        self.check('remove')
        return (a0, a1, fee0, fee1)

    def vault_inventory(self) -> tuple[int, int]:
        amount0 = self.vault0
        amount1 = self.vault1
        for pos in self.positions:
            if pos.owner != 'vault' or (pos.liquidity == 0 and pos.fee0 == 0 and (pos.fee1 == 0)):
                continue
            a0, a1 = principal_amounts(self.sqrt, pos.lower, pos.upper, pos.liquidity, False)
            amount0 += a0 + pos.fee0
            amount1 += a1 + pos.fee1
        return (amount0, amount1)

    def liquidation(self) -> tuple[int, int, int]:
        collected0, collected1 = self.vault_inventory()
        ext = self.active_L(exclude='vault')
        value = collected0
        unsold = collected1
        if unsold == 0 or ext == 0 or self.sqrt >= self.upper:
            return (value, 0, unsold)
        _sqrt_next, amount_in, amount_out, fee_amount = compute_swap_step(self.sqrt, self.upper, ext, -unsold, self.fee)
        spent = amount_in + fee_amount
        return (value + amount_out, spent, unsold - spent)

    def deposit_quote(self, credit: int) -> tuple[int, int]:
        value, _sold, _unsold = self.liquidation()
        shares = issue(self.supply, value, credit)
        self._debit('attacker', 0, credit)
        self.vault0 += credit
        self.supply += shares
        self.attacker_shares += shares
        self.check('deposit')
        return (shares, value)

    def redeem_quote(self, shares: int) -> tuple[int, int]:
        value, _sold, _unsold = self.liquidation()
        assets = entitlement(self.supply, value, shares)
        if self.vault0 < assets:
            raise AssertionError(f'sleeve short {assets} > {self.vault0}')
        self.vault0 -= assets
        self._credit('attacker', 0, assets)
        self.supply -= shares
        self.attacker_shares -= shares
        self.check('redeem')
        return (assets, value)

    def close_token1_to_debt(self) -> dict:
        target = self.debt1
        if self.attacker1 > target:
            excess = self.attacker1 - target
            _ain, out, fee = self.swap_exact_in(False, excess, 'attacker')
            return {'action': 'sold_excess_token1', 'excess': excess, 'token0_out': out, 'fee': fee, 'attacker1': self.attacker1, 'target': target}
        if self.attacker1 < target:
            short = target - self.attacker1
            ain, out, fee = self.swap_exact_out(True, short, 'attacker')
            return {'action': 'bought_short_token1', 'short': short, 'got': out, 'token0_in': ain + fee, 'fee': fee, 'attacker1': self.attacker1, 'target': target}
        return {'action': 'already_closed', 'attacker1': self.attacker1, 'target': target}

    def finish(self, label: str, start_attacker0: int, start_attacker1: int) -> dict:
        self.repay_all()
        closed = self.debt0 == 0 and self.debt1 == 0 and (self.attacker_shares == 0) and (self.liquidity_of('jit') == 0) and (self.attacker1 == start_attacker1)
        profit = self.attacker0 - start_attacker0
        incumbent_target_delta = self.vault0 - self.initial_vault0
        dust0 = self.pool0 - self.claims()[0]
        dust1 = self.pool1 - self.claims()[1]
        result = {'label': label, 'closed': closed, 'attacker_target_delta': profit, 'attacker1': self.attacker1, 'attacker1_delta': self.attacker1 - start_attacker1, 'shares': self.attacker_shares, 'jit_L': self.liquidity_of('jit'), 'debt0': self.debt0, 'debt1': self.debt1, 'vault0': self.vault0, 'vault1': self.vault1, 'incumbent_idle_target_delta': incumbent_target_delta, 'vault_inventory': self.vault_inventory(), 'lender_delta': (self.lender0 - self.initial_lender0, self.lender1 - self.initial_lender1), 'pool_dust': (dust0, dust1), 'sqrt': self.sqrt, 'classification': classify(closed, profit, self.attacker1 - start_attacker1), 'log': self.log}
        return result

def classify(closed: bool, target_delta: int, token1_delta: int) -> str:
    if closed and target_delta > 0:
        return 'closed_target_profit'
    if closed and target_delta == 0:
        return 'closed_flat'
    if closed and target_delta < 0:
        return 'closed_target_loss'
    return f'not_closed token1_delta={token1_delta} target_delta={target_delta}'

def fresh(l_ext: int=L_EXT, vault0: int=VAULT_T, vault1: int=VAULT_O, fee: int=FEE, supply: int=SUPPLY, vault_lp: int=0) -> World:
    world = World(l_ext, vault0, vault1, fee, supply, vault_lp)
    world.endow(ENDOW, 0)
    return world

def borrow_deposit_and_buffer(world: World, deposit: int, token1_needed: int) -> None:
    world.borrow(deposit + BUFFER, token1_needed + BUFFER)

def rule1_jit(l_ext: int, l_jit: int, fee: int, label: str, deposit: int=DEPOSIT) -> dict:
    world = fresh(l_ext=l_ext, fee=fee)
    start0 = world.attacker0
    start1 = world.attacker1
    jit0 = jit1 = 0
    if l_jit:
        jit0, jit1 = principal_amounts(world.sqrt, world.lower, world.upper, l_jit, True)
    world.borrow(deposit + jit0 + BUFFER, jit1 + BUFFER)
    world.snap('after_borrow')
    shares, v0 = world.deposit_quote(deposit)
    world.snap('after_deposit', V0=v0, minted=shares)
    if l_jit:
        _pos, c0, c1 = world.add_liquidity('jit', l_jit, 'attacker')
        world.snap('after_jit', jit_cost=(c0, c1))
    assets, v1 = world.redeem_quote(shares)
    world.snap('after_redeem', V1=v1, paid=assets)
    if l_jit:
        for pos in list(world.positions):
            if pos.owner == 'jit' and pos.liquidity:
                world.remove_liquidity(pos, pos.liquidity, 'attacker')
        world.snap('after_jit_remove')
    world.close_token1_to_debt()
    world.snap('after_close')
    result = world.finish(label, start0, start1)
    result['V0'] = v0
    result['V1'] = v1
    result['minted'] = shares
    result['paid'] = assets
    result['formula_profit'] = deposit * (v1 - (v0 + deposit)) // (v0 + deposit)
    result['fee'] = fee
    result['l_ext'] = l_ext
    result['l_jit'] = l_jit
    return result

def rule2_swap_then_jit(fraction_num: int, fraction_den: int, l_jit: int, label: str) -> dict:
    world = fresh()
    start0 = world.attacker0
    start1 = world.attacker1
    deposit = DEPOSIT
    q = muldiv(deposit, fraction_num, fraction_den)
    jit0, jit1 = principal_amounts(world.sqrt, world.lower, world.upper, l_jit, True)
    world.borrow(deposit + q + jit0 * 2 + FEE_FLOAT, jit1 * 2 + BUFFER)
    ain, aout, fee = world.swap_exact_in(True, q, 'attacker')
    world.snap('after_mandated_swap', q=q, token1_out=aout, fee=fee)
    shares, v0 = world.deposit_quote(deposit)
    world.snap('after_deposit', V0=v0, minted=shares)
    _pos, c0, c1 = world.add_liquidity('jit', l_jit, 'attacker')
    world.snap('after_jit', jit_cost=(c0, c1))
    assets, v1 = world.redeem_quote(shares)
    world.snap('after_redeem', V1=v1, paid=assets)
    for pos in list(world.positions):
        if pos.owner == 'jit' and pos.liquidity:
            world.remove_liquidity(pos, pos.liquidity, 'attacker')
    close = world.close_token1_to_debt()
    world.snap('after_close', close=close)
    result = world.finish(label, start0, start1)
    result.update({'q': q, 'V0': v0, 'V1': v1, 'minted': shares, 'paid': assets, 'mandated_token1_out': aout, 'close': close})
    return result

def p_exec_wad(token0_in: int, token1_out: int) -> int:
    if token1_out == 0:
        raise ValueError('p_exec undefined')
    return muldiv(token0_in, WAD, token1_out)

def mark_book(amount_t: int, amount_o: int, p_wad: int) -> int:
    return amount_t + muldiv(p_wad, amount_o, WAD)

def rule3_mark_sandwich(push_token1: int, q: int, label: str, inventory_cutoff: bool) -> dict:
    world = fresh()
    start0 = world.attacker0
    start1 = world.attacker1
    world.borrow(DEPOSIT + q + FEE_FLOAT, push_token1 + BUFFER)
    if push_token1:
        world.swap_exact_in(False, push_token1, 'attacker')
        world.snap('after_push', sqrt=world.sqrt)
    pre_t, pre_o = world.vault_inventory()
    ain, aout, fee = world.swap_exact_in(True, q, 'attacker')
    post_t, post_o = world.vault_inventory()
    p_wad = p_exec_wad(ain + fee, aout)
    traded = min(post_o, aout) if inventory_cutoff else post_o
    value_pre = mark_book(pre_t, min(pre_o, aout) if inventory_cutoff else pre_o, p_wad)
    value_post = mark_book(post_t, traded, p_wad)
    shares = issue(world.supply, value_post, DEPOSIT)
    world._debit('attacker', 0, DEPOSIT)
    world.vault0 += DEPOSIT
    world.supply += shares
    world.attacker_shares += shares
    world.check('mark-mint')
    world.snap('after_mint', p_wad=p_wad, value_post=value_post, value_pre=value_pre, minted=shares)
    close_push = world.close_token1_to_debt()
    world.snap('after_restore', close=close_push)
    if world.attacker0 < q:
        world.borrow(q, 0)
    ain2, aout2, fee2 = world.swap_exact_in(True, q, 'attacker')
    p2 = p_exec_wad(ain2 + fee2, aout2)
    book_t, book_o = world.vault_inventory()
    traded2 = min(book_o, aout2) if inventory_cutoff else book_o
    value_exit = mark_book(book_t, traded2, p2)
    assets = entitlement(world.supply, value_exit, shares)
    if world.vault0 < assets:
        result = {'label': label, 'closed': False, 'classification': 'sleeve_short_not_profit', 'assets': assets, 'vault0': world.vault0, 'p_entry': p_wad, 'p_exit': p2, 'value_entry': value_post, 'value_exit': value_exit}
        return result
    world.vault0 -= assets
    world._credit('attacker', 0, assets)
    world.supply -= shares
    world.attacker_shares -= shares
    world.check('mark-redeem')
    close = world.close_token1_to_debt()
    world.snap('after_exit_close', close=close, paid=assets, value_exit=value_exit)
    result = world.finish(label, start0, start1)
    result.update({'p_entry': p_wad, 'p_exit': p2, 'value_entry': value_post, 'value_exit': value_exit, 'minted': shares, 'paid': assets, 'inventory_cutoff': inventory_cutoff, 'A_T_post': post_t, 'A_O_post': post_o, 'traded_marked': traded})
    return result

def rule3_cutoff_then_slice(q: int, label: str) -> dict:
    world = fresh()
    start0 = world.attacker0
    start1 = world.attacker1
    world.borrow(DEPOSIT + q + FEE_FLOAT, BUFFER)
    ain, aout, fee = world.swap_exact_in(True, q, 'attacker')
    book_t, book_o = world.vault_inventory()
    value = book_t
    shares = issue(world.supply, value, DEPOSIT)
    world._debit('attacker', 0, DEPOSIT)
    world.vault0 += DEPOSIT
    world.supply += shares
    world.attacker_shares += shares
    world.check('cutoff-mint')
    world.snap('after_mint', value=value, minted=shares, mandated_out=aout, fee=fee)
    slice_exit(world, shares)
    world.snap('after_slice')
    close = world.close_token1_to_debt()
    world.snap('after_close', close=close)
    result = world.finish(label, start0, start1)
    result.update({'value_entry': value, 'minted': shares, 'A_T': book_t, 'A_O': book_o, 'q': q})
    return result

def slice_exit(world: World, shares: int) -> tuple[int, int]:
    if shares <= 0 or shares > world.supply:
        raise ValueError('bad slice')
    before1 = world.attacker1
    t_out = muldiv(world.vault0, shares, world.supply)
    o_out = muldiv(world.vault1, shares, world.supply)
    world.vault0 -= t_out
    world.vault1 -= o_out
    world._credit('attacker', 0, t_out)
    world._credit('attacker', 1, o_out)
    for pos in list(world.positions):
        if pos.owner == 'vault' and pos.liquidity:
            l_out = muldiv(pos.liquidity, shares, world.supply)
            if l_out:
                world.remove_liquidity(pos, l_out, 'attacker')
    world.supply -= shares
    world.attacker_shares -= shares
    world.check('slice-remove')
    gained1 = world.attacker1 - before1
    if gained1:
        world.swap_exact_in(False, gained1, 'attacker')
    return (t_out, o_out)

def rule4_single_sided() -> dict:
    world = fresh()
    components = claim_components(world)
    d = {'idle0': DEPOSIT, 'idle1': 0}
    minted = proportional_shares(world.supply, components, d)
    return {'label': 'rule4_single_sided', 'components': components, 'minted': minted, 'classification': 'mint_zero' if minted == 0 else 'unexpected_mint'}

def claim_components(world: World) -> dict:
    comps = {'idle0': world.vault0, 'idle1': world.vault1}
    i = 0
    for pos in world.positions:
        if pos.owner == 'vault' and pos.liquidity:
            comps[f'L{i}'] = pos.liquidity
            i += 1
    return comps

def proportional_shares(supply: int, components: dict, supplied: dict) -> int:
    ratios = []
    for name, size in components.items():
        if size == 0:
            continue
        got = supplied.get(name, 0)
        if got == 0:
            return 0
        ratios.append(muldiv(supply, got, size))
    if not ratios:
        return 0
    return min(ratios)

def rule4_round_trip() -> dict:
    world = fresh()
    start0 = world.attacker0
    start1 = world.attacker1
    f_num, f_den = (1, 5)
    need0 = muldiv_up(world.vault0, f_num, f_den)
    need1 = muldiv_up(world.vault1, f_num, f_den)
    world.borrow(need0 + BUFFER, need1 + BUFFER)
    components = claim_components(world)
    supplied = {'idle0': need0, 'idle1': need1}
    shares = proportional_shares(world.supply, components, supplied)
    use0 = muldiv(world.vault0, shares, world.supply)
    use1 = muldiv(world.vault1, shares, world.supply)
    world._debit('attacker', 0, use0)
    world._debit('attacker', 1, use1)
    world.vault0 += use0
    world.vault1 += use1
    world.supply += shares
    world.attacker_shares += shares
    world.check('prop-mint')
    out0 = muldiv(world.vault0, shares, world.supply)
    out1 = muldiv(world.vault1, shares, world.supply)
    world.vault0 -= out0
    world.vault1 -= out1
    world._credit('attacker', 0, out0)
    world._credit('attacker', 1, out1)
    world.supply -= shares
    world.attacker_shares -= shares
    world.check('prop-exit')
    world.repay_all()
    return {'label': 'rule4_round_trip', 'shares': shares, 'use': (use0, use1), 'out': (out0, out1), 'attacker_target_delta': world.attacker0 - start0, 'attacker1_delta': world.attacker1 - start1, 'debt': (world.debt0, world.debt1), 'incumbent_idle': (world.vault0, world.vault1), 'initial_idle': (world.initial_vault0, world.initial_vault1), 'closed': world.debt0 == 0 and world.debt1 == 0 and (world.attacker_shares == 0), 'classification': 'incumbent_idle_unchanged' if (world.vault0, world.vault1) == (VAULT_T, VAULT_O) else 'incumbent_changed'}

def disjoint_ranges() -> dict:
    sqrt_p = SQRT_MID
    lower_a, upper_a = (SQRT_LO, SQRT_MID)
    l = 10 ** 18
    below = principal_amounts(sqrt_p, SQRT_LO // 2, SQRT_LO, l, False)
    above = principal_amounts(sqrt_p, SQRT_HI, SQRT_HI + SQRT_LO, l, False)
    summed_l = principal_amounts(sqrt_p, SQRT_LO // 2, SQRT_HI + SQRT_LO, l + l, False)
    added = (below[0] + above[0], below[1] + above[1])
    return {'label': 'disjoint_ranges', 'below_token0_only_range_principal': below, 'above_token1_only_range_principal': above, 'sum_of_principals': added, 'fake_summed_liquidity_principal': summed_l, 'equal': added == summed_l}

def twap_identities() -> dict:
    last_ts = 0
    last_cum = 0
    prev = 0
    now = 1800
    window = 1800
    live = 9116
    as_written = consult(last_ts, last_cum, prev, now, window, live, backfill_live=True)
    idealized = consult(last_ts, last_cum, prev, now, window, live, backfill_live=False)
    recorded, new_cum, _ts = write_as_implemented(last_ts, last_cum, prev, now, live)
    recorded2, cum2, _ts2 = write_as_implemented(now, new_cum, recorded, now + 1, 0)
    mean_after_restore_write = (cum2 - last_cum) // window
    cap = price_cap_9116()
    return {'label': 'twap_identities', 'consult_as_written_mean_tick': as_written, 'consult_idealized_mean_tick': idealized, 'write_records_tick': recorded, 'write_credits_gap_seconds': now - last_ts, 'next_write_records': recorded2, 'window_mean_one_second_after_restore_write': mean_after_restore_write, 'price_multiple_at_9116_ticks': cap, 'sqrt_1_5_price_multiple': '2.25', 'move_inside_one_poke_cap': cap > 2.25}

def consult(last_ts: int, last_cum: int, prev_tick: int, now: int, window: int, live_tick: int, backfill_live: bool) -> int:
    if now - last_ts < window:
        raise ValueError('gap shorter than window')
    tick = live_tick if backfill_live else prev_tick
    cum_now = last_cum + tick * (now - last_ts)
    cum_then = last_cum + tick * (now - window - last_ts)
    delta = cum_now - cum_then
    mean = delta // window
    if delta < 0 and delta % window:
        mean -= 1
    return mean

def write_as_implemented(last_ts: int, last_cum: int, prev_tick: int, now: int, live_tick: int):
    recorded = live_tick
    if recorded > prev_tick + 9116:
        recorded = prev_tick + 9116
    elif recorded < prev_tick - 9116:
        recorded = prev_tick - 9116
    delta = now - last_ts
    return (recorded, last_cum + recorded * delta, now)

def price_cap_9116() -> float:
    x = 1.0
    for _ in range(9116):
        x *= 1.0001
    return x

def rule5_gate_ignores_jit() -> dict:
    world = fresh(l_ext=L_EXT)
    before = world.liquidation()[0]
    gate0, gate1 = principal_amounts(world.sqrt, world.lower, world.upper, L_JIT, True)
    world.borrow(gate0 + BUFFER, gate1 + BUFFER)
    world.add_liquidity('jit', L_JIT, 'attacker')
    after = world.liquidation()[0]
    return {'label': 'rule5_gate', 'sqrt_unchanged': world.sqrt == SQRT_MID, 'quote_before': before, 'quote_after_jit': after, 'quote_increased': after > before, 'classification': 'gate_passes_quote_inflates' if world.sqrt == SQRT_MID and after > before else 'unexpected'}

def rule5_spot_mark_sandwich(push_token1: int, label: str, use_live_as_twap: bool) -> dict:
    world = fresh()
    start0 = world.attacker0
    start1 = world.attacker1
    world.borrow(DEPOSIT + FEE_FLOAT, push_token1 + BUFFER)
    if use_live_as_twap and push_token1:
        world.swap_exact_in(False, push_token1, 'attacker')
    book_t, book_o = world.vault_inventory()
    value_entry = book_t + mark_token1_in_token0(world.sqrt, book_o)
    shares = issue(world.supply, value_entry, DEPOSIT)
    world._debit('attacker', 0, DEPOSIT)
    world.vault0 += DEPOSIT
    world.supply += shares
    world.attacker_shares += shares
    world.check('twap-mint')
    world.snap('after_mint', value_entry=value_entry, minted=shares, sqrt=world.sqrt)
    close_push = world.close_token1_to_debt()
    book_t2, book_o2 = world.vault_inventory()
    value_exit = book_t2 + mark_token1_in_token0(world.sqrt, book_o2)
    assets = entitlement(world.supply, value_exit, shares)
    if world.vault0 < assets:
        return {'label': label, 'classification': 'sleeve_short_not_profit', 'assets': assets, 'vault0': world.vault0}
    world.vault0 -= assets
    world._credit('attacker', 0, assets)
    world.supply -= shares
    world.attacker_shares -= shares
    world.check('twap-redeem')
    close = world.close_token1_to_debt()
    world.snap('after_exit', close_push=close_push, close=close, paid=assets, value_exit=value_exit)
    result = world.finish(label, start0, start1)
    result.update({'value_entry': value_entry, 'value_exit': value_exit, 'minted': shares, 'paid': assets, 'push_token1': push_token1})
    return result

def rule5_idealized_in_tx() -> dict:
    world = fresh()
    world.endow(10 ** 16, 0)
    start0 = world.attacker0
    start1 = world.attacker1
    push = 10 ** 17
    world.borrow(DEPOSIT, push + BUFFER)
    anchor = world.sqrt
    world.swap_exact_in(False, push, 'attacker')
    book_t, book_o = world.vault_inventory()
    value = book_t + mark_token1_in_token0(anchor, book_o)
    shares = issue(world.supply, value, DEPOSIT)
    world._debit('attacker', 0, DEPOSIT)
    world.vault0 += DEPOSIT
    world.supply += shares
    world.attacker_shares += shares
    world.close_token1_to_debt()
    book_t2, book_o2 = world.vault_inventory()
    value2 = book_t2 + mark_token1_in_token0(anchor, book_o2)
    assets = entitlement(world.supply, value2, shares)
    world.vault0 -= assets
    world._credit('attacker', 0, assets)
    world.supply -= shares
    world.attacker_shares -= shares
    world.close_token1_to_debt()
    world.repay_all()
    return {'label': 'rule5_idealized_in_tx', 'value_entry': value, 'value_exit': value2, 'minted': shares, 'paid': assets, 'attacker_target_delta': world.attacker0 - start0, 'attacker1_delta': world.attacker1 - start1, 'debt': (world.debt0, world.debt1), 'closed': world.debt0 == 0 and world.debt1 == 0 and (world.attacker_shares == 0) and (world.attacker1 == start1), 'classification': classify(world.debt0 == 0 and world.debt1 == 0 and (world.attacker_shares == 0) and (world.attacker1 == start1), world.attacker0 - start0, world.attacker1 - start1)}

def quote_mint_slice_exit(push_token1: int, label: str) -> dict:
    world = fresh()
    start0 = world.attacker0
    start1 = world.attacker1
    world.borrow(DEPOSIT + FEE_FLOAT, push_token1 + BUFFER)
    if push_token1:
        world.swap_exact_in(False, push_token1, 'attacker')
    shares, v0 = world.deposit_quote(DEPOSIT)
    world.snap('after_deposit', V0=v0, minted=shares)
    close_push = world.close_token1_to_debt()
    world.snap('after_restore', close=close_push)
    slice_exit(world, shares)
    extra1 = world.attacker1 - start1
    if extra1 > 0:
        world.swap_exact_in(False, extra1, 'attacker')
    close = world.close_token1_to_debt()
    world.snap('after_slice_close', close=close)
    result = world.finish(label, start0, start1)
    result.update({'V0': v0, 'minted': shares, 'push_token1': push_token1})
    return result

def vault_only_lp_gap() -> dict:
    l_vault = L_EXT
    world = fresh(l_ext=0, vault0=VAULT_T, vault1=0, vault_lp=l_vault)
    v_bare = world.liquidation()
    gap0, gap1 = principal_amounts(world.sqrt, world.lower, world.upper, L_JIT, True)
    world.borrow(gap0 + BUFFER, gap1 + BUFFER)
    world.add_liquidity('jit', L_JIT, 'attacker')
    v_jit = world.liquidation()
    return {'label': 'vault_only_lp_quote_gap', 'quote_without_external': v_bare, 'quote_with_jit': v_jit, 'uplift': v_jit[0] - v_bare[0], 'local_target': world.vault0, 'note': 'view gap only; redeem still has to be paid from local target or an actual _fund swap'}

def fund_path_zero_sleeve() -> dict:
    l_vault = L_EXT
    world = fresh(l_ext=0, vault0=0, vault1=0, supply=10 ** 17, vault_lp=l_vault)
    start0 = world.attacker0
    start1 = world.attacker1
    v0, _s0, u0 = world.liquidation()
    deposit = 10 ** 17
    jit_l = 5 * L_EXT
    j0, j1 = principal_amounts(world.sqrt, world.lower, world.upper, jit_l, True)
    world.borrow(deposit + j0 + BUFFER, j1 + BUFFER)
    shares = issue(world.supply, v0, deposit)
    world._debit('attacker', 0, deposit)
    world.vault0 += deposit
    world.supply += shares
    world.attacker_shares += shares
    world.check('fund-deposit')
    world.add_liquidity('jit', jit_l, 'attacker')
    v1, sold, unsold = world.liquidation()
    assets = entitlement(world.supply, v1, shares)
    for pos in list(world.positions):
        if pos.owner == 'vault' and pos.liquidity:
            world.remove_liquidity(pos, pos.liquidity, 'vault')
    if world.vault1:
        world.swap_exact_in(False, world.vault1, 'vault')
    paid = assets if world.vault0 >= assets else world.vault0
    short = world.vault0 < assets
    if not short:
        world.vault0 -= assets
        world._credit('attacker', 0, assets)
    world.supply -= shares
    world.attacker_shares -= shares
    world.check('fund-redeem')
    for pos in list(world.positions):
        if pos.owner == 'jit' and pos.liquidity:
            world.remove_liquidity(pos, pos.liquidity, 'attacker')
    close = world.close_token1_to_debt()
    result = world.finish('fund_path_zero_sleeve', start0, start1)
    result.update({'V0': v0, 'V0_unsold': u0, 'V1': v1, 'V1_sold': sold, 'V1_unsold': unsold, 'minted': shares, 'entitlement': assets, 'sleeve_short': short, 'paid': 0 if short else assets, 'close': close})
    return result

def self_fill_slice() -> dict:
    l_vault = L_EXT
    world = fresh(l_ext=L_EXT, vault0=VAULT_T, vault1=VAULT_O, vault_lp=l_vault)
    start0 = world.attacker0
    start1 = world.attacker1
    f_num, f_den = (1, 5)
    need0 = muldiv_up(world.vault0, f_num, f_den)
    world.borrow(need0 + BUFFER, BUFFER)
    use0 = muldiv(world.vault0, world.supply // 5, world.supply)
    shares = issue(world.supply, world.liquidation()[0], use0)
    world._debit('attacker', 0, use0)
    world.vault0 += use0
    world.supply += shares
    world.attacker_shares += shares
    before = world.vault_inventory()
    slice_exit(world, shares)
    after = world.vault_inventory()
    close = world.close_token1_to_debt()
    result = world.finish('self_fill_note', start0, start1)
    result.update({'inventory_before': before, 'inventory_after': after, 'close': close, 'shares_minted_at_quote': shares})
    return result

def fee_aware_residual() -> dict:
    world = fresh(vault_lp=L_EXT)
    world.borrow(10 ** 17, 0)
    pre = world.vault_inventory()
    pre_quote = world.liquidation()[0]
    amount_in, amount_out, fee = world.swap_exact_in(True, 10 ** 17, 'attacker')
    post = world.vault_inventory()
    p_wad = p_exec_wad(amount_in + fee, amount_out)
    marked = mark_book(post[0], post[1], p_wad)
    liquid = world.liquidation()[0]
    return {'label': 'fee_aware_residual', 'pre': pre, 'post': post, 'p_wad': p_wad, 'marked': marked, 'liquidation': liquid, 'pre_quote': pre_quote, 'marked_minus_liquidation': marked - liquid, 'swap_out': amount_out, 'fee': fee}

def compact(result: dict, keep_log: bool=False) -> dict:
    out = {k: v for k, v in result.items() if k != 'log'}
    if keep_log:
        out['log'] = result.get('log', [])
    return out

def run() -> dict:
    control = rule1_jit(L_EXT, 0, FEE, 'rule1_control_no_jit')
    jit = rule1_jit(L_EXT, L_JIT, FEE, 'rule1_jit_fee_3000')
    jit0 = rule1_jit(L_EXT, L_JIT, 0, 'rule1_jit_fee_0')
    shallow = rule1_jit(10 ** 17, L_JIT, FEE, 'rule1_jit_shallow_external')
    rule2 = [rule2_swap_then_jit(num, 100, L_JIT, f'rule2_swap_{num}pct_then_jit') for num in (1, 49, 50, 51)]
    rule2.append(rule2_swap_then_jit(1, DEPOSIT, L_JIT, 'rule2_swap_1wei_then_jit'))
    rule3 = [rule3_mark_sandwich(0, DEPOSIT // 2, 'rule3_no_push_50pct_mark_all', False), rule3_mark_sandwich(10 ** 17, DEPOSIT // 2, 'rule3_push_50pct_mark_all', False), rule3_mark_sandwich(10 ** 17, muldiv(DEPOSIT, 49, 100), 'rule3_push_49pct_mark_all', False), rule3_mark_sandwich(10 ** 17, muldiv(DEPOSIT, 51, 100), 'rule3_push_51pct_mark_all', False), rule3_mark_sandwich(10 ** 17, 10 ** 12, 'rule3_push_attacker_chosen_1e12_mark_all', False), rule3_mark_sandwich(10 ** 17, DEPOSIT // 2, 'rule3_push_50pct_cutoff_min', True), rule3_cutoff_then_slice(10 ** 12, 'rule3_strict_cutoff_then_slice'), rule3_cutoff_then_slice(DEPOSIT // 2, 'rule3_strict_cutoff_then_slice_50pct')]
    rule5 = [twap_identities(), rule5_gate_ignores_jit(), rule5_spot_mark_sandwich(10 ** 17, 'rule5_as_written_live_backfill_push', True), rule5_spot_mark_sandwich(0, 'rule5_as_written_control_no_push', True), rule5_idealized_in_tx(), rule5_spot_mark_sandwich(10 ** 17, 'rule5_idealized_after_window_same_ledger_as_push', True)]
    combo = [quote_mint_slice_exit(0, 'combo_quote_mint_slice_exit_no_push'), quote_mint_slice_exit(10 ** 17, 'combo_quote_mint_slice_exit_push')]
    report = {'domain': {'range_sqrt': [SQRT_LO, SQRT_HI], 'initial_sqrt': SQRT_MID, 'fee_pips_default': FEE, 'protocol_fee': 0, 'L_ext': L_EXT, 'L_jit': L_JIT, 'vault_idle0': VAULT_T, 'vault_idle1': VAULT_O, 'supply': SUPPLY, 'deposit': DEPOSIT, 'target': 'token0', 'model': 'one initialized range; idle book unless a case names vault_lp', 'not_modeled': ['both-wing harvest', 'hooks', 'tick bitmap', 'nonzero protocol fee', 'donation', 'stepLimit exhaustion']}, 'rule1_control': compact(control), 'rule1_jit': compact(jit, keep_log=True), 'rule1_jit_fee0': compact(jit0), 'rule1_shallow': compact(shallow), 'vault_only_gap': vault_only_lp_gap(), 'fund_path': compact(fund_path_zero_sleeve(), keep_log=False), 'rule2': [compact(row) for row in rule2], 'rule3': [compact(row) for row in rule3], 'rule4_single_sided': rule4_single_sided(), 'rule4_round_trip': rule4_round_trip(), 'disjoint': disjoint_ranges(), 'self_fill_note': compact(self_fill_slice()), 'fee_aware_residual': fee_aware_residual(), 'rule5': [compact(row) if isinstance(row, dict) and 'log' in row else row for row in rule5], 'combo': [compact(row) for row in combo]}
    return report

def main() -> None:
    report = run()
    print(json.dumps(report, indent=2, sort_keys=True))
    control = report['rule1_control']
    jit = report['rule1_jit']
    if not control['closed'] or control['attacker_target_delta'] > 0:
        raise SystemExit('control did not close flat or at a loss')
    if jit['classification'] != 'closed_target_profit':
        raise SystemExit(f"primary JIT witness did not close a target profit: {jit['classification']}")
    if jit['attacker_target_delta'] <= 0:
        raise SystemExit('primary JIT witness profit was not positive')
    if report['disjoint']['equal']:
        raise SystemExit('disjoint ranges collapsed to one scalar, witness invalid')
    twap = report['rule5'][0]
    if twap['consult_as_written_mean_tick'] != 9116 or twap['consult_idealized_mean_tick'] != 0:
        raise SystemExit('TWAP identity failed')
if __name__ == '__main__':
    main()
