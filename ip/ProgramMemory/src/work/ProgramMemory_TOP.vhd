
LIBRARY IEEE;--! standard library IEEE (Institute of Electrical and Electronics Engineers)
USE IEEE.std_logic_1164.ALL;--! standard unresolved logic UX01ZWLH-
USE IEEE.numeric_std.ALL;--! for the signed, unsigned types and arithmetic ops

-- -- -- -- Задача блока: -- -- -- --
-- 1. Хранить в каком-то массиве код программы, либо считывает его из файла
-- 2. При запросе данных через протокол AXI4-MM по адресу возвращать нужные данные с учетом длины
-- 3. Размер шины данных строго 32 бита = 4 байта, далее 4 байта называется "словом", WORD - одна команда
-- 4. Размер шины адреса 12 бит, т.е размер погромы 2^12=4046 бит или 64 слова (команда)
------------------------------------

-- -- -- -- Распределение: -- -- -- --
-- Коля: 
-- - Протокол AXI4-MM Master (только чтение) 
-- - Функция выборки данных их памяти при запросе
-- Наташа: 
-- - Код программы
-------------------------------------

ENTITY ProgramMemory_TOP IS
  PORT (
    refclk : IN STD_LOGIC; --! reference clock expect 250Mhz
    rst    : IN STD_LOGIC; --! sync active high reset. sync -> refclk

    -- AXI-4 MM Ports
    -- address channel signals
    S_AXI_ARADDR  : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    S_AXI_ARLEN   : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    S_AXI_ARVALID : IN STD_LOGIC;
    S_AXI_ARREADY : OUT STD_LOGIC;

    -- data channel signals
    S_AXI_RDATA  : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    S_AXI_RRESP  : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    S_AXI_RLAST  : OUT STD_LOGIC;
    S_AXI_RVALID : OUT STD_LOGIC;
    S_AXI_RREADY : IN STD_LOGIC;

    -- Write channel
    S_AXI_AWADDR  : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    S_AXI_AWLEN   : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    S_AXI_AWVALID : IN STD_LOGIC;
    S_AXI_AWREADY : OUT STD_LOGIC;

    -- data channel signals
    S_AXI_WDATA  : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    S_AXI_WLAST  : IN STD_LOGIC;
    S_AXI_WVALID : IN STD_LOGIC;
    S_AXI_WREADY : OUT STD_LOGIC;

    --New data from Dima
    S_AXI_BRESP  : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    S_AXI_BVALID : OUT STD_LOGIC;
    S_AXI_BREADY : IN STD_LOGIC
  );

