# Webamp Skin Loading and Changing Research Report

## Executive Summary

The Webamp clone implements a comprehensive skin loading and switching system that parses `.wsz` (Winamp Skin Zip) files and dynamically applies them to the UI. The system uses JSZip to extract skin files, parses various image and configuration files, and applies the skin through CSS injection and React component updates.

## Architecture Overview

### Core Components

1. **Skin Parser** (`skinParser.js`) - Parses `.wsz` files into skin data
2. **Skin Parser Utils** (`skinParserUtils.ts`) - Utility functions for extracting and processing skin files
3. **Skin Component** (`components/Skin.tsx`) - React component that applies skin CSS
4. **Action Creators** (`actionCreators/files.ts`) - Redux actions for loading/switching skins
5. **Display Reducer** (`reducers/display.ts`) - Manages skin state in Redux
6. **Skin Selectors** (`skinSelectors.ts`) - Maps skin sprites to CSS selectors

## File Structure

### Key Files and Their Roles

```
webamp_clone/packages/webamp/js/
├── skinParser.js                    # Main skin parsing logic
├── skinParserUtils.ts               # File extraction utilities
├── skinSprites.ts                   # Sprite definitions and mappings
├── skinSelectors.ts                 # CSS selector mappings
├── baseSkin.json                    # Default skin data
├── constants.ts                     # DEFAULT_SKIN constant
├── components/
│   ├── Skin.tsx                     # Skin CSS application component
│   └── SkinsContextMenu.tsx         # UI for skin selection
├── actionCreators/
│   ├── files.ts                     # Skin loading actions
│   └── index.ts                     # Exports setSkinFromUrl, etc.
├── reducers/
│   ├── display.ts                   # Skin state management
│   └── settings.ts                  # Available skins list
└── selectors.ts                     # State selectors including getAvaliableSkins

demo/
├── js/
│   ├── availableSkins.ts            # Demo skin list
│   ├── webampConfig.ts              # Configuration with skin options
│   └── index.tsx                    # Demo initialization
└── skins/                           # Demo .wsz files
```

---

## 1. Skin File Format (.wsz)

### What is a .wsz file?

A `.wsz` file is a ZIP archive containing bitmap images, text configuration files, and optional cursor files that define the visual appearance of Winamp.

### Key Files in a .wsz Archive

#### Images (BMP or PNG):
- `MAIN.BMP` - Main window background and controls
- `CBUTTONS.BMP` - Control buttons (play, pause, stop, etc.)
- `TITLEBAR.BMP` - Title bar
- `NUMBERS.BMP` - Display digits
- `PLAYPAUS.BMP` - Play/pause indicators
- `POSBAR.BMP` - Position slider
- `VOLUME.BMP` - Volume slider
- `BALANCE.BMP` - Balance slider
- `MONOSTER.BMP` - Mono/Stereo indicators
- `SHUFREP.BMP` - Shuffle/Repeat buttons
- `TEXT.BMP` - Font characters
- `GEN.BMP` - Generic text (for letter width calculation)
- `GENEX.BMP` - Extended colors
- `EQ_EX.BMP` - Equalizer window
- `PLEDIT.BMP` - Playlist window
- And many more...

#### Configuration Files:
- `VISCOLOR.TXT` - Visualizer colors
- `PLEDIT.TXT` - Playlist style (colors, fonts)
- `REGION.TXT` - Window region definitions (for non-rectangular windows)

#### Cursors (Optional):
- `*.CUR` files - Custom cursor images for different UI elements

---

## 2. Skin Parsing Implementation

### Main Parser Function

**File:** `/Users/hank/dev/src/MacAmp/webamp_clone/packages/webamp/js/skinParser.js`

**Lines 142-176:**

```javascript
async function skinParser(zipFileBuffer, JSZip) {
  const zip = await JSZip.loadAsync(zipFileBuffer);

  const [
    colors,
    playlistStyle,
    images,
    cursors,
    region,
    genTextSprites,
    genExColors,
  ] = await Promise.all([
    genVizColors(zip),
    SkinParserUtils.getPlaylistStyle(zip),
    genImages(zip),
    genCursors(zip),
    genRegion(zip),
    genGenTextSprites(zip),
    SkinParserUtils.getGenExColors(zip),
  ]);

  const [genLetterWidths, genTextImages] = genTextSprites || [null, {}];

  return {
    colors,
    playlistStyle,
    images: { ...images, ...genTextImages },
    genLetterWidths,
    cursors,
    region,
    genExColors,
  };
}
```

### Key Parsing Functions

#### 1. Image Extraction (`genImages`)

**File:** `skinParser.js` **Lines 64-72:**

```javascript
async function genImages(zip) {
  const imageObjs = await Promise.all(
    Object.keys(SKIN_SPRITES).map((fileName) =>
      SkinParserUtils.getSpriteUrisFromFilename(zip, fileName)
    )
  );
  // Merge all the objects into a single object
  return shallowMerge(imageObjs);
}
```

#### 2. Sprite Extraction Utility

**File:** `/Users/hank/dev/src/MacAmp/webamp_clone/packages/webamp/js/skinParserUtils.ts`

**Lines 120-129:**

