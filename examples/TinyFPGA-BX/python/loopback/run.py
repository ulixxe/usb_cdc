import tinyfpga
import time
import os

#tinyfpga.boot()

ser = tinyfpga.open()

length = 1024
i = 10000
while i > 0:
    print(f"{i} ", end = "\r")
    RAM_DATA = os.urandom(length)
    ser.write(RAM_DATA)
    data = ser.read(length)
    if (data != RAM_DATA):
        print(f"\033[91mERROR: RAM data mismatch!\033[0m")
    i -= 1

time.sleep(1)
if (ser.inWaiting() != 0):
    print(f"\033[91mERROR: read buffer not empty!\033[0m")
