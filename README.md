# Nexrender Skill

Expert Nexrender Cloud API guidance for AI coding agents.

This skill teaches Claude Code, Codex, OpenCode, Cursor, Gemini CLI, GitHub
Copilot, and other agent tools how to work with Nexrender Cloud without
guessing. It covers render jobs, job payloads, template upload and
introspection, fonts, secrets, webhooks, batch jobs, nested jobs, join jobs,
output settings, clean room workflows, and render debugging.

The skill is built around the open `SKILL.md` agent skills format and includes
extra reference material and helper scripts for real Nexrender Cloud workflows.

## What Is Included

```text
.
|-- SKILL.md                 # Main skill instructions and trigger description
|-- references/              # API, payload, pipeline, and workflow guidance
|-- scripts/                 # Bash and PowerShell helpers for Cloud tasks
`-- evals/                   # Skill evaluation fixtures
```

Install the whole directory whenever possible. Copying only `SKILL.md` works as
a minimal fallback, but the agent will lose the bundled `references/` docs and
`scripts/` helpers that make the skill much more useful.

## Prerequisites

- Git, for clone-based installs.
- Node.js 18 or newer, only if you use the `npx skills` installer.
- Bash or PowerShell, if you want to run the bundled helper scripts.
- A Nexrender Cloud API token for live Cloud calls.

Set the API key as an environment variable:

```bash
export NEXRENDER_API_KEY="..."
```

PowerShell:

```powershell
$env:NEXRENDER_API_KEY = "..."
```

For project-local setup, you can also store it in a `.env` file:

```dotenv
NEXRENDER_API_KEY=...
```

Do not commit `.env` or print API token values in logs, tickets, prompts, or
chat transcripts.

## Quick Install

Recommended cross-agent install:

```bash
npx skills@latest add https://github.com/nexrender/nexrender-skill --skill nexrender
```

Install to specific agents:

```bash
# Claude Code
npx skills@latest add https://github.com/nexrender/nexrender-skill --skill nexrender -a claude-code

# Codex
npx skills@latest add https://github.com/nexrender/nexrender-skill --skill nexrender -a codex

# OpenCode
npx skills@latest add https://github.com/nexrender/nexrender-skill --skill nexrender -a opencode
```

Useful installer flags:

```bash
# Install globally for your user instead of this project
npx skills@latest add https://github.com/nexrender/nexrender-skill --skill nexrender -g

# Install to every detected supported agent
npx skills@latest add https://github.com/nexrender/nexrender-skill --skill nexrender --all

# Non-interactive install for one agent
npx skills@latest add https://github.com/nexrender/nexrender-skill --skill nexrender -a codex -g -y

# Copy files instead of symlinking
npx skills@latest add https://github.com/nexrender/nexrender-skill --skill nexrender --copy

# List skills found in the repository without installing
npx skills@latest add https://github.com/nexrender/nexrender-skill --list
```

## Claude Code

Claude Code personal skills live in `~/.claude/skills/<skill-name>/SKILL.md`.
Project skills live in `.claude/skills/<skill-name>/SKILL.md`.

Install globally:

```bash
mkdir -p ~/.claude/skills
git clone https://github.com/nexrender/nexrender-skill ~/.claude/skills/nexrender
```

Install into one project:

```bash
mkdir -p .claude/skills
git clone https://github.com/nexrender/nexrender-skill .claude/skills/nexrender
```

If you already cloned this repository:

```bash
mkdir -p ~/.claude/skills/nexrender
cp -R SKILL.md references scripts evals ~/.claude/skills/nexrender/
```

Invoke directly with:

```text
/nexrender
```

Or ask naturally:

```text
Use the nexrender skill to create a preview render workflow.
```

## Codex

Codex supports agent skills in the CLI, IDE extension, and Codex app. For
project-scoped installs, use `.agents/skills/<skill-name>/SKILL.md`.

Install into the current project:

```bash
mkdir -p .agents/skills
git clone https://github.com/nexrender/nexrender-skill .agents/skills/nexrender
```

Install with the skills CLI:

```bash
# Project install
npx skills@latest add https://github.com/nexrender/nexrender-skill --skill nexrender -a codex

