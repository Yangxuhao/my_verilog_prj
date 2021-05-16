module sd_if (
		//ahb bus slave singals 
			hclk;
			hrst_n;
			hsel;
			hwrite;
			htrans;
			hburst;
			hwadata;
			haddr;
			hsize;
			hready_in;
			//out
			hready_out;
			hresp;
			hrdata;
		//--------------------------
			response0;
			response1;
			response2;
			response3;

//-- host_dma
			dma_en;
			dma_direc;
			transfer_size;
			dma_addr;

			fifo_full_int_gen;
			fifo_empty_int_gen;
			dma_finish_int_gen;
			clr_fifo_full_int;
			clr_fifo_empty_int;
			clr_dma_finish_int;
			clr_dma_en;
			fifo_full_int;
			fifo_empty_int;
			dma_finish_int;


			in_sd_clk;
			sd_fifo_empty;
			sd_fifo_full;
			sd_fifo_re;
			in_end_command;
			in_end_command_and_response;
			in_transfer_complete;
			in_send_data_crc_error;
			in_receive_data_crc_error;
			in_response_timeout;
			in_cmd_current_state;
			in_read_to_error;
			one_bk_re_end;
			sd_clk_enable;
			hw_stop_clk;
			sd_clk_divider;
			sd_soft_reset;
			high_speed_clk;
			command_argument;
			command_index;
			block_size;
			block_len;
			sd_op_finish;
			block_number;
			data_direction;
			data_width;
			read_to;
			irq;
			out_response;
			out_longresponse;
			cmd_fsm_ready;
			data_fsm_ready;
);

// AHB signals
input hclk;			
input hrst_n;
input hsel;			
input hwrite;
input   [1:0]   htrans;		//IDLE、BUSY、NONSEQ、SEQ
input   [2:0]   hburst;		//burst类型，支持4、8、16 burst，incrementing/wrapping
input   [31:0]  hwadata;
input   [31:0]  haddr;
input   [2:0]   hsize;		//8、16、32  bits this design
input 			hready_in;	//other slave is no busy

output			hready_out;
output  [1:0]   hresp;
output  [31:0]  hrdata;

//-- host_dma
output  		dma_en;		
output 			dma_direc;	
output  [15:0]  transfer_size;	//dma transfer X byte
output  [31:0]  dma_addr;

// interrupt signals generater enable
output  fifo_full_int_gen;
output	fifo_empty_int_gen;
output	dma_finish_int_gen;
//clear interrupt signals
output	clr_fifo_full_int;
output	clr_fifo_empty_int;
output	clr_dma_finish_int;

input	clr_dma_en;
input	fifo_full_int;
input	fifo_empty_int;
input	dma_finish_int;

input [31:0]	response0;
input [31:0]	response1;
input [31:0]	response2;
input [31:0]	response3;

input			in_sd_clk;
input			sd_fifo_empty;
input			sd_fifo_full;
input			sd_fifo_re;
//state register signal
input			in_end_command;
input			in_end_command_and_response;
input			in_transfer_complete;
input			in_send_data_crc_error;
input			in_receive_data_crc_error;
input			in_response_timeout;
input [2:0]		in_cmd_current_state;
input			in_read_to_error;
input			one_bk_re_end;

output			sd_clk_enable;
output			hw_stop_clk;
output [7:0]	sd_clk_divider;
output			sd_soft_reset;
output			high_speed_clk;	
	
output [31:0]	command_argument;
output [5:0]	command_index;
output [10:0]	block_size;		
output [10:0]	block_len;
output			sd_op_finish;
output [31:0]	block_number;
output			data_direction;
output			data_width;
output [31:0]	read_to;		//read timeout
output			irq;				//interrupt to interrupt controler
output			out_response;	//respobnse 48bit
output			out_longresponse;	//longresponse 136bit
output			cmd_fsm_ready;	//fsm start signal
output			data_fsm_ready;	//fsm start signal

