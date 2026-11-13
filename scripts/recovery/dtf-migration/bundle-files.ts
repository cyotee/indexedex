import { lstat, mkdir, readFile, readdir, realpath, writeFile } from "node:fs/promises";
import { dirname, isAbsolute, join, resolve } from "node:path";
import { z } from "zod";
import { canonical, fingerprint } from "./provenance.js";
import { bundleReference, PreparationError, sha256, uint } from "./schema.js";

const file = z.object({
  path: z.string().regex(/^data\/[0-9a-f]{64}$/), sha256, bytes: uint,
}).strict();
export const bundleManifest = z.object({
  version: z.literal("dtf-operator-bundle-v1"),
  originalBase: z.string().min(1),
  template: file.readonly(),
  files: z.array(file.extend({ originalPath: z.string().min(1) }).strict().readonly()).readonly(),
}).strict().readonly();
export type BundleReference = z.infer<typeof bundleReference>;
export type BundleManifest = z.infer<typeof bundleManifest>;
export type SourceFile = { readonly path: string; readonly sha256: string; readonly bytes: string };

function fail(message: string): never { throw new PreparationError("PROVENANCE", message); }
export function verifyBytes(raw: Uint8Array, expected: SourceFile): void {
  if (fingerprint(raw) !== expected.sha256 || String(raw.byteLength) !== expected.bytes) {
    fail(`bundle raw bytes differ: ${expected.path}`);
  }
}
async function regular(path: string): Promise<Buffer> {
  const stat = await lstat(path);
  if (!stat.isFile() || stat.isSymbolicLink()) fail(`bundle item is not a regular file: ${path}`);
  return readFile(path);
}

// Every declared item is read and authenticated before a template is used.
// Original locations below are lookup keys only, never filesystem fallbacks.
export async function readBundle(path: string, expected?: BundleReference) {
  const absolute = resolve(path);
  const root = dirname(absolute);
  if (await realpath(root) !== root) fail("bundle root or ancestor is a symlink");
  const raw = await regular(absolute);
  if (expected) verifyBytes(raw, expected);
  const manifest = bundleManifest.parse(JSON.parse(raw.toString("utf8")));
  if (!isAbsolute(manifest.originalBase) || resolve(manifest.originalBase) !== manifest.originalBase) {
    fail("bundle original base must be canonical absolute metadata");
  }
  const data = join(root, "data");
  if (!(await lstat(data)).isDirectory() || await realpath(data) !== data) fail("unsafe bundle data directory");
  const originals = new Map<string, SourceFile>();
  const contents = new Map<string, Buffer>();
  const reads = [{ path: absolute, bytes: String(raw.length), sha256: fingerprint(raw) }];
  for (const item of [manifest.template, ...manifest.files]) {
    if (item.path !== `data/${item.sha256}`) fail("bundle content name differs from digest");
    const physical = join(root, item.path);
    const bytes = await regular(physical);
    verifyBytes(bytes, item);
    reads.push({ path: physical, bytes: String(bytes.length), sha256: fingerprint(bytes) });
    const prior = contents.get(item.path);
    if (prior && !prior.equals(bytes)) fail("conflicting bundle file identity");
    contents.set(item.path, bytes);
  }
  for (const item of manifest.files) {
    if (!isAbsolute(item.originalPath) || resolve(item.originalPath) !== item.originalPath
      || originals.has(item.originalPath)) fail("duplicate or ambiguous bundle reference");
    originals.set(item.originalPath, item);
  }
  const actual = (await readdir(data)).sort();
  const declared = [...contents.keys()].map((p) => p.slice("data/".length)).sort();
  if (canonical(actual) !== canonical(declared)) fail("bundle data membership differs");
  const used = new Set<string>();
  const locate = (originalPath: string, base = manifest.originalBase) => {
    const key = resolve(base, originalPath);
    const item = originals.get(key);
    if (!item) fail(`missing declared bundle reference: ${key}`);
    used.add(key);
    return { ...item, path: join(root, item.path) };
  };
  const bytesOf = (originalPath: string, base = manifest.originalBase) => {
    const item = locate(originalPath, base);
    const raw = contents.get(`data/${item.sha256}`);
    if (!raw) fail("missing bundle bytes");
    return raw;
  };
  const template = contents.get(manifest.template.path);
  if (!template) fail("missing bundle template");
  return {
    manifest, root, template, reads,
    reference: { path: absolute, sha256: fingerprint(raw), bytes: String(raw.length) },
    locate, bytesOf,
    complete() {
      if (used.size !== originals.size) fail("unreferenced bundle item");
    },
  };
}

export async function writeBundle(options: {
  readonly templatePath: string;
  readonly sources: readonly SourceFile[];
  readonly output: string;
}) {
  const templatePath = resolve(options.templatePath);
  const template = await readFile(templatePath);
  const output = resolve(options.output);
  // Exclusive root creation prevents merging with partial or unrelated data.
  await mkdir(output, { recursive: false });
  await mkdir(join(output, "data"));
  const written = new Set<string>();
  const store = async (raw: Buffer) => {
    const sha256 = fingerprint(raw);
    const path = `data/${sha256}`;
    if (!written.has(path)) {
      await writeFile(join(output, path), raw, { flag: "wx" });
      written.add(path);
    }
    return { path, sha256, bytes: String(raw.length) };
  };
  const files = [];
  const originals = new Map<string, SourceFile>();
  for (const source of options.sources) {
    const path = resolve(source.path);
    const previous = originals.get(path);
    if (previous) {
      if (previous.sha256 !== source.sha256 || previous.bytes !== source.bytes) fail("conflicting source references");
      continue;
    }
    originals.set(path, source);
    const raw = await readFile(path);
    verifyBytes(raw, source);
    files.push({ ...await store(raw), originalPath: path });
  }
  const manifest = bundleManifest.parse({
    version: "dtf-operator-bundle-v1", originalBase: dirname(templatePath),
    template: await store(template), files,
  });
  const path = join(output, "bundle.json");
  await writeFile(path, `${canonical(manifest)}\n`, { flag: "wx" });
  return path;
}
