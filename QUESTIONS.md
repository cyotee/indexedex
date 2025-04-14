# QUESTIONS

Answer inline under each item.

## 1. Frontend environment selection

What should be the canonical frontend environment selector for runtime resolution?

Options I see:
- explicit env var such as `NEXT_PUBLIC_DEPLOYMENT_ENV`
- wallet chain plus localhost detection
- a hybrid of both

Answer:
Use the hybrid option.

Decision:
- wallet `chainId` is the primary selector for chain role
- a visible developer-facing app environment toggle determines whether the UI loads `sepolia` or `supersim_sepolia`

Rationale:
- the local SuperSim Anvil instances will preserve the chain IDs of their forked chains, so `chainId` cleanly distinguishes Ethereum-side versus Base-side
- the remaining ambiguity is environment, not chain role
- the app should therefore not guess from wallet RPC details
- the environment switch should be explicit and visible to developers during local testing

Intended resolution shape:
- `{ environment: "sepolia", chainId: 11155111 }`
- `{ environment: "sepolia", chainId: <base-sepolia-chain-id> }`
- `{ environment: "supersim_sepolia", chainId: 11155111 }`
- `{ environment: "supersim_sepolia", chainId: <base-sepolia-chain-id> }`

## 2. Local SuperSim chain IDs

For local SuperSim, what chain IDs should the UI treat as the authoritative Ethereum-side and Base-side identities?

Is the expectation that the local forks preserve Sepolia and Base Sepolia chain IDs, or that they use local Anvil-style IDs with an environment registry layered on top?

Answer:
Preserve the real forked chain IDs.

Decision:
- the local Ethereum SuperSim fork should use Ethereum Sepolia's chain ID
- the local Base SuperSim fork should use Base Sepolia's chain ID
- do not introduce synthetic Anvil-style chain IDs for this environment

Rationale:
- the UI should treat the local SuperSim chains as the same logical chains as their public Sepolia counterparts
- this keeps chain-role selection simple and lets wallet `chainId` distinguish Ethereum-side versus Base-side directly
- environment selection then only needs to decide between `sepolia` and `supersim_sepolia`

## 3. Frontend registry generation model

Do you want the frontend registry to be fully generated from deployment outputs, or do you want a checked-in typed registry file that imports generated JSON artifacts?

Answer:
Generate a typed frontend registry file into the correct frontend location, and use that generated registry as the source of runtime environment-plus-chain resolution. I will handle committing it.

Decision:
- generate the registry file into the frontend at the correct location
- keep the registry typed and structured so we can expand supported chains in the future
- use the generated registry as the runtime source of truth for `{ environment, chainId } -> artifact bundle`

Implementation note:
- this is not meant to be a manually maintained registry
- the deployment/export flow should generate it, and I will handle committing it afterward

## 4. Frontend artifact directory shape

Should the new frontend artifact layout be nested by environment and chain, like `frontend/app/addresses/supersim_sepolia/ethereum/...`, or do you prefer a flatter naming convention with explicit filenames in a single directory?

Answer: Yes, the directories should be environment and chain.

## 5. Public Sepolia frontend path compatibility

For public Sepolia artifacts, do you want to keep the existing `frontend/app/addresses/sepolia/...` paths for compatibility, or should that bucket also be normalized into separate `ethereum` and `base` subfolders now?

Answer: Separate ethereum and base with subfolders of the network folder.

## 6. Canonical manifest schema

What is the canonical manifest schema you want each chain-local deployment to emit?

At minimum I assume:
- `platform`
- `factories`
- `tokenlists`
- `contractlists`
- bridge metadata

Do you also want:
- stage metadata
- chain metadata
- timestamps
- commit hashes
- source environment metadata

Answer: No, we do not need the additional metadata.

## 7. External dependency addresses in manifests

Should the chain-local manifest include only deployed addresses, or also the canonical external dependency addresses consumed from the fork, such as Balancer V3 vault and router addresses and other non-deployed chain dependencies?

Answer: It should include the addresses from our own deployment and all external dependency addresses required by the deployment, bridge bootstrap, and frontend/runtime flows.

## 8. Shared bridge metadata location

For bridge bootstrap outputs, should shared cross-chain metadata live only in `deployments/supersim_sepolia/shared/`, or should the shared data also be copied back into each chain-local manifest for easier frontend and runtime consumption?

Answer: Copy it into the chain-local manifest.

## 9. Top-level Foundry orchestration behavior

Should the top-level Foundry orchestration script actually broadcast all phases in one run, or is it acceptable for it to invoke dry-run or simulate logic for some phases and broadcast logic for others depending on flags?

Answer: it should broadcast or dry-run all phases in one run.

## 10. Gas estimation granularity

When you say you want gas estimation from the single Foundry entrypoint, do you need one aggregate estimate for the whole environment, or per-phase and per-chain estimates emitted from that single entrypoint?

Answer: I do not need the script itself to do anything for gas estimation. I simply want a Foundry wrapper as a single entry-point so Foundry itself can provided a holistic gas estimate.

