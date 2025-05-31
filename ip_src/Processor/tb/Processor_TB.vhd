
LIBRARY IEEE;--! standard library IEEE (Institute of Electrical and Electronics Engineers)
USE IEEE.std_logic_1164.ALL;--! standard unresolved logic UX01ZWLH-
USE IEEE.numeric_std.ALL;--! for the signed, unsigned types and arithmetic ops
USE IEEE.std_logic_textio.ALL; -- если используете to_hstring

ENTITY Processor_TB IS
  GENERIC (
    EDGE_CLK : TIME := 2 ns
  );
END ENTITY Processor_TB;
ARCHITECTURE rtl OF Processor_TB IS
  SIGNAL rst            : STD_LOGIC := '0';
  SIGNAL refclk         : STD_LOGIC := '0';
  SIGNAL test_completed : BOOLEAN   := FALSE;

  SIGNAL decoder_test_completed           : STD_LOGIC := '0';
  SIGNAL cache_test_completed             : STD_LOGIC := '0';
  SIGNAL alu_test_completed               : STD_LOGIC := '0';
  SIGNAL registers_test_completed         : STD_LOGIC := '0';
  SIGNAL core_test_completed              : STD_LOGIC := '0';
  SIGNAL result_controller_test_completed : STD_LOGIC := '0';
  SIGNAL control_unit_test_completed      : STD_LOGIC := '0';

  SIGNAL M_AXI_ARADDR  : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
  SIGNAL M_AXI_ARLEN   : STD_LOGIC_VECTOR(7 DOWNTO 0)  := (OTHERS => '0');
  SIGNAL M_AXI_ARVALID : STD_LOGIC                     := '0';
  SIGNAL M_AXI_ARREADY : STD_LOGIC                     := '0';
  SIGNAL M_AXI_RDATA   : STD_LOGIC_VECTOR(7 DOWNTO 0)  := (OTHERS => '0');
  SIGNAL M_AXI_RRESP   : STD_LOGIC_VECTOR(1 DOWNTO 0)  := (OTHERS => '0');
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
      M_AXI_RREADY : OUT STD_LOGIC;
      -- /AXI-4 MM (Только Reader) Ports

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

  COMPONENT control_unit_tb IS
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

  COMPONENT result_controller_tb IS
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

    M_AXI_RDATA  => M_AXI_RDATA,
    M_AXI_RRESP  => M_AXI_RRESP,
    M_AXI_RLAST  => M_AXI_RLAST,
    M_AXI_RVALID => M_AXI_RVALID,
    M_AXI_RREADY => M_AXI_RREADY,

    M_AXI_AWADDR  => M_AXI_AWADDR,
    M_AXI_AWVALID => M_AXI_AWVALID,
    M_AXI_AWREADY => M_AXI_AWREADY,
    M_AXI_AWLEN   => M_AXI_AWLEN,

    M_AXI_WDATA  => M_AXI_WDATA,
    M_AXI_WVALID => M_AXI_WVALID,
    M_AXI_WREADY => M_AXI_WREADY,
    M_AXI_WLAST  => M_AXI_WLAST,

    M_AXI_BRESP  => M_AXI_BRESP,
    M_AXI_BVALID => M_AXI_BVALID,
    M_AXI_BREADY => M_AXI_BREADY
  );

  test_completed <= decoder_test_completed = '1'
    AND cache_test_completed = '1'
    AND alu_test_completed = '1'
    AND result_controller_test_completed = '1'
    AND registers_test_completed = '1'
    AND core_test_completed = '1'
    AND control_unit_test_completed = '1';

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

  tb_result_controller_inst : result_controller_tb
  GENERIC MAP(
    EDGE_CLK => EDGE_CLK
  )
  PORT MAP(
    clk            => refclk,
    rst            => rst,
    test_completed => result_controller_test_completed
  );
  tb_control_unit_inst : control_unit_tb
  GENERIC MAP(
    EDGE_CLK => EDGE_CLK
  )
  PORT MAP(
    clk            => refclk,
    rst            => rst,
    test_completed => control_unit_test_completed
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
    VARIABLE axi_last : STD_LOGIC := '0';

    PROCEDURE transmit_byte(
      byte : STD_LOGIC_VECTOR(7 DOWNTO 0);
      last : STD_LOGIC
    ) IS
    BEGIN
      WAIT UNTIL rising_edge(refclk);
      M_AXI_RVALID <= '1';
      M_AXI_RDATA  <= byte;
      M_AXI_RLAST  <= last;

      WAIT UNTIL rising_edge(refclk) AND M_AXI_RREADY = '1' FOR 5 * EDGE_CLK;
      ASSERT M_AXI_RREADY = '1' REPORT "M_AXI_ARREADY != 1" SEVERITY ERROR;

      M_AXI_RVALID <= '0';

      WAIT FOR EDGE_CLK;

    END PROCEDURE;

    PROCEDURE transmit_word(
      word : STD_LOGIC_VECTOR(31 DOWNTO 0);
      last : STD_LOGIC
    ) IS
      VARIABLE byte_last : STD_LOGIC := '0';
    BEGIN
      FOR i IN 0 TO 3 LOOP
        IF i = 3 AND last = '1' THEN
          byte_last := '1';
        END IF;
        transmit_byte(word(i * 8 + 7 DOWNTO i * 8), byte_last);
      END LOOP;

    END PROCEDURE;

  BEGIN
    rst <= '1';
    WAIT FOR 10 * EDGE_CLK;
    rst <= '0';

    M_AXI_ARREADY <= '1';

    WAIT UNTIL M_AXI_ARVALID = '1' FOR 10 * EDGE_CLK;
    ASSERT M_AXI_ARVALID = '1' REPORT "M_AXI_ARREADY != 1" SEVERITY ERROR;

    M_AXI_ARREADY <= '0';

    -- Simulate data return (64 bytes)
    transmit_word("00000001100100000000001010010011", '0'); -- addi x5, zero, 25  (ADDR: 0)
    transmit_word("00000001111000000000001100010011", '0'); -- addi x6, zero, 30 (ADDR: 4)
    transmit_word("00000000011000101000001110110011", '0'); -- add  x7, x5, x6 (ADDR: 8)
    transmit_word("00000011011100000000111000010011", '0'); -- addi x28, zero, 55 (ADDR: 12)
    transmit_word("00000101110000111001010001100011", '0'); -- bne x7, x28, test_failed (+40) 0x28 (ADDR: 16)
    transmit_word("00000010000000000000000011101111", '0'); -- j test_completed (+32) 0x20 (ADDR: 20 (0x14))

    FOR i IN 6 * 4 TO 63 LOOP
      IF i = 63 THEN
        axi_last := '1';
      END IF;
      transmit_byte(x"00", axi_last);
    END LOOP;

    WAIT FOR EDGE_CLK;

    M_AXI_RVALID  <= '0';
    M_AXI_RLAST   <= '0';
    M_AXI_ARREADY <= '1';

    -- Расчет времени выполнения команды:
    -- После установки M_AXI_ARREADY=1 команда попадет в декодер через 1 такт
    -- первая команда выполнится за 4 такта
    -- последующие команды выполняются 1 такт
    -- всего команд 5 (не считая первой)
    -- после выполнения прыжка нужен еще 1 такт чтобы сигнал из кэша дошел до axi_reader
    -- Итог: 1 + 4 + 5 + 1= 11
    WAIT FOR 11 * 2 * EDGE_CLK; -- На выполнение команды дается 6 тактов 
    WAIT FOR EDGE_CLK;

    ASSERT M_AXI_ARVALID = '1' REPORT "M_AXI_ARVALID != '1'" SEVERITY ERROR;

    -- PC(0x14) + 0x20 * 4 = 148 (0x94)
    ASSERT unsigned(M_AXI_ARADDR) = 16#94# REPORT "Program should have requested the address 0x94 (PC(0x14) + 0x20 * 4) is 0x" & to_hstring(to_bitvector(M_AXI_ARADDR)) SEVERITY ERROR;

    core_test_completed <= '1';

    WAIT;

  END PROCESS test_bench_main;
END ARCHITECTURE rtl;