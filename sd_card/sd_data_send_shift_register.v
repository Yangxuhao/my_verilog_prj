`define DATA_STATE_STOP                 4'b0000
`define DATA_STATE_IDLE                 4'b0001
`define DATA_STATE_WAIT_RECEIVE         4'b0010
`define DATA_STATE_RECEIVE              4'b0011
`define DATA_STATE_RECEIVE_CRC          4'b0100
`define DATA_STATE_RECEIVE_END_BIT      4'b0101
`define DATA_STATE_WAIT_SEND            4'b0110
`define DATA_STATE_SEND                 4'b0111
`define DATA_STATE_SEND_CRC             4'b1000
`define DATA_STATE_SEND_END_BIT         4'b1001
`define DATA_STATE_RECEIVE_CRC_STATUS   4'b1010
`define DATA_STATE_SEND_BUSY            4'b1011
`define DATA_STATE_SEND_START_BIT            4'b1100/////////////////////////
`define DATA_STATE_SEND_Z               4'b1101
`define DATA_STATE_SEND_P               4'b1110
module sd_data_send_shift_register (
        in_sd_clk,
        hrst_n,
        in_soft_reset,
        in_sd_data,
        sd_fifo_rdata,
        in_current_state,
        in_next_state,
        in_data_width,
        in_send_crc_counter,
        in_has_send_bit,
        in_interval_counter,
        in_high_speed_clk,
        out_serial_data,
        sd_fifo_re,
        out_crc_status_wrong,
        out_data_dir,
        out_data_half_delay
);

input               in_sd_clk;              //clock for sd card
input               hrst_n;                 //ahb signal
input               in_soft_reset;          //software reset
input   [3:0]       in_sd_data;             //data input drom sd card
input   [31:0]      sd_fifo_rdata;          //parallel data from tx fifo
input   [3:0]       in_current_state;       //current state of data fsm
input   [3:0]       in_next_state;          //next state of data fsm
input               in_data_width;          //data width 1:4bit 0:1bit
input   [3:0]       in_send_crc_counter;    //has sent crc bits
input   [13:0]      in_has_send_bit;        //has sent data bits
input   [1:0]       in_interval_counter;    //time interval
input               in_high_speed_clk;      

output  [3:0]       out_serial_data;        //original serial output data
output              sd_fifo_re;             //tx fifo read enable
output              out_crc_status_wrong;   //crc status wrong flag
output  [3:0]       out_data_dir;           //data direction   1:send
output  [3:0]       out_data_half_delay;    //serial output data to sd card


reg [3:0]   out_serial_data;
reg [31:0]  shift_reg0;
reg [15:0]  crc_reg0;
reg [15:0]  crc_reg1;
reg [15:0]  crc_reg2;
reg [15:0]  crc_reg3;
reg [15:0]  crc_shift_reg0;
reg [15:0]  crc_shift_reg1;
reg [15:0]  crc_shift_reg2;
reg [15:0]  crc_shift_reg3;
reg [0:31]  data_for_send;
reg [3:0]   crc_status_reg;
reg         sd_fifo_re;
reg         out_crc_status_wrong;
reg [3:0]   out_data_half_delay_tp;
reg [3:0]   data_dir_nes;

wire [31:0] sd_fifo_rdata_tp;
wire [3:0]  data_dir_pos;



//-------------------------------------------------------------------
// Beginning of main code
//---------------------------------------------------------------------
// Overview of the data send shift register operation
// The following key signals are used in the command send shift register
// out_data_dir is the data direction
// out_data_half_delay is the output data to sd card
// crc_reg3 is the denerated data crc register
// crc_reg2 is the denerated data crc register
// crc_reg1 is the denerated data crc register
// crc_reg0 is the denerated data crc register
// sd_fifo_rdata is the parallel data from tx fifo
// sd_fifo_re is the tx fifo read enable signal
// crc_status_reg is the crc status from sd card after sending data

//-----------------------------------------------------------------------
// Output data to sd card
//---------------------------------------------------------------------
//the data was sent at negedge
always @(negedge in_sd_clk or negedge hrst_n) begin
    if (!hrst_n) begin
        out_data_half_delay_tp <= 4'b1111;
    end
    else begin
        out_data_half_delay_tp <= out_serial_data;
		//???clk????????????????????????????????????
    end
end
//???????????????????????????????????????  ?????????????????????  ?????????????????????timing ??????????????????????????????
assign out_data_half_delay = in_high_speed_clk ? out_serial_data : out_data_half_delay_tp;
//-----------------------------------------------------------------------------
// Data direction   0:receive  1:send
//------------------------------------------------------------------------------
//??????????????????sd??????
assign data_dir_pos[0] = (  (in_current_state == `DATA_STATE_SEND_P)            ||
                            (in_current_state == `DATA_STATE_SEND_START_BIT)    ||
                            (in_current_state == `DATA_STATE_SEND)              ||
                            (in_current_state == `DATA_STATE_SEND_CRC)          ||
                            ((in_current_state == `DATA_STATE_SEND_END_BIT)     &&
                            ((in_interval_counter == 0) || (in_interval_counter == 1)))
                        );

