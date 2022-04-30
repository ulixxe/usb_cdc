//  USB 2.0 full speed IN/OUT BULK Endpoints.
//  Written in verilog 2001

// BULK_ENDP module shall implement IN/OUT Bulk Endpoints and
//   FIFO interface of USB_CDC module.
// While IN FIFO is not empty, when required by in_req_i, BULK_ENDP
//   shall source IN data.
// While OUT FIFO is not full, when OUT data is available, BULK_ENDP
//   shall sink OUT data.

module bulk_endp
  #(parameter IN_BULK_MAXPACKETSIZE = 'd8,
    parameter OUT_BULK_MAXPACKETSIZE = 'd8,
    parameter BIT_SAMPLES = 'd4,
    parameter USE_APP_CLK = 0,
    parameter APP_CLK_RATIO = 'd4)
   (
    // ---- to/from Application ------------------------------------
    input        app_clk_i,
    input [7:0]  app_in_data_i,
    input        app_in_valid_i,
    // While app_in_valid_i is high, app_in_data_i shall be valid.
    output       app_in_ready_o,
    // When both app_in_ready_o and app_in_valid_i are high, app_in_data_i shall
    //   be consumed.
    output [7:0] app_out_data_o,
    output       app_out_valid_o,
    // While app_out_valid_o is high, the app_out_data_o shall be valid and both
    //   app_out_valid_o and app_out_data_o shall not change until consumed.
    input        app_out_ready_i,
    // When both app_out_valid_o and app_out_ready_i are high, the app_out_data_o shall
    //   be consumed.

    // ---- from USB_CDC module ------------------------------------
    input        clk_i,
    // clk_i clock shall have a frequency of 12MHz*BIT_SAMPLES
    input        rstn_i,
    // While rstn_i is low (active low), the module shall be reset
    input        usb_reset_i,
    // While usb_reset_i is high, the module shall be reset

    // ---- to/from SIE module ------------------------------------
    output [7:0] in_data_o,
    // While in_valid_o is high, in_data_o shall be valid.
    output       in_valid_o,
    // While in_req_i is high and IN FIFO is not empty, in_valid_o shall be high.
    input        in_req_i,
    // When a new IN transaction is requested, in_req_i shall change from low to high.
    // When a IN transaction ends, in_req_i shall change from high to low.
    input        in_ready_i,
    // When both in_ready_i and in_valid_o are high, in_data_o shall be consumed.
    // When in_data_o is consumed, in_ready_i shall be high only for
    //   one clk_i period.
    input        in_data_ack_i,
    // When in_data_ack_i is high and out_ready_i is high, an ACK packet shall be received.
    output       out_nak_o,
    // While out_valid_i is high, when OUT FIFO is full, out_nak_o shall be
    //   latched high.
    // While out_nak_o is latched high and OUT FIFO is not full, when a new
    //   OUT transaction starts, out_nak_o shall return low.
    input [7:0]  out_data_i,
    input        out_valid_i,
    // While out_valid_i is high, the out_data_i shall be valid and both
    //   out_valid_i and out_data_i shall not change until consumed.
    input        out_err_i,
    // When both out_err_i and out_ready_i are high, SIE shall abort the
    //   current packet reception and OUT Bulk Endpoint shall manage the error
    //   condition.
    input        out_ready_i /* synthesis syn_direct_enable = 1 */
    // When both out_valid_i and out_ready_i are high, the out_data_i shall
    //   be consumed.
    // When in_data_ack_i, out_valid_i and out_err_i are low and out_ready_i is high, the
    //   on-going OUT transaction shall end.
    // out_ready_i shall be high only for one clk_i period.
    );

   wire          rstn;
   wire          app_rstn;

   assign rstn = rstn_i & ~usb_reset_i;

   generate
      if (USE_APP_CLK == 0) begin : u_sync_app_rstn
         assign app_rstn = 1'b0;
      end else begin : u_async_app_rstn
         reg [1:0]     app_rstn_sq;

         assign app_rstn = app_rstn_sq[0];

         always @(posedge app_clk_i or negedge rstn) begin
            if (~rstn) begin
               app_rstn_sq <= 2'd0;
            end else begin
               app_rstn_sq <= {1'b1, app_rstn_sq[1]};
            end
         end
      end
   endgenerate

   in_fifo #(.IN_MAXPACKETSIZE(IN_BULK_MAXPACKETSIZE),
             .BIT_SAMPLES(BIT_SAMPLES),
             .USE_APP_CLK(USE_APP_CLK),
             .APP_CLK_RATIO(APP_CLK_RATIO))
   u_in_fifo (.in_empty_o(),
              .in_full_o(),
              .in_data_o(in_data_o),
              .in_valid_o(in_valid_o),
              .app_in_ready_o(app_in_ready_o),
              .clk_i(clk_i),
              .app_clk_i(app_clk_i),
              .rstn_i(rstn),
              .app_rstn_i(app_rstn),
              .in_req_i(in_req_i),
              .in_data_ack_i(in_data_ack_i),
              .app_in_data_i(app_in_data_i),
              .app_in_valid_i(app_in_valid_i),
              .out_valid_i(out_valid_i),
              .out_ready_i(out_ready_i),
              .in_ready_i(in_ready_i));

   out_fifo #(.OUT_MAXPACKETSIZE(OUT_BULK_MAXPACKETSIZE),
              .BIT_SAMPLES(BIT_SAMPLES),
              .USE_APP_CLK(USE_APP_CLK),
              .APP_CLK_RATIO(APP_CLK_RATIO))
   u_out_fifo (.out_empty_o(),
               .out_full_o(),
               .out_nak_o(out_nak_o),
               .app_out_valid_o(app_out_valid_o),
               .app_out_data_o(app_out_data_o),
               .clk_i(clk_i),
               .app_clk_i(app_clk_i),
               .rstn_i(rstn),
               .app_rstn_i(app_rstn),
               .out_data_i(out_data_i),
               .out_valid_i(out_valid_i),
               .out_err_i(out_err_i),
               .out_ready_i(out_ready_i),
               .app_out_ready_i(app_out_ready_i));

endmodule
