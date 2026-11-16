import { readdir, lstat, readlink, mkdir, writeFile, access } from "node:fs/promises";
import { join, dirname } from "node:path";

const WT = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-27-data-candidates";
const COMMON = "/Users/cyotee/Projects/indexedex/.git";
const OWN = "dtf-migration-phase-27-data-candidates";
const HELD09 = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-09-deployment-gas";
const OUT = "/tmp/phase27-data-candidates-precommit";
const COMMIT_DIR = join(WT, "docs/incidents/2026-09-16-dtf-recovery/migration/data-candidates/commit");

const gitEnv = {
  ...process.env,
  GIT_MASTER: "1",
  GIT_OPTIONAL_LOCKS: "0",
  GIT_PAGER: "cat",
  PAGER: "cat",
};

function guard(abs) {
  if (abs === HELD09 || abs.startsWith(HELD09 + "/")) {
    throw new Error("refusing to open held09 worktree path: " + abs);
  }
}

function gitMode(st) {
  if (st.isSymbolicLink()) return "120000";
  if (st.isFile()) return (st.mode & 0o111) !== 0 ? "100755" : "100644";
  return "000000";
}

function perm(st) {
  return "0o" + (st.mode & 0o777).toString(8);
}

function kindOf(st) {
  if (st.isSymbolicLink()) return "symlink";
  if (st.isDirectory()) return "dir";
  if (st.isFile()) return "file";
  return "other";
}

function cmpPath(a, b) {
  return Buffer.compare(Buffer.from(a.path, "utf8"), Buffer.from(b.path, "utf8"));
}

function sha256Bytes(buf) {
  return new Bun.CryptoHasher("sha256").update(buf).digest("hex");
}

async function hashFile(abs) {
  guard(abs);
  const hasher = new Bun.CryptoHasher("sha256");
  const stream = Bun.file(abs).stream();
  const reader = stream.getReader();
  while (true) {
    const chunk = await reader.read();
    if (chunk.done) break;
    hasher.update(chunk.value);
  }
  return hasher.digest("hex");
}

async function mapPool(items, limit, fn) {
  const out = new Array(items.length);
  let next = 0;
  let done = 0;
  async function worker() {
    while (true) {
      const idx = next++;
      if (idx >= items.length) return;
      out[idx] = await fn(items[idx], idx);
      done++;
      if (done % 2000 === 0) console.error("hashed", done, "/", items.length);
    }
  }
  const n = Math.min(limit, Math.max(items.length, 1));
  await Promise.all(Array.from({ length: n }, () => worker()));
  return out;
}

async function collect(absRoot, relRoot) {
  guard(absRoot);
  const entries = [];
  async function rec(abs, rel) {
    guard(abs);
    const st = await lstat(abs);
    const row = {
      path: rel,
      kind: kindOf(st),
      gitMode: gitMode(st),
      perm: perm(st),
      st_mode: st.mode,
      size: st.size,
      sha256: null,
      target: null,
      ino: st.ino,
    };
    if (st.isSymbolicLink()) {
      row.target = await readlink(abs);
      row.sha256 = sha256Bytes(Buffer.from(row.target, "utf8"));
      entries.push(row);
      return;
    }
    if (st.isDirectory()) {
      entries.push(row);
      const names = await readdir(abs);
      for (const name of names) {
        const childRel = rel.length === 0 ? name : rel + "/" + name;
        await rec(join(abs, name), childRel);
      }
      return;
    }
    entries.push(row);
  }
  await rec(absRoot, relRoot);
  return entries;
}

async function fillHashes(entries, absFor) {
  const files = entries.filter((e) => e.kind === "file");
  await mapPool(files, 12, async (row) => {
    row.sha256 = await hashFile(absFor(row.path));
  });
}

function toJsonl(entries, keys) {
  const sorted = entries.slice().sort(cmpPath);
  let text = "";
  for (const row of sorted) {
    const obj = {};
    for (const key of keys) obj[key] = row[key];
    text += JSON.stringify(obj) + "\n";
  }
  return text;
}

const CONTENT_KEYS = ["path", "kind", "gitMode", "perm", "st_mode", "size", "sha256", "target"];
const PERM_KEYS = ["path", "kind", "perm", "st_mode", "size", "sha256", "target"];

function contentOf(entries) {
  return entries.filter((e) => e.kind !== "dir");
}

async function git(args) {
  const r = await Bun.$`git -C ${WT} --no-pager ${args}`.env(gitEnv).nothrow().quiet();
  return { args, exit: r.exitCode, stdout: r.stdout.toString(), stderr: r.stderr.toString() };
}

