import tinyfpga
import binascii
import time
import os
import random

#tinyfpga.boot()

ser = tinyfpga.open()

def b2verilog(data):
	return str(len(data)) + "'h" + binascii.hexlify(data).decode().upper()

def run(ser, runs):
	i = runs
	max_length = 4*1024
	while i > 0:
		length = int(min(random.expovariate(6/max_length), random.randint(int(max_length/2), max_length)))
		print(f"{str(ser.name).rjust(20)}: {str(i).rjust(6)}: {str(length).rjust(6)} ", end = "\r")
		wr_data = os.urandom(length)
		ser.write(wr_data)
		rd_data = ser.read(length)
		if (rd_data != wr_data):
			print(f"\033[91m")
			print(f"ERROR: data mismatch!")
			print(f"  actual:\n{b2verilog(rd_data)}")
			print(f"  expected:\n{b2verilog(wr_data)}")
			print(f"\033[0m")
			break
		i -= 1

run(ser, 1000)

time.sleep(1)
if (ser.inWaiting() != 0):
	data = ser.read(ser.inWaiting())
	print(f"\033[91m")
	print(f"ERROR: read buffer not empty!")
	print(f"{b2verilog(data)}")
	print(f"\033[0m")
