# Token List pipeline

The deployment scripts emit per-artifact JSON **fragments** into a typed directory tree.
A Node aggregator reads those fragments and writes Uniswap-compatible Token Lists into
`frontend/app/addresses/<env>/<chain>/`.

## Producer side (Solidity)

Solidity deploy scripts call `_writeManifestEntry(typeDir, key, entry)` per artifact.
The `typeDir` chooses the fragment's home:

- `tokens/` — ERC20 base tokens
- `pools/balancerV3/` — Balancer V3 pool tokens
- `pools/uniV2/` — Uniswap V2 LP tokens
- `pools/aerodrome/` — Aerodrome LP tokens
- `vaults/strategy/` — Pachira-style strategy vault shares
- `vaults/erc4626/` — ERC4626 vault shares
- `vaults/protocolDetf/` — Protocol DETF share tokens
- `factories/`, `facets/`, `hooks/`, `routers/` — consumed by other registries, not the Token List

Fragments live under `deployments/<env>/<chain>/fragments/<typeDir>/<key>.json` and look like:

```json
{
  "chainId": 11155111,
  "address": "0x...",
  "name": "Test Token A",
  "symbol": "TTA",
  "decimals": 18,
  "tags": ["testToken"]
}
```

## Aggregator (Node)

Runs automatically after every staged deploy via `scripts/shell/local_testing.sh`.
It walks the fragment tree, derives default tags from each fragment's directory,
groups fragments into output buckets per `tokenlists.config.ts`, bumps the semver
version by diffing against the previously published list, validates against the
Uniswap Token List schema, and writes one Token List per bucket.

Run directly:

```bash
cd scripts/node && \
INDEXEDEX_REPO_ROOT="$(git rev-parse --show-toplevel)" \
  npm run build-tokenlists -- --config "$(git rev-parse --show-toplevel)/tokenlists.config.ts"
```

Opt out from the shell wrapper:

```bash
SKIP_TOKENLIST_BUILD=1 bash scripts/shell/local_testing.sh foundation
```

## Schema constraints worth knowing

The Uniswap Token List schema is strict. The aggregator normalizes inputs to fit:

- Tag identifiers: `^[\w]+$`, max 10 chars. Use short tags (`balV3`, `aero`, `detf`).
- Tag descriptions: `^[ \w\.,:]+$`. No hyphens or slashes.
- Token symbol: max 20 chars, no whitespace. Longer symbols are truncated; the original
  is preserved (also truncated to 42) in `extensions.fullSymbol`.
- Token name: max 60 chars. Longer names are truncated; full name preserved in
  `extensions.fullName` (also truncated to 42).
- Extension primitive string values: max 42 chars.
- Extension values cannot be arrays. The normalizer rewrites arrays as indexed objects
  (`["a", "b"]` → `{ "0": "a", "1": "b" }`).
- Lists with zero tokens are skipped (the schema requires `minItems: 1`).

## Consumer (UI)

`frontend/app/lib/tokenlistCompose.ts` loads N Token Lists per `(env, chain)` from
the registry in `frontend/app/lib/tokenlistRegistry.ts`, merges them into a composed
store keyed by `(chainId, address)`, and exposes:

- `byTag(store, tags[], chainId)` — used by the "Select Pool" dropdown and friends
- `byAddress(store, address, chainId)` — single lookup
- `resolveLabel(token)` — prefers `extensions.display`, then `name`, then `symbol`

To override a dropdown label without redeploying, edit a fragment or list to add
`extensions.display: "My Label"` for that address.

## One-time legacy migration

Pre-existing per-category JSONs (`<env>-balancerv3-pools.tokenlist.json` etc.) were
migrated once via `scripts/node/src/migrateLegacy.ts`. The script wraps each legacy
array in a valid Token List envelope and writes it under the new bucket name. Future
deploys (via the aggregator) overwrite these.