```typescript
export async function getSpriteUrisFromFilename(
  zip: JSZip,
  fileName: string
): Promise<{ [spriteName: string]: string }> {
  const img = await getImgFromFilename(zip, fileName);
  if (img == null) {
    return {};
  }
  return getSpriteUrisFromImg(img, SKIN_SPRITES[fileName]);
}
```

**Lines 79-98:** (Sprite URI generation from canvas)

```typescript
export function getSpriteUrisFromImg(
  img: HTMLImageElement | ImageBitmap,
  sprites: Sprite[]
): { [spriteName: string]: string } {
  const canvas = document.createElement("canvas");
  const context = canvas.getContext("2d", { willReadFrequently: true });
  if (context == null) {
    throw new Error("Failed to get canvas context");
  }
  const images: { [spriteName: string]: string } = {};
  sprites.forEach((sprite) => {
    canvas.height = sprite.height;
    canvas.width = sprite.width;

    context.drawImage(img, -sprite.x, -sprite.y);
    const image = canvas.toDataURL();
    images[sprite.name] = image;
  });
  return images;
}
```

**Key Pattern:** Each skin image file is loaded, and specific sprite regions are extracted using canvas operations, then converted to data URLs for CSS usage.

#### 3. Visualizer Color Extraction

**File:** `skinParser.js` **Lines 54-62:**

```javascript
async function genVizColors(zip) {
  const viscolor = await SkinParserUtils.getFileFromZip(
    zip,
    "VISCOLOR",
    "txt",
    "text"
  );
  return viscolor ? parseViscolors(viscolor.contents) : DEFAULT_SKIN.colors;
}
```

#### 4. Playlist Style Extraction

**File:** `skinParserUtils.ts` **Lines 154-186:**

```typescript
export async function getPlaylistStyle(zip: JSZip): Promise<PlaylistStyle> {
  const files = zip.file(getFilenameRegex("PLEDIT", "txt"));
  const file = files[0];
  if (file == null) {
    return DEFAULT_SKIN.playlistStyle;
  }
  const ini = await file.async("text");
  if (ini == null) {
    return DEFAULT_SKIN.playlistStyle;
  }
  const data = ini && Utils.parseIni(ini).text;
  if (!data) {
    return DEFAULT_SKIN.playlistStyle;
  }

  // Winamp permits colors that contain too many characters
  // Normalize them here
  ["normal", "current", "normalbg", "selectedbg", "mbFG", "mbBG"].forEach(
    (colorKey) => {
      let color = data[colorKey];
      if (!color) {
        return;
      }
      if (color[0] !== "#") {
        color = `#${color}`;
      }
      data[colorKey] = color.slice(0, 7);
    }
  );

  return { ...DEFAULT_SKIN.playlistStyle, ...data };
}
```

---

## 3. Skin Loading Actions

### Loading Skin from Blob

**File:** `/Users/hank/dev/src/MacAmp/webamp_clone/packages/webamp/js/actionCreators/files.ts`

**Lines 78-114:**

```typescript
export function setSkinFromBlob(blob: Blob | Promise<Blob>): Thunk {
  return async (dispatch, getState, { requireJSZip }) => {
    if (!requireJSZip) {
      alert("Webamp has not been configured to support custom skins.");
      return;
    }
    dispatch({ type: "LOADING" });
    let JSZip;
    try {
      JSZip = await requireJSZip();
    } catch (e) {
      console.error(e);
      dispatch({ type: "LOADED" });
      alert("Failed to load the skin parser.");
      return;
    }
    try {
      const skinData = await skinParser(blob, JSZip);
      dispatch({
        type: "SET_SKIN_DATA",
        data: {
          skinImages: skinData.images,
          skinColors: skinData.colors,
          skinPlaylistStyle: skinData.playlistStyle,
          skinCursors: skinData.cursors,
          skinRegion: skinData.region,
          skinGenLetterWidths: skinData.genLetterWidths,
          skinGenExColors: skinData.genExColors,
        } as SkinData,
      });
    } catch (e) {
      console.error(e);
      dispatch({ type: "LOADED" });
      alert(`Failed to parse skin`);
    }
  };
}
```

**Key Flow:**
1. Dispatch `LOADING` action (shows loading indicator)
2. Lazy-load JSZip library
3. Parse skin using `skinParser(blob, JSZip)`
4. Dispatch `SET_SKIN_DATA` action with parsed data
5. On error, dispatch `LOADED` and show alert

### Loading Skin from URL

**File:** `actionCreators/files.ts` **Lines 116-131:**

```typescript
export function setSkinFromUrl(url: string): Thunk {
  return async (dispatch) => {
    dispatch({ type: "LOADING" });
    try {
      const response = await fetch(url);
      if (!response.ok) {
        throw new Error(response.statusText);
      }
      dispatch(setSkinFromBlob(response.blob()));
    } catch (e) {
      console.error(e);
      dispatch({ type: "LOADED" });
      alert(`Failed to download skin from ${url}`);
    }
  };
}
```

### Loading Default Skin

**File:** `actionCreators/index.ts` **Lines 159-161:**

```typescript
export function loadDefaultSkin(): Action {
  return { type: "LOAD_DEFAULT_SKIN" };
}
```

### Opening Skin File Dialog

**File:** `actionCreators/files.ts` **Lines 160-162:**

```typescript
export function openSkinFileDialog() {
  return _openFileDialog(".zip, .wsz", "SKIN");
}
```

**Lines 136-150:**

```typescript
function _openFileDialog(
  accept: string | null,
  expectedType: "SKIN" | "MEDIA" | "EQ"
): Thunk {
  return async (dispatch) => {
    const fileReferences = await promptForFileReferences({ accept });
    dispatch({
      type: "OPENED_FILES",
      expectedType,
      count: fileReferences.length,
      firstFileName: fileReferences[0]?.name,
    });
    dispatch(loadFilesFromReferences(fileReferences));
  };
}
```

### File Detection and Auto-Loading

**File:** `actionCreators/files.ts` **Lines 54-76:**

```typescript
const SKIN_FILENAME_MATCHER = new RegExp("(wsz|zip)$", "i");
const EQF_FILENAME_MATCHER = new RegExp("eqf$", "i");

