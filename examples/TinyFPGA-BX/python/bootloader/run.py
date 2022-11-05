import tinyfpga
import time
import os
import base64
import dump
import filecmp

#tinyfpga.boot()

ser = tinyfpga.open()
tinyfpga.wake(ser)

with open("out.bin", "wb") as binary_file:
	binary_file.write(bytes(tinyfpga.read_data(0xA0, 135100, ser)))

#with open("out.bin", "wb") as binary_file:
#	binary_file.write(bytes(tinyfpga.read_data(0x28000, 135100, ser)))

#with open("out.bin", "wb") as binary_file:
#	binary_file.write(bytes(tinyfpga.read_data(0x0, 298940, ser)))

if (filecmp.cmp("out.bin", "./bootloader-1.0.1.bin")):
	print(f"\033[94mOK: data is correct!\033[0m")
else:
	print(f"\033[91mERROR: file missmatch!\033[0m")

#tinyfpga.write_data(0x28000, tinyfpga.slurp("../../OSS_CAD_Suite/output/bootloader/bootloader.bin"), ser)
#tinyfpga.write_data(0x0, tinyfpga.slurp("../../OSS_CAD_Suite/output/bootloader/fw_bootloader.bin"), ser)

#tinyfpga.read_data(0x28000, 8*1024, ser, 2)
tinyfpga.read_security_register(1, ser, 2)
tinyfpga.read_security_register(2, ser, 2)

#tinyfpga.write_data(0x70FFF, tinyfpga.slurp("out.hex"), ser)


tinyfpga.sleep(ser)

time.sleep(1)
if (ser.inWaiting() != 0):
	print(f"\033[91mERROR: read buffer not empty!\033[0m")
