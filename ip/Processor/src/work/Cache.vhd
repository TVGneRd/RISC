
LIBRARY IEEE;--! standard library IEEE (Institute of Electrical and Electronics Engineers)
USE IEEE.std_logic_1164.ALL;--! standard unresolved logic UX01ZWLH-
USE IEEE.numeric_std.ALL;--! for the signed, unsigned types and arithmetic ops

-- -- -- -- Задача блока: -- -- -- --
-- 1. Дождаться valid=1, сделать ready=0
-- 2. Проверить находится ли address в диапазоне кэша address <= cache_upper_bound && address > cache_upper_bound - cache_size
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

    -- (КАНАЛ ЧТЕНИЯ) Порты для взаимодействия с ядром процессором, через него возвращаются данные из кэша
    r_address : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    r_data    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    r_valid   : IN STD_LOGIC;
    r_ready   : OUT STD_LOGIC;

    -- (КАНАЛ ЗАПИСИ) Порты для взаимодействия с ядром процессором, через него возвращаются данные из кэша
    w_address : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    w_data    : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    w_valid   : IN STD_LOGIC;
    w_ready   : OUT STD_LOGIC;

    -- AXI-4 MM (Только Reader) Ports
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
    M_AXI_RREADY : OUT STD_LOGIC;
    -- /AXI-4 MM (Только Reader) Ports

    -- AXI-4 MM (Writer) Ports
    --  Read address channel signals
    M_AXI_AWADDR  : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    M_AXI_AWLEN   : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    M_AXI_AWVALID : OUT STD_LOGIC;
    M_AXI_AWREADY : IN STD_LOGIC;

    -- Read data channel signals
    M_AXI_WDATA  : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    M_AXI_WLAST  : OUT STD_LOGIC; -- всегда 1
    M_AXI_WVALID : OUT STD_LOGIC;
    M_AXI_WREADY : IN STD_LOGIC;
    -- /AXI-4 MM (Writer) Ports

    M_AXI_BRESP  : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    M_AXI_BVALID : IN STD_LOGIC;
    M_AXI_BREADY : OUT STD_LOGIC
  );
END ENTITY Cache;
ARCHITECTURE rtl OF Cache IS
  TYPE r_state_type IS (R_RESET, R_IDLE, R_FAST_LOAD, R_WAIT_END_TRANSACTION);

  TYPE w_state_type IS (W_RESET, W_IDLE, W_WRITE_CACHE, W_WRITE_MEMORY);

  SIGNAL r_cur_state  : r_state_type := R_RESET;
  SIGNAL r_next_state : r_state_type := R_RESET;

  SIGNAL w_cur_state  : w_state_type := W_RESET;
  SIGNAL w_next_state : w_state_type := W_RESET;

  SIGNAL update_read_data   : BOOLEAN                       := false;
  SIGNAL update_read_addr   : BOOLEAN                       := false;
  SIGNAL update_read_result : BOOLEAN                       := false;
  SIGNAL AXI_1_read_addr    : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
  SIGNAL AXI_1_read_len     : STD_LOGIC_VECTOR(7 DOWNTO 0)  := STD_LOGIC_VECTOR(to_unsigned(cache_size, 8));
  SIGNAL AXI_1_read_data    : STD_LOGIC_VECTOR(7 DOWNTO 0)  := (OTHERS => '0');

  SIGNAL AXI_1_read_start    : STD_LOGIC := '0';
  SIGNAL AXI_1_read_last     : STD_LOGIC := '1';
  SIGNAL AXI_1_read_complete : STD_LOGIC;
  SIGNAL AXI_1_read_result   : STD_LOGIC_VECTOR(1 DOWNTO 0);

  SIGNAL AXI_1_write_addr : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
  SIGNAL AXI_1_write_len  : STD_LOGIC_VECTOR(7 DOWNTO 0)  := STD_LOGIC_VECTOR(to_unsigned(cache_size, 8));
  SIGNAL AXI_1_write_data : STD_LOGIC_VECTOR(7 DOWNTO 0)  := (OTHERS => '0');

  SIGNAL AXI_1_write_start    : STD_LOGIC := '0';
  SIGNAL AXI_1_write_last     : STD_LOGIC := '1';
  SIGNAL AXI_1_write_complete : STD_LOGIC;
  SIGNAL AXI_1_write_result   : STD_LOGIC_VECTOR(1 DOWNTO 0);

  SIGNAL cache_upper_bound : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
  SIGNAL cache_pointer     : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');

  TYPE cache_data_type IS ARRAY (0 TO cache_size - 1) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL cache_data : cache_data_type := (
    OTHERS => (OTHERS => '0')
  );

  SIGNAL read_cache_hit : BOOLEAN := false;

