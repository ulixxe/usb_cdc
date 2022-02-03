import fomu
import time
import os
import base64


ser = fomu.open()
fomu.wait(0, ser)
fomu.lfsr_write(0, ser)
fomu.lfsr_read(ser)

data = b'\x00\x01\x02\x03'
fomu.outdata(data, ser)
fomu.outdata(os.urandom(100000), ser)

fomu.indata(100000, ser)

ser.write(bytearray([0x31]*10))
print(ser.read(10))

ser.write(b'Hello World!' * 100)
print(ser.read(1200))

fomu.ram_read(1028, ser, 2)
fomu.rom_read(1028, ser, 1)

length = 1024
RAM_DATA = bytearray((base64.b64encode(os.urandom(length)).decode('utf-8')[0:length]).encode())
ser.write(RAM_DATA)
time.sleep(1)
ser.read(ser.inWaiting())
ser.write(b'\x00\x08' + (length-1).to_bytes(3, 'little'))
data = bytearray(length)
data = ser.read(length)
if (data != RAM_DATA):
    print(f"\033[91mERROR: RAM data mismatch!\033[0m")

time.sleep(1)
if (ser.inWaiting() != 0):
    print(f"\033[91mERROR: read buffer not empty!\033[0m")
