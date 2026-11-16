import assert from "node:assert/strict";
import { encodeAbiParameters, encodeFunctionData, decodeFunctionResult, parseAbi, keccak256 } from "viem";

// Evidence-only source-primitive witness. No Migration/verifier/bond is deployed.
// The caller records every RPC request/result. This module performs no file I/O.
export async function runWitness(rpc) {
  const token = "0x4a5cfdc2b07016fcf917f4ed5a51c52111a0fcc7";
  const facet = "0x1d17aca0e0717d90cea916372070a1be4652223f";
  const donor = "0x082cb14f04d9c485473dedc00d604d7e9abca303";
  const alice = "0x000000000000000000000000000000000000e601";
  const bob = "0x000000000000000000000000000000000000e602";
  const spender = "0x000000000000000000000000000000000000e603";
  const custody = "0x000000000000000000000000000000000000e604";
  const abi = (signature) => parseAbi([`function ${signature}`]);
  const data = (signature, args) => encodeFunctionData({ abi: abi(signature), args });
  const call = async (signature, args = []) => decodeFunctionResult({
    abi: abi(signature),
    data: await rpc("eth_call", [{ to: token, data: data(signature, args) }, "latest"]),
  });
  const send = async (from, signature, args) => rpc("eth_sendTransaction", [{
    from, to: token, data: data(signature, args), gas: "0x7a120", gasPrice: "0x2540be400",
  }]);
  const receipt = async (hash) => {
    const result = await rpc("eth_getTransactionReceipt", [hash]);
    assert.equal(result.status, "0x1");
    return result;
  };
  const observations = async () => ({
    balances: await Promise.all([donor, alice, bob, custody].map(
      (owner) => call("balanceOf(address) view returns (uint256)", [owner]))),
    allowance: await call("allowance(address,address) view returns (uint256)", [alice, spender]),
    supply: await call("totalSupply() view returns (uint256)"),
  });
  const result = { subjects: { token, facet, donor, alice, bob, spender, custody }, branches: [] };
  assert.equal(await rpc("eth_chainId"), "0x1237");
  const historical = await rpc("eth_getBlockByNumber", ["0x67e5d17", false]);
  assert.equal(historical.hash, "0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733");
  result.historical = historical;
  const code = await rpc("eth_getCode", [facet, "latest"]);
  result.facetHash = keccak256(code);
  assert.equal(result.facetHash, "0xf250dca135b1de9a5fc9ceda732c06af7020fef1d45d7c43dfa92efe02b47e50");
  for (const selector of ["0xa9059cbb", "0x23b872dd", "0x095ea7b3", "0x70a08231"]) {
    assert.equal((await call("facetAddress(bytes4) view returns (address)", [selector])).toLowerCase(), facet);
  }
  for (const owner of [donor, alice, bob, spender, custody]) {
    assert.equal(await rpc("eth_getCode", [owner, "latest"]), "0x");
  }
  const initial = await observations();
  result.initial = initial;
  assert.deepEqual(initial.balances.slice(1), [0n, 0n, 0n]);
  assert.equal(initial.allowance, 0n);
  assert.ok(initial.balances[0] >= 200n);
  const outer = await rpc("evm_snapshot");
  try {
    for (const owner of [donor, alice, bob, spender]) {
      await rpc("anvil_impersonateAccount", [owner]);
      // Gas funding only; never mutate token code/storage or token balances.
      await rpc("anvil_setBalance", [owner, "0x56bc75e2d63100000"]);
    }
    const setup = [];
    setup.push(await send(donor, "transfer(address,uint256) returns (bool)", [alice, 100n]));
    setup.push(await send(donor, "transfer(address,uint256) returns (bool)", [bob, 100n]));
    setup.push(await send(alice, "approve(address,uint256) returns (bool)", [spender, 50n]));
    await rpc("evm_mine");
    result.setup = await Promise.all(setup.map(receipt));
    result.baseline = await observations();
    assert.deepEqual(result.baseline.balances.slice(1), [100n, 100n, 0n]);
    assert.equal(result.baseline.allowance, 50n);
    result.parent = await rpc("eth_getBlockByNumber", ["latest", false]);
    const timestamp = Number(BigInt(result.parent.timestamp)) + 1;
    // Mapping slots are derived from the archived deployed ERC20Repo layout.
    const slot = BigInt(keccak256(encodeAbiParameters([{ type: "string" }], ["eip.erc.20"]))) - 1n;
    const balanceSlot = (owner) => keccak256(encodeAbiParameters(
      [{ type: "address" }, { type: "uint256" }], [owner, slot + 4n]));
    result.balanceSlots = { alice: balanceSlot(alice), custody: balanceSlot(custody) };
    for (const mixed of [false, true]) {
      const checkpoint = await rpc("evm_snapshot");
      try {
        await rpc("evm_setNextBlockTimestamp", [timestamp]);
        const hashes = [];
        hashes.push(await send(alice, "transfer(address,uint256) returns (bool)", [mixed ? bob : alice, 50n]));
        hashes.push(await send(bob, "transfer(address,uint256) returns (bool)", [mixed ? alice : bob, 50n]));
        hashes.push(await send(spender, "transferFrom(address,address,uint256) returns (bool)", [alice, custody, 50n]));
        await rpc("evm_mine");
        const receipts = await Promise.all(hashes.map(receipt));
        assert.deepEqual(receipts.map((r) => r.transactionIndex), ["0x0", "0x1", "0x2"]);
        assert.equal(new Set(receipts.map((r) => r.blockHash)).size, 1);
        const block = await rpc("eth_getBlockByNumber", [receipts[0].blockNumber, false]);
        assert.equal(block.parentHash, result.parent.hash);
        assert.deepEqual(block.transactions, hashes);
        const prestate = await rpc("debug_traceTransaction", [hashes[2], { tracer: "prestateTracer" }]);
        const storage = prestate[token].storage;
        assert.equal(BigInt(storage[result.balanceSlots.alice]), 100n);
        // Clients may omit zero-valued storage in a prestate trace.
        assert.equal(BigInt(storage[result.balanceSlots.custody] ?? "0x0"), 0n);
        const traces = await Promise.all(hashes.map((hash) => rpc(
          "debug_traceTransaction", [hash, { tracer: "callTracer" }])));
        const final = await observations();
        assert.deepEqual(final.balances.slice(1), [50n, 100n, 50n]);
        assert.equal(final.allowance, 0n);
        assert.equal(final.supply, initial.supply);
        // Synthetic authenticated credit baseline, not an actual donor award.
        const aliceCredit = mixed ? 1000n - 500n + (3500n * 50n / 150n) : 1000n;
        const award = aliceCredit * 50n / 100n;
        assert.equal(award, mixed ? 833n : 500n);
        result.branches.push({
          name: mixed ? "balance-restoring-prefix" : "self-transfer-control",
          hashes, receipts, block, prestate, traces, final,
          theoretical: { aliceBeforeCustody: aliceCredit, award, aliceRemainder: aliceCredit - award },
        });
      } finally {
        assert.equal(await rpc("evm_revert", [checkpoint]), true);
      }
    }
    const [control, mixed] = result.branches;
    assert.deepEqual(control.final, mixed.final);
    const transferEvent = (branch) => branch.receipts[2].logs.filter(
      (log) => log.topics[0] === keccak256(new TextEncoder().encode("Transfer(address,address,uint256)")),
    ).map(({ address, topics, data: eventData }) => ({ address, topics, data: eventData }));
    assert.equal(transferEvent(control).length, 1);
    assert.deepEqual(transferEvent(control), transferEvent(mixed));
    result.sameSelectedCustodyEvent = true;
    assert.notEqual(control.block.hash, mixed.block.hash);
    assert.notEqual(control.block.receiptsRoot, mixed.block.receiptsRoot);
    result.distinctHistoryCommitments = true;
    result.pass = true;
  } finally {
    result.restored = await rpc("evm_revert", [outer]);
    assert.equal(result.restored, true);
    result.afterRestore = await observations();
    assert.deepEqual(result.afterRestore, initial);
  }
  return result;
}
