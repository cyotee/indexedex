import type { JsonRpcProvider } from "ethers";
import { z } from "zod";
import { hex } from "./schema.js";
import { stakingClaim, claimBookFacets } from "./claimed-sy-source.js";
import { claimBookReads, claimFrames, ClaimedSyEvidenceError, requireClaimEvidence } from "./claimed-sy-witness.js";
import type { ClaimBooks } from "./claimed-sy-witness.js";

/**
 * Geth TraceCallConfig.txIndex selects the state before that transaction, after
 * replaying its canonical block prefix. i+1 is the target's poststate; if the
 * target is last, the canonical block's final eth_call state is exactly its poststate.
 * No uploaded state, override, isolated-block assumption or retroactive router is used.
 * Primary API: https://geth.ethereum.org/docs/interacting-with-geth/rpc/ns-debug
 */
export async function transactionClaimBooks(provider: Pick<JsonRpcProvider, "send">, wallet: string,
  position: { readonly tag: string; readonly index: number; readonly count: number }) {
  requireClaimEvidence(Number.isSafeInteger(position.index) && position.index >= 0 && position.index < position.count,
    "invalid transaction state position");
  const books = async (index: number): Promise<ClaimBooks> => {
    const values = { weight: 0n, supply: 0n, shares: 0n, vaultSupply: 0n, sy: 0n, vaultSy: 0n, sySupply: 0n };
    for (const [key, target, method, args] of claimBookReads(wallet)) {
      const data = stakingClaim.encodeFunctionData(method, args);
      const request = { from: wallet, to: target, data };
      let raw: unknown;
      try {
        raw = index === position.count
          ? await provider.send("eth_call", [request, position.tag])
          : await provider.send("debug_traceCall", [request, position.tag,
            { tracer: "callTracer", txIndex: `0x${index.toString(16)}` }]);
      } catch (error) {
        if (!(error instanceof Error)) throw error;
        throw new ClaimedSyEvidenceError("STATE_UNAVAILABLE", "RPC cannot provide the exact canonical transaction-prefix state");
      }
      if (index === position.count) {
        values[key] = z.bigint().parse(stakingClaim.decodeFunctionResult(method, hex.parse(raw))[0]);
      } else {
        const frames = claimFrames(raw);
        const root = frames[0];
        const leaf = frames[1];
        requireClaimEvidence(frames.length === 2 && root?.type === "CALL"
          && root.from === wallet && root.to === target && root.input === data
          && leaf?.type === "DELEGATECALL" && leaf.from === target && leaf.to === claimBookFacets[target]
          && leaf.input === data && leaf.output === root.output && root.output.length === 66,
        "transaction-prefix getter execution differs", "WITNESS_SHAPE");
        values[key] = z.bigint().parse(stakingClaim.decodeFunctionResult(method, root.output)[0]);
      }
    }
    return values;
  };
  return { before: await books(position.index), after: await books(position.index + 1) };
}