export function loadFilesFromReferences(
  fileReferences: FileList,
  loadStyle: LoadStyle = LOAD_STYLE.PLAY,
  atIndex: number | undefined = undefined
): Thunk {
  return (dispatch) => {
    if (fileReferences.length < 1) {
      return;
    } else if (fileReferences.length === 1) {
      const fileReference = fileReferences[0];
      if (SKIN_FILENAME_MATCHER.test(fileReference.name)) {
        dispatch(setSkinFromBlob(fileReference));
        return;
      } else if (EQF_FILENAME_MATCHER.test(fileReference.name)) {
        dispatch(setEqFromFileReference(fileReference));
        return;
      }
    }
    dispatch(addTracksFromReferences(fileReferences, loadStyle, atIndex));
  };
}
```

**Key Pattern:** When a file is dropped or selected, the system automatically detects if it's a skin file (`.wsz` or `.zip`) and loads it as a skin instead of as media.

---

## 4. State Management

### Display Reducer

**File:** `/Users/hank/dev/src/MacAmp/webamp_clone/packages/webamp/js/reducers/display.ts`

**State Interface (Lines 16-35):**

```typescript
export interface DisplayState {
  visualizerStyle: number;
  doubled: boolean;
  llama: boolean;
  disableMarquee: boolean;
  marqueeStep: number;
  skinImages: SkinImages;
  skinCursors: Cursors | null;
  skinRegion: SkinRegion;
  skinGenLetterWidths: GenLetterWidths | null;
  skinColors: string[];
  skinPlaylistStyle: PlaylistStyle | null;
  skinGenExColors: SkinGenExColors;
  working: boolean;
  closed: boolean;
  loading: boolean;
  playlistScrollPosition: number;
  zIndex: number;
  dummyVizData: DummyVizData | null;
}
```

**Default State (Lines 62-82):**

```typescript
const defaultDisplayState = {
  doubled: false,
  marqueeStep: 0,
  disableMarquee: false,
  loading: true,
  llama: false,
  closed: false,
  working: false,
  skinImages: DEFAULT_SKIN.images,
  skinColors: DEFAULT_SKIN.colors,
  skinCursors: null,
  skinPlaylistStyle: null,
  skinRegion: {},
  visualizerStyle: 0,
  dummyVizData: null,
  playlistScrollPosition: 0,
  skinGenLetterWidths: null,
  skinGenExColors: defaultSkinGenExColors,
  additionalVisualizers: [],
  zIndex: 0,
};
```

**Reducer Actions (Lines 84-166):**

```typescript
const display = (
  state: DisplayState = defaultDisplayState,
  action: Action
): DisplayState => {
  switch (action.type) {
    case "LOAD_DEFAULT_SKIN": {
      const {
        skinImages,
        skinColors,
        skinCursors,
        skinPlaylistStyle,
        skinRegion,
        skinGenLetterWidths,
        skinGenExColors,
      } = defaultDisplayState;
      return {
        ...state,
        skinImages,
        skinColors,
        skinCursors,
        skinPlaylistStyle,
        skinRegion,
        skinGenLetterWidths,
        skinGenExColors,
      };
    }
    // ...
    case "LOADING":
      return { ...state, loading: true };
    case "LOADED":
      return { ...state, loading: false };
    case "SET_SKIN_DATA":
      const { data } = action as any;
      return {
        ...state,
        loading: false,
        skinImages: data.skinImages,
        skinColors: data.skinColors,
        skinPlaylistStyle: data.skinPlaylistStyle,
        skinCursors: data.skinCursors,
        skinRegion: data.skinRegion,
        skinGenLetterWidths: data.skinGenLetterWidths,
        skinGenExColors: data.skinGenExColors || defaultSkinGenExColors,
      };
    // ...
  }
};
```

### Settings Reducer (Available Skins List)

**File:** `/Users/hank/dev/src/MacAmp/webamp_clone/packages/webamp/js/reducers/settings.ts**

