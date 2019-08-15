#!/usr/bin/python3

import fileinput

flag_repeats = False

phase = 0
repeats = 0

oldcmd = -1
olddata = -1


def decodeVal(v):
    if(v[0] == "b"):
        return int(v[1])*8 + int(v[2])*4 + int(v[3])*2 + int(v[4])*1
    else:
       raise() 
       
cmds = ["READ","WRITE","OR","AND"]
ports = ["P4","P5","P6","P7"]

def cmdString(x):
    cmd = (x & 12) >> 2
    port = x & 3
    return f"{cmds[cmd]:5} {ports[port]}"

print("Time       \tCMD_ID     \tData")
for line in fileinput.input():
    if(line.startswith("#")):
        continue
    if(line.startswith('Time')):
        continue
    parts = line.rstrip().split(",")
    if(len(parts)!=2):
        continue
    
    if(phase == 0): # Expecting cmd
        t=float(parts[0])
        cmd = decodeVal(parts[1])
        if((cmd & 3) == 0): # port 4
            if(repeats != 0):
                print(f"[repeat {repeats} times]")
                repeats = 0
            oldcmd = -1
            phase = 2
        else:
            phase = 1
    elif(phase == 1): # normal value
        data = decodeVal(parts[1])
        if(flag_repeats and (cmd == oldcmd) and (data == olddata)):
            repeats = repeats + 1
        else:
            if(repeats != 0):
                print(f"[repeat {repeats} times]")
            oldcmd = cmd
            olddata = data
            repeats = 0
            print(f"{t:0.8f}\t{cmdString(cmd)}\t{data:b}")
        phase = 0
    elif(phase == 2): # P4 value
        p4 = decodeVal(parts[1])
        phase = 3
    elif(phase == 3): # P5 cmd
        cmd2 = decodeVal(parts[1])
        if((cmd2 & 3) != 1): # port 5
            print(f"bad cmd is {cmdString(cmd2)}")
            raise()
        if((cmd2 & 12) != (cmd & 12)): # Cmds don't match
            raise()
        phase = 4
    elif(phase == 4): # P4 value
        p5 = decodeVal(parts[1])
        b = (p5 << 4) | p4
        print(f"{t:0.8f}\t{cmdString(cmd)}/5\t{p5:b} {p4:b}\t{b:02x}")
        phase = 0