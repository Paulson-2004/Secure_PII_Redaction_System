from PIL import Image, ImageDraw
import os

OUTPUT_ASSET = 'assets/logo.png'
OUTPUT_SIZES = {
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
}

BACKGROUND_COLOR = (255, 255, 255, 0)
LEFT_COLOR = (20, 48, 92, 255)
RIGHT_COLOR = (23, 141, 146, 255)
LOCK_FILL = (255, 255, 255, 255)
LOCK_STROKE = (20, 48, 92, 255)


def create_logo_image(size):
    img = Image.new('RGBA', (size, size), BACKGROUND_COLOR)
    draw = ImageDraw.Draw(img)

    circle_radius = int(size * 0.45)
    circle_center = (size // 2, size // 2)
    draw.ellipse([
        (circle_center[0] - circle_radius, circle_center[1] - circle_radius),
        (circle_center[0] + circle_radius, circle_center[1] + circle_radius)
    ], fill=(255, 255, 255, 255))

    shield_points = [
        (size * 0.5, size * 0.16),
        (size * 0.84, size * 0.28),
        (size * 0.84, size * 0.56),
        (size * 0.5, size * 0.84),
        (size * 0.16, size * 0.56),
        (size * 0.16, size * 0.28),
    ]
    draw.polygon(shield_points, fill=(230, 230, 230, 255))

    left_shield = [
        (size * 0.5, size * 0.16),
        (size * 0.5, size * 0.84),
        (size * 0.16, size * 0.56),
        (size * 0.16, size * 0.28),
    ]
    right_shield = [
        (size * 0.5, size * 0.16),
        (size * 0.84, size * 0.28),
        (size * 0.84, size * 0.56),
        (size * 0.5, size * 0.84),
    ]
    draw.polygon(left_shield, fill=LEFT_COLOR)
    draw.polygon(right_shield, fill=RIGHT_COLOR)

    lock_width = size * 0.30
    lock_height = size * 0.26
    lock_left = size * 0.5 - lock_width / 2
    lock_top = size * 0.42
    lock_right = lock_left + lock_width
    lock_bottom = lock_top + lock_height
    draw.rounded_rectangle([
        (lock_left, lock_top),
        (lock_right, lock_bottom)
    ], radius=int(size * 0.04), fill=LOCK_FILL, outline=LOCK_STROKE, width=int(size * 0.03))

    shackle_center_x = size * 0.5
    shackle_top = size * 0.26
    shackle_bottom = size * 0.46
    shackle_width = size * 0.30
    shackle_height = size * 0.26
    draw.arc([
        (shackle_center_x - shackle_width / 2, shackle_top),
        (shackle_center_x + shackle_width / 2, shackle_top + shackle_height)
    ], start=200, end=-20, fill=LOCK_STROKE, width=int(size * 0.05))
    draw.line([
        (shackle_center_x - shackle_width / 2, shackle_top + shackle_height / 2),
        (shackle_center_x - shackle_width / 2, shackle_top + shackle_height * 0.9)
    ], fill=LOCK_STROKE, width=int(size * 0.05))
    draw.line([
        (shackle_center_x + shackle_width / 2, shackle_top + shackle_height / 2),
        (shackle_center_x + shackle_width / 2, shackle_top + shackle_height * 0.9)
    ], fill=LOCK_STROKE, width=int(size * 0.05))

    return img


def save_image(path, image):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path, format='PNG')


def main():
    os.makedirs('assets', exist_ok=True)
    asset_img = create_logo_image(512)
    save_image(OUTPUT_ASSET, asset_img)

    for path, size in OUTPUT_SIZES.items():
        save_image(path, asset_img.resize((size, size), Image.LANCZOS))

    print(f'Created {OUTPUT_ASSET} and Android launcher icons.')


if __name__ == '__main__':
    main()
