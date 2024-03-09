//  USB 2.0 full speed IN FIFO.
//  Written in verilog 2001

// IN_FIFO module shall implement an IN FIFO interface.
// New app_in_data_i shall be inserted in the IN FIFO when both
//   app_in_valid_i and app_in_ready_o are high.
// in_data_o shall be sourced from the IN FIFO when both in_req_i
//   and in_data_ack_i are low and both in_ready_i and in_valid_o are high.
// Data that is sourced from the IN FIFO shall be removed when it has been
//   acknowledged by an ACK packet.

module in_fifo
  #(parameter IN_MAXPACKETSIZE = 'd8,
    parameter USE_APP_CLK = 0,
    parameter APP_CLK_FREQ = 12) // app_clk frequency in MHz
   (
    // ---- to/from Application ------------------------------------
    input        app_clk_i,
    input        app_rstn_i,
    // While app_rstn_i is low (active low), the app_clk_i'ed registers shall be reset
    input [7:0]  app_in_data_i,
    input        app_in_valid_i,
    // While app_in_valid_i is high, app_in_data_i shall be valid.
    output       app_in_ready_o,
    // When both app_in_ready_o and app_in_valid_i are high, app_in_data_i shall
    //   be consumed.

    // ---- from top module ---------------------------------------
    input        clk_i,
    // clk_i clock shall have a frequency of 12MHz*BIT_SAMPLES
    input        rstn_i,
    // While rstn_i is low (active low), the clk_i'ed registers shall be reset
    input        clk_gate_i,
    // clk_gate_i shall be high for only one clk_i period within every BIT_SAMPLES clk_i periods.
    // When clk_gate_i is high, the registers that are gated by it shall be updated.
    output       in_empty_o,
    // While the IN FIFO is empty and there is no unconfirmed data waiting for ACK packet,
    //   in_empty_o shall be high.
    // When clk_gate_i is high, in_empty_o shall be updated.
    output       in_full_o,
    // While the IN FIFO is full, including the presence of unconfirmed data waiting for ACK packet,
    //   in_full_o shall be high.
    // When clk_gate_i is high, in_full_o shall be updated.

    // ---- to/from SIE module ------------------------------------
    output [7:0] in_data_o,
    // While in_valid_o is high, in_data_o shall be valid.
    output       in_valid_o,
    // While the IN FIFO is not empty, in_valid_o shall be high.
    // When in_valid_o is low, either in_req_i or in_data_ack_i shall be high
    //   at next in_ready_i high.
    // When both in_ready_i and clk_gate_i are high, in_valid_o shall be updated.
    // When clk_gate_i is high, in_valid_o shall be updated.
    input        in_req_i,
    // When both in_req_i and in_ready_i are high, a new IN packet shall be requested.
    // When clk_gate_i is high, in_req_i shall be updated.
    input        in_ready_i,
    // When both in_req_i and in_data_ack_i are low and in_ready_i is high,
    //   in_valid_o shall be high and in_data_o shall be consumed.
    // in_ready_i shall be high only for one clk_gate_i multi-cycle period.
    // When clk_gate_i is high, in_ready_i shall be updated.
    input        in_data_ack_i
    // When both in_data_ack_i and in_ready_i are high, an ACK packet shall be received.
    // When clk_gate_i is high, in_data_ack_i shall be updated.
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

   localparam IN_LENGTH = IN_MAXPACKETSIZE + 'd1; // the contents of the last addressed byte is meaningless

   reg [ceil_log2(IN_LENGTH)-1:0] in_first_q, in_first_qq;
   reg [ceil_log2(IN_LENGTH)-1:0] in_last_q, in_last_qq;
   reg [8*IN_LENGTH-1:0]          in_fifo_q;

   assign in_data_o = in_fifo_q[{in_first_qq, 3'd0} +:8];
   assign in_valid_o = (in_first_qq == in_last_qq) ? 1'b0 : 1'b1;

   always @(posedge clk_i or negedge rstn_i) begin
      if (~rstn_i) begin
         in_first_q <= 'd0;
         in_first_qq <= 'd0;
      end else begin
         if (clk_gate_i) begin
            if (in_ready_i) begin
               if (in_req_i) begin
                  in_first_qq <= in_first_q; // shall retry one more time if in_first_q wasn't updated
               end else if (in_data_ack_i) begin
                  in_first_q <= in_first_qq;
               end else begin
                  if (in_first_qq == IN_LENGTH-1)
                    in_first_qq <= 'd0;
                  else
                    in_first_qq <= in_first_qq + 1;
               end
            end
         end
      end
   end

   wire in_full, app_in_buffer_empty;

   assign in_full = (in_first_q == ((in_last_q == IN_LENGTH-1) ? 'd0 : in_last_q+1) ? 1'b1 : 1'b0);
   assign in_full_o = in_full;
   assign in_empty_o = ((in_first_q == in_last_q && app_in_buffer_empty == 1'b1) ? 1'b1 : 1'b0);

   generate
      if (USE_APP_CLK == 0) begin : u_sync_data
         reg [7:0] app_in_data_q;
         reg       app_in_valid_q, app_in_valid_qq;
         reg       app_in_ready_q;

         assign app_in_ready_o = app_in_ready_q;
         assign app_in_buffer_empty = ~app_in_valid_qq;

         always @(posedge clk_i or negedge rstn_i) begin
            if (~rstn_i) begin
               in_fifo_q <= {IN_LENGTH{8'd0}};
               in_last_q <= 'd0;
               in_last_qq <= 'd0;
               app_in_data_q <= 8'd0;
               app_in_valid_q <= 1'b0;
               app_in_valid_qq <= 1'b0;
               app_in_ready_q <= 1'b0;
            end else begin
               if (clk_gate_i) begin
                  in_fifo_q[{in_last_q, 3'd0} +:8] <= app_in_data_q;
                  app_in_valid_qq <= app_in_valid_q;
                  if (in_ready_i)
                    in_last_qq <= in_last_q;
                  if (~in_full & app_in_valid_qq) begin
                     app_in_valid_q <= 1'b0;
                     app_in_valid_qq <= 1'b0;
                     app_in_ready_q <= 1'b1;
                     if (in_last_q == IN_LENGTH-1) begin
                        in_last_q <= 'd0;
                        if (in_ready_i)
                          in_last_qq <= 'd0;
                     end else begin
                        in_last_q <= in_last_q + 1;
                        if (in_ready_i)
                          in_last_qq <= in_last_q + 1;
                     end
                  end
               end
               if (~app_in_valid_q)
                 app_in_ready_q <= 1'b1;
               if (app_in_valid_i & app_in_ready_q) begin
                  app_in_data_q <= app_in_data_i;
                  app_in_valid_q <= 1'b1;
                  if (clk_gate_i)
                    app_in_valid_qq <= 1'b1;
                  app_in_ready_q <= 1'b0;
               end
            end
         end
      end else if (APP_CLK_FREQ <= 12) begin : u_lte12mhz_async_data
         reg [2:0] app_clk_sq; // BIT_SAMPLES >= 4
         reg [15:0] app_in_data_q;
         reg [1:0]  app_in_valid_q, app_in_valid_qq, app_in_valid_qqq;
         reg        app_in_first_q, app_in_first_qq, app_in_first_qqq;
         reg [1:0]  app_in_consumed_q, app_in_consumed_qq;
         reg        app_in_ready_q;

         assign app_in_ready_o = app_in_ready_q;
         assign app_in_buffer_empty = ~|app_in_valid_qqq;

         always @(posedge clk_i or negedge rstn_i) begin
            if (~rstn_i) begin
               in_fifo_q <= {IN_LENGTH{8'd0}};
               in_last_q <= 'd0;
               in_last_qq <= 'd0;
               app_clk_sq <= 3'b000;
               app_in_valid_qq <= 2'b00;
               app_in_valid_qqq <= 2'b00;
               app_in_first_qq <= 1'b0;
               app_in_first_qqq <= 1'b0;
               app_in_consumed_q <= 2'b00;
               app_in_consumed_qq <= 2'b00;
               app_in_ready_q <= 1'b0;
            end else begin
               app_clk_sq <= {app_clk_i, app_clk_sq[2:1]};
               if (app_clk_sq[1:0] == 2'b10) begin
                  app_in_ready_q <= |(~(app_in_valid_q & ~app_in_consumed_q));
                  app_in_consumed_q <= 2'b00;
                  app_in_consumed_qq <= app_in_consumed_q;
                  app_in_valid_qq <= app_in_valid_q & ~app_in_consumed_q;
                  if (^app_in_consumed_q)
                    app_in_first_qq <= app_in_consumed_q[0];
                  else
                    app_in_first_qq <= app_in_first_q;
               end
               if (clk_gate_i) begin
                  if (app_in_first_qqq == 1'b0)
                    in_fifo_q[{in_last_q, 3'd0} +:8] <= app_in_data_q[7:0];
                  else
                    in_fifo_q[{in_last_q, 3'd0} +:8] <= app_in_data_q[15:8];
                  if (in_ready_i)
                    in_last_qq <= in_last_q;
                  app_in_valid_qqq <= app_in_valid_qq;
                  app_in_first_qqq <= app_in_first_qq;
                  if (app_clk_sq[1:0] == 2'b10) begin
                     app_in_valid_qqq <= app_in_valid_q & ~app_in_consumed_q;
                     if (^app_in_consumed_q)
                       app_in_first_qqq <= app_in_consumed_q[0];
                     else
                       app_in_first_qqq <= app_in_first_q;
                  end
                  if (~in_full & |app_in_valid_qqq) begin
                     if (app_in_first_qqq == 1'b0) begin
                        app_in_valid_qq[0] <= 1'b0;
                        app_in_valid_qqq[0] <= 1'b0;
                        app_in_first_qq <= 1'b1;
                        app_in_first_qqq <= 1'b1;
                        app_in_consumed_q[0] <= 1'b1;
                     end else begin
                        app_in_valid_qq[1] <= 1'b0;
                        app_in_valid_qqq[1] <= 1'b0;
                        app_in_first_qq <= 1'b0;
                        app_in_first_qqq <= 1'b0;
                        app_in_consumed_q[1] <= 1'b1;
                     end
                     if (in_last_q == IN_LENGTH-1) begin
                        in_last_q <= 'd0;
                        if (in_ready_i)
                          in_last_qq <= 'd0;
                     end else begin
                        in_last_q <= in_last_q + 1;
                        if (in_ready_i)
                          in_last_qq <= in_last_q + 1;
                     end
                  end
               end
            end
         end

         always @(posedge app_clk_i or negedge app_rstn_i) begin
            if (~app_rstn_i) begin
               app_in_data_q <= 16'd0;
               app_in_valid_q <= 2'b00;
               app_in_first_q <= 1'b0;
            end else begin
               app_in_valid_q <= app_in_valid_q & ~app_in_consumed_qq;
               if (^app_in_consumed_qq)
                 app_in_first_q <= app_in_consumed_qq[0];
               if (app_in_valid_i & app_in_ready_q) begin
                  if (~(app_in_valid_q[0] & ~app_in_consumed_qq[0])) begin
                     app_in_data_q[7:0] <= app_in_data_i;
                     app_in_valid_q[0] <= 1'b1;
                     app_in_first_q <= app_in_valid_q[1] & ~app_in_consumed_qq[1];
                  end else if (~(app_in_valid_q[1] & ~app_in_consumed_qq[1])) begin
                     app_in_data_q[15:8] <= app_in_data_i;
                     app_in_valid_q[1] <= 1'b1;
                     app_in_first_q <= ~(app_in_valid_q[0] & ~app_in_consumed_qq[0]);
                  end
               end
            end
         end
      end else begin : u_gt12mhz_async_data
         reg [1:0] app_in_valid_sq;
         reg [7:0] app_in_data_q;
         reg       app_in_valid_q, app_in_valid_qq;
         reg       app_in_ready_q;

         assign app_in_buffer_empty = ~app_in_valid_qq;

         always @(posedge clk_i or negedge rstn_i) begin
            if (~rstn_i) begin
               in_fifo_q <= {IN_LENGTH{8'd0}};
               in_last_q <= 'd0;
               app_in_valid_sq <= 2'd0;
               app_in_valid_qq <= 1'b0;
               app_in_ready_q <= 1'b0;
            end else begin
               app_in_valid_sq <= {app_in_valid_q, app_in_valid_sq[1]};
               if (~app_in_valid_sq[0])
                 app_in_ready_q <= 1'b1;
               if (clk_gate_i) begin
                  in_fifo_q[{in_last_q, 3'd0} +:8] <= app_in_data_q;
                  app_in_valid_qq <= app_in_valid_sq[0] & app_in_ready_q;
                  if (in_ready_i)
                    in_last_qq <= in_last_q;
                  if (~in_full & app_in_valid_qq) begin
                     app_in_valid_qq <= 1'b0;
                     app_in_ready_q <= 1'b0;
                     if (in_last_q == IN_LENGTH-1) begin
                        in_last_q <= 'd0;
                        if (in_ready_i)
                          in_last_qq <= 'd0;
                     end else begin
                        in_last_q <= in_last_q + 1;
                        if (in_ready_i)
                          in_last_qq <= in_last_q + 1;
                     end
                  end
               end
            end
         end

         reg [1:0] app_in_ready_sq;

         assign app_in_ready_o = app_in_ready_sq[0] & ~app_in_valid_q;

         always @(posedge app_clk_i or negedge app_rstn_i) begin
            if (~app_rstn_i) begin
               app_in_data_q <= 8'd0;
               app_in_valid_q <= 1'b0;
               app_in_ready_sq <= 2'b00;
            end else begin
               app_in_ready_sq <= {app_in_ready_q, app_in_ready_sq[1]};
               if (~app_in_ready_sq[0])
                 app_in_valid_q <= 1'b0;
               else if (app_in_valid_i & ~app_in_valid_q) begin
                  app_in_data_q <= app_in_data_i;
                  app_in_valid_q <= 1'b1;
               end
            end
         end
      end
   endgenerate
endmodule
