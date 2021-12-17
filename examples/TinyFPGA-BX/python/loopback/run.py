import tinyfpga
import binascii
import time
import os

#tinyfpga.boot()

ser = tinyfpga.open()

length = 1024
i = 10000
while i > 0:
    print(f"{str(i).rjust(6)} ", end = "\r")
    wr_data = os.urandom(length)
    ser.write(wr_data)
    rd_data = ser.read(length)
    if (rd_data != wr_data):
        print(f"\033[91m")
        print(f"ERROR: data mismatch!")
        print(f"  actual:\n{binascii.hexlify(rd_data)}")
        print(f"  expected:\n{binascii.hexlify(wr_data)}")
        print(f"\033[0m")
        i = 0
    i -= 1

time.sleep(1)
if (ser.inWaiting() != 0):
    print(f"\033[91m")
    print(f"ERROR: read buffer not empty!")
    print(f"{binascii.hexlify(ser.read(ser.inWaiting()))}")
    print(f"\033[0m")
