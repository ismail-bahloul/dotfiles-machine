# docs

Documentation for this repository's own configuration — the "why" behind the
files that ship here.

| Document | What it covers |
|---|---|
| [`install.md`](install.md) | One-line install, flags, `[multilib]`, what `install.sh` does, tests. |
| [`components.md`](components.md) | The component switch, the package table, and the opt-in application bricks. |
| [`setup.md`](setup.md) | Repository map, how components gate scripts, the `etc/` convention, hardware, stack, omenctl, aliases, vendored widgets. |
| [`boot-tuning.md`](boot-tuning.md) | Boot tweaks: dead UEFI boot entries, the slimmed initramfs (`run_once_11` + `etc/`), and why `systemd-analyze`'s firmware phase is not a usable metric. |
| [`material-you.md`](material-you.md) | How the wallpaper-driven theming works (kitty / btop / Zed / prompt), the KWin transparency and blur setup, and the two things that break after updates. |
| [`notes.md`](notes.md) | Working notes: which configuration is versioned and which is deliberately not, the PipeWire setup, and SSH keys. |

---

Back to the [main README](../README.md).
