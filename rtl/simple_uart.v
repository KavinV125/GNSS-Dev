`timescale 1ns / 1ps

module simple_uart #(
    parameter integer CLOCK_FREQ = 100000000,     // 100 MHz default for XC7S50
    parameter integer BAUD_RATE  = 115200
) (
    input  wire        clk,
    input  wire        reset,
    input  wire        uart_sel,
    input  wire        mem_valid,
    input  wire [31:0] mem_wdata,
    input  wire [ 3:0] mem_wstrb,
    output reg         mem_ready,
    output wire [31:0] mem_rdata,
    output wire        uart_tx
);

    reg        tx_start;
    reg  [7:0] tx_data;
    wire       tx_busy;

    uart_tx #(
        .CLOCK_FREQ(CLOCK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_tx (
        .clk     (clk),
        .reset   (reset),
        .tx_start(tx_start),
        .tx_data (tx_data),
        .tx      (uart_tx),
        .tx_busy (tx_busy)
    );

    // Reading the UART register returns the busy flag on bit 0
    assign mem_rdata = {31'b0, tx_busy};

    localparam [1:0] STATE_IDLE = 2'b00;
    localparam [1:0] STATE_WAIT = 2'b01;

    reg [1:0] state;

    always @(posedge clk) begin
        if (reset) begin
            state     <= STATE_IDLE;
            tx_start  <= 1'b0;
            tx_data   <= 8'h00;
            mem_ready <= 1'b0;
        end else begin
            tx_start  <= 1'b0;
            mem_ready <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    if (uart_sel && mem_valid) begin
                        if (|mem_wstrb) begin
                            // CPU is writing a byte to UART TX
                            if (!tx_busy) begin
                                // Transmitter is free: accept byte, trigger UART transmission
                                tx_data   <= mem_wdata[7:0];
                                tx_start  <= 1'b1;
                                mem_ready <= 1'b1; // Acknowledge write to CPU
                                state     <= STATE_WAIT;
                            end
                            // If tx_busy is 1: stay in STATE_IDLE and keep mem_ready = 0.
                            // This automatically stalls PicoRV32 until UART can safely accept the write!
                        end else begin
                            // CPU is reading UART status register
                            mem_ready <= 1'b1;
                            state     <= STATE_WAIT;
                        end
                    end
                end

                STATE_WAIT: begin
                    // Wait for PicoRV32 to deassert mem_valid to complete the bus handshake
                    if (!mem_valid) begin
                        state <= STATE_IDLE;
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule
