module sd_clk(
    hclk,
    hrst_n,
    in_clk_divider,
    in_sd_clk_enable,
    hw_stop_clk,
    
    out_sd_clk_dft,
    fifo_sd_clk,

    in_TestMode
);
input       in_TestMode;
input       hclk;
input       hrst_n;
input [7:0] in_clk_divider;
input       in_sd_clk_enable;
input       hw_stop_clk;
output      fifo_sd_clk;
output      out_sd_clk_dft;

reg         out_sd_clk;
reg [7:0]   div_counter;
wire        divider_0_val;
wire        out_sd_clk_tp;
wire        clk_ena_stop;

assign  divider_0_val = (in_clk_divider == 8'b0 );
assign  clk_ena_stop = (!in_sd_clk_enable || hw_stop_clk);

always@(posedge hclk or negedge hrst_n) begin
    if(!hrst_n)
        out_sd_clk <= 8'b0;
    else if (clk_ena_stop)
        out_sd_clk <= out_sd_clk;
    else if (divider_0_val)
        out_sd_clk <= hclk;
    else if (div_counter == in_clk_divider-1)
        out_sd_clk <= ~out_sd_clk;
end

always@(posedge hclk or negedge hrst_n) begin
    if(!hrst_n)
        div_counter <= 8'b0;
    else if ( clk_ena_stop || div_0_val)
        div_counter <= 8'b0;
    else begin
        if(div_counter == in_clk_divider-1)
            div_counter <= 8'b0;
        else
            div_counter <= div_counter + 1;
    end
end

assign fifo_sd_clk = divider_0_val? hclk : out_sd_clk;
assign out_sd_clk_dft = (!in_sd_clk_enable || hw_stop_clk) ? 
                            1'b0 : (in_TestMode) ? 
                            hclk : (in_clk_divider == 8'b0) ?
                            hclk : out_sd_clk;

endmodule