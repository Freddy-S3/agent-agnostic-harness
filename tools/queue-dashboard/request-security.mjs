const MAX_BODY_BYTES = 64 * 1024;

export function allowedWriteOrigin(origin, host, publicOrigin = "") {
  if (typeof origin !== "string" || typeof host !== "string") return false;
  try {
    const parsed = new URL(origin);
    if (parsed.origin !== origin || parsed.host !== host || parsed.username || parsed.password) return false;
    const name = parsed.hostname.toLowerCase();
    const local = parsed.protocol === "http:" && (name === "localhost" || name === "127.0.0.1" || /^100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\.\d{1,3}\.\d{1,3}$/.test(name));
    const tailnet = parsed.protocol === "https:" && name.endsWith(".ts.net");
    const configured = publicOrigin !== "" && origin === publicOrigin && parsed.protocol === "https:";
    return local || tailnet || configured;
  } catch {
    return false;
  }
}

export async function readLimitedBody(req) {
  const chunks = [];
  let size = 0;
  let oversized = false;
  for await (const chunk of req) {
    const bytes = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    size += bytes.length;
    if (size > MAX_BODY_BYTES) oversized = true;
    if (!oversized) chunks.push(bytes);
  }
  if (oversized) {
    const error = new Error("request body too large");
    error.code = 413;
    throw error;
  }
  return Buffer.concat(chunks).toString("utf8");
}