END ENTITY ProgramMemory_TOP;
ARCHITECTURE rtl OF ProgramMemory_TOP IS

  TYPE state_type_read IS (
    RESET,
    IDLE,
    PROCESS_ADDRESS,
    WAITING_DATA,
    CHECK_LEN,
    SEND_DATA
  );

  TYPE state_type_write IS (
    W_RESET,
    W_IDLE,
    W_PROCESS_ADDRESS,
    W_WAITING_DATA,
    W_SAVE_DATA
  );

  SIGNAL current_state, next_state     : state_type_read;
  SIGNAL w_current_state, w_next_state : state_type_write;

  SIGNAL addr_reg    : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
  SIGNAL w_addr_reg  : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
  SIGNAL len_counter : STD_LOGIC_VECTOR(7 DOWNTO 0)  := (OTHERS => '0');
  SIGNAL rdy         : STD_LOGIC                     := '0';
  SIGNAL val         : STD_LOGIC                     := '0';
  SIGNAL adrr_err    : STD_LOGIC                     := '0';
  SIGNAL rl          : STD_LOGIC                     := '0';

  TYPE memory_type IS ARRAY (0 TO 511) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL memory : memory_type := (
    --  4,       3        2         1        ,
    "10010011", "00000010", "10010000", "00000001",
    "00010011", "00000011", "11100000", "00000001",
    "10110011", "10000011", "01100010", "00000000",
    "00010011", "00001110", "01110000", "00000011",
    "01100011", "10011100", "11000011", "01000111",
    "10110011", "00000011", "01010011", "01000000",
    "00010011", "00001110", "01010000", "00000000",
    "11100011", "10010110", "11000011", "00100001",
    "10110111", "01010010", "01010101", "01010101",
    "10010011", "10000010", "01010010", "01010101",
    "00110111", "10100011", "10101010", "10101010",
    "00010011", "00000011", "10100011", "10101010",
    "10110011", "11110011", "01100010", "00000000",
    "11100011", "10011010", "00000011", "00111100",
    "10110011", "11100011", "01100010", "00000000",
    "00010011", "00001110", "11110000", "11111111",
    "10110011", "11000011", "01100010", "00000000",
    "10010011", "00000010", "01010000", "00000001",
    "00010011", "10010011", "10000010", "00000000",
    "10010011", "10010011", "00000010", "00000001",
    "00110011", "00001110", "01110011", "00000000",
    "10010011", "01011110", "10001110", "00000000",
    "00010011", "00001111", "01010000", "01010101",
    "11100011", "10010110", "11101110", "00110011",
    "10010011", "00000010", "10100000", "00000000",
    "00010011", "00000011", "01000000", "00000001",
    "01100011", "11001000", "01100010", "00000000",
    "01101111", "00010000", "00000000", "00100010",
    "11100011", "01010101", "01010011", "00111010",
    "00100011", "00100000", "01110001", "00000000",
    "00110011", "10000100", "01100010", "00000010",
    "10110011", "00100100", "01010011", "00000010",
    "00110011", "00110101", "01010011", "00000010",
    "00010011", "00000101", "00000000", "00000000",
    "10010011", "00000010", "00010000", "00000000",
    OTHERS => (OTHERS => '0')
  );

  CONSTANT MIN_ADDR : STD_LOGIC_VECTOR(11 DOWNTO 0) := "000000000000";
  CONSTANT MAX_ADDR : STD_LOGIC_VECTOR(11 DOWNTO 0) := x"1FF";

