import { join } from "node:path";
import { verifyAuthorization, hashAuthorization, keccak256, Transaction } from "ethers";
import { Rpc, check, save, wallet, signed, capture, qty, hex, hash, abi,
  T, Y, DONOR, PIN, PINHASH, numberAt, blockSchema } from "./common.js";
import { deploy, identities, probeAbi } from "./chain.js";

export const W0 = 10013000000000000000017n;
export const UNRELATED_WEIGHT = 7000000000000000000n;
export const FULL = 291;
export const SPLIT = 292;
export const DONATION = 293;
export const WRONG = 294;

export async function setup(rpc: Rpc, output: string) {
  check(BigInt(qty.parse(await rpc.send("eth_chainId", []))) === 4663n, "chain pin");
  check(await rpc.send("eth_blockNumber", []) === PIN, "fresh fork required");
  const anchor = blockSchema.parse(await rpc.send("eth_getBlockByNumber", [PIN, false]));
  check(anchor.hash === PINHASH, "source pin hash");
  await save(join(output, "anchor.json"), anchor);
  const bindings = await identities(rpc);
  const allowed = [
    [T, "withdrawClaim", "0x5628dcb4bb0a1a24e6bde3b985f92c2ef0894ddd6006a55ddaffccc877a52742"],
    ["0xaf5c0cd3fdedd10bee00eff77fa0429bacdb41f0", "redeem", "0x8c1ea71d607b09b21c4e78f850647a059dc7935b6772f7cd3aeaa700a995439f"],
    [Y, "transfer", "0x6da9227c829765d0464b5eeee02c55ea45883e3af2767aea546f5e906e8b143d"],
  ];
  for (const [target, method, codeHash] of allowed) {
    check(bindings.find(b => b.target === target)?.routes.find(r => r.method === method)?.runtimeHash === codeHash,
      "retained fixed source runtime differs");
  }
  await save(join(output, "source-bindings-before.json"), bindings);
  const full = wallet(FULL).address.toLowerCase(), split = wallet(SPLIT).address.toLowerCase();
  const custody = await deploy(rpc, "SourceCustody", [full, split]);
  const delegate = await deploy(rpc, "DelegatedSourceProbe", [full, split, wallet(0).address, custody]);
  const runtime = hex.parse(await rpc.send("eth_getCode", [delegate, "latest"]));
  const runtimeHash = keccak256(runtime);
  check(await rpc.send("eth_getCode", [DONOR, "latest"]) === "0x", "donor must be actual EOA");
  await signed(rpc, 0, { to: DONOR, value: 10n ** 18n });
  const acquisition = [];
  for (const [index, amount] of [[FULL, W0 + UNRELATED_WEIGHT],
    [SPLIT, W0 + UNRELATED_WEIGHT + 2n], [DONATION, 3n * 10n ** 18n], [WRONG, 0n]] as const) {
    const account = wallet(index).address.toLowerCase();
    check(await rpc.send("eth_getCode", [account, "latest"]) === "0x"
      && await numberAt(rpc, T, "balanceOf", [account]) === 0n
      && await numberAt(rpc, Y, "balanceOf", [account]) === 0n, "fresh signer");
    check((await signed(rpc, 0, { to: account, value: 10n ** 18n })).receipt.status === "0x1", "gas transfer");
    if (amount === 0n) continue;
    const before = await numberAt(rpc, T, "balanceOf", [DONOR]);
    const supply = await numberAt(rpc, T, "totalSupply");
    await rpc.send("anvil_impersonateAccount", [DONOR]);
    try {
      const txHash = hash.parse(await rpc.send("eth_sendTransaction", [{
        from: DONOR, to: T, data: abi.encodeFunctionData("reassign", [account, amount]),
        gas: "0x4c4b40",
      }]));
      await rpc.send("evm_mine", []);
      const captured = await capture(rpc, txHash, null);
      check(captured.receipt.status === "0x1", "donor reassignment");
      const after = await numberAt(rpc, T, "balanceOf", [DONOR]);
      check(before - after === amount && await numberAt(rpc, T, "balanceOf", [account]) === amount
        && await numberAt(rpc, T, "totalSupply") === supply, "actual reassignment conservation");
      acquisition.push({ account, amount, before, after, captured,
        provenance: "LOCAL impersonated existing EOA holder reassign; not a donor signature, public consent or owner operation" });
    } finally { await rpc.send("anvil_stopImpersonatingAccount", [DONOR]); }
  }
  await save(join(output, "acquisition.json"), acquisition);
  const setups = [];
  for (const index of [FULL, SPLIT]) {
    const signer = wallet(index), account = signer.address.toLowerCase();
    const nonceBefore = BigInt(qty.parse(await rpc.send("eth_getTransactionCount", [account, "latest"])));
    const auth = signer.authorizeSync({ address: delegate, chainId: 4663n, nonce: nonceBefore });
    check(verifyAuthorization(auth, auth.signature).toLowerCase() === account, "authorization signer");
    const captured = await signed(rpc, 0, { to: account, type: 4, authorizationList: [auth],
      data: probeAbi.encodeFunctionData(index === SPLIT ? "fail" : "ping") });
    const code = hex.parse(await rpc.send("eth_getCode", [account, "latest"]));
    const nonceAfter = BigInt(qty.parse(await rpc.send("eth_getTransactionCount", [account, "latest"])));
    check(code === `0xef0100${delegate.slice(2)}` && nonceAfter === nonceBefore + 1n,
      "real delegation processing");
    check(captured.receipt.status === (index === SPLIT ? "0x0" : "0x1"), "setup execution status");
    check(captured.raw !== null, "authorization raw transaction missing");
    const parsed = Transaction.from(captured.raw);
    check(parsed.type === 4 && parsed.authorizationList?.length === 1, "type4 original signed bytes");
    setups.push({ account, auth, digest: hashAuthorization(auth), nonceBefore, nonceAfter, code, captured,
      executionReverted: index === SPLIT,
      qualification: "authorization code and nonce persist even when execution fails; not generic EVM rollback" });
  }
  await save(join(output, "authorizations.json"), setups);
  check((await signed(rpc, 0, { to: split, data: probeAbi.encodeFunctionData("ping") })).receipt.status === "0x1",
    "failed-execution setup still delegated");
  const donationClaim = await signed(rpc, DONATION, { to: T,
    data: abi.encodeFunctionData("withdrawClaim", [3n * 10n ** 18n]) });
  check(donationClaim.receipt.status === "0x1", "real excluded donation source");
  for (const [account, amount] of [[full, 100n], [split, 101n]] as const) {
    check((await signed(rpc, DONATION, { to: Y, data: abi.encodeFunctionData("transfer", [account, amount]) }))
      .receipt.status === "0x1", "real unrelated SY transfer");
    check(await numberAt(rpc, Y, "balanceOf", [account]) === amount, "unrelated SY floor");
  }
  await save(join(output, "fixture.json"), { full, split, custody, delegate, runtime, runtimeHash,
    bindings, donationClaim: donationClaim.transaction.hash, w0: W0, unrelatedWeight: UNRELATED_WEIGHT,
    fullSyFloor: 100n, splitSyFloor: 101n, relayer: wallet(0).address.toLowerCase(),
    qualification: "Real source mechanics; synthetic eligible originals, zero prior compensation and exclusions; no Migration award" });
  console.log("SETUP_COMPLETE", full, split, delegate);
  return { full, split, custody, delegate, runtime, runtimeHash, bindings };
}
