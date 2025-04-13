LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;

ENTITY result_controller_tb IS
    GENERIC (
        EDGE_CLK : TIME := 2 ns
    );
    PORT (
        clk            : IN STD_LOGIC;
        rst            : IN STD_LOGIC;
        test_completed : OUT STD_LOGIC
    );
END result_controller_tb;

ARCHITECTURE behavior OF result_controller_tb IS
    -- Константы
    CONSTANT CLOCK_PERIOD : TIME := 4 ns; -- 250 МГц -> период 4 нс

    -- Сигналы для подключения к ResultController
    SIGNAL enable           : STD_LOGIC                     := '0';
    SIGNAL result           : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL rd_addr          : STD_LOGIC_VECTOR(4 DOWNTO 0)  := (OTHERS => '0');
    SIGNAL reg_addr_in      : STD_LOGIC_VECTOR(4 DOWNTO 0);
    SIGNAL reg_data_in      : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL reg_write_enable : STD_LOGIC;

    -- Флаг для остановки симуляции
    SIGNAL sim_done : BOOLEAN := FALSE;

    COMPONENT ResultController
        PORT (
            refclk : IN STD_LOGIC;--! reference clock expect 250Mhz
            rst    : IN STD_LOGIC;--! sync active high reset. sync -> refclk

            enable  : IN STD_LOGIC;
            result  : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            rd_addr : IN STD_LOGIC_VECTOR(4 DOWNTO 0); -- Адрес регистра rd

            reg_addr_in      : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);  -- адрес регистра (0-31)
            reg_data_in      : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); -- данные которые хотим записать в регистр 
            reg_write_enable : OUT STD_LOGIC
        );
    END COMPONENT;
BEGIN
    -- Инстанцирование тестируемого модуля (Unit Under Test)
    uut : ResultController
    PORT MAP(
        refclk           => clk,
        rst              => rst,
        enable           => enable,
        result           => result,
        rd_addr          => rd_addr,
        reg_addr_in      => reg_addr_in,
        reg_data_in      => reg_data_in,
        reg_write_enable => reg_write_enable
    );

    -- Процесс стимуляции
    stim_proc : PROCESS
    BEGIN
        test_completed <= '0';

        WAIT UNTIL rising_edge(clk) AND rst = '0';

        -- Инициализация
        --rst     <= '1';
        enable  <= '0';
        result  <= (OTHERS => '0');
        rd_addr <= (OTHERS => '0');
        WAIT FOR 4 * EDGE_CLK;

        -- Сброс
        -- REPORT "Test 1: Reset";
        -- rst <= '1';
        -- WAIT FOR 2 * EDGE_CLK;
        -- ASSERT reg_write_enable = '0'
        -- REPORT "Test 1 failed: reg_write_enable not '0' during reset" SEVERITY ERROR;
        -- ASSERT reg_addr_in = "000000"
        -- REPORT "Test 1 failed: reg_addr_in not '000000' during reset" SEVERITY ERROR;
        -- ASSERT reg_data_in = X"00000000"
        -- REPORT "Test 1 failed: reg_data_in not '00000000' during reset" SEVERITY ERROR;
        -- rst <= '0';
        -- WAIT FOR 2 * EDGE_CLK;

        -- Тест 2: Запись в регистр x1 (rd_addr = "00001")
        REPORT "Test 2: Write to register x1";
        enable  <= '1';
        rd_addr <= "00001";
        result  <= X"DEADBEEF";
        WAIT FOR EDGE_CLK;
        ASSERT reg_write_enable = '1'
        REPORT "Test 2 failed: reg_write_enable not '1'" SEVERITY ERROR;
        ASSERT reg_addr_in = "00001"
        REPORT "Test 2 failed: reg_addr_in not '00001'" SEVERITY ERROR;
        ASSERT reg_data_in = X"DEADBEEF"
        REPORT "Test 2 failed: reg_data_in not 'DEADBEEF'" SEVERITY ERROR;
        enable <= '0';
        WAIT FOR EDGE_CLK;

        -- Тест 3: Нет записи при enable = '0'
        REPORT "Test 3: No write when enable = '0'";
        enable  <= '0';
        rd_addr <= "00010";
        result  <= X"12345678";
        WAIT FOR EDGE_CLK;
        ASSERT reg_write_enable = '0'
        REPORT "Test 3 failed: reg_write_enable not '0'" SEVERITY ERROR;
        ASSERT reg_addr_in = "00000"
        REPORT "Test 3 failed: reg_addr_in not '00000'" SEVERITY ERROR;
        ASSERT reg_data_in = X"00000000"
        REPORT "Test 3 failed: reg_data_in not '00000000'" SEVERITY ERROR;
        WAIT FOR EDGE_CLK;

        -- Тест 4: Запись в регистр x31 (rd_addr = "11111")
        REPORT "Test 4: Write to register x31";
        enable  <= '1';
        rd_addr <= "11111";
        result  <= X"AAAAAAAA";
        WAIT FOR EDGE_CLK;
        ASSERT reg_write_enable = '1'
        REPORT "Test 4 failed: reg_write_enable not '1'" SEVERITY ERROR;
        ASSERT reg_addr_in = "11111"
        REPORT "Test 4 failed: reg_addr_in not '11111'" SEVERITY ERROR;
        ASSERT reg_data_in = X"AAAAAAAA"
        REPORT "Test 4 failed: reg_data_in not 'AAAAAAAA'" SEVERITY ERROR;
        enable <= '0';
        WAIT FOR EDGE_CLK;

        -- Тест 5: Попытка записи в x0 (rd_addr = "00000")
        REPORT "Test 5: Attempt to write to register x0";
        enable  <= '1';
        rd_addr <= "00000";
        result  <= X"FFFFFFFF";
        WAIT FOR EDGE_CLK;
        ASSERT reg_write_enable = '1'
        REPORT "Test 5 failed: reg_write_enable not '1'" SEVERITY ERROR;
        ASSERT reg_addr_in = "00000"
        REPORT "Test 5 failed: reg_addr_in not '00000'" SEVERITY ERROR;
        ASSERT reg_data_in = X"FFFFFFFF"
        REPORT "Test 5 failed: reg_data_in not 'FFFFFFFF'" SEVERITY ERROR;
        enable <= '0';
        WAIT FOR EDGE_CLK;

        -- Завершение симуляции
        test_completed <= '1';
        REPORT "ResultController test completed!" SEVERITY NOTE;
        sim_done <= TRUE;
        WAIT;
    END PROCESS;

END ARCHITECTURE behavior;