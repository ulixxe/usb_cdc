
module sync
  (
   input        rstn_i,

   input        iclk_i,
   input [7:0]  idata_i,
   input        ivalid_i,
   output       iready_o,

   input        oclk_i,
   output [7:0] odata_o,
   output       ovalid_o,
   input        oready_i
   );

   reg [1:0]    iready_sq;
   reg          iready_mask_q;
   reg [7:0]    idata_q;

   assign iready_o = iready_sq[0] & ~iready_mask_q;

   always @(posedge iclk_i or negedge rstn_i) begin
      if (~rstn_i) begin
         iready_sq <= 2'b00;
         iready_mask_q <= 1'b0;
         idata_q <= 8'd0;
      end else begin
         iready_sq <= {~ovalid_mask_q, iready_sq[1]};
         if (~iready_sq[0])
           iready_mask_q <= 1'b0;
         else if (ivalid_i & ~iready_mask_q) begin
            idata_q <= idata_i;
            iready_mask_q <= 1'b1;
         end
      end
   end

   reg [1:0] ovalid_sq;
   reg       ovalid_mask_q;

   assign ovalid_o = ovalid_sq[0] & ~ovalid_mask_q;
   assign odata_o = idata_q;

   always @(posedge oclk_i or negedge rstn_i) begin
      if (~rstn_i) begin
         ovalid_sq <= 2'b00;
         ovalid_mask_q <= 1'b0;
      end else begin
         ovalid_sq <= {iready_mask_q, ovalid_sq[1]};
         if (~ovalid_sq[0])
           ovalid_mask_q <= 1'b0;
         else if (oready_i & ~ovalid_mask_q)
           ovalid_mask_q <= 1'b1;
      end
   end
endmodule


