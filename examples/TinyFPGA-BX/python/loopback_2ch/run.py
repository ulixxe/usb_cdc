import tinyfpga
import binascii
import time
import os
import random

#tinyfpga.boot()

ser_list = tinyfpga.open()

def run(ser):
	i = 1000
	while i > 0:
		length = random.randint(900, 1024)
		print(f"{str(ser.name).rjust(20)}: {str(i).rjust(6)}: {str(length).rjust(6)} ", end = "\r")
		wr_data = os.urandom(length)
		ser.write(wr_data)
		time.sleep(0.01)
		rd_data = ser.read(length)
		if (rd_data != wr_data):
			print(f"\033[91m")
			print(f"ERROR: data mismatch!")
			print(f"  actual:\n{binascii.hexlify(rd_data)}")
			print(f"  expected:\n{binascii.hexlify(wr_data)}")
			print(f"\033[0m")
			i = 0
		i -= 1

for ser in ser_list:
	run(ser)

time.sleep(1)
for ser in ser_list:
	if (ser.inWaiting() != 0):
		print(f"\033[91m")
		print(f"ERROR: read buffer not empty!")
		print(f"{binascii.hexlify(ser.read(ser.inWaiting()))}")
		print(f"\033[0m")
