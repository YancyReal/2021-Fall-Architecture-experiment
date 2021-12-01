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
    input [`MS_TO_ES_BUS_WD -1:0] ms_to_es_bus,
    //to ms
    output                         es_to_ms_valid,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    // data sram interface
    input           data_sram_addr_ok,   //lab10
    output [ 1:0]   data_sram_size ,     //lab10
    output          data_sram_en   ,
    output [ 3:0]   data_sram_wen  ,
    output [31:0]   data_sram_addr ,
    output [31:0]   data_sram_wdata,
    //es to ds feedback
    output [`ES_TO_DS_BUS_WD - 1:0]  es_to_ds_bus,
    output                           es_ex_int   ,
    input                            ms_ex_int   ,
    input                            ws_ex_int   ,
    // to fs
    input                            ws_block,
    // csr
    output                           es_cnt_op,
    input [31:0]                     es_cnt,

    //lab14
    input [31:0]         asid,
    input [31:0]         tlbehi,

    // search port 1 (for load/store)
    output tlbsrch,
    output [ 18:0] s1_vppn,
    output s1_va_bit12,
    output [ 9:0] s1_asid,
    // input s1_found,
    // input [$clog2(16)-1:0] s1_index,
    // input [ 19:0] s1_ppn,
    // input [ 5:0] s1_ps,
    // input [ 1:0] s1_plv,
    // input [ 1:0] s1_mat,
    // input s1_d,
    // input s1_v,
    output invtlb_valid,
    output [4:0] invtlb_op

);

reg         es_valid      ;
wire        es_ready_go   ;
wire        es_cancel;
wire        es_req;

reg  [63:0] stable_couter;
wire [31:0] es_clk_data;
wire es_rdcntid;
wire es_rdcntvh_w;
wire es_rdcntvl_w;
wire es_clk_op = es_rdcntvh_w | es_rdcntvl_w ;

