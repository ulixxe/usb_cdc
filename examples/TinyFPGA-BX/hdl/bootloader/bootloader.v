
module bootloader
  (
   input  clk, // 16MHz Clock
   output led, // User LED ON=1, OFF=0
   inout  usb_p, // USB+
   inout  usb_n, // USB-
   output usb_pu, // USB 1.5kOhm Pullup EN
   output sck,
   output ss,
   output sdo,
   input  sdi
   );

   localparam BIT_SAMPLES = 'd4;
   localparam [6:0] DIVF = 12*BIT_SAMPLES-1;

   wire             clk_pll;
   wire             lock;
   wire             dp_pu;
   wire             dp_rx;
   wire             dn_rx;
   wire             dp_tx;
   wire             dn_tx;
   wire             tx_en;
   wire [7:0]       out_data;
   wire             out_valid;
   wire             in_ready;
   wire [7:0]       in_data;
   wire             in_valid;
   wire             out_ready;
   wire             boot;
   wire [10:0]      frame;
   wire             configured;

   assign led = (configured) ? frame[9] : ~&frame[4:3];

   // if FEEDBACK_PATH = SIMPLE:
   // clk_freq = (ref_freq * (DIVF + 1)) / (2**DIVQ * (DIVR + 1));
   SB_PLL40_CORE #(.DIVR(4'd0),
                   .DIVF(DIVF),
                   .DIVQ(3'd4),
                   .FILTER_RANGE(3'b001),
                   .FEEDBACK_PATH("SIMPLE"),
                   .DELAY_ADJUSTMENT_MODE_FEEDBACK("FIXED"),
                   .FDA_FEEDBACK(4'b0000),
                   .DELAY_ADJUSTMENT_MODE_RELATIVE("FIXED"),
                   .FDA_RELATIVE(4'b0000),
                   .SHIFTREG_DIV_MODE(2'b00),
                   .PLLOUT_SELECT("GENCLK"),
                   .ENABLE_ICEGATE(1'b0))
   u_pll (.REFERENCECLK(clk), // 16MHz
          .PLLOUTCORE(),
          .PLLOUTGLOBAL(clk_pll), // 48MHz
          .EXTFEEDBACK(1'b0),
          .DYNAMICDELAY(8'd0),
          .LOCK(lock),
          .BYPASS(1'b0),
          .RESETB(1'b1),
          .SDI(1'b0),
          .SDO(),
          .SCLK(1'b0),
          .LATCHINPUTVALUE(1'b1));

   app u_app (.clk_i(clk),
              .rstn_i(lock),
              .out_data_i(out_data),
              .out_valid_i(out_valid),
              .in_ready_i(in_ready),
              .out_ready_o(out_ready),
              .in_data_o(in_data),
              .in_valid_o(in_valid),
              .heartbeat_i(configured & frame[0]),
              .boot_o(boot),
              .sck_o(sck),
              .csn_o(ss),
              .mosi_o(sdo),
              .miso_i(sdi));

   usb_cdc #(.VENDORID(16'h1D50),
             .PRODUCTID(16'h6130),
             .IN_BULK_MAXPACKETSIZE('d8),
             .OUT_BULK_MAXPACKETSIZE('d8),
             .BIT_SAMPLES(BIT_SAMPLES),
             .USE_APP_CLK(1),
             .APP_CLK_RATIO(BIT_SAMPLES*12/16))  // BIT_SAMPLES * 12MHz / 16MHz
   u_usb_cdc (.frame_o(frame),
              .configured_o(configured),
              .app_clk_i(clk),
              .clk_i(clk_pll),
              .rstn_i(lock),
              .out_ready_i(out_ready),
              .in_data_i(in_data),
              .in_valid_i(in_valid),
              .dp_rx_i(dp_rx),
              .dn_rx_i(dn_rx),
              .out_data_o(out_data),
              .out_valid_o(out_valid),
              .in_ready_o(in_ready),
              .dp_pu_o(dp_pu),
              .tx_en_o(tx_en),
              .dp_tx_o(dp_tx),
              .dn_tx_o(dn_tx));

   SB_WARMBOOT u_warmboot (.S1(1'b0),
                           .S0(1'b1),
                           .BOOT(boot));

   SB_IO #(.PIN_TYPE(6'b101001),
           .PULLUP(1'b0))
   u_usb_p (.PACKAGE_PIN(usb_p),
            .OUTPUT_ENABLE(tx_en),
            .D_OUT_0(dp_tx),
            .D_IN_0(dp_rx),
            .D_OUT_1(1'b0),
            .D_IN_1(),
            .CLOCK_ENABLE(1'b0),
            .LATCH_INPUT_VALUE(1'b0),
            .INPUT_CLK(1'b0),
            .OUTPUT_CLK(1'b0));

   SB_IO #(.PIN_TYPE(6'b101001),
           .PULLUP(1'b0))
   u_usb_n (.PACKAGE_PIN(usb_n),
            .OUTPUT_ENABLE(tx_en),
            .D_OUT_0(dn_tx),
            .D_IN_0(dn_rx),
            .D_OUT_1(1'b0),
            .D_IN_1(),
            .CLOCK_ENABLE(1'b0),
            .LATCH_INPUT_VALUE(1'b0),
            .INPUT_CLK(1'b0),
            .OUTPUT_CLK(1'b0));

   // drive usb_pu to 3.3V or to high impedance
   SB_IO #(.PIN_TYPE(6'b101001),
           .PULLUP(1'b0))
   u_usb_pu (.PACKAGE_PIN(usb_pu),
             .OUTPUT_ENABLE(dp_pu),
             .D_OUT_0(1'b1),
             .D_IN_0(),
             .D_OUT_1(1'b0),
             .D_IN_1(),
             .CLOCK_ENABLE(1'b0),
             .LATCH_INPUT_VALUE(1'b0),
             .INPUT_CLK(1'b0),
             .OUTPUT_CLK(1'b0));

endmodule
