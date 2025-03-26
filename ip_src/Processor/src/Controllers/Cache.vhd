
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
    data    : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
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
  CONSTANT cash_size : INTEGER := 64;

  TYPE state_type IS (rst_state, IDLE, CHECK_ADDR, LOAD_DATA, REQUEST_DATA, WAIT_END_TRANSACTION);
  SIGNAL cur_state  : state_type := rst_state;
  SIGNAL next_state : state_type := rst_state;

  SIGNAL update_read_data   : BOOLEAN                       := false;
  SIGNAL update_read_addr   : BOOLEAN                       := false;
  SIGNAL update_read_result : BOOLEAN                       := false;
  SIGNAL AXI_1_read_addr    : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
  SIGNAL AXI_1_read_len     : STD_LOGIC_VECTOR(7 DOWNTO 0)  := STD_LOGIC_VECTOR(to_unsigned(cash_size, 8));
  SIGNAL AXI_1_read_data    : STD_LOGIC_VECTOR(7 DOWNTO 0)  := (OTHERS => '0');

  SIGNAL AXI_1_read_start    : STD_LOGIC := '0';
  SIGNAL AXI_1_read_last     : STD_LOGIC := '1';
  SIGNAL AXI_1_read_complete : STD_LOGIC;
  SIGNAL AXI_1_read_result   : STD_LOGIC_VECTOR(1 DOWNTO 0);

  SIGNAL cache_upper_bound : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
  SIGNAL cache_pointer     : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');

  TYPE cache_data_type IS ARRAY (0 TO cash_size) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL cache_data : cache_data_type := (
    OTHERS => (OTHERS => '0')
  );

BEGIN
  reader : ENTITY work.axi4_reader
    PORT MAP(
      clk => refclk,
      rst => rst,

      read_addr     => AXI_1_read_addr,
      read_len      => AXI_1_read_len,
      read_data     => AXI_1_read_data,
      read_start    => AXI_1_read_start,
      read_complete => AXI_1_read_complete,
      read_last     => AXI_1_read_last,
      read_result   => AXI_1_read_result,

      --  Read address channel signals
      M_AXI_ARADDR  => M_AXI_ARADDR,
      M_AXI_ARLEN   => M_AXI_ARLEN,
      M_AXI_ARVALID => M_AXI_ARVALID,
      M_AXI_ARREADY => M_AXI_ARREADY,
      -- Read data channel signals
      M_AXI_RDATA  => M_AXI_RDATA,
      M_AXI_RRESP  => M_AXI_RRESP,
      M_AXI_RLAST  => M_AXI_RLAST,
      M_AXI_RVALID => M_AXI_RVALID,
      M_AXI_RREADY => M_AXI_RREADY
    );

  -- Handles the cur_state variable
  sync_proc : PROCESS (refclk, rst)
  BEGIN
    IF rst = '0' THEN
      cur_state <= rst_state;
    ELSIF rising_edge(refclk) THEN
      cur_state <= next_state;
    END IF;
  END PROCESS;

  -- handles the next_state variable
  state_transmission : PROCESS (refclk, cur_state)
  BEGIN
    next_state <= cur_state;
    CASE cur_state IS
      WHEN rst_state =>
        next_state <= IDLE;
      WHEN IDLE =>
        IF valid = '1' THEN
          next_state <= CHECK_ADDR;
        END IF;
      WHEN CHECK_ADDR =>
        IF (unsigned(address) - cash_size) < unsigned(cache_upper_bound) THEN
          next_state <= LOAD_DATA;
        ELSE
          next_state <= REQUEST_DATA;
        END IF;
      WHEN LOAD_DATA =>
        next_state <= IDLE;
      WHEN REQUEST_DATA =>
        IF AXI_1_read_complete = '1' THEN
          next_state <= WAIT_END_TRANSACTION;
        END IF;
      WHEN WAIT_END_TRANSACTION =>
        IF AXI_1_read_last = '1' THEN
          next_state <= LOAD_DATA;
        END IF;
    END CASE;
  END PROCESS;

  -- The state decides the output
  output_decider : PROCESS (refclk, cur_state)
  BEGIN
    CASE cur_state IS
      WHEN rst_state =>
        -- ДОБАВИТЬ!

      WHEN CHECK_ADDR =>
        -- ДОБАВИТЬ!
        cache_pointer <= (OTHERS => '0');

      WHEN REQUEST_DATA =>
        AXI_1_read_addr  <= address;
        AXI_1_read_len   <= STD_LOGIC_VECTOR(to_unsigned(cache_size, 7));
        AXI_1_read_start <= '1';
        data             <= (OTHERS => '0');
        ready            <= '0';
        cache_pointer    <= cache_pointer;

      WHEN LOAD_DATA              =>
        AXI_1_read_addr  <= (OTHERS => '0');
        AXI_1_read_len   <= (OTHERS => '0');
        AXI_1_read_start <= '0';
        data             <= cache_data(to_integer(unsigned(address) MOD cache_size));
        ready            <= '1';

      WHEN WAIT_END_TRANSACTION =>
        AXI_1_read_addr  <= AXI_1_read_addr;
        AXI_1_read_len   <= AXI_1_read_len;
        AXI_1_read_start <= AXI_1_read_start;
        data             <= (OTHERS => '0');
        ready            <= '0';

        IF AXI_1_read_complete = '1' THEN
          cache_data(to_integer(unsigned(address) MOD cache_size + unsigned(cache_pointer))) <= AXI_1_read_data;
          cache_pointer                                                                      <= STD_LOGIC_VECTOR(unsigned(cache_pointer) + 1);
        END IF;
    END CASE;
  END PROCESS;
END ARCHITECTURE rtl;