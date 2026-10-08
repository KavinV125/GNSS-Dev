/*
 * Bare-metal C Firmware for PicoRV32 Minimal SoC
 * Prints "hello lingesh\r\n" over memory-mapped UART TX.
 */

#define UART_TX (*(volatile unsigned int *)0x02000000)

static void uart_putc(char c)
{
    // The hardware UART automatically stalls CPU writes if transmitting,
    // guaranteeing zero dropped characters without requiring software delays.
    UART_TX = (unsigned int)c;
}

static void uart_puts(const char *str)
{
    while (*str) {
        uart_putc(*str++);
    }
}

static void delay(volatile unsigned int count)
{
    while (count--) {
        __asm__ volatile ("nop");
    }
}

int main(void)
{
    const char *msg = "hello lingesh\r\n";

    while (1) {
        uart_puts(msg);
        delay(2000000); // ~0.5 - 1 second delay at 100 MHz
    }

    return 0;
}
