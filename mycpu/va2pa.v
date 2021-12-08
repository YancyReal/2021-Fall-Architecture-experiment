module va2pa(
    input  [31:0] vaddr         ,
    input         v2p_inst      ,
    input         v2p_ld        ,
    input         v2p_st        ,
    input  [31:0] csr_crmd      ,
    input  [31:0] csr_asid      ,
    input  [31:0] csr_dmw0      ,
    input  [31:0] csr_dmw1      ,
    output [31:0] paddr         ,
    output [ 5:0] tlb_ex        , // PIL, PIS, PIF, PME, PPI, TLBR

    output [18:0] s_vppn        ,
    output        s_va_bit12    ,
    output [ 9:0] s_asid        ,
    input         s_found       ,
    input  [ 3:0] s_index       ,
    input  [19:0] s_ppn         ,
    input  [ 5:0] s_ps          ,
    input  [ 1:0] s_plv         ,
    input  [ 1:0] s_mat         ,
    input         s_d           ,
    input         s_v           ,   
    output        dmw_hit 
);

wire        direct    ;
wire        dmw_hit0  ;
wire        dmw_hit1  ;
wire [31:0] dmw_paddr0;
wire [31:0] dmw_paddr1;
wire [31:0] tlb_paddr ;
wire        pil_ex ;
wire        pis_ex ;
wire        pif_ex ;
wire        pme_ex ;
wire        ppi_ex ;
wire        tlbr_ex;


// 直接地址翻译模式
assign direct     = csr_crmd[3] & ~csr_crmd[4]; 	// DA = 1 && PG = 0
// 直接配置映射
assign dmw_hit0   = csr_dmw0[csr_crmd[1:0]] && (csr_dmw0[31:29] == vaddr[31:29]);	
assign dmw_hit1   = csr_dmw1[csr_crmd[1:0]] && (csr_dmw1[31:29] == vaddr[31:29]); 
assign dmw_paddr0 = {csr_dmw0[27:25],vaddr[28:0]};
assign dmw_paddr1 = {csr_dmw1[27:25],vaddr[28:0]};
assign dmw_hit    = dmw_hit0 | dmw_hit1;

// TLB映射地址翻译模式
assign s_vppn     = vaddr[31:13] ;
assign s_va_bit12 = vaddr[12]    ;
assign s_asid     = csr_asid[9:0];

// tlb异常判断
assign tlbr_ex = ~dmw_hit & ~s_found 
                             & (v2p_inst | v2p_ld | v2p_st);

assign pil_ex = ~dmw_hit & v2p_ld & ~s_v & s_found;
assign pis_ex = ~dmw_hit & v2p_st & ~s_v & s_found;
assign pif_ex = ~dmw_hit & v2p_inst & ~s_v & s_found;

assign ppi_ex = ~dmw_hit & (csr_crmd[1:0] > s_plv) 
                             & (v2p_inst | v2p_ld | v2p_st) & s_v; 

assign pme_ex = ~dmw_hit & v2p_st & ~s_d & s_found & s_v & ~(csr_crmd[1:0] > s_plv);
 

assign tlb_ex = direct ? 6'b0
			: {	pil_ex, 
				pis_ex, 
				pif_ex, 
				pme_ex, 
				ppi_ex, 
				tlbr_ex}; // PIL, PIS, PIF, PME, PPI, TLBR

assign tlb_paddr = (s_ps == 6'd12) ? {s_ppn[19: 0],vaddr[11:0]} 
                                   : {s_ppn[19:10],vaddr[21:0]};

assign paddr = direct   ? vaddr
             : dmw_hit0 ? dmw_paddr0 
             : dmw_hit1 ? dmw_paddr1 
                        : tlb_paddr;
endmodule