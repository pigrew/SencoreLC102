#!/usr/bin/python3

# This script merges comments into the output of dasmx

import sys

def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)
	
def getNextRemark(rem_fp):
	while (True):
		rem_line = rem_fp.readline();
		# File complete
		if(not rem_line):
			return None
			
		rem_line = rem_line.rstrip()
		# Check for empty remark line
		if (rem_line.isspace() or not rem_line):
			continue
			
		rem_parts = rem_line.split(None,maxsplit=1)
		rem_line_num = int(rem_parts[0], 16)
		#print("XY ```%s''' <<<%s>>>" %(rem_line_num, rem_parts[1]))
		return (rem_line_num, rem_parts[1]);
	
def countStringCols(str, tabwidth=4):
	w = 0
	for c in str:
		w = w + 1
		if(c == '\t'):
			x = w % tabwidth
			if(x>0):
				w = w + (tabwidth-x)
		#print ("* %c => %d" % (c, w))
	return w
	
eprint("Merging Remarks into source file")

asmFilename = sys.argv[1]
remFilename = sys.argv[2]

eprint("remFilename is %s" % (remFilename))

rem_fp = open(remFilename, 'r')
asm_fp = open(asmFilename, 'r')

rem = getNextRemark(rem_fp)
exit
tabwidth = 4
commentColumn = 70

for asm_line in asm_fp:
	# Read a line
	asm_line = asm_line.rstrip()
	# Is it a code line?
	if(len(asm_line) > 9 and asm_line[4] == ' ' and asm_line[5] == ':' and asm_line[6] == ' '):
		asm_parts = asm_line.split(None,2)
		asm_line_num = int(asm_parts[0],16)
		while(rem and rem[0] < asm_line_num):
			print("%s;%s" % ("\t" * int(commentColumn/tabwidth),rem[1]))
			rem = getNextRemark(rem_fp)
		if(rem and rem[0] == asm_line_num):
			w = commentColumn - countStringCols(asm_line)
			if(w < 1):
				w = 4
			w = w - (w % 4)
			w = int(w / 4);
			print("%s%s; %s" % (asm_line, "\t" * w, rem[1]))
			rem = getNextRemark(rem_fp)
			while(rem and rem[0] == asm_line_num):
				print("%s; %s" % ("\t" * int(commentColumn/tabwidth),rem[1]))
				rem = getNextRemark(rem_fp)
		else:
			print("%s" % (asm_line))
	else:
		print("%s" % (asm_line))
	
while(rem):
	print("\t\t\t\t\t; " + rem[1])
	rem = getNextRemark(rem_fp)
	
asm_fp.close()
rem_fp.close()
