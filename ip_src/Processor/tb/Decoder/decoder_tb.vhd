LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.riscv_opcodes_pkg.ALL;
USE work.control_signals_pkg.ALL;

ENTITY tb_decoder IS
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
            clk         : IN STD_LOGIC;
            rst         : IN STD_LOGIC;
            instruction : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            rs1_addr    : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
            rs2_addr    : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
            rd_addr     : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
            imm         : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            control     : OUT control_signals_t
        );
    END COMPONENT;

    -- Сигналы для теста
    SIGNAL instruction : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL rs1_addr    : STD_LOGIC_VECTOR(4 DOWNTO 0);
    SIGNAL rs2_addr    : STD_LOGIC_VECTOR(4 DOWNTO 0);
    SIGNAL rd_addr     : STD_LOGIC_VECTOR(4 DOWNTO 0);
    SIGNAL imm         : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL control     : control_signals_t;

    -- Период тактового сигнала (250 МГц -> 4 нс)
    CONSTANT CLK_PERIOD : TIME := 4 ns;

BEGIN
    -- Экземпляр декодера
    uut : Decoder
    PORT MAP(
        clk         => clk,
        rst         => rst,
        instruction => instruction,
        rs1_addr    => rs1_addr,
        rs2_addr    => rs2_addr,
        rd_addr     => rd_addr,
        imm         => imm,
        control     => control
    );

    -- Тестовый процесс
    stim_proc : PROCESS
        PROCEDURE check_signals(
            expected_rs1_addr   : STD_LOGIC_VECTOR(4 DOWNTO 0);
            expected_rs2_addr   : STD_LOGIC_VECTOR(4 DOWNTO 0);
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
            WAIT FOR CLK_PERIOD; -- Ждём один такт для синхронизации
            ASSERT rs1_addr = expected_rs1_addr
            REPORT test_name & ": rs1_addr mismatch, expected "
                SEVERITY ERROR;
            ASSERT rs2_addr = expected_rs2_addr
            REPORT test_name & ": rs2_addr mismatch, expected "
                SEVERITY ERROR;
            ASSERT rd_addr = expected_rd_addr
            REPORT test_name & ": rd_addr mismatch, expected "
                SEVERITY ERROR;
            ASSERT imm = expected_imm
            REPORT test_name & ": imm mismatch, expected "
                SEVERITY ERROR;
            ASSERT control.opcode = expected_opcode
            REPORT test_name & ": opcode mismatch, expected " & riscv_opcode_t'image(expected_opcode) & ", got " & riscv_opcode_t'image(control.opcode)
                SEVERITY ERROR;
            ASSERT control.reg_write = expected_reg_write
            REPORT test_name & ": reg_write mismatch, expected " & STD_LOGIC'image(expected_reg_write) & ", got " & STD_LOGIC'image(control.reg_write)
                SEVERITY ERROR;
            ASSERT control.alu_en = expected_alu_en
            REPORT test_name & ": alu_en mismatch, expected " & STD_LOGIC'image(expected_alu_en) & ", got " & STD_LOGIC'image(control.alu_en)
                SEVERITY ERROR;
            ASSERT control.mem_read = expected_mem_read
            REPORT test_name & ": mem_read mismatch, expected " & STD_LOGIC'image(expected_mem_read) & ", got " & STD_LOGIC'image(control.mem_read)
                SEVERITY ERROR;
            ASSERT control.mem_write = expected_mem_write
            REPORT test_name & ": mem_write mismatch, expected " & STD_LOGIC'image(expected_mem_write) & ", got " & STD_LOGIC'image(control.mem_write)
                SEVERITY ERROR;
            ASSERT control.mem_to_reg = expected_mem_to_reg
            REPORT test_name & ": mem_to_reg mismatch, expected " & STD_LOGIC'image(expected_mem_to_reg) & ", got " & STD_LOGIC'image(control.mem_to_reg)
                SEVERITY ERROR;
            ASSERT control.branch = expected_branch
            REPORT test_name & ": branch mismatch, expected " & STD_LOGIC'image(expected_branch) & ", got " & STD_LOGIC'image(control.branch)
                SEVERITY ERROR;
            ASSERT control.jump = expected_jump
            REPORT test_name & ": jump mismatch, expected " & STD_LOGIC'image(expected_jump) & ", got " & STD_LOGIC'image(control.jump)
                SEVERITY ERROR;
            ASSERT control.imm_type = expected_imm_type
            REPORT test_name & ": imm_type mismatch"
                SEVERITY ERROR;
        END PROCEDURE;

    BEGIN
        -- Инициализация
        instruction <= (OTHERS => '0');
        -- Тест 1: ADD (R-тип)
        -- ADD x1, x2, x3 (funct7=0000000, funct3=000, opcode=0110011)
        instruction <= "00000000001100010000000010110011";
        check_signals(
        expected_rs1_addr   => "00010",  -- x2
        expected_rs2_addr   => "00011",  -- x3
        expected_rd_addr    => "00001",  -- x1
        expected_imm => (OTHERS => '0'), -- imm не используется
        expected_opcode     => OP_ADD,
        expected_alu_en     => '1',
        expected_reg_write  => '1',
        expected_mem_read   => '0',
        expected_mem_write  => '0',
        expected_mem_to_reg => '0',
        expected_branch     => '0',
        expected_jump       => '0',
        expected_imm_type   => IMM_R_TYPE, -- не используется, но по умолчанию
        test_name           => "ADD instruction"
        );

        -- Тест 2: ADDI (I-тип)
        -- ADDI x1, x2, 5 (imm=000000000101, funct3=000, opcode=0010011)
        instruction <= "00000000010100010000000010010011";
        check_signals(
        expected_rs1_addr   => "00010",                            -- x2
        expected_rs2_addr   => "00000",                            -- не используется
        expected_rd_addr    => "00001",                            -- x1
        expected_imm        => STD_LOGIC_VECTOR(to_signed(5, 32)), -- imm = 5
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
        instruction <= "00000000010000010010000010000011";
        check_signals(
        expected_rs1_addr   => "00010",                            -- x2
        expected_rs2_addr   => "00000",                            -- не используется
        expected_rd_addr    => "00001",                            -- x1
        expected_imm        => STD_LOGIC_VECTOR(to_signed(4, 32)), -- imm = 4
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
        instruction <= "00000000001100010010010000100011";
        check_signals(
        expected_rs1_addr   => "00010",                            -- x2
        expected_rs2_addr   => "00011",                            -- x3
        expected_rd_addr    => "00000",                            -- не используется
        expected_imm        => STD_LOGIC_VECTOR(to_signed(8, 32)), -- imm = 8
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
        instruction <= "00000000001100010000100001100011"; -- "0_000000_00011_00010_000_1000_0_1100011"

        check_signals(
        expected_rs1_addr   => "00010",                             -- x2
        expected_rs2_addr   => "00011",                             -- x3
        expected_rd_addr    => "00000",                             -- не используется
        expected_imm        => STD_LOGIC_VECTOR(to_signed(16, 32)), -- imm = 16
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
        instruction <= "00010010001101000101000010110111";
        check_signals(
        expected_rs1_addr   => "00000",                                -- не используется
        expected_rs2_addr   => "00000",                                -- не используется
        expected_rd_addr    => "00001",                                -- x1
        expected_imm => "00010010001101000101" & (11 DOWNTO 0 => '0'), -- imm = 0x12345000
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
        instruction <= "00000010000000000000000011101111"; -- "0_0000010000_0_00000000_00001_1101111"
        check_signals(
        expected_rs1_addr   => "00000",                             -- не используется
        expected_rs2_addr   => "00000",                             -- не используется
        expected_rd_addr    => "00001",                             -- x1
        expected_imm        => STD_LOGIC_VECTOR(to_signed(32, 32)), -- imm = 32
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
        instruction <= "00000000000000000000000001110011";
        check_signals(
        expected_rs1_addr   => "00000",  -- не используется
        expected_rs2_addr   => "00000",  -- не используется
        expected_rd_addr    => "00000",  -- не используется
        expected_imm => (OTHERS => '0'), -- imm не используется
        expected_opcode     => OP_ECALL,
        expected_alu_en     => '0',
        expected_reg_write  => '0',
        expected_mem_read   => '0',
        expected_mem_write  => '0',
        expected_mem_to_reg => '0',
        expected_branch     => '0',
        expected_jump       => '0',
        expected_imm_type   => IMM_I_TYPE, -- не используется
        test_name           => "ECALL instruction"
        );

        -- Тест 9: Некорректная инструкция
        -- OPCODE = 1111111 (не существует)
        instruction <= "00000000000000000000000001111111";
        check_signals(
        expected_rs1_addr   => "00000",
        expected_rs2_addr   => "00000",
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
        REPORT "Test completed";
        test_completed <= '1';
        WAIT;
    END PROCESS;

END ARCHITECTURE behavior;