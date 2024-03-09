`timescale 1 ns/10 ps  // time-unit/precision
`define BIT_TIME (1000/12)
`define CLK_PER (1000/16)

module tb_loopback_7ch ( );
`define USB_CDC_INST tb_loopback_7ch.u_loopback_7ch.u_usb_cdc

   localparam MAX_BITS = 128;
   localparam MAX_BYTES = 512;
   localparam MAX_STRING = 128;

   reg        dp_force;
   reg        dn_force;
   reg        power_on;
   reg [8*MAX_STRING-1:0] test;

   wire                   dp_sense;
   wire                   dn_sense;

   integer                errors;
   integer                warnings;

   localparam             IN_BULK_MAXPACKETSIZE = 'd8;
   localparam             OUT_BULK_MAXPACKETSIZE = 'd8;
   localparam             VENDORID = 16'h1D50;
   localparam             PRODUCTID = 16'h6130;

`include "usb_test_7ch.v"

   `progress_bar(test, 38)

   reg                    clk;

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

   loopback_7ch u_loopback_7ch (.clk(clk),
                                .led(led),
                                .usb_p(usb_p),
                                .usb_n(usb_n),
                                .usb_pu(usb_pu));

   assign usb_p = dp_force;
   assign usb_n = dn_force;

   assign (pull1, highz0) usb_p = usb_pu; // 1.5kOhm device pull-up resistor
   //pullup (usb_p); // to speedup simulation don't wait for usb_pu

   //pulldown (weak0) dp_pd (usb_p), dn_pd (usb_n); // 15kOhm host pull-down resistors
   assign (highz1, weak0) usb_p = 1'b0; // to bypass verilator error on above pulldown
   assign (highz1, weak0) usb_n = 1'b0; // to bypass verilator error on above pulldown

   assign dp_sense = usb_p;
   assign dn_sense = usb_n;

   usb_monitor #(.MAX_BITS(MAX_BITS),
                 .MAX_BYTES(MAX_BYTES))
   u_usb_monitor (.usb_dp_i(dp_sense),
                  .usb_dn_i(dn_sense));

   reg [6:0] address;
   reg [15:0] datain_toggle;
   reg [15:0] dataout_toggle;

   initial begin : u_host
      $timeformat(-6, 3, "us", 3);
      $dumpfile("tb.dump");
      $dumpvars;

      power_on = 1'b1;
      dp_force = 1'bZ;
      dn_force = 1'bZ;
      errors = 0;
      warnings = 0;
      address = 'd0;
      dataout_toggle = 'd0;
      datain_toggle = 'd0;
      wait_idle(20000000/83*`BIT_TIME);
      #(100000/83*`BIT_TIME);

      test_usb(address, datain_toggle, dataout_toggle);

      test = "OUT 1 BULK DATA";
      test_data_out(address, ENDP_BULK1,
                    {8'h01, 8'h02, 8'h03, 8'h04, 8'h05, 8'h06, 8'h07},
                    7, PID_ACK, OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, dataout_toggle);

      test = "OUT 2 BULK DATA";
      test_data_out(address, ENDP_BULK2,
                    {8'h81, 8'h82, 8'h83, 8'h84, 8'h85, 8'h86, 8'h87},
                    7, PID_ACK, OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, dataout_toggle);

      test = "OUT 3 BULK DATA";
      test_data_out(address, ENDP_BULK3,
                    {8'h91, 8'h92, 8'h93, 8'h94, 8'h95, 8'h96, 8'h97},
                    7, PID_ACK, OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, dataout_toggle);

      test = "OUT 4 BULK DATA";
      test_data_out(address, ENDP_BULK4,
                    {8'hA1, 8'hA2, 8'hA3, 8'hA4, 8'hA5, 8'hA6, 8'hA7},
                    7, PID_ACK, OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, dataout_toggle);

      test = "OUT 5 BULK DATA";
      test_data_out(address, ENDP_BULK5,
                    {8'hB1, 8'hB2, 8'hB3, 8'hB4, 8'hB5, 8'hB6, 8'hB7},
                    7, PID_ACK, OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, dataout_toggle);

      test = "OUT 6 BULK DATA";
      test_data_out(address, ENDP_BULK6,
                    {8'hC1, 8'hC2, 8'hC3, 8'hC4, 8'hC5, 8'hC6, 8'hC7},
                    7, PID_ACK, OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, dataout_toggle);

      test = "OUT 7 BULK DATA";
      test_data_out(address, ENDP_BULK7,
                    {8'hD1, 8'hD2, 8'hD3, 8'hD4, 8'hD5, 8'hD6, 8'hD7},
                    7, PID_ACK, OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, dataout_toggle);

      test = "IN 1 BULK DATA";
      test_data_in(address, ENDP_BULK1,
                   {8'h01, 8'h02, 8'h03, 8'h04, 8'h05, 8'h06, 8'h07},
                   7, PID_ACK, IN_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, datain_toggle, ZLP);

      test = "IN 2 BULK DATA";
      test_data_in(address, ENDP_BULK2,
                   {8'h81, 8'h82, 8'h83, 8'h84, 8'h85, 8'h86, 8'h87},
                   7, PID_ACK, IN_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, datain_toggle, ZLP);

      test = "IN 3 BULK DATA";
      test_data_in(address, ENDP_BULK3,
                   {8'h91, 8'h92, 8'h93, 8'h94, 8'h95, 8'h96, 8'h97},
                   7, PID_ACK, IN_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, datain_toggle, ZLP);

      test = "IN 4 BULK DATA";
      test_data_in(address, ENDP_BULK4,
                   {8'hA1, 8'hA2, 8'hA3, 8'hA4, 8'hA5, 8'hA6, 8'hA7},
                   7, PID_ACK, IN_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, datain_toggle, ZLP);

      test = "IN 5 BULK DATA";
      test_data_in(address, ENDP_BULK5,
                   {8'hB1, 8'hB2, 8'hB3, 8'hB4, 8'hB5, 8'hB6, 8'hB7},
                   7, PID_ACK, IN_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, datain_toggle, ZLP);

      test = "IN 6 BULK DATA";
      test_data_in(address, ENDP_BULK6,
                   {8'hC1, 8'hC2, 8'hC3, 8'hC4, 8'hC5, 8'hC6, 8'hC7},
                   7, PID_ACK, IN_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, datain_toggle, ZLP);

      test = "IN 7 BULK DATA";
      test_data_in(address, ENDP_BULK7,
                   {8'hD1, 8'hD2, 8'hD3, 8'hD4, 8'hD5, 8'hD6, 8'hD7},
                   7, PID_ACK, IN_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, datain_toggle, ZLP);

      test = "IN 1 BULK DATA with NAK";
      test_data_in(address, ENDP_BULK1,
                   {8'h01, 8'h02, 8'h03, 8'h04, 8'h05, 8'h06, 8'h07},
                   7, PID_NAK, IN_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, datain_toggle, ZLP);

      test = "OUT 1 BULK DATA";
      test_data_out(address, ENDP_BULK1,
                    {8'h11, 8'h12, 8'h13, 8'h14, 8'h15, 8'h16, 8'h17, 8'h18},
                    8, PID_ACK, OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, dataout_toggle);

      test = "IN 1 BULK DATA with ZLP";
      test_data_in(address, ENDP_BULK1,
                   {8'h11, 8'h12, 8'h13, 8'h14, 8'h15, 8'h16, 8'h17, 8'h18},
                   8, PID_ACK, IN_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, datain_toggle, ZLP);

      test = "OUT 1 BULK DATA";
      test_data_out(address, ENDP_BULK1,
                    {8'h21, 8'h22, 8'h23, 8'h24, 8'h25, 8'h26, 8'h27, 8'h28,
                     8'h31, 8'h32, 8'h33, 8'h34, 8'h35, 8'h36, 8'h37, 8'h38},
                    16, PID_ACK, OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, dataout_toggle);

      test = "IN 1 BULK DATA with ZLP";
      test_data_in(address, ENDP_BULK1,
                   {8'h21, 8'h22, 8'h23, 8'h24, 8'h25, 8'h26, 8'h27, 8'h28,
                    8'h31, 8'h32, 8'h33, 8'h34, 8'h35, 8'h36, 8'h37, 8'h38},
                   16, PID_ACK, IN_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, datain_toggle, ZLP);

      test = "OUT 1 BULK DATA";
      test_data_out(address, ENDP_BULK1,
                    {8'h41, 8'h42, 8'h43, 8'h44, 8'h45, 8'h46, 8'h47, 8'h48,
                     8'h51, 8'h52, 8'h53, 8'h54, 8'h55, 8'h56, 8'h57, 8'h58,
                     8'h61, 8'h62, 8'h63, 8'h64, 8'h65},
                    21, PID_NAK, OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, dataout_toggle);

      test = "IN 1 BULK DATA with ZLP";
      test_data_in(address, ENDP_BULK1,
                   {8'h41, 8'h42, 8'h43, 8'h44, 8'h45, 8'h46, 8'h47, 8'h48,
                    8'h51, 8'h52, 8'h53, 8'h54, 8'h55, 8'h56, 8'h57, 8'h58},
                   16, PID_ACK, IN_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, datain_toggle, ZLP);

      test = "OUT 1 BULK DATA (1/3)";
      test_data_out(address, ENDP_BULK1,
                    {8'h71, 8'h72},
                    2, PID_ACK, OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, dataout_toggle);

      test = "CLEAR_FEATURE on OUT endpoint 1 (reset data toggle)";
      test_setup_out(address, 8'h02, STD_REQ_CLEAR_FEATURE, 16'h0000, 16'h0001, 16'h0000,
                     8'd0, 'd0, PID_ACK);

      test = "OUT 1 BULK DATA (2/3) skipped due to data toggle mismatch";
      test_data_out(address, ENDP_BULK1,
                    {8'h73, 8'h74},
                    2, PID_ACK, OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, dataout_toggle);

      test = "OUT 1 BULK DATA (3/3)";
      test_data_out(address, ENDP_BULK1,
                    {8'h75, 8'h76},
                    2, PID_ACK, OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, dataout_toggle);

      test = "IN 1 BULK DATA";
      test_data_in(address, ENDP_BULK1,
                   {8'h71, 8'h72, 8'h75, 8'h76},
                   4, PID_ACK, IN_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, datain_toggle, ZLP);

      test = "Test END";
      #(100*`BIT_TIME);
      `report_end("All tests correctly executed!")
   end
endmodule
