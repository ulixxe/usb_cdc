# USB_CDC Examples

All the examples are built with both [Lattice iCEcube2](https://www.latticesemi.com/iCEcube2) and [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build) design flows.

* Lattice design flow
	* Open `examples/TinyFPGA-BX/iCecube2/<example name>/usb_cdc_sbt.project` file with iCEcube2.
* OSS CAD Suite flow
	* inside `examples/TinyFPGA-BX/OSS_CAD_Suite` run `make all PROJ=<example name>`

## `demo`
Purpose of `demo` example is to test reliability and speed of USB CDC data transmission.
These tests are executed with python script `examples/TinyFPGA-BX/python/demo/run.py`.

Here, RAM and ROM are instantiated to check USB IN/OUT transmissions.

## `loopback`
This is an example with minimal logic outside USB_CDC to test its functionality.

A python script is provided to check it (`examples/TinyFPGA-BX/python/loopback/run.py`).

## `soc`
In `soc` example a FIFO interface is instantiated to allow USB_CDC interfacing to a cpu bus.

`fifo_if` module has a bus protocol similar to RAM. Data to be written to `fifo_if` is provided on the same rising edge of write control signals. Data to be read from `fifo_if` is available on following rising edge after read control signals.


