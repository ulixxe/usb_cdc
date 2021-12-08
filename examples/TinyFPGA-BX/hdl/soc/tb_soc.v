`timescale 1 ns/10 ps  // time-unit/precision
`define BIT_TIME (1000/12)
`define CLK_PER (1000/16)

module tb_soc ( );
`define MAX_BITS 128
`define MAX_BYTES 128
`define MAX_STRING 128
`define USB_CDC_INST tb_soc.u_soc.u_usb_cdc
`include "usb_tasks.v"

   `progress_bar(37)

   reg clk;
   reg power_on;

   initial begin
      clk = 0;
   end

   always @(clk or power_on) begin
      if (power_on | clk)
        #(`CLK_PER/2) clk <= ~clk;
   end

   wire led;
   wire usb_p;
   wire usb_n;
   wire usb_pu;

   soc u_soc (.clk(clk),
              .led(led),
              .usb_p(usb_p),
              .usb_n(usb_n),
              .usb_pu(usb_pu));

   reg  dp_force;
   reg  dn_force;

   wire dp_sense;
   wire dn_sense;

   assign usb_p = dp_force;
   assign usb_n = dn_force;

   assign (pull1, highz0) usb_p = usb_pu; // 1.5kOhm device pull-up resistor
   //pullup (usb_p); // to speedup simulation don't wait for usb_pu

   //pulldown (weak0) dp_pd (usb_p), dn_pd (usb_n); // 15kOhm host pull-down resistors
   assign (highz1, weak0) usb_p = 1'b0; // to bypass verilator error on above pulldown
   assign (highz1, weak0) usb_n = 1'b0; // to bypass verilator error on above pulldown

   assign dp_sense = usb_p;
   assign dn_sense = usb_n;

   reg [6:0] address;
   reg [15:0] datain_toggle;
   reg [15:0] dataout_toggle;
   reg [8*`MAX_STRING-1:0] test;
   reg                     device_fail;

   initial begin : u_host
      $timeformat(-6, 3, "us", 3);
      $dumpfile("tb.dump");
      $dumpvars;

      power_on = 1'b1;
      dp_force = 1'bZ;
      dn_force = 1'bZ;
      device_fail = 0;
      address = 'd0;
      dataout_toggle = 'd0;
      datain_toggle = 'd0;
      wait_idle(20000000/83*`BIT_TIME);
      #(10000/83*`BIT_TIME);
      
      test_usb(address, datain_toggle, dataout_toggle);

      test = "OUT BULK DATA";
      test_data_out(address, ENDP_BULK,
                    {8'h01, 8'h02, 8'h03, 8'h04, 8'h05, 8'h06, 8'h07},
                    7, 256, 256, PID_NAK, OUT_BULK_MAXPACKETSIZE, 300*`BIT_TIME, dataout_toggle);

      test = "IN BULK DATA";
      test_data_in(address, ENDP_BULK,
                   {8'h01, 8'h02, 8'h03, 8'h04, 8'h05, 8'h06, 8'h07},
                   7, 256, 256, PID_NAK, IN_BULK_MAXPACKETSIZE, 0, datain_toggle);

      test = "IN BULK DATA with NAK";
      test_data_in(address, ENDP_BULK,
                   {8'h01, 8'h02, 8'h03, 8'h04, 8'h05, 8'h06, 8'h07},
                   7, 256, 0, PID_NAK, IN_BULK_MAXPACKETSIZE, 0, datain_toggle);

      test = "OUT BULK DATA";
      test_data_out(address, ENDP_BULK,
                    {8'h11, 8'h12, 8'h13, 8'h14, 8'h15, 8'h16, 8'h17, 8'h18},
                    8, 256, 256, PID_NAK, OUT_BULK_MAXPACKETSIZE, 300*`BIT_TIME, dataout_toggle);

      test = "IN BULK DATA with ZLP";
      test_data_in(address, ENDP_BULK,
                   {8'h11, 8'h12, 8'h13, 8'h14, 8'h15, 8'h16, 8'h17, 8'h18},
                   8, 256, 256, PID_NAK, IN_BULK_MAXPACKETSIZE, 0, datain_toggle);

      test = "OUT BULK DATA";
      test_data_out(address, ENDP_BULK,
                    {8'h21, 8'h22, 8'h23, 8'h24, 8'h25, 8'h26, 8'h27, 8'h28,
                     "12345678"},
                    16, 256, 256, PID_NAK, OUT_BULK_MAXPACKETSIZE, 300*`BIT_TIME, dataout_toggle);

      test = "IN BULK DATA with ZLP";
      test_data_in(address, ENDP_BULK,
                   {8'h21, 8'h22, 8'h23, 8'h24, 8'h25, 8'h26, 8'h27, 8'h28,
                    "23456789"},
                   16, 256, 256, PID_NAK, IN_BULK_MAXPACKETSIZE, 300*`BIT_TIME, datain_toggle);

      test = "OUT BULK DATA";
      test_data_out(address, ENDP_BULK,
                    {"ABCDEFGH",
                     "QRSTUVWX",
                     "abcd"},
                    20, 256, 2, PID_NAK, OUT_BULK_MAXPACKETSIZE, 300*`BIT_TIME, dataout_toggle);

      test = "IN BULK DATA with ZLP";
      test_data_in(address, ENDP_BULK,
                   {"abcdefgh",
                    "qrstuvwx"},
                   16, 256, 256, PID_NAK, IN_BULK_MAXPACKETSIZE, 300*`BIT_TIME, datain_toggle);

      test = "Test END";
      #(100*`BIT_TIME);
      `assert_end("All tests correctly executed!");
   end
endmodule
