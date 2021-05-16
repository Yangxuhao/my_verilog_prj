module sd_cmd_send_shift_regidter (
    in_sd_clk,              //clock for sd card
    hrst_n,                 //ahb signal
    in_soft_reset,          //software reset
    in_current_state,       //current state od command fsm
    in_command_index,       //command index
    in_command_argument,    //command argument
    in_has_send_bit,        //has sent command bits counter      
    in_high_speed_clk,
    out_sd_cmd,             //output command for sd card
    out_cmd_dir             //command direction  0:receive  1:send

);

input   in_sd_clk;
input   hrst_n;
input   in_soft_reset;
input [2:0]  in_current_state;
input [5:0]   in_command_index;
input [31:0]  in_command_argument;
input [5:0]  in_has_send_bit;
input   in_high_speed_clk;

output   out_sd_cmd;
output   out_cmd_dir;

reg [7:0]   shift_r;
reg [6:0]   crc_reg;
reg [0:7]   cmd_for_send;
reg cmd_dir_neg;
reg cmd_dir_pos;
reg sd_cmd_pos;
reg sd_cmd_neg;

//---------------------------------------------------
// Beginning if main code
//---------------------------------------------------
// Overview iof the command send shift register operation
//the following key signals are used in the command send shift register
//out_cmd_dir is the command direction
//out_sd_cmd is the output command to sd card
//crc_reg is the generated command crc register
//----------------------------------------------------
// Determine the command direction  0:receive 1:send
//----------------------------------------------------

always @(posedge in_sd_clk or negedge hrst_n) begin
    if(!hrst_n)
        cmd_dir_pos <= 1'b0;
	else if (in_current_state == `CMD_STATE_SEND)
		cmd_dir_pos <= 1'b1;
	else if (in_current_state == `CMD_STATE_STOP)
		cmd_dir_pos <= 1'b0;
	else if (in_current_state == `CMD_STATE_WAIT_RECEIVE)
		cmd_dir_pos <= 1'b0;
end

always @(negedge in_sd_clk or negedge hrst_n) begin
    if(!hrst_n)
        cmd_dir_neg <= 1'b0;
    else
        cmd_dir_neg <= cmd_dir_pos;
end
// cmd_dir_neg 比 cmd_dir_pos delay 半个周期

assign out_cmd_dir = in_high_speed_clk ? cmd_dir_pos : cmd_dir_neg;

//------------------------------------------------------------
// Divide the command payload in to 5 8bit parts
// -----------------------------------------------------------
always @(*) begin
    cmd_for_send = 8'b0;
//这里先写了cmd_for_send=0，等下就不用else了，有什么优点来着？？
//下面的case不包含所有的情况，
    if (in_current_state == `CMD_STATE_SEND)
        begin
            case(in_has_send_bit)
                6'b0,6'b1,6'b10,6'b11,6'b100,6'b101,6'b110,6'b111:
				//{start bit，transmit bit，in_command_index}  差7bit crc  1bit end bit
                    cmd_for_send = {1'b0,1'b1,in_command_index};
                6'b001000,6'b001001,6'b001010,6'b001011,6'b001100,6'b001101,6'b001110,6'b001111:
                    cmd_for_send = {in_command_argument[31:24]};
                6'b010000,6'b010001,6'b010010,6'b010011,6'b010100,6'b010101,6'b010110,6'b010111:
                    cmd_for_send = {in_command_argument[23:16]};
                6'b011000,6'b011001,6'b011010,6'b011011,6'b011100,6'b011101,6'b011110,6'b011111:
                    cmd_for_send = {in_command_argument[15:8]};
                6'b100000,6'b100001,6'b100010,6'b100011,6'b100100,6'b100101,6'b100110,6'b100111:
                    cmd_for_send = {in_command_argument[7:0]};
            endcase
        end
end

//------------------------------------------------------------
// Send command
//------------------------------------------------------------

always @(posedge in_sd_clk or negedge hrst_n) begin
    if(!hrst_n)
        begin
            sd_cmd_pos <= 1'b1;
            shift_r <= 8'b0;
        end
    else if(!in_soft_reset)
        begin
            sd_cmd_pos <= 1'b1;
            shift_r <= 8'b0;
        end
    else
        begin
            if(in_current_state == `CMD_STATE_SEND)
                begin
				//每8bit的开始进到case判断是第几个8bit，拿数据
				//不是开始，则每个clk移位并行转串行
				//这里最后可以不补0，把shift_r改小1bit
                    if(in_has_send_bit[2:0] == 3'b0)
                        begin
                            case(in_has_send_bit)
                                6'b000000:
                                    {sd_cmd_pos,shift_r} <= {1'b0,1'b1,in_command_index,1'b0};
                                6'b001000:
                                    {sd_cmd_pos,shift_r} <= {in_command_argument[31:24],1'b0};
                                6'b010000:
                                    {sd_cmd_pos,shift_r} <= {in_command_argument[23:16],1'b0};
                                6'b011000:
                                    {sd_cmd_pos,shift_r} <= {in_command_argument[15:8],1'b0};
                                6'b100000:
                                    {sd_cmd_pos,shift_r} <= {in_command_argument[7:0],1'b0};
								6'b101000:
                                    {sd_cmd_pos,shift_r} <= {crc_reg,1'b1,1'b0};
                            endcase
                        end
                    else
                        {sd_cmd_pos,shift_r} <= {shift_r,1'b0};
                end
        end
end

always @(negedge in_sd_clk or negedge hrst_n) begin
    if (!hrst_n)
        sd_cmd_neg <= 1'b0;
    else
        sd_cmd_neg <= sd_cmd_pos;
end

assign out_sd_cmd = in_high_speed_clk ? sd_cmd_pos : sd_cmd_neg;
//让接收方更好的满足时序，pos建立时间不满足，那么移动半个周期可能就满足了
//-------------------------------------------------------------
// Genetate the command crc for sending
// ------------------------------------------------------------

always @(posedge in_sd_clk or negedge hrst_n) begin
    if(!hrst_n)
        crc_reg <= 7'b0;
    else if (!in_soft_reset)
        crc_reg <= 7'b0;
    else
        if((in_current_state == `CMD_STATE_SEND) &&
            (in_has_send_bit >= 6'b0)            &&
            (in_has_send_bit < 6'd40))
        begin
            crc_reg[0] <= cmd_for_send[in_has_send_bit[2:0]]^crc_reg[6];
            crc_reg[1] <= crc_reg[0];
            crc_reg[2] <= crc_reg[1];
            crc_reg[3] <= cmd_for_send[in_has_send_bit[2:0]]^crc_reg[6]^crc_reg[2];
            crc_reg[4] <= crc_reg[3];
            crc_reg[5] <= crc_reg[4];
            crc_reg[6] <= crc_reg[5];
        end
        else
            crc_reg <= 7'b0;
end

endmodule