# Global user install
npx skills@latest add https://github.com/nexrender/nexrender-skill --skill nexrender -a codex -g
```

Invoke explicitly in Codex with:

```text
$nexrender
```

Or ask for Nexrender help directly. Codex can load the skill automatically when
your task matches the skill description.

## OpenCode

OpenCode discovers skills from OpenCode-specific, Claude-compatible, and
agent-compatible paths.

Global install:

```bash
mkdir -p ~/.config/opencode/skills
git clone https://github.com/nexrender/nexrender-skill ~/.config/opencode/skills/nexrender
```

Project install:

```bash
mkdir -p .opencode/skills
git clone https://github.com/nexrender/nexrender-skill .opencode/skills/nexrender
```

Shared agent-compatible project install:

```bash
mkdir -p .agents/skills
git clone https://github.com/nexrender/nexrender-skill .agents/skills/nexrender
```

Or use the skills CLI:

```bash
npx skills@latest add https://github.com/nexrender/nexrender-skill --skill nexrender -a opencode
```

## Other Popular Agents

The `npx skills` installer supports many agents and can detect installed tools
interactively. These are common targets:

| Tool | Installer command | Typical project path | Typical global path |
| --- | --- | --- | --- |
| Cursor | `npx skills@latest add https://github.com/nexrender/nexrender-skill --skill nexrender -a cursor` | `.agents/skills/nexrender` | `~/.cursor/skills/nexrender` |
| Gemini CLI | `npx skills@latest add https://github.com/nexrender/nexrender-skill --skill nexrender -a gemini-cli` | `.agents/skills/nexrender` | `~/.gemini/skills/nexrender` |
| GitHub Copilot | `npx skills@latest add https://github.com/nexrender/nexrender-skill --skill nexrender -a github-copilot` | `.agents/skills/nexrender` | `~/.copilot/skills/nexrender` |
| Windsurf | `npx skills@latest add https://github.com/nexrender/nexrender-skill --skill nexrender -a windsurf` | `.windsurf/skills/nexrender` | `~/.codeium/windsurf/skills/nexrender` |
| Cline | `npx skills@latest add https://github.com/nexrender/nexrender-skill --skill nexrender -a cline` | `.agents/skills/nexrender` | `~/.agents/skills/nexrender` |
| Roo Code | `npx skills@latest add https://github.com/nexrender/nexrender-skill --skill nexrender -a roo` | `.roo/skills/nexrender` | `~/.roo/skills/nexrender` |
| Kiro CLI | `npx skills@latest add https://github.com/nexrender/nexrender-skill --skill nexrender -a kiro-cli` | `.kiro/skills/nexrender` | `~/.kiro/skills/nexrender` |
| Qwen Code | `npx skills@latest add https://github.com/nexrender/nexrender-skill --skill nexrender -a qwen-code` | `.qwen/skills/nexrender` | `~/.qwen/skills/nexrender` |
| Goose | `npx skills@latest add https://github.com/nexrender/nexrender-skill --skill nexrender -a goose` | `.goose/skills/nexrender` | `~/.config/goose/skills/nexrender` |
| OpenHands | `npx skills@latest add https://github.com/nexrender/nexrender-skill --skill nexrender -a openhands` | `.openhands/skills/nexrender` | `~/.openhands/skills/nexrender` |

To install into all supported agents:

```bash
npx skills@latest add https://github.com/nexrender/nexrender-skill --skill nexrender --all
```

## Generic Installation

Most tools that support the open agent skills format expect a directory that
contains a `SKILL.md` file:

```text
<agent-skill-dir>/nexrender/SKILL.md
<agent-skill-dir>/nexrender/references/
<agent-skill-dir>/nexrender/scripts/
```

Generic clone:

```bash
git clone https://github.com/nexrender/nexrender-skill <agent-skill-dir>/nexrender
```

Install from a local checkout with the skills CLI:

```bash
git clone https://github.com/nexrender/nexrender-skill
cd nexrender-skill
npx skills@latest add . --skill nexrender
```

