`timescale 1ns / 1ps

module picorv32_top #(
    parameter integer CLOCK_FREQ         = 100000000,      // 100 MHz default for XC7S50CSGA324-1 (Pin R2)
    parameter integer BAUD_RATE          = 115200,         // Standard 115200 Baud
    parameter integer BRAM_WORDS         = 16384,          // 64 KB BRAM
    parameter         INIT_FILE          = "program.hex",
    parameter integer RESET_ACTIVE_HIGH  = 1               // 1 = active-high (Real Digital Boolean Board Pin J2)
) (
    input  wire       clk,
    input  wire       reset,
    output wire       uart_tx,
    output wire       trap,
    output wire [3:0] led
);

    // Convert external reset to active-high internal raw reset
    // For active-high button (J2), pressing drives 1 -> rst_raw = 1 (reset asserted)
    wire rst_raw = RESET_ACTIVE_HIGH ? reset : ~reset;

    // 2-stage reset synchronizer for clean clock-domain crossing and FPGA stability
    reg [1:0] rst_sync;
    always @(posedge clk or posedge rst_raw) begin
        if (rst_raw) begin
            rst_sync <= 2'b11;
        end else begin
            rst_sync <= {rst_sync[0], 1'b0};
        end
    end

    // Active-low synchronous reset for the SoC
    wire sys_resetn = ~rst_sync[1];

    // Instantiate the complete SoC
    soc #(
        .CLOCK_FREQ(CLOCK_FREQ),
        .BAUD_RATE (BAUD_RATE),
        .BRAM_WORDS(BRAM_WORDS),
        .INIT_FILE (INIT_FILE)
    ) u_soc (
        .clk      (clk),
        .resetn   (sys_resetn),
        .trap     (trap),
        .uart_tx  (uart_tx)
    );

    // 26-bit clock divider for heartbeat (~1.5 Hz blink at 100 MHz)
    reg [25:0] heartbeat_cnt = 26'd0;
    always @(posedge clk) begin
        heartbeat_cnt <= heartbeat_cnt + 1'b1;
    end

    // Diagnostic LEDs
    // led[0]: Clock heartbeat (proves 100 MHz oscillator is oscillating)
    // led[1]: CPU running indicator (HIGH when reset is released)
    // led[2]: UART TX activity indicator (pulses when transmitting)
    // led[3]: CPU trap indicator (HIGH only if CPU crashes)
    assign led[0] = heartbeat_cnt[25];
    assign led[1] = sys_resetn;
    assign led[2] = ~uart_tx;
    assign led[3] = trap;

endmodule
