module top #(
    parameter SYS_CLK_FREQ  = 50_000_000,  // 50 MHz
    parameter USER_CLK_FREQ = 100_000_000, // 100 MHz
    parameter REF_CLK_FREQ  = 200_000_000, // 200 MHz
    parameter DRAM_CLK_FREQ = 800_000_000, // 800 MHz
    parameter WORD_SIZE     = 256          // Word size for DRAM controller
) (
    input  logic        sys_clk,
    input  logic        rst_n,

    input  logic        rxd,
    output logic        txd,

    output logic [7:0]  led,

    // DRAM interface
    inout  logic [31:0] ddr3_dq,
    inout  logic [3:0]  ddr3_dqs_n,
    inout  logic [3:0]  ddr3_dqs_p,
    output logic [14:0] ddr3_addr,
    output logic [2:0]  ddr3_ba,
    output logic        ddr3_ras_n,
    output logic        ddr3_cas_n,
    output logic        ddr3_we_n,
    output logic        ddr3_reset_n,
    output logic [0:0]  ddr3_ck_p,
    output logic [0:0]  ddr3_ck_n,
    output logic [0:0]  ddr3_cke,
    output logic [0:0]  ddr3_cs_n,
    output logic [3:0]  ddr3_dm,
    output logic [0:0]  ddr3_odt
);
    // PLL and clock generation
    logic user_clk, locked, user_sys_clk, dram_pll_locked;

    clk_wiz_0 clk_wiz_0_inst (
        .clk_out1 (sys_clk_100mhz), // 100 MHz system clock
        .resetn   (rst_n),          // Active low reset
        .locked   (locked),         // Locked signal
        .clk_in1  (sys_clk)         // System clock - 50 MHz
    );

    // Control signals
    logic ddr3_init_done;
    logic ddr3_init_error;

    logic wb_ctrl_ack;
    logic [29:0] wb_ctrl_adr;
    logic [1:0] wb_ctrl_bte;
    logic [2:0] wb_ctrl_cti;
    logic wb_ctrl_cyc;
    logic [31:0] wb_ctrl_dat_r;
    logic [31:0] wb_ctrl_dat_w;
    logic wb_ctrl_err;
    logic [3:0] wb_ctrl_sel;
    logic wb_ctrl_stb;
    logic wb_ctrl_we;

    // User port signals
    logic user_rst;
    logic user_clk;

    // User wishbone signals
    logic user_port_wishbone_0_ack;
    logic [24:0] user_port_wishbone_0_adr;
    logic user_port_wishbone_0_cyc;
    logic [255:0] user_port_wishbone_0_dat_r;
    logic [255:0] user_port_wishbone_0_dat_w;
    logic user_port_wishbone_0_err;
    logic [31:0] user_port_wishbone_0_sel;
    logic user_port_wishbone_0_stb;
    logic user_port_wishbone_0_we;


    litedram_core u_litedram_core (
        .clk                        (sys_clk_100mhz),                // 1 bit
        .rst                        (~rst_n),                        // 1 bit
        
        .ddram_a                    (ddr3_addr),                     // 15 bits
        .ddram_ba                   (ddr3_ba),                       // 3 bits
        .ddram_cas_n                (ddr3_cas_n),                    // 1 bit
        .ddram_cke                  (ddr3_cke),                      // 1 bit
        .ddram_clk_n                (ddr3_clk_n),                    // 1 bit
        .ddram_clk_p                (ddr3_clk_p),                    // 1 bit
        .ddram_cs_n                 (ddr3_cs_n),                     // 1 bit
        .ddram_dm                   (ddr3_dm),                       // 4 bits
        .ddram_odt                  (ddr3_odt),                      // 1 bit
        .ddram_ras_n                (ddr3_ras_n),                    // 1 bit
        .ddram_reset_n              (ddr3_reset_n),                  // 1 bit
        .ddram_we_n                 (ddr3_we_n),                     // 1 bit
        .init_done                  (ddr3_init_done),                // 1 bit
        .init_error                 (ddr3_init_error),               // 1 bit
        .pll_locked                 (dram_pll_locked),               // 1 bit
        
        .user_clk                   (user_clk),                      // 1 bit
        .user_port_wishbone_0_ack   (user_port_wishbone_0_ack),      // 1 bit
        .user_port_wishbone_0_adr   (user_port_wishbone_0_adr),      // 25 bits
        .user_port_wishbone_0_cyc   (user_port_wishbone_0_cyc),      // 1 bit
        .user_port_wishbone_0_dat_r (user_port_wishbone_0_dat_r),    // 256 bits
        .user_port_wishbone_0_dat_w (user_port_wishbone_0_dat_w),    // 256 bits
        .user_port_wishbone_0_err   (user_port_wishbone_0_err),      // 1 bit
        .user_port_wishbone_0_sel   (user_port_wishbone_0_sel),      // 32 bits
        .user_port_wishbone_0_stb   (user_port_wishbone_0_stb),      // 1 bit
        .user_port_wishbone_0_we    (user_port_wishbone_0_we),       // 1 bit
        .user_rst                   (user_rst),                      // 1 bit
        
        .wb_ctrl_ack                (wb_ctrl_ack),                   // 1 bit
        .wb_ctrl_adr                (wb_ctrl_adr),                   // 30 bits
        .wb_ctrl_bte                (wb_ctrl_bte),                   // 2 bits
        .wb_ctrl_cti                (wb_ctrl_cti),                   // 3 bits
        .wb_ctrl_cyc                (wb_ctrl_cyc),                   // 1 bit
        .wb_ctrl_dat_r              (wb_ctrl_dat_r),                 // 32 bits
        .wb_ctrl_dat_w              (wb_ctrl_dat_w),                 // 32 bits
        .wb_ctrl_err                (wb_ctrl_err),                   // 1 bit
        .wb_ctrl_sel                (wb_ctrl_sel),                   // 4 bits
        .wb_ctrl_stb                (wb_ctrl_stb),                   // 1 bit
        .wb_ctrl_we                 (wb_ctrl_we)                     // 1 bit
    );

    typedef enum logic [2:0] {
        TST_IDLE,
        TST_WRITE,
        TST_WAIT_WRITE,
        TST_READ,
        TST_WAIT_READ,
        TST_CHECK
    } test_state_t;

    test_state_t test_state;
    logic [15:0] delay_counter;
    logic test_pass, test_fail;

    localparam TEST_VALUE = {WORD_SIZE{1'b10100101}}; // Padrão A5 repetido
    localparam logic [127:0] TEST_VALUE1 = {16{8'hA5}};
    localparam logic [127:0] TEST_VALUE2 = {16{8'h5A}};
    localparam logic [127:0] TEST_VALUE3 = {16{8'hFF}};
    localparam logic [127:0] TEST_VALUE4 = {16{8'h00}};
    localparam logic [127:0] TEST_VALUE5 = {16{8'hF0}};
    localparam logic [127:0] TEST_VALUE6 = {16{8'h0F}};
    localparam logic [127:0] TEST_VALUE7 = {16{8'hAA}};
    localparam logic [127:0] TEST_VALUE8 = {16{8'h55}};
    localparam logic [127:0] TEST_VALUE9 = 128'hAABB_CCDD_EEFF_0011_2233_4455_6677_8899;

    always_ff @( posedge user_clk ) begin
        if(user_rst) begin
            test_state <= TST_IDLE;
        end else begin
            case (test_state)
                TST_IDLE: begin
                    
                end 

                TST_WRITE: begin
                    
                end

                TST_WAIT_WRITE: begin
                    
                end

                TST_READ: begin
                    
                end

                TST_WAIT_READ: begin
                    
                end

                TST_CHECK: begin
                    
                end

                default: test_state <= TST_IDLE; // Reset to idle state 
            endcase
        end
    end




    assign wb_ctrl_we  = 1'b0;
    assign wb_ctrl_sel = 4'hF; // Select all bytes
    assign wb_ctrl_bte = 2'b00; // Linear burst type
    assign wb_ctrl_cti = 3'b000; // Normal burst
    assign wb_ctrl_cyc = 1'b0; // Cycle not active
    assign wb_ctrl_stb = 1'b0; // Strobe not active
    assign wb_ctrl_adr = 30'h0; // Address not used in this test

endmodule