reg			cmd_fsm_ready;
reg	[31:0]	hrdtata;
reg			sd_clk_enable;
reg	[7:0]	sd_clk_divider;
reg			sd_soft_reset;
reg			hw_stop_clk_en;
reg			high_speed_clk;
reg	[31:0]	command_argument;
reg	[5:0]	command_index;
reg 		command_enable;
reg 		data_present;		//indicate if the current command has data transfer
reg	[1:0]	response_type;
reg	[10:0]	block_size;
reg	[10:0]	block_len;
reg	[10:0]	block_len_r;
reg	[31:0]	block_number;
reg			data_direction;
reg			data_width;
reg	[31:0]	read_to;
reg			read_to_error;

reg			dma_finish_interrupt_mask;
reg			end_command_and_response_interrupt_mask;
reg			sd_fifo_empty_interrupt_mask;	//tx fifo empty interrupt mask
reg			fifo_full_interrupt_mask;		//tx fifo full interrupt mask
reg			fifo_empty_interrupt_mask;
reg			sd_fifo_full_interrupt_mask;	//rx fifo full interrupt mask
reg			command_complete_interrupt_mask;
reg			transfer_complete_interrupt_mask;
reg			read_to_error_interrupt_mask;
reg			rx_fifo_write_error_interrupt_mask;
reg			tx_fifo_read_error_interrupt_mask;
reg			read_data_crc_error_interrupt_mask;
reg			write_data_crc_error_interrupt_mask;
reg			response_timeout_error_interrupt_mask;

reg			sd_fifo_empty_r;
reg			sd_fifo_full_r;
reg			end_command;
reg			transfer_complete;
reg			send_data_crc_error;
reg			receive_data_crc_error;
reg			response_timeout;
reg			out_response;
reg			out_longresponse;
reg			end_command_and_response;

//--host_dma
reg			dma_en;
reg			dma_direc;transfer_size;
reg	[15:0]	dma_addr;
reg	[31:0]	fifo_full_int_gen;
reg			fifo_empty_int_gen;
reg			dma_finish_int_gen;
reg			clr_fifo_full_int;
reg			clr_fifo_empty_int;
reg			clr_dma_finish_int;
//-------------internal register-------------
reg 		hwrite_r;
reg [2:0]	hsize_r;
reg [2:0]	hburst_r;
reg [1:0]	htrans_r;
reg [31:0]	haddr_r;

reg 		dma_end_tp;
reg 		dma_end;
reg 		dma_end_r;
reg 		cmd_ready_pre;
reg 		hw_stop_clk;

reg [31:0]	block_number_ahb;
reg [31:0]	block_num_tp;
reg 		one_bk_re_end_tp_1;
reg 		one_bk_re_end_tp_2;
reg 		one_bk_re_end_tp_3;
reg 		cmd_state_send_tp1;
reg 		cmd_state_send_tp2;
reg 		cmd_state_send_tp3;
reg 		in_end_cmd_and_resp_tp_1;
reg 		in_end_cmd_and_resp_tp_2;
reg 		in_end_cmd_and_resp_tp_3;
reg 		sd_fifo_empty_tp1;
reg 		sd_fifo_full_tp1;
reg 		in_end_cmd_tp_1;
reg 		in_end_cmd_tp_2;
reg 		in_end_cmd_tp_3;
reg 		in_transfer_end_tp_1;
reg 		in_transfer_end_tp_2;
reg 		in_transfer_end_tp_3;
reg 		in_rd_to_err_tp_1;
reg 		in_rd_to_err_tp_2;
reg 		in_rd_to_err_tp_3;
reg 		in_send_data_crc_err_tp_1;
reg 		in_send_data_crc_err_tp_2;
reg 		in_send_data_crc_err_tp_3;
reg 		in_receive_data_crc_err_tp_1;
reg 		in_receive_data_crc_err_tp_2;
reg 		in_receive_data_crc_err_tp_3;
reg 		in_resp_timeout_tp_1;
reg 		in_resp_timeout_tp_2;
reg 		in_resp_timeout_tp_3;
reg [31:0]	response0_ahb;
reg [31:0]	response1_ahb;
reg [31:0]	response2_ahb;
reg [31:0]	response3_ahb;
reg 		cmd_state_send;
reg 		ahb_wr_reg_en;
reg 		ahb_rd_reg_en;
//----------------------------------------------------------
// Beginning of main code 
//-------------------------------------------------------------