Project-scoped install for tools that read `.agents/skills`:

```bash
mkdir -p .agents/skills
git clone https://github.com/nexrender/nexrender-skill .agents/skills/nexrender
```

ZIP download fallback:

1. Download the repository ZIP from GitHub.
2. Extract it.
3. Rename the extracted folder to `nexrender`.
4. Move it into your agent's skills directory.
5. Restart the agent if it does not detect new skills automatically.

## Verify Installation

Start your agent in any project and ask:

```text
Use the nexrender skill to create a preview render workflow.
```

Good signs that the skill loaded:

- The agent mentions `NEXRENDER_API_KEY` for authentication.
- It uses `https://api.nexrender.com/api/v2` as the Cloud API base URL.
- It prefers `curl` or the bundled helper scripts for Cloud calls.
- It warns that `preview: true` and `settings` are mutually exclusive.
- It treats `missingFonts` as a visual correctness warning.

If the skill does not show up, check that:

- The file is named exactly `SKILL.md`.
- The skill directory is named `nexrender`.
- The whole folder was copied, including `references/` and `scripts/`.
- Your agent supports skills and is looking at the directory you installed into.
- Your agent was restarted if it does not watch skill directory changes.

## Helper Scripts

The scripts read `NEXRENDER_API_KEY` from the environment first, then from a
project `.env` file. They use `curl` under the hood. On Windows PowerShell, the
helpers call `curl.exe` to avoid PowerShell's `curl` alias.

List templates:

```bash
scripts/list-templates.sh
```

```powershell
.\scripts\list-templates.ps1
```

Upload a `.ttf` font:

```bash
scripts/upload-font.sh --path ./fonts/Montserrat-SemiBold.ttf
```

```powershell
.\scripts\upload-font.ps1 -Path .\fonts\Montserrat-SemiBold.ttf
```

Upload an After Effects template:

```bash
scripts/upload-template.sh --path ./templates/product-promo.zip --display-name "Product Promo"
```

```powershell
.\scripts\upload-template.ps1 -Path .\templates\product-promo.zip -DisplayName "Product Promo"
```

Create a preview job:

```bash
scripts/create-preview-job.sh --template-id 01JTGM9GCR71JV7EJYDF45QAFD --composition main --assets-json ./assets.json
```

```powershell
.\scripts\create-preview-job.ps1 -TemplateId 01JTGM9GCR71JV7EJYDF45QAFD -Composition main -AssetsJson .\assets.json
```

Poll a job:

```bash
scripts/poll-job.sh --job-id 01JTRDF7HCR8QAHYW8GPCP4S9Y
```

```powershell
.\scripts\poll-job.ps1 -JobId 01JTRDF7HCR8QAHYW8GPCP4S9Y
```

Use `--dry-run` or `-DryRun` where supported to inspect payloads without
submitting Cloud requests.

## What The Skill Helps With

- Build valid Nexrender Cloud job payloads.
- Choose correct asset types for text, data, images, video, audio, static files,
  scripts, functions, and nested jobs.
- Upload templates through the two-step create and presigned PUT flow.
- Poll template status until `uploaded` before rendering.
- Upload and reference fonts safely.
- Use secrets with `${secrets.NAME}` instead of raw credentials.
- Configure webhooks that return `2xx` and handle retries.
- Submit batch renders and understand partial success.
- Decide between nested jobs and join jobs.
- Configure output settings with fully prefixed codec identifiers.
- Debug render failures from status, `stats.error`, missing layers, missing
  fonts, and template introspection.

## Official Docs

This skill includes curated operational guidance, not a full copy of the
Nexrender docs. For newly changed endpoint shapes, dashboard locations, status
values, codecs, upload fields, or Cloud behavior, check the official docs:

- [Nexrender Cloud quickstart](https://docs.nexrender.com/cloud/quickstart)
- [Template basics](https://docs.nexrender.com/cloud/templates/basics)
- [Template registration](https://docs.nexrender.com/cloud/templates/register_template)
- [API reference](https://docs.nexrender.com/api-reference)
