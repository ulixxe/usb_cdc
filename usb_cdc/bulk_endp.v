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
    input        rstn_i,

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
    // When out_valid_i and out_err_i are low and out_ready_i is high, the
    //   on-going OUT transaction shall end or an ACK packet shall be received
    //   at the end of an IN transaction.
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

   localparam OUT_LENGTH = OUT_BULK_MAXPACKETSIZE + 'd1;
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

   assign app_out_data_o = out_fifo_q[8*out_first_q +:8];
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

   localparam IN_LENGTH = IN_BULK_MAXPACKETSIZE + 'd1;
   localparam ST_IN_IDLE = 1'b0,
              ST_IN_DATA = 1'b1;

   reg [8*IN_LENGTH-1:0] in_fifo_q;
   reg [ceil_log2(IN_LENGTH)-1:0] in_last_q;
   reg [ceil_log2(IN_LENGTH)-1:0] in_first_q;
   reg [ceil_log2(IN_LENGTH)-1:0] in_first_qq;
   reg                            in_state_q;
   reg                            in_req_q;
   reg                            in_valid_q;

   assign in_data_o = in_fifo_q[8*in_first_qq +:8];
   assign in_valid_o = in_valid_q;

   always @(posedge clk_i or negedge rstn_i) begin
      if (~rstn_i) begin
         in_req_q <= 1'b0;
         in_state_q <= ST_IN_IDLE;
         in_valid_q <= 1'b0;
      end else begin
         in_req_q <= in_req_i;
         if (in_state_q == ST_IN_IDLE) begin
            if (in_req_i == 1'b1)
              in_state_q <= ST_IN_DATA;
         end else begin
            if (out_valid_i == 1'b1 || out_ready_i == 1'b1)
              in_state_q <= ST_IN_IDLE;
         end
         if (in_req_q == 1'b0) begin
            if (in_first_q == in_last_q)
              in_valid_q <= 1'b0;
            else
              in_valid_q <= 1'b1;
         end else begin
            if (in_first_qq == in_last_q)
              in_valid_q <= 1'b0;
         end
      end
   end

   wire                           in_start;
   wire                           in_clk_gate;

   assign in_start = (in_req_q == 1'b0 && in_req_i == 1'b1) ? 1'b1 : 1'b0;
   assign in_clk_gate = in_ready_i | out_ready_i | in_start;

   always @(posedge clk_i or negedge rstn_i) begin
      if (~rstn_i) begin
         in_first_q <= 'd0;
         in_first_qq <= 'd0;
      end else begin
         if (in_clk_gate) begin
            if (in_req_i == 1'b1) begin
               if (in_req_q == 1'b0) begin
                  in_first_qq <= in_first_q; // should retry no more in_first_qq!!! because it will be ignored by receiver
               end else begin
                  if (in_first_qq == IN_LENGTH-1)
                    in_first_qq <= 'd0;
                  else
                    in_first_qq <= in_first_qq + 1;
               end
            end else begin
               if (in_state_q == ST_IN_DATA)
                 in_first_q <= in_first_qq;
            end
         end
      end
   end

   reg [ceil_log2(BIT_SAMPLES)-1:0] delay_out_cnt_q;
   reg [ceil_log2(BIT_SAMPLES)-1:0] delay_in_cnt_q;

   wire                             out_empty;
   wire                             in_full;

   assign out_empty = ((out_first_q == out_last_q) ? 1'b1 : 1'b0);
   assign in_full = (in_last_q == ((in_first_q == 'd0) ? IN_LENGTH-1: in_first_q-1) ? 1'b1 : 1'b0);

   generate
      if (USE_APP_CLK == 0) begin : u_data_sync
         assign app_out_valid_o = ((out_empty == 1'b0 && {1'b0, delay_out_cnt_q} == BIT_SAMPLES-1) ? 1'b1 : 1'b0);

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

         assign app_in_ready_o = ((in_full == 1'b0 && {1'b0, delay_in_cnt_q} == BIT_SAMPLES-1) ? 1'b1 : 1'b0);

         always @(posedge clk_i or negedge rstn_i) begin
            if (~rstn_i) begin
               in_fifo_q <= {IN_LENGTH{8'd0}};
               in_last_q <= 'd0;
               delay_in_cnt_q <= 'd0;
            end else begin
               if ({1'b0, delay_in_cnt_q} != BIT_SAMPLES-1) begin
                  delay_in_cnt_q <= delay_in_cnt_q + 1;
               end else begin
                  if (in_full == 1'b0) begin
                     if (app_in_valid_i == 1'b1) begin
                        in_fifo_q[8*in_last_q +:8] <= app_in_data_i;
                        delay_in_cnt_q <= 'd0;
                        if (in_last_q == IN_LENGTH-1)
                          in_last_q <= 'd0;
                        else
                          in_last_q <= in_last_q + 1;
                     end
                  end
               end
            end
         end
      end else begin : u_data_sync
         reg                                  out_valid_q;
         reg                                  out_consumed_q;
         reg [2:0]                            app_clk_sq;
         reg [1:0]                            data_rstn_sq;

         wire                                 data_rstn;

         assign app_out_valid_o = out_valid_q;
         assign data_rstn = data_rstn_sq[0];

         always @(posedge app_clk_i or negedge rstn_i) begin
            if (~rstn_i) begin
               data_rstn_sq <= 2'd0;
            end else begin
               data_rstn_sq <= {1'b1, data_rstn_sq[1]};
            end
         end

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

         always @(posedge app_clk_i or negedge data_rstn) begin
            if (~data_rstn) begin
               out_consumed_q <= 1'b0;
            end else begin
               out_consumed_q <= app_out_ready_i & out_valid_q;
            end
         end

         reg [7:0] in_data_q;
         reg       in_ready_q;
         reg       in_consumed_q;

         assign app_in_ready_o = in_ready_q;

         always @(posedge clk_i or negedge rstn_i) begin
            if (~rstn_i) begin
               in_fifo_q <= {IN_LENGTH{8'd0}};
               in_last_q <= 'd0;
               delay_in_cnt_q <= 'd0;
               in_ready_q <= 1'b0;
            end else begin
               if ({1'b0, delay_in_cnt_q} != BIT_SAMPLES-1) begin
                  delay_in_cnt_q <= delay_in_cnt_q + 1;
               end else begin
                  if (in_full == 1'b0) begin
                     if (app_clk_sq[1:0] == 2'b10) begin
                        in_ready_q <= 1'b1;
                        if (in_consumed_q == 1'b1) begin
                           in_fifo_q[8*in_last_q +:8] <= in_data_q;
                           delay_in_cnt_q <= 'd0;
                           in_ready_q <= 1'b0;
                           if (in_last_q == IN_LENGTH-1)
                             in_last_q <= 'd0;
                           else
                             in_last_q <= in_last_q + 1;
                        end
                     end
                     if (APP_CLK_RATIO >= 8 && app_clk_sq[1:0] == 2'b01) begin
                        in_ready_q <= 1'b1;
                     end
                  end
               end
            end
         end

         always @(posedge app_clk_i or negedge data_rstn) begin
            if (~data_rstn) begin
               in_consumed_q <= 1'b0;
               in_data_q <= 8'd0;
            end else begin
               in_consumed_q <= app_in_valid_i & in_ready_q;
               if (app_in_valid_i == 1'b1 && in_ready_q == 1'b1)
                 in_data_q <= app_in_data_i;
            end
         end
      end
   endgenerate
endmodule
