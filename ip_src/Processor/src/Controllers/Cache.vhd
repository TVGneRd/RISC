
LIBRARY IEEE;--! standard library IEEE (Institute of Electrical and Electronics Engineers)
USE IEEE.std_logic_1164.ALL;--! standard unresolved logic UX01ZWLH-
USE IEEE.numeric_std.ALL;--! for the signed, unsigned types and arithmetic ops

-- -- -- -- Задача блока: -- -- -- --
-- 1. Дождаться valid=1, сделать ready=0
-- 2. Проверить находится ли address в диапазоне кэша (address - cache_size) < cache_upper_bound
-- 3. Если адрес находится в диапазоне, то просто переходим к пункту 4.
-- 3. Если адрес НЕ находится в диапазоне -> считывать 64 байта данных из памяти по AXI-4, записать их собственный кэш (это может быть любой массив)
-- 4. Установить data=массив_загруженных_данных[address % cache_size] и ready=1
-- 5. Ждать следующего valid=1, и повтор всего
------------------------------------
--тестовый комментарий
-- -- -- -- Распределение: -- -- -- --
-- Аня: 1, 2, 3, 4, 5
-------------------------------------

ENTITY Cache IS
  GENERIC (
    cache_size : INTEGER := 64
  );
  PORT (
    refclk : IN STD_LOGIC;--! reference clock expect 250Mhz
    rst    : IN STD_LOGIC;--! sync active high reset. sync -> refclk

    -- Порты для взаимодействия с ядром процессором, через него возвращаются данные из кэша
    address : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    data    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    valid   : IN STD_LOGIC;
    ready   : OUT STD_LOGIC;

    -- AXI-4 MM (Только Reader) Ports
    --  Read address channel signals
    M_AXI_ARADDR  : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    M_AXI_ARLEN   : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    M_AXI_ARVALID : OUT STD_LOGIC;
    M_AXI_ARREADY : IN STD_LOGIC;

    -- Read data channel signals
    M_AXI_RDATA  : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    M_AXI_RRESP  : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    M_AXI_RLAST  : IN STD_LOGIC;
    M_AXI_RVALID : IN STD_LOGIC;
    M_AXI_RREADY : OUT STD_LOGIC
    -- /AXI-4 MM (Только Reader) Ports
  );
END ENTITY Cache;
ARCHITECTURE rtl OF Cache IS
  TYPE state_type IS (rst_state, IDLE, CHECK_ADDR, LOAD_DATA, WAIT_AREADY, WAIT_VALID, REC_DATA, WRITE_CASH);
  SIGNAL cur_state  : state_type := rst_state;
  SIGNAL next_state : state_type := rst_state;

  SIGNAL update_read_data   : BOOLEAN := false;
  SIGNAL update_read_addr   : BOOLEAN := false;
  SIGNAL update_read_result : BOOLEAN := false;
BEGIN
  PORT MAP(
    clk
    rst
    read_addr
    read_data
    read_start
    read_complete
    read_result
    --  Read address channel signals
    M_AXI_ARADDR
    M_AXI_ARLEN
    M_AXI_ARSIZE
    M_AXI_ARBURST
    M_AXI_ARCACHE
    M_AXI_ARUSER
    M_AXI_ARVALID
    M_AXI_ARREADY
    -- Read data channel signals
    M_AXI_RDATA
    M_AXI_RRESP
    M_AXI_RLAST
    M_AXI_RVALID
    M_AXI_RREADY
  );

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
END ARCHITECTURE rtl;