
module loopback
  (
   input  clk, // 16MHz Clock
   output led, // User LED ON=1, OFF=0
   inout  usb_p, // USB+
   inout  usb_n, // USB-
   output usb_pu  // USB 1.5kOhm Pullup EN
   );

   localparam BIT_SAMPLES = 'd4;
   localparam [6:0] DIVF = 12*BIT_SAMPLES-1;

   wire             clk_pll;
   wire             clk_div2;
   wire             clk_div4;
   wire             clk_div8;
   wire             clk_div16;
   wire             lock;
   wire             rx_dp;
   wire             rx_dn;
   wire             tx_dp;
   wire             tx_dn;
   wire             tx_en;
   wire [7:0]       out_data;
   wire             out_valid;
   wire             in_ready;
   wire [7:0]       in_data;
   wire             in_valid;
   wire             out_ready;

   SB_PLL40_CORE #(.DIVR(4'b0000),
                   .DIVF(DIVF),
                   .DIVQ(3'b100),
                   .FILTER_RANGE(3'b001),
                   .FEEDBACK_PATH("SIMPLE"),
                   .DELAY_ADJUSTMENT_MODE_FEEDBACK("FIXED"),
                   .FDA_FEEDBACK(4'b0000),
                   .DELAY_ADJUSTMENT_MODE_RELATIVE("FIXED"),
                   .FDA_RELATIVE(4'b0000),
                   .SHIFTREG_DIV_MODE(2'b00),
                   .PLLOUT_SELECT("GENCLK"),
                   .ENABLE_ICEGATE(1'b0))
   u_pll (.REFERENCECLK(clk),
          .PLLOUTCORE(),
          .PLLOUTGLOBAL(clk_pll),
          .EXTFEEDBACK(1'b0),
          .DYNAMICDELAY('d0),
          .LOCK(lock),
          .BYPASS(1'b0),
          .RESETB(1'b1),
          .SDI(1'b0),
          .SDO(),
          .SCLK(1'b0),
          .LATCHINPUTVALUE(1'b1));

   prescaler u_prescaler (.clk_i(clk_pll),
                          .rstn_i(lock),
                          .clk_div2_o(clk_div2),
                          .clk_div4_o(clk_div4),
                          .clk_div8_o(clk_div8),
                          .clk_div16_o(clk_div16));

   reg [1:0]        rstn_sync;
   reg [20:0]       up_cnt;

   wire             rstn;

   always @(posedge clk or negedge lock) begin
      if (~lock) begin
         rstn_sync <= 2'd0;
      end else begin
         rstn_sync <= {1'b1, rstn_sync[1]};
      end
   end

   assign rstn = rstn_sync[0];

   always @(posedge clk or negedge rstn) begin
      if (~rstn) begin
         up_cnt <= 'd0;
      end else begin
         if (up_cnt[20] == 1'b0)
           up_cnt <= up_cnt + 1;
      end
   end

   assign led = ~up_cnt[20];
   assign usb_pu = up_cnt[20];

   usb_cdc #(.VENDORID(16'h1D50),
             .PRODUCTID(16'h6130),
             .IN_BULK_MAXPACKETSIZE('d8),
             .OUT_BULK_MAXPACKETSIZE('d8),
             .BIT_SAMPLES(BIT_SAMPLES),
             .USE_APP_CLK(1),
             .APP_CLK_RATIO(4))
   u_usb_cdc (.app_clk_i(clk_div4),
              .clk_i(clk_pll),
              .rstn_i(rstn),
              .out_ready_i(in_ready),
              .in_data_i(out_data),
              .in_valid_i(out_valid),
              .rx_dp_i(rx_dp),
              .rx_dn_i(rx_dn),
              .out_data_o(out_data),
              .out_valid_o(out_valid),
              .in_ready_o(in_ready),
              .tx_en_o(tx_en),
              .tx_dp_o(tx_dp),
              .tx_dn_o(tx_dn));

   SB_IO #(.PIN_TYPE(6'b101001),
           .PULLUP(1'b0))
   u_usb_p (.PACKAGE_PIN(usb_p),
            .OUTPUT_ENABLE(tx_en),
            .D_OUT_0(tx_dp),
            .D_IN_0(rx_dp),
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
            .D_OUT_0(tx_dn),
            .D_IN_0(rx_dn),
            .D_OUT_1(1'b0),
            .D_IN_1(),
            .CLOCK_ENABLE(1'b0),
            .LATCH_INPUT_VALUE(1'b0),
            .INPUT_CLK(1'b0),
            .OUTPUT_CLK(1'b0));

endmodule
