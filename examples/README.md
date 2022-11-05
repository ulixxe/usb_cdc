# USB_CDC Examples

All the examples are built with both [Lattice iCEcube2](https://www.latticesemi.com/iCEcube2) and [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build) design flows.

* Lattice design flow
	* Open `examples/<board name>/iCEcube2/<example name>/usb_cdc_sbt.project` file with iCEcube2.
* OSS CAD Suite flow
	* inside `examples/<board name>/OSS_CAD_Suite` run `make all PROJ=<example name>`

Testbenches can be simulated with iverilog/GTKWave.
To run them, inside `examples/<board name>/OSS_CAD_Suite` run `make sim PROJ=<example name>`. Or run `make wave PROJ=<example name>` to show waveforms too.

The GTKWave console makes available a few commands (such as `top`, `out`, `phy_rx`, etc.) to show various waveforms inside the design.

## `bootloader`
The `bootloader` example implements an equivalent of the original TinyFPGA bootloader. It is fully compatible with the `tinyprog` programmer.

## `demo`
Purpose of `demo` example is to test reliability and speed of USB CDC data transmission.
These tests are executed with python script `examples/<board name>/python/demo/run.py`.

Here, RAM and ROM are instantiated to check USB IN/OUT transmissions.  
`demo` example allows to read and program TinyFPGA-BX FLASH memory too.

## `loopback`
This is an example with minimal logic outside USB_CDC to test its functionality.

A python script is provided to check it (`examples/<board name>/python/loopback/run.py`).

## `soc`
In `soc` example a FIFO interface is instantiated to allow USB_CDC interfacing to a cpu bus.

`fifo_if` module has a bus protocol similar to RAM. Data to be written to `fifo_if` is provided on the same rising edge of write address/control signals. Data to be read from `fifo_if` is available on following rising edge after read address/control signals.


