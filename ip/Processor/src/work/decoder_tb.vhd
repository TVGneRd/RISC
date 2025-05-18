LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.riscv_opcodes_pkg.ALL;
USE work.control_signals_pkg.ALL;

ENTITY tb_decoder IS
    GENERIC (
        EDGE_CLK : TIME := 2 ns
    );
    PORT (
        clk            : IN STD_LOGIC;
        rst            : IN STD_LOGIC;
        test_completed : OUT STD_LOGIC
    );
END ENTITY tb_decoder;

ARCHITECTURE behavior OF tb_decoder IS
    -- Компонент декодера
    COMPONENT Decoder
        PORT (
            clk              : IN STD_LOGIC;
            rst              : IN STD_LOGIC;
            instruction      : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            reg_addr_out_i_1 : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
            reg_data_out_i_1 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            reg_addr_out_i_2 : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
            reg_data_out_i_2 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            rd_addr          : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
            rs1              : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            rs2              : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            imm              : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            control          : OUT control_signals_t
        );
    END COMPONENT;

    -- Сигналы для теста
    SIGNAL instruction      : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL reg_addr_out_i_1 : STD_LOGIC_VECTOR(4 DOWNTO 0);
    SIGNAL reg_data_out_i_1 : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL reg_addr_out_i_2 : STD_LOGIC_VECTOR(4 DOWNTO 0);
    SIGNAL reg_data_out_i_2 : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL rd_addr          : STD_LOGIC_VECTOR(4 DOWNTO 0);
    SIGNAL rs1              : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL rs2              : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL imm              : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL control          : control_signals_t;

