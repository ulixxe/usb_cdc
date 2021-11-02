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
