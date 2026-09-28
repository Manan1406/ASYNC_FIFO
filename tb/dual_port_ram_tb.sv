module dual_port_ram_tb;

    logic wr_clk;
    logic write_en;
    logic [2:0] write_addr;
    logic [31:0] write_data;
    logic [2:0] read_addr;
    logic [31:0] read_data;

    logic [31:0] expected_mem [8];

    dual_port_ram #(
        .DATA_WIDTH(32),
        .FIFO_DEPTH(8)
    ) dut (
        .wr_clk(wr_clk),
        .write_addr(write_addr),
        .write_en(write_en),
        .write_data(write_data),
        .read_addr(read_addr),
        .read_data(read_data)
    );

    initial begin
        wr_clk = 0;
        forever #10 wr_clk = ~wr_clk;
    end

    initial begin
        $dumpfile("sim/dual_port_ram.vcd");
        $dumpvars(0, dual_port_ram_tb);

        write_en = 0;
        read_addr = 0;
        @(posedge wr_clk); #1;

        for (int i = 0; i < 8; i++) begin
            write_en   = 1;
            write_addr = i;
            write_data = i * 100;
            expected_mem[i] = i * 100;
            @(posedge wr_clk); #1;
        end

        write_en = 0;

        for (int i = 0; i < 8; i++) begin
            read_addr = i;
            #1;

            if (read_data !== expected_mem[i]) begin
                $display("NOOO, mismatch at addr=%0d: expected=%0d got=%0d", i, expected_mem[i], read_data);
            end else begin
                $display("NICE, addr=%0d read_data=%0d matches expected", i, read_data);
            end
        end

        write_addr = 3;
        write_data = 32'hDEADBEEF;
        write_en   = 0;
        @(posedge wr_clk); #1;
        read_addr = 3;
        #1;

        if (read_data !== 300) begin
            $display("NOOO, write_en=0 should NOT have written — addr=3 changed to %0d", read_data);
        end else begin
            $display("NICE, write_en=0 correctly blocked the write, addr=3 still=%0d", read_data);
        end

        // NEW TEST: read-during-write, same address, same cycle
        // Write NEW data to addr=5 while simultaneously reading addr=5.
        // Since read is combinational and write is registered (updates
        // AFTER the clock edge), the read happening in the same cycle
        // as the write should show the OLD value, not the new one —
        // the new value only becomes visible on/after the next edge.
        read_addr  = 5;
        write_addr = 5;
        write_data = 32'h11112222;
        write_en   = 1;
        #1; // sample read_data BEFORE the clock edge commits the write

        if (read_data === 500) begin
            $display("NICE, read-during-write showed OLD value (500) before edge, as expected");
        end else begin
            $display("NOOO, read-during-write showed unexpected value=%0d before edge", read_data);
        end

        @(posedge wr_clk); #1; // now the write has committed

        if (read_data === 32'h11112222) begin
            $display("NICE, after the clock edge, addr=5 now shows the NEW value");
        end else begin
            $display("NOOO, addr=5 did not update after the edge, got=%0h", read_data);
        end

        write_en = 0;
        $finish;
    end

endmodule