
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
    rst    : IN STD_LOGIC  --! sync active high reset. sync -> refclk

    -- AXI-4 MM Ports
    -- address channel signals
    M_AXI_ARADDR  : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    M_AXI_ARLEN   : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    M_AXI_ARVALID : IN STD_LOGIC;
    M_AXI_ARREADY : OUT STD_LOGIC;

    -- data channel signals
    M_AXI_RDATA  : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    M_AXI_RRESP  : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    M_AXI_RLAST  : OUT STD_LOGIC;
    M_AXI_RVALID : OUT STD_LOGIC;
    M_AXI_RREADY : IN STD_LOGIC
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
  SIGNAL addr_reg                  : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL len_counter               : STD_LOGIC_VECTOR(7 DOWNTO 0);

  TYPE memory_type IS ARRAY (0 TO 511) OF STD_LOGIC_VECTOR(31 DOWNTO 0);
  SIGNAL memory : memory_type := (
    -- команды
    OTHERS => (OTHERS => '0')
  );

  CONSTANT MIN_ADDR : STD_LOGIC_VECTOR(11 DOWNTO 0) := x"00";
  CONSTANT MAX_ADDR : STD_LOGIC_VECTOR(11 DOWNTO 0) := x"FFF";

BEGIN

  state_register : PROCESS (refclk)
  BEGIN
    IF rising_edge(refclk) THEN
      IF rst = '1' THEN
        current_state <= RESET_STATE;
      ELSE
        current_state <= next_state;
      END IF;
    END IF;
  END PROCESS;

  state : PROCESS (current_state, M_AXI_ARVALID, M_AXI_ARREADY, M_AXI_RREADY, len_counter, burst_len)
  BEGIN
    -- Значения по умолчанию
    M_AXI_ARREADY <= '0';
    M_AXI_RVALID  <= '0';
    M_AXI_RLAST   <= '0';

    CASE current_state IS
      WHEN RESET_STATE =>
        next_state <= IDLE;

      WHEN IDLE =>
        IF M_AXI_ARVALID = '1' THEN
          next_state <= PROCESS_ADDRESS;
        ELSE
          next_state <= IDLE;
        END IF;

      WHEN PROCESS_ADDRESS =>
        IF M_AXI_ARVALID = '1' AND M_AXI_ARREADY = '1' THEN
          next_state <= WAITING_DATA;
        ELSE
          next_state <= PROCESS_ADDRESS;
        END IF;

      WHEN WAITING_DATA =>
        IF M_AXI_RVALID = '1' THEN
          next_state <= SEND_DATA;
        ELSE
          next_state <= WAITING_DATA;
          M_AXI_RRESP = "11"
        END IF;

      WHEN SEND_DATA =>
        IF M_AXI_RREADY = '1' AND len_counter = '0' AND M_AXI_RLAST = '1' THEN
          next_state <= IDLE;
        ELSE
          IF M_AXI_RREADY = '0' AND M_AXI_RVALID = '1' THEN
            next_state <= CHECK_LEN;
          END IF;

        WHEN CHECK_LEN =>
          IF M_AXI_RREADY = '1' AND len_counter > 0 THEN
            next_state <= SEND_DATA;
          ELSE
            M_AXI_RRESP = "00"
            next_state <= IDLE;
          END IF;

        WHEN OTHERS =>
          next_state <= IDLE;
        END CASE;
    END PROCESS;

    action : PROCESS (current_state, M_AXI_ARVALID, M_AXI_ARREADY, M_AXI_RREADY, len_counter)
    BEGIN

      CASE current_state IS
        WHEN PROCESS_ADDRESS =>
          M_AXI_ARREADY <= '1';

        WHEN WAITING_DATA => -- исправить
          addr_reg    <= M_AXI_ARADDR;
          len_counter <= M_AXI_ARLEN;

          IF addr_reg >= MIN_ADDR AND addr_reg <= MAX_ADDR THEN
            M_AXI_RVALID                         <= '1';
          END IF;

        WHEN SEND_DATA =>
          M_AXI_RDATA <= memory(addr_reg);
          addr_reg = addr_reg + 1;
          len_counter = len_counter - 1;

      END CASE;

    END PROCESS;

  END ARCHITECTURE rtl;