module adma_dm_axi_r #(
    // DMA
    parameter DMA_CHN_NUM       = 4,    // Number of DMA channels
    parameter ROB_EN            = 1,
    // AXI Interface
    parameter MST_ID_W          = 5,
    parameter ATX_LEN_W         = 8,
    parameter ATX_SIZE_W        = 3,
    parameter ATX_RESP_W        = 2,
    parameter ATX_SRC_DATA_W    = 256,
    parameter ATX_NUM_OSTD      = DMA_CHN_NUM,   // Number of outstanding transactions in AXI bus (recmd: equal to the number of channel)
    parameter ATX_INTL_DEPTH    = 16, // Interleaving depth on the AXI data channel 
    // Do not configure these
    parameter DMA_CHN_NUM_W     = (DMA_CHN_NUM > 1) ? $clog2(DMA_CHN_NUM) : 1
) (
    input                           clk,
    input                           rst_n,
    // AXI Transaction information
    input   [DMA_CHN_NUM_W-1:0]     atx_chn_id,
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
    // -- R channel  
    input   [MST_ID_W-1:0]          m_rid_i,
    input   [ATX_SRC_DATA_W-1:0]    m_rdata_i,
    input   [ATX_RESP_W-1:0]        m_rresp_i,
    input                           m_rlast_i,
    input                           m_rvalid_i,
    output                          m_rready_o
);
    // Local parameters
    localparam R_INFO_W   = MST_ID_W + ATX_SRC_DATA_W + ATX_RESP_W + 1; // RID + RDATA + RRESP + RLAST
    localparam ROB_INFO_W = ATX_SRC_DATA_W + ATX_RESP_W; // Data + Resp
    localparam SLVERR_ENC = 2'b10;
    localparam DECERR_ENC = 2'b11;
    // Internal variable
    genvar chn_idx;
    // Internal signal
    wire    [MST_ID_W-1:0]          m_rid;
    wire    [ATX_SRC_DATA_W-1:0]    m_rdata;
    wire    [ATX_RESP_W-1:0]        m_rresp;
    wire                            m_rlast;
    wire                            m_rvalid;
    wire                            m_rready;

    wire    [ATX_SRC_DATA_W-1:0]    fwd_rdata;
    wire    [ATX_RESP_W-1:0]        fwd_rresp;
    wire                            fwd_vld;
    wire                            fwd_rdy;

    wire                            atx_vld_flt; // Filtered atx_vld

    wire                            rob_ord_vld;
    wire                            rob_ord_rdy;

    wire    [DMA_CHN_NUM_W-1:0]     ab_fwd_chn_id;
    wire                            ab_fwd_rdy;
    wire                            ab_bwd_vld;
    wire                            ab_bwd_rdy;

    wire                            m_r_hsk;
    // Module instantiation
    // -- Skid buffer
    skid_buffer #(
        .SBUF_TYPE      (4),    // Bypass
        .DATA_WIDTH     (R_INFO_W) 
    ) r_sb (
        .clk            (clk),
        .rst_n          (rst_n),
        .bwd_data_i     ({m_rid_i,  m_rdata_i,  m_rresp_i,  m_rlast_i}),
        .bwd_valid_i    (m_rvalid_i),
        .bwd_ready_o    (m_rready_o),
        .fwd_data_o     ({m_rid,    m_rdata,    m_rresp,    m_rlast}),
        .fwd_valid_o    (m_rvalid),
        .fwd_ready_i    (m_rready)
    );
    // -- Reorder Buffer
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
        .clk            (clk),
        .rst_n          (rst_n),
        .bwd_id         (m_rid),
        .bwd_data       ({m_rdata, m_rresp}),
        .bwd_vld        (m_rvalid),
        .bwd_rdy        (m_rready),
        .fwd_data       ({fwd_rdata, fwd_rresp}),
        .fwd_vld        (fwd_vld),
        .fwd_rdy        (fwd_rdy),
        .ord_id         (atx_arid),
        .ord_len        (atx_arlen),    // total length = atx_arlen - 1
        .ord_vld        (rob_ord_vld),
        .ord_rdy        (rob_ord_rdy),
        .buf_id         (atx_id)
    );
end
else begin : ROB_BYPASS_GEN
    assign fwd_rdata    = m_rdata;
    assign fwd_rresp    = m_rresp;
    assign fwd_vld      = m_rvalid;
    assign m_rready     = fwd_rdy;
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
    assign atx_rdata        = fwd_rdata;
    assign atx_rdata_vld    = fwd_vld;
    assign fwd_rdy          = atx_rdata_rdy; 
    assign m_r_hsk          = m_rvalid & m_rready;
    assign ab_fwd_rdy       = m_rlast & m_r_hsk;  // Pop the atx_buffer when the last data has been accepted
generate
for (chn_idx = 0; chn_idx < DMA_CHN_NUM; chn_idx = chn_idx + 1) begin : ATX_SRC_ERR_GEN
    assign atx_src_err[chn_idx] = (ab_fwd_chn_id == chn_idx) & (~|(m_rresp^SLVERR_ENC) | ~|(m_rresp^DECERR_ENC))  & m_r_hsk; // The accepted data is a Error response -> return the flag
end
endgenerate

endmodule