async function exists(p) {
  try {
    await access(p);
    return true;
  } catch {
    return false;
  }
}

if (await exists(COMMIT_DIR)) throw new Error("commit/ already exists; capture must precede it");

const accepted = JSON.parse(await Bun.file("/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase27-data-candidates-commit-source.json").text());
const manifest = JSON.parse(await Bun.file(join(WT, "docs/incidents/2026-09-16-dtf-recovery/migration/data-candidates/verification-r2/source-manifest.json")).text());
const byPath = new Map(manifest.files.map((f) => [f.path, f]));
const binding = [];
for (const item of accepted.paths) {
  const abs = join(WT, item.path);
  const buf = await Bun.file(abs).bytes();
  const st = await lstat(abs);
  const sha = sha256Bytes(buf);
  const tested = byPath.get(item.path);
  const row = {
    path: item.path,
    bytes: buf.length,
    sha256: sha,
    acceptedBytes: item.bytes,
    acceptedSha256: item.sha256,
    testedBytes: tested ? tested.bytes : null,
    testedSha256: tested ? tested.sha256 : null,
    testedManifestHasMode: false,
    filesystemMode: st.mode,
    perm: perm(st),
    predictedGitMode: gitMode(st),
    matchAccepted: sha === item.sha256 && buf.length === item.bytes,
    matchTested: tested ? sha === tested.sha256 && buf.length === tested.bytes : false,
  };
  if (!row.matchAccepted || !row.matchTested) throw new Error("source binding mismatch " + item.path);
  binding.push(row);
}
if (binding.length !== 10) throw new Error("expected 10 accepted paths");
if (manifest.files.length !== 62) throw new Error("expected 62 tested identities, got " + manifest.files.length);

const frozen = [];
for (const f of manifest.files) {
  const abs = join(WT, f.path);
  const buf = await Bun.file(abs).bytes();
  const st = await lstat(abs);
  const sha = sha256Bytes(buf);
  if (sha !== f.sha256 || buf.length !== f.bytes) throw new Error("frozen identity mismatch " + f.path);
  frozen.push({
    path: f.path,
    bytes: buf.length,
    sha256: sha,
    filesystemMode: st.mode,
    perm: perm(st),
    predictedGitMode: gitMode(st),
    testedManifestHasMode: false,
  });
}

console.error("collecting docs/incidents");
const docs = await collect(join(WT, "docs/incidents"), "docs/incidents");
console.error("docs entries", docs.length);
console.error("collecting out");
const outEntries = await collect(join(WT, "out"), "out");
console.error("out entries", outEntries.length);
console.error("collecting cache_forge");
const cache = await collect(join(WT, "cache_forge"), "cache_forge");
console.error("cache_forge entries", cache.length);

const external = [
  ["original-recovery", "/Users/cyotee/Projects/indexedex/docs/incidents", "/Users/cyotee/Projects/indexedex/docs/incidents/2026-09-16-dtf-recovery", "2026-09-16-dtf-recovery"],
  ["original-pre-exploit", "/Users/cyotee/Projects/indexedex/docs/incidents", "/Users/cyotee/Projects/indexedex/docs/incidents/2026-09-16-dtf-pre-exploit", "2026-09-16-dtf-pre-exploit"],
  ["recovered-input", "/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration", "/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase27-frozen-input-recovery", "phase27-frozen-input-recovery"],
];
const externalEntries = {};
for (const [name, parent, abs, rel] of external) {
  console.error("collecting", name);
  externalEntries[name] = { parent, abs, rel, entries: await collect(abs, rel) };
  console.error(name, "entries", externalEntries[name].entries.length);
}

const allForHash = [
  ...docs,
  ...outEntries,
  ...cache,
  ...Object.values(externalEntries).flatMap((x) => x.entries),
].filter((e) => e.kind === "file");
console.error("hashing files", allForHash.length);
const absForPath = new Map();
function remember(entries, rootAbs, relRoot) {
  for (const row of entries) {
    if (row.kind !== "file") continue;
    const suffix = row.path === relRoot ? "" : row.path.slice(relRoot.length + 1);
    absForPath.set(row, suffix.length === 0 ? rootAbs : join(rootAbs, suffix));
  }
}
remember(docs, join(WT, "docs/incidents"), "docs/incidents");
remember(outEntries, join(WT, "out"), "out");
remember(cache, join(WT, "cache_forge"), "cache_forge");
for (const item of Object.values(externalEntries)) {
  remember(item.entries, item.abs, item.rel);
}
await mapPool(allForHash, 12, async (row) => {
  const abs = absForPath.get(row);
  if (!abs) throw new Error("missing abs for " + row.path);
  row.sha256 = await hashFile(abs);
});
for (const row of [...docs, ...outEntries, ...cache, ...Object.values(externalEntries).flatMap((x) => x.entries)]) {
  if (row.kind === "dir") row.sha256 = null;
}