always @(posedge clk) begin
    if (reset || stable_couter == ~(64'b0)) begin     
        stable_couter <= 64'b0;
    end
    else begin 
        stable_couter <= stable_couter + 1;
    end
end

assign es_clk_data = es_rdcntvh_w ? stable_couter[63:32] : stable_couter[31:0];

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;
wire es_pc_exce     ;
wire [31:0]es_bad_pc;
wire load_exce      ;
wire store_exce     ;
wire es_mem_exce    ;
wire es_invtlb_op_exce;
wire [4:0] es_invtlb_op;
wire es_tlbsrch;
wire es_tlbrd;
wire es_tlbwr;
wire es_tlbfill;
wire es_invtlb;

wire es_csr_we;
wire es_csr_re;
wire [13:0] es_csr_num  ;
wire [31:0] es_csr_rdata;
wire [31:0] es_csr_wdata;
wire [31:0] es_csr_wmask;
wire        es_has_int;
wire        es_csr_ertn;
wire        es_sys_exce;
wire        es_brk_exce;
wire        es_ine_exce;
wire        es_csr_gr;

assign es_csr_gr = es_csr_we & es_valid;

wire [14:0] es_alu_op     ;
wire [3 :0] es_div_op     ;
wire        es_div_sign   ;
wire        es_div_unsign ;
wire        es_src1_is_pc ;
wire        es_src2_is_imm; 
wire        es_gr_we      ;
wire [ 4:0] es_dest       ;
wire [31:0] es_imm        ;
wire [31:0] es_rj_value   ;
wire [31:0] es_rkd_value  ;
wire [31:0] es_pc         ;


wire        es_res_from_mem;
wire [4:0]  es_ld_inst;

wire es_ld_b;
wire es_ld_h;
wire es_ld_w;

wire es_st_b;
wire es_st_h;
wire es_st_w;
wire [2: 0] es_st_inst; 
wire        es_mem_we;                                                           
wire [3: 0] es_store_strb;
wire [31:0] es_store_data;

//lab14
assign {es_invtlb_op    ,
        es_tlbsrch      ,
        es_tlbrd        ,
        es_tlbwr        ,
        es_tlbfill      ,
        es_invtlb       ,
        es_rdcntid      ,  //285:285
        es_has_int      ,  //284:284
        es_rdcntvl_w    ,  //282:282
        es_rdcntvh_w    ,  //283:283
        es_ine_exce     ,  //281:281
        es_brk_exce     ,  //280:280
        es_pc_exce      ,  //279:279
        es_csr_ertn     ,  //278:278
        es_sys_exce     ,  //277:277
        es_csr_num      ,  //276:263
        es_csr_we       ,  //262:262
        es_csr_re       ,  //261:261
        es_csr_wdata    ,  //260:229   
        es_csr_wmask    ,  //228:197
        es_csr_rdata    ,  //196:165
        es_st_inst      ,  //164:162
        es_ld_inst      ,  //161:157
        es_div_op       ,  //156:153
        es_alu_op       ,  //152:138
        es_res_from_mem ,  //137:137
        es_src1_is_pc   ,  //136:136
        es_src2_is_imm  ,  //135:135
        es_gr_we        ,  //134:134
        es_mem_we       ,  //133:133
        es_dest         ,  //132:128
        es_imm          ,  //127:96
        es_rj_value     ,  //95 :64
        es_rkd_value    ,  //63 :32
        es_pc              //31 :0
       } = ds_to_es_bus_r;


wire [31:0] es_alu_src1   ;
wire [31:0] es_alu_src2   ;
wire [31:0] es_alu_result ;
wire [31:0] es_result     ;

wire         es_ds_we;
wire [4: 0]  es_ds_dest;

assign es_to_ds_bus = {       
                       es_rdcntid && es_valid        ,     //54:54
                       es_csr_gr                     ,     //53:33
                       es_csr_num                    ,     //52:39
                       es_ds_we                      ,     //38:38         
                       es_ds_dest                    ,     //37:33
                       es_result                     ,     //32:1
                       es_res_from_mem && es_valid         //0 :0
                      };

assign es_to_ms_bus = {es_invtlb_op_exce,
                       es_invtlb,
                       es_tlbfill,
                       es_tlbrd,
                       es_tlbwr,
                       es_rdcntid       ,  //162:162 +1
                       es_has_int       ,  //161:161 +1
                       es_ine_exce      ,  //160:160 +1
                       es_mem_exce      ,  //159:159 +1
                       es_brk_exce      ,  //158:158 +1
                       es_pc_exce       ,  //157:157 +1
                       es_csr_ertn      ,  //156:156 +1
                       es_sys_exce      ,  //155:155 +1
                       es_csr_num       ,  //154:141 +1
                       es_csr_we        ,  //140:140 +1
                       es_csr_wdata     ,  //139:108 +1
                       es_csr_wmask     ,  //107:76 +1
                       es_ld_inst       ,  //75:71 +1
                       es_res_from_mem  ,  //70:70 +1
                       es_mem_we        ,  //70:70
                       es_gr_we         ,  //69:69
                       es_dest          ,  //68:64
                       es_result        ,  //63:32
                       es_pc               //31:0
                      };
wire ms_tlbrd;
wire ms_csr_gr;
wire [13:0]ms_csr_num;
assign {
    ms_tlbrd,
    ms_csr_num,
    ms_csr_gr}  = ms_to_es_bus;

wire tlbsrch_block = (ms_csr_gr && (ms_csr_num == `CSR_ASID|| ms_csr_num==`CSR_TLBEHI) ||
                     ms_tlbrd) && es_tlbsrch;
assign es_ex_int = (es_sys_exce | es_csr_ertn | es_mem_exce | es_brk_exce | es_pc_exce | es_ine_exce | es_invtlb_op_exce | es_has_int) & es_valid;

//div var declaration part
wire div_block;
wire div_finished_signed;
wire div_finished_unsigned;
reg  div_state_signed;
reg  div_state_unsigned;
wire div_shaked_sign;
wire div_shaked_unsign;
//input of div device
reg  divisor_tvalid_signed;
reg  dividend_tvalid_signed;
reg  divisor_tvalid_unsigned;
reg  dividend_tvalid_unsigned;
wire divisor_tready_signed;
wire divisor_tready_unsigned;
wire dividend_tready_signed;
wire dividend_tready_unsigned;
//output of div device
wire div_tvalid_signed;
wire div_tvalid_unsigned;
wire [63: 0] div_signed_res;
wire [63: 0] div_unsigned_res;

wire [31: 0]div_result;
wire [31: 0]mod_result;

// 这里只有在下一级可以进入时才能发出请求
assign es_req = ms_allowin && (es_res_from_mem || es_mem_we) && es_valid && !ms_ex_int && !es_mem_exce && !es_cancel;

assign es_cancel      = ws_block;
assign es_ready_go    = ((es_res_from_mem || es_mem_we) ? ((!es_mem_exce) ? (es_req && data_sram_addr_ok) : 1'b1)
                                                         : 1'b1) && !div_block && !tlbsrch_block;
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go;
always @(posedge clk) begin
    if (reset || es_cancel) begin     
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
        divisor_tvalid_signed  <= 1'b0;
        dividend_tvalid_signed <= 1'b0;
    end
    else if(div_shaked_sign) begin
        divisor_tvalid_signed  <= 1'b0;
        dividend_tvalid_signed <= 1'b0;
    end
    else if(es_div_sign & es_valid & !div_state_signed & !ms_ex_int & !ws_ex_int)begin
        divisor_tvalid_signed  <= 1'b1;
        dividend_tvalid_signed <= 1'b1;
    end
end

always @(posedge clk) begin
    if(reset) begin
        div_state_signed       <= 1'b0;
    end
    else if(div_finished_signed) begin
        div_state_signed       <= 1'b0;
    end
    else if(div_shaked_sign) begin
        div_state_signed       <= 1'b1;
    end
end

always @(posedge clk) begin
    if(reset) begin
        divisor_tvalid_unsigned  <= 1'b0;
        dividend_tvalid_unsigned <= 1'b0;
    end
    else if(div_shaked_unsign) begin
        divisor_tvalid_unsigned  <= 1'b0;
        dividend_tvalid_unsigned <= 1'b0;
    end
    else if(es_div_unsign & es_valid & !div_state_unsigned& !ms_ex_int & !ws_ex_int) begin
        divisor_tvalid_unsigned  <= 1'b1;
        dividend_tvalid_unsigned <= 1'b1;
    end
end

always @(posedge clk) begin
    if(reset) begin
        div_state_unsigned       <= 1'b0;
    end
    else if(div_finished_unsigned) begin
        div_state_unsigned       <= 1'b0;
    end 
    else if(div_shaked_unsign) begin
        div_state_unsigned       <= 1'b1;
    end
end


assign div_shaked_sign   = (divisor_tready_signed   & divisor_tvalid_signed   & dividend_tready_signed   & dividend_tvalid_signed);
assign div_shaked_unsign = (divisor_tready_unsigned & divisor_tvalid_unsigned & dividend_tready_unsigned & dividend_tvalid_unsigned);

                            
assign div_finished_signed   = div_tvalid_signed   & es_div_sign;
assign div_finished_unsigned = div_tvalid_unsigned & es_div_unsign;
                      
assign div_block = es_valid & (|es_div_op) & !(div_finished_signed | div_finished_unsigned) & !ms_ex_int & !ws_ex_int;

div_signed div_signed(
  .aclk                   (clk),
  .s_axis_divisor_tdata   (es_alu_src2),
  .s_axis_divisor_tready  (divisor_tready_signed),
  .s_axis_divisor_tvalid  (divisor_tvalid_signed),

  .s_axis_dividend_tdata  (es_alu_src1),
  .s_axis_dividend_tready (dividend_tready_signed),
  .s_axis_dividend_tvalid (dividend_tvalid_signed),

  .m_axis_dout_tdata      (div_signed_res),
  .m_axis_dout_tvalid     (div_tvalid_signed)
);

div_unsigned div_unsigned(
  .aclk                   (clk),
  .s_axis_divisor_tdata   (es_alu_src2),
  .s_axis_divisor_tready  (divisor_tready_unsigned),
  .s_axis_divisor_tvalid  (divisor_tvalid_unsigned),

  .s_axis_dividend_tdata  (es_alu_src1),
  .s_axis_dividend_tready (dividend_tready_unsigned),
  .s_axis_dividend_tvalid (dividend_tvalid_unsigned),

  .m_axis_dout_tdata      (div_unsigned_res),
  .m_axis_dout_tvalid     (div_tvalid_unsigned)
);

assign es_result = (es_div_op[0] | es_div_op[1]) ? div_result   :
                   (es_div_op[2] | es_div_op[3]) ? mod_result   :
                   (es_csr_re)                   ? es_csr_rdata :
                   (es_clk_op)                   ? es_clk_data  :
                                                   es_alu_result;

assign es_ds_we    = es_valid && es_gr_we;
assign es_ds_dest  = es_dest;

assign es_ld_w = es_ld_inst[0];
assign es_ld_b = es_ld_inst[1] | es_ld_inst[3];
assign es_ld_h = es_ld_inst[2] | es_ld_inst[4];

assign es_st_b = es_st_inst[0];
assign es_st_h = es_st_inst[1];
assign es_st_w = es_st_inst[2];
assign es_store_strb = es_st_b ?(
                                (es_alu_result[1:0] == 2'b00) ? 4'b0001 :
                                (es_alu_result[1:0] == 2'b01) ? 4'b0010 :
                                (es_alu_result[1:0] == 2'b10) ? 4'b0100 :
                                                                4'b1000 )  :
                       es_st_h ?(
                                (es_alu_result[1:0] == 0) ?    4'b0011 :
                                                               4'b1100 )  :
                       es_st_w ?                               4'b1111 :
                                                               4'b0000    ;
assign es_store_data = es_st_b ? {4{es_rkd_value[7: 0]}}:
                       es_st_h ? {2{es_rkd_value[15:0]}}:
                                    es_rkd_value        ;    //es_st_w or orher all


assign load_exce   = (es_ld_w && ~(es_alu_result[1:0] == 2'b00)) || (es_ld_h && es_alu_result[0]);
assign store_exce  = (es_st_w && ~(es_alu_result[1:0] == 2'b00)) || (es_st_h && es_alu_result[0]);
assign es_mem_exce = load_exce | store_exce;
assign es_invtlb_op_exce = es_invtlb & ~(es_invtlb_op == 5'h0 || es_invtlb_op == 5'h1 || es_invtlb_op == 5'h2 
                                      || es_invtlb_op == 5'h3 || es_invtlb_op == 5'h4 || es_invtlb_op == 5'h5 
                                      || es_invtlb_op == 5'h6);

//lab14
assign invtlb_op = es_invtlb_op;
assign invtlb_valid = es_invtlb && es_valid;
assign s1_asid     = es_invtlb ? es_rj_value[9:0] : asid[9:0];
assign s1_vppn     = es_invtlb ? es_rkd_value[31:13] : tlbehi[31:13];
assign s1_va_bit12 = es_invtlb ? es_rkd_value[12] : 1'b0;
assign tlbsrch = es_tlbsrch;
assign invtlb = es_invtlb;


assign data_sram_en    = es_req;
assign data_sram_wen   = (es_mem_we && es_valid) ? es_store_strb : 4'h0;
assign data_sram_addr  = es_alu_result;
assign data_sram_wdata = es_store_data;
assign data_sram_size  = (es_ld_w || es_st_w) ? 2'd2 :
                         (es_ld_h || es_st_h) ? 2'b1 : 2'b0;

endmodule