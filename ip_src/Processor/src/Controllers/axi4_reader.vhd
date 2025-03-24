LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY axi4_reader IS
    GENERIC (
        axi_data_width    : NATURAL RANGE 1 TO 255 := 5;
        axi_address_width : NATURAL RANGE 1 TO 255 := 6
    );
    PORT (
        clk           : IN STD_LOGIC;
        rst           : IN STD_LOGIC;
        read_addr     : IN STD_LOGIC_VECTOR(axi_address_width - 1 DOWNTO 0);
        read_data     : OUT STD_LOGIC_VECTOR(axi_data_width - 1 DOWNTO 0);
        read_start    : IN STD_LOGIC;
        read_complete : OUT STD_LOGIC;
        read_result   : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        --  Read address channel signals
        M_AXI_ARADDR  : OUT STD_LOGIC_VECTOR(axi_address_width - 1 DOWNTO 0);
        M_AXI_ARLEN   : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        M_AXI_ARSIZE  : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        M_AXI_ARBURST : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        M_AXI_ARCACHE : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        M_AXI_ARUSER  : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
        M_AXI_ARVALID : OUT STD_LOGIC;
        M_AXI_ARREADY : IN STD_LOGIC;
        -- Read data channel signals
        M_AXI_RDATA  : IN STD_LOGIC_VECTOR(axi_data_width - 1 DOWNTO 0);
        M_AXI_RRESP  : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        M_AXI_RLAST  : IN STD_LOGIC;
        M_AXI_RVALID : IN STD_LOGIC;
        M_AXI_RREADY : OUT STD_LOGIC
    );
END axi4_reader;

ARCHITECTURE Behavioral OF axi4_reader IS
    TYPE state_type IS (rst_state, IDLE, CHECK_ADDR, LOAD_DATA, WAIT_AREADY, WAIT_VALID, REC_DATA, WRITE_CASH);
    SIGNAL cur_state  : state_type := rst_state;
    SIGNAL next_state : state_type := rst_state;

    SIGNAL update_read_data   : BOOLEAN := false;
    SIGNAL update_read_addr   : BOOLEAN := false;
    SIGNAL update_read_result : BOOLEAN := false;

BEGIN
    -- Handles the cur_state variable
    sync_proc : PROCESS (clk, rst)
    BEGIN
        IF rst = '0' THEN
            cur_state <= rst_state;
        ELSIF rising_edge(clk) THEN
            cur_state <= next_state;
        END IF;
    END PROCESS;

    -- handles the next_state variable
    state_transmission : PROCESS (cur_state, M_AXI_ARREADY,
        M_AXI_RLAST, M_AXI_RVALID, M_AXI_ARVALID)
    BEGIN
        next_state <= cur_state;
        CASE cur_state IS
            WHEN rst_state =>
                next_state <= IDLE;
            WHEN IDLE =>
                IF M_AXI_RVALID = '1'
                    IF M_AXI_RREADY = '0' THEN
                        next_state <= CHECK_ADDR;
                    END IF;
                END IF;
            WHEN CHECK_ADDR =>
                IF (address - cash_size) < cache_apper_bound THEN
                    next_state <= LOAD_DATA;
                ELSE
                    IF M_AXI_ARVALID = '1' THEN
                        next_state <= WAIT_AREADY;
                    END IF;
                END IF;
            WHEN LOAD_DATA =>
                IF M_AXI_RREADY = '1' THEN
                    next_state <= IDLE;
                END IF;
            WHEN WAIT_AREADY =>
                IF M_AXI_ARREADY = '1' THEN
                    next_state <= WAIT_VALID;
                END IF;
            WHEN WAIT_VALID =>
                IF M_AXI_RVALID = '1' THEN
                    next_state <= REC_DATA;
                END IF;
            WHEN REC_DATA =>
                IF M_AXI_RREADY = '1' THEN
                    IF M_AXI_RVALID = '1' THEN
                        next_state <= WRITE_CASH;
                    END IF;
                END IF;
            WHEN WRITE_CASH =>
                IF M_AXI_RREADY = '0' THEN
                    IF M_AXI_RLAST = '0' THEN
                        next_state <= REC_DATA;
                    ELSE
                        next_state <= LOAD_DATA;
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
        IF rst = '0' THEN
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
        M_AXI_ARSIZE <= STD_LOGIC_VECTOR(to_unsigned(axi_data_width, M_AXI_ARSIZE'length));
    END PROCESS;

    -- The state decides the output
    output_decider : PROCESS (cur_state, M_AXI_RDATA, read_addr, M_AXI_RRESP)
    BEGIN
        CASE cur_state IS
            WHEN rst_state =>
                read_complete      <= '0';
                M_AXI_ARVALID      <= '0';
                M_AXI_RREADY       <= '0';
                update_read_data   <= false;
                update_read_addr   <= false;
                update_read_result <= false;
            WHEN wait_for_start =>
                read_complete      <= '1';
                M_AXI_ARVALID      <= '0';
                M_AXI_RREADY       <= '0';
                update_read_data   <= false;
                update_read_addr   <= true;
                update_read_result <= false;
            WHEN assert_arvalid =>
                read_complete      <= '0';
                M_AXI_ARVALID      <= '1';
                M_AXI_RREADY       <= '0';
                update_read_data   <= true;
                update_read_addr   <= false;
                update_read_result <= true;
            WHEN wait_for_rvalid_rise =>
                read_complete      <= '0';
                M_AXI_ARVALID      <= '0';
                M_AXI_RREADY       <= '1';
                update_read_data   <= true;
                update_read_addr   <= false;
                update_read_result <= true;
            WHEN wait_for_rvalid_fall =>
                read_complete      <= '0';
                M_AXI_ARVALID      <= '0';
                M_AXI_RREADY       <= '0';
                update_read_data   <= true;
                update_read_addr   <= false;
                update_read_result <= true;
        END CASE;
        -- The following signals get a default value because this is still a simple test
        -- One burst:
        M_AXI_ARLEN <= (OTHERS => '0');
        -- For the test, the burst type does not matter. Keep it at 0 (FIXED)
        M_AXI_ARBURST <= (OTHERS => '0');
        -- See tech ref page 103. ARCACHE and AWCACHE control wether or not the processor cache is involved in this transaction
        -- For now, they are set to 0, no cache involvement. In the future this feature should be added
        M_AXI_ARCACHE <= (OTHERS => '0');
        M_AXI_ARUSER  <= (OTHERS => '0');

    END PROCESS;
END Behavioral;