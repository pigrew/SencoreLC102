
.PHONY: default

%.lst: %.bin %.sym
	../../Dasmx.exe -wt $<

%.lsta: %.lst %.rem
	./mergeRemarks.py $*.lst $*.rem > $@

default: A.lsta B.lsta C.lsta D.lsta