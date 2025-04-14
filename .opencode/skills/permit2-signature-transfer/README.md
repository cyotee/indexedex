# Permit2 Signature Transfer

Skill folder: .opencode/skills/permit2-signature-transfer

Purpose
-------
Utilities and examples for creating Permit2 signature-transfer EIP-712 typed data with an additional "witness" binding so frontend can request a single signature that authorizes a specific action (swap/deposit/withdraw) without prior approval.

Quick start (example)
---------------------
See `uniswap/permit2-sdk.ts` for the helper `SignatureTransfer.getPermitData()` used to produce the domain, types and values for `signTypedData`.

Witness patterns
----------------
- exchangeIn (Exact In): witness includes `actionId: bytes32`
- exchangeOut (Exact Out): witness includes `actionId: bytes32` which may incorporate `maxAmountIn`

Contract integration
--------------------
The Solidity contract implementation that verifies and consumes the signature lives in the related skill `permit2-signature-transfer-contract`.

Files
-----
- `uniswap/permit2-sdk.ts` — TypeScript helper that builds EIP-712 typed data for Permit2 SignatureTransfer permits.
