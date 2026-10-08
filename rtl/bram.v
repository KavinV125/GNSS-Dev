`timescale 1ns / 1ps

module bram #(
    parameter integer WORDS     = 16384,          // 16384 x 32-bit words = 64 KB memory
    parameter         INIT_FILE = "program.hex"   // Hex file to initialize memory
) (
    input  wire        clk,
    input  wire        resetn,
    input  wire        bram_sel,
    input  wire        mem_valid,
    input  wire [ 3:0] mem_wstrb,
    input  wire [31:0] mem_addr,
    input  wire [31:0] mem_wdata,
    output reg         mem_ready,
    output reg  [31:0] mem_rdata
);

    localparam integer ADDR_BITS = $clog2(WORDS);

    // Inferred synchronous Block RAM
    reg [31:0] mem [0:WORDS-1];

    // PicoRV32 uses 32-bit byte addresses.
    // mem_addr[31:2] converts byte address to 32-bit word index.
    wire [ADDR_BITS-1:0] word_addr = mem_addr[ADDR_BITS+1:2];

    // Initialize memory contents from HEX file for simulation and synthesis
    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    // Synchronous memory access with byte-wide write enables
    always @(posedge clk) begin
        if (mem_valid && bram_sel) begin
            if (mem_wstrb[0]) mem[word_addr][ 7: 0] <= mem_wdata[ 7: 0];
            if (mem_wstrb[1]) mem[word_addr][15: 8] <= mem_wdata[15: 8];
            if (mem_wstrb[2]) mem[word_addr][23:16] <= mem_wdata[23:16];
            if (mem_wstrb[3]) mem[word_addr][31:24] <= mem_wdata[31:24];
            mem_rdata <= mem[word_addr];
        end
    end

    // Single wait-state synchronous ready handshake:
    // mem_ready asserts 1 cycle after mem_valid && bram_sel, matching synchronous BRAM output timing.
    always @(posedge clk) begin
        if (!resetn) begin
            mem_ready <= 1'b0;
        end else begin
            mem_ready <= mem_valid && bram_sel && !mem_ready;
        end
    end

endmodule
