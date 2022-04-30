// Correctly map pins for the iCE40UP5K SB_RGBA_DRV hard macro.
// The variables EVT, PVT and HACKER are set from the Makefile.
`ifdef EVT
 `define BLUEPWM  RGB0PWM
 `define REDPWM   RGB1PWM
 `define GREENPWM RGB2PWM
`elsif HACKER
 `define BLUEPWM  RGB0PWM
 `define GREENPWM RGB1PWM
 `define REDPWM   RGB2PWM
`elsif PVT
 `define GREENPWM RGB0PWM
 `define REDPWM   RGB1PWM
 `define BLUEPWM  RGB2PWM
`endif

module loopback
  (
   input  clki, // 48MHz Clock
   output rgb0, // Red LED
   output rgb1, // Green LED
   output rgb2, // Blue LED
   inout  usb_dp, // USB+
   inout  usb_dn, // USB-
   output usb_dp_pu  // USB 1.5kOhm Pullup EN
   );

   wire   clk_3mhz;
   wire   clk_6mhz;
   wire   clk_12mhz;
   wire   clk_24mhz;
   wire   dp_pu;
   wire   dp_rx;
   wire   dn_rx;
   wire   dp_tx;
   wire   dn_tx;
   wire   tx_en;
   wire [7:0] out_data;
   wire       out_valid;
   wire       in_ready;
   wire [7:0] in_data;
   wire       in_valid;
   wire       out_ready;
   wire [2:0] led;

   assign led = {2'b00, ~dp_pu};

   // Connect to system clock (with buffering)
   wire       clk;
   SB_GB clk_gb (.USER_SIGNAL_TO_GLOBAL_BUFFER(clki),
                 .GLOBAL_BUFFER_OUTPUT(clk));

   reg [1:0]  rstn_sync = 0;

   wire       rstn;

   assign rstn = rstn_sync[0];

   always @(posedge clk) begin
      rstn_sync <= {1'b1, rstn_sync[1]};
   end

   prescaler u_prescaler (.clk_i(clk),
                          .rstn_i(rstn),
                          .clk_div16_o(clk_3mhz),
                          .clk_div8_o(clk_6mhz),
                          .clk_div4_o(clk_12mhz),
                          .clk_div2_o(clk_24mhz));

   // Instantiate iCE40 LED driver hard logic.
   //
   // Note that it's possible to drive the LEDs directly,
   // however that is not current-limited and results in
   // overvolting the red LED.
   //
   // See also:
   // https://www.latticesemi.com/-/media/LatticeSemi/Documents/ApplicationNotes/IK/ICE40LEDDriverUsageGuide.ashx?document_id=50668
   SB_RGBA_DRV #(.CURRENT_MODE("0b1"),       // half current
                 .RGB0_CURRENT("0b000011"),  // 4 mA
                 .RGB1_CURRENT("0b000011"),  // 4 mA
                 .RGB2_CURRENT("0b000011"))  // 4 mA
   RGBA_DRIVER (.CURREN(1'b1),
                .RGBLEDEN(1'b1),
                .`REDPWM(led[0]),      // Red
                .`GREENPWM(led[1]),    // Green
                .`BLUEPWM(led[2]),     // Blue
                .RGB0(rgb0),
                .RGB1(rgb1),
                .RGB2(rgb2));

   usb_cdc #(.VENDORID(16'h1209),
             .PRODUCTID(16'h5BF0),
             .IN_BULK_MAXPACKETSIZE('d8),
             .OUT_BULK_MAXPACKETSIZE('d8),
             .BIT_SAMPLES('d4),
             .USE_APP_CLK(1),
             .APP_CLK_RATIO(48/12))  // 48MHz / 12MHz
   u_usb_cdc (.frame_o(),
              .configured_o(),
              .app_clk_i(clk_12mhz),
              .clk_i(clk),
              .rstn_i(rstn),
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
   u_usb_dp (.PACKAGE_PIN(usb_dp),
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
   u_usb_dn (.PACKAGE_PIN(usb_dn),
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
   u_usb_pu (.PACKAGE_PIN(usb_dp_pu),
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
