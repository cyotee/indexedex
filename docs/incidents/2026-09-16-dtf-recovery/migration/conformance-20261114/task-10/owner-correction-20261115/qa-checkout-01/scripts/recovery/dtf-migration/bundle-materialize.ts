import { mkdir, writeFile } from "node:fs/promises";
import { join, resolve } from "node:path";
import { canonical } from "./provenance.js";
import { loadSavedBundle } from "./bundle.js";
import { prepareFile } from "./preparation.js";

// Generated files are fresh local templates/manifests, not original captures.
// The bundle's raw templates and source bytes remain unchanged.
export async function materializeBundle(path: string, directory: string) {
  const saved = await loadSavedBundle(path);
  const output = resolve(directory);
  await mkdir(output, { recursive: false });
  const save = async (name: string, value: unknown) => {
    const path = join(output, name);
    await writeFile(path, `${canonical(value)}\n`, { flag: "wx" });
    return path;
  };
  await save("bundle-access.json", {
    bundle: saved.reference, reads: saved.reads,
    scope: "Actual contained raw-file reads by this materialization; original paths were metadata only.",
  });
  switch (saved.kind) {
    case "authorities":
      return { kind: saved.kind, bundle: saved.reference, sources: saved.sources,
        rehearsalFundingEvidence: saved.rehearsalFundingEvidence };
    case "preparation": {
      const input = await save("input.json", saved.input);
      return { kind: saved.kind, input, bundle: saved.reference };
    }
    case "execution": {
      let preparedManifest: string | null = null;
      if (saved.input) {
        const input = await save("input.json", saved.input);
        await prepareFile(input, join(output, "prepared"));
        preparedManifest = join(output, "prepared/manifest.json");
      }
      const manifest = await save("execution.json", { ...saved.execution, preparedManifest });
      return { kind: saved.kind, manifest, bundle: saved.reference };
    }
  }
}
