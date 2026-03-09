// A2UI Phoenix LiveView Hooks
window.A2UIHooks = {
  A2UITabs: {
    mounted() {
      this.el.addEventListener("click", (e) => {
        const tab = e.target.closest("[role='tab']");
        if (!tab) return;

        const index = parseInt(tab.dataset.tabIndex, 10);
        const tabs = this.el.querySelectorAll("[role='tab']");
        const panels = this.el.querySelectorAll("[role='tabpanel']");

        tabs.forEach((t, i) => {
          const active = i === index;
          t.classList.toggle("a2ui-tabs__tab--active", active);
          t.setAttribute("aria-selected", String(active));
        });

        panels.forEach((p, i) => {
          const active = i === index;
          p.classList.toggle("a2ui-tabs__panel--active", active);
          p.classList.toggle("a2ui-tabs__panel--hidden", !active);
        });
      });
    }
  }
};
