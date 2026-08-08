"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const cli_1 = require("@wagmi/cli");
const plugins_1 = require("@wagmi/cli/plugins");
const chains_1 = require("@wagmi/chains");
// Import deployment addresses from committed artifacts
const platformSepolia = require('./app/addresses/sepolia/base_deployments.json');
const platformSupersimEthereum = require('./app/addresses/supersim_sepolia/ethereum/base_deployments.json');
const platformSupersimBase = require('./app/addresses/supersim_sepolia/base/base_deployments.json');
const nonZeroAddress = (address) => {
    if (!address)
        return undefined;
    if (!/^0x[a-fA-F0-9]{40}$/.test(address))
        return undefined;
    if (/^0x0{40}$/i.test(address))
        return undefined;
    return address;
};
const DUMMY_NON_ZERO_ADDRESS = '0x0000000000000000000000000000000000000001';
const batchRouterSepolia = (nonZeroAddress(platformSepolia.balancerV3StandardExchangeBatchRouter) ??
    nonZeroAddress(platformSepolia.balancerV3StandardExchangeRouter) ??
    nonZeroAddress(platformSupersimEthereum.balancerV3StandardExchangeRouter) ??
    DUMMY_NON_ZERO_ADDRESS);
const batchRouterSupersimEthereum = (nonZeroAddress(platformSupersimEthereum.balancerV3StandardExchangeBatchRouter) ??
    nonZeroAddress(platformSupersimEthereum.balancerV3StandardExchangeRouter) ??
    nonZeroAddress(platformSepolia.balancerV3StandardExchangeRouter) ??
    DUMMY_NON_ZERO_ADDRESS);
const batchRouterBaseSepolia = (nonZeroAddress(platformSupersimBase.balancerV3StandardExchangeBatchRouter) ??
    nonZeroAddress(platformSupersimBase.balancerV3StandardExchangeRouter) ??
    nonZeroAddress(platformSupersimEthereum.balancerV3StandardExchangeRouter) ??
    DUMMY_NON_ZERO_ADDRESS);
exports.default = (0, cli_1.defineConfig)({
    out: 'app/generated.ts',
    plugins: [
        (0, plugins_1.foundry)({
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
                    [chains_1.sepolia.id]: platformSepolia.weth9,
                    [chains_1.foundry.id]: platformSupersimEthereum.weth9,
                    [chains_1.baseSepolia.id]: platformSupersimBase.weth9,
                },
                BetterPermit2: {
                    [chains_1.sepolia.id]: platformSepolia.permit2,
                    [chains_1.foundry.id]: platformSupersimEthereum.permit2,
                    [chains_1.baseSepolia.id]: platformSupersimBase.permit2,
                },
                DiamondPackageCallBackFactory: {
                    [chains_1.sepolia.id]: platformSepolia.craneDiamondFactory,
                    [chains_1.foundry.id]: platformSupersimEthereum.craneDiamondFactory,
                    [chains_1.baseSepolia.id]: platformSupersimBase.craneDiamondFactory,
                },
                VaultRegistryDeploymentFacet: {
                    [chains_1.sepolia.id]: platformSepolia.vaultRegistry,
                    [chains_1.foundry.id]: platformSupersimEthereum.vaultRegistry,
                    [chains_1.baseSepolia.id]: platformSupersimBase.vaultRegistry,
                },
                UniswapV2StandardExchangeDFPkg: {
                    // Key name differs in artifacts, but the address is the DFPkg.
                    [chains_1.sepolia.id]: platformSepolia.uniswapV2StandardStrategyVaultPkg,
                    [chains_1.foundry.id]: platformSupersimEthereum.uniswapV2StandardStrategyVaultPkg,
                    [chains_1.baseSepolia.id]: platformSupersimBase.uniswapV2StandardStrategyVaultPkg,
                },
                BalancerV3ConstantProductPoolStandardVaultPkg: {
                    [chains_1.sepolia.id]: platformSepolia.balancerV3ConstantProductPoolStandardVaultPkg,
                    [chains_1.foundry.id]: platformSupersimEthereum.balancerV3ConstantProductPoolStandardVaultPkg,
                    [chains_1.baseSepolia.id]: platformSupersimBase.balancerV3ConstantProductPoolStandardVaultPkg,
                },
                // Router facets all point at the router proxy address.
                BalancerV3StandardExchangeRouterExactInQueryFacet: {
                    [chains_1.sepolia.id]: platformSepolia.balancerV3StandardExchangeRouter,
                    [chains_1.foundry.id]: platformSupersimEthereum.balancerV3StandardExchangeRouter,
                    [chains_1.baseSepolia.id]: platformSupersimBase.balancerV3StandardExchangeRouter,
                },
                BalancerV3StandardExchangeRouterExactInSwapFacet: {
                    [chains_1.sepolia.id]: platformSepolia.balancerV3StandardExchangeRouter,
                    [chains_1.foundry.id]: platformSupersimEthereum.balancerV3StandardExchangeRouter,
                    [chains_1.baseSepolia.id]: platformSupersimBase.balancerV3StandardExchangeRouter,
                },
                BalancerV3StandardExchangeRouterExactOutQueryFacet: {
                    [chains_1.sepolia.id]: platformSepolia.balancerV3StandardExchangeRouter,
                    [chains_1.foundry.id]: platformSupersimEthereum.balancerV3StandardExchangeRouter,
                    [chains_1.baseSepolia.id]: platformSupersimBase.balancerV3StandardExchangeRouter,
                },
                BalancerV3StandardExchangeRouterExactOutSwapFacet: {
                    [chains_1.sepolia.id]: platformSepolia.balancerV3StandardExchangeRouter,
                    [chains_1.foundry.id]: platformSupersimEthereum.balancerV3StandardExchangeRouter,
                    [chains_1.baseSepolia.id]: platformSupersimBase.balancerV3StandardExchangeRouter,
                },
                BalancerV3StandardExchangeBatchRouterExactInFacet: {
                    [chains_1.sepolia.id]: batchRouterSepolia,
                    [chains_1.foundry.id]: batchRouterSupersimEthereum,
                    [chains_1.baseSepolia.id]: batchRouterBaseSepolia,
                },
                BalancerV3StandardExchangeBatchRouterExactOutFacet: {
                    [chains_1.sepolia.id]: batchRouterSepolia,
                    [chains_1.foundry.id]: batchRouterSupersimEthereum,
                    [chains_1.baseSepolia.id]: batchRouterBaseSepolia,
                },
                // Router TARGET contracts - point to same router proxy address as facets
                BalancerV3StandardExchangeRouterExactInSwapTarget: {
                    [chains_1.sepolia.id]: platformSepolia.balancerV3StandardExchangeRouter,
                    [chains_1.foundry.id]: platformSupersimEthereum.balancerV3StandardExchangeRouter,
                    [chains_1.baseSepolia.id]: platformSupersimBase.balancerV3StandardExchangeRouter,
                },
                BalancerV3StandardExchangeRouterExactOutSwapTarget: {
                    [chains_1.sepolia.id]: platformSepolia.balancerV3StandardExchangeRouter,
                    [chains_1.foundry.id]: platformSupersimEthereum.balancerV3StandardExchangeRouter,
                    [chains_1.baseSepolia.id]: platformSupersimBase.balancerV3StandardExchangeRouter,
                },
            },
        }),
        (0, plugins_1.react)(),
    ],
});
