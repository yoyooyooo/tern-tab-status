import { appendFileSync } from "node:fs";

const log = (event, detail = {}) => {
  const path = process.env.TERN_STATUS_VERIFY_PROVIDER_LOG;
  if (!path) throw new Error("Missing isolated provider evidence path");
  appendFileSync(path, JSON.stringify({ time: Date.now(), pid: process.pid, host: process.env.TERN_STATUS_VERIFY_HOST, event, ...detail }) + "\n");
};

export default function offlineProvider(pi) {
  log("extension_loaded");
  pi.registerCommand("verify-confirm", {
    description: "Open a real blocking confirmation for native status verification",
    handler: async (_args, ctx) => {
      log("confirm_open");
      const accepted = await ctx.ui.confirm("Tab status verification", "Accept this isolated verification confirmation?");
      log("confirm_closed", { accepted });
      ctx.ui.notify(accepted ? "Verification accepted" : "Verification dismissed", "info");
    },
  });
  pi.registerProvider("tern-status-offline", {
    name: "Tern status offline verification",
    api: "tern-status-offline-api",
    apiKey: "offline-no-secret",
    baseUrl: "http://127.0.0.1",
    models: [{ id: "delayed", name: "Delayed offline fixture", input: ["text", "image"],
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, contextWindow: 100000, maxTokens: 4096 }],
    streamSimple(model, context) {
      const lastUser = [...context.messages].reverse().find(message => message.role === "user");
      const request = JSON.stringify(lastUser);
      const failed = request.includes("VERIFY_FAILURE");
      const delay = request.includes("VERIFY_LONG") ? 18000 : 5000;
      const output = {
        role: "assistant", content: failed ? [] : [{ type: "text", text: "VERIFIED_OFFLINE_SUCCESS" }],
        api: model.api, provider: model.provider, model: model.id,
        usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0,
          cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } },
        stopReason: failed ? "error" : "stop", ...(failed ? { errorMessage: "VERIFIED_OFFLINE_FAILURE" } : {}), timestamp: Date.now(),
      };
      log("request", { request, failed, delay });
      const ready = new Promise(resolve => setTimeout(resolve, delay));
      let sent = false;
      return {
        push() {}, end() {}, result: async () => { await ready; return output; },
        async *[Symbol.asyncIterator]() {
          if (sent) return;
          sent = true;
          yield { type: "start", partial: output };
          await ready;
          if (failed) {
            log("response", { failed });
            yield { type: "error", reason: "error", error: output };
          } else {
            yield { type: "text_start", contentIndex: 0, partial: output };
            yield { type: "text_delta", contentIndex: 0, delta: "VERIFIED_OFFLINE_SUCCESS", partial: output };
            yield { type: "text_end", contentIndex: 0, content: "VERIFIED_OFFLINE_SUCCESS", partial: output };
            log("response", { failed });
            yield { type: "done", reason: "stop", message: output };
          }
        },
      };
    },
  });
}
