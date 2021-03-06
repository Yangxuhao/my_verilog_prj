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
`define DATA_STATE_SEND_START_BIT       4'b1100/////////////////////////
`define DATA_STATE_SEND_Z               4'b1101
`define DATA_STATE_SEND_P               4'b1110
module sd_data_fsm(
    in_sd_clk,              //clock for sd card
    hrst_n,                 //ahb reset signal
    in_soft_reset,          //software reset
    in_data_ready,          //data fsm ready signal
    sd_fifo_full,
    in_sd_data,             //data input from sd card
    in_data_direction,      //data direction 1:write 0:read
    need_to_receive_byte,   //block length
    need_to_receive_block, //block number
    need_to_send_byte,      //block length
    need_to_send_block,     //block number
    in_data_width,          //data width 1:4bit  0:1bit
    in_read_to,             //time of read data fsm
    current_state,          //current state of data fsm
    next_state,             //next state of data fsm
    has_send_bit_counter_en,//has send bit counter enable
    send_crc_counter,       //has sent crc bits counter
    has_send_bit,           //has send data bits counter
    receive_crc_status_counter, //has receive crc status bits counter
    has_receive_bit,        //has receive data bits counter
    out_transfer_complete,  //indicate data transfer has completed 
    interval_counter,       //time interval between data end bit and crc status
    out_read_to_error,      //read timeout error flag
    one_bk_re_end
);                      
input           in_sd_clk;              //clock for sd card
input           hrst_n;                 //ahb reset signal
input           in_soft_reset;          //software reset
input           in_data_ready;
input           sd_fifo_full;
input [3:0]     in_sd_data;             //data input from sd card
input           in_data_direction;      //data direction 1:write 0:read
input [10:0]    need_to_receive_byte;   //block length
input [10:0]    need_to_receive_block; //block number
input [31:0]    need_to_send_byte;      //block length
input [31:0]    need_to_send_block;     //block number
input           in_data_width;          //data width 1:4bit  0:1bit
input [31:0]    in_read_to;             //time of read data fsm

output [3:0]    current_state;        //current state of data fsm
output [3:0]    next_state;            //next state of data fsm
output          has_send_bit_counter_en;//has send bit counter enable
output [3:0]    send_crc_counter;       //has sent crc bits counter
output [13:0]   has_send_bit;           //has send data bits counter
output [1:0]    receive_crc_status_counter; //has receive crc status bits counter
output [13:0]   has_receive_bit;        //has receive data bits counter
output reg     out_transfer_complete;  //indicate data transfer has completed 
output [1:0]    interval_counter;       //time interval between data end bit and crc status
output          out_read_to_error;      //read timeout error flag
output          one_bk_re_end;/////////////////////////////////////////////////
reg     [3:0]       current_state;
reg     [3:0]       next_state;
reg                 has_receive_bit_counter_en;
reg                 has_send_bit_counter_en;
reg                 has_receive_block_counter_en;
reg                 has_send_block_counter_en;
reg                 receive_crc_counter_en;
reg                 read_resp_time_counter_en;
reg                 send_crc_counter_en;
reg                 interval_counter_en;
reg                 receive_crc_status_counter_en;
reg     [13:0]      has_receive_bit;
reg     [13:0]      has_send_bit;
reg     [31:0]      has_receive_block;
reg     [31:0]      has_send_block;
reg     [3:0]       receive_crc_counter;
reg     [31:0]      read_resp_time_counter;
reg     [31:0]      send_crc_counter;
reg     [1:0]       interval_counter;
reg     [1:0]       receive_crc_status_counter;
reg                 out_read_to_error;

wire                one_bk_re_end_tp;
reg                 one_bk_re_end;

wire    [13:0]      need_to_send_bit;
wire    [13:0]      need_to_receive_bit;
wire    [13:0]      need_to_send_bit_4;
wire    [13:0]      need_to_receive_bit_4;

//--------------------------------------------------------
// Beginning of main code 
//--------------------------------------------------------
//????????????/???????????????????????????bit????????????????????????
assign      need_to_send_bit = {need_to_send_byte,3'b0};
assign      need_to_receive_bit = {need_to_receive_byte,3'b0};
assign      need_to_send_bit_4 = {2'b0,need_to_send_byte,1'b0};
assign      need_to_receive_bit_4 = {2'b0,need_to_receive_byte,1'b0};

//----------------------------------------------------------------------
// Data fsm
//----------------------------------------------------------------------
// State description:
//
// DATA_STATE_STOP is the reset state of data fsm
// DATA_STATE_IDLE determines the data direction
// DATA_STATE_WAIT_RECEIVE waits for the start bit of data from sd card
// DATA_STATE_RECEIVE receives payload data from sd card
// DATA_STATE_RECEIVE_CRC receives crc of data from sd card
// DATA_STATE_RECEIVE_END_BIT receives the end bit of data from sd card and
// determines if all blocks have sent
// DATA_STATE_WAIT_SEND waits to send data to sd card until sd is not busy
// DATA_STATE_SEND sends payload data to sd card
// DATA_STATE_SEND_CRC send crc of data to sd card
// DATA_STATE_SEND_END_BIT send the end bit of the data to sd card
// DATA_STATE_RECEIVE_CRC_STATUS receives the crc status of data sent from sd
// card
// DATA_STATE_SEND_BUSY determines if all blcks have been sent
// DATA_STATE_START_BIT sends the start bit of data to sd card
// DATA_STATE_SEND_Z sends a Z bit to sd card
// DATA_STATE_SEND_P sends a P bit to sd card

//fsm1
always @ (posedge in_sd_clk or negedge hrst_n) begin
    if(!hrst_n)
        current_state <= `DATA_STATE_STOP;
    else if(!in_soft_reset)
        current_state <= `DATA_STATE_STOP;
    else 
        current_state <= next_state;
end

//fsm2
always @(*) begin
    out_read_to_error = 1'b0;
    case (current_state)
        `DATA_STATE_STOP: //0
        begin
            has_receive_bit_counter_en      = 1'b0;
            has_send_bit_counter_en         = 1'b0;
            has_receive_block_counter_en    = 1'b0;
            has_send_block_counter_en       = 1'b0;
            receive_crc_counter_en          = 1'b0;
            read_resp_time_counter_en       = 1'b0; 
            send_crc_counter_en             = 1'b0;
            interval_counter_en             = 1'b0;
            receive_crc_status_counter_en   = 1'b0;
            out_transfer_complete           = 1'b0;
            
            if(in_data_ready)
                next_state = `DATA_STATE_IDLE;
            else
                next_state = `DATA_STATE_STOP;
        end

        `DATA_STATE_IDLE: //1
		//IDLE???????????????/???sd???????????????????????????
        begin
            has_receive_bit_counter_en      = 1'b0;
            has_send_bit_counter_en         = 1'b0;
            has_receive_block_counter_en    = 1'b0;
            has_send_block_counter_en       = 1'b0;
            receive_crc_counter_en          = 1'b0;
            read_resp_time_counter_en       = 1'b0; 
            send_crc_counter_en             = 1'b0;
            interval_counter_en             = 1'b0;
            receive_crc_status_counter_en   = 1'b0;
            out_transfer_complete           = 1'b0;
            if(!in_data_direction)
                next_state = `DATA_STATE_WAIT_RECEIVE;
            else
                next_state = `DATA_STATE_WAIT_SEND;
        end

        `DATA_STATE_WAIT_RECEIVE: //2
		//?????????????????????????????????blcok??????STOP????????????STOP???
		//???????????????????????????data[0]==0,????????????????????????
        begin
            has_receive_bit_counter_en      = 1'b0;
            has_send_bit_counter_en         = 1'b0;
            has_receive_block_counter_en    = 1'b0;
            has_send_block_counter_en       = 1'b0;
            receive_crc_counter_en          = 1'b0;
            read_resp_time_counter_en       = 1'b0; 
            send_crc_counter_en             = 1'b0;
            interval_counter_en             = 1'b0;
            receive_crc_status_counter_en   = 1'b0;

            if (has_receive_block == need_to_receive_block)
            begin
                next_state = `DATA_STATE_STOP;
                out_transfer_complete = 1'b1;
            end
            else if (read_resp_time_counter == in_read_to)
            begin
                next_state = `DATA_STATE_STOP;
                out_read_to_error = 1'b1;
            end
            else begin
                if(!in_sd_data[0])
                    next_state = `DATA_STATE_RECEIVE;
                else begin
                    next_state = `DATA_STATE_WAIT_RECEIVE;
                    read_resp_time_counter_en = 1'b1;
                end
            end
        end
        
        `DATA_STATE_RECEIVE: //3
		//?????????????????????????????????bit???????????????????????????bit????????????
		//????????????crc????????????
        begin
            //has_receive_bit_counter_en      = 1'b0;
            has_send_bit_counter_en         = 1'b0;
            has_receive_block_counter_en    = 1'b0;
            has_send_block_counter_en       = 1'b0;
            receive_crc_counter_en          = 1'b0;
            read_resp_time_counter_en       = 1'b0; 
            send_crc_counter_en             = 1'b0;
            interval_counter_en             = 1'b0;
            receive_crc_status_counter_en   = 1'b0;
            out_transfer_complete           = 1'b0;

            if(!in_data_width) begin
                if (has_receive_bit == need_to_receive_bit - 1)
                begin
                    next_state = `DATA_STATE_RECEIVE_CRC;
                    has_receive_bit_counter_en = 1'b0;
                end
                else begin
                    next_state = `DATA_STATE_RECEIVE;
                    has_receive_bit_counter_en = 1'b1;
                end
            end
            else begin
                if (has_receive_bit == (need_to_receive_bit_4 - 1))
                begin
                    next_state = `DATA_STATE_RECEIVE_CRC;
                    has_receive_bit_counter_en = 1'b0;
                end
                else begin
                    next_state = `DATA_STATE_RECEIVE;
                    has_receive_bit_counter_en = 1'b1;
                end
            end
        end

        `DATA_STATE_RECEIVE_CRC: //4
		//??????crc?????????????????????crc???????????????????????????????????????end_bit??????
        begin
            has_receive_bit_counter_en      = 1'b0;
            has_send_bit_counter_en         = 1'b0;
            has_receive_block_counter_en    = 1'b0;
            has_send_block_counter_en       = 1'b0;
            //receive_crc_counter_en          = 1'b0;
            read_resp_time_counter_en       = 1'b0; 
            send_crc_counter_en             = 1'b0;
            interval_counter_en             = 1'b0;
            receive_crc_status_counter_en   = 1'b0;
            out_transfer_complete           = 1'b0;
            if(receive_crc_counter == 15) begin
                next_state =`DATA_STATE_RECEIVE_END_BIT;
                receive_crc_counter_en = 1'b0;
            end
            else begin
                next_state = `DATA_STATE_RECEIVE_CRC;
                receive_crc_counter_en = 1'b1;
            end
        end
        
        `DATA_STATE_RECEIVE_END_BIT: //5
		//??????end_bit?????????block??????????????????STOP
		//??????blcok??????????????????????????????????????????????????????????????????block???????????????1
        begin
            has_receive_bit_counter_en      = 1'b0;
            has_send_bit_counter_en         = 1'b0;
            //has_receive_block_counter_en    = 1'b0;
            has_send_block_counter_en       = 1'b0;
            receive_crc_counter_en          = 1'b0;
            read_resp_time_counter_en       = 1'b0; 
            send_crc_counter_en             = 1'b0;
            interval_counter_en             = 1'b0;
            receive_crc_status_counter_en   = 1'b0;
            out_transfer_complete           = 1'b0;
            if(has_receive_block == (need_to_receive_block - 1)) begin
                next_state = `DATA_STATE_STOP;
                has_receive_block_counter_en = 1'b0;
                out_transfer_complete = 1'b1;
            end
            else begin
                next_state = `DATA_STATE_WAIT_RECEIVE;
                has_receive_block_counter_en = 1'b1;
            end
        end

        `DATA_STATE_WAIT_SEND: //6
        begin
            has_receive_bit_counter_en      = 1'b0;
            has_send_bit_counter_en         = 1'b0;
            has_receive_block_counter_en    = 1'b0;
            has_send_block_counter_en       = 1'b0;
            receive_crc_counter_en          = 1'b0;
            read_resp_time_counter_en       = 1'b0; 
            send_crc_counter_en             = 1'b0;
            interval_counter_en             = 1'b0;
            receive_crc_status_counter_en   = 1'b0;
            out_transfer_complete           = 1'b0;
            if(sd_fifo_full) begin
                if(has_send_block == need_to_send_block)
                begin
                    next_state = `DATA_STATE_STOP;
                    out_transfer_complete = 1'b1;
                end
                else begin
                   // if (!in_sd_data[0])
				    if (in_sd_data[0])
                        next_state = `DATA_STATE_WAIT_SEND;
                    else
                        next_state = `DATA_STATE_SEND_Z;
                end
            end
            else
                next_state = `DATA_STATE_WAIT_SEND;
        end
        
        `DATA_STATE_SEND: //7
		//????????????bit?????????????????????????????????crc???
        begin
            has_receive_bit_counter_en      = 1'b0;
            //has_send_bit_counter_en         = 1'b0;
            has_receive_block_counter_en    = 1'b0;
            has_send_block_counter_en       = 1'b0;
            receive_crc_counter_en          = 1'b0;
            read_resp_time_counter_en       = 1'b0; 
            send_crc_counter_en             = 1'b0;
            interval_counter_en             = 1'b0;
            receive_crc_status_counter_en   = 1'b0;
            out_transfer_complete           = 1'b0;
            if (!in_data_width)
            begin
                if (has_send_bit == (need_to_send_bit - 1))///////////////////////////////////////yxh
                begin
                    next_state = `DATA_STATE_SEND_CRC;
                    has_send_bit_counter_en = 1'b0;
                end
                else begin
                    next_state = `DATA_STATE_SEND;
                    has_send_bit_counter_en = 1'b1;
                end
            end
            else begin
                if (has_send_bit == (need_to_send_bit_4 - 1))
                begin
                    next_state = `DATA_STATE_SEND_CRC;
                    has_send_bit_counter_en = 1'b0;
                end
                else begin
                    next_state = `DATA_STATE_SEND;
                    has_send_bit_counter_en = 1'b1;
                end
            end
        end
        
        `DATA_STATE_SEND_CRC: //8
		//????????????crc bit??????????????????crc?????????end bit
        begin
            has_receive_bit_counter_en      = 1'b0;
            has_send_bit_counter_en         = 1'b0;
            has_receive_block_counter_en    = 1'b0;
            has_send_block_counter_en       = 1'b0;
            receive_crc_counter_en          = 1'b0;
            read_resp_time_counter_en       = 1'b0; 
            //send_crc_counter_en             = 1'b0;
            interval_counter_en             = 1'b0;
            receive_crc_status_counter_en   = 1'b0;
            out_transfer_complete           = 1'b0;
            if (send_crc_counter == 15)
            begin
                next_state = `DATA_STATE_SEND_END_BIT;
                send_crc_counter_en = 1'b0;
            end
            else begin
                next_state = `DATA_STATE_SEND_CRC;
                send_crc_counter_en = 1'b1;
            end
        end

        `DATA_STATE_SEND_END_BIT: //9
		//?????????endbit ?????????????????????????????????????????????
		//??????????????????????????????????????????????????????????????????
        begin
            has_receive_bit_counter_en      = 1'b0;
            has_send_bit_counter_en         = 1'b0;
            has_receive_block_counter_en    = 1'b0;
            has_send_block_counter_en       = 1'b0;
            receive_crc_counter_en          = 1'b0;
            read_resp_time_counter_en       = 1'b0; 
            send_crc_counter_en             = 1'b0;
            interval_counter_en             = 1'b0;
            receive_crc_status_counter_en   = 1'b0;
            out_transfer_complete           = 1'b0;
			//??????4???????????????EZZS
            if (interval_counter == 3)
            begin
                next_state = `DATA_STATE_RECEIVE_CRC_STATUS;
                interval_counter_en = 1'b0;
            end
            else begin
                next_state = `DATA_STATE_SEND_END_BIT;
                interval_counter_en = 1'b1;
            end
        end

        `DATA_STATE_RECEIVE_CRC_STATUS ://10
		
        begin
            has_receive_bit_counter_en      = 1'b0;
            has_send_bit_counter_en         = 1'b0;
            has_receive_block_counter_en    = 1'b0;
            has_send_block_counter_en       = 1'b0;
            receive_crc_counter_en          = 1'b0;
            read_resp_time_counter_en       = 1'b0; 
            send_crc_counter_en             = 1'b0;
            interval_counter_en             = 1'b0;
            receive_crc_status_counter_en   = 1'b0;
            out_transfer_complete           = 1'b0;
			//??????4???????????????status(3bit)+E
            if (receive_crc_status_counter == 3)
            begin
                next_state = `DATA_STATE_SEND_BUSY;
                receive_crc_status_counter_en = 1'b0;
            end
            else begin
                next_state = `DATA_STATE_RECEIVE_CRC_STATUS;
                receive_crc_status_counter_en = 1'b1;
            end
        end

        `DATA_STATE_SEND_BUSY: //11
		//??????????????????????????????????????????block???????????????
		//??????STATE_STOP????????????????????????
		//???????????????DATA_STATE_WAIT_SEND???????????????????????????????????????????????????
        begin
            has_receive_bit_counter_en      = 1'b0;
            has_send_bit_counter_en         = 1'b0;
            has_receive_block_counter_en    = 1'b0;
            //has_send_block_counter_en       = 1'b0;
            receive_crc_counter_en          = 1'b0;
            read_resp_time_counter_en       = 1'b0; 
            send_crc_counter_en             = 1'b0;
            interval_counter_en             = 1'b0;
            receive_crc_status_counter_en   = 1'b0;
            out_transfer_complete           = 1'b0;
            if (has_send_block == (need_to_send_block - 1))
            begin
                next_state = `DATA_STATE_STOP;
                has_send_block_counter_en = 1'b0;
                out_transfer_complete = 1'b1;
            end
            else begin
                next_state = `DATA_STATE_WAIT_SEND;
                has_send_block_counter_en = 1'b1;
            end
        end

        `DATA_STATE_SEND_START_BIT: //12
        begin
            has_receive_bit_counter_en      = 1'b0;
            has_send_bit_counter_en         = 1'b0;
            has_receive_block_counter_en    = 1'b0;
            has_send_block_counter_en       = 1'b0;
            receive_crc_counter_en          = 1'b0;
            read_resp_time_counter_en       = 1'b0; 
            send_crc_counter_en             = 1'b0;
            interval_counter_en             = 1'b0;
            receive_crc_status_counter_en   = 1'b0;
            out_transfer_complete           = 1'b0;
            next_state = `DATA_STATE_SEND;
        end

        `DATA_STATE_SEND_Z:
        begin
            has_receive_bit_counter_en      = 1'b0;
            has_send_bit_counter_en         = 1'b0;
            has_receive_block_counter_en    = 1'b0;
            has_send_block_counter_en       = 1'b0;
            receive_crc_counter_en          = 1'b0;
            read_resp_time_counter_en       = 1'b0; 
            send_crc_counter_en             = 1'b0;
            interval_counter_en             = 1'b0;
            receive_crc_status_counter_en   = 1'b0;
            out_transfer_complete           = 1'b0;
            next_state = `DATA_STATE_SEND_P;
        end

        `DATA_STATE_SEND_P:
        begin
            has_receive_bit_counter_en      = 1'b0;
            has_send_bit_counter_en         = 1'b0;
            has_receive_block_counter_en    = 1'b0;
            has_send_block_counter_en       = 1'b0;
            receive_crc_counter_en          = 1'b0;
            read_resp_time_counter_en       = 1'b0; 
            send_crc_counter_en             = 1'b0;
            interval_counter_en             = 1'b0;
            receive_crc_status_counter_en   = 1'b0;
            out_transfer_complete           = 1'b0;
            next_state = `DATA_STATE_SEND_START_BIT;
        end

        default:
        begin
            has_receive_bit_counter_en      = 1'b0;
            has_send_bit_counter_en         = 1'b0;
            has_receive_block_counter_en    = 1'b0;
            has_send_block_counter_en       = 1'b0;
            receive_crc_counter_en          = 1'b0;
            read_resp_time_counter_en       = 1'b0; 
            send_crc_counter_en             = 1'b0;
            interval_counter_en             = 1'b0;
            receive_crc_status_counter_en   = 1'b0;
            out_transfer_complete = 1'b0;
            next_state = `DATA_STATE_STOP;
        end
    endcase
