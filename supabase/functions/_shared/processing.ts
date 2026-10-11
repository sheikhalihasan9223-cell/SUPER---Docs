import { coreTools, type Output, processCore } from "./core_pdf.ts";
export type Options = Record<string, unknown>;
export type Upload = { name: string; bytes: Uint8Array };
export type Dependencies = {
  env: (name: string) => string | undefined;
  fetch: typeof fetch;
};
export class ProcessingError extends Error {
  constructor(message: string, public status = 422) {
    super(message);
  }
}
const workerTools = new Set([
  "compress",
  "repair",
  "pdf_jpg",
  "text",
  "protect",
  "unlock",
  "word_pdf",
  "excel_pdf",
  "ppt_pdf",
  "pdf_word",
  "pdf_excel",
  "pdf_ppt",
  "ocr",
  "edit",
  "sign",
]);
export const supportedTools = new Set([
  ...coreTools,
  ...workerTools,
  "image_enhance",
]);
async function worker(
  tool: string,
  files: Upload[],
  options: Options,
  deps: Dependencies,
): Promise<Output> {
  const endpoint = deps.env("PROCESSOR_URL"),
    secret = deps.env("PROCESSOR_SHARED_SECRET");
  if (!endpoint || !secret) {
    throw new ProcessingError(
      "This tool needs the processing worker. The backend administrator must configure its HTTPS address and shared secret.",
      503,
    );
  }
  const uri = new URL(endpoint);
  if (uri.protocol !== "https:") {
    throw new ProcessingError(
      "The processing worker requires an HTTPS URL.",
      503,
    );
  }
  const form = new FormData();
  form.set("options", JSON.stringify(options));
  for (const file of files) {
    form.append(
      "files",
      new Blob([new Uint8Array(file.bytes).buffer]),
      file.name,
    );
  }
  const response = await deps.fetch(
    `${endpoint.replace(/\/+$/, "")}/process/${tool}`,
    {
      method: "POST",
      headers: { "X-Processor-Secret": secret },
      body: form,
      signal: AbortSignal.timeout(110000),
      redirect: "error",
    },
  );
  if (!response.ok) {
    throw new ProcessingError(
      "The processing worker could not complete this file. Check its configuration or try a smaller file.",
      response.status === 429 ? 429 : 422,
    );
  }
  const name = response.headers.get("x-output-name") ?? "result.pdf";
  return {
    bytes: new Uint8Array(await response.arrayBuffer()),
    name,
    mime: response.headers.get("content-type") ?? "application/octet-stream",
  };
}
export async function process(
  tool: string,
  files: Upload[],
  options: Options,
  deps: Dependencies,
): Promise<Output> {
  if (!supportedTools.has(tool)) {
    throw new ProcessingError("This tool is not enabled.");
  }
  if (coreTools.has(tool)) {
    return processCore(
      tool,
      files.map((f) => f.bytes),
      options,
    );
  }
  if (tool === "image_enhance" && files.length !== 1) {
    throw new ProcessingError(
      "Select one photograph at a time for Upscayl enhancement.",
    );
  }
  return worker(tool, files, options, deps);
}
