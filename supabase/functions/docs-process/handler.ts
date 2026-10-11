import {
  type Dependencies,
  process,
  ProcessingError,
  supportedTools,
} from "../_shared/processing.ts";
const MAX_TOTAL = 12 * 1024 * 1024;
export function createHandler(deps: Dependencies) {
  return async (request: Request): Promise<Response> => {
    const origin = request.headers.get("Origin");
    const allowed = (deps.env("ALLOWED_ORIGINS") ??
      "http://localhost:8080,http://127.0.0.1:8080").split(",").map((s) =>
        s.trim()
      );
    const headers: Record<string, string> = {
      "Access-Control-Allow-Headers":
        "authorization, apikey, content-type, x-client-info",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Expose-Headers": "X-Output-Name",
      "Vary": "Origin",
      "Cache-Control": "no-store",
    };
    if (origin && allowed.includes(origin)) {
      headers["Access-Control-Allow-Origin"] = origin;
    }
    const fail = (status: number, detail: string) =>
      Response.json({ detail }, { status, headers });
    if (origin && !allowed.includes(origin)) {
      return fail(403, "This app origin is not allowed.");
    }
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers });
    }
    if (request.method !== "POST") return fail(405, "Use POST for processing.");
    const authorization = request.headers.get("Authorization");
    if (!authorization?.startsWith("Bearer ")) {
      return fail(401, "Sign in with Google to process files.");
    }
    const base = deps.env("SUPABASE_URL"),
      key = deps.env("SUPABASE_ANON_KEY") ??
        deps.env("SUPABASE_PUBLISHABLE_KEY");
    if (!base || !key) {
      return fail(503, "Cloud authentication is not configured.");
    }
    try {
      const authHeaders = { Authorization: authorization, apikey: key };
      const userResponse = await deps.fetch(`${base}/auth/v1/user`, {
        headers: authHeaders,
        signal: AbortSignal.timeout(10000),
      });
      if (!userResponse.ok) {
        return fail(401, "Your session expired. Sign in again.");
      }
      const user = await userResponse.json() as { id?: string };
      if (!user.id) return fail(401, "Sign in with Google to process files.");
      const tool =
        new URL(request.url).pathname.split("/").filter(Boolean).at(-1) ?? "";
      if (!supportedTools.has(tool)) {
        return fail(422, "This tool is not enabled.");
      }
      if (
        !request.headers.get("content-type")?.startsWith("multipart/form-data")
      ) return fail(415, "Send multipart/form-data.");
      const quota = await deps.fetch(
        `${base}/rest/v1/rpc/claim_processing_request`,
        {
          method: "POST",
          headers: { ...authHeaders, "Content-Type": "application/json" },
          body: "{}",
          signal: AbortSignal.timeout(10000),
        },
      );
      if (!quota.ok) {
        return fail(503, "The cloud database setup is incomplete.");
      }
      if (await quota.json() !== true) {
        return fail(
          429,
          "Your daily processing limit is reached. Please try tomorrow.",
        );
      }
      if (
        Number(request.headers.get("content-length")) > MAX_TOTAL + 1024 * 1024
      ) return fail(413, "Cloud processing supports 12 MB total per task.");
      const chunks: Uint8Array[] = [];
      let length = 0;
      const reader = request.body?.getReader();
      if (!reader) return fail(422, "Select a file or enter AI instructions.");
      while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        length += value.length;
        if (length > MAX_TOTAL + 1024 * 1024) {
          await reader.cancel();
          return fail(413, "Cloud processing supports 12 MB total per task.");
        }
        chunks.push(value);
      }
      const body = new Uint8Array(length);
      let offset = 0;
      for (const chunk of chunks) {
        body.set(chunk, offset);
        offset += chunk.length;
      }
      const form = await new Response(body, {
        headers: { "Content-Type": request.headers.get("content-type")! },
      }).formData();
      const entries = form.getAll("files");
      if (entries.length > 5 || entries.some((f) => !(f instanceof File))) {
        return fail(422, "Select at most five files.");
      }
      const files = await Promise.all(
        (entries as File[]).map(async (file) => ({
          name: file.name,
          bytes: new Uint8Array(await file.arrayBuffer()),
        })),
      );
      if (files.reduce((sum, f) => sum + f.bytes.length, 0) > MAX_TOTAL) {
        return fail(413, "Cloud processing supports 12 MB total per task.");
      }
      const raw = form.get("options") ?? "{}";
      if (typeof raw !== "string" || raw.length > 1024 * 1024) {
        return fail(422, "Options are too large.");
      }
      let options;
      try {
        options = JSON.parse(raw);
      } catch {
        return fail(422, "Options must be valid JSON.");
      }
      if (!options || typeof options !== "object" || Array.isArray(options)) {
        return fail(422, "Options must be a JSON object.");
      }
      const output = await process(tool, files, options, deps);
      return new Response(new Uint8Array(output.bytes).buffer, {
        headers: {
          ...headers,
          "Content-Type": output.mime,
          "X-Output-Name": output.name,
          "Content-Disposition": `attachment; filename="${
            output.name.replace(/[^a-zA-Z0-9._-]/g, "_")
          }"`,
        },
      });
    } catch (error) {
      if (error instanceof ProcessingError) {
        return fail(error.status, error.message);
      }
      if (error instanceof DOMException && error.name === "TimeoutError") {
        return fail(504, "Processing took too long. Try a smaller file.");
      }
      return fail(
        422,
        "Unable to process this file. Check the file and try standard processing if needed.",
      );
    }
  };
}
