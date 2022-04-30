//  Serial Peripheral Interface.
//  Written in verilog 2001

//  SPI module shall serialize wr_data_i to mosi_o bitstream
//    and de-serialize miso_i bitstream to rd_data_o.
//  A SPI bitstream shall have csn_o low and shall start with a write byte.

module spi
  #(parameter SCK_PERIOD_MULTIPLIER = 'd2)
   (
    input        clk_i,
    input        rstn_i,
    // While rstn_i is low (active low), the module shall be reset

    // ---- to/from application module --------------
    input        en_i,
    // When en_i changes from high to low, the current bitstream shall end at the
    //   end of current byte transmission.
    input [7:0]  wr_data_i,
    // While wr_valid_i is high, the wr_data_i shall be valid.
    input        wr_valid_i,
    // While en_i is high and when wr_valid_i changes from low to high, SPI shall start a
    //   new bitstream transmission as soon as possible.
    output       wr_ready_o,
    // While en_i is high and when both wr_valid_i and wr_ready_o are high, the 8-bit
    //   wr_data_i shall be consumed.
    output [7:0] rd_data_o,
    // While en_i is high and when both rd_valid_o and rd_ready_i are high, rd_data_o
    //   shall be consumed by application module.
    output       rd_valid_o,
    // When rd_data_o is valid, rd_valid_o shall be high only for one clk_i period.
    input        rd_ready_i,
    // While both en_i and rd_ready_i are high, a read bitstream shall continue at
    //  the end of the current byte transmission.

    // ---- to/from serial bus ----------------------
    output       sck_o,
    // While en_i is high and both wr_valid_o and rd_ready_i are low, sck_o shall
    //   wait at the end of current byte transmission.
    output       csn_o,
    // When both en_i and wr_valid_i are high, csn_o shall go low.
    // When en_i changes from high to low, csn_o shall go high at the end of current
    //   byte transmission.
    output       mosi_o,
    input        miso_i
    );

   function integer ceil_log2;
      input integer arg;
      begin
         ceil_log2 = 0;
         while ((2 ** ceil_log2) < arg)
           ceil_log2 = ceil_log2 + 1;
      end
   endfunction

   localparam CLK_STEPS = (SCK_PERIOD_MULTIPLIER+1)/2;

   wire       clk_gate;

   generate
      if (CLK_STEPS <= 1) begin : u_single_clk_period
         assign clk_gate = 1'b1;
      end else begin : u_multiple_clk_periods
         reg [ceil_log2(CLK_STEPS)-1:0] clk_cnt_q;

         assign clk_gate = ({1'b0, clk_cnt_q} == CLK_STEPS-1) ? 1'b1 : 1'b0;

         always @(posedge clk_i or negedge rstn_i) begin
            if (~rstn_i) begin
               clk_cnt_q <= 'd0;
            end else begin
               if ({1'b0, clk_cnt_q} == CLK_STEPS-1)
                 clk_cnt_q <= 'd0;
               else
                 clk_cnt_q <= clk_cnt_q + 1;
            end
         end
      end
   endgenerate

   localparam [1:0] ST_RESET = 2'd0,
                    ST_IDLE = 2'd1,
                    ST_DATA_SHIFT = 2'd2,
                    ST_DATA_WAIT = 2'd3;

   reg [1:0]        state_q, state_d;
   reg [2:0]        bit_cnt_q, bit_cnt_d;
   reg [7:0]        wr_data_q, wr_data_d;
   reg [7:0]        rd_data_q, rd_data_d;
   reg              en_q, en_d;
   reg              sck_q, sck_d;

   assign csn_o = (state_q != ST_DATA_SHIFT && state_q != ST_DATA_WAIT) ? 1'b1 : 1'b0;
   assign sck_o = sck_q;
   assign mosi_o = wr_data_q[7];
   assign rd_data_o = rd_data_q;

   always @(posedge clk_i or negedge rstn_i) begin
      if (~rstn_i) begin
         state_q <= ST_RESET;
         bit_cnt_q <= 'd0;
         wr_data_q <= 'd0;
         rd_data_q <= 'd0;
         en_q <= 1'b0;
         sck_q <= 1'b0;
      end else begin
         en_q <= en_i & en_q;
         if (clk_gate) begin
            state_q <= state_d;
            bit_cnt_q <= bit_cnt_d;
            wr_data_q <= wr_data_d;
            rd_data_q <= rd_data_d;
            en_q <= en_d;
            sck_q <= sck_d;
         end
      end
   end

   reg wr_ready;
   reg rd_valid;

   wire wr_valid;
   wire rd_ready;

   assign wr_ready_o = wr_ready & clk_gate;
   assign rd_valid_o = rd_valid & clk_gate;
   assign wr_valid = wr_valid_i & en_i;
   assign rd_ready = rd_ready_i & en_i;

   always @(/*AS*/bit_cnt_q or en_i or en_q or miso_i or rd_data_q
            or rd_ready or sck_q or state_q or wr_data_i or wr_data_q
            or wr_valid) begin
      state_d = state_q;
      bit_cnt_d = bit_cnt_q;
      wr_data_d = wr_data_q;
      rd_data_d = rd_data_q;
      en_d = en_i & en_q;
      sck_d = 1'b0;
      wr_ready = 1'b0;
      rd_valid = 1'b0;

      case (state_q)
        ST_RESET : begin
           state_d = ST_IDLE;
        end
        ST_IDLE : begin
           bit_cnt_d = 'd7;
           wr_ready = 1'b1;
           if (wr_valid) begin
              en_d = 1'b1;
              wr_data_d = wr_data_i;
              state_d = ST_DATA_SHIFT;
           end
        end
        ST_DATA_SHIFT : begin
           sck_d = ~sck_q;
           if (sck_q) begin
              wr_data_d = {wr_data_q[6:0], 1'b0};
              if (bit_cnt_q == 'd0) begin
                 bit_cnt_d = 'd7;
                 rd_valid = 1'b1;
                 if (en_q) begin
                    wr_ready = 1'b1;
                    if (wr_valid) begin
                       wr_data_d = wr_data_i;
                    end else
                      state_d = ST_DATA_WAIT;
                 end else
                   state_d = ST_DATA_WAIT;
              end else begin
                 bit_cnt_d = bit_cnt_q - 1;
              end
           end else begin
              rd_data_d = {rd_data_q[6:0], miso_i};
           end
        end
        ST_DATA_WAIT : begin
           bit_cnt_d = 'd7;
           if (en_q) begin
              wr_ready = 1'b1;
              if (wr_valid) begin
                 wr_data_d = wr_data_i;
                 state_d = ST_DATA_SHIFT;
              end else if (rd_ready) begin
                 sck_d = 1'b1;
                 rd_data_d = {rd_data_q[6:0], miso_i};
                 state_d = ST_DATA_SHIFT;
              end
           end else
             state_d = ST_IDLE;
        end
        default : begin
           bit_cnt_d = 'd7;
           state_d = ST_IDLE;
        end
      endcase
   end
endmodule
