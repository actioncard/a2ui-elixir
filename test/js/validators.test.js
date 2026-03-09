import { describe, test, expect } from "bun:test";
const { A2UI_VALIDATORS } = require("../../priv/static/a2ui-hooks.js");

describe("required", () => {
  const v = A2UI_VALIDATORS.required;

  test("empty string returns false", () => {
    expect(v("", {})).toBe(false);
  });

  test("whitespace-only returns false", () => {
    expect(v("   ", {})).toBe(false);
    expect(v("\t\n", {})).toBe(false);
  });

  test("non-empty string returns true", () => {
    expect(v("hello", {})).toBe(true);
    expect(v("0", {})).toBe(true);
  });
});

describe("email", () => {
  const v = A2UI_VALIDATORS.email;

  test("empty string passes (not required)", () => {
    expect(v("", {})).toBe(true);
  });

  test("valid emails pass", () => {
    expect(v("user@example.com", {})).toBe(true);
    expect(v("a@b.co", {})).toBe(true);
  });

  test("invalid emails fail", () => {
    expect(v("not-an-email", {})).toBe(false);
    expect(v("@missing.local", {})).toBe(false);
    expect(v("no@domain", {})).toBe(false);
    expect(v("spaces in@email.com", {})).toBe(false);
  });
});

describe("regex", () => {
  const v = A2UI_VALIDATORS.regex;

  test("empty string passes (not required)", () => {
    expect(v("", { pattern: "^\\d+$" })).toBe(true);
  });

  test("matching pattern passes", () => {
    expect(v("123", { pattern: "^\\d+$" })).toBe(true);
  });

  test("non-matching pattern fails", () => {
    expect(v("abc", { pattern: "^\\d+$" })).toBe(false);
  });

  test("invalid regex pattern passes gracefully", () => {
    expect(v("anything", { pattern: "[invalid" })).toBe(true);
  });
});

describe("length", () => {
  const v = A2UI_VALIDATORS.length;

  test("empty string passes (not required)", () => {
    expect(v("", { min: 3 })).toBe(true);
  });

  test("below min fails", () => {
    expect(v("ab", { min: 3 })).toBe(false);
  });

  test("above max fails", () => {
    expect(v("abcdef", { max: 5 })).toBe(false);
  });

  test("within range passes", () => {
    expect(v("abc", { min: 2, max: 5 })).toBe(true);
  });

  test("exact min boundary passes", () => {
    expect(v("abc", { min: 3 })).toBe(true);
  });

  test("exact max boundary passes", () => {
    expect(v("abcde", { max: 5 })).toBe(true);
  });

  test("no constraints passes", () => {
    expect(v("anything", {})).toBe(true);
  });
});

describe("numeric", () => {
  const v = A2UI_VALIDATORS.numeric;

  test("empty string passes (not required)", () => {
    expect(v("", {})).toBe(true);
  });

  test("non-numeric string fails", () => {
    expect(v("abc", {})).toBe(false);
  });

  test("leading-number string passes (parseFloat behavior)", () => {
    // parseFloat("12abc") returns 12 — this is expected JS behavior
    expect(v("12abc", {})).toBe(true);
  });

  test("valid number passes", () => {
    expect(v("42", {})).toBe(true);
    expect(v("3.14", {})).toBe(true);
    expect(v("-7", {})).toBe(true);
  });

  test("below min fails", () => {
    expect(v("5", { min: 10 })).toBe(false);
  });

  test("above max fails", () => {
    expect(v("100", { max: 50 })).toBe(false);
  });

  test("within range passes", () => {
    expect(v("25", { min: 10, max: 50 })).toBe(true);
  });

  test("boundary values pass", () => {
    expect(v("10", { min: 10 })).toBe(true);
    expect(v("50", { max: 50 })).toBe(true);
  });
});
