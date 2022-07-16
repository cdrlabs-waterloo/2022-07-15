`default_nettype none

module XOR2_CMO(
  input wire A1_S0,
  input wire A1_S1,
  input wire A2_S0,
  input wire A2_S1,
  output wire Z_S0,
  output wire Z_S1
);
  XOR2D0 cmo_xor0(.A1(A1_S0), .A2(A2_S0), .Z(Z_S0));
  XOR2D0 cmo_xor1(.A1(A1_S1), .A2(A2_S1), .Z(Z_S1));
endmodule

module INV_CMO(
  input wire I_S0,
  input wire I_S1,
  output wire ZN_S0,
  output wire ZN_S1
);
  INVD0  cmo_inv0(.I(I_S0), .ZN(ZN_S0));
  BUFFD0 cmo_buf0(.I(I_S1), .Z(ZN_S1));
endmodule

// From: Biryukov2018
module AN2_CMO(
  input wire A1_S0,
  input wire A1_S1,
  input wire A2_S0,
  input wire A2_S1,
  output wire Z_S0,
  output wire Z_S1
);
  wire X1, X2, Y1, Y2;

  wire Y2N;
  wire X1_AN_Y1, X1_OR_Y2N;
  wire X2_AN_Y1, X2_OR_Y2N;

  assign X1 = A1_S0;
  assign X2 = A1_S1;
  assign Y1 = A2_S0;
  assign Y2 = A2_S1;

  INVD0  g0(.I(Y2), .ZN(Y2N));

  // z1 = (x1 & y1) xor (x1 | ~y2)
  AN2D0  cmo_and0(.A1(X1),       .A2(Y1),        .Z(X1_AN_Y1));
  OR2D0  cmo_or0(.A1(X1),       .A2(Y2N),       .Z(X1_OR_Y2N));
  XOR2D0 cmo_xor0(.A1(X1_AN_Y1), .A2(X1_OR_Y2N), .Z(Z_S0));

  // z2 = (x2 & y1) xor (x2 | ~y2)
  AN2D0  cmo_and1(.A1(X2),       .A2(Y1),        .Z(X2_AN_Y1));
  OR2D0  cmo_or1(.A1(X2),       .A2(Y2N),       .Z(X2_OR_Y2N));
  XOR2D0 cmo_xor1(.A1(X2_AN_Y1), .A2(X2_OR_Y2N), .Z(Z_S1));
endmodule

// From: Biryukov2018
module OR2_CMO(
  input wire A1_S0,
  input wire A1_S1,
  input wire A2_S0,
  input wire A2_S1,
  output wire Z_S0,
  output wire Z_S1
);
  wire X1, X2, Y1, Y2;
  wire X1_AN_Y1, X1_OR_Y2;
  wire X2_OR_Y1, X2_AN_Y2;

  assign X1 = A1_S0;
  assign X2 = A1_S1;
  assign Y1 = A2_S0;
  assign Y2 = A2_S1;

  // z1 = (x1 & y1) xor (x1 | y2)
  AN2D0  cmo_and0(.A1(X1),       .A2(Y1),       .Z(X1_AN_Y1));
  OR2D0  cmo_or0(.A1(X1),       .A2(Y2),       .Z(X1_OR_Y2));
  XOR2D0 cmo_xor0(.A1(X1_AN_Y1), .A2(X1_OR_Y2), .Z(Z_S0));

  // z2 = (x2 | y1) xor (x2 & y2)
  OR2D0  cmo_or1(.A1(X2),       .A2(Y1),       .Z(X2_OR_Y1));
  AN2D0  cmo_and1(.A1(X2),       .A2(Y2),       .Z(X2_AN_Y2));
  XOR2D0 cmo_xor1(.A1(X2_OR_Y1), .A2(X2_AN_Y2), .Z(Z_S1));
endmodule

module DFCNQ_CMO(
  input wire CP,
  input wire CDN,
  input wire D_S0,
  input wire D_S1,
  input wire R,
  output wire Q_S0,
  output wire Q_S1
);
  wire X_S0, X_S1;
  XOR2D0 cmo_r0(.A1(D_S0), .A2(R), .Z(X_S0));
  XOR2D0 cmo_r1(.A1(D_S1), .A2(R), .Z(X_S1));

  DFCNQD1 cmo_flop0(.CP(CP), .CDN(CDN), .D(X_S0), .Q(Q_S0));
  DFCNQD1 cmo_flop1(.CP(CP), .CDN(CDN), .D(X_S1), .Q(Q_S1));
endmodule

