import { defineConfig } from '@wagmi/cli'
import { foundry, react } from '@wagmi/cli/plugins'
import { sepolia } from 'wagmi/chains'

// Import deployment addresses from addresses.json
const addresses = require('./addresses.json')

export default defineConfig({
  out: 'src/generated.ts', // Output file for hooks
  contracts: [
    // ERC20 Tokens (standard ERC20 ABI)
    {
      name: 'TokenA',
      contractName: 'ERC20Token', // Maps to out/ERC20Token.sol/ERC20Token.json
      address: {
        [sepolia.id]: addresses.TokenA, // Same proxy address
      },
    },
    {
      name: 'TokenAMintable',
      contractName: 'ERC20MintableToken', // Maps to out/ERC20MintableToken.sol/ERC20MintableToken.json
      address: {
        [sepolia.id]: addresses.TokenA, // Same proxy address
      },
    },
    {
      name: 'TokenB',
      contractName: 'ERC20Token',
      address: {
        [sepolia.id]: addresses.TokenB,
      },
    },
    {
      name: 'TokenBMintable',
      contractName: 'ERC20MintableToken',
      address: {
        [sepolia.id]: addresses.TokenB,
      },
    },
    {
      name: 'TokenC',
      contractName: 'ERC20Token',
      address: {
        [sepolia.id]: addresses.TokenC,
      },
    },
    {
      name: 'TokenCMintable',
      contractName: 'ERC20MintableToken',
      address: {
        [sepolia.id]: addresses.TokenC,
      },
    },
    // ERC4626 Vaults (single ABI per vault)
    {
      name: 'VaultA',
      contractName: 'ERC4626Vault', // Maps to out/ERC4626Vault.sol/ERC4626Vault.json
      address: {
        [sepolia.id]: addresses.VaultA,
      },
    },
    {
      name: 'VaultB',
      contractName: 'ERC4626Vault',
      address: {
        [sepolia.id]: addresses.VaultB,
      },
    },
    {
      name: 'VaultC',
      contractName: 'ERC4626Vault',
      address: {
        [sepolia.id]: addresses.VaultC,
      },
    },
  ],
  plugins: [
    foundry({
      project: '../my-contract', // Path to Foundry project (adjust as needed)
      include: ['ERC20Token.sol', 'ERC20MintableToken.sol', 'ERC4626Vault.sol'], // Load ABIs from out/
    }),
    react(), // Generates hooks like useReadTokenABalance, useWriteTokenAMintableMint, useWriteVaultADeposit
  ],
})