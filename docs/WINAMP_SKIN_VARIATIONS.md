# Winamp Skin Format Variations

**Date:** 2026-09-25
**Purpose:** Skin format differences that matter when switching skins, and how MacAmp handles missing sheets

Winamp skins are not standardized: sheet sets vary by skin era, and optional sheets (`NUMS_EX`, `EQ_EX`, `GEN`, `VIDEO`) may or may not be present. MacAmp loads what exists and substitutes the rest.

---

## Two Number Systems

Digits are pre-rendered 9×13 bitmap sprites, not font glyphs. A skin provides them from `NUMBERS.bmp`, `NUMS_EX.bmp`, or both.

### 1. NUMBERS.bmp (Classic/Standard Skins)

99×13 pixels, 12 sprites (10 digits + 2 signs). Defined in `SkinSprites.defaultSprites` under `NUMBERS`.

```
NO_MINUS_SIGN    (x:9,  y:6, 5×1)
MINUS_SIGN       (x:20, y:6, 5×1)
DIGIT_0          (x:0,  y:0, 9×13)
DIGIT_1          (x:9,  y:0, 9×13)
...
DIGIT_9          (x:81, y:0, 9×13)
```

### 2. NUMS_EX.bmp (Extended Skins)

108×13 pixels, 12 sprites. Defined in `SkinSprites.numsExSprites`.

```
NO_MINUS_SIGN_EX (x:90, y:0, 9×13)
MINUS_SIGN_EX    (x:99, y:0, 9×13)
DIGIT_0_EX       (x:0,  y:0, 9×13)
...
DIGIT_9_EX       (x:81, y:0, 9×13)
```

### Bundled Skins

From the archives in `MacAmpApp/Skins/`:

| Skin | NUMBERS | NUMS_EX | EQ_EX | GEN | VIDEO |
|------|:---:|:---:|:---:|:---:|:---:|
| Winamp.wsz (default) | ✅ | | ✅ | ✅ | ✅ |
| Internet-Archive.wsz | | ✅ | ✅ | ✅ | ✅ |
| Winamp3_Classified_v5.5.wsz | ✅ | ✅ | ✅ | ✅ | ✅ |
| Tron-Vaporwave-by-LuigiHann.wsz | | ✅ | ✅ | ✅ | ✅ |
| Mac_OS-X_skin.wsz | | ✅ | ✅ | | |
| KenWood_KDC_7000_Elite.wsz | ✅ | | ✅ | | |
| Sony_MP3_Player_.wsz | ✅ | | ✅ | | |

Digits render in the skin's own colors (e.g. Internet Archive's digits are white, Winamp's green).

---

## How MacAmp Handles This

### Archive Loading

`SkinArchiveLoader.load(from:expectedSheets:)` (`MacAmpApp/ViewModels/SkinArchiveLoader.swift`, ZIPFoundation) reads every entry, lower-cases the file name, strips directories, and keeps `.bmp` or `.png` files whose base name is an expected sheet, plus `pledit.txt` and `viscolor.txt`. `loadAsync` runs it off the main actor.

### Sheet Processing

`SkinManager.loadSkin(from:)` (`MacAmpApp/ViewModels/SkinManager.swift`):

1. Starts from `SkinSprites.defaultSprites.sheets`.
2. Adds `NUMS_EX` (`SkinSprites.numsExSprites`) only if the archive contains `nums_ex`.
3. For each sheet:
   - **Missing** → the same sheet's sprites from the bundled default skin (`bundled:Winamp`, payload loaded once and sprites extracted lazily per sheet); if unavailable, transparent sprites. Logged as `AppLog.warn(.skin, "Missing sheet data: …")`.
   - **Fails to decode** → transparent sprites for the whole sheet.
   - **Crop fails** → one transparent sprite.
   - Only successfully decoded sheets are recorded in `loadedSheets`.

Transparent fallbacks (`createFallbackSprite(named:)`) take their size from `SkinSprites.dimensions(forSprite:)`, which searches every sheet and then `numsExSprites`, defaulting to 16×16.

### Digit Selection

`SpriteResolver` resolves `.digit(n)` to `DIGIT_n_EX` if present, else `DIGIT_n` (see [SPRITE_SYSTEM_COMPLETE.md](SPRITE_SYSTEM_COMPLETE.md)). So:

| Skin has | Result |
|----------|--------|
| NUMBERS only | Digits from NUMBERS |
| NUMS_EX only | Digits from NUMS_EX; the "Missing sheet data: NUMBERS" warning is expected, and default-skin NUMBERS sprites fill in unused |
| Both | NUMS_EX wins |
| Neither | Default-skin NUMBERS digits |

### Where Digits Appear

Only the main window time display uses digit sprites (`MainWindowFullLayer.swift` and `MainWindowShadeLayer.swift`). Bitrate and sample rate use TEXT.bmp `CHARACTER_<ascii>` sprites (5×6, `MainWindowIndicatorsLayer.swift`); playlist times are not digit sprites.

---

## Comparison with Webamp

Webamp (`packages/webamp/js/skinParserUtils.ts`) returns `{}` for a missing sheet and shallow-merges all sheets, so missing sheets contribute nothing:

```javascript
export async function getSpriteUrisFromFilename(zip, fileName) {
  const img = await getImgFromFilename(zip, fileName);
  if (img == null) {
    return {};
  }
  return getSpriteUrisFromImg(img, SKIN_SPRITES[fileName]);
}
```

MacAmp goes further by filling missing sheets from the default skin, so incomplete or damaged skins (common on skins.webamp.org) keep a working layout.

---

## Fonts vs Sprites

| | Digits | Text |
|---|---|---|
| Purpose | Time/number displays | Song titles, artist names |
| Source | NUMBERS.bmp or NUMS_EX.bmp | TEXT.bmp; GEN.bmp letters for generic window titles |
| Format | Fixed-width 9×13 bitmaps | Bitmap font |

Webamp's `genGenTextSprites()` measures GEN.bmp letter widths dynamically by scanning for the background color:

```javascript
const getLetters = (y, prefix) => {
  const backgroundColor = getColorAt(0);
  return LETTERS.map((letter) => {
    let nextBackground = x;
    while (getColorAt(nextBackground) !== backgroundColor) {
      nextBackground++;
    }
    const width = nextBackground - x;  // variable width
    ...
  });
};
```

See [MILKDROP_WINDOW.md](MILKDROP_WINDOW.md) for MacAmp's GEN.bmp handling.

---

## Possible Enhancement

A skin info panel listing which sheets are present, missing, or substituted from the default skin.
