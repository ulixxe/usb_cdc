import tinyfpga
import binascii
import time
import os
import random
import threading
import sys

#tinyfpga.boot()


def b2verilog(data):
	return str(len(data)) + "'h" + binascii.hexlify(data).decode().upper()

def run(ser, runs, lock):
	i = runs
	max_length = 4*1024
	while i > 0:
		length = int(min(random.expovariate(6/max_length), random.randint(int(max_length/2), max_length)))
		with lock:
			print(f"{str(ser.name).rjust(20)}: {str(i).rjust(6)}: {str(length).rjust(6)} ", end = "\r")
			sys.stdout.flush()
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

def main():
	ser_list = tinyfpga.open()
	lock = threading.Lock()
	print("Number of CDC channels:", len(ser_list))
	threads = []

	for ser in ser_list:
		thread = threading.Thread(target=run, args=(ser, 1000, lock))
		threads.append(thread)
	for thread in threads:
		thread.start()
	for thread in threads:
		thread.join()

	time.sleep(1)
	for ser in ser_list:
		if (ser.inWaiting() != 0):
			data = ser.read(ser.inWaiting())
			print(f"\033[91m")
			print(f"ERROR: read buffer not empty!")
			print(f"{b2verilog(data)}")
			print(f"\033[0m")
	return True

if __name__ == '__main__':
	main()
