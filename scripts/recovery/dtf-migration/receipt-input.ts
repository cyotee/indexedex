import { z } from "zod";
import { field, integer, table, unique, candidateError } from "./candidate-input.js";
import type { CandidateInput, TableRow } from "./candidate-input.js";
import { deriveNfts, legacy } from "./candidate-nfts.js";
import type { NftObservation } from "./candidate-nfts.js";
import { ANCHOR, rpcAddress } from "./receipt-association.js";
import { hash } from "./schema.js";

export const claimSource = "0xe4c9ff4cfd17ae73ecb3825ebdf7db113c146d00";
export const sy = "0xb55604cf4dcdabb362078e106d20f98512391edf";
export const earlier = "0xaf0e1967c8f755c747615c5427108bc549ca1122";
export type ReceiptReference =
  | { readonly kind: "nft"; readonly row: TableRow; readonly tx: string; readonly nft: NftObservation;
      readonly expectedTransfers: readonly TableRow[] }
  | { readonly kind: "claim"; readonly row: TableRow; readonly tx: string; readonly recipient: string;
      readonly principal: string; readonly output: string; readonly expectedBlock: string;
      readonly expectedTransfers: readonly TableRow[] };

export function receiptReferences(input: CandidateInput): readonly ReceiptReference[] {
  if (input.sources.chainId !== 4663 || String(input.sources.evidenceCutoff.block) !== ANCHOR.number
    || input.sources.evidenceCutoff.hash.toLowerCase() !== ANCHOR.hash) candidateError("receipt input cutoff differs");
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
