LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY tb_alu IS
END tb_alu;

ARCHITECTURE behavior OF tb_alu IS
    -- Компонент ALU
    COMPONENT alu
        PORT (
            clk       : IN STD_LOGIC;
            rst       : IN STD_LOGIC;
            valid     : IN STD_LOGIC;
            operand_1 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            operand_2 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            operation : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
            ready     : OUT STD_LOGIC;
            result    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            zero      : OUT STD_LOGIC;
            sign      : OUT STD_LOGIC
        );
    END COMPONENT;

    -- Сигналы
    SIGNAL clk       : STD_LOGIC                     := '0';
    SIGNAL rst       : STD_LOGIC                     := '1';
    SIGNAL valid     : STD_LOGIC                     := '0';
    SIGNAL operand_1 : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL operand_2 : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL operation : STD_LOGIC_VECTOR(4 DOWNTO 0)  := (OTHERS => '0');
    SIGNAL ready     : STD_LOGIC;
    SIGNAL result    : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL zero      : STD_LOGIC;
    SIGNAL sign      : STD_LOGIC;

    -- Частота clock
    CONSTANT clk_period : TIME := 10 ns;

BEGIN
    -- Подключаем ALU
    uut : alu PORT MAP(
        clk => clk, rst => rst, valid => valid,
        operand_1 => operand_1, operand_2 => operand_2, operation => operation,
        ready => ready, result => result, zero => zero, sign => sign
    );

    -- Генерация clock
    clk_process : PROCESS
    BEGIN
        clk <= '0';
        WAIT FOR clk_period/2;
        clk <= '1';
        WAIT FOR clk_period/2;
    END PROCESS;

    -- [Предыдущая часть кода до stim_proc остается без изменений]

    stim_proc : PROCESS
    BEGIN
        -- Сброс
        WAIT FOR 20 ns;
        rst <= '0';
        WAIT FOR 20 ns;

        -- Тест 1: SRA (сдвиг вправо арифметический)
        valid     <= '1';
        operand_1 <= X"80000000"; -- -2^31
        operand_2 <= X"00000002"; -- сдвиг на 2
        operation <= "00101";     -- OP_SRA
        WAIT FOR clk_period * 5;
        ASSERT result = X"E0000000" -- Ожидаем -2^31 >> 2
        REPORT "SRA failed!" SEVERITY ERROR;
        valid <= '0';
        WAIT FOR clk_period * 5;

        -- Тест 2: SLT (сравнение со знаком)
        valid     <= '1';
        operand_1 <= X"FFFFFFFE"; -- -2
        operand_2 <= X"00000001"; -- 1
        operation <= "00010";     -- OP_SLT
        WAIT FOR clk_period * 5;
        ASSERT result = X"00000001" -- Ожидаем 1 (true, -2 < 1)
        REPORT "SLT failed!" SEVERITY ERROR;
        valid <= '0';
        WAIT FOR clk_period * 5;

        -- Тест 3: SLTU (сравнение без знака)
        valid     <= '1';
        operand_1 <= X"FFFFFFFE"; -- большое положительное
        operand_2 <= X"00000001"; -- 1
        operation <= "00011";     -- OP_SLTU
        WAIT FOR clk_period * 5;
        ASSERT result = X"00000000" -- Ожидаем 0 (false, 2^32-2 > 1)
        REPORT "SLTU failed!" SEVERITY ERROR;
        valid <= '0';
        WAIT FOR clk_period * 5;

        -- Тест 4: LUI
        valid     <= '1';
        operand_1 <= X"12345000"; -- Загружаем 0x12345 << 12
        operation <= "00111";     -- OP_LUI
        WAIT FOR clk_period * 5;
        ASSERT result = X"12345000" -- Ожидаем тот же верхний бит
        REPORT "LUI failed!" SEVERITY ERROR;
        valid <= '0';
        WAIT FOR clk_period * 5;

        -- Завершение
        REPORT "Simulation completed!" SEVERITY NOTE;
        WAIT;
    END PROCESS;

END behavior;