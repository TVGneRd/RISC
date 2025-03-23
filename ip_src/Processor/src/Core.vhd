
LIBRARY IEEE;--! standard library IEEE (Institute of Electrical and Electronics Engineers)
USE IEEE.std_logic_1164.ALL;--! standard unresolved logic UX01ZWLH-
USE IEEE.numeric_std.ALL;--! for the signed, unsigned types and arithmetic ops

-- -- -- -- Задача блока: -- -- -- --
-- 1. Подключение регистров и распространение его в остальные модули 
-- 2. Конвейер, 4 ступени
-- 3. Передача команды в декодер
-- 4. Передача данных на АЛУ
-- 5. Запись данных в результирующий/регистр
------------------------------------

-- -- -- -- Распределение: -- -- -- --
-- Дима:
-- Андрей:
-- Диана:
-------------------------------------

ENTITY Core IS
  PORT (
    refclk : IN STD_LOGIC;--! reference clock expect 250Mhz
    rst    : IN STD_LOGIC--! sync active high reset. sync -> refclk
  );
END ENTITY Core;
ARCHITECTURE rtl OF Core IS
BEGIN
END ARCHITECTURE rtl;