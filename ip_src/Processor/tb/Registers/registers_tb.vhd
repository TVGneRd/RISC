LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.riscv_opcodes_pkg.ALL;
USE work.control_signals_pkg.ALL;

ENTITY registers_tb IS
    GENERIC (
        EDGE_CLK : TIME := 2 ns
    );
    PORT (
        clk            : IN STD_LOGIC;
        rst            : IN STD_LOGIC;
        test_completed : OUT STD_LOGIC
    );
END ENTITY registers_tb;

ARCHITECTURE behavior OF registers_tb IS
    SIGNAL reset        : STD_LOGIC                     := '0';
    SIGNAL addr_i       : STD_LOGIC_VECTOR(4 DOWNTO 0)  := (OTHERS => '0');
    SIGNAL data_in      : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL data_out_i   : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL write_enable : STD_LOGIC := '0';

BEGIN
    -- Инстанцирование тестируемого устройства
    uut : ENTITY work.Registers
        PORT MAP(
            refclk       => clk,
            rst          => reset,
            addr_i       => addr_i,
            data_in      => data_in,
            data_out_i   => data_out_i,
            write_enable => write_enable
        );

    -- Основной тестовый процесс
    stim_proc : PROCESS
    BEGIN
        test_completed <= '0';
        reset          <= rst;
        WAIT UNTIL rising_edge(clk) AND reset = '0';

        -- Попытка записи в x0 (addr_i = 0), не должна сохраняться
        addr_i       <= "00000"; -- x0
        data_in      <= x"DEADBEEF";
        write_enable <= '1';
        WAIT FOR EDGE_CLK;

        -- Проверка, что x0 всё ещё 0
        write_enable <= '0';
        WAIT FOR EDGE_CLK;
        ASSERT data_out_i = x"00000000"
        REPORT "Error: Register x0 cannot be not a 0!" SEVERITY ERROR;

        -- Запись в x5
        addr_i       <= "00101"; -- x5
        data_in      <= x"12345678";
        write_enable <= '1';
        WAIT FOR EDGE_CLK;

        -- Чтение из x5
        write_enable <= '0';
        WAIT FOR EDGE_CLK;
        ASSERT data_out_i = x"12345678"
        REPORT "Error: Invalid data in register x5" SEVERITY ERROR;

        -- Повторная запись в x5
        data_in      <= x"AABBCCDD";
        write_enable <= '1';
        WAIT FOR EDGE_CLK;

        -- Проверка обновления x5
        write_enable <= '0';
        WAIT FOR EDGE_CLK;
        ASSERT data_out_i = x"AABBCCDD"
        REPORT "Error: Register x5 has invalid value" SEVERITY ERROR;

        -- Проверка сброса
        reset <= '1';
        WAIT FOR EDGE_CLK;
        reset  <= '0';
        addr_i <= "00101"; -- x5
        WAIT FOR EDGE_CLK;
        ASSERT data_out_i = x"00000000"
        REPORT "Error: Register x5 has invalid zero value" SEVERITY ERROR;

        -- Завершение
        test_completed <= '1';
        REPORT "Registers test completed";
        WAIT;
    END PROCESS;

END ARCHITECTURE behavior;