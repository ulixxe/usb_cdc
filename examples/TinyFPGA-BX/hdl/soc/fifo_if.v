// FIFO_IF module shall implement an interface for MCUs to USB_CDC FIFO.
// FIFO_IF shall:
//   - Store FIFO consumed OUT data into an internal 8bit buffer waiting
//       for the MCU to get it.
//   - Store MCU output data into an internal 8bit buffer waiting to be
//       consumed as IN data by USB_CDC FIFO.
//   - Provide internal IN/OUT buffers status to MCU.
//   - Provide pulsed IRQ to signal when IN data is consumed.
//   - Provide pulsed IRQ to signal when OUT data is consumed.

module fifo_if
  (
   input        clk_i,
   input        rstn_i,

   // ---- to/from uC -----------------------------------------------
   input        sel_i,
   input        read_i,
   input        write_i,
   input [1:0]  addr_i,
   input [7:0]  data_i,
   output [7:0] data_o,
   output       in_irq_o,
   output       out_irq_o,

   // ---- to/from USB_CDC ------------------------------------------
   output [7:0] in_data_o,
   output       in_valid_o,
   // While in_valid_o is high, in_data_o shall be valid and both
   //   in_valid_o and in_data_o shall not change until consumed.
   input        in_ready_i,
   // When both in_ready_i and in_valid_o are high, in_data_o shall
   //   be consumed.
   input [7:0]  out_data_i,
   input        out_valid_i,
   // While out_valid_i is high, the out_data_i shall be valid.
   output       out_ready_o
   // When both out_valid_i and out_ready_o are high, the out_data_i shall
   //   be consumed.
   );

   reg [7:0]    in_buffer_q;
   reg          in_valid_q;
   reg          in_irq_q;

   assign in_data_o = in_buffer_q;
   assign in_valid_o = in_valid_q;
   assign in_irq_o = in_irq_q;

   always @(posedge clk_i or negedge rstn_i) begin
      if (~rstn_i) begin
         in_buffer_q <= 8'd0;
         in_valid_q <= 1'b0;
         in_irq_q <= 1'b0;
      end else begin
         in_irq_q <= 1'b0;
         if (in_valid_q == 1'b1) begin
            if (in_ready_i == 1'b1) begin
               in_valid_q <= 1'b0;
               in_irq_q <= 1'b1;
            end
         end else
           if (write_i == 1'b1 && sel_i == 1'b1 && addr_i == 2'b01) begin
              in_buffer_q <= data_i;
              in_valid_q <= 1'b1;
           end
      end
   end

   reg [1:0]     addr_q;
   reg [7:0]     out_buffer_q;
   reg           out_ready_q;
   reg           out_irq_q;
   reg           started_q;

   assign out_ready_o = out_ready_q;
   assign out_irq_o = out_irq_q;

   always @(posedge clk_i or negedge rstn_i) begin
      if (~rstn_i) begin
         started_q <= 1'b0;
         addr_q <= 2'd0;
         out_buffer_q <= 8'd0;
         out_ready_q <= 1'b0;
         out_irq_q <= 1'b0;
      end else begin
         started_q <= 1'b1;
         if (read_i == 1'b1 && sel_i == 1'b1)
           addr_q <= addr_i;
         out_irq_q <= 1'b0;
         if ((read_i == 1'b1 && sel_i == 1'b1 && addr_i == 2'b11) || ~started_q)
           out_ready_q <= 1'b1;
         if (out_valid_i == 1'b1 && out_ready_q == 1'b1) begin
            out_buffer_q <= out_data_i;
            out_ready_q <= 1'b0;
            out_irq_q <= 1'b1;
         end
      end
   end

   reg [7:0] rdata;
   assign data_o = rdata;

   always @(/*AS*/addr_q or in_valid_q or out_buffer_q or out_ready_q) begin
      case (addr_q) 
        2'b01: begin
           rdata = {7'b0, ~in_valid_q};
        end
        2'b10: begin
           rdata = {7'b0, ~out_ready_q};
        end
        2'b11: begin
           rdata = out_buffer_q;
        end
        default: begin
           rdata = 8'b0;
        end
      endcase
   end
endmodule
