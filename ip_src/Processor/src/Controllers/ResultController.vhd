
LIBRARY IEEE;--! standard library IEEE (Institute of Electrical and Electronics Engineers)
USE IEEE.std_logic_1164.ALL;--! standard unresolved logic UX01ZWLH-
USE IEEE.numeric_std.ALL;--! for the signed, unsigned types and arithmetic ops

-- -- -- -- Задача блока: -- -- -- --
-- 1. Записывать данных в регистр или в память (вместо памяти будет заглушка) 
------------------------------------

-- -- -- -- Распределение: -- -- -- --
-- Диана: 1
-------------------------------------

ENTITY ResultController IS
  PORT (
    refclk : IN STD_LOGIC;--! reference clock expect 250Mhz
    rst    : IN STD_LOGIC;--! sync active high reset. sync -> refclk

    result : IN STD_LOGIC_VECTOR(31 DOWNTO 0);

    valid : IN STD_LOGIC;
    ready : IN STD_LOGIC
  );
END ENTITY ResultController;
ARCHITECTURE rtl OF ResultController IS
BEGIN
END ARCHITECTURE rtl;