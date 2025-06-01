LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY PC_Controller IS
    PORT (
        clk : IN STD_LOGIC;
        rst : IN STD_LOGIC;

        stall     : IN STD_LOGIC;
        jump      : IN STD_LOGIC;
        jump_addr : IN STD_LOGIC_VECTOR(11 DOWNTO 0);

        pc_out : OUT STD_LOGIC_VECTOR(11 DOWNTO 0)
    );
END ENTITY;

ARCHITECTURE rtl OF PC_Controller IS
    SIGNAL pc_reg : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
BEGIN
    pc_proc : PROCESS (rst, clk, stall, jump, jump_addr)
    BEGIN
        IF stall = '0' THEN
            IF rising_edge(clk) THEN
                IF rst = '1' THEN
                    pc_reg <= (OTHERS => '0');
                ELSIF jump = '1' THEN
                    pc_reg <= jump_addr;
                ELSE
                    pc_reg <= STD_LOGIC_VECTOR(unsigned(pc_reg) + 4);
                END IF;
            END IF;
        ELSE
            pc_reg <= pc_reg; -- ничего не делаем
        END IF;
    END PROCESS pc_proc;

    pc_out <= pc_reg;

END ARCHITECTURE;