#!/usr/bin/env python3

import os
import shutil
from PIL import Image
import subprocess

def create_iconset(input_image, output_name):
    """Create macOS .icns file from input image"""

    # Create iconset directory
    iconset_dir = f"{output_name}.iconset"
    os.makedirs(iconset_dir, exist_ok=True)

    # Open and process image
    img = Image.open(input_image)

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

    print(f"Creating iconset for {output_name}...")
    for size, filename in sizes:
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(os.path.join(iconset_dir, filename), "PNG", optimize=True)
        print(f"  ✓ {filename}")

    # Convert to .icns using iconutil
    print(f"Converting to .icns...")
    subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", f"{output_name}.icns"])

    # Clean up iconset directory
    shutil.rmtree(iconset_dir)

    print(f"✓ Created {output_name}.icns\n")

if __name__ == "__main__":
    # Icon files from nanobanana (minimalist v2)
    icons = [
        ("gen_20251024_122326_1_1_00aa0bed.png", "icon1-folded-m"),
        ("gen_20251024_122336_1_1_0f422185.png", "icon2-server-blocks"),
        ("gen_20251024_122348_1_1_864b3afc.png", "icon3-twisted-ribbon"),
        ("gen_20251024_122358_1_1_83bcf0a6.png", "icon4-cube"),
        ("gen_20251024_122407_1_1_87b446e3.png", "icon5-hex-prism"),
    ]

    nanobanana_dir = os.path.expanduser("~/nanobanana-images")
    output_dir = "MCPServerManager/icons"
    os.makedirs(output_dir, exist_ok=True)

    os.chdir(output_dir)

    for icon_file, output_name in icons:
        input_path = os.path.join(nanobanana_dir, icon_file)
        if os.path.exists(input_path):
            create_iconset(input_path, output_name)
        else:
            print(f"Warning: {input_path} not found, skipping...")

    print("\n✅ All icons created in MCPServerManager/icons/")
    print("\nIcon options (minimalist v2):")
    print("  1. icon1-folded-m.icns            - Folded ribbon M letter")
    print("  2. icon2-server-blocks.icns       - Stacked server blocks")
    print("  3. icon3-twisted-ribbon.icns      - Twisted ribbon network")
    print("  4. icon4-cube.icns                - Simple gradient cube")
    print("  5. icon5-hex-prism.icns           - Hexagonal prism")
