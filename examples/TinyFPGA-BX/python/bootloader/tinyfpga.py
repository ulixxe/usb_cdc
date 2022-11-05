import serial.tools.list_ports
import binascii
import time
import dump
import builtins

class bcolors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

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
		print(f"TinyFPGA is on {portValue}")
		ser = serial.Serial(portValue)
		ser.timeout = 1			#non-block read
		ser.write(b'\x00')
		ser.close()
	else:
		print(f"{bcolors.FAIL}TinyFPGA not found!{bcolors.ENDC}")

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

def cmd(opcode, wr_length, rd_length, ser):
	wr_total_length = wr_length + 1; # add opcode
	ser.write(b'\x01' + wr_total_length.to_bytes(2, 'little') + rd_length.to_bytes(2, 'little') + opcode)

def sleep(ser):
	cmd(b'\xB9', 0, 0, ser)

def wake(ser):
	cmd(b'\xAB', 0, 0, ser)

def write_enable(ser):
	cmd(b'\x06', 0, 0, ser)

def write_disable(ser):
	cmd(b'\x04', 0, 0, ser)

def wait_while_busy(ser):
	while int.from_bytes(read_status(ser), 'little') & 1:
		pass

def erase_4k(addr, ser):
	write_enable(ser)
	cmd(b'\x20', 3, 0, ser)
	ser.write(addr.to_bytes(3, 'big'))
	wait_while_busy(ser)

def read_id(ser, p=0):
	cmd(b'\x9F', 0, 3, ser)
	data = ser.read(3)
	if (len(data) < 3):
		print(f"{bcolors.FAIL}{3-len(data)} ID bytes are missing{bcolors.ENDC}")
	elif (p == 0):
		return data
	else:
		print(f"ID = {hex(int.from_bytes(data, 'little'))}")

def read_status(ser, p=0):
	cmd(b'\x05', 0, 1, ser)
	data = ser.read(1)
	if (len(data) < 1):
		print(f"{bcolors.FAIL}{1-len(data)} STATUS bytes are missing{bcolors.ENDC}")
	elif (p == 0):
		return data
	else:
		print(f"STATUS = {hex(int.from_bytes(data, 'little'))}")
 
def read_security_register(addr, ser, p=0):
	if (addr < 1 or addr > 3):
		print(f"{bcolors.FAIL}Address limited to 1-3 {bcolors.ENDC}")
		return
	length = 256
	i = 0
	data = bytearray(length)
	start = time.time()
	cmd(b'\x48', 4, length, ser)
	ser.write(addr.to_bytes(2, 'big') + b'\x00\x00')
	data = ser.read(length)
	end = time.time()
	if (p == 1):
		print(binascii.hexlify(data))
	elif (p == 2):
		print(dump.data_dump(data))
	if (len(data) < length):
		print(f"{bcolors.FAIL}{length-len(data)} bytes are missing{bcolors.ENDC}")
	elif (p == 0):
		return data
	elif (end != start):
		print(f"{bcolors.OKGREEN}OK! {length} bytes transferred in {round(end-start, 3)} sec ({round(length/1000/(end-start), 1)} kB/s){bcolors.ENDC}")
	else:
		print(f"{bcolors.OKGREEN}OK! {length} bytes transferred in {round(end-start, 3)} sec{bcolors.ENDC}")
 
def read_data(addr, length, ser, p=0):
	if (length > 2**24):
		length = 2**24
		print(f"{bcolors.WARNING}Data length limited to {length} bytes{bcolors.ENDC}")
	i = 0
	data = bytearray(length)
	start = time.time()
	while i < length:
		chunk_length = min(4096, length-i)
		chunk_addr = addr + i
		cmd(b'\x0B', 4, chunk_length, ser)
		ser.write(chunk_addr.to_bytes(3, 'big') + b'\x00')
		data[i:i+chunk_length] = ser.read(chunk_length)
		i = i + chunk_length
	end = time.time()
	if (p == 1):
		print(binascii.hexlify(data))
	elif (p == 2):
		print(dump.data_dump(data))
	if (len(data) < length):
		print(f"{bcolors.FAIL}{length-len(data)} bytes are missing{bcolors.ENDC}")
	elif (p == 0):
		return data
	elif (end != start):
		print(f"{bcolors.OKGREEN}OK! {length} bytes transferred in {round(end-start, 3)} sec ({round(length/1000/(end-start), 1)} kB/s){bcolors.ENDC}")
	else:
		print(f"{bcolors.OKGREEN}OK! {length} bytes transferred in {round(end-start, 3)} sec{bcolors.ENDC}")

def write_data(addr, data, ser):
	length = len(data)
	ustart = 0x28000
	uend = 0x90000
	if (addr < ustart or addr+length >= uend):
		print(f"{bcolors.FAIL}Data programming limited to {hex(ustart)}-{hex(uend)} {bcolors.ENDC}")
		return
	i = 0
	erased_addr = -1
	start = time.time()
	while i < length:
		if (int((addr+i)/(4*1024))*4*1024 != erased_addr):
			erase_4k(int((addr+i)/(4*1024))*4*1024, ser)
			erased_addr = int((addr+i)/(4*1024))*4*1024
		write_addr = addr + i
		write_length = min(256-write_addr%256, length-i)
		write_enable(ser)
		cmd(b'\x02', 3+write_length, 0, ser)
		ser.write(write_addr.to_bytes(3, 'big'))
		ser.write(data[i:i+write_length])
		wait_while_busy(ser)
		i = i + write_length
	end = time.time()
	time.sleep(0.5)
	if (end != start):
		print(f"{bcolors.OKGREEN}OK! {length} bytes transferred in {round(end-start, 3)} sec ({round(length/1000/(end-start), 1)} kB/s){bcolors.ENDC}")
	else:
		print(f"{bcolors.OKGREEN}OK! {length} bytes transferred in {round(end-start, 3)} sec{bcolors.ENDC}")

def slurp(filename):
	if filename.endswith('.bit') or filename.endswith('.bin'):
		with builtins.open(filename, "rb") as f:
			return f.read()
	elif filename.endswith('.hex'):
		with builtins.open(filename, "rb") as f:
			return bytes("".join(chr(int(i, 16)) for i in f.read().split()), encoding='utf-8')
	else:
		print(f"{bcolors.FAIL}Unknown bitstream extension {bcolors.ENDC}")
		return