```typescript
export interface SettingsState {
  availableSkins: Array<Skin>;
}

const defaultSettingsState = {
  availableSkins: [],
};

const settings = (
  state: SettingsState = defaultSettingsState,
  action: Action
): SettingsState => {
  switch (action.type) {
    case "SET_AVAILABLE_SKINS":
      return { ...state, availableSkins: (action as any).skins };
    default:
      return state;
  }
};
```

### Selectors

**File:** `/Users/hank/dev/src/MacAmp/webamp_clone/packages/webamp/js/selectors.ts`

**Line 836-838:**

```typescript
export function getAvaliableSkins(state: AppState) {
  return state.settings.availableSkins;
}
```

**Skin data selectors are accessed via:**
- `state.display.skinImages`
- `state.display.skinColors`
- `state.display.skinCursors`
- `state.display.skinRegion`
- `state.display.skinGenLetterWidths`
- `state.display.skinPlaylistStyle`
- `state.display.skinGenExColors`

---

## 5. Skin Application to UI

### Skin Component

**File:** `/Users/hank/dev/src/MacAmp/webamp_clone/packages/webamp/js/components/Skin.tsx`

**Lines 141-153:**

```typescript
export default function Skin() {
  const cssRules = useTypedSelector(getCssRules);
  const clipPaths = useTypedSelector(getClipPaths);
  if (cssRules == null) {
    return null;
  }
  return (
    <>
      <Css id="webamp-skin">{cssRules}</Css>
      <ClipPaths>{clipPaths}</ClipPaths>
    </>
  );
}
```

### CSS Rules Generation

**Lines 48-128:**

```typescript
const getCssRules = createSelector(
  Selectors.getSkinImages,
  Selectors.getSkinCursors,
  Selectors.getSkinLetterWidths,
  Selectors.getSkinRegion,
  (skinImages, skinCursors, skinGenLetterWidths, skinRegion): string | null => {
    if (!skinImages || !skinCursors) {
      return null;
    }
    const cssRules = [];

    // Apply background images
    Object.keys(imageSelectors).forEach((imageName) => {
      const imageUrl =
        skinImages[imageName] || skinImages[FALLBACKS[imageName]];
      if (imageUrl) {
        imageSelectors[imageName].forEach((_selector) => {
          const selector = _selector;
          cssRules.push(
            `${CSS_PREFIX} ${selector} {background-image: url(${imageUrl})}`
          );
        });
      }
    });

    // Apply letter widths
    if (skinGenLetterWidths != null) {
      LETTERS.forEach((letter) => {
        const width = skinGenLetterWidths[`GEN_TEXT_${letter}`];
        const selectedWidth =
          skinGenLetterWidths[`GEN_TEXT_SELECTED_${letter}`];
        cssRules.push(
          `${CSS_PREFIX} .gen-text-${letter.toLowerCase()} {width: ${width}px;}`
        );
        cssRules.push(
          `${CSS_PREFIX} .selected .gen-text-${letter.toLowerCase()} {width: ${selectedWidth}px;}`
        );
      });
    }

    // Apply cursors
    Object.entries(cursorSelectors).forEach(([cursorName, cursorSelector]) => {
      const cursor = skinCursors[cursorName];
      if (cursor == null) {
        return;
      }
      const cursorRules = cursorSelector
        .map(normalizeCursorSelector)
        .map((selector) => {
          switch (cursor.type) {
            case "cur":
              return `${selector} {cursor: url(${cursor.url}), auto}`;
            case "ani": {
              try {
                return convertAniBinaryToCSS(selector, cursor.aniData);
              } catch (e) {
                console.error(e);
                return null;
              }
            }
          }
        })
        .filter(Boolean);
      cssRules.push(...cursorRules);
    });

    // Apply region clip paths
    for (const [regionName, polygons] of Object.entries(skinRegion)) {
      if (polygons) {
        const matcher = mapRegionNamesToMatcher[regionName];
        const id = mapRegionNamesToIds[regionName];
        cssRules.push(`${CSS_PREFIX} ${matcher} { clip-path: url(#${id}); }`);
      }
    }

    return cssRules.join("\n");
  }
);
```

**Key Pattern:** The Skin component uses React memoization (via `createSelector` from reselect) to generate CSS rules that map skin sprite data URLs to CSS selectors. These rules are injected into the page via a `<Css>` component (likely a `<style>` tag wrapper).

### Skin Selectors Mapping

**File:** `/Users/hank/dev/src/MacAmp/webamp_clone/packages/webamp/js/skinSelectors.ts`

**Sample mappings (Lines 8-40):**

```typescript
export const imageSelectors: Selectors = {
  MAIN_BALANCE_BACKGROUND: ["#balance"],
  MAIN_BALANCE_THUMB: [
    "#balance::-webkit-slider-thumb",
    "#balance::-moz-range-thumb",
  ],
  MAIN_BALANCE_THUMB_ACTIVE: [
    "#balance:active::-webkit-slider-thumb",
    "#balance:active::-moz-range-thumb",
  ],
  MAIN_PREVIOUS_BUTTON: [".actions #previous"],
  MAIN_PREVIOUS_BUTTON_ACTIVE: [".actions #previous.winamp-active"],
  MAIN_PLAY_BUTTON: [".actions #play"],
  MAIN_PLAY_BUTTON_ACTIVE: [".actions #play.winamp-active"],
  MAIN_PAUSE_BUTTON: [".actions #pause"],
  MAIN_PAUSE_BUTTON_ACTIVE: [".actions #pause.winamp-active"],
  // ... many more
};
```

**Cursor mappings (Lines 356-403):**

```typescript
export const cursorSelectors: Selectors = {
  CLOSE: ["#title-bar #close"],
  EQSLID: ["#equalizer-window .band"],
  EQNORMAL: ["#equalizer-window"],
  EQCLOSE: ["#equalizer-window #equalizer-close"],
  EQTITLE: [
    "#equalizer-window .title-bar",
    "#equalizer-window.shade",
    "#equalizer-window.shade input",
  ],
  MAINMENU: ["#main-window #option", "#webamp-context-menu .context-menu"],
  // ... more
};
```

---

## 6. User Interface for Skin Selection

### Skins Context Menu

**File:** `/Users/hank/dev/src/MacAmp/webamp_clone/packages/webamp/js/components/SkinsContextMenu.tsx**

