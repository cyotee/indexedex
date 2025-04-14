import { defineConfig } from '@wagmi/cli'
import { foundry, react } from '@wagmi/cli/plugins'
import { sepolia } from 'wagmi/chains'

// Import deployment addresses from addresses.json
const addresses = require('./addresses.json')

export default defineConfig({
  out: 'src/generated.ts', // Output file for hooks
  contracts: [
    // ERC20 Tokens (all use ERC20Token ABI from Foundry)
    {
      name: 'TokenA',
      contractName: 'ERC20Token', // Explicitly map to ERC20Token ABI
      address: {
        [sepolia.id]: addresses.TokenA,
      },
    },
    {
      name: 'TokenB',
      contractName: 'ERC20Token', // Explicitly map to ERC20Token ABI
      address: {
        [sepolia.id]: addresses.TokenB,
      },
    },
    {
      name: 'TokenC',
      contractName: 'ERC20Token', // Explicitly map to ERC20Token ABI
      address: {
        [sepolia.id]: addresses.TokenC,
      },
    },
    // ERC4626 Vaults (all use ERC4626Vault ABI from Foundry)
    {
      name: 'VaultA',
      contractName: 'ERC4626Vault', // Explicitly map to ERC4626Vault ABI
      address: {
        [sepolia.id]: addresses.VaultA,
      },
    },
    {
      name: 'VaultB',
      contractName: 'ERC4626Vault', // Explicitly map to ERC4626Vault ABI
      address: {
        [sepolia.id]: addresses.VaultB,
      },
    },
    {
      name: 'VaultC',
      contractName: 'ERC4626Vault', // Explicitly map to ERC4626Vault ABI
      address: {
        [sepolia.id]: addresses.VaultC,
      },
    },
  ],
  plugins: [
    foundry({
      project: '../my-contract', // Path to Foundry project (adjust as needed)
      include: ['ERC20Token.sol', 'ERC4626Vault.sol'], // Load ABIs for these contracts
    }),
    react(), // Generates hooks like useReadTokenABalance, useWriteVaultADeposit
  ],
})