`include "mycpu.h"

module mem_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ws_allowin    ,
    output                         ms_allowin    ,
    //from es
    input                          es_to_ms_valid,
    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    //to ws
    output                         ms_to_ws_valid,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus  ,
    //from data-sram
    input  [31                 :0] data_sram_rdata,
    output [`MS_TO_DS_BUS_WD -1:0] ms_to_ds_bus   ,
    output                         ms_ex_int      ,
    // to fs
    input                          ws_block
);

reg         ms_valid;
wire        ms_ready_go;

wire ms_ld_w ;
wire ms_ld_b ;
wire ms_ld_h ;
wire ms_ld_bu;
wire ms_ld_hu;
wire [4:0] ms_ld_inst;
wire [3:0] Vaddr;
wire [7:0] Byte0;
wire [7:0] Byte1; 

reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;
wire        ms_res_from_mem;
wire        ms_gr_we;
// wire        ms_pc_exce;
wire        ms_csr_we;
wire [13:0] ms_csr_num;
wire [31:0] ms_csr_wdata;
wire [31:0] ms_csr_wmask;
wire        ms_csr_ertn;
wire        ms_sys_exce;
wire [ 4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [31:0] ms_pc;

assign {
        // ms_pc_exce     ,
        ms_csr_ertn    ,//156:156
        ms_sys_exce    ,//155:155
        ms_csr_num     ,//154:141 
        ms_csr_we      ,//140:140
        ms_csr_wdata   ,//139:108
        ms_csr_wmask   ,//107:76
        ms_ld_inst     ,//75:71 
        ms_res_from_mem,//70:70 
        ms_gr_we       ,//69:69 
        ms_dest        ,//68:64 
        ms_alu_result  ,//63:32 
        ms_pc           //31:0  
        } = es_to_ms_bus_r;

assign ms_ld_w  = ms_ld_inst[0];
assign ms_ld_b  = ms_ld_inst[1];
assign ms_ld_h  = ms_ld_inst[2];
assign ms_ld_bu = ms_ld_inst[3];
assign ms_ld_hu = ms_ld_inst[4];

wire [31:0] mem_result;
wire [31:0] ms_final_result;

assign ms_to_ws_bus = {
                       ms_csr_ertn    ,  //150:150
                       ms_sys_exce    ,  //149:149
                       ms_csr_num     ,  //148:135
                       ms_csr_we      ,  //134:134
                       ms_csr_wdata   ,  //133:102
                       ms_csr_wmask   ,  //101:70
                       ms_gr_we       ,  //69:69
                       ms_dest        ,  //68:64
                       ms_final_result,  //63:32
                       ms_pc             //31:0
                      };

wire        ms_ds_we;
wire [ 4:0] ms_ds_dest;
wire        ms_csr_gr;
assign ms_csr_gr = ms_csr_we & ms_valid;

assign ms_ex_int = (ms_sys_exce | ms_csr_ertn) && ms_valid;

assign ms_to_ds_bus = {
                       ms_csr_gr   ,    //52:52
                       ms_csr_num  ,    //51:38 
                       ms_ds_we    ,    //37:37
                       ms_ds_dest  ,    //36:32
                       ms_final_result  //31:0
                      };
                      
assign ms_ready_go    = 1'b1;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go && !ws_block;
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end

    if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r  <= es_to_ms_bus;
    end
end

assign ms_ds_we   = ms_valid && ms_gr_we;
assign ms_ds_dest = ms_dest;

assign Vaddr[0] = ms_alu_result[1:0] == 2'b00 ;
assign Vaddr[1] = ms_alu_result[1:0] == 2'b01 ;
assign Vaddr[2] = ms_alu_result[1:0] == 2'b10 ;
assign Vaddr[3] = ms_alu_result[1:0] == 2'b11 ;


assign Byte0 = Vaddr[0] ? data_sram_rdata[7 : 0] :
               Vaddr[1] ? data_sram_rdata[15: 8] :
               Vaddr[2] ? data_sram_rdata[23:16] :
               Vaddr[3] ? data_sram_rdata[31:24] :
                                           8'b0  ;
assign Byte1 = Vaddr[0] ? data_sram_rdata[15: 8] :
               Vaddr[1] ? data_sram_rdata[23:16] :
               Vaddr[2] ? data_sram_rdata[31:24] :
                                           8'b0  ;

assign mem_result = ms_ld_w  ? data_sram_rdata                      :
                    ms_ld_b  ? {{24{Byte0[7]}},  Byte0            } :
                    ms_ld_h  ? {{16{Byte1[7]}},  Byte1   ,   Byte0} :
                    ms_ld_bu ? {24'b0         ,  Byte0            } :
                    ms_ld_hu ? {16'b0         ,  Byte1   ,   Byte0} :
                                                             32'b0  ;

assign ms_final_result = ms_res_from_mem ? mem_result
                                         : ms_alu_result;

endmodule
