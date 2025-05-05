module adma_dm_axi_ax #(
    // AXI Interface
    parameter ATX_ADDR_W        = 32,
    parameter MST_ID_W          = 5,
    parameter ATX_LEN_W         = 8,
    parameter ATX_SIZE_W        = 3,
    parameter ATX_NUM_OSTD      = 4   // Number of outstanding transactions in AXI bus (recmd: equal to the number of channel)
) (
    input                       clk,
    input                       rst_n,
    // AXI Transaction information
    input   [MST_ID_W-1:0]      atx_axid,
    input   [ATX_ADDR_W-1:0]    atx_axaddr,
    input   [ATX_LEN_W-1:0]     atx_axlen,
    input   [1:0]               atx_axburst,
    input                       atx_vld,
    output                      atx_rdy,
    // AXI Master Interface
    // -- AR channel         
    output  [MST_ID_W-1:0]      m_axid_o,
    output  [ATX_ADDR_W-1:0]    m_axaddr_o,
    output  [ATX_LEN_W-1:0]     m_axlen_o,
    output  [1:0]               m_axburst_o,
    output                      m_axvalid_o,
    input                       m_axready_i
);
    // Local parameters
    localparam AX_INFO_W    = MST_ID_W + ATX_ADDR_W + ATX_LEN_W + 2; // AxID + AxADDR + AxLEN + AxBURST
    // Internal signal
    wire    [MST_ID_W-1:0]      m_axid;
    wire    [ATX_ADDR_W-1:0]    m_axaddr;
    wire    [ATX_LEN_W-1:0]     m_axlen;
    wire    [1:0]               m_axburst;
    wire                        m_axvalid;
    wire                        m_axready;
    wire                        sb_bwd_vld;
    wire                        sb_bwd_rdy;
    // Module instantiation
    // -- Outstanding transaction buffer
    sync_fifo #(
        .FIFO_TYPE      (1),    // Normal type
        .DATA_WIDTH     (AX_INFO_W),
        .FIFO_DEPTH     (ATX_NUM_OSTD) 
    ) ostd_buffer (
        .clk            (clk),
        .data_i         ({atx_axid, atx_axaddr, atx_axlen,  atx_axburst}),
        .wr_valid_i     (atx_vld),
        .wr_ready_o     (atx_rdy),
        .data_o         ({m_axid,   m_axaddr,   m_axlen,    m_axburst}),
        .rd_valid_i     (sb_bwd_rdy),
        .rd_ready_o     (sb_bwd_vld),
        .empty_o        (),
        .full_o         (),
        .almost_empty_o (),
        .almost_full_o  (),
        .counter        (),
        .rst_n          (rst_n)
    );
    // -- Skid buffer
    skid_buffer #(
        .SBUF_TYPE      (0),    // Full-registered type
        .DATA_WIDTH     (AX_INFO_W) 
    ) ax_sb (
        .clk            (clk),
        .rst_n          (rst_n),
        .bwd_data_i     ({m_axid,   m_axaddr,   m_axlen,    m_axburst}),
        .bwd_valid_i    (sb_bwd_vld),
        .bwd_ready_o    (sb_bwd_rdy),
        .fwd_data_o     ({m_axid_o, m_axaddr_o, m_axlen_o,  m_axburst_o}),
        .fwd_valid_o    (m_axvalid_o),
        .fwd_ready_i    (m_axready_i)
    );
endmodule