```typescript
const SkinContextMenu = () => {
  const loadDefaultSkin = useActionCreator(Actions.loadDefaultSkin);
  const openSkinFileDialog = useActionCreator(Actions.openSkinFileDialog);
  const setSkin = useActionCreator(Actions.setSkinFromUrl);

  const availableSkins = useTypedSelector(Selectors.getAvaliableSkins);
  return (
    <Parent label="Skins">
      <Node onClick={openSkinFileDialog} label="Load Skin..." />
      <Hr />
      <Node onClick={loadDefaultSkin} label={"<Base Skin>"} />
      {availableSkins.map((skin) => (
        <Node
          key={skin.url}
          onClick={() => setSkin(skin.url)}
          label={skin.name}
        />
      ))}
    </Parent>
  );
};
```

**Key UI Elements:**
1. **"Load Skin..."** - Opens file dialog (accepts `.zip`, `.wsz`)
2. **"<Base Skin>"** - Resets to default skin
3. **Dynamic skin list** - Shows all skins in `availableSkins` array

### Available Skins Configuration

**File:** `/Users/hank/dev/src/MacAmp/webamp_clone/packages/webamp/demo/js/availableSkins.ts**

```typescript
export default [
  { url: green, name: "Green Dimension V2" },
  { url: internetArchive, name: "Internet Archive" },
  { url: osx, name: "Mac OSX v1.5 (Aqua)" },
  { url: topaz, name: "TopazAmp" },
  { url: visor, name: "Vizor" },
  { url: xmms, name: "XMMS Turquoise " },
  { url: zaxon, name: "Zaxon Remake" },
];
```

**Skin Type:**
```typescript
export type Skin = {
  url: string;
  name: string;
};
```

---

## 7. Initialization and Configuration

### WebampLazy Initialization

**File:** `/Users/hank/dev/src/MacAmp/webamp_clone/packages/webamp/js/webampLazy.tsx**

**Lines 83-90 (Constructor options):**

```typescript
const {
  initialTracks,
  initialSkin,
  availableSkins,
  enableHotkeys = false,
  zIndex,
  requireJSZip,
  requireMusicMetadata,
  requireButterchurnPresets,
  // ...
} = options;
```

**Lines 188-215 (Initialization):**

```typescript
if (initialSkin) {
  this.store.dispatch(Actions.setSkinFromUrl(initialSkin.url));
} else {
  // We are using the default skin.
  this.store.dispatch({ type: "LOADED" });
}

// Handle deprecated misspelling
if (options.avaliableSkins != null) {
  console.warn(
    "The misspelled option `avaliableSkins` is deprecated. Please use `availableSkins` instead."
  );
  this.store.dispatch({
    type: "SET_AVAILABLE_SKINS",
    skins: options.avaliableSkins,
  });
} else if (availableSkins != null) {
  this.store.dispatch({
    type: "SET_AVAILABLE_SKINS",
    skins: availableSkins,
  });
}
```

### Demo Configuration

**File:** `/Users/hank/dev/src/MacAmp/webamp_clone/packages/webamp/demo/js/webampConfig.ts**

**Lines 47-128:**

```typescript
export async function getWebampConfig(
  screenshot: boolean,
  skinUrl: string | null,
  soundCloudPlaylist: SoundCloud.SoundCloudPlaylist | null
): Promise<Options & PrivateOptions & InjectableDependencies> {
  // ... butterchurn and layout setup ...

  const initialSkin = !skinUrl ? undefined : { url: skinUrl };

  return {
    initialSkin,
    initialTracks: screenshot
      ? undefined
      : soundCloudPlaylist != null
      ? SoundCloud.tracksFromPlaylist(soundCloudPlaylist)
      : initialTracks,
    availableSkins,  // Imported from availableSkins.ts
    windowLayout,
    filePickers: [dropboxFilePicker],
    enableHotkeys: true,
    enableMediaSession: true,
    // ...
    requireJSZip: () =>
      import(/* webpackChunkName: "jszip" */ "jszip/dist/jszip"),
    requireMusicMetadata: () =>
      import(/* webpackChunkName: "music-metadata" */ "music-metadata"),
    // ...
  };
}
```

---

## 8. Data Structures and Types

### SkinData Type

**File:** `/Users/hank/dev/src/MacAmp/webamp_clone/packages/webamp/js/types.ts`

**Lines 154-162:**

```typescript
export type SkinData = {
  skinImages: SkinImages;
  skinColors: string[];
  skinPlaylistStyle: PlaylistStyle;
  skinCursors: Cursors;
  skinRegion: SkinRegion;
  skinGenLetterWidths: GenLetterWidths;
  skinGenExColors: SkinGenExColors | null;
};
```

### Supporting Types

**Lines 89-102:**

```typescript
export type Cursors = { [cursor: string]: CursorImage };

