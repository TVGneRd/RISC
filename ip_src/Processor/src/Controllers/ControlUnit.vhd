
LIBRARY IEEE;--! standard library IEEE (Institute of Electrical and Electronics Engineers)
USE IEEE.std_logic_1164.ALL;--! standard unresolved logic UX01ZWLH-
USE IEEE.numeric_std.ALL;--! for the signed, unsigned types and arithmetic ops
USE work.riscv_opcodes_pkg.ALL;

-- -- -- -- Задача блока: -- -- -- --
-- 1. Выполнять переходы и системные функции
------------------------------------

-- -- -- -- Распределение: -- -- -- --
-- Коля: 1
-------------------------------------

ENTITY ControlUnit IS
  PORT (
    refclk : IN STD_LOGIC;--! reference clock expect 250Mhz
    rst    : IN STD_LOGIC;--! sync active high reset. sync -> refclk

    opcode : IN riscv_opcode_t;

    rs1_addr : IN STD_LOGIC_VECTOR(4 DOWNTO 0); -- Адрес регистра rs1
    rs2_addr : IN STD_LOGIC_VECTOR(4 DOWNTO 0); -- Адрес регистра rs2

    imm : IN STD_LOGIC_VECTOR(31 DOWNTO 0); -- Непосредственное значение

    enable : IN STD_LOGIC;

    pc_in  : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    pc_out : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END ENTITY ControlUnit;
ARCHITECTURE rtl OF ControlUnit IS

BEGIN

END ARCHITECTURE rtl;