import { test } from "node:test";
import assert from "node:assert/strict";
import { z } from "zod";
import { transactionClaimBooks } from "./claimed-sy-state.js";
import { claimBookReads } from "./claimed-sy-witness.js";
import { claimBookFacets, stakingClaim } from "./claimed-sy-source.js";
import { address, hex } from "./schema.js";
import { a } from "./preparation.fixture.js";

const wallet = a(10);
const states = [
  { weight: 50n, supply: 500n, shares: 800n, vaultSupply: 1000n, sy: 4n, vaultSy: 90n, sySupply: 100n },
  { weight: 50n, supply: 470n, shares: 740n, vaultSupply: 940n, sy: 4n, vaultSy: 84n, sySupply: 100n },
  { weight: 40n, supply: 460n, shares: 720n, vaultSupply: 920n, sy: 6n, vaultSy: 82n, sySupply: 100n },
  { weight: 40n, supply: 430n, shares: 660n, vaultSupply: 860n, sy: 6n, vaultSy: 76n, sySupply: 100n },
] as const;

function prefixRpc() {
  return {
    async send(method: string, params: readonly unknown[]): Promise<unknown> {
      const call = z.object({ from: address, to: address, data: hex }).parse(params[0]);
      assert.equal(params[1], "0x64");
      const index = method === "eth_call" ? 3 : z.object({ tracer: z.literal("callTracer"),
        txIndex: z.string().regex(/^0x[0-9a-f]+$/).transform((value) => Number(BigInt(value))),
      }).parse(params[2]).txIndex;
      assert.ok(index >= 0 && index < states.length);
      const state = states[index];
      assert.ok(state);
      const read = claimBookReads(wallet).find(([, target, fn, args]) =>
        call.to === target && call.data === stakingClaim.encodeFunctionData(fn, args));
      assert.ok(read);
      const [key, target, fn] = read;
      const output = stakingClaim.encodeFunctionResult(fn, [state[key]]);
      if (method === "eth_call") return output;
      assert.equal(method, "debug_traceCall");
      return { type: "CALL", from: wallet, to: target, input: call.data, output,
        calls: [{ type: "DELEGATECALL", from: target, to: claimBookFacets[target], input: call.data, output }] };
    },
  };
}

test("unbracketed claims read the target prefix and successor prefix, not parent and final block", async () => {
  const books = await transactionClaimBooks(prefixRpc(), wallet, { tag: "0x64", index: 1, count: 3 });
  assert.deepEqual(books, { before: states[1], after: states[2] });
  assert.equal(books.before.supply - books.after.supply, 10n);
  assert.equal(states[0].supply - states[3].supply, 70n);
});

test("a block's final unbracketed transaction uses canonical final state only for its poststate", async () => {
  assert.deepEqual(await transactionClaimBooks(prefixRpc(), wallet, { tag: "0x64", index: 2, count: 3 }),
    { before: states[2], after: states[3] });
});

test("unavailable transaction-prefix state fails closed rather than falling back to block deltas", async () => {
  await assert.rejects(transactionClaimBooks({
    async send(method: string) {
      assert.equal(method, "debug_traceCall");
      throw new Error("unsupported transaction state");
    },
  }, wallet, { tag: "0x64", index: 1, count: 3 }), { code: "PROVENANCE", reason: "STATE_UNAVAILABLE" });
});

test("unbracketed indirect certificate admits a contract wallet without an invented delegation or router witness", async () => {
  const { claimedSyCertificate } = await import("./schema.js");
  const { h } = await import("./preparation.fixture.js");
  const member = claimedSyCertificate.unwrap().shape.members.unwrap().element.parse({
    transactionHash: h(10), rawSignedTransaction: "0x", blockNumber: "100", blockHash: h(100),
    consumedWeight: "10", receivedSy: "2", redeemedVaultShares: "20",
    execution: { kind: "indirect-transaction-v1", walletCodeHash: h(9) },
  });
  assert.deepEqual(member.execution, { kind: "indirect-transaction-v1", walletCodeHash: h(9) });
});
