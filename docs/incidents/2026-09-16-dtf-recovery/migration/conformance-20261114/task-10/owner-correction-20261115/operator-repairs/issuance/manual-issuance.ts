import assert from "node:assert/strict";
import { resolve } from "node:path";
import { actualIssuance, issuanceContext, issuanceCorruptions } from "./issuance-context.js";
import { canonicalReceipt } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-rpc.js";
import { interfaceFile } from "../../../../../../../../../scripts/recovery/dtf-migration/rehearsal-data.js";
import { canonical, fingerprint } from "../../../../../../../../../scripts/recovery/dtf-migration/provenance.js";
import { receipt, ExecutionError } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-schema.js";

const actual = await actualIssuance();
const authenticated = await canonicalReceipt({
  async send(method: string): Promise<unknown> {
    switch (method) {
      case "eth_getTransactionReceipt": return actual.saved.receipt;
      case "eth_getBlockByNumber": return actual.saved.header;
      case "eth_getLogs": return actual.saved.receipt.logs;
      default: throw new ExecutionError("RPC", `saved evidence does not contain ${method}`);
    }
  },
}, actual.saved.receipt.transactionHash);
assert.ok(authenticated);
const erc20 = await interfaceFile(resolve("out/IERC20.sol/IERC20.json"));
assert.throws(() => erc20.parseLog({ topics: [...actual.transfer.topics], data: actual.transfer.data }),
  (error: unknown) => error instanceof RangeError && error.message.includes("BUFFER_OVERRUN"));
const transfer = actual.bondAbi.parseLog({ topics: [...actual.transfer.topics], data: actual.transfer.data });
const created = actual.bondAbi.parseLog({ topics: [...actual.creation.topics], data: actual.creation.data });
assert.equal(transfer?.name, "Transfer");
assert.equal(created?.name, "MigrationPositionCreated");
assert.equal(transfer.args[2], created.args[0]);
assert.equal(transfer.args[1], created.args[1]);
console.log(JSON.stringify({
  kind: "saved-actual-local-chain-receipt", status: actual.saved.receipt.status,
  transactionHash: actual.saved.receipt.transactionHash, receiptSha256: fingerprint(actual.raw),
  erc721: actual.transfer, requiredEvent: actual.creation,
  expectedTransferValues: [...transfer.args].map(String), expectedCreationValues: [...created.args].map(String),
  legacyErc20ParserFailure: "BUFFER_OVERRUN",
  limit: "Only saved canonical receipt and event facts replayed; complete post-issuance getter RPC state is not saved here. No historical domain was rebound.",
}));

const f = await issuanceContext();
try {
  console.log(JSON.stringify({ kind: "new-synthetic-source-bound-context", domainHash: f.record.domainHash,
    transactionHash: f.record.transactionHash, sources: f.domain.manifest.sources,
    limit: "Fixture signatures, addresses, quantities and getter replies are synthetic; actual ERC721/event shapes use generated artifacts. No Anvil transaction." }));
  if (process.argv.includes("--before")) {
    await assert.rejects(f.verify(f.mined),
      (error: unknown) => error instanceof RangeError && error.message.includes("BUFFER_OVERRUN"));
    console.log(JSON.stringify({ kind: "production-before", expectedParserFailure: "BUFFER_OVERRUN" }));
  } else {
    const completed = await f.verify(f.mined);
    assert.equal(completed.state["bond:3"], canonical([String(f.principal), "0", String(f.gons), "2000", "7776000"]));
    console.log(JSON.stringify({ kind: "production-after", status: "accepted", state: completed.state }));
    for (const c of issuanceCorruptions(f)) {
      await assert.rejects(f.verify(c.receipt));
      console.log(JSON.stringify({ kind: "corrupted-copy", name: c.name, status: "rejected" }));
    }
    await assert.rejects(f.verify(receipt.parse({ ...f.mined, status: "0x0" })), /canonical transaction reverted/);
    console.log(JSON.stringify({ kind: "misleading-success", status: "reverted receipt rejected despite complete events" }));
    f.changes.reads.set(f.bondAbi.encodeFunctionData("positionOf", [3n]),
      f.bondAbi.encodeFunctionResult("positionOf", [[f.principal + 1n, 0n, f.gons, f.start, 7776000n]]));
    await assert.rejects(f.verify(f.mined), /actual bond identity, principal, owner or fresh cliff differs/);
    console.log(JSON.stringify({ kind: "stale-state", status: "stale principal getter rejected despite valid receipt" }));
  }
  assert.equal(f.methods.includes("eth_sendRawTransaction"), false);
} finally { await f.close(); }
