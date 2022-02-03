import tinyfpga
import time
import os
import base64
import dump

#tinyfpga.boot()

ser = tinyfpga.open()
tinyfpga.wait(0, ser)
tinyfpga.lfsr_write(0, ser)
tinyfpga.lfsr_read(ser)

#data = b'\x00\x01\x02\x03'
#tinyfpga.outdata(data, ser)
tinyfpga.outdata(os.urandom(100000), ser)

tinyfpga.indata(100000, ser)

#ser.write(bytearray([0x31]*10))
#print(ser.read(10))

#ser.write(b'Hello World!' * 100)
#print(ser.read(1200))

#tinyfpga.addr_write(0, ser)
#tinyfpga.ram_read(1028, ser, 2)

#tinyfpga.addr_write(0, ser)
#tinyfpga.rom_read(1028, ser, 1)

#length = 1024
#RAM_DATA = bytearray((base64.b64encode(os.urandom(length)).decode('utf-8')[0:length]).encode())

#tinyfpga.addr_write(0, ser)
#ser.write(RAM_DATA)
#time.sleep(1)
#ser.read(ser.inWaiting())

#tinyfpga.addr_write(0, ser)
#ser.write(b'\x00\x08' + (length-1).to_bytes(3, 'little'))
#data = bytearray(length)
#data = ser.read(length)
#if (data != RAM_DATA):
#    print(f"\033[91mERROR: RAM data mismatch!\033[0m")

#tinyfpga.flash_status_read(ser)
#tinyfpga.flash_clear_status(ser)

#tinyfpga.addr_write(0xFF000, ser)
#tinyfpga.flash_read(1024*4, ser, 2)

#data = os.urandom(1024*4+0)
#print(dump.data_dump(data))
#tinyfpga.addr_write(0xFF000, ser)
#tinyfpga.flash_write(data, ser)

#tinyfpga.flash_status_read(ser)

tinyfpga.addr_write(0xFF000, ser)
tinyfpga.flash_read(1024*4, ser, 2)

tinyfpga.flash_status_read(ser)

time.sleep(1)
if (ser.inWaiting() != 0):
    print(f"\033[91mERROR: read buffer not empty!\033[0m")
