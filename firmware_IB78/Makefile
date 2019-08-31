
.PHONY: default

%.lst: %.bin %.sym
	dasmx140/Dasmx.exe -wt $<

%.lsta: %.lst %.rem
	./mergeRemarks.py $*.lst $*.rem > $@

default: Sencore_IB78_Signetic_27C256-20_169G266-33.lsta