export type GenLetterWidths = { [letter: string]: number };

export interface PlaylistStyle {
  normal: string;
  current: string;
  normalbg: string;
  selectedbg: string;
  font: string;
}

export type SkinImages = { [sprite: string]: string };

export type SkinRegion = { [windowName: string]: string[] };
```

**Lines 77-85 (CursorImage):**

```typescript
export type CursorImage =
  | {
      type: "cur";
      url: string;
    }
  | {
      type: "ani";
      aniData: Uint8Array;
    };
```

**Lines 126-149 (SkinGenExColors):**

```typescript
export interface SkinGenExColors {
  itemBackground: string;
  itemForeground: string;
  windowBackground: string;
  buttonText: string;
  windowText: string;
  divider: string;
  playlistSelection: string;
  listHeaderBackground: string;
  listHeaderText: string;
  listHeaderFrameTopAndLeft: string;
  listHeaderFrameBottomAndRight: string;
  listHeaderFramePressed: string;
  listHeaderDeadArea: string;
  scrollbarOne: string;
  scrollbarTwo: string;
  pressedScrollbarOne: string;
  pressedScrollbarTwo: string;
  scrollbarDeadArea: string;
  listTextHighlighted: string;
  listTextHighlightedBackground: string;
  listTextSelected: string;
  listTextSelectedBackground: string;
}
```

---

## 9. Default Skin

### Base Skin Data

**File:** `/Users/hank/dev/src/MacAmp/webamp_clone/packages/webamp/js/baseSkin.json`

The default skin is a minimal JSON file containing:
- **images:** Data URLs for essential sprites (EQ_PREAMP_LINE, EQ_GRAPH_LINE_COLORS)
- **colors:** Array of RGB color strings for visualizer
- **playlistStyle:** Font and color settings for playlist

**Reference in constants:**

**File:** `constants.ts` **Line 48:**

```typescript
export const DEFAULT_SKIN = baseSkin;
```

---

## 10. Data Flow Summary

### Skin Loading Flow

```
User Action
  ↓
Action Creator (setSkinFromUrl/setSkinFromBlob/loadDefaultSkin/openSkinFileDialog)
  ↓
Async Operations:
  - Fetch skin file (if URL)
  - Load JSZip library
  - Parse .wsz with skinParser()
    - Extract images → convert to data URLs
    - Extract text configs → parse INI
    - Extract cursors → convert to data URLs
  ↓
Dispatch SET_SKIN_DATA action
  ↓
Display Reducer
  - Updates state.display.skinImages
  - Updates state.display.skinColors
  - Updates state.display.skinCursors
  - Updates state.display.skinRegion
  - Updates state.display.skinPlaylistStyle
  - Updates state.display.skinGenLetterWidths
  - Updates state.display.skinGenExColors
  ↓
Skin Component (via selectors)
  - Generates CSS rules mapping sprites to selectors
  - Injects CSS into page
  ↓
UI Updates with new skin appearance
```

### Skin Selection Flow

```
User opens context menu
  ↓
SkinsContextMenu component renders
  - Shows "Load Skin..." option
  - Shows "<Base Skin>" option
  - Shows list from state.settings.availableSkins
  ↓
User clicks option
  ↓
Triggers action:
  - openSkinFileDialog() → file picker → setSkinFromBlob()
  - loadDefaultSkin() → resets to default
  - setSkin(url) → setSkinFromUrl()
  ↓
Follows skin loading flow above
```

### Available Skins Initialization Flow

```
WebampLazy constructor
  ↓
Options include availableSkins array
  ↓
Dispatch SET_AVAILABLE_SKINS action
  ↓
Settings Reducer
  - Updates state.settings.availableSkins
  ↓
SkinsContextMenu reads from selector
  - getAvaliableSkins(state)
  ↓
