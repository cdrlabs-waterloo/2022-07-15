`default_nettype none

/*
 * The inputs indexed with number two are inplicitly considered inverted.
 *  - To build an AND gate, connect previous outputs Z1/Z1 in the A1/B1 ports,
 *    output is Z1/Z2 as expected
 *  - To build an OR  gate, connect previous complemented outputs Z2/Z2 in
 *    the A1/B1 ports, swap the outputs Z1/Z2 as well
 */

module AN_XYZ_DLO(
  input wire CP,
  input wire A1,
  input wire A2,
  input wire B1,
  input wire B2,
  output wire Z1,
  output wire Z2);
  // Z=(A & B)
  AO_DLO_D0 ao1( .CP(CP),
    .A1(A1), .B1(B1), .Z1(Z1),
    .A2(A2), .B2(B2), .Z2(Z2));
endmodule

module OR_XYZ_DLO(
  input wire CP,
  input wire A1,
  input wire A2,
  input wire B1,
  input wire B2,
  output wire Z1,
  output wire Z2);

  // Z=(A | B)
  AO_DLO_D0 ao1(.CP(CP), // swapped to build OR gate
    .A1(A2), .B1(B2), .Z1(Z2),
    .A2(A1), .B2(B1), .Z2(Z1));
endmodule

module INV_XYZ_DLO(
  input wire A1,
  input wire A2,
  output wire Z1,
  output wire Z2);
  // Z = ~A
  assign Z1 = A2;
  assign Z2 = A1;
endmodule

module XOR_SHR_DLO(
  input  wire CP,
  input  wire A1_S0,
  input  wire A1_S1,
  input  wire A2_S0,
  input  wire A2_S1,
  output wire Z_S0,
  output wire Z_S1,
  input  wire A1_S0N,
  input  wire A1_S1N,
  input  wire A2_S0N,
  input  wire A2_S1N,
  output wire Z_S0N,
  output wire Z_S1N
);

  XOR_DLO_D0 xor0(.CP(CP),
                   .A1(A1_S0),  .B1(A2_S0),  .Z1(Z_S0),
                   .A2(A1_S0N),  .B2(A2_S0N),  .Z2(Z_S0N));

  XOR_DLO_D0 xor1(.CP(CP),
                   .A1(A1_S1),  .B1(A2_S1),  .Z1(Z_S1),
                   .A2(A1_S1N), .B2(A2_S1N), .Z2(Z_S1N));
endmodule

module INV_SHR_DLO(
  input   wire I_S0,
  input   wire I_S1,
  output wire ZN_S0,
  output wire ZN_S1,
  // complemented io
  input   wire I_S0N,
  input   wire I_S1N,
  output wire ZN_S0N,
  output wire ZN_S1N
);
  INV_XYZ_DLO inv1(
    .A1(I_S0),  .Z1(ZN_S0) ,
    .A2(I_S0N), .Z2(ZN_S0N));

  assign ZN_S1  = I_S1;
  assign ZN_S1N = I_S1N;
endmodule

// From: Biryukov2018
module AN_SHR_DLO(
  input wire CP,
  input wire A1_S0,
  input wire A1_S1,
  input wire A2_S0,
  input wire A2_S1,
  output wire Z_S0,
  output wire Z_S1,
  // complemented outputs
  input wire A1_S0N,
  input wire A1_S1N,
  input wire A2_S0N,
  input wire A2_S1N,
  output wire Z_S0N,
  output wire Z_S1N
);
  wire X1, X2, Y1, Y2;
  wire X1N, X2N, Y1N, Y2N;

  wire Y2C;
  wire Y2CN;

  wire X1_AN_Y1, X1_OR_Y2C;
  wire X1_AN_Y1N, X1_OR_Y2CN;

  wire X2_AN_Y1, X2_OR_Y2C;
  wire X2_AN_Y1N, X2_OR_Y2CN;

  assign X1 = A1_S0;
  assign X2 = A1_S1;
  assign Y1 = A2_S0;
  assign Y2 = A2_S1;

  assign X1N = A1_S0N;
  assign X2N = A1_S1N;
  assign Y1N = A2_S0N;
  assign Y2N = A2_S1N;

  INV_XYZ_DLO inv1(
    .A1(Y2),  .Z1(Y2C),
    .A2(Y2N), .Z2(Y2CN));

  // z1 = (x1 & y1) xor (x1 | ~y2)
  AN_XYZ_DLO  and1(.CP(CP),
                   .A1(X1),        .B1(Y1),         .Z1(X1_AN_Y1),
                   .A2(X1N),       .B2(Y1N),        .Z2(X1_AN_Y1N));

  OR_XYZ_DLO  or1 (.CP(CP),
                   .A1(X1),        .B1(Y2C),        .Z1(X1_OR_Y2C),
                   .A2(X1N),       .B2(Y2CN),       .Z2(X1_OR_Y2CN));

  XOR_DLO_D0 xor1(.CP(CP),
                   .A1(X1_AN_Y1),  .B1(X1_OR_Y2C),  .Z1(Z_S0),
                   .A2(X1_AN_Y1N), .B2(X1_OR_Y2CN), .Z2(Z_S0N));


  // z2 = (x2 & y1) xor (x2 | ~y2)
  AN_XYZ_DLO  and2(.CP(CP),
                   .A1(X2),        .B1(Y1),         .Z1(X2_AN_Y1),
                   .A2(X2N),       .B2(Y1N),        .Z2(X2_AN_Y1N));

  OR_XYZ_DLO  or2 (.CP(CP),
                   .A1(X2),        .B1(Y2C),        .Z1(X2_OR_Y2C),
                   .A2(X2N),       .B2(Y2CN),       .Z2(X2_OR_Y2CN));

  XOR_DLO_D0 xor2(.CP(CP),
                   .A1(X2_AN_Y1),  .B1(X2_OR_Y2C),  .Z1(Z_S1),
                   .A2(X2_AN_Y1N), .B2(X2_OR_Y2CN), .Z2(Z_S1N));


endmodule

// From: Biryukov2018
module OR_SHR_DLO(
  input wire CP,
  input wire A1_S0,
  input wire A1_S1,
  input wire A2_S0,
  input wire A2_S1,
  output wire Z_S0,
  output wire Z_S1,
  // complemented io
  input wire A1_S0N,
  input wire A1_S1N,
  input wire A2_S0N,
  input wire A2_S1N,
  output wire Z_S0N,
  output wire Z_S1N
);
  wire X1,  X2,  Y1,  Y2;
  wire X1N, X2N, Y1N, Y2N;

  wire X1_AN_Y1,  X1_OR_Y2;
  wire X1_AN_Y1N, X1_OR_Y2N;

  wire X2_OR_Y1,  X2_AN_Y2;
  wire X2_OR_Y1N, X2_AN_Y2N;

  assign X1 = A1_S0;
  assign X2 = A1_S1;
  assign Y1 = A2_S0;
  assign Y2 = A2_S1;

  assign X1N = A1_S0N;
  assign X2N = A1_S1N;
  assign Y1N = A2_S0N;
  assign Y2N = A2_S1N;

  // z1 = (x1 & y1) xor (x1 | y2)
  AN_XYZ_DLO  and1(.CP(CP),
                   .A1(X1),       .B1(Y1),       .Z1(X1_AN_Y1),
                   .A2(X1N),      .B2(Y1N),      .Z2(X1_AN_Y1N));

  OR_XYZ_DLO  or1 (.CP(CP),
                   .A1(X1),       .B1(Y2),       .Z1(X1_OR_Y2),
                   .A2(X1N),      .B2(Y2N),      .Z2(X1_OR_Y2N));

  XOR_DLO_D0 xor1(.CP(CP),
                   .A1(X1_AN_Y1),  .B1(X1_OR_Y2),  .Z1(Z_S0),
                   .A2(X1_AN_Y1N), .B2(X1_OR_Y2N), .Z2(Z_S0N));


  // z2 = (x2 | y1) xor (x2 & y2)
  OR_XYZ_DLO  or2 (.CP(CP),
                   .A1(X2),       .B1(Y1),       .Z1(X2_OR_Y1),
                   .A2(X2N),      .B2(Y1N),      .Z2(X2_OR_Y1N));

  AN_XYZ_DLO  and2(.CP(CP),
                   .A1(X2),       .B1(Y2),       .Z1(X2_AN_Y2),
                   .A2(X2N),      .B2(Y2N),      .Z2(X2_AN_Y2N));

  XOR_DLO_D0 xor2(.CP(CP),
                   .A1(X2_OR_Y1),  .B1(X2_AN_Y2),  .Z1(Z_S1),
                   .A2(X2_OR_Y1N), .B2(X2_AN_Y2N), .Z2(Z_S1N));

endmodule

module REG_SHR_DLO(
  input  wire CP,
  input  wire CDN,
  input  wire R,
  input  wire D_S0,
  input  wire D_S1,
  output wire Q_S0,
  output wire Q_S1,
  // complemented outputs
  input  wire D_S0N, // ignored
  input  wire D_S1N, // ignored
  output wire Q_S0N,
  output wire Q_S1N
);
  wire X_S0, X_S1;
  XOR2D0 xor1(.A1(D_S0), .A2(R), .Z(X_S0));
  XOR2D0 xor2(.A1(D_S1), .A2(R), .Z(X_S1));

  DFCND1 ff1(.CP(CP), .CDN(CDN), .D(X_S0), .Q(Q_S0), .QN(Q_S0N));
  DFCND1 ff2(.CP(CP), .CDN(CDN), .D(X_S1), .Q(Q_S1), .QN(Q_S1N));
endmodule