## 11. Partial deploy support

Should the local SuperSim workflow always deploy both Ethereum and Base together, or do you want flags to deploy just one side and skip shared bridge bootstrap for iteration speed?

Answer: Yes, it should always deploy Base and Ethereum together. This is supposed to be a holistic demonstration.

## 12. ETH sweep timing

For the ETH sweep behavior, should it happen once at the very beginning of each chain-local deploy, before every broadcast phase, or only when the deployer balance falls below a threshold?

Answer: The sweep should be the first step for both chains.

## 13. Minimum Ethereum-side demo asset set

Which Ethereum-side demo assets are mandatory for the first implementation?

I understand:
- test tokens
- Uniswap V2 pools
- vaults
- Balancer V3 pools

What exact minimum set of tokens, pools, and vaults defines success?

Answer: 

Test Tokens
- Test Token A (TTA)
- Test Token B (TTB)
- Test Token C (TTC)

Uniswap V2 Pools
- TTA/TTB
- TTA/TTC
- TTB/TTC
- WETH/TTC

Vaults
- Uniswap V2 Standard Exchange Vault of TTA/TTB
- Uniswap V2 Standard Exchange Vault of TTA/TTC
- Uniswap V2 Standard Exchange Vault of TTB/TTC
- Uniswap V2 Standard Exchange Vault of WETH/TTC

Rate Providers
- Uniswap V2 Standard Exchange Vault of TTA/TTB rated as TTA
- Uniswap V2 Standard Exchange Vault of TTA/TTB rated as TTB
- Uniswap V2 Standard Exchange Vault of TTA/TTC rated as TTA
- Uniswap V2 Standard Exchange Vault of TTA/TTC rated as TTC
- Uniswap V2 Standard Exchange Vault of TTB/TTC rated as TTB
- Uniswap V2 Standard Exchange Vault of TTB/TTC rated as TTC
- Uniswap V2 Standard Exchange Vault of WETH/TTC rated as WETH
- Uniswap V2 Standard Exchange Vault of WETH/TTC rated as TTC

Balancer V3 Pools
- Balancer V3 Constant Product Pool of TTA/TTB
- Balancer V3 Constant Product Pool of TTA/TTC
- Balancer V3 Constant Product Pool of TTB/TTC
- Balancer V3 Constant Product Pool of WETH/TTC
- Balancer V3 Constant Product Pool of TTA/Uniswap V2 Standard Exchange Vault of TTA/TTB rated as TTB
- Balancer V3 Constant Product Pool of TTB/Uniswap V2 Standard Exchange Vault of TTA/TTB rated as TTA
- Balancer V3 Constant Product Pool of TTA/Uniswap V2 Standard Exchange Vault of TTA/TTC rated as TTC
- Balancer V3 Constant Product Pool of TTC/Uniswap V2 Standard Exchange Vault of TTA/TTC rated as TTA
- Balancer V3 Constant Product Pool of TTB/Uniswap V2 Standard Exchange Vault of TTB/TTC rated as TTC
- Balancer V3 Constant Product Pool of TTC/Uniswap V2 Standard Exchange Vault of TTB/TTC rated as TTB
- Balancer V3 Constant Product Pool of WETH/Uniswap V2 Standard Exchange Vault of WETH/TTC rated as TTC
- Balancer V3 Constant Product Pool of TTC/Uniswap V2 Standard Exchange Vault of WETH/TTC rated as WETH

## 14. Minimum Base-side demo asset set

Which Base-side demo assets are mandatory for the first implementation?

Same question for the Aerodrome and Base Balancer V3 side.

Answer:

Test Tokens
- Optimism Bridge Token of Test Token A (TTA)
- Optimism Bridge Token of Test Token B (TTB)
- Optimism Bridge Token of Test Token C (TTC)

Interpretation note:
- these are intentionally not the same local token contracts as Ethereum
- they are the Base-side bridge-token counterparts of the Ethereum test tokens
- Base should still have its own local pools, vaults, rate providers, and Balancer compositions built from those Base-side tokens

Aerodrome Pools
- TTA/TTB
- TTA/TTC
- TTB/TTC
- WETH/TTC

Vaults
- Aerodrome Standard Exchange Vault of TTA/TTB
- Aerodrome Standard Exchange Vault of TTA/TTC
- Aerodrome Standard Exchange Vault of TTB/TTC
- Aerodrome Standard Exchange Vault of WETH/TTC

Rate Providers
- Aerodrome Standard Exchange Vault of TTA/TTB rated as TTA
- Aerodrome Standard Exchange Vault of TTA/TTB rated as TTB
- Aerodrome Standard Exchange Vault of TTA/TTC rated as TTA
- Aerodrome Standard Exchange Vault of TTA/TTC rated as TTC
- Aerodrome Standard Exchange Vault of TTB/TTC rated as TTB
- Aerodrome Standard Exchange Vault of TTB/TTC rated as TTC
- Aerodrome Standard Exchange Vault of WETH/TTC rated as WETH
- Aerodrome Standard Exchange Vault of WETH/TTC rated as TTC

