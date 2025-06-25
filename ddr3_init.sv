module ddr3_init_fsm (
    input  logic        sys_clk_100mhz,
    input  logic        rst_n,
    output logic        init_done,

    output logic        wb_ctrl_cyc,
    output logic        wb_ctrl_stb,
    output logic        wb_ctrl_we,
    output logic [29:0] wb_ctrl_adr,
    output logic [31:0] wb_ctrl_dat_w,
    output logic [3:0]  wb_ctrl_sel,
    input  logic [31:0] wb_ctrl_dat_r,
    input  logic        wb_ctrl_ack,
    input  logic        wb_ctrl_err
);

    // Endereços Wishbone dos CSR 
    localparam SDRAM_DFII_CONTROL_WRITE_ADDRESS   = 'h1000;
    localparam SDRAM_DFII_PI0_COMMAND_WRITE       = 'h1004;
    localparam SDRAM_DFII_PI0_COMMAND_ISSUE_WRITE = 'h1008;
    localparam SDRAM_DFII_PI0_BADDRESS            = 'h1010;
    localparam SDRAM_DFII_PI0_ADDRESS_WRITE       = 'h100C;

    localparam DFII_CONTROL_SEL     = 'h01;
    localparam DFII_CONTROL_CKE     = 'h02;
    localparam DFII_CONTROL_ODT     = 'h04;
    localparam DFII_CONTROL_RESET_N = 'h08;

    localparam DFII_COMMAND_CS     = 'h01;
    localparam DFII_COMMAND_WE     = 'h02;
    localparam DFII_COMMAND_CAS    = 'h04;
    localparam DFII_COMMAND_RAS    = 'h08;
    localparam DFII_COMMAND_WRDATA = 'h10;
    localparam DFII_COMMAND_RDDATA = 'h20;

    typedef enum logic [7:0] {
        WB_IDLE,
        
        INIT_RELEASE_RESET,
        INIT_RELEASE_RESET_B,
        INIT_RELEASE_RESET_CONTROL,
        INIT_RELEASE_RESET_WAIT,
        
        INIT_CKE_HIGH_WAIT,
        INIT_CKE_HIGH,
        INIT_CKE_HIGH_B,
        INIT_CKE_HIGH_CONTROL,
        INIT_RELEASE_CKE_HIGH_WAIT,

        INIT_MR2_WAIT,
        INIT_LOAD_MR2,
        INIT_LOAD_MR2_B,
        INIT_LOAD_MR2_CMD,
        INIT_LOAD_MR2_ISSUE,
        INIT_MR2_POST_WAIT,

        INIT_LOAD_MR3,
        INIT_LOAD_MR3_B,
        INIT_LOAD_MR3_CMD,
        INIT_LOAD_MR3_ISSUE,
        INIT_MR3_POST_WAIT,

        INIT_LOAD_MR1,
        INIT_LOAD_MR1_B,
        INIT_LOAD_MR1_CMD,
        INIT_LOAD_MR1_ISSUE,
        INIT_MR1_POST_WAIT,

        INIT_MR0_DELAY,
        INIT_MR0_DELAY_WAIT,
        INIT_LOAD_MR0,
        INIT_LOAD_MR0_B,
        INIT_LOAD_MR0_CMD,
        INIT_LOAD_MR0_ISSUE,
        INIT_MR0_POST_WAIT,

        INIT_ZQ_CALIB_DELAY,
        INIT_ZQ_CALIB_DELAY_WAIT,
        INIT_ZQ_CALIB,
        INIT_ZQ_CALIB_B,
        INIT_ZQ_CALIB_CMD,
        INIT_ZQ_CALIB_ISSUE,
        INIT_ZQ_CALIB_WAIT,

        WB_WRITE,
        WB_WRITE_WAIT,

        INIT_DONE
    } init_state_t;


    init_state_t init_state, next_state;

    logic [31:0] wb_write_data;
    logic [29:0] wb_write_addr;
    logic wb_start_write;
    logic [31:0] delay_counter;

    always_ff @(posedge sys_clk_100mhz or negedge rst_n) begin
        if (!rst_n) begin
            wb_ctrl_cyc   <= 0;
            wb_ctrl_stb   <= 0;
            wb_ctrl_we    <= 0;
            wb_ctrl_adr   <= 0;
            wb_ctrl_dat_w <= 0;
            wb_ctrl_sel   <= 4'b1111;
        end else begin
            if (wb_start_write) begin
                wb_ctrl_cyc   <= 1;
                wb_ctrl_stb   <= 1;
                wb_ctrl_we    <= 1;
                wb_ctrl_adr   <= wb_write_addr;
                wb_ctrl_dat_w <= wb_write_data;
            end else if (wb_ctrl_ack) begin
                wb_ctrl_cyc <= 0;
                wb_ctrl_stb <= 0;
                wb_ctrl_we  <= 0;
            end
        end
    end

    always_ff @(posedge sys_clk_100mhz or negedge rst_n) begin
        if (!rst_n) begin
            init_state      <= WB_IDLE;
            delay_counter   <= 0;
            wb_start_write  <= 0;
            init_done       <= 0;
        end else begin
            wb_start_write <= 0;

            case (init_state)
                WB_IDLE: begin
                    init_state <= INIT_RELEASE_RESET;
                end

                INIT_RELEASE_RESET: begin
                    wb_write_addr <= SDRAM_DFII_PI0_ADDRESS_WRITE;
                    wb_write_data <= 32'h00;
                    wb_start_write <= 1;
                    init_state <= WB_WRITE_WAIT;
                    next_state <= INIT_RELEASE_RESET_B;
                end

                INIT_RELEASE_RESET_B: begin
                    wb_write_addr <= SDRAM_DFII_PI0_BADDRESS;
                    wb_write_data <= 32'h00;
                    wb_start_write <= 1;
                    init_state <= WB_WRITE_WAIT;
                    next_state <= INIT_RELEASE_RESET_CONTROL;
                end

                INIT_RELEASE_RESET_CONTROL: begin
                    wb_write_addr <= SDRAM_DFII_CONTROL_WRITE_ADDRESS;
                    wb_write_data <= DFII_CONTROL_ODT|DFII_CONTROL_RESET_N;
                    wb_start_write <= 1;
                    init_state <= WB_WRITE_WAIT;
                    next_state <= INIT_RELEASE_RESET_WAIT;
                end

                INIT_RELEASE_RESET_WAIT: begin
                    delay_counter <= 0;
                    init_state <= INIT_CKE_HIGH_WAIT;
                end

                INIT_CKE_HIGH_WAIT: begin
                    delay_counter <= delay_counter + 1;
                    if (delay_counter > 500000) begin
                        init_state <= INIT_CKE_HIGH;
                    end
                end

                INIT_CKE_HIGH: begin
                    wb_write_addr <= SDRAM_DFII_PI0_ADDRESS_WRITE;
                    wb_write_data <= 32'h0;
                    wb_start_write <= 1;
                    init_state <= WB_WRITE_WAIT;
                    next_state <= INIT_CKE_HIGH_B;
                end

                INIT_CKE_HIGH_B: begin
                    wb_write_addr <= SDRAM_DFII_PI0_BADDRESS;
                    wb_write_data <= 32'h00;
                    wb_start_write <= 1;
                    init_state <= WB_WRITE_WAIT;
                    next_state <= INIT_CKE_HIGH_CONTROL;
                end

                INIT_CKE_HIGH_CONTROL: begin
                    wb_write_addr <= SDRAM_DFII_CONTROL_WRITE_ADDRESS;
                    wb_write_data <= DFII_CONTROL_CKE|DFII_CONTROL_ODT|DFII_CONTROL_RESET_N;
                    wb_start_write <= 1;
                    init_state <= WB_WRITE_WAIT;
                    next_state <= INIT_RELEASE_CKE_HIGH_WAIT;
                end

                INIT_RELEASE_CKE_HIGH_WAIT: begin
                    delay_counter <= 0;
                    init_state <= INIT_MR2_WAIT;
                end

                INIT_MR2_WAIT: begin
                    delay_counter <= delay_counter + 1;
                    if (delay_counter > 100000) begin
                        init_state <= INIT_LOAD_MR2;
                    end
                end

                // ----------- MR2 -----------
                INIT_LOAD_MR2: begin
                    wb_write_addr <= SDRAM_DFII_PI0_ADDRESS_WRITE;
                    wb_write_data <= 32'h218;
                    wb_start_write <= 1;
                    init_state <= WB_WRITE_WAIT;
                    next_state <= INIT_LOAD_MR2_B;
                end

                INIT_LOAD_MR2_B: begin
                    wb_write_addr <= SDRAM_DFII_PI0_BADDRESS;
                    wb_write_data <= 32'h02;  // BA=2 para MR2
                    wb_start_write <= 1;
                    init_state <= WB_WRITE_WAIT;
                    next_state <= INIT_LOAD_MR2_CMD;
                end

                INIT_LOAD_MR2_CMD: begin
                    wb_write_addr <= SDRAM_DFII_PI0_COMMAND_WRITE;
                    wb_write_data <= DFII_COMMAND_CS | DFII_COMMAND_WE | DFII_COMMAND_CAS | DFII_COMMAND_RAS;
                    wb_start_write <= 1;
                    init_state <= WB_WRITE_WAIT;
                    next_state <= INIT_LOAD_MR2_ISSUE;
                end

                INIT_LOAD_MR2_ISSUE: begin
                    wb_write_addr <= SDRAM_DFII_PI0_COMMAND_ISSUE_WRITE;
                    wb_write_data <= 32'h01;
                    wb_start_write <= 1;
                    init_state <= WB_WRITE_WAIT;
                    next_state <= INIT_LOAD_MR3;
                end

                // ----------- MR3 -----------
                INIT_LOAD_MR3: begin
                    wb_write_addr <= SDRAM_DFII_PI0_ADDRESS_WRITE;
                    wb_write_data <= 32'h0;
                    wb_start_write <= 1;
                    init_state <= WB_WRITE_WAIT;
                    next_state <= INIT_LOAD_MR3_B;
                end

                INIT_LOAD_MR3_B: begin
                    wb_write_addr <= SDRAM_DFII_PI0_BADDRESS;
                    wb_write_data <= 32'h03;  // BA=3 para MR3
                    wb_start_write <= 1;
                    init_state <= WB_WRITE_WAIT;
                    next_state <= INIT_LOAD_MR3_CMD;
                end

                INIT_LOAD_MR3_CMD: begin
                    wb_write_addr <= SDRAM_DFII_PI0_COMMAND_WRITE;
                    wb_write_data <= DFII_COMMAND_CS | DFII_COMMAND_WE | DFII_COMMAND_CAS | DFII_COMMAND_RAS;
                    wb_start_write <= 1;
                    init_state <= WB_WRITE_WAIT;
                    next_state <= INIT_LOAD_MR3_ISSUE;
                end

                INIT_LOAD_MR3_ISSUE: begin
                    wb_write_addr <= SDRAM_DFII_PI0_COMMAND_ISSUE_WRITE;
                    wb_write_data <= 32'h01;
                    wb_start_write <= 1;
                    init_state <= WB_WRITE_WAIT;
                    next_state <= INIT_LOAD_MR1;
                end

                // ----------- MR1 -----------
                INIT_LOAD_MR1: begin
                    wb_write_addr <= SDRAM_DFII_PI0_ADDRESS_WRITE;
                    wb_write_data <= 32'h6;
                    wb_start_write <= 1;
                    init_state <= WB_WRITE_WAIT;
                    next_state <= INIT_LOAD_MR1_B;
                end

                INIT_LOAD_MR1_B: begin
                    wb_write_addr <= SDRAM_DFII_PI0_BADDRESS;
                    wb_write_data <= 32'h01;  // BA=1 para MR1
                    wb_start_write <= 1;
                    init_state <= WB_WRITE_WAIT;
                    next_state <= INIT_LOAD_MR1_CMD;
                end

                INIT_LOAD_MR1_CMD: begin
                    wb_write_addr <= SDRAM_DFII_PI0_COMMAND_WRITE;
                    wb_write_data <= DFII_COMMAND_CS | DFII_COMMAND_WE | DFII_COMMAND_CAS | DFII_COMMAND_RAS;
                    wb_start_write <= 1;
                    init_state <= WB_WRITE_WAIT;
                    next_state <= INIT_LOAD_MR1_ISSUE;
                end

                INIT_LOAD_MR1_ISSUE: begin
                    wb_write_addr <= SDRAM_DFII_PI0_COMMAND_ISSUE_WRITE;
                    wb_write_data <= 32'h01;
                    wb_start_write <= 1;
                    init_state <= WB_WRITE_WAIT;
                    next_state <= INIT_LOAD_MR0;
                end

                // ----------- MR0 -----------
                INIT_LOAD_MR0: begin
                    wb_write_addr <= SDRAM_DFII_PI0_ADDRESS_WRITE;
                    wb_write_data <= 32'hD70;  // MR0: CL=11, BL=8
                    wb_start_write <= 1;
                    init_state <= WB_WRITE_WAIT;
                    next_state <= INIT_LOAD_MR0_B;
                end

                INIT_LOAD_MR0_B: begin
                    wb_write_addr <= SDRAM_DFII_PI0_BADDRESS;
                    wb_write_data <= 32'h00;  // BA=0 para MR0
                    wb_start_write <= 1;
                    init_state <= WB_WRITE_WAIT;
                    next_state <= INIT_LOAD_MR0_CMD;
                end

                INIT_LOAD_MR0_CMD: begin
                    wb_write_addr <= SDRAM_DFII_PI0_COMMAND_WRITE;
                    wb_write_data <= DFII_COMMAND_CS | DFII_COMMAND_WE | DFII_COMMAND_CAS | DFII_COMMAND_RAS;
                    wb_start_write <= 1;
                    init_state <= WB_WRITE_WAIT;
                    next_state <= INIT_LOAD_MR0_ISSUE;
                end

                INIT_LOAD_MR0_ISSUE: begin
                    wb_write_addr <= SDRAM_DFII_PI0_COMMAND_ISSUE_WRITE;
                    wb_write_data <= 32'h01;
                    wb_start_write <= 1;
                    init_state <= WB_WRITE_WAIT;
                    next_state <= INIT_MR0_DELAY;
                end

                INIT_MR0_DELAY: begin
                    delay_counter <= 0;
                    init_state <= INIT_MR0_DELAY_WAIT;
                end

                INIT_MR0_DELAY_WAIT: begin
                    delay_counter <= delay_counter + 1;
                    if (delay_counter > 20000) begin  // Aproximadamente equivalente a cdelay(200)
                        init_state <= INIT_ZQ_CALIB;
                    end
                end

                // ----------- ZQ Calibration -----------
                INIT_ZQ_CALIB: begin
                    wb_write_addr <= SDRAM_DFII_PI0_ADDRESS_WRITE;
                    wb_write_data <= 32'h400;
                    wb_start_write <= 1;
                    init_state <= WB_WRITE_WAIT;
                    next_state <= INIT_ZQ_CALIB_B;
                end

                INIT_ZQ_CALIB_B: begin
                    wb_write_addr <= SDRAM_DFII_PI0_BADDRESS;
                    wb_write_data <= 32'h00;  // BA=0
                    wb_start_write <= 1;
                    init_state <= WB_WRITE_WAIT;
                    next_state <= INIT_ZQ_CALIB_CMD;
                end

                INIT_ZQ_CALIB_CMD: begin
                    wb_write_addr <= SDRAM_DFII_PI0_COMMAND_WRITE;
                    wb_write_data <= DFII_COMMAND_CS | DFII_COMMAND_WE;
                    wb_start_write <= 1;
                    init_state <= WB_WRITE_WAIT;
                    next_state <= INIT_ZQ_CALIB_ISSUE;
                end

                INIT_ZQ_CALIB_ISSUE: begin
                    wb_write_addr <= SDRAM_DFII_PI0_COMMAND_ISSUE_WRITE;
                    wb_write_data <= 32'h01;
                    wb_start_write <= 1;
                    init_state <= WB_WRITE_WAIT;
                    next_state <= INIT_ZQ_CALIB_DELAY;
                end

                INIT_ZQ_CALIB_DELAY: begin
                    delay_counter <= 0;
                    init_state <= INIT_ZQ_CALIB_DELAY_WAIT;
                end

                INIT_ZQ_CALIB_DELAY_WAIT: begin
                    delay_counter <= delay_counter + 1;
                    if (delay_counter > 20000) begin  // Aproximadamente cdelay(200)
                        init_state <= INIT_DONE;
                    end
                end

                // ----------- Write Wait Generic -----------
                WB_WRITE_WAIT: begin
                    if (wb_ctrl_ack) begin
                        init_state <= next_state;
                    end
                end

                INIT_DONE: begin
                    init_done <= 1;
                end

                default: init_state <= WB_IDLE;
            endcase
        end
    end
endmodule