assign data_dir_pos[1] = in_data_width && ((in_current_state == `DATA_STATE_SEND_P) ||
                            (in_current_state == `DATA_STATE_SEND_START_BIT)        ||
                            (in_current_state == `DATA_STATE_SEND)                  ||
                            (in_current_state == `DATA_STATE_SEND_CRC)              ||
                            ((in_current_state == `DATA_STATE_SEND_END_BIT)         &&
                            ((in_interval_counter == 0) || (in_interval_counter == 1)))
                        );

assign data_dir_pos[2] = in_data_width && ((in_current_state == `DATA_STATE_SEND_P) ||
                            (in_current_state == `DATA_STATE_SEND_START_BIT)        ||
                            (in_current_state == `DATA_STATE_SEND)                  ||
                            (in_current_state == `DATA_STATE_SEND_CRC)              ||
                            ((in_current_state == `DATA_STATE_SEND_END_BIT)         &&
                            ((in_interval_counter == 0) || (in_interval_counter == 1)))
                        );

assign data_dir_pos[3] = in_data_width && ((in_current_state == `DATA_STATE_SEND_P) ||
                            (in_current_state == `DATA_STATE_SEND_START_BIT)        ||
                            (in_current_state == `DATA_STATE_SEND)                  ||
                            (in_current_state == `DATA_STATE_SEND_CRC)              ||
                            ((in_current_state == `DATA_STATE_SEND_END_BIT)         &&
                            ((in_interval_counter == 0) || (in_interval_counter == 1)))
                        );
// assign data_dir_pos[1] = in_data_width && data_dir_pos[0];
// assign data_dir_pos[2] = data_dir_pos[1];
// assign data_dir_pos[3] = data_dir_pos[1];

always @(negedge in_sd_clk or negedge hrst_n) begin
    if (!hrst_n) begin
        data_dir_nes <= 4'b0;
    end
    else begin
            data_dir_nes <= {data_dir_pos[3],data_dir_pos[2],data_dir_pos[1],data_dir_pos[0]};
    end
end
// out_data_dir ???????????????????????????
assign out_data_dir = in_high_speed_clk ? data_dir_pos :data_dir_nes;

//---------------------------------------------------------------------------------
// Generate output data to sd card 1ibt and 4bit mode and receive crc status bits
// -------------------------------------------------------------------------------
always @(posedge in_sd_clk or negedge hrst_n) begin
    if (!hrst_n) begin
        shift_reg0 <= 32'b0;
        out_serial_data <= 4'b1111;
        crc_status_reg <= 4'b0;
        crc_shift_reg0 <= 16'b0;
        crc_shift_reg1 <= 16'b0;
        crc_shift_reg2 <= 16'b0;
        crc_shift_reg3 <= 16'b0;
    end
    else if (!in_soft_reset) 
    begin
        shift_reg0 <= 32'b0;
        out_serial_data <= 4'b1111;
        crc_status_reg <= 4'b0;
        crc_shift_reg0 <= 16'b0;
        crc_shift_reg1 <= 16'b0;
        crc_shift_reg2 <= 16'b0;
        crc_shift_reg3 <= 16'b0;
    end
    else 
    begin
        if(!in_data_width)
        begin
            if (in_current_state == `DATA_STATE_SEND_START_BIT)
			//send start bit
                out_serial_data[0] <= 1'b0;
            else if (in_current_state == `DATA_STATE_SEND)
            begin
			//???32???bit???????????????????????????fifo??????????????????
                if (in_has_send_bit[4:0] == 5'b0)
                    {out_serial_data[0],shift_reg0} <= {sd_fifo_rdata_tp,1'b0};
                else 
                    {out_serial_data[0],shift_reg0} <= {shift_reg0,1'b0};
					//????????????????????????????????????
            end
            else if (in_current_state == `DATA_STATE_SEND_CRC)
            begin
                if (in_send_crc_counter == 0)
                    {out_serial_data[0],crc_shift_reg0} <= {crc_reg0,1'b0};
                else 
                    {out_serial_data[0],crc_shift_reg0} <= {crc_shift_reg0,1'b0};
            end
            else if (in_current_state == `DATA_STATE_SEND_END_BIT)
            begin
                out_serial_data[0] <= 1'b1;
            end
			//DATA_STATE_RECEIVE_CRC_STATUS ??????sd ???????????????????????????????????????crc_status
            else if (in_current_state == `DATA_STATE_RECEIVE_CRC_STATUS)
            begin
                crc_status_reg <= {crc_status_reg[2:0], in_sd_data[0]};
            end
            else if (in_current_state == `DATA_STATE_WAIT_SEND)
            begin
                crc_status_reg <= 4'b0;
            end
        end
        else
        begin
            if (in_current_state == `DATA_STATE_SEND_START_BIT)
                out_serial_data <= 4'b0;
            else if (in_current_state == `DATA_STATE_SEND)
            begin
                if (in_has_send_bit[2:0] == 3'b0)
                    {out_serial_data,shift_reg0} <= {sd_fifo_rdata_tp,4'b0};
                else
                    {out_serial_data,shift_reg0} <= {shift_reg0,4'b0};
            end
            else if (in_current_state == `DATA_STATE_SEND_CRC)
            begin
                if(in_send_crc_counter == 0)
                begin
                    {out_serial_data[3],crc_shift_reg3} <= {crc_reg3,1'b0};
                    {out_serial_data[2],crc_shift_reg2} <= {crc_reg2,1'b0};
                    {out_serial_data[1],crc_shift_reg1} <= {crc_reg1,1'b0};
                    {out_serial_data[0],crc_shift_reg0} <= {crc_reg0,1'b0};
                end
                else
                begin
                    {out_serial_data[3],crc_shift_reg3} <= {crc_shift_reg3,1'b0};
                    {out_serial_data[2],crc_shift_reg2} <= {crc_shift_reg2,1'b0};
                    {out_serial_data[1],crc_shift_reg1} <= {crc_shift_reg1,1'b0};
                    {out_serial_data[0],crc_shift_reg0} <= {crc_shift_reg0,1'b0};
                end
            end
            else if (in_current_state == `DATA_STATE_RECEIVE_CRC_STATUS)
            begin
                crc_status_reg <= {crc_status_reg[2:0],in_sd_data[0]};
            end
            else if (in_current_state ==`DATA_STATE_WAIT_SEND)
                crc_status_reg <= 4'b0;
        end
    end

end

//----------------------------------------------------
// Generate output data crc
//----------------------------------------------------

always @(posedge in_sd_clk or negedge hrst_n) begin
    if (!hrst_n) begin
        crc_reg3 <= 16'b0;
        crc_reg2 <= 16'b0;
        crc_reg1 <= 16'b0;
        crc_reg0 <= 16'b0;
    end
    else begin 
        if (!in_soft_reset) begin
        crc_reg3 <= 16'b0;
        crc_reg2 <= 16'b0;
        crc_reg1 <= 16'b0;
        crc_reg0 <= 16'b0;
        end
        if (in_current_state == `DATA_STATE_WAIT_SEND)begin
        crc_reg3 <= 16'b0;
        crc_reg2 <= 16'b0;
        crc_reg1 <= 16'b0;
        crc_reg0 <= 16'b0;
        end
    end
    if (in_current_state == `DATA_STATE_SEND)
    begin
        if (!in_data_width)
        begin
            crc_reg0[0] <= data_for_send[in_has_send_bit[4:0]] ^ crc_reg0[15];
            crc_reg0[1] <= crc_reg0[0];
            crc_reg0[2] <= crc_reg0[1];
            crc_reg0[3] <= crc_reg0[2];
            crc_reg0[4] <= crc_reg0[3];
            crc_reg0[5] <= crc_reg0[4] ^ data_for_send[in_has_send_bit[4:0]] ^ crc_reg0[15];
            crc_reg0[6] <= crc_reg0[5];
            crc_reg0[7] <= crc_reg0[6];
            crc_reg0[8] <= crc_reg0[7];
            crc_reg0[9] <= crc_reg0[8];
            crc_reg0[10] <= crc_reg0[9];
            crc_reg0[11] <= crc_reg0[10];
            crc_reg0[12] <= crc_reg0[11] ^ data_for_send[in_has_send_bit[4:0] ^ crc_reg0[15]];
            crc_reg0[13] <= crc_reg0[12];
            crc_reg0[14] <= crc_reg0[13];
            crc_reg0[15] <= crc_reg0[14];
        end
        else
        begin
            crc_reg3[0] <= data_for_send[{in_has_send_bit[2:0],2'b0}] ^ crc_reg3[15];
            crc_reg3[1] <= crc_reg3[0];
            crc_reg3[2] <= crc_reg3[1];
            crc_reg3[3] <= crc_reg3[2];
            crc_reg3[4] <= crc_reg3[3];
            crc_reg3[5] <= crc_reg3[4] ^ data_for_send[{in_has_send_bit[2:0],2'b0}] ^ crc_reg3[15];
            crc_reg3[6] <= crc_reg3[5];
            crc_reg3[7] <= crc_reg3[6];
            crc_reg3[8] <= crc_reg3[7];
            crc_reg3[9] <= crc_reg3[8];
            crc_reg3[10] <= crc_reg3[9];
            crc_reg3[11] <= crc_reg3[10];
            crc_reg3[12] <= crc_reg3[11] ^ data_for_send[{in_has_send_bit[2:0],2'b0}] ^ crc_reg3[15];
            crc_reg3[13] <= crc_reg3[12];
            crc_reg3[14] <= crc_reg3[13];
            crc_reg3[15] <= crc_reg3[14];
            
            crc_reg2[0] <= data_for_send[{in_has_send_bit[2:0],2'b0}+1] ^ crc_reg2[15];
            crc_reg2[1] <= crc_reg2[0];
            crc_reg2[2] <= crc_reg2[1];
            crc_reg2[3] <= crc_reg2[2];
            crc_reg2[4] <= crc_reg2[3];
            crc_reg2[5] <= crc_reg2[4] ^ data_for_send[{in_has_send_bit[2:0],2'b0}+1] ^ crc_reg2[15];
            crc_reg2[6] <= crc_reg2[5];
            crc_reg2[7] <= crc_reg2[6];
            crc_reg2[8] <= crc_reg2[7];
            crc_reg2[9] <= crc_reg2[8];
            crc_reg2[10] <= crc_reg2[9];
            crc_reg2[11] <= crc_reg2[10];
            crc_reg2[12] <= crc_reg2[11] ^ data_for_send[{in_has_send_bit[2:0],2'b0}+1] ^ crc_reg2[15];
            crc_reg2[13] <= crc_reg2[12];
            crc_reg2[14] <= crc_reg2[13];
            crc_reg2[15] <= crc_reg2[14];
           

            crc_reg1[0] <= data_for_send[{in_has_send_bit[2:0],2'b0}+2] ^ crc_reg1[15];
            crc_reg1[1] <= crc_reg1[0];
            crc_reg1[2] <= crc_reg1[1];
            crc_reg1[3] <= crc_reg1[2];
            crc_reg1[4] <= crc_reg1[3];
            crc_reg1[5] <= crc_reg1[4] ^ data_for_send[{in_has_send_bit[2:0],2'b0}+2] ^ crc_reg1[15];
            crc_reg1[6] <= crc_reg1[5];
            crc_reg1[7] <= crc_reg1[6];
            crc_reg1[8] <= crc_reg1[7];
            crc_reg1[9] <= crc_reg1[8];
            crc_reg1[10] <= crc_reg1[9];
            crc_reg1[11] <= crc_reg1[10];
            crc_reg1[12] <= crc_reg1[11] ^ data_for_send[{in_has_send_bit[2:0],2'b0}+2] ^ crc_reg1[15];
            crc_reg1[13] <= crc_reg1[12];
            crc_reg1[14] <= crc_reg1[13];
            crc_reg1[15] <= crc_reg1[14];

            crc_reg0[0] <= data_for_send[{in_has_send_bit[2:0],2'b0}+3] ^ crc_reg0[15];
            crc_reg0[1] <= crc_reg0[0];
            crc_reg0[2] <= crc_reg0[1];
            crc_reg0[3] <= crc_reg0[2];
            crc_reg0[4] <= crc_reg0[3];
            crc_reg0[5] <= crc_reg0[4] ^ data_for_send[{in_has_send_bit[2:0],2'b0}+3] ^ crc_reg0[15];
            crc_reg0[6] <= crc_reg0[5];
            crc_reg0[7] <= crc_reg0[6];
            crc_reg0[8] <= crc_reg0[7];
            crc_reg0[9] <= crc_reg0[8];
            crc_reg0[10] <= crc_reg0[9];
            crc_reg0[11] <= crc_reg0[10];
            crc_reg0[12] <= crc_reg0[11] ^ data_for_send[{in_has_send_bit[2:0],2'b0}+3] ^ crc_reg0[15];
            crc_reg0[13] <= crc_reg0[12];
            crc_reg0[14] <= crc_reg0[13];
            crc_reg0[15] <= crc_reg0[14];
        end
    end
end

//------------------------------------------------------
// Generate data for send
//------------------------------------------------------
assign sd_fifo_rdata_tp = {sd_fifo_rdata[7:0],sd_fifo_rdata[15:8],sd_fifo_rdata[23:16],sd_fifo_rdata[31:24]};
//data_for_send???[0:31] ???sd_fifo_rdata_tp ??????????????????????????????crc?????????
always @(*) begin
    data_for_send = 32'b0;
    if (in_current_state == `DATA_STATE_SEND)
        data_for_send = sd_fifo_rdata_tp;
end

//-------------------------------------------------------
// GEnerate tx fifo read enable signal
//-------------------------------------------------------

always @(*) begin
    sd_fifo_re = 1'b0;
    if (!in_data_width)
    begin
        if(((in_current_state == `DATA_STATE_SEND_START_BIT) && (in_has_send_bit[4:0] == 5'b0)) ||
            ((in_current_state == `DATA_STATE_SEND) && (in_next_state == `DATA_STATE_SEND) && (in_has_send_bit[4:0] == 5'b11111)))
            sd_fifo_re = 1'b1;
    end
    else begin
        if(((in_current_state == `DATA_STATE_SEND_START_BIT) && (in_has_send_bit[2:0] == 3'b0)) ||
            ((in_current_state == `DATA_STATE_SEND) && (in_next_state == `DATA_STATE_SEND) && (in_has_send_bit[2:0] == 3'b111)))
            sd_fifo_re = 1'b1;
    end
end

//---------------------------------------------------------------
// Generate crc status wrong flag after sending data to sd card
//---------------------------------------------------------------
//crc????????????3bit?????????010???OK???????????????????????????????????????????????????
//???????????????3???010????????????????????????????????????????????????
always @(*) begin
    out_crc_status_wrong =1'b0;
    //  there crc_status_reg maybe sould be 4'b0100  ,see the wave
    if((in_current_state == `DATA_STATE_SEND_BUSY) && !(crc_status_reg == 4'b0010))
        out_crc_status_wrong =1'b1;
end

endmodule