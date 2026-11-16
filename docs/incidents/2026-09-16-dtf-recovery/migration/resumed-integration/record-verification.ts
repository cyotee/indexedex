import { createReadStream } from "node:fs";
import { createHash } from "node:crypto";
import { lstat, mkdir, readFile, readdir, readlink, writeFile } from "node:fs/promises";
import { isAbsolute, join, relative, resolve, sep } from "node:path";
import { z } from "zod";
import { child, FORGE } from "../../../../../scripts/recovery/dtf-migration/rehearsal-process.js";
import { save } from "../../../../../scripts/recovery/dtf-migration/rehearsal-data.js";

class InventoryError extends Error {
  constructor(readonly entry: string, message: string) { super(`${entry}: ${message}`); }
}
const fingerprint = (bytes: Buffer | string) => createHash("sha256").update(bytes).digest("hex");
const fileHash = async (file: string) => {
  const hash = createHash("sha256");
  for await (const bytes of createReadStream(file)) hash.update(bytes);
  return hash.digest("hex");
};
const hashSchema = z.string().regex(/^[0-9a-f]{64}$/);
const absolutePath = z.string().refine(isAbsolute, "absolute path required");
const entryPath = z.string().min(1).refine((value) =>
  !isAbsolute(value) && !value.split(/[\\/]/).some((part) => part === ".." || part === "." || part === ""),
"normalized relative entry path required");
const entrySchema = z.object({
  path: entryPath, type: z.enum(["file", "directory", "symlink", "unsupported"]),
  size: z.number().int().nonnegative(), sha256: hashSchema.nullable(), link: z.string().optional(),
}).strict();
type Entry = z.infer<typeof entrySchema>;
const supersessionSchema = z.object({
  sourcePath: absolutePath, sourceSha256: hashSchema,
  destinationPath: absolutePath, destinationSha256: hashSchema,
  preservedPath: absolutePath, reason: z.string().min(1),
}).strict();
const recoveryRowSchema = z.object({
  sourcePath: absolutePath, sourceRoot: absolutePath, path: entryPath, destination: absolutePath,
  deliveredPath: absolutePath, type: z.enum(["file", "directory", "symlink"]),
  size: z.number().int().nonnegative(), sha256: hashSchema.nullable(),
  sourceRevision: z.string().min(1), ownership: z.enum([
    "migration-task-output", "migration-execution-record", "existing-primary-migration-output",
  ]),
  ownershipEvidence: z.array(z.string().min(1)).min(1), status: z.string().min(1), disposition: z.string().min(1),
}).passthrough();
const recoverySchema = z.object({
  version: z.literal(1), destinationRoot: absolutePath,
  rows: z.array(recoveryRowSchema), unresolved: z.array(z.unknown()).max(0),
}).passthrough();
const comparisonSchema = z.object({
  path: entryPath, status: z.enum(["identical", "missing", "EOF-only", "semantic", "symlink", "unsupported"]),
  disposition: z.string().min(1),
  resolution: supersessionSchema.optional(),
}).strict();
const auditSchema = z.object({
  version: z.literal(1), sourceRoot: absolutePath, destinationRoot: absolutePath,
  source: z.array(entrySchema), destination: z.array(entrySchema), rows: z.array(comparisonSchema),
  recovery: z.object({ path: absolutePath, sha256: hashSchema }).nullable(),
  supersessions: z.array(supersessionSchema),
  generatedAuditRecords: z.array(absolutePath),
  concurrentScope: z.array(z.object({
    prefix: z.literal("conformance-20261114/task-1"), disposition: z.string().min(1),
  }).strict()),
  qualification: z.string(),
  parentInventory: z.object({ path: absolutePath, sha256: hashSchema }).optional(),
}).strict();
type Audit = z.infer<typeof auditSchema>;
const inspect = async (file: string) => {
  try { return await lstat(file); }
  catch (error) {
    if (error instanceof Error && "code" in error && error.code === "ENOENT") return null;
    throw error;
  }
};
async function noSymlinkAncestors(file: string) {
  let cursor: string = sep;
  for (const component of resolve(file).split(sep).filter(Boolean)) {
    cursor = join(cursor, component);
    if ((await inspect(cursor))?.isSymbolicLink()) throw new InventoryError(cursor, "symlink boundary");
  }
}
function inside(root: string, file: string) {
  const path = relative(root, file);
  return path === "" || (!isAbsolute(path) && path !== ".." && !path.startsWith(`..${sep}`));
}
async function tree(root: string): Promise<Entry[]> {
  await noSymlinkAncestors(root);
  if (!(await lstat(root)).isDirectory()) throw new InventoryError(root, "tree root must be a directory");
  const entries: Entry[] = [];
  async function walk(directory: string) {
    for (const name of (await readdir(directory)).sort()) {
      const file = join(directory, name);
      const stat = await lstat(file);
      const path = relative(root, file);
      if (stat.isSymbolicLink()) {
        const link = await readlink(file);
        entries.push({ path, type: "symlink", size: Buffer.byteLength(link), sha256: fingerprint(link), link });
      } else if (stat.isDirectory()) {
        entries.push({ path, type: "directory", size: 0, sha256: null });
        await walk(file);
      } else if (stat.isFile()) {
        const hash = await fileHash(file);
        const after = await lstat(file);
        if (stat.size !== after.size || stat.mtimeMs !== after.mtimeMs || stat.ino !== after.ino) {
          throw new InventoryError(file, "entry changed while hashing");
        }
        entries.push({ path, type: "file", size: stat.size, sha256: hash });
      } else entries.push({ path, type: "unsupported", size: stat.size, sha256: null });
    }
  }
  await walk(root);
  return entries;
}
function unique(entries: readonly Entry[], root: string) {
  const map = new Map<string, Entry>();
  for (const entry of entries) {
    if (map.has(entry.path)) throw new InventoryError(join(root, entry.path), "duplicate entry");
    if (entry.type === "file" && entry.sha256 === null) throw new InventoryError(entry.path, "file hash required");
    if (entry.type === "symlink" && (entry.link === undefined || fingerprint(entry.link) !== entry.sha256)) {
      throw new InventoryError(entry.path, "link text/hash mismatch");
    }
    map.set(entry.path, entry);
  }
  return map;
}
function identical(expected: Entry, actual: Entry | undefined) {
  return actual?.type === expected.type && actual.size === expected.size && actual.sha256 === expected.sha256
    && actual.link === expected.link;
}
async function newOutput(output: string) {
  await noSymlinkAncestors(output);
  await mkdir(output, { recursive: false });
}
async function inventory(output: string, sourceRoot: string, destinationRoot: string) {
  if (inside(sourceRoot, output) || inside(sourceRoot, destinationRoot) || inside(destinationRoot, sourceRoot)) {
    throw new InventoryError(output, "retained and destination trees must be disjoint; output cannot be inside retained tree");
  }
  const source = await tree(sourceRoot);
  const destination = await tree(destinationRoot);
  unique(source, sourceRoot);
  const destinationMap = unique(destination, destinationRoot);
  const recoveryPath = join(destinationRoot, "conformance-20261114/task-2/recovery.json");
  const recoveryEntry = destinationMap.get(relative(destinationRoot, recoveryPath));
  let recovery: Audit["recovery"] = null;
  if (recoveryEntry) {
    if (recoveryEntry.type !== "file" || !recoveryEntry.sha256) throw new InventoryError(recoveryPath, "regular recovery manifest required");
    const parsed = recoverySchema.parse(JSON.parse(await readFile(recoveryPath, "utf8")));
    if (parsed.destinationRoot !== destinationRoot) throw new InventoryError(recoveryPath, "wrong destination binding");
    recovery = { path: recoveryPath, sha256: recoveryEntry.sha256 };
  }
  const supersessionsPath = join(destinationRoot, "conformance-20261114/task-2/supersessions.json");
  const supersessionsEntry = destinationMap.get(relative(destinationRoot, supersessionsPath));
  if (supersessionsEntry && supersessionsEntry.type !== "file") {
    throw new InventoryError(supersessionsPath, "regular supersession manifest required");
  }
  const supersessions = supersessionsEntry
    ? z.array(supersessionSchema).parse(JSON.parse(await readFile(supersessionsPath, "utf8"))) : [];
  const rows: Audit["rows"] = [];
  const withoutEof = (bytes: Buffer) => {
    let end = bytes.length;
    while (end > 0 && (bytes[end - 1] === 10 || bytes[end - 1] === 13)) end--;
    return bytes.subarray(0, end);
  };
  for (const entry of source) {
    const actual = destinationMap.get(entry.path);
    let status: Audit["rows"][number]["status"] = "identical";
    if (entry.type === "symlink") status = "symlink";
    else if (entry.type === "unsupported") status = "unsupported";
    else if (!actual) status = "missing";
    else if (!identical(entry, actual)) {
      status = entry.type === "file" && actual.type === "file"
        && withoutEof(await readFile(join(sourceRoot, entry.path)))
          .equals(withoutEof(await readFile(join(destinationRoot, entry.path)))) ? "EOF-only" : "semantic";
    }
    const resolution = supersessions.find((row) => row.sourcePath === join(sourceRoot, entry.path)
      && row.sourceSha256 === entry.sha256 && row.destinationPath === join(destinationRoot, entry.path));
    rows.push({ path: entry.path, status,
      disposition: resolution?.reason ?? (status === "identical" ? "same-relative-path raw bytes" : "unresolved; delivery must fail until restored or source-qualified"),
      ...(resolution ? { resolution } : {}) });
  }
  const audit: Audit = {
    version: 1, sourceRoot, destinationRoot, source, destination, rows, recovery, supersessions,
    generatedAuditRecords: [join(output, "inventory.json")],
    concurrentScope: recovery ? [{
      prefix: "conformance-20261114/task-1",
      disposition: "Observed only: task 1 has a concurrent writer. Task 2 does not certify it; final delivery must inventory its completed evidence.",
    }] : [],
    qualification: "Raw content inventory, not current financial/source authentication or historical test re-execution. Every retained task-owned byte remains required. Audit JSON alone is exempt from recursive self-hashing.",
  };
  const differences = rows.filter((row) => row.status !== "identical");
  const report = [
    `Retained root: ${sourceRoot}`, `Destination root: ${destinationRoot}`,
    `Source entries: ${source.length}; destination entries: ${destination.length}`,
    ...differences.map((row) => `${row.status}\t${row.path}\t${row.disposition}`),
    "Additional historical-source differences and exact archived destinations: conformance-20261114/task-2/recovery-differences.json (when present).",
  ].join("\n") + "\n";
  if (inside(destinationRoot, join(output, "differences.txt"))) {
    audit.destination.push({ path: relative(destinationRoot, join(output, "differences.txt")),
      type: "file", size: Buffer.byteLength(report), sha256: fingerprint(report) });
  }
  await newOutput(output);
  await writeFile(join(output, "differences.txt"), report, { flag: "wx" });
  await save(join(output, "inventory.json"), audit);
  console.log(`INVENTORY_COMPLETE source=${source.length} destination=${destination.length} divergent=${differences.length}`);
}
async function delivery(input: string, output: string) {
  await noSymlinkAncestors(input);
  const inputBytes = await readFile(input);
  const audit = auditSchema.parse(JSON.parse(inputBytes.toString("utf8")));
  if (inside(audit.sourceRoot, output)) throw new InventoryError(output, "delivery output cannot be inside retained tree");
  const expectedSource = unique(audit.source, audit.sourceRoot);
  const expectedDestination = unique(audit.destination, audit.destinationRoot);
  const currentSource = unique(await tree(audit.sourceRoot), audit.sourceRoot);
  const currentEntries = await tree(audit.destinationRoot);
  const current = unique(currentEntries, audit.destinationRoot);
  const failures: string[] = [];
  const issues = new Set<string>();
  const fail = (entry: string, message: string) => { issues.add(`${entry}: ${message}`); };
  const matchFile = (file: string, hash: string | null, size?: number) => {
    if (!inside(audit.destinationRoot, file)) { fail(file, "unresolved destination outside delivery boundary"); return false; }
    const actual = current.get(relative(audit.destinationRoot, file));
    const matches = actual?.type === "file" && actual.sha256 === hash && (size === undefined || actual.size === size);
    if (!matches) fail(file, actual ? "different bytes/type" : "missing task-owned file");
    return matches;
  };
  const superseded = (file: string, hash: string | null) => {
    const row = audit.supersessions.find((item) => item.destinationPath === file && item.sourceSha256 === hash);
    if (!row) return false;
    const source = expectedSource.get(relative(audit.sourceRoot, row.sourcePath));
    // A source-qualified update must preserve its historical bytes and bind its delivered replacement.
    if (source && source.sha256 !== row.sourceSha256) { fail(file, "supersession source binding mismatch"); return false; }
    return matchFile(row.preservedPath, row.sourceSha256) && matchFile(file, row.destinationSha256);
  };
  const rowMap = new Map(audit.rows.map((row) => [row.path, row]));
  if (rowMap.size !== audit.rows.length || rowMap.size !== expectedSource.size) fail(input, "missing/duplicate source dispositions");
  for (const entry of audit.source) {
    const sourcePath = join(audit.sourceRoot, entry.path);
    const target = join(audit.destinationRoot, entry.path);
    if (!identical(entry, currentSource.get(entry.path))) fail(sourcePath, "stale source inventory; source bytes/type changed or missing");
    const row = rowMap.get(entry.path);
    if (!row) fail(sourcePath, "unresolved source disposition");
    if (entry.type === "symlink" || entry.type === "unsupported") {
      fail(target, `unresolved ${entry.type}; no traversal or implicit exclusion`);
    } else if (!identical(entry, current.get(entry.path)) && !superseded(target, entry.sha256)) {
      fail(target, current.has(entry.path) ? "different retained bytes/type; unresolved divergence" : "missing task-owned entry");
    }
  }
  for (const entry of currentSource.values()) {
    if (!expectedSource.has(entry.path)) fail(join(audit.sourceRoot, entry.path), "stale inventory; unrecorded retained entry");
  }
  for (const entry of audit.destination) {
    if (audit.concurrentScope.some((scope) => entry.path === scope.prefix || entry.path.startsWith(`${scope.prefix}/`))) continue;
    const target = join(audit.destinationRoot, entry.path);
    if (entry.type === "symlink" || entry.type === "unsupported") {
      fail(target, `unresolved ${entry.type} in delivered tree`);
    } else if (!identical(entry, current.get(entry.path)) && !superseded(target, entry.sha256)) {
      fail(target, current.has(entry.path) ? "different recorded destination bytes/type" : "missing task-owned entry");
    }
  }
  for (const file of audit.generatedAuditRecords) {
    if (!inside(audit.destinationRoot, file)) continue;
    if (current.get(relative(audit.destinationRoot, file))?.type !== "file") fail(file, "missing generated audit record");
  }
  if (audit.recovery) {
    await noSymlinkAncestors(audit.recovery.path);
    if (matchFile(audit.recovery.path, audit.recovery.sha256)) {
      const recovered = recoverySchema.parse(JSON.parse(await readFile(audit.recovery.path, "utf8")));
      if (recovered.destinationRoot !== audit.destinationRoot) fail(audit.recovery.path, "wrong recovery destination");
      for (const row of recovered.rows) {
        if (row.type === "directory") {
          if (current.get(relative(audit.destinationRoot, row.deliveredPath))?.type !== "directory") fail(row.deliveredPath, "missing recovered directory");
        } else if (!superseded(row.deliveredPath, row.sha256)) matchFile(row.deliveredPath, row.sha256, row.size);
      }
    }
  }
  for (const entry of currentEntries) {
    if (entry.type === "symlink" || entry.type === "unsupported") fail(join(audit.destinationRoot, entry.path), `unresolved new ${entry.type}`);
  }
  failures.push(...issues);
  const next: Audit = {
    ...audit, destination: currentEntries,
    generatedAuditRecords: [join(output, "inventory.json"), join(output, "delivery.json")],
    parentInventory: { path: input, sha256: fingerprint(inputBytes) },
  };
  const receipt = {
    completed: failures.length === 0, input, inputSha256: fingerprint(inputBytes),
    sourceEntries: audit.source.length, destinationEntries: currentEntries.length,
    addedEntries: currentEntries.filter((entry) => !expectedDestination.has(entry.path)).map((entry) => entry.path),
    failures, concurrentScope: audit.concurrentScope,
    generatedAuditRecords: next.generatedAuditRecords,
    qualification: audit.qualification,
  };
  await newOutput(output);
  await save(join(output, "inventory.json"), next);
  await save(join(output, "delivery.json"), receipt);
  for (const failure of failures) console.error(`DELIVERY_FAILURE ${failure}`);
  console.log(`DELIVERY_${receipt.completed ? "COMPLETE" : "FAILED"} entries=${currentEntries.length} failures=${failures.length}`);
  if (!receipt.completed) process.exitCode = 1;
}

