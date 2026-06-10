/**
 * Hyperspace generative UI — native web components (light DOM).
 * Agents compose: <hs-callout>, <hs-finding>, <hs-comparison>, <hs-option>, <hs-details>
 */
(function () {
  function defineIfMissing(name, ctor) {
    if (!customElements.get(name)) customElements.define(name, ctor);
  }

  /** Presentational shell — styling via hyperspace-components.css */
  class HsCallout extends HTMLElement {}
  class HsFinding extends HTMLElement {}
  class HsOption extends HTMLElement {}

  /**
   * <hs-comparison title="…">
   *   <hs-option title="A">…</hs-option>
   * </hs-comparison>
   */
  class HsComparison extends HTMLElement {
    connectedCallback() {
      if (this.dataset.hsReady) return;
      this.dataset.hsReady = "1";

      const title = this.getAttribute("title");
      if (title && !this.querySelector("h2")) {
        const h2 = document.createElement("h2");
        h2.textContent = title;
        this.prepend(h2);
      }

      const options = [...this.querySelectorAll(":scope > hs-option")];
      if (options.length === 0) return;

      let grid = this.querySelector(":scope > .hs-grid");
      if (!grid) {
        grid = document.createElement("div");
        grid.className = "hs-grid";
        this.append(grid);
      }

      for (const option of options) {
        if (!option.getAttribute("title")) continue;
        if (option.querySelector("h3")) continue;
        const h3 = document.createElement("h3");
        h3.textContent = option.getAttribute("title");
        option.prepend(h3);
      }

      for (const option of options) {
        if (option.parentElement === grid) continue;
        grid.append(option);
      }
    }
  }

  /**
   * <hs-details summary="…">content</hs-details>
   * or <hs-details><details><summary>…</summary>…</details></hs-details>
   */
  class HsDetails extends HTMLElement {
    connectedCallback() {
      if (this.querySelector("details")) return;

      const summary = this.getAttribute("summary");
      if (!summary) return;

      const open = this.hasAttribute("open");
      const content = this.innerHTML;

      const details = document.createElement("details");
      if (open) details.open = true;

      const summaryEl = document.createElement("summary");
      summaryEl.textContent = summary;
      details.append(summaryEl);

      const body = document.createElement("div");
      body.innerHTML = content;
      details.append(body);

      this.innerHTML = "";
      this.append(details);
    }
  }

  defineIfMissing("hs-callout", HsCallout);
  defineIfMissing("hs-finding", HsFinding);
  defineIfMissing("hs-comparison", HsComparison);
  defineIfMissing("hs-option", HsOption);
  defineIfMissing("hs-details", HsDetails);
})();
