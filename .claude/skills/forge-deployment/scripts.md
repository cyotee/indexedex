# Forge Deployment Scripts

Solidity-based deployment scripts using forge-std's Script contract.

## Script Structure

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {MyContract} from "../src/MyContract.sol";
import {Token} from "../src/Token.sol";

contract DeployScript is Script {
    // Configuration
    address public constant OWNER = 0x...;
    uint256 public constant INITIAL_SUPPLY = 1_000_000e18;

    // Deployed contracts
    MyContract public myContract;
    Token public token;

    function run() public {
        // Load private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy contracts
        token = new Token("MyToken", "MTK", INITIAL_SUPPLY);
        myContract = new MyContract(address(token), OWNER);

        // Configure contracts
        token.transfer(address(myContract), INITIAL_SUPPLY / 2);

        // Stop broadcasting
        vm.stopBroadcast();

        // Log results
        console.log("Token deployed to:", address(token));
        console.log("MyContract deployed to:", address(myContract));
    }
}
```

## Environment Variables

### Reading Environment

```solidity
function run() public {
    // Required (reverts if missing)
    uint256 privateKey = vm.envUint("PRIVATE_KEY");
    address owner = vm.envAddress("OWNER_ADDRESS");
    string memory rpcUrl = vm.envString("RPC_URL");

    // Optional with default
    uint256 gasLimit = vm.envOr("GAS_LIMIT", uint256(3_000_000));
    bool verify = vm.envOr("VERIFY", false);

    // Arrays
    address[] memory admins = vm.envAddress("ADMINS", ",");
}
```

### .env Example

```bash
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
OWNER_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
RPC_URL=https://eth-mainnet.g.alchemy.com/v2/your-api-key
ETHERSCAN_API_KEY=your-etherscan-key
```

## Broadcast Modes

### Single Deployer

```solidity
function run() public {
    vm.startBroadcast(deployerPrivateKey);
    // All transactions from deployer
    vm.stopBroadcast();
}
```

### Using msg.sender

```solidity
function run() public {
    // Uses the address derived from --private-key flag
    vm.startBroadcast();
    // Transactions from caller
    vm.stopBroadcast();
}
```

### Multiple Signers

```solidity
function run() public {
    uint256 deployerKey = vm.envUint("DEPLOYER_KEY");
    uint256 adminKey = vm.envUint("ADMIN_KEY");

    // Deploy as deployer
    vm.startBroadcast(deployerKey);
    MyContract myContract = new MyContract();
    vm.stopBroadcast();

    // Configure as admin
    vm.startBroadcast(adminKey);
    myContract.setConfig(newConfig);
    vm.stopBroadcast();
}
```

## Constructor Arguments

### Basic Arguments

```solidity
function run() public {
    vm.startBroadcast();

    Token token = new Token(
        "MyToken",      // name
        "MTK",          // symbol
        18,             // decimals
        1_000_000e18    // initial supply
    );

    vm.stopBroadcast();
}
```

### Complex Arguments

```solidity
function run() public {
    // Prepare struct
    MyContract.Config memory config = MyContract.Config({
        owner: OWNER,
        fee: 100,
        enabled: true
    });

    // Prepare array
    address[] memory admins = new address[](2);
    admins[0] = ADMIN_1;
    admins[1] = ADMIN_2;

    vm.startBroadcast();
    new MyContract(config, admins);
    vm.stopBroadcast();
}
```

## Deployment Patterns

### Deploy and Initialize (Proxy Pattern)

```solidity
function run() public {
    vm.startBroadcast();

    // Deploy implementation
    MyContract implementation = new MyContract();

    // Deploy proxy
    bytes memory initData = abi.encodeCall(
        MyContract.initialize,
        (OWNER, INITIAL_FEE)
    );
    ERC1967Proxy proxy = new ERC1967Proxy(
        address(implementation),
        initData
    );

    // Cast proxy to implementation interface
    MyContract myContract = MyContract(address(proxy));

    vm.stopBroadcast();

    console.log("Proxy:", address(proxy));
    console.log("Implementation:", address(implementation));
}
```

### Diamond Pattern Deployment

```solidity
function run() public {
    vm.startBroadcast();

    // Deploy facets
    DiamondCutFacet diamondCut = new DiamondCutFacet();
    DiamondLoupeFacet loupe = new DiamondLoupeFacet();
    OwnershipFacet ownership = new OwnershipFacet();
    MyFacet myFacet = new MyFacet();

    // Build cut
    IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](3);
    cut[0] = buildCut(address(loupe), loupeSelectors());
    cut[1] = buildCut(address(ownership), ownershipSelectors());
    cut[2] = buildCut(address(myFacet), myFacetSelectors());

    // Deploy diamond
    Diamond diamond = new Diamond(OWNER, address(diamondCut));

    // Execute cut
    IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");

    vm.stopBroadcast();
}
```

### Factory Deployment

```solidity
function run() public {
    vm.startBroadcast();

    // Deploy factory
    TokenFactory factory = new TokenFactory();

    // Deploy tokens via factory
    address token1 = factory.createToken("Token1", "TK1", 1_000_000e18);
    address token2 = factory.createToken("Token2", "TK2", 2_000_000e18);

    vm.stopBroadcast();

    console.log("Factory:", address(factory));
    console.log("Token1:", token1);
    console.log("Token2:", token2);
}
```

## Network-Specific Deployment

### Chain Detection

```solidity
function run() public {
    vm.startBroadcast();

    // Different config per chain
    address oracle;
    if (block.chainid == 1) {
        oracle = MAINNET_ORACLE;
    } else if (block.chainid == 11155111) {
        oracle = SEPOLIA_ORACLE;
    } else if (block.chainid == 42161) {
        oracle = ARBITRUM_ORACLE;
    } else {
        revert("Unsupported chain");
    }

    new MyContract(oracle);

    vm.stopBroadcast();
}
```

### Configuration Files

```solidity
function run() public {
    // Load chain-specific config
    string memory config = vm.readFile(
        string.concat("config/", vm.toString(block.chainid), ".json")
    );

    address oracle = vm.parseJsonAddress(config, ".oracle");
    uint256 fee = vm.parseJsonUint(config, ".fee");

    vm.startBroadcast();
    new MyContract(oracle, fee);
    vm.stopBroadcast();
}
```

## Post-Deployment Actions

### Transfer Ownership

```solidity
function run() public {
    vm.startBroadcast();

    MyContract myContract = new MyContract();

    // Transfer ownership to multisig
    myContract.transferOwnership(MULTISIG_ADDRESS);

    vm.stopBroadcast();
}
```

### Grant Roles

```solidity
function run() public {
    vm.startBroadcast();

    MyContract myContract = new MyContract();

    // Grant roles
    myContract.grantRole(myContract.ADMIN_ROLE(), ADMIN_1);
    myContract.grantRole(myContract.ADMIN_ROLE(), ADMIN_2);
    myContract.grantRole(myContract.MINTER_ROLE(), MINTER);

    // Renounce deployer's admin role if needed
    myContract.renounceRole(myContract.DEFAULT_ADMIN_ROLE(), msg.sender);

    vm.stopBroadcast();
}
```

### Fund Contracts

```solidity
function run() public {
    vm.startBroadcast();

    MyContract myContract = new MyContract();

    // Fund with ETH
    (bool success,) = address(myContract).call{value: 1 ether}("");
    require(success, "ETH transfer failed");

    // Fund with tokens
    IERC20(TOKEN).transfer(address(myContract), 1000e18);

    vm.stopBroadcast();
}
```

## Saving Deployment Info

### JSON Output

```solidity
function run() public returns (string memory) {
    vm.startBroadcast();

    Token token = new Token();
    MyContract myContract = new MyContract(address(token));

    vm.stopBroadcast();

    // Build JSON
    string memory json = "deployment";
    vm.serializeAddress(json, "token", address(token));
    string memory output = vm.serializeAddress(json, "myContract", address(myContract));

    // Write to file
    vm.writeJson(output, "./deployments/latest.json");

    return output;
}
```

### Reading Previous Deployments

```solidity
function run() public {
    // Read existing deployment
    string memory json = vm.readFile("./deployments/latest.json");
    address existingToken = vm.parseJsonAddress(json, ".token");

    vm.startBroadcast();

    // Use existing token
    new MyContract(existingToken);

    vm.stopBroadcast();
}
```

## Testing Scripts

```solidity
// test/Deploy.t.sol
contract DeployTest is Test {
    DeployScript script;

    function setUp() public {
        script = new DeployScript();
    }

    function test_Deploy() public {
        script.run();

        // Verify deployment
        assertTrue(address(script.myContract()) != address(0));
        assertEq(script.myContract().owner(), EXPECTED_OWNER);
    }
}
```

## Running Scripts

```bash
# Dry run (simulation only)
forge script script/Deploy.s.sol

# Broadcast to network
forge script script/Deploy.s.sol --rpc-url sepolia --broadcast

# With verification
forge script script/Deploy.s.sol \
    --rpc-url sepolia \
    --broadcast \
    --verify \
    --etherscan-api-key $ETHERSCAN_API_KEY

# Verbose output
forge script script/Deploy.s.sol -vvvv

# Resume failed broadcast
forge script script/Deploy.s.sol --rpc-url sepolia --resume
```
