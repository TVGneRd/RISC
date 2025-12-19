
LIBRARY IEEE;--! standard library IEEE (Institute of Electrical and Electronics Engineers)
USE IEEE.std_logic_1164.ALL;--! standard unresolved logic UX01ZWLH-
USE IEEE.numeric_std.ALL;--! for the signed, unsigned types and arithmetic ops

-- use work.Registers.mnemonic_pkg.ALL; Пакет для использования мнемоники 

-- -- -- -- Задача блока: -- -- -- --
-- 1. Хранение данных регистров
-- 2. Чтение-запись регистров
-- 3. 4 канала чтения (по 2 порта на конвейер) и 4 канала записи
------------------------------------

-- -- -- -- Распределение: -- -- -- --
-- Дима: Регистры Базового набора RV32I
-------------------------------------

ENTITY Registers IS
  PORT (
    refclk : IN STD_LOGIC;--! reference clock expect 250Mhz
    rst    : IN STD_LOGIC;--! sync active high reset. sync -> refclk

    -- Pipeline 0: Read/Write Interface
    p0_addr_out_1 : IN STD_LOGIC_VECTOR(4 DOWNTO 0);   -- адрес регистра rs1
    p0_data_out_1 : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); -- данные регистра rs1
    p0_addr_out_2 : IN STD_LOGIC_VECTOR(4 DOWNTO 0);   -- адрес регистра rs2
    p0_data_out_2 : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); -- данные регистра rs2
    p0_addr_in    : IN STD_LOGIC_VECTOR(4 DOWNTO 0);   -- адрес регистра для записи
    p0_data_in    : IN STD_LOGIC_VECTOR(31 DOWNTO 0);  -- данные для записи
    p0_write_en   : IN STD_LOGIC;                      -- разрешение записи

    -- Pipeline 1: Read/Write Interface
    p1_addr_out_1 : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    p1_data_out_1 : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    p1_addr_out_2 : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    p1_data_out_2 : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    p1_addr_in    : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    p1_data_in    : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    p1_write_en   : IN STD_LOGIC;

    -- Pipeline 2: Read/Write Interface
    p2_addr_out_1 : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    p2_data_out_1 : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    p2_addr_out_2 : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    p2_data_out_2 : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    p2_addr_in    : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    p2_data_in    : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    p2_write_en   : IN STD_LOGIC;

    -- Pipeline 3: Read/Write Interface
    p3_addr_out_1 : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    p3_data_out_1 : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    p3_addr_out_2 : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    p3_data_out_2 : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    p3_addr_in    : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    p3_data_in    : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    p3_write_en   : IN STD_LOGIC
  );
END ENTITY Registers;

ARCHITECTURE rtl OF Registers IS
  TYPE reg_array_i IS ARRAY (0 TO 31) OF STD_LOGIC_VECTOR(31 DOWNTO 0);
  SIGNAL registers_i : reg_array_i := (OTHERS => (OTHERS => '0'));

BEGIN
  registers_i(0) <= (OTHERS => '0'); -- Обеспечиваем, что x0 всегда 0

  -- Чтение для всех конвейеров (комбинаторное)
  -- Pipeline 0
  p0_data_out_1 <= registers_i(to_integer(unsigned(p0_addr_out_1)));
  p0_data_out_2 <= registers_i(to_integer(unsigned(p0_addr_out_2)));
  -- Pipeline 1
  p1_data_out_1 <= registers_i(to_integer(unsigned(p1_addr_out_1)));
  p1_data_out_2 <= registers_i(to_integer(unsigned(p1_addr_out_2)));
  -- Pipeline 2
  p2_data_out_1 <= registers_i(to_integer(unsigned(p2_addr_out_1)));
  p2_data_out_2 <= registers_i(to_integer(unsigned(p2_addr_out_2)));
  -- Pipeline 3
  p3_data_out_1 <= registers_i(to_integer(unsigned(p3_addr_out_1)));
  p3_data_out_2 <= registers_i(to_integer(unsigned(p3_addr_out_2)));

  -- Запись из всех конвейеров параллельно
  -- Приоритет при конфликте: Pipeline 0 > Pipeline 1 > Pipeline 2 > Pipeline 3
  handle : PROCESS (refclk)
  BEGIN
    IF rising_edge(refclk) THEN
      IF rst = '1' THEN
        registers_i <= (OTHERS => (OTHERS => '0'));
      ELSE
        -- Pipeline 3 (самый низкий приоритет - записывается первым, может быть перезаписан)
        IF p3_write_en = '1' AND unsigned(p3_addr_in) /= 0 THEN
          registers_i(to_integer(unsigned(p3_addr_in))) <= p3_data_in;
        END IF;
        -- Pipeline 2
        IF p2_write_en = '1' AND unsigned(p2_addr_in) /= 0 THEN
          registers_i(to_integer(unsigned(p2_addr_in))) <= p2_data_in;
        END IF;
        -- Pipeline 1
        IF p1_write_en = '1' AND unsigned(p1_addr_in) /= 0 THEN
          registers_i(to_integer(unsigned(p1_addr_in))) <= p1_data_in;
        END IF;
        -- Pipeline 0 (самый высокий приоритет - записывается последним)
        IF p0_write_en = '1' AND unsigned(p0_addr_in) /= 0 THEN
          registers_i(to_integer(unsigned(p0_addr_in))) <= p0_data_in;
        END IF;
      END IF;
    END IF;
  END PROCESS;
END ARCHITECTURE rtl;