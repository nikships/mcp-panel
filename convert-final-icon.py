#!/usr/bin/env python3

import os
import shutil
from PIL import Image
import subprocess

def create_app_icon(input_image):
    """Create macOS .icns file from the chosen icon"""

    output_dir = "MCPServerManager/icons"
    os.makedirs(output_dir, exist_ok=True)

    iconset_dir = f"{output_dir}/AppIcon.iconset"
    os.makedirs(iconset_dir, exist_ok=True)

    # Open and process image
    img = Image.open(input_image).convert("RGBA")

    # Create a black background image
    bg = Image.new('RGBA', img.size, (0, 0, 0, 255))
    # Paste the original image onto the black background
    bg.paste(img, (0, 0), img)
    img = bg

    # macOS icon sizes
    sizes = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png"),
    ]

    print("Creating final app icon...")
    for size, filename in sizes:
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(os.path.join(iconset_dir, filename), "PNG", optimize=True)
        print(f"  ✓ {filename}")

    # Convert to .icns
    print("Converting to .icns...")
    subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", f"{output_dir}/AppIcon.icns"])

    # Clean up iconset directory
    shutil.rmtree(iconset_dir)

    print(f"\n✅ Final app icon created: {output_dir}/AppIcon.icns")

if __name__ == "__main__":
    input_path = 'app-icon.png'
    create_app_icon(input_path)
