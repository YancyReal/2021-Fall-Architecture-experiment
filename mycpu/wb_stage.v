`include "mycpu.h"

module wb_stage(
    input                           clk           ,
    input                           reset         ,
    //allowin
    output                          ws_allowin    ,
    //from ms
    input                           ms_to_ws_valid,
    input  [`MS_TO_WS_BUS_WD -1:0]  ms_to_ws_bus  ,
    // to fs
    output [`WS_TO_FS_BUS_WD -1:0]  ws_to_fs_bus  ,
    output                          ws_block      ,
    //to rf: for write back
    output [`WS_TO_RF_BUS_WD -1:0]  ws_to_rf_bus  ,
    // to csr rf
    output                          ws_ex            ,
    output                          ws_csr_gr        ,
    output [13:0]                   ws_csr_num       ,
    output [31:0]                   ws_csr_wdata     ,
    output [31:0]                   ws_csr_wmask     ,
    output                          ws_csr_eret_flush,
    output [31:0]                   ws_vaddr         ,
    output [5:0]                    ws_csr_ecode     ,
    output [8:0]                    ws_csr_esubcode  ,
    input  [31:0]                   ws_tid_rvalue    ,
    output                          ws_csr_mem_inst  ,

    //lab14
    input [31:0]         asid,
    input [31:0]         tlbehi,
    input [31:0]         tlbidx,
    input [31:0]         tlbelo0,
    input [31:0]         tlbelo1,
    // write port
    output we, //w(rite) e(nable)
    output [$clog2(16)-1:0] w_index,
    output w_e,
    output [ 18:0] w_vppn,
    output [ 5:0] w_ps,
    output [ 9:0] w_asid,
    output w_g,
    output [ 19:0] w_ppn0,
    output [ 1:0] w_plv0,
    output [ 1:0] w_mat0,
    output w_d0,
    output w_v0,
    output [ 19:0] w_ppn1,
    output [ 1:0] w_plv1,
    output [ 1:0] w_mat1,
    output w_d1,
    output w_v1,


    output [3:0] r_index,
    output tlbfill,
    output tlbrd,
    output tlbwr,
     
    //trace debug interface
    output [31:0] debug_wb_pc     ,
    output [ 3:0] debug_wb_rf_wen ,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);

reg         ws_valid;
wire        ws_ready_go;
wire        ws_cancel;

reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;
wire [31:0] ws_error_vaddr;
wire        ws_has_int;
wire        ws_pc_exce;
wire        ws_mem_exce;
wire        ws_brk_exce;
wire        ws_sys_exce;
wire        ws_invtlb_op_exce;
wire        ws_gr_we;
wire [ 4:0] ws_dest;
wire [31:0] ws_final_result;
wire [31:0] ws_pc;
wire        ws_ertn;
wire        ws_rdcntid;
wire        ws_csr_we;
wire        ws_tlbfill;
wire        ws_tlbwr;
wire        ws_tlbrd;
wire        ws_refetch;
wire        ws_invtlb;
wire [5:0]  ws_tlb_ex;
reg [3:0] tlbfill_random;
wire        ws_mem_inst;
wire        ws_ade;
assign {
        ws_ade           ,  //201:201
        ws_mem_inst      ,  //200:200
        ws_tlb_ex        ,  //199:194
        ws_invtlb_op_exce,  //193:193
        ws_invtlb        ,  //192:192
        ws_tlbfill       ,  //191:191
        ws_tlbrd         ,  //190:190
        ws_tlbwr         ,  //189:189
        ws_rdcntid       ,  //188:188
        ws_has_int       ,  //187:187
        ws_ine_exce      ,  //186:186
        ws_mem_exce      ,  //185:185
        ws_brk_exce      ,  //184:184
        ws_error_vaddr   ,  //183:152
        ws_pc_exce       ,  //151:151
        ws_ertn          ,  //150:150
        ws_sys_exce      ,  //149:149
        ws_csr_num       ,  //148:135
        ws_csr_we        ,  //134:134
        ws_csr_wdata     ,  //133:102
        ws_csr_wmask     ,  //101:70
        ws_gr_we         ,  //69:69
        ws_dest          ,  //68:64
        ws_final_result  ,  //63:32
        ws_pc               //31:0
       } = ms_to_ws_bus_r;

