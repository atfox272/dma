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
    input                                   clk,
    input                                   rst_n,
    input                                   queue_en_glb_i,
    input   [DMA_CHN_NUM-1:0]               queue_en_i, // Queue enable signal (DMA_enable & CHN_enable)
    // To Registers Map
    input   [DMA_CHN_NUM*SRC_ADDR_W-1:0]    src_addr_i,
    input   [DMA_CHN_NUM*DST_ADDR_W-1:0]    dst_addr_i,
    input   [DMA_CHN_NUM*DMA_LENGTH_W-1:0]  xfer_xlen_i,
    input   [DMA_CHN_NUM*DMA_LENGTH_W-1:0]  xfer_ylen_i,
    input   [DMA_CHN_NUM*DMA_LENGTH_W-1:0]  src_stride_i,
    input   [DMA_CHN_NUM*DMA_LENGTH_W-1:0]  dst_stride_i,
    input   [DMA_CHN_NUM-1:0]               desc_wr_vld_i,
    output  [DMA_CHN_NUM-1:0]               desc_wr_rdy_o,
    // To Channel Management
    output  [DMA_CHN_NUM*DMA_XFER_ID_W-1:0] xfer_id_o,
    output  [DMA_CHN_NUM*SRC_ADDR_W-1:0]    src_addr_o,
    output  [DMA_CHN_NUM*DST_ADDR_W-1:0]    dst_addr_o,
    output  [DMA_CHN_NUM*DMA_LENGTH_W-1:0]  xfer_xlen_o,
    output  [DMA_CHN_NUM*DMA_LENGTH_W-1:0]  xfer_ylen_o,
    output  [DMA_CHN_NUM*DMA_LENGTH_W-1:0]  src_stride_o,
    output  [DMA_CHN_NUM*DMA_LENGTH_W-1:0]  dst_stride_o,
    input   [DMA_CHN_NUM-1:0]               desc_rd_vld_i,
    output  [DMA_CHN_NUM-1:0]               desc_rd_rdy_o,
    // Transfer control
    output  [DMA_CHN_NUM*DMA_DESC_DEPTH-1:0]xfer_done_clear,
    // Channel CSR
    input   [DMA_CHN_NUM-1:0]               chn_irq_msk_irq_qed,
    output  [DMA_CHN_NUM-1:0]               chn_irq_src_irq_qed,  // Status
    output  [DMA_CHN_NUM*DMA_XFER_ID_W-1:0] nxt_xfer_id,
    // Interrupt reuqest control
    output  [DMA_CHN_NUM-1:0]               irq_qed
);
    // Local parameters
    localparam DESC_INFO_W      = DMA_XFER_ID_W + SRC_ADDR_W + DST_ADDR_W + DMA_LENGTH_W + DMA_LENGTH_W + DMA_LENGTH_W + DMA_LENGTH_W; // transfer_id + src_addr + dest_addr + x_len + y_len + src_stride + dest_stride 

    // Internal variable
    genvar chn_idx;

    // Internal signal
    wire                        desc_wr_hsk [0:DMA_CHN_NUM-1];
    wire                        desc_wr_vld [0:DMA_CHN_NUM-1];
    wire                        desc_wr_rdy [0:DMA_CHN_NUM-1];
    reg     [DMA_XFER_ID_W-1:0] xfer_id_cnt [0:DMA_CHN_NUM-1];   // 0 -> 3 -> 0 ... 
    wire                        xfer_qed    [0:DMA_CHN_NUM-1];

generate
for(chn_idx = 0; chn_idx < DMA_CHN_NUM; chn_idx = chn_idx + 1) begin : DESC_QUEUE_LOGIC
    // Module instantiation
    // -- Queued interrupt request generator
    edgedet #(
        .RISING_EDGE    (1) // RISING edge
    ) qig (
        .clk            (clk),
        .rst_n          (rst_n),
        .i              (xfer_qed[chn_idx]),
        .en             (chn_irq_msk_irq_qed[chn_idx]),
        .o              (irq_qed[chn_idx])
    );
    // Combination logic
    assign desc_wr_vld[chn_idx]     = queue_en_glb_i & queue_en_i[chn_idx] & desc_wr_vld_i[chn_idx];
    assign desc_wr_rdy_o[chn_idx]   = queue_en_glb_i & queue_en_i[chn_idx] & desc_wr_rdy[chn_idx];
    assign desc_wr_hsk[chn_idx]     = desc_wr_rdy_o[chn_idx] & desc_wr_vld[chn_idx];
    assign xfer_qed[chn_idx]        = desc_wr_hsk[chn_idx];
    assign nxt_xfer_id[(chn_idx+1)*DMA_XFER_ID_W-1-:DMA_XFER_ID_W]       = xfer_id_cnt[chn_idx]; 
    assign xfer_done_clear[(chn_idx+1)*DMA_DESC_DEPTH-1-:DMA_DESC_DEPTH] = desc_wr_hsk[chn_idx]; // Assert 1 cycle only
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
            .data_i         ({xfer_id_cnt[chn_idx],                                     src_addr_i[(chn_idx+1)*SRC_ADDR_W-1-:SRC_ADDR_W], dst_addr_i[(chn_idx+1)*DST_ADDR_W-1-:DST_ADDR_W], xfer_xlen_i[(chn_idx+1)*DMA_LENGTH_W-1-:DMA_LENGTH_W], xfer_ylen_i[(chn_idx+1)*DMA_LENGTH_W-1-:DMA_LENGTH_W], src_stride_i[(chn_idx+1)*DMA_LENGTH_W-1-:DMA_LENGTH_W], dst_stride_i[(chn_idx+1)*DMA_LENGTH_W-1-:DMA_LENGTH_W]}),
            .data_o         ({xfer_id_o[(chn_idx+1)*DMA_XFER_ID_W-1-:DMA_XFER_ID_W],    src_addr_o[(chn_idx+1)*SRC_ADDR_W-1-:SRC_ADDR_W], dst_addr_o[(chn_idx+1)*DST_ADDR_W-1-:DST_ADDR_W], xfer_xlen_o[(chn_idx+1)*DMA_LENGTH_W-1-:DMA_LENGTH_W], xfer_ylen_o[(chn_idx+1)*DMA_LENGTH_W-1-:DMA_LENGTH_W], src_stride_o[(chn_idx+1)*DMA_LENGTH_W-1-:DMA_LENGTH_W], dst_stride_o[(chn_idx+1)*DMA_LENGTH_W-1-:DMA_LENGTH_W]}),
            .wr_valid_i     (desc_wr_vld[chn_idx]),
            .rd_valid_i     (desc_rd_vld_i[chn_idx]),
            .empty_o        (), 
            .full_o         (), 
            .wr_ready_o     (desc_wr_rdy[chn_idx]),
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