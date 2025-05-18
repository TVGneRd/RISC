----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/16/2024 05:21:21 PM
-- Design Name: 
-- Module Name: m_axi - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY axi4_writer IS
    PORT (
        clk : IN STD_LOGIC;
        rst : IN STD_LOGIC;

        write_addr     : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
        write_data     : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        write_start    : IN STD_LOGIC;
        write_complete : OUT STD_LOGIC;
        write_result   : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);

        -- Write address channel signals
        M_AXI_AWADDR  : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
        M_AXI_AWVALID : OUT STD_LOGIC;
        M_AXI_AWREADY : IN STD_LOGIC;
        M_AXI_AWLEN   : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        -- Write data channel signals
        M_AXI_WDATA  : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        M_AXI_WVALID : OUT STD_LOGIC;
        M_AXI_WREADY : IN STD_LOGIC;
        M_AXI_WRESP  : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        M_AXI_WLAST  : OUT STD_LOGIC
    );
END axi4_writer;

ARCHITECTURE Behavioral OF axi4_writer IS
    TYPE m_state_type IS (rst_state, wait_for_start, wait_for_awready, wait_for_wready, assert_bready);

    SIGNAL cur_state  : m_state_type := rst_state;
    SIGNAL next_state : m_state_type := rst_state;

    SIGNAL write_addr_read : BOOLEAN := false;
    SIGNAL write_data_read : BOOLEAN := false;

BEGIN

    data_safe : PROCESS (clk, rst, write_addr_read, write_data_read)
        VARIABLE write_addr_safe : STD_LOGIC_VECTOR(write_addr'RANGE);
        VARIABLE write_data_safe : STD_LOGIC_VECTOR(write_data'RANGE);
        VARIABLE wdata_reg       : STD_LOGIC_VECTOR(M_AXI_WDATA'RANGE);
    BEGIN
        IF rst = '0' THEN
            write_addr_safe := (OTHERS => '0');
            write_data_safe := (OTHERS => '0');
        ELSIF rising_edge(clk) THEN
            IF write_addr_read THEN
                write_addr_safe := write_addr;
            END IF;
            IF write_data_read THEN
                write_data_safe := write_data;
            END IF;
        END IF;

        wdata_reg := write_data_safe;

        M_AXI_AWADDR <= write_addr_safe;
        M_AXI_WDATA  <= STD_LOGIC_VECTOR(unsigned(wdata_reg));

    END PROCESS;

    state_transition : PROCESS (clk, rst)
    BEGIN
        IF rst = '0' THEN
            cur_state <= rst_state;
        ELSIF rising_edge(clk) THEN
            cur_state <= next_state;
        END IF;
    END PROCESS;

    state_decider : PROCESS (cur_state, write_start, M_AXI_AWREADY, M_AXI_WREADY)
    BEGIN
        next_state <= cur_state;
        CASE cur_state IS
            WHEN rst_state =>
                next_state <= wait_for_start;
            WHEN wait_for_start =>
                IF write_start = '1' THEN
                    next_state <= wait_for_awready;
                END IF;
            WHEN wait_for_awready =>
                IF M_AXI_AWREADY = '1' THEN
                    next_state <= wait_for_wready;
                END IF;
            WHEN wait_for_wready =>
                IF M_AXI_WREADY = '1' THEN
                    next_state <= assert_bready;
                END IF;
            WHEN assert_bready =>
                next_state <= wait_for_start;
        END CASE;
    END PROCESS;

    output_decider : PROCESS (cur_state)
    BEGIN
        CASE cur_state IS
            WHEN rst_state =>
                write_complete  <= '0';
                write_addr_read <= false;
                M_AXI_AWVALID   <= '0';
                write_data_read <= false;
                M_AXI_WVALID    <= '0';
                write_result    <= "00";
            WHEN wait_for_start =>
                write_complete  <= '1';
                write_addr_read <= true;
                M_AXI_AWVALID   <= '0';
                write_data_read <= true;
                M_AXI_WVALID    <= '0';
                write_result    <= "00";

            WHEN wait_for_awready =>
                write_complete  <= '0';
                write_addr_read <= false;
                M_AXI_AWVALID   <= '1';
                write_data_read <= true;
                M_AXI_WVALID    <= '0';
                write_result    <= "00";

            WHEN wait_for_wready =>
                write_complete  <= '0';
                write_addr_read <= true;
                M_AXI_AWVALID   <= '0';
                write_data_read <= false;
                M_AXI_WVALID    <= '1';
                write_result    <= "00";

            WHEN assert_bready =>
                write_complete  <= '0';
                write_addr_read <= true;
                M_AXI_AWVALID   <= '0';
                write_data_read <= true;
                M_AXI_WVALID    <= '0';
                write_result    <= M_AXI_WRESP;
        END CASE;
        M_AXI_AWLEN <= (OTHERS => '0');
        M_AXI_WLAST <= '1';
    END PROCESS;
END Behavioral;