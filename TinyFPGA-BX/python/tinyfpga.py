import serial.tools.list_ports
import binascii
import time
import dump

def port():
	VID = 0x1D50
	PID = 0x6130
	device_list = serial.tools.list_ports.comports()
	portValue = None
	for device in device_list:
		if (device.vid != None or device.pid != None):
			if (device.vid == VID and device.pid == PID):
					portValue = device.device
					break
	return portValue


def boot():
	portValue = port()
	if (portValue != None):
		print("TinyFPGA is on " + portValue)
		ser = serial.Serial(portValue)
		ser.timeout = 1			#non-block read
		ser.write(b'\x00')
		ser.close()
	else:
		print("TinyFPGA not found!")

def open():
	portValue = port()
	if (portValue != None):
		ser = serial.Serial()
		ser.port = portValue
		ser.timeout = 1			#non-block read
		ser.writeTimeout = 2	#timeout for write
		ser.open()
		return ser
	else:
		return None

def wait(cycles, ser):
	ser.write(b'\x00\x03' + cycles.to_bytes(1, 'little'))

def lfsr_write(value, ser):
	ser.write(b'\x00\x04' + value.to_bytes(3, 'little'))

def lfsr_read(ser):
	ser.write(b'\x00\x05')
	lfsr = ser.read(4)
	if (len(lfsr) < 4):
		print(4-len(lfsr), "LFSR bytes are missing")
	else:
		print("LFSR =", hex(int.from_bytes(lfsr, "little")))

def outdata(data, ser):
	length = len(data)
	if (length > 2**24):
		length = 2**24
		print("Data length limited to", length, "bytes")
	ser.write(b'\x00\x02' + (length-1).to_bytes(3, 'little'))
	i = 0
	start = time.time()
	while i < length:
		j = min(i+4096, length)
		ser.write(data[i:j])
		i = j
	end = time.time()
	time.sleep(0.5)
	crc = ser.read(4)
	crc32 = binascii.crc32(data[0:length])
	if (len(crc) < 4):
		print(4-len(crc), "CRC32 bytes are missing")
	elif (int.from_bytes(crc, "little") != crc32):
		print("CRC error: CRC32=", hex(crc32), "should be", hex(int.from_bytes(crc, "little")))
	elif (end != start):
		print("OK!", length, "bytes transferred in", round(end-start, 3), "sec (", round(length/1000/(end-start), 1), "kB/s)")
	else:
		print("OK!", length, "bytes transferred in", round(end-start, 3), "sec")

def indata(length, ser, verbose=0):
	if (length > 2**24):
		length = 2**24
		print("Data length limited to", length, "bytes")
	ser.write(b'\x00\x01' + (length-1).to_bytes(3, 'little'))
	i = 0
	data = bytearray(length+4)
	start = time.time()
	while i < length+4:
		j = min(i+4096, length+4)
		data[i:j] = ser.read(j-i)
		i = j
	end = time.time()
	if (verbose == 1):
		print(binascii.hexlify(data))
	elif (verbose == 2):
		print(dump.data_dump(data))
	if (len(data) < length+4):
		print(length+4-len(data), "bytes are missing")
	elif (binascii.crc32(data) != 0x2144df1c):
		print("CRC error: CRC32=", hex(binascii.crc32(data)), "should be", hex(0x2144df1c))
	elif (end != start):
		print("OK!", length, "bytes transferred in", round(end-start, 3), "sec (", round(length/1000/(end-start), 1), "kB/s)")
	else:
		print("OK!", length, "bytes transferred in", round(end-start, 3), "sec")

def rom_read(length, ser, verbose=0):
	if (length > 2**24):
		length = 2**24
		print("Data length limited to", length, "bytes")
	ser.write(b'\x00\x06' + (length-1).to_bytes(3, 'little'))
	i = 0
	data = bytearray(length)
	start = time.time()
	while i < length:
		j = min(i+4096, length)
		data[i:j] = ser.read(j-i)
		i = j
	end = time.time()
	if (verbose == 1):
		print(binascii.hexlify(data))
	elif (verbose == 2):
		print(dump.data_dump(data))
	if (len(data) < length):
		print(length-len(data), "bytes are missing")
	elif (end != start):
		print("OK!", length, "bytes transferred in", round(end-start, 3), "sec (", round(length/1000/(end-start), 1), "kB/s)")
	else:
		print("OK!", length, "bytes transferred in", round(end-start, 3), "sec")

def ram_read(length, ser, verbose=0):
	if (length > 2**24):
		length = 2**24
		print("Data length limited to", length, "bytes")
	ser.write(b'\x00\x07' + (length-1).to_bytes(3, 'little'))
	i = 0
	data = bytearray(length)
	start = time.time()
	while i < length:
		j = min(i+4096, length)
		data[i:j] = ser.read(j-i)
		i = j
	end = time.time()
	if (verbose == 1):
		print(binascii.hexlify(data))
	elif (verbose == 2):
		print(dump.data_dump(data))
	if (len(data) < length):
		print(length-len(data), "bytes are missing")
	elif (end != start):
		print("OK!", length, "bytes transferred in", round(end-start, 3), "sec (", round(length/1000/(end-start), 1), "kB/s)")
	else:
		print("OK!", length, "bytes transferred in", round(end-start, 3), "sec")
