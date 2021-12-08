`include "mycpu.h"
module mycpu_top(
    input         aclk,
    input         aresetn,
    // inst sram interface
    output     [ 3:0] 	arid,
    output     [31:0]	araddr,
    output     [ 7:0] 	arlen,
    output     [ 2:0] 	arsize,
    output     [ 1:0]	arburst,
    output     [ 1:0]	arlock,
    output     [ 3:0]	arcache,
    output     [ 2:0]	arprot,
    output     		    arvalid,
    input      		    arready,
    // read response interface
    input [ 3:0] 	rid,
    input [31:0]	rdata,
    input [ 1:0]    rresp,
    input		    rlast,
    input 		    rvalid,
    output 		    rready,
    // write req interface
    output     [ 3:0]	awid,
    output     [31:0]	awaddr,
    output     [ 7:0] 	awlen,
    output     [ 2:0]	awsize,
    output     [ 1:0]	awburst,
    output     [ 1:0]	awlock,
    output     [ 3:0]	awcache,
    output     [ 2:0] 	awprot,
    output    		    awvalid,
    input 		        awready,
    // write data interface
    output     [ 3:0]	wid,
    output     [31:0]	wdata,
    output     [ 3:0]	wstrb,
    output 		        wlast,
    output    		    wvalid,
    input		        wready,
    // write response interface
    input      [ 3:0]   bid,
    input      [ 1:0]   bresp,
    input 		        bvalid,
    output		        bready,
    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);

wire clk;
assign resetn = aresetn;
assign clk = aclk;
assign resetn = aresetn;
reg         reset;
always @(posedge clk) reset <= ~resetn; 



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
wire [`MS_TO_ES_BUS_WD -1:0] ms_to_es_bus;
wire [`WS_TO_FS_BUS_WD -1:0] ws_to_fs_bus;

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
wire ws_mem_inst;
wire [31:0] wb_vaddr;
wire [5:0]  wb_ecode;
wire [8:0]  wb_esubcode;

wire ws_block;
wire [31:0] tid_rvalue;
wire        inst_sram_req;
wire        inst_sram_wr;    
wire [ 1:0] inst_sram_size;   
wire [31:0] inst_sram_addr;    
wire [ 3:0] inst_sram_wstrb;   
wire [31:0] inst_sram_wdata;   
wire [31:0] inst_sram_rdata;   
wire        inst_sram_addr_ok; 
wire        inst_sram_data_ok; 
// data sram interface
wire        data_sram_req;     
wire        data_sram_wr;      
wire [ 1:0] data_sram_size;    
wire [31:0] data_sram_addr;    
wire [ 3:0] data_sram_wstrb;   
wire [31:0] data_sram_wdata;   
wire [31:0] data_sram_rdata;   
wire        data_sram_addr_ok; 
wire        data_sram_data_ok; 


//TLB 
//search port 0(for fetch)
wire [18:0] s0_vppn;
wire        s0_va_bit12;
wire [9:0]  s0_asid;
wire        s0_found;
wire [3:0] s0_index;
wire [19:0] s0_ppn;
wire [5:0]  s0_ps;
wire [1:0]  s0_plv;
wire [1:0]  s0_mat;
wire        s0_d;
wire        s0_v;
//search port 1(for load/store)
wire [18:0] s1_vppn;
wire        s1_va_bit12;
wire [9:0]  s1_asid;
wire        s1_found;
wire [3:0] s1_index;
wire [19:0] s1_ppn;
wire [5:0]  s1_ps;
wire [1:0]  s1_plv;
wire [1:0]  s1_mat;
wire        s1_d;
wire        s1_v;
//invtlb opcode
wire [4:0]  invtlb_op;
wire        invtlb_valid;
//write port
wire        we;
wire [3:0] w_index;
wire        w_e;
wire [18:0] w_vppn;
wire [5:0]  w_ps;
wire [9:0]  w_asid;
wire        w_g;
wire [19:0] w_ppn0;
wire [1:0]  w_plv0;
wire [1:0]  w_mat0;
wire        w_d0;
wire        w_v0;
wire [19:0] w_ppn1;
wire [1:0]  w_plv1;
wire [1:0]  w_mat1;
wire        w_d1;
wire        w_v1;
//read port
wire [3:0] r_index;
wire        r_e;
wire [18:0] r_vppn;
wire [5:0]  r_ps;
wire [9:0]  r_asid;
wire        r_g;
wire [19:0] r_ppn0;
wire [1:0]  r_plv0;
wire [1:0]  r_mat0;
wire        r_d0;
wire        r_v0;
wire [19:0] r_ppn1;
wire [1:0]  r_plv1;
wire [1:0]  r_mat1;
wire        r_d1;
wire        r_v1;

wire [31:0]    asid;
wire [31:0]    tlbehi;
wire [31:0]    tlbidx;
wire [31:0]    tlbelo0;
wire [31:0]    tlbelo1;
wire [31:0]    csr_crmd;
wire [31:0]    csr_dmw0;
wire [31:0]    csr_dmw1;

wire    ws_tlbrd;
wire    ws_tlbwr;
wire    ws_tlbfill;
wire    es_tlbsrch;
wire    es_invtlb;

assign inst_sram_wr = |inst_sram_wstrb;
assign data_sram_wr = |data_sram_wstrb;




axi u_axi(
    .aclk(clk),
    .aresetn(resetn),
    // inst sram interface: slave
    .inst_sram_req(inst_sram_req),     
    .inst_sram_wr(inst_sram_wr),      
    .inst_sram_size(inst_sram_size),    
    .inst_sram_addr(inst_sram_addr),    
    .inst_sram_wstrb(inst_sram_wstrb),   
    .inst_sram_wdata(inst_sram_wdata),   
    .inst_sram_rdata(inst_sram_rdata),   
    .inst_sram_addr_ok(inst_sram_addr_ok), 
    .inst_sram_data_ok(inst_sram_data_ok), 
    // data sram interface: slave
    .data_sram_addr(data_sram_addr),
    .data_sram_wdata(data_sram_wdata),
    .data_sram_rdata(data_sram_rdata),
    .data_sram_req(data_sram_req),     
    .data_sram_wr(data_sram_wr),      
    .data_sram_size(data_sram_size),    
    .data_sram_wstrb(data_sram_wstrb),   
    .data_sram_addr_ok(data_sram_addr_ok), 
    .data_sram_data_ok(data_sram_data_ok), 
    // axi interface:master
    // read req interface
    .arid(arid),
    .araddr(araddr),
    .arlen(arlen),
    .arsize(arsize),
    .arburst(arburst),
    .arlock(arlock),
    .arcache(arcache),
    .arprot(arprot),
    .arvalid(arvalid),
    .arready(arready),
    // read response interface
    .rid(rid),
    .rdata(rdata),
    .rresp(rresp),
    .rlast(rlast),
    .rvalid(rvalid),
    .rready(rready),
    // write req interface
    .awid(awid),
    .awaddr(awaddr),
    .awlen(awlen),
    .awsize(awsize),
    .awburst(awburst),
    .awlock(awlock),
    .awcache(awcache),
    .awprot(awprot),
    .awvalid(awvalid),
    .awready(awready),
    // write data interface
    .wid(wid),
    .wdata(wdata),
    .wstrb(wstrb),
    .wlast(wlast),
    .wvalid(wvalid),
    .wready(wready),
    // write response interface
    .bid(bid),
    .bresp(bresp),
    .bvalid(bvalid),
    .bready(bready)
);


//lab14
`define TLBNUM  16


//lab14tlb
tlb tlb(
    .clk        (clk),
    // search port 0
    .s0_vppn    (s0_vppn),
    .s0_va_bit12(s0_va_bit12),  
    .s0_asid    (s0_asid),
    .s0_found   (s0_found),
    .s0_index   (s0_index),
    .s0_ppn     (s0_ppn),
    .s0_ps      (s0_ps),
    .s0_plv     (s0_plv),
    .s0_mat     (s0_mat),
    .s0_d       (s0_d),
    .s0_v       (s0_v),
    // search port 1
    .s1_vppn    (s1_vppn),
    .s1_va_bit12(s1_va_bit12),
    .s1_asid    (s1_asid),
    .s1_found   (s1_found),
    .s1_index   (s1_index),
    .s1_ppn     (s1_ppn),
    .s1_ps      (s1_ps),
    .s1_plv     (s1_plv),
    .s1_mat     (s1_mat),
    .s1_d       (s1_d),
    .s1_v       (s1_v),
    // invtlb opcode
    .invtlb_valid(invtlb_valid),
    .invtlb_op  (invtlb_op),
    // write port
    .we         (we), //w(rite) e(nable)
    .w_index    (w_index),
    .w_e        (w_e),
    .w_vppn     (w_vppn),
    .w_ps       (w_ps),
    .w_asid     (w_asid),
    .w_g        (w_g),
    .w_ppn0     (w_ppn0),
    .w_plv0     (w_plv0),
    .w_mat0     (w_mat0),
    .w_d0       (w_d0),
    .w_v0       (w_v0),
    .w_ppn1     (w_ppn1),
    .w_plv1     (w_plv1),
    .w_mat1     (w_mat1),
    .w_d1       (w_d1),
    .w_v1       (w_v1),
    // read port
    .r_index    (r_index),
    .r_e        (r_e),
    .r_vppn     (r_vppn),
    .r_ps       (r_ps),
    .r_asid     (r_asid),
    .r_g        (r_g),
    .r_ppn0     (r_ppn0),
    .r_plv0     (r_plv0),
    .r_mat0     (r_mat0),
    .r_d0       (r_d0),
    .r_v0       (r_v0),
    .r_ppn1     (r_ppn1),
    .r_plv1     (r_plv1),
    .r_mat1     (r_mat1),
    .r_d1       (r_d1),
    .r_v1       (r_v1)
);

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
    .ertn_entry     (ertn_entry     ),
    .csr_crmd       (csr_crmd       ),
    .csr_asid       (asid       ),
    .csr_dmw0       (csr_dmw0       ),
    .csr_dmw1       (csr_dmw1       ),

    //s0 port
    .s0_vppn        (s0_vppn        ),
    .s0_va_bit12    (s0_va_bit12    ),
    .s0_asid        (s0_asid        ),
    .s0_found       (s0_found       ),
    .s0_index       (s0_index       ),
    .s0_ppn         (s0_ppn         ),
    .s0_ps          (s0_ps          ),
    .s0_plv         (s0_plv         ),
    .s0_mat         (s0_mat         ),
    .s0_d           (s0_d           ),
    .s0_v           (s0_v           )
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
    //form ms
    .ms_to_es_bus   (ms_to_es_bus   ),
    //to ms
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    // data sram interface
    .data_sram_en   (data_sram_req   ),    //lab10
    .data_sram_wen  (data_sram_wstrb ),    //lab10       
    .data_sram_size (data_sram_size  ),    //lab10
    .data_sram_addr (data_sram_addr  ),    //lab10 
    .data_sram_wdata(data_sram_wdata ),    //lab10 
    .data_sram_addr_ok(data_sram_addr_ok), //lab10
    //to ds
    .es_to_ds_bus   (es_to_ds_bus   ),
    .es_ex_int      (es_ex_int      ),
    .ms_ex_int      (ms_ex_int      ),
    .ws_ex_int      (ws_block       ),
    //to fs
    .ws_block       (ws_block       ),
    //tlb
    .tlbsrch        (es_tlbsrch     ),
    .invtlb_valid   (invtlb_valid   ),
    .invtlb_op      (invtlb_op      ),
    // search port 1
    .s1_vppn        (s1_vppn        ),
    .s1_va_bit12    (s1_va_bit12    ),
    .s1_asid        (s1_asid        ),
    .s1_found       (s1_found       ),
    .s1_index       (s1_index       ),
    .s1_ppn         (s1_ppn         ),
    .s1_ps          (s1_ps          ),
    .s1_plv         (s1_plv         ),
    .s1_mat         (s1_mat         ),
    .s1_d           (s1_d           ),
    .s1_v           (s1_v           ),
    // csr
    .asid           (asid           ),
    .tlbehi         (tlbehi         ),
    .csr_crmd       (csr_crmd       ),
    .csr_dmw0       (csr_dmw0       ),
    .csr_dmw1       (csr_dmw1       )
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
    // to es
    .ms_to_es_bus   (ms_to_es_bus   ),
    //to ws
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //from data-sram
    .data_sram_rdata  (data_sram_rdata  ),
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
    .ws_csr_mem_inst(ws_mem_inst    ),

    .asid           (asid           ),
    .tlbehi         (tlbehi         ),
    .tlbidx         (tlbidx         ),
    .tlbelo0        (tlbelo0        ),
    .tlbelo1        (tlbelo1        ),

    // write port
    .we             (we             ), //w(rite) e(nable)
    .w_index        (w_index        ),
    .w_e            (w_e            ),
    .w_vppn         (w_vppn         ),
    .w_ps           (w_ps           ),
    .w_asid         (w_asid         ),
    .w_g            (w_g            ),
    .w_ppn0         (w_ppn0         ),
    .w_plv0         (w_plv0         ),
    .w_mat0         (w_mat0         ),
    .w_d0           (w_d0           ),
    .w_v0           (w_v0           ),
    .w_ppn1         (w_ppn1         ),
    .w_plv1         (w_plv1         ),
    .w_mat1         (w_mat1         ),
    .w_d1           (w_d1           ),
    .w_v1           (w_v1           ),
    
    .r_index        (r_index        ),
    .tlbfill        (ws_tlbfill     ),
    .tlbrd          (ws_tlbrd       ),
    .tlbwr          (ws_tlbwr       ),

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
    .tid_rvalue   (tid_rvalue ),

    .ws_mem_inst  (ws_mem_inst ),
    .ws_tlbrd     (ws_tlbrd    ),
    .ws_tlbwr     (ws_tlbwr    ),
    .ws_tlbfill   (ws_tlbwr    ),
    .es_tlbsrch   (es_tlbsrch  ),
    .es_invtlb    (invtlb_valid),
    // search
    .s1_found     (s1_found    ),
    .s1_index     (s1_index    ),
    
    // read port
    .r_e          (r_e         ),
    .r_vppn       (r_vppn      ),
    .r_ps         (r_ps        ),
    .r_asid       (r_asid      ),
    .r_g          (r_g         ),
    .r_ppn0       (r_ppn0      ),
    .r_plv0       (r_plv0      ),
    .r_mat0       (r_mat0      ),
    .r_d0         (r_d0        ),
    .r_v0         (r_v0        ),
    .r_ppn1       (r_ppn1      ),
    .r_plv1       (r_plv1      ),
    .r_mat1       (r_mat1      ),
    .r_d1         (r_d1        ),
    .r_v1         (r_v1        ),

    // search
    .asid         (asid        ),
    .tlbehi       (tlbehi      ),
    .tlbidx       (tlbidx      ),
    .tlbelo0      (tlbelo0     ),
    .tlbelo1      (tlbelo1     ),
    .csr_crmd     (csr_crmd    ),
    .csr_dmw0     (csr_dmw0    ),
    .csr_dmw1     (csr_dmw1    )
);

endmodule
