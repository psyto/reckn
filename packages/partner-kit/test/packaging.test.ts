import { test } from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { execFileSync } from "node:child_process";

/**
 * **What a consumer actually receives.**
 *
 * Measured on 2026-09-09: `npm pack` from a clean checkout produced FOUR files — package.json
 * and three profiles. No `dist/`, because it is gitignored and nothing built it, and no
 * `README.md`, because `files` listed one that did not exist. `main`, `types` and `bin` all
 * pointed at paths that were not in the tarball, so `import "@reckn/partner-kit"` threw
 * ERR_MODULE_NOT_FOUND and the `reckn` binary was not there.
 *
 * Nothing in the test suite noticed, because every test imports from `../dist/` in a tree
 * where `npm test` had just built it. The package was only ever exercised in the one
 * condition a consumer is never in.
 *
 * So this asserts the property rather than the fix: everything the manifest PROMISES must
 * exist. Add a new entry point and forget to ship it and this fails.
 */
const pkg = JSON.parse(readFileSync(new URL("../package.json", import.meta.url), "utf8"));
const at = (p: string) => new URL("../" + p.replace(/^\.\//, ""), import.meta.url);

test("every path package.json points at exists", () => {
  const promised: Array<[string, string]> = [
    ["main", pkg.main], ["types", pkg.types],
    ...Object.entries(pkg.bin as Record<string, string>).map(([k, v]) => [`bin.${k}`, v] as [string, string]),
    ...Object.entries((pkg.exports?.["."] ?? {}) as Record<string, string>)
      .map(([k, v]) => [`exports["."].${k}`, v] as [string, string]),
  ];
  assert.ok(promised.length >= 4, "the manifest should still declare an entry point");
  for (const [field, path] of promised) {
    assert.ok(existsSync(at(path)), `package.json ${field} points at ${path}, which does not exist`);
  }
});

test("every entry in `files` exists, including the README it promises", () => {
  for (const f of pkg.files as string[]) {
    assert.ok(existsSync(at(f)), `package.json files lists "${f}", which does not exist`);
  }
  assert.ok((pkg.files as string[]).includes("README.md"));
});

test("no lifecycle script ships with this package", () => {
  // The first fix for the empty tarball was a `prepare` hook. It worked, and it was the wrong
  // shape: npm runs `prepare` on the CONSUMER's machine when the package is installed from
  // git, so a package whose entire claim is "nobody but a proof decides your payout" would
  // have been executing our code on their machine at install time. The property the hook was
  // protecting is asserted above and by release-gate.sh, which runs when WE publish.
  const LIFECYCLE = ["preinstall", "install", "postinstall", "prepare", "prepublish",
    "prepublishOnly", "prepack", "postpack", "preuninstall", "uninstall", "postuninstall"];
  const declared = LIFECYCLE.filter((h) => pkg.scripts?.[h]);
  assert.deepEqual(declared, [], `package.json declares lifecycle script(s): ${declared.join(", ")}`);
});

test("there is a release gate, and it is not a lifecycle hook", () => {
  assert.equal(pkg.scripts["release-gate"], "bash release-gate.sh");
  assert.ok(existsSync(at("release-gate.sh")), "release-gate.sh must exist");
});

test("the CLI it ships actually runs and prints its own usage", () => {
  // `bin` existing on disk is not the same as `bin` working. This executes it.
  const out = execFileSync(process.execPath, [new URL("../dist/cli.js", import.meta.url).pathname], {
    encoding: "utf8",
  });
  for (const cmd of ["reckn terms", "reckn preflight", "reckn verify", "reckn profiles"]) {
    assert.ok(out.includes(cmd), `usage does not mention ${cmd}`);
  }
  // F7: the slot-index default is Circle's layout and not a standard. Silence about it is how
  // a partner aims a predicate at a slot nothing writes.
  assert.match(out, /--slot-index/);
  assert.match(out, /DEFAULTS TO 9/);
  // The three exit codes verify now distinguishes, including the timeout refund.
  assert.match(out, /Exit 3/);
});
