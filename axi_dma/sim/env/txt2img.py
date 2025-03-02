from PIL import Image
import os

def read_image_size(file_path):
    with open(file_path, 'r') as f:
        line = f.readline().strip()
        size_str = line.split(':')[1].strip()
        width, height = map(int, size_str.split('x'))
    return width, height

def read_image_data(file_path, width, height):
    with open(file_path, 'r') as f:
        lines = f.readlines()[3:]  # Skip the first 3 lines
    data = []
    for line in lines:
        # Split the line into 4-character chunks (each representing a pixel in RGB565 format)
        pixels = [line[i:i+4] for i in range(0, len(line.strip()), 4)]
        pixels.reverse()  # Reverse the order of pixels in each line
        data.extend(pixels)
    
    return data

def convert_rgb565_to_rgb888(rgb565):
    r = (rgb565 >> 11) & 0x1F
    g = (rgb565 >> 5) & 0x3F
    b = rgb565 & 0x1F
    r = (r << 3) | (r >> 2)
    g = (g << 2) | (g >> 4)
    b = (b << 3) | (b >> 2)
    return (r, g, b)

def create_image(data, width, height):
    image = Image.new('RGB', (width, height))
    pixels = image.load()
    
    for y in range(height):
        for x in range(width):
            index = y * width + x
            rgb565 = int(data[index], 16)
            pixels[x, y] = convert_rgb565_to_rgb888(rgb565)
    
    return image

def process_files(directory):
    for file_name in os.listdir(directory):
        if file_name.startswith('dst_mem_') and file_name.endswith('.txt') and 'format' not in file_name:
            num = file_name.split('_')[2].split('.')[0]
            format_file = f'dst_mem_{num}_format.txt'
            data_file = f'dst_mem_{num}.txt'
            
            format_path = os.path.join(directory, format_file)
            data_path = os.path.join(directory, data_file)
            
            if os.path.getsize(format_path) == 0:
                print(f'Skipping {data_file}, because DMA channel {num} is disable')
                continue
            
            width, height = read_image_size(format_path)
            data = read_image_data(data_path, width, height)
            image = create_image(data, width, height)
            
            output_image_path = os.path.join(directory, f'output_channel_{num}.png')
            image.save(output_image_path)
            print(f'Saved image: {output_image_path}')

if __name__ == '__main__':
    directory = os.path.dirname(os.path.abspath(__file__))
    process_files(directory)