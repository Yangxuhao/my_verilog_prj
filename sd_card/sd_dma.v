module sd_dma (
			hclk,
			hrst_n,
			ahb_soft_rst,
			hready,
			hgrant,
			hresp,
			hrdata,
			
			hlock,
			hbusreq,
			haddr,
			htrans,
			hwrite,
			hszie,
			hburst,
			hprot,
			hwdata,
		//dma contrl signals	
			dma_en,
			dma_direc,
			dma_addr,
			transfer_size,
			clr_dma_en,
			fifo_empty,
			fifo_full,
			
			
			fifo_rdata,
			fifo_wdata,
			fifo_we,
			fifo_rd,
			fifo_full_int_gen,
			fifo_empty_int_gen,
			dma_finish_int_gen,
			fifo_full_int,
			fifo_empty_int,
			dma_finish_int
			clr_dma_finish_int,
			clr_fifo_full_int,
			clr_fifo_empty_int


);
//ahb master signasl
input			hclk;
input			hrst_n;
input			ahb_soft_rst;
input			hready;		// slave ready signal
input			hgrant;		// DMA use the BUS need Arbiter’s grant
input [1:0]		hresp;		// slave respones
input [31:0]	hrdata;

output			hlock;
output			hbusreq;
output [31:0]	haddr;
output [1:0]	htrans;
output 			hwrite;
output [2:0]	hszie;
output [2:0]	hburst;
output [3:0]	hprot;
output [31:0]	hwdata;

//dma control & other signals
input 			dma_en;
input 			dma_direc;
input [31:0]	dma_addr;
input [15:0]	transfer_size;

input [31:0]	fifo_rdata;
input			fifo_empty;
input			fifo_full;
input			clr_dma_finish_int;
input			clr_fifo_full_int;
input			clr_fifo_empty_int;
input			fifo_full_int_gen;
input			fifo_empty_int_gen;
input			dma_finish_int_gen;
output			clr_dma_en;
output [31:0]	fifo_wdata;
output			fifo_we;
output			fifo_rd;
output			fifo_full_int;
output			fifo_empty_int;
output			dma_finish_int;

//signals declaration
reg			hlock;
wire [3:0]	hprot;
wire		hbusreq;
wire [2:0]	hszie;
wire [2:0]	hburst;
reg [1:0]	htrans;
reg 		hwrite;

wire [31:0]	fifo_wdata;
wire 		fifo_rd;
reg			dma_finish_int;
reg			fifo_full_int;
reg			fifo_empty_int;

//local signals
wire 		dma_error,dma_load;
wire 		idle_bit,bus_req_bit,wr_ahb_bit;
wire 		rd_ahb_bit;
wire 		rd_last_bit,go_init,addr_finish;
wire [15:0]	dma_cnt;
wire 		fifo_full_pulse,fifo_empty_pulse;
wire		dma_finish;
wire 		grant_to_low;
wire 		addr_valid,load_clr;
wire 		rd_data_valid;
wire 		access_ahb_posedge;

reg	[3:0]	cur_state,nxt_state;
reg			direct;

reg	[15:0]	addr_cnt;
reg			fifo_full_tp,fifo_empty_tp;
reg [3:0]	grant_low_cnt;
reg			grant_low_again;
reg			dma_fifo_we;
ref	[31:0]	dma_fifo_wdata;

parameter	IDLE	= 4'h0;
parameter	BUS_REQ = 4'h1;
parameter	WR_AHB	= 4'h2;
parameter	WR_LAST	= 4'h3;
parameter	RD_AHB	= 4'h4;
parameter	RD_LAST	= 4'h5;
parameter	FINISH	= 4'h6;
parameter	WAIT	= 4'h7;

