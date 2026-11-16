import { lstat, readFile } from "node:fs/promises";
import { dirname, relative, resolve } from "node:path";
import { z } from "zod";
import { fingerprint } from "./provenance.js";
import { PreparationError } from "./schema.js";

const binding = z.object({
  sha256: z.string().regex(/^[0-9a-f]{64}$/),
  bytes: z.number().int().nonnegative().safe(),
});
const sourceIndex = z.object({
  chainId: z.literal(4663),
  incident: z.object({
    lastFullBlock: z.number().int().safe(), attackBlock: z.number().int().safe(),
    attackTransactionIndex: z.number().int().safe(), attackTransaction: z.string(),
  }).readonly(),
  evidenceCutoff: z.object({ block: z.number().int().safe(), hash: z.string(), utc: z.string() }).readonly(),
  sourceNotes: z.array(z.string()).readonly(),
  sources: z.array(binding.extend({ id: z.string().regex(/^S[0-9]{3}$/), path: z.string(), description: z.string() }).readonly()).readonly(),
}).readonly();
export type CandidateBinding = z.infer<typeof binding> & {
  readonly path: string; readonly declaration: string;
};
export type CandidateInput = {
  readonly sources: z.infer<typeof sourceIndex>;
  readonly bindings: readonly CandidateBinding[];
  readonly bytes: ReadonlyMap<string, Uint8Array>;
};
export function candidateError(message: string): never {
  throw new PreparationError("PROVENANCE", `candidates: ${message}`);
}

// The two explicit indexes are the trust roots. Authenticate sources.json from
// manifest.json before parsing it, then authenticate EVERY declaration before CSV.
export async function loadCandidateInput(root: string): Promise<CandidateInput> {
  const base = resolve(root);
  const read = async (path: string): Promise<Uint8Array> => {
    const target = resolve(base, path);
    const rel = relative(dirname(base), target);
    if (rel.startsWith("..") || rel === "") candidateError(`path outside input tree: ${path}`);
    let cursor = target;
    for (;;) {
      const stat = await lstat(cursor);
      if (stat.isSymbolicLink()) candidateError(`symlink input: ${path}`);
      if (cursor === target && !stat.isFile()) candidateError(`not a regular file: ${path}`);
      const parent = dirname(cursor);
      if (parent === cursor) break;
      cursor = parent;
    }
    return readFile(target);
  };
  const manifestBytes = await read("manifest.json");
  const manifest = z.object({ files: z.record(binding) }).parse(JSON.parse(new TextDecoder().decode(manifestBytes)));
  const sourceBinding = manifest.files["sources.json"];
  if (!sourceBinding) candidateError("manifest must bind sources.json");
  const sourceBytes = await read("sources.json");
  const check = (bytes: Uint8Array, expected: z.infer<typeof binding>, path: string): void => {
    if (bytes.byteLength !== expected.bytes || fingerprint(bytes) !== expected.sha256) candidateError(`raw binding differs: ${path}`);
  };
  check(sourceBytes, sourceBinding, "sources.json");
  const sources = sourceIndex.parse(JSON.parse(new TextDecoder().decode(sourceBytes)));
  if (new Set(sources.sources.map((s) => s.id)).size !== sources.sources.length) candidateError("duplicate source ID");
  const declarations: CandidateBinding[] = [
    ...sources.sources.map((s) => ({ ...s, declaration: s.id })),
    ...Object.entries(manifest.files).map(([path, b]) => ({ ...b, path, declaration: "manifest" })),
  ];
  const bytes = new Map<string, Uint8Array>([["manifest.json", manifestBytes]]);
  for (const d of declarations) {
    if (relative(base, resolve(base, d.path)) !== d.path) candidateError(`noncanonical path: ${d.path}`);
    const raw = bytes.get(d.path) ?? await read(d.path);
    check(raw, d, d.path);
    bytes.set(d.path, raw);
  }
  return { sources, bindings: declarations, bytes };
}

export type RawRow = Readonly<Record<string, string>>;
export type TableRow = {
  readonly locator: string; readonly row: number; readonly path: string;
  readonly fields: RawRow;
};
// RFC4180 subset with strict rectangular rows, doubled quotes and embedded
// newlines. Row numbers are logical CSV records (header is record 1).
export function parseCandidateCsv(text: string, path: string): readonly TableRow[] {
  const records: string[][] = [];
  let row: string[] = [], field = "", quoted = false, closed = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"' && text[i + 1] === '"') { field += '"'; i++; }
      else if (c === '"') { quoted = false; closed = true; }
      else field += c;
    } else if (c === '"' && field === "" && !closed) quoted = true;
    else if (c === "," || c === "\n" || c === "\r") {
      row.push(field); field = ""; closed = false;
      if (c !== ",") {
        if (c === "\r" && text[i + 1] === "\n") i++;
        records.push(row); row = [];
      }
    } else {
      if (closed || c === '"') candidateError(`malformed CSV: ${path}`);
      field += c;
    }
  }
  if (quoted) candidateError(`unclosed CSV quote: ${path}`);
  if (row.length || field || closed) { row.push(field); records.push(row); }
  const header = records.shift();
  if (!header?.length || header.some((h) => !h) || new Set(header).size !== header.length) candidateError(`invalid CSV header: ${path}`);
  return records.map((values, i) => {
    if (values.length !== header.length) candidateError(`CSV width: ${path}:${i + 2}`);
    const fields = Object.fromEntries(header.map((key, j) => [key, values[j] ?? ""]));
    return { locator: `${path}#row=${i + 2}`, row: i + 2, path, fields };
  });
}
export function field(row: TableRow, key: string): string {
  const value = row.fields[key];
  if (value === undefined) candidateError(`missing column ${key}: ${row.locator}`);
  return value;
}
export function integer(value: string): string {
  if (!/^(0|[1-9][0-9]*)$/.test(value)) candidateError(`malformed unsigned integer: ${value}`);
  return value;
}
export function optionalInteger(value: string): string | null {
  return value === "" ? null : integer(value);
}
export function signedInteger(value: string): string {
  if (!/^(0|-?[1-9][0-9]*)$/.test(value)) candidateError(`malformed signed integer: ${value}`);
  return value;
}
export function table(input: CandidateInput, path: string): readonly TableRow[] {
  const bytes = input.bytes.get(path);
  if (!bytes) candidateError(`missing bound table: ${path}`);
  return parseCandidateCsv(new TextDecoder("utf-8", { fatal: true }).decode(bytes), path);
}
export function unique(rows: readonly TableRow[], key: string): ReadonlyMap<string, TableRow> {
  const result = new Map<string, TableRow>();
  for (const r of rows) {
    const id = field(r, key).toLowerCase();
    if (!id || result.has(id)) candidateError(`duplicate/empty ${key}: ${r.locator}`);
    result.set(id, r);
  }
  return result;
}
