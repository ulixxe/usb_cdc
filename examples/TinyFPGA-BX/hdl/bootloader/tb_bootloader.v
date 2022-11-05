`timescale 1 ns/10 ps  // time-unit/precision
`define BIT_TIME (1000/12)
`define CLK_PER (1000/16)

module tb_bootloader ( );
`define USB_CDC_INST tb_bootloader.u_bootloader.u_usb_cdc

   localparam MAX_BITS = 128;
   localparam MAX_BYTES = (8*1024);
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

`include "usb_tasks.v"
`include "bootloader_tasks.v"

   `progress_bar(37)

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

   bootloader u_bootloader (.clk(clk),
                .led(led),
                .usb_p(usb_p),
                .usb_n(usb_n),
                .usb_pu(usb_pu),
                .sck(sck),
                .ss(csn),
                .sdo(mosi),
                .sdi(miso));

   localparam MEM_PATH = "../../common/hdl/flash/";

   wire       hold_n;
   wire       wp_n;

   assign hold_n = 1'b1;
   assign wp_n = 1'b1;

   AT25SF081 #(.CELL_DATA({MEM_PATH, "init_cell_data.hex"}),
               .CELL_DATA_SEC({MEM_PATH, "init_cell_data_sec.hex"}))
   u_flash (.SCLK(sck),
            .CS_N(csn),
            .SI(mosi),
            .HOLD_N(hold_n),
            .WP_N(wp_n),
            .SO(miso));

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

   reg [6:0]  address;
   reg [15:0] datain_toggle;
   reg [15:0] dataout_toggle;
   reg [8*MAX_BYTES-1:0] data;
   reg [7:0]             flash_init_data[0:1024*1024-1];
   integer               i;

   initial begin : u_host
      $readmemh({MEM_PATH, "init_cell_data.hex"}, flash_init_data);
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

      test = "TRASH DATA";
      test_data_out(address, ENDP_BULK,
                    {8'h02, 8'h03, 8'h04, 8'h05, 8'h06, 8'h07, 8'h08},
                    7, PID_ACK, OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, dataout_toggle);

      test = "NOP";
      test_data_out(address, ENDP_BULK,
                    {8'h01, 8'h00, 8'h00, 8'h00, 8'h00},
                    5, PID_ACK, OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, dataout_toggle);

      test = "WAKE";
      test_cmd(8'hAB, 'd0, 'd0,
               address, OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, dataout_toggle);
      #(20000/83*`BIT_TIME); // wait 20us

      test = "READ ID (1/2)";
      test_cmd(8'h9F, 'd0, 'd3,
               address, OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, dataout_toggle);

      test = "READ ID (2/2)";
      test_data_in(address, ENDP_BULK,
                   {8'h1F, 8'h85, 8'h01},
                   3, PID_ACK, IN_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, datain_toggle, ZLP);

      test = "READ @addr=0";
      test_read('d0,
                {8'h31, 8'hF2, 8'h38, 8'h61, 8'hE1, 8'h81, 8'h19, 8'hCA},
                8, address, IN_BULK_MAXPACKETSIZE, OUT_BULK_MAXPACKETSIZE,
                100000/83*`BIT_TIME, datain_toggle, dataout_toggle);

      test = "READ @addr=1000";
      test_read('d1000,
                {8'h68, 8'hFA, 8'h45, 8'hE3, 8'hCD, 8'h72, 8'h10, 8'h30},
                8, address, IN_BULK_MAXPACKETSIZE, OUT_BULK_MAXPACKETSIZE,
                100000/83*`BIT_TIME, datain_toggle, dataout_toggle);


      test = "Test END";
      #(100*`BIT_TIME);
      `report_end("All tests correctly executed!")
   end
endmodule
