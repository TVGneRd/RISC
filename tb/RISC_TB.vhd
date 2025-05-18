
LIBRARY IEEE;--! standard library IEEE (Institute of Electrical and Electronics Engineers)
USE IEEE.std_logic_1164.ALL;--! standard unresolved logic UX01ZWLH-
USE IEEE.numeric_std.ALL;--! for the signed, unsigned types and arithmetic ops

ENTITY RISC_TB IS
  GENERIC (
    EDGE_CLK : TIME := 2 ns
  );
END ENTITY RISC_TB;
ARCHITECTURE rtl OF RISC_TB IS
  SIGNAL rst            : STD_LOGIC := '1';
  SIGNAL refclk         : STD_LOGIC := '0';
  SIGNAL test_completed : BOOLEAN   := false;
  COMPONENT design_1_wrapper IS
    PORT (
      refclk : IN STD_LOGIC;--! reference clock expect 250Mhz
      rst    : IN STD_LOGIC--! sync active high reset. sync -> refclk
    );
  END COMPONENT;
BEGIN

  design : design_1_wrapper
  PORT MAP
  (
    refclk => refclk,
    rst    => rst
  );

  test_clk_generator : PROCESS
  BEGIN
    IF NOT test_completed THEN
      refclk <= NOT refclk;
      WAIT FOR EDGE_CLK;
    ELSE
      WAIT;
    END IF;
  END PROCESS test_clk_generator;

  test_bench_main : PROCESS
  BEGIN
    rst <= '0' AFTER 5 ns;
    WAIT;
  END PROCESS test_bench_main;
END ARCHITECTURE rtl;