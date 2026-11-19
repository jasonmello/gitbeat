# GitBeat

Apple Health, but for coding with AI: tokens per day (Claude Code, OpenCode, Codex CLI, Gemini CLI), active time, GitHub commits and PRs, goal rings and streaks. A native Mac app with Liquid Glass and a menu bar item. English and Portuguese.

```bash
scripts/build-app.sh --install
```

- **Private by design:** GitBeat only reads numbers (time, project, model, tokens) from the session files your tools already keep. Conversation text is never stored or sent.
- **History that lasts:** Claude Code deletes conversations after 30 days. GitBeat keeps a permanent copy of the numbers on your Mac and in your iCloud Drive.
- **GitHub, private repos included:** commits are read from each repository's history, so private work counts even if your profile calendar hides it.

**Do I need Xcode?** No. GitBeat builds with Apple's free Command Line Tools (`xcode-select --install`). Xcode only helps if you want to edit the code with previews and a debugger. GitHub data needs the GitHub CLI signed in (`gh auth login`).

Proudly developed by Jason Mello.

---

**Português:** o app Saúde para quem programa com IA. Mesmo comando para instalar. Não precisa do Xcode. Idioma em Ajustes (⌘,). Mapa do projeto para quem vai mexer: `AGENTS.md`.
