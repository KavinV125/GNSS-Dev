#define LED_REG (*(volatile unsigned int *)0x30000000)

static void delay(void)
{
    for (volatile int i = 0; i < 200000; i++)
        ;
}

int main(void)
{
    unsigned int val = 1;

    while (1) {
        LED_REG = val;
        delay();
        val <<= 1;
        if (val == 0 || val > 0x8000)
            val = 1;
    }

    return 0;
}
