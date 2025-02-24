module adma_dm_wr_host #(
    // DMA
    parameter DMA_CHN_NUM       = 4,    // Number of DMA channels
    parameter ROB_EN            = 1,
    // AXI Interface
    parameter DST_ADDR_W        = 32,
    parameter MST_ID_W          = 5,
    parameter ATX_LEN_W         = 8,
    parameter ATX_SIZE_W        = 3,
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
    input   [DST_ADDR_W-1:0]        atx_awaddr,
    input   [ATX_LEN_W-1:0]         atx_awlen,
    input   [1:0]                   atx_awburst,
    input                           atx_vld,
    output                          atx_rdy,
    // AXI Transaction control
    input   [ATX_DST_DATA_W-1:0]    atx_wdata,
    input                           atx_wdata_vld,
    output                          atx_wdata_rdy,
    input   [MST_ID_W-1:0]          atx_id      [0:DMA_CHN_NUM-1],
    output                          atx_dst_err [0:DMA_CHN_NUM-1],
    output                          atx_done    [0:DMA_CHN_NUM-1],
    // AXI Master interface
    // -- AW channel         
    output  [MST_ID_W-1:0]          m_awid_o,
    output  [DST_ADDR_W-1:0]        m_awaddr_o,
    output  [ATX_LEN_W-1:0]         m_awlen_o,
    output  [1:0]                   m_awburst_o,
    output                          m_awvalid_o,
    input                           m_awready_i,
    // -- W channel          
    output  [ATX_DST_DATA_W-1:0]    m_wdata_o,
    output                          m_wlast_o,
    output                          m_wvalid_o,
    input                           m_wready_i,
    // -- B channel
    input   [MST_ID_W-1:0]          m_bid_i,
    input   [ATX_RESP_W-1:0]        m_bresp_i,
    input                           m_bvalid_i,
    output                          m_bready_o
);
    // Internal signal
    wire atx_vld_flt;
    wire atx_aw_rdy;
    wire atx_w_rdy;
    wire atx_b_rdy;
    // Module instantiation
    // -- AW channel
    adma_dm_axi_ax #(
        .ATX_ADDR_W     (DST_ADDR_W),
        .MST_ID_W       (MST_ID_W),
        .ATX_LEN_W      (ATX_LEN_W),
        .ATX_SIZE_W     (ATX_SIZE_W),
        .ATX_NUM_OSTD   (ATX_NUM_OSTD)
    ) aw (
        .clk            (clk),
        .rst_n          (rst_n),
        .atx_axid       (atx_awid),
        .atx_axaddr     (atx_awaddr),
        .atx_axlen      (atx_awlen),
        .atx_axburst    (atx_awburst),
        .atx_vld        (atx_vld_flt),
        .atx_rdy        (atx_aw_rdy),
        .m_axid_o       (m_awid_o),
        .m_axaddr_o     (m_awaddr_o),
        .m_axlen_o      (m_awlen_o),
        .m_axburst_o    (m_awburst_o),
        .m_axvalid_o    (m_awvalid_o),
        .m_axready_i    (m_awready_i)
    );  
    // -- W channel
    adma_dm_axi_w #(
        .ATX_LEN_W      (ATX_LEN_W),
        .ATX_DST_DATA_W (ATX_DST_DATA_W),
        .ATX_NUM_OSTD   (ATX_NUM_OSTD)
    ) w (
        .clk            (clk),
        .rst_n          (rst_n),
        .atx_awlen      (atx_awlen),
        .atx_vld        (atx_vld_flt),
        .atx_rdy        (atx_w_rdy),
        .atx_wdata      (atx_wdata),
        .atx_wdata_vld  (atx_wdata_vld),
        .atx_wdata_rdy  (atx_wdata_rdy),
        .m_wdata_o      (m_wdata_o),
        .m_wlast_o      (m_wlast_o),
        .m_wvalid_o     (m_wvalid_o),
        .m_wready_i     (m_wready_i)
    );
    // -- B channel
    adma_dm_axi_b #(
        .DMA_CHN_NUM    (DMA_CHN_NUM),
        .ROB_EN         (ROB_EN),
        .MST_ID_W       (MST_ID_W),
        .ATX_RESP_W     (ATX_RESP_W),
        .ATX_DST_DATA_W (ATX_DST_DATA_W),
        .ATX_NUM_OSTD   (ATX_NUM_OSTD),
        .ATX_INTL_DEPTH (ATX_INTL_DEPTH)
    ) b (
        .clk            (clk),
        .rst_n          (rst_n),
        .atx_chn_id     (atx_chn_id),
        .atx_awid       (atx_awid),
        .atx_vld        (atx_vld_flt),
        .atx_rdy        (atx_b_rdy),
        .atx_id         (atx_id),
        .atx_dst_err    (atx_dst_err),
        .atx_done       (atx_done),
        .m_bid_i        (m_bid_i),
        .m_bresp_i      (m_bresp_i),
        .m_bvalid_i     (m_bvalid_i),
        .m_bready_o     (m_bready_o)
    );
    // Combinational logic
    assign atx_rdy      = atx_aw_rdy & atx_w_rdy & atx_b_rdy;
    assign atx_vld_flt  = atx_vld & atx_rdy;
endmodule