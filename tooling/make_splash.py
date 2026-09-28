"""Draw the factory's boot image: services/shell/splash.png.

"Latensea" over "PRODUCTIONS" on the navy ground, in Manrope, on a square
Godot fits to the screen's width (boot_splash/stretch_mode Keep). Godot shows
it the moment an app starts, while the engine loads; then the opening scene
(services/shell/opening.gd) draws the same image the same way and the wave
under it. Where the wave goes is WAVE_AT in splash.gd, in this image's pixels.

Needs Pillow. Run again after changing the words, the font or the palette:

    python tooling/make_splash.py
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SHELL = ROOT / "services" / "shell"
LOOK = ROOT / "services" / "look"
SIDE = 1080
GROUND = "#121829"
INK = "#eef2fa"
INK_SOFT = "#8e9ab8"
NAME, NAME_SIZE, NAME_WEIGHT = "Latensea", 132, 750
LINE, LINE_SIZE, LINE_WEIGHT, SPACING = "PRODUCTIONS", 38, 600, 11
# The name's baseline, and the line's below it, in this image's pixels.
NAME_BASE, LINE_BASE = 520, 590


def font(size: int, weight: int) -> ImageFont.FreeTypeFont:
    face = ImageFont.truetype(str(LOOK / "fonts" / "Manrope.ttf"), size)
    face.set_variation_by_axes([weight])
    return face


def main() -> None:
    image = Image.new("RGB", (SIDE, SIDE), GROUND)
    draw = ImageDraw.Draw(image)
    name = font(NAME_SIZE, NAME_WEIGHT)
    draw.text((SIDE / 2, NAME_BASE), NAME, font=name, fill=INK, anchor="ms")
    line = font(LINE_SIZE, LINE_WEIGHT)
    widths = [draw.textlength(letter, font=line) for letter in LINE]
    x = (SIDE - (sum(widths) + SPACING * (len(LINE) - 1))) / 2
    for letter, width in zip(LINE, widths):
        draw.text((x, LINE_BASE), letter, font=line, fill=INK_SOFT, anchor="ls")
        x += width + SPACING
    image.save(SHELL / "splash.png", optimize=True)
    print(f"wrote {SHELL / 'splash.png'}")


if __name__ == "__main__":
    main()
