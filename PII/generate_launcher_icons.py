from PIL import Image
import os

# Path to the source logo
source_logo = r'C:\Users\HP\OneDrive\Desktop\privlock\assets\images\privlock_logo.png'

# Android mipmap directories and sizes
mipmap_dirs = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192
}

# Open the source image
img = Image.open(source_logo)

# Ensure it's in RGBA mode for transparency
img = img.convert('RGBA')

# Base path for res
res_path = r'C:\Users\HP\OneDrive\Desktop\privlock\android\app\src\main\res'

for mipmap, size in mipmap_dirs.items():
    # Resize the image
    resized_img = img.resize((size, size), Image.Resampling.LANCZOS)
    
    # Path to save
    save_path = os.path.join(res_path, mipmap, 'ic_launcher.png')
    
    # Save the image
    resized_img.save(save_path)
    
    print(f'Created {save_path}')

print('All launcher icons generated successfully.')