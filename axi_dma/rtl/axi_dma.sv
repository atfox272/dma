module axi_dma #(
    // DMA
    parameter DMA_BASE_ADDR     = 32'h8000_0000,
    parameter DMA_CHN_NUM       = 4,    // Number of DMA channels
    parameter DMA_LENGTH_W      = 16,   // Maximum size of 1 transfer is (2^16 * 256) 
    parameter DMA_DESC_DEPTH    = 4,    // The maximum number of descriptors in each channel
    parameter DMA_CHN_ARB_W     = 3,    // Channel arbitration weight's width
    parameter ROB_EN            = 0,    // Reorder multiple AXI outstanding transactions enable
    parameter DESC_QUEUE_TYPE   = (DMA_DESC_DEPTH >= 16) ? "RAM-BASED" : "FLIPFLOP-BASED",
    // AXI4 Master 
    parameter ATX_SRC_DATA_W    = 256,
    parameter ATX_DST_DATA_W    = 256,
    // AXI4 Slave
    parameter S_DATA_W          = 32,
    parameter S_ADDR_W          = 32,
    // AXI4 BUS 
    parameter SRC_ADDR_W        = 32,
    parameter DST_ADDR_W        = 32,
    parameter MST_ID_W          = 5,
    parameter ATX_LEN_W         = 8,
    parameter ATX_SIZE_W        = 3,
    parameter ATX_RESP_W        = 2,
    parameter ATX_NUM_OSTD      = DMA_CHN_NUM,  // Number of outstanding transactions in AXI bus (recmd: equal to the number of channel)
    parameter ATX_INTL_DEPTH    = 16 // Interleaving depth on the AXI data channel 
) (
    input                           aclk,
    input                           aresetn,

    // AXI4 Slave Interface            
    // -- AW channel         
    input   [MST_ID_W-1:0]          s_awid_i,
    input   [S_ADDR_W-1:0]          s_awaddr_i,
    input   [ATX_LEN_W-1:0]         s_awlen_i,
    input                           s_awvalid_i,
    output                          s_awready_o,
    // -- W channel          
    input   [S_DATA_W-1:0]          s_wdata_i,
    input                           s_wlast_i,
    input                           s_wvalid_i,
    output                          s_wready_o,
    // -- B channel          
    output  [MST_ID_W-1:0]          s_bid_o,
    output  [ATX_RESP_W-1:0]        s_bresp_o,
    output                          s_bvalid_o,
    input                           s_bready_i,
    // -- AR channel         
    input   [MST_ID_W-1:0]          s_arid_i,
    input   [S_ADDR_W-1:0]          s_araddr_i,
    input   [ATX_LEN_W-1:0]         s_arlen_i,
    input                           s_arvalid_i,
    output                          s_arready_o,
    // -- R channel          
    output  [MST_ID_W-1:0]          s_rid_o,
    output  [S_DATA_W-1:0]          s_rdata_o,
    output  [ATX_RESP_W-1:0]        s_rresp_o,
    output                          s_rlast_o,
    output                          s_rvalid_o,
    input                           s_rready_i,
    
    // AXI4 Master Read (source) port
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

    // AXI4 Master Write (destination) port
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
    output                          m_bready_o,

    // Interrupt
    output                          irq         [0:DMA_CHN_NUM-1],  // Caused by TX Queueing, TX Completion
    output                          trap        [0:DMA_CHN_NUM-1]   // Caused by Wrong address mapping
);
    // Local parameters
    localparam DMA_XFER_ID_W        = $clog2(DMA_DESC_DEPTH);
    localparam DMA_CHN_NUM_W        = $clog2(DMA_CHN_NUM);
    // Internal variables 
    genvar chn_idx;
    // Internal connection
    // Registers Map
    // -- DMA CSRs
    wire                            dma_en;
    // -- Channel CSR
    wire                            chn_ctrl_en         [0:DMA_CHN_NUM-1];
    wire                            chn_xfer_2d         [0:DMA_CHN_NUM-1];
    wire                            chn_xfer_cyclic     [0:DMA_CHN_NUM-1];
    wire                            chn_irq_msk_irq_com [0:DMA_CHN_NUM-1];
    wire                            chn_irq_msk_irq_qed [0:DMA_CHN_NUM-1];
    wire                            chn_irq_src_irq_com [0:DMA_CHN_NUM-1];
    wire                            chn_irq_src_irq_qed [0:DMA_CHN_NUM-1];
    wire    [DMA_CHN_ARB_W-1:0]     chn_arb_rate        [0:DMA_CHN_NUM-1];
    // -- AXI4 Transaction CSR
    wire    [MST_ID_W-1:0]          atx_id              [0:DMA_CHN_NUM-1];
    wire    [1:0]                   atx_src_burst       [0:DMA_CHN_NUM-1];
    wire    [1:0]                   atx_dst_burst       [0:DMA_CHN_NUM-1];
    wire    [DMA_LENGTH_W-1:0]      atx_wd_per_burst    [0:DMA_CHN_NUM-1];
    // -- DMA Transfer CSR
    wire    [DMA_XFER_ID_W-1:0]     xfer_id             [0:DMA_CHN_NUM-1];
    wire    [DMA_DESC_DEPTH-1:0]    xfer_done           [0:DMA_CHN_NUM-1];
    wire    [DMA_XFER_ID_W-1:0]     active_xfer_id      [0:DMA_CHN_NUM-1];
    wire    [DMA_LENGTH_W-1:0]      active_xfer_len     [0:DMA_CHN_NUM-1];
    // Registers Map -> Descriptor Queue
    wire                            desc_wr_vld         [0:DMA_CHN_NUM-1];
    wire                            desc_wr_rdy         [0:DMA_CHN_NUM-1];
    wire    [SRC_ADDR_W-1:0]        desc_wr_src_addr    [0:DMA_CHN_NUM-1];
    wire    [DST_ADDR_W-1:0]        desc_wr_dst_addr    [0:DMA_CHN_NUM-1];
    wire    [DMA_LENGTH_W-1:0]      desc_wr_xlen        [0:DMA_CHN_NUM-1];
    wire    [DMA_LENGTH_W-1:0]      desc_wr_ylen        [0:DMA_CHN_NUM-1];
    wire    [DMA_LENGTH_W-1:0]      desc_wr_src_strd    [0:DMA_CHN_NUM-1];
    wire    [DMA_LENGTH_W-1:0]      desc_wr_dst_strd    [0:DMA_CHN_NUM-1];
    // Descriptor Queue -> Channel Management
    wire                            desc_rd_vld         [0:DMA_CHN_NUM-1];
    wire                            desc_rd_rdy         [0:DMA_CHN_NUM-1];
    wire    [DMA_XFER_ID_W-1:0]     desc_rd_xfer_id     [0:DMA_CHN_NUM-1];
    wire    [SRC_ADDR_W-1:0]        desc_rd_src_addr    [0:DMA_CHN_NUM-1];
    wire    [DST_ADDR_W-1:0]        desc_rd_dst_addr    [0:DMA_CHN_NUM-1];
    wire    [DMA_LENGTH_W-1:0]      desc_rd_xlen        [0:DMA_CHN_NUM-1];
    wire    [DMA_LENGTH_W-1:0]      desc_rd_ylen        [0:DMA_CHN_NUM-1];
    wire    [DMA_LENGTH_W-1:0]      desc_rd_src_strd    [0:DMA_CHN_NUM-1];
    wire    [DMA_LENGTH_W-1:0]      desc_rd_dst_strd    [0:DMA_CHN_NUM-1];
    wire    [DMA_DESC_DEPTH-1:0]    xfer_done_clear     [0:DMA_CHN_NUM-1];
    // Channel Management -> AXI Transaction Scheduler
    wire    [SRC_ADDR_W-1:0]        tx_src_addr         [0:DMA_CHN_NUM-1];
    wire    [DST_ADDR_W-1:0]        tx_dst_addr         [0:DMA_CHN_NUM-1];
    wire    [DMA_LENGTH_W-1:0]      tx_len              [0:DMA_CHN_NUM-1];
    wire                            tx_vld              [0:DMA_CHN_NUM-1];
    wire                            tx_rdy              [0:DMA_CHN_NUM-1];
    wire                            tx_done             [0:DMA_CHN_NUM-1];
    // AXI Transaction Scheduler -> Data Mover
    wire    [DMA_CHN_NUM_W-1:0]     atx_chn_id;
    wire    [MST_ID_W-1:0]          atx_arid;
    wire    [SRC_ADDR_W-1:0]        atx_araddr;
    wire    [ATX_LEN_W-1:0]         atx_arlen;
    wire    [1:0]                   atx_arburst;
    wire    [MST_ID_W-1:0]          atx_awid;
    wire    [DST_ADDR_W-1:0]        atx_awaddr;
    wire    [ATX_LEN_W-1:0]         atx_awlen;
    wire    [1:0]                   atx_awburst;
    wire                            atx_vld;
    wire                            atx_rdy;
    wire                            atx_done            [0:DMA_CHN_NUM-1];
    // Interrupt request
    wire                            irq_qed             [0:DMA_CHN_NUM-1];
    wire                            irq_com             [0:DMA_CHN_NUM-1];
    wire                            trap_atx_src_err    [0:DMA_CHN_NUM-1];
    wire                            trap_atx_dst_err    [0:DMA_CHN_NUM-1];
    // Module instantiation
    // -- Register Map
    adma_reg_map #(
        .DMA_BASE_ADDR      (DMA_BASE_ADDR),
        .DMA_CHN_NUM        (DMA_CHN_NUM),
        .DMA_LENGTH_W       (DMA_LENGTH_W),
        .DMA_DESC_DEPTH     (DMA_DESC_DEPTH),
        .DMA_CHN_ARB_W      (DMA_CHN_ARB_W),
        .S_DATA_W           (S_DATA_W),
        .S_ADDR_W           (S_ADDR_W),
        .SRC_ADDR_W         (SRC_ADDR_W),
        .DST_ADDR_W         (DST_ADDR_W),
        .MST_ID_W           (MST_ID_W),
        .ATX_LEN_W          (ATX_LEN_W),
        .ATX_SIZE_W         (ATX_SIZE_W),
        .ATX_RESP_W         (ATX_RESP_W)
    ) rm (
        .aclk               (aclk),
        .aresetn            (aresetn),
        .s_awid_i           (s_awid_i),
        .s_awaddr_i         (s_awaddr_i),
        .s_awlen_i          (s_awlen_i),
        .s_awvalid_i        (s_awvalid_i),
        .s_awready_o        (s_awready_o),
        .s_wdata_i          (s_wdata_i),
        .s_wlast_i          (s_wlast_i),
        .s_wvalid_i         (s_wvalid_i),
        .s_wready_o         (s_wready_o),
        .s_bid_o            (s_bid_o),
        .s_bresp_o          (s_bresp_o),
        .s_bvalid_o         (s_bvalid_o),
        .s_bready_i         (s_bready_i),
        .s_arid_i           (s_arid_i),
        .s_araddr_i         (s_araddr_i),
        .s_arlen_i          (s_arlen_i),
        .s_arvalid_i        (s_arvalid_i),
        .s_arready_o        (s_arready_o),
        .s_rid_o            (s_rid_o),
        .s_rdata_o          (s_rdata_o),
        .s_rresp_o          (s_rresp_o),
        .s_rlast_o          (s_rlast_o),
        .s_rvalid_o         (s_rvalid_o),
        .s_rready_i         (s_rready_i),
        .dma_en             (dma_en),
        .chn_ctrl_en        (chn_ctrl_en),
        .chn_xfer_2d        (chn_xfer_2d),
        .chn_xfer_cyclic    (chn_xfer_cyclic),
        .chn_irq_msk_irq_com(chn_irq_msk_irq_com),
        .chn_irq_msk_irq_qed(chn_irq_msk_irq_qed),
        .chn_irq_src_irq_com(chn_irq_src_irq_com),
        .chn_irq_src_irq_qed(chn_irq_src_irq_qed),
        .chn_arb_rate       (chn_arb_rate),
        .atx_id             (atx_id),
        .atx_src_burst      (atx_src_burst),
        .atx_dst_burst      (atx_dst_burst),
        .atx_wd_per_burst   (atx_wd_per_burst),
        .desc_wr_vld_o      (desc_wr_vld),
        .desc_wr_rdy_i      (desc_wr_rdy),
        .desc_src_addr_o    (desc_wr_src_addr),
        .desc_dst_addr_o    (desc_wr_dst_addr),
        .desc_xfer_xlen_o   (desc_wr_xlen),
        .desc_xfer_ylen_o   (desc_wr_ylen),
        .desc_src_strd_o    (desc_wr_src_strd),
        .desc_dst_strd_o    (desc_wr_dst_strd),
        .xfer_id            (xfer_id),
        .xfer_done          (xfer_done),
        .active_xfer_id     (active_xfer_id),
        .active_xfer_len    (active_xfer_len)
    );
    // -- Descriptor Queue
    adma_desc_queue #(
        .DMA_CHN_NUM        (DMA_CHN_NUM),
        .DMA_DESC_DEPTH     (DMA_DESC_DEPTH),
        .DESC_QUEUE_TYPE    (DESC_QUEUE_TYPE),
        .SRC_ADDR_W         (SRC_ADDR_W),
        .DST_ADDR_W         (DST_ADDR_W),
        .DMA_LENGTH_W       (DMA_LENGTH_W)
    ) dq (
        .clk                (clk),
        .rst_n              (rst_n),
        .queue_en_glb_i     (dma_en),
        .queue_en_i         (chn_ctrl_en),
        .src_addr_i         (desc_wr_src_addr),
        .dst_addr_i         (desc_wr_dst_addr),
        .xfer_xlen_i        (desc_wr_xlen),
        .xfer_ylen_i        (desc_wr_ylen),
        .src_stride_i       (desc_wr_src_strd),
        .dst_stride_i       (desc_wr_dst_strd),
        .desc_wr_vld_i      (desc_wr_vld),
        .desc_wr_rdy_o      (desc_wr_rdy),
        .xfer_id_o          (desc_rd_xfer_id),
        .src_addr_o         (desc_rd_src_addr),
        .dst_addr_o         (desc_rd_dst_addr),
        .xfer_xlen_o        (desc_rd_xlen),
        .xfer_ylen_o        (desc_rd_ylen),
        .src_stride_o       (desc_rd_src_strd),
        .dst_stride_o       (desc_rd_dst_strd),
        .desc_rd_vld_i      (desc_rd_vld),
        .desc_rd_rdy_o      (desc_rd_rdy),
        .xfer_done_clear    (xfer_done_clear),
        .chn_irq_msk_irq_qed(chn_irq_msk_irq_qed),
        .chn_irq_src_irq_qed(chn_irq_src_irq_qed),
        .nxt_xfer_id        (xfer_id),
        .irq_qed            (irq_qed)
    );

    adma_chn_man #(
        .DMA_CHN_NUM        (DMA_CHN_NUM),
        .DMA_DESC_DEPTH     (DMA_DESC_DEPTH),
        .SRC_ADDR_W         (SRC_ADDR_W),
        .DST_ADDR_W         (DST_ADDR_W),
        .DMA_LENGTH_W       (DMA_LENGTH_W)
    ) cm (
        .clk                (clk),
        .rst_n              (rst_n),
        .xfer_id_i          (desc_rd_xfer_id),
        .src_addr_i         (desc_rd_src_addr),
        .dst_addr_i         (desc_rd_dst_addr),
        .xfer_xlen_i        (desc_rd_xlen),
        .xfer_ylen_i        (desc_rd_ylen),
        .src_stride_i       (desc_rd_src_strd),
        .dst_stride_i       (desc_rd_dst_strd),
        .desc_rd_vld_o      (desc_rd_vld),
        .desc_rd_rdy_i      (desc_rd_rdy),
        .xfer_done_clear    (xfer_done_clear),
        .chn_xfer_2d        (chn_xfer_2d),
        .chn_xfer_cyclic    (chn_xfer_cyclic),
        .chn_irq_msk_irq_com(chn_irq_msk_irq_com),
        .chn_irq_src_irq_com(chn_irq_src_irq_com),
        .atx_src_burst      (atx_src_burst),
        .atx_dst_burst      (atx_dst_burst),
        .xfer_done          (xfer_done),
        .active_xfer_id     (active_xfer_id),
        .active_xfer_len    (active_xfer_len),
        .tx_src_addr        (tx_src_addr),
        .tx_dst_addr        (tx_dst_addr),
        .tx_len             (tx_len),
        .tx_vld             (tx_vld),
        .tx_rdy             (tx_rdy),
        .tx_done            (tx_done),
        .irq_com            (irq_com)
    );

    adma_atx_sched #(
        .DMA_CHN_NUM        (DMA_CHN_NUM),
        .DMA_CHN_ARB_W      (DMA_CHN_ARB_W),
        .DMA_LENGTH_W       (DMA_LENGTH_W),
        .SRC_ADDR_W         (SRC_ADDR_W),
        .DST_ADDR_W         (DST_ADDR_W),
        .MST_ID_W           (MST_ID_W),
        .ATX_LEN_W          (ATX_LEN_W),
        .ATX_NUM_OSTD       (ATX_NUM_OSTD)
    ) as (
        .clk                (clk),
        .rst_n              (rst_n),
        .tx_src_addr        (tx_src_addr),
        .tx_dst_addr        (tx_dst_addr),
        .tx_len             (tx_len),
        .tx_vld             (tx_vld),
        .tx_rdy             (tx_rdy),
        .tx_done            (tx_done),
        .atx_id             (atx_id),
        .atx_src_burst      (atx_src_burst),
        .atx_dst_burst      (atx_dst_burst),
        .atx_wd_per_burst   (atx_wd_per_burst),
        .chn_arb_rate       (chn_arb_rate),
        .atx_chn_id         (atx_chn_id),
        .atx_arid           (atx_arid),
        .atx_araddr         (atx_araddr),
        .atx_arlen          (atx_arlen),
        .atx_arburst        (atx_arburst),
        .atx_awid           (atx_awid),
        .atx_awaddr         (atx_awaddr),
        .atx_awlen          (atx_awlen),
        .atx_awburst        (atx_awburst),
        .atx_vld            (atx_vld),
        .atx_rdy            (atx_rdy),
        .atx_done           (atx_done)
    );

    adma_data_mover #(
        .DMA_CHN_NUM        (DMA_CHN_NUM),
        .ROB_EN             (ROB_EN),
        .SRC_ADDR_W         (SRC_ADDR_W),
        .DST_ADDR_W         (DST_ADDR_W),
        .MST_ID_W           (MST_ID_W),
        .ATX_LEN_W          (ATX_LEN_W),
        .ATX_SIZE_W         (ATX_SIZE_W),
        .ATX_RESP_W         (ATX_RESP_W),
        .ATX_SRC_DATA_W     (ATX_SRC_DATA_W),
        .ATX_DST_DATA_W     (ATX_DST_DATA_W),
        .ATX_NUM_OSTD       (ATX_NUM_OSTD),
        .ATX_INTL_DEPTH     (ATX_INTL_DEPTH)
    ) dm (
        .clk                (clk),
        .rst_n              (rst_n),
        .atx_chn_id         (atx_chn_id),
        .atx_arid           (atx_arid),
        .atx_araddr         (atx_araddr),
        .atx_arlen          (atx_arlen),
        .atx_arburst        (atx_arburst),
        .atx_awid           (atx_awid),
        .atx_awaddr         (atx_awaddr),
        .atx_awlen          (atx_awlen),
        .atx_awburst        (atx_awburst),
        .atx_vld            (atx_vld),
        .atx_rdy            (atx_rdy),
        .atx_done           (atx_done),
        .atx_id             (atx_id),
        .atx_src_err        (trap_atx_src_err),
        .atx_dst_err        (trap_atx_dst_err),
        .m_arid_o           (m_arid_o),
        .m_araddr_o         (m_araddr_o),
        .m_arlen_o          (m_arlen_o),
        .m_arburst_o        (m_arburst_o),
        .m_arvalid_o        (m_arvalid_o),
        .m_arready_i        (m_arready_i),
        .m_rid_i            (m_rid_i),
        .m_rdata_i          (m_rdata_i),
        .m_rresp_i          (m_rresp_i),
        .m_rlast_i          (m_rlast_i),
        .m_rvalid_i         (m_rvalid_i),
        .m_rready_o         (m_rready_o),
        .m_awid_o           (m_awid_o),
        .m_awaddr_o         (m_awaddr_o),
        .m_awlen_o          (m_awlen_o),
        .m_awburst_o        (m_awburst_o),
        .m_awvalid_o        (m_awvalid_o),
        .m_awready_i        (m_awready_i),
        .m_wdata_o          (m_wdata_o),
        .m_wlast_o          (m_wlast_o),
        .m_wvalid_o         (m_wvalid_o),
        .m_wready_i         (m_wready_i),
        .m_bid_i            (m_bid_i),
        .m_bresp_i          (m_bresp_i),
        .m_bvalid_i         (m_bvalid_i),
        .m_bready_o         (m_bready_o)
    );
    // Combine all interrupts and traps
generate
for (chn_idx = 0; chn_idx < DMA_CHN_NUM; chn_idx = chn_idx + 1) begin : UNPACK_GEN
    assign irq[chn_idx]     = irq_qed[chn_idx] | irq_com[chn_idx];
    assign trap[chn_idx]    = trap_atx_src_err[chn_idx] | trap_atx_dst_err[chn_idx];
end
endgenerate
endmodule