//------------------------------------------------------
// Generate AHB hready_out and hresp signals
//------------------------------------------------------------
//sd 的工作和这边没有关系，这里只是配置寄存器，配置完就根据寄存器内容进行工作
//这里若拉低了，DMA也不能工作
assign hready_out = 1'b1;	//这里能实现单周期配置寄存器，这里没有必要拉低
assign hresp =2'b0;			//respone always OK

//----------------------------------------------------------
//register AHB bus control and addr
//-----------------------------------------------------------

always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
	begin
		hwrite_r 	<= 1'b0;
        hsize_r 	<= 3'b0;
        hburst_r	<= 3'b0;
        htrans_r	<= 2'b0;
        haddr_r		<= 32'b0;
	end
	//hsel decoder 选中sd host，hread_in  other slave is IDLE
	else if (hsel && hready_in)
	begin
		hwrite_r 	<= hwrite;
        hsize_r 	<= hsize;
        hburst_r	<= hburst;
        htrans_r	<= htrans;
        haddr_r		<= haddr;
	end
	else begin
		hwrite_r 	<= 1'b0;
        hsize_r 	<= 3'b0;
        hburst_r	<= 3'b0;
        htrans_r	<= 2'b0;
        haddr_r		<= 32'b0;
	end
end

//-----------------------------------------------------------
// Generate ahb_wr_reg_en and ahb_rd_reg_en
//----------------------------------------------------------
//10 NOSNSEQ  11  SEQ
//ahb_wr_reg_en 写寄存器使能，ahb_rd_reg_en 读寄存器使能
assign ahb_wr_reg_en = hready_in && hwrite_r && (htrans_r == 2'b10 | htrans_r == 2'b11);
assign ahb_rd_reg_en = hsel && hready_in && !hwrite & (htrans_r == 2'b10 | htrans_r == 2'b11);
//write use hwrite_r (打拍)地址周期打完一拍刚好对上数据周期
//read use !hwrite (没打拍)

//-------------------------------------------------------------
// Generate block_len for fifo
//------------------------------------------------------------
// delay 2 clk  (blcok_size hclk domian) 2d (block_len in_sd_clk block_len)
// 因为in_sd_clk 也是hclk 分频得到，这里可以保证不出现亚稳态？？（他说的）
always @(posedge in_sd_clk or negedge hrst_n) begin
	if (!hrst_n)
	begin
		block_len   <= 11'd200;
		block_len_r <= 11'd200;
	end
	else
	begin
		block_len_r <= block_size;
		block_len <= block_len_r;
	end
end

//--------------------------------------------------------------
//DMA control operation
//DMA_CTRL_ADDR : 	[0] dma_en
//					[4]	dma_direc
//				[31:16]	transfer_size
//		   [15:5]/[3:1]	reserved
//-------------------------------------------------------------
always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
		dma_en <= 1'b0;
	else if (clr_dma_en)
		dma_en <= 1'b0;
	else if (ahb_wr_reg_en & (haddr_r[7:0]) == `DMA_CTRL_ADDR)
		dma_en <= hwdata[0];
end
// dma_en 单独写（没和下面的一起），dma_en是个traig信号，只有被clr才清零

always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
	begin
		dma_direc <= 1'b0;
		transfer_size <= 16'b0;
		dma_addr <= 32'b0;
	end
	else if (ahb_wr_reg_en)
	begin
		case (haddr_r[7:0])
			`DMA_CTRL_ADDR : begin
				dma_direc <= hwdata[4];
				transfer_size <= hwdata[31:16];
			end
			`DMA_ADDR_ADDR:
				dma_addr <= hwdata[31:0];
		endcase
	end
end
//------------------------------------------------
// INT_GEN_REG_ADDR
//---------------------------------------------------

always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
	begin
		fifo_full_int_gen <= 1'b1;
		fifo_empty_int_gen <= 1'b1;
		dma_finish_int_gen <= 1'b1;
	end
	else if (ahb_wr_reg_en && (haddr_r[7:0]== `INT_GEN_REG_ADDR))
	begin
		fifo_full_int_gen <= hwdata[0];
		fifo_empty_int_gen <= hwdata[4];
		dma_finish_int_gen <= hwdata[8];
	end
