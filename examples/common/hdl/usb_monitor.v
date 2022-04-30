`timescale 1 ns/10 ps  // time-unit/precision
`define BIT_TIME (1000/12)

module usb_monitor
  #(parameter MAX_BITS = 128,
    parameter MAX_BYTES = 8*1024)
   (
    input usb_dp_i,
    input usb_dn_i
    );

   localparam MAX_STRING = 8;

   integer    errors;
   integer    warnings;

   wire       dp_sense;
   wire       dn_sense;

`include "usb_rx_tasks.v"

   reg [3:0]  pid;
   reg [6:0]  addr;
   reg [3:0]  endp;
   reg [10:0] frame;
   reg [8*MAX_BYTES-1:0] data;
   reg [8*MAX_STRING-1:0] info;

   integer                bytes;

   assign dp_sense = usb_dp_i;
   assign dn_sense = usb_dn_i;

   initial begin
      errors = 0;
      warnings = 0;
      forever begin
         packet_rx(pid, addr, endp, frame, data, bytes,
                   `BIT_TIME, 1000000);
         case (pid)
           PID_OUT : info = "OUT";
           PID_IN : info = "IN";
           PID_SOF : info = "SOF";
           PID_SETUP : info = "SETUP";
           PID_DATA0 : info = "DATA0";
           PID_DATA1 : info = "DATA1";
           PID_ACK : info = "ACK";
           PID_NAK : info = "NAK";
           PID_STALL : info = "STALL";
           default : info = "";
         endcase
      end
   end

endmodule
