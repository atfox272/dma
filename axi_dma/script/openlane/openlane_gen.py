import os
import shutil
import json

# Define name
DESIGN_NAME = "axi_dma"

# Define paths
OPENLANE_DIR = "output/openlane"
SRC_DIR = os.path.join(OPENLANE_DIR, "src")
RTL_FILE = "rtl.f"
SDC_SOURCE = f"../rtl/{DESIGN_NAME}.sdc"
SDC_DEST = os.path.join(SRC_DIR, f"{DESIGN_NAME}.sdc")
PIN_ORDER_SOURCE = "openlane/openlane_pin_order.cfg"
PIN_ORDER_DEST = os.path.join(OPENLANE_DIR, "pin_order.cfg")
CONFIG_TEMPLATE = "openlane/openlane_config.json"
CONFIG_OUTPUT = os.path.join(OPENLANE_DIR, "config.json")

# Remove the existing src directory if it exists
if os.path.exists(SRC_DIR):
    shutil.rmtree(SRC_DIR)

# Create the src directory
os.makedirs(SRC_DIR, exist_ok=True)

# Read rtl.f and copy the listed files to SRC_DIR
verilog_files = []
with open(RTL_FILE, "r") as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith("#"):  # Skip comments and empty lines
            continue

        file_path = line
        if not os.path.exists(file_path):
            print(f"[WARN]: File not found: {file_path}")
            continue

        dest_path = os.path.join(SRC_DIR, os.path.basename(file_path))
        shutil.copy(file_path, dest_path)
        verilog_files.append(f"dir::src/{os.path.basename(file_path)}")
        print(f"[INFO]: Copied: {file_path} -> {dest_path}")

# Copy the SDC file
if os.path.exists(SDC_SOURCE):
    shutil.copy(SDC_SOURCE, SDC_DEST)
    print(f"[INFO]: Copied SDC: {SDC_SOURCE} -> {SDC_DEST}")
else:
    print(f"[WARN]: SDC file not found: {SDC_SOURCE}")

# Copy the pin order configuration file
if os.path.exists(PIN_ORDER_SOURCE):
    shutil.copy(PIN_ORDER_SOURCE, PIN_ORDER_DEST)
    print(f"[INFO]: Copied Pin Order: {PIN_ORDER_SOURCE} -> {PIN_ORDER_DEST}")
else:
    print(f"[WARN]: Pin order file not found: {PIN_ORDER_SOURCE}")

# Load the config template
with open(CONFIG_TEMPLATE, "r") as f:
    config = json.load(f)

# Update config fields
new_config = {
    "DESIGN_NAME": DESIGN_NAME,
    "VERILOG_FILES": verilog_files
}

# Merge the new config with the existing one while keeping new keys on top
new_config.update(config)

# Save the new config.json
with open(CONFIG_OUTPUT, "w") as f:
    json.dump(new_config, f, indent=4)

print(f"[INFO]: Config generated at {CONFIG_OUTPUT}")