//main code
assign	hprot = 4'h1; 	// user access data  正常状态，不是特殊状态这里固定为1
assign	hsize = hbusreq ? 3'h2 : 3'h0;	// dma工作时是32bit传输，否则将其置为0
assign	hburst = hbusreq ? 3'h1 : 3'h0;	// 1：INCR无限制
//transfer_size > 16'h0400  error   当1024byte  FIFO大小是1024个byte，大于1024就错
//transfer_size 从fifo中读/写多少个数据，大于1024操作不了  可能是CPU配寄存器时错了  
//比直接用>节省资源，或用的门比较少
assign dma_error = (|transfer_size[15:11]) || (transfer_size[10] && |transfer_size[9:0]);
assign dma_load = dma_en & !dma_error;
//idle_bit = (cur_state == IDLE );
assign idle_bit = (cur_state == IDLE ) ? 1'b1:1'b0;
assign bus_req_bit = (cur_state == BUS_REQ) ? 1'b1:1'b0;
assign wr_ahb_bit = (cur_state == WR_AHB ) ? 1'b1:1'b0;
assign rd_ahb_bit = (cur_state == RD_AHB ) ? 1'b1:1'b0;
assign rd_last_bit = (cur_state == RD_LAST ) ? 1'b1:1'b0;
assign clr_dma_en = bus_req_bit;
assign load_clr = (nxt_state == FINISH ) ? 1'b1:1'b0;
assign dma_finish = (cur_state == FINISH ) ? 1'b1:1'b0;
//总线请求
assign hbusreq = (bus_req_bit || wr_ahb_bit || rd_ahb_bit ) ? 1'b1:1'b0;
//初始化，下一个状态不请求总线了，1 clk 脉冲
assign go_init = (bus_req_bit && (nxt_state != BUS_REQ) ) ? 1'b1 : 1'b0;
//fifo读信号，读fifo写AHB
assign fifo_rd = (hready && wr_ahb_bit) ? 1'b1:1'b0;
//fifo写使能，dma写fifo
assign fifo_we = dma_fifo_we;
//fifo写数据，dma写入fifo中的数据。 we=0时不care数据
//原来 assign fifo_wdata = dma_fifo_we ？ dma_fifo_wdata :0;
assign fifo_wdata = dma_fifo_wdata;
//FIFO读出的数据，即写ahb的数据
assign hwdata = fifo_rdata;
//transfer 要搬多少个数据，counter就需要多少
assign dma_cnt = transfer_size;
//addr有效信号
assign addr_valid = hready && (wr_ahb_bit || rd_ahb_bit || go_init);
assign rd_data_valid = !hready ? 1'b0 :((htrans == 2'h3) && (rd_ahb_bit)) ? 1'b1:
						rd_last_bit ? 1'b1 :(grant_to_low && !dma_direc) ? 1'b1 :1'b0;
//修改后：assign rd_data_valid = hready && (((htrans == 2'h3) && (rd_ahb_bit)) || rd_last_bit ||(grant_to_low && !dma_direc)) ;

//dma_direc =0 时读。前面的条件时写 ，在读写时读数据有效
//读，或者写  在搬完最后一个byte的时候  addr_finish
assign addr_finish = ((wr_ahb_bit || rd_ahb_bit ) && (addr_cnt == dma_cnt) && hready) ? 1'b1:1'b0;

//fsm1
always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
		cur_state <= IDLE;
	else if (ahb_soft_rst)
		cur_state <= IDLE;
	else 
		cur_state <= nxt_state;
end

always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
		direct <= 1'b0;
	else if (ahb_soft_rst)
		direct <= 1'b0;
	else if (dma_en)
		direct <= dma_direc;
end

//fsm2
always @(*) begin
//做nxt的初始值，防出错
	nxt_state = cur_state;
	case (cur_state)
	IDLE:begin
	//assign dma_load = dma_en & !dma_error;  没有error的dma_en
			if ((dma_load) && hready)
				nxt_state = BUS_REQ;
			else
				nxt_state = IDLE;
		end
		
	BUS_REQ:begin
	//向总线发送请求，满足hgrant && hready，才得到总线使用
			if (hgrant && hready) 
			begin
				if(direct)  //dma_direc=0  :write fifo   /=1 : read fifo
					nxt_state = WR_AHB;
				else
					nxt_state = RD_AHB;
			end
			else
				nxt_state = BUS_REQ;
		end
	
	WR_AHB: begin
	//assign addr_finish = ((wr_ahb_bit || rd_ahb_bit ) && (addr_cnt == dma_cnt) && hready) ? 1'b1:1'b0;
	//地址全部写完了进入WR_LAST写入最后一个数据，先地址周期后数据周期，所以还有写最后一个数据的状态
		if (addr_finish)
			nxt_state = WR_LAST;
			//没lock总线，可能grant被拉低，拉低了就回到BUS_REQ
		else if (!hgrant)
			nxt_state = BUS_REQ;
		else
			nxt_state = WR_AHB;
		end
		
	WR_LAST:begin
	//写完最后一个数据就真正的结束了
		if (hready)
			nxt_state = FINISH;
		else 
			nxt_state = WR_LAST;
		end
		
	RD_AHB: begin
		if (addr_finish)
			nxt_state = RD_LAST;
		else if (!hgrant)
			nxt_state = BUS_REQ;
		else
			nxt_state = RD_AHB;
		end	
		
	RD_LAST:begin
		if (hready)
			nxt_state = FINISH;
		else 
			nxt_state = RD_LAST;
		end
	
	FINISH:begin
		nxt_state = IDLE
		end
	
	default:begin
		nxt_state = IDLE
		end	
	endcase
end
//------------------------------------------------------------
// used to write or read data after hgrant ==0
//hgrant拉低之后其实还可以再读/写一个数据。这里grant_to_low只保持一个时钟周期
assign grant_to_low = (grant_low_again && (grant_low_cnt == 0)) ? !hgrant && hready : 1'b0;

always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
		grant_low_cnt <= 4'h0;
	else if (go_init)
		grant_low_cnt <= 4'h0;
	else if (grant_to_low)
	//这里用1-2个bit就够了，grant_to_low只有效一个周期
		grant_low_cnt <= grant_low_cnt + 4'h1;
