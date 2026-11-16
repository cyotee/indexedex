import { readFile, readdir } from "node:fs/promises";
import { join } from "node:path";
import { z } from "zod";
import { Transaction, keccak256, verifyAuthorization } from "ethers";
import { check, abi, T, V, Y, DONOR, wallet, hex, frameSchema, receiptSchema, txSchema, blockSchema, json } from "./common.js";
import { admitMember } from "./admission.js";
import type { Member } from "./admission.js";

const integer = z.string().regex(/^[0-9]+$/).transform(BigInt);
const bookSchema = z.object({
  weight: integer, weightSupply: integer, shares: integer, vaultSupply: integer,
  walletSy: integer, vaultSy: integer, sySupply: integer, custodySy: integer,
  allowance: integer, booked: integer, rewards: integer, donorWeight: integer,
  relayerSy: integer, walletShares: integer,
}).strict();
const capturedSchema = z.object({
  raw: hex.nullable(), receipt: receiptSchema, transaction: txSchema, block: blockSchema,
  prior: blockSchema, trace: frameSchema,
}).strict();
export const memberSchema = z.object({
  wallet: z.string(), weight: integer, before: bookSchema, after: bookSchema, captured: capturedSchema,
  delegation: z.object({
    delegate: z.string(), runtime: hex, runtimeHash: z.string(), beforeCode: hex,
    afterCode: hex, afterRuntime: hex, relayer: z.string(),
  }).strict(),
}).strict();
const bindingSchema = z.array(z.object({
  target: z.string(), code: hex, codeHash: z.string(),
  routes: z.array(z.object({ method: z.string(), selector: hex, facet: z.string(), runtime: hex, runtimeHash: z.string() })),
}));
const fixtureSchema = z.object({
  full: z.string(), split: z.string(), custody: z.string(), delegate: z.string(),
  runtime: hex, runtimeHash: z.string(), relayer: z.string(), bindings: bindingSchema,
}).passthrough();
const requestSchema = z.object({
  jsonrpc: z.literal("2.0"), id: z.number(), method: z.string(), params: z.array(z.unknown()),
});
const responseSchema = z.object({
  jsonrpc: z.literal("2.0"), id: z.number(), result: z.unknown().optional(), error: z.unknown().optional(),
});
export async function loadEvidence(directory: string) {
  const fixture = fixtureSchema.parse(JSON.parse(await readFile(join(directory, "fixture.json"), "utf8")));
  const rows = z.array(z.object({ label: z.string(), member: memberSchema }))
    .parse(JSON.parse(await readFile(join(directory, "operations.json"), "utf8")));
  const wire = new Map<string, unknown>();
  let exchanges = 0;
  for (const name of (await readdir(join(directory, "wire"))).filter(n => /^\d+\.json$/.test(n)).sort()) {
    const saved = z.object({ request: z.string(), response: z.string(), httpStatus: z.number(), raw: z.literal(true) })
      .parse(JSON.parse(await readFile(join(directory, "wire", name), "utf8")));
    const req = requestSchema.parse(JSON.parse(saved.request)), res = responseSchema.parse(JSON.parse(saved.response));
    check(req.id === res.id && saved.httpStatus === 200 && res.error === undefined, "wire exchange failed");
    const key = json([req.method, req.params]);
    // Only exact numbered observations are used for authentication; latest reads may vary.
    wire.set(key, res.result);
    exchanges++;
  }
  const observed = (method: string, params: readonly unknown[]) => {
    const key = json([method, params]);
    check(wire.has(key), `missing independent wire observation ${method}`);
    return wire.get(key);
  };
  const n = (target: string, method: string, args: readonly unknown[], tag: string) =>
    z.bigint().parse(abi.decodeFunctionResult(method, hex.parse(observed("eth_call",
      [{ to: target, data: abi.encodeFunctionData(method, args) }, tag])))[0]);
  const code = (target: string, tag: string) => hex.parse(observed("eth_getCode", [target, tag]));
  const authenticate = (member: Member) => {
    const c = member.captured, h = c.transaction.hash, account = member.wallet;
    check([fixture.full, fixture.split].includes(account), "unsupported fixture authority");
    check(member.delegation.delegate === fixture.delegate && member.delegation.runtime === fixture.runtime
      && member.delegation.runtimeHash === fixture.runtimeHash
      && member.delegation.relayer === fixture.relayer, "unreviewed delegate identity");
    const original = {
      transaction: txSchema.parse(observed("eth_getTransactionByHash", [h])),
      receipt: receiptSchema.parse(observed("eth_getTransactionReceipt", [h])),
      block: blockSchema.parse(observed("eth_getBlockByNumber", [c.block.number, false])),
      prior: blockSchema.parse(observed("eth_getBlockByNumber", [c.prior.number, false])),
      trace: frameSchema.parse(observed("debug_traceTransaction", [h, { tracer: "callTracer" }])),
    };
    check(json(original) === json({ transaction: c.transaction, receipt: c.receipt,
      block: c.block, prior: c.prior, trace: c.trace }), "captured transaction/receipt/trace differs from wire");
    check(c.raw !== null && observed("eth_sendRawTransaction", [c.raw]) === h, "original signed submission missing");
    for (const [tag, state] of [[c.prior.number, member.before], [c.block.number, member.after]] as const) {
      const measured = {
        weight: n(T, "balanceOf", [account], tag), weightSupply: n(T, "totalSupply", [], tag),
        shares: n(V, "balanceOf", [T], tag), vaultSupply: n(V, "totalSupply", [], tag),
        walletSy: n(Y, "balanceOf", [account], tag), vaultSy: n(Y, "balanceOf", [V], tag),
        sySupply: n(Y, "totalSupply", [], tag), custodySy: n(Y, "balanceOf", [fixture.custody], tag),
        allowance: n(Y, "allowance", [account, fixture.custody], tag),
        booked: n(fixture.custody, "booked", [account], tag), rewards: n(T, "rewards", [account], tag),
        donorWeight: n(T, "balanceOf", [DONOR], tag), relayerSy: n(Y, "balanceOf", [wallet(0).address], tag),
        walletShares: n(V, "balanceOf", [account], tag),
      };
      check(json(measured) === json(state), "uploaded state differs from wire");
      check(code(account, tag) === `0xef0100${fixture.delegate.slice(2)}`, "actual designation differs");
    }
    check(code(fixture.delegate, c.block.number) === fixture.runtime, "actual delegate runtime differs");
    return admitMember(member);
  };
  const authorizations = z.array(z.object({
    account: z.string(), nonceBefore: integer, nonceAfter: integer, code: hex,
    captured: capturedSchema, executionReverted: z.boolean(),
  }).passthrough()).parse(JSON.parse(await readFile(join(directory, "authorizations.json"), "utf8")));
  for (const setup of authorizations) {
    check(setup.captured.raw !== null, "missing authorization transaction");
    const signed = Transaction.from(setup.captured.raw), auth = signed.authorizationList?.[0];
    check(signed.type === 4 && signed.authorizationList?.length === 1 && auth
      && verifyAuthorization(auth, auth.signature).toLowerCase() === setup.account
      && auth.chainId === 4663n && auth.address.toLowerCase() === fixture.delegate
      && auth.nonce === setup.nonceBefore && setup.nonceAfter === setup.nonceBefore + 1n
      && signed.hash === setup.captured.transaction.hash
      && setup.code === `0xef0100${fixture.delegate.slice(2)}`, "authorization proof differs");
    check(json(receiptSchema.parse(observed("eth_getTransactionReceipt", [signed.hash])))
      === json(setup.captured.receipt), "authorization canonical receipt differs");
  }
  check(keccak256(fixture.runtime) === fixture.runtimeHash, "delegate runtime digest");
  return { fixture, rows, authenticate, exchanges, authorizations };
}
