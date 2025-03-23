
LIBRARY IEEE;--! standard library IEEE (Institute of Electrical and Electronics Engineers)
USE IEEE.std_logic_1164.ALL;--! standard unresolved logic UX01ZWLH-
USE IEEE.numeric_std.ALL;--! for the signed, unsigned types and arithmetic ops

-- -- -- -- Задача блока: -- -- -- --
-- 1. Выполнять переходы и системные функции
------------------------------------

-- -- -- -- Распределение: -- -- -- --
-- Дима: 1
-------------------------------------

ENTITY ControlUnit IS
  PORT (
    refclk : IN STD_LOGIC;--! reference clock expect 250Mhz
    rst    : IN STD_LOGIC--! sync active high reset. sync -> refclk
  );
END ENTITY ControlUnit;
ARCHITECTURE rtl OF ControlUnit IS
BEGIN
END ARCHITECTURE rtl;