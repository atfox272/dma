.PHONY: all pre_sim input_gen sim output_anal clean

all: clean pre_sim input_gen sim output_anal

pre_sim:
	if not exist env\src_mem.txt (type nul > env\src_mem.txt)
	if not exist env\dst_mem_0.txt (type nul > env\dst_mem_0.txt)
	if not exist env\dst_mem_1.txt (type nul > env\dst_mem_1.txt)
	if not exist env\dst_mem_0_format.txt (type nul > env\dst_mem_0_format.txt)
	if not exist env\dst_mem_1_format.txt (type nul > env\dst_mem_1_format.txt)

input_gen:
	python env/img2txt.py

sim:
	$(MAKE) -f tool_run

output_anal:
	python env/txt2img.py
	move env\output_channel_* .

clean:
	if exist env\src_mem.txt del /f env\src_mem.txt
	if exist env\dst_mem_0.txt del /f env\dst_mem_0.txt
	if exist env\dst_mem_1.txt del /f env\dst_mem_1.txt
	if exist env\dst_mem_0_format.txt del /f env\dst_mem_0_format.txt
	if exist env\dst_mem_1_format.txt del /f env\dst_mem_1_format.txt
	if exist env\dst_mem_0.png del /f env\dst_mem_0.png
	if exist env\dst_mem_1.png del /f env\dst_mem_1.png
	if exist output_channel_* del /f output_channel_*
