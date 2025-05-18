LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE work.riscv_opcodes_pkg.ALL;

PACKAGE control_signals_pkg IS
    TYPE control_signals_t IS RECORD
        opcode     : riscv_opcode_t;   -- Операция для ALU
        alu_en     : STD_LOGIC;        -- Операция для ALU
        reg_write  : STD_LOGIC;        -- Разрешение записи в регистр
        mem_read   : STD_LOGIC;        -- Чтение из памяти
        mem_write  : STD_LOGIC;        -- Запись в память
        mem_to_reg : STD_LOGIC;        -- Источник для записи в регистр (0: ALU, 1: память)
        branch     : STD_LOGIC;        -- Условное ветвление
        jump       : STD_LOGIC;        -- Безусловный прыжок (JAL, JALR)
        imm_type   : riscv_imm_type_t; -- Тип непосредственного значения
    END RECORD;
END PACKAGE control_signals_pkg;