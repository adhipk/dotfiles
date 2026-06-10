#!/usr/bin/env node
/**
 * Nearly-headless artifact server.
 * GET /              → live doc canvas (session picker)
 * GET /:route/       → editable canvas for that project
 * GET /:route/*      → files under <project>/.hyperspace/
 * GET/POST /api/:route/doc → load/save livedoc.html for sessions
 * GET /:route/preview/   → standalone livedoc.html
 */

const LIVE_DOC_SOURCE = "livedoc.html";
const LIVE_DOC_JSON = "live-doc.json";
const LIVEDOC_TEMPLATE = "livedoc.html.template";
const COMPONENTS_DIR = "components";
const SHARED_COMPONENTS = ["hyperspace-components.js", "hyperspace-components.css"];

import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawn, spawnSync } from "node:child_process";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const PORT = Number(process.env.HYPERSPACE_SERVE_PORT || process.argv.find((a) => a.startsWith("--port="))?.split("=")[1] || 4200);
const HOST = process.env.HYPERSPACE_SERVE_HOST || "127.0.0.1";
const CONFIG_FILE = process.env.HYPERSPACE_CONFIG_FILE || path.join(process.env.HOME, ".config/hyperspaces/config.json");
const STATE_DIR = process.env.HYPERSPACE_STATE_DIR || path.join(process.env.HOME, ".local/state/hyperspaces");
const SESSION_DIR_FILE = process.env.HYPERSPACE_SESSION_DIR_FILE || path.join(STATE_DIR, "sessions.json");
const EVENT_LOG_FILE = process.env.HYPERSPACE_EVENT_LOG_FILE || path.join(STATE_DIR, "events.jsonl");

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".webp": "image/webp",
  ".ico": "image/x-icon",
};

function expandHome(p) {
  if (!p) return p;
  return p.replace(/^~(?=$|[/])/, process.env.HOME);
}

function readHyperspaceConfig() {
  try {
    return JSON.parse(fs.readFileSync(CONFIG_FILE, "utf8"));
  } catch {
    return { projects: {}, defaults: {} };
  }
}

function readSessionDirectory() {
  try {
    const parsed = JSON.parse(fs.readFileSync(SESSION_DIR_FILE, "utf8"));
    return parsed && typeof parsed === "object" ? parsed : { sessions: {} };
  } catch {
    return { sessions: {} };
  }
}

function isValidProjectSlug(id) {
  if (!id || typeof id !== "string") return false;
  if (["_", ".", ".."].includes(id)) return false;
  if (id === path.basename(process.env.HOME)) return false;
  if (id.includes("/")) return false;
  return /^[a-zA-Z][a-zA-Z0-9._-]*$/.test(id);
}

function projectPath(projectId, config) {
  if (!projectId || !isValidProjectSlug(projectId)) return null;

  const configured = config?.projects?.[projectId]?.path;
  if (configured) {
    const resolved = path.resolve(expandHome(configured));
    if (fs.existsSync(resolved)) return resolved;
  }

  const guess = path.join(process.env.HOME, projectId);
  if (fs.existsSync(guess)) return guess;

  return null;
}

function projectIdFromPath(rootPath, config) {
  const resolved = path.resolve(rootPath);
  const home = path.resolve(process.env.HOME);

  for (const [id, proj] of Object.entries(config.projects || {})) {
    const configured = path.resolve(expandHome(proj.path));
    if (configured === resolved) return id;
  }

  if (resolved === home) return null;

  const base = path.basename(resolved);
  return isValidProjectSlug(base) ? base : null;
}

function sessionRoute(projectId, config) {
  const configured = config?.projects?.[projectId]?.route;
  const route = configured || projectId;
  return isValidProjectSlug(route) ? route : projectId;
}

function sessionWorkingDir(session) {
  for (const target of [`${session}:shell`, session]) {
    const cwd = tmuxLines(["display", "-p", "-t", target, "#{pane_current_path}"]);
    if (cwd && fs.existsSync(cwd)) return path.resolve(cwd);
  }
  return null;
}

