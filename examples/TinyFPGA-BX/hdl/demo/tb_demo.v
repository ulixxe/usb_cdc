`timescale 1 ns/10 ps  // time-unit/precision
`define BIT_TIME (1000/12)
`define CLK_PER (1000/16)

module tb_demo ( );
`define USB_CDC_INST tb_demo.u_demo.u_usb_cdc

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
`include "demo_tasks.v"

   `progress_bar(316)

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

   demo u_demo (.clk(clk),
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

      test = "OUT BULK DATA";
      test_data_out(address, ENDP_BULK,
                    {8'h01, 8'h02, 8'h03, 8'h04, 8'h05, 8'h06, 8'h07},
                    7, PID_ACK, OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, dataout_toggle);

      test = "IN BULK DATA";
      test_data_in(address, ENDP_BULK,
                   {8'h01, 8'h02, 8'h03, 8'h04, 8'h05, 8'h06, 8'h07},
                   7, PID_ACK, IN_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, datain_toggle, ZLP);

      test = "IN BULK DATA with NAK";
      test_data_in(address, ENDP_BULK,
                   {8'h01, 8'h02, 8'h03, 8'h04, 8'h05, 8'h06, 8'h07},
                   7, PID_NAK, IN_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, datain_toggle, ZLP);

      test = "OUT BULK DATA";
      test_data_out(address, ENDP_BULK,
                    {8'h11, 8'h12, 8'h13, 8'h14, 8'h15, 8'h16, 8'h17, 8'h18},
                    8, PID_ACK, OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, dataout_toggle);

      test = "IN BULK DATA with ZLP";
      test_data_in(address, ENDP_BULK,
                   {8'h11, 8'h12, 8'h13, 8'h14, 8'h15, 8'h16, 8'h17, 8'h18},
                   8, PID_ACK, IN_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, datain_toggle, ZLP);

      test = "OUT BULK DATA";
      test_data_out(address, ENDP_BULK,
                    {8'h21, 8'h22, 8'h23, 8'h24, 8'h25, 8'h26, 8'h27, 8'h28,
                     8'h31, 8'h32, 8'h33, 8'h34, 8'h35, 8'h36, 8'h37, 8'h38},
                    16, PID_ACK, OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, dataout_toggle);

      test = "IN BULK DATA with ZLP";
      test_data_in(address, ENDP_BULK,
                   {8'h21, 8'h22, 8'h23, 8'h24, 8'h25, 8'h26, 8'h27, 8'h28,
                    8'h31, 8'h32, 8'h33, 8'h34, 8'h35, 8'h36, 8'h37, 8'h38},
                   16, PID_ACK, IN_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, datain_toggle, ZLP);

      test = "WAIT CMD";
      test_demo_cmd1(address, ENDP_BULK, WAIT_CMD, 8'd0,
                     OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, dataout_toggle);
      #(30*`BIT_TIME);
      `assert_error("WAIT write error", tb_demo.u_demo.u_app.wait_q, 8'd0)

      test = "OUT BULK DATA";
      test_data_out(address, ENDP_BULK,
                    {8'h41, 8'h42, 8'h43, 8'h44, 8'h45, 8'h46, 8'h47, 8'h48,
                     8'h51, 8'h52, 8'h53, 8'h54, 8'h55, 8'h56, 8'h57, 8'h58,
                     8'h61, 8'h62},
                    18, PID_NAK, OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, dataout_toggle);

      test = "IN BULK DATA with ZLP";
      test_data_in(address, ENDP_BULK,
                   {8'h41, 8'h42, 8'h43, 8'h44, 8'h45, 8'h46, 8'h47, 8'h48,
                    8'h51, 8'h52, 8'h53, 8'h54, 8'h55, 8'h56, 8'h57, 8'h58},
                   16, PID_ACK, IN_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, datain_toggle, ZLP);

      test = "ADDR CMD";
      test_demo_cmd3(address, ENDP_BULK, ADDR_CMD, 24'h000000,
                     OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, dataout_toggle);
      #(30*`BIT_TIME);
      `assert_error("ADDR write error", tb_demo.u_demo.u_app.mem_addr_q, 24'h000000)

      test = "ROM READ CMD";
      test_demo_cmd3(address, ENDP_BULK, ROM_READ_CMD, 1024-1,
                     OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, dataout_toggle);

      test = "ROM READ";
      test_data_in(address, ENDP_BULK,
                   ROM_DATA,
                   1024, PID_ACK, IN_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, datain_toggle, ZLP);

      test = "ADDR CMD";
      test_demo_cmd3(address, ENDP_BULK, ADDR_CMD, 24'h000000,
                     OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, dataout_toggle);
      #(30*`BIT_TIME);
      `assert_error("ADDR write error", tb_demo.u_demo.u_app.mem_addr_q, 24'h000000)

      test = "RAM READ CMD";
      test_demo_cmd3(address, ENDP_BULK, RAM_READ_CMD, 55-1,
                     OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, dataout_toggle);

      test = "RAM READ";
      test_data_in(address, ENDP_BULK,
                   {8'h01, 8'h02, 8'h03, 8'h04, 8'h05, 8'h06, 8'h07,
                    8'h11, 8'h12, 8'h13, 8'h14, 8'h15, 8'h16, 8'h17, 8'h18,
                    8'h21, 8'h22, 8'h23, 8'h24, 8'h25, 8'h26, 8'h27, 8'h28,
                    8'h31, 8'h32, 8'h33, 8'h34, 8'h35, 8'h36, 8'h37, 8'h38,
                    8'h41, 8'h42, 8'h43, 8'h44, 8'h45, 8'h46, 8'h47, 8'h48,
                    8'h51, 8'h52, 8'h53, 8'h54, 8'h55, 8'h56, 8'h57, 8'h58,
                    RAM_DATA[8*(1024-47)-1 -:64]},
                   55, PID_ACK, IN_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, datain_toggle, ZLP);

      test = "LFSR WRITE CMD";
      test_demo_cmd3(address, ENDP_BULK, LFSR_WRITE_CMD, 24'h333881,
                     OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, dataout_toggle);
      #(30*`BIT_TIME);
      `assert_error("LFSR write error", tb_demo.u_demo.u_app.lfsr_q, 24'h333881)

      test = "IN CMD";
      test_demo_cmd3(address, ENDP_BULK, IN_CMD, 10-1,
                     OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, dataout_toggle);

      test = "IN";
      test_demo_in(address, ENDP_BULK, 10,
                   IN_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, datain_toggle);

      test = "OUT CMD";
      test_demo_cmd3(address, ENDP_BULK, OUT_CMD, 10-1,
                     OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, dataout_toggle);

      test = "OUT";
      test_demo_out(address, ENDP_BULK,
                    {8'h71, 8'h72, 8'h73, 8'h74, 8'h75, 8'h76, 8'h77, 8'h78,
                     8'h79, 8'h7A},
                    10, IN_BULK_MAXPACKETSIZE, OUT_BULK_MAXPACKETSIZE,
                    100000/83*`BIT_TIME, 0, datain_toggle, dataout_toggle);

      test = "ADDR CMD";
      test_demo_cmd3(address, ENDP_BULK, ADDR_CMD, 24'h04FFFD,
                     OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, dataout_toggle);
      #(30*`BIT_TIME);
      `assert_error("ADDR write error", tb_demo.u_demo.u_app.mem_addr_q, 24'h04FFFD)

      test = "FLASH READ CMD";
      test_demo_cmd3(address, ENDP_BULK, FLASH_READ_CMD, 10-1,
                     OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, dataout_toggle);

      for (i = 0; i<10; i = i+1)
        data[8*(10-i-1) +:8] = flash_init_data[24'h04FFFD+i];

      test = "FLASH READ";
      test_data_in(address, ENDP_BULK,
                   data,
                   10, PID_ACK, IN_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, datain_toggle, ZLP);

      test = "FLASH WRITE CMD";
      test_demo_cmd3(address, ENDP_BULK, FLASH_WRITE_CMD, 10-1,
                     OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, dataout_toggle);

      test = "FLASH WRITE";
      test_demo_out(address, ENDP_BULK,
                    {8'h81, 8'h82, 8'h83, 8'h84, 8'h85, 8'h86, 8'h87, 8'h88,
                     8'h89, 8'h8A},
                    10, IN_BULK_MAXPACKETSIZE, OUT_BULK_MAXPACKETSIZE,
                    100000000/83*`BIT_TIME, 1000000/83*`BIT_TIME, datain_toggle, dataout_toggle);

      test = "ADDR CMD";
      test_demo_cmd3(address, ENDP_BULK, ADDR_CMD, 24'h04FFFD,
                     OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, dataout_toggle);
      #(30*`BIT_TIME);
      `assert_error("ADDR write error", tb_demo.u_demo.u_app.mem_addr_q, 24'h04FFFD)

      test = "FLASH READ CMD";
      test_demo_cmd3(address, ENDP_BULK, FLASH_READ_CMD, 16-1,
                     OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, dataout_toggle);

      test = "FLASH READ";
      test_data_in(address, ENDP_BULK,
                   {data[8*(10-3) +:24],
                    8'h81, 8'h82, 8'h83, 8'h84, 8'h85, 8'h86, 8'h87, 8'h88,
                    8'h89, 8'h8A, 8'hFF, 8'hFF, 8'hFF},
                   16, PID_ACK, IN_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, datain_toggle, ZLP);

      test = "FLASH STATUS READ CMD";
      test_demo_cmd0(address, ENDP_BULK, FLASH_READ_STATUS_CMD,
                     OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, dataout_toggle);

      test = "FLASH STATUS READ";
      test_data_in(address, ENDP_BULK,
                   {8'h00, 8'h00, 8'h00, 8'h00},
                   4, PID_ACK, IN_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, datain_toggle, ZLP);

      test = "ADDR CMD";
      test_demo_cmd3(address, ENDP_BULK, ADDR_CMD, 24'h0FF000,
                     OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, dataout_toggle);
      #(30*`BIT_TIME);
      `assert_error("ADDR write error", tb_demo.u_demo.u_app.mem_addr_q, 24'h0FF000)

      test = "FLASH WRITE CMD";
      test_demo_cmd3(address, ENDP_BULK, FLASH_WRITE_CMD, 4*1024+1-1,
                     OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, dataout_toggle);

      test = "FLASH WRITE";
      test_data_out(address, ENDP_BULK,
                    'd0,
                    4*1024+1, PID_ACK, OUT_BULK_MAXPACKETSIZE,
                    100000000/83*`BIT_TIME, 10000/83*`BIT_TIME, dataout_toggle);
      test_data_in(address, ENDP_BULK,
                   'h11001CC7,
                   4, PID_ACK, IN_BULK_MAXPACKETSIZE,
                   100000000/83*`BIT_TIME, 0, datain_toggle, ZLP);

      test = "FLASH STATUS READ CMD";
      test_demo_cmd0(address, ENDP_BULK, FLASH_READ_STATUS_CMD,
                     OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, dataout_toggle);

      test = "FLASH STATUS READ";
      test_data_in(address, ENDP_BULK,
                   {8'h08, 8'h00, 8'h00, 8'h00},
                   4, PID_ACK, IN_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, datain_toggle, ZLP);

      test = "FLASH CLEAR STATUS CMD";
      test_demo_cmd0(address, ENDP_BULK, FLASH_CLEAR_STATUS_CMD,
                     OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, dataout_toggle);

      test = "FLASH STATUS READ CMD";
      test_demo_cmd0(address, ENDP_BULK, FLASH_READ_STATUS_CMD,
                     OUT_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, dataout_toggle);

      test = "FLASH STATUS READ";
      test_data_in(address, ENDP_BULK,
                   {8'h00, 8'h00, 8'h00, 8'h00},
                   4, PID_ACK, IN_BULK_MAXPACKETSIZE, 100000/83*`BIT_TIME, 0, datain_toggle, ZLP);


      test = "Test END";
      #(100*`BIT_TIME);
      `report_end("All tests correctly executed!")
   end
endmodule
