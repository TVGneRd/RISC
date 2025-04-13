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
            valid     : IN STD_LOGIC;
            operand_1 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            operand_2 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            opcode    : IN riscv_opcode_t;
            ready     : OUT STD_LOGIC;
            result    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            zero      : OUT STD_LOGIC;
            sign      : OUT STD_LOGIC
        );
    END COMPONENT;

    -- Сигналы
    --SIGNAL refclk    : STD_LOGIC                     := '0';
    --SIGNAL rst       : STD_LOGIC                     := '1';
    SIGNAL valid     : STD_LOGIC                     := '0';
    SIGNAL operand_1 : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL operand_2 : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL opcode    : riscv_opcode_t                := OP_INVALID;
    SIGNAL ready     : STD_LOGIC;
    SIGNAL result    : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL zero      : STD_LOGIC;
    SIGNAL sign      : STD_LOGIC;

    -- Частота clock
    CONSTANT clk_period : TIME := 10 ns;

BEGIN
    -- Подключаем ALU
    uut : alu PORT MAP(
        refclk => clk, rst => rst,
        valid => valid,
        operand_1 => operand_1, operand_2 => operand_2, opcode => opcode,
        ready => ready, result => result, zero => zero, sign => sign
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
        valid     <= '1';
        WAIT FOR EDGE_CLK * 2;
        --WAIT UNTIL ready = '0' FOR EDGE_CLK * 9;
        --WAIT UNTIL ready = '1' FOR EDGE_CLK * 9;
        --WAIT FOR EDGE_CLK * 8;
        --WAIT FOR EDGE_CLK * 3;
        ASSERT result = X"80000002" -- Ожидаем -2^31 >> 2
        REPORT "OR failed!" SEVERITY ERROR;
        --WAIT FOR EDGE_CLK;
        valid <= '0';
        WAIT FOR EDGE_CLK * 2;

        -- Тест 2: SLT (сравнение со знаком)
        valid     <= '1';
        operand_1 <= X"FFFFFFFE"; -- -2
        operand_2 <= X"00000001"; -- 1
        opcode    <= OP_SLT;      -- OP_SLT
        WAIT FOR EDGE_CLK * 1;
        ASSERT result = X"00000001" -- Ожидаем 1 (true, -2 < 1)
        REPORT "SLT failed!" SEVERITY ERROR;
        valid <= '0';
        WAIT FOR EDGE_CLK * 2;

        -- Тест 3: SLTU (сравнение без знака)
        valid     <= '1';
        operand_1 <= X"FFFFFFFE"; -- большое положительное
        operand_2 <= X"00000001"; -- 1
        opcode    <= OP_SLTU;     -- OP_SLTU
        WAIT FOR EDGE_CLK * 1;
        ASSERT result = X"00000000" -- Ожидаем 0 (false, 2^32-2 > 1)
        REPORT "SLTU failed!" SEVERITY ERROR;
        valid <= '0';
        WAIT FOR EDGE_CLK * 2;

        -- Тест 4: LUI
        valid     <= '1';
        operand_1 <= X"12345000"; -- Загружаем 0x12345 << 12
        opcode    <= OP_LUI;      -- OP_LUI
        WAIT FOR EDGE_CLK * 2;
        ASSERT result = X"12345000" -- Ожидаем тот же верхний бит
        REPORT "LUI failed!" SEVERITY ERROR;
        valid <= '0';
        WAIT FOR EDGE_CLK * 2;

        --Тест 5 ADD (Сложение)
        valid     <= '1';
        operand_1 <= X"00001000"; -- большое положительное
        operand_2 <= X"00001010"; -- 1
        opcode    <= OP_ADD;      -- OP_SLTU
        WAIT FOR EDGE_CLK * 2;
        ASSERT result = X"00002010" -- Ожидаем 0 (false, 2^32-2 > 1)
        REPORT "ADD failed!" SEVERITY ERROR;
        valid <= '0';
        WAIT FOR EDGE_CLK * 2;
        -- Завершение
        test_completed <= '1';
        REPORT "ALU test completed!" SEVERITY NOTE;
        WAIT;
    END PROCESS;

END behavior;