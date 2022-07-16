`default_nettype none

module serv_bufreg
  (
   input wire         clk,
   input wire         rst_n,
   input wire         i_cnt0,
   input wire         i_cnt1,
   input wire         i_en,
   input wire         i_init,
   input wire         i_rs1,
   input wire         i_rs1_en,
   input wire         i_imm,
   input wire         i_imm_en,
   input wire         i_clr_lsb,
   output reg [1:0]   o_lsb,
   output wire [31:0] o_dbus_adr,
   output wire        o_q);

   wire               c, q;
   reg                c_r;
   reg [31:0]         data;

   wire               clr_lsb = i_cnt0 & i_clr_lsb;

   assign {c,q} = {1'b0,(i_rs1 & i_rs1_en)} + {1'b0,(i_imm & i_imm_en & !clr_lsb)} + c_r;

   always @(posedge clk or negedge rst_n) begin
     if (!rst_n) begin
       c_r <= 1'b0;
       data <= 32'b0;
       o_lsb <= 2'b0;
     end else begin
       //Make sure carry is cleared before loading new data
       c_r <= c & i_en;

       if (i_en)
         data <= {i_init ? q : o_q, data[31:1]};

       if (i_cnt0 & i_init)
         o_lsb[0] <= q;
       if (i_cnt1 & i_init)
         o_lsb[1] <= q;
     end
   end

   assign o_q = data[0];
   assign o_dbus_adr = {data[31:2], 2'b00};

endmodule

module serv_shift
  (
   input wire       clk,
   input wire       rst_n,
   input wire       i_load,
   input wire [4:0] i_shamt,
   input wire       i_shamt_msb,
   input wire       i_signbit,
   input wire       i_right,
   output wire      o_done,
   input wire       i_d,
   output wire      o_q);

   reg              signbit;
   reg [5:0]        cnt;
   reg              wrapped;

   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        signbit <= 0;
        cnt <= 6'b0;
        wrapped <= 1'b0;
      end else begin
        cnt <= cnt + 6'd1;
        if (i_load) begin
           cnt <= 6'd0;
           signbit <= i_signbit & i_right;
        end
        wrapped <= cnt[5] | (i_shamt_msb & !i_right);
      end
   end

   assign o_done = (cnt[4:0] == i_shamt);
   assign o_q = (i_right^wrapped) ? i_d : signbit;

endmodule

module serv_decode
  (
   input wire        clk,
   input wire        rst_n,
   //Input
   input wire [31:0] i_wb_rdt, // originally [31:2]
   input wire        i_wb_en,
   //To state
   output wire       o_bne_or_bge,
   output wire       o_cond_branch,
   output wire       o_e_op,
   output wire       o_ebreak,
   output wire       o_branch_op,
   output wire       o_mem_op,
   output wire       o_shift_op,
   output wire       o_slt_op,
   output wire       o_rd_op,
   //To bufreg
   output wire       o_bufreg_rs1_en,
   output wire       o_bufreg_imm_en,
   output wire       o_bufreg_clr_lsb,
   //To ctrl
   output wire       o_ctrl_jal_or_jalr,
   output wire       o_ctrl_utype,
   output wire       o_ctrl_pc_rel,
   output wire       o_ctrl_mret,
   //To alu
   output wire       o_alu_sub,
   output wire [1:0] o_alu_bool_op,
   output wire       o_alu_cmp_eq,
   output wire       o_alu_cmp_sig,
   output wire       o_alu_sh_signed,
   output wire       o_alu_sh_right,
   output wire [3:0] o_alu_rd_sel,
   //To mem IF
   output wire       o_mem_signed,
   output wire       o_mem_word,
   output wire       o_mem_half,
   output wire       o_mem_cmd,
   //To CSR
   output wire       o_csr_en,
   output wire [1:0] o_csr_addr,
   output wire       o_csr_mstatus_en,
   output wire       o_csr_mie_en,
   output wire       o_csr_mcause_en,
   output wire [1:0] o_csr_source,
   output wire       o_csr_d_sel,
   output wire       o_csr_imm_en,
   //To top
   output wire [3:0] o_immdec_ctrl,
   output wire       o_op_b_source,
   output wire       o_rd_csr_en,
   output wire       o_rd_alu_en);

`include "serv_params.vh"

   reg [4:0] opcode;
   reg [2:0] funct3;
   reg        op20;
   reg        op21;
   reg        op22;
   reg        op26;

   reg       imm30;

   //opcode
   wire      op_or_opimm = (!opcode[4] & opcode[2] & !opcode[0]);

   assign o_mem_op   = !opcode[4] & !opcode[2] & !opcode[0];
   assign o_branch_op = opcode[4] & !opcode[2];

   //jal,branch =     imm
   //jalr       = rs1+imm
   //mem        = rs1+imm
   //shift      = rs1
   assign o_bufreg_rs1_en = !opcode[4] | (!opcode[1] & opcode[0]);
   assign o_bufreg_imm_en = !opcode[2];

   //Clear LSB of immediate for BRANCH and JAL ops
   //True for BRANCH and JAL
   //False for JALR/LOAD/STORE/OP/OPIMM?
   assign o_bufreg_clr_lsb = opcode[4] & ((opcode[1:0] == 2'b00) | (opcode[1:0] == 2'b11));

   //Conditional branch
   //True for BRANCH
   //False for JAL/JALR
   assign o_cond_branch = !opcode[0];

   assign o_ctrl_utype       = !opcode[4] & opcode[2] & opcode[0];
   assign o_ctrl_jal_or_jalr = opcode[4] & opcode[0];

   //PC-relative operations
   //True for jal, b* auipc
   //False for jalr, lui
   assign o_ctrl_pc_rel = (opcode[2:0] == 3'b000) |
                          (opcode[1:0] == 2'b11) |
                          (opcode[4:3] == 2'b00);
   //Write to RD
   //True for OP-IMM, AUIPC, OP, LUI, SYSTEM, JALR, JAL, LOAD
   //False for STORE, BRANCH, MISC-MEM
   assign o_rd_op = (opcode[2] |
                     (!opcode[2] & opcode[4] & opcode[0]) |
                     (!opcode[2] & !opcode[3] & !opcode[0]));

   //
   //funct3
   //

   assign o_bne_or_bge = funct3[0];
   
   //
   // opcode & funct3
   //

   assign o_shift_op = op_or_opimm & (funct3[1:0] == 2'b01);
   assign o_slt_op   = op_or_opimm & (funct3[2:1] == 2'b01);

   //Matches system ops except eceall/ebreak/mret
   wire csr_op = opcode[4] & opcode[2] & (|funct3);


   //op20
   assign o_ebreak = op20;


   //opcode & funct3 & op21

   assign o_ctrl_mret = opcode[4] & opcode[2] & op21 & !(|funct3);
   //Matches system opcodes except CSR accesses (funct3 == 0)
   //and mret (!op21)
   assign o_e_op = opcode[4] & opcode[2] & !op21 & !(|funct3);

   //opcode & funct3 & imm30
   //True for sub, sll*, b*, slt*
   //False for add*, sr*
   assign o_alu_sub = (!funct3[2] & (funct3[0] | (opcode[3] & imm30))) | funct3[1] | opcode[4];


   /*
    Bits 26, 22, 21 and 20 are enough to uniquely identify the eight supported CSR regs
    mtvec, mscratch, mepc and mtval are stored externally (normally in the RF) and are
    treated differently from mstatus, mie, mcause and mip which are stored in serv_csr.
    
    The former get a 2-bit address (as found in serv_params.vh) while the latter get a
    one-hot enable signal each.
    
    Hex|2 222|Reg
    adr|6 210|name
    ---|-----|-------
    300|0_000|mstatus
    304|0_100|mie
    305|0_101|mtvec
    340|1_000|mscratch
    341|1_001|mepc
    342|1_010|mcause
    343|1_011|mtval
    344|1_100|mip
    
    */

   //true  for mtvec,mscratch,mepc and mtval
   //false for mstatus, mie, mcause, mip
   wire csr_valid = op20 | (op26 & !op22 & !op21);

   assign o_rd_csr_en = csr_op;

   assign o_csr_en         = csr_op & csr_valid;
   assign o_csr_mstatus_en = csr_op & !op26 & !op22;
   assign o_csr_mie_en     = csr_op & !op26 &  op22 & !op20;
   assign o_csr_mcause_en  = csr_op         &  op21 & !op20;

   assign o_csr_source = funct3[1:0];
   assign o_csr_d_sel = funct3[2];
   assign o_csr_imm_en = opcode[4] & opcode[2] & funct3[2];

   assign o_csr_addr = (op26 & !op20) ? CSR_MSCRATCH :
                       (op26 & !op21) ? CSR_MEPC :
                       (op26)         ? CSR_MTVAL :
                       CSR_MTVEC;

   assign o_alu_cmp_eq = funct3[2:1] == 2'b00;

   assign o_alu_cmp_sig = ~((funct3[0] & funct3[1]) | (funct3[1] & funct3[2]));
   assign o_alu_sh_signed = imm30;
   assign o_alu_sh_right = funct3[2];

   assign o_mem_cmd  = opcode[3];
   assign o_mem_signed = ~funct3[2];
   assign o_mem_word   = funct3[1];
   assign o_mem_half   = funct3[0];

   assign o_alu_bool_op = funct3[1:0];

   //True for S (STORE) or B (BRANCH) type instructions
   //False for J type instructions
   assign o_immdec_ctrl[0] = opcode[3:0] == 4'b1000;
   //True for OP-IMM, LOAD, STORE, JALR  (I S)
   //False for LUI, AUIPC, JAL           (U J) 
   assign o_immdec_ctrl[1] = (opcode[1:0] == 2'b00) | (opcode[2:1] == 2'b00);
   assign o_immdec_ctrl[2] = opcode[4] & !opcode[0];
   assign o_immdec_ctrl[3] = opcode[4];

   assign o_alu_rd_sel[0] = (funct3 == 3'b000); // Add/sub
   assign o_alu_rd_sel[1] = (funct3[1:0] == 2'b01); //Shift
   assign o_alu_rd_sel[2] = (funct3[2:1] == 2'b01); //SLT*
   assign o_alu_rd_sel[3] = (funct3[2] & !(funct3[1:0] == 2'b01)); //Bool
   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        funct3 <= 3'b0;
        imm30  <= 1'b0;
        opcode <= 5'b0;
        op20   <= 1'b0;
        op21   <= 1'b0;
        op22   <= 1'b0;
        op26   <= 1'b0;
      end else begin
        if (i_wb_en) begin
           funct3        <= i_wb_rdt[14:12];
           imm30         <= i_wb_rdt[30];
           opcode        <= i_wb_rdt[6:2];
           op20 <= i_wb_rdt[20];
           op21 <= i_wb_rdt[21];
           op22 <= i_wb_rdt[22];
           op26 <= i_wb_rdt[26];
        end
      end
   end

   //0 (OP_B_SOURCE_IMM) when OPIMM
   //1 (OP_B_SOURCE_RS2) when BRANCH or OP
   assign o_op_b_source = opcode[3];

   assign o_rd_alu_en  = !opcode[0] & opcode[2] & !opcode[4];


endmodule

module serv_immdec
  (
   input wire        clk,
   input wire        rst_n,
   //State
   input wire        i_cnt_en,
   input wire        i_cnt_done,
   //Control
   input wire        i_csr_imm_en,
   input wire [3:0]  i_ctrl,
   output wire [4:0] o_rd_addr,
   output wire [4:0] o_rs1_addr,
   output wire [4:0] o_rs2_addr,
   //Data
   output wire       o_csr_imm,
   output wire       o_imm,
   //External
   input wire        i_wb_en,
   input wire [31:0] i_wb_rdt); // originally [31:7] 

   reg        signbit;

   reg [8:0]  imm19_12_20;
   reg        imm7;
   reg [5:0]  imm30_25;
   reg [4:0]  imm24_20;
   reg [4:0]  imm11_7;

   reg [4:0]  rd_addr;
   reg [4:0]  rs1_addr;
   reg [4:0]  rs2_addr;

   assign o_rd_addr  = rd_addr;
   assign o_rs1_addr = rs1_addr;
   assign o_rs2_addr = rs2_addr;

   assign o_imm = i_cnt_done ? signbit : i_ctrl[0] ? imm11_7[0] : imm24_20[0];
   assign o_csr_imm = imm19_12_20[4];

   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        signbit <= 1'b0;

        imm19_12_20 <= 9'b0;
        imm7 <= 1'b0;
        imm30_25 <= 6'b0;
        imm24_20 <= 5'b0;
        imm11_7 <= 5'b0;
                  
        rd_addr <= 5'b0;
        rs1_addr <= 5'b0;
        rs2_addr <= 5'b0;
      end else begin
        if (i_wb_en) begin
           /* CSR immediates are always zero-extended, hence clear the signbit */
           signbit     <= i_wb_rdt[31] & !i_csr_imm_en;
           imm19_12_20 <= {i_wb_rdt[19:12],i_wb_rdt[20]};
           imm7        <= i_wb_rdt[7];
           imm30_25    <= i_wb_rdt[30:25];
           imm24_20    <= i_wb_rdt[24:20];
           imm11_7     <= i_wb_rdt[11:7];

           rd_addr  <= i_wb_rdt[11:7];
           rs1_addr <= i_wb_rdt[19:15];
           rs2_addr <= i_wb_rdt[24:20];
        end
        if (i_cnt_en) begin
           imm19_12_20 <= {i_ctrl[3] ? signbit : imm24_20[0], imm19_12_20[8:1]};
           imm7        <= signbit;
           imm30_25    <= {i_ctrl[2] ? imm7 : i_ctrl[1] ? signbit : imm19_12_20[0], imm30_25[5:1]};
           imm24_20    <= {imm30_25[0], imm24_20[4:1]};
           imm11_7     <= {imm30_25[0], imm11_7[4:1]};
        end
      end
   end
endmodule

module serv_alu
  (
   input wire       clk,
   input wire       rst_n,
   input wire       i_en,
   input wire       i_shift_op,
   input wire       i_cnt0,
   input wire       i_rs1,
   input wire       i_rs2,
   input wire       i_imm,
   input wire       i_op_b_rs2,
   input wire       i_buf,
   input wire       i_cnt_done,
   input wire       i_sub,
   input wire [1:0] i_bool_op,
   input wire       i_cmp_eq,
   input wire       i_cmp_sig,
   output wire      o_cmp,
   input wire       i_shamt_en,
   input wire       i_sh_right,
   input wire       i_sh_signed,
   output wire      o_sh_done,
   input wire [3:0] i_rd_sel,
   output wire      o_rd);

   wire        result_add;
   wire        result_eq;
   wire        result_sh;

   reg         result_lt_r;

   reg [4:0]   shamt;
   reg         shamt_msb;

   wire        add_cy;
   reg         add_cy_r;

   wire op_b = i_op_b_rs2 ? i_rs2 : i_imm;

   serv_shift shift
     (
      .clk (clk),
      .rst_n (rst_n),
      .i_load (i_cnt_done),
      .i_shamt (shamt),
      .i_shamt_msb (shamt_msb),
      .i_signbit (i_sh_signed & i_rs1),
      .i_right  (i_sh_right),
      .o_done   (o_sh_done),
      .i_d (i_buf),
      .o_q (result_sh));

   //Sign-extended operands
   wire rs1_sx  = i_rs1 & i_cmp_sig;
   wire op_b_sx = op_b  & i_cmp_sig;

   wire result_lt = rs1_sx + ~op_b_sx + add_cy;

   wire add_a = i_rs1 & ~i_shift_op;
   wire add_b = op_b^i_sub;

   assign {add_cy,result_add}   = add_a+add_b+add_cy_r;

   reg        eq_r;

   assign result_eq = !result_add & eq_r;

   assign o_cmp = i_cmp_eq ? result_eq : result_lt;

   localparam [15:0] BOOL_LUT = 16'h8E96;//And, Or, =, xor
   wire result_bool = BOOL_LUT[{i_bool_op, i_rs1, op_b}];

   assign o_rd = (i_rd_sel[0] & result_add) |
                 (i_rd_sel[1] & result_sh) |
                 (i_rd_sel[2] & result_lt_r & i_cnt0) |
                 (i_rd_sel[3] & result_bool);


   always @(posedge clk or negedge rst_n) begin
     if (!rst_n) begin
       add_cy_r    <= 1'b0;
       result_lt_r <= 1'b0;
       eq_r        <= 1'b0;
       shamt_msb   <= 1'b0;
       shamt       <= 5'b0;
     end else begin
       add_cy_r <= i_en ? add_cy : i_sub;

       if (i_en) begin
          result_lt_r <= result_lt;
       end
       eq_r <= result_eq | ~i_en;

       if (i_shamt_en) begin
          shamt_msb <= add_cy;
          shamt <= {result_add,shamt[4:1]};
       end
     end
   end

endmodule

module serv_csr
  (
   input wire       clk,
   input wire       rst_n,
   //State
   input wire       i_en,
   input wire       i_cnt0to3,
   input wire       i_cnt3,
   input wire       i_cnt7,
   input wire       i_cnt_done,
   input wire       i_mem_misalign,
   input wire       i_mtip,
   input wire       i_trap_taken,
   input wire       i_pending_irq,
   output wire      o_new_irq,
   //Control
   input wire       i_e_op,
   input wire       i_ebreak,
   input wire       i_mem_cmd,
   input wire       i_mstatus_en,
   input wire       i_mie_en,
   input wire       i_mcause_en,
   input wire [1:0] i_csr_source,
   input wire       i_mret,
   input wire       i_csr_d_sel,
   //Data
   input wire       i_rf_csr_out,
   output wire      o_csr_in,
   input wire       i_csr_imm,
   input wire       i_rs1,
   output wire      o_q);

   localparam [1:0]
     CSR_SOURCE_CSR = 2'b00,
     CSR_SOURCE_EXT = 2'b01,
     CSR_SOURCE_SET = 2'b10,
     CSR_SOURCE_CLR = 2'b11;

   reg              mstatus_mie;
   reg              mstatus_mpie;
   reg              mie_mtie;

   reg          mcause31;
   reg [3:0]    mcause3_0;
   wire         mcause;

   wire         csr_in;
   wire         csr_out;

   reg          timer_irq_r;

   wire         d = i_csr_d_sel ? i_csr_imm : i_rs1;

   assign csr_in = (i_csr_source == CSR_SOURCE_EXT) ? d :
                   (i_csr_source == CSR_SOURCE_SET) ? csr_out | d :
                   (i_csr_source == CSR_SOURCE_CLR) ? csr_out & ~d :
                   (i_csr_source == CSR_SOURCE_CSR) ? csr_out :
                   1'bx;

   assign csr_out = (i_mstatus_en & mstatus_mie & i_cnt3) |
                    i_rf_csr_out |
                    (i_mcause_en & i_en & mcause);

   assign o_q = csr_out;

   wire         timer_irq = i_mtip & mstatus_mie & mie_mtie;

   assign mcause = i_cnt0to3 ? mcause3_0[0] : //[3:0]
                   i_cnt_done ? mcause31 //[31]
                   : 1'b0;

   assign o_csr_in = csr_in;

   assign o_new_irq = !timer_irq_r & timer_irq;


   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        mstatus_mie <= 1'b0;
        mstatus_mpie <= 1'b0;
        mie_mtie <= 1'b0;
        mcause31 <= 1'b0;
        mcause3_0 <= 4'b0;
        timer_irq_r <= 1'b0;
      end else begin
        if (i_mie_en & i_cnt7)
          mie_mtie <= csr_in;

        timer_irq_r <= timer_irq;

        /*
         The mie bit in mstatus gets updated under three conditions

         When a trap is taken, the bit is cleared
         During an mret instruction, the bit is restored from mpie
         During a mstatus CSR access instruction it's assigned when
          bit 3 gets updated

         These conditions are all mutually exclusibe
         */
        if (i_trap_taken | i_mstatus_en & i_cnt3 | i_mret)
          mstatus_mie <= !i_trap_taken & (i_mret ?  mstatus_mpie : csr_in);

        /*
         Note: To save resources mstatus_mpie (mstatus bit 7) is not
         readable or writable from sw
         */
        if (i_trap_taken)
          mstatus_mpie <= mstatus_mie;

        /*
         The four lowest bits in mcause hold the exception code

         These bits get updated under three conditions

         During an mcause CSR access function, they are assigned when
         bits 0 to 3 gets updated

         During an external interrupt the exception code is set to
         7, since SERV only support timer interrupts

         During an exception, the exception code is assigned to indicate
         if it was caused by an ebreak instruction (3),
         ecall instruction (11), misaligned load (4), misaligned store (6)
         or misaligned jump (0)
         */
        if (i_mcause_en & i_en & i_cnt0to3 | i_trap_taken)
          mcause3_0 <= !i_trap_taken ? {csr_in, mcause3_0[3:1]} :
                       i_pending_irq ? 4'd7 :
                       i_e_op ? {!i_ebreak, 3'b011} :
                       i_mem_misalign ? {2'b01, i_mem_cmd, 1'b0} :
                       4'd0;

        if (i_mcause_en & i_cnt_done | i_trap_taken)
          mcause31 <= i_trap_taken ? i_pending_irq : csr_in;
      end
   end

endmodule

module serv_ctrl
  #(parameter RESET_PC = 32'd0,
    parameter WITH_CSR = 1)
  (
   input wire        clk,
   input wire        rst_n,
   //State
   input wire        i_pc_en,
   input wire        i_cnt12to31,
   input wire        i_cnt0,
   input wire        i_cnt2,
   input wire        i_cnt_done,
   //Control
   input wire        i_jump,
   input wire        i_jal_or_jalr,
   input wire        i_utype,
   input wire        i_pc_rel,
   input wire        i_trap,
   //Data
   input wire        i_imm,
   input wire        i_buf,
   input wire        i_csr_pc,
   output wire       o_rd,
   output wire       o_bad_pc,
   //External
   output reg [31:0] o_ibus_adr);

   wire       pc_plus_4;
   wire       pc_plus_4_cy;
   reg        pc_plus_4_cy_r;
   wire       pc_plus_offset;
   wire       pc_plus_offset_cy;
   reg        pc_plus_offset_cy_r;
   wire       pc_plus_offset_aligned;
   wire       plus_4;

   wire       pc = o_ibus_adr[0];

   wire       new_pc;

   wire       offset_a;
   wire       offset_b;

   assign plus_4        = i_cnt2;

   assign o_bad_pc = pc_plus_offset_aligned;

   assign {pc_plus_4_cy,pc_plus_4} = pc+plus_4+pc_plus_4_cy_r;

   generate
      if (WITH_CSR)
        assign new_pc = i_trap ? (i_csr_pc & !i_cnt0) : i_jump ? pc_plus_offset_aligned : pc_plus_4;
      else
        assign new_pc = i_jump ? pc_plus_offset_aligned : pc_plus_4;
   endgenerate
   assign o_rd  = (i_utype & pc_plus_offset_aligned) | (pc_plus_4 & i_jal_or_jalr);

   assign offset_a = i_pc_rel & pc;
   assign offset_b = i_utype ? (i_imm & i_cnt12to31): i_buf;
   assign {pc_plus_offset_cy,pc_plus_offset} = offset_a+offset_b+pc_plus_offset_cy_r;

   assign pc_plus_offset_aligned = pc_plus_offset & !i_cnt0;


   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        o_ibus_adr <= RESET_PC;
        pc_plus_4_cy_r <= 1'b0;
        pc_plus_offset_cy_r <= 1'b0;
      end else begin
        pc_plus_4_cy_r <= i_pc_en & pc_plus_4_cy;
        pc_plus_offset_cy_r <= i_pc_en & pc_plus_offset_cy;

        if (i_pc_en)
          o_ibus_adr <= {new_pc, o_ibus_adr[31:1]};
      end
   end
endmodule
module serv_state
  #(parameter [0:0] WITH_CSR = 1)
  (
   input wire        clk,
   input wire        rst_n,
   input wire        i_new_irq,
   output wire       o_trap_taken,
   output wire        o_pending_irq,
   input wire        i_dbus_ack,
   output wire       o_ibus_cyc,
   input wire        i_ibus_ack,
   output wire       o_rf_rreq,
   output wire       o_rf_wreq,
   input wire        i_rf_ready,
   output wire       o_rf_rd_en,
   input wire        i_cond_branch,
   input wire        i_bne_or_bge,
   input wire        i_alu_cmp,
   input wire        i_branch_op,
   input wire        i_mem_op,
   input wire        i_shift_op,
   input wire        i_slt_op,
   input wire        i_e_op,
   input wire        i_rd_op,
   output wire       o_init,
   output wire       o_cnt_en,
   output wire       o_cnt0,
   output wire       o_cnt0to3,
   output wire       o_cnt12to31,
   output wire       o_cnt1,
   output wire       o_cnt2,
   output wire       o_cnt3,
   output wire       o_cnt7,
   output wire       o_ctrl_pc_en,
   output reg        o_ctrl_jump,
   output wire       o_ctrl_trap,
   input wire        i_ctrl_misalign,
   output wire       o_alu_shamt_en,
   input wire        i_alu_sh_done,
   output wire       o_dbus_cyc,
   output wire [1:0] o_mem_bytecnt,
   input wire        i_mem_misalign,
   output reg        o_cnt_done,
   output wire       o_bufreg_en);

   wire              cnt4;

   reg  stage_two_req;

   reg [4:2] o_cnt;
   reg [3:0] o_cnt_r;

   reg       ibus_cyc;
   reg       first_inst_n;
   reg       init_done;
   //Update PC in RUN or TRAP states
   assign o_ctrl_pc_en  = o_cnt_en & !o_init;

   assign o_cnt_en = |o_cnt_r;

   assign o_mem_bytecnt = o_cnt[4:3];

   assign o_cnt0to3   = (o_cnt[4:2] == 3'd0);
   assign o_cnt12to31 = (o_cnt[4] | (o_cnt[3:2] == 2'b11));
   assign o_cnt0 = (o_cnt[4:2] == 3'd0) & o_cnt_r[0];
   assign o_cnt1 = (o_cnt[4:2] == 3'd0) & o_cnt_r[1];
   assign o_cnt2 = (o_cnt[4:2] == 3'd0) & o_cnt_r[2];
   assign o_cnt3 = (o_cnt[4:2] == 3'd0) & o_cnt_r[3];
   assign cnt4   = (o_cnt[4:2] == 3'd1) & o_cnt_r[0];
   assign o_cnt7 = (o_cnt[4:2] == 3'd1) & o_cnt_r[3];
   
   assign o_alu_shamt_en = (o_cnt0to3 | cnt4) & o_init;

   //Take branch for jump or branch instructions (opcode == 1x0xx) if
   //a) It's an unconditional branch (opcode[0] == 1)
   //b) It's a conditional branch (opcode[0] == 0) of type beq,blt,bltu (funct3[0] == 0) and ALU compare is true
   //c) It's a conditional branch (opcode[0] == 0) of type bne,bge,bgeu (funct3[0] == 1) and ALU compare is false
   //Only valid during the last cycle of INIT, when the branch condition has
   //been calculated.
   wire      take_branch = i_branch_op & (!i_cond_branch | (i_alu_cmp^i_bne_or_bge));

   //slt*, branch/jump, shift, load/store
   wire two_stage_op = i_slt_op | i_mem_op | i_branch_op | i_shift_op;

   assign o_dbus_cyc = !o_cnt_en & init_done & i_mem_op & !i_mem_misalign;

   wire trap_pending = 1'b0;

   //Prepare RF for reads when a new instruction is fetched
   // or when stage one caused an exception (rreq implies a write request too)
   assign o_rf_rreq = i_ibus_ack | (stage_two_req & trap_pending);

   //Prepare RF for writes when everything is ready to enter stage two
   assign o_rf_wreq = ((i_shift_op & i_alu_sh_done & init_done) | (i_mem_op & i_dbus_ack) | (stage_two_req & (i_slt_op | i_branch_op))) & !trap_pending;

   assign o_rf_rd_en = i_rd_op & o_cnt_en & !o_init;

   //Shift operations require bufreg to hold for one cycle between INIT and RUN before shifting
   assign o_bufreg_en = o_cnt_en | (!stage_two_req & i_shift_op);

   assign o_ibus_cyc = ibus_cyc;

   assign o_init = two_stage_op & !o_pending_irq & !init_done;

   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        o_cnt            <= 3'd0;
        o_cnt_r          <= 4'b0;
        o_cnt_done       <= 1'b0;
        init_done        <= 1'b0;
        o_ctrl_jump      <= 1'b0;
        ibus_cyc         <= 1'b0;
        first_inst_n     <= 1'b0;
        stage_two_req    <= 1'b0;
      end else begin
        //ibus_cyc changes on three conditions.
        //1. o_ibus_cyc will be asserted as soon as the reset is released.
        //   This is how the first instruction is fetched
        //2. o_cnt_done and o_ctrl_pc_en are asserted. This means that SERV just
        //   finished updating the PC, is done with the current instruction and
        //   o_ibus_cyc gets asserted to fetch a new instruction
        //3. When i_ibus_ack, a new instruction is fetched and o_ibus_cyc gets
        //   deasserted to finish the transaction
        if (i_ibus_ack | o_cnt_done)
          ibus_cyc <= o_ctrl_pc_en;

        first_inst_n <= 1'b1;
        if (~first_inst_n)
          ibus_cyc <= 1'b1;

        if (o_cnt_done) begin
           init_done <= o_init & !init_done;
           o_ctrl_jump <= o_init & take_branch;
        end
        o_cnt_done <= (o_cnt[4:2] == 3'b111) & o_cnt_r[2];

        //Need a strobe for the first cycle in the IDLE state after INIT
        stage_two_req <= o_cnt_done & o_init;

        /*
         Because SERV is 32-bit bit-serial we need a counter than can count 0-31
         to keep track of which bit we are currently processing. o_cnt and o_cnt_r
         are used together to create such a counter.
         The top three bits (o_cnt) are implemented as a normal counter, but
         instead of the two LSB, o_cnt_r is a 4-bit shift register which loops 0-3
         When o_cnt_r[3] is 1, o_cnt will be increased.

         The counting starts when the core is idle and the i_rf_ready signal
         comes in from the RF module by shifting in the i_rf_ready bit as LSB of
         the shift register. Counting is stopped by using o_cnt_done to block the
         bit that was supposed to be shifted into bit 0 of o_cnt_r.

         There are two benefit of doing the counter this way
         1. We only need to check four bits instead of five when we want to check
         if the counter is at a certain value. For 4-LUT architectures this means
         we only need one LUT instead of two for each comparison.
         2. We don't need a separate enable signal to turn on and off the counter
         between stages, which saves an extra FF and a unique control signal. We
         just need to check if o_cnt_r is not zero to see if the counter is
         currently running
         */
        o_cnt <= o_cnt + {2'd0,o_cnt_r[3]};
        o_cnt_r <= {o_cnt_r[2:0],(o_cnt_r[3] & !o_cnt_done) | (i_rf_ready & !o_cnt_en)};
      end
   end
   assign o_trap_taken = 0;
   assign o_ctrl_trap = 0;
   assign o_pending_irq = 1'b0;
endmodule

module serv_top
  #(parameter WITH_CSR = 1,
    parameter RESET_PC = 32'd0)
   (
   input wire                 clk,
   input wire                 rst_n,
   input wire                 i_timer_irq,
`ifdef RISCV_FORMAL
   output reg                 rvfi_valid = 1'b0,
   output reg [63:0]          rvfi_order = 64'd0,
   output reg [31:0]          rvfi_insn = 32'd0,
   output reg                 rvfi_trap = 1'b0,
   output reg                 rvfi_halt = 1'b0,
   output reg                 rvfi_intr = 1'b0,
   output reg [1:0]           rvfi_mode = 2'b11,
   output reg [1:0]           rvfi_ixl = 2'b01,
   output reg [4:0]           rvfi_rs1_addr,
   output reg [4:0]           rvfi_rs2_addr,
   output reg [31:0]          rvfi_rs1_rdata,
   output reg [31:0]          rvfi_rs2_rdata,
   output reg [4:0]           rvfi_rd_addr,
   output reg [31:0]          rvfi_rd_wdata,
   output reg [31:0]          rvfi_pc_rdata,
   output reg [31:0]          rvfi_pc_wdata,
   output reg [31:0]          rvfi_mem_addr,
   output reg [3:0]           rvfi_mem_rmask,
   output reg [3:0]           rvfi_mem_wmask,
   output reg [31:0]          rvfi_mem_rdata,
   output reg [31:0]          rvfi_mem_wdata,
`endif
   //RF Interface
   output wire                o_rf_rreq,
   output wire                o_rf_wreq,
   input wire                 i_rf_ready,
   output wire [4+WITH_CSR:0] o_wreg0,
   output wire [4+WITH_CSR:0] o_wreg1,
   output wire                o_wen0,
   output wire                o_wen1,
   output wire                o_wdata0,
   output wire                o_wdata1,
   output wire [4+WITH_CSR:0] o_rreg0,
   output wire [4+WITH_CSR:0] o_rreg1,
   input wire                 i_rdata0,
   input wire                 i_rdata1,

   output wire [31:0]         o_ibus_adr,
   output wire                o_ibus_cyc,
   input wire [31:0]          i_ibus_rdt,
   input wire                 i_ibus_ack,
   output wire [31:0]         o_dbus_adr,
   output wire [31:0]         o_dbus_dat,
   output wire [3:0]          o_dbus_sel,
   output wire                o_dbus_we ,
   output wire                o_dbus_cyc,
   input wire [31:0]          i_dbus_rdt,
   input wire                 i_dbus_ack);

   wire [4:0]    rd_addr;
   wire [4:0]    rs1_addr;
   wire [4:0]    rs2_addr;

   wire [3:0]    immdec_ctrl;

   wire          bne_or_bge;
   wire          cond_branch;
   wire          e_op;
   wire          ebreak;
   wire          branch_op;
   wire          mem_op;
   wire          shift_op;
   wire          slt_op;
   wire          rd_op;

   wire          rd_alu_en;
   wire          rd_csr_en;
   wire          ctrl_rd;
   wire          alu_rd;
   wire          mem_rd;
   wire          csr_rd;

   wire          ctrl_pc_en;
   wire          jump;
   wire          jal_or_jalr;
   wire          utype;
   wire          mret;
   wire          imm;
   wire          trap;
   wire          pc_rel;

   wire          init;
   wire          cnt_en;
   wire          cnt0to3;
   wire          cnt12to31;
   wire          cnt0;
   wire          cnt1;
   wire          cnt2;
   wire          cnt3;
   wire          cnt7;

   wire          cnt_done;

   wire          bufreg_en;
   wire          bufreg_rs1_en;
   wire          bufreg_imm_en;
   wire          bufreg_clr_lsb;
   wire          bufreg_q;

   wire          alu_sub;
   wire [1:0]    alu_bool_op;
   wire          alu_cmp_eq;
   wire          alu_cmp_sig;
   wire          alu_cmp;
   wire          alu_shamt_en;
   wire          alu_sh_signed;
   wire          alu_sh_right;
   wire          alu_sh_done;
   wire [3:0]    alu_rd_sel;

   wire          rs1;
   wire          rs2;
   wire          rd_en;

   wire          op_b_source;

   wire          mem_signed;
   wire          mem_word;
   wire          mem_half;
   wire [1:0]    mem_bytecnt;

   wire          mem_misalign;

   wire          bad_pc;

   wire          csr_mstatus_en;
   wire          csr_mie_en;
   wire          csr_mcause_en;
   wire [1:0]    csr_source;
   wire          csr_imm;
   wire          csr_d_sel;
   wire          csr_en;
   wire [1:0]    csr_addr;
   wire          csr_pc;
   wire          csr_imm_en;
   wire          csr_in;
   wire          rf_csr_out;

   wire          new_irq;
   wire          trap_taken;
   wire          pending_irq;

   wire [1:0]   lsb;

   serv_state
     #(.WITH_CSR (WITH_CSR))
   state
     (
      .clk            (clk),
      .rst_n          (rst_n),
      //State
      .i_new_irq      (new_irq),
      .o_trap_taken   (trap_taken),
      .o_pending_irq  (pending_irq),
      .i_alu_cmp      (alu_cmp),
      .o_init         (init),
      .o_cnt_en       (cnt_en),
      .o_cnt0to3      (cnt0to3),
      .o_cnt12to31    (cnt12to31),
      .o_cnt0         (cnt0),
      .o_cnt1         (cnt1),
      .o_cnt2         (cnt2),
      .o_cnt3         (cnt3),
      .o_cnt7         (cnt7),
      .o_cnt_done     (cnt_done),
      .o_bufreg_en    (bufreg_en),
      .o_ctrl_pc_en   (ctrl_pc_en),
      .o_ctrl_jump    (jump),
      .o_ctrl_trap    (trap),
      .i_ctrl_misalign(lsb[1]),
      .o_alu_shamt_en (alu_shamt_en),
      .i_alu_sh_done  (alu_sh_done),
      .o_mem_bytecnt  (mem_bytecnt),
      .i_mem_misalign (mem_misalign),
      //Control
      .i_bne_or_bge   (bne_or_bge),
      .i_cond_branch  (cond_branch),
      .i_branch_op    (branch_op),
      .i_mem_op       (mem_op),
      .i_shift_op     (shift_op),
      .i_slt_op       (slt_op),
      .i_e_op         (e_op),
      .i_rd_op        (rd_op),
      //External
      .o_dbus_cyc     (o_dbus_cyc),
      .i_dbus_ack     (i_dbus_ack),
      .o_ibus_cyc     (o_ibus_cyc),
      .i_ibus_ack     (i_ibus_ack),
      //RF Interface
      .o_rf_rreq      (o_rf_rreq),
      .o_rf_wreq      (o_rf_wreq),
      .i_rf_ready     (i_rf_ready),
      .o_rf_rd_en     (rd_en));

   serv_decode decode
     (
      .clk                (clk),
      .rst_n              (rst_n),
      //Input
      .i_wb_rdt           (i_ibus_rdt), // originally [31:2]
      .i_wb_en            (i_ibus_ack),
      //To state
      .o_bne_or_bge       (bne_or_bge),
      .o_cond_branch      (cond_branch),
      .o_e_op             (e_op),
      .o_ebreak           (ebreak),
      .o_branch_op        (branch_op),
      .o_mem_op           (mem_op),
      .o_shift_op         (shift_op),
      .o_slt_op           (slt_op),
      .o_rd_op            (rd_op),
      //To bufreg
      .o_bufreg_rs1_en    (bufreg_rs1_en),
      .o_bufreg_imm_en    (bufreg_imm_en),
      .o_bufreg_clr_lsb   (bufreg_clr_lsb),
      //To ctrl
      .o_ctrl_jal_or_jalr (jal_or_jalr),
      .o_ctrl_utype       (utype),
      .o_ctrl_pc_rel      (pc_rel),
      .o_ctrl_mret        (mret),
      //To alu
      .o_op_b_source      (op_b_source),
      .o_alu_sub          (alu_sub),
      .o_alu_bool_op      (alu_bool_op),
      .o_alu_cmp_eq       (alu_cmp_eq),
      .o_alu_cmp_sig      (alu_cmp_sig),
      .o_alu_sh_signed    (alu_sh_signed),
      .o_alu_sh_right     (alu_sh_right),
      .o_alu_rd_sel       (alu_rd_sel),
      //To mem IF
      .o_mem_cmd          (o_dbus_we),
      .o_mem_signed       (mem_signed),
      .o_mem_word         (mem_word),
      .o_mem_half         (mem_half),
      //To CSR
      .o_csr_en           (csr_en),
      .o_csr_addr         (csr_addr),
      .o_csr_mstatus_en   (csr_mstatus_en),
      .o_csr_mie_en       (csr_mie_en),
      .o_csr_mcause_en    (csr_mcause_en),
      .o_csr_source       (csr_source),
      .o_csr_d_sel        (csr_d_sel),
      .o_csr_imm_en       (csr_imm_en),
      //To top
      .o_immdec_ctrl      (immdec_ctrl),
      .o_rd_csr_en        (rd_csr_en),
      .o_rd_alu_en        (rd_alu_en));

   serv_immdec immdec
     (
      .clk          (clk),
      .rst_n        (rst_n),
      //State
      .i_cnt_en     (cnt_en),
      .i_cnt_done   (cnt_done),
      //Control
      .i_csr_imm_en (csr_imm_en),
      .i_ctrl       (immdec_ctrl),
      .o_rd_addr    (rd_addr),
      .o_rs1_addr   (rs1_addr),
      .o_rs2_addr   (rs2_addr),
      //Data
      .o_csr_imm    (csr_imm),
      .o_imm        (imm),
      //External
      .i_wb_en      (i_ibus_ack),
      .i_wb_rdt     (i_ibus_rdt)); // originally [31:7]

   serv_bufreg bufreg
     (
      .clk      (clk),
      .rst_n    (rst_n),
      //State
      .i_cnt0   (cnt0),
      .i_cnt1   (cnt1),
      .i_en     (bufreg_en),
      .i_init   (init),
      .o_lsb    (lsb),
      //Control
      .i_rs1_en (bufreg_rs1_en),
      .i_imm_en (bufreg_imm_en),
      .i_clr_lsb (bufreg_clr_lsb),
      //Data
      .i_rs1    (rs1),
      .i_imm    (imm),
      .o_q      (bufreg_q),
      //External
      .o_dbus_adr (o_dbus_adr));

   serv_ctrl
     #(.RESET_PC (RESET_PC),
       .WITH_CSR (WITH_CSR))
   ctrl
     (
      .clk        (clk),
      .rst_n      (rst_n),
      //State
      .i_pc_en    (ctrl_pc_en),
      .i_cnt12to31 (cnt12to31),
      .i_cnt0     (cnt0),
      .i_cnt2     (cnt2),
      .i_cnt_done (cnt_done),
      //Control
      .i_jump     (jump),
      .i_jal_or_jalr (jal_or_jalr),
      .i_utype    (utype),
      .i_pc_rel   (pc_rel),
      .i_trap     (trap | mret),
      //Data
      .i_imm      (imm),
      .i_buf      (bufreg_q),
      .i_csr_pc   (csr_pc),
      .o_rd       (ctrl_rd),
      .o_bad_pc   (bad_pc),
      //External
      .o_ibus_adr (o_ibus_adr));

   serv_alu alu
     (
      .clk        (clk),
      .rst_n      (rst_n),
      //State
      .i_en       (cnt_en),
      .i_cnt0     (cnt0),
      .i_cnt_done (cnt_done),
      .i_shamt_en (alu_shamt_en),
      .o_cmp      (alu_cmp),
      .o_sh_done  (alu_sh_done),
      //Control
      .i_shift_op (shift_op),
      .i_op_b_rs2 (op_b_source),
      .i_sub      (alu_sub),
      .i_bool_op  (alu_bool_op),
      .i_cmp_eq   (alu_cmp_eq),
      .i_cmp_sig  (alu_cmp_sig),
      .i_sh_right (alu_sh_right),
      .i_sh_signed (alu_sh_signed),
      .i_rd_sel   (alu_rd_sel),
      //Data
      .i_rs1      (rs1),
      .i_rs2      (rs2),
      .i_imm      (imm),
      .i_buf      (bufreg_q),
      .o_rd       (alu_rd));

   serv_rf_if
     #(.WITH_CSR (WITH_CSR))
   rf_if
     (//RF interface
      .o_wreg0     (o_wreg0),
      .o_wreg1     (o_wreg1),
      .o_wen0      (o_wen0),
      .o_wen1      (o_wen1),
      .o_wdata0    (o_wdata0),
      .o_wdata1    (o_wdata1),
      .o_rreg0     (o_rreg0),
      .o_rreg1     (o_rreg1),
      .i_rdata0    (i_rdata0),
      .i_rdata1    (i_rdata1),

      //Trap interface
      .i_trap      (trap),
      .i_mret      (mret),
      .i_mepc      (o_ibus_adr[0]),
      .i_mem_misalign (mem_misalign),
      .i_bufreg_q  (bufreg_q),
      .i_bad_pc    (bad_pc),
      .o_csr_pc    (csr_pc),
      //CSR write port
      .i_csr_en    (csr_en),
      .i_csr_addr  (csr_addr),
      .i_csr       (csr_in),
      //RD write port
      .i_rd_wen    (rd_en),
      .i_rd_waddr  (rd_addr),
      .i_ctrl_rd   (ctrl_rd),
      .i_alu_rd    (alu_rd),
      .i_rd_alu_en (rd_alu_en),
      .i_csr_rd    (csr_rd),
      .i_rd_csr_en (rd_csr_en),
      .i_mem_rd    (mem_rd),

      //RS1 read port
      .i_rs1_raddr (rs1_addr),
      .o_rs1       (rs1),
      //RS2 read port
      .i_rs2_raddr (rs2_addr),
      .o_rs2       (rs2),

      //CSR read port
      .o_csr       (rf_csr_out));

   serv_mem_if
     #(.WITH_CSR (WITH_CSR))
   mem_if
     (
      .clk        (clk),
      .rst_n      (rst_n),
      //State
      .i_en       (cnt_en),
      .i_bytecnt  (mem_bytecnt),
      .i_lsb      (lsb),
      .o_misalign (mem_misalign),
      //Control
      .i_mem_op   (mem_op),
      .i_signed   (mem_signed),
      .i_word     (mem_word),
      .i_half     (mem_half),
      //Data
      .i_rs2    (rs2),
      .o_rd     (mem_rd),
      //External interface
      .o_wb_dat   (o_dbus_dat),
      .o_wb_sel   (o_dbus_sel),
      .i_wb_rdt   (i_dbus_rdt),
      .i_wb_ack   (i_dbus_ack));

   generate
      if (WITH_CSR) begin
         serv_csr csr
           (
            .clk          (clk),
            .rst_n        (rst_n),
            //State
            .i_en         (cnt_en),
            .i_cnt0to3    (cnt0to3),
            .i_cnt3       (cnt3),
            .i_cnt7       (cnt7),
            .i_cnt_done   (cnt_done),
            .i_mem_misalign (mem_misalign),
            .i_mtip       (i_timer_irq),
            .i_trap_taken (trap_taken),
            .i_pending_irq (pending_irq),
            .o_new_irq    (new_irq),
            //Control
            .i_e_op       (e_op),
            .i_ebreak     (ebreak),
            .i_mem_cmd    (o_dbus_we),
            .i_mstatus_en (csr_mstatus_en),
            .i_mie_en     (csr_mie_en    ),
            .i_mcause_en  (csr_mcause_en ),
            .i_csr_source (csr_source),
            .i_mret       (mret),
            .i_csr_d_sel  (csr_d_sel),
            //Data
            .i_rf_csr_out (rf_csr_out),
            .o_csr_in     (csr_in),
            .i_csr_imm    (csr_imm),
            .i_rs1        (rs1),
            .o_q          (csr_rd));
      end else begin
         assign csr_in = 1'b0;
         assign csr_rd = 1'b0;
         assign new_irq = 1'b0;
      end
   endgenerate


`ifdef RISCV_FORMAL
   reg [31:0]    pc = RESET_PC;

   wire rs_en = (branch_op|mem_op|shift_op|slt_op) ? init : ctrl_pc_en;

   always @(posedge clk) begin
      rvfi_valid <= cnt_done & ctrl_pc_en & rst_n;
      rvfi_order <= rvfi_order + {63'd0,rvfi_valid};
      if (o_ibus_cyc & i_ibus_ack)
        rvfi_insn <= i_ibus_rdt;
      if (o_wen0)
        rvfi_rd_wdata <= {o_wdata0,rvfi_rd_wdata[31:1]};
      if (cnt_done & ctrl_pc_en) begin
         rvfi_pc_rdata <= pc;
         if (!(rd_en & (|rd_addr))) begin
           rvfi_rd_addr <= 5'd0;
           rvfi_rd_wdata <= 32'd0;
         end
      end
      rvfi_trap <= trap;
      if (rvfi_valid) begin
         rvfi_trap <= 1'b0;
         pc <= rvfi_pc_wdata;
      end

      rvfi_halt <= 1'b0;
      rvfi_intr <= 1'b0;
      rvfi_mode <= 2'd3;
      rvfi_ixl = 2'd1;
      if (i_rf_ready) begin
         rvfi_rs1_addr <= rs1_addr;
         rvfi_rs2_addr <= rs2_addr;
         rvfi_rd_addr  <= rd_addr;
      end
      if (rs_en) begin
         rvfi_rs1_rdata <= {rs1,rvfi_rs1_rdata[31:1]};
         rvfi_rs2_rdata <= {rs2,rvfi_rs2_rdata[31:1]};
      end

      if (i_dbus_ack) begin
         rvfi_mem_addr <= o_dbus_adr;
         rvfi_mem_rmask <= o_dbus_we ? 4'b0000 : o_dbus_sel;
         rvfi_mem_wmask <= o_dbus_we ? o_dbus_sel : 4'b0000;
         rvfi_mem_rdata <= i_dbus_rdt;
         rvfi_mem_wdata <= o_dbus_dat;
      end
      if (i_ibus_ack) begin
         rvfi_mem_rmask <= 4'b0000;
         rvfi_mem_wmask <= 4'b0000;
      end
   end

   always @(o_ibus_adr)
     rvfi_pc_wdata <= o_ibus_adr;

`endif

endmodule

module serv_mem_if
  #(parameter WITH_CSR = 1)
  (
   input wire         clk,
   input wire         rst_n,
   //State
   input wire         i_en,
   input wire [1:0]   i_bytecnt,
   input wire [1:0]   i_lsb,
   output wire        o_misalign,
   //Control
   input wire         i_mem_op,
   input wire         i_signed,
   input wire         i_word,
   input wire         i_half,
   //Data
   input wire         i_rs2,
   output wire        o_rd,
   //External interface
   output wire [31:0] o_wb_dat,
   output wire [3:0]  o_wb_sel,
   input wire [31:0]  i_wb_rdt,
   input wire         i_wb_ack);

   reg           signbit;
   reg [31:0]    dat;

   wire [2:0]    tmp = {1'b0,i_bytecnt}+{1'b0,i_lsb};

   wire          dat_en = i_en & !tmp[2];

   wire          dat_cur =
                 ((i_lsb == 2'd3) & dat[24]) |
                 ((i_lsb == 2'd2) & dat[16]) |
                 ((i_lsb == 2'd1) & dat[8]) |
                 ((i_lsb == 2'd0) & dat[0]);

   wire dat_valid =
        i_word |
        (i_bytecnt == 2'b00) |
        (i_half & !i_bytecnt[1]);

   assign o_rd = i_mem_op & (dat_valid ? dat_cur : signbit & i_signed);

   assign o_wb_sel[3] = (i_lsb == 2'b11) | i_word | (i_half & i_lsb[1]);
   assign o_wb_sel[2] = (i_lsb == 2'b10) | i_word;
   assign o_wb_sel[1] = (i_lsb == 2'b01) | i_word | (i_half & !i_lsb[1]);
   assign o_wb_sel[0] = (i_lsb == 2'b00);

   assign o_wb_dat = dat;

   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        dat     <= 32'b0;
        signbit <= 1'b0;
      end else begin
        if (dat_en)
          dat <= {i_rs2, dat[31:1]};

        if (i_wb_ack)
          dat <= i_wb_rdt;

        if (dat_valid)
          signbit <= dat_cur;
      end
   end
   generate
      if (WITH_CSR) begin
         reg             misalign;
         always @(posedge clk or negedge rst_n) begin
            if (!rst_n) misalign <= 1'b0;
            else        misalign <= (i_lsb[0] & (i_word | i_half)) | (i_lsb[1] & i_word);
         end
         assign o_misalign = misalign & i_mem_op;
      end else begin
         assign o_misalign = 1'b0;
      end
   endgenerate

endmodule

module serv_rf_if
  #(parameter WITH_CSR = 1)
  (//RF Interface
   output wire [4+WITH_CSR:0] o_wreg0,
   output wire [4+WITH_CSR:0] o_wreg1,
   output wire       o_wen0,
   output wire       o_wen1,
   output wire       o_wdata0,
   output wire       o_wdata1,
   output wire [4+WITH_CSR:0] o_rreg0,
   output wire [4+WITH_CSR:0] o_rreg1,
   input wire        i_rdata0,
   input wire        i_rdata1,

   //Trap interface
   input wire        i_trap,
   input wire        i_mret,
   input wire        i_mepc,
   input wire        i_mem_misalign,
   input wire        i_bufreg_q,
   input wire        i_bad_pc,
   output wire       o_csr_pc,
   //CSR interface
   input wire        i_csr_en,
   input wire [1:0]  i_csr_addr,
   input wire        i_csr,
   output wire       o_csr,
   //RD write port
   input wire        i_rd_wen,
   input wire [4:0]  i_rd_waddr,
   input wire        i_ctrl_rd,
   input wire        i_alu_rd,
   input wire        i_rd_alu_en,
   input wire        i_csr_rd,
   input wire        i_rd_csr_en,
   input wire        i_mem_rd,

   //RS1 read port
   input wire [4:0]  i_rs1_raddr,
   output wire       o_rs1,
   //RS2 read port
   input wire [4:0]  i_rs2_raddr,
   output wire       o_rs2);


`include "serv_params.vh"

   /*
    ********** Write side ***********
    */

   wire              rd_wen = i_rd_wen & (|i_rd_waddr);

   generate
   if (WITH_CSR) begin
   wire              rd = (i_ctrl_rd ) |
                          (i_alu_rd & i_rd_alu_en) |
                          (i_csr_rd & i_rd_csr_en) |
                          (i_mem_rd);

   wire              mtval = i_mem_misalign ? i_bufreg_q : i_bad_pc;

   assign            o_wdata0 = i_trap ? mtval  : rd;
   assign            o_wdata1 = i_trap ? i_mepc : i_csr;

   //port 0 rd mtval
   //port 1 csr mepc
   //mepc  100010
   //mtval 100011
   //csr   1000xx
   //rd    0xxxxx
   assign o_wreg0 = i_trap ? {4'b1000,CSR_MTVAL} : {1'b0,i_rd_waddr};
   assign o_wreg1 = i_trap ? {4'b1000,CSR_MEPC}  : {4'b1000,i_csr_addr};

   assign       o_wen0 = i_trap | rd_wen;
   assign       o_wen1 = i_trap | i_csr_en;

   /*
    ********** Read side ***********
    */

   //0 : RS1
   //1 : RS2 / CSR


   assign o_rreg0 = {1'b0, i_rs1_raddr};
   assign o_rreg1 =
                 i_trap   ? {4'b1000, CSR_MTVEC} :
                 i_mret   ? {4'b1000, CSR_MEPC} :
                 i_csr_en ? {4'b1000, i_csr_addr} :
                 {1'b0,i_rs2_raddr};

   assign o_rs1 = i_rdata0;
   assign o_rs2 = i_rdata1;
   assign o_csr = i_rdata1 & i_csr_en;
   assign o_csr_pc = i_rdata1;

   end else begin
      wire           rd = (i_ctrl_rd ) |
                          (i_alu_rd & i_rd_alu_en) |
                          (i_mem_rd);

      assign         o_wdata0 = rd;
      assign         o_wdata1 = 1'b0;

      assign o_wreg0 = i_rd_waddr;
      assign o_wreg1 = 5'd0;

      assign       o_wen0 = rd_wen;
      assign       o_wen1 = 1'b0;

   /*
    ********** Read side ***********
    */

      assign o_rreg0 = i_rs1_raddr;
      assign o_rreg1 = i_rs2_raddr;

      assign o_rs1 = i_rdata0;
      assign o_rs2 = i_rdata1;
      assign o_csr = 1'b0;
      assign o_csr_pc = 1'b0;
   end // else: !if(WITH_CSR)
   endgenerate
endmodule

module serv_rf_ram_if (
   //SERV side
   input wire        clk,
   input wire        rst_n,
   input wire        i_wreq,
   input wire        i_rreq,
   output wire       o_ready,
   input wire [4:0]  i_wreg0,
   input wire [4:0]  i_wreg1,
   input wire        i_wen0,
   input wire        i_wen1,
   input wire        i_wdata0,
   input wire        i_wdata1,
   input wire [4:0]  i_rreg0,
   input wire [4:0]  i_rreg1,
   output wire       o_rdata0,
   output wire       o_rdata1,
   //RAM side
   output wire [8:0] o_waddr,
   output wire [1:0] o_wdata,
   output wire       o_wen,
   output wire [8:0] o_raddr,
   input  wire [1:0] i_rdata);

   reg rgnt;

   assign o_ready = rgnt | i_wreq;

   // --------------------------------------------------------------
   // Write side
   //

   reg [4:0]         wcnt;
   reg               wgo;


   reg       wdata0_r;
   reg [1:0] wdata1_r;

   reg               wen0_r;
   reg               wen1_r;
   wire              wtrig0;
   wire              wtrig1;

   assign wtrig0 = ~wcnt[0];
   assign wtrig1 =  wcnt[0];

   assign o_wdata = wtrig1 ?
                    wdata1_r :
                    {i_wdata0, wdata0_r};

   wire [4:0] wreg  = wtrig1 ? i_wreg1 : i_wreg0;
   assign o_waddr = {wreg, wcnt[4:1]};

   assign o_wen = wgo & ((wtrig0 & wen0_r) | (wtrig1 & wen1_r));

   reg        wreq_r;

   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) wdata0_r  <= 1'b0;
      else        wdata0_r  <= i_wdata0;
   end

   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        wcnt      <= 5'd0;
        wgo       <= 1'b0;
        wdata1_r  <= 2'b0;
        wen0_r    <= 1'b0;
        wen1_r    <= 1'b0;
        wreq_r    <= 1'b0;
      end else begin
        wen0_r    <= i_wen0;
        wen1_r    <= i_wen1;
        wreq_r    <= i_wreq | rgnt;

        wdata1_r  <= {i_wdata1,wdata1_r[1]};

        if (wgo)
          wcnt <= wcnt + 1'd1;

        if (wreq_r)
          wgo <= 1'b1;

        if (wcnt == 5'b11111)
          wgo <= 1'b0;

      end
   end

   // ---------------------------------------------------------
   // Read side
   //

   reg [4:0]      rcnt;

   wire           rtrig0;
   reg            rtrig1;

   wire [4:0] rreg = rtrig0 ? i_rreg1 : i_rreg0;
   assign o_raddr = {rreg, rcnt[4:1]};

   reg [1:0]  rdata0;
   reg        rdata1;

   assign o_rdata0 = rdata0[0];
   assign o_rdata1 = rtrig1 ?  (i_rreg1 == 5'b0 ? 1'b0 : i_rdata[0]) : rdata1;

   assign rtrig0 = (rcnt[0] == 1);

   reg rreq_r;

   always @(posedge clk or negedge rst_n)
     if (!rst_n)      rdata1 <= 1'b0;
     else if (rtrig1) rdata1 <= i_rreg1 == 5'b0 ? 1'b0 : i_rdata[1];

   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        rtrig1 <= 1'b0;
        rcnt   <= 5'b0;
        rdata0 <= 2'b0;
        rgnt   <= 1'b0;
        rreq_r <= 1'b0;
      end else begin
        rtrig1 <= rtrig0;
        rcnt   <= rcnt + 1'd1;

        if (i_rreq)
          rcnt <= 5'd0;

        rreq_r <= i_rreq;
        rgnt <= rreq_r;

        rdata0 <= {1'b0,rdata0[1]};
        if (rtrig0)
          rdata0 <= i_rreg0 == 5'b0 ? 2'b0 : i_rdata;
      end
   end

endmodule

module serv_rf_top
  #(parameter RESET_PC = 32'd0,
    parameter WITH_CSR = 1,
    parameter RF_WIDTH = 2,
    parameter RF_L2D   = $clog2((32+(WITH_CSR*4))*32/RF_WIDTH))
  (
   input wire         clk,
   input wire         rst_n,
   input wire         i_timer_irq,
`ifdef RISCV_FORMAL
   output wire        rvfi_valid,
   output wire [63:0] rvfi_order,
   output wire [31:0] rvfi_insn,
   output wire        rvfi_trap,
   output wire        rvfi_halt,
   output wire        rvfi_intr,
   output wire [1:0]  rvfi_mode,
   output wire [1:0]  rvfi_ixl,
   output wire [4:0]  rvfi_rs1_addr,
   output wire [4:0]  rvfi_rs2_addr,
   output wire [31:0] rvfi_rs1_rdata,
   output wire [31:0] rvfi_rs2_rdata,
   output wire [4:0]  rvfi_rd_addr,
   output wire [31:0] rvfi_rd_wdata,
   output wire [31:0] rvfi_pc_rdata,
   output wire [31:0] rvfi_pc_wdata,
   output wire [31:0] rvfi_mem_addr,
   output wire [3:0]  rvfi_mem_rmask,
   output wire [3:0]  rvfi_mem_wmask,
   output wire [31:0] rvfi_mem_rdata,
   output wire [31:0] rvfi_mem_wdata,
`endif
   output wire [31:0] o_ibus_adr,
   output wire        o_ibus_cyc,
   input wire [31:0]  i_ibus_rdt,
   input wire         i_ibus_ack,
   output wire [31:0] o_dbus_adr,
   output wire [31:0] o_dbus_dat,
   output wire [3:0]  o_dbus_sel,
   output wire        o_dbus_we ,
   output wire        o_dbus_cyc,
   input wire [31:0]  i_dbus_rdt,
   input wire         i_dbus_ack,
   output wire [RF_L2D-1:0]    o_rf_waddr,
   output wire [RF_WIDTH-1:0]  o_rf_wdata,
   output wire                 o_rf_wen,
   output wire [RF_L2D-1:0]    o_rf_raddr,
   input wire [RF_WIDTH-1:0]   i_rf_rdata);

   localparam CSR_REGS = WITH_CSR*4;

   wire               rf_wreq;
   wire               rf_rreq;
   wire [4+WITH_CSR:0] wreg0;
   wire [4+WITH_CSR:0] wreg1;
   wire               wen0;
   wire               wen1;
   wire               wdata0;
   wire               wdata1;
   wire [4+WITH_CSR:0] rreg0;
   wire [4+WITH_CSR:0] rreg1;
   wire               rf_ready;
   wire               rdata0;
   wire               rdata1;


   serv_rf_ram_if rf_ram_if
     (.clk    (clk),
      .rst_n    (rst_n),
      .i_wreq   (rf_wreq),
      .i_rreq   (rf_rreq),
      .o_ready  (rf_ready),
      .i_wreg0  (wreg0),
      .i_wreg1  (wreg1),
      .i_wen0   (wen0),
      .i_wen1   (wen1),
      .i_wdata0 (wdata0),
      .i_wdata1 (wdata1),
      .i_rreg0  (rreg0),
      .i_rreg1  (rreg1),
      .o_rdata0 (rdata0),
      .o_rdata1 (rdata1),
      .o_waddr  (o_rf_waddr),
      .o_wdata  (o_rf_wdata),
      .o_wen    (o_rf_wen),
      .o_raddr  (o_rf_raddr),
      .i_rdata  (i_rf_rdata));

   serv_top
     #(.RESET_PC (RESET_PC),
       .WITH_CSR (WITH_CSR))
   cpu
     (
      .clk      (clk),
      .rst_n    (rst_n),
      .i_timer_irq  (i_timer_irq),
`ifdef RISCV_FORMAL
      .rvfi_valid     (rvfi_valid    ),
      .rvfi_order     (rvfi_order    ),
      .rvfi_insn      (rvfi_insn     ),
      .rvfi_trap      (rvfi_trap     ),
      .rvfi_halt      (rvfi_halt     ),
      .rvfi_intr      (rvfi_intr     ),
      .rvfi_mode      (rvfi_mode     ),
      .rvfi_ixl       (rvfi_ixl      ),
      .rvfi_rs1_addr  (rvfi_rs1_addr ),
      .rvfi_rs2_addr  (rvfi_rs2_addr ),
      .rvfi_rs1_rdata (rvfi_rs1_rdata),
      .rvfi_rs2_rdata (rvfi_rs2_rdata),
      .rvfi_rd_addr   (rvfi_rd_addr  ),
      .rvfi_rd_wdata  (rvfi_rd_wdata ),
      .rvfi_pc_rdata  (rvfi_pc_rdata ),
      .rvfi_pc_wdata  (rvfi_pc_wdata ),
      .rvfi_mem_addr  (rvfi_mem_addr ),
      .rvfi_mem_rmask (rvfi_mem_rmask),
      .rvfi_mem_wmask (rvfi_mem_wmask),
      .rvfi_mem_rdata (rvfi_mem_rdata),
      .rvfi_mem_wdata (rvfi_mem_wdata),
`endif
      .o_rf_rreq   (rf_rreq),
      .o_rf_wreq   (rf_wreq),
      .i_rf_ready  (rf_ready),
      .o_wreg0     (wreg0),
      .o_wreg1     (wreg1),
      .o_wen0      (wen0),
      .o_wen1      (wen1),
      .o_wdata0    (wdata0),
      .o_wdata1    (wdata1),
      .o_rreg0     (rreg0),
      .o_rreg1     (rreg1),
      .i_rdata0    (rdata0),
      .i_rdata1    (rdata1),

      .o_ibus_adr   (o_ibus_adr),
      .o_ibus_cyc   (o_ibus_cyc),
      .i_ibus_rdt   (i_ibus_rdt),
      .i_ibus_ack   (i_ibus_ack),

      .o_dbus_adr   (o_dbus_adr),
      .o_dbus_dat   (o_dbus_dat),
      .o_dbus_sel   (o_dbus_sel),
      .o_dbus_we    (o_dbus_we),
      .o_dbus_cyc   (o_dbus_cyc),
      .i_dbus_rdt   (i_dbus_rdt),
      .i_dbus_ack   (i_dbus_ack));

endmodule
`default_nettype wire
