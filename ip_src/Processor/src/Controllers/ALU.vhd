LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;

USE work.riscv_opcodes_pkg.ALL;

ENTITY ALU IS
  PORT (
    refclk    : IN STD_LOGIC;
    rst       : IN STD_LOGIC;
    opcode    : IN riscv_opcode_t;
    operand_1 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    operand_2 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    result    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    zero      : OUT STD_LOGIC;
    sign      : OUT STD_LOGIC;
    valid     : IN STD_LOGIC;
    ready     : OUT STD_LOGIC
  );
END ENTITY ALU;

ARCHITECTURE behavioral OF ALU IS
  -- Внутренние сигналы для комбинационных результатов
  SIGNAL add_result  : STD_LOGIC_VECTOR(31 DOWNTO 0);
  SIGNAL sub_result  : STD_LOGIC_VECTOR(31 DOWNTO 0);
  SIGNAL and_result  : STD_LOGIC_VECTOR(31 DOWNTO 0);
  SIGNAL or_result   : STD_LOGIC_VECTOR(31 DOWNTO 0);
  SIGNAL xor_result  : STD_LOGIC_VECTOR(31 DOWNTO 0);
  SIGNAL sll_result  : STD_LOGIC_VECTOR(31 DOWNTO 0);
  SIGNAL srl_result  : STD_LOGIC_VECTOR(31 DOWNTO 0);
  SIGNAL sra_result  : STD_LOGIC_VECTOR(31 DOWNTO 0);
  SIGNAL slt_result  : STD_LOGIC_VECTOR(31 DOWNTO 0);
  SIGNAL sltu_result : STD_LOGIC_VECTOR(31 DOWNTO 0);
  SIGNAL lui_result  : STD_LOGIC_VECTOR(31 DOWNTO 0);

  SIGNAL result_comb : STD_LOGIC_VECTOR(31 DOWNTO 0);
  SIGNAL zero_comb   : STD_LOGIC;
  SIGNAL sign_comb   : STD_LOGIC;
  SIGNAL ready_comb  : STD_LOGIC;

  SIGNAL result_reg : STD_LOGIC_VECTOR(31 DOWNTO 0);
  SIGNAL zero_reg   : STD_LOGIC;
  SIGNAL sign_reg   : STD_LOGIC;
  SIGNAL ready_reg  : STD_LOGIC;

  SIGNAL op1_signed   : SIGNED(31 DOWNTO 0);
  SIGNAL op2_signed   : SIGNED(31 DOWNTO 0);
  SIGNAL op1_unsigned : UNSIGNED(31 DOWNTO 0);
  SIGNAL op2_unsigned : UNSIGNED(31 DOWNTO 0);
  SIGNAL shift_amount : INTEGER RANGE 0 TO 31;

BEGIN
  -- Комбинационная логика
  comb_logic : PROCESS (opcode, operand_1, operand_2, valid)
    -- Используем сигналы вместо переменных для совместимости с VHDL-2002
  BEGIN
    -- Приведение типов
    op1_signed   <= SIGNED(operand_1);
    op2_signed   <= SIGNED(operand_2);
    op1_unsigned <= UNSIGNED(operand_1);
    op2_unsigned <= UNSIGNED(operand_2);
    shift_amount <= to_integer(UNSIGNED(operand_2(4 DOWNTO 0)));

    -- Вычисление операций
    add_result <= STD_LOGIC_VECTOR(op1_signed + op2_signed);
    sub_result <= STD_LOGIC_VECTOR(op1_signed - op2_signed);
    and_result <= operand_1 AND operand_2;
    or_result  <= operand_1 OR operand_2;
    xor_result <= operand_1 XOR operand_2;

    -- Сдвиги реализованы через явные выражения для VHDL-2002
    sll_result <= STD_LOGIC_VECTOR(op1_unsigned SLL shift_amount);
    srl_result <= STD_LOGIC_VECTOR(op1_unsigned SRL shift_amount);
    sra_result <= STD_LOGIC_VECTOR(shift_right(op1_signed, shift_amount));

    -- Сравнения
    IF op1_signed < op2_signed THEN
      slt_result <= X"00000001";
    ELSE
      slt_result <= X"00000000";
    END IF;
    IF op1_unsigned < op2_unsigned THEN
      sltu_result <= X"00000001";
    ELSE
      sltu_result <= X"00000000";
    END IF;

    lui_result <= operand_1;

    -- Выбор результата
    IF valid = '1' THEN
      CASE opcode IS
        WHEN OP_ADD | OP_ADDI =>
          result_comb <= add_result;
        WHEN OP_SUB =>
          result_comb <= sub_result;
        WHEN OP_AND | OP_ANDI =>
          result_comb <= and_result;
        WHEN OP_OR | OP_ORI =>
          result_comb <= or_result;
        WHEN OP_XOR | OP_XORI =>
          result_comb <= xor_result;
        WHEN OP_SLL | OP_SLLI =>
          result_comb <= sll_result;
        WHEN OP_SRL | OP_SRLI =>
          result_comb <= srl_result;
        WHEN OP_SRA | OP_SRAI =>
          result_comb <= sra_result;
        WHEN OP_SLT | OP_SLTI =>
          result_comb <= slt_result;
        WHEN OP_SLTU =>
          result_comb <= sltu_result;
        WHEN OP_LUI =>
          result_comb <= lui_result;
        WHEN OTHERS            =>
          result_comb <= result_comb;
      END CASE;
      ready_comb <= '1';
    ELSE
      --result_comb <= (OTHERS => '0');
      ready_comb  <= '0';
    END IF;

    -- Флаги
    IF result_comb = X"00000000" THEN
      zero_comb <= '1';
    ELSE
      zero_comb <= '0';
    END IF;
    sign_comb <= result_comb(31);
  END PROCESS;

  -- Синхронный процесс
  -- sync_proc : PROCESS (refclk, rst)
  -- BEGIN
  --   IF rst = '1' THEN
  --     result_reg <= (OTHERS => '0');
  --     zero_reg   <= '0';
  --     sign_reg   <= '0';
  --     ready_reg  <= '0';
  --   ELSIF rising_edge(refclk) THEN
  --   --ELSE
  --     result_reg <= result_comb;
  --     zero_reg   <= zero_comb;
  --     sign_reg   <= sign_comb;
  --     ready_reg  <= ready_comb;
  --   END IF;
  -- END PROCESS;

  -- Выходы
  result <= result_comb;
  zero   <= zero_comb;
  sign   <= sign_comb;
  ready  <= ready_comb;

END behavioral;