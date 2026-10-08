`timescale 1ns / 1ps

module tb_soc;

    // Simulation Parameters for XC7S50 (100 MHz oscillator)
    parameter integer CLOCK_FREQ = 100000000; // 100 MHz
    parameter integer BAUD_RATE  = 115200;    // 115200 baud
    parameter integer BRAM_WORDS = 16384;     // 64 KB

    localparam time CLK_PERIOD = 10ns;        // 100 MHz clock period
    localparam time BIT_PERIOD = 8680ns;      // 868 cycles * 10ns = 8.68 us per bit

    reg clk;
    reg reset; // Active-low reset (matches C18 button on Arty S7)
    wire uart_tx;
    wire trap;

    // Instantiate Top-Level SoC configured for XC7S50
    picorv32_top #(
        .CLOCK_FREQ       (CLOCK_FREQ),
        .BAUD_RATE        (BAUD_RATE),
        .BRAM_WORDS       (BRAM_WORDS),
        .INIT_FILE        ("program.hex"),
        .RESET_ACTIVE_HIGH(0) // Active-low button
    ) dut (
        .clk    (clk),
        .reset  (reset),
        .uart_tx(uart_tx),
        .trap   (trap)
    );

    // Clock Generator (100 MHz)
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // Reset Sequence (Active-Low: 0 = in reset, 1 = run)
    initial begin
        $display("==========================================================");
        $display(" Starting PicoRV32 SoC Simulation for XC7S50 (100 MHz)    ");
        $display("==========================================================");

        $dumpfile("tb_soc.vcd");
        $dumpvars(0, tb_soc);

        reset = 1'b0; // Assert reset (active-low)
        #(200ns);
        @(posedge clk);
        reset = 1'b1; // Release reset (pin goes high)
        $display("[%0t ns] Reset released (Active-Low). PicoRV32 booting from 0x00000000...", $time);

        // Run simulation until string is completely transmitted or timeout
        #(2500000ns);
        $display("\n[%0t ns] Simulation timeout.", $time);
        $finish;
    end

    // Trap monitor
    always @(posedge clk) begin
        if (trap) begin
            $display("\n[%0t ns] ERROR: CPU entered TRAP state!", $time);
            $finish;
        end
    end

    // Behavioral UART RX Monitor
    reg [7:0] rx_byte;
    integer bit_idx;
    string received_string = "";

    initial begin
        forever begin
            // 1. Wait for Start bit (falling edge)
            @(negedge uart_tx);

            // 2. Wait to middle of start bit
            #(BIT_PERIOD / 2);
            if (uart_tx == 1'b0) begin
                // 3. Sample 8 data bits
                for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                    #(BIT_PERIOD);
                    rx_byte[bit_idx] = uart_tx;
                end

                // 4. Wait for stop bit
                #(BIT_PERIOD);
                if (uart_tx == 1'b1) begin
                    $write("%c", rx_byte);
                    $fflush();
                    received_string = {received_string, rx_byte};

                    // Check for message completion
                    if (rx_byte == 8'h0A) begin // '\n'
                        $display("\n----------------------------------------------------------");
                        $display("[%0t ns] SUCCESS: Complete message received: \"%s\"", $time, received_string);
                        $display("==========================================================");
                        #(BIT_PERIOD * 4);
                        $finish;
                    end
                end else begin
                    $display("\n[%0t ns] UART Framing Error!", $time);
                end
            end
        end
    end

endmodule
