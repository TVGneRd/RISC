LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- Пакет для определения OPCODE RISC-V RV32I
PACKAGE riscv_opcodes_pkg IS
    -- Перечисляемый тип для OPCODE RV32I
    TYPE riscv_opcode_t IS (
        -- R-тип (OPCODE = 0110011)
        OP_ADD,  -- ADD (funct3 = 000, funct7 = 0000000)
        OP_SUB,  -- SUB (funct3 = 000, funct7 = 0100000)
        OP_SLL,  -- SLL (funct3 = 001, funct7 = 0000000)
        OP_SLT,  -- SLT (funct3 = 010, funct7 = 0000000)
        OP_SLTU, -- SLTU (funct3 = 011, funct7 = 0000000)
        OP_XOR,  -- XOR (funct3 = 100, funct7 = 0000000)
        OP_SRL,  -- SRL (funct3 = 101, funct7 = 0000000)
        OP_SRA,  -- SRA (funct3 = 101, funct7 = 0100000)
        OP_OR,   -- OR (funct3 = 110, funct7 = 0000000)
        OP_AND,  -- AND (funct3 = 111, funct7 = 0000000)

        -- Расширение M (умножение и деление)
        OP_MUL,    -- MUL (funct3 = 000, funct7 = 0000001)
        OP_MULH,   -- MULH (funct3 = 001, funct7 = 0000001)
        OP_MULHSU, -- MULHSU (funct3 = 010, funct7 = 0000001)
        OP_MULHU,  -- MULHU (funct3 = 011, funct7 = 0000001)
        OP_DIV,    -- DIV (funct3 = 100, funct7 = 0000001)
        OP_DIVU,   -- DIVU (funct3 = 101, funct7 = 0000001)
        OP_REM,    -- REM (funct3 = 110, funct7 = 0000001)
        OP_REMU,   -- REMU (funct3 = 111, funct7 = 0000001)

        -- I-тип (OPCODE = 0010011 для арифметики, 0000011 для загрузки, 1100111 для JALR)
        OP_ADDI,  -- ADDI (funct3 = 000, OPCODE = 0010011)
        OP_SLTI,  -- SLTI (funct3 = 010, OPCODE = 0010011)
        OP_SLTIU, -- SLTIU (funct3 = 011, OPCODE = 0010011)
        OP_XORI,  -- XORI (funct3 = 100, OPCODE = 0010011)
        OP_ORI,   -- ORI (funct3 = 110, OPCODE = 0010011)
        OP_ANDI,  -- ANDI (funct3 = 111, OPCODE = 0010011)
        OP_SLLI,  -- SLLI (funct3 = 001, funct7 = 0000000, OPCODE = 0010011)
        OP_SRLI,  -- SRLI (funct3 = 101, funct7 = 0000000, OPCODE = 0010011)
        OP_SRAI,  -- SRAI (funct3 = 101, funct7 = 0100000, OPCODE = 0010011)

        OP_LB,  -- LB (funct3 = 000, OPCODE = 0000011)
        OP_LH,  -- LH (funct3 = 001, OPCODE = 0000011)
        OP_LW,  -- LW (funct3 = 010, OPCODE = 0000011)
        OP_LBU, -- LBU (funct3 = 100, OPCODE = 0000011)
        OP_LHU, -- LHU (funct3 = 101, OPCODE = 0000011)

        OP_JALR, -- JALR (funct3 = 000, OPCODE = 1100111)

        -- S-тип (OPCODE = 0100011)
        OP_SB, -- SB (funct3 = 000)
        OP_SH, -- SH (funct3 = 001)
        OP_SW, -- SW (funct3 = 010)

        -- B-тип (OPCODE = 1100011)
        OP_BEQ,  -- BEQ (funct3 = 000)
        OP_BNE,  -- BNE (funct3 = 001)
        OP_BLT,  -- BLT (funct3 = 100)
        OP_BGE,  -- BGE (funct3 = 101)
        OP_BLTU, -- BLTU (funct3 = 110)
        OP_BGEU, -- BGEU (funct3 = 111)

        -- U-тип (OPCODE = 0110111 для LUI, 0010111 для AUIPC)
        OP_LUI,   -- LUI
        OP_AUIPC, -- AUIPC

        -- J-тип (OPCODE = 1101111)
        OP_JAL, -- JAL

        -- Системные инструкции (OPCODE = 1110011)
        OP_ECALL,  -- ECALL (funct3 = 000, imm = 000000000000)
        OP_EBREAK, -- EBREAK (funct3 = 000, imm = 000000000001)

        -- Для некорректных или неподдерживаемых инструкций
        OP_INVALID
    );

    TYPE riscv_imm_type_t IS (
        IMM_R_TYPE,
        IMM_I_TYPE,
        IMM_S_TYPE,
        IMM_B_TYPE,
        IMM_U_TYPE,
        IMM_J_TYPE
    );

    -- Функция для декодирования OPCODE из инструкции
    FUNCTION decode_opcode(instruction : STD_LOGIC_VECTOR(31 DOWNTO 0)) RETURN riscv_opcode_t;
END PACKAGE riscv_opcodes_pkg;

