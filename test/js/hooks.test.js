import { describe, test, expect, beforeEach } from "bun:test";
import { mockElement, addChild, mockEvent } from "./support/dom.js";
const { A2UIHooks, A2UI_LOCAL_ACTIONS, dispatchLocalAction } = require("../../priv/static/a2ui-hooks.js");

// Helper: create a fresh hook instance bound to an element, then call mounted()
function mountHook(hookName, el) {
  const hook = Object.create(A2UIHooks[hookName]);
  hook.el = el;
  hook.mounted();
  return hook;
}

// ─── A2UITabs ────────────────────────────────────────────────────────────────

describe("A2UITabs", () => {
  let container, tabs, panels;

  beforeEach(() => {
    tabs = [
      mockElement("button", { role: "tab", dataset: { tabIndex: "0" }, classes: ["a2ui-tabs__tab--active"], attrs: { "aria-selected": "true" } }),
      mockElement("button", { role: "tab", dataset: { tabIndex: "1" }, attrs: { "aria-selected": "false" } }),
    ];
    panels = [
      mockElement("div", { role: "tabpanel", classes: ["a2ui-tabs__panel--active"] }),
      mockElement("div", { role: "tabpanel", classes: ["a2ui-tabs__panel--hidden"] }),
    ];
    container = mockElement("div", { children: [...tabs, ...panels] });
    mountHook("A2UITabs", container);
  });

  test("clicking second tab activates it", () => {
    const event = mockEvent("click", { target: tabs[1] });
    container.dispatchEvent(event);

    expect(tabs[0].classList.contains("a2ui-tabs__tab--active")).toBe(false);
    expect(tabs[0].getAttribute("aria-selected")).toBe("false");
    expect(tabs[1].classList.contains("a2ui-tabs__tab--active")).toBe(true);
    expect(tabs[1].getAttribute("aria-selected")).toBe("true");

    expect(panels[0].classList.contains("a2ui-tabs__panel--active")).toBe(false);
    expect(panels[0].classList.contains("a2ui-tabs__panel--hidden")).toBe(true);
    expect(panels[1].classList.contains("a2ui-tabs__panel--active")).toBe(true);
    expect(panels[1].classList.contains("a2ui-tabs__panel--hidden")).toBe(false);
  });

  test("clicking non-tab element does nothing", () => {
    const randomChild = mockElement("span");
    addChild(container, randomChild);
    // closest("[role='tab']") returns null for a span without role
    const event = mockEvent("click", { target: randomChild });
    container.dispatchEvent(event);

    // State unchanged
    expect(tabs[0].classList.contains("a2ui-tabs__tab--active")).toBe(true);
  });
});

// ─── A2UIModal ───────────────────────────────────────────────────────────────

describe("A2UIModal", () => {
  let container, entry, overlay, content;

  beforeEach(() => {
    content = mockElement("div", { classes: ["a2ui-modal__content"] });
    overlay = mockElement("div", { classes: ["a2ui-modal__overlay", "a2ui-modal__overlay--hidden"], children: [content] });
    entry = mockElement("div", { classes: ["a2ui-modal__entry"] });
    container = mockElement("div", { children: [entry, overlay] });
    mountHook("A2UIModal", container);
  });

  test("clicking entry removes --hidden from overlay", () => {
    entry.dispatchEvent(mockEvent("click"));
    expect(overlay.classList.contains("a2ui-modal__overlay--hidden")).toBe(false);
  });

  test("clicking overlay background adds --hidden", () => {
    // First open the modal
    entry.dispatchEvent(mockEvent("click"));
    expect(overlay.classList.contains("a2ui-modal__overlay--hidden")).toBe(false);

    // Click on overlay itself (not content)
    overlay.dispatchEvent(mockEvent("click", { target: overlay }));
    expect(overlay.classList.contains("a2ui-modal__overlay--hidden")).toBe(true);
  });

  test("clicking content inside overlay does NOT close", () => {
    entry.dispatchEvent(mockEvent("click"));

    // Click target is the content div, not the overlay
    overlay.dispatchEvent(mockEvent("click", { target: content }));
    expect(overlay.classList.contains("a2ui-modal__overlay--hidden")).toBe(false);
  });
});

// ─── A2UIValidation ──────────────────────────────────────────────────────────

