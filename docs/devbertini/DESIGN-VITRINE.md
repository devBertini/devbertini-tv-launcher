# Vitrine: the home's design

Vitrine was chosen from three directions drawn as mockups and refined over ten rounds of review; this is the spec the
Flutter build follows. The mockups were HTML pages at the launcher's 960x540 logical canvas, rendered at 2x by
`tools/devbertini/mockup/render.sh` (they used third-party art, so they stay out of the repository). All sizes are
Flutter logical px on the 960x540 canvas (1 CSS px of the mockup = 1 logical px). The README's pictures come from the
real widgets (`test/devbertini/vitrine_capture_test.dart`).

## Decisions

- The home starts in the dark theme; Configurações > Tela inicial > Aparência offers Escuro, Claro and Automático
  (dark from 22h to 6h, the Modo noite hours). The five palettes (DevBertini, Aurora, Cinema Dourado, Neon, Oceano)
  are the accent colour, each with a tone for the light field and one for black.
- The TV's own functions (the console, Entradas, Imagem, Som, Modo jogo, Painel rápido, Energia) are not on the home;
  the rail item TV is the way to them.
- The music island is a black pill at the top centre, the same in both themes.
- Dark surfaces are pure black: the field, the open rail, the app plates and the selected rail item; plates keep only a
  1 px #262A31 edge and the logo.
- The signature (the devBertini mark and name) is discreet, at the bottom left of the rail.
- Rows scroll sideways with the next item peeking at the right edge (Apps and Continuar assistindo).
- The rail's avatar stays at the top (centred with the name in the open panel); the seven items are centred vertically
  on the screen. The open rail takes only the width its labels need, with the same space on both sides of the items.
- The Apps row is the larger one: five whole plates and the next peeking; Continuar assistindo sits low, clear of the
  bottom edge.
- Home always brings the normal home back, from an app, with the home already in front or over the screensaver: the
  rail and any panel or page over the home close at once, with no animation, the row goes back to its start and the
  focus to the first app, as the Google TV launcher does. Back from an app returns to where the focus was.

## Layout (dark default; light uses the same geometry)

- Field: dark #000000 everywhere; light a painted vertical gradient #EAEEF3 > #E4E9EF > #DCE3EB.
- Rail, collapsed: avatar 26 px (circle in the profile's colour, graphite #4A525E for the first profile, letter 12 px
  w600 white) at x 34, y 30. Seven items centred vertically (y 163..377): pills 34x28 at x 30..64 (axis x 47),
  radius 14, 15 px icons, gap 3: Início, Apps, TV, Música, Notificações (count badge 15 px, 11 px digit, with a 2 px
  ring of the colour under it, on the icon's top right: its left 7.5 px into the icon, its top 5 px above the pill,
  the same open or closed), Rede, Configurações. Selected (Início): black (light: white) fill, 1 px edge, accent
  icon. Focus: 3 px accent ring and scale 1.05 (light adds the one soft shadow). Icons at rest ink-3.
- Rail, expanded (while a rail item has the focus): an opaque panel over the content (dark #000000 with a 1 px #262A31
  right edge; light #F3F6F9 with a 1 px edge and a soft shadow); labels 12 px (rest ink-2, selected and focused ink
  w600), 10 px after the icon. Every pill is as wide as the widest row needs (9.5 px padding, icon, gap, the widest
  label measured at w600, 9.5 px), and the panel ends 30 px after the pills, the same 30 px the pills keep from the
  screen's edge: with the pt-BR labels, pills 127 wide at x 30..157 and the panel x 0..187. The avatar gains the profile's
  name 12 px w600 (gap 8), and the two are centred together in the panel (x 93.5) on their own; the items keep their
  alignment and their icons never move. Right or Back closes it and returns the focus where it was; 160 ms width
  animation.
