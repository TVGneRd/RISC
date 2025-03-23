
LIBRARY IEEE;--! standard library IEEE (Institute of Electrical and Electronics Engineers)
USE IEEE.std_logic_1164.ALL;--! standard unresolved logic UX01ZWLH-
USE IEEE.numeric_std.ALL;--! for the signed, unsigned types and arithmetic ops

USE work.Decoder.riscv_opcodes_pkg.ALL;
-- -- -- -- Задача блока: -- -- -- --
-- 1. Выполнение арифметических операций R-тип и I-тип
------------------------------------

-- -- -- -- Распределение: -- -- -- --
-- Андрей: 1
-------------------------------------

ENTITY ALU IS
  PORT (
    refclk : IN STD_LOGIC;--! reference clock expect 250Mhz
    rst    : IN STD_LOGIC;--! sync active high reset. sync -> refclk

    opcode    : IN riscv_opcode_t;
    operand_1 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    operand_2 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);

    result : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); -- Результат
    zero   : OUT STD_LOGIC;                     -- Флаг нуля (для ветвлений)
    sign   : OUT STD_LOGIC;                     -- Флаг знака (для сравнений)

    valid : IN STD_LOGIC;
    ready : IN STD_LOGIC
  );
END ENTITY ALU;
ARCHITECTURE rtl OF ALU IS
BEGIN
END ARCHITECTURE rtl;