describe("A2UIValidation", () => {
  function makeValidationElement(checks, inputValue = "") {
    const input = mockElement("input");
    input.value = inputValue;
    const errorSpan = mockElement("span", { classes: ["a2ui-text-field__error"] });
    errorSpan.style.display = "none";
    const el = mockElement("div", {
      dataset: checks ? { a2uiChecks: JSON.stringify(checks) } : {},
      children: [input, errorSpan],
    });
    return { el, input, errorSpan };
  }

  test("_parseChecks parses valid JSON from dataset", () => {
    const checks = [{ call: "required", message: "Required" }];
    const { el } = makeValidationElement(checks);
    const hook = mountHook("A2UIValidation", el);

    expect(hook._checks).toEqual(checks);
  });

  test("_parseChecks handles invalid JSON gracefully", () => {
    const input = mockElement("input");
    const el = mockElement("div", {
      dataset: { a2uiChecks: "not-json{" },
      children: [input],
    });
    const hook = mountHook("A2UIValidation", el);

    expect(hook._checks).toEqual([]);
  });

  test("_parseChecks handles missing attribute", () => {
    const input = mockElement("input");
    const el = mockElement("div", { children: [input] });
    const hook = mountHook("A2UIValidation", el);

    expect(hook._checks).toEqual([]);
  });

  test("_showError adds --invalid class and sets error text", () => {
    const { el, errorSpan } = makeValidationElement([]);
    const hook = mountHook("A2UIValidation", el);

    hook._showError("Field is required");

    expect(el.classList.contains("a2ui-text-field--invalid")).toBe(true);
    expect(errorSpan.textContent).toBe("Field is required");
    expect(errorSpan.style.display).toBe("");
  });

  test("_clearError removes --invalid class and hides error", () => {
    const { el, errorSpan } = makeValidationElement([]);
    const hook = mountHook("A2UIValidation", el);

    hook._showError("Error");
    hook._clearError();

    expect(el.classList.contains("a2ui-text-field--invalid")).toBe(false);
    expect(errorSpan.textContent).toBe("");
    expect(errorSpan.style.display).toBe("none");
  });

  test("blur triggers validation and shows error for required field", () => {
    const checks = [{ call: "required", message: "Required" }];
    const { el, input, errorSpan } = makeValidationElement(checks, "");
    mountHook("A2UIValidation", el);

    // Simulate blur on input
    input.dispatchEvent(mockEvent("blur"));

    expect(el.classList.contains("a2ui-text-field--invalid")).toBe(true);
    expect(errorSpan.textContent).toBe("Required");
  });

  test("blur with valid value clears error", () => {
    const checks = [{ call: "required", message: "Required" }];
    const { el, input, errorSpan } = makeValidationElement(checks, "hello");
    mountHook("A2UIValidation", el);

    input.dispatchEvent(mockEvent("blur"));

    expect(el.classList.contains("a2ui-text-field--invalid")).toBe(false);
    expect(errorSpan.textContent).toBe("");
  });

  test("_a2uiValidation API is exposed on element", () => {
    const { el } = makeValidationElement([]);
    mountHook("A2UIValidation", el);

    expect(el._a2uiValidation).toBeDefined();
    expect(typeof el._a2uiValidation.validate).toBe("function");
    expect(el._a2uiValidation.blurred).toBe(false);
  });

  test("first failing check shows its message", () => {
    const checks = [
      { call: "required", message: "Required" },
      { call: "email", message: "Invalid email" },
    ];
    const { el, input, errorSpan } = makeValidationElement(checks, "");
    mountHook("A2UIValidation", el);

    input.dispatchEvent(mockEvent("blur"));

    // required fails first, so its message is shown
    expect(errorSpan.textContent).toBe("Required");
  });

  test("updated re-parses checks and re-validates if blurred", () => {
    const { el, input, errorSpan } = makeValidationElement(
      [{ call: "required", message: "Required" }],
      "valid"
    );
    const hook = mountHook("A2UIValidation", el);

    // Blur first to set _blurred
    input.dispatchEvent(mockEvent("blur"));
    expect(el.classList.contains("a2ui-text-field--invalid")).toBe(false);

    // Simulate LiveView update: change checks and clear input
    el.dataset.a2uiChecks = JSON.stringify([{ call: "required", message: "Now required" }]);
    input.value = "";
    hook.updated();

    expect(el.classList.contains("a2ui-text-field--invalid")).toBe(true);
    expect(errorSpan.textContent).toBe("Now required");
  });
});

// ─── A2UISubmit ──────────────────────────────────────────────────────────────

