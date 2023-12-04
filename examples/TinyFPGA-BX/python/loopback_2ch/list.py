import serial.tools.list_ports

VID = 0x1D50
PID = 0x6130
device_list = [p for p in serial.tools.list_ports.comports() if p.vid == VID and p.pid == PID]
for device in device_list:
  print (f"Device: {device.device}")
  print (f"name: {device.name}")
  print (f"description: {device.description}")
  print (f"hwid: {device.hwid}")
  print (f"vid: {device.vid}")
  print (f"pid: {device.pid}")
  print (f"serial_number: {device.serial_number}")
  print (f"location: {device.location}")
  print (f"manufacturer: {device.manufacturer}")
  print (f"product: {device.product}")
  print (f"interface: {device.interface}")
  print ()
  
