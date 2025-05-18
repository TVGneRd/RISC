
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
    S_AXI_BRESP  : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    S_AXI_BVALID : IN STD_LOGIC;
    S_AXI_BREADY : OUT STD_LOGIC
  );

END ENTITY ProgramMemory_TOP;
ARCHITECTURE rtl OF ProgramMemory_TOP IS

  TYPE state_type IS (
    RESET,
    IDLE,
    PROCESS_ADDRESS,
    WAITING_DATA,
    CHECK_LEN,
    SEND_DATA
  );

  SIGNAL current_state, next_state : state_type;
  SIGNAL addr_reg                  : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
  SIGNAL len_counter               : STD_LOGIC_VECTOR(7 DOWNTO 0)  := (OTHERS => '0');
  SIGNAL rdy                       : STD_LOGIC                     := '0';
  SIGNAL val                       : STD_LOGIC                     := '0';
  SIGNAL rl                        : STD_LOGIC                     := '0';

  TYPE memory_type IS ARRAY (0 TO 511) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL memory : memory_type := (
    "00000001", "10010000", "00000010", "10010011",
    "00000001", "11100000", "00000011", "00010011",
    "00000000", "01100010", "10000011", "10110011",
    "00000011", "01110000", "00001110", "00010011",
    "00000101", "11000011", "10010100", "01100011",
    "01000000", "01010011", "00000011", "10110011",
    "00000000", "01010000", "00001110", "00010011",
    "00000101", "11000011", "10010101", "01100011",
    "01010101", "01010101", "01010010", "10110111",
    "01010101", "01010010", "10000010", "10010011",
    "10101010", "10101010", "10100011", "00110111",
    "10101010", "10100011", "00000011", "00010011",
    "00000000", "01100010", "11110011", "10110011",
    "00001000", "00000011", "10010101", "01100011",
    "00000000", "01100010", "11100011", "10110011",
    "11111111", "11110000", "00001110", "00010011",
    "00000000", "01100010", "11000011", "10110011",
    "00000001", "01010000", "00000010", "10010011",
    "00000000", "10000010", "10010011", "00010011",
    "00000001", "00000010", "10010011", "10010011",
    "00000000", "01110011", "00001110", "00110011",
    "00000000", "10001110", "01011110", "10010011",
    "01010101", "01010000", "00001111", "00010011",
    "00001011", "11011101", "10010101", "01100011",
    "00000000", "10100000", "00000010", "10010011",
    "00000001", "01000000", "00000011", "00010011",
    "00000100", "01100010", "11001101", "01100011",
    "00000000", "11100000", "00000000", "01101111",
    "00001000", "01010011", "01010000", "01100011",
    "00000000", "11100000", "00000000", "01101111",
    "00100011", "01000000", "00000010", "10010011",
    "01010101", "10101010", "01010101", "00110111",
    "01011010", "10100101", "00000101", "00010011",
    "00000001", "01000000", "00000000", "01101111",
    "00000000", "00000000", "00000101", "00010011",
    "00000000", "00010000", "00000010", "10010011",
    OTHERS => (OTHERS => '0')
  );

  CONSTANT MIN_ADDR : STD_LOGIC_VECTOR(11 DOWNTO 0) := "000000000000";
  CONSTANT MAX_ADDR : STD_LOGIC_VECTOR(11 DOWNTO 0) := x"1FF";

BEGIN

  state_register : PROCESS (refclk)
  BEGIN
    IF rising_edge(refclk) THEN
      IF rst = '1' THEN
        current_state <= RESET;
      ELSE
        current_state <= next_state;
      END IF;
    END IF;
  END PROCESS;

  state : PROCESS (current_state, S_AXI_ARVALID, S_AXI_RREADY, len_counter, val)
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

END ARCHITECTURE rtl;