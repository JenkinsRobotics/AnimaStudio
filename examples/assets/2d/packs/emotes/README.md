# `emotes` — demo character pack

Nine pixel-art emotions in two mouth states on one 9x2 sheet.

|  | col 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|---|
| **row 0** — mouth open (talking) | love | shocked | angry | nervous | frustrated | crying | happy | unamused | neutral |
| **row 1** — mouth closed (idle) | love | shocked | angry | nervous | frustrated | crying | happy | unamused | neutral |

Cell index is row-major, so `<emotion>_closed` is always
`<emotion>_open + 9`. Alternating rows on a fixed column is a mouth
flap; changing column is a mood change. That is what makes this a
talking face rather than 18 unrelated pictures.

**Not yet wired into the app** — dropped here as assets; integration
comes later.

## Provenance

Derived from Mochi's `assets/bmps/random_emotes.bmp`, a 1280x456
screenshot containing two 3x3 grids plus UI chrome. The extraction into
a clean atlas is scripted in the JaegerAnimation repo
(`dev/tools/build_emotes_atlas.py`).

## Format note

This carries JaegerAnimation's `character/v1` manifest as authored —
`expressions` map to a grid column, `mouth_states` to a row, so a cell
is `column + row * 9`.

AnimaCore's own convention is `pack/v1` (`animacore/pack.py`), where
slots map to a file plus a grid index. **The two formats are not yet
reconciled** — this pack is placed as assets, deliberately unconverted,
so the standardization work has one concrete character described both
ways to work against.

Neither project imports the other; the pack is the only thing that
crosses between them.
