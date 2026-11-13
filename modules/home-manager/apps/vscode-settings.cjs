const fs = require("node:fs");
const path = require("node:path");
const jsonc = require(process.env.JSONC_PARSER);

function disableUpdateChecks(text) {
  const errors = [];
  const root = jsonc.parseTree(text, errors, {
    allowTrailingComma: true,
    allowEmptyContent: true,
  });
  if (errors.length || (root && root.type !== "object")) {
    throw new Error("Refusing to modify invalid or non-object VS Code settings");
  }

  // Update every duplicate left by older rewrites, without touching nested keys.
  const settings = (root?.children ?? []).filter(
    (property) => property.children[0].value === "update.mode",
  );
  const edits = settings.length
    ? settings.map((property) => {
        const value = property.children[1];
        return { offset: value.offset, length: value.length, content: '"none"' };
      })
    : jsonc.modify(text, ["update.mode"], "none", {
        formattingOptions: {
          insertSpaces: true,
          tabSize: 2,
          eol: text.includes("\r\n") ? "\r\n" : "\n",
        },
      });
  return jsonc.applyEdits(text, edits);
}

function main() {
  const home = process.env.HOME;
  const config = process.env.XDG_CONFIG_HOME || path.join(home, ".config");
  const settingsPaths = [
    path.join(config, "Code/User/settings.json"),
    path.join(config, "Code - Insiders/User/settings.json"),
    path.join(config, "Code - OSS/User/settings.json"),
    path.join(config, "VSCodium/User/settings.json"),
    path.join(home, ".var/app/com.visualstudio.code/config/Code/User/settings.json"),
  ];
  for (const [index, settingsPath] of settingsPaths.entries()) {
    if (index !== 0 && !fs.existsSync(settingsPath)) continue;
    const original = fs.existsSync(settingsPath)
      ? fs.readFileSync(settingsPath, "utf8")
      : "";
    const updated = disableUpdateChecks(original);
    if (updated !== original) {
      fs.mkdirSync(path.dirname(settingsPath), { recursive: true });
      fs.writeFileSync(settingsPath, updated, { mode: 0o600 });
    }
  }
}

module.exports = { disableUpdateChecks };
if (require.main === module) main();
