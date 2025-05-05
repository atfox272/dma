# OpenLane directories and script
OUTPUT_DIR := output
OPENLANE_DESIGN_DIR ?= ../../test_env/OpenLane/designs/dcasic
OPENLANE_SETUP_DIR := $(OUTPUT_DIR)/openlane
RTL_LIST := rtl.f
SRC_DIR := $(OPENLANE_SETUP_DIR)/src
OPENLANE_SCRIPT := openlane/openlane_gen.py
ASSEMBLER_SCRIPT := assembler_script/assembler.py
FIRMWARE_DIR := ../firmware
BITSTREAM_SCRIPT := programmer_script/build.py
UPLOAD_SCRIPT := programmer_script/programmer.py
MAIN_HEX := $(FIRMWARE_DIR)/main/main.hex
ISR_HEX := $(FIRMWARE_DIR)/isr/isr.hex
BITSTREAM_OUTPUT := $(OUTPUT_DIR)/programmer/bitstream.hex

# Detect OS (Windows or Linux/macOS)
OS := $(shell uname 2>/dev/null || echo Windows)

.PHONY: clean openlane_gen build_bitstream

# Prepare output directory
prepare:
ifeq ($(OS), Windows)
	@if not exist "$(OUTPUT_DIR)" mkdir "$(OUTPUT_DIR)" && echo [INFO]: Created output directory.
else
	@mkdir -p $(OUTPUT_DIR)
	@echo "[INFO]: Created output directory"
endif

# Clean output directory
clean:
ifeq ($(OS), Windows)
	@if exist "$(OUTPUT_DIR)" ( \
		rmdir /s /q "$(OUTPUT_DIR)" && echo [INFO]: Cleaned output directory. \
	) else ( \
		echo [INFO]: No output directory to clean. \
	)
else
	@rm -rf $(OUTPUT_DIR)
	@echo "[INFO]: Cleaned output directory"
endif

# Generate OpenLane source files
openlane_gen: prepare
ifeq ($(OS), Windows)
	@if not exist "$(OPENLANE_SETUP_DIR)" mkdir "$(OPENLANE_SETUP_DIR)"
	@if not exist "$(SRC_DIR)" mkdir "$(SRC_DIR)"
	@python $(OPENLANE_SCRIPT) "$(RTL_LIST)" "$(SRC_DIR)"
	@echo [INFO]: OpenLane environment files generated in $(OPENLANE_SETUP_DIR)
else
	@mkdir -p $(SRC_DIR)
	@python3 $(OPENLANE_SCRIPT) $(RTL_LIST) $(SRC_DIR)
	@echo "[INFO]: OpenLane source files generated in $(SRC_DIR)"
endif

# Push OpenLane folder to the specified design directory
openlane_push: openlane_gen prepare
ifeq ($(OS), Windows)
	@if exist "$(OPENLANE_DESIGN_DIR)" ( \
		echo "[INFO]: Pushing OpenLane files to $(OPENLANE_DESIGN_DIR)..."; \
		xcopy /E /I /Y "$(OPENLANE_SETUP_DIR)" "$(OPENLANE_DESIGN_DIR)" >nul; \
		echo "[INFO]: Push complete." \
	) else ( \
		echo "[ERROR]: OpenLane design folder does not exist: $(OPENLANE_DESIGN_DIR)"; \
		exit 1 \
	)
else
	@if [ -d "$(OPENLANE_DESIGN_DIR)" ]; then \
		echo "[INFO]: Pushing OpenLane files to $(OPENLANE_DESIGN_DIR)..."; \
		rsync -av --delete $(OPENLANE_SETUP_DIR)/ $(OPENLANE_DESIGN_DIR)/; \
		echo "[INFO]: Push complete."; \
	else \
		echo "[ERROR]: OpenLane design folder does not exist: $(OPENLANE_DESIGN_DIR)"; \
		exit 1; \
	fi
endif

# Clean OpenLane directory
openlane_clean:
ifeq ($(OS), Windows)
	@if exist "$(OPENLANE_SETUP_DIR)" ( \
		rmdir /s /q "$(OPENLANE_SETUP_DIR)" && echo [INFO]: Cleaned OpenLane environment. \
	) else ( \
		echo [INFO]: No OpenLane environment to clean. \
	)
else
	@rm -rf $(OPENLANE_SETUP_DIR)
	@echo "[INFO]: Cleaned OpenLane environment"
endif