const files = {};
function add(name, entries, keys) {
  files[name] = toJsonl(entries, keys);
}
add("docs-incidents.jsonl", contentOf(docs), CONTENT_KEYS);
add("docs-incidents-perms.jsonl", docs, PERM_KEYS);
add("out.jsonl", contentOf(outEntries), CONTENT_KEYS);
add("out-perms.jsonl", outEntries, PERM_KEYS);
add("cache_forge.jsonl", contentOf(cache), CONTENT_KEYS);
add("cache_forge-perms.jsonl", cache, PERM_KEYS);
for (const [name, item] of Object.entries(externalEntries)) {
  add(name + ".jsonl", contentOf(item.entries), CONTENT_KEYS);
  add(name + "-perms.jsonl", item.entries, PERM_KEYS);
}

const cacheAbsent = { path: join(WT, "cache"), exists: false, error: "ENOENT" };
try {
  await lstat(join(WT, "cache"));
  cacheAbsent.exists = true;
  cacheAbsent.error = null;
} catch (e) {
  cacheAbsent.error = e.code || String(e);
}

const host = [];
async function addSymlink(rel) {
  const abs = join(WT, rel);
  guard(abs);
  const st = await lstat(abs);
  if (!st.isSymbolicLink()) {
    host.push({ path: rel, kind: kindOf(st), openedTarget: false, note: "not a symlink" });
    return;
  }
  const target = await readlink(abs);
  host.push({
    path: rel,
    kind: "symlink",
    perm: perm(st),
    st_mode: st.mode,
    size: st.size,
    ino: st.ino,
    target,
    sha256: sha256Bytes(Buffer.from(target, "utf8")),
    openedTarget: false,
  });
}
const top = await readdir(WT);
for (const name of top) {
  const st = await lstat(join(WT, name));
  if (st.isSymbolicLink()) await addSymlink(name);
}
const libNames = await readdir(join(WT, "lib"));
for (const name of libNames) {
  const rel = "lib/" + name;
  const st = await lstat(join(WT, rel));
  if (st.isSymbolicLink()) await addSymlink(rel);
}
const authorities = [
  "/Users/cyotee/Projects/indexedex/docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md",
  "/Users/cyotee/Projects/indexedex/docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_DRAFT_PRD.md",
  "/Users/cyotee/Projects/indexedex/docs/incidents/2026-09-16-dtf-recovery/ENTITLEMENT_LEDGER_PROVENANCE.md",
  "/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/requirements-coverage-0856a5c5.md",
];
const authorityRows = [];
for (const abs of authorities) {
  guard(abs);
  const st = await lstat(abs);
  const buf = await Bun.file(abs).bytes();
  authorityRows.push({
    path: abs,
    kind: kindOf(st),
    perm: perm(st),
    st_mode: st.mode,
    size: st.size,
    bytes: buf.length,
    sha256: sha256Bytes(buf),
    openedAsRegularFile: st.isFile(),
  });
}

const indexes = [];
async function addIndex(abs, own) {
  guard(abs);
  const st = await lstat(abs);
  const buf = await Bun.file(abs).bytes();
  indexes.push({
    path: abs,
    foreign: !own,
    own,
    perm: perm(st),
    st_mode: st.mode,
    size: st.size,
    bytes: buf.length,
    sha256: sha256Bytes(buf),
  });
}
if (await exists(join(COMMON, "index"))) await addIndex(join(COMMON, "index"), false);
const wtNames = await readdir(join(COMMON, "worktrees"));
wtNames.sort();
for (const name of wtNames) {
  const index = join(COMMON, "worktrees", name, "index");
  if (await exists(index)) await addIndex(index, name === OWN);
}

