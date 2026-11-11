import { afterEach, test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, readdir, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { Wallet, keccak256 } from "ethers";
import { Journal } from "./journal.js";
import { canonical, fingerprint } from "./provenance.js";
import { intent, funding } from "./execution-schema.js";
import { main } from "./cli.js";

const roots: string[] = [];
async function directory() {
  const root = await mkdtemp(join(tmpdir(), "dtf-execution-test-"));
  roots.push(root);
  return root;
}
afterEach(async () => { for (const root of roots.splice(0)) await rm(root, { recursive: true }); });

test("journal refuses live concurrent writers and changed domains", async () => {
  const root = await directory();
  const journal = await Journal.acquire(root, { chain: "4663", proxy: "original" });
  await assert.rejects(Journal.acquire(root, { chain: "4663", proxy: "original" }), /live writer/);
  await journal.close();
  await assert.rejects(Journal.acquire(root, { chain: "4663", proxy: "different" }), /domain changed/);
  const resumed = await Journal.acquire(root, { chain: "4663", proxy: "original" });
  await resumed.close();
});

test("durable signed intent survives reopening without acquiring another nonce", async () => {
  const root = await directory();
  const domain = { chain: "4663", snapshot: "frozen", payload: "complete" };
  const journal = await Journal.acquire(root, domain);
  const wallet = new Wallet("0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80");
  const transaction = { from: wallet.address.toLowerCase(), to: "0x1111111111111111111111111111111111111111", data: "0x", value: "19" };
  const raw = await wallet.signTransaction({ to: transaction.to, value: 19n, nonce: 7, gasPrice: 2n, gasLimit: 21000n, chainId: 4663n });
  const record = intent.parse({
    version: "dtf-operator-intent-v1", domainHash: journal.domainHash, id: fingerprint("donation"),
    stage: "fund", method: "donateMigrationCapital", transaction, nonce: "7", startBlock: "100",
    signedTransaction: raw, transactionHash: keccak256(raw),
  });
  await journal.persistIntent(record);
  await journal.close();
  const resumed = await Journal.acquire(root, domain);
  assert.deepEqual(await resumed.intents(), [record]);
  await assert.rejects(resumed.persistIntent(record), { code: "EEXIST" });
  assert.equal((await readdir(root)).filter((name) => name.endsWith(".intent.json")).length, 1);
  await resumed.close();
});

test("journal rejects a foreign intent rather than accepting its receipt", async () => {
  const root = await directory();
  const journal = await Journal.acquire(root, { payload: "one" });
  await writeFile(join(root, "foreign.intent.json"), "{}");
  await assert.rejects(journal.intents());
  await journal.close();
  assert.equal(JSON.parse(await readFile(join(root, "domain.json"), "utf8")).payload, "one");
});

test("partial unpublished records cannot become completed operations", async () => {
  const root = await directory();
  const journal = await Journal.acquire(root, { payload: "one" });
  await writeFile(join(root, "interrupted.intent.json.pending"), '{"nonce":');
  assert.deepEqual(await journal.intents(), []);
  await journal.close();
});

test("funding rejects arbitrary calldata and unknown native values", () => {
  assert.equal(funding.safeParse({ donations: [], genesis: null, calldata: "0x" }).success, false);
  assert.equal(funding.safeParse({ donations: [{
    id: `0x${"1".repeat(64)}`, tokens: [], amounts: [], nativeAmount: null, minimum: "0", deadline: "100",
  }], genesis: null }).success, false);
});

for (const { args, reason } of [
  { args: ["fund", "--manifest", "unused", "--checkpoint", "unused", "--execute-local", "--broadcast"], reason: /execution modes are exclusive/ },
  { args: ["resume", "--manifest", "unused", "--checkpoint", "unused", "--instance-id", "old"], reason: /confirmation requires explicit mode/ },
  { args: ["activate", "--manifest", "unused", "--checkpoint", "unused", "--broadcast"], reason: /all fresh public confirmations required/ },
  { args: ["fund", "--manifest", "unused", "--checkpoint", "unused", "--target", "0x1111111111111111111111111111111111111111"], reason: /Unknown option/ },
]) {
  test(`CLI rejects ambiguous authority before file or network access: ${canonical(args)}`, async () => {
    await assert.rejects(main(args), reason);
  });
}