function makeSessionRecord(session, project, basePath, config) {
  if (!isValidProjectSlug(project)) return null;

  return {
    route: sessionRoute(project, config),
    project,
    session,
    path: basePath,
    artifactDir: path.join(basePath, ".hyperspace"),
    liveDocWindow: liveDocWindow(project, config),
  };
}

function liveDocWindow(project, config) {
  const configured = config?.projects?.[project]?.liveDocWindow;
  if (configured) return configured;

  const projectWindows = Object.keys(config?.projects?.[project]?.windows || {});
  if (projectWindows.length > 0) return projectWindows[0];

  const defaultWindows = Object.keys(config?.defaults || {});
  return defaultWindows[0] || "codex-main";
}

function makeStateSessionRecord(project, entry, config) {
  if (!isValidProjectSlug(project)) return null;

  const basePath = entry?.path ? path.resolve(expandHome(entry.path)) : projectPath(project, config);
  if (!basePath) return null;

  return {
    route: entry?.route && isValidProjectSlug(entry.route) ? entry.route : sessionRoute(project, config),
    project,
    session: entry?.session || `hs-${project}`,
    path: basePath,
    artifactDir: path.join(basePath, ".hyperspace"),
    status: entry?.status || "unknown",
    managed: true,
    liveDocWindow: entry?.liveDocWindow || liveDocWindow(project, config),
    windows: Object.values(entry?.windows || {}).map((window) => ({
      name: window.id || window.window,
      provider: window.provider || "shell",
      providerSessionId: window.providerSessionId || null,
      status: window.status || "unknown",
      active: false,
      updatedAt: window.updatedAt || null,
    })).filter((window) => window.name),
    updatedAt: entry?.updatedAt || null,
  };
}

function resolveSession(session, config) {
  const nameProject = session.slice(3);

  if (config.projects?.[nameProject]?.path) {
    const basePath = projectPath(nameProject, config);
    const record = basePath ? makeSessionRecord(session, nameProject, basePath, config) : null;
    if (record) return record;
  }

  const cwd = sessionWorkingDir(session);
  if (cwd) {
    const project = projectIdFromPath(cwd, config);
    if (project) {
      const record = makeSessionRecord(session, project, cwd, config);
      if (record) return record;
    }
  }

  if (isValidProjectSlug(nameProject)) {
    const basePath = projectPath(nameProject, config);
    if (basePath) return makeSessionRecord(session, nameProject, basePath, config);
  }

  return null;
}

function tmuxLines(args) {
  const result = spawnSync("tmux", args, { encoding: "utf8" });
  if (result.status !== 0) return "";
  return (result.stdout || "").trim();
}

function tmuxRun(args) {
  return spawnSync("tmux", args, { encoding: "utf8" }).status === 0;
}

function paneStatus(session, window) {
  const target = `${session}:${window}`;
  const title = tmuxLines(["display", "-p", "-t", target, "#{pane_title}"]);
  const cmd = tmuxLines(["display", "-p", "-t", target, "#{pane_current_command}"]);
  if (/action required|approve/i.test(title)) return "needs-input";
  if (!cmd || /^(bash|zsh|sh|login|-zsh|-bash)$/i.test(cmd)) return "idle";
  return "running";
}

function aggregateStatus(statuses) {
  if (statuses.includes("needs-input")) return "needs-input";
  if (statuses.includes("running")) return "running";
  if (statuses.length === 0) return "idle";
  return statuses[0] || "unknown";
}

function listSessionWindows(session) {
  const raw = tmuxLines(["list-windows", "-t", session, "-F", "#{window_name}|#{window_active}"]);
  if (!raw) return [];

  return raw
    .split("\n")
    .filter(Boolean)
    .map((line) => {
      const [window, active] = line.split("|");
      if (window === "shell") return null;
      return {
        name: window,
        status: paneStatus(session, window),
        active: active === "1",
      };
    })
    .filter(Boolean);
}

function mergeWindows(managedWindows, liveWindows) {
  const merged = new Map();

  for (const window of managedWindows || []) {
    merged.set(window.name, { ...window, active: false });
  }

  for (const window of liveWindows || []) {
    merged.set(window.name, {
      ...(merged.get(window.name) || {}),
      ...window,
      live: true,
    });
  }

  return Array.from(merged.values()).sort((a, b) => a.name.localeCompare(b.name));
}

