import serial.tools.list_ports

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

def ports():
	VID = 0x1D50
	PID = 0x6130
	device_list = serial.tools.list_ports.comports()
	port_list = []
	for device in device_list:
		if (device.vid != None or device.pid != None):
			if (device.vid == VID and device.pid == PID):
				port_list.append(device.device)
	return port_list


def boot():
	port_list = ports()
	if (len(port_list) > 0):
		for port in port_list:
			print(f"TinyFPGA is on {port}")
			ser = serial.Serial(port)
			ser.timeout = 1			#non-block read
			ser.write(b'\x00')
			ser.close()
	else:
		print(f"{bcolors.FAIL}TinyFPGA not found!{bcolors.ENDC}")

def open():
	port_list = ports()
	ser_list = []
	if (len(port_list) > 0):
		for port in port_list:
			ser = serial.Serial()
			ser.port = port
			ser.timeout = 1		#non-block read
			ser.write_timeout = 10	#timeout for write
			ser.open()
			ser_list.append(ser)
		return ser_list
	else:
		return []
