
`define max(a,b)((a) > (b) ? (a) : (b))
`define min(a,b)((a) < (b) ? (a) : (b))

module ram
  #(parameter VECTOR_LENGTH = 'd512,
    parameter WORD_WIDTH = 'd16,
    parameter ADDR_WIDTH = ceil_log2(VECTOR_LENGTH))
   (
    output [WORD_WIDTH-1:0] rdata_o,
    input                   clk_i,
    input                   clke_i,
    input                   we_i,
    input [ADDR_WIDTH-1:0]  addr_i,
    input [WORD_WIDTH-1:0]  mask_i,
    input [WORD_WIDTH-1:0]  wdata_i
    );

   function integer ceil_log2;
      input integer         arg;
      begin
         ceil_log2 = 0;
         while ((2 ** ceil_log2) < arg)
           ceil_log2 = ceil_log2 + 1;
      end
   endfunction

   wire [7:0]  addr;
   wire [31:0] rdata32;
   wire [31:0] wdata32;
   wire [31:0] mask32;

   generate
      if (WORD_WIDTH == 'd8) begin : u_8bit
         reg byte_addr_q;

         assign rdata_o = byte_addr_q ? rdata32[15:8] : rdata32[7:0];
         assign addr = addr_i[`min(8,ADDR_WIDTH-1):1];
         assign wdata32 = {16'h0000, wdata_i, wdata_i};
         assign mask32 = (addr_i[0] == 1'b0) ? {16'hFFFF, 8'hFF, mask_i} : {16'hFFFF, mask_i, 8'hFF};

         always @(posedge clk_i) begin
            if (clke_i ==1'b1 && we_i == 1'b0)
              byte_addr_q <= addr_i[0];
         end
      end else if (WORD_WIDTH == 'd16) begin : u_16bit
         assign rdata_o = rdata32[15:0];
         assign addr = addr_i[`min(7,ADDR_WIDTH-1):0];
         assign wdata32 = {16'h0000, wdata_i};
         assign mask32 = {16'hFFFF, mask_i};
      end else begin : u_32bit
         assign rdata_o = rdata32;
         assign addr = addr_i[`min(7,ADDR_WIDTH-1):0];
         assign wdata32 = wdata_i;
         assign mask32 = mask_i;
      end
   endgenerate

   localparam RAM_WORDS = (WORD_WIDTH == 'd32) ? 2 : 1;
   localparam RAM_BLOCKS = (((WORD_WIDTH == 'd8) ? (VECTOR_LENGTH+1)/2 : VECTOR_LENGTH)+255)/256;
   wire [16*RAM_BLOCKS*RAM_WORDS-1:0] rdata;
   wire [`max(ceil_log2(RAM_BLOCKS)-1, 0):0] block_addr;

   generate
      if (RAM_BLOCKS > 1) begin : u_multi_bank
         reg [ceil_log2(RAM_BLOCKS)-1:0] block_addr_q;

         assign block_addr = addr_i[ADDR_WIDTH-1 -:ceil_log2(RAM_BLOCKS)];
         assign rdata32[15:0] = rdata[16*RAM_WORDS*block_addr_q +:16];
         if (RAM_WORDS > 1) begin : u_high_word
            assign rdata32[31:16] = rdata[16*(RAM_WORDS*block_addr_q+1) +:16];
         end

         always @(posedge clk_i) begin
            if (clke_i == 1'b1 && we_i == 1'b0)
              block_addr_q <= block_addr;
         end
      end else begin : u_single_bank
         assign block_addr = 0;
         assign rdata32[15:0] = rdata[15:0];
         if (RAM_WORDS > 1) begin : u_high_word
            assign rdata32[31:16] = rdata[31:16];
         end
      end
   endgenerate

   localparam [256*16*2-1:0] RAM_DATA = {256'hC1D4816ED2646D089AE661690164DABE1B873D7F8EC3AF7D8C7DA5C43F9743CD,
                                         256'hC2FA7C36540E7700BDAC2AFFF42F77777F077A45A204B6274AE8965088EAA7DE,
                                         256'h83863B4C3D0D002FEDA8C8806A7BC889D79C5AAE9736B416E9D6DA525773D584,
                                         256'h4A0B90E9CDA6050D51719A2267926CBA03855F698F55CA97178015499BF1B937,
                                         256'h96CE2E60E1513C6FF180F8F9311D6130777B3F337A0AEC075E278893A872436F,
                                         256'hB0F7D959D47313F7C2130EDC97E63C4FCAE3CAA66C823BC63EA4F7684CF29649,
                                         256'hDA32ACFEF1B1AF8C261DA967BB797182429BF220CF49C388C903BA1A36D3C986,
                                         256'h3B5D98A13C514ECD18A7BA4FB34891B3309FBACE1907F5A134247D57D90A325B,
                                         256'h3CF03A082F42F0B4D4F6BF9D0A2D6EB16E2BA8BC4E943C31C31D73120C1975D9,
                                         256'hB32852C021BCD1A3DD59887C4C6E49435C5C08180B267667F7FBD044DE82BF74,
                                         256'h78839C7F82B455D8FF1BCC32EE5FE613E221369A55CEE4B9391E1F5B7805FBF8,
                                         256'h61103711B59FACD8277E00A69ADD8A95C9A1F57D36A338268429586157D6D3FC,
                                         256'hF3D27A5C509539F960CA39F2071F7DB19227CAB90A66D0EC4A5A9BFE1B1C3D62,
                                         256'h3627910C12045120AAEBEB2614142A709F85B4510BAE7A7DA7A9A098E1D74564,
                                         256'hAC0890217D4DE966E44E68D1B36111C8D35D87573182754ABF29B7BFFBB8555D,
                                         256'h4964D879A2D4826B1F68D49D1EF07EDF7DE586970A1304E902EF7754D722C8FF,
                                         256'hABAC0E61FE578C814D146F0F2707AFE0EE2A22EB0FE41881DD80BE2727E1C9F6,
                                         256'h5A5E34C6B6454ACA633B8730DACB19A3DD74E8B93672CC2E17BBBBC583EB66B8,
                                         256'h08C7DEA00021F84186CA1F14329D83CFAF6ABE1015AAD6BE901C534EDAD49EB4,
                                         256'hE2C09734B901B715DF59B2AC37504F9113FE7166FE00223DD3579BD73AB3817C,
                                         256'hA6B0E6F8E6375000F84D79DB4613BD1A48872F850CF87FAAC7DD664922ACEE8A,
                                         256'h4A74546376D57AD2DAD89AD100073076BED6D224292456E276EE3D95FA052B51,
                                         256'hCB34EC22270804CEEAE6F1B8667B847651945A69658E758377A37BFF854D7C3F,
                                         256'h2F6FA55973278DC04BF19C26A2DFE912617FEACC8CE3F098099CAF98980E696C,
                                         256'h7BD8B21B22E37D4A15AAA76D6541C7932ADDD3ADD2A1E0C609FD8B57EE729721,
                                         256'h60EFC3C3C433737B47CDDF1E4BA9849FF6601365A7E6E7752A7CEF56333792EB,
                                         256'h613698187C59A3765CC248F5B5DF943B20097B779708D12A7E6723AAE792DE14,
                                         256'h0B0C6F3F9D4A10A8E6FB097C658C11F68C4C26B1E05F534AA418BED25324A246,
                                         256'h1ED9655323CE82A8E31812001FFE6AA0E8BB562B81B4E5CCB7EAFF0817ADB955,
                                         256'h4D43BF34C0A091F49F6410926E5CA9FF116D5AE344DC0362B23E788FE20D8D06,
                                         256'hDB06F2655983015722DF8BBC539FBD0430A921207E035D10CDD029D72DD727F7,
                                         256'h440A49737ED1A47239E2824653E8CEF7544C19B1B04F0B19AABAA3B447985F96};

   genvar                    i,j;

   generate
      for (i = 0; i < RAM_BLOCKS; i = i+1) begin : u_ram_blocks
         wire re, we;

         assign re = (i == block_addr && we_i == 1'b0) ? 1'b1 : 1'b0;
         assign we = (i == block_addr && we_i == 1'b1) ? 1'b1 : 1'b0;

         for (j = 0; j < RAM_WORDS; j = j+1) begin : u_ram_words
            SB_RAM256x16 #(.INIT_0(RAM_DATA[256*((RAM_WORDS*(0+16*i)+j)%(2*16)) +:256]),
                           .INIT_1(RAM_DATA[256*((RAM_WORDS*(1+16*i)+j)%(2*16)) +:256]),
                           .INIT_2(RAM_DATA[256*((RAM_WORDS*(2+16*i)+j)%(2*16)) +:256]),
                           .INIT_3(RAM_DATA[256*((RAM_WORDS*(3+16*i)+j)%(2*16)) +:256]),
                           .INIT_4(RAM_DATA[256*((RAM_WORDS*(4+16*i)+j)%(2*16)) +:256]),
                           .INIT_5(RAM_DATA[256*((RAM_WORDS*(5+16*i)+j)%(2*16)) +:256]),
                           .INIT_6(RAM_DATA[256*((RAM_WORDS*(6+16*i)+j)%(2*16)) +:256]),
                           .INIT_7(RAM_DATA[256*((RAM_WORDS*(7+16*i)+j)%(2*16)) +:256]),
                           .INIT_8(RAM_DATA[256*((RAM_WORDS*(8+16*i)+j)%(2*16)) +:256]),
                           .INIT_9(RAM_DATA[256*((RAM_WORDS*(9+16*i)+j)%(2*16)) +:256]),
                           .INIT_A(RAM_DATA[256*((RAM_WORDS*(10+16*i)+j)%(2*16)) +:256]),
                           .INIT_B(RAM_DATA[256*((RAM_WORDS*(11+16*i)+j)%(2*16)) +:256]),
                           .INIT_C(RAM_DATA[256*((RAM_WORDS*(12+16*i)+j)%(2*16)) +:256]),
                           .INIT_D(RAM_DATA[256*((RAM_WORDS*(13+16*i)+j)%(2*16)) +:256]),
                           .INIT_E(RAM_DATA[256*((RAM_WORDS*(14+16*i)+j)%(2*16)) +:256]),
                           .INIT_F(RAM_DATA[256*((RAM_WORDS*(15+16*i)+j)%(2*16)) +:256]))
            u_ram256x16 (.RDATA(rdata[16*(RAM_WORDS*i+j) +:16]),
                         .RADDR(addr),
                         .RCLK(clk_i),
                         .RCLKE(clke_i),
                         .RE(re),
                         .WADDR(addr),
                         .WCLK(clk_i),
                         .WCLKE(clke_i),
                         .WDATA(wdata32[16*j +:16]),
                         .WE(we),
                         .MASK(mask32[16*j +:16]));
         end
      end
   endgenerate
endmodule
