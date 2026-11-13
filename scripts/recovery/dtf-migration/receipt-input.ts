import { z } from "zod";
import { field, integer, optionalInteger, table, unique, candidateError } from "./candidate-input.js";
import type { CandidateInput, TableRow } from "./candidate-input.js";
import { deriveNfts, legacy } from "./candidate-nfts.js";
import type { NftObservation } from "./candidate-nfts.js";
import { ANCHOR, rpcAddress } from "./receipt-association.js";
import { hash } from "./schema.js";

export const claimSource = "0xe4c9ff4cfd17ae73ecb3825ebdf7db113c146d00";
export const sy = "0xb55604cf4dcdabb362078e106d20f98512391edf";
export const earlier = "0xaf0e1967c8f755c747615c5427108bc549ca1122";
export const receiptSelection = z.enum(["purchases-and-claims", "conversions-and-recoveries"]);
export type ReceiptSelection = z.infer<typeof receiptSelection>;
export type ReceiptReference =
  | { readonly kind: "nft"; readonly row: TableRow; readonly tx: string; readonly nft: NftObservation;
      readonly expectedTransfers: readonly TableRow[] }
  | { readonly kind: "claim"; readonly row: TableRow; readonly tx: string; readonly recipient: string;
      readonly principal: string; readonly output: string; readonly expectedBlock: string;
      readonly expectedTransfers: readonly TableRow[] }
  | { readonly kind: "conversion" | "recovery"; readonly row: TableRow; readonly tx: string;
      readonly recipient: string; readonly asset: string; readonly amount: string | null;
      readonly decimals: string; readonly expectedBlock: string; readonly logIndex: string | null;
      readonly expectedTransfers: readonly TableRow[] };

export function receiptReferences(input: CandidateInput, selection: ReceiptSelection = "purchases-and-claims"): readonly ReceiptReference[] {
  if (input.sources.chainId !== 4663 || String(input.sources.evidenceCutoff.block) !== ANCHOR.number
    || input.sources.evidenceCutoff.hash.toLowerCase() !== ANCHOR.hash) candidateError("receipt input cutoff differs");
  receiptSelection.parse(selection);
  if (selection === "conversions-and-recoveries") {
    const transfers = table(input, "evidence/transfers.csv");
    return (["conversions.csv", "observed-recoveries.csv"] as const).flatMap((path) => {
      const rows = table(input, path), recovery = path === "observed-recoveries.csv";
      unique(rows, recovery ? "recovery_id" : "conversion_id");
      return rows.map((row): ReceiptReference => {
        const tx = hash.parse(field(row, "tx")), recipient = rpcAddress.parse(field(row, "recipient"));
        const asset = rpcAddress.parse(field(row, recovery ? "asset" : "output_asset"));
        const decimals = integer(field(row, recovery ? "decimals" : "output_decimals"));
        if (BigInt(decimals) > 255n) candidateError(`invalid token decimals: ${row.locator}`);
        const expectedBlock = integer(field(row, "block"));
        if (BigInt(expectedBlock) > BigInt(ANCHOR.number)) candidateError(`declared block after anchor: ${row.locator}`);
        const logIndex = recovery ? integer(field(row, "log_index")) : null;
        return { kind: recovery ? "recovery" : "conversion", row, tx, recipient, asset, decimals,
          amount: optionalInteger(field(row, recovery ? "observed_amount_raw" : "output_raw")),
          expectedBlock, logIndex,
          expectedTransfers: transfers.filter((r) => field(r, "tx").toLowerCase() === tx
            && field(r, "asset").toLowerCase() === asset && field(r, "to").toLowerCase() === recipient
            && (logIndex === null || field(r, "log_index") === logIndex)) };
      });
    }).sort((a, b) => a.row.locator.localeCompare(b.row.locator));
  }
  for (const [id, path] of [["S008", "evidence/weighted-bonds.csv"], ["S009", "evidence/earlier-cp-bonds.csv"]] as const) {
    if (input.sources.sources.find((s) => s.id === id)?.path !== path) candidateError(`receipt source path differs: ${id}`);
  }
  const transfers = table(input, "evidence/transfers.csv");
  const purchases = [...table(input, "evidence/weighted-bonds.csv"), ...table(input, "evidence/earlier-cp-bonds.csv")];
  const nfts = deriveNfts(input);
  const refs: ReceiptReference[] = nfts.map((nft) => {
    const row = purchases.find((r) => r.locator === nft.purchaseLocator);
    if (!row) return candidateError("purchase locator missing");
    hash.parse(nft.purchaseTx); rpcAddress.parse(nft.recipientObservation);
    return { kind: "nft", row, nft, tx: nft.purchaseTx,
      expectedTransfers: transfers.filter((r) => field(r, "tx").toLowerCase() === nft.purchaseTx) };
  });
  const conversions = table(input, "conversions.csv");
  unique(conversions, "conversion_id");
  for (const row of conversions.filter((r) => field(r, "kind") === "legacy_weight_to_sy")) {
    const tx = hash.parse(field(row, "tx")), recipient = rpcAddress.parse(field(row, "recipient"));
    if (rpcAddress.parse(field(row, "output_asset")) !== sy || field(row, "output_decimals") !== "9") {
      candidateError(`claim output unit differs: ${row.locator}`);
    }
    refs.push({ kind: "claim", row, tx, recipient, principal: integer(field(row, "principal_raw")),
      output: integer(field(row, "output_raw")), expectedBlock: integer(field(row, "block")),
      expectedTransfers: transfers.filter((r) => field(r, "tx").toLowerCase() === tx
        && field(r, "asset").toLowerCase() === sy && field(r, "to").toLowerCase() === recipient) });
  }
  return refs.sort((a, b) => a.row.locator.localeCompare(b.row.locator));
}
export function receiptRequests(refs: readonly ReceiptReference[]) {
  return [...new Set(refs.map((r) => r.tx))].sort().map((tx) => ({
    tx, references: refs.filter((r) => r.tx === tx).map((r) => r.row.locator),
  }));
}
export const archiveVersion = z.literal("dtf-finite-receipt-evidence-v1");
export { legacy };
