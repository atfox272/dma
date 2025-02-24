module adma_data_mover #(
    // DMA
    parameter DMA_CHN_NUM       = 4,    // Number of DMA channels
    parameter ROB_EN            = 1,
    // AXI Interface
    parameter SRC_ADDR_W        = 32,
    parameter DST_ADDR_W        = 32,
    parameter MST_ID_W          = 5,
    parameter ATX_LEN_W         = 8,
    parameter ATX_SIZE_W        = 3,
    parameter ATX_RESP_W        = 2,
    parameter ATX_SRC_DATA_W    = 256,
    parameter ATX_DST_DATA_W    = 256,
    parameter ATX_NUM_OSTD      = (DMA_CHN_NUM > 1) ? DMA_CHN_NUM : 2,   // Number of outstanding transactions in AXI bus (recmd: equal to the number of channel)
    parameter ATX_INTL_DEPTH    = 16, // Interleaving depth on the AXI data channel 
    // Do not configure these
    parameter DMA_CHN_NUM_W     = (DMA_CHN_NUM > 1) ? $clog2(DMA_CHN_NUM) : 1
) (
    input                           clk,
    input                           rst_n,
    // AXI Transaction information
    input   [DMA_CHN_NUM_W-1:0]     atx_chn_id,
    input   [MST_ID_W-1:0]          atx_arid,
    input   [SRC_ADDR_W-1:0]        atx_araddr,
    input   [ATX_LEN_W-1:0]         atx_arlen,
    input   [1:0]                   atx_arburst,
    input   [MST_ID_W-1:0]          atx_awid,
    input   [DST_ADDR_W-1:0]        atx_awaddr,
    input   [ATX_LEN_W-1:0]         atx_awlen,
    input   [1:0]                   atx_awburst,
    input                           atx_vld,
    output                          atx_rdy,
    // AXI Transaction control
    input   [MST_ID_W-1:0]          atx_id      [0:DMA_CHN_NUM-1],
    output                          atx_done    [0:DMA_CHN_NUM-1],
    output                          atx_src_err [0:DMA_CHN_NUM-1],
    output                          atx_dst_err [0:DMA_CHN_NUM-1],
    // AXI Master Interface
    // -- AR channel         
    output  [MST_ID_W-1:0]          m_arid_o,
    output  [SRC_ADDR_W-1:0]        m_araddr_o,
    output  [ATX_LEN_W-1:0]         m_arlen_o,
    output  [1:0]                   m_arburst_o,
    output                          m_arvalid_o,
    input                           m_arready_i,
    // -- -- R channel  
    input   [MST_ID_W-1:0]          m_rid_i,
    input   [ATX_SRC_DATA_W-1:0]    m_rdata_i,
    input   [ATX_RESP_W-1:0]        m_rresp_i,
    input                           m_rlast_i,
    input                           m_rvalid_i,
    output                          m_rready_o,
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
    wire                        atx_vld_flt;
    wire                        atx_r_rdy;
    wire                        atx_w_rdy;
    wire [ATX_SRC_DATA_W-1:0]   db_src_data;
    wire                        db_src_vld;
    wire                        db_src_rdy;
    wire [ATX_DST_DATA_W-1:0]   db_dst_data;
    wire                        db_dst_vld;
    wire                        db_dst_rdy;
    // Module instantiation
    // -- Read host
    adma_dm_rd_host #(
        .DMA_CHN_NUM    (DMA_CHN_NUM),
        .ROB_EN         (ROB_EN),
        .SRC_ADDR_W     (SRC_ADDR_W),
        .MST_ID_W       (MST_ID_W),
        .ATX_LEN_W      (ATX_LEN_W),
        .ATX_SIZE_W     (ATX_SIZE_W),
        .ATX_RESP_W     (ATX_RESP_W),
        .ATX_SRC_DATA_W (ATX_SRC_DATA_W),
        .ATX_NUM_OSTD   (ATX_NUM_OSTD),
        .ATX_INTL_DEPTH (ATX_INTL_DEPTH)
    ) rh (
        .clk            (clk),
        .rst_n          (rst_n),
        .atx_chn_id     (atx_chn_id),
        .atx_arid       (atx_arid),
        .atx_araddr     (atx_araddr),
        .atx_arlen      (atx_arlen),
        .atx_arburst    (atx_arburst),
        .atx_vld        (atx_vld_flt),
        .atx_rdy        (atx_r_rdy),
        .atx_rdata      (db_src_data),
        .atx_rdata_vld  (db_src_vld),
        .atx_rdata_rdy  (db_src_rdy),
        .atx_id         (atx_id),
        .atx_src_err    (atx_src_err),
        .m_arid_o       (m_arid_o),
        .m_araddr_o     (m_araddr_o),
        .m_arlen_o      (m_arlen_o),
        .m_arburst_o    (m_arburst_o),
        .m_arvalid_o    (m_arvalid_o),
        .m_arready_i    (m_arready_i),
        .m_rid_i        (m_rid_i),
        .m_rdata_i      (m_rdata_i),
        .m_rresp_i      (m_rresp_i),
        .m_rlast_i      (m_rlast_i),
        .m_rvalid_i     (m_rvalid_i),
        .m_rready_o     (m_rready_o)
    );
    // -- Write host
    adma_dm_wr_host #(
        .DMA_CHN_NUM    (DMA_CHN_NUM),
        .ROB_EN         (ROB_EN),
        .DST_ADDR_W     (DST_ADDR_W),
        .MST_ID_W       (MST_ID_W),
        .ATX_LEN_W      (ATX_LEN_W),
        .ATX_SIZE_W     (ATX_SIZE_W),
        .ATX_RESP_W     (ATX_RESP_W),
        .ATX_DST_DATA_W (ATX_DST_DATA_W),
        .ATX_NUM_OSTD   (ATX_NUM_OSTD),
        .ATX_INTL_DEPTH (ATX_INTL_DEPTH)
    ) wh (
        .clk            (clk),
        .rst_n          (rst_n),
        .atx_chn_id     (atx_chn_id),
        .atx_awid       (atx_awid),
        .atx_awaddr     (atx_awaddr),
        .atx_awlen      (atx_awlen),
        .atx_awburst    (atx_awburst),
        .atx_vld        (atx_vld_flt),
        .atx_rdy        (atx_w_rdy),
        .atx_wdata      (db_dst_data),
        .atx_wdata_vld  (db_dst_vld),
        .atx_wdata_rdy  (db_dst_rdy),
        .atx_id         (atx_id),
        .atx_dst_err    (atx_dst_err),
        .atx_done       (atx_done),
        .m_awid_o       (m_awid_o),
        .m_awaddr_o     (m_awaddr_o),
        .m_awlen_o      (m_awlen_o),
        .m_awburst_o    (m_awburst_o),
        .m_awvalid_o    (m_awvalid_o),
        .m_awready_i    (m_awready_i),
        .m_wdata_o      (m_wdata_o),
        .m_wlast_o      (m_wlast_o),
        .m_wvalid_o     (m_wvalid_o),
        .m_wready_i     (m_wready_i),
        .m_bid_i        (m_bid_i),
        .m_bresp_i      (m_bresp_i),
        .m_bvalid_i     (m_bvalid_i),
        .m_bready_o     (m_bready_o)
    );
    // -- Data buffer
    adma_dm_data_buf #(
        .ATX_SRC_DATA_W (ATX_SRC_DATA_W),
        .ATX_DST_DATA_W (ATX_DST_DATA_W)
    ) db (
        .clk            (clk),
        .rst_n          (rst_n),
        .src_data       (db_src_data),
        .src_vld        (db_src_vld),
        .src_rdy        (db_src_rdy),
        .dst_data       (db_dst_data),
        .dst_vld        (db_dst_vld),
        .dst_rdy        (db_dst_rdy)
    );
    // Combinational logic
    assign atx_rdy      = atx_w_rdy & atx_r_rdy;
    assign atx_vld_flt  = atx_vld & atx_rdy;

endmodule