BEGIN

  state_register : PROCESS (refclk)
  BEGIN
    IF rising_edge(refclk) THEN
      IF rst = '1' THEN
        current_state   <= RESET;
        w_current_state <= W_RESET;
      ELSE
        current_state   <= next_state;
        w_current_state <= w_next_state;
      END IF;
    END IF;
  END PROCESS;

  stateWrite : PROCESS (w_current_state, S_AXI_AWVALID, S_AXI_WLAST, adrr_err)
  BEGIN
    CASE w_current_state IS
      WHEN W_RESET =>
        w_next_state <= W_IDLE;

      WHEN W_IDLE =>
        IF S_AXI_AWVALID = '1' THEN
          w_next_state <= W_PROCESS_ADDRESS;
        ELSE
          w_next_state <= W_IDLE;
        END IF;

      WHEN W_PROCESS_ADDRESS =>
        IF S_AXI_AWVALID = '0' THEN
          w_next_state <= W_WAITING_DATA;
        ELSE
          w_next_state <= W_PROCESS_ADDRESS;
        END IF;

      WHEN W_WAITING_DATA =>
        IF adrr_err = '1' THEN
          w_next_state <= W_IDLE;
        ELSE
          IF S_AXI_WVALID = '1' THEN
            w_next_state <= W_SAVE_DATA;
          ELSE
            w_next_state <= W_WAITING_DATA;
          END IF;
        END IF;

      WHEN W_SAVE_DATA => --?
        IF S_AXI_WVALID = '1' AND S_AXI_WLAST = '1' THEN
          w_next_state <= W_IDLE;
        ELSIF S_AXI_WVALID = '0' THEN
          w_next_state <= W_IDLE;
        END IF;
    END CASE;
  END PROCESS;

  stateRead : PROCESS (current_state, S_AXI_ARVALID, S_AXI_RREADY, len_counter, val)
  BEGIN
    CASE current_state IS
      WHEN RESET =>
        next_state <= IDLE;

      WHEN IDLE =>
        IF S_AXI_ARVALID = '1' THEN
          next_state <= PROCESS_ADDRESS;
        ELSE
          next_state <= IDLE;
        END IF;

      WHEN PROCESS_ADDRESS =>
        next_state <= WAITING_DATA;

      WHEN WAITING_DATA =>
        IF val = '1' THEN
          next_state <= SEND_DATA;
        ELSE
          next_state <= WAITING_DATA;
        END IF;

      WHEN SEND_DATA =>
        IF S_AXI_RREADY = '1' AND unsigned(len_counter) = 0 THEN
          next_state <= IDLE;
        ELSIF S_AXI_RREADY = '0' THEN
          next_state <= CHECK_LEN;
        END IF;

      WHEN CHECK_LEN =>
        IF unsigned(len_counter) = 0 THEN
          next_state <= IDLE;
        ELSIF S_AXI_RREADY = '1' THEN
          next_state <= SEND_DATA;
        END IF;

      WHEN OTHERS =>
        next_state <= IDLE;
    END CASE;
  END PROCESS;

  output_process : PROCESS (current_state)
  BEGIN
    CASE current_state IS
      WHEN IDLE =>
        S_AXI_ARREADY <= '1';
        S_AXI_RVALID  <= '0';
        S_AXI_RLAST   <= '0';

      WHEN PROCESS_ADDRESS =>
        S_AXI_ARREADY <= '0';
        addr_reg      <= S_AXI_ARADDR;
        len_counter   <= S_AXI_ARLEN;

      WHEN WAITING_DATA =>
        S_AXI_ARREADY                                                      <= '1';
        IF unsigned(addr_reg) >= unsigned(MIN_ADDR) AND unsigned(addr_reg) <= unsigned(MAX_ADDR) THEN
          val                                                                <= '1';
          S_AXI_RRESP                                                        <= "00";
        ELSE
          val         <= '1';
          len_counter <= (OTHERS => '0');
          S_AXI_RRESP <= "11";
        END IF;

      WHEN SEND_DATA =>
        S_AXI_RVALID          <= '1';
        IF unsigned(addr_reg) <= unsigned(MAX_ADDR) THEN
          S_AXI_RDATA           <= memory(to_integer(unsigned(addr_reg)));
          IF unsigned(len_counter) = 1 THEN
            S_AXI_RLAST <= '1';
          ELSE
            S_AXI_RLAST <= '0';
          END IF;
          addr_reg    <= STD_LOGIC_VECTOR(unsigned(addr_reg) + 1);
          len_counter <= STD_LOGIC_VECTOR(unsigned(len_counter) - 1);
        ELSE
          S_AXI_RRESP <= "11";
        END IF;

      WHEN CHECK_LEN =>
        S_AXI_RVALID <= '0';
        val          <= '0';

      WHEN OTHERS =>
        S_AXI_ARREADY <= '0';
        S_AXI_RVALID  <= '0';
        S_AXI_RLAST   <= '0';
        S_AXI_RDATA   <= (OTHERS => '0');
        S_AXI_RRESP   <= (OTHERS => '0');
    END CASE;
  END PROCESS;

  w_output_process : PROCESS (w_current_state)
  BEGIN
    CASE w_current_state IS
      WHEN W_IDLE =>
        S_AXI_AWREADY <= '1';
        S_AXI_WREADY  <= '0';
        S_AXI_BVALID  <= '0';
        adrr_err      <= '0';

      WHEN W_PROCESS_ADDRESS =>
        S_AXI_AWREADY <= '0';
        w_addr_reg    <= S_AXI_AWADDR;

      WHEN W_WAITING_DATA =>
        S_AXI_WREADY                                                           <= '1';
        IF unsigned(w_addr_reg) >= unsigned(MIN_ADDR) AND unsigned(w_addr_reg) <= unsigned(MAX_ADDR) THEN
          S_AXI_BRESP                                                            <= "00";

        ELSE
          S_AXI_BRESP  <= "11";
          adrr_err     <= '1';
          S_AXI_BVALID <= '1';
        END IF;

      WHEN W_SAVE_DATA =>
        memory(to_integer(unsigned(w_addr_reg))) <= S_AXI_WDATA;
        IF S_AXI_BREADY = '1' THEN
          S_AXI_BVALID <= '1';
        END IF;

      WHEN OTHERS =>
        S_AXI_AWREADY <= '0';
        S_AXI_WREADY  <= '0';
        S_AXI_BRESP   <= (OTHERS => '0');
        S_AXI_BVALID  <= '0';
    END CASE;
  END PROCESS;
END ARCHITECTURE rtl;