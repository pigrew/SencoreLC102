# Sencore-IB to USB PCB

This is an Altium-based PCB project for a Sencore-IB to USB clone.


# Defects

Some defects have been noticed on this PCB revision:

1. The selected isolated DC-DC converter is unregulated. This would fry the bus tranceiver IC. Correct by cutting the track at the input of the bus tranceiver IC and add a TPS77050 LDO.
2. Some silkscreens are not in the proper place. A lot of the pin-1 designators didn't make it.
3. The selected STM32F042 barely has enough RAM to run the USB stack. Board revisions need a different footprint to accept MCUs with more RAM. For the current footprint, STM32F070F6P6TR could be used which has more flash, but not more RAM (and it needs an external crystal).
4. USB D+ and D- are swapped; Do a crossover in place of R17/R18.
5. Pinout of U3 is flipped; Mount part upsidedown, but leave the pin closest to the RS232 connector up in the air (the flag pin).
6. JTAG pins are connected to the wrong place. SWDIO should be pin13, SWCLK should be pin14