end

assign  one_bk_re_end_tp = (current_state == `DATA_STATE_RECEIVE_END_BIT);

always @(posedge in_sd_clk or negedge hrst_n) begin
    if (!hrst_n)
		one_bk_re_end <= 1'b0;
	else 
		one_bk_re_end <= one_bk_re_end_tp;
end
//---------------------------------------------------------------------
// Has received data bits from sd card counter
//---------------------------------------------------------------------
always @(posedge in_sd_clk or negedge hrst_n) begin
    if (!hrst_n)
        has_receive_bit <= 14'b0;
    else if (!in_soft_reset)
        has_receive_bit <= 14'b0;
    else if (current_state == `DATA_STATE_RECEIVE_CRC)
        has_receive_bit <= 14'b0;
    else if (has_receive_bit == (need_to_send_block - 1))
        has_receive_bit <= 14'b0;
    else if (has_receive_bit_counter_en)
        has_receive_bit <= has_receive_bit + 1;
end

//---------------------------------------------------------------------
// Read data from sd card response time counter
//---------------------------------------------------------------------
always @(posedge in_sd_clk or negedge hrst_n) begin
    if (!hrst_n)
        read_resp_time_counter <= 32'b0;
    else if (!in_soft_reset)
        read_resp_time_counter <= 32'b0;
    else if (current_state == `DATA_STATE_STOP)
        read_resp_time_counter <= 32'b0;
    else if (read_resp_time_counter == in_read_to)
        read_resp_time_counter <= 32'b0;
    else if (read_resp_time_counter_en)
        read_resp_time_counter <= read_resp_time_counter + 1;
end       

//---------------------------------------------------------------------
// Has sent data bits counter
//---------------------------------------------------------------------
always @(posedge in_sd_clk or negedge hrst_n) begin
    if (!hrst_n)
        has_send_bit <= 14'b0;
    else if (!in_soft_reset)
        has_send_bit <= 14'b0;
    else if (current_state == `DATA_STATE_SEND_CRC)
        has_send_bit <= 14'b0;
    else if (has_send_bit_counter_en)
        has_send_bit <= has_send_bit + 1;
