import { AppError } from "./errors.js";

/** Inspect signatures rather than trusting a filename or multipart MIME header. */
export function documentContentType(bytes: Buffer, imagesOnly = false): string {
  if (bytes.length >= 3 && bytes.subarray(0, 3).equals(Buffer.from([0xff, 0xd8, 0xff]))) return "image/jpeg";
  if (bytes.length >= 8 && bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))) return "image/png";
  if (bytes.length >= 12 && bytes.toString("ascii", 4, 8) === "ftyp" &&
      ["heic", "heix", "hevc", "hevx"].includes(bytes.toString("ascii", 8, 12))) return "image/heic";
  if (!imagesOnly && bytes.toString("ascii", 0, 5) === "%PDF-") return "application/pdf";
  throw new AppError(422, "unsupported_file_type", imagesOnly ? "Select a JPEG, PNG or HEIC image" : "Select a JPEG, PNG, HEIC image or PDF");
}
