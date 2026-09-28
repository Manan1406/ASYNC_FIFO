module gray_counter #(
    parameter WIDTH = 4
)(
    input logic clk,
    input logic rst,
    input logic en,
    output logic [WIDTH-1:0] gray_count,
    output logic [WIDTH-1:0] binary_count
);

always_ff@(posedge clk, negedge rst) begin
    if(!rst) begin
        binary_count <= '0;
    end else begin
        if(en) begin
            binary_count <= binary_count + 1;
        end
    end
end

assign gray_count = binary_count ^ (binary_count >> 1);

endmodule