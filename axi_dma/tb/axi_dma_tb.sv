`timescale 1ns/1ps

`define DUT_CLK_PERIOD      2
`define RST_DLY_START       3
`define RST_DUR             9

`define ATX_MAX_LENGTH      128

// Monitor mode
// `define MONITOR_DMA_SLV_AW
// `define MONITOR_DMA_SLV_W
// `define MONITOR_DMA_SLV_B
// `define MONITOR_DMA_SLV_AR
// `define MONITOR_DMA_SLV_R
`define MONITOR_DMA_MST_AW
// `define MONITOR_DMA_MST_W
// `define MONITOR_DMA_MST_B
`define MONITOR_DMA_MST_AR
// `define MONITOR_DMA_MST_R


// -- Delay
`define RREADY_STALL_MAX    2
`define ARREADY_STALL_MAX   2
`define AWREADY_STALL_MAX   2
`define WREADY_STALL_MAX    2
`define BREADY_STALL_MAX    2

`define END_TIME            50000

parameter DMA_BASE_ADDR     = 32'h8000_0000;
parameter DMA_CHN_NUM       = 1;    // Number of DMA channels
parameter DMA_LENGTH_W      = 16;   // Maximum size of 1 transfer is (2^16 * 256) 
parameter DMA_DESC_DEPTH    = 4;    // The maximum number of descriptors in each channel
parameter DMA_CHN_ARB_W     = 3;    // Channel arbitration weight's width
parameter ROB_EN            = 0;    // Reorder multiple AXI outstanding transactions enable
parameter DESC_QUEUE_TYPE   = (DMA_DESC_DEPTH >= 16) ? "RAM-BASED" : "FLIPFLOP-BASED";
parameter ATX_SRC_DATA_W    = 256;
parameter ATX_DST_DATA_W    = 256;
parameter S_DATA_W          = 32;
parameter S_ADDR_W          = 32;
parameter SRC_ADDR_W        = 32;
parameter DST_ADDR_W        = 32;
parameter MST_ID_W          = 5;
parameter ATX_LEN_W         = 8;
parameter ATX_SIZE_W        = 3;
parameter ATX_RESP_W        = 2;
parameter ATX_NUM_OSTD      = (DMA_CHN_NUM > 1) ? DMA_CHN_NUM : 2;  // Number of outstanding transactions in AXI bus (recmd: equal to the number of channel)
parameter ATX_INTL_DEPTH    = 16; // Interleaving depth on the AXI data channel 

typedef struct {
    bit                     trans_type; // Write(1) / read(0) transaction
    bit [MST_ID_W-1:0]      axid;
    bit [DST_ADDR_W-1:0]    axaddr;
    bit [1:0]               axburst;
    bit [ATX_LEN_W-1:0]     axlen;
    bit [ATX_SIZE_W-1:0]    axsize;
} atx_ax_info;

