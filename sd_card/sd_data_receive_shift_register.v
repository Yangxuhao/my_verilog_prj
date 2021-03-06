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
module sd_data_receive_shift_register(
        in_sd_clk,                  //clock for sd card
        hrst_n,                     
        in_soft_reset,              //software reset
        in_current_state,           //surrent state of data fsm
        in_serial_data,             //data input from sd card
        in_data_width,              //data width 1:4bit 0:1bit
        in_has_receive_bit,         //has received data bits
        sd_fifo_wdata,              //output parallel data to rx fifo
        sd_fifo_we,                 //host writes rx_fifo
        out_receive_data_crc_error  //receive data crc error flag
);
input               in_sd_clk;                  //clock for sd card
input               hrst_n;                     
input               in_soft_reset;              //software reset
input   [3:0]       in_current_state;           //surrent state of data fsm
input   [3:0]       in_serial_data;             //data input from sd card
input               in_data_width;              //data width 1:4bit 0:1bit
input   [13:0]      in_has_receive_bit;         //has received data bits

output  [31:0]      sd_fifo_wdata;              //output parallel data to rx fifo
output              sd_fifo_we;                 //host writes rx_fifo
output              out_receive_data_crc_error;  //receive data crc error flag

reg                 out_receive_data_crc_error;
reg                 sd_fifo_we;
reg     [15:0]      crc_reg0;
reg     [15:0]      crc_reg1;
reg     [15:0]      crc_reg2;
reg     [15:0]      crc_reg3;
reg     [15:0]      generate_crc_reg0;
reg     [15:0]      generate_crc_reg1;
reg     [15:0]      generate_crc_reg2;
reg     [15:0]      generate_crc_reg3;
reg     [31:0]      shift_reg;
reg                 out_write_receive_fifo;

//------------------------------------------------------------
// Beginning of main code
//------------------------------------------------------------
// Overview of the data receive shift register operation
// the following key signals are used in the data receive shift register
// in_serial_data is the data input from sd card
// out_write_receive_fifo is the rx fifo write enable signal
// crc_regx is the received data crc
// generate_crc_regx is the generated data crc
// out_receive_data_crc_error is the data receiveing crc error flag

//assign sd_fifo_wdata =shift_reg;
assign sd_fifo_wdata = {shift_reg[7:0],shift_reg[15:8],shift_reg[23:16],shift_reg[31:24]};

//------------------------------------------------------
// Register rx fifo write enable signal
//------------------------------------------------------

always @(posedge in_sd_clk or negedge hrst_n) begin
    if (!hrst_n)
        sd_fifo_we <= 1'b0;
    else if (!in_soft_reset)
        sd_fifo_we <= 1'b0;
    else 
        sd_fifo_we <= out_write_receive_fifo;
end

//-------------------------------------------------------------
// Serial to Parallel conversion
// ------------------------------------------------------------

