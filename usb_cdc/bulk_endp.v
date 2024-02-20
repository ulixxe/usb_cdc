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
    parameter USE_APP_CLK = 0,
    parameter APP_CLK_FREQ = 12) // app_clk frequency in MHz
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
    input        clk_gate_i,
    // clk_gate_i shall be high for only one clk_i period within every BIT_SAMPLES clk_i periods.
    // When clk_gate_i is high, the registers that are gated by it shall be updated.
    input        bus_reset_i,
    // While bus_reset_i is high, the module shall be reset
    // When clk_gate_i is high, bus_reset_i shall be updated.

    // ---- to/from SIE module ------------------------------------
    output [7:0] in_data_o,
    // While in_valid_o is high, in_data_o shall be valid.
    output       in_valid_o,
    // While IN FIFO is not empty, in_valid_o shall be high.
    // When clk_gate_i is high, in_valid_o shall be updated.
    input        in_req_i,
    // When both in_req_i and in_ready_i are high, a new IN packet shall be requested.
    // When clk_gate_i is high, in_req_i shall be updated.
    input        in_ready_i,
    // When both in_ready_i and in_valid_o are high, in_data_o shall be consumed.
    // in_ready_i shall be high only for one clk_gate_i multi-cycle period.
    // When clk_gate_i is high, in_ready_i shall be updated.
    input        in_data_ack_i,
    // When both in_data_ack_i and in_ready_i are high, an ACK packet shall be received.
    // When clk_gate_i is high, in_data_ack_i shall be updated.
    output       out_nak_o,
    // While out_valid_i is high, when OUT FIFO is full, out_nak_o shall be
    //   latched high.
    // When either out_valid_i or out_err_i is low and out_ready_i is high,
    //   out_nak_o shall be low.
    // When clk_gate_i is high, out_nak_o shall be updated.
    input [7:0]  out_data_i,
    input        out_valid_i,
    // While out_valid_i is high, the out_data_i shall be valid and both
    //   out_valid_i and out_data_i shall not change until consumed.
    // When clk_gate_i is high, out_valid_i shall be updated.
    input        out_err_i,
    // When both out_err_i and out_ready_i are high, SIE shall abort the
    //   current packet reception and OUT Bulk Endpoint shall manage the error
    //   condition.
    // When clk_gate_i is high, out_err_i shall be updated.
    input        out_ready_i
    // When both out_valid_i and out_ready_i are high, the out_data_i shall
    //   be consumed.
    // When out_valid_i and out_err_i are low and out_ready_i is high, the
    //   on-going OUT packet shall end (EOP).
    // out_ready_i shall be high only for one clk_gate_i multi-cycle period.
    // When clk_gate_i is high, out_ready_i shall be updated.
    );

   wire          rstn;
   wire          app_rstn;

   assign rstn = rstn_i & ~bus_reset_i;

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
             .USE_APP_CLK(USE_APP_CLK),
             .APP_CLK_FREQ(APP_CLK_FREQ))
   u_in_fifo (.in_empty_o(),
              .in_full_o(),
              .in_data_o(in_data_o),
              .in_valid_o(in_valid_o),
              .app_in_ready_o(app_in_ready_o),
              .clk_i(clk_i),
              .app_clk_i(app_clk_i),
              .rstn_i(rstn),
              .app_rstn_i(app_rstn),
              .clk_gate_i(clk_gate_i),
              .in_req_i(in_req_i),
              .in_data_ack_i(in_data_ack_i),
              .app_in_data_i(app_in_data_i),
              .app_in_valid_i(app_in_valid_i),
              .in_ready_i(in_ready_i));

   out_fifo #(.OUT_MAXPACKETSIZE(OUT_BULK_MAXPACKETSIZE),
              .USE_APP_CLK(USE_APP_CLK),
              .APP_CLK_FREQ(APP_CLK_FREQ))
   u_out_fifo (.out_empty_o(),
               .out_full_o(),
               .out_nak_o(out_nak_o),
               .app_out_valid_o(app_out_valid_o),
               .app_out_data_o(app_out_data_o),
               .clk_i(clk_i),
               .app_clk_i(app_clk_i),
               .rstn_i(rstn),
               .app_rstn_i(app_rstn),
               .clk_gate_i(clk_gate_i),
               .out_data_i(out_data_i),
               .out_valid_i(out_valid_i),
               .out_err_i(out_err_i),
               .out_ready_i(out_ready_i),
               .app_out_ready_i(app_out_ready_i));

endmodule
