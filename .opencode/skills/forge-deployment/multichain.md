# Multi-Chain Deployments

Patterns for deploying contracts across multiple chains with Foundry.

## Configuration

### foundry.toml

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]

[rpc_endpoints]
mainnet = "${MAINNET_RPC_URL}"
arbitrum = "${ARBITRUM_RPC_URL}"
optimism = "${OPTIMISM_RPC_URL}"
base = "${BASE_RPC_URL}"
polygon = "${POLYGON_RPC_URL}"
sepolia = "${SEPOLIA_RPC_URL}"
arbitrum_sepolia = "${ARBITRUM_SEPOLIA_RPC_URL}"

[etherscan]
mainnet = { key = "${ETHERSCAN_API_KEY}" }
arbitrum = { key = "${ARBISCAN_API_KEY}" }
optimism = { key = "${OPTIMISM_ETHERSCAN_API_KEY}" }
base = { key = "${BASESCAN_API_KEY}" }
polygon = { key = "${POLYGONSCAN_API_KEY}" }
sepolia = { key = "${ETHERSCAN_API_KEY}" }
arbitrum_sepolia = { key = "${ARBISCAN_API_KEY}" }
```

## Basic Multi-Chain Script

```solidity
// script/MultiChainDeploy.s.sol
contract MultiChainDeploy is Script {
    string[] public chains = ["mainnet", "arbitrum", "base"];

    function run() public {
        for (uint256 i = 0; i < chains.length; i++) {
            deployToChain(chains[i]);
        }
    }

    function deployToChain(string memory chain) internal {
        console.log("Deploying to:", chain);

        // Create and select fork
        vm.createSelectFork(chain);

        // Load deployer key
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerKey);

        MyContract myContract = new MyContract(getConfig(chain));

        vm.stopBroadcast();

        console.log("  Deployed to:", address(myContract));
    }

    function getConfig(string memory chain) internal pure returns (Config memory) {
        bytes32 chainHash = keccak256(bytes(chain));

        if (chainHash == keccak256("mainnet")) {
            return Config({oracle: MAINNET_ORACLE, fee: 100});
        } else if (chainHash == keccak256("arbitrum")) {
            return Config({oracle: ARBITRUM_ORACLE, fee: 50});
        } else if (chainHash == keccak256("base")) {
            return Config({oracle: BASE_ORACLE, fee: 75});
        }

        revert("Unknown chain");
    }
}
```

## Deterministic Multi-Chain Deployment

Deploy to the same address across all chains using CREATE2:

```solidity
contract DeterministicMultiChainDeploy is Script {
    // Same salt produces same address across chains
    bytes32 public constant SALT = keccak256("myprotocol-v1");

    // CREATE2 deployer (same on all chains)
    address public constant CREATE2_FACTORY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    function run() public {
        string[] memory chains = new string[](3);
        chains[0] = "mainnet";
        chains[1] = "arbitrum";
        chains[2] = "base";

        // Compute expected address (same for all chains)
        address expectedAddress = computeCreate2Address();
        console.log("Expected address on all chains:", expectedAddress);

        for (uint256 i = 0; i < chains.length; i++) {
            deployToChain(chains[i], expectedAddress);
        }
    }

    function deployToChain(string memory chain, address expectedAddr) internal {
        vm.createSelectFork(chain);

        // Check if already deployed
        if (expectedAddr.code.length > 0) {
            console.log(chain, ": Already deployed");
            return;
        }

        vm.startBroadcast();

        // Deploy using CREATE2
        MyContract deployed = new MyContract{salt: SALT}();

        require(address(deployed) == expectedAddr, "Address mismatch");

        vm.stopBroadcast();

        console.log(chain, ": Deployed to", address(deployed));
    }

    function computeCreate2Address() public view returns (address) {
        bytes32 initCodeHash = keccak256(
            abi.encodePacked(
                type(MyContract).creationCode
            )
        );

        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this), // Deployer address
            SALT,
            initCodeHash
        )))));
    }
}
```

## Chain-Specific Configuration

### JSON Config Files

```
config/
├── mainnet.json
├── arbitrum.json
└── base.json
```

```json
// config/mainnet.json
{
  "oracle": "0x...",
  "fee": 100,
  "treasury": "0x...",
  "admins": ["0x...", "0x..."]
}
```

```solidity
contract ConfigurableMultiChainDeploy is Script {
    function deployToChain(string memory chain) internal {
        vm.createSelectFork(chain);

        // Load chain-specific config
        string memory configPath = string.concat("config/", chain, ".json");
        string memory config = vm.readFile(configPath);

        address oracle = vm.parseJsonAddress(config, ".oracle");
        uint256 fee = vm.parseJsonUint(config, ".fee");
        address treasury = vm.parseJsonAddress(config, ".treasury");
        address[] memory admins = vm.parseJsonAddressArray(config, ".admins");

        vm.startBroadcast();

        MyContract myContract = new MyContract(oracle, fee, treasury);

        for (uint256 i = 0; i < admins.length; i++) {
            myContract.grantRole(ADMIN_ROLE, admins[i]);
        }

        vm.stopBroadcast();
    }
}
```

## Parallel Deployment Script

Deploy to multiple chains in parallel using shell:

```bash
#!/bin/bash
# deploy-all.sh

