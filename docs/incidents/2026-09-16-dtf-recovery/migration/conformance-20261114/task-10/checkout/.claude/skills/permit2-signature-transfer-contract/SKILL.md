---
name: permit2-signature-transfer-contract
description: Solidity contract implementation for permitWitnessTransferFrom. Use when writing Solidity contracts that receive Permit2 signatures.
---

# Permit2 Signature Transfer - Contract Integration

Solidity implementation for `permitWitnessTransferFrom` pattern.

## Contract Setup

```solidity
import {ISignatureTransfer} from "@uniswap/permit2/src/interfaces/ISignatureTransfer.sol";

contract IndexedexRouter {
    address public constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    // Must match frontend exactly
    string public constant WITNESS_TYPE_STRING =
        "PermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline,Witness witness)"
        "TokenPermissions(address token,uint256 amount)"
        "Witness(bytes32 actionId)";

    bytes32 public constant WITNESS_TYPEHASH = keccak256("Witness(bytes32 actionId)");
}
```

## Exchange In Handler

```solidity
function handlePermitSignatureIn(
    ISignatureTransfer.PermitTransferFrom calldata permit,
    ISignatureTransfer.SignatureTransferDetails calldata transferDetails,
    address owner,
    bytes32 actionId,
    bytes calldata signature
) external {
    bytes32 witness = keccak256(abi.encode(WITNESS_TYPEHASH, actionId));

    ISignatureTransfer(PERMIT2).permitWitnessTransferFrom(
        permit,
        transferDetails,
        owner,
        witness,
        WITNESS_TYPE_STRING,
        signature
    );

    // tokens now in this contract - execute the swap
}
```

## Exchange Out Handler

For exact-out swaps, include `maxAmountIn` in the actionId:

```solidity
bytes32 actionId = keccak256(abi.encodePacked(
    tokenIn,
    tokenOut,
    vaultAddress,
    amountOut,
    maxAmountIn
));
```

## Cross-Chain Considerations

- Permit2 address is **canonical** (same on all chains)
- ChainId must match the network where signature will be used
- Signatures are not valid across chains
