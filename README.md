# USB\_CDC verilog module

USB\_CDC is a Verilog implementation of the Full Speed (12Mbit/s) USB communications device class (or USB CDC class). It implements the Abstract Control Model (ACM) subclass.

Windows 10 provides a built-in driver (Usbser.sys) for USB CDC devices.
A USB\_CDC device is automatically recognized by Windows 10 as a virtual COM port, and a serial port terminal application such as [CoolTerm](https://freeware.the-meiers.org/) can be used to communicate with it.

The USB\_CDC idea was born from the awesome [Luke Valenty's TinyFPGA](https://github.com/tinyfpga/TinyFPGA-BX) board. TinyFPGA uses a ["bit-banged" USB port](https://github.com/tinyfpga/TinyFPGA-Bootloader) implemented in FPGA itself for communication with the host PC.
David Williams, with his [TinyFPGA-BX USB serial module](https://github.com/davidthings/tinyfpga_bx_usbserial), changed Luke's code to allow USB communication for FPGA designs.
David's code uses the same clock for both USB internal stuff and data interface with FPGA designs.
Instead, USB\_CDC aims to use a different asynchronous clock to allow a lower frequency clock for FPGA designs.
Furthermore, USB\_CDC was designed from scratch to keep FPGA resource utilization at the minimum and without the use of EBR memories.

## Block Diagram

![](readme_files/usb_cdc.png)


## Verilog Configuration Parameters
USB\_CDC has few Verilog parameters that allow customizing some module features.

### VENDORID and PRODUCTID
VENDORID and PRODUCTID define USB vendor ID (VID) and product ID (PID). For TinyFPGA, these are 0x1D50 and 0x6130. By default, they are not defined (VENDORID=0x0000 and PRODUCTID=0x0000).

### IN\_BULK\_MAXPACKETSIZE and OUT\_BULK\_MAXPACKETSIZE
IN\_BULK\_MAXPACKETSIZE and OUT\_BULK\_MAXPACKETSIZE define maximum bulk data payload sizes for IN and OUT bulk transactions. The allowable full-speed values are only 8, 16, 32, and 64 bytes. The default value for both is 8.

### BIT\_SAMPLES
BIT\_SAMPLES defines the number of samples taken on USB dp/dn lines for each bit. Full Speed USB has a bit rate of 12MHz, so the `clk` clock has to be BIT\_SAMPLES times faster. For example, the default value of 4 needs a `clk` frequency of 48MHz (see the picture below).

![](readme_files/bit_samples.png)

### USE\_APP\_CLK and APP\_CLK\_RATIO
`app_clk` is the FPGA design clock. It can be the same as USB internal stuff (USE\_APP\_CLK = 0) or can be a different asynchronous one (USE\_APP\_CLK = 1). If `app_clk` is asynchronous with `clk`, then for proper synchronization, it must have a frequency less or equal to CLK<sub>freq</sub>/4 (APP\_CLK\_RATIO &ge; 4).
If APP\_CLK\_RATIO is greater than or equal to 8, then USB data is exchanged with FPGA design at each `app_clk` cycle. Otherwise, if 4 &le; APP\_CLK\_RATIO &lt; 8, then USB data is exchanged every 2 `app_clk` cycles.
 
## Logic Resource Utilization

The USB\_CDC code alone (with IN/OUT data in simple loopback configuration and default verilog parameters) shows the following logic resource utilization from iCecube2:

```
Logic Resource Utilization:
---------------------------
    Total Logic Cells: 1125/7680
        Combinational Logic Cells: 742      out of   7680      9.66146%
        Sequential Logic Cells:    383      out of   7680      4.98698%
        Logic Tiles:               205      out of   960       21.3542%
    Registers: 
        Logic Registers:           383      out of   7680      4.98698%
        IO Registers:              0        out of   1280      0
    Block RAMs:                    0        out of   32        0%
    Warm Boots:                    0        out of   1         0%
    Pins:
        Input Pins:                1        out of   63        1.5873%
        Output Pins:               2        out of   63        3.1746%
        InOut Pins:                2        out of   63        3.1746%
    Global Buffers:                7        out of   8         87.5%
    PLLs:                          1        out of   1         100%
```

The clock timing summary is:

```
                   1::Clock Frequency Summary
 =====================================================================
Number of clocks: 4
Clock: clk_ext           | Frequency: 424.30 MHz  | Target: 16.13 MHz  | 
Clock: clk_1mhz          | Frequency: 143.96 MHz  | Target: 1.01 MHz   | 
Clock: clk               | Frequency: 76.60 MHz   | Target: 50.00 MHz  | 
Clock: u_pll/PLLOUTCORE  | N/A                    | Target: 48.39 MHz  |
```

## Directory Structure

```
.
├── README.md                      --> This file
├── usb_cdc                        --> USB_CDC verilog files
│   ├── bulk_endp.v
│   ├── ctrl_endp.v
│   ├── phy_rx.v
│   ├── phy_tx.v
│   ├── sie.v
│   └── usb_cdc.v
└── TinyFPGA-BX                    --> Example design
    ├── hdl
    │   ├── TinyFPGA_BX_fpga.vhd   --> Top level
    │   ├── app.v
    │   ├── prescaler_rtl.vhd
    │   ├── ram_wrapper.v
    │   └── rom_wrapper.v
    ├── iCecube2                   --> iCecube2 project
    │   ├── constraints
    │   │   ├── clk.sdc
    │   │   └── pins.pcf
    │   ├── usb_cdc_Implmnt
    │   │   └── sbt
    │   │       └── outputs
    │   │           ├── TinyFPGA_BX_sbt.rpt
    │   │           └── bitmap
    │   │               └── TinyFPGA_BX_bitmap.bin
    │   ├── usb_cdc_sbt.project    --> iCecube2 project file
    │   └── usb_cdc_syn.prj
    └── python                     --> USB CDC class test
        ├── dump.py
        ├── run.py
        └── tinyfpga.py 
```
