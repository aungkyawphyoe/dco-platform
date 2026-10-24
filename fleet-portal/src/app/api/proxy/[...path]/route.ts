import { NextRequest, NextResponse } from "next/server";
import { FLEET_ACCESS_COOKIE } from "@/lib/auth/cookies";
import { rejectCrossOrigin } from "@/lib/auth/request-origin";
import { upstream } from "@/lib/api/upstream";

async function proxy(request: NextRequest, context: { params: Promise<{ path: string[] }> }) {
  const rejected = rejectCrossOrigin(request);
  if (rejected) return rejected;
  const { path } = await context.params;
  // Reject traversal and credential-issuing endpoints; never proxy arbitrary URLs.
  if (path.some(part => !part || part === "." || part === ".." || /[\\/%?#]/.test(part)) ||
      (path[0] === "auth" && path.join("/") !== "auth/change-password")) {
    return NextResponse.json({ error: { code: "invalid_path", message: "API path rejected" } }, { status: 400 });
  }
  const token = request.cookies.get(FLEET_ACCESS_COOKIE)?.value;
  if (!token) return NextResponse.json({ error: { code: "unauthenticated", message: "Session expired" } }, { status: 401 });
  const headers = new Headers({ authorization: `Bearer ${token}` });
  for (const name of ["content-type", "accept", "if-match"]) {
    const value = request.headers.get(name);
    if (value) headers.set(name, value);
  }
  const length = Number(request.headers.get("content-length") ?? 0);
  if (length > 16 * 1024 * 1024) return new NextResponse(null, { status: 413 });
  let body: ArrayBuffer | undefined;
  if (!["GET", "HEAD"].includes(request.method) && request.body) {
    const reader = request.body.getReader();
    const chunks: Uint8Array[] = [];
    let total = 0;
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      total += value.byteLength;
      if (total > 16 * 1024 * 1024) {
        await reader.cancel();
        return new NextResponse(null, { status: 413 });
      }
      chunks.push(value);
    }
    const bytes = new Uint8Array(total);
    let offset = 0;
    for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
    body = bytes.buffer;
  }
  const response = await upstream(`/${path.map(encodeURIComponent).join("/")}${request.nextUrl.search}`, {
    method: request.method, headers, body, redirect: "manual",
  });
  const outputHeaders = new Headers({ "cache-control": "no-store", "x-content-type-options": "nosniff" });
  for (const name of ["content-type", "content-disposition", "retry-after", "etag"]) {
    const value = response.headers.get(name);
    if (value) outputHeaders.set(name, value);
  }
  return new NextResponse(response.body, { status: response.status, headers: outputHeaders });
}
export { proxy as GET, proxy as POST, proxy as PATCH, proxy as PUT, proxy as DELETE, proxy as HEAD };
