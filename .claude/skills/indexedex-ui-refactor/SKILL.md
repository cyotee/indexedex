---
name: indexedex-ui-refactor
description: Indexedex frontend deployment-environment and artifact-registry refactor. Use when switching the UI between live Sepolia and local supersim_sepolia, updating address artifact loading, changing wagmi transports, or touching the deployment environment toggle, address registry, or chain-id resolution helpers.
---

# Indexedex UI Refactor

This skill documents the frontend refactor that made the UI environment-aware across live Sepolia and the local SuperSim rehearsal.

## Use This Skill For

- adding or changing deployment environments
- updating address artifact imports or registry wiring
- fixing chain-id to artifact resolution
- adjusting wagmi transport selection for local versus live networks
- reviewing pages that consume deployment artifacts and token lists

## Core Architecture

The frontend now has one central artifact registry and one central deployment-environment state.

### Single Source of Truth

- `frontend/app/addresses/index.ts` owns the artifact registry.
- `frontend/app/lib/addressArtifacts.ts` owns chain-id resolution and typed access to bundles.
- `frontend/app/lib/deploymentEnvironment.tsx` owns the deployment-environment type, context contract, storage key, and toggle UI.
- `frontend/app/providers.tsx` owns persisted environment state and wagmi transport switching.

Do not scatter direct artifact JSON imports across feature pages when the data belongs in the shared registry.

## Deployment Environment Model

Current supported environments:

```ts
type DeploymentEnvironment = 'sepolia' | 'supersim_sepolia'
```

Rules:

- Default to `supersim_sepolia` unless `NEXT_PUBLIC_DEFAULT_DEPLOYMENT_ENVIRONMENT` overrides it.
- Persist the current environment in localStorage under `indexedex:deployment-environment`.
- Keep environment switching in provider and context code, not in individual pages.

## Artifact Registry Rules

In `frontend/app/addresses/index.ts`:

- Import each environment's JSON artifacts once.
- Build bundles with `buildBundle(...)` so every list is normalized consistently.
- Stamp `chainId` into normalized platform and token-list entries.
- Keep the registry keyed by environment and canonical chain id.

Canonical chain ids:

- `11155111` for Ethereum Sepolia
- `84532` for Base Sepolia

When adding a new artifact category, update:

1. the import set in `frontend/app/addresses/index.ts`
2. the `ArtifactBundle` type
3. `buildBundle(...)`
4. the registry entry for each supported environment

## Chain Resolution Rules

In `frontend/app/lib/addressArtifacts.ts`:

- Treat canonical artifacts as Sepolia and Base Sepolia bundles.
- Resolve `31337` and `1337` to Sepolia artifacts for local development.
- Resolve chain id `8453` to Base Sepolia artifacts only when the selected environment is `supersim_sepolia`.
- Throw explicit errors for unsupported chain ids or missing bundles.

Do not duplicate ad hoc chain-id fallback logic in pages or hooks.

## Provider Rules

In `frontend/app/providers.tsx`:

- Keep wagmi config dependent on the selected deployment environment.
- For `supersim_sepolia`, route Sepolia traffic to `NEXT_PUBLIC_LOCAL_RPC_URL` and Base Sepolia traffic to `NEXT_PUBLIC_BASE_RPC_URL`.
- For live `sepolia`, route Sepolia and Base Sepolia traffic to their normal RPC URLs.
- Update the in-memory default artifact environment whenever the UI environment changes.

This prevents the wallet layer and artifact lookup layer from drifting out of sync.

## UI Pattern

The environment switcher is intentionally lightweight:

- fixed overlay
- explicit label
- simple select control
- no page-specific copies of the same control

Keep this as a shared control instead of re-implementing environment selection per page.

## Refactor Checklist

When changing deployment-environment behavior:

1. Update the environment union and registry first.
2. Confirm chain-id resolution still maps local chains to the intended artifact bundle.
3. Confirm provider transports match the selected environment.
4. Confirm localStorage persistence still restores the previous selection.
5. Confirm both `sepolia` and `supersim_sepolia` render with the expected artifacts.

## Source Files

- `frontend/app/addresses/index.ts`
- `frontend/app/lib/addressArtifacts.ts`
- `frontend/app/lib/deploymentEnvironment.tsx`
- `frontend/app/providers.tsx`

## What To Avoid

- page-level direct imports of deployment JSON that bypass the shared registry
- duplicate environment state in multiple hooks or pages
- inconsistent chain-id mapping between wagmi transports and artifact lookup
- defaulting to live RPCs while still reading local supersim artifacts