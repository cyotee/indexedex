import type { Plugin } from "@opencode-ai/plugin";
import { createCouncilGuard, observeTaskDefinition, reviewProfile, type CouncilClient, type CouncilRuntime } from "../support/research-council";

const reviewCouncil = (async ({ client, directory }: { client: CouncilClient; directory: string }) => {
  const runtime: CouncilRuntime = {};
  return {
    "tool.definition": async (input: { toolID: string }, output: { parameters?: unknown; jsonSchema?: unknown }) => {
      observeTaskDefinition(runtime, input, output);
    },
    "tool.execute.before": createCouncilGuard(client, directory, runtime, reviewProfile),
  };
}) satisfies Plugin;

export default reviewCouncil;
