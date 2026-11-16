import assert from "node:assert/strict";
import { readFile, readdir, stat, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { resolve } from "node:path";
import { z } from "zod";

export const root = process.cwd();
export const hex = z.string().regex(/^0x(?:[0-9a-f]{2})*$/i);
export const address = z.string().regex(/^0x[0-9a-f]{40}$/i);
export const hash = z.string().regex(/^0x[0-9a-f]{64}$/i);
export const uint = z.string().regex(/^(0|[1-9][0-9]*)$/);
export const binding = z.object({ path: z.string(), bytes: z.number(), sha256: z.string() });
export async function json(path: string): Promise<unknown> {
  return JSON.parse(await readFile(path, "utf8"));
}
export function sha(bytes: string | Uint8Array): string {
  return createHash("sha256").update(bytes).digest("hex");
}
export async function bind(path: string) {
  const bytes = await readFile(path);
  return { path, bytes: bytes.length, sha256: sha(bytes), mode: (await stat(path)).mode & 0o777 };
}
export async function files(path: string): Promise<string[]> {
  const result: string[] = [];
  for (const entry of await readdir(path, { withFileTypes: true })) {
    const child = resolve(path, entry.name);
    if (entry.isDirectory()) result.push(...await files(child));
    else if (entry.isFile()) result.push(child);
  }
  return result.sort();
}
export async function save(path: string, value: unknown) {
  const owned = resolve(root, "docs/incidents/2026-09-16-dtf-recovery/migration/earlier-receipt/verification/");
  assert(resolve(path).startsWith(`${owned}/`));
  await writeFile(path, `${JSON.stringify(value, (_, v: unknown) => typeof v === "bigint" ? v.toString() : v, 2)}\n`, { flag: "wx" });
}
export function required<T>(value: T | null | undefined): T {
  if (value === undefined || value === null) throw new TypeError("Required evidence value is absent");
  return value;
}
export function canonical(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`;
  if (value !== null && typeof value === "object") {
    return `{${Object.entries(value).sort(([a], [b]) => a.localeCompare(b))
      .map(([k, v]) => `${JSON.stringify(k)}:${canonical(v)}`).join(",")}}`;
  }
  return required(JSON.stringify(value));
}
