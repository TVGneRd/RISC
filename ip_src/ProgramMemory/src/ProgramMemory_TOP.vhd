
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
    S_AXI_WRESP  : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    S_AXI_WLAST  : IN STD_LOGIC;
    S_AXI_WVALID : IN STD_LOGIC;
    S_AXI_WREADY : OUT STD_LOGIC
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
    "00000001100100000000001010010011",
    "00000001111000000000001100010011",
    "00000000011000101000001110110011",
    "00000011011100000000111000010011",
    "00000101110000111001010001100011",
    "01000000010100110000001110110011",
    "00000000010100000000111000010011",
    "00000101110000111001010101100011",
    "01010101010101010101001010110111",
    "01010101010100101000001010010011",
    "10101010101010101010001100110111",
    "10101010101000110000001100010011",
    "00000000011000101111001110110011",
    "00001000000000111001010101100011",
    "00000000011000101110001110110011",
    "11111111111100000000111000010011",
    "00000000011000101100001110110011",
    "00000001010100000000001010010011",
    "00000000100000101001001100010011",
    "00000001000000101001001110010011",
    "00000000011100110000111000110011",
    "00000000100011100101111010010011",
    "01010101010100000000111100010011",
    "00001011110111011001010101100011",
    "00000000101000000000001010010011",
    "00000001010000000000001100010011",
    "00000100011000101100110101100011",
    "00000000111000000000000001101111",
    "00001000010100110101000001100011",
    "00000000111000000000000001101111",
    "00100011010000000000001010010011",
    "01010101101010100101010100110111",
    "01011010101001010000010100010011",
    "00000001010000000000000001101111",
    "00000000000000000000010100010011",
    "00000000000100000000001010010011",
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