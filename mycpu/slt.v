module slt(
  input  [1:0] alu_op,
  input  [31:0] alu_src1,
  input  [31:0] alu_src2,
  output [31:0] alu_result
);

wire op_slt;   //signed compared and set less than
wire op_sltu;  //unsigned compared and set less than
// control code decomposition
assign op_slt   = alu_op[0];
assign op_sltu  = alu_op[1];

wire [31:0] slt_result;
wire [31:0] sltu_result;

// 32-bit adder
wire [31:0] adder_a;
wire [31:0] adder_b;
wire [31:0] adder_result;
wire        adder_cout;

assign adder_a   =  alu_src1;
assign adder_b   = ~alu_src2;  //src1 - src2 rj-rk
assign {adder_cout, adder_result} = adder_a + adder_b + 1'b1;


// SLT result
assign slt_result = {31'b0, 
                          (alu_src1[31] & ~alu_src2[31])
                        | ((alu_src1[31] ~^ alu_src2[31]) & adder_result[31])};   //rj < rk 1

// SLTU result
assign sltu_result = {31'b0, ~adder_cout};

// final result mux
assign alu_result = ({32{op_slt }} & slt_result)
                  | ({32{op_sltu}} & sltu_result);

endmodule