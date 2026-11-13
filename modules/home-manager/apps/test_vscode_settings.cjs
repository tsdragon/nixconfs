const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const { test } = require("node:test");
const jsonc = require(process.env.JSONC_PARSER);
const { disableUpdateChecks } = require("./vscode-settings.cjs");

for (const input of [
  "",
  "{}",
  '{"files.exclude": {}}',
  '{"update.mode": "default"}',
  '{"update.mode": "none", "update.mode": "default"}',
  '// a misleading { brace\n{"files.exclude": {},}',
  '{\n  // preserve this comment\n  "editor.columnSelection": true,\n}',
  '{"nested": {"update.mode": "manual"}, "url": "https://example.com"}',
  '{\r\n  "editor.columnSelection": true,\r\n}',
  '// comments without settings\n',
]) {
  test(`preserves settings and is idempotent: ${JSON.stringify(input)}`, () => {
    const errors = [];
    const before = jsonc.parse(input, [], { allowTrailingComma: true }) || {};
    const updated = disableUpdateChecks(input);
    const after = jsonc.parse(updated, errors, { allowTrailingComma: true });
    assert.deepEqual(errors, []);
    assert.deepEqual(after, { ...before, "update.mode": "none" });
    assert.equal(disableUpdateChecks(updated), updated);
    jsonc.visit(input, {
      onComment: (offset, length) => {
        assert.ok(updated.includes(input.slice(offset, offset + length)));
      },
    }, { allowTrailingComma: true });
  });
}

test("only the top-level value changes, preserving surrounding text", () => {
  const input = '{"nested": {"update.mode": "manual"}, "update.mode": "default" /* keep */}';
  assert.equal(disableUpdateChecks(input), input.replace('"default"', '"none"'));
});

test("rejects malformed and non-object settings", () => {
  for (const input of ['{"broken": }', "[]", "null", '{"a": 1 "b": 2}']) {
    assert.throws(() => disableUpdateChecks(input), /Refusing to modify/);
  }
});

test("activation helper leaves files writable and preserves other editions", () => {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), "vscode-settings-"));
  try {
    const config = path.join(home, "custom-config");
    const file = path.join(config, "Code/User/settings.json");
    const insiders = path.join(config, "Code - Insiders/User/settings.json");
    fs.mkdirSync(path.dirname(insiders), { recursive: true });
    fs.writeFileSync(insiders, '{"editor.columnSelection": true}', { mode: 0o640 });
    const invoke = () => spawnSync(process.execPath, [path.join(__dirname, "vscode-settings.cjs")], {
      env: { ...process.env, HOME: home, XDG_CONFIG_HOME: config },
      encoding: "utf8",
    });
    let result = invoke();
    assert.equal(result.status, 0, result.stderr);
    assert.equal(fs.lstatSync(file).isSymbolicLink(), false);
    assert.equal(fs.statSync(file).mode & 0o777, 0o600);
    assert.equal(fs.statSync(insiders).mode & 0o777, 0o640);
    assert.equal(jsonc.parse(fs.readFileSync(insiders, "utf8"))["editor.columnSelection"], true);
    assert.equal(fs.existsSync(path.join(config, "VSCodium")), false);
    fs.writeFileSync(file, '{"editor.columnSelection": true}');
    result = invoke();
    assert.equal(result.status, 0, result.stderr);
    assert.equal(jsonc.parse(fs.readFileSync(file, "utf8"))["editor.columnSelection"], true);
    fs.writeFileSync(file, '{"broken": }');
    result = invoke();
    assert.notEqual(result.status, 0);
    assert.equal(fs.readFileSync(file, "utf8"), '{"broken": }');
  } finally {
    fs.rmSync(home, { recursive: true, force: true });
  }
});