end

always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
		grant_low_again <= 1'h0;
	else if (go_init || idle_bit)
		grant_low_again <= 1'h0;
	//在读写状态的时候grant被拉低了，产生grant_low_again信号
	else if (!hgrant && (wr_ahb_bit || rd_ahb_bit))
		grant_low_again <= 1'h1;
end
//---------------------------------------------------
always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
		hlock <= 1'b0;
	else if (ahb_soft_rst)
		hlock <= 1'b0;
	else 
		hlock <= 1'b0;
end

always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
		haddr <= 32'h0;
	else if (ahb_soft_rst)
		haddr <= 32'h0;
	else if (idle_bit)
		haddr <= 32'h0;
	else if (go_init)
	begin
		if (grant_low_again)
		//grant_low_again  地址保持
			haddr <= haddr;
		else 
		//第一次发数据用到的地址，用dma_address
			haddr <= dma_addr;
	end
	else if(addr_valid)
		haddr <= haddr + 32'h4;
end

always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
		dma_fifo_we <= 1'b0;
	else if (ahb_soft_rst)
		dma_fifo_we <= 1'b0;
	else 
	//对齐有效数据写入，
		dma_fifo_we <= rd_data_valid;
end

always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
		dma_fifo_wdata <= 32'h0;
	else if (ahb_soft_rst)
		dma_fifo_wdata <= 32'h0;
	else 
		dma_fifo_wdata <= hdata;
end

always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
		hwrite <= 1'b0;
	else if (ahb_soft_rst)
		hwrite <= 1'b0;
	//在读FIFO写AHB && go_init时，hwrite
	else if (go_init && direct)
		hwrite <= 1'b1;
	else if (addr_finish)
		hwrite <= 1'b0;
end

always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
		addr_cnt <= 16'h0;
	else if (ahb_soft_rst)
		addr_cnt <= 16'h0;
	else if (idle_bit)
		addr_cnt <= 16'h0;
	else if (grant_low_again)
	//else if (!hgrant && (wr_ahb_bit || rd_ahb_bit))
	//	grant_low_again <= 1'h1;
	//保存当前的地址，但下次获得权限可以继续之前的工作
		addr_cnt <= addr_cnt;
	else if (addr_valid)
	begin	
	//下面两个分支可以去掉，address前面也是固定+4的
	//assign	hsize = hbusreq ? 3'h2 : 3'h0;
		if (hsize == 2'h2)
			addr_cnt <= addr_cnt +16'h4;
		else if (hsize == 2'h1)
			addr_cnt <= addr_cnt +16'h2;
		else 
			addr_cnt <= addr_cnt +16'h1;
	end
end

always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
		htrans <= 2'h0;
	else if (ahb_soft_rst)
		htrans <= 2'h0;
	else if (addr_finish)
		htrans <= 2'h0;
	else if (go_init)
	//第一次发送的时NONSEQ
		htrans <= 2'h2;
	else if (!hready)
	//在！hready的狮虎保持
		htrans <= htrans;
	else if (wr_ahb_bit || rd_ahb_bit)
	//读写的时候SEQ
		htrans <= 2'h3;
	else 
	//不是读写，也不是第一次发送，那就是IDLE　让其＝０
		htrans <= 2'h0;
end

always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
		fifo_full_tp <= 1'b0;
	else if (ahb_soft_rst)
		fifo_full_tp <= 1'b0;
	else 
		fifo_full_tp <= fifo_full;
end

assign fifo_full_pulse = !fifo_full_tp && fifo_full ;

always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
		fifo_empty_tp <= 1'b0;
	else if (ahb_soft_rst)
		fifo_empty_tp <= 1'b0;
	else 
		fifo_empty_tp <= fifo_empty;
end

assign fifo_empty_pulse = !fifo_empty_tp && fifo_empty ;

always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
		dma_finish_int <= 1'b0;
	else if (ahb_soft_rst)
		dma_finish_int <= 1'b0;
	else if (dma_finish_int_gen && dma_finish)
		dma_finish_int <= 1'b1;
	else if (clr_dma_finish_int)
		dma_finish_int <= 1'b0;
end

always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
		fifo_full_int <= 1'b0;
	else if (ahb_soft_rst)
		fifo_full_int <= 1'b0;
	else if (fifo_full_int_gen && fifo_full_pulse)
		fifo_full_int <= 1'b1;
	else if (clr_dma_finish_int)
		fifo_full_int <= 1'b0;
end

always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
		fifo_empty_int <= 1'b0;
	else if (ahb_soft_rst)
		fifo_empty_int <= 1'b0;
	else if (fifo_empty_int_gen && fifo_empty_pulse)
		fifo_empty_int <= 1'b1;
	else if (clr_dma_finish_int)
		fifo_empty_int <= 1'b0;
end

endmodule