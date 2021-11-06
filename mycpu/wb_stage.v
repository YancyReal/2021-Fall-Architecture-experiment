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
    output [1               :0]     ws_to_fs_bus  ,
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
wire        ws_gr_we;
wire [ 4:0] ws_dest;
wire [31:0] ws_final_result;
wire [31:0] ws_pc;
wire        ws_ertn;
wire        ws_rdcntid;
wire        ws_csr_we;

assign {
        ws_rdcntid     ,  //188:188
        ws_has_int     ,  //187:187
        ws_ine_exce    ,  //186:186
        ws_mem_exce    ,  //185:185
        ws_brk_exce    ,  //184:184
        ws_error_vaddr ,  //183:152
        ws_pc_exce     ,  //151:151
        ws_ertn        ,  //150:150
        ws_sys_exce    ,  //149:149
        ws_csr_num     ,  //148:135
        ws_csr_we      ,  //134:134
        ws_csr_wdata   ,  //133:102
        ws_csr_wmask   ,  //101:70
        ws_gr_we       ,  //69:69
        ws_dest        ,  //68:64
        ws_final_result,  //63:32
        ws_pc             //31:0
       } = ms_to_ws_bus_r;

assign ws_to_fs_bus = {
                       ws_ertn & ws_valid,
                       ws_ex
                      };

assign ws_csr_eret_flush = ws_ertn && ws_valid;
assign ws_ex = (ws_sys_exce || ws_pc_exce || ws_mem_exce || ws_brk_exce || ws_ine_exce || ws_has_int) && ws_valid;
assign ws_vaddr = ws_error_vaddr;
assign ws_block = ws_ex | ws_csr_eret_flush;         //进入调用或者退出的清空信号



assign ws_csr_ecode   = ws_pc_exce  ? `ECODE_ADE :
                        ws_mem_exce ? `ECODE_ALE :
                        ws_sys_exce ? `ECODE_SYS :
                        ws_brk_exce ? `ECODE_BRK :
                        ws_ine_exce ? `ECODE_INE :
                                        6'b0     ;
                                    
assign ws_csr_esubcode = ws_pc_exce  ? `ESUBCODE_ADEF :
                                     1'b0;

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

// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = {4{rf_we}};
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = ws_final_result;

endmodule
