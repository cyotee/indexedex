import { describe, expect, it } from 'vitest'
import {
  classifyToken,
  disambiguate,
  resolveRoute,
  type Address,
} from './routeMatcher'

/* -------------------------------------------------------------------------- */
/*                          Test fixture addresses                            */
/* -------------------------------------------------------------------------- */

const A = {
  // Balancer pool tokens (mix of underlying and vault wrappers)
  poolBalancer: '0xBA1A11CE0000000000000000000000000000B001' as Address,
  // Standard Exchange Vault used as pool
  poolVault: '0xVA1707000000000000000000000000000000aabb' as Address,
  // Underlying tokens
  TTA: '0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA0001' as Address,
  TTB: '0xBbBbBbBbBbBbBbBbBbBbBbBbBbBbBbBbBbBb0002' as Address,
  TTC: '0xcCCCCCcCccCCCcCCccCCCcccCCCccccCCCcc0003' as Address,
  // Standard Exchange Vault share tokens
  VAB: '0x0000000000000000000000000000000000000aB1' as Address,
  VAC: '0x0000000000000000000000000000000000000aC1' as Address,
  VBC: '0x0000000000000000000000000000000000000Bc1' as Address,
  // Random non-route token
  Z: '0xDeadDeadDeadDeadDeadDeadDeadDeadDeadDead' as Address,
} as const

const emptyMap = new Map<string, readonly Address[]>()

/* -------------------------------------------------------------------------- */
/*                              classifyToken                                 */
/* -------------------------------------------------------------------------- */

describe('classifyToken', () => {
  it('returns direct when the token is one of the pool tokens', () => {
    expect(classifyToken(A.TTA, [A.TTA, A.TTB], emptyMap)).toEqual({ kind: 'direct' })
  })

  it('case-insensitive direct match', () => {
    const upper = A.TTA.toUpperCase() as Address
    expect(classifyToken(upper, [A.TTA, A.TTB], emptyMap)).toEqual({ kind: 'direct' })
  })

  it('returns wrapped when exactly one pool token is a vault that wraps the token', () => {
    const map = new Map<string, readonly Address[]>([[A.VAB.toLowerCase(), [A.TTA, A.TTB]]])
    expect(classifyToken(A.TTA, [A.VAB, A.TTC], map)).toEqual({ kind: 'wrapped', vault: A.VAB })
  })

  it('returns ambiguous when two pool tokens are both vaults that wrap the token', () => {
    const map = new Map<string, readonly Address[]>([
      [A.VAB.toLowerCase(), [A.TTA, A.TTB]],
      [A.VAC.toLowerCase(), [A.TTA, A.TTC]],
    ])
    const result = classifyToken(A.TTA, [A.VAB, A.VAC], map)
    expect(result.kind).toBe('ambiguous')
    if (result.kind === 'ambiguous') {
      expect(result.candidates).toEqual([A.VAB, A.VAC])
    }
  })

  it('returns invalid when no pool token wraps the requested token', () => {
    const map = new Map<string, readonly Address[]>([[A.VAB.toLowerCase(), [A.TTA, A.TTB]]])
    expect(classifyToken(A.Z, [A.VAB, A.TTC], map)).toEqual({ kind: 'invalid' })
  })

  it('ignores vaults that are not in pool tokens, even if they wrap the token', () => {
    const map = new Map<string, readonly Address[]>([[A.VAB.toLowerCase(), [A.TTA]]])
    // VAB is NOT in poolTokens — router can't route through it on this pool.
    expect(classifyToken(A.TTA, [A.TTC, A.TTB], map)).toEqual({ kind: 'invalid' })
  })
})

/* -------------------------------------------------------------------------- */
/*                              disambiguate                                  */
/* -------------------------------------------------------------------------- */

