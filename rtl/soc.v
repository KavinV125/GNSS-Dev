`timescale 1ns / 1ps

module soc #(
    parameter integer CLOCK_FREQ = 100000000,      // 100 MHz clock
    parameter integer BAUD_RATE  = 115200,         // 115200 Baud
    parameter integer BRAM_WORDS = 16384,          // 64 KB RAM
    parameter         INIT_FILE  = "program.hex"
) (
    input  wire clk,
    input  wire resetn,     // Active-low reset for CPU and system
    output wire trap,       // CPU trap indicator
    output wire uart_tx     // UART serial TX output
);

    // CPU native memory bus signals
    wire        mem_valid;
    wire        mem_instr;
    wire        mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [ 3:0] mem_wstrb;
    wire [31:0] mem_rdata;

    // Peripheral select lines
    // 0x00000000 - 0x0000FFFF : 64 KB unified instruction & data BRAM
    wire bram_sel = (mem_addr[31:16] == 16'h0000);

    // 0x02000000 : UART TX peripheral register
    wire uart_sel = (mem_addr == 32'h02000000) || (mem_addr[31:24] == 8'h02);

    // Peripheral response signals
    wire        bram_ready;
    wire [31:0] bram_rdata;

    wire        uart_ready;
    wire [31:0] uart_rdata;

    // Safety fallback for unmapped addresses to prevent CPU hanging on illegal pointers
    reg unmapped_ready;
    always @(posedge clk) begin
        if (!resetn) begin
            unmapped_ready <= 1'b0;
        end else begin
            unmapped_ready <= mem_valid && !bram_sel && !uart_sel && !unmapped_ready;
        end
    end

    // Bus Multiplexer
    assign mem_ready = bram_sel ? bram_ready :
                       uart_sel ? uart_ready :
                       unmapped_ready;

    assign mem_rdata = bram_sel ? bram_rdata :
                       uart_sel ? uart_rdata :
                       32'h00000000;

    // PicoRV32 RISC-V Core Instance
    picorv32 #(
        .ENABLE_COUNTERS     (1),
        .ENABLE_COUNTERS64   (0),
        .ENABLE_REGS_16_31   (1),
        .ENABLE_REGS_DUALPORT(1),
        .LATCHED_MEM_RDATA   (0),
        .TWO_STAGE_SHIFT     (1),
        .BARREL_SHIFTER      (0),
        .TWO_CYCLE_COMPARE   (0),
        .TWO_CYCLE_ALU       (0),
        .COMPRESSED_ISA      (0),
        .CATCH_MISALIGN      (1),
        .CATCH_ILLINSN       (1),
        .ENABLE_PCPI         (0),
        .ENABLE_MUL          (0),
        .ENABLE_FAST_MUL     (0),
        .ENABLE_DIV          (0),
        .ENABLE_IRQ          (0),
        .ENABLE_IRQ_QREGS    (0),
        .ENABLE_IRQ_TIMER    (0),
        .ENABLE_TRACE        (0),
        .REGS_INIT_ZERO      (1),
        .PROGADDR_RESET      (32'h0000_0000),
        .PROGADDR_IRQ        (32'h0000_0010),
        .STACKADDR           (32'h0001_0000)  // Stack starts at top of 64KB BRAM
    ) u_cpu (
        .clk          (clk),
        .resetn       (resetn),
        .trap         (trap),

        // Memory interface
        .mem_valid    (mem_valid),
        .mem_instr    (mem_instr),
        .mem_ready    (mem_ready),
        .mem_addr     (mem_addr),
        .mem_wdata    (mem_wdata),
        .mem_wstrb    (mem_wstrb),
        .mem_rdata    (mem_rdata),

        // Look-Ahead Interface (unused)
        .mem_la_read  (),
        .mem_la_write (),
        .mem_la_addr  (),
        .mem_la_wdata (),
        .mem_la_wstrb (),

        // Pico Co-Processor Interface (unused)
        .pcpi_valid   (),
        .pcpi_insn    (),
        .pcpi_rs1     (),
        .pcpi_rs2     (),
        .pcpi_wr      (1'b0),
        .pcpi_rd      (32'h0),
        .pcpi_wait    (1'b0),
        .pcpi_ready   (1'b0),

        // IRQ Interface (unused)
        .irq          (32'h0),
        .eoi          (),

        // Trace Interface (unused)
        .trace_valid  (),
        .trace_data   ()
    );

    // Instruction & Data Block RAM (Unified Memory)
    bram #(
        .WORDS    (BRAM_WORDS),
        .INIT_FILE(INIT_FILE)
    ) u_bram (
        .clk      (clk),
        .resetn   (resetn),
        .bram_sel (bram_sel),
        .mem_valid(mem_valid),
        .mem_wstrb(mem_wstrb),
        .mem_addr (mem_addr),
        .mem_wdata(mem_wdata),
        .mem_ready(bram_ready),
        .mem_rdata(bram_rdata)
    );

    // Memory-Mapped UART TX Peripheral
    simple_uart #(
        .CLOCK_FREQ(CLOCK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_uart (
        .clk      (clk),
        .reset    (~resetn),  // simple_uart uses active-high reset
        .uart_sel (uart_sel),
        .mem_valid(mem_valid),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_ready(uart_ready),
        .mem_rdata(uart_rdata),
        .uart_tx  (uart_tx)
    );

endmodule