Renders menu items for each skin
```

---

## 11. Key Patterns and Best Practices

### Pattern 1: Lazy Loading of Dependencies

**JSZip is loaded only when needed:**

```typescript
requireJSZip: () => import(/* webpackChunkName: "jszip" */ "jszip/dist/jszip")
```

This reduces initial bundle size.

### Pattern 2: Async/Await for File Processing

All skin parsing is asynchronous:
```typescript
async function skinParser(zipFileBuffer, JSZip) {
  const zip = await JSZip.loadAsync(zipFileBuffer);
  const [colors, images, ...] = await Promise.all([...]);
  return { colors, images, ... };
}
```

### Pattern 3: Canvas for Image Processing

Sprites are extracted using canvas:
```typescript
context.drawImage(img, -sprite.x, -sprite.y);
const image = canvas.toDataURL();
```

This converts BMP regions to data URLs for CSS.

### Pattern 4: Reselect for Memoization

CSS rules are memoized to avoid regeneration:
```typescript
const getCssRules = createSelector(
  Selectors.getSkinImages,
  Selectors.getSkinCursors,
  (skinImages, skinCursors) => {
    // Generate CSS only when skin data changes
  }
);
```

### Pattern 5: CSS Injection for Dynamic Styling

Instead of inline styles, skins are applied via injected CSS:
```typescript
<Css id="webamp-skin">{cssRules}</Css>
```

This allows pseudo-elements and complex selectors.

### Pattern 6: Fallback to Default Skin

All parsing functions fall back to `DEFAULT_SKIN`:
```typescript
return viscolor ? parseViscolors(viscolor.contents) : DEFAULT_SKIN.colors;
```

### Pattern 7: Type Safety with TypeScript

Strong typing for all skin data structures:
- `SkinData`, `SkinImages`, `Cursors`, `PlaylistStyle`, etc.

### Pattern 8: Action-Based State Updates

All skin changes go through Redux actions:
- `SET_SKIN_DATA`
- `LOAD_DEFAULT_SKIN`
- `SET_AVAILABLE_SKINS`
- `LOADING` / `LOADED`

---

## 12. Event Handling

### File Drop Handling

**File:** `actionCreators/files.ts` **Lines 54-76:**

When files are dropped or selected, the system checks file extensions:
- `.wsz` or `.zip` → Load as skin
- `.eqf` → Load as equalizer preset
- Other → Load as media tracks

### Context Menu Handling

**File:** `components/SkinsContextMenu.tsx**

Context menu items trigger action creators directly:
```typescript
<Node onClick={openSkinFileDialog} label="Load Skin..." />
<Node onClick={loadDefaultSkin} label={"<Base Skin>"} />
<Node onClick={() => setSkin(skin.url)} label={skin.name} />
```

---

## 13. Configuration Options

### Webamp Options Related to Skins

From the WebampLazy constructor:

```typescript
interface Options {
  initialSkin?: { url: string };
  availableSkins?: Array<{ url: string; name: string }>;
  requireJSZip?: () => Promise<any>;
  // ... other options
}
```

### Demo Configuration Pattern

```typescript
const config = {
  initialSkin: skinUrl ? { url: skinUrl } : undefined,
  availableSkins: [
    { url: "/path/to/skin1.wsz", name: "Skin 1" },
    { url: "/path/to/skin2.wsz", name: "Skin 2" },
  ],
  requireJSZip: () => import("jszip/dist/jszip"),
};

const webamp = new WebampLazy(config);
```

---

## 14. Error Handling

### Skin Loading Errors

**File:** `actionCreators/files.ts`

Errors are caught and displayed to the user:

```typescript
try {
  const skinData = await skinParser(blob, JSZip);
  dispatch({ type: "SET_SKIN_DATA", data: skinData });
} catch (e) {
  console.error(e);
  dispatch({ type: "LOADED" });
  alert(`Failed to parse skin`);
}
```

### Missing JSZip

```typescript
if (!requireJSZip) {
  alert("Webamp has not been configured to support custom skins.");
  return;
}
```

### Fetch Errors

```typescript
try {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(response.statusText);
  }
  dispatch(setSkinFromBlob(response.blob()));
} catch (e) {
  console.error(e);
  dispatch({ type: "LOADED" });
  alert(`Failed to download skin from ${url}`);
}
```

---

## 15. Performance Considerations

### 1. Lazy Loading
- JSZip loaded only when needed
- Reduces initial bundle size

### 2. Memoization
- CSS rules memoized with reselect
- Prevents unnecessary recalculation

### 3. Parallel Parsing
- All skin components parsed in parallel:
  ```typescript
  await Promise.all([
    genVizColors(zip),
    genImages(zip),
    genCursors(zip),
    // ...
  ]);
  ```

### 4. Canvas Operations
- Native browser APIs used for image processing
- `createImageBitmap()` used when available for better performance

### 5. Data URLs
- Sprites converted to data URLs once, then cached in state
- No repeated file reading

---

## 16. Compatibility Notes

### Browser Support

**File:** `skinParserUtils.ts` **Lines 58-76:**

```typescript
export async function getImgFromBlob(
  blob: Blob
): Promise<ImageBitmap | HTMLImageElement | null> {
  try {
    // Use faster native browser API if available
    return await window.createImageBitmap(blob);
  } catch (e) {
    try {
      return await fallbackGetImgFromBlob(blob);
    } catch (ee) {
      // Like Winamp we will silently fail on images that don't parse
      return null;
    }
  }
}
```

### File Format Support

**File:** `skinParserUtils.ts` **Lines 100-118:**

- **BMP** - Native Winamp format
- **PNG** - Supported for smaller file sizes (following WACUP precedent)

