
LIBRARY IEEE;--! standard library IEEE (Institute of Electrical and Electronics Engineers)
USE IEEE.std_logic_1164.ALL;--! standard unresolved logic UX01ZWLH-
USE IEEE.numeric_std.ALL;--! for the signed, unsigned types and arithmetic ops

-- use work.Registers.mnemonic_pkg.ALL; Пакет для использования мнемоники 

-- -- -- -- Задача блока: -- -- -- --
-- 1. Хранение данных регистров
-- 2. Чтение-запись регистров
------------------------------------

-- -- -- -- Распределение: -- -- -- --
-- Дима: Регистры Базового набора RV32I
-------------------------------------

ENTITY Registers IS
  PORT (
    refclk : IN STD_LOGIC;--! reference clock expect 250Mhz
    rst    : IN STD_LOGIC;--! sync active high reset. sync -> refclk

    addr_in_i : IN STD_LOGIC_VECTOR(4 DOWNTO 0);  -- адрес регистра (0-31)
    data_in_i : IN STD_LOGIC_VECTOR(31 DOWNTO 0); -- данные которые хотим записать в регистр 

    addr_out_i_1 : IN STD_LOGIC_VECTOR(4 DOWNTO 0);   -- адрес регистра (0-31)
    data_out_i_1 : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); -- данные регистра по адресу

    addr_out_i_2 : IN STD_LOGIC_VECTOR(4 DOWNTO 0);   -- адрес регистра (0-31)
    data_out_i_2 : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); -- данные регистра по адресу

    write_enable : IN STD_LOGIC -- разрешение на запись, если 0 то данные возвращаются в data_out, иначе записываются в регистр из data_in
  );
END ENTITY Registers;

ARCHITECTURE rtl OF Registers IS
  TYPE reg_array_i IS ARRAY (0 TO 31) OF STD_LOGIC_VECTOR(31 DOWNTO 0);
  SIGNAL registers_i : reg_array_i := (OTHERS => (OTHERS => '0'));

BEGIN
  registers_i(0) <= (OTHERS => '0'); -- Обеспечиваем, что x0 всегда 0

  data_out_i_1 <= registers_i(to_integer(unsigned(addr_out_i_1))); -- Записывает в data_out_i чему равен регистр по адресу addr_i
  data_out_i_2 <= registers_i(to_integer(unsigned(addr_out_i_2))); -- Записывает в data_out_i чему равен регистр по адресу addr_i

  handle : PROCESS (rst, write_enable, addr_in_i, data_in_i)
  BEGIN
    IF rst = '1' THEN
      registers_i <= (OTHERS => (OTHERS => '0'));
    ELSE
      IF write_enable = '1' THEN
        IF unsigned(addr_in_i) /= 0 THEN
          registers_i(to_integer(unsigned(addr_in_i))) <= data_in_i;
        END IF;
      END IF;
    END IF;
  END PROCESS;
END ARCHITECTURE rtl;