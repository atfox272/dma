module adma_dm_axi_b #(
    // DMA
    parameter DMA_CHN_NUM       = 4,    // Number of DMA channels
    parameter ROB_EN            = 1,
    // AXI Interface
    parameter MST_ID_W          = 5,
    parameter ATX_RESP_W        = 2,
    parameter ATX_DST_DATA_W    = 256,
    parameter ATX_NUM_OSTD      = DMA_CHN_NUM,   // Number of outstanding transactions in AXI bus (recmd: equal to the number of channel)
    parameter ATX_INTL_DEPTH    = 16, // Interleaving depth on the AXI data channel 
    // Do not configure these
    parameter DMA_CHN_NUM_W     = (DMA_CHN_NUM > 1) ? $clog2(DMA_CHN_NUM) : 1
) (
    input                           clk,
    input                           rst_n,
    // AXI Transaction information
    input   [DMA_CHN_NUM_W-1:0]     atx_chn_id,
    input   [MST_ID_W-1:0]          atx_awid,
    input                           atx_vld,
    output                          atx_rdy,
    // AXI Transaction control
    input   [DMA_CHN_NUM*MST_ID_W-1:0]  atx_id,
    output  [DMA_CHN_NUM-1:0]           atx_done,
    output  [DMA_CHN_NUM-1:0]           atx_dst_err,
    // AXI Master interface
    // -- B channel
    input   [MST_ID_W-1:0]          m_bid_i,
    input   [ATX_RESP_W-1:0]        m_bresp_i,
    input                           m_bvalid_i,
    output                          m_bready_o
);
    // Local parameters 
    localparam B_INFO_W   = MST_ID_W + ATX_RESP_W;
    localparam SLVERR_ENC = 2'b10;
    localparam DECERR_ENC = 2'b11;
    // Internal variable
    genvar chn_idx;
    // Internal signal
    wire    [MST_ID_W-1:0]          m_bid;
    wire    [ATX_RESP_W-1:0]        m_bresp;
    wire                            m_bvalid;
    wire                            m_bready;

    wire                            m_b_hsk;

    wire    [ATX_RESP_W-1:0]        fwd_bresp;
    wire                            fwd_vld;
    wire                            fwd_rdy;

    wire                            rob_ord_vld;
    wire                            rob_ord_rdy;

    wire                            atx_vld_flt; // Filtered atx_vld

    wire    [DMA_CHN_NUM_W-1:0]     ab_fwd_chn_id;
    wire                            ab_fwd_rdy;
    wire                            ab_bwd_vld;
    wire                            ab_bwd_rdy;
    // Module instantiation
    // -- Skid buffer
    skid_buffer #(
        .SBUF_TYPE      (4),    // Bypass
        .DATA_WIDTH     (B_INFO_W) 
    ) b_sb (
        .clk            (clk),
        .rst_n          (rst_n),
        .bwd_data_i     ({m_bid_i,  m_bresp_i}),
        .bwd_valid_i    (m_bvalid_i),
        .bwd_ready_o    (m_bready_o),
        .fwd_data_o     ({m_bid,    m_bresp}),
        .fwd_valid_o    (m_bvalid),
        .fwd_ready_i    (m_bready)
    );
    // -- Reorder Buffer
generate
if((ROB_EN == 1) && (DMA_CHN_NUM > 1)) begin : ROB_GEN
    reorder_buffer #(
        .FIX_ID         (0),
        .ORD_DEPTH      (ATX_NUM_OSTD),
        .BUF_DEPTH      (ATX_INTL_DEPTH),
        .ID_W           (MST_ID_W),
        .DATA_W         (ATX_RESP_W),
        .LEN_W          (1)
    ) rob (
        .clk            (clk),
        .rst_n          (rst_n),
        .bwd_id         (m_bid),
        .bwd_data       (m_bresp),
        .bwd_vld        (m_bvalid),
        .bwd_rdy        (m_bready),
        .fwd_data       (fwd_bresp),
        .fwd_vld        (fwd_vld),
        .fwd_rdy        (fwd_rdy),
        .ord_id         (atx_awid),
        .ord_len        (1'b1),    // total length = atx_arlen - 1
        .ord_vld        (rob_ord_vld),
        .ord_rdy        (rob_ord_rdy),
        .buf_id         (atx_id)
    );
end
else begin : ROB_BYPASS_GEN
    assign fwd_bresp    = m_bresp;
    assign fwd_vld      = m_bvalid;
    assign m_bready     = fwd_rdy;
    assign rob_ord_rdy  = 1'b1;
end
endgenerate
    // -- ATX buffer
    sync_fifo #(
        .FIFO_TYPE      (1),    // Normal type
        .DATA_WIDTH     (DMA_CHN_NUM_W),
        .FIFO_DEPTH     (ATX_NUM_OSTD) 
    ) atx_buffer (
        .clk            (clk),
        .data_i         (atx_chn_id),
        .wr_valid_i     (ab_bwd_vld),
        .wr_ready_o     (ab_bwd_rdy),
        .data_o         (ab_fwd_chn_id),
        .rd_valid_i     (ab_fwd_rdy),
        .rd_ready_o     (), // pop ONLY when the buffer contains data
        .empty_o        (),
        .full_o         (),
        .almost_empty_o (),
        .almost_full_o  (),
        .counter        (),
        .rst_n          (rst_n)
    );
    // Combinational logic
    assign atx_rdy          = rob_ord_rdy & ab_bwd_rdy;
    assign atx_vld_flt      = atx_vld & atx_rdy; 
    assign rob_ord_vld      = atx_vld_flt;
    assign ab_bwd_vld       = atx_vld_flt;
    assign fwd_rdy          = 1'b1; 
    assign m_b_hsk          = m_bvalid & m_bready;
    assign ab_fwd_rdy       = m_b_hsk;  
    generate
for (chn_idx = 0; chn_idx < DMA_CHN_NUM; chn_idx = chn_idx + 1) begin : ATX_DST_ERR_GEN
    assign atx_dst_err[chn_idx] = (ab_fwd_chn_id == chn_idx) & (~|(m_bresp^SLVERR_ENC) | ~|(m_bresp^DECERR_ENC))  & m_b_hsk; // The accepted data is a Error response -> return the flag
    assign atx_done[chn_idx]    = (ab_fwd_chn_id == chn_idx) & m_b_hsk; // ATX done -> return the flag
end
endgenerate
endmodule