# MacAmp Icon - macOS 26 Tahoe Edition

This iconset is designed for **macOS 26 Tahoe** with support for the new **Liquid Glass** design language and layered icon system.

## 🎨 Design Features

### Liquid Glass Aesthetic
- **Layered depth**: Icon appears as multiple layers of glass with subtle depth
- **Adaptive tinting**: Supports light, dark, and custom color tinting
- **Glass effects**: Subtle blur and transparency for modern macOS look
- **Vaporwave styling**: Purple-to-pink gradient with retro 80s/90s aesthetic

### Visual Elements
1. **Background Layer**: Purple-to-pink gradient with subtle grid overlay
2. **Sun Layer**: Retro orange sunset with horizontal scanlines and glow effect
3. **Equalizer Layer**: Cyan-to-pink gradient bars with glass highlights
4. **Text Layer**: "MacAmp" branding with shadow and highlight for depth

## 📁 File Structure

### Composite Icons (Backward Compatibility)
Standard .icns format icons for macOS Sequoia and earlier:
- `icon_16x16.png` through `icon_512x512@2x.png`
- All standard macOS icon sizes (1x and 2x)
- Ready to use with traditional asset catalogs

### Layered Components (macOS 26 Tahoe)
Separate layer files for `.icon` format compilation:
- `layer_1024x1024_background.png` - Gradient background + grid
- `layer_1024x1024_sun.png` - Retro sun with scanlines
- `layer_1024x1024_equalizer.png` - Audio equalizer bars
- `layer_1024x1024_text.png` - MacAmp text branding

## 🔧 Implementation

### Option 1: Traditional Asset Catalog (Sequoia & Earlier)
Simply use the composite icons with the existing `Contents.json`:
```bash
# Copy to your Xcode project
cp -r AppIcon-Tahoe.appiconset YourApp/Assets.xcassets/
```

### Option 2: macOS 26 Tahoe .icon Format
For full Liquid Glass support with layering:

1. **Create .icon folder structure**:
   ```
   MacAmp.icon/
   ├── layer1/
   │   └── content.png (background layer)
   ├── layer2/
   │   └── content.png (sun layer)
   ├── layer3/
   │   └── content.png (equalizer layer)
   └── layer4/
       └── content.png (text layer)
   ```

2. **Compile with actool**:
   ```bash
   xcrun actool --compile ./Assets.car \
     --platform macosx \
     --minimum-deployment-target 15.0 \
     --app-icon MacAmp \
     MacAmp.icon
   ```

3. **Add to app bundle**:
   - Place `Assets.car` in `YourApp.app/Contents/Resources/`
   - Also include legacy `.icns` for backward compatibility
   - Set `CFBundleIconName` in Info.plist to "MacAmp"

## 🎯 macOS 26 Features

### Adaptive Appearance
The layered format enables:
- **Light mode**: Standard appearance with full colors
- **Dark mode**: Automatic adjustment for dark backgrounds
- **Tinted mode**: User-customizable color tinting
- **Clear mode**: Transparent iOS-style appearance

### Layer Guidelines
- **Maximum 4 layer groups** (we use all 4)
- Each layer supports transparency
- Layers automatically receive depth effect
- System applies automatic glass/blur effects

## 🔄 Conversion Guide

### From Original Iconset
The Tahoe version enhances the original with:
- ✅ Subtle blur for liquid glass effect
- ✅ Layer separation for depth
- ✅ Enhanced transparency and highlights
- ✅ Optimized for adaptive tinting

### Differences from Original
| Feature | Original | Tahoe |
|---------|----------|-------|
| Format | .icns only | .icon + .icns |
| Layers | Composite | 4 separate layers |
| Effects | None | Liquid glass blur |
| Tinting | No | Yes (adaptive) |
| macOS Support | All versions | 15+ (26+ for full features) |

## 📋 Requirements

### Build Tools
- **Xcode 16.0+**: For macOS 26 SDK
- **actool**: Icon compiler (included with Xcode)
- **Python 3.x + Pillow**: For regenerating icons

### System Requirements
- **Full features**: macOS 26 Tahoe or later
- **Backward compatible**: macOS 15.0 (Sequoia) minimum
- **Legacy support**: Composite icons work on all macOS versions

## 🎨 Regenerating Icons

To customize or regenerate the icons:

```bash
# Edit the generation script
python3 generate_tahoe_icon.py

# Output will be in tmp/AppIcon-Tahoe.appiconset/
```

### Customization Options
Edit `generate_tahoe_icon.py` to modify:
- Gradient colors (purple/pink)
- Sun size and position
- Equalizer bar count/heights
- Text font and styling
- Layer blur intensity

## 🚀 Best Practices

### For macOS 26 Tahoe
1. Use all 4 layer groups for maximum depth effect
2. Keep layers visually distinct for tinting to work well
3. Use transparency appropriately (not too much, not too little)
4. Test with all appearance modes (light/dark/tinted/clear)

### For Backward Compatibility
1. Always include composite `.icns` fallback
2. Ensure composite version looks good without layering
3. Test on macOS Sequoia to verify appearance
4. Set proper minimum deployment target

## 📖 Additional Resources

- [Apple Human Interface Guidelines - App Icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [macOS 26 Tahoe Icon Format Documentation](https://successfulsoftware.net/2025/09/26/updating-application-icons-for-macos-26-tahoe-and-liquid-glass/)
- [Liquid Glass Design Language](https://developer.apple.com/design/liquid-glass/)

## 📝 Credits

- **Design**: Vaporwave/synthwave aesthetic inspired by classic Winamp skins
- **Generated**: Python script using Pillow (PIL)
- **Format**: macOS 26 Tahoe `.icon` format with backward compatibility
- **License**: Same as MacAmp project

---

**Note**: The `.icon` format is new in macOS 26 Tahoe. For maximum compatibility, this iconset provides both modern layered assets and traditional composite icons.
