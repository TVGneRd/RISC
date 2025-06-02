LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

USE work.riscv_opcodes_pkg.ALL;

ENTITY alu_tb IS
    GENERIC (
        EDGE_CLK : TIME := 2 ns
    );
    PORT (
        clk            : IN STD_LOGIC;
        rst            : IN STD_LOGIC;
        test_completed : OUT STD_LOGIC
    );
END alu_tb;

ARCHITECTURE behavior OF alu_tb IS
    -- Компонент ALU
    COMPONENT alu
        PORT (
            refclk    : IN STD_LOGIC;
            rst       : IN STD_LOGIC;
            enable    : IN STD_LOGIC;
            operand_1 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            operand_2 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            opcode    : IN riscv_opcode_t;
            --ready     : OUT STD_LOGIC;
            result : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            zero   : OUT STD_LOGIC;
            sign   : OUT STD_LOGIC
        );
    END COMPONENT;

    -- Сигналы
    --SIGNAL refclk    : STD_LOGIC                     := '0';
    --SIGNAL rst       : STD_LOGIC                     := '1';
    SIGNAL enable    : STD_LOGIC                     := '0';
    SIGNAL operand_1 : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL operand_2 : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL opcode    : riscv_opcode_t                := OP_INVALID;
    --SIGNAL ready     : STD_LOGIC;
    SIGNAL result : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL zero   : STD_LOGIC;
    SIGNAL sign   : STD_LOGIC;

    -- Частота clock
    CONSTANT clk_period : TIME := 10 ns;