function hasProviderBinding(session) {
  return (session.windows || []).some((window) => Boolean(window.providerSessionId));
}

function detachedSession(session) {
  return {
    ...session,
    status: "detached",
    windows: (session.windows || []).map((window) => ({
      ...window,
      status: window.providerSessionId ? "detached" : window.status,
      active: false,
      live: false,
    })),
  };
}

function liveDocPaths(session) {
  return {
    source: path.join(session.artifactDir, LIVE_DOC_SOURCE),
    meta: path.join(session.artifactDir, LIVE_DOC_JSON),
  };
}

function livedocTemplatePath() {
  return path.join(__dirname, LIVEDOC_TEMPLATE);
}

function ensureLiveDocShared(artifactDir) {
  const sharedDir = path.join(artifactDir, "shared");
  fs.mkdirSync(sharedDir, { recursive: true });
  for (const name of SHARED_COMPONENTS) {
    const src = path.join(__dirname, COMPONENTS_DIR, name);
    const dest = path.join(sharedDir, name);
    if (fs.existsSync(src)) fs.copyFileSync(src, dest);
  }
}

function ensureLiveDocSource(sourcePath, artifactDir) {
  if (fs.existsSync(sourcePath)) return;

  const template = livedocTemplatePath();
  fs.mkdirSync(path.dirname(sourcePath), { recursive: true });
  ensureLiveDocShared(artifactDir);

  if (fs.existsSync(template)) {
    fs.copyFileSync(template, sourcePath);
    return;
  }

  fs.writeFileSync(
    sourcePath,
    `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Live doc</title>
  <link rel="stylesheet" href="shared/hyperspace-components.css">
</head>
<body data-hyperspace-live-doc>
  <main class="live-doc-canvas"></main>
  <script src="shared/hyperspace-components.js"></script>
</body>
</html>
`,
    "utf8",
  );
}

function extractCanvasFromHtml(raw) {
  const main = raw.match(/<main[^>]*class="live-doc-canvas"[^>]*>([\s\S]*?)<\/main>/i);
  if (main) return main[1].trim();
  return "";
}

function readRenderedCanvas(session) {
  const { source } = liveDocPaths(session);
  ensureLiveDocSource(source, session.artifactDir);
  ensureLiveDocShared(session.artifactDir);
  return extractCanvasFromHtml(fs.readFileSync(source, "utf8"));
}

