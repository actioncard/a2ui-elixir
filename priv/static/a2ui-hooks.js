// A2UI Phoenix LiveView Hooks
const A2UIHooks = {
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
  },

  A2UIModal: {
    mounted() {
      const entry = this.el.querySelector(".a2ui-modal__entry");
      const overlay = this.el.querySelector(".a2ui-modal__overlay");
      if (!entry || !overlay) return;

      entry.addEventListener("click", () => {
        overlay.classList.remove("a2ui-modal__overlay--hidden");
      });

      overlay.addEventListener("click", (e) => {
        if (e.target === overlay) {
          overlay.classList.add("a2ui-modal__overlay--hidden");
        }
      });
    }
  },

  A2UISubmit: {
    mounted() {
      this.el.addEventListener("click", (e) => {
        const surface = this.el.closest(".a2ui-surface");
        if (!surface) return;

        const validators = surface.querySelectorAll("[phx-hook='A2UIValidation']");
        if (validators.length === 0) return;

        // Force validation on every field (even untouched ones)
        let hasErrors = false;
        validators.forEach((el) => {
          const v = el._a2uiValidation;
          if (!v) return;
          v.blurred = true;
          v.validate();
          if (el.classList.contains("a2ui-text-field--invalid")) {
            hasErrors = true;
          }
        });

        if (hasErrors) {
          e.preventDefault();
          e.stopPropagation();
        }
      }, true); // capture phase — runs before LiveView's handler
    }
  },

  A2UIValidation: {
    mounted() {
      this._input = this.el.querySelector("input, textarea");
      this._error = this.el.querySelector(".a2ui-text-field__error");
      this._checks = this._parseChecks();
      this._blurred = false;

      // Expose validation API for A2UISubmit hook
      this.el._a2uiValidation = {
        blurred: false,
        validate: () => {
          this._blurred = this.el._a2uiValidation.blurred;
          this._validate();
        }
      };

      if (this._input) {
        this._input.addEventListener("blur", () => {
          this._blurred = true;
          this.el._a2uiValidation.blurred = true;
          this._validate();
        });
      }
    },

    updated() {
      this._checks = this._parseChecks();
      if (this._blurred) this._validate();
    },

    _parseChecks() {
      const raw = this.el.dataset.a2uiChecks;
      if (!raw) return [];
      try { return JSON.parse(raw); } catch (_) { return []; }
    },

    _validate() {
      const value = this._input ? this._input.value : "";

      for (const check of this._checks) {
        const fn = A2UI_VALIDATORS[check.call];
        if (!fn) continue;
        if (!fn(value, check.args || {})) {
          this._showError(check.message || "Invalid");
          return;
        }
      }

      this._clearError();
    },

    _showError(msg) {
      this.el.classList.add("a2ui-text-field--invalid");
      if (this._error) {
        this._error.textContent = msg;
        this._error.style.display = "";
      }
    },

    _clearError() {
      this.el.classList.remove("a2ui-text-field--invalid");
      if (this._error) {
        this._error.textContent = "";
        this._error.style.display = "none";
      }
    }
  }
};

const A2UI_VALIDATORS = {
  required(value, _args) {
    return value.trim() !== "";
  },

  regex(value, args) {
    if (value === "") return true;
    try { return new RegExp(args.pattern).test(value); } catch (_) { return true; }
  },

  length(value, args) {
    if (value === "") return true;
    if (args.min != null && value.length < args.min) return false;
    if (args.max != null && value.length > args.max) return false;
    return true;
  },

  numeric(value, args) {
    if (value === "") return true;
    const n = parseFloat(value);
    if (isNaN(n)) return false;
    if (args.min != null && n < args.min) return false;
    if (args.max != null && n > args.max) return false;
    return true;
  },

  email(value, _args) {
    if (value === "") return true;
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
  }
};

// Local action dispatch map
const A2UI_LOCAL_ACTIONS = {
  openUrl(_event, args) { window.open(args.url, "_blank", "noopener"); }
};

/**
 * Dispatch a local action from an element's data-a2ui-action attribute.
 * Returns true if an action was dispatched, false otherwise.
 */
function dispatchLocalAction(event, el) {
  let action;
  try { action = JSON.parse(el.dataset.a2uiAction); } catch (_) { return false; }

  const fn = A2UI_LOCAL_ACTIONS[action.call];
  if (fn) {
    fn(event, action.args || {});
    return true;
  }

  console.warn("A2UI: unknown local action:", action.call);
  return false;
}

// Browser: attach to window for LiveView hook registration
if (typeof window !== "undefined") {
  window.A2UIHooks = A2UIHooks;
  window.A2UI_LOCAL_ACTIONS = A2UI_LOCAL_ACTIONS;

  // Delegated click handler for local actions
  document.addEventListener("click", (e) => {
    const target = e.target.closest("[data-a2ui-action]");
    if (!target) return;
    dispatchLocalAction(e, target);
  });
}

// Test: CommonJS export for Bun
if (typeof module !== "undefined") {
  module.exports = {
    A2UIHooks, A2UI_VALIDATORS, A2UI_LOCAL_ACTIONS, dispatchLocalAction
  };
}
