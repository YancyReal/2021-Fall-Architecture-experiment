`include "mycpu.h"

module exe_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ms_allowin    ,
    output                         es_allowin    ,
    //from ds
    input                          ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to ms
    output                         es_to_ms_valid,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    // data sram interface
    output        data_sram_en   ,
    output [ 3:0] data_sram_wen  ,
    output [31:0] data_sram_addr ,
    output [31:0] data_sram_wdata,
    //es to ds feedback
    output [`ES_TO_DS_BUS_WD - 1:0]  es_to_ds_bus
);

reg         es_valid      ;
wire        es_ready_go   ;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;
wire [14:0] es_alu_op     ;
wire [3 :0] es_div_op     ;
wire        es_div_sign   ;
wire        es_div_unsign ;
wire        es_src1_is_pc ;
wire        es_src2_is_imm; 
wire        es_gr_we      ;
wire        es_mem_we     ;
wire [ 4:0] es_dest       ;
wire [31:0] es_imm        ;
wire [31:0] es_rj_value   ;
wire [31:0] es_rkd_value  ;
wire [31:0] es_pc         ;

wire        es_res_from_mem;
wire        es_load_op;
assign {es_div_op      ,  //156:153
        es_alu_op      ,  //152:138
        es_load_op     ,  //137:137
        es_src1_is_pc  ,  //136:136
        es_src2_is_imm ,  //135:135
        es_gr_we       ,  //134:134
        es_mem_we      ,  //133:133
        es_dest        ,  //132:128
        es_imm         ,  //127:96
        es_rj_value    ,  //95 :64
        es_rkd_value   ,  //63 :32
        es_pc             //31 :0
       } = ds_to_es_bus_r;

wire [31:0] es_alu_src1   ;
wire [31:0] es_alu_src2   ;
wire [31:0] es_alu_result ;
wire [31:0] es_result ;

wire         es_ds_we;
wire [4: 0]  es_ds_dest;

assign es_to_ds_bus = {es_ds_we               ,     //38:38         
                       es_ds_dest             ,     //37:33
                       es_result          ,         //32:1
                       es_load_op && es_valid       //0 :0
                      };

assign es_res_from_mem = es_load_op;
assign es_to_ms_bus = {es_res_from_mem,  //70:70
                       es_gr_we       ,  //69:69
                       es_dest        ,  //68:64
                       es_result      ,  //63:32
                       es_pc             //31:0
                      };

//div var declaration part
wire es_inst_div;

wire div_block;
wire div_finished_signed;
wire div_finished_unsigned;
reg  div_state_signed;
reg  div_state_unsigned;
wire div_tvalid_signed;
wire div_tvalid_unsigned;

wire div_hand_succeeded_signed;
wire div_hand_succeeded_unsigned;

reg  divisor_tvalid_signed;
reg  dividend_tvalid_signed;
reg  divisor_tvalid_unsigned;
reg  dividend_tvalid_unsigned;

wire divisor_tready_signed;
wire divisor_tready_unsigned;
wire dividend_tready_signed;
wire dividend_tready_unsigned;

wire [63: 0] div_signed_res;
wire [63: 0] div_unsigned_res;
wire [31: 0] div_result;
wire [31: 0] mod_result;

assign es_ready_go    = !div_block;
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go;
always @(posedge clk) begin
    if (reset) begin     
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin 
        es_valid <= ds_to_es_valid;
    end

    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end

assign es_alu_src1 = es_src1_is_pc  ? es_pc[31:0] : 
                                      es_rj_value;
                                      
assign es_alu_src2 = es_src2_is_imm ? es_imm : 
                                      es_rkd_value;

alu u_alu(
    .alu_op     (es_alu_op    ),
    .alu_src1   (es_alu_src1  ),
    .alu_src2   (es_alu_src2  ),
    .alu_result (es_alu_result)
    );

assign div_result = (es_div_op[0]) ? div_signed_res[63:32] : div_unsigned_res[63:32];
assign mod_result = (es_div_op[2]) ? div_signed_res[31: 0] : div_unsigned_res[31:0];

