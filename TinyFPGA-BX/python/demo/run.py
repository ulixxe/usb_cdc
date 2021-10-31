import tinyfpga
import os

#tinyfpga.boot()

ser = tinyfpga.open()
tinyfpga.wait(0, ser)
tinyfpga.lfsr_write(0, ser)
tinyfpga.lfsr_read(ser)

data = b'\x00\x01\x02\x03'
tinyfpga.outdata(data, ser)
tinyfpga.outdata(os.urandom(100000), ser)

tinyfpga.indata(100000, ser)

ser.write(bytearray([0x31]*10))
print(ser.read(10))

ser.write(b'Hello World!' * 100)
print(ser.read(1200))

tinyfpga.ram_read(1028, ser, 2)
tinyfpga.rom_read(1028, ser, 1)

if (ser.inWaiting() != 0):
    print("ERROR: read buffer not empty!")
