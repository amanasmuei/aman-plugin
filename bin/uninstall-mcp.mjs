#!/usr/bin/env node
/**
 * uninstall-mcp.mjs — Remove the aman MCP server entry from Claude Code's
 * MCP server config. Idempotent: silently no-ops if no entry is found.
 *
 * Walks all candidate config paths (so a user who installed via the macOS
 * Claude Desktop app and ALSO via Claude Code CLI gets cleaned up everywhere).
 */

import { promises as fs } from "node:fs";
import * as path from "node:path";
import * as os from "node:os";

const ENTRY_NAME = "aman";

function candidateConfigPaths() {
  const home = os.homedir();
  const xdgConfig =
    process.env.XDG_CONFIG_HOME ?? path.join(home, ".config");
  const appData = process.env.APPDATA;

  const paths = [
    path.join(home, ".claude.json"),
    path.join(xdgConfig, "claude-code", "config.json"),
  ];
  if (appData) {
    paths.push(path.join(appData, "Claude", "claude_desktop_config.json"));
  }
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

async function tryRemoveFromConfig(target) {
  let raw;
  try {
    raw = await fs.readFile(target, "utf-8");
  } catch {
    return false; // file missing
  }
  let config;
  try {
    config = raw.trim() === "" ? {} : JSON.parse(raw);
  } catch {
    console.warn(`(skipping ${target}: not valid JSON)`);
    return false;
  }
  if (
    !config.mcpServers ||
    typeof config.mcpServers !== "object" ||
    !(ENTRY_NAME in config.mcpServers)
  ) {
    return false; // entry not present
  }
  delete config.mcpServers[ENTRY_NAME];

  const tmpPath = `${target}.aman-uninstall.tmp`;
  await fs.writeFile(tmpPath, JSON.stringify(config, null, 2) + "\n", "utf-8");
  await fs.rename(tmpPath, target);
  console.log(`✓ Removed aman MCP server from ${target}`);
  return true;
}

async function main() {
  let removedAny = false;
  for (const target of candidateConfigPaths()) {
    const removed = await tryRemoveFromConfig(target);
    if (removed) removedAny = true;
  }
  if (!removedAny) {
    console.log(
      "aman MCP server was not found in any known Claude Code config location.",
    );
    console.log("Nothing to remove.");
  } else {
    console.log("");
    console.log("Restart Claude Code for the change to take effect.");
  }
}

main().catch((err) => {
  console.error(`Failed: ${err instanceof Error ? err.message : String(err)}`);
  process.exit(1);
});
