import { runSequences } from "./sequences.mjs";
import { runCompatibility } from "./compatibility.mjs";

export const runVerification = () => ({ sequences: runSequences(), compatibility: runCompatibility() });

if (import.meta.main) {
  console.log(JSON.stringify(runVerification(), (_, value) => typeof value === "bigint" ? value.toString() : value, 2));
}