const refs = [];
async function addRefFile(abs, rel) {
  guard(abs);
  const st = await lstat(abs);
  if (st.isSymbolicLink()) {
    const target = await readlink(abs);
    refs.push({ path: rel, kind: "symlink", perm: perm(st), st_mode: st.mode, size: st.size, sha256: sha256Bytes(Buffer.from(target, "utf8")), target });
    return;
  }
  if (st.isDirectory()) {
    const names = await readdir(abs);
    for (const name of names) await addRefFile(join(abs, name), rel + "/" + name);
    return;
  }
  if (!st.isFile()) {
    refs.push({ path: rel, kind: kindOf(st), perm: perm(st), st_mode: st.mode, size: st.size, sha256: null, target: null });
    return;
  }
  const buf = await Bun.file(abs).bytes();
  refs.push({ path: rel, kind: "file", perm: perm(st), st_mode: st.mode, size: st.size, sha256: sha256Bytes(buf), target: null, bytes: buf.length });
}
await addRefFile(join(COMMON, "refs"), ".git/refs");
for (const extra of ["HEAD", "packed-refs"]) {
  const abs = join(COMMON, extra);
  if (await exists(abs)) await addRefFile(abs, ".git/" + extra);
}
for (const name of wtNames) {
  const abs = join(COMMON, "worktrees", name, "HEAD");
  if (await exists(abs)) await addRefFile(abs, ".git/worktrees/" + name + "/HEAD");
}

const showRef = await git(["show-ref"]);
const status = await git(["status", "--short", "--ignore-submodules=all"]);
const diff = await git(["diff", "--ignore-submodules=all"]);
const diffStat = await git(["diff", "--stat", "--ignore-submodules=all"]);
const cached = await git(["diff", "--cached", "--ignore-submodules=all"]);
const head = await git(["rev-parse", "HEAD"]);
const parents = await git(["rev-list", "--parents", "-n", "1", "HEAD"]);
const branch = await git(["branch", "--show-current"]);
const ls = await git(["ls-files", "-s", "--", "docs/incidents/2026-09-16-dtf-recovery/migration/operator-runbook.md", "scripts/recovery/dtf-migration/cli.ts", "lib/crane"]);
const autocrlf = await git(["config", "--get", "core.autocrlf"]);
const gpgsign = await git(["config", "--get", "commit.gpgsign"]);
const gpgProgram = await git(["config", "--get", "gpg.program"]);
const upstream = await git(["rev-parse", "--abbrev-ref", "@{upstream}"]);

async function checkSeal(relDir) {
  const base = join(WT, relDir);
  const sealPath = join(base, "seal.json");
  const raw = await Bun.file(sealPath).bytes();
  const seal = JSON.parse(new TextDecoder().decode(raw));
  const members = [];
  for (const [key, value] of Object.entries(seal)) {
    if (value && typeof value === "object" && typeof value.path === "string" && typeof value.sha256 === "string" && typeof value.bytes === "number") {
      const abs = join(base, value.path);
      const buf = await Bun.file(abs).bytes();
      const sha = sha256Bytes(buf);
      members.push({
        key,
        path: value.path,
        expectedBytes: value.bytes,
        actualBytes: buf.length,
        expectedSha256: value.sha256,
        actualSha256: sha,
        match: sha === value.sha256 && buf.length === value.bytes,
      });
    }
  }
  return { sealPath, bytes: raw.length, sha256: sha256Bytes(raw), members };
}
const seals = [];
for (const rel of [
  "docs/incidents/2026-09-16-dtf-recovery/migration/data-candidates/verification-r2",
  "docs/incidents/2026-09-16-dtf-recovery/migration/data-candidates/implementation-r2",
  "docs/incidents/2026-09-16-dtf-recovery/migration/data-candidates/verification",
  "docs/incidents/2026-09-16-dtf-recovery/migration/data-candidates/implementation",
]) {
  seals.push(await checkSeal(rel));
}

const report = await Bun.file(join(WT, "docs/incidents/2026-09-16-dtf-recovery/migration/data-candidates/verification-r2/report.md")).bytes();
const reportSha = sha256Bytes(report);

let foundryCache = null;
const foundry = await Bun.file(join(WT, "foundry.toml")).text();
const cacheLine = foundry.split("\n").find((line) => line.includes("cache_path") || line.includes("cache "));
foundryCache = cacheLine || null;

for (const row of allForHash) if (!row.sha256) throw new Error("unhashed file " + row.path);
if (await exists(COMMIT_DIR)) throw new Error("commit/ appeared during capture");

