//  FLASH memory serial interface.
//  Written in verilog 2001

//  FLASH_SPI module shall provide access to read/program serial FLASH memory:
//    - When in_en_i/out_en_i changes from low to high, a new read/program operation shall start.
//    - Memory read shall start at byte address specified by start_block_addr_i+read_addr_offset_i.
//    - Memory programming shall start at beginning of the block addressed by start_block_addr_i.
//    - Memory read/program operation shall end at the end of the block addressed by end_block_addr_i.
//  FLASH_SPI module shall check correct block erasing and correct data programming:
//    - Erase/Programming failures shall be reported by status_o.
//    - When status_o reports a failure, FLASH_SPI shall wait a clear_status_i pulse to clear status_o
//        and to allow the next read/program operation.

`define min(a,b)((a) < (b) ? (a) : (b))

module flash_spi
  #(parameter SCK_PERIOD_MULTIPLIER = 'd2,
    parameter CLK_PERIODS_PER_US = 'd10,
    parameter FLASH_SIZE = 'd1048576,
    parameter BLOCK_SIZE = 'd4096,
    parameter PAGE_SIZE = 'd256,
    parameter RESUME_US = 'd10,
    parameter BLOCK_ERASE_US = 'd60000,
    parameter PAGE_PROG_US = 'd700)
   (
    input                                                   clk_i,
    input                                                   rstn_i,
    // While rstn_i is low (active low), the module shall be reset

    // ---- to/from application module --------------
    input                                                   out_en_i,
    // When out_en_i changes from low to high, a new program operation shall start.
    // When out_en_i changes from high to low, the current program operation shall end.
    input                                                   in_en_i,
    // When in_en_i changes from low to high, a new read operation shall start.
    // When in_en_i changes from high to low, the current read operation shall end.
    input [ceil_log2(FLASH_SIZE)-ceil_log2(BLOCK_SIZE)-1:0] start_block_addr_i,
    input [ceil_log2(FLASH_SIZE)-ceil_log2(BLOCK_SIZE)-1:0] end_block_addr_i,
    input [ceil_log2(BLOCK_SIZE)-1:0]                       read_addr_offset_i,
    input [7:0]                                             out_data_i,
    // While out_valid_i is high, the out_data_i shall be valid.
    input                                                   out_valid_i,
    // When both out_en_i and out_valid_i change from low to high, a new programming
    //   operation shall start.
    output                                                  out_ready_o,
    // While out_en_i is high and when both out_valid_i and out_ready_o are high, out_data_i
    //   shall be consumed.
    output [7:0]                                            in_data_o,
    // While in_valid_o is high, the in_data_o shall be valid.
    output                                                  in_valid_o,
    // While in_en_i is high and when both in_valid_o and in_ready_i are high, in_data_o
    //   shall be consumed by application module.
    // in_valid_o shall be high only for one clk_i period.
    input                                                   in_ready_i,
    // When both in_en_i and in_ready_i change from low to high, a new read
    //   operation shall start.
    input                                                   clear_status_i,
    // While status_o reports an error or the end of programming/read operation (4'bF),
    //   when clear_status_i is high, status_o shall be cleared to 4'h0.
    output [3:0]                                            status_o,
    // status_o shall report an error (4'h5, 4'h7 or 4'h8) or the end of a correct
    //   programming/read operation (4'hF), otherwise shall be 4'h0.
    output                                                  erase_busy_o,
    output                                                  program_busy_o,

    // ---- to/from serial bus ----------------------
    output                                                  sck_o,
    output                                                  csn_o,
    output                                                  mosi_o,
    input                                                   miso_i
    );

   function integer ceil_log2;
      input integer                                         arg;
      begin
         ceil_log2 = 0;
         while ((2 ** ceil_log2) < arg)
           ceil_log2 = ceil_log2 + 1;
      end
   endfunction

   function [15:0] crc16;
      input [7:0] data;
      input [15:0] crc;
      localparam [15:0] POLY16 = 16'h8005;
      reg [3:0]         i;
      begin
         crc16 = crc;
         for (i = 0; i <= 7; i = i + 1) begin
            if ((data[i[2:0]] ^ crc16[15]) == 1'b1)
              crc16 = {crc16[14:0], 1'b0} ^ POLY16;
            else
              crc16 = {crc16[14:0], 1'b0};
         end
      end
   endfunction

   localparam [3:0] STATUS_OK = 4'h0,
                    STATUS_errCHECK_ERASED = 4'h5,
                    STATUS_errVERIFY = 4'h7,
                    STATUS_errADDRESS = 4'h8,
                    STATUS_END = 4'hF;

   localparam [7:0] FLASH_CMD_RESUME_DPD = 8'hAB,
                    FLASH_CMD_DATA_READ = 8'h0B,
                    FLASH_CMD_DPD = 8'hB9,
                    FLASH_CMD_WRITE_ENABLE = 8'h06,
                    FLASH_CMD_4KB_ERASE = 8'h20,
                    FLASH_CMD_SR1_READ = 8'h05,
                    FLASH_CMD_DATA_WRITE = 8'h02;

   localparam [4:0] ST_IDLE = 'd0,
                    ST_RESUME_DPD = 'd1,
                    ST_RD_DATA_CMD = 'd2,
                    ST_RD_DATA = 'd3,
                    ST_WR_ERASE_ENABLE = 'd4,
                    ST_WR_ERASE = 'd5,
                    ST_WR_ERASE_STATUS = 'd6,
                    ST_WR_ERASE_RD_DATA_CMD = 'd7,
                    ST_WR_ERASE_RD_DATA = 'd8,
                    ST_WR_ERASE_END = 'd9,
                    ST_WR_ERASE_ERROR = 'd10,
                    ST_WR_DATA_ENABLE = 'd11,
                    ST_WR_DATA_CMD = 'd12,
                    ST_WR_DATA = 'd13,
                    ST_WR_EOP = 'd14,
                    ST_WR_DATA_STATUS = 'd15,
                    ST_WR_RD_DATA_CMD = 'd16,
                    ST_WR_RD_DATA = 'd17,
                    ST_WR_DATA_CHECK = 'd18,
                    ST_WR_DATA_ERROR = 'd19,
                    ST_WR_ADDR_ERROR = 'd20,
                    ST_DPD = 'd21,
                    ST_DPD_END = 'd22,
                    ST_END = 'd23;

   localparam       BYTE_CNT_WIDTH = ceil_log2(PAGE_SIZE);
   localparam       PAGE_ADDR_WIDTH = ceil_log2(FLASH_SIZE)-BYTE_CNT_WIDTH;
   localparam       PAGES_WIDTH = ceil_log2(BLOCK_SIZE)-BYTE_CNT_WIDTH;

   reg [BYTE_CNT_WIDTH-1:0] byte_cnt_q, byte_cnt_d;
   reg [BYTE_CNT_WIDTH-1:0] last_byte_q, last_byte_d;
   reg [PAGE_ADDR_WIDTH-1:0] page_addr_q, page_addr_d;
   reg [4:0]                 state_q, state_d;
   reg [15:0]                wait_cnt_q, wait_cnt_d;
   reg [15:0]                crc16_q, crc16_d;
   reg                       out_en_q, out_en_d;
   reg                       in_en_q, in_en_d;

   always @(posedge clk_i or negedge rstn_i) begin
      if (~rstn_i) begin
         state_q <= ST_IDLE;
         byte_cnt_q <= 'd0;
         page_addr_q <= 'd0;
         wait_cnt_q <= 'd0;
         crc16_q <= 16'd0;
         last_byte_q <= 'd0;
         out_en_q <= 1'b0;
         in_en_q <= 1'b0;
      end else begin
         state_q <= state_d;
         byte_cnt_q <= byte_cnt_d;
         page_addr_q <= page_addr_d;
         wait_cnt_q <= wait_cnt_d;
         crc16_q <= crc16_d;
         last_byte_q <= last_byte_d;
         out_en_q <= out_en_d;
         in_en_q <= in_en_d;
      end
   end

   reg        spi_en;
   reg [7:0]  spi_wr_data;
   reg        spi_wr_valid;
   reg        spi_rd_ready;
   reg [7:0]  in_data;
   reg        in_valid;
   reg        out_ready;
   reg [23:0] cmd_addr;
   reg [23:0] cmd_rdaddr;

   wire       spi_wr_ready;
   wire [7:0] spi_rd_data;
   wire       spi_rd_valid;
   wire       out_valid;
   wire       in_ready;

   assign in_data_o = in_data;
   assign in_valid_o = in_valid;
   assign out_ready_o = out_ready;
   assign out_valid = out_valid_i & out_en_i;
   assign in_ready = in_ready_i & in_en_i;
   assign status_o = (state_q == ST_END) ? STATUS_END :
                     (state_q == ST_WR_ERASE_ERROR) ? STATUS_errCHECK_ERASED :
                     (state_q == ST_WR_DATA_ERROR) ? STATUS_errVERIFY :
                     (state_q == ST_WR_ADDR_ERROR) ? STATUS_errADDRESS :
                     STATUS_OK;
   assign erase_busy_o = (state_q == ST_WR_ERASE_ENABLE || state_q == ST_WR_ERASE ||
                          state_q == ST_WR_ERASE_STATUS || state_q == ST_WR_ERASE_RD_DATA_CMD ||
                          state_q == ST_WR_ERASE_RD_DATA || state_q == ST_WR_ERASE_END) ?
                         1'b1 : 1'b0;
   assign program_busy_o = (state_q == ST_WR_DATA_ENABLE || state_q == ST_WR_DATA_CMD ||
                            state_q == ST_WR_DATA || state_q == ST_WR_EOP ||
                            state_q == ST_WR_DATA_STATUS || state_q == ST_WR_RD_DATA_CMD ||
                            state_q == ST_WR_RD_DATA || state_q == ST_WR_DATA_CHECK) ?
                           1'b1 : 1'b0;

   always @(/*AS*/byte_cnt_q or clear_status_i or crc16_q
            or end_block_addr_i or in_en_i or in_en_q or in_ready
            or last_byte_q or out_data_i or out_en_i or out_en_q
            or out_valid or page_addr_q or read_addr_offset_i
            or spi_rd_data or spi_rd_valid or spi_wr_ready
            or start_block_addr_i or state_q or wait_cnt_q) begin
      state_d = state_q;
      byte_cnt_d = byte_cnt_q;
      page_addr_d = page_addr_q;
      wait_cnt_d = wait_cnt_q;
      crc16_d = crc16_q;
      last_byte_d = last_byte_q;
      out_en_d = out_en_i & out_en_q;
      in_en_d = in_en_i & in_en_q;
      spi_en = 1'b0;
      spi_wr_data = 'd0;
      spi_wr_valid = 1'b0;
      spi_rd_ready = 1'b0;
      in_data = 'd0;
      in_valid = 1'b0;
      out_ready = 1'b0;
      cmd_addr = 24'd0;
      cmd_addr[PAGE_ADDR_WIDTH-1+BYTE_CNT_WIDTH:BYTE_CNT_WIDTH] = page_addr_q;
      cmd_rdaddr = 24'd0;
      cmd_rdaddr[PAGE_ADDR_WIDTH-1+BYTE_CNT_WIDTH:BYTE_CNT_WIDTH+PAGES_WIDTH] = page_addr_q[PAGE_ADDR_WIDTH-1: PAGES_WIDTH];
      cmd_rdaddr[ceil_log2(BLOCK_SIZE)-1:0] = read_addr_offset_i;

      case (state_q)
        ST_IDLE : begin
           if (out_en_i | in_en_i) begin
              state_d = ST_RESUME_DPD;
              if (in_en_i)
                in_en_d = 1'b1;
              else
                out_en_d = 1'b1;
           end
           byte_cnt_d = 'd0;
           wait_cnt_d = 'd0;
        end
        ST_RESUME_DPD : begin
           case (byte_cnt_q)
             'd0 : begin
                spi_en = 1'b1;
                spi_wr_data = FLASH_CMD_RESUME_DPD;
                spi_wr_valid = 1'b1;
                if (spi_wr_ready == 1'b1)
                  byte_cnt_d = byte_cnt_q + 1;
             end
             'd1 : begin
                if (spi_rd_valid == 1'b1)
                  byte_cnt_d = byte_cnt_q + 1;
             end
             'd2 : begin // wait to resume from Deep Power Down
                wait_cnt_d = wait_cnt_q + 1;
                if (wait_cnt_q == `min(RESUME_US*CLK_PERIODS_PER_US+(SCK_PERIOD_MULTIPLIER+1)/2, {16{1'b1}})) begin
                   byte_cnt_d = byte_cnt_q + 1;
                   wait_cnt_d = 'd0;
                end
             end
             default : begin
                if (~(out_en_q | in_en_q)) begin
                   state_d = ST_DPD;
                   byte_cnt_d = 'd0;
                end else if (in_en_q & in_ready) begin
                   state_d = ST_RD_DATA_CMD;
                   byte_cnt_d = 'd0;
                end else if (out_en_q & out_valid) begin
                   state_d = ST_WR_ERASE_ENABLE;
                   byte_cnt_d = 'd0;
                end
                page_addr_d[PAGE_ADDR_WIDTH-1:PAGES_WIDTH] = start_block_addr_i;
                page_addr_d[PAGES_WIDTH-1:0] = {PAGES_WIDTH{1'b0}};
             end
           endcase
        end
        ST_RD_DATA_CMD : begin
           spi_en = 1'b1;
           spi_wr_valid = 1'b1;
           if (spi_wr_ready == 1'b1)
             byte_cnt_d = byte_cnt_q + 1;
           case (byte_cnt_q)
             'd0 : begin
                spi_wr_data = FLASH_CMD_DATA_READ;
             end
             'd1 : begin
                spi_wr_data = cmd_rdaddr[23:16];
             end
             'd2 : begin
                spi_wr_data = cmd_rdaddr[15:8];
             end
             'd3 : begin
                spi_wr_data = cmd_rdaddr[7:0];
             end
             'd4 : begin
                spi_wr_data = 'd0;
             end
             default : begin
                page_addr_d[PAGES_WIDTH-1:0] = read_addr_offset_i[ceil_log2(BLOCK_SIZE)-1:BYTE_CNT_WIDTH];
                if (spi_rd_valid == 1'b1) begin
                   state_d = ST_RD_DATA;
                   byte_cnt_d = read_addr_offset_i[BYTE_CNT_WIDTH-1:0];
                end
             end
           endcase
        end
        ST_RD_DATA : begin
           if (in_en_q) begin
              spi_en = 1'b1;
              in_data = spi_rd_data;
              in_valid = spi_rd_valid;
              spi_rd_ready = in_ready;
              if (spi_rd_valid & in_ready) begin
                 byte_cnt_d = byte_cnt_q + 1;
                 if (&byte_cnt_q) begin
                    page_addr_d = page_addr_q + 1;
                    if (&page_addr_q[PAGES_WIDTH-1:0] &&
                        page_addr_q[PAGE_ADDR_WIDTH-1:PAGES_WIDTH] == end_block_addr_i)
                      in_en_d = 'b0;
                 end
              end
           end else begin
              state_d = ST_DPD_END;
              byte_cnt_d = 'd0;
           end
        end
        ST_WR_ERASE_ENABLE : begin
           case (byte_cnt_q)
             'd0 : begin
                spi_en = 1'b1;
                spi_wr_data = FLASH_CMD_WRITE_ENABLE;
                spi_wr_valid = 1'b1;
                if (spi_wr_ready == 1'b1)
                  byte_cnt_d = byte_cnt_q + 1;
             end
             default : begin
                state_d = ST_WR_ERASE;
                byte_cnt_d = 'd0;
             end
           endcase
        end
        ST_WR_ERASE : begin
           case (byte_cnt_q)
             'd0 : begin
                spi_en = 1'b1;
                spi_wr_data = FLASH_CMD_4KB_ERASE;
                spi_wr_valid = 1'b1;
                if (spi_wr_ready == 1'b1)
                  byte_cnt_d = byte_cnt_q + 1;
             end
             'd1 : begin
                spi_en = 1'b1;
                spi_wr_data = cmd_addr[23:16];
                spi_wr_valid = 1'b1;
                if (spi_wr_ready == 1'b1)
                  byte_cnt_d = byte_cnt_q + 1;
             end
             'd2 : begin
                spi_en = 1'b1;
                spi_wr_data = cmd_addr[15:8];
                spi_wr_valid = 1'b1;
                if (spi_wr_ready == 1'b1)
                  byte_cnt_d = byte_cnt_q + 1;
             end
             'd3 : begin
                spi_en = 1'b1;
                spi_wr_data = cmd_addr[7:0];
                spi_wr_valid = 1'b1;
                if (spi_wr_ready == 1'b1)
                  byte_cnt_d = byte_cnt_q + 1;
             end
             default : begin
                state_d = ST_WR_ERASE_STATUS;
                byte_cnt_d = 'd0;
                wait_cnt_d = 'd0;
             end
           endcase
        end
        ST_WR_ERASE_STATUS : begin
           case (byte_cnt_q)
             'd0 : begin
                spi_en = 1'b1;
                spi_wr_data = FLASH_CMD_SR1_READ;
                spi_wr_valid = 1'b1;
                if (spi_wr_ready == 1'b1)
                  byte_cnt_d = byte_cnt_q + 1;
             end
             'd1 : begin
                spi_en = 1'b1;
                if (spi_rd_valid == 1'b1)
                  byte_cnt_d = byte_cnt_q + 1;
             end
             'd2 : begin
                spi_en = 1'b1;
                spi_rd_ready = 1'b1;
                if (spi_rd_valid == 1'b1) begin
                   if (spi_rd_data[0] == 1'b0) begin
                      byte_cnt_d = byte_cnt_q + 1;
                   end else begin
                      byte_cnt_d = 'd4;
                   end
                end
             end
             'd3 : begin
                state_d = ST_WR_ERASE_RD_DATA_CMD;
                byte_cnt_d = 'd0;
             end
             default : begin // wait before next status check
                wait_cnt_d = wait_cnt_q + 1;
                if (wait_cnt_q == `min(BLOCK_ERASE_US*CLK_PERIODS_PER_US/10, {16{1'b1}})) begin
                   byte_cnt_d = 'd0;
                   wait_cnt_d = 'd0;
                end
             end
           endcase
        end
        ST_WR_ERASE_RD_DATA_CMD : begin
           spi_en = 1'b1;
           spi_wr_valid = 1'b1;
           if (spi_wr_ready == 1'b1)
             byte_cnt_d = byte_cnt_q + 1;
           case (byte_cnt_q)
             'd0 : begin
                spi_wr_data = FLASH_CMD_DATA_READ;
             end
             'd1 : begin
                spi_wr_data = cmd_addr[23:16];
             end
             'd2 : begin
                spi_wr_data = cmd_addr[15:8];
             end
             'd3 : begin
                spi_wr_data = cmd_addr[7:0];
             end
             'd4 : begin
                spi_wr_data = 'd0;
             end
             default : begin
                if (spi_rd_valid == 1'b1) begin
                   state_d = ST_WR_ERASE_RD_DATA;
                   page_addr_d[PAGES_WIDTH-1:0] = {PAGES_WIDTH{1'b0}};
                   byte_cnt_d = 'd0;
                end
             end
           endcase
        end
        ST_WR_ERASE_RD_DATA : begin
           spi_en = 1'b1;
           spi_rd_ready = 1'b1;
           if (spi_rd_valid) begin
              if (&spi_rd_data) begin
                 byte_cnt_d = byte_cnt_q + 1;
                 if (&byte_cnt_q) begin
                    page_addr_d = page_addr_q + 1;
                    byte_cnt_d = 'd0;
                    if (&page_addr_q[PAGES_WIDTH-1:0]) begin
                       state_d = ST_WR_ERASE_END;
                       page_addr_d = {page_addr_q[PAGE_ADDR_WIDTH-1:PAGES_WIDTH], {PAGES_WIDTH{1'b0}}};
                    end
                 end
              end else begin
                 state_d = ST_WR_ERASE_ERROR;
              end
           end
        end
        ST_WR_ERASE_END : begin
           state_d = ST_WR_DATA_ENABLE;
        end
        ST_WR_ERASE_ERROR : begin
           if (clear_status_i)
             state_d = ST_IDLE;
        end
        ST_WR_DATA_ENABLE : begin
           case (byte_cnt_q)
             'd0 : begin
                spi_en = 1'b1;
                spi_wr_data = FLASH_CMD_WRITE_ENABLE;
                spi_wr_valid = 1'b1;
                if (spi_wr_ready == 1'b1)
                  byte_cnt_d = byte_cnt_q + 1;
             end
             default : begin
                state_d = ST_WR_DATA_CMD;
                byte_cnt_d = 'd0;
             end
           endcase
        end
        ST_WR_DATA_CMD : begin
           spi_en = 1'b1;
           spi_wr_valid = 1'b1;
           if (spi_wr_ready == 1'b1)
             byte_cnt_d = byte_cnt_q + 1;
           case (byte_cnt_q)
             'd0 : begin
                spi_wr_data = FLASH_CMD_DATA_WRITE;
             end
             'd1 : begin
                spi_wr_data = cmd_addr[23:16];
             end
             'd2 : begin
                spi_wr_data = cmd_addr[15:8];
             end
             default : begin
                spi_wr_data = cmd_addr[7:0];
                crc16_d = 16'hFFFF;
                if (spi_wr_ready == 1'b1) begin
                   state_d = ST_WR_DATA;
                   byte_cnt_d = 'd0;
                end
             end
           endcase
        end
        ST_WR_DATA : begin
           if (out_en_q) begin
              spi_en = 1'b1;
              spi_wr_data = out_data_i;
              spi_wr_valid = out_valid;
              out_ready = spi_wr_ready;
              if (spi_wr_ready & out_valid) begin
                 crc16_d = crc16(out_data_i, crc16_q);
                 byte_cnt_d = byte_cnt_q + 1;
                 last_byte_d = byte_cnt_q;
                 if (&byte_cnt_q) begin
                    state_d = ST_WR_EOP; // End Of Page
                 end
              end
           end else begin
              state_d = ST_WR_DATA_STATUS;
              byte_cnt_d = 'd0;
              wait_cnt_d = 'd0;
           end
        end
        ST_WR_EOP : begin
           state_d = ST_WR_DATA_STATUS;
           byte_cnt_d = 'd0;
           wait_cnt_d = 'd0;
        end
        ST_WR_DATA_STATUS : begin
           case (byte_cnt_q)
             'd0 : begin
                spi_en = 1'b1;
                spi_wr_data = FLASH_CMD_SR1_READ;
                spi_wr_valid = 1'b1;
                if (spi_wr_ready == 1'b1)
                  byte_cnt_d = byte_cnt_q + 1;
             end
             'd1 : begin
                spi_en = 1'b1;
                if (spi_rd_valid == 1'b1)
                  byte_cnt_d = byte_cnt_q + 1;
             end
             'd2 : begin
                spi_en = 1'b1;
                spi_rd_ready = 1'b1;
                if (spi_rd_valid == 1'b1) begin
                   if (spi_rd_data[0] == 1'b0) begin
                      byte_cnt_d = byte_cnt_q + 1;
                   end else begin
                      byte_cnt_d = 'd4;
                   end
                end
             end
             'd3 : begin
                state_d = ST_WR_RD_DATA_CMD;
                byte_cnt_d = 'd0;
             end
             default : begin // wait before next status check
                wait_cnt_d = wait_cnt_q + 1;
                if (wait_cnt_q == `min(PAGE_PROG_US*CLK_PERIODS_PER_US/10, {16{1'b1}})) begin
                   byte_cnt_d = 'd0;
                   wait_cnt_d = 'd0;
                end
             end
           endcase
        end
        ST_WR_RD_DATA_CMD : begin
           spi_en = 1'b1;
           spi_wr_valid = 1'b1;
           if (spi_wr_ready == 1'b1)
             byte_cnt_d = byte_cnt_q + 1;
           case (byte_cnt_q)
             'd0 : begin
                spi_wr_data = FLASH_CMD_DATA_READ;
             end
             'd1 : begin
                spi_wr_data = cmd_addr[23:16];
             end
             'd2 : begin
                spi_wr_data = cmd_addr[15:8];
             end
             'd3 : begin
                spi_wr_data = cmd_addr[7:0];
             end
             'd4 : begin
                spi_wr_data = 'd0;
             end
             default : begin
                if (spi_rd_valid == 1'b1) begin
                   wait_cnt_d = crc16_q;
                   crc16_d = 16'hFFFF;
                   state_d = ST_WR_RD_DATA;
                   byte_cnt_d = 'd0;
                end
             end
           endcase
        end
        ST_WR_RD_DATA : begin
           spi_en = 1'b1;
           spi_rd_ready = 1'b1;
           if (spi_rd_valid) begin
              crc16_d = crc16(spi_rd_data, crc16_q);
              byte_cnt_d = byte_cnt_q + 1;
              if (byte_cnt_q == last_byte_q) begin
                 state_d = ST_WR_DATA_CHECK;
                 byte_cnt_d = 'd0;
              end
           end
        end
        ST_WR_DATA_CHECK : begin
           if (crc16_q == wait_cnt_q) begin
              byte_cnt_d = 'd0;
              if (out_en_q) begin
                 page_addr_d = page_addr_q + 1;
                 if (&page_addr_q[PAGES_WIDTH-1:0]) begin
                    if (page_addr_q[PAGE_ADDR_WIDTH-1:PAGES_WIDTH] == end_block_addr_i) begin
                       if (out_valid)
                         state_d = ST_WR_ADDR_ERROR;
                       else
                         page_addr_d = page_addr_q;
                    end else
                      state_d = ST_WR_ERASE_ENABLE;
                 end else
                   state_d = ST_WR_DATA_ENABLE;
              end else
                state_d = ST_DPD_END;
           end else begin
              state_d = ST_WR_DATA_ERROR;
           end
        end
        ST_WR_DATA_ERROR : begin
           if (clear_status_i)
             state_d = ST_IDLE;
        end
        ST_WR_ADDR_ERROR : begin
           if (clear_status_i)
             state_d = ST_IDLE;
        end
        ST_DPD, ST_DPD_END : begin
           if (byte_cnt_q == 'd0) begin
              spi_en = 1'b1;
              spi_wr_data = FLASH_CMD_DPD;
              spi_wr_valid = 1'b1;
              if (spi_wr_ready == 1'b1)
                byte_cnt_d = byte_cnt_q + 1;
           end else begin
              if (state_q == ST_DPD_END)
                state_d = ST_END;
              else
                state_d = ST_IDLE;
              byte_cnt_d = 'd0;
           end
        end
        ST_END : begin
           if (clear_status_i)
             state_d = ST_IDLE;
        end
        default : begin
           state_d = ST_IDLE;
           byte_cnt_d = 'd0;
        end
      endcase
   end

   spi #(.SCK_PERIOD_MULTIPLIER(SCK_PERIOD_MULTIPLIER))
   u_spi (.clk_i(clk_i),
          .rstn_i(rstn_i),
          .en_i(spi_en),
          .wr_data_i(spi_wr_data),
          .wr_valid_i(spi_wr_valid),
          .wr_ready_o(spi_wr_ready),
          .rd_data_o(spi_rd_data),
          .rd_valid_o(spi_rd_valid),
          .rd_ready_i(spi_rd_ready),
          .sck_o(sck_o),
          .csn_o(csn_o),
          .mosi_o(mosi_o),
          .miso_i(miso_i));
endmodule
