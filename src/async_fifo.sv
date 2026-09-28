module async_fifo #(parameter DATA_WIDTH = 32, FIFO_DEPTH = 8)(
    input logic wr_clk, rd_clk, rd_en, wr_en, rst,
    input logic[DATA_WIDTH-1:0] data_in,
    output logic[DATA_WIDTH-1:0] data_out,
    output logic fifo_full,
    output logic fifo_empty,
    output logic fifo_almost_full,
    output logic fifo_almost_empty
);

logic [3:0] gray_count_wr; // gray coded version of write pointer that travels from the write to read domain, 
                           // to do comparisons against read pointer values to check for empty RAM.

logic [3:0] binary_count_wr; // write address sent to dual port ram(which address is getting written to)

logic [3:0] gray_count_rd; // gray coded version of read pointer that travels from the read to write domain,
                           // to do comparisons against write pointer values to check for full RAM

logic [3:0] binary_count_rd; // read address sent to dual port ram(which address is getting read from)

logic [3:0] cross_gray_wr; // version of gray_count_wr that has arrived into the read domain

logic [3:0] cross_gray_rd; // version of gray_count_rd that has arrived into the write domain

// W2R exists because: fifo_empty is computed in the read domain, but needs to know the write pointer's value → write pointer must safely cross into the read domain.
// R2W exists because: fifo_full is computed in the write domain, but needs to know the read pointer's value → read pointer must safely cross into the write domain.

logic[3:0] binary_rd_next; // computing next binary read pointer value to check for almost empty
logic[3:0] gray_count_rd_next; // converting above into gray code
logic[3:0] binary_wr_next; // computing next binary write pointer value to check for almost empty
logic[3:0] gray_count_wr_next; // converting above into gray code



gray_counter #(
    .WIDTH(4)
) gray_counter_wr_inst (
    .clk(wr_clk),
    .rst(rst),
    .en(wr_en && !fifo_full),
    .gray_count(gray_count_wr),
    .binary_count(binary_count_wr)
);

gray_counter #(
    .WIDTH(4)
) gray_counter_rd_inst (
    .clk(rd_clk),
    .rst(rst),
    .en(rd_en && !fifo_empty),
    .gray_count(gray_count_rd),
    .binary_count(binary_count_rd)
);

sync_2ff #(
    .WIDTH(4)
) sync_2ff_wr_inst (
    .clk(rd_clk),
    .rst(rst),
    .gray_value(gray_count_wr),
    .cross_gray_value(cross_gray_wr)
);

sync_2ff #(
    .WIDTH(4)
) sync_2ff_rd_inst (
    .clk(wr_clk),
    .rst(rst),
    .gray_value(gray_count_rd),
    .cross_gray_value(cross_gray_rd)
);

dual_port_ram #(
    .DATA_WIDTH(32),
    .FIFO_DEPTH(8)
) dual_port_ram_inst(
    .wr_clk(wr_clk),
    .write_addr(binary_count_wr[2:0]),
    .read_addr(binary_count_rd[2:0]),
    .write_en(wr_en && !fifo_full),
    .write_data(data_in),
    .read_data(data_out)
);

// fifo_empty is when the cross domain gray value of the write pointer is compared within the read domain to 
// the gray read pointer value, all 4 bits must be exactly the same bit for bit for the the empty condition to be true.
assign fifo_empty = (cross_gray_wr == gray_count_rd);

// fifo_full is when the synchronized read pointer's top two bits are inverted, forming the 
// exact gray-coded value the write pointer would have if it had lapped the read pointer exactly 
// once, and then compared directly to the current write pointer, basically we check whether the 
// write pointer has caught up to one full lap ahead of the read pointer
assign fifo_full = (gray_count_wr == {~cross_gray_rd[3], ~cross_gray_rd[2], cross_gray_rd[1:0]});

// fifo_almost_empty  is when the binary read address is incremented by 1, converted into a gray coded value 
// and then the incoming gray write address is compared to this incremented gray read value to check for if the 
// buffer is almost empty, basically we check that whether the next read pointer is gonna be equal to the current 
// write address pointer
assign binary_rd_next = binary_count_rd + 1;
assign gray_count_rd_next = binary_rd_next ^ (binary_rd_next >> 1);
assign fifo_almost_empty = (gray_count_rd_next == cross_gray_wr);

// fifo_almost_full  is when the binary write address is incremented by 1, converted into a gray coded value 
// and then the incoming gray read address is compared to this incremented gray write value to check for if the 
// buffer is almost full, basically we check that whether the next write pointer is gonna be equal to the current
// read address pointer
assign binary_wr_next = binary_count_wr + 1;
assign gray_count_wr_next = binary_wr_next ^ (binary_wr_next >> 1);
assign fifo_almost_full = ((gray_count_wr_next[2:0] == cross_gray_rd[2:0]) && (gray_count_wr_next[3] != cross_gray_rd[3]));


endmodule