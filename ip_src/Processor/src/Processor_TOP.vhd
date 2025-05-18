
LIBRARY IEEE;--! standard library IEEE (Institute of Electrical and Electronics Engineers)
USE IEEE.std_logic_1164.ALL;--! standard unresolved logic UX01ZWLH-
USE IEEE.numeric_std.ALL;--! for the signed, unsigned types and arithmetic ops

-- -- -- -- Задача блока: -- -- -- --
-- 1. Подключение ядер
------------------------------------

-- -- -- -- Распределение: -- -- -- --
-- Дима:
-------------------------------------

ENTITY Processor_TOP IS
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
END ENTITY Processor_TOP;
ARCHITECTURE rtl OF Processor_TOP IS
BEGIN
  core_1 : ENTITY work.Core
    PORT MAP(
      refclk => refclk,
      rst    => rst,
      -- AXI-4 MM (Только Reader) Ports
      --  Read address channel signals
      M_AXI_ARADDR  => M_AXI_ARADDR,
      M_AXI_ARLEN   => M_AXI_ARLEN,
      M_AXI_ARVALID => M_AXI_ARVALID,
      M_AXI_ARREADY => M_AXI_ARREADY,

      -- Read data channel signals
      M_AXI_RDATA  => M_AXI_RDATA,
      M_AXI_RRESP  => M_AXI_RRESP,
      M_AXI_RLAST  => M_AXI_RLAST,
      M_AXI_RVALID => M_AXI_RVALID,
      M_AXI_RREADY => M_AXI_RREADY,

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
END ARCHITECTURE rtl;