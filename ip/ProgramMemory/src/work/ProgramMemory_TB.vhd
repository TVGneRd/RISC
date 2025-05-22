LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;

ENTITY ProgramMemory_TOP_tb IS
END ENTITY ProgramMemory_TOP_tb;

ARCHITECTURE behavior OF ProgramMemory_TOP_tb IS
  -- Component Declaration for the Unit Under Test (UUT)
  COMPONENT ProgramMemory_TOP
    PORT (
      refclk        : IN STD_LOGIC;
      rst           : IN STD_LOGIC;
      S_AXI_ARADDR  : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
      S_AXI_ARLEN   : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
      S_AXI_ARVALID : IN STD_LOGIC;
      S_AXI_ARREADY : OUT STD_LOGIC;
      S_AXI_RDATA   : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      S_AXI_RRESP   : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      S_AXI_RLAST   : OUT STD_LOGIC;
      S_AXI_RVALID  : OUT STD_LOGIC;
      S_AXI_RREADY  : IN STD_LOGIC;
      -- Write channel
      S_AXI_AWADDR  : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
      S_AXI_AWLEN   : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
      S_AXI_AWVALID : IN STD_LOGIC;
      S_AXI_AWREADY : OUT STD_LOGIC;

      -- data channel signals
      S_AXI_WDATA  : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
      S_AXI_WLAST  : IN STD_LOGIC;
      S_AXI_WVALID : IN STD_LOGIC;
      S_AXI_WREADY : OUT STD_LOGIC;

      --New data from Dima
      S_AXI_BRESP  : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      S_AXI_BVALID : OUT STD_LOGIC;
      S_AXI_BREADY : IN STD_LOGIC
    );
  END COMPONENT;

  -- Inputs
  SIGNAL refclk        : STD_LOGIC                     := '0';
  SIGNAL rst           : STD_LOGIC                     := '1';
  SIGNAL S_AXI_ARADDR  : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
  SIGNAL S_AXI_ARLEN   : STD_LOGIC_VECTOR(7 DOWNTO 0)  := (OTHERS => '0');
  SIGNAL S_AXI_ARVALID : STD_LOGIC                     := '0';
  SIGNAL S_AXI_RREADY  : STD_LOGIC                     := '0';

  -- Outputs
  SIGNAL S_AXI_ARREADY : STD_LOGIC;
  SIGNAL S_AXI_RDATA   : STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL S_AXI_RRESP   : STD_LOGIC_VECTOR(1 DOWNTO 0);
  SIGNAL S_AXI_RLAST   : STD_LOGIC;
  SIGNAL S_AXI_RVALID  : STD_LOGIC;

  SIGNAL S_AXI_BRESP  : STD_LOGIC_VECTOR(1 DOWNTO 0) := "00";
  SIGNAL S_AXI_BVALID : STD_LOGIC                    := '0';
  SIGNAL S_AXI_BREADY : STD_LOGIC                    := '0';

  SIGNAL S_AXI_AWADDR  : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
  SIGNAL S_AXI_AWVALID : STD_LOGIC                     := '0';
  SIGNAL S_AXI_AWREADY : STD_LOGIC                     := '0';
  SIGNAL S_AXI_AWLEN   : STD_LOGIC_VECTOR(7 DOWNTO 0)  := (OTHERS => '0');

  SIGNAL S_AXI_WDATA  : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
  SIGNAL S_AXI_WVALID : STD_LOGIC                    := '0';
  SIGNAL S_AXI_WREADY : STD_LOGIC                    := '0';
  SIGNAL S_AXI_WLAST  : STD_LOGIC                    := '0';

  -- Clock period definitions
  CONSTANT refclk_period : TIME := 4 ns; -- 250 MHz

