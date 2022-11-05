// APP module shall implement an example of application module for USB_CDC.
// APP shall:
//   - Loopback data from out_data_i to in_data_o and at the same time
//       write it on RAM.
//   - Source random data and calculated CRC32 checksum to in_data_o.
//   - Sink data from out_data_i and source calculated CRC32 checksum
//       to in_data_o.
//   - Source ROM data to in_data_o.
//   - Source RAM data to in_data_o.
//   - Source FLASH memory data to in_data_o.
//   - Sink data from out_data_i to program FLASH memory and source
//       calculated CRC32 checksum to in_data_o.
//   - Wait a programmable number of clk_i periods before sink/source each
//       8bit data.

`define max(a,b)((a) > (b) ? (a) : (b))

module app
  (
   input        clk_i,
   input        rstn_i,

   // ---- to/from USB_CDC ------------------------------------------
   output [7:0] in_data_o,
   output       in_valid_o,
   // While in_valid_o is high, in_data_o shall be valid.
   input        in_ready_i,
   // When both in_ready_i and in_valid_o are high, in_data_o shall
   //   be consumed.
   input [7:0]  out_data_i,
   input        out_valid_i,
   // While out_valid_i is high, the out_data_i shall be valid and both
   //   out_valid_i and out_data_i shall not change until consumed.
   output       out_ready_o,
   // When both out_valid_i and out_ready_o are high, the out_data_i shall
   //   be consumed.
   output       sck_o,
   output       csn_o,
   output       mosi_o,
   input        miso_i
   );

   function [31:0] crc32;
      input [7:0] data;
      input [31:0] crc;
      localparam [31:0] POLY32 = 32'h04C11DB7;
      reg [3:0]         i;
      begin
         crc32 = crc;
         for (i = 0; i <= 7; i = i + 1) begin
            if ((data[i[2:0]] ^ crc32[31]) == 1'b1)
              crc32 = {crc32[30:0], 1'b0} ^ POLY32;
            else
              crc32 = {crc32[30:0], 1'b0};
         end
      end
   endfunction
   
   function [7:0] rev8;
      input [7:0] data;
      reg [3:0]   i;
      begin
         for (i = 0; i <= 7; i = i + 1) begin
            rev8[i[2:0]] = data[7-i];
         end
      end
   endfunction

   function integer ceil_log2;
      input integer arg;
      begin
         ceil_log2 = 0;
         while ((2 ** ceil_log2) < arg)
           ceil_log2 = ceil_log2 + 1;
      end
   endfunction

   localparam [31:0] RESI32 = 32'hC704DD7B; // = rev32(~32'h2144DF1C)
   localparam [23:0] LFSR_POLY24 = 24'b111000010000000000000000;

   reg [1:0]         rstn_sq;

   wire              rstn;

   assign rstn = rstn_sq[0];

   always @(posedge clk_i or negedge rstn_i) begin
      if (~rstn_i) begin
         rstn_sq <= 2'd0;
      end else begin
         rstn_sq <= {1'b1, rstn_sq[1]};
      end
   end

   localparam [3:0] RESET_STATE = 4'd0,
                    LOOPBACK_STATE = 4'd1,
                    CMD0_STATE = 4'd2,
                    CMD1_STATE = 4'd3,
                    CMD2_STATE = 4'd4,
                    CMD3_STATE = 4'd5,
                    IN_STATE = 4'd6,
                    OUT_STATE = 4'd7,
                    READ0_STATE = 4'd8,
                    READ1_STATE = 4'd9,
                    READ2_STATE = 4'd10,
                    READ3_STATE = 4'd11,
                    READ_ROM_STATE = 4'd12,
                    READ_RAM_STATE = 4'd13,
                    READ_FLASH_STATE = 4'd14,
                    WRITE_FLASH_STATE = 4'd15;

   localparam [7:0] NO_CMD = 8'd0,
                    IN_CMD = 8'd1,
                    OUT_CMD = 8'd2,
                    ADDR_CMD = 8'd3,
                    WAIT_CMD = 8'd4,
                    LFSR_WRITE_CMD = 8'd5,
                    LFSR_READ_CMD = 8'd6,
                    ROM_READ_CMD = 8'd7,
                    RAM_READ_CMD = 8'd8,
                    FLASH_READ_CMD = 8'd9,
                    FLASH_WRITE_CMD = 8'd10,
                    FLASH_READ_STATUS_CMD = 8'd11,
                    FLASH_CLEAR_STATUS_CMD = 8'd12;

   localparam       ROM_SIZE = 'd1024; // byte size
   localparam       RAM_SIZE = 'd1024; // byte size
   localparam       FLASH_SIZE = 'd1048576; // byte size
   localparam       FLASH_BLOCK_SIZE = 'd4096; // byte size

   reg [7:0]        out_data_q;
   reg              out_valid_q;
   reg [3:0]        state_q, state_d;
   reg [7:0]        cmd_q, cmd_d;
   reg [31:0]       crc32_q, crc32_d;
   reg [23:0]       lfsr_q, lfsr_d;
   reg [23:0]       byte_cnt_q, byte_cnt_d;
   reg [7:0]        wait_q, wait_d;
   reg [7:0]        wait_cnt_q, wait_cnt_d;
   reg              mem_valid_q, mem_valid_d;
   reg [23:0]       mem_addr_q, mem_addr_d;
   reg              out_ready;

   wire             wait_end;
   wire             out_valid;

   assign wait_end = ~|wait_cnt_q;
   assign out_valid = out_valid_i & wait_end;
   assign out_ready_o = (~out_valid_q | out_ready) & wait_end;

   always @(posedge clk_i or negedge rstn) begin
      if (~rstn) begin
         out_data_q <= 8'd0;
         out_valid_q <= 1'b0;
         state_q <= RESET_STATE;
         cmd_q <= NO_CMD;
         crc32_q <= 32'd0;
         lfsr_q <= 24'd0;
         byte_cnt_q <= 24'd0;
         wait_q <= 8'd0;
         wait_cnt_q <= 8'd0;
         mem_valid_q <= 1'b0;
         mem_addr_q <= 'd0;
      end else begin
         if (out_valid & (~out_valid_q | out_ready)) begin
            out_data_q <= out_data_i;
            out_valid_q <= 1'b1;
         end else if (out_ready)
           out_valid_q <= 1'b0;
         state_q <= state_d;
         cmd_q <= cmd_d;
         crc32_q <= crc32_d;
         lfsr_q <= lfsr_d;
         byte_cnt_q <= byte_cnt_d;
         wait_q <= wait_d;
         if (~wait_end)
           wait_cnt_q <= wait_cnt_q - 1;
         else
           wait_cnt_q <= wait_cnt_d;
         mem_valid_q <= mem_valid_d;
         mem_addr_q <= mem_addr_d;
      end
   end

   localparam USERDATA_ADDR = 'h50000;

   reg [7:0]  in_data;
   reg        in_valid;
   reg        rom_clke;
   reg        ram_clke;
   reg        ram_we;
   reg        flash_out_en;
   reg        flash_in_en;
   reg        flash_in_ready;
   reg        flash_out_valid;
   reg        flash_clear_status;
   reg [ceil_log2(FLASH_SIZE)-ceil_log2(FLASH_BLOCK_SIZE)-1:0] start_block_addr;
   reg [ceil_log2(FLASH_SIZE)-ceil_log2(FLASH_BLOCK_SIZE)-1:0] end_block_addr;

   wire                                                        in_ready;
   wire                                                        flash_out_ready;
   wire                                                        flash_in_valid;
   wire [7:0]                                                  flash_in_data;
   wire [7:0]                                                  rom_data;
   wire [7:0]                                                  ram_rdata;
   wire [3:0]                                                  flash_status;

   assign in_data_o = in_data;
   assign in_valid_o = in_valid & wait_end;
   assign in_ready = in_ready_i & wait_end;

   always @(/*AS*/byte_cnt_q or cmd_q or crc32_q or flash_in_data
            or flash_in_valid or flash_out_ready or flash_status
            or in_ready or lfsr_q or mem_addr_q or mem_valid_q
            or out_data_q or out_valid_q or ram_rdata or rom_data
            or state_q or wait_q) begin
      state_d = state_q;
      cmd_d = cmd_q;
      crc32_d = crc32_q;
      lfsr_d = lfsr_q;
      byte_cnt_d = byte_cnt_q;
      wait_d = wait_q;
      wait_cnt_d = 8'd0;
      mem_valid_d = mem_valid_q;
      mem_addr_d = mem_addr_q;
      in_data = out_data_q;
      in_valid = 1'b0;
      out_ready = 1'b0;
      rom_clke = 1'b0;
      ram_clke = 1'b0;
      ram_we = 1'b0;
      flash_out_en = 1'b0;
      flash_in_en = 1'b0;
      start_block_addr = {(ceil_log2(FLASH_SIZE)-ceil_log2(FLASH_BLOCK_SIZE)){1'b1}};
      end_block_addr = {(ceil_log2(FLASH_SIZE)-ceil_log2(FLASH_BLOCK_SIZE)){1'b1}};
      flash_in_ready = 1'b0;
      flash_out_valid = 1'b0;
      flash_clear_status = 1'b0;

      case (state_q) 
        RESET_STATE: begin
           if (out_valid_q == 1'b1)
             state_d = LOOPBACK_STATE;
        end
        LOOPBACK_STATE: begin
           if (out_valid_q == 1'b1) begin
              if (out_data_q == 8'h00) begin
                 state_d = CMD0_STATE;
                 out_ready = 1'b1;
              end else begin
                 in_valid = 1'b1;
                 out_ready = in_ready;
                 if (in_ready == 1'b1) begin
                    ram_clke = 1'b1;
                    ram_we = 1'b1;
                    mem_addr_d = mem_addr_q + 1;
                 end
              end
           end
           if (&flash_status)
             flash_clear_status = 1'b1;
        end
        CMD0_STATE: begin
           out_ready = 1'b1;
           if (out_valid_q == 1'b1) begin
              state_d = CMD1_STATE;
              cmd_d = out_data_q;
           end
           mem_valid_d = 1'b0;
        end
        CMD1_STATE: begin
           case (cmd_q)
             IN_CMD, OUT_CMD, ROM_READ_CMD, RAM_READ_CMD, FLASH_READ_CMD, FLASH_WRITE_CMD: begin
                out_ready = 1'b1;
                if (out_valid_q == 1'b1) begin
                   state_d = CMD2_STATE;
                   byte_cnt_d[7:0] = out_data_q;
                end
             end
             ADDR_CMD: begin
                out_ready = 1'b1;
                if (out_valid_q == 1'b1) begin
                   state_d = CMD2_STATE;
                   mem_addr_d[7:0] = out_data_q;
                end
             end
             WAIT_CMD: begin
                out_ready = 1'b1;
                if (out_valid_q == 1'b1) begin
                   state_d = LOOPBACK_STATE;
                   wait_d = out_data_q;
                end
             end
             LFSR_WRITE_CMD: begin
                out_ready = 1'b1;
                if (out_valid_q == 1'b1) begin
                   state_d = CMD2_STATE;
                   lfsr_d[7:0] = out_data_q;
                end
             end
             LFSR_READ_CMD: begin
                state_d = READ0_STATE;
             end
             FLASH_READ_STATUS_CMD: begin
                state_d = READ0_STATE;
             end
             FLASH_CLEAR_STATUS_CMD: begin
                flash_clear_status = 1'b1;
                state_d = LOOPBACK_STATE;
             end
             default: begin
                state_d = LOOPBACK_STATE;
             end
           endcase
        end
        CMD2_STATE: begin
           case (cmd_q)
             IN_CMD, OUT_CMD, ROM_READ_CMD, RAM_READ_CMD, FLASH_READ_CMD, FLASH_WRITE_CMD: begin
                out_ready = 1'b1;
                if (out_valid_q == 1'b1) begin
                   state_d = CMD3_STATE;
                   byte_cnt_d[15:8] = out_data_q;
                end
             end
             ADDR_CMD: begin
                out_ready = 1'b1;
                if (out_valid_q == 1'b1) begin
                   state_d = CMD3_STATE;
                   mem_addr_d[15:8] = out_data_q;
                end
             end
             LFSR_WRITE_CMD: begin
                out_ready = 1'b1;
                if (out_valid_q == 1'b1) begin
                   state_d = CMD3_STATE;
                   lfsr_d[15:8] = out_data_q;
                end
             end
             default: begin
                state_d = LOOPBACK_STATE;
             end
           endcase
        end
        CMD3_STATE: begin
           case (cmd_q)
             IN_CMD: begin
                out_ready = 1'b1;
                if (out_valid_q == 1'b1) begin
                   state_d = IN_STATE;
                   byte_cnt_d[23:16] = out_data_q;
                end
             end
             OUT_CMD: begin
                out_ready = 1'b1;
                if (out_valid_q == 1'b1) begin
                   state_d = OUT_STATE;
                   byte_cnt_d[23:16] = out_data_q;
                end
             end
             ADDR_CMD: begin
                out_ready = 1'b1;
                if (out_valid_q == 1'b1) begin
                   state_d = LOOPBACK_STATE;
                   mem_addr_d[23:16] = out_data_q;
                end
             end
             LFSR_WRITE_CMD: begin
                out_ready = 1'b1;
                if (out_valid_q == 1'b1) begin
                   state_d = LOOPBACK_STATE;
                   lfsr_d[23:16] = out_data_q;
                end
             end
             ROM_READ_CMD: begin
                out_ready = 1'b1;
                if (out_valid_q == 1'b1) begin
                   state_d = READ_ROM_STATE;
                   byte_cnt_d[23:16] = out_data_q;
                end
             end
             RAM_READ_CMD: begin
                out_ready = 1'b1;
                if (out_valid_q == 1'b1) begin
                   state_d = READ_RAM_STATE;
                   byte_cnt_d[23:16] = out_data_q;
                end
             end
             FLASH_READ_CMD: begin
                flash_in_en = 1'b1;
                out_ready = 1'b1;
                if (out_valid_q == 1'b1) begin
                   state_d = READ_FLASH_STATE;
                   byte_cnt_d[23:16] = out_data_q;
                end
             end
             FLASH_WRITE_CMD: begin
                flash_out_en = 1'b1;
                out_ready = 1'b1;
                if (out_valid_q == 1'b1) begin
                   state_d = WRITE_FLASH_STATE;
                   byte_cnt_d[23:16] = out_data_q;
                end
                if (mem_addr_q[ceil_log2(FLASH_SIZE)-1:ceil_log2(FLASH_BLOCK_SIZE)] < USERDATA_ADDR[ceil_log2(FLASH_SIZE)-1:ceil_log2(FLASH_BLOCK_SIZE)])
                  mem_addr_d = USERDATA_ADDR;
             end
             default: begin
                state_d = LOOPBACK_STATE;
             end
           endcase
           crc32_d = 32'hFFFFFFFF;
        end
        IN_STATE: begin
           in_data = lfsr_q[7:0];
           in_valid = 1'b1;
           if (in_ready == 1'b1) begin
              crc32_d = crc32(lfsr_q[7:0], crc32_q);
              lfsr_d = {lfsr_q[22:0], ~^(lfsr_q & LFSR_POLY24)};
              if (byte_cnt_q == 24'd0)
                state_d = READ0_STATE;
              else
                byte_cnt_d = byte_cnt_q - 1;
              wait_cnt_d = wait_q;
           end
        end
        OUT_STATE: begin
           out_ready = 1'b1;
           if (out_valid_q == 1'b1) begin
              crc32_d = crc32(out_data_q, crc32_q);
              if (byte_cnt_q == 24'd0)
                state_d = READ0_STATE;
              else
                byte_cnt_d = byte_cnt_q - 1;
              wait_cnt_d = wait_q;
           end
        end
        READ0_STATE: begin
           in_valid = 1'b1;
           if (in_ready == 1'b1) begin
              state_d = READ1_STATE;
           end
           if (cmd_q == LFSR_READ_CMD)
             in_data = lfsr_q[7:0];
           else if (cmd_q == FLASH_READ_STATUS_CMD)
             in_data = {4'd0, flash_status};
           else
             in_data = rev8(~crc32_q[31:24]);
        end
        READ1_STATE: begin
           in_valid = 1'b1;
           if (in_ready == 1'b1) begin
              state_d = READ2_STATE;
           end
           if (cmd_q == LFSR_READ_CMD)
             in_data = lfsr_q[15:8];
           else if (cmd_q == FLASH_READ_STATUS_CMD)
             in_data = 8'd0;
           else
             in_data = rev8(~crc32_q[23:16]);
        end
        READ2_STATE: begin
           in_valid = 1'b1;
           if (in_ready == 1'b1) begin
              state_d = READ3_STATE;
           end
           if (cmd_q == LFSR_READ_CMD)
             in_data = lfsr_q[23:16];
           else if (cmd_q == FLASH_READ_STATUS_CMD)
             in_data = 8'd0;
           else
             in_data = rev8(~crc32_q[15:8]);
        end
        READ3_STATE: begin
           in_valid = 1'b1;
           if (in_ready == 1'b1) begin
              state_d = LOOPBACK_STATE;
           end
           if (cmd_q == LFSR_READ_CMD)
             in_data = 8'd0;
           else if (cmd_q == FLASH_READ_STATUS_CMD)
             in_data = 8'd0;
           else
             in_data = rev8(~crc32_q[7:0]);
        end
        READ_ROM_STATE: begin
           if (mem_valid_q == 1'b0) begin
              rom_clke = 1'b1;
              mem_valid_d = 1'b1;
              mem_addr_d = mem_addr_q + 1;
           end
           in_data = rom_data;
           in_valid = mem_valid_q;
           if (in_ready == 1'b1 && mem_valid_q == 1'b1) begin
              mem_valid_d = 1'b0;
              if (byte_cnt_q == 24'd0) begin
                 state_d = LOOPBACK_STATE;
                 mem_addr_d = 'd0;
              end else begin
                 byte_cnt_d = byte_cnt_q - 1;
                 rom_clke = 1'b1;
                 mem_valid_d = 1'b1;
                 mem_addr_d = mem_addr_q + 1;
              end
              wait_cnt_d = wait_q;
           end
        end
        READ_RAM_STATE: begin
           if (mem_valid_q == 1'b0) begin
              ram_clke = 1'b1;
              mem_valid_d = 1'b1;
              mem_addr_d = mem_addr_q + 1;
           end
           in_data = ram_rdata;
           in_valid = mem_valid_q;
           if (in_ready == 1'b1 && mem_valid_q == 1'b1) begin
              mem_valid_d = 1'b0;
              if (byte_cnt_q == 24'd0) begin
                 state_d = LOOPBACK_STATE;
                 mem_addr_d = 'd0;
              end else begin
                 byte_cnt_d = byte_cnt_q - 1;
                 ram_clke = 1'b1;
                 mem_valid_d = 1'b1;
                 mem_addr_d = mem_addr_q + 1;
              end
              wait_cnt_d = wait_q;
           end
        end
        READ_FLASH_STATE: begin
           flash_in_en = 1'b1;
           start_block_addr = mem_addr_q[ceil_log2(FLASH_SIZE)-1:ceil_log2(FLASH_BLOCK_SIZE)];
           end_block_addr = {(ceil_log2(FLASH_SIZE)-ceil_log2(FLASH_BLOCK_SIZE)){1'b1}};
           flash_in_ready = in_ready;
           in_data = flash_in_data;
           in_valid = flash_in_valid;
           if (|flash_status) begin  // End of operation
              flash_in_ready = 1'b0;
              in_valid = 1'b0;
              state_d = LOOPBACK_STATE;
           end else if (in_ready == 1'b1 && flash_in_valid == 1'b1) begin
              if (byte_cnt_q == 24'd0) begin
                 state_d = LOOPBACK_STATE;
              end else begin
                 byte_cnt_d = byte_cnt_q - 1;
              end
              wait_cnt_d = wait_q;
           end
        end
        WRITE_FLASH_STATE: begin
           flash_out_en = 1'b1;
           start_block_addr = mem_addr_q[ceil_log2(FLASH_SIZE)-1:ceil_log2(FLASH_BLOCK_SIZE)];
           end_block_addr = {(ceil_log2(FLASH_SIZE)-ceil_log2(FLASH_BLOCK_SIZE)){1'b1}};
           out_ready = flash_out_ready;
           flash_out_valid = out_valid_q;
           if (|flash_status) begin  // End of operation
              out_ready = 1'b1;
              flash_out_valid = 1'b0;
              if (out_valid_q) begin
                 if (byte_cnt_q == 24'd0) begin
                    state_d = READ0_STATE;
                 end else begin
                    byte_cnt_d = byte_cnt_q - 1;
                 end
              end
           end else if (out_valid_q == 1'b1 && flash_out_ready == 1'b1) begin
              crc32_d = crc32(out_data_q, crc32_q);
              if (byte_cnt_q == 24'd0) begin
                 state_d = READ0_STATE;
              end else begin
                 byte_cnt_d = byte_cnt_q - 1;
              end
              wait_cnt_d = wait_q;
           end
        end
        default: begin
           state_d = LOOPBACK_STATE;
        end
      endcase
   end

   rom #(.VECTOR_LENGTH(ROM_SIZE),
         .WORD_WIDTH('d8),
         .ADDR_WIDTH(ceil_log2(ROM_SIZE)))
   u_rom (.data_o(rom_data),
          .clk_i(clk_i),
          .clke_i(rom_clke),
          .addr_i(mem_addr_q[ceil_log2(ROM_SIZE)-1:0]));

   ram #(.VECTOR_LENGTH(RAM_SIZE),
         .WORD_WIDTH('d8),
         .ADDR_WIDTH(ceil_log2(RAM_SIZE)))
   u_ram (.rdata_o(ram_rdata),
          .clk_i(clk_i),
          .clke_i(ram_clke),
          .we_i(ram_we),
          .addr_i(mem_addr_q[ceil_log2(RAM_SIZE)-1:0]),
          .mask_i(8'd0),
          .wdata_i(out_data_q));

   flash_spi #(.SCK_PERIOD_MULTIPLIER('d2),
               .CLK_PERIODS_PER_US('d2),
               .FLASH_SIZE(FLASH_SIZE),
               .BLOCK_SIZE(FLASH_BLOCK_SIZE),
               .PAGE_SIZE('d256),
               .RESUME_US('d10),
               .BLOCK_ERASE_US('d60000),
               .PAGE_PROG_US('d700))
   u_flash_spi (.clk_i(clk_i),
                .rstn_i(rstn),
                .out_en_i(flash_out_en),
                .in_en_i(flash_in_en),
                .start_block_addr_i(start_block_addr),
                .end_block_addr_i(end_block_addr),
                .read_addr_offset_i(mem_addr_q[ceil_log2(FLASH_BLOCK_SIZE)-1:0]),
                .out_data_i(out_data_q),
                .out_valid_i(flash_out_valid),
                .out_ready_o(flash_out_ready),
                .in_data_o(flash_in_data),
                .in_valid_o(flash_in_valid),
                .in_ready_i(flash_in_ready),
                .clear_status_i(flash_clear_status),
                .status_o(flash_status),
                .erase_busy_o(),
                .program_busy_o(),
                .sck_o(sck_o),
                .csn_o(csn_o),
                .mosi_o(mosi_o),
                .miso_i(miso_i));

endmodule
