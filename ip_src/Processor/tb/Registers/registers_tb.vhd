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
    SIGNAL reset : STD_LOGIC := '1';

    -- Pipeline 0 signals
    SIGNAL p0_addr_out_1 : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    SIGNAL p0_data_out_1 : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL p0_addr_out_2 : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    SIGNAL p0_data_out_2 : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL p0_addr_in    : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    SIGNAL p0_data_in    : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL p0_write_en   : STD_LOGIC := '0';

    -- Pipeline 1 signals
    SIGNAL p1_addr_out_1 : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    SIGNAL p1_data_out_1 : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL p1_addr_out_2 : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    SIGNAL p1_data_out_2 : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL p1_addr_in    : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    SIGNAL p1_data_in    : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL p1_write_en   : STD_LOGIC := '0';

    -- Pipeline 2 signals
    SIGNAL p2_addr_out_1 : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    SIGNAL p2_data_out_1 : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL p2_addr_out_2 : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    SIGNAL p2_data_out_2 : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL p2_addr_in    : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    SIGNAL p2_data_in    : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL p2_write_en   : STD_LOGIC := '0';

    -- Pipeline 3 signals
    SIGNAL p3_addr_out_1 : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    SIGNAL p3_data_out_1 : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL p3_addr_out_2 : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    SIGNAL p3_data_out_2 : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL p3_addr_in    : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    SIGNAL p3_data_in    : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL p3_write_en   : STD_LOGIC := '0';