assign es_div_sign   = es_div_op[0] | es_div_op[2];
assign es_div_unsign = es_div_op[1] | es_div_op[3];

always @(posedge clk) begin
    if(reset) begin
        div_state_signed       <= 1'b0;
        divisor_tvalid_signed  <= 1'b0;
        dividend_tvalid_signed <= 1'b0;
    end
    if(div_finished_signed)
        div_state_signed       <= 1'b0;
    if(es_div_sign & es_valid & !div_state_signed)begin
        divisor_tvalid_signed  <= 1'b1;
        dividend_tvalid_signed <= 1'b1;
    end
    if(div_hand_succeeded_signed) begin
        divisor_tvalid_signed  <= 1'b0;
        dividend_tvalid_signed <= 1'b0;
        div_state_signed       <= 1'b1;
    end
end

always @(posedge clk) begin
    if(reset) begin
        div_state_unsigned       <= 1'b0;
        divisor_tvalid_unsigned  <= 1'b0;
        dividend_tvalid_unsigned <= 1'b0;
    end
    if(div_finished_unsigned)
        div_state_unsigned       <= 1'b0;
    if(es_div_unsign & es_valid & !div_state_unsigned)begin
        divisor_tvalid_unsigned  <= 1'b1;
        dividend_tvalid_unsigned <= 1'b1;
    end
    if(div_hand_succeeded_unsigned) begin
        divisor_tvalid_unsigned  <= 1'b0;
        dividend_tvalid_unsigned <= 1'b0;
        div_state_unsigned       <= 1'b1;
    end
end


assign div_hand_succeeded_signed   = (divisor_tready_signed   & divisor_tvalid_signed   & dividend_tready_signed   & dividend_tvalid_signed);
assign div_hand_succeeded_unsigned = (divisor_tready_unsigned & divisor_tvalid_unsigned & dividend_tready_unsigned & dividend_tvalid_unsigned);

                            
assign div_finished_signed   = div_tvalid_signed   & es_div_sign;
assign div_finished_unsigned = div_tvalid_unsigned & es_div_unsign;
                      
assign div_block = es_valid & (|es_div_op) & !(div_finished_signed | div_finished_unsigned);

div_signed div_signed(
  .aclk                   (clk),
  .s_axis_divisor_tdata   (es_alu_src2),
  .s_axis_divisor_tready  (divisor_tready_signed),
  .s_axis_divisor_tvalid  (divisor_tvalid_signed),

  .s_axis_dividend_tdata  (es_alu_src1),
  .s_axis_dividend_tready (dividend_tready_signed),
  .s_axis_dividend_tvalid (dividend_tvalid_signed),

  .m_axis_dout_tdata     (div_signed_res),
  .m_axis_dout_tvalid    (div_tvalid_signed)
);

div_unsigned div_unsigned(
  .aclk                   (clk),
  .s_axis_divisor_tdata   (es_alu_src2),
  .s_axis_divisor_tready  (divisor_tready_unsigned),
  .s_axis_divisor_tvalid  (divisor_tvalid_unsigned),

  .s_axis_dividend_tdata  (es_alu_src1),
  .s_axis_dividend_tready (dividend_tready_unsigned),
  .s_axis_dividend_tvalid (dividend_tvalid_unsigned),

  .m_axis_dout_tdata     (div_unsigned_res),
  .m_axis_dout_tvalid    (div_tvalid_unsigned)
);

assign es_result = (es_div_op[0] | es_div_op[1]) ? div_result :
                   (es_div_op[2] | es_div_op[3]) ? mod_result :
                                                   es_alu_result;



assign es_ds_we       = es_valid && es_gr_we;
assign es_ds_dest     = es_dest;

assign data_sram_en    = (es_res_from_mem || es_mem_we) && es_valid;
assign data_sram_wen   = es_mem_we ? 4'hf : 4'h0;
assign data_sram_addr  = es_alu_result;
assign data_sram_wdata = es_rkd_value;

endmodule
