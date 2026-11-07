const MAX_BODY_BYTES = 64 * 1024;

export function validPublicOrigin(value) {
  if (!value) return true;
  try {
    const parsed = new URL(value);
    return parsed.protocol === "https:" && parsed.origin === value && !parsed.username && !parsed.password;
  } catch {
    return false;
  }
}

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

export function readLimitedBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    let finished = false;
    req.on("data", (chunk) => {
      if (finished) return;
      const bytes = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
      size += bytes.length;
      if (size > MAX_BODY_BYTES) {
        finished = true;
        chunks.length = 0;
        const error = new Error("request body too large");
        error.code = 413;
        reject(error);
        return;
      }
      chunks.push(bytes);
    });
    req.on("end", () => {
      if (!finished) {
        finished = true;
        resolve(Buffer.concat(chunks).toString("utf8"));
      }
    });
    req.on("error", (error) => {
      if (!finished) {
        finished = true;
        reject(error);
      }
    });
    req.on("aborted", () => {
      if (!finished) {
        finished = true;
        reject(new Error("request aborted"));
      }
    });
  });
}
