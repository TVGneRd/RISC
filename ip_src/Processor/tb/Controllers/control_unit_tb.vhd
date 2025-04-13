LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE work.riscv_opcodes_pkg.ALL;

ENTITY control_unit_tb IS
    GENERIC (
        EDGE_CLK : TIME := 2 ns
    );
    PORT (
        clk            : IN STD_LOGIC;
        rst            : IN STD_LOGIC;
        test_completed : OUT STD_LOGIC
    );
END ENTITY control_unit_tb;

ARCHITECTURE behavior OF control_unit_tb IS
    -- Component Declaration for the Unit Under Test (UUT)
    COMPONENT ControlUnit
        PORT (
            refclk : IN STD_LOGIC;
            rst    : IN STD_LOGIC;
            opcode : IN riscv_opcode_t;
            rs1    : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            rs2    : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            imm    : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            enable : IN STD_LOGIC;
            pc_in  : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            pc_out : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            jump   : OUT STD_LOGIC
        );
    END COMPONENT;

    -- Inputs
    SIGNAL opcode : riscv_opcode_t;
    SIGNAL rs1    : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL rs2    : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL imm    : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL enable : STD_LOGIC                     := '0';
    SIGNAL pc_in  : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');

    -- Outputs
    SIGNAL pc_out : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL jump   : STD_LOGIC;
    PROCEDURE verify_test (
        test_name     : STRING;
        expected_pc   : STD_LOGIC_VECTOR(31 DOWNTO 0);
        expected_jump : STD_LOGIC;
        actual_pc     : STD_LOGIC_VECTOR(31 DOWNTO 0);
        actual_jump   : STD_LOGIC
    ) IS
    BEGIN
        IF actual_pc = expected_pc AND actual_jump = expected_jump THEN
            REPORT "PASS: " & test_name SEVERITY NOTE;
        ELSE
            REPORT "FAIL: " & test_name &
                " (Expected: pc=0x" &
                ", jump=" & STD_LOGIC'image(expected_jump) &
                " | Actual: pc=0x" &
                ", jump=" & STD_LOGIC'image(actual_jump) & ")"
                SEVERITY ERROR;
        END IF;
        WAIT FOR 2 * EDGE_CLK;
    END PROCEDURE;

BEGIN
    -- Instantiate the Unit Under Test (UUT)
    uut : ControlUnit PORT MAP(
        refclk => clk,
        rst    => rst,
        opcode => opcode,
        rs1    => rs1,
        rs2    => rs2,
        imm    => imm,
        enable => enable,
        pc_in  => pc_in,
        pc_out => pc_out,
        jump   => jump
    );
    -- Stimulus process
    stim_proc : PROCESS
    BEGIN
        test_completed <= '0';

        WAIT UNTIL rising_edge(clk) AND rst = '0';
        -- Test 1: BEQ when equal
        enable <= '1';
        opcode <= OP_BEQ;
        rs1    <= X"0000000A";
        rs2    <= X"0000000A";
        imm    <= X"00000004"; -- pc_out should be 0x10 (4*4)
        pc_in  <= X"00000001";
        verify_test("BEQ (equal)", X"00000005", '1', pc_out, jump);

        -- Test 2: BEQ when not equal
        rs1 <= X"0000000A";
        rs2 <= X"0000000B";
        verify_test("BEQ (not equal)", pc_in, '0', pc_out, jump);

        -- Test 3: BNE when not equal
        opcode <= OP_BNE;
        rs1    <= X"0000000A";
        rs2    <= X"0000000B";

        verify_test("BNE (not equal)", X"00000010", '1', pc_out, jump);

        -- Test 4: BNE when equal
        rs1 <= X"0000000A";
        rs2 <= X"0000000A";

        verify_test("BNE (equal)", pc_in, '0', pc_out, jump);

        -- Test 5: BLT when less (signed)
        opcode <= OP_BLT;
        rs1    <= X"FFFFFFFF"; -- -1
        rs2    <= X"00000001"; -- 1

        verify_test("BLT (less, signed)", X"00000010", '1', pc_out, jump);

        -- Test 6: BLT when not less (signed)
        rs1 <= X"00000002"; -- 2
        rs2 <= X"00000001"; -- 1

        verify_test("BLT (not less, signed)", pc_in, '0', pc_out, jump);

        -- Test 7: BGE when greater or equal (signed)
        opcode <= OP_BGE;
        rs1    <= X"00000001"; -- 1
        rs2    <= X"FFFFFFFF"; -- -1

        verify_test("BGE (greater, signed)", X"00000010", '1', pc_out, jump);

        -- Test 8: BGE when not greater or equal (signed)
        rs1 <= X"FFFFFFFF"; -- -1
        rs2 <= X"00000001"; -- 1

        verify_test("BGE (not greater, signed)", pc_in, '0', pc_out, jump);

        -- Test 9: BLTU when less (unsigned)
        opcode <= OP_BLTU;
        rs1    <= X"00000001"; -- 1
        rs2    <= X"00000002"; -- 2

        verify_test("BLTU (less, unsigned)", X"00000010", '1', pc_out, jump);

        -- Test 10: BLTU when not less (unsigned)
        rs1 <= X"00000002"; -- 2
        rs2 <= X"00000001"; -- 1

        verify_test("BLTU (not less, unsigned)", pc_in, '0', pc_out, jump);

        -- Test 11: BGEU when greater or equal (unsigned)
        opcode <= OP_BGEU;
        rs1    <= X"00000002"; -- 2
        rs2    <= X"00000001"; -- 1

        verify_test("BGEU (greater, unsigned)", X"00000010", '1', pc_out, jump);

        -- Test 12: BGEU when not greater or equal (unsigned)
        rs1 <= X"00000001"; -- 1
        rs2 <= X"00000002"; -- 2

        verify_test("BGEU (not greater, unsigned)", pc_in, '0', pc_out, jump);

        -- Test 13: JAL (unconditional jump)
        opcode <= OP_JAL;
        imm    <= X"00001000"; -- Jump to 0x1000 directly

        verify_test("JAL (unconditional)", X"00001000", '1', pc_out, jump);

        -- Test 14: Disabled (enable = 0)
        enable <= '0';
        opcode <= OP_BEQ;
        rs1    <= X"0000000A";
        rs2    <= X"0000000A";

        verify_test("Disabled (enable=0)", pc_in, '0', pc_out, jump);

        -- Test 15: Unknown opcode
        enable <= '1';
        opcode <= OP_INVALID; -- Unknown opcode

        verify_test("Unknown opcode", (OTHERS => '0'), '0', pc_out, jump);

        -- End of simulation
        REPORT "Control Unit Test Completed" SEVERITY NOTE;
        test_completed <= '1';
        WAIT;
    END PROCESS;

END ARCHITECTURE behavior;