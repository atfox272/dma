/*
    With the FlipFlop-based approach: 
        -> Each channel has one corresponding queue.
    With the RAM-based approach (recommand with depth = .... or number of channel = ....):
        -> All queues share a single memory region and are managed using a linked-list mechanism.
*/
module adma_desc_queue
#(
    // Queue
    parameter DMA_CHN_NUM       = 4,    // Number of DMA channels
    parameter DMA_DESC_DEPTH    = 4,    // The maximum number of descriptors in each channel
    parameter DESC_QUEUE_TYPE   = (DMA_DESC_DEPTH >= 16) ? "RAM-BASED" : "FLIPFLOP-BASED",
    // Descriptor 
    parameter SRC_ADDR_W        = 32,
    parameter DST_ADDR_W        = 32,
    parameter DMA_LENGTH_W      = 16,
    // Do not modify
    parameter DMA_XFER_ID_W     = $clog2(DMA_DESC_DEPTH)
) (
    input                       clk,
    input                       rst_n,
    input                       queue_en_i,   // Queue enable signal
    // To Registers Map
    input   [SRC_ADDR_W-1:0]    src_addr_i      [0:DMA_CHN_NUM-1],
    input   [DST_ADDR_W-1:0]    dst_addr_i      [0:DMA_CHN_NUM-1],
    input   [DMA_LENGTH_W-1:0]  xfer_xlen_i     [0:DMA_CHN_NUM-1],
    input   [DMA_LENGTH_W-1:0]  xfer_ylen_i     [0:DMA_CHN_NUM-1],
    input   [DMA_LENGTH_W-1:0]  src_stride_i    [0:DMA_CHN_NUM-1],
    input   [DMA_LENGTH_W-1:0]  dst_stride_i    [0:DMA_CHN_NUM-1],
    input                       desc_wr_vld_i   [0:DMA_CHN_NUM-1],
    output                      desc_wr_rdy_o   [0:DMA_CHN_NUM-1],
    // To Channel Management
    output  [DMA_XFER_ID_W-1:0] xfer_id_o       [0:DMA_CHN_NUM-1],
    output  [SRC_ADDR_W-1:0]    src_addr_o      [0:DMA_CHN_NUM-1],
    output  [DST_ADDR_W-1:0]    dst_addr_o      [0:DMA_CHN_NUM-1],
    output  [DMA_LENGTH_W-1:0]  xfer_xlen_o     [0:DMA_CHN_NUM-1],
    output  [DMA_LENGTH_W-1:0]  xfer_ylen_o     [0:DMA_CHN_NUM-1],
    output  [DMA_LENGTH_W-1:0]  src_stride_o    [0:DMA_CHN_NUM-1],
    output  [DMA_LENGTH_W-1:0]  dst_stride_o    [0:DMA_CHN_NUM-1],
    input                       desc_rd_vld_i   [0:DMA_CHN_NUM-1],
    output                      desc_rd_rdy_o   [0:DMA_CHN_NUM-1],

    output  [DMA_DESC_DEPTH-1:0]xfer_done_clear [0:DMA_CHN_NUM-1]
);
    // Local parameters
    localparam DESC_INFO_W      = DMA_XFER_ID_W + SRC_ADDR_W + DST_ADDR_W + DMA_LENGTH_W + DMA_LENGTH_W + DMA_LENGTH_W + DMA_LENGTH_W; // transfer_id + src_addr + dest_addr + x_len + y_len + src_stride + dest_stride 

    // Internal variable
    genvar chn_idx;

    // Internal signal
    wire                        desc_wr_hsk [0:DMA_CHN_NUM-1];
    reg     [DMA_XFER_ID_W-1:0] xfer_id_cnt [0:DMA_CHN_NUM-1];   // 0 -> 3 -> 0 ... 

generate
    for(chn_idx = 0; chn_idx < DMA_CHN_NUM; chn_idx = chn_idx + 1) begin : DESC_QUEUE_LOGIC
        assign desc_wr_hsk[chn_idx]     = desc_wr_rdy_o[chn_idx] & desc_wr_vld_i[chn_idx];
        assign xfer_done_clear[chn_idx] = desc_wr_hsk[chn_idx]; // Assert 1 cycle only
        always @(posedge clk or negedge rst_n) begin
            if(~rst_n) begin
                xfer_id_cnt[chn_idx] <= {DMA_XFER_ID_W{1'b0}};
            end
            else begin
                xfer_id_cnt[chn_idx] <= xfer_id_cnt[chn_idx] + desc_wr_hsk[chn_idx];
            end
        end
    end
endgenerate

generate
if(DESC_QUEUE_TYPE == "FLIPFLOP-BASED") begin : FF_BASED
    for(chn_idx = 0; chn_idx < DMA_CHN_NUM; chn_idx = chn_idx + 1) begin : DESC_QUEUE_GEN
        // Module instantiation
        sync_fifo #(
            .FIFO_TYPE      (1),    // Normal FIFO
            .DATA_WIDTH     (DESC_INFO_W),
            .FIFO_DEPTH     (DMA_DESC_DEPTH)
        ) desc_queue (
            .clk            (clk),
            .data_i         ({xfer_id_cnt[chn_idx], src_addr_i[chn_idx], dst_addr_i[chn_idx], xfer_xlen_i[chn_idx], xfer_ylen_i[chn_idx], src_stride_i[chn_idx], dst_stride_i[chn_idx]}),
            .data_o         ({xfer_id_o[chn_idx],   src_addr_o[chn_idx], dst_addr_o[chn_idx], xfer_xlen_o[chn_idx], xfer_ylen_o[chn_idx], src_stride_o[chn_idx], dst_stride_o[chn_idx]}),
            .wr_valid_i     (desc_wr_vld_i[chn_idx]),
            .rd_valid_i     (desc_rd_vld_i[chn_idx]),
            .empty_o        (), 
            .full_o         (), 
            .wr_ready_o     (desc_wr_rdy_o[chn_idx]),
            .rd_ready_o     (desc_rd_rdy_o[chn_idx]),
            .almost_empty_o (),
            .almost_full_o  (),
            .counter        (),
            .rst_n          (rst_n)
        );
    end
end else 
if(DESC_QUEUE_TYPE == "RAM-BASED") begin : RAM_BASED
    // TODO: Update later
end
endgenerate
    
endmodule