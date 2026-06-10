(function () {
  const root = document.querySelector(".hyperspace-app");
  if (!root) return;

  const sessions = JSON.parse(root.dataset.sessions || "[]");
  const activeRoute = root.dataset.route || "";
  const canvasEl = document.getElementById("live-canvas");
  const titleEl = document.getElementById("doc-title");
  const statusEl = document.getElementById("doc-status");
  const saveMetaEl = document.getElementById("save-meta");
  const saveBtn = document.getElementById("save-btn");
  const clearBtn = document.getElementById("clear-btn");
  const insertButtons = [...document.querySelectorAll("[data-insert-component]")];
  const artifactListEl = document.getElementById("artifact-list");

  let dirty = false;
  let saving = false;
  let pollTimer = null;
  let lastVersion = 0;

  function sessionByRoute(route) {
    return sessions.find((s) => s.route === route);
  }

  function setRunStatus(status, savedAt) {
    if (!saveMetaEl) return;
    if (status === "running" || status === "queued") {
      saveMetaEl.className = "doc-meta dirty";
      saveMetaEl.textContent = "Run active...";
      return;
    }
    if (status === "blocked") {
      saveMetaEl.className = "doc-meta dirty";
      saveMetaEl.textContent = "Run blocked";
      return;
    }
    saveMetaEl.className = "doc-meta saved";
    saveMetaEl.textContent = savedAt ? `Saved ${new Date(savedAt).toLocaleString()}` : "Ready";
  }

  function setDirty(value) {
    dirty = value;
    if (saveBtn) saveBtn.disabled = !activeRoute || saving || !dirty;
  }

  function setCanvasEnabled(value) {
    const disabled = !activeRoute || saving || !value;
    if (clearBtn) clearBtn.disabled = disabled;
    for (const button of insertButtons) button.disabled = disabled;
  }

  function normalizeCanvasHtml(raw) {
    const template = document.createElement("template");
    template.innerHTML = raw || "";

    const allowed = new Set([
      "A", "B", "BLOCKQUOTE", "BR", "CODE", "DIV", "EM", "H1", "H2", "H3", "H4",
      "HR", "I", "IMG", "LI", "OL", "P", "PRE", "SCRIPT", "SPAN", "STRONG",
      "TABLE", "TBODY", "TD", "TH", "THEAD", "TR", "UL",
      "HS-CALLOUT", "HS-COMPARISON", "HS-DETAILS", "HS-FINDING", "HS-OPTION",
    ]);
    const rename = new Map([
      ["B", "strong"],
      ["I", "em"],
      ["BOLD", "strong"],
      ["ITALIC", "em"],
    ]);

    function normalizeElement(el) {
      for (const child of [...el.children]) normalizeElement(child);

      const replacementTag = rename.get(el.tagName);
      if (replacementTag) {
        const replacement = document.createElement(replacementTag);
        for (const attr of [...el.attributes]) replacement.setAttribute(attr.name, attr.value);
        while (el.firstChild) replacement.appendChild(el.firstChild);
        el.replaceWith(replacement);
        return;
      }

      if (!allowed.has(el.tagName)) {
        const fragment = document.createDocumentFragment();
        while (el.firstChild) fragment.appendChild(el.firstChild);
        el.replaceWith(fragment);
      }
    }

    for (const child of [...template.content.children]) normalizeElement(child);
    return template.innerHTML.trim();
  }

  function componentTemplate(type) {
    switch (type) {
      case "callout":
        return '<hs-callout variant="info" label="Note"><p>New note.</p></hs-callout>';
      case "finding":
        return '<hs-finding severity="low"><h3>Finding</h3><p>What changed and why it matters.</p></hs-finding>';
      case "details":
        return '<hs-details summary="Details"><p>Add supporting context here.</p></hs-details>';
      case "comparison":
        return [
          '<hs-comparison title="Options">',
          '<hs-option title="Option A"><p>Describe the first path.</p></hs-option>',
          '<hs-option title="Option B"><p>Describe the second path.</p></hs-option>',
          "</hs-comparison>",
        ].join("");
      case "section":
        return "<h2>Section</h2><p>Start writing here.</p>";
      default:
        return "";
    }
  }

  function selectionInsideCanvas() {
    const selection = window.getSelection();
    if (!selection || selection.rangeCount === 0 || !canvasEl) return null;
    const range = selection.getRangeAt(0);
    if (!canvasEl.contains(range.commonAncestorContainer)) return null;
    return range;
  }

  function placeCursorAfter(node) {
    const selection = window.getSelection();
    if (!selection || !node?.parentNode) return;
    const range = document.createRange();
    range.setStartAfter(node);
    range.collapse(true);
    selection.removeAllRanges();
    selection.addRange(range);
  }

  function insertComponent(type) {
    if (!canvasEl || !activeRoute || saving) return;

    const html = componentTemplate(type);
    if (!html) return;

    canvasEl.className = "live-canvas live-doc-canvas";
    canvasEl.contentEditable = "true";

    const activeRange = selectionInsideCanvas();
    const range = activeRange || document.createRange();
    if (!activeRange) {
      range.selectNodeContents(canvasEl);
      range.collapse(false);
    }

    const fragment = range.createContextualFragment(html);
    const inserted = fragment.lastElementChild || fragment.lastChild;
    range.deleteContents();
    range.insertNode(fragment);
    canvasEl.focus();

    if (inserted?.isConnected) {
      placeCursorAfter(inserted);
    } else {
      const last = canvasEl.lastElementChild || canvasEl.lastChild;
      placeCursorAfter(last);
    }

    setDirty(true);
    setCanvasEnabled(true);
  }

  function renderArtifacts(session) {
    if (!artifactListEl) return;
    artifactListEl.innerHTML = "";
    const files = new Set(session?.artifacts || []);
    files.add("livedoc.html");
    for (const file of [...files].sort()) {
      const li = document.createElement("li");
      const a = document.createElement("a");
      const href =
        file === "livedoc.html"
          ? `/${encodeURIComponent(session.route)}/preview/`
          : `/${encodeURIComponent(session.route)}/${file}`;
      a.href = href;
      a.textContent = file;
      a.target = "_blank";
      li.appendChild(a);
      artifactListEl.appendChild(li);
    }
  }

  function showEmpty(message) {
    stopPoll();
    if (canvasEl) {
      canvasEl.contentEditable = "false";
      canvasEl.className = "empty-state";
      canvasEl.innerHTML = message;
    }
    if (saveBtn) saveBtn.disabled = true;
    setCanvasEnabled(false);
  }

  function applyDoc(data, force) {
    if (canvasEl && (force || !dirty)) {
      canvasEl.className = "live-canvas live-doc-canvas";
      canvasEl.contentEditable = "true";
      canvasEl.innerHTML = data.html || "";
      setCanvasEnabled(true);
    }
    lastVersion = data.version || lastVersion;
    setRunStatus(data.status, data.savedAt);
    if (statusEl) {
      statusEl.className = `badge ${data.status === "running" || data.status === "queued" ? "running" : data.status === "blocked" ? "needs-input" : "idle"}`;
      statusEl.textContent = data.status || "idle";
    }
  }

  async function fetchDoc(route) {
    const response = await fetch(`/api/${encodeURIComponent(route)}/doc?t=${Date.now()}`, {
      cache: "no-store",
    });
    if (!response.ok) throw new Error("load failed");
    return response.json();
  }

  async function loadDoc(route) {
    const data = await fetchDoc(route);
    applyDoc(data, true);
    setDirty(false);
    if (data.status === "running" || data.status === "queued" || data.pending) {
      startPoll(route);
    }
  }

  function startPoll(route) {
    stopPoll();
    pollTimer = setInterval(async () => {
      try {
        const data = await fetchDoc(route);
        const terminal = data.status === "done" || data.status === "blocked" || data.status === "error";
        if (!dirty && (terminal || (data.version || 0) > lastVersion)) {
          applyDoc(data, true);
        } else {
          applyDoc(data, false);
        }
        if (terminal) {
          stopPoll();
        }
      } catch {
        /* keep polling */
      }
    }, 2000);
  }

  function stopPoll() {
    if (pollTimer) clearInterval(pollTimer);
    pollTimer = null;
  }

  async function saveDoc(route) {
    if (!canvasEl || saving) return;
    saving = true;
    if (saveBtn) saveBtn.disabled = true;
    if (clearBtn) clearBtn.disabled = true;
    saveMetaEl.textContent = "Saving…";

    try {
      const response = await fetch(`/api/${encodeURIComponent(route)}/doc`, {
        method: "POST",
        cache: "no-store",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ html: normalizeCanvasHtml(canvasEl.innerHTML) }),
      });
      if (!response.ok) throw new Error("save failed");
      const data = await response.json();
      lastVersion = data.version || lastVersion;
      setDirty(false);
      setRunStatus(data.status || "queued", data.savedAt);
      startPoll(route);
      const session = sessionByRoute(route);
      if (session) {
        session.artifacts = [...new Set([...(session.artifacts || []), "livedoc.html"])];
        renderArtifacts(session);
      }
    } catch {
      saveMetaEl.textContent = "Save failed";
      saveMetaEl.className = "doc-meta dirty";
    } finally {
      saving = false;
      if (saveBtn) saveBtn.disabled = !dirty;
      setCanvasEnabled(Boolean(activeRoute));
    }
  }

  function clearCanvas() {
    if (!canvasEl || !activeRoute || saving) return;
    stopPoll();
    canvasEl.className = "live-canvas live-doc-canvas";
    canvasEl.contentEditable = "true";
    canvasEl.innerHTML = "";
    canvasEl.focus();
    setDirty(true);
    setCanvasEnabled(true);
    if (saveMetaEl) {
      saveMetaEl.className = "doc-meta dirty";
      saveMetaEl.textContent = "Cleared, not saved";
    }
  }

  function bootSession(route) {
    const session = sessionByRoute(route);
    if (!session) {
      showEmpty("Session not found. Pick a project from the sidebar.");
      return;
    }

    titleEl.textContent = session.project;
    renderArtifacts(session);
    loadDoc(route).catch(() => {
      if (canvasEl) {
        canvasEl.className = "live-canvas live-doc-canvas";
        canvasEl.contentEditable = "true";
        canvasEl.innerHTML = "";
      }
      setDirty(false);
      setCanvasEnabled(true);
    });
  }

  canvasEl?.addEventListener("input", () => setDirty(true));

  canvasEl?.addEventListener("paste", (event) => {
    const text = event.clipboardData?.getData("text/plain");
    if (!text) return;
    event.preventDefault();
    document.execCommand("insertText", false, text);
    setDirty(true);
  });

  saveBtn?.addEventListener("click", () => {
    if (activeRoute) saveDoc(activeRoute);
  });

  clearBtn?.addEventListener("click", clearCanvas);

  for (const button of insertButtons) {
    button.addEventListener("click", () => insertComponent(button.dataset.insertComponent));
  }

  document.addEventListener("keydown", (event) => {
    if ((event.metaKey || event.ctrlKey) && event.key === "s") {
      event.preventDefault();
      if (activeRoute && dirty) saveDoc(activeRoute);
    }
  });

  if (!activeRoute) {
    if (sessions.length === 0) {
      showEmpty("No active sessions. Run hyperspace dotfiles in a terminal.");
    } else if (sessions.length === 1) {
      window.location.replace(`/${encodeURIComponent(sessions[0].route)}/`);
    } else {
      showEmpty("Select a project to open its live doc.");
    }
    return;
  }

  bootSession(activeRoute);
})();
