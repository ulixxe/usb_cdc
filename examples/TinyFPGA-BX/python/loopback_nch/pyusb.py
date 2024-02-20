import usb.core
import usb.control
import usb.util
import usb.backend.libusb1
import binascii


def b2verilog(data):
	return str(len(data)) + "'h" + binascii.hexlify(data).decode().upper()

backend = usb.backend.libusb1.get_backend(find_library=lambda x: "/opt/local/lib/libusb-1.0.dylib")
dev = usb.core.find(idVendor=0x1D50, idProduct=0x6130)
if dev is None:
    raise ValueError('Our device is not connected')

print(dev)
print()
print(b2verilog(usb.control.get_descriptor(dev, 0x400, usb.util.DESC_TYPE_DEVICE, 0)))
print()
print(b2verilog(usb.control.get_descriptor(dev, 0x400, usb.util.DESC_TYPE_CONFIG, 0)))
print()
print(b2verilog(usb.control.get_descriptor(dev, 0x400, usb.util.DESC_TYPE_STRING, 1)) + " --> " + usb.util.get_string(dev, 1))
print(b2verilog(usb.control.get_descriptor(dev, 0x400, usb.util.DESC_TYPE_STRING, 2)) + " --> " + usb.util.get_string(dev, 2))
print(b2verilog(usb.control.get_descriptor(dev, 0x400, usb.util.DESC_TYPE_STRING, 3)) + " --> " + usb.util.get_string(dev, 3))
print(b2verilog(usb.control.get_descriptor(dev, 0x400, usb.util.DESC_TYPE_STRING, 4)) + " --> " + usb.util.get_string(dev, 4))
print(b2verilog(usb.control.get_descriptor(dev, 0x400, usb.util.DESC_TYPE_STRING, 5)) + " --> " + usb.util.get_string(dev, 5))
print(b2verilog(usb.control.get_descriptor(dev, 0x400, usb.util.DESC_TYPE_STRING, 6)) + " --> " + usb.util.get_string(dev, 6))
print(b2verilog(usb.control.get_descriptor(dev, 0x400, usb.util.DESC_TYPE_STRING, 7)) + " --> " + usb.util.get_string(dev, 7))


