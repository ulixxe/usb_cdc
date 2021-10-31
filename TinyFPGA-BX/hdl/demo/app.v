// APP module shall implement an example of application module for USB_CDC.
// APP shall:
//   - Loopback data from out_data_i to in_data_o and at the same time
//       write it on RAM.
//   - Source random data and calculated CRC32 checksum to in_data_o.
//   - Sink data from out_data_i and source calculated CRC32 checksum
//       to in_data_o.
//   - Source ROM data to in_data_o.
//   - Source RAM data to in_data_o.
//   - Wait a programmable number of clk_i periods before sink/source each
//       8bit data.

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
   output       out_ready_o
   // When both out_valid_i and out_ready_o are high, the out_data_i shall
   //   be consumed.
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
                    READ_RAM_STATE = 4'd13;

   localparam [7:0] NO_CMD = 8'd0,
                    IN_CMD = 8'd1,
                    OUT_CMD = 8'd2,
                    WAIT_CMD = 8'd3,
                    LFSR_WRITE_CMD = 8'd4,
                    LFSR_READ_CMD = 8'd5,
                    ROM_READ_CMD = 8'd6,
                    RAM_READ_CMD = 8'd7;

   localparam       MEM_SIZE = 'd1024;

   reg [3:0]        state_q, state_d;
   reg [7:0]        cmd_q, cmd_d;
   reg [7:0]        data_q, data_d;
   reg              data_valid_q, data_valid_d;
   reg [31:0]       crc32_q, crc32_d;
   reg [23:0]       lfsr_q, lfsr_d;
   reg [23:0]       byte_cnt_q, byte_cnt_d;
   reg [7:0]        wait_q, wait_d;
   reg [7:0]        wait_cnt_q, wait_cnt_d;
   reg              mem_valid_q, mem_valid_d;
   reg [ceil_log2(MEM_SIZE)-1:0] mem_addr_q, mem_addr_d;
   reg                           read_addr_lsb_q, read_addr_lsb_d;

   always @(posedge clk_i or negedge rstn) begin
      if (~rstn) begin
         state_q <= RESET_STATE;
         cmd_q <= NO_CMD;
         data_q <= 8'd0;
         data_valid_q <= 1'b0;
         crc32_q <= 32'd0;
         lfsr_q <= 24'd0;
         byte_cnt_q <= 24'd0;
         wait_q <= 8'd0;
         wait_cnt_q <= 8'd0;
         mem_valid_q <= 1'b0;
         mem_addr_q <= 'd0;
         read_addr_lsb_q <= 1'b0;
      end else begin
         state_q <= state_d;
         cmd_q <= cmd_d;
         data_q <= data_d;
         data_valid_q <= data_valid_d;
         crc32_q <= crc32_d;
         lfsr_q <= lfsr_d;
         byte_cnt_q <= byte_cnt_d;
         wait_q <= wait_d;
         wait_cnt_q <= wait_cnt_d;
         mem_valid_q <= mem_valid_d;
         mem_addr_q <= mem_addr_d;
         read_addr_lsb_q <= read_addr_lsb_d;
      end
   end

   reg [7:0] in_data;
   reg       in_valid;
   reg       out_ready;
   reg       data_ready;
   reg       rom_clke;
   reg       ram_clke;
   reg       ram_we;

   wire [15:0] rom_data;
   wire [15:0] ram_rdata;

   assign in_data_o = in_data;
   assign in_valid_o = in_valid;
   assign out_ready_o = out_ready;

   always @(/*AS*/byte_cnt_q or cmd_q or crc32_q or data_q
            or data_valid_q or in_ready_i or lfsr_q or mem_addr_q
            or mem_valid_q or out_data_i or out_valid_i or ram_rdata
            or read_addr_lsb_q or rom_data or state_q or wait_cnt_q
            or wait_q) begin
      state_d = state_q;
      cmd_d = cmd_q;
      data_d = data_q;
      data_valid_d = data_valid_q;
      crc32_d = crc32_q;
      lfsr_d = lfsr_q;
      byte_cnt_d = byte_cnt_q;
      wait_d = wait_q;
      if (|wait_cnt_q)
        wait_cnt_d = wait_cnt_q - 1;
      else
        wait_cnt_d = 8'd0;
      mem_valid_d = mem_valid_q;
      mem_addr_d = mem_addr_q;
      read_addr_lsb_d = read_addr_lsb_q;
      in_data = data_q;
      in_valid = 1'b0;
      out_ready = 1'b0;
      data_ready = 1'b0;
      rom_clke = 1'b0;
      ram_clke = 1'b0;
      ram_we = 1'b0;

      case (state_q) 
        RESET_STATE: begin
           if (data_valid_q == 1'b1)
             state_d = LOOPBACK_STATE;
        end
        LOOPBACK_STATE: begin
           if (data_valid_q == 1'b1) begin
              if (data_q == 8'h00) begin
                 state_d = CMD0_STATE;
                 data_ready = 1'b1;
              end else begin
                 in_valid = 1'b1;
                 data_ready = in_ready_i;
                 if (in_ready_i == 1'b1) begin
                    ram_clke = 1'b1;
                    ram_we = 1'b1;
                    mem_addr_d = mem_addr_q + 1;
                 end
              end
           end
        end
        CMD0_STATE: begin
           if (data_valid_q == 1'b1) begin
              state_d = CMD1_STATE;
              cmd_d = data_q;
              data_ready = 1'b1;
           end
           mem_valid_d = 1'b0;
           mem_addr_d = 'd0;
        end
        CMD1_STATE: begin
           case (cmd_q)
             IN_CMD, OUT_CMD, ROM_READ_CMD, RAM_READ_CMD: begin
                if (data_valid_q == 1'b1) begin
                   state_d = CMD2_STATE;
                   byte_cnt_d[7:0] = data_q;
                   data_ready = 1'b1;
                end
             end
             WAIT_CMD: begin
                if (data_valid_q == 1'b1) begin
                   state_d = LOOPBACK_STATE;
                   wait_d = data_q;
                   data_ready = 1'b1;
                end
             end
             LFSR_WRITE_CMD: begin
                if (data_valid_q == 1'b1) begin
                   state_d = CMD2_STATE;
                   lfsr_d[7:0] = data_q;
                   data_ready = 1'b1;
                end
             end
             LFSR_READ_CMD: begin
                state_d = READ0_STATE;
             end
             default: begin
                state_d = LOOPBACK_STATE;
             end
           endcase
        end
        CMD2_STATE: begin
           if (data_valid_q == 1'b1) begin
              case (cmd_q)
                IN_CMD, OUT_CMD, ROM_READ_CMD, RAM_READ_CMD: begin
                   state_d = CMD3_STATE;
                   byte_cnt_d[15:8] = data_q;
                end
                LFSR_WRITE_CMD: begin
                   state_d = CMD3_STATE;
                   lfsr_d[15:8] = data_q;
                end
                default: begin
                   state_d = LOOPBACK_STATE;
                end
              endcase
              data_ready = 1'b1;
           end
        end
        CMD3_STATE: begin
           if (data_valid_q == 1'b1) begin
              case (cmd_q)
                IN_CMD: begin
                   state_d = IN_STATE;
                   byte_cnt_d[23:16] = data_q;
                end
                OUT_CMD: begin
                   state_d = OUT_STATE;
                   byte_cnt_d[23:16] = data_q;
                end
                LFSR_WRITE_CMD: begin
                   state_d = LOOPBACK_STATE;
                   lfsr_d[23:16] = data_q;
                end
                ROM_READ_CMD: begin
                   state_d = READ_ROM_STATE;
                   byte_cnt_d[23:16] = data_q;
                end
                RAM_READ_CMD: begin
                   state_d = READ_RAM_STATE;
                   byte_cnt_d[23:16] = data_q;
                end
                default: begin
                   state_d = LOOPBACK_STATE;
                end
              endcase
              data_ready = 1'b1;
           end
           crc32_d = 32'hFFFFFFFF;
        end
        IN_STATE: begin
           if (wait_cnt_q == 8'd0) begin
              if (in_ready_i == 1'b1) begin
                 crc32_d = crc32(lfsr_q[7:0], crc32_q);
                 lfsr_d = {lfsr_q[22:0], ~^(lfsr_q & LFSR_POLY24)};
                 if (byte_cnt_q == 24'd0)
                   state_d = READ0_STATE;
                 else
                   byte_cnt_d = byte_cnt_q - 1;
                 wait_cnt_d = wait_q;
              end
              in_valid = 1'b1;
           end
           in_data = lfsr_q[7:0];
        end
        OUT_STATE: begin
           if (data_valid_q == 1'b1) begin
              crc32_d = crc32(data_q, crc32_q);
              if (byte_cnt_q == 24'd0)
                state_d = READ0_STATE;
              else
                byte_cnt_d = byte_cnt_q - 1;
              data_ready = 1'b1;
           end
        end
        READ0_STATE: begin
           if (in_ready_i == 1'b1) begin
              state_d = READ1_STATE;
           end
           if (cmd_q == LFSR_READ_CMD)
             in_data = lfsr_q[7:0];
           else
             in_data = rev8(~crc32_q[31:24]);
           in_valid = 1'b1;
        end
        READ1_STATE: begin
           if (in_ready_i == 1'b1) begin
              state_d = READ2_STATE;
           end
           if (cmd_q == LFSR_READ_CMD)
             in_data = lfsr_q[15:8];
           else
             in_data = rev8(~crc32_q[23:16]);
           in_valid = 1'b1;
        end
        READ2_STATE: begin
           if (in_ready_i == 1'b1) begin
              state_d = READ3_STATE;
           end
           if (cmd_q == LFSR_READ_CMD)
             in_data = lfsr_q[23:16];
           else
             in_data = rev8(~crc32_q[15:8]);
           in_valid = 1'b1;
        end
        READ3_STATE: begin
           if (in_ready_i == 1'b1) begin
              state_d = LOOPBACK_STATE;
           end
           if (cmd_q == LFSR_READ_CMD)
             in_data = 8'd0;
           else
             in_data = rev8(~crc32_q[7:0]);
           in_valid = 1'b1;
        end
        READ_ROM_STATE: begin
           if (mem_valid_q == 1'b0) begin
              rom_clke = 1'b1;
              mem_valid_d = 1'b1;
              read_addr_lsb_d = mem_addr_q[0];
              mem_addr_d = mem_addr_q + 1;
           end
           if (wait_cnt_q == 8'd0) begin
              if (in_ready_i == 1'b1 && mem_valid_q == 1'b1) begin
                 mem_valid_d = 1'b0;
                 if (byte_cnt_q == 24'd0) begin
                    state_d = LOOPBACK_STATE;
                    mem_addr_d = 'd0;
                 end else begin
                    byte_cnt_d = byte_cnt_q - 1;
                    rom_clke = 1'b1;
                    mem_valid_d = 1'b1;
                    read_addr_lsb_d = mem_addr_q[0];
                    mem_addr_d = mem_addr_q + 1;
                 end
                 wait_cnt_d = wait_q;
              end
              in_valid = mem_valid_q;
           end
           if (read_addr_lsb_q == 1'b0)
             in_data = rom_data[7:0];
           else
             in_data = rom_data[15:8];
        end
        READ_RAM_STATE: begin
           if (mem_valid_q == 1'b0) begin
              ram_clke = 1'b1;
              mem_valid_d = 1'b1;
              read_addr_lsb_d = mem_addr_q[0];
              mem_addr_d = mem_addr_q + 1;
           end
           if (wait_cnt_q == 8'd0) begin
              if (in_ready_i == 1'b1 && mem_valid_q == 1'b1) begin
                 mem_valid_d = 1'b0;
                 if (byte_cnt_q == 24'd0) begin
                    state_d = LOOPBACK_STATE;
                    mem_addr_d = 'd0;
                 end else begin
                    byte_cnt_d = byte_cnt_q - 1;
                    ram_clke = 1'b1;
                    mem_valid_d = 1'b1;
                    read_addr_lsb_d = mem_addr_q[0];
                    mem_addr_d = mem_addr_q + 1;
                 end
                 wait_cnt_d = wait_q;
              end
              in_valid = mem_valid_q;
           end
           if (read_addr_lsb_q == 1'b0)
             in_data = ram_rdata[7:0];
           else
             in_data = ram_rdata[15:8];
        end
        default: begin
        end
      endcase

      if (out_valid_i == 1'b1 && wait_cnt_q == 8'd0 &&
          (data_valid_q == 1'b0 || data_ready == 1'b1)) begin
         data_d = out_data_i;
         data_valid_d = 1'b1;
         wait_cnt_d = wait_q;
         out_ready = 1'b1;
      end else if (data_ready == 1'b1) begin
         data_valid_d = 1'b0;
      end
   end

   wire [15:0] ram_wdata;
   wire [15:0] ram_mask;

   assign ram_wdata = {data_q, data_q};
   assign ram_mask = (mem_addr_q[0] == 1'b0) ? {{8{1'b1}}, {8{1'b0}}} : {{8{1'b0}}, {8{1'b1}}};

   rom #(.VECTOR_LENGTH(MEM_SIZE/2),
         .WORD_WIDTH('d16),
         .ADDR_WIDTH(ceil_log2(MEM_SIZE/2)),
         .INIT_FILE("./mem_files/rom.hex"))
   u_rom (.data_o(rom_data),
          .clk_i(clk_i),
          .clke_i(rom_clke),
          .addr_i(mem_addr_q[ceil_log2(MEM_SIZE)-1:1]));

   ram #(.VECTOR_LENGTH(MEM_SIZE/2),
         .WORD_WIDTH('d16),
         .ADDR_WIDTH(ceil_log2(MEM_SIZE/2)))
   u_ram (.rdata_o(ram_rdata),
          .clk_i(clk_i),
          .clke_i(ram_clke),
          .we_i(ram_we),
          .addr_i(mem_addr_q[ceil_log2(MEM_SIZE)-1:1]),
          .mask_i(ram_mask),
          .wdata_i(ram_wdata));

endmodule
