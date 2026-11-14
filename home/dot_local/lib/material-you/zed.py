#!/usr/bin/env python3
# zed.py
# Generates ~/.config/zed/themes/materialyou.json: a "Material You" Zed theme
# derived from the Konsole colorscheme (same palette as kitty/btop), starting from
# the complete structure of the Ayu Dark theme (base) to guarantee a valid theme.
import json
import os
import sys

import material_you_lib as my

OUT = os.path.expanduser('~/.config/zed/themes/materialyou.json')

# --- base structure (Ayu Dark): only the colors are replaced -----------------
BASE = json.loads(r'''
{"border":"#3f4043ff","border.variant":"#2d2f34ff","border.focused":"#1b4a6eff","border.selected":"#1b4a6eff","border.transparent":"#00000000","border.disabled":"#383a3eff","elevated_surface.background":"#1f2127ff","surface.background":"#1f2127ff","background":"#313337ff","element.background":"#1f2127ff","element.hover":"#2d2f34ff","element.active":"#3e4043ff","element.selected":"#3e4043ff","element.disabled":"#1f2127ff","drop_target.background":"#8a898680","ghost_element.background":"#00000000","ghost_element.hover":"#2d2f34ff","ghost_element.active":"#3e4043ff","ghost_element.selected":"#3e4043ff","ghost_element.disabled":"#1f2127ff","text":"#bfbdb6ff","text.muted":"#8a8986ff","text.placeholder":"#696a6aff","text.disabled":"#696a6aff","text.accent":"#5ac1feff","icon":"#bfbdb6ff","icon.muted":"#8a8986ff","icon.disabled":"#696a6aff","icon.placeholder":"#8a8986ff","icon.accent":"#5ac1feff","status_bar.background":"#313337ff","title_bar.background":"#313337ff","title_bar.inactive_background":"#1f2127ff","toolbar.background":"#0d1016ff","tab_bar.background":"#1f2127ff","tab.inactive_background":"#1f2127ff","tab.active_background":"#0d1016ff","search.match_background":"#5ac2fe66","search.active_match_background":"#ea570166","panel.background":"#1f2127ff","panel.focused_border":"#5ac1feff","pane.focused_border":null,"scrollbar.thumb.background":"#bfbdb64c","scrollbar.thumb.hover_background":"#2d2f34ff","scrollbar.thumb.border":"#2d2f34ff","scrollbar.track.background":"#00000000","scrollbar.track.border":"#1b1e24ff","editor.foreground":"#bfbdb6ff","editor.background":"#0d1016ff","editor.gutter.background":"#0d1016ff","editor.subheader.background":"#1f2127ff","editor.active_line.background":"#1f2127bf","editor.highlighted_line.background":"#1f2127ff","editor.line_number":"#4b4c4e","editor.active_line_number":"#cbcccd","editor.hover_line_number":"#a1a2a5","editor.invisible":"#666767ff","editor.wrap_guide":"#bfbdb60d","editor.active_wrap_guide":"#bfbdb61a","editor.document_highlight.read_background":"#5ac1fe1a","editor.document_highlight.write_background":"#66676766","terminal.background":"#0d1016ff","terminal.foreground":"#bfbdb6ff","terminal.bright_foreground":"#bfbdb6ff","terminal.dim_foreground":"#85847fff","terminal.ansi.black":"#0d1016ff","terminal.ansi.bright_black":"#545557ff","terminal.ansi.dim_black":"#3a3b3cff","terminal.ansi.red":"#ef7177ff","terminal.ansi.bright_red":"#83353bff","terminal.ansi.dim_red":"#a74f53ff","terminal.ansi.green":"#aad84cff","terminal.ansi.bright_green":"#567627ff","terminal.ansi.dim_green":"#769735ff","terminal.ansi.yellow":"#feb454ff","terminal.ansi.bright_yellow":"#92582bff","terminal.ansi.dim_yellow":"#b17d3aff","terminal.ansi.blue":"#5ac1feff","terminal.ansi.bright_blue":"#27618cff","terminal.ansi.dim_blue":"#3e87b1ff","terminal.ansi.magenta":"#39bae5ff","terminal.ansi.bright_magenta":"#205a78ff","terminal.ansi.dim_magenta":"#2782a0ff","terminal.ansi.cyan":"#95e5cbff","terminal.ansi.bright_cyan":"#4c806fff","terminal.ansi.dim_cyan":"#68a08eff","terminal.ansi.white":"#bfbdb6ff","terminal.ansi.bright_white":"#fafafaff","terminal.ansi.dim_white":"#85847fff","link_text.hover":"#5ac1feff","conflict":"#feb454ff","conflict.background":"#572815ff","conflict.border":"#754221ff","created":"#aad84cff","created.background":"#294113ff","created.border":"#405c1cff","deleted":"#ef7177ff","deleted.background":"#48161bff","deleted.border":"#66272dff","error":"#ef7177ff","error.background":"#48161bff","error.border":"#66272dff","hidden":"#696a6aff","hidden.background":"#313337ff","hidden.border":"#383a3eff","hint":"#628b80ff","hint.background":"#0d2f4eff","hint.border":"#1b4a6eff","ignored":"#696a6aff","ignored.background":"#313337ff","ignored.border":"#3f4043ff","info":"#5ac1feff","info.background":"#0d2f4eff","info.border":"#1b4a6eff","modified":"#feb454ff","modified.background":"#572815ff","modified.border":"#754221ff","predictive":"#5a728bff","predictive.background":"#294113ff","predictive.border":"#405c1cff","renamed":"#5ac1feff","renamed.background":"#0d2f4eff","renamed.border":"#1b4a6eff","success":"#aad84cff","success.background":"#294113ff","success.border":"#405c1cff","unreachable":"#8a8986ff","unreachable.background":"#313337ff","unreachable.border":"#3f4043ff","warning":"#feb454ff","warning.background":"#572815ff","warning.border":"#754221ff"}
''')


