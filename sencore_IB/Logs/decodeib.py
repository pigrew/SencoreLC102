#!/usr/bin/python3

import fileinput

flag_repeats = True

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
        if(flag_repeats and (((cmd & 3) == 0) or  ((cmd & 3) == 1)) ): # port 4 or 5
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
            print(f"{t:0.8f}\t{cmdString(cmd)}\t{data:04b}")
        phase = 0
    elif(phase == 2): # P4/5 value
        p45_a = decodeVal(parts[1])
        phase = 3
    elif(phase == 3): # P5 cmd
        cmd2 = decodeVal(parts[1])
        cmdMatch = (cmd & 12) == (cmd2 & 12)
        regsValid = (((cmd & 3) == 0) and ((cmd2 & 3) == 1)) or (((cmd & 3) == 1) and ((cmd2 & 3) == 0))
        if( cmdMatch and regsValid):
            phase = 4
            continue
        # Something weird happened
        print(f"bad cmd is {cmdString(cmd2)};  {cmdMatch} {regsValid} ///{cmd},{cmd2}")
        print(f"{t:0.8f}\t{cmdString(cmd)}\t{p45_a:04b}")
        oldcmd = cmd
        cmd = cmd2
        repeats = 0
        phase = 1
    elif(phase == 4): # P4 value
        p45_b = decodeVal(parts[1])
        if((cmd & 3) == 0): # P4,P5
            b = (p45_a << 4) | p45_b
            print(f"{t:0.8f}\t{cmdString(cmd)}/5\t{p45_a:04b} {p45_a:04b}\t{b:02x}")
        else:
            b = (p45_b << 4) | p45_a
            print(f"{t:0.8f}\t{cmdString(cmd)}/4\t{p45_a:04b} {p45_b:04b}\t{b:02x}")
        phase = 0
