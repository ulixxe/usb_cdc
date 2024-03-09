//  USB 2.0 full speed OUT FIFO.
//  Written in verilog 2001

// OUT_FIFO module shall implement an OUT FIFO interface.
// New out_data_i shall be inserted in the OUT FIFO when the FIFO is not
//   full, out_err_i is low and both out_valid_i and out_ready_i are high.
// Data that is inserted in the OUT FIFO shall be confirmed by EOP signaled
//   when out_valid_i and out_err_i are low and out_ready_i is high.
// app_out_data_o shall be sourced and removed from the OUT FIFO when both
//   app_out_valid_o and app_out_ready_i are high.

module out_fifo
  #(parameter OUT_MAXPACKETSIZE = 'd8,
    parameter USE_APP_CLK = 0,
    parameter APP_CLK_FREQ = 12) // app_clk frequency in MHz
   (
    // ---- to/from Application ------------------------------------
    input        app_clk_i,
    input        app_rstn_i,
    // While app_rstn_i is low (active low), the app_clk_i'ed registers shall be reset
    output [7:0] app_out_data_o,
    output       app_out_valid_o,
    // While app_out_valid_o is high, the app_out_data_o shall be valid and both
    //   app_out_valid_o and app_out_data_o shall not change until consumed.
    input        app_out_ready_i,
    // When both app_out_valid_o and app_out_ready_i are high, the app_out_data_o shall
    //   be consumed.

    // ---- from top module ---------------------------------------
    input        clk_i,
    // clk_i clock shall have a frequency of 12MHz*BIT_SAMPLES
    input        rstn_i,
    // While rstn_i is low (active low), the clk_i'ed registers shall be reset
    input        clk_gate_i,
    // clk_gate_i shall be high for only one clk_i period within every BIT_SAMPLES clk_i periods.
    // When clk_gate_i is high, the registers that are gated by it shall be updated.
    output       out_empty_o,
    // While the OUT FIFO is empty out_empty_o shall be high. Unconfirmed data is not condidered.
    // When clk_gate_i is high, out_empty_o shall be updated.
    output       out_full_o,
    // While the OUT FIFO is full, including the presence of unconfirmed data waiting for EOP,
    //   in_full_o shall be high.
    // When clk_gate_i is high, out_full_o shall be updated.

    // ---- to/from SIE module ------------------------------------
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
    //   current packet reception and OUT FIFO shall manage the error condition.
    // When clk_gate_i is high, out_err_i shall be updated.
    input        out_ready_i
    // When both out_valid_i and out_ready_i are high, the out_data_i shall
    //   be consumed.
    // When out_valid_i and out_err_i are low and out_ready_i is high, the
    //   on-going OUT packet shall end (EOP).
    // out_ready_i shall be high only for one clk_gate_i multi-cycle period.
    // When clk_gate_i is high, out_ready_i shall be updated.
    );

   function integer ceil_log2;
      input [31:0] arg;
      integer      i;
      begin
         ceil_log2 = 0;
         for (i = 0; i < 32; i = i + 1) begin
            if (arg > (1 << i))
              ceil_log2 = ceil_log2 + 1;
         end
      end
   endfunction

   localparam OUT_LENGTH = OUT_MAXPACKETSIZE + 'd1; // the contents of the last addressed byte is meaningless

   reg [8*OUT_LENGTH-1:0] out_fifo_q;
   reg [ceil_log2(OUT_LENGTH)-1:0] out_first_q;
   reg [ceil_log2(OUT_LENGTH)-1:0] out_last_q, out_last_d;
   reg [ceil_log2(OUT_LENGTH)-1:0] out_last_qq, out_last_dd;
   reg                             out_nak_q, out_nak_d;

   wire                            out_full;

   assign out_full = (out_first_q == ((out_last_qq == OUT_LENGTH-1) ? 'd0 : out_last_qq+1) ? 1'b1 : 1'b0);
   assign out_full_o = out_full;
   assign out_nak_o = out_nak_q;

   always @(posedge clk_i or negedge rstn_i) begin
      if (~rstn_i) begin
         out_fifo_q <= {OUT_LENGTH{8'd0}};
         out_last_q <= 'd0;
         out_last_qq <= 'd0;
         out_nak_q <= 1'b0;
      end else begin
         if (clk_gate_i) begin
            out_fifo_q[{out_last_qq, 3'd0} +:8] <= out_data_i;
            if (out_ready_i) begin
               out_last_q <= out_last_d;
               out_last_qq <= out_last_dd;
               out_nak_q <= out_nak_d;
            end
         end
      end
   end

   always @(/*AS*/out_err_i or out_full or out_last_q or out_last_qq
            or out_nak_q or out_valid_i) begin
      out_last_d = out_last_q;
      out_last_dd = out_last_qq;
      out_nak_d = 1'b0;

      if (out_err_i) begin
         out_last_dd = out_last_q;
      end else if (~out_valid_i) begin
         if (out_nak_q == 1'b1)
           out_last_dd = out_last_q;
         else
           out_last_d = out_last_qq;
      end else if (out_full | out_nak_q) begin
         out_nak_d = 1'b1;
      end else begin
         if (out_last_qq == OUT_LENGTH-1)
           out_last_dd = 'd0;
         else
           out_last_dd = out_last_qq + 1;
      end
   end

   wire [7:0] app_out_data;
   wire       out_empty;
   wire       app_out_buffer_empty;

   assign app_out_data = out_fifo_q[{out_first_q, 3'd0} +:8];
   assign out_empty = ((out_first_q == out_last_q) ? 1'b1 : 1'b0);
   assign out_empty_o = out_empty && app_out_buffer_empty;

   generate
      if (USE_APP_CLK == 0) begin : u_sync_data
         reg [7:0] app_out_data_q;
         reg       app_out_valid_q, app_out_valid_qq;

         assign app_out_data_o = app_out_data_q;
         assign app_out_valid_o = app_out_valid_q;
         assign app_out_buffer_empty = ~app_out_valid_qq;

         always @(posedge clk_i or negedge rstn_i) begin
            if (~rstn_i) begin
               out_first_q <= 'd0;
               app_out_data_q <= 8'd0;
               app_out_valid_q <= 1'b0;
               app_out_valid_qq <= 1'b0;
            end else begin
               if (app_out_ready_i & app_out_valid_q)
                 app_out_valid_q <= 1'b0;
               if (clk_gate_i) begin
                  app_out_valid_qq <= app_out_valid_q;
                  if (~out_empty) begin
                     if (~app_out_valid_q | (app_out_ready_i & app_out_valid_q)) begin
                        app_out_data_q <= app_out_data;
                        app_out_valid_q <= 1'b1;
                        app_out_valid_qq <= 1'b1;
                        if (out_first_q == OUT_LENGTH-1)
                          out_first_q <= 'd0;
                        else
                          out_first_q <= out_first_q + 1;
                     end
                  end
               end
            end
         end
      end else if (APP_CLK_FREQ <= 12) begin : u_lte12mhz_async_data
         reg [15:0] app_out_data_q;
         reg [1:0]  app_out_valid_q;
         reg        app_out_valid_qq, app_out_valid_qqq;
         reg        app_out_consumed_q;
         reg [2:0]  app_clk_sq; // BIT_SAMPLES >= 4

         assign app_out_data_o = app_out_data_q[7:0];
         assign app_out_valid_o = app_out_valid_qq;
         assign app_out_buffer_empty = ~app_out_valid_qqq;

         always @(posedge clk_i or negedge rstn_i) begin
            if (~rstn_i) begin
               out_first_q <= 'd0;
               app_out_data_q <= 16'd0;
               app_out_valid_q <= 2'b00;
               app_out_valid_qq <= 1'b0;
               app_out_valid_qqq <= 1'b0;
               app_clk_sq <= 3'b000;
            end else begin
               app_clk_sq <= {app_clk_i, app_clk_sq[2:1]};
               if (app_clk_sq[1:0] == 2'b10) begin
                  app_out_valid_qq <= app_out_valid_q[0];
                  if (app_out_consumed_q) begin
                     if (app_out_valid_q[1]) begin
                        app_out_data_q[7:0] <= app_out_data_q[15:8];
                        app_out_valid_q <= 2'b01;
                        app_out_valid_qq <= 1'b1;
                     end else begin
                        app_out_valid_q <= 2'b00;
                        app_out_valid_qq <= 1'b0;
                     end
                  end
               end
               if (clk_gate_i) begin
                  app_out_valid_qqq <= |app_out_valid_q;
                  if (~out_empty) begin
                     if (app_out_valid_q != 2'b11 ||
                         (app_clk_sq[1:0] == 2'b10 && app_out_consumed_q == 1'b1)) begin
                        if (app_out_valid_q[1] == 1'b1 &&
                            (app_clk_sq[1:0] == 2'b10 && app_out_consumed_q == 1'b1)) begin
                           app_out_data_q[15:8] <= app_out_data;
                           app_out_valid_q[1] <= 1'b1;
                           app_out_valid_qqq <= 1'b1;
                        end else if (app_out_valid_q[0] == 1'b0 ||
                            (app_clk_sq[1:0] == 2'b10 && app_out_consumed_q == 1'b1)) begin
                           app_out_data_q[7:0] <= app_out_data;
                           app_out_valid_q[0] <= 1'b1;
                           app_out_valid_qqq <= 1'b1;
                        end else begin
                           app_out_data_q[15:8] <= app_out_data;
                           app_out_valid_q[1] <= 1'b1;
                           app_out_valid_qqq <= 1'b1;
                        end
                        if (out_first_q == OUT_LENGTH-1)
                          out_first_q <= 'd0;
                        else
                          out_first_q <= out_first_q + 1;
                     end
                  end
               end
            end
         end

         always @(posedge app_clk_i or negedge app_rstn_i) begin
            if (~app_rstn_i) begin
               app_out_consumed_q <= 1'b0;
            end else begin
               app_out_consumed_q <= app_out_ready_i & app_out_valid_qq;
            end
         end
      end else begin : u_gt12mhz_async_data
         reg [1:0] app_out_consumed_sq;
         reg [7:0] app_out_data_q;
         reg       app_out_valid_q;
         reg       app_out_consumed_q;

         assign app_out_buffer_empty = ~app_out_valid_q;

         always @(posedge clk_i or negedge rstn_i) begin
            if (~rstn_i) begin
               out_first_q <= 'd0;
               app_out_data_q <= 8'd0;
               app_out_valid_q <= 1'b0;
               app_out_consumed_sq <= 2'b00;
            end else begin
               app_out_consumed_sq <= {app_out_consumed_q, app_out_consumed_sq[1]};
               if (clk_gate_i) begin
                  if (app_out_consumed_sq[0])
                    app_out_valid_q <= 1'b0;
                  else if (~out_empty & ~app_out_valid_q) begin
                     app_out_data_q <= app_out_data;
                     app_out_valid_q <= 1'b1;
                     if (out_first_q == OUT_LENGTH-1)
                       out_first_q <= 'd0;
                     else
                       out_first_q <= out_first_q + 1;
                  end
               end
            end
         end

         reg [1:0] out_valid_sq;

         assign app_out_data_o = app_out_data_q;
         assign app_out_valid_o = out_valid_sq[0] & ~app_out_consumed_q;

         always @(posedge app_clk_i or negedge app_rstn_i) begin
            if (~app_rstn_i) begin
               out_valid_sq <= 2'b00;
               app_out_consumed_q <= 1'b0;
            end else begin
               out_valid_sq <= {app_out_valid_q, out_valid_sq[1]};
               if (~out_valid_sq[0])
                 app_out_consumed_q <= 1'b0;
               else if (app_out_ready_i & ~app_out_consumed_q)
                 app_out_consumed_q <= 1'b1;
            end
         end
      end
   endgenerate
endmodule
