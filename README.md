# iphone-duo

An agent skill that audits an iOS app against Apple's iPhone Duo requirements, fixes what it finds, and checks the result on the Duo simulator. It works with any coding agent that reads `SKILL.md` files, such as Claude Code or Codex.

The Duo APIs shipped in iOS 27.0 and 27.1, after most models' training data ends. Without the docs, an agent guesses at signatures. The skill makes it look them up.

## Install

Clone the repo into your agent's skills folder, then download Apple's docs. This example uses Claude Code's folder, `~/.claude/skills`. Swap in your agent's.

```bash
git clone https://github.com/mattbirchler/iphone-duo-skill ~/.claude/skills/iphone-duo
python3 ~/.claude/skills/iphone-duo/scripts/fetch-docs.py
```

The second command downloads Apple's documentation pages, which I can't redistribute here. It needs Python 3 and curl.

If your agent has no skills folder, clone the repo anywhere and tell the agent to read `SKILL.md`.

## Use

Open your iOS project in your agent and ask it to get the app ready for iPhone Duo. Say "audit only" if you want the report without code changes.

You need Xcode 27.1 for the iPhone Duo simulator.

MIT licensed.
