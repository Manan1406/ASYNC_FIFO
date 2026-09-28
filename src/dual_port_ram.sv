module dual_port_ram #(
    parameter DATA_WIDTH = 32,
    parameter FIFO_DEPTH = 8
)(
    input logic wr_clk,
    input logic[$clog2(FIFO_DEPTH)-1:0] write_addr,
    input logic write_en,
    input logic[DATA_WIDTH-1:0] write_data,
    input logic[$clog2(FIFO_DEPTH)-1:0] read_addr,
    output logic[DATA_WIDTH-1:0] read_data
);

//body 
logic [DATA_WIDTH-1:0] mem [FIFO_DEPTH];

always_ff@(posedge wr_clk) begin
    if(write_en) begin
        mem[write_addr] <= write_data;
    end
end

assign read_data = mem[read_addr];



endmodule