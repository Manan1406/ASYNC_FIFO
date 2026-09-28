module async_fifo_tb;

    localparam DATA_WIDTH = 32;
    localparam FIFO_DEPTH = 8;
    localparam NUM_TRANSACTIONS = 20;

    logic wr_clk, rd_clk, rst;
    logic wr_en, rd_en;
    logic [DATA_WIDTH-1:0] data_in;
    logic [DATA_WIDTH-1:0] data_out;
    logic fifo_full, fifo_empty, fifo_almost_full, fifo_almost_empty;

    logic [DATA_WIDTH-1:0] scoreboard [$];
    int write_count = 0;
    int read_count  = 0;
    int errors      = 0;
    logic go;

    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) dut (
        .wr_clk(wr_clk),
        .rd_clk(rd_clk),
        .rst(rst),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .data_in(data_in),
        .data_out(data_out),
        .fifo_full(fifo_full),
        .fifo_empty(fifo_empty),
        .fifo_almost_full(fifo_almost_full),
        .fifo_almost_empty(fifo_almost_empty)
    );

    initial begin
        wr_clk = 0;
        forever #10 wr_clk = ~wr_clk;   // 20ns period = 50MHz
    end

    initial begin
        rd_clk = 0;
        forever #20 rd_clk = ~rd_clk;   // 40ns period = 25MHz
    end

    initial begin
        $dumpfile("sim/async_fifo.vcd");
        $dumpvars(0, async_fifo_tb);

        go      = 0;
        rst     = 0;
        wr_en   = 0;
        rd_en   = 0;
        data_in = '0;

        @(posedge wr_clk); #1;
        @(posedge wr_clk); #1;
        rst = 1;
        #1;
        go = 1;
    end

    // write process — writes whenever not full, logs each real write into the scoreboard
    initial begin
        @(posedge go);

        for (int i = 0; i < NUM_TRANSACTIONS; i++) begin
            @(posedge wr_clk); #1;
            if (!fifo_full) begin
                wr_en   = 1;
                data_in = i;
                scoreboard.push_back(i);
                write_count++;
            end else begin
                wr_en = 0;
            end
        end

        wr_en = 0;
    end

    // read process — reads whenever not empty, checks data_out against the scoreboard
    initial begin
        logic [DATA_WIDTH-1:0] expected_data;

        @(posedge go);

        for (int i = 0; i < NUM_TRANSACTIONS + 10; i++) begin
            @(posedge rd_clk); #1;
            if (!fifo_empty && scoreboard.size() > 0) begin
                expected_data = scoreboard.pop_front();
                rd_en = 1;

                if (data_out !== expected_data) begin
                    $display("NOOO, read #%0d mismatch: expected=%0d got=%0d", read_count, expected_data, data_out);
                    errors++;
                end else begin
                    $display("NICE, read #%0d data_out=%0d matches expected", read_count, data_out);
                end
                read_count++;
            end else begin
                rd_en = 0;
            end
        end

        rd_en = 0;
        #20;

        if (errors == 0 && read_count == write_count && write_count > 0) begin
            $display("YAY! All %0d actually-written transactions read back in order, zero mismatches.", write_count);
        end else begin
            $display("NAY! errors=%0d write_count=%0d read_count=%0d", errors, write_count, read_count);
        end

        $finish;
    end

endmodule