BEGIN
  -- Instantiate the Unit Under Test (UUT)
  uut : ProgramMemory_TOP PORT MAP(
    refclk        => refclk,
    rst           => rst,
    S_AXI_ARADDR  => S_AXI_ARADDR,
    S_AXI_ARLEN   => S_AXI_ARLEN,
    S_AXI_ARVALID => S_AXI_ARVALID,
    S_AXI_ARREADY => S_AXI_ARREADY,
    S_AXI_RDATA   => S_AXI_RDATA,
    S_AXI_RRESP   => S_AXI_RRESP,
    S_AXI_RLAST   => S_AXI_RLAST,
    S_AXI_RVALID  => S_AXI_RVALID,
    S_AXI_RREADY  => S_AXI_RREADY,
    S_AXI_BRESP   => S_AXI_BRESP,
    S_AXI_BVALID  => S_AXI_BVALID,
    S_AXI_BREADY  => S_AXI_BREADY,
    S_AXI_AWADDR  => S_AXI_AWADDR,
    S_AXI_AWLEN   => S_AXI_AWLEN,
    S_AXI_AWVALID => S_AXI_AWVALID,
    S_AXI_AWREADY => S_AXI_AWREADY,

    S_AXI_WDATA  => S_AXI_WDATA,
    S_AXI_WLAST  => S_AXI_WLAST,
    S_AXI_WVALID => S_AXI_WVALID,
    S_AXI_WREADY => S_AXI_WREADY

  );

  -- Clock process definitions
  refclk_process : PROCESS
  BEGIN
    refclk <= '0';
    WAIT FOR refclk_period/2;
    refclk <= '1';
    WAIT FOR refclk_period/2;
  END PROCESS;

  -- Stimulus process
  stim_proc : PROCESS
  BEGIN
    -- Hold reset state for a few cycles
    rst <= '1';
    WAIT FOR refclk_period * 5;
    rst <= '0';
    WAIT FOR refclk_period;

    -- Test case 1: Single byte read
    REPORT "Test case 1: Single byte read";
    S_AXI_ARADDR  <= X"010"; -- Address 0x10
    S_AXI_ARLEN   <= X"01";  -- Length 1 (ARLEN is number of transfers minus 1)
    S_AXI_ARVALID <= '1';
    WAIT UNTIL rising_edge(refclk) AND S_AXI_ARREADY = '1';
    WAIT FOR refclk_period;
    S_AXI_ARVALID <= '0';

    -- Wait for data to be valid
    WAIT UNTIL S_AXI_RVALID = '1';
    S_AXI_RREADY <= '1';
    WAIT FOR refclk_period;
    ASSERT S_AXI_RLAST = '1' REPORT "RLAST should be high for single transfer" SEVERITY ERROR;
    S_AXI_RREADY <= '0';
    WAIT FOR refclk_period * 2;

    -- Test case 2: Burst read of 4 bytes
    REPORT "Test case 2: Burst read of 4 bytes";
    S_AXI_ARADDR  <= X"020"; -- Address 0x20
    S_AXI_ARLEN   <= X"04";  -- Length 4
    S_AXI_ARVALID <= '1';
    WAIT UNTIL rising_edge(refclk) AND S_AXI_ARREADY = '1';
    WAIT FOR refclk_period;
    S_AXI_ARVALID <= '0';

    -- Read all 4 bytes
    FOR i IN 0 TO 3 LOOP
      WAIT UNTIL rising_edge(refclk) AND S_AXI_RVALID = '1';
      S_AXI_RREADY <= '1';
      WAIT FOR refclk_period;
      IF i = 3 THEN
        ASSERT S_AXI_RLAST = '1' REPORT "RLAST should be high for last transfer" SEVERITY ERROR;
      ELSE
        ASSERT S_AXI_RLAST = '0' REPORT "RLAST should be low for non-last transfers" SEVERITY ERROR;
      END IF;
      S_AXI_RREADY <= '0';
      WAIT FOR refclk_period;
    END LOOP;

    -- Test case 3: Test backpressure (slave not ready)
    REPORT "Test case 3: Test backpressure";
    S_AXI_ARADDR  <= X"030"; -- Address 0x30
    S_AXI_ARLEN   <= X"03";  -- Length 3
    S_AXI_ARVALID <= '1';
    WAIT UNTIL rising_edge(refclk) AND S_AXI_ARREADY = '1';
    WAIT FOR refclk_period;
    S_AXI_ARVALID <= '0';

    -- First byte
    WAIT UNTIL rising_edge(refclk) AND S_AXI_RVALID = '1';
    S_AXI_RREADY <= '1';
    WAIT FOR refclk_period;
    S_AXI_RREADY <= '0';

    -- Second byte - don't accept immediately
    WAIT UNTIL rising_edge(refclk) AND S_AXI_RVALID = '1';
    WAIT FOR refclk_period * 2;
    S_AXI_RREADY <= '1';
    WAIT FOR refclk_period;
    S_AXI_RREADY <= '0';

    -- Third byte
    WAIT UNTIL rising_edge(refclk) AND S_AXI_RVALID = '1';
    S_AXI_RREADY <= '1';
    WAIT FOR refclk_period;
    ASSERT S_AXI_RLAST = '1' REPORT "RLAST should be high for last transfer" SEVERITY ERROR;
    S_AXI_RREADY <= '0';

    -- Test case 4: Invalid address
    REPORT "Test case 4: Invalid address";
    S_AXI_ARADDR  <= X"FFF"; -- Invalid address
    S_AXI_ARLEN   <= X"01";  -- Length 1
    S_AXI_ARVALID <= '1';
    WAIT UNTIL rising_edge(refclk) AND S_AXI_ARREADY = '1';
    WAIT FOR refclk_period;
    S_AXI_ARVALID <= '0';

    WAIT UNTIL rising_edge(refclk) AND S_AXI_RVALID = '1';
    S_AXI_RREADY <= '1';
    WAIT FOR refclk_period;
    ASSERT S_AXI_RRESP = "11" REPORT "Should get error response for invalid address" SEVERITY ERROR;
    S_AXI_RREADY <= '0';

    WAIT FOR refclk_period * 5;
    REPORT "All tests completed";
    WAIT;
  END PROCESS;

END ARCHITECTURE behavior;