
LIBRARY IEEE;--! standard library IEEE (Institute of Electrical and Electronics Engineers)
USE IEEE.std_logic_1164.ALL;--! standard unresolved logic UX01ZWLH-
USE IEEE.numeric_std.ALL;--! for the signed, unsigned types and arithmetic ops

-- -- -- -- Задача блока: -- -- -- --
-- 1. Записывать данных в регистр 
------------------------------------

-- -- -- -- Распределение: -- -- -- --
-- Андрей: 1
-------------------------------------

ENTITY ResultController IS
  PORT (
    refclk : IN STD_LOGIC;--! reference clock expect 250Mhz
    rst    : IN STD_LOGIC;--! sync active high reset. sync -> refclk

    enable  : IN STD_LOGIC;
    result  : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    rd_addr : IN STD_LOGIC_VECTOR(4 DOWNTO 0); -- Адрес регистра rd

    reg_addr_in      : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);  -- адрес регистра (0-31)
    reg_data_in      : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); -- данные которые хотим записать в регистр 
    reg_write_enable : OUT STD_LOGIC                      -- разрешение на запись, если 0 то данные возвращаются в data_out, иначе записываются в регистр из data_in
  );
END ENTITY ResultController;

ARCHITECTURE rtl OF ResultController IS
  -- Сигналы для соединения с модулем Registers
  SIGNAL reg_addr_internal  : STD_LOGIC_VECTOR(4 DOWNTO 0)  := (OTHERS => '0');
  SIGNAL reg_data_internal  : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
  SIGNAL reg_write_internal : STD_LOGIC                     := '0';
  SIGNAL data_out_unused    : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); -- Не используется

BEGIN
  -- Логика управления записью
  PROCESS (refclk, rst)
  BEGIN
    IF rst = '1' THEN
      reg_addr_internal  <= (OTHERS => '0');
      reg_data_internal  <= (OTHERS => '0');
      reg_write_internal <= '0';
    ELSIF rising_edge(refclk) THEN
      IF enable = '1' THEN
        reg_addr_internal  <= rd_addr;
        reg_data_internal  <= result;
        reg_write_internal <= '1';
      ELSE
        reg_addr_internal  <= (OTHERS => '0');
        reg_data_internal  <= (OTHERS => '0');
        reg_write_internal <= '0';
      END IF;
    END IF;
  END PROCESS;

  -- Подключение внутренних сигналов к выходам
  reg_addr_in      <= reg_addr_internal;
  reg_data_in      <= reg_data_internal;
  reg_write_enable <= reg_write_internal;

END ARCHITECTURE rtl;