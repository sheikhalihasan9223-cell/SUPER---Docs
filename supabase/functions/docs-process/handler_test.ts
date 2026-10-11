import { assert, assertEquals } from "jsr:@std/assert@1";
import { PDFDocument } from "npm:pdf-lib@1.17.1";
import { unzipSync } from "npm:fflate@0.8.2";
import { createHandler } from "./handler.ts";
import { pageIndices } from "../_shared/core_pdf.ts";
const decoder = new TextDecoder();
const tinyPng = Uint8Array.from(
  atob(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a9XkAAAAASUVORK5CYII=",
  ),
  (c) => c.charCodeAt(0),
);
async function pdf() {
  const doc = await PDFDocument.create();
  doc.addPage();
  return await doc.save();
}
function fixture(
  options: {
    signedIn?: boolean;
    quota?: boolean;
    parts?: unknown[];
    providerStatus?: number;
    providerReason?: string;
    worker?: boolean;
  } = {},
) {
  let providerCalls = 0, workerCalls = 0;
  const env: Record<string, string> = {
    SUPABASE_URL: "https://project.test",
    SUPABASE_ANON_KEY: "public-key",
    GEMINI_API_KEY: "private-provider-key",
  };
  if (options.worker) {
    env.PROCESSOR_URL = "https://worker.test";
    env.PROCESSOR_SHARED_SECRET = "worker-private-secret";
  }
  const handler = createHandler({
    env: (name) => env[name],
    fetch: (async (input, init) => {
      const url = String(input);
      if (url.endsWith("/auth/v1/user")) {
        return Response.json(
          options.signedIn === false ? {} : { id: "owner" },
          { status: options.signedIn === false ? 401 : 200 },
        );
      }
      if (url.endsWith("/rpc/claim_processing_request")) {
        return Response.json(options.quota !== false);
      }
      if (url.startsWith("https://generativelanguage.googleapis.com/")) {
        providerCalls++;
        assertEquals(
          new Headers(init?.headers).get("x-goog-api-key"),
          "private-provider-key",
        );
        assert(!url.includes("private-provider-key"));
        return options.providerStatus
          ? new Response(
            options.providerReason
              ? JSON.stringify({
                error: {
                  message: "private-provider-key",
                  details: [{ reason: options.providerReason }],
                },
              })
              : "private-provider-key",
            {
              status: options.providerStatus,
            },
          )
          : Response.json({
            candidates: [{
              finishReason: "STOP",
              content: { parts: options.parts ?? [{ text: "Sample answer" }] },
            }],
          });
      }
      if (url.startsWith("https://worker.test/")) {
        workerCalls++;
        assertEquals(
          new Headers(init?.headers).get("x-processor-secret"),
          "worker-private-secret",
        );
        assertEquals(new Headers(init?.headers).get("authorization"), null);
        return new Response(new Uint8Array(url.endsWith("/image_enhance") ? tinyPng : await pdf()).buffer, {
          headers: {
            "X-Output-Name": url.endsWith("/image_enhance") ? "enhanced-upscayl.png" : "searchable.pdf",
            "Content-Type": url.endsWith("/image_enhance") ? "image/png" : "application/pdf",
          },
        });
      }
      throw new Error(`Unexpected URL ${url}`);
    }) as typeof fetch,
  });
  return { handler, calls: () => ({ providerCalls, workerCalls }) };
}
function request(
  tool: string,
  files: Uint8Array[] = [],
  options: Record<string, unknown> = {},
  name = "file.pdf",
) {
  const form = new FormData();
  form.set("options", JSON.stringify(options));
  for (const bytes of files) {
    form.append("files", new Blob([new Uint8Array(bytes).buffer]), name);
  }
  return new Request(
    `https://project.test/functions/v1/docs-process/process/${tool}`,
    {
      method: "POST",
      headers: { Authorization: "Bearer test-session" },
      body: form,
    },
  );
}
Deno.test("Rejects anonymous and expired sessions before provider calls", async () => {
  const auth = fixture();
  assertEquals(
    (await auth.handler(
      new Request("https://project.test/image_enhance", { method: "POST" }),
    )).status,
    401,
  );
  const expired = fixture({ signedIn: false });
  assertEquals(
    (await expired.handler(
      await request("image_enhance", [tinyPng], {}, "photo.png"),
    )).status,
    401,
  );
  assertEquals(expired.calls().providerCalls, 0);
});
Deno.test("Daily quota prevents Gemini calls and CORS prevents foreign origins", async () => {
  const blocked = fixture({ quota: false });
  assertEquals(
    (await blocked.handler(
      await request("image_enhance", [tinyPng], {}, "photo.png"),
    )).status,
    429,
  );
  assertEquals(blocked.calls().providerCalls, 0);
  const req = await request("image_enhance", [tinyPng], {}, "photo.png");
  req.headers.set("Origin", "https://foreign.test");
  assertEquals((await fixture().handler(req)).status, 403);
});
Deno.test("Authenticated merge returns a readable two-page PDF", async () => {
  const api = fixture();
  const response = await api.handler(
    await request("merge", [await pdf(), await pdf()]),
  );
  assertEquals(response.status, 200);
  assertEquals(
    (await PDFDocument.load(await response.arrayBuffer())).getPageCount(),
    2,
  );
  assertEquals(api.calls().providerCalls, 0);
});
Deno.test("Page ranges preserve explicit order and reject out-of-bounds values", async () => {
  assertEquals(pageIndices("2,1,2", 2), [1, 0, 1]);
  const response = await fixture().handler(
    await request("extract", [await pdf()], { range: "8" }),
  );
  assertEquals(response.status, 422);
});
Deno.test("Upscayl enhancement forwards to private worker without Gemini", async () => {
  const api = fixture({worker: true});
  const response = await api.handler(await request("image_enhance", [tinyPng], {upscale: 2}, "photo.png"));
  assertEquals(response.status, 200);
  assertEquals(new Uint8Array(await response.arrayBuffer()), tinyPng);
  assertEquals(response.headers.get("x-output-name"), "enhanced-upscayl.png");
  assertEquals(api.calls().workerCalls, 1);
  assertEquals(api.calls().providerCalls, 0);
});
Deno.test("Office conversion ignores legacy Gemini flags and uses the worker", async () => {
  for (const tool of ["pdf_word", "pdf_excel", "pdf_ppt", "text"]) {
    const api = fixture({ worker: true });
    const response = await api.handler(
      await request(tool, [await pdf()], { useGemini: true }),
    );
    assertEquals(response.status, 200);
    assertEquals(api.calls().providerCalls, 0);
    assertEquals(api.calls().workerCalls, 1);
  }
  const removed = fixture();
  assertEquals(
    (await removed.handler(await request("ai_assist", [], { prompt: "Hello" })))
      .status,
    422,
  );
  assertEquals(removed.calls().providerCalls, 0);
});
Deno.test("Missing native worker is explicit; configured worker receives only server secret", async () => {
  assertEquals(
    (await fixture().handler(await request("ocr", [await pdf()]))).status,
    503,
  );
  const api = fixture({ worker: true });
  assertEquals(
    (await api.handler(await request("ocr", [await pdf()]))).status,
    200,
  );
  assertEquals(api.calls().workerCalls, 1);
});

