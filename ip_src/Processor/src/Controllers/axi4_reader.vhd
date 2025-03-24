
LIBRARY IEEE;--! standard library IEEE (Institute of Electrical and Electronics Engineers)
USE IEEE.std_logic_1164.ALL;--! standard unresolved logic UX01ZWLH-
USE IEEE.numeric_std.ALL;--! for the signed, unsigned types and arithmetic ops

ENTITY TestProject_TOP IS
    PORT (
        refclk : IN STD_LOGIC;--! reference clock expect 250Mhz
        rstn   : IN STD_LOGIC; --! sync active low reset. sync -> refclk

        cam_data  : IN STD_LOGIC_VECTOR (23 DOWNTO 0);
        cam_ready : IN STD_LOGIC;
        cam_valid : OUT STD_LOGIC;

        s_axi_araddr_0  : IN STD_LOGIC_VECTOR (14 DOWNTO 0);
        s_axi_arlen_0   : IN STD_LOGIC_VECTOR (7 DOWNTO 0);
        s_axi_arready_0 : OUT STD_LOGIC;
        s_axi_arsize_0  : IN STD_LOGIC_VECTOR (2 DOWNTO 0);
        s_axi_arvalid_0 : IN STD_LOGIC;
        s_axi_rdata_0   : OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
        s_axi_rlast_0   : OUT STD_LOGIC;
        s_axi_rready_0  : IN STD_LOGIC;
        s_axi_rresp_0   : OUT STD_LOGIC_VECTOR (1 DOWNTO 0);
        s_axi_rvalid_0  : OUT STD_LOGIC
    );

END ENTITY TestProject_TOP;
ARCHITECTURE rtl OF TestProject_TOP IS
BEGIN
    design_1_wrapper_i : ENTITY work.design_1_wrapper
        PORT MAP(
            refclk    => refclk,
            sys_rst_n => rstn,

            cam_data  => cam_data,
            cam_ready => cam_ready,
            cam_valid => cam_valid,

            s_axi_araddr_0  => s_axi_araddr_0,
            s_axi_arlen_0   => s_axi_arlen_0,
            s_axi_arready_0 => s_axi_arready_0,
            s_axi_arsize_0  => s_axi_arsize_0,
            s_axi_arvalid_0 => s_axi_arvalid_0,
            s_axi_rdata_0   => s_axi_rdata_0,
            s_axi_rlast_0   => s_axi_rlast_0,
            s_axi_rready_0  => s_axi_rready_0,
            s_axi_rresp_0   => s_axi_rresp_0,
            s_axi_rvalid_0  => s_axi_rvalid_0
        );

END ARCHITECTURE rtl;