always @(posedge in_sd_clk or negedge hrst_n) begin
    if(!hrst_n)
        shift_reg <= 32'b0;
    else if (!in_soft_reset)
        shift_reg <= 32'b0;
    else begin
        if (in_current_state == `DATA_STATE_RECEIVE)
        begin
            if(!in_data_width)
                shift_reg <= {shift_reg[30:0],in_serial_data[0]};
            else
                shift_reg <= {shift_reg[27:0],in_serial_data};
        end
    end
end

//-------------------------------------------------------------------
//Generate rx fifo write enable signal
//-------------------------------------------------------------------
always @(*) begin
    out_write_receive_fifo = 1'b0;
    if (!in_data_width) 
    begin
        if ((in_current_state == `DATA_STATE_RECEIVE) && (in_has_receive_bit[4:0] == 5'b11111))
            out_write_receive_fifo = 1'b1;
    end
    else begin
        if((in_current_state == `DATA_STATE_RECEIVE) && (in_has_receive_bit[2:0] == 3'b111))
            out_write_receive_fifo = 1'b1;
    end
end

//--------------------------------------------------------------------
// Receive data crc 1bit and 4bit mode
//--------------------------------------------------------------------

always @(posedge in_sd_clk or negedge hrst_n)begin
    if (!hrst_n)
    begin
        crc_reg0 <= 16'b0;
        crc_reg1 <= 16'b0;
        crc_reg2 <= 16'b0;
        crc_reg3 <= 16'b0;
    end
    else if (in_soft_reset)
    begin
        crc_reg0 <= 16'b0;
        crc_reg1 <= 16'b0;
        crc_reg2 <= 16'b0;
        crc_reg3 <= 16'b0;
    end
    else if ((in_current_state == `DATA_STATE_RECEIVE_END_BIT))
    begin
        crc_reg0 <= 16'b0;
        crc_reg1 <= 16'b0;
        crc_reg2 <= 16'b0;
        crc_reg3 <= 16'b0;
    end
    else if (in_current_state == `DATA_STATE_RECEIVE_CRC)
    begin
        if(in_data_width == 1'b0)
            crc_reg0 <= {crc_reg0[14:0],in_serial_data[0]};
        else begin
            crc_reg0 <= {crc_reg0[14:0],in_serial_data[0]};
            crc_reg1 <= {crc_reg1[14:0],in_serial_data[1]};
            crc_reg2 <= {crc_reg2[14:0],in_serial_data[2]};
            crc_reg3 <= {crc_reg3[14:0],in_serial_data[3]};
        end
    end
end

//-----------------------------------------------------
// Generate data crc for 1bit and 4bit mode
//-----------------------------------------------------
 always @(posedge in_sd_clk or negedge hrst_n) begin
     if (!hrst_n)
     begin
         generate_crc_reg0 <= 16'b0;
         generate_crc_reg1 <= 16'b0;
         generate_crc_reg2 <= 16'b0;
         generate_crc_reg3 <= 16'b0;
    end
    else if (!in_soft_reset)
    begin
         generate_crc_reg0 <= 16'b0;
         generate_crc_reg1 <= 16'b0;
         generate_crc_reg2 <= 16'b0;
         generate_crc_reg3 <= 16'b0;
     end
     else if ((in_current_state == `DATA_STATE_RECEIVE_END_BIT))
     begin
         generate_crc_reg0 <= 16'b0;
         generate_crc_reg1 <= 16'b0;
         generate_crc_reg2 <= 16'b0;
         generate_crc_reg3 <= 16'b0;
     end
     else if (in_current_state == `DATA_STATE_RECEIVE)
     begin
         if (in_data_width == 1'b0)
         begin
             generate_crc_reg0[0] <= in_serial_data[0] ^ generate_crc_reg0[15];
             generate_crc_reg0[1] <= generate_crc_reg0[0];
             generate_crc_reg0[2] <= generate_crc_reg0[1];
             generate_crc_reg0[3] <= generate_crc_reg0[2];
             generate_crc_reg0[4] <= generate_crc_reg0[3];
             generate_crc_reg0[5] <= generate_crc_reg0[4] ^ in_serial_data[0] ^ generate_crc_reg0[15];
             generate_crc_reg0[6] <= generate_crc_reg0[5];
             generate_crc_reg0[7] <= generate_crc_reg0[6];
             generate_crc_reg0[8] <= generate_crc_reg0[7];
             generate_crc_reg0[9] <= generate_crc_reg0[8];
             generate_crc_reg0[10] <= generate_crc_reg0[9];
             generate_crc_reg0[11] <= generate_crc_reg0[10];
             generate_crc_reg0[12] <= generate_crc_reg0[11] ^ in_serial_data[0] ^ generate_crc_reg0[15];
             generate_crc_reg0[13] <= generate_crc_reg0[12];
             generate_crc_reg0[14] <= generate_crc_reg0[13];
             generate_crc_reg0[15] <= generate_crc_reg0[14];
         end
         else begin
             generate_crc_reg0[0] <= in_serial_data[0] ^ generate_crc_reg0[15];
             generate_crc_reg0[1] <= generate_crc_reg0[0];
             generate_crc_reg0[2] <= generate_crc_reg0[1];
             generate_crc_reg0[3] <= generate_crc_reg0[2];
             generate_crc_reg0[4] <= generate_crc_reg0[3];
             generate_crc_reg0[5] <= generate_crc_reg0[4] ^ in_serial_data[0] ^ generate_crc_reg0[15];
             generate_crc_reg0[6] <= generate_crc_reg0[5];
             generate_crc_reg0[7] <= generate_crc_reg0[6];
             generate_crc_reg0[8] <= generate_crc_reg0[7];
             generate_crc_reg0[9] <= generate_crc_reg0[8];
             generate_crc_reg0[10] <= generate_crc_reg0[9];
             generate_crc_reg0[11] <= generate_crc_reg0[10];
             generate_crc_reg0[12] <= generate_crc_reg0[11] ^ in_serial_data[0] ^ generate_crc_reg0[15];
             generate_crc_reg0[13] <= generate_crc_reg0[12];
             generate_crc_reg0[14] <= generate_crc_reg0[13];
             generate_crc_reg0[15] <= generate_crc_reg0[14];

             generate_crc_reg1[0] <= in_serial_data[1] ^ generate_crc_reg1[15];
             generate_crc_reg1[1] <= generate_crc_reg1[0];
             generate_crc_reg1[2] <= generate_crc_reg1[1];
             generate_crc_reg1[3] <= generate_crc_reg1[2];
             generate_crc_reg1[4] <= generate_crc_reg1[3];
             generate_crc_reg1[5] <= generate_crc_reg1[4] ^ in_serial_data[1] ^ generate_crc_reg1[15];
             generate_crc_reg1[6] <= generate_crc_reg1[5];
             generate_crc_reg1[7] <= generate_crc_reg1[6];
             generate_crc_reg1[8] <= generate_crc_reg1[7];
             generate_crc_reg1[9] <= generate_crc_reg1[8];
             generate_crc_reg1[10] <= generate_crc_reg1[9];
             generate_crc_reg1[11] <= generate_crc_reg1[10];
             generate_crc_reg1[12] <= generate_crc_reg1[11] ^ in_serial_data[1] ^ generate_crc_reg1[15];
             generate_crc_reg1[13] <= generate_crc_reg1[12];
             generate_crc_reg1[14] <= generate_crc_reg1[13];
             generate_crc_reg1[15] <= generate_crc_reg1[14];

             generate_crc_reg2[0] <= in_serial_data[2] ^ generate_crc_reg2[15];
             generate_crc_reg2[1] <= generate_crc_reg2[0];
             generate_crc_reg2[2] <= generate_crc_reg2[1];
             generate_crc_reg2[3] <= generate_crc_reg2[2];
             generate_crc_reg2[4] <= generate_crc_reg2[3];
             generate_crc_reg2[5] <= generate_crc_reg2[4] ^ in_serial_data[2] ^ generate_crc_reg2[15];
             generate_crc_reg2[6] <= generate_crc_reg2[5];
             generate_crc_reg2[7] <= generate_crc_reg2[6];
             generate_crc_reg2[8] <= generate_crc_reg2[7];
             generate_crc_reg2[9] <= generate_crc_reg2[8];
             generate_crc_reg2[10] <= generate_crc_reg2[9];
             generate_crc_reg2[11] <= generate_crc_reg2[10];
             generate_crc_reg2[12] <= generate_crc_reg2[11] ^ in_serial_data[2] ^ generate_crc_reg2[15];
             generate_crc_reg2[13] <= generate_crc_reg2[12];
             generate_crc_reg2[14] <= generate_crc_reg2[13];
             generate_crc_reg2[15] <= generate_crc_reg2[14];

             generate_crc_reg3[0] <= in_serial_data[3] ^ generate_crc_reg3[15];
             generate_crc_reg3[1] <= generate_crc_reg3[0];
             generate_crc_reg3[2] <= generate_crc_reg3[1];
             generate_crc_reg3[3] <= generate_crc_reg3[2];
             generate_crc_reg3[4] <= generate_crc_reg3[3];
             generate_crc_reg3[5] <= generate_crc_reg3[4] ^ in_serial_data[3] ^ generate_crc_reg3[15];
             generate_crc_reg3[6] <= generate_crc_reg3[5];
             generate_crc_reg3[7] <= generate_crc_reg3[6];
             generate_crc_reg3[8] <= generate_crc_reg3[7];
             generate_crc_reg3[9] <= generate_crc_reg3[8];
             generate_crc_reg3[10] <= generate_crc_reg3[9];
             generate_crc_reg3[11] <= generate_crc_reg3[10];
             generate_crc_reg3[12] <= generate_crc_reg3[11] ^ in_serial_data[3] ^ generate_crc_reg3[15];
             generate_crc_reg3[13] <= generate_crc_reg3[12];
             generate_crc_reg3[14] <= generate_crc_reg3[13];
             generate_crc_reg3[15] <= generate_crc_reg3[14];
         end
     end
end

 //----------------------------------------------------------
 // Compare generated data crc with received data crc
 //----------------------------------------------------------
 
always @(*) begin
     out_receive_data_crc_error = 1'b0;
     if(!in_data_width)begin
         if ((in_current_state == `DATA_STATE_RECEIVE_END_BIT) && !(crc_reg0 == generate_crc_reg0))
             out_receive_data_crc_error = 1'b1;
     end
     else begin
         if((in_current_state == `DATA_STATE_RECEIVE_END_BIT) && (((crc_reg0 != generate_crc_reg0))||((crc_reg1 != generate_crc_reg1)) ||((crc_reg2 != generate_crc_reg2))) ||((crc_reg3 != generate_crc_reg3)) )
             out_receive_data_crc_error = 1'b1;
     end
end
endmodule