import { afterEach, test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, readdir, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { Wallet, keccak256 } from "ethers";
import { Journal } from "./journal.js";
import { canonical, fingerprint } from "./provenance.js";
import { intent, funding, ownerBond } from "./execution-schema.js";
import { interfaceFile } from "./rehearsal-data.js";
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
    version: "dtf-operator-intent-v2", domainHash: journal.domainHash, id: fingerprint("donation"),
    stage: "fund", method: "donateMigrationCapital", transaction, nonce: "7", startBlock: "100",
    gasLimit: "21000", gasPrice: "2", signedTransaction: raw, transactionHash: keccak256(raw),
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

test("paid owner purchase requires explicit positive payment and ordinary duration", async () => {
  const terms = { token: "0x1111111111111111111111111111111111111111",
    amount: "1000000000000000000", duration: "7776000", deadline: "2000000000" };
  for (const key of ["token", "amount", "duration", "deadline"] as const) {
    const { [key]: _missing, ...omitted } = terms;
    assert.equal(ownerBond.safeParse(omitted).success, false);
  }
  for (const changed of [{ amount: "0" }, { duration: "0" }, { deadline: "0" },
    { pretransferred: true }, { syntheticPrincipal: "1" }]) {
    assert.equal(ownerBond.safeParse({ ...terms, ...changed }).success, false);
  }
  const parsed = ownerBond.parse(terms);
  const parent = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json");
  const stageAbi = await interfaceFile("out/Phase_08_Stage_01_MigrationExecution.s.sol/Phase_08_Stage_01_MigrationExecution.json");
  const args = [parsed.token, parsed.amount, parsed.duration, terms.token, false, parsed.deadline];
  const decoded = parent.decodeFunctionData("bond", parent.encodeFunctionData("bond", args));
  assert.equal(decoded[1], BigInt(terms.amount));
  assert.equal(decoded[2], BigInt(terms.duration));
  assert.equal(decoded[4], false);
  const stage = stageAbi.decodeFunctionData("ownerFirstBond", stageAbi.encodeFunctionData("ownerFirstBond",
    [terms.token, parsed.token, parsed.amount, parsed.duration, parsed.deadline]));
  assert.equal(stage[2], decoded[1]);
  assert.equal(stage[3], decoded[2]);
  assert.equal(stage[4], decoded[5]);
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
