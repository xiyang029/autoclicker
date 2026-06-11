from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUTPUTS = {
    ROOT / "android" / "app" / "src" / "main" / "res" / "mipmap-mdpi" / "ic_launcher.png": 48,
    ROOT / "android" / "app" / "src" / "main" / "res" / "mipmap-hdpi" / "ic_launcher.png": 72,
    ROOT / "android" / "app" / "src" / "main" / "res" / "mipmap-xhdpi" / "ic_launcher.png": 96,
    ROOT / "android" / "app" / "src" / "main" / "res" / "mipmap-xxhdpi" / "ic_launcher.png": 144,
    ROOT / "android" / "app" / "src" / "main" / "res" / "mipmap-xxxhdpi" / "ic_launcher.png": 192,
    ROOT / "assets" / "icon" / "app_icon_preview.png": 512,
}

BASE_SIZE = 1024


def interpolate(start: tuple[int, int, int], end: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(round(start[i] + (end[i] - start[i]) * t) for i in range(3))


def draw_linear_gradient(size: int) -> Image.Image:
    image = Image.new("RGBA", (size, size))
    pixels = image.load()
    start = (255, 154, 90)
    mid = (255, 106, 92)
    end = (244, 63, 94)

    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            if t < 0.52:
                color = interpolate(start, mid, t / 0.52)
            else:
                color = interpolate(mid, end, (t - 0.52) / 0.48)
            pixels[x, y] = (*color, 255)
    return image


def apply_round_mask(image: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, image.size[0], image.size[1]), radius=radius, fill=255)
    rounded = Image.new("RGBA", image.size, (0, 0, 0, 0))
    rounded.paste(image, mask=mask)
    return rounded


def add_glow(image: Image.Image) -> None:
    glow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)
    draw.ellipse((110, 80, 620, 590), fill=(255, 243, 214, 110))
    glow = glow.filter(ImageFilter.GaussianBlur(48))
    image.alpha_composite(glow)


def draw_icon_shape() -> Image.Image:
    icon = apply_round_mask(draw_linear_gradient(BASE_SIZE), 248)
    add_glow(icon)

    shadow = Image.new("RGBA", (BASE_SIZE, BASE_SIZE), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_color = (117, 13, 48, 86)
    shadow_draw.ellipse((251, 283, 693, 725), outline=shadow_color, width=62)
    shadow_draw.ellipse((323, 355, 621, 653), outline=shadow_color, width=38)
    shadow_draw.ellipse((424, 428, 520, 524), fill=shadow_color)
    shadow_draw.polygon(
        [(592, 620), (770, 566), (684, 748), (635, 699), (556, 780), (510, 734), (588, 656)],
        fill=shadow_color,
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(18))
    shadow = ImageChops.offset(shadow, 0, 28)
    icon.alpha_composite(shadow)

    draw = ImageDraw.Draw(icon)
    draw.ellipse((252, 254, 692, 694), outline=(255, 255, 255, 240), width=62)
    draw.ellipse((324, 326, 620, 622), outline=(255, 255, 255, 240), width=38)
    draw.ellipse((424, 428, 520, 524), fill=(255, 255, 255, 255))
    draw.ellipse((454, 458, 490, 494), fill=(20, 33, 61, 255))

    for bounds, alpha in [((278, 288, 330, 340), 240), ((252, 380, 288, 416), 214), ((628, 252, 668, 292), 224)]:
        draw.ellipse(bounds, fill=(255, 242, 204, alpha))

    pointer_points = [(592, 592), (770, 538), (684, 720), (635, 671), (556, 752), (510, 706), (588, 628)]
    draw.polygon(pointer_points, fill=(45, 212, 191, 255))
    draw.line(pointer_points + [pointer_points[0]], fill=(255, 255, 255, 255), width=24, joint="curve")

    draw.arc((656, 260, 796, 400), start=292, end=20, fill=(255, 244, 222, 255), width=28)
    draw.arc((702, 216, 858, 372), start=292, end=20, fill=(255, 244, 222, 210), width=24)
    return icon


def main() -> None:
    icon = draw_icon_shape()
    for output_path, size in OUTPUTS.items():
        output_path.parent.mkdir(parents=True, exist_ok=True)
        resized = icon.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(output_path)
        print(f"Generated {output_path} ({size}x{size})")


if __name__ == "__main__":
    main()
