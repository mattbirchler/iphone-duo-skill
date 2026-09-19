# iphone-duo

A Claude Code skill that audits an iOS app against Apple's iPhone Duo requirements, fixes what it finds, and checks the result on the Duo simulator.

The Duo APIs shipped in iOS 27.0 and 27.1, after Claude's training data ends. Without the docs, Claude guesses at signatures. The skill makes it look them up.

## Install

```bash
git clone https://github.com/mattbirchler/iphone-duo-skill ~/.claude/skills/iphone-duo
python3 ~/.claude/skills/iphone-duo/scripts/fetch-docs.py
```

The second command downloads Apple's documentation pages, which I can't redistribute here. It needs Python 3 and curl.

## Use

Open your iOS project in Claude Code and run `/iphone-duo`, or ask it to get the app ready for iPhone Duo. Say "audit only" if you want the report without code changes.

You need Xcode 27.1 for the iPhone Duo simulator.

MIT licensed.
