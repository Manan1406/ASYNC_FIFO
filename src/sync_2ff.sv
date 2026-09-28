module sync_2ff #(
    parameter WIDTH = 4
)(
    input logic[WIDTH-1:0] gray_value,
    input logic clk,
    input logic rst,
    output logic[WIDTH-1:0] cross_gray_value
);
//body

logic[WIDTH-1:0] gray_value_intermediate;

always_ff@(posedge clk, negedge rst) begin

    if(!rst) begin
        gray_value_intermediate <= '0;
        cross_gray_value <= '0;
    end
    else begin
        gray_value_intermediate <= gray_value;
        cross_gray_value <= gray_value_intermediate;
    end

end

endmodule