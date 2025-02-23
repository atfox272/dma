module sync_fifo
#(
    // FIFO configuration
    parameter FIFO_TYPE         = 4,
    parameter DATA_WIDTH        = 32,
    parameter FIFO_DEPTH        = 32,
    // For Concatenating FIFO
    parameter IN_DATA_WIDTH     = DATA_WIDTH,
    parameter OUT_DATA_WIDTH    = DATA_WIDTH,
    // -- For CONCAT FIFO 
    parameter CONCAT_ORDER      = "LSB",
    // Do not configure
    parameter ADDR_WIDTH        = $clog2(FIFO_DEPTH)
)
(
    input                           clk,
    
    input   [IN_DATA_WIDTH-1:0]     data_i,
    output  [OUT_DATA_WIDTH-1:0]    data_o,
    
    input                           wr_valid_i,
    input                           rd_valid_i,
    
    output                          empty_o,
    output                          full_o,
    output                          wr_ready_o,     // Optional
    output                          rd_ready_o,     // Optional
    output                          almost_empty_o, // Optional
    output                          almost_full_o,  // Optional
    
    output  [ADDR_WIDTH:0]          counter,        // Optional
    input                           rst_n
);
// Internal variable declaration
genvar addr;
    
generate
if(FIFO_TYPE == 1) begin : NORMAL_FIFO
    // Internal signal
    // -- wire   
    wire                    rd_handshake;
    wire                    wr_handshake;
    // -- reg
    reg [DATA_WIDTH-1:0]    mem     [FIFO_DEPTH-1:0];
    reg [ADDR_WIDTH:0]      rd_ptr;
    reg [ADDR_WIDTH:0]      wr_ptr;
    
    // Combination logic
    assign data_o       = mem[rd_ptr[ADDR_WIDTH-1:0]];
    assign empty_o      = ~|(rd_ptr^wr_ptr);
    assign full_o       = (rd_ptr[ADDR_WIDTH]^wr_ptr[ADDR_WIDTH]) & (~|(rd_ptr[ADDR_WIDTH-1:0]^wr_ptr[ADDR_WIDTH-1:0]));
    assign wr_ready_o   = (~full_o);
    assign rd_ready_o   = (~empty_o);
    assign rd_handshake = rd_valid_i & rd_ready_o;
    assign wr_handshake = wr_valid_i & wr_ready_o;
    assign counter      = wr_ptr - rd_ptr;
    
    // Flip-flop/RAM
    always @(posedge clk) begin
        if(wr_handshake) begin
            mem[wr_ptr[ADDR_WIDTH-1:0]] <= data_i;
        end
    end
    always @(posedge clk) begin
        if(!rst_n) begin
            wr_ptr <= {(ADDR_WIDTH+1){1'b0}};
        end
        else if(wr_handshake) begin
            wr_ptr <= wr_ptr + 1'b1;
        end
    end
    always @(posedge clk) begin
        if(!rst_n) begin
            rd_ptr <= {(ADDR_WIDTH+1){1'b0}};
        end
        else if(rd_handshake) begin
            rd_ptr <= rd_ptr + 1'b1;
        end
    end
end
else if(FIFO_TYPE == 2) begin : FWD_FLOP
    // Internal signal
    // -- wire   
    wire                    rd_handshake;
    wire                    wr_handshake;
    wire                    po_bwd_valid;
    wire                    po_bwd_ready;
    wire                    po_fwd_valid;
    // -- reg
    reg [DATA_WIDTH-1:0]    mem     [FIFO_DEPTH-1:0];
    reg [ADDR_WIDTH:0]      rd_ptr;
    reg [ADDR_WIDTH:0]      wr_ptr;
    
    // Internal module
    skid_buffer #(
        .SBUF_TYPE  (0),
        .DATA_WIDTH (DATA_WIDTH)
    ) pipe_out (
        .clk        (clk),        
        .rst_n      (rst_n),      
        .bwd_data_i (mem[rd_ptr[ADDR_WIDTH-1:0]]), 
        .bwd_valid_i(po_bwd_valid),
        .fwd_ready_i(rd_valid_i),
        .fwd_data_o (data_o), 
        .bwd_ready_o(po_bwd_ready),
        .fwd_valid_o(po_fwd_valid)
    );
    
    // Combination logic
    assign empty_o      = ~po_fwd_valid;
    assign full_o       = (rd_ptr[ADDR_WIDTH]^wr_ptr[ADDR_WIDTH]) & (~|(rd_ptr[ADDR_WIDTH-1:0]^wr_ptr[ADDR_WIDTH-1:0]));
    assign wr_ready_o   = (~full_o);
    assign rd_ready_o   = po_fwd_valid;
    assign po_bwd_valid = |(rd_ptr^wr_ptr);
    assign rd_handshake = po_bwd_valid & po_bwd_ready;
    assign wr_handshake = wr_valid_i & wr_ready_o;
    assign counter      = wr_ptr - rd_ptr;
    
    // Flip-flop/RAM
    always @(posedge clk) begin
        if(wr_handshake) begin
            mem[wr_ptr[ADDR_WIDTH-1:0]] <= data_i;
        end
    end
    always @(posedge clk) begin
        if(!rst_n) begin
            wr_ptr <= {(ADDR_WIDTH+1){1'b0}};
        end
        else if(wr_handshake) begin
            wr_ptr <= wr_ptr + 1'b1;
        end
    end
    always @(posedge clk) begin
        if(!rst_n) begin
            rd_ptr <= {(ADDR_WIDTH+1){1'b0}};
        end
        else if(rd_handshake) begin
            rd_ptr <= rd_ptr + 1'b1;
        end
    end
end
else if(FIFO_TYPE == 0) begin : HALF_FLOP
    // Internal signal declaration
    // wire declaration
    // -- Common
    wire                    full_r_en;
    wire                    empty_r_en;
    wire                    full_nxt;
    wire                    empty_nxt;
    // -- Write handle
    wire                    wr_handshake;
    wire[ADDR_WIDTH:0]      wr_addr_inc;
    wire[ADDR_WIDTH - 1:0]  wr_addr_map;
    // -- Read handle
    wire                    rd_handshake;
    wire[ADDR_WIDTH:0]      rd_addr_inc;
    wire[ADDR_WIDTH - 1:0]  rd_addr_map;
    
    // reg declaration
	reg [DATA_WIDTH - 1:0]  mem        [0:FIFO_DEPTH - 1];
	reg [ADDR_WIDTH:0]      wr_addr;
    reg [ADDR_WIDTH:0]      rd_addr;
    reg                     empty_q;
    reg                     full_q;
    reg                     rd_ready;
    reg                     wr_ready;
    
    // combinational logic
    // -- Common
    assign data_o           = mem[rd_addr_map];
    // -- Write handle
    assign wr_addr_inc      = wr_addr + 1'b1;
    assign wr_addr_map      = wr_addr[ADDR_WIDTH - 1:0];
    assign wr_handshake     = wr_valid_i & !full_o;
    assign full_o           = full_q;
    assign wr_ready_o       = wr_ready;
    // -- Read handle
    assign rd_addr_inc      = rd_addr + 1'b1;
    assign rd_addr_map      = rd_addr[ADDR_WIDTH - 1:0];
    assign rd_handshake     = rd_valid_i & !empty_o;
    assign empty_o          = empty_q;
    assign rd_ready_o       = rd_ready;
    // -- Common
    assign empty_r_en       = wr_handshake | rd_handshake;
    assign full_r_en        = wr_handshake | rd_handshake;
    assign empty_nxt        = (rd_handshake & almost_empty_o) & (~wr_handshake);
    assign full_nxt         = (wr_handshake & almost_full_o) & (~rd_handshake);
    assign almost_empty_o   = rd_addr_inc ==  wr_addr;
    assign almost_full_o    = wr_addr_map + 1'b1 == rd_addr_map;
    assign counter          = wr_addr - rd_addr;
    
    // flip-flop logic
    // -- Buffer updater
    always @(posedge clk) begin
        if(wr_handshake) begin
            mem[wr_addr_map] <= data_i;
        end
    end
    always @(posedge clk) begin
    
    end
    // -- Write pointer updater
    always @(posedge clk) begin
        if(!rst_n) begin 
            wr_addr <= 0;        
        end
        else if(wr_handshake) begin
            wr_addr <= wr_addr_inc;
        end
    end
    // -- Read pointer updater
    always @(posedge clk) begin
        if(!rst_n) begin
            rd_addr <= 0;
        end
        else if(rd_handshake) begin
            rd_addr <= rd_addr_inc;
        end
    end
    // -- Full signal update
    always @(posedge clk) begin
        if(!rst_n) begin
            full_q <= 1'b0;
        end
        else if(full_r_en) begin
            full_q <= full_nxt;
        end
    end
    // -- Write Ready update (optional)
    always @(posedge clk) begin
        if(!rst_n) begin
            wr_ready <= 1'b1;
        end
        else if(full_r_en) begin
            wr_ready <= ~full_nxt;
        end
    end
    // -- Empty signal update
    always @(posedge clk) begin
        if(!rst_n) begin
            empty_q <= 1'b1;
        end
        else if(empty_r_en) begin
            empty_q <= empty_nxt;
        end
    end
    // -- Read ready update
    always @(posedge clk) begin
        if(!rst_n) begin
            rd_ready <= 1'b0;
        end
        else if(empty_r_en) begin
            rd_ready <= ~empty_nxt;
        end
    end
end
else if(FIFO_TYPE == 3) begin : CONCAT_FIFO
    // Local parameter
    localparam CAT_NUM      = OUT_DATA_WIDTH/IN_DATA_WIDTH;
    localparam CAT_NUM_W    = $clog2(CAT_NUM);
    
    // Internal variables
    genvar sml_idx;
    
    // Internal signal
    // -- wire
    wire                    wr_hsk;
    wire                    rd_hsk;
    wire                    sml_full;
    // -- reg 
    reg [IN_DATA_WIDTH-1:0] buffer  [0:CAT_NUM-1];
    reg [CAT_NUM_W-1:0]     sml_cnt;
    reg                     wr_ptr;
    reg                     rd_ptr;
    
    // Combination logic
    assign wr_ready_o   = (~(wr_ptr^rd_ptr)) | rd_valid_i;
    assign rd_ready_o   = (wr_ptr^rd_ptr);
    assign empty_o      = ~rd_ready_o;
    assign full_o       = ~wr_ready_o;
    assign wr_hsk       = wr_valid_i & wr_ready_o;
    assign rd_hsk       = rd_valid_i & rd_ready_o;
    assign sml_full     = ~|(sml_cnt ^ (CAT_NUM-1));
    for(sml_idx = 0; sml_idx < CAT_NUM; sml_idx = sml_idx + 1) begin
        if(CONCAT_ORDER == "LSB") begin
            assign data_o[IN_DATA_WIDTH*(sml_idx+1)-1-:IN_DATA_WIDTH] = buffer[sml_idx];
        end
        else if(CONCAT_ORDER == "MSB") begin
            assign data_o[IN_DATA_WIDTH*(sml_idx+1)-1-:IN_DATA_WIDTH] = buffer[CAT_NUM - 1 - sml_idx];
        end
    end
    
    // Flip-flop
    always @(posedge clk) begin
        if(wr_hsk) begin
            buffer[sml_cnt] <= data_i;
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            wr_ptr <= 1'b0;
        end
        else if(wr_hsk & sml_full) begin
            wr_ptr <= ~wr_ptr;
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_ptr <= 1'b0;
        end
        else if(rd_hsk) begin
            rd_ptr <= ~rd_ptr;
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            sml_cnt <= {CAT_NUM_W{1'b0}};
        end
        else begin
            sml_cnt <= sml_cnt + wr_hsk;
        end
    end
    
end
else if(FIFO_TYPE == 4) begin : DECONCAT_FIFO
    // Internal variable
    genvar sml_idx;
    // Local parameter 
    localparam CAT_NUM      = IN_DATA_WIDTH/OUT_DATA_WIDTH;
    localparam CAT_NUM_W    = $clog2(CAT_NUM);
    // Internal signal
    // -- wire
    wire                        wr_hsk;
    wire                        rd_hsk;
    wire [OUT_DATA_WIDTH-1:0]   data_map [0:CAT_NUM-1];    
    wire                        buf_ocp;
    // -- reg 
    reg  [IN_DATA_WIDTH-1:0]    buffer;
    reg  [CAT_NUM_W-1:0]        sml_cnt;
    reg                         rd_ptr;
    reg                         wr_ptr;
    // Combination logic
    assign data_o       = data_map[sml_cnt];
    assign wr_ready_o   = (((~|(sml_cnt^(CAT_NUM-1))) & rd_hsk) | ((~|sml_cnt) & (~buf_ocp)));
    assign rd_ready_o   = buf_ocp;
    assign full_o       = ~wr_ready_o;
    assign empty_o      = ~rd_ready_o;
    assign buf_ocp      = wr_ptr ^ rd_ptr;
    assign wr_hsk       = wr_valid_i & wr_ready_o;
    assign rd_hsk       = rd_valid_i & rd_ready_o;
    for(sml_idx = 0; sml_idx < CAT_NUM; sml_idx = sml_idx + 1) begin
        assign data_map[sml_idx] = buffer[OUT_DATA_WIDTH*(sml_idx+1)-1-:OUT_DATA_WIDTH];
    end
    // Flip-flop
    always @(posedge clk) begin
        if(wr_hsk) begin
            buffer <= data_i;
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            sml_cnt <= {CAT_NUM_W{1'b0}};
        end
        else begin
            sml_cnt <= sml_cnt + rd_hsk;
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            wr_ptr <= 1'b0;
        end
        else begin
            wr_ptr <= wr_ptr + wr_hsk;
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            rd_ptr <= 1'b0;
        end
        else begin
            rd_ptr <= rd_ptr + (rd_hsk & (~|(sml_cnt^(CAT_NUM-1))));
        end
    end
end
endgenerate
endmodule
//    sync_fifo 
//        #(
//        .DATA_WIDTH(),
//        .FIFO_DEPTH(32)
//        ) fifo (
//        .clk(clk),
//        .data_i(),
//        .data_o(),
//        .rd_valid_i(),
//        .wr_valid_i(),
//        .empty_o(),
//        .full_o(),
//        .almost_empty_o(),
//        .almost_full_o(),
//        .rst_n(rst_n)
//        );