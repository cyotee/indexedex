import hardhatEthers from "@nomicfoundation/hardhat-ethers";
import hardhatEthersChaiMatchers from "@nomicfoundation/hardhat-ethers-chai-matchers";
import hardhatFoundry from "@nomicfoundation/hardhat-foundry";
import hardhatMocha from "@nomicfoundation/hardhat-mocha";
import hardhatToolboxViem from "@nomicfoundation/hardhat-toolbox-viem";
import hardhatTypechain from "@nomicfoundation/hardhat-typechain";
import { configVariable, defineConfig } from "hardhat/config";
import { definePlugin } from "hardhat/plugins";
import { join } from "node:path";

const accounts =
  process.env.PRIVATE_KEY === undefined ? [] : [configVariable("PRIVATE_KEY")];

const localNetwork = {
  type: "edr-simulated",
  chainType: "l1",
  hardfork: "osaka",
  allowUnlimitedContractSize: true,
  gas: "auto",
} as const;

const projectImports = definePlugin({
  id: "indexedex-project-imports",
  hookHandlers: {
    solidity: async () => ({
      default: async () => ({
        async readNpmPackageRemappings(context, name, version, packagePath, next) {
          const remappings = await next(context, name, version, packagePath);
          if (packagePath !== context.config.paths.root) return remappings;
          // Foundry already resolves these root-relative imports. Keep this
          // identity mapping local to Hardhat rather than changing Foundry metadata.
          return [
            ...remappings,
            {
              remappings: [
                "contracts/=contracts/",
                "scripts/=scripts/",
                "test/=test/",
                "lib/=lib/",
              ],
              source: join(packagePath, "hardhat.config.ts"),
            },
          ];
        },
      }),
    }),
  },
});

export default defineConfig({
  // Keep the archived config's Viem Ignition adapter. Registering the Ethers
  // toolbox as well would register a second, incompatible Ignition adapter.
  plugins: [
    hardhatToolboxViem,
    hardhatMocha,
    hardhatEthers,
    hardhatEthersChaiMatchers,
    hardhatTypechain,
    hardhatFoundry,
    projectImports,
  ],
  solidity: {
    // Match the effective default profile in foundry.toml.
    version: "0.8.35",
    settings: {
      evmVersion: "osaka",
      optimizer: { enabled: true, runs: 1 },
      viaIR: false,
    },
  },
  paths: {
    sources: {
      solidity: ["./contracts", "./lib/crane/contracts/test/stubs/lock"],
    },
    tests: {
      mocha: "./test/hard-hat/spec",
      nodejs: "./test/hard-hat/node",
      solidity: "./test/hard-hat",
    },
    cache: "./cache",
    artifacts: "./artifacts",
  },
  typechain: { outDir: "./typechain" },
  networks: {
    default: localNetwork,
    node: localNetwork,
    hardhat: localNetwork,
    sepolia: {
      type: "http",
      url: configVariable("SEPOLIA_RPC_URL"),
      accounts,
    },
    tanenbaum: {
      type: "http",
      url: configVariable("TROLLUX_RPC_URL"),
      accounts,
    },
    localhost: {
      type: "http",
      url: "http://localhost:8545",
      accounts,
    },
  },
});