CHAINS=("mainnet" "arbitrum" "base" "optimism")

for chain in "${CHAINS[@]}"; do
    echo "Deploying to $chain..."
    forge script script/Deploy.s.sol \
        --rpc-url $chain \
        --broadcast \
        --verify &
done

wait
echo "All deployments complete"
```

## Cross-Chain Deployment Verification

```solidity
contract VerifyMultiChainDeploy is Script {
    address public constant EXPECTED_ADDRESS = 0x...;

    string[] public chains = ["mainnet", "arbitrum", "base"];

    function run() public view {
        for (uint256 i = 0; i < chains.length; i++) {
            verifyChain(chains[i]);
        }
    }

    function verifyChain(string memory chain) internal view {
        vm.createSelectFork(chain);

        require(
            EXPECTED_ADDRESS.code.length > 0,
            string.concat("Not deployed on ", chain)
        );

        MyContract deployed = MyContract(EXPECTED_ADDRESS);

        // Verify configuration
        require(
            deployed.owner() == EXPECTED_OWNER,
            string.concat("Wrong owner on ", chain)
        );

        console.log(chain, ": Verified");
    }
}
```

## Saving Multi-Chain Deployments

```solidity
contract MultiChainDeploy is Script {
    struct Deployment {
        uint256 chainId;
        address contractAddress;
        uint256 blockNumber;
    }

    Deployment[] public deployments;

    function run() public {
        deployToChain("mainnet");
        deployToChain("arbitrum");
        deployToChain("base");

        saveDeployments();
    }

    function deployToChain(string memory chain) internal {
        vm.createSelectFork(chain);

        vm.startBroadcast();
        MyContract deployed = new MyContract();
        vm.stopBroadcast();

        deployments.push(Deployment({
            chainId: block.chainid,
            contractAddress: address(deployed),
            blockNumber: block.number
        }));
    }

    function saveDeployments() internal {
        string memory json = "deployments";

        for (uint256 i = 0; i < deployments.length; i++) {
            string memory chainKey = vm.toString(deployments[i].chainId);
            vm.serializeAddress(chainKey, "address", deployments[i].contractAddress);
            string memory chainJson = vm.serializeUint(chainKey, "blockNumber", deployments[i].blockNumber);

            vm.serializeString(json, chainKey, chainJson);
        }

        string memory output = vm.serializeUint(json, "timestamp", block.timestamp);
        vm.writeJson(output, "./deployments/multichain.json");
    }
}
```

## Running Multi-Chain Scripts

```bash
# Deploy to all chains
forge script script/MultiChainDeploy.s.sol --broadcast

# Deploy to specific chains (modify script or use env vars)
CHAINS="mainnet,arbitrum" forge script script/MultiChainDeploy.s.sol --broadcast

# Verify all deployments
forge script script/MultiChainDeploy.s.sol \
    --broadcast \
    --verify
```

## Best Practices

1. **Use deterministic deployments** for consistent addresses across chains
2. **Store chain-specific config** in separate files
3. **Verify deployments** match expected addresses and configuration
4. **Test on testnets first** (Sepolia, Arbitrum Sepolia, Base Sepolia)
5. **Save deployment records** with chain IDs and block numbers
6. **Handle existing deployments** gracefully (skip if already deployed)
