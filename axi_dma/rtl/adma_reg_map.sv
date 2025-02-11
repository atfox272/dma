module adma_reg_map
#(
    // DMA
    parameter DST_CHANNEL_NUM    = 4,
    // AXI4 Slave
    parameter S_DATA_W          = 32,
    // AXI4 BUS 
    parameter ADDR_W            = 32,
    parameter MST_ID_W          = 5,
    parameter TRANS_DATA_LEN_W  = 8,
    parameter TRANS_DATA_SIZE_W = 3,
    parameter TRANS_RESP_W      = 2
) (
    
    input                                   aclk,
    input                                   aresetn,
    // AXI4 Slave Interface            
    // -- AW channel         
    input   [MST_ID_W-1:0]                  s_awid_i,
    input   [ADDR_W-1:0]                    s_awaddr_i,
    input   [TRANS_DATA_LEN_W-1:0]          s_awlen_i,
    input                                   s_awvalid_i,
    output                                  s_awready_o,
    // -- W channel          
    input   [S_DATA_W-1:0]                  s_wdata_i,
    input                                   s_wlast_i,
    input                                   s_wvalid_i,
    output                                  s_wready_o,
    // -- B channel          
    output  [MST_ID_W-1:0]                  s_bid_o,
    output  [TRANS_RESP_W-1:0]              s_bresp_o,
    output                                  s_bvalid_o,
    input                                   s_bready_i,
    // -- AR channel         
    input   [MST_ID_W-1:0]                  s_arid_i,
    input   [ADDR_W-1:0]                    s_araddr_i,
    input   [TRANS_DATA_LEN_W-1:0]          s_arlen_i,
    input                                   s_arvalid_i,
    output                                  s_arready_o,
    // -- R channel          
    output  [MST_ID_W-1:0]                  s_rid_o,
    output  [S_DATA_W-1:0]                  s_rdata_o,
    output  [TRANS_RESP_W-1:0]              s_rresp_o,
    output                                  s_rlast_o,
    output                                  s_rvalid_o,
    input                                   s_rready_i
);
    
    // Module instantiation
    axi4_ctrl #(
        .AXI4_CTRL_CONF     (1),
        .AXI4_CTRL_STAT     (1),
        .AXI4_CTRL_MEM      (0),
        .AXI4_CTRL_WR_ST    (1),
        .AXI4_CTRL_RD_ST    (0),
        .DATA_W             (S_DATA_W),
        .ADDR_W             (ADDR_W),
        .MST_ID_W           (MST_ID_W),
        .CONF_BASE_ADDR     (),
        .CONF_OFFSET        (),
        .CONF_REG_NUM       ()
        
    ) ac (
        .clk            (aclk),
        .rst_n          (aresetn),
        .m_awid_i       (s_awid_i),
        .m_awaddr_i     (s_awaddr_i),
        .m_awlen_i      (s_awlen_i),
        .m_awvalid_i    (s_awvalid_i),
        .m_wdata_i      (s_wdata_i),
        .m_wlast_i      (s_wlast_i),
        .m_wvalid_i     (s_wvalid_i),
        .m_bready_i     (s_bready_i),
        .m_arid_i       (s_arid_i),
        .m_araddr_i     (s_araddr_i),
        .m_arlen_i      (s_arlen_i),
        .m_arvalid_i    (s_arvalid_i),
        .m_rready_i     (s_rready_i),
        .stat_reg_i     (),
        .mem_wr_rdy_i   (),
        .mem_rd_data_i  (),
        .mem_rd_rdy_i   (),
        .wr_st_rd_vld_i (),
        .rd_st_wr_data_i(),
        .rd_st_wr_vld_i (),
        .m_awready_o    (s_awready_o),
        .m_wready_o     (s_wready_o),
        .m_bid_o        (s_bid_o),
        .m_bresp_o      (s_bresp_o),
        .m_bvalid_o     (s_bvalid_o),
        .m_arready_o    (s_arready_o),
        .m_rid_o        (s_rid_o),
        .m_rdata_o      (s_rdata_o),
        .m_rresp_o      (s_rresp_o),
        .m_rlast_o      (s_rlast_o),
        .m_rvalid_o     (s_rvalid_o),
        .conf_reg_o     (),
        .mem_wr_data_o  (),
        .mem_wr_addr_o  (),
        .mem_wr_vld_o   (),
        .mem_rd_addr_o  (),
        .mem_rd_vld_o   (),
        .wr_st_rd_data_o(),
        .wr_st_rd_rdy_o (),
        .rd_st_wr_rdy_o ()
    );
    
endmodule