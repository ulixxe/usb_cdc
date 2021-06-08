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
ser.read(ser.inWaiting())

tinyfpga.rom_read(1028, ser, 1)

ser.write(b'Hello World!' * 100)
ser.read(ser.inWaiting())

tinyfpga.ram_read(1028, ser, 2)
