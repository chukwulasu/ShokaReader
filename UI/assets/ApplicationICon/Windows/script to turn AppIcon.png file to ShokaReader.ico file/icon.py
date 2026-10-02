from PIL import Image

img = Image.open("AppIcon.png")
icon_sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
img.save("ShokaReader.ico", format="ICO", sizes=icon_sizes)