describe('disambiguate', () => {
  const ambiguous = { kind: 'ambiguous' as const, candidates: [A.VAB, A.VAC] }

  it('promotes ambiguous to wrapped when the selection matches a candidate', () => {
    expect(disambiguate(ambiguous, A.VAB)).toEqual({ kind: 'wrapped', vault: A.VAB })
  })

  it('keeps ambiguous when the selection is not in the candidates list', () => {
    expect(disambiguate(ambiguous, A.VBC)).toEqual(ambiguous)
  })

  it('keeps ambiguous when the selection is null', () => {
    expect(disambiguate(ambiguous, null)).toEqual(ambiguous)
  })

  it('passes through non-ambiguous classifications unchanged', () => {
    const wrapped = { kind: 'wrapped' as const, vault: A.VAB }
    expect(disambiguate(wrapped, A.VAC)).toEqual(wrapped)
    expect(disambiguate({ kind: 'direct' }, A.VAB)).toEqual({ kind: 'direct' })
    expect(disambiguate({ kind: 'invalid' }, A.VAB)).toEqual({ kind: 'invalid' })
  })

  it('selection match is case-insensitive', () => {
    const upper = A.VAB.toUpperCase() as Address
    const result = disambiguate(ambiguous, upper)
    expect(result.kind).toBe('wrapped')
    if (result.kind === 'wrapped') expect(result.vault.toLowerCase()).toBe(A.VAB.toLowerCase())
  })
})

/* -------------------------------------------------------------------------- */
/*                       resolveRoute — pool == vault                         */
/* -------------------------------------------------------------------------- */

describe('resolveRoute (pool == vault)', () => {
  // MultiAsset vault.vaultTokens() reports every accepted exchange token
  // EXCEPT the vault share itself (the vault is always assumed to accept
  // itself). The matcher validates the non-vault side against this list.
  const vaultUnderlying = new Map<string, readonly Address[]>([
    [A.poolVault.toLowerCase(), [A.TTA, A.TTB]],
  ])

  it('pending when vaultTokens() has not loaded yet', () => {
    expect(
      resolveRoute({
        poolType: 'vault',
        poolAddress: A.poolVault,
        tokenIn: A.TTA,
        tokenOut: A.TTB,
        poolTokens: [A.poolVault],
        underlyingByVault: emptyMap,
      })
    ).toEqual({ kind: 'pending' })
  })

  it('Strategy Vault Withdrawal: tokenIn == vault share, tokenOut in vaultTokens()', () => {
    const result = resolveRoute({
      poolType: 'vault',
      poolAddress: A.poolVault,
      tokenIn: A.poolVault,
      tokenOut: A.TTA,
      poolTokens: [A.poolVault],
      underlyingByVault: vaultUnderlying,
    })
    expect(result).toMatchObject({
      kind: 'ok',
      route: 'Strategy Vault Withdrawal',
      useTokenInVault: false,
      useTokenOutVault: true,
      tokenOutVault: A.poolVault,
    })
  })

  it('Strategy Vault Deposit: tokenIn in vaultTokens(), tokenOut == vault share', () => {
    const result = resolveRoute({
      poolType: 'vault',
      poolAddress: A.poolVault,
      tokenIn: A.TTA,
      tokenOut: A.poolVault,
      poolTokens: [A.poolVault],
      underlyingByVault: vaultUnderlying,
    })
    expect(result).toMatchObject({
      kind: 'ok',
      route: 'Strategy Vault Deposit',
      useTokenInVault: true,
      useTokenOutVault: false,
      tokenInVault: A.poolVault,
    })
  })

  it('Vault Pass-Through: both tokens in vaultTokens(), neither is the vault share', () => {
    const result = resolveRoute({
      poolType: 'vault',
      poolAddress: A.poolVault,
      tokenIn: A.TTA,
      tokenOut: A.TTB,
      poolTokens: [A.poolVault],
      underlyingByVault: vaultUnderlying,
    })
    expect(result).toMatchObject({
      kind: 'ok',
      route: 'Vault Pass-Through',
      useTokenInVault: true,
      useTokenOutVault: true,
      tokenInVault: A.poolVault,
      tokenOutVault: A.poolVault,
    })
  })

  it('invalid when one of the tokens is not in vaultTokens() and is not the vault itself', () => {
    const result = resolveRoute({
      poolType: 'vault',
      poolAddress: A.poolVault,
      tokenIn: A.TTA,
      tokenOut: A.Z,
      poolTokens: [A.poolVault],
      underlyingByVault: vaultUnderlying,
    })
    expect(result.kind).toBe('invalid')
  })

  it('invalid when both tokenIn AND tokenOut equal the vault share', () => {
    const result = resolveRoute({
      poolType: 'vault',
      poolAddress: A.poolVault,
      tokenIn: A.poolVault,
      tokenOut: A.poolVault,
      poolTokens: [A.poolVault],
      underlyingByVault: vaultUnderlying,
    })
    expect(result.kind).toBe('invalid')
  })

  it('case-insensitive vault address comparison', () => {
    const lower = A.poolVault.toLowerCase() as Address
    const upper = A.poolVault.toUpperCase() as Address
    const result = resolveRoute({
      poolType: 'vault',
      poolAddress: lower,
      tokenIn: upper,
      tokenOut: A.TTA,
      poolTokens: [lower],
      underlyingByVault: new Map<string, readonly Address[]>([[lower, [A.TTA, A.TTB]]]),
    })
    expect(result).toMatchObject({ kind: 'ok', route: 'Strategy Vault Withdrawal' })
  })
})

