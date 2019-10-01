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

(From the point of view of LC102. Write goes to IB, Read comes from IB)

| Pin        | Function |
|------------|----------|
| p4.\[3210\]  | D3 .. D0 |
| p5.\[3210\]  | D7 .. D4 |
|------------|----------|
| p6         | Inputs to the 8039      |
| p6.3       | Write ACK (active low) |
| p6.2       | Talk request, (only sent in write mode (P7.0=1)?), clear |
| p6.1       | (Normally low, is this a reset thing?) |
| p6.0       | READ data Available (active low), data already on P4/P5 bus. |
|------------|----------|
| p7         | Outputs from the 8039      |
| p7.3       |               |
| p7.2       | W̅R̅I̅T̅E̅  |
| p7.1       | Read complete (active low) |
| p7.0       | Enter LC102 read phase (active low) |


(Below is from the point of view of the meter, not the IB slave)

To initialize:
1. Set p4,p5,p6,p7 to be read ports
2. p7 = 1110 (enter read phase)

To check if I should talk:
1. p7 = 1111
2. Abort if p6.2 is high.
3. Continue with write if p6.2 is low.

To write:

1. Put data on P4/P5 bus
2. Assert p7.2 low
3. Wait until p6.3 goes low (ACK) (p6.2 should go back high at this point, too)
4. Reset p7.2 high

To enter read phase:
1. Set p4/p5/p6 to inputs
2. P7 = 1111
3. p7 = 1110 (Sets read mode)

To perform read:
1. Wait until p6.0 goes low
2. Read data
3. Ack data by asserting p7.1 low
4. Wait until p6.0 goes high
5. Reset p7.1 high



