# Research: Default skin fallback for VIDEO.bmp

## Current sprite extraction flow
- `SkinManager.applySkinPayload` (`MacAmpApp/ViewModels/SkinManager.swift`) builds `sheetsToProcess` from `SkinSprites.defaultSprites` and loops each sheet. If a sheet is missing or fails to decode it calls `createFallbackSprites`, which creates fully transparent `NSImage`s sized from metadata.
- VIDEO sprites already live inside `SkinSprites.defaultSprites` (`MacAmpApp/Models/SkinSprites.swift`), so when a skin omits `VIDEO.bmp` the entire loop substitutes transparent tiles. This is why the video window becomes invisible even though sprite names exist.

## Available storage hooks
- `AppSettings.ensureSkinsDirectory` writes to `~/Library/Application Support/MacAmp/Skins`, while `AppSettings.fallbackSkinsDirectory` returns `~/Library/Caches/MacAmp/FallbackSkins`. The caches path is ideal for derived assets because it survives relaunches but may be purged safely.
- `SkinMetadata.bundledSkins` enumerates bundled `.wsz` archives (including `Winamp.wsz`) so the app can grab the canonical classic skin without hard-coding paths.

## Opportunities for reuse
- The existing `Skin` struct already records `images` and `loadedSheets`, which is all we need for a fallback skin. Holding a `Skin` instance in memory prevents re-reading BMPs every time a sprite is missing.
- `SkinManager.loadSkin` already has the full set of `expectedSheets`. A helper that “builds a `Skin` from payload” could be reused both for the user-selected skin and for the default fallback skin.
- Because `applySkinPayload` already knows which `Sprite` objects belong to a sheet, we can swap transparent placeholders for lookups against `defaultSkin.images[sprite.name]` when the default skin really has that sheet.

## Constraints & risks
- Extracting `Winamp.wsz` to a directory requires ensuring the caches folder exists and cleaning it occasionally—caches may be deleted by the system, so we must recreate on demand.
- Loading two skins per launch increases memory usage, but only by the classic Winamp sprite set (~1–2 MB). CPU impact is confined to the first launch because both skins follow the same parsing path.
- Access to fallback sprites must avoid blocking the main thread. `SkinManager` already uses `Task.detached` to parse archives; the default skin loader should reuse that async pattern to avoid double work on the main actor.