typedef struct {
    bit [DST_ADDR_W-1:0]    wdata [`ATX_MAX_LENGTH];
} atx_w_info;

typedef struct {
    bit [MST_ID_W-1:0]      bid;
    bit [ATX_RESP_W-1:0]    bresp;
} atx_b_info;

module axi_dma_tb;

    logic                           aclk;
    logic                           aresetn;

    // AXI4 Slave Interface            
    // -- AW channel         
    logic   [MST_ID_W-1:0]          s_awid_i;
    logic   [S_ADDR_W-1:0]          s_awaddr_i;
    logic   [ATX_LEN_W-1:0]         s_awlen_i;
    logic                           s_awvalid_i;
    logic                           s_awready_o;
    // -- W channel          
    logic   [S_DATA_W-1:0]          s_wdata_i;
    logic                           s_wlast_i;
    logic                           s_wvalid_i;
    logic                           s_wready_o;
    // -- B channel          
    logic   [MST_ID_W-1:0]          s_bid_o;
    logic   [ATX_RESP_W-1:0]        s_bresp_o;
    logic                           s_bvalid_o;
    logic                           s_bready_i;
    // -- AR channel         
    logic   [MST_ID_W-1:0]          s_arid_i;
    logic   [S_ADDR_W-1:0]          s_araddr_i;
    logic   [ATX_LEN_W-1:0]         s_arlen_i;
    logic                           s_arvalid_i;
    logic                           s_arready_o;
    // -- R channel          
    logic   [MST_ID_W-1:0]          s_rid_o;
    logic   [S_DATA_W-1:0]          s_rdata_o;
    logic   [ATX_RESP_W-1:0]        s_rresp_o;
    logic                           s_rlast_o;
    logic                           s_rvalid_o;
    logic                           s_rready_i;
    
    // AXI4 Master Read (source) port
    // -- AR channel         
    logic   [MST_ID_W-1:0]          m_arid_o;
    logic   [SRC_ADDR_W-1:0]        m_araddr_o;
    logic   [ATX_LEN_W-1:0]         m_arlen_o;
    logic   [1:0]                   m_arburst_o;
    logic                           m_arvalid_o;
    logic                           m_arready_i;
    // -- -- R channel          
    logic   [MST_ID_W-1:0]          m_rid_i;
    logic   [ATX_SRC_DATA_W-1:0]    m_rdata_i;
    logic   [ATX_RESP_W-1:0]        m_rresp_i;
    logic                           m_rlast_i;
    logic                           m_rvalid_i;
    logic                           m_rready_o;

    // AXI4 Master Write (destination) port
    // -- AW channel         
    logic   [MST_ID_W-1:0]          m_awid_o;
    logic   [DST_ADDR_W-1:0]        m_awaddr_o;
    logic   [ATX_LEN_W-1:0]         m_awlen_o;
    logic   [1:0]                   m_awburst_o;
    logic                           m_awvalid_o;
    logic                           m_awready_i;
    // -- W channel          
    logic   [ATX_DST_DATA_W-1:0]    m_wdata_o;
    logic                           m_wlast_o;
    logic                           m_wvalid_o;
    logic                           m_wready_i;
    // -- B channel
    logic   [MST_ID_W-1:0]          m_bid_i;
    logic   [ATX_RESP_W-1:0]        m_bresp_i;
    logic                           m_bvalid_i;
    logic                           m_bready_o;

    // Interrupt
    logic                           irq         [0:DMA_CHN_NUM-1];
    logic                           trap        [0:DMA_CHN_NUM-1];
    axi_dma #(
        .DMA_BASE_ADDR  (DMA_BASE_ADDR),
        .DMA_CHN_NUM    (DMA_CHN_NUM),
        .DMA_LENGTH_W   (DMA_LENGTH_W),
        .DMA_DESC_DEPTH (DMA_DESC_DEPTH),
        .DMA_CHN_ARB_W  (DMA_CHN_ARB_W),
        .ROB_EN         (ROB_EN),
        .DESC_QUEUE_TYPE(DESC_QUEUE_TYPE),
        .ATX_SRC_DATA_W (ATX_SRC_DATA_W),
        .ATX_DST_DATA_W (ATX_DST_DATA_W),
        .S_DATA_W       (S_DATA_W),
        .S_ADDR_W       (S_ADDR_W),
        .SRC_ADDR_W     (SRC_ADDR_W),
        .DST_ADDR_W     (DST_ADDR_W),
        .MST_ID_W       (MST_ID_W),
        .ATX_LEN_W      (ATX_LEN_W),
        .ATX_SIZE_W     (ATX_SIZE_W),
        .ATX_RESP_W     (ATX_RESP_W),
        .ATX_NUM_OSTD   (ATX_NUM_OSTD),
        .ATX_INTL_DEPTH (ATX_INTL_DEPTH)
    ) dut (
        .*
    );
    initial begin
        aclk            <= 0;
        aresetn         <= 1;

        s_awid_i        <= 0;
        s_awaddr_i      <= 0;
        s_awlen_i       <= 0;
        s_awvalid_i     <= 0;
        
        s_wdata_i       <= 0;
        s_wlast_i       <= 0;
        s_wvalid_i      <= 0;
        
        s_bready_i      <= 1'b1;
        
        s_awid_i        <= 0;
        s_awaddr_i      <= 0;
        s_awvalid_i     <= 0;
        
        s_bready_i      <= 1'b1;
        
        s_arid_i        <= 0;
        s_araddr_i      <= 0;
        s_arlen_i       <= 0;
        s_arvalid_i     <= 0;

        s_rready_i      <= 1'b1;

        // Source
        m_arready_i     <= 1'b1;

        m_rid_i         <= 5'h02;
        m_rdata_i       <= 32'h11;
        m_rresp_i       <= 2'b00;
        m_rlast_i       <= 1'b0;
        m_rvalid_i      <= 1'b0;

        // Destination
        m_awready_i     <= 1'b1;

        m_bid_i         <= 5'h02;
        m_bresp_i       <= 2'b00;
        m_bvalid_i      <= 1'b0;

        #(`RST_DLY_START)   aresetn <= 0;
        #(`RST_DUR)         aresetn <= 1;
    end
    
    initial begin
        forever #(`DUT_CLK_PERIOD/2) aclk <= ~aclk;
    end
    
    initial begin : SIM_END
        #`END_TIME;
        $finish;
    end

    initial begin   : MASTER_DRIVER
        #(`RST_DLY_START + `RST_DUR + 1);
        fork 
            begin   : AW_chn
                // 1st: DMA en
                s_aw_transfer(.s_awid(5'h01), .s_awaddr(32'h8000_0000), .s_awlen(8'd00));
                // 2nd: Channel en
                s_aw_transfer(.s_awid(5'h02), .s_awaddr(32'h8000_0001), .s_awlen(8'd00));
                // 3rd: Channel flag -> 2D & Cyclic
                s_aw_transfer(.s_awid(5'h03), .s_awaddr(32'h8000_0002), .s_awlen(8'd00));
                // 4th: Channel interrupt mask
                s_aw_transfer(.s_awid(5'h04), .s_awaddr(32'h8000_0003), .s_awlen(8'd00));
                // 5th: ATX_ID
                s_aw_transfer(.s_awid(5'h05), .s_awaddr(32'h8000_0005), .s_awlen(8'd00));
                // 6th: ATX_SRC_BURST 
                s_aw_transfer(.s_awid(5'h06), .s_awaddr(32'h8000_0006), .s_awlen(8'd00));
                // 7th: ATX_DST_BURST 
                s_aw_transfer(.s_awid(5'h07), .s_awaddr(32'h8000_0007), .s_awlen(8'd00));
                // 8th: ATX_WD_PER_BURST 
                s_aw_transfer(.s_awid(5'h08), .s_awaddr(32'h8000_0008), .s_awlen(8'd00));
                // 9th: DESC - SRC_ADDR
                s_aw_transfer(.s_awid(5'h09), .s_awaddr(32'h8000_0009), .s_awlen(8'd00));
                // 10th: DESC - DST_ADDR
                s_aw_transfer(.s_awid(5'h0A), .s_awaddr(32'h8000_000A), .s_awlen(8'd00));
                // 11th: DESC - X_LEN
                s_aw_transfer(.s_awid(5'h0B), .s_awaddr(32'h8000_000B), .s_awlen(8'd00));
                // 12th: DESC - Y_LEN
                s_aw_transfer(.s_awid(5'h0C), .s_awaddr(32'h8000_000C), .s_awlen(8'd00));
                // 13th: DESC - SRC_STRIDE 
                s_aw_transfer(.s_awid(5'h0D), .s_awaddr(32'h8000_000D), .s_awlen(8'd00));
                // 14th: DESC - DST_STRIDE
                s_aw_transfer(.s_awid(5'h0E), .s_awaddr(32'h8000_000E), .s_awlen(8'd00));
                // 15th: DESC - SUBMIT
                s_aw_transfer(.s_awid(5'h0F), .s_awaddr(32'h8000_1000), .s_awlen(8'd00));
                aclk_cl;
                s_awvalid_i <= 1'b0;
            end
            begin   : W_chn
                // 1st: DMA en
                s_w_transfer(.s_wdata(32'h01), .s_wlast(1'b1));
                // 2nd: Channel en
                s_w_transfer(.s_wdata(32'h01), .s_wlast(1'b1));
                // 3rd: Channel flag -> 2D & Cyclic
                s_w_transfer(.s_wdata(32'h01), .s_wlast(1'b1));
                // 4th: Channel interrupt mask
                s_w_transfer(.s_wdata(32'h03), .s_wlast(1'b1));
                // 5th: ATX_ID
                s_w_transfer(.s_wdata(32'h02), .s_wlast(1'b1));
                // 6th: ATX_SRC_BURST 
                s_w_transfer(.s_wdata(32'b01), .s_wlast(1'b1));
                // 7th: ATX_DST_BURST 
                s_w_transfer(.s_wdata(32'b01), .s_wlast(1'b1));
                // 8th: ATX_WD_PER_BURST 
                s_w_transfer(.s_wdata(32'd04), .s_wlast(1'b1));
                // 9th: DESC - SRC_ADDR
                s_w_transfer(.s_wdata(32'h1000_0000), .s_wlast(1'b1));
                // 10th: DESC - DST_ADDR
                s_w_transfer(.s_wdata(32'h2000_0000), .s_wlast(1'b1));
                // 11th: DESC - X_LEN
                s_w_transfer(.s_wdata(32'd04), .s_wlast(1'b1));
                // 12th: DESC - Y_LEN
                s_w_transfer(.s_wdata(32'd03), .s_wlast(1'b1));
                // 13th: DESC - SRC_STRIDE 
                s_w_transfer(.s_wdata(32'd05), .s_wlast(1'b1));
                // 14th: DESC - DST_STRIDE
                s_w_transfer(.s_wdata(32'd05), .s_wlast(1'b1));
                // 15th: DESC - SUBMIT
                s_w_transfer(.s_wdata(32'h01), .s_wlast(1'b1));
                aclk_cl;
                s_wvalid_i <= 1'b0;
            end
            begin   : AR_chn
                // 1st: TRANSFER_ID
                s_ar_transfer(.s_arid(5'h00), .s_araddr(32'h8000_2001), .s_arlen(8'd00));
                // 2nd: TRANSFER_ID
                s_ar_transfer(.s_arid(5'h00), .s_araddr(32'h8000_2001), .s_arlen(8'd00));
                aclk_cl;
                s_arvalid_i <= 1'b0;
            end
            begin: R_chn
                // Wrong request
                // TODO: monitor the response data
            end
        join_none
    end

    initial begin : SLAVE_DRIVER
        #(`RST_DLY_START + `RST_DUR + 1);
        slave_driver;
    end

    /*          DMA slave monitor            */
    initial begin   : DMA_SLV_MONITOR
        #(`RST_DLY_START + `RST_DUR + 1);
        fork 
            `ifdef MONITOR_DMA_SLV_AW
                begin   : AW_chn
                    while(1'b1) begin
                        wait(s_awready_o & s_awvalid_i); #0.1;  // AW hanshaking
                        $display("\n---------- DMA Slave: AW channel ----------");
                        $display("AWID:     0x%8h", s_awid_i);
                        $display("AWADDR:   0x%8h", s_awaddr_i);
                        $display("AWLEN:    0x%8h", s_awlen_i);
                        $display("--------------------------------------------");
                        aclk_cl;
                    end
                end
            `endif
            `ifdef MONITOR_DMA_SLV_W
                begin   : W_chn
                    while(1'b1) begin
                        wait(s_wready_o & s_wvalid_i); #0.1;  // W hanshaking
                        $display("\n---------- DMA Slave: W channel ----------");
                        $display("WDATA:    0x%8h", s_wdata_i);
                        $display("WLAST:    0x%8h", s_wlast_i);
                        $display("--------------------------------------------");
                        aclk_cl;
                    end
                end
            `endif
            `ifdef MONITOR_DMA_SLV_B
                begin   : B_chn
                    while(1'b1) begin
                        wait(s_bready_i & s_bvalid_o); #0.1;  // B hanshaking
                        $display("\n---------- DMA Slave: B channel ----------");
                        $display("BID:      0x%8h", s_bid_o);
                        $display("BRESP:    0x%8h", s_bresp_o);
                        $display("--------------------------------------------");
                        aclk_cl;
                    end
                end
            `endif
            `ifdef MONITOR_DMA_SLV_AR
                begin   : AR_chn
                    while(1'b1) begin
                        wait(s_arready_o & s_arvalid_i); #0.1;  // AR hanshaking
                        $display("\n---------- DMA Slave: AR channel ----------");
                        $display("ARID:     0x%8h", s_arid_i);
                        $display("ARADDR:   0x%8h", s_araddr_i);
                        $display("ARLEN:    0x%8h", s_arlen_i);
                        $display("--------------------------------------------");
                        aclk_cl;
                    end
                end
            `endif
            `ifdef MONITOR_DMA_SLV_R
                begin   : R_chn
                    while(1'b1) begin
                        wait(s_rready_i & s_rvalid_o); #0.1;  // R hanshaking
                        $display("\n---------- DMA Slave: R channel ----------");
                        $display("RDATA:    0x%8h", s_rdata_o);
                        $display("RRESP:    0x%8h", s_rresp_o);
                        $display("RLAST:    0x%8h", s_rlast_o);
                        $display("--------------------------------------------");
                        aclk_cl;
                    end
                end
            `endif
            begin end
        join_none
    end
    /*          DMA slave monitor            */

    /*          DMA master monitor            */
    initial begin   : DMA_MST_MONITOR
        #(`RST_DLY_START + `RST_DUR + 1);
        fork 
            `ifdef MONITOR_DMA_MST_AW
                begin   : AW_chn
                    while(1'b1) begin
                    wait(m_awready_i & m_awvalid_o); #0.1;  // AW hanshaking
                    $display("\n---------- DMA Master: AW channel ----------");
                    $display("AWID:     0x%8h", m_awid_o);
                    $display("AWADDR:   0x%8h", m_awaddr_o);
                    $display("AWLEN:    0x%8h", m_awlen_o);
                    $display("--------------------------------------------");
                    aclk_cl;
                    end
                end
            `endif
            `ifdef MONITOR_DMA_MST_W
                begin   : W_chn
                    while(1'b1) begin
                    wait(m_wready_i & m_wvalid_o); #0.1;  // W hanshaking
                    $display("\n---------- DMA Master: W channel ----------");
                    $display("WDATA:    0x%8h", m_wdata_o);
                    $display("WLAST:    0x%8h", m_wlast_o);
                    $display("--------------------------------------------");
                    aclk_cl;
                    end
                end
            `endif
            `ifdef MONITOR_DMA_MST_B
                begin   : B_chn
                    while(1'b1) begin
                    wait(m_bready_o & m_bvalid_i); #0.1;  // B hanshaking
                    $display("\n---------- DMA Master: B channel ----------");
                    $display("BID:      0x%8h", m_bid_i);
                    $display("BRESP:    0x%8h", m_bresp_i);
                    $display("--------------------------------------------");
                    aclk_cl;
                    end
                end
            `endif
            `ifdef MONITOR_DMA_MST_AR
                begin   : AR_chn
                    while(1'b1) begin
                    wait(m_arready_i & m_arvalid_o); #0.1;  // AR hanshaking
                    $display("\n---------- DMA Master: AR channel ----------");
                    $display("ARID:     0x%8h", m_arid_o);
                    $display("ARADDR:   0x%8h", m_araddr_o);
                    $display("ARLEN:    0x%8h", m_arlen_o);
                    $display("--------------------------------------------");
                    aclk_cl;
                    end
                end
            `endif
            `ifdef MONITOR_DMA_MST_R
                begin   : R_chn
                    while(1'b1) begin
                    wait(m_rready_o & m_rvalid_i); #0.1;  // R hanshaking
                    $display("\n---------- DMA Master: R channel ----------");
                    $display("RDATA:    0x%8h", m_rdata_i);
                    $display("RRESP:    0x%8h", m_rresp_i);
                    $display("RLAST:    0x%8h", m_rlast_i);
                    $display("--------------------------------------------");
                    aclk_cl;
                    end
                end
            `endif
            begin end
        join_none
    end
    /*          DMA master monitor            */

   /*           DeepCode                */
    task automatic aclk_cl;
        @(posedge aclk);
        #0.2; 
    endtask
    task automatic s_aw_transfer(
        input [MST_ID_W-1:0]    s_awid,
        input [S_ADDR_W-1:0]    s_awaddr,
        input [ATX_LEN_W-1:0]   s_awlen
    );
        aclk_cl;
        s_awid_i            <= s_awid;
        s_awaddr_i          <= s_awaddr;
        s_awlen_i           <= s_awlen;
        s_awvalid_i         <= 1'b1;
        // Handshake occur
        wait(s_awready_o == 1'b1); #0.1;
    endtask

    task automatic s_w_transfer (
        input [S_DATA_W-1:0]    s_wdata,
        input                   s_wlast
    );
        aclk_cl;
        s_wdata_i           <= s_wdata;
        s_wlast_i           <= s_wlast;
        s_wvalid_i          <= 1'b1;
        // Handshake occur
        wait(s_wready_o == 1'b1); #0.1;
    endtask

    task automatic s_ar_transfer(
        input [MST_ID_W-1:0]    s_arid,
        input [S_ADDR_W-1:0]    s_araddr,
        input [ATX_LEN_W-1:0]   s_arlen
    );
        aclk_cl;
        s_arid_i            <= s_arid;
        s_araddr_i          <= s_araddr;
        s_arlen_i           <= s_arlen;
        s_arvalid_i         <= 1'b1;
        // Handshake occur
        wait(s_arready_o == 1'b1); #0.1;
    endtask
    
    /////////////////////////////////////////////////
    task automatic m_aw_receive(
        output  [MST_ID_W-1:0]      awid,
        output  [DST_ADDR_W-1:0]    awaddr,
        output  [1:0]               awburst,
        output  [ATX_LEN_W-1:0]     awlen
        // output      [ATX_SIZE_W-1:0]    awsize
    );
        // Wait for BVALID
        wait(m_awvalid_o == 1'b1); #0.1;
        awid    = m_awid_o;
        awaddr  = m_awaddr_o;
        awburst = m_awburst_o;
        awlen   = m_awlen_o; 
        // awsize  = m_awsize_o; 
    endtask
    task automatic m_w_receive (
        output  [ATX_DST_DATA_W-1:0]    wdata,
        output                          wlast
    );
        wait(m_wvalid_o == 1'b1); #0.1;
        wdata   = m_wdata_o;
        wlast   = m_wlast_o;
    endtask
    task automatic m_b_transfer (
        input [MST_ID_W-1:0]    bid,
        input [ATX_RESP_W-1:0]  bresp
    );
        aclk_cl;
        m_bid_i     <= bid;
        m_bresp_i   <= bresp;
        m_bvalid_i  <= 1'b1;
        // Wait for handshaking
        wait(m_bready_o == 1'b1); #0.1;
    endtask
    task automatic m_ar_receive(
        output  [MST_ID_W-1:0]      arid,
        output  [DST_ADDR_W-1:0]    araddr,
        output  [1:0]               arburst,
        output  [ATX_LEN_W-1:0]     arlen
        // output  [ATX_SIZE_W-1:0]    arsize
    );
        // Wait for BVALID
        wait(m_arvalid_o == 1'b1); #0.1;
        arid    = m_arid_o;
        araddr  = m_araddr_o;
        arburst = m_arburst_o;
        arlen   = m_arlen_o; 
        // arsize  = m_arsize_o; 
    endtask
    task automatic m_r_transfer (
        input [MST_ID_W-1:0]    rid, 
        input [DST_ADDR_W-1:0]  rdata,
        input [ATX_RESP_W-1:0]  rresp,
        input                   rlast
    );
        aclk_cl;
        m_rid_i     <= rid;
        m_rdata_i   <= rdata;
        m_rresp_i   <= rresp;
        m_rlast_i   <= rlast;
        m_rvalid_i  <= 1'b1;
        // Wait for handshaking
        #0.1;
        wait(m_rready_o == 1'b1); #0.1;
    endtask
    /////////////////////////////////////////////////

    mailbox #(atx_ax_info)  m_drv_aw_info;
    mailbox #(atx_b_info)   m_drv_b_info;
    mailbox #(atx_ax_info)  m_drv_ar_info;

    
    task automatic rand_stall_cycle(input int stall_max);
        int slave_stall_1cycle;
        slave_stall_1cycle = $urandom_range(0, stall_max);
        for(int stall_num = 0; stall_num < slave_stall_1cycle; stall_num = stall_num + 1) begin
            aclk_cl;
        end
    endtask

    task automatic slave_driver;
        m_drv_aw_info   = new();
        m_drv_b_info    = new();
        m_drv_ar_info   = new();
        fork
            begin   : AW_CHN
                atx_ax_info aw_temp;
                forever begin
                    m_arready_i = 1'b1;
                    m_aw_receive (
                        .awid   (aw_temp.axid),
                        .awaddr (aw_temp.axaddr),
                        .awburst(aw_temp.axburst),
                        .awlen  (aw_temp.axlen)
                        // .awsize (aw_temp.axsize)
                    );
                    // Store AW info 
                    m_drv_aw_info.put(aw_temp);
                    // Handshake occurs
                    aclk_cl;
                    // Stall random
                    m_arready_i = 1'b0;
                    rand_stall_cycle(`AWREADY_STALL_MAX);
                end
            end
            begin   : W_CHN
                atx_ax_info aw_temp;
                atx_w_info  w_temp;
                atx_b_info  b_temp;
                bit         wlast_temp;
                forever begin
                    if(m_drv_aw_info.try_get(aw_temp)) begin
                        for(int i = 0; i <= aw_temp.axlen; i = i + 1) begin
                            // Assert WREADY
                            m_wready_i = 1'b1;
                            m_w_receive (
                                .wdata(w_temp.wdata[i]),
                                .wlast(wlast_temp)
                            );
                            // WDATA predictor
                            if(w_temp.wdata[i] == i) begin
                                // $display("[INFO]: Destination - Sample WDATA[%1d] = %h and WLAST = %1b)", i, w_temp.wdata[i], i, wlast_temp);
                            end
                            else begin
                                $display("[FAIL]: Destination - Sample WDATA[%1d] = %h and Golden WDATA = %h)", i, w_temp.wdata[i], i);
                                $stop;
                            end
                            // WLAST predictor
                            if(wlast_temp == (i == aw_temp.axlen)) begin
                            
                            end
                            else begin
                                $display("[FAIL]: Destination - Wrong sample WLAST = %0d at WDATA = %8h (idx: %0d, AWLEN: %2d)", wlast_temp, w_temp.wdata[i], i, aw_temp.axlen);
                                $stop;
                            end
                            // Handshake occurs 
                            aclk_cl;
                            // Stall random
                            m_wready_i = 1'b0;
                            rand_stall_cycle(`WREADY_STALL_MAX);
                        end
                        // Generate B transfer
                        b_temp.bid      = aw_temp.axid;
                        b_temp.bresp    = 2'b00;
                        m_drv_b_info.put(b_temp);
                    end
                    else begin
                        // Wait 1 cycle
                        aclk_cl;
                        m_wready_i = 1'b0;
                    end
                end
            end
            begin   : B_CHN
                atx_b_info  b_temp;
                forever begin
                    if(m_drv_b_info.try_get(b_temp)) begin
                        m_b_transfer (
                            .bid(b_temp.bid),
                            .bresp(b_temp.bresp)
                        );
                        $display("[INFO]: Destination - The transaction with ID-%0h has been completed", b_temp.bid);
                    end
                    else begin
                        // Wait 1 cycle
                        aclk_cl;
                        m_bvalid_i = 1'b0;
                    end
                end
            end
            begin   : AR_CHN
                atx_ax_info ar_temp;
                forever begin
                    m_arready_i = 1'b1;
                    m_ar_receive (
                        .arid   (ar_temp.axid),
                        .araddr (ar_temp.axaddr),
                        .arburst(ar_temp.axburst),
                        .arlen  (ar_temp.axlen)
                    );
                    // Handshake occurs
                    aclk_cl;
                    // Store AW info 
                    m_drv_ar_info.put(ar_temp);
                    // Stall random
                    m_arready_i = 1'b0;
                    rand_stall_cycle(`ARREADY_STALL_MAX);
                end
            end
            begin   : R_CHN
                atx_ax_info ar_temp;
                forever begin
                    if(m_drv_ar_info.try_get(ar_temp)) begin
                        for(int i = 0; i <= ar_temp.axlen; i = i + 1) begin
                            m_r_transfer (
                                .rid(ar_temp.axid),
                                .rdata(i),
                                .rresp(2'b00),
                                .rlast(i == ar_temp.axlen)
                            );
                        end
                    end
                    else begin
                        // Wait 1 cycle
                        aclk_cl;
                        m_rvalid_i = 1'b0;
                    end
                end
            end 
        join_none
    endtask
endmodule