function writeLivedocFromCanvas(sourcePath, artifactDir, canvasHtml, project) {
  const body = normalizeCanvasHtml(String(canvasHtml ?? "")).trim();
  ensureLiveDocShared(artifactDir);
  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Live doc — ${escapeHtml(project)}</title>
  <link rel="stylesheet" href="shared/hyperspace-components.css">
</head>
<body data-hyperspace-live-doc data-project="${escapeHtml(project)}">
  <main class="live-doc-canvas">
${body}
  </main>
  <script src="shared/hyperspace-components.js"></script>
</body>
</html>
`;
  fs.writeFileSync(sourcePath, html, "utf8");
}

function normalizeCanvasHtml(raw) {
  return String(raw || "")
    .replace(/<\s*bold(\s[^>]*)?>/gi, "<strong$1>")
    .replace(/<\s*\/\s*bold\s*>/gi, "</strong>")
    .replace(/<\s*italic(\s[^>]*)?>/gi, "<em$1>")
    .replace(/<\s*\/\s*italic\s*>/gi, "</em>")
    .replace(/<\s*b(\s[^>]*)?>/gi, "<strong$1>")
    .replace(/<\s*\/\s*b\s*>/gi, "</strong>")
    .replace(/<\s*i(\s[^>]*)?>/gi, "<em$1>")
    .replace(/<\s*\/\s*i\s*>/gi, "</em>");
}

function readLiveDocMeta(metaPath) {
  let savedAt = null;
  let version = 0;
  let status = "idle";
  let pending = false;
  let window = null;

  if (fs.existsSync(metaPath)) {
    try {
      const m = JSON.parse(fs.readFileSync(metaPath, "utf8"));
      savedAt = m.savedAt || null;
      version = m.version || 0;
      status = m.status || "idle";
      pending = Boolean(m.pending);
      window = m.window || null;
    } catch {
      /* ignore corrupt meta */
    }
  }

  return { savedAt, version, status, pending, window };
}

function readLiveDoc(session) {
  const { source, meta } = liveDocPaths(session);
  const html = readRenderedCanvas(session);
  const metaFields = readLiveDocMeta(meta);

  return {
    html,
    previewReady: fs.existsSync(source),
    ...metaFields,
    path: `.hyperspace/${LIVE_DOC_SOURCE}`,
    window: metaFields.window || session.liveDocWindow || null,
  };
}

function writeLiveDoc(session, canvasHtml) {
  const { source, meta } = liveDocPaths(session);
  fs.mkdirSync(session.artifactDir, { recursive: true });
  ensureLiveDocShared(session.artifactDir);

  const savedAt = new Date().toISOString();
  let version = 1;
  if (fs.existsSync(meta)) {
    try {
      version = (JSON.parse(fs.readFileSync(meta, "utf8")).version || 0) + 1;
    } catch {
      version = 1;
    }
  }

  writeLivedocFromCanvas(source, session.artifactDir, canvasHtml, session.project);

  fs.writeFileSync(
    meta,
    `${JSON.stringify(
      {
        savedAt,
        version,
        project: session.project,
        route: session.route,
        window: session.liveDocWindow,
        path: `.hyperspace/${LIVE_DOC_SOURCE}`,
        pending: true,
        status: "queued",
      },
      null,
      2,
    )}\n`,
    "utf8",
  );

  triggerLiveDocRun(session);
  return { savedAt, version, status: "queued", window: session.liveDocWindow, path: `.hyperspace/${LIVE_DOC_SOURCE}` };
}

function triggerLiveDocRun(session) {
  const run = path.join(process.env.HOME, "bin", "hyperspace-run-live-doc");
  if (!fs.existsSync(run)) return;
  const args = [session.project];
  if (session.liveDocWindow) args.push(session.liveDocWindow);
  const child = spawn(run, args, { detached: true, stdio: "ignore" });
  child.unref();
}

/** @returns {Array<{route, project, session, path, artifactDir, windows, status}>} */
function discoverSessions() {
  const config = readHyperspaceConfig();
  const directory = readSessionDirectory();
  const raw = tmuxLines(["list-sessions", "-F", "#{session_name}"]);

  const entries = new Map();

  for (const [project, stateEntry] of Object.entries(directory.sessions || {})) {
    const managed = makeStateSessionRecord(project, stateEntry, config);
    if (!managed) continue;
    entries.set(managed.project, managed);
  }

  for (const session of (raw || "").split("\n")) {
    if (!session?.startsWith("hs-")) continue;

    const resolved = resolveSession(session, config);
    if (!resolved) continue;

    const windows = listSessionWindows(session);
    const managed = entries.get(resolved.project);

    entries.set(resolved.project, {
      ...(managed || {}),
      ...resolved,
      managed: Boolean(managed),
      windows: mergeWindows(managed?.windows, windows),
      status: aggregateStatus(windows.map((a) => a.status)),
      live: true,
    });
  }

  return Array.from(entries.values())
    .filter((entry) => entry.live || hasProviderBinding(entry))
    .map((entry) => (entry.live ? entry : detachedSession(entry)))
    .sort((a, b) => a.project.localeCompare(b.project));
}

function findSession(route) {
  const sessions = discoverSessions();
  return sessions.find((s) => s.route === route || s.project === route || s.session === route);
}

function listArtifacts(artifactDir) {
  if (!fs.existsSync(artifactDir)) return [];
  const out = [];
  const walk = (dir, prefix = "") => {
    for (const name of fs.readdirSync(dir)) {
      if (name.startsWith(".")) continue;
      const full = path.join(dir, name);
      const rel = path.join(prefix, name);
      const st = fs.statSync(full);
      if (st.isDirectory()) walk(full, rel);
      else out.push({ rel: rel.replace(/\\/g, "/"), size: st.size, mtime: st.mtime });
    }
  };
  walk(artifactDir);
  return out.sort((a, b) => b.mtime - a.mtime);
}

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function sessionsPayload(sessions) {
  const payloadWindows = (s) => s.windows || [];
  return sessions.map((s) => ({
    route: s.route,
    project: s.project,
    session: s.session,
    status: s.status,
    path: s.path,
    live: Boolean(s.live),
    managed: Boolean(s.managed),
    updatedAt: s.updatedAt || null,
    liveDocWindow: s.liveDocWindow || null,
    windows: payloadWindows(s),
    artifacts: listArtifacts(s.artifactDir)
      .filter((f) => f.rel.endsWith(".html"))
      .map((f) => f.rel),
  }));
}

function readEvents(limit = 50) {
  if (!fs.existsSync(EVENT_LOG_FILE)) return [];
  const bounded = Math.max(1, Math.min(Number(limit) || 50, 500));
  return fs
    .readFileSync(EVENT_LOG_FILE, "utf8")
    .trim()
    .split("\n")
    .filter(Boolean)
    .slice(-bounded)
    .map((line) => {
      try {
        return JSON.parse(line);
      } catch {
        return { type: "runtime.unparseable", raw: line };
      }
    });
}

function renderLiveDocPage(sessions, activeRoute = "") {
  const sessionItems = sessions
    .map((s) => {
      const active = s.route === activeRoute ? " active" : "";
      const windows = (s.windows || []).map((a) => `${a.name}:${a.status || "unknown"}`).join(" ");
      const windowLine = windows ? `<span class="windows">${escapeHtml(windows)}</span>` : "";
      const liveDocLine = s.liveDocWindow ? `<span class="status">live doc -> ${escapeHtml(s.liveDocWindow)}</span>` : "";
      return `<li><a href="/${encodeURIComponent(s.route)}/" class="${active}">
        <strong>${escapeHtml(s.project)}</strong>
        <span class="status">${escapeHtml(s.session)} · ${escapeHtml(s.status)}</span>
        ${windowLine}
        ${liveDocLine}
      </a></li>`;
    })
    .join("");

  const emptySidebar =
    sessions.length === 0
      ? '<li style="padding:0.65rem;color:var(--subtext);font-size:0.85rem;">No sessions — run <code>hyperspace dotfiles</code></li>'
      : sessionItems;

  const payload = JSON.stringify(sessionsPayload(sessions)).replace(/</g, "\\u003c");

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Hyperspace</title>
  <link rel="stylesheet" href="/_hyperspace/hyperspace_live.css">
  <link rel="stylesheet" href="/_hyperspace/hyperspace-components.css">
</head>
<body>
  <div class="hyperspace-app" data-sessions='${payload}' data-route="${escapeHtml(activeRoute)}">
    <aside class="sidebar">
      <h2>Projects</h2>
      <ul class="session-list">${emptySidebar}</ul>
    </aside>
    <section class="doc-main">
      <header class="doc-header">
        <h1 id="doc-title">Hyperspace</h1>
        <span id="doc-status" class="badge idle">idle</span>
        <div class="doc-toolbar">
          <div class="component-palette" aria-label="Insert component">
            <button type="button" class="secondary" data-insert-component="callout" disabled>Callout</button>
            <button type="button" class="secondary" data-insert-component="finding" disabled>Finding</button>
            <button type="button" class="secondary" data-insert-component="details" disabled>Details</button>
            <button type="button" class="secondary" data-insert-component="comparison" disabled>Compare</button>
            <button type="button" class="secondary" data-insert-component="section" disabled>Section</button>
          </div>
          <button type="button" id="clear-btn" class="secondary" disabled>Clear</button>
          <button type="button" id="save-btn" disabled>Save</button>
        </div>
        <span id="save-meta" class="doc-meta">Ready</span>
      </header>
      <div class="canvas-wrap">
        <div id="live-canvas" class="live-canvas live-doc-canvas" contenteditable="true"></div>
      </div>
    </section>
    <aside class="artifacts">
      <h2>Artifacts</h2>
      <ul id="artifact-list" class="artifact-list"></ul>
    </aside>
  </div>
  <script src="/_hyperspace/hyperspace-components.js"></script>
  <script src="/_hyperspace/hyperspace_live.js"></script>
</body>
</html>`;
}

