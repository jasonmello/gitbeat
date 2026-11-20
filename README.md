# GitBeat

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE) · Name, logo and mascot reserved — see [`NOTICE`](NOTICE)

Your coding rhythm, at a glance: tokens per day (Claude Code, OpenCode, Codex CLI, Gemini CLI), active time, GitHub commits and PRs, goal rings and streaks. A native Mac app with Liquid Glass and a menu bar item. English and Portuguese.

```bash
scripts/build-app.sh --install
```

- **Private by design:** GitBeat only reads numbers (time, project, model, tokens) from the session files your tools already keep. Conversation text is never stored or sent.
- **History that lasts:** Claude Code deletes conversations after 30 days. GitBeat keeps a permanent copy of the numbers on your Mac and in your iCloud Drive.
- **GitHub, private repos included:** commits are read from each repository's history, so private work counts even if your profile calendar hides it.

**Do I need Xcode?** No. GitBeat builds with the free Command Line Tools (`xcode-select --install`). Xcode only helps if you want to edit the code with previews and a debugger. GitHub data needs the GitHub CLI signed in (`gh auth login`).

Proudly developed by [Jason Mello](https://github.com/jasonmello).

---

**Português:** o seu ritmo de programação, num relance. Mesmo comando para instalar. Não precisa do Xcode. Idioma em Ajustes (⌘,). Mapa do projeto para quem vai mexer: `AGENTS.md`.

---

## License

GitBeat is free software under the **GNU General Public License v3** ([`LICENSE`](LICENSE)), with one additional term: if you distribute GitBeat or a version based on it, you must keep the attribution **"Based on GitBeat by Jason Mello (github.com/jasonmello)"** in the About screen and the README. Contributions and modified versions stay under the GPL.

The **name "GitBeat", the logo and the mascot are not part of the license** — they remain © 2026 Jason Mello, all rights reserved. A fork must use a different name and replace the logo and mascot. Full terms in [`NOTICE`](NOTICE).

**Português:** o GitBeat é software livre sob a **GNU General Public License v3** ([`LICENSE`](LICENSE)), com um termo a mais: ao distribuir o GitBeat ou uma versão baseada nele, você precisa manter a atribuição **"Baseado no GitBeat, de Jason Mello (github.com/jasonmello)"** na tela Sobre e no README. Contribuições e versões modificadas continuam sob a GPL. O **nome "GitBeat", o logo e o mascote não entram na licença** — continuam © 2026 Jason Mello, todos os direitos reservados. Um fork precisa usar outro nome e trocar o logo e o mascote. Termos completos no [`NOTICE`](NOTICE).
