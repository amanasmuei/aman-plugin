#!/usr/bin/env node
/**
 * install-mcp.mjs — Register aman-mcp as a Claude Code MCP server.
 *
 * Adds an `aman` entry to Claude Code's MCP server config so the user can
 * call live aman tools (identity_read, identity_update_section, rules_check,
 * rules_list, etc.) during any session, with `AMAN_MCP_SCOPE=dev:plugin`
 * set automatically.
 *
 * This is the "live tools" upgrade path on top of the plugin's session-start
 * hook (which loads identity/rules into context as text). With both:
 *   - The hook gives you fast startup context (identity is in the prompt)
 *   - aman-mcp gives you live read/write tool calls during the session
 *
 * Idempotent: re-running this updates the existing entry if present.
 * Use uninstall-mcp.mjs to remove.
 *
 * Cross-platform: tries the standard Claude Code config locations on
 * macOS, Linux, and Windows.
 */

import { promises as fs } from "node:fs";
import * as path from "node:path";
import * as os from "node:os";

const ENTRY_NAME = "aman";
const ENTRY_VALUE = {
  command: "npx",
  args: ["-y", "@aman_asmuei/aman-mcp@^0.6.0"],
  env: {
    AMAN_MCP_SCOPE: "dev:plugin",
  },
};

/**
 * Candidate Claude Code config locations, in order of preference.
 * The first one that already exists wins. If none exist, we create the first.
 */
function candidateConfigPaths() {
  const home = os.homedir();
  const xdgConfig =
    process.env.XDG_CONFIG_HOME ?? path.join(home, ".config");
  const appData = process.env.APPDATA;

  const paths = [
    // Claude Code CLI (most common)
    path.join(home, ".claude.json"),
    // XDG location
    path.join(xdgConfig, "claude-code", "config.json"),
  ];

  // Windows
  if (appData) {
    paths.push(path.join(appData, "Claude", "claude_desktop_config.json"));
  }
  // macOS Claude Desktop (the older app)
  paths.push(
    path.join(
      home,
      "Library",
      "Application Support",
      "Claude",
      "claude_desktop_config.json",
    ),
  );

  return paths;
}

async function findExistingConfig() {
  for (const p of candidateConfigPaths()) {
    try {
      await fs.access(p);
      return p;
    } catch {
      // doesn't exist, try next
    }
  }
  return null;
}

async function main() {
  const found = await findExistingConfig();
  const target = found ?? candidateConfigPaths()[0];

  let config = {};
  if (found) {
    let raw;
    try {
      raw = await fs.readFile(found, "utf-8");
    } catch (err) {
      console.error(
        `Failed to read ${found}: ${err instanceof Error ? err.message : String(err)}`,
      );
      process.exit(1);
    }
    try {
      config = raw.trim() === "" ? {} : JSON.parse(raw);
    } catch (err) {
      console.error(
        `Failed to parse ${found} as JSON: ${err instanceof Error ? err.message : String(err)}`,
      );
      console.error("Refusing to overwrite a malformed config file.");
      process.exit(1);
    }
  } else {
    console.log(`No Claude Code config found; creating ${target}`);
    await fs.mkdir(path.dirname(target), { recursive: true });
  }

  if (!config.mcpServers || typeof config.mcpServers !== "object") {
    config.mcpServers = {};
  }

  const existed = config.mcpServers[ENTRY_NAME] !== undefined;
  config.mcpServers[ENTRY_NAME] = ENTRY_VALUE;

  // Atomic write: write to temp, then rename
  const tmpPath = `${target}.aman-install.tmp`;
  await fs.writeFile(tmpPath, JSON.stringify(config, null, 2) + "\n", "utf-8");
  await fs.rename(tmpPath, target);

  console.log("");
  console.log(`✓ ${existed ? "Updated" : "Added"} aman MCP server in:`);
  console.log(`  ${target}`);
  console.log("");
  console.log("Configuration:");
  console.log(`  command:           ${ENTRY_VALUE.command}`);
  console.log(`  args:              ${ENTRY_VALUE.args.join(" ")}`);
  console.log(`  AMAN_MCP_SCOPE:    ${ENTRY_VALUE.env.AMAN_MCP_SCOPE}`);
  console.log("");
  console.log("Restart Claude Code to load the new MCP server.");
  console.log('Then ask: "what do you remember about me?"');
  console.log("");
  console.log(
    `To remove: node ${path.basename(import.meta.url.replace("install-mcp", "uninstall-mcp"))}`,
  );
}

main().catch((err) => {
  console.error(`Failed: ${err instanceof Error ? err.message : String(err)}`);
  process.exit(1);
});
