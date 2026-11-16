import { link, mkdir, open, readFile, readdir, unlink } from "node:fs/promises";
import { join, resolve } from "node:path";
import { randomUUID } from "node:crypto";
import { z } from "zod";
import { canonical, fingerprint } from "./provenance.js";
import { completion, ExecutionError, intent } from "./execution-schema.js";
import type { Completion, Intent } from "./execution-schema.js";

async function durableCreate(path: string, value: unknown): Promise<void> {
  const temporary = `${path}.${randomUUID()}.pending`;
  const file = await open(temporary, "wx", 0o600);
  try {
    await file.writeFile(`${canonical(value)}\n`);
    await file.sync();
  } finally {
    await file.close();
  }
  try { await link(temporary, path); } finally { await unlink(temporary); }
}

export class Journal {
  private constructor(readonly directory: string, readonly domainHash: string, readonly operatorRoot: string) {}

  static async inspect(directory: string, domain: unknown): Promise<Journal | undefined> {
    let previous: unknown;
    try { previous = JSON.parse(await readFile(join(directory, "domain.json"), "utf8")); }
    catch (error) {
      if (error instanceof Error && "code" in error && error.code === "ENOENT") return undefined;
      throw error;
    }
    if (canonical(previous) !== canonical(domain)) throw new ExecutionError("DOMAIN", "checkpoint domain changed");
    return new Journal(directory, fingerprint(canonical(domain)), directory);
  }

  static async acquire(directory: string, domain: unknown, operatorRoot = directory): Promise<Journal> {
    await mkdir(directory, { recursive: true, mode: 0o700 });
    const domainHash = fingerprint(canonical(domain));
    const lockPath = join(directory, "lock");
    try {
      await durableCreate(lockPath, { pid: process.pid });
    } catch (error) {
      if (!(error instanceof Error) || !("code" in error) || error.code !== "EEXIST") throw error;
      const old = z.object({ pid: z.number().int().positive() }).strict().parse(JSON.parse(await readFile(lockPath, "utf8")));
      try {
        process.kill(old.pid, 0);
      } catch (cause) {
        if (!(cause instanceof Error) || !("code" in cause) || cause.code !== "ESRCH") throw cause;
        // Only a proven dead writer can relinquish this exclusive local lock.
        await unlink(lockPath);
        return Journal.acquire(directory, domain, operatorRoot);
      }
      throw new ExecutionError("LOCK", "checkpoint has a live writer");
    }
    const journal = new Journal(directory, domainHash, operatorRoot);
    try {
      const names = await readdir(directory);
      if (names.includes("domain.json")) {
        const previous: unknown = JSON.parse(await readFile(join(directory, "domain.json"), "utf8"));
        if (canonical(previous) !== canonical(domain)) throw new ExecutionError("DOMAIN", "checkpoint domain changed");
      } else {
        await durableCreate(join(directory, "domain.json"), domain);
      }
      if (names.includes("terminal.json")) {
        const terminal = z.object({ state: z.enum(["complete", "blocked"]), domainHash: z.string(),
          operationIds: z.array(z.string()) }).strict().parse(JSON.parse(await readFile(join(directory, "terminal.json"), "utf8")));
        if (terminal.domainHash !== domainHash || terminal.state === "blocked") {
          throw new ExecutionError("STATE", "terminal blocked checkpoint requires a new immutable execution");
        }
      }
      const activePath = join(operatorRoot, "active-execution.json");
      const active = { directory: resolve(directory), domainHash };
      try { await durableCreate(activePath, active); }
      catch (error) {
        if (!(error instanceof Error) || !("code" in error) || error.code !== "EEXIST") throw error;
        const existing: unknown = JSON.parse(await readFile(activePath, "utf8"));
        if (canonical(existing) !== canonical(active)) {
          throw new ExecutionError("LOCK", "second active execution under operator root");
        }
      }
      await journal.syncDirectory();
      return journal;
    } catch (error) {
      await journal.close();
      throw error;
    }
  }

  async syncDirectory(): Promise<void> {
    const directory = await open(this.directory, "r");
    try { await directory.sync(); } finally { await directory.close(); }
  }

