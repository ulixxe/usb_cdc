
module loopback
  (
   input  clk, // 16MHz Clock
   output led, // User LED ON=1, OFF=0
   inout  usb_p, // USB+
   inout  usb_n, // USB-
   output usb_pu  // USB 1.5kOhm Pullup EN
   );

   localparam CHANNELS = 'd1;
   localparam BIT_SAMPLES = 'd4;
   localparam [6:0] DIVF = 12*BIT_SAMPLES-1;

   wire             clk_pll;
   wire             clk_prescaler;
   wire             clk_usb;
   wire             clk_app;
   wire             clk_div2;
   wire             clk_div4;
   wire             clk_div8;
   wire             clk_div16;
   wire             lock;
   wire             dp_pu;
   wire             dp_rx;
   wire             dn_rx;
   wire             dp_tx;
   wire             dn_tx;
   wire             tx_en;
   wire [8*CHANNELS-1:0] out_data;
   wire [CHANNELS-1:0]   out_valid;
   wire [CHANNELS-1:0]   in_ready;
   wire [10:0]           frame;
   wire                  configured;

   localparam CONF = 3;
   localparam [2:0] DIVQ =
                    (CONF == 0) ? 3'd2 : // 192MHz
                    (CONF == 1) ? 3'd4 : // 48MHz
                    (CONF == 2) ? 3'd4 : // 48MHz
                    3'd4;                // 48MHz
   localparam       APP_CLK_FREQ =
                    (CONF == 0) ? 192 : // 192MHz
                    (CONF == 1) ? 12 :  // 12MHz
                    (CONF == 2) ? 2 :   // 2MHz
                    12;                 // Not used
   localparam       USE_APP_CLK =
                    (CONF == 0) ? 1 :
                    (CONF == 1) ? 1 :
                    (CONF == 2) ? 1 :
                    0;

   generate
      if (CONF == 0) begin : u_conf_0
         assign clk_prescaler = clk_pll; // 192MHz
         assign clk_app = clk_pll;
         assign clk_usb = clk_div4;      // 48MHz
      end else if (CONF == 1) begin : u_conf_1
         assign clk_prescaler = clk_pll; // 48MHz
         assign clk_app = clk_div4;      // 12MHz
         assign clk_usb = clk_pll;
      end else if (CONF == 2) begin : u_conf_2
         assign clk_prescaler = clk;     // 16MHz
         assign clk_app = clk_div8;      // 2MHz
         assign clk_usb = clk_pll;
      end else begin : u_conf_3
         assign clk_prescaler = 1'b0;    // Not used
         assign clk_app = 1'b0;          // Not used
         assign clk_usb = clk_pll;
      end
   endgenerate

   assign led = (configured) ? frame[9] : ~&frame[4:3];

   // if FEEDBACK_PATH = SIMPLE:
   // clk_freq = (ref_freq * (DIVF + 1)) / (2**DIVQ * (DIVR + 1));
   SB_PLL40_CORE #(.DIVR(4'd0),
                   .DIVF(DIVF),
                   .DIVQ(DIVQ),
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
          .PLLOUTGLOBAL(clk_pll),
          .EXTFEEDBACK(1'b0),
          .DYNAMICDELAY(8'd0),
          .LOCK(lock),
          .BYPASS(1'b0),
          .RESETB(1'b1),
          .SDI(1'b0),
          .SDO(),
          .SCLK(1'b0),
          .LATCHINPUTVALUE(1'b1));

   prescaler u_prescaler (.clk_i(clk_prescaler),
                          .rstn_i(lock),
                          .clk_div2_o(clk_div2),
                          .clk_div4_o(clk_div4),
                          .clk_div8_o(clk_div8),
                          .clk_div16_o(clk_div16));

   usb_cdc #(.VENDORID(16'h1D50),
             .PRODUCTID(16'h6130),
             .CHANNELS(CHANNELS),
             .IN_BULK_MAXPACKETSIZE('d8),
             .OUT_BULK_MAXPACKETSIZE('d8),
             .BIT_SAMPLES(BIT_SAMPLES),
             .USE_APP_CLK(USE_APP_CLK),
             .APP_CLK_FREQ(APP_CLK_FREQ))
   u_usb_cdc (.frame_o(frame),
              .configured_o(configured),
              .app_clk_i(clk_app),
              .clk_i(clk_usb),
              .rstn_i(lock),
              .out_ready_i(in_ready),
              .in_data_i(out_data),
              .in_valid_i(out_valid),
              .dp_rx_i(dp_rx),
              .dn_rx_i(dn_rx),
              .out_data_o(out_data),
              .out_valid_o(out_valid),
              .in_ready_o(in_ready),
              .dp_pu_o(dp_pu),
              .tx_en_o(tx_en),
              .dp_tx_o(dp_tx),
              .dn_tx_o(dn_tx));

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