const summary = {
  capturedBeforeStaging: true,
  commitDirExisted: false,
  head: head.stdout.trim(),
  parents: parents.stdout.trim(),
  branch: branch.stdout.trim(),
  reportBytes: report.length,
  reportSha256: reportSha,
  acceptedPaths: 10,
  frozenSourceIdentities: 62,
  cacheAbsent,
  foundryCacheLine: foundryCache,
  counts: {
    docsContent: contentOf(docs).length,
    docsPerms: docs.length,
    outContent: contentOf(outEntries).length,
    outPerms: outEntries.length,
    cacheForgeContent: contentOf(cache).length,
    cacheForgePerms: cache.length,
    originalRecoveryContent: contentOf(externalEntries["original-recovery"].entries).length,
    originalRecoveryPerms: externalEntries["original-recovery"].entries.length,
    originalPreExploitContent: contentOf(externalEntries["original-pre-exploit"].entries).length,
    originalPreExploitPerms: externalEntries["original-pre-exploit"].entries.length,
    recoveredContent: contentOf(externalEntries["recovered-input"].entries).length,
    recoveredPerms: externalEntries["recovered-input"].entries.length,
    indexes: indexes.length,
    foreignIndexes: indexes.filter((x) => x.foreign).length,
    refs: refs.length,
    hostSymlinks: host.length,
    authorities: authorityRows.length,
    sealMemberMismatches: seals.reduce((n, s) => n + s.members.filter((m) => !m.match).length, 0),
  },
  git: {
    statusExit: status.exit,
    diffExit: diff.exit,
    diffBytes: Buffer.byteLength(diff.stdout),
    cachedExit: cached.exit,
    cachedBytes: Buffer.byteLength(cached.stdout),
    showRefExit: showRef.exit,
    showRefBytes: Buffer.byteLength(showRef.stdout),
    autocrlfExit: autocrlf.exit,
    autocrlf: autocrlf.stdout.trim(),
    gpgsignExit: gpgsign.exit,
    gpgsign: gpgsign.stdout.trim(),
    gpgProgramExit: gpgProgram.exit,
    gpgProgram: gpgProgram.stdout.trim(),
    upstreamExit: upstream.exit,
    upstreamStderr: upstream.stderr.trim(),
  },
  testedManifestsOmitModes: true,
};
const fileHashes = {};
for (const [name, text] of Object.entries(files)) {
  await writeFile(join(OUT, name), text);
  fileHashes[name] = { bytes: Buffer.byteLength(text), sha256: sha256Bytes(Buffer.from(text)) };
}
await writeFile(join(OUT, "source-bindings.json"), JSON.stringify(binding, null, 2) + "\n");
await writeFile(join(OUT, "frozen-source-modes.json"), JSON.stringify(frozen, null, 2) + "\n");
await writeFile(join(OUT, "host-deps.json"), JSON.stringify(host, null, 2) + "\n");
await writeFile(join(OUT, "authorities.json"), JSON.stringify(authorityRows, null, 2) + "\n");
await writeFile(join(OUT, "indexes.json"), JSON.stringify(indexes, null, 2) + "\n");
await writeFile(join(OUT, "refs.jsonl"), toJsonl(refs, ["path", "kind", "perm", "st_mode", "size", "sha256", "target"]));
await writeFile(join(OUT, "show-ref.txt"), showRef.stdout);
await writeFile(join(OUT, "status.txt"), status.stdout);
await writeFile(join(OUT, "diff.patch"), diff.stdout);
await writeFile(join(OUT, "diff-stat.txt"), diffStat.stdout);
await writeFile(join(OUT, "cached.diff"), cached.stdout);
await writeFile(join(OUT, "ls-files.txt"), ls.stdout);
await writeFile(join(OUT, "seal-check.json"), JSON.stringify(seals, null, 2) + "\n");
await writeFile(join(OUT, "cache-absent.json"), JSON.stringify(cacheAbsent, null, 2) + "\n");
await writeFile(join(OUT, "roots.json"), JSON.stringify({
  worktree: WT,
  originalRecoveryParent: "/Users/cyotee/Projects/indexedex/docs/incidents",
  originalPreExploitParent: "/Users/cyotee/Projects/indexedex/docs/incidents",
  recoveredParent: "/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration",
  gitCommon: COMMON,
  ownWorktreeGitName: OWN,
  held09NotOpened: HELD09,
}, null, 2) + "\n");
summary.inventoryHashes = fileHashes;
await writeFile(join(OUT, "summary.json"), JSON.stringify(summary, null, 2) + "\n");
await writeFile(join(OUT, "CAPTURE_COMPLETE"), summary.head + "\n");
console.error("CAPTURE_COMPLETE");
console.log("CAPTURE_COMPLETE");