- Signature: bottom 22, one line: mark 10 px + "devBertini" 10 px w700 at 80% opacity ("dev" accent-ink, "Bertini"
  ink-2), centred on x 47 collapsed and in the panel expanded. The mark, here, in Configurações and in the intro, is
  the dB in cream and amber on a graphite tile (#4A525E).
- Content column: x 100..912 (36 px after the rail's pills, 48 px right safe edge); rows run past 912 to the screen
  edge to show the peeking item.
- Island (unchanged widget): top 24, centred, 40 tall.
- Clock block, right edge x 912, top 27: one 12 px line (weather icon 16 px, temperature w600 ink, date ink-2), the
  time 25 px w300 (tracking 0.3), "Desliga às HH:MM" 12 px ink-2 while the sleep timer is set.
- Hero (newest Watch Next item), x 100, y 50..199: provider logo 19 px tall; title 28 px w400, tracking -0.6, line 32;
  a 72x3 progress bar and "NN min restantes" 12 px w500 ink-2; synopsis 12/16, 285 wide, at most two lines; capsules
  26 tall, radius 13, 12 px w600, 16 px icons, gap 7: "Continuar" (primary: #F2F4F8 with black text on dark; white with
  a 1 px edge on light) and "Detalhes" (quiet: #15171C with a 1 px edge on dark; 7% ink on light).
- Hero art: the item's artwork at x 236, y -30, 790x444, cover, under one painted overlay: down fade from y 221 to solid
  at 361; left fade solid to x 380, 0.85 at 430, 0.35 at 520, clear at 600; a right scrim 0.94 at the edge to clear at
  290 px in (so the clock reads); on dark all in the field's black, on light the down fade in #E2E7EE and the side
  ones in #E8ECF1 (the field is a gradient there). The field, the art, the overlay and Modo noite's darker
  art are one picture of the screen, painted again only when one of them changes (Performance).
- Apps: label "Apps" 15 px w600 at y 232; plates 140x71, radius 12, gap 14, y 259..330, five whole and the sixth
  peeking 90 px at the edge, "Todos" (22 px apps icon + 16 px) at the end. Dark plates #000 with the edge; light
  #FFFFFF with #D3DAE3 edge. Logos centred (Netflix 25 px tall, YouTube 21, HBO Max 37, Prime Video 26, Twitch 25,
  Spotify 26, Google Play 34; white variants of YouTube and HBO Max on black; Twitch keeps its purple mark). Focus: 3 px accent ring, scale
  1.06.
- Continuar assistindo: label 14 px w600 at y 386; cards 180x93, radius 10, gap 12, y 411..504 (36 px above the
  bottom edge; the TV's 5% overscan is 27), the fifth peeking.
  Card: artwork (cover) under a painted scrim (to 0.88 black at the bottom), service logo 15 px tall at the top right,
  title 13/16 w600 white (ellipsis), "NN min restantes" 12 px #E3E6EB, a 2 px progress bar inset 9 (white on 28%
  white).

## Tokens

| Token | Dark | Light |
|---|---|---|
| field | #000000 | gradient #EAEEF3 > #E4E9EF > #DCE3EB |
| plate (app plates, selected rail item) | #000000 + 1 px #262A31 | #FFFFFF + 1 px #D3DAE3 |
| quiet (secondary capsule) | #15171C + 1 px #262A31 | rgba(20,23,28,0.07) |
| panel (open rail, settings) | #000000 | #F3F6F9 |
| ink / ink-2 / ink-3 | #F2F4F8 / #A3A8B0 / #8A9099 | #14171C / #4A525E / #5B6370 |
| accent (ring, selected icon) | palette's black tone (DevBertini #F2F4F8) | palette's light tone (DevBertini #14171C) |
| accent-ink (accent as text) | DevBertini #F2F4F8 | DevBertini #14171C |
| gold (warnings) | #E8B04A | #7A5410 |
| badge fill, digits | DevBertini #F2F4F8, black digits | DevBertini #14171C, white digits |

Accent tones per palette, light / black: DevBertini #14171C / #F2F4F8 (no hue: the ink and the soft white of the
text, so the focus sits with any art; the default), Aurora #047857 / #10B981, Cinema Dourado
#8A5A0B / #E0A63A, Neon #B5179E / #FF2BD6, Oceano #0369A1 / #0EA5E9.

Type: Onest (OFL, variable, wght 100 to 900; bundled with its license, never downloaded), one family. A plain
`FontWeight`, any value such as 450, sets its wght axis (Flutter 3.47's `dart:ui` FontWeight documentation), so no
`FontVariation` is needed.

## Remote

- Start: the first app plate. Digits 1 to 9 open the first nine apps. Home, from anywhere: back to the
  start (Decisions).
- Up from Apps: the hero capsules; up again: the island when it shows (OK opens the player).
- Down from Apps: Continuar assistindo. Left from the first item of any row: the rail opens on Início.
- Rail: avatar (profiles), Início, Apps (every app and category), TV (HDMI-CEC devices with their state, then Entradas,
  Imagem, Som, Modo jogo, Painel rápido, Energia; hidden on a device without TV inputs, such as a TV box), Música (the island's player when something
  plays; Spotify when nothing does), Notificações, Rede (the network panel), Configurações (the side panel).
  Every panel the rail opens opens on the left, where the rail is: Configurações and TV as 384 px full-height panels,
  Notificações as a 420 px one, Rede and the profiles as cards at x 24, y 60.
- Hold OK opens an item's options (apps: move, hide, change the image; cards: remove).

## Data

- Hero and cards: Android Watch Next (title, description, artwork, position and duration, package, intent), newest first,
  without the programs, apps and packages hidden in the settings; the newest is the hero, the rest the row. Only apps that
  publish Watch Next appear there (on the reference TV, Twitch did). Configurações > Tela inicial > Continuar assistindo
  (on by default) turns both off. With no item the hero and the row go and the Apps row moves up to y 120.
- The Apps row is the first category with apps (the one the number keys open); "Todos" and the rail's Apps open every
  category in lines of five plates.
- Provider logos are PNGs per known package that the PC puts on the device (`tools/devbertini/logo_art.py`,
  `deploy.ps1 -Art`), never in the repository; an unknown package falls back to the app's banner, then its name.

## Performance (Mali-G52, OpenGL)

The bar: never heavy, stuck or stuttering on the reference TV, measured frame by frame on it (`PERFORMANCE.md` holds
the tools and the results). What keeps the home within it:

- No blur, no BackdropFilter, no full-screen translucent layer, and nothing large painted live every frame: the
  backdrop (field, hero art, its three fades, Modo noite's darker art) is painted once into one picture of the
  screen (`VitrineBackdrop`) and drawn as that one image, and so is the light field's gradient wherever it fills a
  page (`VitrineField`: the home without a hero, the apps page). Painted live, the three fade gradients alone took
  the Mali-G52 about 11 ms of GPU per frame.
- The GPU's budget per frame on the TCL is about 12 ms, not 16.7: its hardware composer puts the launcher's two
  layers on the GPU, and SurfaceFlinger's composition takes about 4.5 ms of every frame.
- A focus change rebuilds only the items that gain and lose it (a listenable per item, never a setState on the
  home); each row is a lazily built horizontal list behind its own RepaintBoundary, and so are the hero, the clock
  and the rail.
- The rail's opening animates only the panel's width over the content; the content never lays out again.
- Any change to the rail's cost is measured on the TV before it stays: making its threads faster made its opening
  less smooth there (`PERFORMANCE.md`).
- Hero art decoded at its drawn size (cacheWidth about 1580), cross-faded once when the item changes.
- Plates and cards decode at their size and are precached when the home loads; shadows only on the focused element
  in the light theme.
- The clock repaints once a minute, the island's meter only while music plays.
- A second after the home first shows, an open copy of the rail is painted once under the field, so the rail's first
  opening finds its shaders compiled and its labels' glyphs ready (it took about 30 ms on the TCL's raster thread
  without it).
