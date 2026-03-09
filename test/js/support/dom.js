// Minimal DOM stubs for testing A2UI hooks outside the browser.

/**
 * Create a mock DOM element with the subset of APIs used by A2UI hooks.
 *
 * @param {string} tag - HTML tag name (e.g. "div", "input")
 * @param {object} opts
 * @param {string[]} opts.classes - Initial CSS classes
 * @param {object} opts.attrs - Attribute key/value pairs
 * @param {object} opts.dataset - data-* attribute key/value pairs
 * @param {MockElement[]} opts.children - Child elements
 * @param {string} opts.role - Shorthand for attrs.role
 * @param {string} opts.hook - Shorthand for attrs["phx-hook"]
 * @returns {MockElement}
 */
export function mockElement(tag, { classes = [], attrs = {}, dataset = {}, children = [], role, hook } = {}) {
  const _classes = new Set(classes);
  const _attrs = { ...attrs };
  const _listeners = {};
  const _style = {};

  if (role) _attrs.role = role;
  if (hook) _attrs["phx-hook"] = hook;

  const el = {
    tagName: tag.toUpperCase(),
    textContent: "",
    value: "",
    dataset: { ...dataset },
    children,
    style: _style,

    classList: {
      add(cls) { _classes.add(cls); },
      remove(cls) { _classes.delete(cls); },
      contains(cls) { return _classes.has(cls); },
      toggle(cls, force) {
        if (force === undefined) {
          _classes.has(cls) ? _classes.delete(cls) : _classes.add(cls);
        } else {
          force ? _classes.add(cls) : _classes.delete(cls);
        }
      },
    },

    getAttribute(name) {
      return _attrs[name] ?? null;
    },

    setAttribute(name, value) {
      _attrs[name] = value;
    },

    addEventListener(event, handler, options) {
      if (!_listeners[event]) _listeners[event] = [];
      _listeners[event].push({ handler, capture: options === true || (options && options.capture) });
    },

    // Dispatch a synthetic event to registered listeners
    dispatchEvent(event) {
      const handlers = _listeners[event.type] || [];
      for (const { handler } of handlers) handler(event);
    },

    querySelector(selector) {
      return _findInTree(el, selector, false);
    },

    querySelectorAll(selector) {
      return _findInTree(el, selector, true);
    },

    closest(selector) {
      // Walk up via _parent (set by addChild)
      let current = el;
      while (current) {
        if (_matchesSelector(current, selector)) return current;
        current = current._parent;
      }
      return null;
    },
  };

  // Set parent refs on children
  for (const child of children) {
    child._parent = el;
  }

  return el;
}

/**
 * Append a child to a parent, setting _parent back-reference.
 */
export function addChild(parent, child) {
  parent.children.push(child);
  child._parent = parent;
}

/**
 * Create a minimal synthetic event object.
 */
export function mockEvent(type, { target } = {}) {
  return {
    type,
    target: target || null,
    _defaultPrevented: false,
    _propagationStopped: false,
    preventDefault() { this._defaultPrevented = true; },
    stopPropagation() { this._propagationStopped = true; },
  };
}

// --- Internals ---

function _matchesSelector(el, selector) {
  // Handle comma-separated selectors (e.g. "input, textarea")
  if (selector.includes(",")) {
    return selector.split(",").some((s) => _matchesSingle(el, s.trim()));
  }
  return _matchesSingle(el, selector);
}

function _matchesSingle(el, selector) {
  // Supports: .class, [attr], [attr='value'], tag
  if (selector.startsWith(".")) {
    const cls = selector.slice(1);
    return el.classList && el.classList.contains(cls);
  }

  const attrMatch = selector.match(/^\[([^\]=]+)(?:='([^']*)')?\]$/);
  if (attrMatch) {
    const [, name, value] = attrMatch;
    const actual = el.getAttribute ? el.getAttribute(name) : null;
    if (value !== undefined) return actual === value;
    return actual !== null;
  }

  // tag name
  return el.tagName === selector.toUpperCase();
}

function _findInTree(root, selector, all) {
  const results = [];

  function walk(node) {
    for (const child of (node.children || [])) {
      if (_matchesSelector(child, selector)) {
        results.push(child);
        if (!all) return;
      }
      walk(child);
    }
  }

  walk(root);
  return all ? results : (results[0] || null);
}
