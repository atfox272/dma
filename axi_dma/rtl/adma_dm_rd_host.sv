module adma_dm_rd_host #(
    // DMA
    parameter DMA_CHN_NUM       = 4,    // Number of DMA channels
    parameter ROB_EN            = 1,
    // SOURCE 
    parameter SRC_IF_TYPE       = "AXI4", // "AXI4" || "AXIS"
    parameter SRC_ADDR_W        = 32,
    parameter SRC_TDEST_W       = 2,
    parameter ATX_SRC_DATA_W    = 256,
    // AXI Interface
    parameter MST_ID_W          = 5,
    parameter ATX_LEN_W         = 8,
    parameter ATX_SIZE_W        = 3,
    parameter ATX_RESP_W        = 2,
    parameter ATX_SRC_BYTE_AMT  = ATX_SRC_DATA_W/8,
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
    
    // Source port
    // -- AXI4
    // -- -- AR channel         
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
    // -- AXI-Stream
    input   [MST_ID_W-1:0]          s_tid_i,    
    input   [SRC_TDEST_W-1:0]       s_tdest_i,
    input   [ATX_SRC_DATA_W-1:0]    s_tdata_i,
    input   [ATX_SRC_BYTE_AMT-1:0]  s_tkeep_i,
    input   [ATX_SRC_BYTE_AMT-1:0]  s_tstrb_i,
    input                           s_tlast_i,
    input                           s_tvalid_i,
    output                          s_tready_o
);
    // Internal signal
    wire atx_vld_flt;   // Filtered valid signal
    wire atx_ar_rdy;
    wire atx_r_rdy;
    wire atx_axis_rdy;
    // Module instantiation
generate
if(SRC_IF_TYPE == "AXI4") begin : SRC_AXI4_GEN
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
    // AXI-Stream is not used
    assign s_tready_o   = 1'b0;
    // Combinational logic
    assign atx_rdy      = atx_ar_rdy & atx_r_rdy;
    assign atx_vld_flt  = atx_vld & atx_rdy; // Filtered valid is asserted only when all channels are ready 
end
else if(SRC_IF_TYPE == "AXIS") begin : SRC_AXIS_GEN
    // -- AXI-Stream slave
    adma_dm_src_axis #(
        .DMA_CHN_NUM    (DMA_CHN_NUM),
        .ROB_EN         (ROB_EN),
        .SRC_TDEST_W    (SRC_TDEST_W),
        .ATX_SRC_DATA_W (ATX_SRC_DATA_W),
        .ATX_SRC_BYTE_AMT(ATX_SRC_BYTE_AMT),
        .MST_ID_W       (MST_ID_W)
    ) as (
        .aclk           (clk),
        .aresetn        (rst_n),
        .atx_arid       (atx_arid),
        .atx_arlen      (atx_arlen),
        .atx_vld        (atx_vld),
        .atx_rdy        (atx_rdy),
        .atx_rdata      (atx_rdata),
        .atx_rdata_vld  (atx_rdata_vld),
        .atx_rdata_rdy  (atx_rdata_rdy),
        .atx_id         (atx_id),
        .atx_src_err    (atx_src_err),
        .s_tid_i        (s_tid_i),
        .s_tdest_i      (s_tdest_i),
        .s_tdata_i      (s_tdata_i),
        .s_tkeep_i      (s_tkeep_i),
        .s_tstrb_i      (s_tstrb_i),
        .s_tlast_i      (s_tlast_i),
        .s_tvalid_i     (s_tvalid_i),
        .s_tready_o     (s_tready_o)
    );
    // AXI4 is not used
    assign m_arid_o     = {MST_ID_W{1'b0}};
    assign m_araddr_o   = {SRC_ADDR_W{1'b0}};
    assign m_arlen_o    = {ATX_LEN_W{1'b0}};
    assign m_arburst_o  = 2'b00;
    assign m_arvalid_o  = 1'b0;
end
endgenerate
endmodule