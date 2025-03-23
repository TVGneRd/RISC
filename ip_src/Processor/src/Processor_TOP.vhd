
LIBRARY IEEE;--! standard library IEEE (Institute of Electrical and Electronics Engineers)
USE IEEE.std_logic_1164.ALL;--! standard unresolved logic UX01ZWLH-
USE IEEE.numeric_std.ALL;--! for the signed, unsigned types and arithmetic ops

-- -- -- -- Задача блока: -- -- -- --
-- 1. Подключение ядер
------------------------------------

-- -- -- -- Распределение: -- -- -- --
-- Дима:
-------------------------------------

ENTITY Processor_TOP IS
  PORT (
    refclk : IN STD_LOGIC;--! reference clock expect 250Mhz
    rst    : IN STD_LOGIC--! sync active high reset. sync -> refclk
  );
END ENTITY Processor_TOP;
ARCHITECTURE rtl OF Processor_TOP IS
BEGIN
END ARCHITECTURE rtl;