  async intents(): Promise<readonly Intent[]> {
    const names = (await readdir(this.directory)).filter((name) => name.endsWith(".intent.json"));
    const records = await Promise.all(names.map(async (name) => {
      const record = intent.parse(JSON.parse(await readFile(join(this.directory, name), "utf8")));
      if (name !== `${record.id}.intent.json`) throw new ExecutionError("INTENT", "intent filename differs from operation identity");
      return record;
    }));
    for (const record of records) {
      if (record.domainHash !== this.domainHash
        || !names.includes(`${record.id}.intent.json`)) throw new ExecutionError("DOMAIN", "foreign intent");
    }
    if (new Set(records.map((r) => r.nonce)).size !== records.length) throw new ExecutionError("INTENT", "multiple intents claim the same nonce");
    return records.sort((a, b) => BigInt(a.nonce) < BigInt(b.nonce) ? -1 : 1);
  }

  async persistIntent(record: Intent): Promise<void> {
    if (record.domainHash !== this.domainHash) throw new ExecutionError("DOMAIN", "foreign intent");
    await durableCreate(join(this.directory, `${record.id}.intent.json`), record);
    await this.syncDirectory();
  }

  async completed(record: Intent): Promise<Completion | undefined> {
    const name = `${record.id}.receipt.json`;
    if (!(await readdir(this.directory)).includes(name)) return undefined;
    const result = completion.parse(JSON.parse(await readFile(join(this.directory, name), "utf8")));
    if (result.intentHash !== fingerprint(canonical(record))
      || result.receipt.transactionHash !== record.transactionHash) {
      throw new ExecutionError("INTENT", "receipt does not bind this exact signed intent");
    }
    return result;
  }

  async complete(record: Intent, result: Completion): Promise<void> {
    if (result.intentHash !== fingerprint(canonical(record))) throw new ExecutionError("INTENT", "wrong intent receipt");
    await durableCreate(join(this.directory, `${record.id}.receipt.json`), result);
    await this.syncDirectory();
  }

  async finish(operationIds: readonly string[]): Promise<void> {
    const records = await this.intents();
    if (canonical(records.map((r) => r.id).sort()) !== canonical([...operationIds].sort())) {
      throw new ExecutionError("STATE", "terminal execution is missing signed operations");
    }
    for (const record of records) if (!await this.completed(record)) throw new ExecutionError("STATE", "terminal execution has unresolved intent");
    const result = { state: "complete", domainHash: this.domainHash, operationIds };
    const path = join(this.directory, "terminal.json");
    try { await durableCreate(path, result); }
    catch (error) {
      if (!(error instanceof Error) || !("code" in error) || error.code !== "EEXIST") throw error;
      if (canonical(JSON.parse(await readFile(path, "utf8"))) !== canonical(result)) throw new ExecutionError("STATE", "terminal journal differs");
    }
    await unlink(join(this.operatorRoot, "active-execution.json"));
    await this.syncDirectory();
  }

  async blocked(error: unknown): Promise<void> {
    await durableCreate(join(this.directory, `${randomUUID()}.blocked.json`), {
      state: "blocked", domainHash: this.domainHash,
      code: error instanceof ExecutionError ? error.code : "INPUT",
      message: error instanceof ExecutionError ? error.message : "execution failed; original intent remains authoritative",
    });
    // No signed intent means there is no possible in-flight transaction to
    // reconcile. Close this immutable attempt and allow a new manifest/root child.
    // Signed uncertainty deliberately retains the active execution reservation.
    if ((await this.intents()).length === 0) {
      if (!(await readdir(this.directory)).includes("terminal.json")) {
        await durableCreate(join(this.directory, "terminal.json"), {
          state: "blocked", domainHash: this.domainHash, operationIds: [],
        });
      }
      await unlink(join(this.operatorRoot, "active-execution.json"));
    }
    await this.syncDirectory();
  }

  async close(): Promise<void> {
    await unlink(join(this.directory, "lock"));
    await this.syncDirectory();
  }
}
