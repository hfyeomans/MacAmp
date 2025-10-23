#!/usr/bin/env python3
"""
Generate MacAmp app icon with vaporwave/synthwave aesthetic
"""
from PIL import Image, ImageDraw, ImageFont
import math

def create_gradient_background(width, height):
    """Create purple to pink gradient background"""
    image = Image.new('RGB', (width, height))
    draw = ImageDraw.Draw(image)

    # Vaporwave gradient: deep purple to hot pink
    for y in range(height):
        # Calculate color interpolation
        ratio = y / height

        # Purple (top) to pink (bottom)
        r = int(138 + (255 - 138) * ratio)  # 138 -> 255
        g = int(43 + (20 - 43) * ratio)     # 43 -> 20
        b = int(226 + (147 - 226) * ratio)  # 226 -> 147

        draw.line([(0, y), (width, y)], fill=(r, g, b))

    return image

def draw_sun(draw, cx, cy, radius, color):
    """Draw retro sunset sun with horizontal lines"""
    # Draw main sun circle
    draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius],
                 fill=color, outline=None)

    # Add horizontal scanlines for retro effect
    line_spacing = max(1, radius // 8)
    for i in range(-radius, radius, line_spacing):
        y = cy + i
        # Calculate chord width at this height
        if abs(i) < radius:
            half_width = math.sqrt(radius * radius - i * i)
            x1 = cx - half_width
            x2 = cx + half_width
            draw.line([(x1, y), (x2, y)], fill=(255, 165, 0), width=2)

def draw_equalizer_bars(draw, x, y, width, height, num_bars=7):
    """Draw retro equalizer bars"""
    bar_width = width // (num_bars * 2)
    spacing = bar_width

    # Create bars with varying heights
    heights = [0.4, 0.7, 0.9, 1.0, 0.9, 0.6, 0.5]

    for i in range(num_bars):
        bar_x = x + i * (bar_width + spacing)
        bar_height = int(height * heights[i % len(heights)])
        bar_y = y + height - bar_height

        # Gradient from cyan to pink
        ratio = i / (num_bars - 1)
        r = int(0 + (255 - 0) * ratio)
        g = int(255 - (255 - 20) * ratio)
        b = int(255 - (255 - 147) * ratio)

        draw.rectangle([bar_x, bar_y, bar_x + bar_width, y + height],
                      fill=(r, g, b), outline=(255, 255, 255), width=1)

def draw_retro_text(draw, text, x, y, size, color):
    """Draw retro-style text with outline"""
    try:
        # Try to use a geometric sans-serif font
        font = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Bold.ttf', size)
    except:
        font = ImageFont.load_default()

    # Draw black outline for visibility
    outline_color = (0, 0, 0)
    for ox in [-2, -1, 0, 1, 2]:
        for oy in [-2, -1, 0, 1, 2]:
            if ox != 0 or oy != 0:
                draw.text((x + ox, y + oy), text, font=font, fill=outline_color)

    # Draw main text
    draw.text((x, y), text, font=font, fill=color)

def create_icon(size):
    """Create MacAmp icon at specified size"""
    # Create base gradient
    img = create_gradient_background(size, size)
    draw = ImageDraw.Draw(img)

    # Add grid lines for vaporwave aesthetic (subtle)
    grid_color = (255, 255, 255, 30)
    line_spacing = size // 10
    for i in range(0, size, line_spacing):
        # Vertical lines
        draw.line([(i, 0), (i, size)], fill=(138, 43, 226, 20), width=1)
        # Horizontal lines
        draw.line([(0, i), (size, i)], fill=(138, 43, 226, 20), width=1)

    # Draw sun in upper portion
    sun_radius = size // 6
    sun_y = size // 3
    draw_sun(draw, size // 2, sun_y, sun_radius, (255, 140, 0))

    # Draw equalizer bars in middle
    eq_height = size // 5
    eq_y = int(size * 0.52)
    draw_equalizer_bars(draw, size // 6, eq_y, size * 2 // 3, eq_height)

    # Draw MacAmp text
    text_size = size // 6
    text_y = int(size * 0.75)

    # Center the text
    try:
        font = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Bold.ttf', text_size)
        bbox = draw.textbbox((0, 0), "MacAmp", font=font)
        text_width = bbox[2] - bbox[0]
    except:
        text_width = text_size * 4  # Rough estimate

    text_x = (size - text_width) // 2
    draw_retro_text(draw, "MacAmp", text_x, text_y, text_size, (255, 255, 255))

    return img

# Generate all required icon sizes for macOS
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

print("Generating MacAmp icons...")
for size, name in sizes:
    print(f"Creating {name} ({size}x{size})...")
    icon = create_icon(size)
    icon.save(f'MacAmpApp/Assets.xcassets/AppIcon.appiconset/icon_{name}.png')

print("Icon generation complete!")