BEGIN
    -- Инстанцирование тестируемого устройства
    uut : ENTITY work.Registers
        PORT MAP(
            refclk => clk,
            rst    => reset,
            -- Pipeline 0
            p0_addr_out_1 => p0_addr_out_1,
            p0_data_out_1 => p0_data_out_1,
            p0_addr_out_2 => p0_addr_out_2,
            p0_data_out_2 => p0_data_out_2,
            p0_addr_in    => p0_addr_in,
            p0_data_in    => p0_data_in,
            p0_write_en   => p0_write_en,
            -- Pipeline 1
            p1_addr_out_1 => p1_addr_out_1,
            p1_data_out_1 => p1_data_out_1,
            p1_addr_out_2 => p1_addr_out_2,
            p1_data_out_2 => p1_data_out_2,
            p1_addr_in    => p1_addr_in,
            p1_data_in    => p1_data_in,
            p1_write_en   => p1_write_en,
            -- Pipeline 2
            p2_addr_out_1 => p2_addr_out_1,
            p2_data_out_1 => p2_data_out_1,
            p2_addr_out_2 => p2_addr_out_2,
            p2_data_out_2 => p2_data_out_2,
            p2_addr_in    => p2_addr_in,
            p2_data_in    => p2_data_in,
            p2_write_en   => p2_write_en,
            -- Pipeline 3
            p3_addr_out_1 => p3_addr_out_1,
            p3_data_out_1 => p3_data_out_1,
            p3_addr_out_2 => p3_addr_out_2,
            p3_data_out_2 => p3_data_out_2,
            p3_addr_in    => p3_addr_in,
            p3_data_in    => p3_data_in,
            p3_write_en   => p3_write_en
        );

    -- Основной тестовый процесс
    stim_proc : PROCESS
    BEGIN
        test_completed <= '0';
        reset          <= rst;
        WAIT UNTIL rising_edge(clk) AND rst = '0';

        -- ===== Тест Pipeline 0 =====
        -- Попытка записи в x0 (addr_in = 0), не должна сохраняться
        p0_addr_in  <= "00000"; -- x0
        p0_data_in  <= x"DEADBEEF";
        p0_write_en <= '1';
        WAIT FOR EDGE_CLK * 2;

        -- Проверка, что x0 всё ещё 0
        p0_write_en   <= '0';
        p0_addr_out_1 <= "00000"; -- x0
        WAIT FOR EDGE_CLK * 2;
        ASSERT p0_data_out_1 = x"00000000"
        REPORT "Error: Register x0 cannot be not a 0!" SEVERITY ERROR;

        -- Запись в x5 через pipeline 0
        p0_addr_in  <= "00101"; -- x5
        p0_data_in  <= x"12345678";
        p0_write_en <= '1';
        WAIT FOR EDGE_CLK * 2;

        -- Чтение из x5 через pipeline 0
        p0_write_en   <= '0';
        p0_addr_out_1 <= "00101"; -- x5
        WAIT FOR EDGE_CLK * 2;
        ASSERT p0_data_out_1 = x"12345678"
        REPORT "Error: Invalid data in register x5" SEVERITY ERROR;

        -- ===== Тест параллельного чтения всеми конвейерами =====
        p0_addr_out_1 <= "00101"; -- x5
        p1_addr_out_1 <= "00101"; -- x5
        p2_addr_out_1 <= "00101"; -- x5
        p3_addr_out_1 <= "00101"; -- x5
        WAIT FOR EDGE_CLK * 2;
        ASSERT p0_data_out_1 = x"12345678" AND p1_data_out_1 = x"12345678" AND
               p2_data_out_1 = x"12345678" AND p3_data_out_1 = x"12345678"
        REPORT "Error: Parallel read from all pipelines failed" SEVERITY ERROR;

        -- ===== Тест записи из разных конвейеров в разные регистры =====
        p0_addr_in  <= "00001"; -- x1
        p0_data_in  <= x"11111111";
        p0_write_en <= '1';
        p1_addr_in  <= "00010"; -- x2
        p1_data_in  <= x"22222222";
        p1_write_en <= '1';
        p2_addr_in  <= "00011"; -- x3
        p2_data_in  <= x"33333333";
        p2_write_en <= '1';
        p3_addr_in  <= "00100"; -- x4
        p3_data_in  <= x"44444444";
        p3_write_en <= '1';
        WAIT FOR EDGE_CLK * 2;

        -- Отключение записи
        p0_write_en <= '0';
        p1_write_en <= '0';
        p2_write_en <= '0';
        p3_write_en <= '0';

        -- Проверка всех записей
        p0_addr_out_1 <= "00001"; -- x1
        p1_addr_out_1 <= "00010"; -- x2
        p2_addr_out_1 <= "00011"; -- x3
        p3_addr_out_1 <= "00100"; -- x4
        WAIT FOR EDGE_CLK * 2;
        ASSERT p0_data_out_1 = x"11111111"
        REPORT "Error: x1 has invalid value" SEVERITY ERROR;
        ASSERT p1_data_out_1 = x"22222222"
        REPORT "Error: x2 has invalid value" SEVERITY ERROR;
        ASSERT p2_data_out_1 = x"33333333"
        REPORT "Error: x3 has invalid value" SEVERITY ERROR;
        ASSERT p3_data_out_1 = x"44444444"
        REPORT "Error: x4 has invalid value" SEVERITY ERROR;

        -- ===== Тест приоритета записи (все пишут в один регистр) =====
        -- Pipeline 0 имеет высший приоритет
        p0_addr_in  <= "00110"; -- x6
        p0_data_in  <= x"AAAAAAAA";
        p0_write_en <= '1';
        p1_addr_in  <= "00110"; -- x6
        p1_data_in  <= x"BBBBBBBB";
        p1_write_en <= '1';
        p2_addr_in  <= "00110"; -- x6
        p2_data_in  <= x"CCCCCCCC";
        p2_write_en <= '1';
        p3_addr_in  <= "00110"; -- x6
        p3_data_in  <= x"DDDDDDDD";
        p3_write_en <= '1';
        WAIT FOR EDGE_CLK * 2;

        p0_write_en <= '0';
        p1_write_en <= '0';
        p2_write_en <= '0';
        p3_write_en <= '0';
        p0_addr_out_1 <= "00110"; -- x6
        WAIT FOR EDGE_CLK * 2;
        -- Pipeline 0 должен победить
        ASSERT p0_data_out_1 = x"AAAAAAAA"
        REPORT "Error: Priority write failed - expected Pipeline 0 value" SEVERITY ERROR;

        -- ===== Проверка сброса =====
        reset <= '1';
        WAIT FOR EDGE_CLK * 2;
        reset <= '0';
        p0_addr_out_1 <= "00101"; -- x5
        WAIT FOR EDGE_CLK * 2;
        ASSERT p0_data_out_1 = x"00000000"
        REPORT "Error: Register x5 has invalid zero value after reset" SEVERITY ERROR;

        -- Завершение
        test_completed <= '1';
        REPORT "Registers test completed";
        WAIT;
    END PROCESS;

END ARCHITECTURE behavior;