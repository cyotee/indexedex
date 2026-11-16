import { witnesses } from "./witnesses.mjs";
import { callers, rejectedBoundaries, consumerUnits, rawBudgets } from "./callers.mjs";

export function run() {
  return { classification: "Finite integer/caller model, not SUT acceptance",
    accounting: witnesses(), callers: callers(), raw: rawBudgets(),
    consumers: consumerUnits(), negatives: rejectedBoundaries() };
}
if (import.meta.main) {
  console.log(JSON.stringify(run(), (_, value) => typeof value === "bigint" ? value.toString() : value, 2));
}
