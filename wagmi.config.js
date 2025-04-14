"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const cli_1 = require("@wagmi/cli");
const plugins_1 = require("@wagmi/cli/plugins");
const chains_1 = require("wagmi/chains");
// Import deployment addresses from addresses.json
const addresses = require('./addresses.json');
exports.default = (0, cli_1.defineConfig)({
    out: 'src/generated.ts', // Output file for hooks
    contracts: [
        // ERC20 Tokens (all use ERC20Token ABI from Foundry)
        {
            name: 'TokenA',
            contractName: 'ERC20Token', // Explicitly map to ERC20Token ABI
            address: {
                [chains_1.sepolia.id]: addresses.TokenA,
            },
        },
        {
            name: 'TokenB',
            contractName: 'ERC20Token', // Explicitly map to ERC20Token ABI
            address: {
                [chains_1.sepolia.id]: addresses.TokenB,
            },
        },
        {
            name: 'TokenC',
            contractName: 'ERC20Token', // Explicitly map to ERC20Token ABI
            address: {
                [chains_1.sepolia.id]: addresses.TokenC,
            },
        },
        // ERC4626 Vaults (all use ERC4626Vault ABI from Foundry)
        {
            name: 'VaultA',
            contractName: 'ERC4626Vault', // Explicitly map to ERC4626Vault ABI
            address: {
                [chains_1.sepolia.id]: addresses.VaultA,
            },
        },
        {
            name: 'VaultB',
            contractName: 'ERC4626Vault', // Explicitly map to ERC4626Vault ABI
            address: {
                [chains_1.sepolia.id]: addresses.VaultB,
            },
        },
        {
            name: 'VaultC',
            contractName: 'ERC4626Vault', // Explicitly map to ERC4626Vault ABI
            address: {
                [chains_1.sepolia.id]: addresses.VaultC,
            },
        },
    ],
    plugins: [
        (0, plugins_1.foundry)({
            project: '../my-contract', // Path to Foundry project (adjust as needed)
            include: ['ERC20Token.sol', 'ERC4626Vault.sol'], // Load ABIs for these contracts
        }),
        (0, plugins_1.react)(), // Generates hooks like useReadTokenABalance, useWriteVaultADeposit
    ],
});
