# =============================================================================
# machine.zsh — the CachyOS/Arch layer of the shell
#
# Sourced by the portable ~/.zshrc (which owns the shared config) when this file
# exists. Everything here is specific to this laptop; a plain userspace install
# never has it.
# =============================================================================

# --- Material You prompt + ls colors -----------------------------------------
# prompt.py (triggered by kde-material-you-colors) writes the p10k colors AND
# LS_COLORS derived from the same palette. Here we only source the file -> no
# process launched on every prompt.
_prompt_material() {
  local cache="$HOME/.cache/material-you/prompt.zsh"
  [[ -f "$cache" ]] && source "$cache"
  [[ -n $LS_COLORS ]] && zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
}
_prompt_material
# Prepend, not append: p10k computes the prompt in _p9k_precmd, so sourcing
# the colors before it makes them apply to the prompt being drawn right now
# instead of the next one.
[[ " ${precmd_functions[*]} " == *" _prompt_material "* ]] ||
  precmd_functions=(_prompt_material $precmd_functions)

alias material-refresh='$HOME/.local/bin/material-you-refresh'

# --- pkgfile "command not found" handler (Arch package) ----------------------
[[ -r /usr/share/doc/pkgfile/command-not-found.zsh ]] &&
  source /usr/share/doc/pkgfile/command-not-found.zsh

# --- Boot to Windows / VFIO / Linux (via Limine) -----------------------------
alias ww="limine-boot-win"
alias vv="limine-boot-vfio"
alias ll="limine-boot-linux"

# --- HP Omen: fans + power profiles ------------------------------------------
alias power="sudo omenctl status"
alias auto="sudo omenctl profile auto && sudo omenctl status"
alias quiet="sudo omenctl profile quiet && sudo omenctl status"
alias eco="sudo omenctl profile eco && sudo omenctl status"
alias perf="sudo omenctl profile perf && sudo omenctl status"

# --- Backup + CachyOS full update (repos + AUR + Flatpak + cleanup) ----------
alias backup="backup-data"
alias uu='$HOME/DATA/05_Code/Projects/arch-auto-update/arch-auto-update'