describe("A2UISubmit", () => {
  function makeSurface(validatorElements) {
    const surface = mockElement("div", {
      classes: ["a2ui-surface"],
      children: validatorElements,
    });
    return surface;
  }

  function makeValidatorEl(checks, inputValue = "") {
    const input = mockElement("input");
    input.value = inputValue;
    const errorSpan = mockElement("span", { classes: ["a2ui-text-field__error"] });
    errorSpan.style.display = "none";
    const el = mockElement("div", {
      hook: "A2UIValidation",
      dataset: checks ? { a2uiChecks: JSON.stringify(checks) } : {},
      children: [input, errorSpan],
    });
    // Mount validation hook on the element
    mountHook("A2UIValidation", el);
    return el;
  }

  test("blocks click when any field is invalid", () => {
    const v1 = makeValidatorEl([{ call: "required", message: "Required" }], "");
    const v2 = makeValidatorEl([{ call: "required", message: "Required" }], "ok");
    const surface = makeSurface([v1, v2]);

    const button = mockElement("button");
    addChild(surface, button);
    mountHook("A2UISubmit", button);

    const event = mockEvent("click");
    button.dispatchEvent(event);

    expect(event._defaultPrevented).toBe(true);
    expect(event._propagationStopped).toBe(true);
  });

  test("does NOT block when all fields are valid", () => {
    const v1 = makeValidatorEl([{ call: "required", message: "Required" }], "valid");
    const v2 = makeValidatorEl([{ call: "required", message: "Required" }], "also valid");
    const surface = makeSurface([v1, v2]);

    const button = mockElement("button");
    addChild(surface, button);
    mountHook("A2UISubmit", button);

    const event = mockEvent("click");
    button.dispatchEvent(event);

    expect(event._defaultPrevented).toBe(false);
    expect(event._propagationStopped).toBe(false);
  });

  test("forces blurred=true on untouched fields", () => {
    const v1 = makeValidatorEl([{ call: "required", message: "Required" }], "");
    const surface = makeSurface([v1]);

    const button = mockElement("button");
    addChild(surface, button);
    mountHook("A2UISubmit", button);

    // v1 was never blurred
    expect(v1._a2uiValidation.blurred).toBe(false);

    button.dispatchEvent(mockEvent("click"));

    // After submit, blurred is set to true
    expect(v1._a2uiValidation.blurred).toBe(true);
  });

  test("does nothing when no validators in surface", () => {
    const surface = makeSurface([]);

    const button = mockElement("button");
    addChild(surface, button);
    mountHook("A2UISubmit", button);

    const event = mockEvent("click");
    button.dispatchEvent(event);

    expect(event._defaultPrevented).toBe(false);
  });

  test("does nothing when no surface ancestor", () => {
    const button = mockElement("button");
    mountHook("A2UISubmit", button);

    const event = mockEvent("click");
    button.dispatchEvent(event);

    expect(event._defaultPrevented).toBe(false);
  });
});

// ─── Local Actions ──────────────────────────────────────────────────────────

describe("dispatchLocalAction", () => {
  test("openUrl calls window.open with correct args", () => {
    const originalOpen = globalThis.window?.open;
    let openArgs;
    globalThis.window = globalThis.window || {};
    globalThis.window.open = (...args) => { openArgs = args; };

    const el = mockElement("button", {
      dataset: { a2uiAction: JSON.stringify({ call: "openUrl", args: { url: "https://example.com" } }) },
    });
    const event = mockEvent("click");

    const result = dispatchLocalAction(event, el);

    expect(result).toBe(true);
    expect(openArgs).toEqual(["https://example.com", "_blank", "noopener"]);

    // Restore
    if (originalOpen) globalThis.window.open = originalOpen;
  });

  test("unknown action logs warning and returns false", () => {
    const warnings = [];
    const originalWarn = console.warn;
    console.warn = (...args) => { warnings.push(args); };

    const el = mockElement("button", {
      dataset: { a2uiAction: JSON.stringify({ call: "unknownAction", args: {} }) },
    });
    const event = mockEvent("click");

    const result = dispatchLocalAction(event, el);

    expect(result).toBe(false);
    expect(warnings.length).toBe(1);
    expect(warnings[0]).toEqual(["A2UI: unknown local action:", "unknownAction"]);

    console.warn = originalWarn;
  });

  test("invalid JSON returns false silently", () => {
    const el = mockElement("button", {
      dataset: { a2uiAction: "not-valid-json{" },
    });
    const event = mockEvent("click");

    const result = dispatchLocalAction(event, el);

    expect(result).toBe(false);
  });

  test("A2UI_LOCAL_ACTIONS contains openUrl", () => {
    expect(typeof A2UI_LOCAL_ACTIONS.openUrl).toBe("function");
  });
});
