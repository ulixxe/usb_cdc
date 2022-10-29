//  USB 2.0 full speed OUT FIFO.
//  Written in verilog 2001

// OUT_FIFO module shall implement OUT FIFO interface.
// While OUT FIFO is not full, when OUT data is available, OUT_FIFO
//   shall sink OUT data.

module out_fifo
  #(parameter OUT_MAXPACKETSIZE = 'd8,
    parameter BIT_SAMPLES = 'd4,
    parameter USE_APP_CLK = 0,
    parameter APP_CLK_RATIO = 'd4)
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
    output       out_empty_o,
    output       out_full_o,

    // ---- to/from SIE module ------------------------------------
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
    //   current packet reception and OUT FIFO shall manage the error
    //   condition.
    input        out_ready_i
    // When both out_valid_i and out_ready_i are high, the out_data_i shall
    //   be consumed.
    // When out_valid_i and out_err_i are low and out_ready_i is high, the
    //   on-going OUT transaction shall end.
    // out_ready_i shall be high only for one clk_i period.
    );

   function integer ceil_log2;
      input integer arg;
      begin
         ceil_log2 = 0;
         while ((2 ** ceil_log2) < arg)
           ceil_log2 = ceil_log2 + 1;
      end
   endfunction

   localparam OUT_LENGTH = OUT_MAXPACKETSIZE + 'd1;
   localparam [1:0] ST_OUT_IDLE = 2'd0,
                    ST_OUT_DATA = 2'd1,
                    ST_OUT_NAK = 2'd2;

   reg [1:0]        out_state_q, out_state_d;
   reg [8*OUT_LENGTH-1:0] out_fifo_q, out_fifo_d;
   reg [ceil_log2(OUT_LENGTH)-1:0] out_first_q;
   reg [ceil_log2(OUT_LENGTH)-1:0] out_last_q, out_last_d;
   reg [ceil_log2(OUT_LENGTH)-1:0] out_last_qq, out_last_dd;
   reg                             out_nak_q, out_nak_d;
   reg                             out_full_q;

   assign out_nak_o = out_nak_q;

   always @(posedge clk_i or negedge rstn_i) begin
      if (~rstn_i) begin
         out_fifo_q <= {OUT_LENGTH{8'd0}};
         out_last_q <= 'd0;
         out_last_qq <= 'd0;
         out_state_q <= ST_OUT_IDLE;
         out_nak_q <= 1'b0;
      end else begin
         if (out_ready_i) begin
            out_fifo_q <= out_fifo_d;
            out_last_q <= out_last_d;
            out_last_qq <= out_last_dd;
            out_state_q <= out_state_d;
            out_nak_q <= out_nak_d;
         end
      end
   end

   always @(/*AS*/out_data_i or out_err_i or out_fifo_q or out_full_q
            or out_last_q or out_last_qq or out_nak_q or out_state_q
            or out_valid_i) begin
      out_fifo_d = out_fifo_q;
      out_last_d = out_last_q;
      out_last_dd = out_last_qq;
      out_state_d = out_state_q;
      out_nak_d = out_nak_q;

      if (out_err_i == 1'b1) begin
         out_state_d = ST_OUT_IDLE;
         out_last_dd = out_last_q;
         out_nak_d = 1'b0;
      end else if (out_valid_i == 1'b0) begin
         out_state_d = ST_OUT_IDLE;
         if (out_nak_q == 1'b1)
           out_last_dd = out_last_q;
         else
           out_last_d = out_last_qq;
      end else if (out_full_q == 1'b1 || out_state_q == ST_OUT_NAK) begin
         out_state_d = ST_OUT_NAK;
         out_nak_d = 1'b1;
      end else begin
         out_state_d = ST_OUT_DATA;
         out_fifo_d[8*out_last_qq +:8] = out_data_i;
         if (out_last_qq == OUT_LENGTH-1)
           out_last_dd = 'd0;
         else
           out_last_dd = out_last_qq + 1;
         out_nak_d = 1'b0;
      end
   end

   reg [ceil_log2(BIT_SAMPLES)-1:0] delay_out_cnt_q;

   wire                             out_empty;

   assign out_empty = ((out_first_q == out_last_q) ? 1'b1 : 1'b0);
   assign out_empty_o = out_empty;
   assign out_full_o = out_full_q;

   generate
      if (USE_APP_CLK == 0) begin : u_sync_data
         assign app_out_valid_o = ((out_empty == 1'b0 && {1'b0, delay_out_cnt_q} == BIT_SAMPLES-1) ? 1'b1 : 1'b0);
         assign app_out_data_o = out_fifo_q[8*out_first_q +:8];

         always @(posedge clk_i or negedge rstn_i) begin
            if (~rstn_i) begin
               out_first_q <= 'd0;
               delay_out_cnt_q <= 'd0;
               out_full_q <= 1'b0;
            end else begin
               if ({1'b0, delay_out_cnt_q} != BIT_SAMPLES-1) begin
                  delay_out_cnt_q <= delay_out_cnt_q + 1;
               end else begin
                  out_full_q <= (out_last_qq == ((out_first_q == 'd0) ? OUT_LENGTH-1: out_first_q-1) ? 1'b1 : 1'b0);
                  if (out_empty == 1'b0) begin
                     if (app_out_ready_i == 1'b1) begin
                        delay_out_cnt_q <= 'd0;
                        if (out_first_q == OUT_LENGTH-1)
                          out_first_q <= 'd0;
                        else
                          out_first_q <= out_first_q + 1;
                     end
                  end
               end
            end
         end
      end else if (APP_CLK_RATIO >= 4) begin : u_gtex4_async_data
         reg [2:0] app_clk_sq;
         reg       out_valid_q;
         reg       out_consumed_q;

         assign app_out_valid_o = out_valid_q;
         assign app_out_data_o = out_fifo_q[8*out_first_q +:8];

         always @(posedge clk_i or negedge rstn_i) begin
            if (~rstn_i) begin
               out_first_q <= 'd0;
               delay_out_cnt_q <= 'd0;
               out_full_q <= 1'b0;
               out_valid_q <= 1'b0;
               app_clk_sq <= 3'd0;
            end else begin
               app_clk_sq <= {app_clk_i, app_clk_sq[2:1]};
               if ({1'b0, delay_out_cnt_q} != BIT_SAMPLES-1) begin
                  delay_out_cnt_q <= delay_out_cnt_q + 1;
               end else begin
                  out_full_q <= (out_last_qq == ((out_first_q == 'd0) ? OUT_LENGTH-1: out_first_q-1) ? 1'b1 : 1'b0);
                  if (out_empty == 1'b0) begin
                     if (app_clk_sq[1:0] == 2'b10) begin
                        out_valid_q <= 1'b1;
                        if (out_consumed_q == 1'b1) begin
                           delay_out_cnt_q <= 'd0;
                           out_valid_q <= 1'b0;
                           if (out_first_q == OUT_LENGTH-1)
                             out_first_q <= 'd0;
                           else
                             out_first_q <= out_first_q + 1;
                        end
                     end
                     if (APP_CLK_RATIO >= 8 && app_clk_sq[1:0] == 2'b01) begin
                        out_valid_q <= 1'b1;
                     end
                  end
               end
            end
         end

         always @(posedge app_clk_i or negedge app_rstn_i) begin
            if (~app_rstn_i) begin
               out_consumed_q <= 1'b0;
            end else begin
               out_consumed_q <= app_out_ready_i & out_valid_q;
            end
         end
      end else begin : u_ltx4_async_data
         reg [1:0] out_iready_sq;
         reg       out_iready_mask_q;
         reg       out_ovalid_mask_q;
         reg [7:0] out_data_q;

         always @(posedge clk_i or negedge rstn_i) begin
            if (~rstn_i) begin
               out_first_q <= 'd0;
               delay_out_cnt_q <= 'd0;
               out_full_q <= 1'b0;
               out_iready_sq <= 2'b00;
               out_iready_mask_q <= 1'b0;
               out_data_q <= 8'd0;
            end else begin
               out_iready_sq <= {~out_ovalid_mask_q, out_iready_sq[1]};
               if ({1'b0, delay_out_cnt_q} != BIT_SAMPLES-1) begin
                  delay_out_cnt_q <= delay_out_cnt_q + 1;
               end else begin
                  out_full_q <= (out_last_qq == ((out_first_q == 'd0) ? OUT_LENGTH-1: out_first_q-1) ? 1'b1 : 1'b0);
                  if (~out_iready_sq[0])
                    out_iready_mask_q <= 1'b0;
                  else if (~out_empty & ~out_iready_mask_q) begin
                     out_data_q <= out_fifo_q[8*out_first_q +:8];
                     out_iready_mask_q <= 1'b1;
                     delay_out_cnt_q <= 'd0;
                     if (out_first_q == OUT_LENGTH-1)
                       out_first_q <= 'd0;
                     else
                       out_first_q <= out_first_q + 1;
                  end
               end
            end
         end

         reg [1:0] out_ovalid_sq;

         assign app_out_valid_o = out_ovalid_sq[0] & ~out_ovalid_mask_q;
         assign app_out_data_o = out_data_q;

         always @(posedge app_clk_i or negedge app_rstn_i) begin
            if (~app_rstn_i) begin
               out_ovalid_sq <= 2'b00;
               out_ovalid_mask_q <= 1'b0;
            end else begin
               out_ovalid_sq <= {out_iready_mask_q, out_ovalid_sq[1]};
               if (~out_ovalid_sq[0])
                 out_ovalid_mask_q <= 1'b0;
               else if (app_out_ready_i & ~out_ovalid_mask_q)
                 out_ovalid_mask_q <= 1'b1;
            end
         end
      end
   endgenerate
endmodule
