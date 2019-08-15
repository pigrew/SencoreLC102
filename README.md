# Sencore LC102 Reverse-Engineering

## Firmware

The firmware is stored on an EEPROM. The circuit is designed to only read half of the
ROM, so half of the ROM binary is blank.

It uses a TMP80C39AP processor, part of the Intel MC-48 family. Its ROM is segmented
into four parts (the address bus is only as wide as 1/8th of the EEPROM). It can
toggle output ports in order to switch between I/O segments.

It has been disassembled using the xdasmx software (sadly, not open source), and
also a python script that will merge comments into the disassembly. I've mostly
been working on the "B" part, which handles GPIB.

If browsing the code, you should look at comments in the *.sym files, in adition to 
the *.lsta (annotated source listing) files.

## GPIB/RS232

Stored in firmware part B is the GPIB/RS232 controller logic. It uses an TMP82C43P to
expand its I/O ports and access a GPIB controller IC or UART. Here is the pin mapping that
I've figured out so far:

| Pin        | Function |
|------------|----------|
| p4.\[3210\]  | D3 .. D0 |
| p5.\[3210\]  | D7 .. D4 |
| p6         | Inputs to the 8039         |
| p6.3       | I̅R̅Q̅(operation complete) |
| p7         | Outputs from the 8039      |
| p7.3       | W̅R̅I̅T̅E̅                 |
| p7.0       | R̅E̅S̅E̅T̅ (???)           |

For GPIB, there should be a set of three register select pins, I'm guessing they are p7.\[210\].
But, there also needs to be a read_enable (or read) pin.
I don't know how it would be mapped. Addresses also need to be input to the controller
from the switches in the interface box. Perhaps there is some sort of mux in the box
that I've not decoded yet.

For RS232:

Reset is:
1. WRITE P7 0xF
2. WRITE P7 0xF
3. WRITE P7 0xF
4. WRITE P7 0xF
