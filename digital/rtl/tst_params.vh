
localparam TEST_LOGIC_RESET = 4'h0;
localparam RUN_TEST_IDLE    = 4'h1;
localparam SELECT_DR        = 4'h2;
localparam CAPTURE_DR       = 4'h3;
localparam SHIFT_DR         = 4'h4;
localparam EXIT1_DR         = 4'h5;
localparam PAUSE_DR         = 4'h6;
localparam EXIT2_DR         = 4'h7;
localparam UPDATE_DR        = 4'h8;
localparam SELECT_IR        = 4'h9;
localparam CAPTURE_IR       = 4'hA;
localparam SHIFT_IR         = 4'hB;
localparam EXIT1_IR         = 4'hC;
localparam PAUSE_IR         = 4'hD;
localparam EXIT2_IR         = 4'hE;
localparam UPDATE_IR        = 4'hF;

localparam RF_OP       = 4'd3;
localparam RAM_OP      = 4'd4;
localparam CLK_OP      = 4'd5;
localparam FLK_OP      = 4'd6;
localparam KEY_OP      = 4'd7;
localparam RNG_OP      = 4'd8;
localparam STA_OP      = 4'd9;
localparam IDCODE_OP   = 4'b1110; // 'd14
localparam BYPASS_OP   = 4'b1111; // 'd15

localparam IDCODE_LEN    = 32;
localparam BYPASS_LEN    = 1;
localparam RF_LEN        = 13;
localparam RAM_LEN       = 44;
localparam CLK_LEN       = 29;
localparam FLK_LEN       = 1;
localparam KEY_LEN       = 75;
localparam RNG_LEN       = 88;
localparam STA_LEN       = 5;

