import { defineConfig } from '@wagmi/cli'
import { foundry as foundryPlugin, react } from '@wagmi/cli/plugins'
import { baseSepolia, foundry as foundryChain, sepolia } from 'wagmi/chains'

// Import deployment addresses from committed artifacts
const platformSepolia = require('./app/addresses/sepolia/base_deployments.json')
const platformPublicEthereum = require('./app/addresses/public_sepolia/ethereum/base_deployments.json')
const platformPublicBase = require('./app/addresses/public_sepolia/base/base_deployments.json')
const platformSupersimEthereum = require('./app/addresses/supersim_sepolia/ethereum/base_deployments.json')
const platformSupersimBase = require('./app/addresses/supersim_sepolia/base/base_deployments.json')

const nonZeroAddress = (address?: string): string | undefined => {
    if (!address) return undefined
    if (!/^0x[a-fA-F0-9]{40}$/.test(address)) return undefined
    if (/^0x0{40}$/i.test(address)) return undefined
    return address
}

const DUMMY_NON_ZERO_ADDRESS = '0x0000000000000000000000000000000000000001' as const

const batchRouterSepolia = (
    nonZeroAddress(platformSepolia.balancerV3StandardExchangeBatchRouter) ??
    nonZeroAddress(platformSepolia.balancerV3StandardExchangeRouter) ??
    nonZeroAddress(platformPublicEthereum.balancerV3StandardExchangeRouter) ??
    nonZeroAddress(platformSupersimEthereum.balancerV3StandardExchangeRouter) ??
    DUMMY_NON_ZERO_ADDRESS
) as `0x${string}`

const batchRouterSupersimEthereum = (
    nonZeroAddress(platformSupersimEthereum.balancerV3StandardExchangeBatchRouter) ??
    nonZeroAddress(platformSupersimEthereum.balancerV3StandardExchangeRouter) ??
    nonZeroAddress(platformSepolia.balancerV3StandardExchangeRouter) ??
    DUMMY_NON_ZERO_ADDRESS
) as `0x${string}`

const batchRouterBaseSepolia = (
    nonZeroAddress(platformPublicBase.balancerV3StandardExchangeBatchRouter) ??
    nonZeroAddress(platformPublicBase.balancerV3StandardExchangeRouter) ??
    nonZeroAddress(platformSupersimBase.balancerV3StandardExchangeBatchRouter) ??
    nonZeroAddress(platformSupersimBase.balancerV3StandardExchangeRouter) ??
    nonZeroAddress(platformSupersimEthereum.balancerV3StandardExchangeRouter) ??
    DUMMY_NON_ZERO_ADDRESS
) as `0x${string}`

