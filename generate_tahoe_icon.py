#!/usr/bin/env python3
"""
Generate MacAmp app icon for macOS 26 Tahoe with Liquid Glass layering support
Creates separate layer components that can be compiled into .icon format

macOS 26 Tahoe Features:
- Layered glass appearance with depth
- Support for light/dark/tinted modes
- Maximum 4 layer groups
- Requires .icon folder format (not .icns)
"""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math
import os

OUTPUT_DIR = "tmp/AppIcon-Tahoe.appiconset"

def create_gradient_background(width, height, opacity=1.0):
    """Create purple to pink gradient background with optional transparency"""
    image = Image.new('RGBA', (width, height))
    draw = ImageDraw.Draw(image)

    for y in range(height):
        ratio = y / height
        # Purple (top) to pink (bottom)
        r = int(138 + (255 - 138) * ratio)
        g = int(43 + (20 - 43) * ratio)
        b = int(226 + (147 - 226) * ratio)
        a = int(255 * opacity)
        draw.line([(0, y), (width, y)], fill=(r, g, b, a))

    return image

def apply_liquid_glass_effect(image, blur_radius=2):
    """Apply subtle blur for liquid glass appearance"""
    return image.filter(ImageFilter.GaussianBlur(blur_radius))

def create_grid_overlay(width, height):
    """Create subtle grid overlay for vaporwave aesthetic"""
    overlay = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    line_spacing = width // 10
    line_color = (138, 43, 226, 15)  # Very subtle purple

    for i in range(0, width, line_spacing):
        draw.line([(i, 0), (i, height)], fill=line_color, width=1)
    for i in range(0, height, line_spacing):
        draw.line([(0, i), (width, i)], fill=line_color, width=1)

    return overlay

