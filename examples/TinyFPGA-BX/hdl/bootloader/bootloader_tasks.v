
task automatic test_cmd
  (
   input [7:0]   opcode,
   input integer wr_length,
   input integer rd_length,
   input [6:0]   address,
   input integer wMaxPacketSize,
   input time    timeout,
   inout [15:0]  dataout_toggle
   );
   integer       wr_total_length;
   begin : u_test_cmd_task
      wr_total_length = wr_length + 1; // add opcode

      test_data_out(address, ENDP_BULK,
                    {8'h01,
                     wr_total_length[7:0], wr_total_length[15:8],
                     rd_length[7:0], rd_length[15:8],
                     opcode},
                    6, PID_ACK, wMaxPacketSize, timeout, 0, dataout_toggle);
   end
endtask

task automatic test_read
  (
   input integer           rd_addr, 
   input [8*MAX_BYTES-1:0] data,
   input integer           bytes,
   input [6:0]             address,
   input integer           in_wMaxPacketSize,
   input integer           out_wMaxPacketSize,
   input time              timeout,
   inout [15:0]            datain_toggle,
   inout [15:0]            dataout_toggle
   );
   integer                 wr_length;
   integer                 rd_length;
   begin : u_test_read_task
      wr_length = 5;
      rd_length = bytes;

      test_data_out(address, ENDP_BULK,
                    {8'h01, wr_length[7:0], wr_length[15:8], rd_length[7:0], rd_length[15:8],
                     8'h0B, rd_addr[23:16], rd_addr[15:8], rd_addr[7:0], 8'd0},
                    10, PID_ACK, out_wMaxPacketSize, timeout, 0, dataout_toggle);
      test_data_in(address, ENDP_BULK,
                   data,
                   bytes, PID_ACK, in_wMaxPacketSize, timeout, 0, datain_toggle, ZLP);
   end
endtask
