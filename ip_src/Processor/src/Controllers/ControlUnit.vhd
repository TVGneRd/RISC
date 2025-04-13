
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

    rs1 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); -- регистра rs1
    rs2 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); -- регистра rs2

    imm : IN STD_LOGIC_VECTOR(31 DOWNTO 0); -- Непосредственное значение

    enable : IN STD_LOGIC;

    pc_in  : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    pc_out : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);

    jump : OUT STD_LOGIC -- Индикатор перехода 
  );
END ENTITY ControlUnit;
ARCHITECTURE rtl OF ControlUnit IS

BEGIN
  IF enable = 1 THEN
    CASE opcode IS
        -- R-тип
      WHEN OP_BEQ =>
        IF rs1 == rs2 THEN
          pc_out <= imm * 4;
          jump   <= '1';
        ELSE
          pc_out <= pc_in;
        END IF;
      WHEN OP_BNE =>
        IF rs1 ! = rs2 THEN
          pc_out <= imm * 4;
          jump   <= '1';
        ELSE
          pc_out <= pc_in;
        END IF;

      WHEN OP_BLT =>
        IF signed(rs1) < signed(rs2) THEN
          pc_out <= imm * 4;
          jump   <= '1';
        ELSE
          pc_out <= pc_in;
        END IF;

      WHEN OP_BGE =>
        IF signed(rs1) >= signed(rs2) THEN
          pc_out <= imm * 4;
          jump   <= '1';
        ELSE
          pc_out <= pc_in;
        END IF;

      WHEN OP_BLTU =>
        IF unsigned(rs1) < unsigned(rs2) THEN
          pc_out <= imm * 4;
          jump   <= '1';
        ELSE
          pc_out <= pc_in;
        END IF;
      WHEN OP_BGEU =>
        IF unsigned(rs1) >= unsigned(rs2) THEN
          pc_out <= imm * 4;
          jump   <= '1';
        ELSE
          pc_out <= pc_in;
        END IF;

      WHEN OP_JAL =>
        pc_out <= imm;
        jump   <= '1';
      WHEN OTHERS       =>
        pc_out <= (OTHERS => '0');
    END CASE;
  END IF;
END PROCESS;

END ARCHITECTURE rtl;