BEGIN
  read_cache_hit <= unsigned(r_address) <= (unsigned(cache_upper_bound) + 2) AND unsigned(r_address) >= (unsigned(cache_upper_bound) - cache_size + 1);

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

  writer : ENTITY work.axi4_writer
    PORT MAP(
      clk => refclk,
      rst => rst,

      write_addr     => AXI_1_write_addr,
      write_data     => AXI_1_write_data,
      write_start    => AXI_1_write_start,
      write_complete => AXI_1_write_complete,
      write_result   => AXI_1_write_result,

      M_AXI_AWADDR  => M_AXI_AWADDR,
      M_AXI_AWVALID => M_AXI_AWVALID,
      M_AXI_AWREADY => M_AXI_AWREADY,
      M_AXI_AWLEN   => M_AXI_AWLEN,

      M_AXI_WDATA  => M_AXI_WDATA,
      M_AXI_WVALID => M_AXI_WVALID,
      M_AXI_WREADY => M_AXI_WREADY,
      M_AXI_WLAST  => M_AXI_WLAST,

      M_AXI_BRESP  => M_AXI_BRESP,
      M_AXI_BVALID => M_AXI_BVALID,
      M_AXI_BREADY => M_AXI_BREADY
    );

  -- Handles the r_cur_state variable
  sync_proc : PROCESS (refclk, rst)
  BEGIN
    IF rst = '1' THEN
      r_cur_state <= R_RESET;
      w_cur_state <= W_RESET;
    ELSIF rising_edge(refclk) THEN
      r_cur_state <= r_next_state;
      w_cur_state <= w_next_state;
    END IF;
  END PROCESS;

  -- handles the r_next_state variable
  r_state_transmission : PROCESS (refclk, r_valid, AXI_1_read_complete)
  BEGIN
    r_next_state <= r_cur_state;

    CASE r_cur_state IS
      WHEN R_RESET =>
        r_next_state <= R_IDLE;

      WHEN R_IDLE =>
        IF r_valid = '1' THEN
          IF read_cache_hit THEN
            r_next_state <= R_FAST_LOAD;
          ELSE
            r_next_state <= R_WAIT_END_TRANSACTION;
          END IF;
        END IF;

      WHEN R_FAST_LOAD =>
        r_next_state <= R_WAIT_END_TRANSACTION;

        IF r_valid = '1' AND read_cache_hit THEN
          r_next_state <= R_FAST_LOAD;
        END IF;

      WHEN R_WAIT_END_TRANSACTION =>
        IF AXI_1_read_complete = '1' AND AXI_1_read_last = '1' THEN
          IF r_valid = '0' THEN
            r_next_state <= R_IDLE;
          ELSE
            r_next_state <= R_FAST_LOAD;
          END IF;
        END IF;
    END CASE;
  END PROCESS;

  -- handles the r_next_state variable
  w_state_transmission : PROCESS (refclk, w_cur_state, w_valid, AXI_1_write_complete)
  BEGIN
    w_next_state <= w_cur_state;
    CASE w_cur_state IS
      WHEN W_RESET =>
        w_next_state <= W_IDLE;

      WHEN W_IDLE =>
        IF w_valid = '1' THEN
          w_next_state <= W_WRITE_CACHE;
        END IF;

      WHEN W_WRITE_CACHE =>
        -- Check if address is in cache
        IF unsigned(w_address) <= unsigned(cache_upper_bound) AND
          unsigned(w_address) >= (unsigned(cache_upper_bound) - cache_size + 1) THEN
          -- Address is in cache, update cache
          w_next_state <= W_IDLE;
        ELSE
          -- Address not in cache, write directly to memory
          w_next_state <= W_WRITE_MEMORY;
        END IF;

      WHEN W_WRITE_MEMORY =>
        IF AXI_1_write_complete = '1' THEN
          w_next_state <= W_IDLE;
        END IF;

    END CASE;
  END PROCESS;

  -- The state decides the output
  r_output_decider : PROCESS (refclk, r_cur_state, read_cache_hit)
  BEGIN
    IF rising_edge(refclk) THEN
      r_data <= cache_data(to_integer((unsigned(r_address) + 3) MOD cache_size)) & -- Байт 3 (старший)
        cache_data(to_integer((unsigned(r_address) + 2) MOD cache_size)) &           -- Байт 2
        cache_data(to_integer((unsigned(r_address) + 1) MOD cache_size)) &           -- Байт 1
        cache_data(to_integer(unsigned(r_address) MOD cache_size));                  -- Байт 0 (младший)
    END IF;

    CASE r_cur_state IS
      WHEN R_RESET                =>
        AXI_1_read_addr  <= (OTHERS => '0');
        AXI_1_read_len   <= (OTHERS => '0');
        AXI_1_read_start <= '0';
        r_ready          <= '0';
      WHEN R_IDLE                 =>
        AXI_1_read_addr  <= (OTHERS => '0');
        AXI_1_read_len   <= (OTHERS => '0');
        AXI_1_read_start <= '0';
        r_ready          <= '1';
      WHEN R_FAST_LOAD            =>
        AXI_1_read_addr  <= (OTHERS => '0');
        AXI_1_read_len   <= (OTHERS => '0');
        AXI_1_read_start <= '0';
        r_ready          <= '0';

        IF read_cache_hit THEN
          r_ready <= '1';
        END IF;

      WHEN R_WAIT_END_TRANSACTION =>
        AXI_1_read_addr <= r_address;
        AXI_1_read_len  <= STD_LOGIC_VECTOR(to_unsigned(cache_size, 8));
        IF AXI_1_read_complete = '1' THEN
          AXI_1_read_start <= '0';
        ELSE
          AXI_1_read_start <= '1';
        END IF;

        r_ready <= '0';
        IF AXI_1_read_last = '1' THEN
          r_ready <= '1';
        END IF;
    END CASE;

  END PROCESS;

  safe_data : PROCESS (AXI_1_read_complete, r_cur_state)
  BEGIN
    IF rising_edge(AXI_1_read_complete) THEN
      cache_pointer     <= STD_LOGIC_VECTOR(unsigned(cache_pointer) + 1);
      cache_upper_bound <= STD_LOGIC_VECTOR(unsigned(r_address) + unsigned(cache_pointer));
    ELSIF AXI_1_read_complete = '1' THEN
      cache_pointer     <= cache_pointer;
      cache_upper_bound <= cache_upper_bound;
    ELSIF r_cur_state /= R_WAIT_END_TRANSACTION THEN
      cache_pointer     <= (OTHERS => '0');
      cache_upper_bound <= cache_upper_bound;
    END IF;
  END PROCESS safe_data;

  -- The state decides the output
  w_output_decider : PROCESS (refclk, w_cur_state, AXI_1_write_complete)
  BEGIN
    CASE w_cur_state IS
      WHEN W_RESET                 =>
        AXI_1_write_addr  <= (OTHERS => '0');
        AXI_1_write_data  <= (OTHERS => '0');
        AXI_1_write_start <= '0';
        w_ready           <= '0';

      WHEN W_IDLE                  =>
        AXI_1_write_addr  <= (OTHERS => '0');
        AXI_1_write_data  <= (OTHERS => '0');
        AXI_1_write_start <= '0';
        w_ready           <= '1';

      WHEN W_WRITE_CACHE =>
        -- Prepare memory write in any case (write-through policy)
        AXI_1_write_addr  <= w_address;
        AXI_1_write_data  <= w_data;
        AXI_1_write_start <= '1';

        w_ready <= '0';

      WHEN W_WRITE_MEMORY =>
        AXI_1_write_start <= '0'; -- Deassert after one cycle

        IF AXI_1_write_complete = '1' THEN
          w_ready <= '1';
        ELSE
          w_ready <= '0';
        END IF;
    END CASE;

  END PROCESS;
  write_cache : PROCESS (w_cur_state, r_cur_state, AXI_1_read_complete)
  BEGIN

    IF w_cur_state = W_WRITE_CACHE THEN
      IF unsigned(w_address)                                     <= unsigned(cache_upper_bound) AND
        unsigned(w_address)                                        <= unsigned(cache_upper_bound) - cache_size + 1 THEN
        cache_data(to_integer(unsigned(w_address) MOD cache_size)) <= w_data;
      END IF;
    END IF;

    IF r_cur_state = R_WAIT_END_TRANSACTION THEN
      IF rising_edge(AXI_1_read_complete) THEN
        cache_data(to_integer(unsigned(cache_pointer))) <= AXI_1_read_data;
      END IF;
    END IF;

  END PROCESS;

END ARCHITECTURE rtl;