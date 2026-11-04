# r3 h3-aave-loop-eip712-uninit: CONFIRMED (functional/integration DoS, INFO/low)

DUPLICATE of hunt3/h3-crane-bundled-facets.md NEW-3 (INFO). This run adds execution evidence.

Test: AaveLoopEip712Uninit.t.sol::test_r3_eip712_uninit_permit_dos. PASS on the audit runner slot1.
Fixture: the real E2E deploy path (IndexedexManager, then DFPkg, then VaultRegistry.deployVault, giving a diamond). An honest holder deposits 10e18 tokenA and receives axCARRY.

Observed:
- eip712Domain() returns fields 0x0f, name "", version "".
- ERC20 name() returns "Aave Cross-Version Carry Loop".
- DOMAIN_SEPARATOR() is 0xf203...b567, which equals keccak(TYPEHASH, bytes32(0), bytes32(0), chainid, vault).
- A standard ERC-5267 signer uses keccak("") for name and version and builds 0xfa1a...7d3f. Its permit reverts.
- A standard signer using name() and version "1" builds 0x3d85...f529. Its permit reverts.
- A signer that uses the raw on-chain DOMAIN_SEPARATOR() is accepted. The allowance is set and the nonce is incremented.

Impact: ERC-2612 permit on axCARRY does not work with standard tooling, such as viem/ethers signTypedData or EIP-5267 discovery. This affects gasless approvals and routers that use permit. No funds are at risk and there is no attacker profit. Cross-domain replay is not possible, because chainid and verifyingContract stay in the domain.

Fix: in AaveCrossVersionLoopDFPkg.initAccount, add
`EIP712Repo._initialize("Aave Cross-Version Carry Loop", "1");`
This matches ERC4626StandardExchangeDFPkg:209 and MorphoBlueStandardExchangeDFPkg:219.
