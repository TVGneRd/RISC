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
    enable    : IN STD_LOGIC
    --ready     : OUT STD_LOGIC
  );
END ENTITY ALU;

ARCHITECTURE behavioral OF ALU IS
  -- Внутренние сигналы для комбинационных результатов
  SIGNAL result_comb : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
  SIGNAL zero_comb   : STD_LOGIC                     := '0';
  SIGNAL sign_comb   : STD_LOGIC                     := '0';
  SIGNAL ready_comb  : STD_LOGIC                     := '0';
BEGIN
  -- Комбинационная логика
  comb_logic : PROCESS (refclk, opcode, operand_1, operand_2, enable)
    -- Используем сигналы вместо переменных для совместимости с VHDL-2002
    VARIABLE op1_signed   : SIGNED(31 DOWNTO 0);
    VARIABLE op2_signed   : SIGNED(31 DOWNTO 0);
    VARIABLE op1_unsigned : UNSIGNED(31 DOWNTO 0);
    VARIABLE op2_unsigned : UNSIGNED(31 DOWNTO 0);
    VARIABLE shift_amount : INTEGER RANGE 0 TO 31;

    VARIABLE add_result  : STD_LOGIC_VECTOR(31 DOWNTO 0);
    VARIABLE sub_result  : STD_LOGIC_VECTOR(31 DOWNTO 0);
    VARIABLE and_result  : STD_LOGIC_VECTOR(31 DOWNTO 0);
    VARIABLE or_result   : STD_LOGIC_VECTOR(31 DOWNTO 0);
    VARIABLE xor_result  : STD_LOGIC_VECTOR(31 DOWNTO 0);
    VARIABLE sll_result  : STD_LOGIC_VECTOR(31 DOWNTO 0);
    VARIABLE srl_result  : STD_LOGIC_VECTOR(31 DOWNTO 0);
    VARIABLE sra_result  : STD_LOGIC_VECTOR(31 DOWNTO 0);
    VARIABLE slt_result  : STD_LOGIC_VECTOR(31 DOWNTO 0);
    VARIABLE sltu_result : STD_LOGIC_VECTOR(31 DOWNTO 0);
    VARIABLE lui_result  : STD_LOGIC_VECTOR(31 DOWNTO 0);

    -- Переменные для операций умножения и деления
    VARIABLE mul_result    : STD_LOGIC_VECTOR(31 DOWNTO 0);
    VARIABLE mulh_result   : STD_LOGIC_VECTOR(31 DOWNTO 0);
    VARIABLE mulhsu_result : STD_LOGIC_VECTOR(31 DOWNTO 0);
    VARIABLE mulhu_result  : STD_LOGIC_VECTOR(31 DOWNTO 0);
    VARIABLE div_result    : STD_LOGIC_VECTOR(31 DOWNTO 0);
    VARIABLE divu_result   : STD_LOGIC_VECTOR(31 DOWNTO 0);
    VARIABLE rem_result    : STD_LOGIC_VECTOR(31 DOWNTO 0);
    VARIABLE remu_result   : STD_LOGIC_VECTOR(31 DOWNTO 0);

    VARIABLE op2_signed_positive : SIGNED(31 DOWNTO 0);

    -- Временные переменные для 64-битных промежуточных результатов
    VARIABLE temp64_signed   : SIGNED(63 DOWNTO 0);
    VARIABLE temp64_unsigned : UNSIGNED(63 DOWNTO 0);

    VARIABLE result_reg : STD_LOGIC_VECTOR(31 DOWNTO 0);
    VARIABLE zero_reg   : STD_LOGIC;
    VARIABLE sign_reg   : STD_LOGIC;
    VARIABLE ready_reg  : STD_LOGIC;
  BEGIN
    -- Приведение типов
    op1_signed   := SIGNED(operand_1);
    op2_signed   := SIGNED(operand_2);
    op1_unsigned := UNSIGNED(operand_1);
    op2_unsigned := UNSIGNED(operand_2);
    shift_amount := to_integer(UNSIGNED(operand_2(4 DOWNTO 0)));

    -- Вычисление операций
    add_result := STD_LOGIC_VECTOR(op1_signed + op2_signed);
    sub_result := STD_LOGIC_VECTOR(op1_signed - op2_signed);
    and_result := operand_1 AND operand_2;
    or_result  := operand_1 OR operand_2;
    xor_result := operand_1 XOR operand_2;

    -- Сдвиги реализованы через явные выражения для VHDL-2002
    sll_result := STD_LOGIC_VECTOR(op1_unsigned SLL shift_amount);
    srl_result := STD_LOGIC_VECTOR(op1_unsigned SRL shift_amount);
    sra_result := STD_LOGIC_VECTOR(shift_right(op1_signed, shift_amount));

    -- Сравнения
    IF op1_signed < op2_signed THEN
      slt_result := X"00000001";
    ELSE
      slt_result := X"00000000";
    END IF;
    IF op1_unsigned < op2_unsigned THEN
      sltu_result := X"00000001";
    ELSE
      sltu_result := X"00000000";
    END IF;

    lui_result := operand_2;

    -- Вычисление операций умножения и деления (расширение M)
    -- MUL: умножение младших 32 бит (знаковое × знаковое)
    temp64_signed := op1_signed * op2_signed;
    mul_result    := STD_LOGIC_VECTOR(temp64_signed(31 DOWNTO 0));

    -- MULH: старшие 32 бита произведения (знаковое × знаковое)
    mulh_result := STD_LOGIC_VECTOR(temp64_signed(63 DOWNTO 32));

    -- MULHSU: старшие 32 бита произведения (знаковое × беззнаковое)
    --    temp64_signed := op1_signed * SIGNED('0' & op2_unsigned);
    --    mulhsu_result := STD_LOGIC_VECTOR(temp64_signed(63 DOWNTO 32));
    op2_signed_positive := SIGNED(op2_unsigned);
    temp64_signed       := op1_signed * op2_signed_positive;
    mulhsu_result       := STD_LOGIC_VECTOR(temp64_signed(63 DOWNTO 32));

    -- MULHU: старшие 32 бита произведения (беззнаковое × беззнаковое)
    temp64_unsigned := op1_unsigned * op2_unsigned;
    mulhu_result    := STD_LOGIC_VECTOR(temp64_unsigned(63 DOWNTO 32));

    -- DIV: деление (знаковое)
    IF op2_signed = 0 THEN
      div_result := (OTHERS => '1'); -- Деление на 0: возвращаем все единицы
    ELSIF op1_signed =- 2147483648 AND op2_signed =- 1 THEN
      div_result := X"80000000"; -- Особый случай переполнения
    ELSE
      div_result := STD_LOGIC_VECTOR(op1_signed / op2_signed);
    END IF;

    -- DIVU: деление (беззнаковое)
    IF op2_unsigned = 0 THEN
      divu_result := (OTHERS => '1'); -- Деление на 0: возвращаем все единицы
    ELSE
      divu_result := STD_LOGIC_VECTOR(op1_unsigned / op2_unsigned);
    END IF;

    -- REM: остаток от деления (знаковый)
    IF op2_signed = 0 THEN
      rem_result := operand_1; -- При делении на 0 возвращаем делимое
    ELSIF op1_signed =- 2147483648 AND op2_signed =- 1 THEN
      rem_result := (OTHERS => '0'); -- Особый случай переполнения
    ELSE
      rem_result := STD_LOGIC_VECTOR(op1_signed REM op2_signed);
    END IF;

    -- REMU: остаток от деления (беззнаковый)
    IF op2_unsigned = 0 THEN
      remu_result := operand_1; -- При делении на 0 возвращаем делимое
    ELSE
      remu_result := STD_LOGIC_VECTOR(op1_unsigned REM op2_unsigned);
    END IF;

    -- Выбор результата
    IF enable = '1' THEN
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

          -- Операции умножения и деления (расширение M)
        WHEN OP_MUL =>
          result_comb <= mul_result;
        WHEN OP_MULH =>
          result_comb <= mulh_result;
        WHEN OP_MULHSU =>
          result_comb <= mulhsu_result;
        WHEN OP_MULHU =>
          result_comb <= mulhu_result;
        WHEN OP_DIV =>
          result_comb <= div_result;
        WHEN OP_DIVU =>
          result_comb <= divu_result;
        WHEN OP_REM =>
          result_comb <= rem_result;
        WHEN OP_REMU =>
          result_comb <= remu_result;

        WHEN OTHERS =>
          result_comb <= result_comb;
      END CASE;
      --ready_comb <= '1';
    ELSE
      --result_comb <= (OTHERS => '0');
      --ready_comb <= '0';
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
  --ready  <= ready_comb;

END behavioral;