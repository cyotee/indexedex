import { FetchRequest, Interface, JsonRpcProvider, Network } from "ethers";
import { z } from "zod";
import { address, hash, hex } from "./schema.js";
import { ExecutionError, quantity, receipt } from "./execution-schema.js";
import { subscribeReceipt } from "./execution-rpc.js";
import type { Receipt } from "./execution-schema.js";

export const LEGACY = {
  weighted: "0xfe4cc6d5faafdf210af4e728f4108fcaad9bb65e",
  earlier: "0x15666f0b4c8d09d046d2aa9048afcaf49e8cb391",
  receipt: "0x4fa4974a8a09660258b8edd430b51c1620ebfe5c",
  detf: "0x4a5cfdc2b07016fcf917f4ed5a51c52111a0fcc7",
  sy: "0xb55604cf4dcdabb362078e106d20f98512391edf",
  dtf: "0xee5576fa1bcaa380e591d01245f406f3f384eb01",
} as const;
export const legacyAbi = new Interface([
  "function ownerOf(uint256) view returns(address)",
  "function getApproved(uint256) view returns(address)",
  "function approve(address,uint256)",
  "function transferFrom(address,address,uint256)",
  "function setApprovalForAll(address,bool)",
  "function transfer(address,uint256) returns(bool)",
  "function balanceOf(address) view returns(uint256)",
  "function gonsOf(address) view returns(uint256)",
  "function claimBond(uint256,address) returns(uint256,uint256)",
  "function stakingState() view returns((uint256 totalGons,uint256 gonsPerUnit,uint256 accountedBacking,uint256 allocationDust,uint256 stakingDust,uint256 feeWeight,uint256 creatorWeight))",
  "function exchangeIn(address,uint256,address,uint256,address,bool,uint256) returns(uint256)",
]);
export class RehearsalChain {
  readonly endpoint: URL;
  readonly provider: JsonRpcProvider;
  readonly receipts: Receipt[] = [];
  constructor(port: string) {
    this.endpoint = new URL(`http://127.0.0.1:${port}`);
    const request = new FetchRequest(this.endpoint.toString());
    request.timeout = 15000;
    this.provider = new JsonRpcProvider(request, new Network("owned-anvil", 4663), { batchMaxCount: 1, staticNetwork: true, cacheTimeout: -1 });
  }
  async send(method: string, params: readonly unknown[]): Promise<unknown> { return this.provider.send(method, [...params]); }
  async call(target: string, abi: Interface, method: string, args: readonly unknown[] = []) {
    return abi.decodeFunctionResult(method, hex.parse(await this.send("eth_call", [{ to: target, data: abi.encodeFunctionData(method, args) }, "latest"])));
  }
  async canonicalReceipt(transactionHash: string): Promise<Receipt | undefined> {
    const raw = await this.send("eth_getTransactionReceipt", [transactionHash]);
    if (raw === null) return undefined;
    const mined = receipt.parse(raw);
    const block = z.object({ hash }).passthrough().parse(await this.send("eth_getBlockByNumber", [mined.blockNumber, false]));
    if (block.hash !== mined.blockHash) throw new ExecutionError("AMBIGUOUS", "fixture receipt is not canonical");
    return mined;
  }
  async transact(target: string, request: { readonly from: string; readonly data: string; readonly value?: string }, expectedStatus = 1n) {
    // This fixture-only path uses unlocked holders, never a production key.
    // Subscribe before submitting; a pending event triggers the exact receipt read.
    let selected: string | undefined;
    const watch = await subscribeReceipt({ endpoint: this.endpoint,
      canonicalReceipt: async () => selected ? this.canonicalReceipt(selected) : undefined }, `0x${"0".repeat(64)}`);
    try {
      const gasPrice = quantity.parse(await this.send("eth_gasPrice", []));
      selected = hash.parse(await this.send("eth_sendTransaction", [{ ...request, to: target, gas: "0x5f5e100", gasPrice, type: "0x0" }]));
      const mined = await watch.mined();
      if (BigInt(mined.status) !== expectedStatus) throw new ExecutionError("REVERT", `fixture transaction status differs: ${selected}`);
      this.receipts.push(mined);
      return mined;
    } finally { watch.close(); }
  }
  async withHolder(tokenId: string, action: (holder: string) => Promise<void>) {
    const holder = address.parse((await this.call(LEGACY.weighted, legacyAbi, "ownerOf", [tokenId]))[0]);
    await this.send("anvil_setBalance", [holder, "0x3635c9adc5dea00000"]);
    await this.send("anvil_impersonateAccount", [holder]);
    try { await action(holder); }
    finally { await this.send("anvil_stopImpersonatingAccount", [holder]); }
  }
  async timestamp(): Promise<bigint> {
    return BigInt(z.object({ timestamp: quantity }).passthrough().parse(await this.send("eth_getBlockByNumber", ["latest", false])).timestamp);
  }
  close() { this.provider.destroy(); }
}
