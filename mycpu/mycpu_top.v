`include "mycpu.h"
module mycpu_top(
    input         clk,
    input         resetn,
    // inst sram interface
    output        inst_sram_req,     //lab10
    output        inst_sram_wr,      //lab10
    output [ 1:0] inst_sram_size,    //lab10
    output [31:0] inst_sram_addr,    //lab10
    output [ 3:0] inst_sram_wstrb,   //lab10
    output [31:0] inst_sram_wdata,   //lab10
    input  [31:0] inst_sram_rdata,   //lab10
    input         inst_sram_addr_ok, //lan10
    input         inst_sram_data_ok, //lab10
    // data sram interface
    output        data_sram_req,     //lab10
    output        data_sram_wr,      //lab10
    output [ 1:0] data_sram_size,    //lab10
    output [31:0] data_sram_addr,    //lab10
    output [ 3:0] data_sram_wstrb,   //lab10
    output [31:0] data_sram_wdata,   //lab10
    input  [31:0] data_sram_rdata,   //lab10
    input         data_sram_addr_ok, //lan10
    input         data_sram_data_ok, //lab10
    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);

reg         reset;
always @(posedge clk) reset <= ~resetn; 

assign inst_sram_wr = |inst_sram_wstrb;
assign data_sram_wr = |data_sram_wstrb;

wire         ds_allowin;
wire         es_allowin;
wire         ms_allowin;
wire         ws_allowin;
wire         fs_to_ds_valid;
wire         ds_to_es_valid;
wire         es_to_ms_valid;
wire         ms_to_ws_valid;
wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus;
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus;
wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus;
wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus;
wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;
wire [`BR_BUS_WD       -1:0] br_bus;
//feedback bus
wire [`ES_TO_DS_BUS_WD -1:0] es_to_ds_bus;
wire [`MS_TO_DS_BUS_WD -1:0] ms_to_ds_bus;
wire csr_re;
wire [13:0] csr_rnum;
wire [31:0] csr_rvalue;
wire [13:0] csr_wnum;
wire csr_we;
wire [31:0] csr_wvalue;
wire [31:0] csr_wmask;
wire [31:0] ex_entry;
wire [31:0] ertn_entry;
wire has_int;
wire eret_flush;
wire wb_ex;
wire [31:0] wb_vaddr;
wire [5:0]  wb_ecode;
wire [8:0]  wb_esubcode;
wire [1:0] ws_to_fs_bus;
wire ws_block;
wire [31:0] tid_rvalue;

// IF stage
if_stage if_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ds_allowin     (ds_allowin     ),
    //brbus
    .br_bus         (br_bus         ),
    //outputs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    // inst sram interface
    .inst_sram_en   (inst_sram_req  ),      //lab10
    .inst_sram_wen  (inst_sram_wstrb),      //lab10
    .inst_sram_size (inst_sram_size ),      //lab10
    .inst_sram_addr (inst_sram_addr ),      //lab10
    .inst_sram_wdata(inst_sram_wdata),      //lab10
    .inst_sram_rdata(inst_sram_rdata),      //lab10
    .inst_sram_addr_ok(inst_sram_addr_ok),  //lab10
    .inst_sram_data_ok(inst_sram_data_ok),  //lab10
    // from wb
    .ws_to_fs_bus   (ws_to_fs_bus   ),
    .ws_block       (ws_block       ),
    // from csr
    .ex_entry       (ex_entry       ),
    .ertn_entry     (ertn_entry     )
);
// ID stage
id_stage id_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ),
    //from fs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    //to es
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to fs
    .br_bus         (br_bus         ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    //feedback from es
    .es_to_ds_bus   (es_to_ds_bus   ),
    //feedback from ms
    .ms_to_ds_bus   (ms_to_ds_bus   ),
    // from csr
    .ds_has_int     (has_int),
    .ds_csr_rdata   (csr_rvalue     ),
    .ds_csr_num     (csr_rnum       ),
    .ds_csr_re      (csr_re         ),

    .es_ex_int      (es_ex_int      ),
    .ms_ex_int      (ms_ex_int      ),
    .ws_ex_int      (ws_block       )
);
// EXE stage
exe_stage exe_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ms_allowin     (ms_allowin     ),
    .es_allowin     (es_allowin     ),
    //from ds
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to ms
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    // data sram interface
    .data_sram_en   (data_sram_req   ),    //lab10
    .data_sram_wen  (data_sram_wstrb ),    //lab10       
    .data_sram_size (data_sram_size ),     //lab10
    .data_sram_addr (data_sram_addr ),     //lab10 
    .data_sram_wdata(data_sram_wdata),     //lab10 
    .data_sram_addr_ok(data_sram_addr_ok), //lab10
    //to ds
    .es_to_ds_bus   (es_to_ds_bus   ),
    .es_ex_int      (es_ex_int      ),
    .ms_ex_int      (ms_ex_int      ),
    .ws_ex_int      (ws_block       ),
    //to fs
    .ws_block       (ws_block       )
);
// MEM stage
mem_stage mem_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    .ms_allowin     (ms_allowin     ),
    //from es
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    //to ws
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //from data-sram
    .data_sram_rdata(data_sram_rdata),
    .data_sram_data_ok(data_sram_data_ok), //lab10
    //to ds
    .ms_to_ds_bus   (ms_to_ds_bus   ),
    .ms_ex_int      (ms_ex_int      ),
    // to fs
    .ws_block       (ws_block       )

);
// WB stage
wb_stage wb_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    //from ms
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    // to fs
    .ws_to_fs_bus   (ws_to_fs_bus   ),
    .ws_block(ws_block),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    .ws_ex          (wb_ex          ),
    .ws_csr_gr      (csr_we         ),
    .ws_csr_num     (csr_wnum       ),
    .ws_csr_wdata   (csr_wvalue     ),
    .ws_csr_wmask   (csr_wmask      ),
    // .ws_csr_has_int (has_int        ),
    .ws_csr_eret_flush(eret_flush   ),
    .ws_csr_ecode   (wb_ecode       ),
    .ws_csr_esubcode(wb_esubcode    ),
    .ws_vaddr       (wb_vaddr       ),
    .ws_tid_rvalue  (tid_rvalue     ),

    //trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_wen  (debug_wb_rf_wen  ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
    
);

csr u_csr(
    .clk          (clk        ),
    .rst          (reset      ),
    .csr_re       (csr_re     ),
    .csr_rnum     (csr_rnum   ),
    .csr_wnum     (csr_wnum   ),
    .csr_rvalue   (csr_rvalue ),
    .csr_we       (csr_we     ),
    .csr_wmask    (csr_wmask  ),
    .csr_wvalue   (csr_wvalue ),
    .ex_entry     (ex_entry   ),
    .ertn_entry   (ertn_entry ),
    .has_int      (has_int    ),
    .eret_flush   (eret_flush ),
    .wb_ex        (wb_ex      ),
    .wb_vaddr     (wb_vaddr   ),
    .wb_ecode     (wb_ecode   ),
    .wb_esubcode  (wb_esubcode),
    .wb_pc        (debug_wb_pc),
    .tid_rvalue   (tid_rvalue)
);

endmodule