const kind = process.argv[2];
if (kind === "inventory") {
  const [, , , output, retainedRoot, destinationRoot, ...extra] = process.argv;
  if (!output || !retainedRoot || !destinationRoot || extra.length) throw new InventoryError("inventory", "expected new-output-directory retained-root destination-root");
  await inventory(resolve(output), resolve(retainedRoot), resolve(destinationRoot));
} else if (kind === "delivery") {
  const [, , , input, output, ...extra] = process.argv;
  if (!input || !output || extra.length) throw new InventoryError("delivery", "expected inventory-json new-output-directory");
  await delivery(resolve(input), resolve(output));
} else {
const destination = process.argv[3];
if (!destination || !["hermetic", "fork", "operator"].includes(kind ?? "")) {
  throw new Error("expected hermetic|fork|operator and a new evidence directory");
}
const evidence = resolve(destination);
await mkdir(evidence, { recursive: false });
const profile = kind === "fork" ? "fork" : "default";
const environment = { ...process.env, FOUNDRY_PROFILE: profile };
const commands: readonly (readonly string[])[] = [
  [FORGE, "--version"],
  ["solar", "--version"],
  ["uname", "-sm"],
  ...(kind === "hermetic" ? [
    [FORGE, "build", "--use", "solar"],
    [FORGE, "test", "--use", "solar", "-vv", "--no-match-path", "**/fork/**", "--no-match-contract", "Fork"],
  ] : kind === "fork" ? [
    ["python3", "scripts/forge-artifacts.py", "test",
      "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRecoveryTarget.sol",
      "--test-root", "test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration",
      "--", "-j", "1", "--compute-units-per-second", "10", "--rpc-timeout", "120", "-vv"],
  ] : [
    ["/bin/zsh", "-c", "bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node scripts/recovery/dtf-migration/*.ts"],
    ["/bin/zsh", "-c", "bun test --timeout 15000 ./scripts/recovery/dtf-migration/*.test.ts"],
  ]),
];
await save(join(evidence, "environment.json"), {
  cwd: process.cwd(), profile, platform: process.platform, arch: process.arch, versions: process.versions,
});
const results: { command: readonly string[]; code: unknown; signal: unknown; log: string }[] = [];
try {
  for (const [index, command] of commands.entries()) {
    const log = join(evidence, `${String(index).padStart(2, "0")}.log`);
    console.log(`CHECK_BEGIN ${kind} ${index}`);
    const result = await child(command, log, environment);
    results.push({ command, code: result.code, signal: result.signal, log });
    for (const line of result.output.split("\n")) {
      if (/^Ran \d+ test suites? in|^\s*\d+ (pass|fail)$|^\[FAIL|^Error|^error:/.test(line)) console.log(line);
    }
    console.log(`CHECK_END ${kind} ${index} ${String(result.code)}`);
    if (result.code !== 0) throw new Error(`validation failed: ${kind} command ${index}`);
  }
  console.log(`VERIFICATION_COMPLETE ${kind}`);
} finally {
  await save(join(evidence, "results.json"), { kind, results,
    completed: results.length === commands.length && results.every((result) => result.code === 0) });
}
}
