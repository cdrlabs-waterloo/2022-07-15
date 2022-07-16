`timescale 1ns/10ps

`celldefine
module AO_DLO_D0 (Z1, Z2, A1, A2, B1, B2, CP, VDD, VSS);
	output Z1;
	output Z2;
	input A1, B1, CP;
	input A2, B2;
        inout VDD, VSS;

        and_dlo(Z1, CP, A1, B1);
        or_dlo (Z2, CP, A2, B2);

	specify
		if ((B1 & CP))
			(A1 => Z1) = 0;
		if ((A1 & CP))
			(B1 => Z1) = 0;
		if ((A1 & B1))
			(CP => Z1) = 0;
		if ((~B2 & CP))
			(A2 => Z2) = 0;
		if ((~A2 & CP))
			(B2 => Z2) = 0;
		if ((A2 & B2))
			(CP => Z2) = 0;
		if ((A2 & ~B2))
			(CP => Z2) = 0;
		if ((~A2 & B2))
			(CP => Z2) = 0;
	endspecify

endmodule
`endcelldefine

`celldefine
module AO_DLO_D1 (Z1, Z2, A1, A2, B1, B2, CP, VDD, VSS);
	output Z1;
	output Z2;
	input A1, B1, CP;
	input A2, B2;
        inout VDD, VSS;

        and_dlo(Z1, CP, A1, B1);
        or_dlo (Z2, CP, A2, B2);

	specify
		if ((B1 & CP))
			(A1 => Z1) = 0;
		if ((A1 & CP))
			(B1 => Z1) = 0;
		if ((A1 & B1))
			(CP => Z1) = 0;
		if ((~B2 & CP))
			(A2 => Z2) = 0;
		if ((~A2 & CP))
			(B2 => Z2) = 0;
		if ((A2 & B2))
			(CP => Z2) = 0;
		if ((A2 & ~B2))
			(CP => Z2) = 0;
		if ((~A2 & B2))
			(CP => Z2) = 0;
	endspecify

endmodule
`endcelldefine

`celldefine
module XOR_DLO_D0 (Z1, Z2, A1, A2, B1, B2, CP, VDD, VSS);
	output Z1;
	output Z2;
	input A1, B1, CP;
	input A2, B2;
        inout VDD, VSS;

        xor_dlo(Z1, CP, A1, B1);
        xnor_dlo (Z2, CP, A2, B2);

	specify
		if ((~B1 & CP))
			(A1 => Z1) = 0;
		if ((~A1 & CP))
			(B1 => Z1) = 0;
		if ((A1 & ~B1))
			(CP => Z1) = 0;
		if ((~A1 & B1))
			(CP => Z1) = 0;
		if ((B2 & CP))
			(A2 => Z2) = 0;
		if ((A2 & CP))
			(B2 => Z2) = 0;
		if ((A2 & B2))
			(CP => Z2) = 0;
		if ((~A2 & ~B2))
			(CP => Z2) = 0;
	endspecify

endmodule
`endcelldefine

`celldefine
module XOR_DLO_D1 (Z1, Z2, A1, A2, B1, B2, CP, VDD, VSS);
	output Z1;
	output Z2;
	input A1, B1, CP;
	input A2, B2;
        inout VDD, VSS;

        xor_dlo(Z1, CP, A1, B1);
        xnor_dlo (Z2, CP, A2, B2);

	specify
		if ((~B1 & CP))
			(A1 => Z1) = 0;
		if ((~A1 & CP))
			(B1 => Z1) = 0;
		if ((A1 & ~B1))
			(CP => Z1) = 0;
		if ((~A1 & B1))
			(CP => Z1) = 0;
		if ((B2 & CP))
			(A2 => Z2) = 0;
		if ((A2 & CP))
			(B2 => Z2) = 0;
		if ((A2 & B2))
			(CP => Z2) = 0;
		if ((~A2 & ~B2))
			(CP => Z2) = 0;
	endspecify
endmodule
`endcelldefine

`celldefine
module XOR_DLO_D2 (Z1, Z2, A1, A2, B1, B2, CP, VDD, VSS);
	output Z1;
	output Z2;
	input A1, B1, CP;
	input A2, B2;
        inout VDD, VSS;

        xor_dlo(Z1, CP, A1, B1);
        xnor_dlo (Z2, CP, A2, B2);

	specify
		if ((~B1 & CP))
			(A1 => Z1) = 0;
		if ((~A1 & CP))
			(B1 => Z1) = 0;
		if ((A1 & ~B1))
			(CP => Z1) = 0;
		if ((~A1 & B1))
			(CP => Z1) = 0;
		if ((B2 & CP))
			(A2 => Z2) = 0;
		if ((A2 & CP))
			(B2 => Z2) = 0;
		if ((A2 & B2))
			(CP => Z2) = 0;
		if ((~A2 & ~B2))
			(CP => Z2) = 0;
	endspecify
endmodule
`endcelldefine

primitive and_dlo(z, cp, a, b);
  output z; 
  input cp, a, b;
  // cp a b z z+
  table
    1   1  1  : 1  ;
    1   0  1  : 0  ;
    1   1  0  : 0  ;
    1   0  0  : 0  ;
    0   ?  ?  : 0  ; // precharge
  endtable
endprimitive

primitive or_dlo(z, cp, a, b);
  output z; 
  input cp, a, b;
  // cp a b z z+
  table
   1   1  1  :  1  ;
   1   0  1  :  1  ;
   1   1  0  :  1  ;
   1   0  0  :  0  ;
   0   ?  ?  :  0  ; // precharge
  endtable
endprimitive

primitive xor_dlo(z, cp, a, b);
  output z; 
  input cp, a, b;
  // cp a b z z+
  table
   1   1  1  :  0  ;
   1   0  1  :  1  ;
   1   1  0  :  1  ;
   1   0  0  :  0  ;
   0   ?  ?  :  0  ; // precharge
  endtable
endprimitive

primitive xnor_dlo(z, cp, a, b);
  output z; 
  input cp, a, b;
  // cp a b z z+
  table
   1   1  1  :  1  ;
   1   0  1  :  0  ;
   1   1  0  :  0  ;
   1   0  0  :  1  ;
   0   ?  ?  :  0  ; // precharge
  endtable
endprimitive