assign ws_to_fs_bus = {
                       ws_pc,
                       ws_refetch & ws_valid,
                       ws_ertn & ws_valid,
                       ws_ex
                      };

assign ws_csr_mem_inst = ws_mem_inst;
assign ws_csr_eret_flush = ws_ertn && ws_valid;
assign ws_ex = (ws_sys_exce || ws_ade || ws_pc_exce || ws_mem_exce || ws_brk_exce || ws_ine_exce || ws_invtlb_op_exce || ws_has_int || (|ws_tlb_ex)) && ws_valid;
assign ws_vaddr = ws_error_vaddr;
assign ws_block = ws_ex | ws_csr_eret_flush;         //进入调用或者退出的清空信号
assign ws_refetch = ws_tlbfill | ws_tlbrd | ws_tlbwr | ws_invtlb;

assign tlbfill = ws_tlbfill && ws_valid;
assign tlbwr = ws_tlbwr && ws_valid;
assign tlbrd = ws_tlbrd && ws_valid;



assign ws_csr_ecode   = 
                        (ws_pc_exce | ws_ade)  ? `ECODE_ADE    :
                        ws_tlb_ex[0]     ? `ECODE_TLBR   :
                        ws_tlb_ex[1]     ? `ECODE_PPI    :
                        ws_tlb_ex[2]     ? `ECODE_PME    :
                        ws_tlb_ex[3]     ? `ECODE_PIF    :
                        ws_tlb_ex[4]     ? `ECODE_PIS    :
                        ws_tlb_ex[5]     ? `ECODE_PIL    :
                        ws_mem_exce      ? `ECODE_ALE    :
                        ws_sys_exce      ? `ECODE_SYS    :
                        ws_brk_exce      ? `ECODE_BRK    :
                        ws_ine_exce      ? `ECODE_INE    :
                        ws_invtlb_op_exce? `ECODE_INVTLB :
                                                6'b0     ;
                                    
assign ws_csr_esubcode = ws_pc_exce  ? `ESUBCODE_ADEF :
                         ws_ade      ? `ESUBCODE_ADEM :
                                                1'b0  ;

wire        rf_we;
wire [4 :0] rf_waddr;
wire [31:0] rf_wdata;
assign ws_csr_gr = ws_csr_we & ws_valid;
assign ws_to_rf_bus = {
                       ws_rdcntid && ws_valid ,   //53:53
                       ws_csr_gr   ,   //52:52
                       ws_csr_num  ,   //51:38  
                       rf_we       ,   //37:37
                       rf_waddr    ,   //36:32
                       rf_wdata        //31:0
                      };

assign ws_cancel   = ws_block;
assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset || ws_cancel) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end

    if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

assign rf_we    = ws_gr_we && ws_valid && ~ws_ex;
assign rf_waddr = ws_dest;
assign rf_wdata = ws_rdcntid ? ws_tid_rvalue : ws_final_result;


//lab14
always@(posedge clk)begin
    if(reset)
        tlbfill_random <= 4'b0;
    else 
        tlbfill_random <= tlbfill_random + 1'b1;
end

assign we = (ws_tlbwr | ws_tlbfill) && ws_valid;
assign w_index = ws_tlbwr? tlbidx[3:0] : tlbfill_random;
assign w_e = ~tlbidx[31];
assign w_vppn = tlbehi[31:13];
assign w_ps = tlbidx[29:24];
assign w_asid = asid[9:0];
assign w_g = tlbelo0[6] & tlbelo1[6];
assign w_ppn0 = tlbelo0[31:8];
assign w_plv0 = tlbelo0[3:2];
assign w_mat0 = tlbelo0[5:4];
assign w_d0 = tlbelo0[1];
assign w_v0 = tlbelo0[0];
assign w_ppn1 = tlbelo1[31:8];
assign w_plv1 = tlbelo1[3:2];
assign w_mat1 = tlbelo1[5:4];
assign w_d1 = tlbelo1[1];
assign w_v1 = tlbelo1[0];

assign r_index = tlbidx[3:0];

// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = {4{rf_we}};
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = ws_final_result;

endmodule
