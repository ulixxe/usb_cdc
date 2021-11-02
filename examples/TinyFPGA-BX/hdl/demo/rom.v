
`define max(a,b)((a) > (b) ? (a) : (b))
`define min(a,b)((a) < (b) ? (a) : (b))

module rom
  #(parameter VECTOR_LENGTH = 'd512,
    parameter WORD_WIDTH = 'd16,  // 8, 16 or 32
    parameter ADDR_WIDTH = ceil_log2(VECTOR_LENGTH))
   (
    output [WORD_WIDTH-1:0] data_o,
    input                   clk_i,
    input                   clke_i,
    input [ADDR_WIDTH-1:0]  addr_i
    );

   function integer ceil_log2;
      input integer         arg;
      begin
         ceil_log2 = 0;
         while ((2 ** ceil_log2) < arg)
           ceil_log2 = ceil_log2 + 1;
      end
   endfunction

   wire [31:0] rdata32;
   wire [7:0]  addr;

   generate
      if (WORD_WIDTH == 'd8) begin : u_8bit
         reg byte_addr_q;

         assign data_o = byte_addr_q ? rdata32[15:8] : rdata32[7:0];
         assign addr = addr_i[`min(8,ADDR_WIDTH-1):1];

         always @(posedge clk_i) begin
            if (clke_i)
              byte_addr_q <= addr_i[0];
         end
      end else if (WORD_WIDTH == 'd16) begin : u_16bit
         assign data_o = rdata32[15:0];
         assign addr = addr_i[`min(7,ADDR_WIDTH-1):0];
      end else begin : u_32bit
         assign data_o = rdata32;
         assign addr = addr_i[`min(7,ADDR_WIDTH-1):0];
      end
   endgenerate

   localparam ROM_WORDS = (WORD_WIDTH == 'd32) ? 2 : 1;
   localparam ROM_BLOCKS = (((WORD_WIDTH == 'd8) ? (VECTOR_LENGTH+1)/2 : VECTOR_LENGTH)+255)/256;
   wire [16*ROM_BLOCKS*ROM_WORDS-1:0] rdata;
   wire [`max(ceil_log2(ROM_BLOCKS)-1, 0):0] block_addr;

   generate
      if (ROM_BLOCKS > 1) begin : u_multi_bank
         reg [ceil_log2(ROM_BLOCKS)-1:0] block_addr_q;

         assign block_addr = addr_i[ADDR_WIDTH-1 -:ceil_log2(ROM_BLOCKS)];
         assign rdata32[15:0] = rdata[16*ROM_WORDS*block_addr_q +:16];
         if (ROM_WORDS > 1) begin : u_high_word
            assign rdata32[31:16] = rdata[16*(ROM_WORDS*block_addr_q+1) +:16];
         end

         always @(posedge clk_i) begin
            if (clke_i)
              block_addr_q <= block_addr;
         end
      end else begin : u_single_bank
         assign block_addr = 0;
         assign rdata32[15:0] = rdata[15:0];
         if (ROM_WORDS > 1) begin : u_high_word
            assign rdata32[31:16] = rdata[31:16];
         end
      end
   endgenerate

   localparam [256*16*2-1:0] ROM_DATA = {256'h6D331DDB26D153A5B677F5093BBB2DDF689DAC0074F3292285BEA438F37C2984,
                                         256'h5537818752892D52892CC66E0799AFD3439EB6F21668948E6E7D38998BFDB692,
                                         256'h012235F6270610D0670129736137B590494FFF2A11C294B22415529CB4E76DC1,
                                         256'h1991AAE9DB1381A74C2505F0160D0426A7E0E3A1A18F18F73AE7E63FCB45E36D,
                                         256'h8D508E74DF4C083652BF4BA8C8A9A103A9807CB69AAF546E3744DF9BB3DA4499,
                                         256'hCCD2F056C832A3122E81F9D3EF6F6BC79B1E442FFF413C2A2468DEF0BFF3954B,
                                         256'hF62F9CA07F8607AA3C9BD09B2F7ED8B0F084AC6E0873A14E36BD492B29EA1617,
                                         256'h70BD1BE5E40980220D504634930E82ACE905A24DE8030FADF6AE572B69E7A6B0,
                                         256'h2EB97F3B3CEC95526D43F131750ECCA56A389B00BEAA3E64B0525F450ACB164D,
                                         256'h347C301CDB370650D88A2AEC52C14C9D9A0CE27FB988AD066D6DF60FDF3F7FB4,
                                         256'h43C7E94CD1B7C9FECBA311F3A06C10D84CD13ADF67337DCDA8D0DE715987F3B3,
                                         256'hDFDF779E14A1000A6E4DC1431CDDD932CF3D99E642AE2EF5CAE093C9F73D61AB,
                                         256'h04091CA820D4B1774E22802335C2D1AAA44426CD5C2CF6D52FCF8DCE8B469C66,
                                         256'hA03E404CC381CDA9DCC1A70BA0F3F067E22F65D4E456C6DC9E08E532D4CD7A7D,
                                         256'hBC44068112661B60E9CA7768AD20D81FF9C769A60EEF63039E091DCAE008B745,
                                         256'h28A87B0CF7112A239C329C5D04C6DC84C42ADB328B66203DB44B1324CE8C003A,
                                         256'hD7A5C3CD0203DD451D4E48774153A7FAC62AAB526D6637A3A4E91D4211D72405,
                                         256'hC91DC8CC90377F1EA3BD9DFD5B76EC44E3BE7C42DD912E60D7713513AD8904CB,
                                         256'h0E7E3FD65E9FE9D4E09E2DF878ABCDD7958610730BD3C52DCEB19CCB365A1E7B,
                                         256'h5C05AA6573A66EC30543476D4ED7AF7458CF1436A8FACD38D940D72460683ED3,
                                         256'h82973E47B9E62E45A6D5A6EF61DDFD205D0B932CBEB0E4D75B9B5232355E5E79,
                                         256'h555DC8BC5B111C1E6CA30C14C14E17FE3DB60C663AD22D7AD465955F2F541260,
                                         256'h83007D7E943D305F62F1B974EE8545175DC423C95AE9A8D794568AF6B9809E4E,
                                         256'hF594CE66FB6668C44BE805CC4CE3E24C0653429E0F4B4B283328034E2132BE6C,
                                         256'h4CAE3CA135E4A1687C6867CF412EB915158990B50EA16A84B8D1698D763001BD,
                                         256'hD3493CF28ADE5F98B7F21218171FF47E634EA49C4E491E7CFD67A5DC8FB2A378,
                                         256'hCF1CE078B591D073D6A82ACE248A7F25BF035D2F71B5EB659A4F407E2D88E9CC,
                                         256'h0CD51007D1C56720D8B4F5D58B6EFED77B9947109D85A7603021AC6633F83953,
                                         256'h8B552F6D6227BF85C9E5031FE0139BD1F3B6EE57F9DF9B0FE61A10F529F9636C,
                                         256'hE4D333CD6DE06FBAF6E0847725216D416357B51B9A09B47BB1B3817667708D93,
                                         256'hD07F8C6DBD91B75A8C81BD4B1009248657FEA9EA0C88EA3AB5F7F9318920C642,
                                         256'h6CA93E9696812BC756AA23ABA720A1B0F76A1F284C757BF364505334F670FF6B};

   genvar                    i,j;

   generate
      for (i = 0; i < ROM_BLOCKS; i = i+1) begin : u_rom_blocks
         wire re;

         assign re = (i == block_addr) ? 1'b1 : 1'b0;

         for (j = 0; j < ROM_WORDS; j = j+1) begin : u_rom_words
            SB_RAM256x16 #(.INIT_0(ROM_DATA[256*((ROM_WORDS*(0+16*i)+j)%(2*16)) +:256]),
                           .INIT_1(ROM_DATA[256*((ROM_WORDS*(1+16*i)+j)%(2*16)) +:256]),
                           .INIT_2(ROM_DATA[256*((ROM_WORDS*(2+16*i)+j)%(2*16)) +:256]),
                           .INIT_3(ROM_DATA[256*((ROM_WORDS*(3+16*i)+j)%(2*16)) +:256]),
                           .INIT_4(ROM_DATA[256*((ROM_WORDS*(4+16*i)+j)%(2*16)) +:256]),
                           .INIT_5(ROM_DATA[256*((ROM_WORDS*(5+16*i)+j)%(2*16)) +:256]),
                           .INIT_6(ROM_DATA[256*((ROM_WORDS*(6+16*i)+j)%(2*16)) +:256]),
                           .INIT_7(ROM_DATA[256*((ROM_WORDS*(7+16*i)+j)%(2*16)) +:256]),
                           .INIT_8(ROM_DATA[256*((ROM_WORDS*(8+16*i)+j)%(2*16)) +:256]),
                           .INIT_9(ROM_DATA[256*((ROM_WORDS*(9+16*i)+j)%(2*16)) +:256]),
                           .INIT_A(ROM_DATA[256*((ROM_WORDS*(10+16*i)+j)%(2*16)) +:256]),
                           .INIT_B(ROM_DATA[256*((ROM_WORDS*(11+16*i)+j)%(2*16)) +:256]),
                           .INIT_C(ROM_DATA[256*((ROM_WORDS*(12+16*i)+j)%(2*16)) +:256]),
                           .INIT_D(ROM_DATA[256*((ROM_WORDS*(13+16*i)+j)%(2*16)) +:256]),
                           .INIT_E(ROM_DATA[256*((ROM_WORDS*(14+16*i)+j)%(2*16)) +:256]),
                           .INIT_F(ROM_DATA[256*((ROM_WORDS*(15+16*i)+j)%(2*16)) +:256]))
            u_ram256x16 (.RDATA(rdata[16*(ROM_WORDS*i+j) +:16]),
                         .RADDR(addr),
                         .RCLK(clk_i),
                         .RCLKE(clke_i),
                         .RE(re),
                         .WADDR(8'd0),
                         .WCLK(1'b0),
                         .WCLKE(1'b0),
                         .WDATA(16'b0),
                         .WE(1'b0),
                         .MASK(16'b0));
         end
      end
   endgenerate
endmodule