end

//---------------------------------------------------------------------
// Has received crc number counter
//---------------------------------------------------------------------
always @(posedge in_sd_clk or negedge hrst_n) begin
    if (!hrst_n)
        receive_crc_counter <= 14'b0;
    else if (!in_soft_reset)
        receive_crc_counter <= 14'b0;
    else if (receive_crc_counter == 15)
        receive_crc_counter <= 14'b0;
    else if (receive_crc_counter_en)
        receive_crc_counter <= receive_crc_counter + 1;
end

//---------------------------------------------------------------------
// Has received block number counter
//---------------------------------------------------------------------
always @(posedge in_sd_clk or negedge hrst_n) begin
    if (!hrst_n)
        has_receive_block <= 32'b0;
    else if (!in_soft_reset)
        has_receive_block <= 32'b0;
    else if (current_state == `DATA_STATE_STOP)
        has_receive_block <= 32'b0;
    else if (has_receive_block_counter_en)
        has_receive_block <= has_receive_block + 1;
end


//---------------------------------------------------------------------
// Has sent block number counter
//---------------------------------------------------------------------
always @(posedge in_sd_clk or negedge hrst_n) begin
    if (!hrst_n)
        has_send_block <= 32'b0;
    else if (!in_soft_reset)
        has_send_block <= 32'b0;
    else if (current_state == `DATA_STATE_STOP)
        has_send_block <= 32'b0;
    else if (has_send_block_counter_en)
        has_send_block <= has_send_block + 1;