end

//-------------------------------------------------------------
//CLR_INT_REG_ADDR spec
//					[0] clr_fifo_full_int
//					[4]	clr_fifo_empty_int
//					[8]	clr_dma_finish_int
//		   		 [....]	reserved
//-------------------------------------------------------------
always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
	begin
		clr_fifo_full_int <= 1'b0;
		clr_fifo_empty_int <= 1'b0;
		clr_dma_finish_int <= 1'b0;
	end
	else if (ahb_wr_reg_en && (haddr_r[7:0]== `CLR_INT_REG_ADDR))
	begin
		clr_fifo_full_int <= hwdata[0];
		clr_fifo_empty_int <= hwdata[4];
		clr_dma_finish_int <= hwdata[8];
	end
	else 
	begin
		clr_fifo_full_int <= 1'b0;
		clr_fifo_empty_int <= 1'b0;
		clr_dma_finish_int <= 1'b0;
	end
end

//-----------------------------------------------
// Generate DATA FSM  start signals
//------------------------------------------------
//写准备好了（有效data_present）+fifo也写满了/commoand结束了
//sd-fifo  data_direction 1:to sd card   0:to fifo
assign data_fsm_ready = data_present && 
						(data_direction ? (sd_fifo_full):(in_end_command));

always @(posedge in_sd_clk or negedge hrst_n) begin
	if (!hrst_n)
	begin
		dma_end_tp 	<= 1'b0;
		dma_end 	<= 1'b0;
		dma_end_r 	<= 1'b0;
	end
	else 
	begin
		dma_end_tp 	<= dma_finish_int;
		dma_end 	<= dma_end_tp;
		dma_end_r 	<= dma_end;
	end
end

//sd op finish used to clear FIFO ptr
// dirction 1:写sd  0：读sd card 
//(!dma_end_r && dma_end)产生搬数据结束的脉冲
assign sd_op_finish = data_direction ? in_transfer_complete : (!dma_end_r && dma_end);

//hw stop sd_clk 
always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
	begin
		one_bk_re_end_tp_1 	<= 1'b0;
		one_bk_re_end_tp_2 	<= 1'b0;
		one_bk_re_end_tp_3 	<= 1'b0;
	end
	else 
	begin
		one_bk_re_end_tp_1 <= one_bk_re_end;
		one_bk_re_end_tp_2 <= one_bk_re_end_tp_1;
		one_bk_re_end_tp_3 <= one_bk_re_end_tp_2;
	end
end

always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
		hw_stop_clk <= 1'b0;
	else if (!data_direction && hw_stop_clk_en)
	begin
		if (!one_bk_re_end_tp_3 && one_bk_re_end_tp_2)
		//一个block 结束脉冲，停sd clk
			hw_stop_clk <= 1'b1;
		else if (dma_finish_int)
		//dma搬数据的时候可以停时钟，搬完了就不要在停时钟了
			hw_stop_clk <= 1'b0;
	end
	else 
		hw_stop_clk <= 1'b0;
end

//-----------------------------------------------
// Generate COMMAND FSM start signals
//-----------------------------------------------
assign cmd_state_send = (in_cmd_current_state == `CMD_STATE_SEND);

always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
	begin
		cmd_state_send_tp1 	<= 1'b0;
		cmd_state_send_tp2 	<= 1'b0;
		cmd_state_send_tp3 	<= 1'b0;
	end
	else 
	begin
		cmd_state_send_tp1 <= cmd_state_send;
		cmd_state_send_tp2 <= cmd_state_send_tp1;
		cmd_state_send_tp3 <= cmd_state_send_tp2;
	end
end

always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
		cmd_ready_pre <= 1'b0;
	else if (!cmd_state_send_tp3 && cmd_state_send_tp2)
	//已经开始发送了 cmd_ready_pre清零，下次在配的时候再发
		cmd_ready_pre <= 1'b0;
	else if (command_enable && (ahb_wr_reg_en &&(haddr_r[7：0] == `ARGUMENT_REGISTER_ADDR)))
		cmd_ready_pre <= 1'b1;
end

always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
		cmd_fsm_ready <= 1'b0;
	else
		cmd_fsm_ready <= cmd_ready_pre;
end
//-------------------------------
// Generate  interrupt signal
//---------------------------------------
//mask signal  mask the interrupt signal

assign irq =((dma_finish_int && !dma_finish_interrupt_mask) ||
			(end_command_and_response && !end_command_and_response_interrupt_mask) ||
			(sd_fifo_empty_r && !sd_fifo_empty_interrupt_mask) ||
			(fifo_full_int && !fifo_full_interrupt_mask) ||
			(fifo_empty_int && !fifo_empty_interrupt_mask) ||
			(sd_fifo_full_r && ! sd_fifo_full_interrupt_mask)||
			(end_command && !command_complete_interrupt_mask) ||
			(transfer_complete && !transfer_complete_interrupt_mask) ||
			(1'b0 && !rx_fifo_write_error_interrupt_mask) ||
			(1'b0 && !tx_fifo_read_error_interrupt_mask) ||
			(receive_data_crc_error && read_data_crc_error_interrupt_mask) ||
			(send_data_crc_error && !write_data_crc_error_interrupt_mask) ||
			(response_timeout && !response_timeout_error_interrupt_mask) ||
			(read_to_error && !read_to_error_interrupt_mask) );
			
//------------------------------------------------------------
always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
		in_end_cmd_and_resp_tp_1 	<= 1'b0;
		in_end_cmd_and_resp_tp_2 	<= 1'b0;
		in_end_cmd_and_resp_tp_3 	<= 1'b0;
	end
	else 
	begin
		in_end_cmd_and_resp_tp_1 <= in_end_command_and_response;
		in_end_cmd_and_resp_tp_2 <= in_end_cmd_and_resp_tp_1;
		in_end_cmd_and_resp_tp_3 <= in_end_cmd_and_resp_tp_2;
	end
end

always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
		end_command_and_response <= 1'b0;
	else if (cmd_ready_pre)
		end_command_and_response <= 1'b0;
	else if (!in_end_cmd_and_resp_tp_3 && in_end_cmd_and_resp_tp_2)
		end_command_and_response <= 1'b1;
end

//---------------------------------------------------
// Generate interrupt state tx fifo empty
//------------------------------------------------------
always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
	begin	
		sd_fifo_empty_tp1 <= 1'b0;
		sd_fifo_empty_r <= 1'b0;
	end
	else begin
		sd_fifo_empty_tp1 <= sd_fifo_empty;
		sd_fifo_empty_r <= sd_fifo_empty_tp1;
	end
end

//---------------------------------------------------
// Generate interrupt state tx fifo empty
//------------------------------------------------------
always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
	begin	
		sd_fifo_full_tp1 <= 1'b0;
		sd_fifo_full_r <= 1'b0;
	end
	else begin
		sd_fifo_full_tp1 <= sd_fifo_full;
		sd_fifo_full_r <= sd_fifo_full_tp1;
	end
end

//---------------------------------------------------
// Generate interrupt command sending fifo empty
//---------------------------------------------
always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
	begin
		in_end_cmd_tp_1 	<= 1'b0;
		in_end_cmd_tp_2 	<= 1'b0;
		in_end_cmd_tp_3 	<= 1'b0;
	end
	else 
	begin
		in_end_cmd_tp_1 <= in_end_command;
		in_end_cmd_tp_2 <= in_end_cmd_tp_1;
		in_end_cmd_tp_3 <= in_end_cmd_tp_2;
	end
end

always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
		end_command <= 1'b0;
	else if (cmd_ready_pre)
		end_command <= 1'b0;
	else if (!in_end_cmd_tp_3 && in_end_cmd_tp_2)
		end_command<= 1'b1;
end

//---------------------------------------------------
// Generate interrupt state data transfer complete
//---------------------------------------------
always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
	begin
		in_transfer_end_tp_1 	<= 1'b0;
		in_transfer_end_tp_2 	<= 1'b0;
		in_transfer_end_tp_3 	<= 1'b0;
	end
	else 
	begin
		in_transfer_end_tp_1 <= in_transfer_complete;
		in_transfer_end_tp_2 <= in_transfer_end_tp_1;
		in_transfer_end_tp_3 <= in_transfer_end_tp_2;
	end
end

always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
		transfer_complete <= 1'b0;
	else if (cmd_ready_pre)
		transfer_complete <= 1'b0;
	else if (!in_transfer_end_tp_3 && in_transfer_end_tp_2)
		transfer_complete<= 1'b1;
end

//---------------------------------------------------
// Generate interrupt state data read_data_crc_error_interrupt_mask timeout
//---------------------------------------------
always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n) 
	begin
		in_rd_to_err_tp_1 	<= 1'b0;
		in_rd_to_err_tp_2 	<= 1'b0;
		in_rd_to_err_tp_3 	<= 1'b0;
	end
	else 
	begin
		in_rd_to_err_tp_1 <= in_read_to_error;
		in_rd_to_err_tp_2 <= in_rd_to_err_tp_1;
		in_rd_to_err_tp_3 <= in_rd_to_err_tp_2;
	end
end

always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
		read_to_error <= 1'b0;
	else if (cmd_ready_pre)
		read_to_error <= 1'b0;
	else if (!in_rd_to_err_tp_3 && in_rd_to_err_tp_2)
		read_to_error<= 1'b1;
end

//---------------------------------------------------
// Generate interrupt state singal sending data crc error
//---------------------------------------------
always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n) 
	begin
		in_send_data_crc_err_tp_1 	<= 1'b0;
		in_send_data_crc_err_tp_2 	<= 1'b0;
		in_send_data_crc_err_tp_3 	<= 1'b0;
	end
	else 
	begin
		in_send_data_crc_err_tp_1 <= in_send_data_crc_error;
		in_send_data_crc_err_tp_2 <= in_send_data_crc_err_tp_1;
		in_send_data_crc_err_tp_3 <= in_send_data_crc_err_tp_2;
	end
end

always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
		send_data_crc_error <= 1'b0;
	else if (cmd_ready_pre)
		send_data_crc_error <= 1'b0;
	else if (!in_send_data_crc_err_tp_3 && in_send_data_crc_err_tp_2)
		send_data_crc_error<= 1'b1;
end

//---------------------------------------------------
// Generate interrupt state singal receive data crc error
//---------------------------------------------
always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n) 
	begin
		in_receive_data_crc_err_tp_1 	<= 1'b0;
		in_receive_data_crc_err_tp_2 	<= 1'b0;
		in_receive_data_crc_err_tp_3 	<= 1'b0;
	end
	else 
	begin
		in_receive_data_crc_err_tp_1 <= in_receive_data_crc_error;
		in_receive_data_crc_err_tp_2 <= in_receive_data_crc_err_tp_1;
		in_receive_data_crc_err_tp_3 <= in_receive_data_crc_err_tp_2;
	end
end

always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
		receive_data_crc_error <= 1'b0;
	else if (cmd_ready_pre)
		receive_data_crc_error <= 1'b0;
	else if (!in_receive_data_crc_err_tp_3 && in_receive_data_crc_err_tp_2)
		receive_data_crc_error<= 1'b1;
end

//---------------------------------------------------
// Generate interrupt state singal command response timeout
//---------------------------------------------
always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n) 
	begin
		in_resp_timeout_tp_1 	<= 1'b0;
		in_resp_timeout_tp_2 	<= 1'b0;
		in_resp_timeout_tp_3 	<= 1'b0;
	end
	else 
	begin
		in_resp_timeout_tp_1 <= in_resp_timeout;
		in_resp_timeout_tp_2 <= in_resp_timeout_tp_1;
		in_resp_timeout_tp_3 <= in_resp_timeout_tp_2;
	end
end

always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
		response_timeout <= 1'b0;
	else if (cmd_ready_pre)
		response_timeout <= 1'b0;
	else if (!in_resp_timeout_tp_3 && in_resp_timeout_tp_2)
		response_timeout<= 1'b1;
end

//---------------------------------------------------
// Config control register
//---------------------------------------------------
always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n) 
	begin
		sd_clk_enable		<= 1'b0;
		sd_clk_divider		<= 8'b0;			
		sd_soft_reset		<= 1'b1;			
		command_argument	<= 32'b0;			
		command_index		<= 6'b0;			
		command_enable		<= 1'b0;			
		data_present		<= 1'b0;		
		response_type		<= 2'b0;			
		block_size			<= 11'd200;
		block_number_ahb	<= 32'b0;			
		data_direction		<= 1'b0;		
		data_width			<= 1'b0;					
		read_to				<= 32'hffff_ffff;		
		dma_finish_interrupt_mask				<= 1'b0;	
		end_command_and_response_interrupt_mask	<= 1'b0;		
		fifo_full_interrupt_mask                <= 1'b0;
		command_complete_interrupt_mask		    <= 1'b0;
		transfer_complete_interrupt_mask	    <= 1'b0;
		read_to_error_interrupt_mask			<= 1'b0;
		rx_fifo_write_error_interrupt_mask      <= 1'b0;
		tx_fifo_read_error_interrupt_mask       <= 1'b0;
		read_data_crc_error_interrupt_mask      <= 1'b0;
		write_data_crc_error_interrupt_mask     <= 1'b0;
		response_timeout_error_interrupt_mask   <= 1'b0;
		fifo_empty_interrupt_mask               <= 1'b0;
		sd_fifo_full_interrupt_mask             <= 1'b0;
		sd_fifo_empty_interrupt_mask            <= 1'b0;
		hw_stop_clk_en                          <= 1'b0;
		high_speed_clk                          <= 1'b0;
		
	end
	else if (ahb_wr_reg_en)
	begin 
		case (haddr_r[7:0])
		
		`CLOCK_CONTROL_REGISTER_ADDR: begin
			sd_clk_enable <= hwdata[2];
			sd_clk_divider <= hwdata[15:8];
		end
		
		`SOFTWARE_RESET_REGISTER_ADDR: begin
			sd_soft_reset <= hwdata[0];
		end
		
		`CLK_EN_SPEED_UP_ADDR: begin
			hw_stop_clk_en <= hwdata[0];
			high_speed_clk <= hwdata[4];
		end
		
		`ARGUMENT_REGISTER_ADDR : begin
			command_argument <= hwdata;
		end
		
		`COMMAND_REGISTER_ADDR : begin
			command_index <= hwdata[10:5];
			command_enable<= hwdata[3];
			data_present  <= hwdata[2];
			response_type <= hwdata[1:0];
		end
			
		`BLOCK_SIZE_REGISTER_ADDR: begin
			block_size <= hwdata[10:0];
		end
		
		`BLOCK_COUNT_REGISTER_ADDR: begin
			block_number_ahb <= hwdata [31:0];
		end
		
		`TRANSFER_MODE_REGISTER_ADDR : begin
			data_direction <= hwdata[1];
			data_width <= hwdata[0];
		end
		
		`READ_TIMEOUT_CONTROL_REGISTER_ADDR: begin
			read_to <= hwdata[31:0];
		end
		
		`INTERRUPT_STATUS_MASK_REGISTER_ADDR: begin
			dma_finish_interrupt_mask				<= hwdata[13];
			end_command_and_response_interrupt_mask	<= hwdata[12];
			sd_fifo_full_interrupt_mask             <= hwdata[11];
			fifo_full_interrupt_mask                <= hwdata[10];
			fifo_empty_interrupt_mask               <= hwdata[9];
			sd_fifo_empty_interrupt_mask            <= hwdata[8;
			command_complete_interrupt_mask		    <= hwdata[7];
			transfer_complete_interrupt_mask	    <= hwdata[6];
		    read_to_error_interrupt_mask			<= hwdata[5];
		    rx_fifo_write_error_interrupt_mask      <= hwdata[4];
            tx_fifo_read_error_interrupt_mask       <= hwdata[3];
            read_data_crc_error_interrupt_mask      <= hwdata[2];
            write_data_crc_error_interrupt_mask     <= hwdata[1];
            response_timeout_error_interrupt_mask   <= hwdata[0];
        end
		endcase
	end
end

//response0-3 sd clk domain to ahb clk domain
//these data are generated in CMD_STATE_RECEIVE of cmd_current_state
//end_command_and_response can become the sync enable

always @(posedge hclk or negedge hrst_n) begin
	if (!hrst_n)
	begin
		response0_ahb <= 32'h0;
		response1_ahb <= 32'h0;
		response2_ahb <= 32'h0;
		response3_ahb <= 32'h0;
	end
	else if (!in_end_cmd_and_resp_tp_3 && in_end_cmd_and_resp_tp_2)
	begin
		response0_ahb <= response0;
		response1_ahb <= response1;
		response2_ahb <= response2;
		response3_ahb <= response3;
	end
end

//----------------------------------------------------------
// Read state register
//-----------------------------------------------------------
always @(posedge hclk or negedge hrst_n)
begin 
	if (!hrst_n)
		hrdata <= 32'b0;
	else if (ahb_rd_reg_en)
	begin
		case (haddr[7:0])
		`CLOCK_CONTROL_REGISTER_ADDR:
			hrdata <= {16'b0,sd_clk_divider,5'b0,sd_clk_enable,2'b0};
		`SOFTWARE_RESET_REGISTER_ADDR:
			hrdata <= {31'b0,sd_soft_reset};
		`CLK_EN_SPEED_UP_ADDR:
			hrdata <= {27'b0,high_speed_clk,3'b0,hw_stop_clk_en};
		`ARGUMENT_REGISTER_ADDR:
			hrdata <= command_argument;
		`COMMAND_REGISTER_ADDR:
			hrdata <= {21'b0,command_index,1'b0,command_enable,data_present,response_type};
		`BLOCK_SIZE_REGISTER_ADDR:
			hrdata <= {21'b0,block_size};
		`BLOCK_COUNT_REGISTER_ADDR:
			hrdata <= block_number_ahb;
		`TRANSFER_MODE_REGISTER_ADDR:
			hrdata <= {30'b0,data_direction,data_width};
		`READ_TIMEOUT_CONTROL_REGISTER_ADDR:
			hrdata <= read_to;
		`DMA_ADDR_ADDR :
			hrdata <= dma_addr;
		`DMA_CTRL_ADDR:
			hrdata <= {transfer_size,11'b0,dma_direc,3'b0,dma_en};
		`INT_GEN_REG_ADDR:
			hrdata <= {23'b0,dma_finish_int_gen,3'b0,fifo_empty_int_gen,3'b0,fifo_full_int_gen};
		`CLR_INT_REG_ADDR:
			hrdata <= {23'b0,clr_fifo_empty_int,3'b0,clr_fifo_full_int,3'b0,clr_dma_finish_int};
		`RESPONSE0_REGISTER_ADDR:
			hrdata <= response0_ahb;
		`RESPONSE1_REGISTER_ADDR:
			hrdata <= response1_ahb;
		`RESPONSE2_REGISTER_ADDR:
			hrdata <= response2_ahb;
		`RESPONSE3_REGISTER_ADDR:
			hrdata <= response3_ahb;
		`INTERRUPT_STATUS_REGISTER_ADDR:
		begin
			hrdata <= {
						18'b0,
						dma_finish_int,
						end_command_and_response,
						sd_fifo_empty_r,
						fifo_full_int,
						fifo_empty_int,
						sd_fifo_full_r,
						end_command,
						transfer_complete,
						read_to_error,
						1'b0,
						1'b0,
						receive_data_crc_error,
						send_data_crc_error,
						response_timeout};
		end
		default : hrdata <= 32'h0;
		endcase
	end
end

//-------------------------------------------------
always @(posedge in_sd_clk or neged  hrst_n) begin
	if (!hrst_n)
	begin
		block_num_tp <= 32'h0;
		block_number <= 32'g0;
	end
	else begin
		block_num_tp <= block_number_ahb;
		block_number <= block_num_tp;
	end
end

endmodule