function safeResolve(root, urlPath) {
  const decoded = decodeURIComponent(urlPath);
  const resolved = path.resolve(root, decoded);
  if (!resolved.startsWith(path.resolve(root))) return null;
  return resolved;
}

function serveFile(res, filePath) {
  const ext = path.extname(filePath).toLowerCase();
  const type = MIME[ext] || "application/octet-stream";
  res.writeHead(200, { "Content-Type": type });
  fs.createReadStream(filePath).pipe(res);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (chunk) => chunks.push(chunk));
    req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    req.on("error", reject);
  });
}

function json(res, status, data) {
  res.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store, max-age=0",
  });
  res.end(JSON.stringify(data));
}

function handleApi(req, res, parts, url) {
  if (parts[0] === "sessions" && req.method === "GET") {
    return json(res, 200, { sessions: sessionsPayload(discoverSessions()) });
  }

  if (parts[0] === "events" && req.method === "GET") {
    return json(res, 200, { events: readEvents(url.searchParams.get("limit") || 50) });
  }

  const route = parts[0];
  const session = findSession(route);
  if (!session) {
    return json(res, 404, { error: "session not found" });
  }

  if (parts[1] === "doc" && req.method === "GET") {
    return json(res, 200, readLiveDoc(session));
  }

  if (parts[1] === "doc" && req.method === "POST") {
    return readBody(req)
      .then((raw) => {
        const body = JSON.parse(raw || "{}");
        const canvasHtml = String(body.html ?? body.user ?? "");
        const result = writeLiveDoc(session, canvasHtml);
        return json(res, 200, { ok: true, ...result });
      })
      .catch(() => json(res, 400, { error: "invalid json" }));
  }

  return json(res, 404, { error: "not found" });
}