-- Тело пакета
PACKAGE BODY riscv_opcodes_pkg IS
    FUNCTION decode_opcode(instruction : STD_LOGIC_VECTOR(31 DOWNTO 0)) RETURN riscv_opcode_t IS
        VARIABLE opcode                    : STD_LOGIC_VECTOR(6 DOWNTO 0)  := instruction(6 DOWNTO 0);
        VARIABLE funct3                    : STD_LOGIC_VECTOR(2 DOWNTO 0)  := instruction(14 DOWNTO 12);
        VARIABLE funct7                    : STD_LOGIC_VECTOR(6 DOWNTO 0)  := instruction(31 DOWNTO 25);
        VARIABLE imm12                     : STD_LOGIC_VECTOR(11 DOWNTO 0) := instruction(31 DOWNTO 20);
    BEGIN
        CASE opcode IS
                -- R-тип и M-тип (OPCODE = 0110011) 
            WHEN "0110011" =>
                CASE funct3 IS
                    WHEN "000" =>
                        IF funct7 = "0000000" THEN
                            RETURN OP_ADD;
                        END IF;
                        IF funct7 = "0100000" THEN
                            RETURN OP_SUB;
                        END IF;
                    WHEN "001" =>
                        IF funct7 = "0000000" THEN
                            RETURN OP_SLL;
                        END IF;
                    WHEN "010" =>
                        IF funct7 = "0000000" THEN
                            RETURN OP_SLT;
                        END IF;
                    WHEN "011" =>
                        IF funct7 = "0000000" THEN
                            RETURN OP_SLTU;
                        END IF;
                    WHEN "100" =>
                        IF funct7 = "0000000" THEN
                            RETURN OP_XOR;
                        END IF;
                    WHEN "101" =>
                        IF funct7 = "0000000" THEN
                            RETURN OP_SRL;
                        END IF;
                        IF funct7 = "0100000" THEN
                            RETURN OP_SRA;
                        END IF;
                    WHEN "110" =>
                        IF funct7 = "0000000" THEN
                            RETURN OP_OR;
                        END IF;
                    WHEN "111" =>
                        IF funct7 = "0000000" THEN
                            RETURN OP_AND;
                        END IF;
                    WHEN OTHERS => RETURN OP_INVALID;
                END CASE;

                -- проверяем расширение M (funct7 = 0000001)
                IF funct7 = "0000001" THEN
                    CASE funct3 IS
                        WHEN "000"  => RETURN OP_MUL;
                        WHEN "001"  => RETURN OP_MULH;
                        WHEN "010"  => RETURN OP_MULHSU;
                        WHEN "011"  => RETURN OP_MULHU;
                        WHEN "100"  => RETURN OP_DIV;
                        WHEN "101"  => RETURN OP_DIVU;
                        WHEN "110"  => RETURN OP_REM;
                        WHEN "111"  => RETURN OP_REMU;
                        WHEN OTHERS => RETURN OP_INVALID;
                    END CASE;
                END IF;

                -- I-тип (арифметика, OPCODE = 0010011)
            WHEN "0010011" =>
                CASE funct3 IS
                    WHEN "000" => RETURN OP_ADDI;
                    WHEN "010" => RETURN OP_SLTI;
                    WHEN "011" => RETURN OP_SLTIU;
                    WHEN "100" => RETURN OP_XORI;
                    WHEN "110" => RETURN OP_ORI;
                    WHEN "111" => RETURN OP_ANDI;
                    WHEN "001" =>
                        IF funct7 = "0000000" THEN
                            RETURN OP_SLLI;
                        END IF;
                    WHEN "101" =>
                        IF funct7 = "0000000" THEN
                            RETURN OP_SRLI;
                        END IF;
                        IF funct7 = "0100000" THEN
                            RETURN OP_SRAI;
                        END IF;
                    WHEN OTHERS => RETURN OP_INVALID;
                END CASE;

                -- I-тип (загрузка, OPCODE = 0000011)
            WHEN "0000011" =>
                CASE funct3 IS
                    WHEN "000"  => RETURN OP_LB;
                    WHEN "001"  => RETURN OP_LH;
                    WHEN "010"  => RETURN OP_LW;
                    WHEN "100"  => RETURN OP_LBU;
                    WHEN "101"  => RETURN OP_LHU;
                    WHEN OTHERS => RETURN OP_INVALID;
                END CASE;

                -- I-тип (JALR, OPCODE = 1100111)
            WHEN "1100111" =>
                IF funct3 = "000" THEN
                    RETURN OP_JALR;
                END IF;

                -- S-тип (OPCODE = 0100011)
            WHEN "0100011" =>
                CASE funct3 IS
                    WHEN "000"  => RETURN OP_SB;
                    WHEN "001"  => RETURN OP_SH;
                    WHEN "010"  => RETURN OP_SW;
                    WHEN OTHERS => RETURN OP_INVALID;
                END CASE;

                -- B-тип (OPCODE = 1100011)
            WHEN "1100011" =>
                CASE funct3 IS
                    WHEN "000"  => RETURN OP_BEQ;
                    WHEN "001"  => RETURN OP_BNE;
                    WHEN "100"  => RETURN OP_BLT;
                    WHEN "101"  => RETURN OP_BGE;
                    WHEN "110"  => RETURN OP_BLTU;
                    WHEN "111"  => RETURN OP_BGEU;
                    WHEN OTHERS => RETURN OP_INVALID;
                END CASE;

                -- U-тип
            WHEN "0110111" => RETURN OP_LUI;   -- LUI
            WHEN "0010111" => RETURN OP_AUIPC; -- AUIPC

                -- J-тип (OPCODE = 1101111)
            WHEN "1101111" => RETURN OP_JAL;

                -- Системные инструкции (OPCODE = 1110011)
            WHEN "1110011" =>
                IF funct3 = "000" THEN
                    IF imm12 = "000000000000" THEN
                        RETURN OP_ECALL;
                    END IF;
                    IF imm12 = "000000000001" THEN
                        RETURN OP_EBREAK;
                    END IF;
                END IF;
                -- Некорректный OPCODE
            WHEN OTHERS => RETURN OP_INVALID;
        END CASE;

        RETURN OP_INVALID; -- По умолчанию
    END FUNCTION;
END PACKAGE BODY riscv_opcodes_pkg;