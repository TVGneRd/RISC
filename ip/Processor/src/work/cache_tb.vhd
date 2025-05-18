LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;

ENTITY cache_tb IS
    GENERIC (
        EDGE_CLK : TIME := 2 ns
    );
    PORT (
        clk            : IN STD_LOGIC;
        rst            : IN STD_LOGIC;
        test_completed : OUT STD_LOGIC
    );
END ENTITY cache_tb;

ARCHITECTURE behavior OF cache_tb IS
    -- Component declaration
    COMPONENT Cache
        GENERIC (
            cache_size : INTEGER := 64
        );
        PORT (
            refclk : IN STD_LOGIC;
            rst    : IN STD_LOGIC;

            r_address : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
            r_data    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            r_valid   : IN STD_LOGIC;
            r_ready   : OUT STD_LOGIC;

            -- (КАНАЛ ЗАПИСИ) Порты для взаимодействия с ядром процессором, через него возвращаются данные из кэша
            w_address : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
            w_data    : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
            w_valid   : IN STD_LOGIC;
            w_ready   : OUT STD_LOGIC;

            M_AXI_ARADDR  : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
            M_AXI_ARLEN   : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
            M_AXI_ARVALID : OUT STD_LOGIC;
            M_AXI_ARREADY : IN STD_LOGIC;
            M_AXI_RDATA   : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
            M_AXI_RRESP   : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
            M_AXI_RLAST   : IN STD_LOGIC;
            M_AXI_RVALID  : IN STD_LOGIC;
            M_AXI_RREADY  : OUT STD_LOGIC;

            M_AXI_AWADDR  : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
            M_AXI_AWLEN   : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
            M_AXI_AWVALID : OUT STD_LOGIC;
            M_AXI_AWREADY : IN STD_LOGIC;

            -- Read data channel signals
            M_AXI_WDATA  : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
            M_AXI_WLAST  : OUT STD_LOGIC; -- всегда 1
            M_AXI_WVALID : OUT STD_LOGIC;
            M_AXI_WREADY : IN STD_LOGIC;

            M_AXI_BRESP  : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
            M_AXI_BVALID : IN STD_LOGIC;
            M_AXI_BREADY : OUT STD_LOGIC
        );
    END COMPONENT;

    -- Testbench signals
    SIGNAL r_address : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
    SIGNAL r_data    : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL r_valid   : STD_LOGIC                     := '0';
    SIGNAL r_ready   : STD_LOGIC                     := '0';

    SIGNAL w_address : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
    SIGNAL w_data    : STD_LOGIC_VECTOR(7 DOWNTO 0)  := (OTHERS => '0');
    SIGNAL w_valid   : STD_LOGIC                     := '0';
    SIGNAL w_ready   : STD_LOGIC                     := '0';

    SIGNAL M_AXI_ARADDR  : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
    SIGNAL M_AXI_ARLEN   : STD_LOGIC_VECTOR(7 DOWNTO 0)  := (OTHERS => '0');
    SIGNAL M_AXI_ARVALID : STD_LOGIC                     := '0';
    SIGNAL M_AXI_ARREADY : STD_LOGIC                     := '0';
    SIGNAL M_AXI_RDATA   : STD_LOGIC_VECTOR(7 DOWNTO 0)  := (OTHERS => '0');
    SIGNAL M_AXI_RRESP   : STD_LOGIC_VECTOR(1 DOWNTO 0)  := "00";
    SIGNAL M_AXI_RLAST   : STD_LOGIC                     := '0';
    SIGNAL M_AXI_RVALID  : STD_LOGIC                     := '0';
    SIGNAL M_AXI_RREADY  : STD_LOGIC                     := '0';

    SIGNAL M_AXI_AWADDR  : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
    SIGNAL M_AXI_AWVALID : STD_LOGIC                     := '0';
    SIGNAL M_AXI_AWREADY : STD_LOGIC                     := '0';
    SIGNAL M_AXI_AWLEN   : STD_LOGIC_VECTOR(7 DOWNTO 0)  := (OTHERS => '0');

    SIGNAL M_AXI_WDATA  : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL M_AXI_WVALID : STD_LOGIC                    := '0';
    SIGNAL M_AXI_WREADY : STD_LOGIC                    := '0';
    SIGNAL M_AXI_WLAST  : STD_LOGIC                    := '0';

    SIGNAL M_AXI_BRESP  : STD_LOGIC_VECTOR(1 DOWNTO 0) := "00";
    SIGNAL M_AXI_BVALID : STD_LOGIC                    := '0';
    SIGNAL M_AXI_BREADY : STD_LOGIC                    := '0';