# Assemble firmware
assemble:
ifeq ($(OS), Windows)
	@if not defined NAME ( \
		echo [ERROR]: Please specify NAME="name_in_firmware_dir" - Example: "make assemble NAME=bootloader" & \
		exit /b 1 \
	)
	@if exist "$(FIRMWARE_DIR)\$(NAME)" ( \
		if exist "$(FIRMWARE_DIR)\$(NAME)\$(NAME).s" ( \
			python $(ASSEMBLER_SCRIPT) "$(FIRMWARE_DIR)\$(NAME)\$(NAME).s" "$(FIRMWARE_DIR)\$(NAME)\$(NAME).hex" & \
			echo [INFO]: Assembling $(FIRMWARE_DIR)/$(NAME)/$(NAME).s with output at $(FIRMWARE_DIR)/$(NAME)/$(NAME).hex & \
			echo [INFO]: Assembly complete. \
		) else ( \
			echo [ERROR]: File $(FIRMWARE_DIR)/$(NAME)/$(NAME).s not found. & exit /b 1 \
		) \
	) else ( \
		echo [ERROR]: Firmware directory $(FIRMWARE_DIR)/$(NAME) not found. & exit /b 1 \
	)
else
	@if [ -z "$(NAME)" ]; then \
		echo "[ERROR]: Please specify NAME=<firmware_name>"; \
		exit 1; \
	fi
	@if [ -d "$(FIRMWARE_DIR)/$(NAME)" ]; then \
		S_FILE="$(FIRMWARE_DIR)/$(NAME)/$(NAME).s"; \
		H_FILE="$(FIRMWARE_DIR)/$(NAME)/$(NAME).hex"; \
		if [ -f "$$S_FILE" ] && [ -f "$$H_FILE" ]; then \
			echo "[INFO]: Assembling $$S_FILE with header $$H_FILE"; \
			python3 $(ASSEMBLER_SCRIPT) $$S_FILE $$H_FILE; \
			echo "[INFO]: Assembly complete."; \
		else \
			if [ ! -f "$$S_FILE" ]; then \
				echo "[ERROR]: File $$S_FILE not found."; \
			fi; \
			if [ ! -f "$$H_FILE" ]; then \
				echo "[ERROR]: File $$H_FILE not found."; \
			fi; \
			exit 1; \
		fi \
	else \
		echo "[ERROR]: Firmware directory $(FIRMWARE_DIR)/$(NAME) not found."; \
		exit 1; \
	fi
endif

# Build bitstream for programming
bitstream_build: bitstream_clean prepare
ifeq ($(OS), Windows)
	@if exist "$(MAIN_HEX)" ( \
		if exist "$(ISR_HEX)" ( \
			if not exist "output/programmer" mkdir "output/programmer" & \
			echo [INFO]: Building bitstream with main.hex and isr.hex & \
			python $(BITSTREAM_SCRIPT) "$(BITSTREAM_OUTPUT)" "$(MAIN_HEX)" "$(ISR_HEX)" & \
			echo [INFO]: Bitstream build completely with output $(BITSTREAM_OUTPUT) \
		) else ( \
			echo [ERROR]: File $(ISR_HEX) not found. & exit /b 1 \
		) \
	) else ( \
		echo [ERROR]: File $(MAIN_HEX) not found. & exit /b 1 \
	)
else
	@if [ -f "$(MAIN_HEX)" ]; then \
		if [ -f "$(ISR_HEX)" ]; then \
			mkdir -p $(PROGRAMMER_OUTPUT_DIR); \
			echo "[INFO]: Building bitstream with main.hex and isr.hex"; \
			python3 $(BITSTREAM_SCRIPT) "$(BITSTREAM_OUTPUT)" "$(MAIN_HEX)" "$(ISR_HEX)"; \
			echo "[INFO]: Bitstream build complete."; \
		else \
			echo "[ERROR]: File $(ISR_HEX) not found."; \
			exit 1; \
		fi \
	else \
		echo "[ERROR]: File $(MAIN_HEX) not found."; \
		exit 1; \
	fi
endif

# Upload bitstream to the device
bitstream_upload: bitstream_build
ifeq ($(OS), Windows)
	@echo [INFO]: Checking COM port...
	@if not defined COM ( \
		echo [ERROR]: Please specify COM port with COM="port_num" - Example: "make bitstream_upload COM=3" & \
		exit /b 1 \
	)
	@echo [INFO]: Uploading bitstream to device via COM$(COM)...
	@python $(UPLOAD_SCRIPT) $(COM)
else
	@if [ -z "$(COM)" ]; then \
		echo "[ERROR]: Please specify COM port with COM=<port_number>"; \
		exit 1; \
	fi
	@echo "[INFO]: Uploading bitstream to device via COM$(COM)..."
	@python3 $(UPLOAD_SCRIPT) $(COM)
endif

# Clean bitstream files in programmer directory
bitstream_clean:
ifeq ($(OS), Windows)
	@if exist "$(OUTPUT_DIR)\programmer" ( \
		rmdir /s /q "$(OUTPUT_DIR)\programmer" && echo [INFO]: Cleaned programmer directory. \
	) else ( \
		echo [INFO]: No programmer directory to clean. \
	)
else
	@rm -rf $(OUTPUT_DIR)/programmer
	@echo "[INFO]: Cleaned programmer directory"
endif