```typescript
export async function getImgFromFilename(
  zip: JSZip,
  fileName: string
): Promise<HTMLImageElement | ImageBitmap | null> {
  // Winamp only supports .bmp, but WACUP set precedent of supporting
  // .png as well to reduce size
  const file = await getFileFromZip(zip, fileName, "(png|bmp)", "blob");
  if (!file) {
    return null;
  }

  const mimeType = `image/${getFileExtension(file.name) || "*"}`;
  const typedBlob = new Blob([file.contents], { type: mimeType });
  return getImgFromBlob(typedBlob);
}
```

### Case Sensitivity

**File:** `skinParserUtils.ts` **Lines 32-45:**

```typescript
// Windows file system is case insensitive, but zip files are not.
// This means it's possible for a zip to contain both `main.bmp` _and_
// `main.BMP` but in Winamp only one will be materialized onto disk when
// decompressing. To mimic that behavior we use the last matching file.
const lastFile = files[files.length - 1];
```

---

## Summary of Key Implementation Details

### Skin Loading Process:

1. **User selects skin** (via menu, file dialog, or drag-drop)
2. **Fetch/read file** (from URL or file system)
3. **Parse .wsz archive** using JSZip
4. **Extract components:**
   - Images → Canvas processing → Data URLs
   - Text configs → INI parsing → Style objects
   - Cursors → Binary conversion → Data URLs
5. **Dispatch Redux action** with parsed skin data
6. **Update state** in display reducer
7. **Generate CSS rules** via memoized selector
8. **Inject CSS** into page via Skin component
9. **UI updates** with new visual appearance

### Key Files for Skin System:

| File | Purpose |
|------|---------|
| `skinParser.js` | Main parsing orchestration |
| `skinParserUtils.ts` | File extraction utilities |
| `skinSprites.ts` | Sprite definitions |
| `skinSelectors.ts` | CSS selector mappings |
| `components/Skin.tsx` | CSS injection component |
| `actionCreators/files.ts` | Skin loading actions |
| `reducers/display.ts` | Skin state management |
| `components/SkinsContextMenu.tsx` | UI for skin selection |

### Configuration:

```typescript
new WebampLazy({
  initialSkin: { url: "/path/to/skin.wsz" },
  availableSkins: [
    { url: "/skin1.wsz", name: "Skin 1" },
    { url: "/skin2.wsz", name: "Skin 2" },
  ],
  requireJSZip: () => import("jszip/dist/jszip"),
});
```

---

## Recommendations for MacAmp Implementation

Based on this research, here are key considerations for implementing skin loading in MacAmp:

### 1. **Architecture Differences**
- Webamp uses Redux for state management
- Webamp uses React components with CSS injection
- MacAmp will need SwiftUI-based state management
- Consider using `@Published` properties and `ObservableObject` for skin state

### 2. **SwiftUI Skin Application**
- Instead of CSS injection, use SwiftUI modifiers
- Consider creating a `SkinProvider` environment object
- Use `.background()`, `.foregroundColor()`, etc. modifiers

### 3. **File Parsing**
- Swift has native ZIP support via `ZIPFoundation` or `Compression` framework
- BMP parsing can use `NSImage` or `UIImage` on macOS
- INI parsing will need custom implementation or library

### 4. **Sprite Extraction**
- Use `CGImage` and `CIImage` for image processing
- `CGImageCreateWithImageInRect` for sprite extraction
- Convert to SwiftUI `Image` for display

### 5. **Performance**
- Use Swift's native concurrency (async/await)
- Cache parsed skin data in memory
- Consider using `@MainActor` for UI updates

### 6. **State Management**
```swift
@MainActor
class SkinManager: ObservableObject {
    @Published var currentSkin: SkinData?
    @Published var availableSkins: [Skin] = []
    @Published var isLoading: Bool = false

    func loadSkin(from url: URL) async throws {
        // Implementation
    }
}
```

### 7. **UI Integration**
```swift
struct ContentView: View {
    @StateObject var skinManager = SkinManager()

    var body: some View {
        PlayerView()
            .environmentObject(skinManager)
            .applySkin(skinManager.currentSkin)
    }
}
```

---

## References

- **Webamp Repository:** `webamp_clone/`
- **Blog Post:** [How Winamp2-js Loads Native Skins in Your Browser](https://jordaneldredge.com/blog/how-winamp2-js-loads-native-skins-in-your-browser/)
- **Winamp Skin Museum:** [Online Collection](https://jordaneldredge.com/blog/winamp-skin-musuem/)
- **JSZip Documentation:** For understanding ZIP file handling patterns
- **Winamp Skinning Guide:** Referenced in comments throughout the code

---

## Conclusion

The Webamp skin system is a sophisticated implementation that:

1. **Parses legacy .wsz files** with high fidelity to original Winamp behavior
2. **Dynamically applies skins** via CSS injection and React components
3. **Manages state** through Redux with proper separation of concerns
4. **Handles errors gracefully** with user feedback
5. **Optimizes performance** through lazy loading and memoization
6. **Supports modern browsers** with fallbacks for compatibility

The system's modular design makes it easy to understand and extend, with clear separation between parsing logic, state management, and UI application. This architecture can serve as a strong reference for implementing similar functionality in SwiftUI-based MacAmp.
