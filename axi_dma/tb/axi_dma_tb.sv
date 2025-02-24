`timescale 1ns/1ps

`define DUT_CLK_PERIOD  2
`define RST_DLY_START   3
`define RST_DUR         9

// `define CONF_MODE_ONLY
// `define WR_ST_MODE
// `define RD_ST_MODE 
// `define CUSTOMIZE_MODE

`define END_TIME        500000

// Slave device physical timing simulation
`define SLV_DVC_LATENCY 2 // Time unit
module axi_dma_tb;
    
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

    initial begin   : SEQUENCER_DRIVER
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

    /*          AXI4 monitor            */
    initial begin   : AXI4_MONITOR
        #(`RST_DLY_START + `RST_DUR + 1);
        fork 
            // begin   : AW_chn
            //     while(1'b1) begin
            //         wait(s_awready_o & s_awvalid_i); #0.1;  // AW hanshaking
            //         $display("\n---------- AW channel ----------");
            //         $display("AWID:     0x%8h", s_awid_i);
            //         $display("AWADDR:   0x%8h", s_awaddr_i);
            //         $display("AWLEN:    0x%8h", s_awlen_i);
            //         $display("-------------------------------");
            //         aclk_cl;
            //     end
            // end
            // begin   : W_chn
            //     while(1'b1) begin
            //         wait(s_wready_o & s_wvalid_i); #0.1;  // W hanshaking
            //         $display("\n---------- W channel ----------");
            //         $display("WDATA:    0x%8h", s_wdata_i);
            //         $display("WLAST:    0x%8h", s_wlast_i);
            //         $display("-------------------------------");
            //         aclk_cl;
            //     end
            // end
            begin   : B_chn
                while(1'b1) begin
                    wait(s_bready_i & s_bvalid_o); #0.1;  // B hanshaking
                    $display("\n---------- B channel ----------");
                    $display("BID:      0x%8h", s_bid_o);
                    $display("BRESP:    0x%8h", s_bresp_o);
                    $display("-------------------------------");
                    aclk_cl;
                end
            end
            // begin   : AR_chn
            //     while(1'b1) begin
            //         wait(s_arready_o & s_arvalid_i); #0.1;  // AR hanshaking
            //         $display("\n---------- AR channel ----------");
            //         $display("ARID:     0x%8h", s_arid_i);
            //         $display("ARADDR:   0x%8h", s_araddr_i);
            //         $display("ARLEN:    0x%8h", s_arlen_i);
            //         $display("-------------------------------");
            //         aclk_cl;
            //     end

            // end
            begin   : R_chn
                while(1'b1) begin
                    wait(s_rready_i & s_rvalid_o); #0.1;  // R hanshaking
                    $display("\n---------- R channel ----------");
                    $display("RDATA:    0x%8h", s_rdata_o);
                    $display("RRESP:    0x%8h", s_rresp_o);
                    $display("RLAST:    0x%8h", s_rlast_o);
                    $display("-------------------------------");
                    aclk_cl;
                end
            end
        join_none
    end
    /*          AXI4 monitor            */

   /* DeepCode */
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

    task automatic aclk_cl;
        @(posedge aclk);
        #0.2; 
    endtask
endmodule