BEGIN
    -- Экземпляр декодера
    uut : Decoder
    PORT MAP(
        clk              => clk,
        rst              => rst,
        instruction      => instruction,
        reg_addr_out_i_1 => reg_addr_out_i_1,
        reg_data_out_i_1 => reg_data_out_i_1,
        reg_addr_out_i_2 => reg_addr_out_i_2,
        reg_data_out_i_2 => reg_data_out_i_2,
        rd_addr          => rd_addr,
        rs1              => rs1,
        rs2              => rs2,
        imm              => imm,
        control          => control
    );

    -- Тестовый процесс
    stim_proc : PROCESS
        PROCEDURE check_signals(
            expected_rs1        : STD_LOGIC_VECTOR(31 DOWNTO 0);
            expected_rs2        : STD_LOGIC_VECTOR(31 DOWNTO 0);
            expected_rd_addr    : STD_LOGIC_VECTOR(4 DOWNTO 0);
            expected_imm        : STD_LOGIC_VECTOR(31 DOWNTO 0);
            expected_opcode     : riscv_opcode_t;
            expected_alu_en     : STD_LOGIC;
            expected_reg_write  : STD_LOGIC;
            expected_mem_read   : STD_LOGIC;
            expected_mem_write  : STD_LOGIC;
            expected_mem_to_reg : STD_LOGIC;
            expected_branch     : STD_LOGIC;
            expected_jump       : STD_LOGIC;
            expected_imm_type   : riscv_imm_type_t;
            test_name           : STRING
        ) IS
        BEGIN
            test_completed <= '0';

            WAIT FOR EDGE_CLK; -- Ждём один такт для синхронизации
            ASSERT rs1 = expected_rs1
            REPORT test_name & ": rs1 mismatch, expected " &
                ", got "
                SEVERITY ERROR;
            ASSERT rs2 = expected_rs2
            REPORT test_name & ": rs2 mismatch, expected " &
                ", got "
                SEVERITY ERROR;
            ASSERT rd_addr = expected_rd_addr
            REPORT test_name & ": rd_addr mismatch, expected " &
                ", got "
                SEVERITY ERROR;
            ASSERT imm = expected_imm
            REPORT test_name & ": imm mismatch, expected " &
                ", got "
                SEVERITY ERROR;
            ASSERT control.opcode = expected_opcode
            REPORT test_name & ": opcode mismatch, expected " & riscv_opcode_t'image(expected_opcode) &
                ", got " & riscv_opcode_t'image(control.opcode)
                SEVERITY ERROR;
            ASSERT control.reg_write = expected_reg_write
            REPORT test_name & ": reg_write mismatch, expected " & STD_LOGIC'image(expected_reg_write) &
                ", got " & STD_LOGIC'image(control.reg_write)
                SEVERITY ERROR;
            ASSERT control.alu_en = expected_alu_en
            REPORT test_name & ": alu_en mismatch, expected " & STD_LOGIC'image(expected_alu_en) &
                ", got " & STD_LOGIC'image(control.alu_en)
                SEVERITY ERROR;
            ASSERT control.mem_read = expected_mem_read
            REPORT test_name & ": mem_read mismatch, expected " & STD_LOGIC'image(expected_mem_read) &
                ", got " & STD_LOGIC'image(control.mem_read)
                SEVERITY ERROR;
            ASSERT control.mem_write = expected_mem_write
            REPORT test_name & ": mem_write mismatch, expected " & STD_LOGIC'image(expected_mem_write) &
                ", got " & STD_LOGIC'image(control.mem_write)
                SEVERITY ERROR;
            ASSERT control.mem_to_reg = expected_mem_to_reg
            REPORT test_name & ": mem_to_reg mismatch, expected " & STD_LOGIC'image(expected_mem_to_reg) &
                ", got " & STD_LOGIC'image(control.mem_to_reg)
                SEVERITY ERROR;
            ASSERT control.branch = expected_branch
            REPORT test_name & ": branch mismatch, expected " & STD_LOGIC'image(expected_branch) &
                ", got " & STD_LOGIC'image(control.branch)
                SEVERITY ERROR;
            ASSERT control.jump = expected_jump
            REPORT test_name & ": jump mismatch, expected " & STD_LOGIC'image(expected_jump) &
                ", got " & STD_LOGIC'image(control.jump)
                SEVERITY ERROR;
            ASSERT control.imm_type = expected_imm_type
            REPORT test_name & ": imm_type mismatch, expected " & riscv_imm_type_t'image(expected_imm_type) &
                ", got " & riscv_imm_type_t'image(control.imm_type)
                SEVERITY ERROR;

            test_completed <= '1';
        END PROCEDURE;

        -- Процедура для установки значений регистров
        PROCEDURE set_register_values(
            rs1_val : STD_LOGIC_VECTOR(31 DOWNTO 0);
            rs2_val : STD_LOGIC_VECTOR(31 DOWNTO 0)
        ) IS
        BEGIN
            reg_data_out_i_1 <= rs1_val;
            reg_data_out_i_2 <= rs2_val;
            WAIT FOR 1 ns; -- Небольшая задержка для стабилизации
        END PROCEDURE;

    BEGIN
        -- Инициализация
        instruction <= (OTHERS => '0');

        -- Тест 1: ADD (R-тип)
        -- ADD x1, x2, x3 (funct7=0000000, funct3=000, opcode=0110011)
        set_register_values(x"00000002", x"00000003"); -- x2=2, x3=3
        instruction <= "00000000001100010000000010110011";
        check_signals(
        expected_rs1        => x"00000002", -- значение x2
        expected_rs2        => x"00000003", -- значение x3
        expected_rd_addr    => "00001",     -- x1
        expected_imm => (OTHERS => '0'),
        expected_opcode     => OP_ADD,
        expected_alu_en     => '1',
        expected_reg_write  => '1',
        expected_mem_read   => '0',
        expected_mem_write  => '0',
        expected_mem_to_reg => '0',
        expected_branch     => '0',
        expected_jump       => '0',
        expected_imm_type   => IMM_R_TYPE,
        test_name           => "ADD instruction"
        );

        -- Тест 2: ADDI (I-тип)
        -- ADDI x1, x2, 5 (imm=000000000101, funct3=000, opcode=0010011)
        set_register_values(x"0000000A", x"00000000"); -- x2=10, x3 не используется
        instruction <= "00000000010100010000000010010011";
        check_signals(
        expected_rs1        => x"0000000A", -- значение x2
        expected_rs2 => (OTHERS => '0'),
        expected_rd_addr    => "00001", -- x1
        expected_imm        => STD_LOGIC_VECTOR(to_signed(5, 32)),
        expected_opcode     => OP_ADDI,
        expected_alu_en     => '1',
        expected_reg_write  => '1',
        expected_mem_read   => '0',
        expected_mem_write  => '0',
        expected_mem_to_reg => '0',
        expected_branch     => '0',
        expected_jump       => '0',
        expected_imm_type   => IMM_I_TYPE,
        test_name           => "ADDI instruction"
        );

        -- Тест 3: LW (I-тип, загрузка)
        -- LW x1, 4(x2) (imm=000000000100, funct3=010, opcode=0000011)
        set_register_values(x"10001000", x"00000000"); -- x2=0x10001000
        instruction <= "00000000010000010010000010000011";
        check_signals(
        expected_rs1        => x"10001000", -- значение x2
        expected_rs2 => (OTHERS => '0'),
        expected_rd_addr    => "00001", -- x1
        expected_imm        => STD_LOGIC_VECTOR(to_signed(4, 32)),
        expected_opcode     => OP_LW,
        expected_alu_en     => '0',
        expected_reg_write  => '1',
        expected_mem_read   => '1',
        expected_mem_write  => '0',
        expected_mem_to_reg => '1',
        expected_branch     => '0',
        expected_jump       => '0',
        expected_imm_type   => IMM_I_TYPE,
        test_name           => "LW instruction"
        );

        -- Тест 4: SW (S-тип)
        -- SW x3, 8(x2) (imm=0000000_01000, funct3=010, opcode=0100011)
        set_register_values(x"20002000", x"DEADBEEF"); -- x2=0x20002000, x3=0xDEADBEEF
        instruction <= "00000000001100010010010000100011";
        check_signals(
        expected_rs1        => x"20002000", -- значение x2
        expected_rs2        => x"DEADBEEF", -- значение x3
        expected_rd_addr    => "00000",     -- не используется
        expected_imm        => STD_LOGIC_VECTOR(to_signed(8, 32)),
        expected_opcode     => OP_SW,
        expected_alu_en     => '0',
        expected_reg_write  => '0',
        expected_mem_read   => '0',
        expected_mem_write  => '1',
        expected_mem_to_reg => '0',
        expected_branch     => '0',
        expected_jump       => '0',
        expected_imm_type   => IMM_S_TYPE,
        test_name           => "SW instruction"
        );

        -- Тест 5: BEQ (B-тип)
        -- BEQ x2, x3, 16 (imm=000000010000, funct3=000, opcode=1100011)
        set_register_values(x"00000042", x"00000042"); -- x2=66, x3=66
        instruction <= "00000000001100010000100001100011";
        check_signals(
        expected_rs1        => x"00000042", -- значение x2
        expected_rs2        => x"00000042", -- значение x3
        expected_rd_addr    => "00000",     -- не используется
        expected_imm        => STD_LOGIC_VECTOR(to_signed(16, 32)),
        expected_opcode     => OP_BEQ,
        expected_alu_en     => '0',
        expected_reg_write  => '0',
        expected_mem_read   => '0',
        expected_mem_write  => '0',
        expected_mem_to_reg => '0',
        expected_branch     => '1',
        expected_jump       => '0',
        expected_imm_type   => IMM_B_TYPE,
        test_name           => "BEQ instruction"
        );

        -- Тест 6: LUI (U-тип)
        -- LUI x1, 0x12345 (imm=00010010001101000101, opcode=0110111)
        set_register_values((OTHERS => '0'), (OTHERS => '0')); -- регистры не используются
        instruction <= "00010010001101000101000010110111";
        check_signals(
        expected_rs1 => (OTHERS => '0'),
        expected_rs2 => (OTHERS => '0'),
        expected_rd_addr    => "00001", -- x1
        expected_imm => "00010010001101000101" & (11 DOWNTO 0 => '0'),
        expected_opcode     => OP_LUI,
        expected_alu_en     => '0',
        expected_reg_write  => '1',
        expected_mem_read   => '0',
        expected_mem_write  => '0',
        expected_mem_to_reg => '0',
        expected_branch     => '0',
        expected_jump       => '0',
        expected_imm_type   => IMM_U_TYPE,
        test_name           => "LUI instruction"
        );

        -- Тест 7: JAL (J-тип)
        -- JAL x1, 32 (imm=00000000000000000000000000100000, opcode=1101111)
        set_register_values((OTHERS => '0'), (OTHERS => '0')); -- регистры не используются
        instruction <= "00000010000000000000000011101111";
        check_signals(
        expected_rs1 => (OTHERS => '0'),
        expected_rs2 => (OTHERS => '0'),
        expected_rd_addr    => "00001", -- x1
        expected_imm        => STD_LOGIC_VECTOR(to_signed(32, 32)),
        expected_opcode     => OP_JAL,
        expected_alu_en     => '0',
        expected_reg_write  => '1',
        expected_mem_read   => '0',
        expected_mem_write  => '0',
        expected_mem_to_reg => '0',
        expected_branch     => '0',
        expected_jump       => '1',
        expected_imm_type   => IMM_J_TYPE,
        test_name           => "JAL instruction"
        );

        -- Тест 8: ECALL (системная инструкция)
        -- ECALL (imm=000000000000, funct3=000, opcode=1110011)
        set_register_values((OTHERS => '0'), (OTHERS => '0')); -- регистры не используются
        instruction <= "00000000000000000000000001110011";
        check_signals(
        expected_rs1 => (OTHERS => '0'),
        expected_rs2 => (OTHERS => '0'),
        expected_rd_addr    => "00000", -- не используется
        expected_imm => (OTHERS => '0'),
        expected_opcode     => OP_ECALL,
        expected_alu_en     => '0',
        expected_reg_write  => '0',
        expected_mem_read   => '0',
        expected_mem_write  => '0',
        expected_mem_to_reg => '0',
        expected_branch     => '0',
        expected_jump       => '0',
        expected_imm_type   => IMM_I_TYPE,
        test_name           => "ECALL instruction"
        );

        -- Тест 9: Некорректная инструкция
        -- OPCODE = 1111111 (не существует)
        set_register_values((OTHERS => '0'), (OTHERS => '0'));
        instruction <= "00000000000000000000000001111111";
        check_signals(
        expected_rs1 => (OTHERS => '0'),
        expected_rs2 => (OTHERS => '0'),
        expected_rd_addr    => "00000",
        expected_imm => (OTHERS => '0'),
        expected_opcode     => OP_INVALID,
        expected_alu_en     => '0',
        expected_reg_write  => '0',
        expected_mem_read   => '0',
        expected_mem_write  => '0',
        expected_mem_to_reg => '0',
        expected_branch     => '0',
        expected_jump       => '0',
        expected_imm_type   => IMM_I_TYPE,
        test_name           => "Invalid instruction"
        );

        -- Завершение теста
        REPORT "Decoder test completed";
        test_completed <= '1';
        WAIT;
    END PROCESS;

END ARCHITECTURE behavior;