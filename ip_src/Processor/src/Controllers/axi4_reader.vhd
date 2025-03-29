LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY axi4_reader IS
    PORT (
        clk           : IN STD_LOGIC;
        rst           : IN STD_LOGIC;
        read_addr     : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
        read_data     : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        read_len      : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        read_last     : OUT STD_LOGIC;
        read_start    : IN STD_LOGIC;
        read_complete : OUT STD_LOGIC;
        read_result   : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        --  Read address channel signals
        M_AXI_ARADDR  : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
        M_AXI_ARLEN   : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        M_AXI_ARVALID : OUT STD_LOGIC;
        M_AXI_ARREADY : IN STD_LOGIC;
        -- Read data channel signals
        M_AXI_RDATA  : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        M_AXI_RRESP  : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        M_AXI_RLAST  : IN STD_LOGIC;
        M_AXI_RVALID : IN STD_LOGIC;
        M_AXI_RREADY : OUT STD_LOGIC
    );
END axi4_reader;

ARCHITECTURE Behavioral OF axi4_reader IS
    TYPE state_type IS (rst_state, wait_for_start, assert_arvalid,
        wait_for_rvalid_rise, wait_for_rvalid_fall);
    SIGNAL cur_state  : state_type := rst_state;
    SIGNAL next_state : state_type := rst_state;

    SIGNAL update_read_data   : BOOLEAN := false;
    SIGNAL update_read_addr   : BOOLEAN := false;
    SIGNAL update_read_result : BOOLEAN := false;

BEGIN
    -- Handles the cur_state variable
    sync_proc : PROCESS (clk, rst)
    BEGIN
        IF rst = '1' THEN
            cur_state <= rst_state;
        ELSIF rising_edge(clk) THEN
            cur_state <= next_state;
        END IF;
    END PROCESS;

    -- handles the next_state variable
    state_decider : PROCESS (cur_state, M_AXI_ARREADY,
        M_AXI_RLAST, M_AXI_RVALID, read_start)
    BEGIN
        next_state <= cur_state;
        CASE cur_state IS
            WHEN rst_state =>
                next_state <= wait_for_start;
            WHEN wait_for_start =>
                IF read_start = '1' THEN
                    next_state <= assert_arvalid;
                END IF;
            WHEN assert_arvalid =>
                IF M_AXI_ARREADY = '1' THEN
                    next_state <= wait_for_rvalid_rise;
                END IF;
            WHEN wait_for_rvalid_rise =>
                IF M_AXI_RVALID = '1' THEN
                    next_state <= wait_for_rvalid_fall;
                END IF;
            WHEN wait_for_rvalid_fall =>
                IF M_AXI_RVALID = '0' THEN
                    IF M_AXI_RLAST = '1' THEN
                        next_state <= wait_for_start;
                    ELSE
                        next_state <= wait_for_rvalid_rise;
                    END IF;
                END IF;
        END CASE;
    END PROCESS;

    signal_store : PROCESS (clk, rst, update_read_data, update_read_addr, update_read_result)
        VARIABLE read_data_store   : STD_LOGIC_VECTOR(M_AXI_RDATA'RANGE);
        VARIABLE read_addr_store   : STD_LOGIC_VECTOR(read_addr'left DOWNTO 0);
        VARIABLE read_result_store : STD_LOGIC_VECTOR(read_result'RANGE);
        VARIABLE shift_modifier    : NATURAL;
    BEGIN
        IF rst = '1' THEN
            read_data_store   := (OTHERS => '0');
            read_addr_store   := (OTHERS => '0');
            read_result_store := (OTHERS => '0');
        ELSIF rising_edge(clk) THEN
            IF update_read_data THEN
                read_data_store := M_AXI_RDATA;
            END IF;
            IF update_read_addr THEN
                read_addr_store := read_addr;
            END IF;
            IF update_read_result THEN
                read_result_store := M_AXI_RRESP;
            END IF;
        END IF;

        shift_modifier := 0;

        read_data    <= read_data_store(read_data'left + shift_modifier * 8 DOWNTO shift_modifier * 8);
        read_result  <= read_result_store;
        M_AXI_ARADDR <= read_addr_store;

    END PROCESS;

    -- The state decides the output
    output_decider : PROCESS (cur_state, M_AXI_RDATA, read_addr, M_AXI_RRESP)
    BEGIN
        CASE cur_state IS
            WHEN rst_state =>
                read_complete      <= '0';
                M_AXI_ARVALID      <= '0';
                M_AXI_RREADY       <= '0';
                read_last          <= '0';
                update_read_data   <= false;
                update_read_addr   <= false;
                update_read_result <= false;
            WHEN wait_for_start =>
                read_complete      <= '0';
                M_AXI_ARVALID      <= '0';
                M_AXI_RREADY       <= '0';
                read_last          <= '0';
                update_read_data   <= false;
                update_read_addr   <= true;
                update_read_result <= false;
            WHEN assert_arvalid =>
                read_complete      <= '0';
                M_AXI_ARVALID      <= '1';
                M_AXI_RREADY       <= '0';
                read_last          <= '0';
                update_read_data   <= true;
                update_read_addr   <= false;
                update_read_result <= true;
            WHEN wait_for_rvalid_rise =>
                read_complete      <= '0';
                M_AXI_ARVALID      <= '0';
                M_AXI_RREADY       <= '1';
                read_last          <= '0';
                update_read_data   <= true;
                update_read_addr   <= false;
                update_read_result <= true;
            WHEN wait_for_rvalid_fall =>
                read_complete      <= '1';
                M_AXI_ARVALID      <= '0';
                M_AXI_RREADY       <= '0';
                read_last          <= M_AXI_RLAST;
                update_read_data   <= true;
                update_read_addr   <= false;
                update_read_result <= true;
        END CASE;

        M_AXI_ARLEN <= read_len;

    END PROCESS;
END Behavioral;