end

//---------------------------------------------------------------------
// Time interval between the end bit of sent data and crc status counter
//---------------------------------------------------------------------
always @(posedge in_sd_clk or negedge hrst_n) begin
    if (!hrst_n)
        interval_counter <= 2'b0;
    else if (!in_soft_reset)
        interval_counter <= 2'b0;
    else if (interval_counter == 3)
        interval_counter <= 2'b0;
    else if (interval_counter_en)
        interval_counter <= interval_counter + 1;
end

//---------------------------------------------------------------------
// Has receive crc status bits counter
//---------------------------------------------------------------------
always @(posedge in_sd_clk or negedge hrst_n) begin
    if (!hrst_n)
        receive_crc_status_counter <= 2'b0;
    else if (!in_soft_reset)
        receive_crc_status_counter <= 2'b0;
    else if (receive_crc_status_counter == 3)
        receive_crc_status_counter <= 14'b0;
    else if (receive_crc_status_counter_en)
        receive_crc_status_counter <= receive_crc_status_counter + 1;
end

//---------------------------------------------------------------------
// Has sent crc bits counter
//---------------------------------------------------------------------
always @(posedge in_sd_clk or negedge hrst_n) begin
    if (!hrst_n)
        send_crc_counter <= 14'b0;
    else if (!in_soft_reset)
        send_crc_counter <= 14'b0;
    else if (send_crc_counter == 15)
        send_crc_counter <= 14'b0;
    else if (send_crc_counter_en)
        send_crc_counter <= send_crc_counter + 1;
end

endmodule