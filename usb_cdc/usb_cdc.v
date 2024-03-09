//  USB 2.0 full speed Communications Device Class.
//  Written in verilog 2001

// USB_CDC module shall implement Full Speed (12Mbit/s) USB communications device
//   class (or USB CDC class) and Abstract Control Model (ACM) subclass.
// USB_CDC shall implement IN/OUT FIFO interface between USB and external APP module.

module usb_cdc
  #(parameter VENDORID = 16'h0000,
    parameter PRODUCTID = 16'h0000,
    parameter CHANNELS = 'd1,
    parameter IN_BULK_MAXPACKETSIZE = 'd8,
    parameter OUT_BULK_MAXPACKETSIZE = 'd8,
    parameter BIT_SAMPLES = 'd4,
    parameter USE_APP_CLK = 0,
    parameter APP_CLK_FREQ = 12) // app_clk frequency in MHz
   (
    input                   clk_i,
    // clk_i clock shall have a frequency of 12MHz*BIT_SAMPLES
    input                   rstn_i,
    // While rstn_i is low (active low), the module shall be reset

    // ---- to/from Application ------------------------------------
    input                   app_clk_i,
    output [8*CHANNELS-1:0] out_data_o,
    output [CHANNELS-1:0]   out_valid_o,
    // While out_valid_o is high, the out_data_o shall be valid and both
    //   out_valid_o and out_data_o shall not change until consumed.
    input [CHANNELS-1:0]    out_ready_i,
    // When both out_valid_o and out_ready_i are high, the out_data_o shall
    //   be consumed.
    input [8*CHANNELS-1:0]  in_data_i,
    input [CHANNELS-1:0]    in_valid_i,
    // While in_valid_i is high, in_data_i shall be valid.
    output [CHANNELS-1:0]   in_ready_o,
    // When both in_ready_o and in_valid_i are high, in_data_i shall
    //   be consumed.
    output [10:0]           frame_o,
    // frame_o shall be last recognized USB frame number sent by USB host.
    output                  configured_o,
    // While USB_CDC is in configured state, configured_o shall be high.

    // ---- to USB bus physical transmitters/receivers --------------
    output                  dp_pu_o,
    output                  tx_en_o,
    output                  dp_tx_o,
    output                  dn_tx_o,
    input                   dp_rx_i,
    input                   dn_rx_i
    );

   function integer ceil_log2;
      input [31:0] arg;
      integer      i;
      begin
         ceil_log2 = 0;
         for (i = 0; i < 32; i = i + 1) begin
            if (arg > (1 << i))
              ceil_log2 = ceil_log2 + 1;
         end
      end
   endfunction

   reg [1:0]        rstn_sq;

   wire             rstn;

   assign rstn = rstn_sq[0];

   always @(posedge clk_i or negedge rstn_i) begin
      if (~rstn_i) begin
         rstn_sq <= 2'd0;
      end else begin
         rstn_sq <= {1'b1, rstn_sq[1]};
      end
   end

   reg [ceil_log2(BIT_SAMPLES)-1:0] clk_cnt_q;
   reg                              clk_gate_q;

   always @(posedge clk_i or negedge rstn) begin
      if (~rstn) begin
         clk_cnt_q <= 'd0;
         clk_gate_q <= 1'b0;
      end else begin
         if ({1'b0, clk_cnt_q} == BIT_SAMPLES-1) begin
            clk_cnt_q <= 'd0;
            clk_gate_q <= 1'b1;
         end else begin
            clk_cnt_q <= clk_cnt_q + 1;
            clk_gate_q <= 1'b0;
         end
      end
   end

   localparam    CTRL_MAXPACKETSIZE = 'd8;
   localparam [3:0] ENDP_CTRL = 'd0;

   reg [7:0]        sie2i_in_data;
   reg              sie2i_in_valid, sie2i_out_nak;

   wire [3:0]       endp;
   wire [7:0]       ctrl_in_data;
   wire [8*CHANNELS-1:0] bulk_in_data;
   wire                  ctrl_in_valid;
   wire [CHANNELS-1:0]   bulk_in_valid;
   wire [CHANNELS-1:0]   bulk_out_nak;

   always @(/*AS*/bulk_in_data or bulk_in_valid or bulk_out_nak
            or ctrl_in_data or ctrl_in_valid or endp) begin : u_mux
      integer j;

      sie2i_in_data = ctrl_in_data;
      sie2i_in_valid = (endp == ENDP_CTRL) ? ctrl_in_valid : 1'b0;
      sie2i_out_nak = 1'b0;
      for (j = 0; j < CHANNELS; j = j+1) begin
         if (endp == 2*j[2:0]+1) begin
            sie2i_in_data = bulk_in_data[8*j +:8];
            sie2i_in_valid = bulk_in_valid[j];
            sie2i_out_nak = bulk_out_nak[j];
         end
      end
   end

   wire [6:0] addr;
   wire [7:0] sie_out_data;
   wire       sie_out_valid;
   wire       sie_in_req;
   wire       sie_out_err;
   wire       setup;
   wire [15:0] in_bulk_endps;
   wire [15:0] out_bulk_endps;
   wire [15:0] in_int_endps;
   wire [15:0] out_int_endps;
   wire [15:0] in_toggle_reset;
   wire [15:0] out_toggle_reset;
   wire        bus_reset;
   wire        sie_in_ready;
   wire        sie_in_data_ack;
   wire        sie_out_ready;
   wire        usb_en;
   wire        sie2i_in_zlp, ctrl_in_zlp;
   wire        sie2i_in_nak;
   wire        sie2i_stall, ctrl_stall;

   assign sie2i_in_zlp = (endp == ENDP_CTRL) ? ctrl_in_zlp : 1'b0;
   assign sie2i_in_nak = in_int_endps[endp];
   assign sie2i_stall = (endp == ENDP_CTRL) ? ctrl_stall : 1'b0;

   sie #(.IN_CTRL_MAXPACKETSIZE(CTRL_MAXPACKETSIZE),
         .IN_BULK_MAXPACKETSIZE(IN_BULK_MAXPACKETSIZE),
         .BIT_SAMPLES(BIT_SAMPLES))
   u_sie (.bus_reset_o(bus_reset),
          .dp_pu_o(dp_pu_o),
          .tx_en_o(tx_en_o),
          .dp_tx_o(dp_tx_o),
          .dn_tx_o(dn_tx_o),
          .endp_o(endp),
          .frame_o(frame_o),
          .out_data_o(sie_out_data),
          .out_valid_o(sie_out_valid),
          .out_err_o(sie_out_err),
          .in_req_o(sie_in_req),
          .setup_o(setup),
          .out_ready_o(sie_out_ready),
          .in_ready_o(sie_in_ready),
          .in_data_ack_o(sie_in_data_ack),
          .in_bulk_endps_i(in_bulk_endps),
          .out_bulk_endps_i(out_bulk_endps),
          .in_int_endps_i(in_int_endps),
          .out_int_endps_i(out_int_endps),
          .in_iso_endps_i(16'b0),
          .out_iso_endps_i(16'b0),
          .clk_i(clk_i),
          .rstn_i(rstn),
          .clk_gate_i(clk_gate_q),
          .usb_en_i(usb_en),
          .usb_detach_i(1'b0),
          .dp_rx_i(dp_rx_i),
          .dn_rx_i(dn_rx_i),
          .addr_i(addr),
          .in_valid_i(sie2i_in_valid),
          .in_data_i(sie2i_in_data),
          .in_zlp_i(sie2i_in_zlp),
          .out_nak_i(sie2i_out_nak),
          .in_nak_i(sie2i_in_nak),
          .stall_i(sie2i_stall),
          .in_toggle_reset_i(in_toggle_reset),
          .out_toggle_reset_i(out_toggle_reset));

   wire ctrl2i_in_req, ctrl2i_out_ready, ctrl2i_in_ready;

   assign ctrl2i_in_req = (endp == ENDP_CTRL) ? sie_in_req : 1'b0;
   assign ctrl2i_out_ready = (endp == ENDP_CTRL) ? sie_out_ready : 1'b0;
   assign ctrl2i_in_ready = (endp == ENDP_CTRL) ? sie_in_ready : 1'b0;

   ctrl_endp #(.VENDORID(VENDORID),
               .PRODUCTID(PRODUCTID),
               .CHANNELS(CHANNELS),
               .CTRL_MAXPACKETSIZE(CTRL_MAXPACKETSIZE),
               .IN_BULK_MAXPACKETSIZE(IN_BULK_MAXPACKETSIZE),
               .OUT_BULK_MAXPACKETSIZE(OUT_BULK_MAXPACKETSIZE))
   u_ctrl_endp (.configured_o(configured_o),
                .usb_en_o(usb_en),
                .addr_o(addr),
                .in_data_o(ctrl_in_data),
                .in_zlp_o(ctrl_in_zlp),
                .in_valid_o(ctrl_in_valid),
                .stall_o(ctrl_stall),
                .in_bulk_endps_o(in_bulk_endps),
                .out_bulk_endps_o(out_bulk_endps),
                .in_int_endps_o(in_int_endps),
                .out_int_endps_o(out_int_endps),
                .in_toggle_reset_o(in_toggle_reset),
                .out_toggle_reset_o(out_toggle_reset),
                .clk_i(clk_i),
                .rstn_i(rstn),
                .clk_gate_i(clk_gate_q),
                .bus_reset_i(bus_reset),
                .out_data_i(sie_out_data),
                .out_valid_i(sie_out_valid),
                .out_err_i(sie_out_err),
                .in_req_i(ctrl2i_in_req),
                .setup_i(setup),
                .in_data_ack_i(sie_in_data_ack),
                .out_ready_i(ctrl2i_out_ready),
                .in_ready_i(ctrl2i_in_ready));

   genvar i;

   generate
      for (i = 0; i < CHANNELS; i = i+1) begin : u_bulk_endps
         wire bulk2i_in_req, bulk2i_out_ready, bulk2i_in_ready;

         assign bulk2i_in_req = (endp == 2*i+1) ? sie_in_req : 1'b0;
         assign bulk2i_out_ready = (endp == 2*i+1) ? sie_out_ready : 1'b0;
         assign bulk2i_in_ready = (endp == 2*i+1) ? sie_in_ready : 1'b0;

         bulk_endp #(.IN_BULK_MAXPACKETSIZE(IN_BULK_MAXPACKETSIZE),
                     .OUT_BULK_MAXPACKETSIZE(OUT_BULK_MAXPACKETSIZE),
                     .USE_APP_CLK(USE_APP_CLK),
                     .APP_CLK_FREQ(APP_CLK_FREQ))
         u_bulk_endp (.in_data_o(bulk_in_data[8*i +:8]),
                      .in_valid_o(bulk_in_valid[i]),
                      .app_in_ready_o(in_ready_o[i]),
                      .out_nak_o(bulk_out_nak[i]),
                      .app_out_valid_o(out_valid_o[i]),
                      .app_out_data_o(out_data_o[8*i +:8]),
                      .clk_i(clk_i),
                      .app_clk_i(app_clk_i),
                      .rstn_i(rstn),
                      .clk_gate_i(clk_gate_q),
                      .bus_reset_i(bus_reset),
                      .out_data_i(sie_out_data),
                      .out_valid_i(sie_out_valid),
                      .out_err_i(sie_out_err),
                      .in_req_i(bulk2i_in_req),
                      .in_data_ack_i(sie_in_data_ack),
                      .app_in_data_i(in_data_i[8*i +:8]),
                      .app_in_valid_i(in_valid_i[i]),
                      .out_ready_i(bulk2i_out_ready),
                      .in_ready_i(bulk2i_in_ready),
                      .app_out_ready_i(out_ready_i[i]));
      end
   endgenerate
endmodule
