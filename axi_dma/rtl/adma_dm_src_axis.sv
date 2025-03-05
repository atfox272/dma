module adma_dm_src_axis #(
    // DMA
    parameter DMA_CHN_NUM       = 4,    // Number of DMA channels
    parameter ROB_EN            = 1,
    // AXI-Stream
    parameter ATX_SRC_DATA_W    = 256,
    parameter ATX_SRC_BYTE_AMT  = ATX_SRC_DATA_W/8,
    parameter SRC_TDEST_W       = 2,
    parameter MST_ID_W          = 5,
    parameter ATX_LEN_W         = 8,
    parameter ATX_NUM_OSTD      = DMA_CHN_NUM,   // Number of outstanding transactions in AXI bus (recmd: equal to the number of channel)
    parameter ATX_INTL_DEPTH    = 16 // Interleaving depth on the AXI data channel 
) (
    input                           aclk,
    input                           aresetn,
    // AXI Transaction information
    input   [MST_ID_W-1:0]          atx_arid,
    input   [ATX_LEN_W-1:0]         atx_arlen,
    input                           atx_vld,
    output                          atx_rdy,
    // AXI Transaction control
    output  [ATX_SRC_DATA_W-1:0]    atx_rdata,
    output                          atx_rdata_vld,
    input                           atx_rdata_rdy,
    input   [MST_ID_W-1:0]          atx_id      [0:DMA_CHN_NUM-1],
    output                          atx_src_err [0:DMA_CHN_NUM-1],
    // -- AXI-Stream
    input   [MST_ID_W-1:0]          s_tid_i,    
    input   [SRC_TDEST_W-1:0]       s_tdest_i,  // Not-use
    input   [ATX_SRC_DATA_W-1:0]    s_tdata_i,
    input   [ATX_SRC_BYTE_AMT-1:0]  s_tkeep_i,
    input   [ATX_SRC_BYTE_AMT-1:0]  s_tstrb_i,
    input                           s_tlast_i,
    input                           s_tvalid_i,
    output                          s_tready_o
);
    // Local parameters
    localparam AXIS_INFO_W = MST_ID_W + ATX_SRC_DATA_W + ATX_SRC_BYTE_AMT + ATX_SRC_BYTE_AMT + 1; // TID + TDATA + TKEEP + TSTRB + TLAST
    localparam ROB_INFO_W  = ATX_SRC_DATA_W;
    // Internal variable
    genvar chn_idx;  
    // Internal signal
    wire    [MST_ID_W-1:0]          s_tid;    
    wire    [ATX_SRC_DATA_W-1:0]    s_tdata;
    wire    [ATX_SRC_BYTE_AMT-1:0]  s_tkeep;
    wire    [ATX_SRC_BYTE_AMT-1:0]  s_tstrb;
    wire                            s_tlast;
    wire                            s_tvalid;
    wire                            s_tready;
    wire    [ATX_SRC_DATA_W-1:0]    fwd_rob_dat;
    wire                            fwd_rob_vld;
    wire                            fwd_rob_rdy;

    // Module instantiation
    // -- Skid buffer
    skid_buffer #(
        .SBUF_TYPE      (4),    // Bypass
        .DATA_WIDTH     (AXIS_INFO_W) 
    ) axis_sb (
        .clk            (aclk),
        .rst_n          (aresetn),
        .bwd_data_i     ({s_tid_i,  s_tdata_i,  s_tkeep_i,  s_tstrb_i, s_tlast_i}),
        .bwd_valid_i    (s_tvalid_i),
        .bwd_ready_o    (s_tready_o),
        .fwd_data_o     ({s_tid,    s_tdata,    s_tkeep,    s_tstrb,   s_tlast}),
        .fwd_valid_o    (s_tvalid),
        .fwd_ready_i    (s_tready)
    );
generate
if((ROB_EN == 1) && (DMA_CHN_NUM > 1)) begin : ROB_GEN
    reorder_buffer #(
        .FIX_ID         (0),
        .ORD_DEPTH      (ATX_NUM_OSTD),
        .BUF_DEPTH      (ATX_INTL_DEPTH),
        .ID_W           (MST_ID_W),
        .DATA_W         (ROB_INFO_W),
        .LEN_W          (ATX_LEN_W)
    ) rob (
        .clk            (aclk),
        .rst_n          (aresetn),
        .bwd_id         (s_tid),
        .bwd_data       (s_tdata),
        .bwd_vld        (s_tvalid),
        .bwd_rdy        (s_tready),
        .fwd_data       (fwd_rob_dat),
        .fwd_vld        (fwd_rob_vld),
        .fwd_rdy        (fwd_rob_rdy),
        .ord_id         (atx_arid),
        .ord_len        (atx_arlen),    // total length = atx_arlen - 1
        .ord_vld        (atx_vld),
        .ord_rdy        (atx_rdy),
        .buf_id         (atx_id)
    );
end
else begin : ROB_BYPASS_GEN
    assign fwd_rob_dat  = s_tdata;
    assign fwd_rob_vld  = s_tvalid;
    assign s_tready     = fwd_rob_rdy;
    assign atx_rdy      = 1'b1;
end
endgenerate
    assign atx_rdata    = fwd_rob_dat;
    assign atx_rdata_vld= fwd_rob_vld;
    assign fwd_rob_rdy  = atx_rdata_rdy; 
generate
for (chn_idx = 0; chn_idx < DMA_CHN_NUM; chn_idx = chn_idx + 1) begin : ATX_SRC_ERR_GEN
    assign atx_src_err[chn_idx] = 1'b0;
end
endgenerate
endmodule