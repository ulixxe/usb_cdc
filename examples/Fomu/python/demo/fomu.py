import serial.tools.list_ports
import binascii
import time
import dump

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
	VID = 0x1209
	PID = 0x5BF0
	device_list = serial.tools.list_ports.comports()
	portValue = None
	for device in device_list:
		if (device.vid != None or device.pid != None):
			if (device.vid == VID and device.pid == PID):
				portValue = device.device
				break
	return portValue


def open():
	portValue = port()
	if (portValue != None):
		ser = serial.Serial()
		ser.port = portValue
		ser.timeout = 1		#non-block read
		ser.writeTimeout = 2	#timeout for write
		ser.open()
		return ser
	else:
		return None

def wait(cycles, ser):
	ser.write(b'\x00\x04' + cycles.to_bytes(1, 'little'))

def addr_write(value, ser):
	ser.write(b'\x00\x03' + value.to_bytes(3, 'little'))

def lfsr_write(value, ser):
	ser.write(b'\x00\x05' + value.to_bytes(3, 'little'))

def lfsr_read(ser):
	ser.write(b'\x00\x06')
	lfsr = ser.read(4)
	if (len(lfsr) < 4):
		print(f"{bcolors.FAIL}{4-len(lfsr)} LFSR bytes are missing{bcolors.ENDC}")
	else:
		print(f"LFSR = {hex(int.from_bytes(lfsr, 'little'))}")

def outdata(data, ser):
	length = len(data)
	if (length > 2**24):
		length = 2**24
		print(f"{bcolors.WARNING}Data length limited to {length} bytes{bcolors.ENDC}")
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
		print(f"{bcolors.FAIL}{4-len(crc)} CRC32 bytes are missing{bcolors.ENDC}")
	elif (int.from_bytes(crc, "little") != crc32):
		print(f"{bcolors.FAIL}CRC error: CRC32={hex(crc32)} should be {hex(int.from_bytes(crc, 'little'))}{bcolors.ENDC}")
	elif (end != start):
		print(f"{bcolors.OKGREEN}OK! {length} bytes transferred in {round(end-start, 3)} sec ({round(length/1000/(end-start), 1)} kB/s){bcolors.ENDC}")
	else:
		print(f"{bcolors.OKGREEN}OK! {length} bytes transferred in {round(end-start, 3)} sec{bcolors.ENDC}")

def indata(length, ser, verbose=0):
	if (length > 2**24):
		length = 2**24
		print(f"{bcolors.WARNING}Data length limited to {length} bytes{bcolors.ENDC}")
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
		print(f"{bcolors.FAIL}{length+4-len(data)} bytes are missing{bcolors.ENDC}")
	elif (binascii.crc32(data) != 0x2144df1c):
		print(f"{bcolors.FAIL}CRC error: CRC32={hex(binascii.crc32(data))} should be {hex(0x2144df1c)}{bcolors.ENDC}")
	elif (end != start):
		print(f"{bcolors.OKGREEN}OK! {length} bytes transferred in {round(end-start, 3)} sec ({round(length/1000/(end-start), 1)} kB/s){bcolors.ENDC}")
	else:
		print(f"{bcolors.OKGREEN}OK! {length} bytes transferred in {round(end-start, 3)} sec{bcolors.ENDC}")

