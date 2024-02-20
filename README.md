# USB\_CDC verilog module

USB\_CDC is a Verilog implementation of the Full Speed (12Mbit/s) USB communications device class (or USB CDC class). It implements the Abstract Control Model (ACM) subclass.

USB\_CDC can be configured through CHANNELS parameter to implement from 1 to a maximum of 7 CDC channels.

Windows 10 provides a built-in driver (Usbser.sys) for USB CDC devices.
A USB\_CDC device is automatically recognized by Windows 10 as a virtual COM port, and a serial port terminal application such as [CoolTerm](https://freeware.the-meiers.org/) can be used to communicate with it.

macOS and Linux provide built-in drivers for USB CDC ACM devices too.
On macOS, the virtual COM gets a name like `/dev/cu.usbmodem14601`, whereas, on Linux, it gets a name like `/dev/ttyACM0`. Linux requires that the user account belongs to the dialout group to grant permissions for virtual COM access.

The USB\_CDC idea was born from the awesome [Luke Valenty's TinyFPGA](https://github.com/tinyfpga/TinyFPGA-BX) board. TinyFPGA uses a ["bit-banged" USB port](https://github.com/tinyfpga/TinyFPGA-Bootloader) implemented in the FPGA fabric for communication with the host PC.
David Williams, with his [TinyFPGA-BX USB serial module](https://github.com/davidthings/tinyfpga_bx_usbserial), changed Luke's code to allow USB communication for FPGA designs.
David's code uses the same clock for both USB internal stuff and data interface with FPGA application designs.
Instead, USB\_CDC aims to use a different asynchronous clock to allow a lower clock frequency for FPGA application designs.

Furthermore, USB\_CDC was designed from scratch. This allowed to:

* keep FPGA resource utilization at the minimum and without the use of EBR memories.
* manage properly both IN and OUT data flows with USB ACK/NAK handshake without data loss.

## Applications
* USB communication interface for microcontrollers and soft cores. USB\_CDC takes little gate resources and no memories, leaving them for the CPU. See `soc` example.
* Bootloaders. See the `bootloader` example for completely replacing the original TinyFPGA bootloader with one fully compatible with the `tinyprog` programmer.
* Etc, it is up to your imagination.

## Block Diagram and Pinout

![](readme_files/usb_cdc.png)

### Clocks
* `clk_i`: clock with a frequency of 12MHz*BIT\_SAMPLES
* `app_clk_i`: asynchronous clock used if parameter `USE_APP_CLK = 1`

### Reset
* `rstn_i`: asynchronous reset, active low

### FIFO out (from the USB host)
* `out_data_o`: data (1 byte if CHANNELS=1, n bytes if CHANNELS=n)
* `out_valid_o`: valid control signal (1 bit if CHANNEL=1, n bits if CHANNELS=n)
* `out_ready_i`: ready control signal (1 bit if CHANNEL=1, n bits if CHANNELS=n)

### FIFO in (to the USB host)
* `in_data_i`: data (1 byte if CHANNELS=1, n bytes if CHANNELS=n)
* `in_valid_i`: valid control signal (1 bit if CHANNEL=1, n bits if CHANNELS=n)
* `in_ready_o`: ready control signal (1 bit if CHANNEL=1, n bits if CHANNELS=n)

### USB I/O buffers
* `dp_rx_i`: D+ input bit stream
* `dn_rx_i`: D- input bit stream
* `dp_tx_o`: D+ output bit stream
* `dn_tx_o`: D- output bit stream
* `tx_en_o`: D+/D- output enable
* `dp_up_o`: 1.5k&Omega; D+ pullup enable

### USB device status
* `frame_o`: last received USB frame number
* `configured_o`: 1 if USB device is in configured state, 0 otherwise

## FIFO interface
USB\_CDC provides a FIFO interface to transfer data to/from FPGA application. Both `in_*` and `out_*` channels use the same transmission protocol.

![](readme_files/fifo_timings.png)

Data is consumed on rising `app_clk` when both `valid` and `ready` signals are high (red up arrows on the picture). Tsetup and Thold depend on FPGA/ASIC technology.

The `valid` signal is high only when new data is available. After data is consumed and there is no new data available, the `valid` signal is asserted low.

![](readme_files/fifo_protocol.png)


## Verilog Configuration Parameters
USB\_CDC has few Verilog parameters that allow customizing some module features.

### VENDORID and PRODUCTID
VENDORID and PRODUCTID define USB vendor ID (VID) and product ID (PID).  
For TinyFPGA: VID=0x1D50 and PID=0x6130.  
For Fomu: VID=0x1209 and PID=0x5BF0.  
By default, they are not defined (VENDORID=0x0000 and PRODUCTID=0x0000).

### IN\_BULK\_MAXPACKETSIZE and OUT\_BULK\_MAXPACKETSIZE
IN\_BULK\_MAXPACKETSIZE and OUT\_BULK\_MAXPACKETSIZE define maximum bulk data payload sizes for IN and OUT bulk transactions. The allowable full-speed values are only 8, 16, 32, and 64 bytes. The default value for both is 8.

### CHANNELS
CHANNELS defines how many CDC channels to implement. It is possible to implement from a minimum of 1 (default) to a maximum of 7 channels.

### BIT\_SAMPLES
BIT\_SAMPLES defines the number of samples taken on USB dp/dn lines for each bit. Full Speed USB has a bit rate of 12MHz, so the `clk` clock has to be BIT\_SAMPLES times faster. For example, the default value of 4 needs a `clk` frequency of 48MHz (see the picture below). BIT\_SAMPLES has to be &ge; 4.

![](readme_files/bit_samples.png)

### USE\_APP\_CLK and APP\_CLK\_FREQ

USE\_APP\_CLK parameter configures if the FPGA application uses the same USB_CDC internal stuff clock (USE\_APP\_CLK = 0) or a different asynchronous one (USE\_APP\_CLK = 1). If  USE\_APP\_CLK = 0 then `app_clk` input is not used and can be connected to a constant value such as `1'b0`.

When USE\_APP\_CLK = 1, APP\_CLK\_FREQ parameter defines the `app_clk` frequency in MHz.


To improve data throughput for lower `app_clk` frequencies, APP\_CLK\_FREQ parameter selects one of two different approaches to synchronize data that cross the two clock domains:

* APP\_CLK\_FREQ &le; 12. FPGA application can exchange data at every 1 or 2 `app_clk` cycles.

* APP\_CLK\_FREQ > 12. FPGA application can exchange data at an average of 2\*2.5 `app_clk` cycles + 2\*2.5 `clk` cycles.


Overall, the USB Full-speed protocol caps data throughput to 1.5MB/s.
So, with freq(`clk`) &ge; 48MHz, data throughput is 1.5MB/s if freq(`app_clk`) > 1.5MHz, otherwise it is freq(`app_clk`) bytes.


## Examples
A few examples with complete implementation on both Fomu and TinyFPGA-BX are present in the `examples` directory. In addition, simulation testbenches are provided for each one.

## Logic Resource Utilization

The USB\_CDC code alone (with IN/OUT data in simple loopback configuration and all verilog parameters to default) shows the following logic resource utilization from iCEcube2:

```
Logic Resource Utilization:
---------------------------
    Total Logic Cells: 1158/7680
        Combinational Logic Cells: 734      out of   7680      9.55729%
        Sequential Logic Cells:    424      out of   7680      5.52083%
        Logic Tiles:               212      out of   960       22.0833%
    Registers: 
        Logic Registers:           424      out of   7680      5.52083%
        IO Registers:              0        out of   1280      0
    Block RAMs:                    0        out of   32        0%
    Warm Boots:                    0        out of   1         0%
    Pins:
        Input Pins:                1        out of   63        1.5873%
        Output Pins:               2        out of   63        3.1746%
        InOut Pins:                2        out of   63        3.1746%
    Global Buffers:                4        out of   8         50%
    PLLs:                          1        out of   1         100%
```

The clock timing summary is:

```
                   1::Clock Frequency Summary
 =====================================================================
Number of clocks: 1
Clock: clk_usb           | Frequency: 76.60 MHz  | Target: 48.01 MHz  |
```

## Directory Structure

```
.
├── README.md                            --> This file
├── usb_cdc                              --> USB_CDC verilog files
│   ├── bulk_endp.v
│   ├── ctrl_endp.v
│   ├── in_fifo.v
│   ├── out_fifo.v
│   ├── phy_rx.v
│   ├── phy_tx.v
│   ├── sie.v
│   └── usb_cdc.v
└── examples                             --> Example designs
    ├── Fomu
    │   :
    │
    └── TinyFPGA-BX
        ├── hdl
        │   ├── demo
        │   │   ├── demo_fpga.vhd        --> Top level (VHDL)
        │   │   ├── demo.v               --> Top level (verilog)
        │   │   :
        │   │
        │   └── loopback
        │       ├── loopback.v           --> Top level (verilog)
        │       :
        │
        ├── iCEcube2                     --> iCEcube2 projects
        │   ├── demo
        │   │   ├── usb_cdc_sbt.project  --> iCEcube2 project file
        │   │   :
        │   │
        │   └── loopback
        │       ├── usb_cdc_sbt.project  --> iCEcube2 project file
        │       :
        │
        ├── OSS_CAD_Suite                --> OSS CAD Suite projects
        │   ├── Makefile
        │   ├── input
        │   │   ├── demo
        │   │   │   :
        │   │   └── loopback
        │   │       :
        │   │
        │   └── output
        │       :
        │
        └── python                       --> test files
            └── demo
                ├── run.py
                :
```
