
LIBRARY IEEE;--! standard library IEEE (Institute of Electrical and Electronics Engineers)
USE IEEE.std_logic_1164.ALL;--! standard unresolved logic UX01ZWLH-
USE IEEE.numeric_std.ALL;--! for the signed, unsigned types and arithmetic ops

ENTITY Processor_TB IS
  GENERIC (
    EDGE_CLK : TIME := 2 ns
  );
END ENTITY Processor_TB;
ARCHITECTURE rtl OF Processor_TB IS
  SIGNAL rst            : STD_LOGIC := '0';
  SIGNAL refclk         : STD_LOGIC := '0';
  SIGNAL test_completed : BOOLEAN   := FALSE;

  SIGNAL decoder_test_completed   : STD_LOGIC := '0';
  SIGNAL cache_test_completed     : STD_LOGIC := '0';
  SIGNAL alu_test_completed       : STD_LOGIC := '0';
  SIGNAL registers_test_completed : STD_LOGIC := '0';

  SIGNAL M_AXI_ARADDR  : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL M_AXI_ARLEN   : STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL M_AXI_ARVALID : STD_LOGIC;
  SIGNAL M_AXI_ARREADY : STD_LOGIC;
  SIGNAL M_AXI_RDATA   : STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL M_AXI_RRESP   : STD_LOGIC_VECTOR(1 DOWNTO 0);
  SIGNAL M_AXI_RLAST   : STD_LOGIC;
  SIGNAL M_AXI_RVALID  : STD_LOGIC;
  SIGNAL M_AXI_RREADY  : STD_LOGIC;

  COMPONENT Processor_TOP IS
    PORT (
      refclk : IN STD_LOGIC; --! reference clock expect 250Mhz
      rst    : IN STD_LOGIC; --! sync active high reset. sync -> refclk

      -- AXI-4 MM (Только Reader) Ports
      --  Read address channel signals
      M_AXI_ARLEN   : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      M_AXI_ARADDR  : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      M_AXI_ARVALID : OUT STD_LOGIC;
      M_AXI_ARREADY : IN STD_LOGIC;

      -- Read data channel signals
      M_AXI_RDATA  : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
      M_AXI_RRESP  : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      M_AXI_RLAST  : IN STD_LOGIC;
      M_AXI_RVALID : IN STD_LOGIC;
      M_AXI_RREADY : OUT STD_LOGIC
      -- /AXI-4 MM (Только Reader) Ports
    );
  END COMPONENT;

  COMPONENT registers_tb IS
    GENERIC (
      EDGE_CLK : TIME := 2 ns
    );
    PORT (
      clk            : IN STD_LOGIC;
      rst            : IN STD_LOGIC;
      test_completed : OUT STD_LOGIC
    );
  END COMPONENT;

  COMPONENT tb_decoder IS
    GENERIC (
      EDGE_CLK : TIME := 2 ns
    );
    PORT (
      clk            : IN STD_LOGIC;
      rst            : IN STD_LOGIC;
      test_completed : OUT STD_LOGIC
    );
  END COMPONENT;

  COMPONENT cache_tb IS
    GENERIC (
      EDGE_CLK : TIME := 2 ns
    );
    PORT (
      clk            : IN STD_LOGIC;
      rst            : IN STD_LOGIC;
      test_completed : OUT STD_LOGIC
    );
  END COMPONENT;

  COMPONENT alu_tb IS
    GENERIC (
      EDGE_CLK : TIME := 2 ns
    );
    PORT (
      clk            : IN STD_LOGIC;
      rst            : IN STD_LOGIC;
      test_completed : OUT STD_LOGIC
    );
  END COMPONENT;

BEGIN

  Processor_TOP_inst : Processor_TOP
  PORT MAP
  (
    refclk => refclk,
    rst    => rst,

    M_AXI_ARADDR  => M_AXI_ARADDR,
    M_AXI_ARLEN   => M_AXI_ARLEN,
    M_AXI_ARVALID => M_AXI_ARVALID,
    M_AXI_ARREADY => M_AXI_ARREADY,
    M_AXI_RDATA   => M_AXI_RDATA,
    M_AXI_RRESP   => M_AXI_RRESP,
    M_AXI_RLAST   => M_AXI_RLAST,
    M_AXI_RVALID  => M_AXI_RVALID,
    M_AXI_RREADY  => M_AXI_RREADY
  );

  test_completed <= decoder_test_completed = '1' AND cache_test_completed = '1' AND alu_test_completed = '1' AND registers_test_completed = '1';

  tb_registers_inst : registers_tb
  GENERIC MAP(
    EDGE_CLK => EDGE_CLK
  )
  PORT MAP(
    clk            => refclk,
    rst            => rst,
    test_completed => registers_test_completed
  );

  tb_decoder_inst : tb_decoder
  GENERIC MAP(
    EDGE_CLK => EDGE_CLK
  )
  PORT MAP(
    clk            => refclk,
    rst            => rst,
    test_completed => decoder_test_completed
  );

  tb_cache_inst : cache_tb
  GENERIC MAP(
    EDGE_CLK => EDGE_CLK
  )
  PORT MAP(
    clk            => refclk,
    rst            => rst,
    test_completed => cache_test_completed
  );

  tb_alu_inst : alu_tb
  GENERIC MAP(
    EDGE_CLK => EDGE_CLK
  )
  PORT MAP(
    clk            => refclk,
    rst            => rst,
    test_completed => alu_test_completed
  );

  test_clk_generator : PROCESS
  BEGIN
    IF NOT test_completed THEN
      refclk <= NOT refclk;
      WAIT FOR EDGE_CLK;
    ELSE
      REPORT "ALL TEST COMPLIED";
      WAIT;
    END IF;
  END PROCESS test_clk_generator;

  test_bench_main : PROCESS
  BEGIN
    rst <= '1';
    WAIT FOR 10 * EDGE_CLK;
    rst <= '0';
    WAIT;
  END PROCESS test_bench_main;
END ARCHITECTURE rtl;