/* -------------------------------------------------------------------------- */
/*                     resolveRoute — pool == balancer                        */
/* -------------------------------------------------------------------------- */

describe('resolveRoute (pool == balancer)', () => {
  it('pending when pool tokens have not loaded', () => {
    expect(
      resolveRoute({
        poolType: 'balancer',
        poolAddress: A.poolBalancer,
        tokenIn: A.TTA,
        tokenOut: A.TTB,
        poolTokens: [],
        underlyingByVault: emptyMap,
      })
    ).toEqual({ kind: 'pending' })
  })

  it('Direct Balancer Swap when both tokens are direct pool tokens', () => {
    const result = resolveRoute({
      poolType: 'balancer',
      poolAddress: A.poolBalancer,
      tokenIn: A.TTA,
      tokenOut: A.TTB,
      poolTokens: [A.TTA, A.TTB],
      underlyingByVault: emptyMap,
    })
    expect(result).toMatchObject({
      kind: 'ok',
      route: 'Direct Balancer Swap',
      useTokenInVault: false,
      useTokenOutVault: false,
      tokenInVault: null,
      tokenOutVault: null,
    })
  })

  it('Vault Deposit + Balancer Swap when tokenIn is wrapped, tokenOut direct', () => {
    const underlying = new Map<string, readonly Address[]>([[A.VAB.toLowerCase(), [A.TTA, A.TTB]]])
    const result = resolveRoute({
      poolType: 'balancer',
      poolAddress: A.poolBalancer,
      tokenIn: A.TTA,
      tokenOut: A.TTC,
      poolTokens: [A.VAB, A.TTC],
      underlyingByVault: underlying,
    })
    expect(result).toMatchObject({
      kind: 'ok',
      route: 'Vault Deposit + Balancer Swap',
      useTokenInVault: true,
      useTokenOutVault: false,
      tokenInVault: A.VAB,
      tokenOutVault: null,
    })
  })

  it('Balancer Swap + Vault Withdrawal when tokenIn direct, tokenOut wrapped', () => {
    const underlying = new Map<string, readonly Address[]>([[A.VBC.toLowerCase(), [A.TTB, A.TTC]]])
    const result = resolveRoute({
      poolType: 'balancer',
      poolAddress: A.poolBalancer,
      tokenIn: A.TTA,
      tokenOut: A.TTC,
      poolTokens: [A.TTA, A.VBC],
      underlyingByVault: underlying,
    })
    expect(result).toMatchObject({
      kind: 'ok',
      route: 'Balancer Swap + Vault Withdrawal',
      useTokenInVault: false,
      useTokenOutVault: true,
      tokenInVault: null,
      tokenOutVault: A.VBC,
    })
  })

  it('Vault Deposit + Swap + Vault Withdrawal when both sides are wrapped', () => {
    const underlying = new Map<string, readonly Address[]>([
      [A.VAB.toLowerCase(), [A.TTA, A.TTB]],
      [A.VBC.toLowerCase(), [A.TTB, A.TTC]],
    ])
    const result = resolveRoute({
      poolType: 'balancer',
      poolAddress: A.poolBalancer,
      tokenIn: A.TTA,
      tokenOut: A.TTC,
      poolTokens: [A.VAB, A.VBC],
      underlyingByVault: underlying,
    })
    expect(result).toMatchObject({
      kind: 'ok',
      route: 'Vault Deposit + Swap + Vault Withdrawal',
      useTokenInVault: true,
      useTokenOutVault: true,
      tokenInVault: A.VAB,
      tokenOutVault: A.VBC,
    })
  })

  it('ambiguous (side: in) when two pool-token vaults both wrap tokenIn', () => {
    const underlying = new Map<string, readonly Address[]>([
      [A.VAB.toLowerCase(), [A.TTA, A.TTB]],
      [A.VAC.toLowerCase(), [A.TTA, A.TTC]],
    ])
    const result = resolveRoute({
      poolType: 'balancer',
      poolAddress: A.poolBalancer,
      tokenIn: A.TTA,
      tokenOut: A.VAC, // direct (it's in poolTokens)
      poolTokens: [A.VAB, A.VAC],
      underlyingByVault: underlying,
    })
    expect(result.kind).toBe('ambiguous')
    if (result.kind === 'ambiguous') {
      expect(result.side).toBe('in')
      expect(result.tokenInCandidates).toEqual([A.VAB, A.VAC])
      expect(result.tokenOutCandidates).toBeNull()
    }
  })

  it('ambiguous (side: both) when both tokens are wrapped by multiple pool-token vaults', () => {
    const underlying = new Map<string, readonly Address[]>([
      [A.VAB.toLowerCase(), [A.TTA, A.TTB]],
      [A.VAC.toLowerCase(), [A.TTA, A.TTC]],
      [A.VBC.toLowerCase(), [A.TTB, A.TTC]],
    ])
    const result = resolveRoute({
      poolType: 'balancer',
      poolAddress: A.poolBalancer,
      tokenIn: A.TTA, // wrapped by both VAB and VAC
      tokenOut: A.TTC, // wrapped by both VAC and VBC
      poolTokens: [A.VAB, A.VAC, A.VBC],
      underlyingByVault: underlying,
    })
    expect(result.kind).toBe('ambiguous')
    if (result.kind === 'ambiguous') {
      expect(result.side).toBe('both')
    }
  })

  it('user disambiguation collapses ambiguous to ok', () => {
    const underlying = new Map<string, readonly Address[]>([
      [A.VAB.toLowerCase(), [A.TTA, A.TTB]],
      [A.VAC.toLowerCase(), [A.TTA, A.TTC]],
    ])
    const result = resolveRoute({
      poolType: 'balancer',
      poolAddress: A.poolBalancer,
      tokenIn: A.TTA,
      tokenOut: A.VAC,
      poolTokens: [A.VAB, A.VAC],
      underlyingByVault: underlying,
      selectedVaultIn: A.VAB, // user picks VAB to disambiguate
    })
    expect(result).toMatchObject({
      kind: 'ok',
      route: 'Vault Deposit + Balancer Swap',
      useTokenInVault: true,
      tokenInVault: A.VAB,
    })
  })

  it('invalid when neither side can be routed', () => {
    const underlying = new Map<string, readonly Address[]>([[A.VAB.toLowerCase(), [A.TTA, A.TTB]]])
    const result = resolveRoute({
      poolType: 'balancer',
      poolAddress: A.poolBalancer,
      tokenIn: A.Z, // not in any pool token's underlying
      tokenOut: A.Z,
      poolTokens: [A.VAB, A.TTC],
      underlyingByVault: underlying,
    })
    expect(result.kind).toBe('invalid')
    if (result.kind === 'invalid') {
      expect(result.poolTokens).toEqual([A.VAB, A.TTC])
      expect(result.underlyingByVault.get(A.VAB.toLowerCase())).toEqual([A.TTA, A.TTB])
    }
  })

  it('invalid even when one side resolves but the other does not', () => {
    const underlying = new Map<string, readonly Address[]>([[A.VAB.toLowerCase(), [A.TTA, A.TTB]]])
    const result = resolveRoute({
      poolType: 'balancer',
      poolAddress: A.poolBalancer,
      tokenIn: A.TTA, // wrapped via VAB
      tokenOut: A.Z, // no route
      poolTokens: [A.VAB, A.TTC],
      underlyingByVault: underlying,
    })
    expect(result.kind).toBe('invalid')
  })
})
