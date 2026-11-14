#!/usr/bin/env python3
# btop.py
# Aligns the btop theme with the Material You colors of the wallpaper, via the
# Konsole colorscheme (same colors as kitty/Konsole).
# Writes ~/.config/btop/themes/materialyou.theme
import os

import material_you_lib as my

THEMES = os.path.expanduser('~/.config/btop/themes')
OUT = os.path.join(THEMES, 'materialyou.theme')


def main():
    p = my.palette_or_die()
    base, ints = p['base'], p['intense']
    bg, fg = p['bg'], p['fg']
    c0, c1, c2, c3, c4, c5, c6, c7 = base
    i0, i1, i2, i3, i4, i5, i6, i7 = ints
    os.makedirs(THEMES, exist_ok=True)

    L = ['#MaterialYou (btop aligned with the Konsole colorscheme, follows the wallpaper)',
         'theme[main_bg]="%s"' % bg,
         'theme[main_fg]="%s"' % fg,
         'theme[title]="%s"' % fg,
         'theme[hi_fg]="%s"' % i1,
         'theme[selected_bg]="%s"' % i1,
         'theme[selected_fg]="%s"' % bg,
         'theme[inactive_fg]="%s"' % i0,
         'theme[graph_text]="%s"' % i1,
         'theme[meter_bg]="%s"' % c6,
         'theme[proc_misc]="%s"' % i1,
         'theme[div_line]="%s"' % c6,
         'theme[cpu_box]="%s"' % i1,
         'theme[mem_box]="%s"' % i1,
         'theme[net_box]="%s"' % i1,
         'theme[proc_box]="%s"' % i1]
    # graph/meter ramp: dark -> accent -> light
    for name in ('temp', 'cpu', 'free', 'cached', 'available',
                 'used', 'download', 'upload', 'process'):
        L += ['theme[%s_start]="%s"' % (name, c1),
              'theme[%s_mid]="%s"' % (name, i1),
              'theme[%s_end]="%s"' % (name, i6)]
    open(OUT, 'w').write('\n'.join(L) + '\n')
    print('btop theme written. accent=%s fg=%s' % (i1, fg))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
