/*
    With the FlipFlop-based approach: 
        -> Each channel has one corresponding queue.
    With the RAM-based approach (recommand with depth = .... or number of channel = ....):
        -> All queues share a single memory region and are managed using a linked-list mechanism.
*/
module adma_desc_queue
#(
    // Queue
    parameter DMA_WR_CHN_NUM    = 4,    // Number of DMA write channels
    parameter DMA_DESC_DEPTH    = 4,    // The maximum number of descriptors in each channel
    parameter DESC_QUEUE_TYPE   = (DESC_QUEUE_DEPTH >= 16) ? "RAM-BASED" : "FLIPFLOP-BASED",
    // Descriptor 
    parameter SRC_ADDR_W        = 32,
    parameter DST_ADDR_W        = 32,
    parameter DMA_LENGTH_W      = 16
) (
    input                       clk,
    input                       rst_n,
    input                       queue_en_i,   // Queue enable signal
    // To Registers Map
    input   [SRC_ADDR_W-1:0]    src_addr_i      [DMA_WR_CHN_NUM-1:0],
    input   [DST_ADDR_W-1:0]    dst_addr_i      [DMA_WR_CHN_NUM-1:0],
    input   [DMA_LENGTH_W-1:0]  xfer_xlen_i     [DMA_WR_CHN_NUM-1:0],
    input   [DMA_LENGTH_W-1:0]  xfer_ylen_i     [DMA_WR_CHN_NUM-1:0],
    input   [DMA_LENGTH_W-1:0]  src_stride_i    [DMA_WR_CHN_NUM-1:0],
    input   [DMA_LENGTH_W-1:0]  dst_stride_i    [DMA_WR_CHN_NUM-1:0],
    input                       desc_wr_vld_i   [DMA_WR_CHN_NUM-1:0],
    output                      desc_wr_rdy_o   [DMA_WR_CHN_NUM-1:0],
    // To Channel Management
    output  [SRC_ADDR_W-1:0]    src_addr_o      [DMA_WR_CHN_NUM-1:0],
    output  [DST_ADDR_W-1:0]    dst_addr_o      [DMA_WR_CHN_NUM-1:0],
    output  [DMA_LENGTH_W-1:0]  xfer_xlen_o     [DMA_WR_CHN_NUM-1:0],
    output  [DMA_LENGTH_W-1:0]  xfer_ylen_o     [DMA_WR_CHN_NUM-1:0],
    output  [DMA_LENGTH_W-1:0]  src_stride_o    [DMA_WR_CHN_NUM-1:0],
    output  [DMA_LENGTH_W-1:0]  dst_stride_o    [DMA_WR_CHN_NUM-1:0],
    input                       desc_rd_vld_i   [DMA_WR_CHN_NUM-1:0],
    output                      desc_rd_rdy_o   [DMA_WR_CHN_NUM-1:0]
);
generate
    if(DESC_QUEUE_TYPE == "FLIPFLOP-BASED") begin : FF_BASED
        
    end else 
    if(DESC_QUEUE_TYPE == "RAM-BASED") begin : RAM_BASED
        // TODO: Update later
    end
endgenerate
    
endmodule