BEGIN
    -- Instantiate the Unit Under Test (UUT)
    uut : Cache
    GENERIC MAP(
        cache_size => 64
    )
    PORT MAP(
        refclk => clk,
        rst    => rst,

        r_address => r_address,
        r_data    => r_data,
        r_valid   => r_valid,
        r_ready   => r_ready,

        w_address => w_address,
        w_data    => w_data,
        w_valid   => w_valid,
        w_ready   => w_ready,

        M_AXI_ARADDR  => M_AXI_ARADDR,
        M_AXI_ARLEN   => M_AXI_ARLEN,
        M_AXI_ARVALID => M_AXI_ARVALID,
        M_AXI_ARREADY => M_AXI_ARREADY,
        M_AXI_RDATA   => M_AXI_RDATA,
        M_AXI_RRESP   => M_AXI_RRESP,
        M_AXI_RLAST   => M_AXI_RLAST,
        M_AXI_RVALID  => M_AXI_RVALID,
        M_AXI_RREADY  => M_AXI_RREADY,

        M_AXI_AWADDR  => M_AXI_AWADDR,
        M_AXI_AWLEN   => M_AXI_AWLEN,
        M_AXI_AWVALID => M_AXI_AWVALID,
        M_AXI_AWREADY => M_AXI_AWREADY,

        M_AXI_WDATA  => M_AXI_WDATA,
        M_AXI_WLAST  => M_AXI_WLAST,
        M_AXI_WVALID => M_AXI_WVALID,
        M_AXI_WREADY => M_AXI_WREADY,

        M_AXI_BRESP  => M_AXI_BRESP,
        M_AXI_BVALID => M_AXI_BVALID,
        M_AXI_BREADY => M_AXI_BREADY
    );

    -- Stimulus process
    stim_proc : PROCESS
    BEGIN
        test_completed <= '0';

        WAIT UNTIL rising_edge(clk) AND rst = '0';

        M_AXI_ARREADY <= '1';

        -- Test 1: Cache miss scenario
        REPORT "Test 1: Cache miss scenario";
        r_address <= X"100"; -- Address outside initial cache range
        r_valid   <= '1';
        WAIT UNTIL rising_edge(clk) AND r_ready = '0'; -- Wait for cache to process request
        r_valid <= '0';

        -- Simulate AXI memory response
        WAIT UNTIL rising_edge(clk) AND M_AXI_ARVALID = '1';
        M_AXI_ARREADY <= '0';
        WAIT UNTIL rising_edge(clk) AND M_AXI_ARVALID = '0';

        -- Simulate r_data return (64 bytes)
        FOR i IN 0 TO 63 LOOP
            WAIT UNTIL rising_edge(clk);
            M_AXI_RVALID <= '1';
            M_AXI_RDATA  <= STD_LOGIC_VECTOR(to_unsigned(i + 3, 8));
            IF i = 63 THEN
                M_AXI_RLAST <= '1';
            END IF;

            WAIT UNTIL rising_edge(clk) AND M_AXI_RREADY = '1';
            M_AXI_RVALID <= '0';
            WAIT FOR EDGE_CLK;
        END LOOP;

        WAIT FOR EDGE_CLK;

        M_AXI_RVALID  <= '0';
        M_AXI_RLAST   <= '0';
        M_AXI_ARREADY <= '1';

        WAIT UNTIL rising_edge(clk) AND r_ready = '1';
        ASSERT r_data = x"06050403" -- Should get bytes 0-3 from r_address 0x100
        REPORT "Test 1 failed: Incorrect r_data" SEVERITY ERROR;
        WAIT FOR EDGE_CLK * 2;

        -- Test 2: Cache hit scenario
        REPORT "Test 2: Cache hit scenario";
        r_address <= X"102"; -- Within cached range
        r_valid   <= '1';
        WAIT UNTIL r_ready = '1';
        ASSERT r_data = x"08070605" -- Should get bytes 2-5
        REPORT "Test 2 failed: Incorrect r_data" SEVERITY ERROR;
        r_valid <= '0';
        WAIT FOR EDGE_CLK * 2;

        -- Test 3: New r_address outside cache
        REPORT "Test 3: New r_address outside cache";
        r_address <= X"200";
        r_valid   <= '1';
        WAIT UNTIL rising_edge(clk) AND r_ready = '0';
        r_valid <= '0';

        -- Simulate AXI response
        WAIT UNTIL rising_edge(clk) AND M_AXI_ARVALID = '1';
        M_AXI_ARREADY <= '0';
        WAIT UNTIL rising_edge(clk) AND M_AXI_ARVALID = '0';

        FOR i IN 0 TO 63 LOOP
            WAIT UNTIL rising_edge(clk);
            M_AXI_RVALID <= '1';
            M_AXI_RDATA  <= STD_LOGIC_VECTOR(to_unsigned(i + 100, 8));
            IF i = 63 THEN
                M_AXI_RLAST <= '1';
            END IF;
            WAIT UNTIL rising_edge(clk) AND M_AXI_RREADY = '1';
            M_AXI_RVALID <= '0';
            WAIT FOR EDGE_CLK;
        END LOOP;

        WAIT FOR EDGE_CLK;

        M_AXI_RVALID  <= '0';
        M_AXI_RLAST   <= '0';
        M_AXI_ARREADY <= '1';

        WAIT UNTIL r_ready = '1';
        ASSERT r_data = X"67666564" -- Should get bytes 100-103
        REPORT "Test 3 failed: Incorrect r_data" SEVERITY ERROR;

        -- Test 4: Cache miss scenario
        WAIT UNTIL rising_edge(clk) AND r_ready = '1';
        REPORT "Test 4: Cache miss (lower bounds)";
        r_address <= X"000"; -- Address outside initial cache range
        r_valid   <= '1';
        WAIT UNTIL rising_edge(clk) AND r_ready = '0'; -- Wait for cache to process request
        r_valid <= '0';

        -- Simulate AXI memory response
        WAIT UNTIL rising_edge(clk) AND M_AXI_ARVALID = '1';
        M_AXI_ARREADY <= '0';
        WAIT UNTIL rising_edge(clk) AND M_AXI_ARVALID = '0';

        -- Simulate r_data return (64 bytes)
        FOR i IN 0 TO 63 LOOP
            WAIT UNTIL rising_edge(clk);
            M_AXI_RVALID <= '1';
            M_AXI_RDATA  <= STD_LOGIC_VECTOR(to_unsigned(i + 3, 8));
            IF i = 63 THEN
                M_AXI_RLAST <= '1';
            END IF;

            WAIT UNTIL rising_edge(clk) AND M_AXI_RREADY = '1';
            M_AXI_RVALID <= '0';
            WAIT FOR EDGE_CLK;
        END LOOP;

        M_AXI_RVALID  <= '0';
        M_AXI_RLAST   <= '0';
        M_AXI_ARREADY <= '1';

        test_completed <= '1';
        REPORT "Cache test completed";
        WAIT;
    END PROCESS;

END ARCHITECTURE behavior;