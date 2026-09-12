// Pure route resolution for the Balancer V3 Standard Exchange Router.
//
// Mirrors the branches in
// contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactInSwapTarget.sol:
//
//   pool == Standard Exchange Vault
//     line 307: Vault Pass-Through       (both sides underlying)
//     line 372: Strategy Vault Deposit    (tokenIn underlying, tokenOut == vault share)
//     line 422: Strategy Vault Withdrawal (tokenIn == vault share, tokenOut underlying)
//
//   pool == Balancer V3 pool
//     line 244: Direct Balancer Swap                    (both sides direct pool tokens)
//     line 505: Strategy Vault Deposit + Balancer Swap  (tokenIn wraps into a pool token via a vault)
//     line 709: Balancer Swap + Strategy Vault Withdrawal (tokenOut unwraps from a pool token via a vault)
//     line 580: Deposit + Swap + Withdrawal             (both sides wrapped)
//
// Any other shape hits the router's `InvalidRoute(...)` revert.
//
// The matcher is direction-agnostic — it works identically for exactIn and
// exactOut callers — and has no React dependencies, so it can be unit tested in
// isolation.

export type Address = `0x${string}`

/** A token's relationship to the active pool. */
export type TokenClassification =
  | { kind: 'direct' }
  | { kind: 'wrapped'; vault: Address }
  | { kind: 'ambiguous'; candidates: Address[] }
  | { kind: 'invalid' }

/**
 * Classify a single side of the swap against the pool's tokens and the table of
 * candidate vaults' underlying tokens.
 *
 * The pool-as-vault case is the degenerate form of this same matcher: pass
 * `poolTokens = [poolAddress]` and `underlyingByVault = { poolAddress: vault.vaultTokens() }`.
 */
export function classifyToken(
  token: Address,
  poolTokens: readonly Address[],
  underlyingByVault: ReadonlyMap<string, readonly Address[]>
): TokenClassification {
  const target = token.toLowerCase()

  // direct: the token IS one of the pool's tokens
  for (const pt of poolTokens) {
    if (pt.toLowerCase() === target) return { kind: 'direct' }
  }

  // wrapped: the token is the underlying of some vault, and that vault is
  // itself one of the pool's tokens (so the router can swap it in/out)
  const matches: Address[] = []
  for (const pt of poolTokens) {
    const underlying = underlyingByVault.get(pt.toLowerCase())
    if (!underlying) continue
    if (underlying.some((u) => u.toLowerCase() === target)) matches.push(pt)
  }
  if (matches.length === 0) return { kind: 'invalid' }
  if (matches.length === 1) return { kind: 'wrapped', vault: matches[0]! }
  return { kind: 'ambiguous', candidates: matches }
}

/**
 * Allow the user to disambiguate by manually selecting one of the candidate
 * vaults. If the manual selection isn't in the candidate list (e.g. they
 * switched pools and the old selection no longer applies), the ambiguity
 * stays unresolved.
 */
export function disambiguate(
  classification: TokenClassification,
  userSelection: Address | null
): TokenClassification {
  if (classification.kind !== 'ambiguous' || !userSelection) return classification
  const sel = userSelection.toLowerCase()
  if (classification.candidates.some((c) => c.toLowerCase() === sel)) {
    return { kind: 'wrapped', vault: userSelection }
  }
  return classification
}

/* -------------------------------------------------------------------------- */
/*                              Route resolution                              */
/* -------------------------------------------------------------------------- */

export type VaultRouteName =
  | 'Strategy Vault Withdrawal'
  | 'Strategy Vault Deposit'
  | 'Vault Pass-Through'

export type BalancerRouteName =
  | 'Direct Balancer Swap'
  | 'Vault Deposit + Balancer Swap'
  | 'Balancer Swap + Vault Withdrawal'
  | 'Vault Deposit + Swap + Vault Withdrawal'

export type RouteResolution<RouteName extends string> =
  | { kind: 'pending' }
  | {
      kind: 'ok'
      route: RouteName
      useTokenInVault: boolean
      useTokenOutVault: boolean
      /** Address to seed selectedVaultIn when useTokenInVault is true. */
      tokenInVault: Address | null
      /** Address to seed selectedVaultOut when useTokenOutVault is true. */
      tokenOutVault: Address | null
    }
  | {
      kind: 'ambiguous'
      side: 'in' | 'out' | 'both'
      tokenInCandidates: Address[] | null
      tokenOutCandidates: Address[] | null
    }
  | {
      kind: 'invalid'
      /** Pool tokens we matched against (so the UI can list them). */
      poolTokens: readonly Address[]
      /** Vault -> underlying mapping for the candidate vaults we considered. */
      underlyingByVault: ReadonlyMap<string, readonly Address[]>
    }

interface ResolveRouteInput {
  poolType: 'balancer' | 'vault'
  poolAddress: Address
  tokenIn: Address
  tokenOut: Address
  poolTokens: readonly Address[]
  underlyingByVault: ReadonlyMap<string, readonly Address[]>
  /** Optional user disambiguation if matching is ambiguous. */
  selectedVaultIn?: Address | null
  selectedVaultOut?: Address | null
}

/**
 * Resolve the (Token In, Token Out) pair to one of the seven router branches,
 * surfacing ambiguity and invalid combinations explicitly so the UI can guide
 * the user.
 */
export function resolveRoute(
  input: ResolveRouteInput
): RouteResolution<VaultRouteName> | RouteResolution<BalancerRouteName> {
  return input.poolType === 'vault' ? resolveVaultPool(input) : resolveBalancerPool(input)
}

