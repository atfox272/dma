module adma_dm_dst_axis #(
    // DMA
    parameter DMA_CHN_NUM       = 4,    // Number of DMA channels
    // AXI Interface
    parameter MST_ID_W          = 5,
    parameter ATX_LEN_W         = 8,
    parameter DST_TDEST_W       = 2,
    parameter ATX_DST_DATA_W    = 256,
    parameter ATX_DST_BYTE_AMT  = ATX_DST_DATA_W/8,
    parameter ATX_NUM_OSTD      = DMA_CHN_NUM,   // Number of outstanding transactions in AXI bus (recmd: equal to the number of channel)
    // Do not configure these
    parameter DMA_CHN_NUM_W     = (DMA_CHN_NUM > 1) ? $clog2(DMA_CHN_NUM) : 1
) (
    input                           aclk,
    input                           aresetn,
    // AXI Transaction information
    input   [DMA_CHN_NUM_W-1:0]     atx_chn_id,
    input   [DST_TDEST_W-1:0]       atx_tdest,
    input   [ATX_LEN_W-1:0]         atx_tlen,
    input                           atx_vld,
    output                          atx_rdy,
    // AXI Transaction data
    input   [ATX_DST_DATA_W-1:0]        atx_wdata,
    input                               atx_wdata_vld,
    output                              atx_wdata_rdy,
    input   [DMA_CHN_NUM*MST_ID_W-1:0]  atx_id,
    output  [DMA_CHN_NUM-1:0]           atx_done,
    output  [DMA_CHN_NUM-1:0]           atx_dst_err,
    // -- AXI-Stream Master Interface
    output  [MST_ID_W-1:0]          m_tid_o,      
    output  [DST_TDEST_W-1:0]       m_tdest_o,
    output  [ATX_DST_DATA_W-1:0]    m_tdata_o,
    output  [ATX_DST_BYTE_AMT-1:0]  m_tkeep_o,
    output  [ATX_DST_BYTE_AMT-1:0]  m_tstrb_o,
    output                          m_tlast_o,
    output                          m_tvalid_o,
    input                           m_tready_i
);
    // Local parameters
    localparam AXIS_INFO_W = MST_ID_W + DST_TDEST_W + ATX_DST_DATA_W + 1;
    // Internal variable
    genvar chn_idx;
    // Internal signal
    wire  [MST_ID_W-1:0]            m_tid;    
    wire  [DST_TDEST_W-1:0]         m_tdest;  // Not-use
    wire  [ATX_DST_DATA_W-1:0]      m_tdata;
    wire  [ATX_DST_BYTE_AMT-1:0]    m_tkeep;
    wire  [ATX_DST_BYTE_AMT-1:0]    m_tstrb;
    wire                            m_tlast;
    wire                            m_tvalid;
    wire                            m_tready;
    wire                            m_axis_hsk;
    wire   [DMA_CHN_NUM_W-1:0]      cur_chn_id;
    wire   [ATX_LEN_W-1:0]          cur_tlen;
    wire   [DST_TDEST_W-1:0]        cur_tdest;
    wire                            cur_atx_vld;
    
    wire    [MST_ID_W-1:0]          atx_id_pck  [0:DMA_CHN_NUM-1];

    reg     [ATX_LEN_W-1:0]         tdata_cnt;
    // Module instantiation
    // -- Skid buffer
    skid_buffer #(
        .SBUF_TYPE      (4),    // Bypass
        .DATA_WIDTH     (AXIS_INFO_W) 
    ) axis_sb (
        .clk            (aclk),
        .rst_n          (aresetn),
        .bwd_data_i     ({m_tid,    m_tdest,    m_tdata,   m_tlast}),
        .bwd_valid_i    (m_tvalid),
        .bwd_ready_o    (m_tready),
        .fwd_data_o     ({m_tid_o,  m_tdest_o,  m_tdata_o,  m_tlast_o}),
        .fwd_valid_o    (m_tvalid_o),
        .fwd_ready_i    (m_tready_i)
    );
    // -- ATX info buffer
    sync_fifo #(
        .FIFO_TYPE      (1),    // Normal type
        .DATA_WIDTH     (DMA_CHN_NUM_W + DST_TDEST_W + ATX_LEN_W),    // CHN_ID + TDEST + LEN
        .FIFO_DEPTH     (ATX_NUM_OSTD) 
    ) atx_buffer (
        .clk            (aclk),
        .data_i         ({atx_chn_id,   atx_tdest,  atx_tlen}),
        .wr_valid_i     (atx_vld),
        .wr_ready_o     (atx_rdy),
        .data_o         ({cur_chn_id,   cur_tdest,  cur_tlen}),
        .rd_valid_i     (m_tlast & m_axis_hsk),
        .rd_ready_o     (cur_atx_vld),
        .empty_o        (),
        .full_o         (),
        .almost_empty_o (),
        .almost_full_o  (),
        .counter        (),
        .rst_n          (aresetn)
    );
    // Combinational logic
    assign m_tid         = atx_id_pck[cur_chn_id];
    assign m_tdest       = cur_tdest;
    assign m_tdata       = atx_wdata;
    assign m_tlast       = ~|(tdata_cnt^cur_tlen);
    assign m_tkeep_o     = {ATX_DST_BYTE_AMT{1'b1}};
    assign m_tstrb_o     = {ATX_DST_BYTE_AMT{1'b1}};
    assign m_tvalid      = atx_wdata_vld & atx_wdata_rdy;
    assign atx_wdata_rdy = m_tready & cur_atx_vld;
    assign m_axis_hsk    = m_tvalid & m_tready;
generate
for (chn_idx = 0; chn_idx < DMA_CHN_NUM; chn_idx = chn_idx + 1) begin : gen_atx_signals
    assign atx_id_pck[chn_idx]  = atx_id[(chn_idx+1)*MST_ID_W-1-:MST_ID_W];
    assign atx_done[chn_idx]    = (cur_chn_id == chn_idx) & (m_tlast & m_axis_hsk);
    assign atx_dst_err[chn_idx] = 1'b0;
end
endgenerate

// Flip-flop
always @(posedge aclk or negedge aresetn) begin
    if(~aresetn) begin
        tdata_cnt <= {ATX_LEN_W{1'b0}};
    end
    else if(m_axis_hsk) begin
        if(m_tlast) begin
            tdata_cnt <= {ATX_LEN_W{1'b0}};
        end
        else begin
            tdata_cnt <= tdata_cnt + 1'b1;
        end
    end
end
endmodule