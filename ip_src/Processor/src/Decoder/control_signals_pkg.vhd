LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

PACKAGE control_signals_pkg IS
    TYPE control_signals_t IS RECORD
        alu_op     : alu_op_t;                     -- Операция для ALU
        reg_write  : STD_LOGIC;                    -- Разрешение записи в регистр
        mem_read   : STD_LOGIC;                    -- Чтение из памяти
        mem_write  : STD_LOGIC;                    -- Запись в память
        mem_to_reg : STD_LOGIC;                    -- Источник для записи в регистр (0: ALU, 1: память)
        branch     : STD_LOGIC;                    -- Условное ветвление
        jump       : STD_LOGIC;                    -- Безусловный прыжок (JAL, JALR)
        alu_src    : STD_LOGIC;                    -- Источник второго операнда ALU (0: регистр, 1: imm)
        imm_type   : STD_LOGIC_VECTOR(2 DOWNTO 0); -- Тип непосредственного значения
    END RECORD;

    -- Константы для типов imm
    CONSTANT IMM_I_TYPE : STD_LOGIC_VECTOR(2 DOWNTO 0) := "000";
    CONSTANT IMM_S_TYPE : STD_LOGIC_VECTOR(2 DOWNTO 0) := "001";
    CONSTANT IMM_B_TYPE : STD_LOGIC_VECTOR(2 DOWNTO 0) := "010";
    CONSTANT IMM_U_TYPE : STD_LOGIC_VECTOR(2 DOWNTO 0) := "011";
    CONSTANT IMM_J_TYPE : STD_LOGIC_VECTOR(2 DOWNTO 0) := "100";
END PACKAGE control_signals_pkg;