export default defineConfig({
    out: 'app/generated.ts',
    plugins: [
        foundryPlugin({
            project: '../', // Points to Foundry project root with out/
            include: [
                'WETH9.sol/*.json',
                'BetterPermit2.sol/BetterPermit2.json',
                'DiamondPackageCallBackFactory.sol/DiamondPackageCallBackFactory.json',
                'VaultRegistryDeploymentFacet.sol/VaultRegistryDeploymentFacet.json',

                // Uniswap V2 package
                'UniswapV2StandardExchangeDFPkg.sol/UniswapV2StandardExchangeDFPkg.json',

                // Balancer router facets (ABI used against the router proxy address)
                'BalancerV3StandardExchangeRouterExactInQueryFacet.sol/BalancerV3StandardExchangeRouterExactInQueryFacet.json',
                'BalancerV3StandardExchangeRouterExactInSwapFacet.sol/BalancerV3StandardExchangeRouterExactInSwapFacet.json',
                'BalancerV3StandardExchangeRouterExactOutQueryFacet.sol/BalancerV3StandardExchangeRouterExactOutQueryFacet.json',
                'BalancerV3StandardExchangeRouterExactOutSwapFacet.sol/BalancerV3StandardExchangeRouterExactOutSwapFacet.json',

                'BalancerV3StandardExchangeBatchRouterExactInFacet.sol/BalancerV3StandardExchangeBatchRouterExactInFacet.json',
                'BalancerV3StandardExchangeBatchRouterExactOutFacet.sol/BalancerV3StandardExchangeBatchRouterExactOutFacet.json',



                // Balancer constant product pool vault package
                'BalancerV3ConstantProductPoolStandardVaultPkg.sol/BalancerV3ConstantProductPoolStandardVaultPkg.json',

                // Balancer router TARGET contracts (contain the actual implementation with permit functions)
                'BalancerV3StandardExchangeRouterExactInSwapTarget.sol/BalancerV3StandardExchangeRouterExactInSwapTarget.json',
                'BalancerV3StandardExchangeRouterExactOutSwapTarget.sol/BalancerV3StandardExchangeRouterExactOutSwapTarget.json',
            ],
            deployments: {
                WETH9: {
                    [sepolia.id]: platformSepolia.weth9,
                    [foundryChain.id]: platformSupersimEthereum.weth9,
                    [baseSepolia.id]: platformPublicBase.weth9,
                },
                BetterPermit2: {
                    [sepolia.id]: platformSepolia.permit2,
                    [foundryChain.id]: platformSupersimEthereum.permit2,
                    [baseSepolia.id]: platformPublicBase.permit2,
                },
                DiamondPackageCallBackFactory: {
                    [sepolia.id]: platformSepolia.craneDiamondFactory,
                    [foundryChain.id]: platformSupersimEthereum.craneDiamondFactory,
                    [baseSepolia.id]: platformPublicBase.craneDiamondFactory,
                },
                VaultRegistryDeploymentFacet: {
                    [sepolia.id]: platformSepolia.vaultRegistry,
                    [foundryChain.id]: platformSupersimEthereum.vaultRegistry,
                    [baseSepolia.id]: platformPublicBase.vaultRegistry,
                },

                UniswapV2StandardExchangeDFPkg: {
                    // Key name differs in artifacts, but the address is the DFPkg.
                    [sepolia.id]: platformSepolia.uniswapV2StandardStrategyVaultPkg,
                    [foundryChain.id]: platformSupersimEthereum.uniswapV2StandardStrategyVaultPkg,
                    [baseSepolia.id]: platformPublicBase.uniswapV2StandardStrategyVaultPkg,
                },
                BalancerV3ConstantProductPoolStandardVaultPkg: {
                    [sepolia.id]: platformSepolia.balancerV3ConstantProductPoolStandardVaultPkg,
                    [foundryChain.id]: platformSupersimEthereum.balancerV3ConstantProductPoolStandardVaultPkg,
                    [baseSepolia.id]: platformPublicBase.balancerV3ConstantProductPoolStandardVaultPkg,
                },

                // Router facets all point at the router proxy address.
                BalancerV3StandardExchangeRouterExactInQueryFacet: {
                    [sepolia.id]: platformSepolia.balancerV3StandardExchangeRouter,
                    [foundryChain.id]: platformSupersimEthereum.balancerV3StandardExchangeRouter,
                    [baseSepolia.id]: platformPublicBase.balancerV3StandardExchangeRouter,
                },
                BalancerV3StandardExchangeRouterExactInSwapFacet: {
                    [sepolia.id]: platformSepolia.balancerV3StandardExchangeRouter,
                    [foundryChain.id]: platformSupersimEthereum.balancerV3StandardExchangeRouter,
                    [baseSepolia.id]: platformPublicBase.balancerV3StandardExchangeRouter,
                },
                BalancerV3StandardExchangeRouterExactOutQueryFacet: {
                    [sepolia.id]: platformSepolia.balancerV3StandardExchangeRouter,
                    [foundryChain.id]: platformSupersimEthereum.balancerV3StandardExchangeRouter,
                    [baseSepolia.id]: platformPublicBase.balancerV3StandardExchangeRouter,
                },
                BalancerV3StandardExchangeRouterExactOutSwapFacet: {
                    [sepolia.id]: platformSepolia.balancerV3StandardExchangeRouter,
                    [foundryChain.id]: platformSupersimEthereum.balancerV3StandardExchangeRouter,
                    [baseSepolia.id]: platformPublicBase.balancerV3StandardExchangeRouter,
                },

                BalancerV3StandardExchangeBatchRouterExactInFacet: {
                    [sepolia.id]: batchRouterSepolia,
                    [foundryChain.id]: batchRouterSupersimEthereum,
                    [baseSepolia.id]: batchRouterBaseSepolia,
                },
                BalancerV3StandardExchangeBatchRouterExactOutFacet: {
                    [sepolia.id]: batchRouterSepolia,
                    [foundryChain.id]: batchRouterSupersimEthereum,
                    [baseSepolia.id]: batchRouterBaseSepolia,
                },


                // Router TARGET contracts - point to same router proxy address as facets
                BalancerV3StandardExchangeRouterExactInSwapTarget: {
                    [sepolia.id]: platformSepolia.balancerV3StandardExchangeRouter,
                    [foundryChain.id]: platformSupersimEthereum.balancerV3StandardExchangeRouter,
                    [baseSepolia.id]: platformPublicBase.balancerV3StandardExchangeRouter,
                },
                BalancerV3StandardExchangeRouterExactOutSwapTarget: {
                    [sepolia.id]: platformSepolia.balancerV3StandardExchangeRouter,
                    [foundryChain.id]: platformSupersimEthereum.balancerV3StandardExchangeRouter,
                    [baseSepolia.id]: platformPublicBase.balancerV3StandardExchangeRouter,
                },
            },
        }),
        react(),
    ],
})