/* ---------------------------- pool == Vault ---------------------------- */

function resolveVaultPool(input: ResolveRouteInput): RouteResolution<VaultRouteName> {
  const { poolAddress, tokenIn, tokenOut, underlyingByVault } = input

  // The vault's IMultiAssetBasicVault.vaultTokens() now reports every token
  // it will accept for exchange, EXCLUDING the vault share itself (a vault is
  // always assumed to accept its own share). So the matcher validates:
  //
  //   tokenIn == vault, tokenOut in vaultTokens()  -> Strategy Vault Withdrawal
  //   tokenIn in vaultTokens(), tokenOut == vault  -> Strategy Vault Deposit
  //   tokenIn in vaultTokens(), tokenOut in vaultTokens()  -> Vault Pass-Through
  //   tokenIn == vault && tokenOut == vault   -> invalid (vault for itself)
  //   anything else  -> invalid (vault won't accept one of the sides)

  const underlying = underlyingByVault.get(poolAddress.toLowerCase())
  if (!underlying) return { kind: 'pending' }

  const vault = poolAddress.toLowerCase()
  const t1 = tokenIn.toLowerCase()
  const t2 = tokenOut.toLowerCase()
  const inIsVault = t1 === vault
  const outIsVault = t2 === vault
  const isUnderlying = (addr: string) => underlying.some((u) => u.toLowerCase() === addr)

  if (inIsVault && outIsVault) {
    return { kind: 'invalid', poolTokens: [poolAddress], underlyingByVault }
  }
  if (inIsVault && isUnderlying(t2)) {
    return {
      kind: 'ok',
      route: 'Strategy Vault Withdrawal',
      useTokenInVault: false,
      useTokenOutVault: true,
      tokenInVault: null,
      tokenOutVault: poolAddress,
    }
  }
  if (outIsVault && isUnderlying(t1)) {
    return {
      kind: 'ok',
      route: 'Strategy Vault Deposit',
      useTokenInVault: true,
      useTokenOutVault: false,
      tokenInVault: poolAddress,
      tokenOutVault: null,
    }
  }
  if (!inIsVault && !outIsVault && isUnderlying(t1) && isUnderlying(t2)) {
    return {
      kind: 'ok',
      route: 'Vault Pass-Through',
      useTokenInVault: true,
      useTokenOutVault: true,
      tokenInVault: poolAddress,
      tokenOutVault: poolAddress,
    }
  }
  return { kind: 'invalid', poolTokens: [poolAddress], underlyingByVault }
}

/* --------------------------- pool == Balancer -------------------------- */

function resolveBalancerPool(input: ResolveRouteInput): RouteResolution<BalancerRouteName> {
  const { tokenIn, tokenOut, poolTokens, underlyingByVault, selectedVaultIn, selectedVaultOut } = input

  if (poolTokens.length === 0) return { kind: 'pending' }

  let inClass = classifyToken(tokenIn, poolTokens, underlyingByVault)
  let outClass = classifyToken(tokenOut, poolTokens, underlyingByVault)

  // User picks override ambiguity.
  inClass = disambiguate(inClass, selectedVaultIn ?? null)
  outClass = disambiguate(outClass, selectedVaultOut ?? null)

  if (inClass.kind === 'ambiguous' || outClass.kind === 'ambiguous') {
    return {
      kind: 'ambiguous',
      side:
        inClass.kind === 'ambiguous' && outClass.kind === 'ambiguous'
          ? 'both'
          : inClass.kind === 'ambiguous'
            ? 'in'
            : 'out',
      tokenInCandidates: inClass.kind === 'ambiguous' ? inClass.candidates : null,
      tokenOutCandidates: outClass.kind === 'ambiguous' ? outClass.candidates : null,
    }
  }

  if (inClass.kind === 'invalid' || outClass.kind === 'invalid') {
    return { kind: 'invalid', poolTokens, underlyingByVault }
  }

  // At this point both sides are { kind: 'direct' } or { kind: 'wrapped'; vault }.
  const inDirect = inClass.kind === 'direct'
  const outDirect = outClass.kind === 'direct'

  if (inDirect && outDirect) {
    return {
      kind: 'ok',
      route: 'Direct Balancer Swap',
      useTokenInVault: false,
      useTokenOutVault: false,
      tokenInVault: null,
      tokenOutVault: null,
    }
  }
  if (inDirect && !outDirect) {
    return {
      kind: 'ok',
      route: 'Balancer Swap + Vault Withdrawal',
      useTokenInVault: false,
      useTokenOutVault: true,
      tokenInVault: null,
      tokenOutVault: (outClass as { kind: 'wrapped'; vault: Address }).vault,
    }
  }
  if (!inDirect && outDirect) {
    return {
      kind: 'ok',
      route: 'Vault Deposit + Balancer Swap',
      useTokenInVault: true,
      useTokenOutVault: false,
      tokenInVault: (inClass as { kind: 'wrapped'; vault: Address }).vault,
      tokenOutVault: null,
    }
  }
  return {
    kind: 'ok',
    route: 'Vault Deposit + Swap + Vault Withdrawal',
    useTokenInVault: true,
    useTokenOutVault: true,
    tokenInVault: (inClass as { kind: 'wrapped'; vault: Address }).vault,
    tokenOutVault: (outClass as { kind: 'wrapped'; vault: Address }).vault,
  }
}
