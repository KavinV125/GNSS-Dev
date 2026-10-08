`timescale 1ns / 1ps

module uart_tx #(
    parameter integer CLOCK_FREQ = 100000000,    // 100 MHz default for XC7S50
    parameter integer BAUD_RATE  = 115200
) (
    input  wire       clk,
    input  wire       reset,
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output reg        tx,
    output wire       tx_busy
);

    localparam integer CLOCKS_PER_BIT = CLOCK_FREQ / BAUD_RATE;

    localparam [1:0] STATE_IDLE  = 2'b00;
    localparam [1:0] STATE_START = 2'b01;
    localparam [1:0] STATE_DATA  = 2'b10;
    localparam [1:0] STATE_STOP  = 2'b11;

    reg [1:0]  state;
    reg [15:0] clk_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  data_buf;

    // tx_busy is asserted whenever a transfer is active or starting
    assign tx_busy = (state != STATE_IDLE) || tx_start;

    always @(posedge clk) begin
        if (reset) begin
            state    <= STATE_IDLE;
            tx       <= 1'b1; // Idle line is HIGH
            clk_cnt  <= 16'd0;
            bit_idx  <= 3'd0;
            data_buf <= 8'd0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    tx      <= 1'b1;
                    clk_cnt <= 16'd0;
                    bit_idx <= 3'd0;
                    if (tx_start) begin
                        data_buf <= tx_data;
                        state    <= STATE_START;
                    end
                end

                STATE_START: begin
                    tx <= 1'b0; // Start bit is LOW
                    if (clk_cnt < CLOCKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end else begin
                        clk_cnt <= 16'd0;
                        state   <= STATE_DATA;
                    end
                end

                STATE_DATA: begin
                    tx <= data_buf[bit_idx]; // Data bits: 0 to 7, LSB first
                    if (clk_cnt < CLOCKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end else begin
                        clk_cnt <= 16'd0;
                        if (bit_idx < 3'd7) begin
                            bit_idx <= bit_idx + 1'b1;
                        end else begin
                            bit_idx <= 3'd0;
                            state   <= STATE_STOP;
                        end
                    end
                end

                STATE_STOP: begin
                    tx <= 1'b1; // Stop bit is HIGH
                    if (clk_cnt < CLOCKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end else begin
                        clk_cnt <= 16'd0;
                        state   <= STATE_IDLE;
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule
