
LIBRARY IEEE;--! standard library IEEE (Institute of Electrical and Electronics Engineers)
USE IEEE.std_logic_1164.ALL;--! standard unresolved logic UX01ZWLH-
USE IEEE.numeric_std.ALL;--! for the signed, unsigned types and arithmetic ops
USE work.Decoder.control_signals_pkg.ALL;
USE work.Decoder.riscv_opcodes_pkg.ALL;

-- -- -- -- Задача блока: -- -- -- --
-- 1. Декодирование команды
------------------------------------

-- -- -- -- Распределение: -- -- -- --
-- Дима: 1
-------------------------------------
ENTITY Decoder IS
  PORT (
    refclk : IN STD_LOGIC;--! reference clock expect 250Mhz
    rst    : IN STD_LOGIC;--! sync active high reset. sync -> refclk

    instruction : IN STD_LOGIC_VECTOR(31 DOWNTO 0); -- Входная инструкция

    rs1_addr : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);  -- Адрес регистра rs1
    rs2_addr : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);  -- Адрес регистра rs2
    rd_addr  : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);  -- Адрес регистра rd
    imm      : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); -- Непосредственное значение

    control : OUT control_signals_t -- Управляющие сигналы
  );
END ENTITY Decoder;
ARCHITECTURE rtl OF Decoder IS
BEGIN
END ARCHITECTURE rtl;