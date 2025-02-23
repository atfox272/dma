module adma_dm_rd_host #(
    // DMA
    parameter DMA_CHN_NUM       = 4,    // Number of DMA channels
    parameter ROB_EN            = 1,
    // AXI Interface
    parameter SRC_ADDR_W        = 32,
    parameter MST_ID_W          = 5,
    parameter ATX_LEN_W         = 8,
    parameter ATX_SIZE_W        = 3,
    parameter ATX_RESP_W        = 2,
    parameter ATX_SRC_DATA_W    = 256,
    parameter ATX_NUM_OSTD      = DMA_CHN_NUM,   // Number of outstanding transactions in AXI bus (recmd: equal to the number of channel)
    parameter ATX_INTL_DEPTH    = 16 // Interleaving depth on the AXI data channel 
) (
    input                           clk,
    input                           rst_n,
    // AXI Transaction information
    input   [MST_ID_W-1:0]          atx_arid,
    input   [SRC_ADDR_W-1:0]        atx_araddr,
    input   [ATX_LEN_W-1:0]         atx_arlen,
    input   [1:0]                   atx_arburst,
    input                           atx_vld,
    output                          atx_rdy,
    // AXI Transaction control
    output  [ATX_SRC_DATA_W-1:0]    atx_rdata,
    output                          atx_rdata_vld,
    input                           atx_rdata_rdy,
    input   [MST_ID_W-1:0]          atx_id      [0:DMA_CHN_NUM-1],
    output                          atx_src_err [0:DMA_CHN_NUM-1],
    // AXI Master Interface
    // -- AR channel         
    output  [MST_ID_W-1:0]          m_arid_o,
    output  [SRC_ADDR_W-1:0]        m_araddr_o,
    output  [ATX_LEN_W-1:0]         m_arlen_o,
    output  [1:0]                   m_arburst_o,
    output                          m_arvalid_o,
    input                           m_arready_i,
    // -- R channel  
    input   [MST_ID_W-1:0]          m_rid_i,
    input   [ATX_SRC_DATA_W-1:0]    m_rdata_i,
    input   [ATX_RESP_W-1:0]        m_rresp_i,
    input                           m_rlast_i,
    input                           m_rvalid_i,
    output                          m_rready_o
);
    // Internal signal
    wire atx_vld_flt;   // Filtered valid signal
    wire atx_ar_rdy;
    wire atx_r_rdy;
    // Module instantiation
    // -- AR channel
    adma_dm_axi_ax #(
        .ATX_ADDR_W     (SRC_ADDR_W),
        .MST_ID_W       (MST_ID_W),
        .ATX_LEN_W      (ATX_LEN_W),
        .ATX_SIZE_W     (ATX_SIZE_W),
        .ATX_NUM_OSTD   (ATX_NUM_OSTD)
    ) ar (
        .clk            (clk),
        .rst_n          (rst_n),
        .atx_axid       (atx_arid),
        .atx_axaddr     (atx_araddr),
        .atx_axlen      (atx_arlen),
        .atx_axburst    (atx_arburst),
        .atx_vld        (atx_vld_flt),
        .atx_rdy        (atx_ar_rdy),
        .m_axid_o       (m_arid_o),
        .m_axaddr_o     (m_araddr_o),
        .m_axlen_o      (m_arlen_o),
        .m_axburst_o    (m_arburst_o),
        .m_axvalid_o    (m_arvalid_o),
        .m_axready_i    (m_arready_i)
    );
    // -- R channel
    adma_dm_axi_r #(
        .DMA_CHN_NUM    (DMA_CHN_NUM),
        .ROB_EN         (ROB_EN),
        .MST_ID_W       (MST_ID_W),
        .ATX_LEN_W      (ATX_LEN_W),
        .ATX_SIZE_W     (ATX_SIZE_W),
        .ATX_RESP_W     (ATX_RESP_W),
        .ATX_SRC_DATA_W (ATX_SRC_DATA_W),
        .ATX_NUM_OSTD   (ATX_NUM_OSTD),
        .ATX_INTL_DEPTH (ATX_INTL_DEPTH)
    ) r (
        .clk            (clk),
        .rst_n          (rst_n),
        .atx_chn_id     (atx_chn_id),
        .atx_arid       (atx_arid),
        .atx_arlen      (atx_arlen),
        .atx_vld        (atx_vld_flt),
        .atx_rdy        (atx_r_rdy),
        .atx_rdata      (atx_rdata),
        .atx_rdata_vld  (atx_rdata_vld),
        .atx_rdata_rdy  (atx_rdata_rdy),
        .atx_id         (atx_id),
        .atx_src_err    (atx_src_err),
        .m_rid_i        (m_rid_i),
        .m_rdata_i      (m_rdata_i),
        .m_rresp_i      (m_rresp_i),
        .m_rlast_i      (m_rlast_i),
        .m_rvalid_i     (m_rvalid_i),
        .m_rready_o     (m_rready_o)
    );
    // Combinational logic
    assign atx_rdy      = atx_ar_rdy & atx_r_rdy;
    assign atx_vld_flt  = atx_vld & atx_rdy; // Filtered valid is asserted only when all channels are ready 
endmodule