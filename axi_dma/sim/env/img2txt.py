from PIL import Image

def convert_image_to_rgb565(image_path, output_path):
    # Open the image file
    with Image.open(image_path) as img:
        # Convert image to RGB
        img = img.convert('RGB')
        width, height = img.size

        with open(output_path, 'w') as f:
            for y in range(height):
                line = []
                for x in range(width):
                    r, g, b = img.getpixel((x, y))
                    # Convert RGB888 to RGB565
                    rgb565 = ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3)
                    line.append(f'{rgb565:04X}')
                    if len(line) == 16:
                        f.write(''.join(line[::-1]) + '\n')
                        line = []
                if line:
                    f.write(' '.join(line[::-1]) + '\n')

if __name__ == "__main__":
    image_path = 'input.jpg'  # Replace with your image file path
    output_path = 'env/src_mem.txt'  # Replace with your desired output file path
    convert_image_to_rgb565(image_path, output_path)


    