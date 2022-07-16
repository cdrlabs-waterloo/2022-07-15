************************************************************************
* auCdl Netlist:
* 
* Library Name:  hgo_analog
* Top Cell Name: AO_DLO_D0
* View Name:     schematic
* Netlisted on:  Mar 18 08:53:18 2021
************************************************************************

*.BIPOLAR
*.RESI = 2000 
*.RESVAL
*.CAPVAL
*.DIOPERI
*.DIOAREA
*.EQUATION
*.SCALE METER
.PARAM



************************************************************************
* Library Name: hgo_analog
* Cell Name:    AO_DLO_D0
* View Name:    schematic
************************************************************************

.SUBCKT AO_DLO_D0 Z1 Z2 A1 A2 B1 B2 CP VDD VSS
*.PININFO A1:I A2:I B1:I B2:I CP:I Z1:O Z2:O VDD:B VSS:B
MM13 Z2 Y VDD VDD pch l=60n w=260.0n m=1
MM12 VDD X Y VDD pch l=120.0n w=120.0n m=1
MM11 Y CP VDD VDD pch l=60n w=260.0n m=1
MM6 VDD Y X VDD pch l=120.0n w=120.0n m=1
MM4 Z1 X VDD VDD pch l=60n w=260.0n m=1
MM0 X CP VDD VDD pch l=60n w=260.0n m=1
MM14 Z2 Y VSS VSS nch l=60n w=195.00n m=1
MM10 Y A2 net15 VSS nch l=60n w=195.00n m=1
MM9 Y B2 net15 VSS nch l=60n w=195.00n m=1
MM5 Z1 X VSS VSS nch l=60n w=195.00n m=1
MM3 X A1 net14 VSS nch l=60n w=195.00n m=1
MM2 net14 B1 net15 VSS nch l=60n w=195.00n m=1
MM1 net15 CP VSS VSS nch l=60n w=195.00n m=1
.ENDS