BEGIN
    -- Подключаем ALU
    uut : alu PORT MAP(
        refclk => clk, rst => rst,
        enable => enable,
        operand_1 => operand_1, operand_2 => operand_2, opcode => opcode,
        result => result, zero => zero, sign => sign
    );

    -- Генерация clock
    -- clk_process : PROCESS
    -- BEGIN
    --     refclk <= '0';
    --     WAIT FOR EDGE_CLK/2;
    --     refclk <= '1';
    --     WAIT FOR EDGE_CLK/2;
    -- END PROCESS;

    -- [Предыдущая часть кода до stim_proc остается без изменений]

    stim_proc : PROCESS
    BEGIN
        test_completed <= '0';

        -- Сброс
        -- WAIT FOR 20 ns;
        -- rst <= '0';
        -- WAIT FOR 20 ns;
        WAIT UNTIL rst = '0';
        --WAIT FOR EDGE_CLK * 1;
        -- Тест 1: OR (ИЛИ)
        operand_1 <= X"80000000"; -- -2^31
        operand_2 <= X"00000002"; -- сдвиг на 2
        opcode    <= OP_OR;       -- OP_SRA
        --WAIT FOR EDGE_CLK;
        enable <= '1';
        WAIT FOR EDGE_CLK * 2;
        --WAIT UNTIL ready = '0' FOR EDGE_CLK * 9;
        --WAIT UNTIL ready = '1' FOR EDGE_CLK * 9;
        --WAIT FOR EDGE_CLK * 8;
        --WAIT FOR EDGE_CLK * 3;
        ASSERT result = X"80000002" -- Ожидаем -2^31 >> 2
        REPORT "OR failed!" SEVERITY ERROR;
        --WAIT FOR EDGE_CLK;
        enable <= '0';
        WAIT FOR EDGE_CLK * 2;

        -- Тест 2: SLT (сравнение со знаком)
        enable    <= '1';
        operand_1 <= X"FFFFFFFE"; -- -2
        operand_2 <= X"00000001"; -- 1
        opcode    <= OP_SLT;      -- OP_SLT
        WAIT FOR EDGE_CLK * 2;
        ASSERT result = X"00000001" -- Ожидаем 1 (true, -2 < 1)
        REPORT "SLT failed!" SEVERITY ERROR;
        enable <= '0';
        WAIT FOR EDGE_CLK * 2;

        -- Тест 3: SLTU (сравнение без знака)
        enable    <= '1';
        operand_1 <= X"FFFFFFFE"; -- большое положительное
        operand_2 <= X"00000001"; -- 1
        opcode    <= OP_SLTU;     -- OP_SLTU
        WAIT FOR EDGE_CLK * 2;
        ASSERT result = X"00000000" -- Ожидаем 0 (false, 2^32-2 > 1)
        REPORT "SLTU failed!" SEVERITY ERROR;
        enable <= '0';
        WAIT FOR EDGE_CLK * 2;

        -- Тест 4: LUI
        enable    <= '1';
        operand_1 <= X"12345000"; -- Загружаем 0x12345 << 12
        opcode    <= OP_LUI;      -- OP_LUI
        WAIT FOR EDGE_CLK * 2;
        ASSERT result = X"12345000" -- Ожидаем тот же верхний бит
        REPORT "LUI failed!" SEVERITY ERROR;
        enable <= '0';
        WAIT FOR EDGE_CLK * 2;

        --Тест 5 ADD (Сложение)
        enable    <= '1';
        operand_1 <= X"00001000"; -- большое положительное
        operand_2 <= X"00001010"; -- 1
        opcode    <= OP_ADD;      -- OP_SLTU
        WAIT FOR EDGE_CLK * 2;
        ASSERT result = X"00002010" -- Ожидаем 0 (false, 2^32-2 > 1)
        REPORT "ADD failed!" SEVERITY ERROR;
        enable <= '0';
        WAIT FOR EDGE_CLK * 2;

        --Тест 6 SUB (Сложение)
        enable    <= '1';
        operand_1 <= X"00031500"; -- большое положительное
        operand_2 <= X"00016300"; -- 1
        opcode    <= OP_SUB;      -- OP_SLTU
        WAIT FOR EDGE_CLK * 2;
        ASSERT result = X"0001B200" -- Ожидаем 0 (false, 2^32-2 > 1)
        REPORT "SUB failed!" SEVERITY ERROR;
        enable <= '0';
        WAIT FOR EDGE_CLK * 2;

        -- Тест 7: MUL (умножение)
        enable    <= '1';
        operand_1 <= X"00000005"; -- 5
        operand_2 <= X"00000004"; -- 4
        opcode    <= OP_MUL;      -- OP_MUL
        WAIT FOR EDGE_CLK * 2;
        ASSERT result = X"00000014" -- Ожидаем 20 (5 * 4)
        REPORT "MUL failed!" SEVERITY ERROR;
        enable <= '0';
        WAIT FOR EDGE_CLK * 2;

        -- Тест 8: MULH (умножение со знаком, старшие биты)
        enable    <= '1';
        operand_1 <= X"80000000"; -- -2^31
        operand_2 <= X"80000000"; -- -2^31
        opcode    <= OP_MULH;     -- OP_MULH
        WAIT FOR EDGE_CLK * 2;
        ASSERT result = X"40000000" -- Ожидаем 2^30 (результат -2^31 * -2^31 = 2^62, старшие 32 бита)
        REPORT "MULH failed!" SEVERITY ERROR;
        enable <= '0';
        WAIT FOR EDGE_CLK * 2;

        -- Тест 9: DIV (деление со знаком)
        enable    <= '1';
        operand_1 <= X"FFFFFFF6"; -- -10
        operand_2 <= X"00000005"; -- 5
        opcode    <= OP_DIV;      -- OP_DIV
        WAIT FOR EDGE_CLK * 2;
        ASSERT result = X"FFFFFFFE" -- Ожидаем -2 (-10 / 5)
        REPORT "DIV failed!" SEVERITY ERROR;
        enable <= '0';
        WAIT FOR EDGE_CLK * 2;

        -- Тест 10: DIVU (деление без знака)
        enable    <= '1';
        --operand_1 <= X"FFFFFFF6"; -- 4294967286
        --operand_2 <= X"00000005"; -- 5
        operand_1 <= X"00000009"; -- 9
        operand_2 <= X"00000002"; -- 3
        opcode    <= OP_DIVU;     -- OP_DIVU
        WAIT FOR EDGE_CLK * 2;
        --ASSERT result = X"33333332" -- Ожидаем 858993458 (4294967286 / 5)
        ASSERT result = X"00000004" -- Ожидаем 4(,5) (9 / 2)
        REPORT "DIVU failed!" SEVERITY ERROR;
        enable <= '0';
        WAIT FOR EDGE_CLK * 2;

        -- Тест 11: REM (остаток от деления со знаком)
        enable    <= '1';
        operand_1 <= X"FFFFFFF6"; -- -10
        operand_2 <= X"00000005"; -- 5
        opcode    <= OP_REM;      -- OP_REM
        WAIT FOR EDGE_CLK * 2;
        ASSERT result = X"00000000" -- Ожидаем 0 (-10 % 5)
        REPORT "REM failed!" SEVERITY ERROR;
        enable <= '0';
        WAIT FOR EDGE_CLK * 2;

        -- Тест 12: REMU (остаток от деления без знака)
        enable    <= '1';
        operand_1 <= X"FFFFFFF6"; -- 4294967286
        operand_2 <= X"00000005"; -- 5
        opcode    <= OP_REMU;     -- OP_REMU
        WAIT FOR EDGE_CLK * 2;
        ASSERT result = X"00000001" -- Ожидаем 1 (4294967286 % 5)
        REPORT "REMU failed!" SEVERITY ERROR;
        enable <= '0';
        WAIT FOR EDGE_CLK * 2;

        -- Завершение
        test_completed <= '1';
        REPORT "ALU test completed!" SEVERITY NOTE;
        WAIT;
    END PROCESS;

END behavior;