def draw_sun_layer(size):
    """Layer 1: Sun with scanlines (background layer)"""
    layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    # Sun parameters
    sun_radius = size // 6
    sun_y = size // 3
    sun_x = size // 2

    # Draw sun circle with glow
    for glow_radius in range(sun_radius + 15, sun_radius - 1, -2):
        glow_alpha = int(100 * (sun_radius + 15 - glow_radius) / 15)
        draw.ellipse(
            [sun_x - glow_radius, sun_y - glow_radius,
             sun_x + glow_radius, sun_y + glow_radius],
            fill=(255, 140, 0, glow_alpha)
        )

    # Main sun
    draw.ellipse(
        [sun_x - sun_radius, sun_y - sun_radius,
         sun_x + sun_radius, sun_y + sun_radius],
        fill=(255, 140, 0, 255)
    )

    # Scanlines
    line_spacing = max(1, sun_radius // 8)
    for i in range(-sun_radius, sun_radius, line_spacing):
        y = sun_y + i
        if abs(i) < sun_radius:
            half_width = math.sqrt(sun_radius * sun_radius - i * i)
            x1 = sun_x - half_width
            x2 = sun_x + half_width
            draw.line([(x1, y), (x2, y)], fill=(255, 165, 0, 200), width=2)

    return layer

def draw_equalizer_layer(size):
    """Layer 2: Equalizer bars (middle layer)"""
    layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    num_bars = 7
    bar_width = size // (num_bars * 3)
    spacing = bar_width
    eq_height = size // 5
    eq_y = int(size * 0.52)
    eq_x = size // 6

    heights = [0.4, 0.7, 0.9, 1.0, 0.9, 0.6, 0.5]

    for i in range(num_bars):
        bar_x = eq_x + i * (bar_width + spacing)
        bar_height = int(eq_height * heights[i % len(heights)])
        bar_y = eq_y + eq_height - bar_height

        # Gradient from cyan to pink
        ratio = i / (num_bars - 1)
        r = int(0 + (255 - 0) * ratio)
        g = int(255 - (255 - 20) * ratio)
        b = int(255 - (255 - 147) * ratio)

        # Bar with slight transparency for layering
        draw.rectangle(
            [bar_x, bar_y, bar_x + bar_width, eq_y + eq_height],
            fill=(r, g, b, 220),
            outline=(255, 255, 255, 180),
            width=1
        )

        # Add highlight for glass effect (only if bar is large enough)
        if bar_width > 2 and bar_height > 3:
            highlight_height = max(1, bar_height // 3)
            draw.rectangle(
                [bar_x + 1, bar_y + 1, bar_x + bar_width - 1, bar_y + highlight_height],
                fill=(255, 255, 255, 60)
            )

    return layer

def draw_text_layer(size):
    """Layer 3: MacAmp text (foreground layer)"""
    layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    text_size = size // 6
    text_y = int(size * 0.75)

    try:
        font = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Bold.ttf', text_size)
        bbox = draw.textbbox((0, 0), "MacAmp", font=font)
        text_width = bbox[2] - bbox[0]
    except:
        font = ImageFont.load_default()
        text_width = text_size * 4

    text_x = (size - text_width) // 2

    # Text shadow for depth
    for offset in [(2, 2), (1, 1)]:
        draw.text((text_x + offset[0], text_y + offset[1]), "MacAmp",
                 font=font, fill=(0, 0, 0, 150))

    # Main text with slight gradient effect
    draw.text((text_x, text_y), "MacAmp", font=font, fill=(255, 255, 255, 255))

    # Highlight on top of text for glass effect
    draw.text((text_x, text_y - 1), "MacAmp", font=font, fill=(255, 255, 255, 80))

    return layer

def create_composite_icon(size):
    """Create composite icon with all layers for standard .icns format"""
    # Background gradient
    base = create_gradient_background(size, size)

    # Add grid overlay
    grid = create_grid_overlay(size, size)
    base = Image.alpha_composite(base, grid)

    # Layer 1: Sun
    sun_layer = draw_sun_layer(size)
    base = Image.alpha_composite(base, sun_layer)

    # Layer 2: Equalizer
    eq_layer = draw_equalizer_layer(size)
    base = Image.alpha_composite(base, eq_layer)

    # Layer 3: Text
    text_layer = draw_text_layer(size)
    base = Image.alpha_composite(base, text_layer)

    # Apply liquid glass effect
    base = apply_liquid_glass_effect(base, blur_radius=1)

    return base

def create_layered_components(size):
    """Create separate layer components for .icon format compilation"""
    layers = {}

    # Background layer (gradient + grid)
    background = create_gradient_background(size, size)
    grid = create_grid_overlay(size, size)
    layers['background'] = Image.alpha_composite(background, grid)

    # Sun layer
    layers['sun'] = draw_sun_layer(size)

    # Equalizer layer
    layers['equalizer'] = draw_equalizer_layer(size)

    # Text layer
    layers['text'] = draw_text_layer(size)

    return layers

# Standard icon sizes for macOS
sizes = [
    (16, '16x16'),
    (32, '16x16@2x'),
    (32, '32x32'),
    (64, '32x32@2x'),
    (128, '128x128'),
    (256, '128x128@2x'),
    (256, '256x256'),
    (512, '256x256@2x'),
    (512, '512x512'),
    (1024, '512x512@2x'),
]

print("Generating macOS 26 Tahoe MacAmp icons...")
print(f"Output directory: {OUTPUT_DIR}\n")

# Create composite icons for backward compatibility
print("Creating composite icons (.icns format):")
for size, name in sizes:
    print(f"  Creating {name} ({size}x{size})...")
    icon = create_composite_icon(size)
    # Convert to RGB for compatibility
    rgb_icon = Image.new('RGB', icon.size, (255, 255, 255))
    rgb_icon.paste(icon, mask=icon.split()[3])
    rgb_icon.save(f'{OUTPUT_DIR}/icon_{name}.png')

# Create layered components for .icon format (1024x1024 only)
print("\nCreating layered components (.icon format):")
layer_sizes = [(1024, 'layer_1024x1024')]

for size, name in layer_sizes:
    print(f"  Creating layers for {size}x{size}...")
    layers = create_layered_components(size)

    for layer_name, layer_image in layers.items():
        filename = f'{OUTPUT_DIR}/{name}_{layer_name}.png'
        layer_image.save(filename)
        print(f"    Saved: {layer_name}")

print("\n✅ Icon generation complete!")
print(f"\nGenerated files in: {OUTPUT_DIR}/")
print("\nFor macOS 26 Tahoe .icon format:")
print("  - Use layered components (background, sun, equalizer, text)")
print("  - Compile with actool to create Assets.car")
print("  - Maximum 4 layer groups supported")
print("\nFor backward compatibility:")
print("  - Composite icons provided in standard sizes")
print("  - Use with traditional .icns format")
