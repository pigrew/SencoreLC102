Firmware for IB78 UART adapter.

|Component| Manufacturer | Part Number |
|---|---|---|
|Micro | Intel |P80C31BH  |
|EPROM |S |27C256-20 FA |
|IO Expander | NEC | D8243C |
|UART | National | NS8250AN/INS8250AN |

Memory map:

| Address | Content |
| --- | --- |
| 0x08 | Baud rate (indexed)
| 0x22 | global status register (bitfield)|
| 0x7fef | Peripheral (only reads), maybe the DIP switches?|
| 0x7ff7 | Peripheral (reads and writes) |
| 0x7ff8 | UART TX/RX data & divisor (muxed by DLAB) |
| 0x7ff9 | UART INT_EN table |
| 0x7ffa | UART INT_FLAG table |
| 0x7ffb | UART line control (parity, stop bits, etc) |
| 0x7ffc | UART modem control |
| 0x7ffd | UART line status |
| 0x7ffe | UART modem status |