def rom_read(length, ser, verbose=0):
	if (length > 2**24):
		length = 2**24
		print(f"{bcolors.FAIL}Data length limited to {length} bytes{bcolors.ENDC}")
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
		print(f"{bcolors.FAIL}{length-len(data)} bytes are missing{bcolors.ENDC}")
	elif (end != start):
		print(f"{bcolors.OKGREEN}OK! {length} bytes transferred in {round(end-start, 3)} sec ({round(length/1000/(end-start), 1)} kB/s){bcolors.ENDC}")
	else:
		print(f"{bcolors.OKGREEN}OK! {length} bytes transferred in {round(end-start, 3)} sec{bcolors.ENDC}")
	ROM_DATA = binascii.unhexlify(
                b'6bff70f634535064f37b754c281f6af7b0a120a7ab23aa56c72b8196963ea96c' +
                b'42c6208931f9f7b53aea880ceaa9fe57862409104bbd818c5ab791bd6d8c7fd0' +
                b'938d70677681b3b17bb4099a1bb55763416d21257784e0f6ba6fe06dcd33d3e4' +
                b'6c63f929f5101ae60f9bdff957eeb6f3d19b13e01f03e5c985bf27626d2f558b' +
                b'5339f83366ac213060a7859d1047997bd7fe6e8bd5f5b4d82067c5d10710d50c' +
                b'cce9882d7e404f9a65ebb5712f5d03bf257f8a24ce2aa8d673d091b578e01ccf' +
                b'78a3b28fdca567fd7c1e494e9ca44e637ef41f171812f2b7985fde8af23c49d3' +
                b'bd0130768d69d1b8846aa10eb590891515b92e41cf67687c68a1e435a13cae4c' +
                b'6cbe32214e032833284b4b0f9e4253064ce2e34ccc05e84bc46866fb66ce94f5' +
                b'4e9e80b9f68a5694d7a8e95ac923c45d174585ee74b9f1625f303d947e7d0083' +
                b'6012542f5f9565d47a2dd23a660cb63dfe174ec1140ca36c1e1c115bbcc85d55' +
                b'795e5e3532529b5bd7e4b0be2c930b5d20fddd61efa6d5a6452ee6b9473e9782' +
                b'd33e686024d740d938cdfaa83614cf5874afd74e6d474305c36ea67365aa055c' +
                b'7b1e5a36cb9cb1ce2dc5d30b73108695d7cdab78f82d9ee0d4e99f5ed63f7e0e' +
                b'cb0489ad133571d7602e91dd427cbee344ec765bfd9dbda31e7f3790ccc81dc9' +
                b'0524d711421de9a4a337666d52ab2ac6faa7534177484e1d45dd0302cdc3a5d7' +
                b'3a008cce24134bb43d20668b32db2ac484dcc6045d9c329c232a11f70c7ba828' +
                b'45b708e0ca1d099e0363ef0ea669c7f91fd820ad6877cae9601b6612810644bc' +
                b'7d7acdd432e5089edcc656e4d4652fe267f0f3a00ba7c1dca9cd81c34c403ea0' +
                b'669c468bce8dcf2fd5f62c5ccd2644a4aad1c2352380224e77b1d420a81c0904' +
                b'ab613df7c993e0caf52eae42e6993dcf32d9dd1c43c14d6e0a00a1149e77dfdf' +
                b'b3f3875971ded0a8cd7d3367df3ad14cd8106ca0f311a3cbfec9b7d14ce9c743' +
                b'b47f3fdf0ff66d6d06ad88b97fe20c9a9d4cc152ec2a8ad8500637db1c307c34' +
                b'4d16cb0a455f52b0643eaabe009b386aa5cc0e7531f1436d5295ec3c3b7fb92e' +
                b'b0a6e7692b57aef6ad0f03e84da205e9ac820e933446500d228009e4e51bbd70' +
                b'1716ea292b49bd364ea173086eac84f0b0d87e2f9bd09b3caa07867fa09c2ff6' +
                b'4b95f3bff0de68242a3c41ff2f441e9bc76b6fefd3f9812e12a332c856f0d2cc' +
                b'9944dab39bdf44376e54af9ab67c80a903a1a9c8a84bbf5236084cdf748e508d' +
                b'6de345cb3fe6e73af7188fa1a1e3e0a726040d16f005254ca78113dbe9aa9119' +
                b'c16de7b49c521524b294c2112aff4f4990b5376173290167d0100627f6352201' +
                b'92b6fd8b99387d6e8e946816f2b69e43d3af99076ec62c89522d895287813755' +
                b'84297cf338a4be852229f37400ac9d68df2dbb3b09f577b6a553d126db1d336d')
	if (data[0:1024] != ROM_DATA):
		print(f"{bcolors.FAIL}ERROR: ROM data mismatch!{bcolors.ENDC}")

def ram_read(length, ser, verbose=0):
	if (length > 2**24):
		length = 2**24
		print(f"{bcolors.WARNING}Data length limited to {length} bytes{bcolors.ENDC}")
	ser.write(b'\x00\x08' + (length-1).to_bytes(3, 'little'))
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
		print(f"{length-len(data)} bytes are missing")
	elif (end != start):
		print(f"{bcolors.OKGREEN}OK! {length} bytes transferred in {round(end-start, 3)} sec ({round(length/1000/(end-start), 1)} kB/s){bcolors.ENDC}")
	else:
		print(f"{bcolors.OKGREEN}OK! {length} bytes transferred in {round(end-start, 3)} sec{bcolors.ENDC}")