Balancer V3 Pools
- Balancer V3 Constant Product Pool of TTA/TTB
- Balancer V3 Constant Product Pool of TTA/TTC
- Balancer V3 Constant Product Pool of TTB/TTC
- Balancer V3 Constant Product Pool of WETH/TTC
- Balancer V3 Constant Product Pool of TTA/Aerodrome Standard Exchange Vault of TTA/TTB rated as TTB
- Balancer V3 Constant Product Pool of TTB/Aerodrome Standard Exchange Vault of TTA/TTB rated as TTA
- Balancer V3 Constant Product Pool of TTA/Aerodrome Standard Exchange Vault of TTA/TTC rated as TTC
- Balancer V3 Constant Product Pool of TTC/Aerodrome Standard Exchange Vault of TTA/TTC rated as TTA
- Balancer V3 Constant Product Pool of TTB/Aerodrome Standard Exchange Vault of TTB/TTC rated as TTC
- Balancer V3 Constant Product Pool of TTC/Aerodrome Standard Exchange Vault of TTB/TTC rated as TTB
- Balancer V3 Constant Product Pool of WETH/Aerodrome Standard Exchange Vault of WETH/TTC rated as TTC
- Balancer V3 Constant Product Pool of TTC/Aerodrome Standard Exchange Vault of WETH/TTC rated as WETH

## 15. Parallel versus intentionally different asset sets

Do you want the Ethereum and Base demo asset sets to be intentionally different to reflect real chain specialization, or should they be semantically parallel where possible for easier cross-chain UI testing?

Answer: The demo assets are intentionally different to reflect real chain specialization.

## 16. Balancer V3 export scope

For the Balancer V3 side, do you want only the specific pool types already used in the current demo flows, or should the new scripts also export the broader Balancer-related tokenlists that already exist in the frontend buckets, such as const-prod and vault-token pool lists?

Answer: Export the broader Balancer related asset lists.

## 17. Legacy filename transition strategy

Should the new deployment flows continue to emit the legacy tokenlist filenames alongside the new registry-driven structure during a transition period, or should the UI migration assume a hard cutover?

Answer: Assume a hard cutover.

## 18. Wagmi generated output shape

For `frontend/wagmi.config.ts`, do you want a single generated `app/generated.ts` that contains addresses for all supported environments and chains, or separate generated outputs per environment with a wrapper selecting one?

Answer: I want a single `app/generated.ts`.

Decision:
- keep a single generated wagmi output file
- do not rely on wagmi deployment mapping as the source of environment-specific addresses when multiple environments share the same chain IDs

Implementation note:
- use wagmi generation primarily for ABIs, typed hooks, and contract wrappers
- resolve contract addresses at runtime from the generated frontend registry using the selected environment and wallet `chainId`

## 19. Wagmi contract identity model

If the same contract ABI is deployed to multiple environments and chains, do you want the wagmi config to generate a single contract definition keyed by chain IDs, or multiple logical entries separated by environment as well?

Answer: Generate a single contract definition keyed by chain IDs.

Implementation note:
- environment-specific address selection should happen outside wagmi generation, in the frontend registry/runtime resolver layer
- wagmi should stay responsible for ABI-driven typing and hook generation rather than environment resolution

## 20. UI behavior for chain-incompatible menus

Should pages like the DETF page hide chain-incompatible menus entirely, or show them disabled with explanatory copy when the connected wallet is on the wrong chain?

Answer: Yes, hide chain incompatible menu entries.

## 21. UI behavior when wallet is disconnected

For the frontend default behavior, if the wallet is disconnected, should the UI fall back to a default environment-plus-chain bundle, or should most menus remain empty until a chain is known?

Answer: Simply gate the pages to indicate the user needs to connect their wallet to see the page.

## 22. Missing bundle behavior

What should happen if the wallet chain is supported by wagmi transport but there is no matching deployment bundle in the selected environment?

Options I see:
- hard error
- soft empty-state
- fallback to another environment

Answer: Implement soft empty-state

## 23. Legacy environment preservation

Do you want `anvil_base_main` and `anvil_sepolia` preserved as explicit compatibility environments in the new registry, or do you want them treated as deprecated and excluded from new code paths except where unavoidable?

Answer: No, we do not need `anvil_base_main` and `anvil_sepolia`, we will be deprecating those.

## 24. Scope of public Sepolia sibling entrypoints

For the public Sepolia sibling entrypoints, do you want them implemented now as part of the same change set, or is it acceptable to define the architecture and leave their concrete scripts for a second pass after local SuperSim is working?

Answer: Implement the public deployment after the SuperSim deployment is working.

## 25. UI validation bar

Should the top-level prompt treat bridge UI validation as requiring an actual end-to-end user flow in the app, or is it enough for the deployment artifacts and contract calls to be wired so the UI can theoretically exercise the flow?

Answer: It is enough to wire the deployment artifacts and contract calls are wired. We will update the UI after the SuperSim deployment is working.