import { readdir, lstat, readlink, mkdir, writeFile, access } from "node:fs/promises";
import { join } from "node:path";

const WT = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-25-full-hermetic";
const COMMON = "/Users/cyotee/Projects/indexedex/.git";
const OWN_WT_GIT = join(COMMON, "worktrees/dtf-migration-phase-25-full-hermetic");
const HELD09 = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-09-deployment-gas";
const OUT = "/tmp/phase25-full-hermetic-precommit";
const ACCEPTED = "e8869bc93a199c7c35c97612b804cbb5fde94ef4df1c5661463670e0e0954fc1";
const SRC = "test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVaultDFPkg_Deploy.t.sol";
const EV = "docs/incidents/2026-09-16-dtf-recovery/migration/full-hermetic";

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

function sha256Bytes(buf) {
  return new Bun.CryptoHasher("sha256").update(buf).digest("hex");
}

async function mapPool(items, limit, fn) {
  const out = new Array(items.length);
  let next = 0;
  let hashed = 0;
  async function worker() {
    while (true) {
      const idx = next++;
      if (idx >= items.length) return;
      out[idx] = await fn(items[idx], idx);
      hashed++;
      if (hashed % 2000 === 0) console.error("hashed", hashed, "/", items.length);
    }
  }
  const n = Math.min(limit, Math.max(items.length, 1));
  await Promise.all(Array.from({ length: n }, () => worker()));
  return out;
}

