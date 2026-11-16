import { Interface } from "ethers";
import { join } from "node:path";
import { z } from "zod";
import { claimedSigned, claimedWallet } from "./rehearsal-claimed-sy-source.js";
import { interfaceFile, save } from "./rehearsal-data.js";
import type { RehearsalChain } from "./rehearsal-chain.js";
import type { PreparationInput } from "./schema.js";
import type { ExecutionManifest } from "./execution-schema.js";
import { ExecutionError } from "./execution-schema.js";

/** A configured holder's later transfer cannot veto the owner's activation. */
export async function exerciseClaimedSyTransfer(context: {
  readonly chain: RehearsalChain; readonly input: PreparationInput;
  readonly manifest: ExecutionManifest; readonly evidence: string;
  readonly activate: () => Promise<void>;
}) {
  const { chain, input, manifest, evidence } = context;
  const wallet = claimedWallet(231).address.toLowerCase();
  const recipient = claimedWallet(241).address.toLowerCase();
  const row = input.weightedSy.find((item) => item.claimedOrigin && item.original.originalWallet === wallet);
  if (!row) throw new ExecutionError("STATE", "controlled claimed original required");
  const token = new Interface([
    "function transfer(address,uint256) returns(bool)",
    "function balanceOf(address) view returns(uint256)",
    "function totalSupply() view returns(uint256)",
  ]);
  const migration = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json");
  const sy = row.original.source;
  const amount = row.original.originalUnits;
  const balance = async (account: string) => z.bigint().parse((await chain.call(sy, token, "balanceOf", [account]))[0]);
  if (await chain.send("eth_getCode", [recipient, "latest"]) !== "0x" || await balance(recipient) !== 0n) {
    throw new ExecutionError("STATE", "transfer recipient must be a fresh controlled account");
  }
  await claimedSigned(chain, evidence, { index: 0, to: recipient, data: "0x", value: 10n ** 18n });
  const original = (await chain.call(manifest.proxy, migration, "weightedSyEntitlement", [row.original.originalId])).toString();
  const away = await claimedSigned(chain, evidence, { index: 231, to: sy,
    data: token.encodeFunctionData("transfer", [recipient, amount]) });
  await context.activate();
  const ledger = async () => (await chain.call(manifest.proxy, migration, "weightedSySurrender", [row.original.originalId])).toString();
  const before = await ledger();
  const supply = (await chain.call(manifest.proxy, token, "totalSupply"))[0];
  const custody = await balance(manifest.proxy);
  const failed = await claimedSigned(chain, evidence, { index: 231, to: manifest.proxy, status: 0n,
    data: migration.encodeFunctionData("surrenderMigrationWeightedSy",
      [row.original.originalId, amount, 0, await chain.timestamp() + 3600n]) });
  if (await ledger() !== before || (await chain.call(manifest.proxy, token, "totalSupply"))[0] !== supply
    || await balance(manifest.proxy) !== custody) {
    throw new ExecutionError("STATE", "absent claimed assets changed credit or custody");
  }
  const returned = await claimedSigned(chain, evidence, { index: 241, to: sy,
    data: token.encodeFunctionData("transfer", [wallet, amount]) });
  if (await balance(recipient) !== 0n || original !==
    (await chain.call(manifest.proxy, migration, "weightedSyEntitlement", [row.original.originalId])).toString()) {
    throw new ExecutionError("STATE", "transfer/return changed configured original");
  }
  await save(join(evidence, "claimed-holder-transfer-activation.json"), {
    originalId: row.original.originalId, originalWallet: wallet, recipient, amount,
    transfer: away.mined.transactionHash, failedSurrender: failed.mined.transactionHash,
    returned: returned.mined.transactionHash, configurationUnchanged: true,
    activationWhileAssetsAway: (await chain.call(manifest.proxy, migration, "migrationActivated"))[0],
  });
}
