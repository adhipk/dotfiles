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
  const commentBtn = document.getElementById("comment-btn");
  const messageForm = document.getElementById("message-form");
  const messageInput = document.getElementById("message-input");
  const messageSend = document.getElementById("message-send");
  const artifactListEl = document.getElementById("artifact-list");

  let dirty = false;
  let saving = false;
  let commentMode = false;
  let selectedCommentTarget = null;
  let composerEl = null;
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
    if (commentBtn) commentBtn.disabled = disabled;
    if (messageInput) messageInput.disabled = disabled;
    if (messageSend) messageSend.disabled = disabled || !messageInput.value.trim();
  }

  function escapeHtml(value) {
    return String(value ?? "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function persistControlState(rootEl) {
    for (const input of rootEl.querySelectorAll("input")) {
      if (input.type === "checkbox" || input.type === "radio") {
        input.toggleAttribute("checked", input.checked);
      } else {
        input.setAttribute("value", input.value);
      }
    }
    for (const textarea of rootEl.querySelectorAll("textarea")) {
      textarea.textContent = textarea.value;
    }
    for (const select of rootEl.querySelectorAll("select")) {
      for (const option of select.options) {
        option.toggleAttribute("selected", option.selected);
      }
    }
  }

  function normalizeCanvasHtml(raw) {
    const template = document.createElement("template");
    template.innerHTML = raw || "";
    persistControlState(template.content);

    const allowed = new Set([
      "A", "ARTICLE", "ASIDE", "B", "BLOCKQUOTE", "BR", "BUTTON", "CANVAS",
      "CAPTION", "CODE", "COL", "COLGROUP", "DATALIST", "DD", "DETAILS",
      "DIV", "DL", "DT", "EM", "FIELDSET", "FIGCAPTION", "FIGURE", "FORM",
      "G", "H1", "H2", "H3", "H4", "H5", "H6", "HR", "I", "IFRAME", "IMG",
      "INPUT", "LABEL", "LEGEND", "LI", "LINE", "MAIN", "MARKER", "METER",
      "NAV", "OL", "OPTGROUP", "OPTION", "OUTPUT", "P", "PATH", "POLYGON",
      "POLYLINE", "PRE", "PROGRESS", "RECT", "SCRIPT", "SECTION", "SELECT",
      "SMALL", "SPAN", "STRONG", "STYLE", "SUB", "SUMMARY", "SUP", "SVG",
      "TABLE", "TBODY", "TD", "TEXT", "TEXTAREA", "TFOOT", "TH", "THEAD",
      "TIME", "TITLE", "TR", "UL",
      "HS-CALLOUT", "HS-COMMENT", "HS-COMMENTS", "HS-COMPARISON", "HS-DETAILS",
      "HS-FINDING", "HS-MESSAGE", "HS-OPTION",
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

      if (!allowed.has(el.tagName) && !el.tagName.includes("-")) {
        const fragment = document.createDocumentFragment();
        while (el.firstChild) fragment.appendChild(el.firstChild);
        el.replaceWith(fragment);
      }
    }

    for (const child of [...template.content.children]) normalizeElement(child);
    return template.innerHTML.trim();
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
      canvasEl.className = "empty-state";
      canvasEl.innerHTML = message;
    }
    if (saveBtn) saveBtn.disabled = true;
    setCanvasEnabled(false);
  }

  function applyDoc(data, force) {
    if (canvasEl && (force || !dirty)) {
      canvasEl.className = "live-canvas live-doc-canvas";
      canvasEl.innerHTML = data.html || "";
      hydrateCommentAnchors();
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
    if (commentBtn) commentBtn.disabled = true;
    setCanvasEnabled(false);
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

  function setCommentMode(value) {
    commentMode = Boolean(value);
    canvasEl?.classList.toggle("comment-mode", commentMode);
    if (commentBtn) {
      commentBtn.classList.toggle("active", commentMode);
      commentBtn.textContent = commentMode ? "Select" : "Comment";
    }
    if (saveMetaEl && commentMode) {
      saveMetaEl.className = "doc-meta";
      saveMetaEl.textContent = "Select part of the artifact";
    }
    if (!commentMode) closeCommentComposer();
  }

  function commentTargetFrom(eventTarget) {
    if (!canvasEl || !(eventTarget instanceof Element)) return null;
    if (eventTarget.closest("hs-comment, hs-message, .hs-user-comment, .hs-user-message, .comment-composer")) return null;
    const target = eventTarget.closest([
      "[data-commentable]",
      "hs-callout", "hs-comparison", "hs-details", "hs-finding", "hs-option",
      "article", "section", "aside", "form", "table", "figure", "details", "blockquote",
      "pre", "canvas", "svg", "h1", "h2", "h3", "h4", "p", "li",
    ].join(","));
    if (!target || target === canvasEl || !canvasEl.contains(target)) return null;
    return target;
  }

  function ensureDomId(target) {
    if (target.id) return `#${target.id}`;
    if (!target.dataset.hsId) {
      target.dataset.hsId = `hs-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
    }
    return `@dom:${target.dataset.hsId}`;
  }

  function insertAtCursor(textarea, text) {
    const start = textarea.selectionStart ?? textarea.value.length;
    const end = textarea.selectionEnd ?? textarea.value.length;
    const before = textarea.value.slice(0, start);
    const after = textarea.value.slice(end);
    const prefix = before && !/\s$/.test(before) ? " " : "";
    const suffix = after && !/^\s/.test(after) ? " " : "";
    textarea.value = `${before}${prefix}${text}${suffix}${after}`;
    const next = start + prefix.length + text.length + suffix.length;
    textarea.setSelectionRange(next, next);
    textarea.focus();
    setCanvasEnabled(Boolean(activeRoute));
  }

  function isMessageAddressing() {
    return document.activeElement === messageInput;
  }

  function ensureCommentId(target) {
    if (!target.dataset.commentId) {
      target.dataset.commentId = `c-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
    }
    return target.dataset.commentId;
  }

  function commentsContainer() {
    let container = canvasEl.querySelector(":scope > hs-comments");
    if (!container) {
      container = document.createElement("hs-comments");
      container.setAttribute("aria-label", "User comments");
      canvasEl.appendChild(container);
    }
    return container;
  }

  function hydrateCommentAnchors() {
    if (!canvasEl) return;
    canvasEl.querySelectorAll("[data-comment-count]").forEach((el) => {
      el.removeAttribute("data-comment-count");
    });
    const counts = new Map();
    for (const comment of canvasEl.querySelectorAll("hs-comment[data-comment-for]")) {
      const id = comment.getAttribute("data-comment-for");
      counts.set(id, (counts.get(id) || 0) + 1);
    }
    for (const [id, count] of counts) {
      const target = canvasEl.querySelector(`[data-comment-id="${CSS.escape(id)}"]`);
      if (target) target.setAttribute("data-comment-count", String(count));
    }
  }

  function targetLabel(target) {
    const explicit = target.getAttribute("aria-label") || target.getAttribute("data-label");
    if (explicit) return explicit;
    const heading = target.querySelector?.("h1, h2, h3, h4, summary");
    const text = (heading?.textContent || target.textContent || target.tagName.toLowerCase()).trim();
    return text.length > 80 ? `${text.slice(0, 77)}...` : text;
  }

  function ensureCommentComposer() {
    if (composerEl) return composerEl;
    composerEl = document.createElement("div");
    composerEl.className = "comment-composer";
    composerEl.innerHTML = [
      '<div class="comment-composer__header">',
      '  <div>',
      '    <strong>Comment</strong>',
      '    <span data-comment-context></span>',
      '  </div>',
      '  <button type="button" class="icon-btn" data-comment-close aria-label="Close">×</button>',
      '</div>',
      '<textarea rows="4" placeholder="Leave feedback for the agent"></textarea>',
      '<div class="comment-composer__actions">',
      '  <button type="button" class="secondary" data-comment-cancel>Cancel</button>',
      '  <button type="button" data-comment-add>Add Comment</button>',
      '</div>',
    ].join("");
    document.body.appendChild(composerEl);
    composerEl.querySelector("[data-comment-close]").addEventListener("click", () => {
      closeCommentComposer();
      setCommentMode(false);
    });
    composerEl.querySelector("[data-comment-cancel]").addEventListener("click", () => {
      closeCommentComposer();
      setCommentMode(false);
    });
    composerEl.querySelector("[data-comment-add]").addEventListener("click", commitComment);
    composerEl.querySelector("textarea").addEventListener("keydown", (event) => {
      if ((event.metaKey || event.ctrlKey) && event.key === "Enter") {
        event.preventDefault();
        commitComment();
      }
    });
    return composerEl;
  }

  function positionComposer(target) {
    if (!composerEl || !target) return;
    const rect = target.getBoundingClientRect();
    const width = Math.min(360, window.innerWidth - 24);
    const left = Math.min(Math.max(12, rect.right + 12), window.innerWidth - width - 12);
    const top = Math.min(Math.max(12, rect.top), window.innerHeight - 260);
    composerEl.style.width = `${width}px`;
    composerEl.style.left = `${left}px`;
    composerEl.style.top = `${top}px`;
  }

  function openCommentComposer(target) {
    canvasEl.querySelectorAll(".hs-comment-target").forEach((el) => el.classList.remove("hs-comment-target"));
    selectedCommentTarget = target;
    target.classList.add("hs-comment-target");
    const composer = ensureCommentComposer();
    composer.querySelector("[data-comment-context]").textContent = targetLabel(target);
    composer.querySelector("textarea").value = "";
    composer.classList.add("is-open");
    positionComposer(target);
    requestAnimationFrame(() => composer.querySelector("textarea").focus());
  }

  function closeCommentComposer() {
    selectedCommentTarget?.classList.remove("hs-comment-target");
    selectedCommentTarget = null;
    composerEl?.classList.remove("is-open");
  }

  function commitComment() {
    if (!selectedCommentTarget || !composerEl) return;
    const textarea = composerEl.querySelector("textarea");
    const text = textarea.value;
    if (!text || !text.trim()) {
      textarea.focus();
      return;
    }
    const target = selectedCommentTarget;
    const commentId = ensureCommentId(target);
    const comment = document.createElement("hs-comment");
    comment.className = "hs-user-comment";
    comment.setAttribute("data-comment-for", commentId);
    comment.setAttribute("data-created-at", new Date().toISOString());
    comment.innerHTML = `<strong>User comment</strong><p>${escapeHtml(text.trim())}</p>`;
    commentsContainer().appendChild(comment);
    hydrateCommentAnchors();
    setDirty(true);
    setCommentMode(false);
    if (saveMetaEl) {
      saveMetaEl.className = "doc-meta dirty";
      saveMetaEl.textContent = "Comment added, not saved";
    }
  }

  async function sendMessage() {
    if (!canvasEl || !activeRoute || saving || !messageInput?.value.trim()) return;
    const message = document.createElement("hs-message");
    message.className = "hs-user-message";
    message.setAttribute("data-created-at", new Date().toISOString());
    message.innerHTML = `<strong>User message</strong><p>${escapeHtml(messageInput.value.trim())}</p>`;
    canvasEl.appendChild(message);
    messageInput.value = "";
    setDirty(true);
    await saveDoc(activeRoute);
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
        canvasEl.innerHTML = "";
      }
      setDirty(false);
      setCanvasEnabled(true);
    });
  }

  canvasEl?.addEventListener("input", () => setDirty(true));
  canvasEl?.addEventListener("change", () => setDirty(true));

  canvasEl?.addEventListener("pointerdown", (event) => {
    if (!isMessageAddressing()) return;
    const target = commentTargetFrom(event.target);
    if (!target) return;
    event.preventDefault();
    event.stopPropagation();
    insertAtCursor(messageInput, ensureDomId(target));
    target.classList.add("hs-reference-target");
    window.setTimeout(() => target.classList.remove("hs-reference-target"), 700);
  });

  canvasEl?.addEventListener("click", (event) => {
    if (isMessageAddressing()) return;
    if (!commentMode) return;
    const target = commentTargetFrom(event.target);
    if (!target) return;
    event.preventDefault();
    event.stopPropagation();
    openCommentComposer(target);
  });

  window.addEventListener("resize", () => positionComposer(selectedCommentTarget));
  document.addEventListener("scroll", () => positionComposer(selectedCommentTarget), true);

  saveBtn?.addEventListener("click", () => {
    if (activeRoute) saveDoc(activeRoute);
  });

  commentBtn?.addEventListener("click", () => setCommentMode(!commentMode));

  messageInput?.addEventListener("input", () => setCanvasEnabled(Boolean(activeRoute)));

  messageInput?.addEventListener("focus", () => {
    canvasEl?.classList.add("reference-mode");
    if (saveMetaEl) {
      saveMetaEl.className = "doc-meta";
      saveMetaEl.textContent = "Click artifact elements to reference them";
    }
  });

  messageInput?.addEventListener("blur", () => {
    window.setTimeout(() => {
      if (document.activeElement !== messageInput) canvasEl?.classList.remove("reference-mode");
    }, 0);
  });

  messageInput?.addEventListener("keydown", (event) => {
    if ((event.metaKey || event.ctrlKey) && event.key === "Enter") {
      event.preventDefault();
      sendMessage();
    }
  });

  messageForm?.addEventListener("submit", (event) => {
    event.preventDefault();
    sendMessage();
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && commentMode) {
      event.preventDefault();
      closeCommentComposer();
      setCommentMode(false);
      return;
    }
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