async function collect(absRoot, relRoot, includeDirs) {
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
    };
    if (st.isSymbolicLink()) {
      row.target = await readlink(abs);
      row.sha256 = sha256Bytes(Buffer.from(row.target, "utf8"));
      entries.push(row);
      return;
    }
    if (st.isDirectory()) {
      if (includeDirs) entries.push(row);
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

async function fillHashes(entries) {
  const files = entries.filter((e) => e.kind === "file");
  await mapPool(files, 16, async (row) => {
    row.sha256 = await hashFile(join(WT, row.path));
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

async function exists(p) {
  try {
    await access(p);
    return true;
  } catch {
    return false;
  }
}

async function git(args) {
  const r = await Bun.$`git -C ${WT} --no-pager ${args}`.env(gitEnv).nothrow();
  return {
    args,
    exit: r.exitCode,
    stdout: r.stdout.toString(),
    stderr: r.stderr.toString(),
  };
}

await mkdir(OUT, { recursive: true });
if (await exists(join(WT, "docs/incidents/2026-09-16-dtf-recovery/migration/full-hermetic/commit"))) {
  throw new Error("commit/ already exists; capture must precede it");
}

const srcAbs = join(WT, SRC);
const srcStat = await lstat(srcAbs);
const srcBytes = await Bun.file(srcAbs).bytes();
const srcSha = sha256Bytes(srcBytes);
if (srcSha !== ACCEPTED || srcBytes.length !== 17776 || srcStat.mode !== 33188) {
  throw new Error("source binding mismatch " + JSON.stringify({ srcSha, bytes: srcBytes.length, mode: srcStat.mode }));
}

console.error("collecting docs/incidents");
const docsPerms = await collect(join(WT, "docs/incidents"), "docs/incidents", true);
console.error("docs entries", docsPerms.length);
console.error("collecting out");
const outPerms = await collect(join(WT, "out"), "out", true);
console.error("out entries", outPerms.length);
console.error("collecting cache_forge");
const cachePerms = await collect(join(WT, "cache_forge"), "cache_forge", true);
console.error("cache entries", cachePerms.length);

const contentEntries = [...docsPerms, ...outPerms, ...cachePerms].filter((e) => e.kind !== "dir");
console.error("hashing content files", contentEntries.filter((e) => e.kind === "file").length);
await fillHashes(contentEntries);
for (const row of [...docsPerms, ...outPerms, ...cachePerms]) {
  if (row.kind === "dir") row.sha256 = null;
}

function subset(entries, prefix, includeDirs) {
  return entries.filter((e) => (e.path === prefix || e.path.startsWith(prefix + "/")) && (includeDirs || e.kind !== "dir"));
}

const docsContent = subset(docsPerms, "docs/incidents", false);
const outContent = subset(outPerms, "out", false);
const cacheContent = subset(cachePerms, "cache_forge", false);

const files = {
  "docs-incidents.jsonl": toJsonl(docsContent, CONTENT_KEYS),
  "docs-incidents-perms.jsonl": toJsonl(docsPerms, PERM_KEYS),
  "out.jsonl": toJsonl(outContent, CONTENT_KEYS),
  "out-perms.jsonl": toJsonl(outPerms, PERM_KEYS),
  "cache_forge.jsonl": toJsonl(cacheContent, CONTENT_KEYS),
  "cache_forge-perms.jsonl": toJsonl(cachePerms, PERM_KEYS),
};

console.error("hashing indexes and refs");
const indexPaths = [join(COMMON, "index")];
for (const name of await readdir(join(COMMON, "worktrees"))) {
  const idx = join(COMMON, "worktrees", name, "index");
  if (await exists(idx)) indexPaths.push(idx);
}
const indexes = [];
for (const p of indexPaths) {
  guard(p);
  const st = await lstat(p);
  const bytes = await Bun.file(p).bytes();
  indexes.push({
    path: p,
    foreign: !p.includes("/worktrees/dtf-migration-phase-25-full-hermetic/"),
    own: p.includes("/worktrees/dtf-migration-phase-25-full-hermetic/"),
    perm: perm(st),
    st_mode: st.mode,
    size: bytes.length,
    sha256: sha256Bytes(bytes),
  });
}
indexes.sort((a, b) => Buffer.compare(Buffer.from(a.path), Buffer.from(b.path)));

async function walkFiles(abs, relBase) {
  const rows = [];
  async function rec(absPath, rel) {
    guard(absPath);
    const st = await lstat(absPath);
    if (st.isDirectory()) {
      for (const name of await readdir(absPath)) await rec(join(absPath, name), rel + "/" + name);
      return;
    }
    if (!st.isFile()) return;
    const bytes = await Bun.file(absPath).bytes();
    rows.push({
      path: rel,
      perm: perm(st),
      st_mode: st.mode,
      size: bytes.length,
      sha256: sha256Bytes(bytes),
    });
  }
  if (await exists(abs)) await rec(abs, relBase);
  rows.sort(cmpPath);
  return rows;
}

const refRows = await walkFiles(join(COMMON, "refs"), ".git/refs");
const extraRefs = [join(COMMON, "HEAD"), join(COMMON, "packed-refs"), join(OWN_WT_GIT, "HEAD"), join(OWN_WT_GIT, "ORIG_HEAD")];
for (const name of await readdir(join(COMMON, "worktrees"))) {
  extraRefs.push(join(COMMON, "worktrees", name, "HEAD"));
}
for (const p of extraRefs) {
  if (!(await exists(p))) continue;
  guard(p);
  const st = await lstat(p);
  if (!st.isFile()) continue;
  const bytes = await Bun.file(p).bytes();
  refRows.push({
    path: p.startsWith(COMMON) ? ".git" + p.slice(COMMON.length) : p,
    perm: perm(st),
    st_mode: st.mode,
    size: bytes.length,
    sha256: sha256Bytes(bytes),
  });
}
refRows.sort(cmpPath);

const hostCandidates = [];
for (const name of await readdir(WT)) {
  const abs = join(WT, name);
  const st = await lstat(abs);
  if (st.isSymbolicLink()) hostCandidates.push({ abs, rel: name, st });
}
for (const name of await readdir(join(WT, "lib"))) {
  const abs = join(WT, "lib", name);
  const st = await lstat(abs);
  if (st.isSymbolicLink()) hostCandidates.push({ abs, rel: "lib/" + name, st });
}
const hostDeps = [];
for (const item of hostCandidates) {
  const target = await readlink(item.abs);
  hostDeps.push({
    path: item.rel,
    kind: "symlink",
    perm: perm(item.st),
    st_mode: item.st.mode,
    size: item.st.size,
    ino: item.st.ino,
    target,
    sha256: sha256Bytes(Buffer.from(target, "utf8")),
    openedTarget: false,
  });
}
hostDeps.sort(cmpPath);

const showRef = await git(["show-ref"]);
const status = await git(["status", "--short", "--ignore-submodules=all"]);
const nameStatus = await git(["diff", "--ignore-submodules=all", "--name-status"]);
const cached = await git(["diff", "--cached", "--ignore-submodules=all", "--name-status"]);
const lsFiles = await git(["ls-files", "-s", "--", "lib", "node_modules"]);
const checkIgnore = await git(["check-ignore", "-v", "lib/crane", "node_modules"]);

const lockNames = [
  "index.lock",
  "MERGE_HEAD",
  "CHERRY_PICK_HEAD",
  "REBASE_HEAD",
  "rebase-apply",
  "rebase-merge",
];
const locks = {};
for (const name of lockNames) {
  locks["common/" + name] = await exists(join(COMMON, name));
  locks["own/" + name] = await exists(join(OWN_WT_GIT, name));
}

const lsof = await Bun.$`lsof -nP -iTCP:18574 -sTCP:LISTEN`.nothrow();
const ps = await Bun.$`ps -ax -o pid=,command=`.nothrow();
const procLines = ps.stdout.toString().split("\n").filter((line) => /\b(forge|anvil|solar)\b/.test(line) && !line.includes("phase25-full-hermetic-precommit-capture"));

const sealPath = join(WT, EV, "seal.json");
const sealRaw = await Bun.file(sealPath).bytes();
const seal = JSON.parse(new TextDecoder().decode(sealRaw));
const sealMembers = [];
for (const member of seal.members) {
  const abs = join(WT, EV, member.path);
  guard(abs);
  const st = await lstat(abs);
  const bytes = await Bun.file(abs).bytes();
  const sha = sha256Bytes(bytes);
  sealMembers.push({
    path: member.path,
    declaredBytes: member.bytes,
    actualBytes: bytes.length,
    declaredSha256: member.sha256,
    actualSha256: sha,
    declaredMode: member.mode,
    actualMode: st.mode,
    match: member.bytes === bytes.length && member.sha256 === sha && member.mode === st.mode,
  });
}

const srcEnd = sha256Bytes(await Bun.file(srcAbs).bytes());
const summary = {
  capturedBeforeCommitDir: true,
  capturedBeforeStaging: true,
  source: { path: SRC, bytes: srcBytes.length, sha256: srcSha, mode: srcStat.mode, sha256AfterWalk: srcEnd, acceptedMatch: srcSha === ACCEPTED && srcEnd === ACCEPTED },
  counts: {
    docsContent: docsContent.length,
    docsPerms: docsPerms.length,
    outContent: outContent.length,
    outPerms: outPerms.length,
    cacheContent: cacheContent.length,
    cachePerms: cachePerms.length,
    indexes: indexes.length,
    foreignIndexes: indexes.filter((i) => i.foreign).length,
    ownIndexes: indexes.filter((i) => i.own).length,
    refs: refRows.length,
    hostDeps: hostDeps.length,
    sealMembers: sealMembers.length,
    sealMismatches: sealMembers.filter((m) => !m.match).length,
  },
  aggregatesAreNotSubstitutes: true,
  aggregates: {},
  git: {
    showRefExit: showRef.exit,
    showRefBytes: Buffer.byteLength(showRef.stdout),
    statusExit: status.exit,
    status: status.stdout,
    nameStatus: nameStatus.stdout,
    cached: cached.stdout,
    lsFilesExit: lsFiles.exit,
    lsFiles: lsFiles.stdout,
    checkIgnoreExit: checkIgnore.exit,
    checkIgnore: checkIgnore.stdout,
    checkIgnoreErr: checkIgnore.stderr,
  },
  locks,
  processes: {
    lsofExit: lsof.exitCode,
    lsof: lsof.stdout.toString(),
    forgeAnvilSolar: procLines,
  },
  held09WorktreeOpened: false,
};
for (const [name, text] of Object.entries(files)) {
  const buf = Buffer.from(text, "utf8");
  await writeFile(join(OUT, name), buf);
  summary.aggregates[name] = { bytes: buf.length, sha256: sha256Bytes(buf), lines: text.length === 0 ? 0 : text.split("\n").length - 1 };
}
const indexText = JSON.stringify(indexes, null, 2) + "\n";
const refText = toJsonl(refRows, ["path", "perm", "st_mode", "size", "sha256"]);
const hostText = JSON.stringify(hostDeps, null, 2) + "\n";
await writeFile(join(OUT, "indexes.json"), indexText);
await writeFile(join(OUT, "refs.jsonl"), refText);
await writeFile(join(OUT, "host-deps.json"), hostText);
await writeFile(join(OUT, "show-ref.txt"), showRef.stdout);
await writeFile(join(OUT, "processes.txt"), `lsof_exit=${lsof.exitCode}\n${lsof.stdout.toString()}${lsof.stderr.toString()}\n---\n${procLines.join("\n")}\n`);
await writeFile(join(OUT, "seal-check.json"), JSON.stringify({ sealBytes: sealRaw.length, sealSha256: sha256Bytes(sealRaw), members: sealMembers }, null, 2) + "\n");
summary.aggregates["indexes.json"] = { bytes: Buffer.byteLength(indexText), sha256: sha256Bytes(Buffer.from(indexText)), count: indexes.length };
summary.aggregates["refs.jsonl"] = { bytes: Buffer.byteLength(refText), sha256: sha256Bytes(Buffer.from(refText)), lines: refText.length === 0 ? 0 : refText.split("\n").length - 1 };
summary.aggregates["host-deps.json"] = { bytes: Buffer.byteLength(hostText), sha256: sha256Bytes(Buffer.from(hostText)) };
summary.aggregates["show-ref.txt"] = { bytes: Buffer.byteLength(showRef.stdout), sha256: sha256Bytes(Buffer.from(showRef.stdout)) };
await writeFile(join(OUT, "summary.json"), JSON.stringify(summary, null, 2) + "\n");
await writeFile(join(OUT, "DONE"), "ok\n");
console.log(JSON.stringify(summary, null, 2));
