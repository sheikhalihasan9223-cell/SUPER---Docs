import { degrees, PDFDocument, rgb, StandardFonts } from "npm:pdf-lib@1.17.1";
import { zipSync } from "npm:fflate@0.8.2";
export type Output = { bytes: Uint8Array; name: string; mime: string };
export const coreTools = new Set([
  "merge",
  "split",
  "extract",
  "organize",
  "rotate",
  "numbers",
  "watermark",
]);
export function pageIndices(value: unknown, count: number): number[] {
  if (!value || !String(value).trim()) {
    return Array.from({ length: count }, (_, i) => i);
  }
  const result: number[] = [];
  for (const part of String(value).split(",")) {
    if (!/^\s*\d+(?:-\d+)?\s*$/.test(part)) {
      throw new Error("Use page ranges such as 1-3,5.");
    }
    const [first, last = first] = part.trim().split("-").map(Number);
    if (
      first < 1 || last < first || last > count ||
      result.length + last - first + 1 > 500
    ) throw new Error("Page range is outside this PDF.");
    for (let i = first - 1; i < last; i++) result.push(i);
  }
  return result;
}
export async function processCore(
  tool: string,
  files: Uint8Array[],
  options: Record<string, unknown>,
): Promise<Output> {
  if (
    !coreTools.has(tool) || !files.length ||
    (tool !== "merge" && files.length !== 1) ||
    (tool === "merge" && files.length < 2)
  ) throw new Error("Select the required PDF files.");
  const sources = await Promise.all(
    files.map((bytes) => PDFDocument.load(bytes)),
  );
  const total = sources.reduce((n, p) => n + p.getPageCount(), 0);
  if (total < 1 || total > 500) {
    throw new Error("Use at most 500 pages per task.");
  }
  const indexes = pageIndices(options.range, sources[0].getPageCount());
  if (tool === "split") {
    const outputs: Record<string, Uint8Array> = {};
    for (const index of indexes) {
      const output = await PDFDocument.create();
      const [page] = await output.copyPages(sources[0], [index]);
      output.addPage(page);
      outputs[`page-${index + 1}.pdf`] = await output.save();
    }
    return {
      bytes: zipSync(outputs),
      name: "split-pages.zip",
      mime: "application/zip",
    };
  }
  const output = await PDFDocument.create();
  for (const source of sources) {
    const selected = ["extract", "organize"].includes(tool)
      ? indexes
      : source.getPageIndices();
    for (const page of await output.copyPages(source, selected)) {
      output.addPage(page);
    }
  }
  if (tool === "rotate") {
    const angle = Number(options.angle ?? 90);
    if (![90, 180, 270].includes(angle)) {
      throw new Error("Use a rotation of 90, 180, or 270 degrees.");
    }
    for (const index of indexes) {
      const page = output.getPage(index);
      page.setRotation(degrees((page.getRotation().angle + angle) % 360));
    }
  }
  if (["watermark", "numbers"].includes(tool)) {
    const font = await output.embedFont(StandardFonts.HelveticaBold);
    for (let index = 0; index < output.getPageCount(); index++) {
      const page = output.getPage(index), { width, height } = page.getSize();
      const text = tool === "numbers"
        ? String(index + 1)
        : String(options.text ?? "").trim();
      if (!text || text.length > 120) {
        throw new Error("Use watermark text between 1 and 120 characters.");
      }
      const size = tool === "numbers"
        ? 12
        : Math.min(44, width / Math.max(1, text.length * 0.65));
      const textWidth = font.widthOfTextAtSize(text, size);
      const position = String(options.position ?? "Bottom center")
        .toLowerCase();
      const x = position.includes("left")
        ? 24
        : position.includes("right")
        ? width - textWidth - 24
        : (width - textWidth) / 2;
      const y = tool === "watermark"
        ? height / 2
        : position.includes("top")
        ? height - 30
        : 24;
      page.drawText(text, {
        font,
        size,
        x,
        y,
        color: rgb(.3, .3, .3),
        opacity: tool === "numbers"
          ? 1
          : Math.max(.05, Math.min(1, Number(options.opacity ?? .25))),
      });
    }
  }
  return {
    bytes: await output.save(),
    name: `${tool}.pdf`,
    mime: "application/pdf",
  };
}