# parsing of the colorscheme and mix() live in material_you_lib (single source
# of truth for the format).
mix = my.mix


def main():
    p = my.palette_or_die()
    bg, fg = p['bg'], p['fg']
    c, i = p['base'], p['intense']
    c0, c1, c2, c3, c4, c5, c6, c7 = c
    i0, i1, i2, i3, i4, i5, i6, i7 = i
    accent = i1
    muted = i0
    elev = mix(bg, fg, 0.07)
    hover = mix(bg, fg, 0.13)
    active = mix(bg, fg, 0.20)
    border = mix(bg, fg, 0.16)
    border_v = mix(bg, fg, 0.10)

    s = dict(BASE)
    s.update({
        'background': bg, 'surface.background': elev, 'elevated_surface.background': elev,
        'element.background': elev, 'element.hover': hover, 'element.active': active,
        'element.selected': active,
        'ghost_element.hover': hover, 'ghost_element.active': active, 'ghost_element.selected': active,
        'border': border, 'border.variant': border_v, 'border.focused': accent, 'border.selected': accent,
        'text': fg, 'text.muted': muted, 'text.placeholder': muted, 'text.disabled': muted, 'text.accent': accent,
        'icon': fg, 'icon.muted': muted, 'icon.disabled': muted, 'icon.placeholder': muted, 'icon.accent': accent,
        'status_bar.background': bg, 'title_bar.background': bg, 'title_bar.inactive_background': elev,
        'toolbar.background': bg, 'tab_bar.background': elev, 'tab.inactive_background': elev,
        'tab.active_background': bg, 'panel.background': elev, 'panel.focused_border': accent,
        'search.match_background': accent + '55', 'search.active_match_background': c3 + '66',
        'scrollbar.thumb.background': mix(bg, fg, 0.30) + 'cc', 'scrollbar.thumb.hover_background': hover,
        'scrollbar.thumb.border': border, 'scrollbar.track.border': border_v,
        'editor.foreground': fg, 'editor.background': bg, 'editor.gutter.background': bg,
        'editor.subheader.background': elev, 'editor.active_line.background': elev,
        'editor.highlighted_line.background': elev, 'editor.line_number': muted,
        'editor.active_line_number': fg, 'editor.hover_line_number': fg,
        'editor.document_highlight.read_background': accent + '1a',
        'editor.document_highlight.write_background': muted + '66',
        'terminal.background': bg, 'terminal.foreground': fg, 'terminal.bright_foreground': fg,
        'terminal.dim_foreground': muted,
        'terminal.ansi.black': c0, 'terminal.ansi.red': c1, 'terminal.ansi.green': c2,
        'terminal.ansi.yellow': c3, 'terminal.ansi.blue': c4, 'terminal.ansi.magenta': c5,
        'terminal.ansi.cyan': c6, 'terminal.ansi.white': c7,
        'terminal.ansi.bright_black': i0, 'terminal.ansi.bright_red': i1, 'terminal.ansi.bright_green': i2,
        'terminal.ansi.bright_yellow': i3, 'terminal.ansi.bright_blue': i4, 'terminal.ansi.bright_magenta': i5,
        'terminal.ansi.bright_cyan': i6, 'terminal.ansi.bright_white': i7,
        'terminal.ansi.dim_black': mix(c0, bg, 0.3), 'terminal.ansi.dim_red': mix(c1, bg, 0.3),
        'terminal.ansi.dim_green': mix(c2, bg, 0.3), 'terminal.ansi.dim_yellow': mix(c3, bg, 0.3),
        'terminal.ansi.dim_blue': mix(c4, bg, 0.3), 'terminal.ansi.dim_magenta': mix(c5, bg, 0.3),
        'terminal.ansi.dim_cyan': mix(c6, bg, 0.3), 'terminal.ansi.dim_white': mix(c7, bg, 0.3),
        'link_text.hover': accent, 'error': c4, 'error.background': mix(bg, c4, 0.18), 'error.border': mix(bg, c4, 0.3),
        'deleted': c4, 'deleted.background': mix(bg, c4, 0.18), 'deleted.border': mix(bg, c4, 0.3),
        'warning': c3, 'warning.background': mix(bg, c3, 0.18), 'warning.border': mix(bg, c3, 0.3),
        'modified': c3, 'modified.background': mix(bg, c3, 0.18), 'modified.border': mix(bg, c3, 0.3),
        'conflict': c3, 'conflict.background': mix(bg, c3, 0.18), 'conflict.border': mix(bg, c3, 0.3),
        'success': c2, 'success.background': mix(bg, c2, 0.18), 'success.border': mix(bg, c2, 0.3),
        'created': c2, 'created.background': mix(bg, c2, 0.18), 'created.border': mix(bg, c2, 0.3),
        'info': accent, 'info.background': mix(bg, accent, 0.18), 'info.border': mix(bg, accent, 0.3),
        'hint': muted, 'hint.background': mix(bg, accent, 0.12), 'hint.border': mix(bg, accent, 0.25),
        'renamed': accent, 'renamed.background': mix(bg, accent, 0.18), 'renamed.border': mix(bg, accent, 0.3),
        'predictive': muted, 'unreachable': muted, 'ignored': muted, 'hidden': muted,
        'hidden.background': elev, 'ignored.background': elev, 'unreachable.background': elev,
        'hidden.border': border_v, 'ignored.border': border, 'unreachable.border': border,
    })

    # players (multi-cursors): 8 shades of the palette
    s['players'] = [{'cursor': col, 'background': col, 'selection': col + '3d'}
                    for col in [i1, i2, i3, i4, i5, i6, i0, accent]]

    # Zed expects 8-hex colors (RRGGBBAA). Our base values are 6-hex; we
    # complete the alpha (unless an explicit alpha is already present).
    def alpha(c):
        return c + 'ff' if isinstance(c, str) and len(c) == 7 and c.startswith('#') else c

    s = {k: alpha(v) for k, v in s.items()}
    s['players'] = [{k: alpha(v) for k, v in p.items()} for p in s['players']]

    # syntax: mapped onto the palette
    syn = {
        'attribute': accent, 'boolean': i5, 'comment': muted, 'comment.doc': muted,
        'constant': i5, 'constructor': accent, 'embedded': fg, 'emphasis': accent,
        'enum': c3, 'function': i1, 'hint': muted, 'keyword': c3, 'label': accent,
        'link_text': c3, 'link_uri': c2, 'namespace': fg, 'number': i5, 'operator': c3,
        'predictive': muted, 'preproc': c3, 'primary': fg, 'property': accent,
        'punctuation': mix(fg, bg, 0.4), 'selector': i5, 'string': c2,
        'string.escape': muted, 'string.regex': i2, 'string.special': c3,
        'string.special.symbol': c3, 'tag': accent, 'text.literal': c3,
        'title': fg, 'type': accent, 'variable': fg, 'variable.parameter': i5,
        'variant': accent, 'diff.plus': c2, 'diff.minus': c4,
    }
    style = {'color': lambda h: {'color': h if h.startswith('#') and len(h) == 7 else h + 'ff',
                                 'font_style': None, 'font_weight': None}}
    syntax = {}
    for k, h in syn.items():
        syntax[k] = {'color': h + 'ff', 'font_style': None, 'font_weight': None}
    syntax['emphasis.strong'] = {'color': accent + 'ff', 'font_style': None, 'font_weight': 700}
    syntax['title'] = {'color': fg + 'ff', 'font_style': None, 'font_weight': 700}
    syntax['link_text'] = {'color': c3 + 'ff', 'font_style': 'italic', 'font_weight': None}
    syntax['predictive'] = {'color': muted + 'ff', 'font_style': 'italic', 'font_weight': None}
    s['syntax'] = syntax

    theme = {
        '$schema': 'https://zed.dev/schema/themes/v0.2.0.json',
        'name': 'Material You',
        'author': 'dotfiles',
        'themes': [{'name': 'Material You', 'appearance': 'dark', 'style': s}],
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    json.dump(theme, open(OUT, 'w'), indent=2)
    print('zed theme written:', OUT, 'accent=', accent)
    return 0


if __name__ == '__main__':
    sys.exit(main())