function serveBundledAsset(res, name) {
  const allowed = new Set([
    "hyperspace_live.css",
    "hyperspace_live.js",
    "hyperspace-components.css",
    "hyperspace-components.js",
  ]);
  if (!allowed.has(name)) {
    res.writeHead(404);
    res.end("Not found");
    return;
  }

  const filePath = ["hyperspace-components.css", "hyperspace-components.js"].includes(name)
    ? path.join(__dirname, COMPONENTS_DIR, name)
    : path.join(__dirname, name);

  if (!fs.existsSync(filePath)) {
    res.writeHead(404);
    res.end("Not found");
    return;
  }
  serveFile(res, filePath);
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url || "/", `http://${HOST}`);
  const parts = url.pathname.split("/").filter(Boolean);

  if (parts[0] === "_hyperspace" && parts.length === 2) {
    serveBundledAsset(res, parts[1]);
    return;
  }

  if (parts[0] === "api") {
    handleApi(req, res, parts.slice(1), url);
    return;
  }

  const sessions = discoverSessions();

  if (parts.length === 0) {
    res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    res.end(renderLiveDocPage(sessions));
    return;
  }

  const route = parts[0];
  const session = findSession(route);

  if (!session) {
    res.writeHead(404, { "Content-Type": "text/html; charset=utf-8" });
    res.end(renderLiveDocPage(sessions, route));
    return;
  }

  fs.mkdirSync(session.artifactDir, { recursive: true });

  if (parts.length === 1) {
    res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    res.end(renderLiveDocPage(sessions, session.route));
    return;
  }

  if (parts[1] === "preview") {
    const previewPath = liveDocPaths(session).source;
    ensureLiveDocSource(previewPath, session.artifactDir);
    serveFile(res, previewPath);
    return;
  }

  const relPath = parts.slice(1).join("/");
  const filePath = safeResolve(session.artifactDir, relPath);

  if (!filePath || !fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
    res.writeHead(404, { "Content-Type": "text/html; charset=utf-8" });
    res.end(`<h1>Not found</h1><p><code>${escapeHtml(relPath)}</code></p>`);
    return;
  }

  serveFile(res, filePath);
});

server.listen(PORT, HOST, () => {
  console.log(`hyperspace serve http://${HOST}:${PORT}`);
  console.log(`config file: ${CONFIG_FILE}`);
});
