// APP module shall implement an example of application module for USB_CDC.
// APP shall:
//   - Loopback data from out_data_i to in_data_o, and at the same time:
//       - Change case if data is an alphabetic character
//       - Increase by 1 if data is a digit from 0 to 8
//       - Change 9 character to 0
//       - Transmit unchanged character for all other characters
//   - Send sleep signal to the TOP module to switch LED on when a
//       character is transmitted

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
  
   // ---- to TOP --------------------------------------------------
   output       sleep_o
   );

   reg [1:0]    rstn_sq;

   wire         rstn;

   assign rstn = rstn_sq[0];

   always @(posedge clk_i or negedge rstn_i) begin
      if (~rstn_i) begin
         rstn_sq <= 2'd0;
      end else begin
         rstn_sq <= {1'b1, rstn_sq[1]};
      end
   end

   localparam [3:0] ST_RESET = 'd0,
                    ST_OUT_CKECK0 = 'd1,
                    ST_OUT_CKECK1 = 'd2,
                    ST_OUT_SLEEP = 'd3,
                    ST_OUT0 = 'd4,
                    ST_OUT1 = 'd5,
                    ST_EXE = 'd6,
                    ST_IN_CKECK0 = 'd7,
                    ST_IN_CKECK1 = 'd8,
                    ST_IN_SLEEP = 'd9,
                    ST_IN = 'd10;

   reg [3:0]        status_q, status_d;
   reg              fifo_irq_q, fifo_irq_d;
   reg [7:0]        data_q, data_d;
   
   assign sleep_o = (status_q == ST_OUT_SLEEP || status_q == ST_IN_SLEEP) ? 1'b1 : 1'b0;

   always @(posedge clk_i or negedge rstn) begin
      if (~rstn) begin
         status_q <= ST_RESET;
         fifo_irq_q <= 1'b0;
         data_q <= 'd0;
      end else begin
         status_q <= status_d;
         fifo_irq_q <= fifo_irq_d;
         data_q <= data_d;
      end
   end

   reg [7:0] cpu_wrdata;
   reg [1:0] cpu_addr;
   reg       cpu_rd, cpu_wr;
   reg       fifo_sel;

   wire [7:0] fifo_rddata;
   wire       fifo_out_irq, fifo_in_irq;
   
   always @(/*AS*/data_q or fifo_in_irq or fifo_irq_q or fifo_out_irq
            or fifo_rddata or status_q) begin
      status_d = status_q;
      fifo_irq_d = fifo_irq_q | fifo_out_irq | fifo_in_irq;
      data_d = data_q;
      cpu_addr = 2'b00;
      cpu_rd = 1'b0;
      cpu_wr = 1'b0;
      cpu_wrdata = 8'd0;
      fifo_sel = 1'b0;
      case (status_q)
        ST_RESET : begin
           status_d = ST_OUT_CKECK0;
        end
        ST_OUT_CKECK0 : begin
           fifo_irq_d = 1'b0;
           cpu_addr = 2'b10;
           cpu_rd = 1'b1;
           fifo_sel = 1'b1;
           status_d = ST_OUT_CKECK1;
        end
        ST_OUT_CKECK1 : begin
           if (fifo_rddata[0] == 1'b1)
             status_d = ST_OUT0;
           else
             status_d = ST_OUT_SLEEP;
        end
        ST_OUT_SLEEP : begin
           if (fifo_irq_q)
             status_d = ST_OUT_CKECK0;
        end
        ST_OUT0 : begin
           cpu_addr = 2'b11;
           cpu_rd = 1'b1;
           fifo_sel = 1'b1;
           status_d = ST_OUT1;
        end
        ST_OUT1 : begin
           data_d = fifo_rddata[7:0];
           status_d = ST_EXE;
        end
        ST_EXE : begin
           if ((data_q >= "a" && data_q <= "z") ||
               (data_q >= "A" && data_q <= "Z"))
             data_d = data_q ^ 8'h20;
           else if (data_q >= "0" && data_q <= "8")
             data_d = data_q + 1;
           else if (data_q == "9")
             data_d = "0";
           status_d = ST_IN_CKECK0;
        end
        ST_IN_CKECK0 : begin
           fifo_irq_d = 1'b0;
           cpu_addr = 2'b01;
           cpu_rd = 1'b1;
           fifo_sel = 1'b1;
           status_d = ST_IN_CKECK1;
        end
        ST_IN_CKECK1 : begin
           if (fifo_rddata[0] == 1'b1)
             status_d = ST_IN;
           else
             status_d = ST_IN_SLEEP;
        end
        ST_IN_SLEEP : begin
           if (fifo_irq_q)
             status_d = ST_IN_CKECK0;
        end
        ST_IN : begin
           cpu_addr = 2'b01;
           cpu_wr = 1'b1;
           fifo_sel = 1'b1;
           cpu_wrdata = data_q;
           status_d = ST_OUT_CKECK0;
        end
        default : begin
           status_d = ST_OUT_CKECK0;
        end
      endcase
   end

   fifo_if u_fifo_if (.clk_i(clk_i),
                      .rstn_i(rstn),
                      .sel_i(fifo_sel),
                      .read_i(cpu_rd),
                      .write_i(cpu_wr),
                      .addr_i(cpu_addr),
                      .data_i(cpu_wrdata),
                      .data_o(fifo_rddata),
                      .in_irq_o(fifo_in_irq),
                      .out_irq_o(fifo_out_irq),
                      .in_data_o(in_data_o),
                      .in_valid_o(in_valid_o),
                      .in_ready_i(in_ready_i),
                      .out_data_i(out_data_i),
                      .out_valid_i(out_valid_i),
                      .out_ready_o(out_ready_o));

endmodule
