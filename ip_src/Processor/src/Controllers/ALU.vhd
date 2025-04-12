
LIBRARY IEEE;--! standard library IEEE (Institute of Electrical and Electronics Engineers)
USE IEEE.std_logic_1164.ALL;--! standard unresolved logic UX01ZWLH-
USE IEEE.numeric_std.ALL;--! for the signed, unsigned types and arithmetic ops

USE work.riscv_opcodes_pkg.ALL;
-- -- -- -- Задача блока: -- -- -- --
-- 1. Выполнение арифметических операций R-тип и I-тип
------------------------------------

-- -- -- -- Распределение: -- -- -- --
-- Андрей: 1
-------------------------------------

ENTITY ALU IS
  PORT (
    refclk : IN STD_LOGIC;--! reference clock expect 250Mhz
    rst    : IN STD_LOGIC;--! sync active high reset. sync -> refclk

    opcode    : IN riscv_opcode_t;
    operand_1 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    operand_2 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);

    result : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); -- Результат
    zero   : OUT STD_LOGIC;                     -- Флаг нуля (для ветвлений)
    sign   : OUT STD_LOGIC;                     -- Флаг знака (для сравнений)

    valid : IN STD_LOGIC;
    ready : OUT STD_LOGIC
  );
END ENTITY ALU;
ARCHITECTURE behavioral OF ALU IS

  TYPE m_state_type IS (rst_state, idle, accept_state, proc_state, transmitting);

  SIGNAL cur_state  : m_state_type := rst_state;
  SIGNAL next_state : m_state_type := rst_state;

  -- Внутренние сигналы
  SIGNAL res : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); -- Временный результат
  -- SIGNAL op1_signed   : SIGNED(31 DOWNTO 0)           := (OTHERS => '0'); -- Операнд 1 как знаковое число
  -- SIGNAL op2_signed   : SIGNED(31 DOWNTO 0)           := (OTHERS => '0'); -- Операнд 2 как знаковое число
  -- SIGNAL op1_unsigned : UNSIGNED(31 DOWNTO 0)         := (OTHERS => '0'); -- Операнд 1 как беззнаковое число
  -- SIGNAL op2_unsigned : UNSIGNED(31 DOWNTO 0)         := (OTHERS => '0'); -- Операнд 2 как беззнаковое число
  -- SIGNAL op2_final    : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); -- Итоговый второй операнд
  -- SIGNAL shift_amount : INTEGER RANGE 0 TO 31         := 0;               -- Величина сдвига

  SIGNAL readyFlag : STD_LOGIC := '0';

BEGIN
  result <= res;
  state_transition : PROCESS (refclk, rst)
  BEGIN
    IF rst = '1' THEN
      cur_state <= rst_state;
    ELSIF rising_edge(refclk) THEN
      cur_state <= next_state;
    END IF;
  END PROCESS;

  -- Основной процесс ALU
  processing : PROCESS (rst, cur_state, refclk)
    VARIABLE op1_signed   : SIGNED(31 DOWNTO 0)   := (OTHERS => '0');
    VARIABLE op2_signed   : SIGNED(31 DOWNTO 0)   := (OTHERS => '0');
    VARIABLE op1_unsigned : UNSIGNED(31 DOWNTO 0) := (OTHERS => '0');
    VARIABLE op2_unsigned : UNSIGNED(31 DOWNTO 0) := (OTHERS => '0');
    VARIABLE shift_amount : INTEGER RANGE 0 TO 31 := 0;
  BEGIN
    IF rst = '1' THEN
      readyFlag <= '0';
      res       <= (OTHERS => '0');
    ELSIF cur_state = idle OR cur_state = accept_state THEN
      readyFlag <= '0';
      res       <= (OTHERS => '0');
    ELSIF cur_state = proc_state AND readyFlag = '0' AND rising_edge(refclk) THEN
      -- IF (opcode = OP_ADD OR opcode = OP_SUB OR
      --   opcode = OP_AND OR opcode = OP_OR OR
      --   opcode = OP_XOR OR opcode = OP_SLL OR
      --   opcode = OP_SRL OR opcode = OP_SRA OR
      --   opcode = OP_SLT OR opcode = OP_SLTU) THEN
      --   op2_final <= operand_2; -- R-тип
      -- ELSE
      --   op2_final <= immediate; -- I-тип
      -- END IF;

      -- Приведение типов для удобства
      op1_signed   := SIGNED(operand_1);
      op2_signed   := SIGNED(operand_2);
      op1_unsigned := UNSIGNED(operand_1);
      op2_unsigned := UNSIGNED(operand_2);
      shift_amount := to_integer(UNSIGNED(operand_2(4 DOWNTO 0))); -- Для сдвигов (младшие 5 бит)

      CASE opcode IS
          -- Сложение
        WHEN OP_ADD | OP_ADDI =>
          res <= STD_LOGIC_VECTOR(op1_signed + op2_signed);

          -- Вычитание
        WHEN OP_SUB => --  | OP_SUBI
          res <= STD_LOGIC_VECTOR(op1_signed - op2_signed);

          -- Логическое И
        WHEN OP_AND | OP_ANDI =>
          res <= operand_1 AND operand_2;

          -- Логическое ИЛИ
        WHEN OP_OR | OP_ORI =>
          res <= operand_1 OR operand_2;

          -- Логическое исключающее ИЛИ
        WHEN OP_XOR | OP_XORI =>
          res <= operand_1 XOR operand_2;

          -- Сдвиг влево
        WHEN OP_SLL | OP_SLLI =>
          res <= STD_LOGIC_VECTOR(shift_left(op1_unsigned, shift_amount));

          -- Сдвиг вправо логический
        WHEN OP_SRL | OP_SRLI =>
          res <= STD_LOGIC_VECTOR(shift_right(op1_unsigned, shift_amount));

          -- Сдвиг вправо арифметический
        WHEN OP_SRA | OP_SRAI =>
          res <= STD_LOGIC_VECTOR(shift_right(op1_signed, shift_amount));

          -- Сравнение со знаком (SLT, SLTI)
        WHEN OP_SLT | OP_SLTI =>
          IF op1_signed < op2_signed THEN
            res <= (0 => '1', OTHERS => '0'); -- 1, если op1 < op2
          ELSE
            res <= (OTHERS => '0'); -- 0, если op1 >= op2
          END IF;
          -- Сравнение без знака (SLTU, SLTIU)
        WHEN OP_SLTU =>
          IF op1_unsigned < op2_unsigned THEN
            res <= (0 => '1', OTHERS => '0'); -- 1, если op1 < op2
          ELSE
            res <= (OTHERS => '0'); -- 0, если op1 >= op2
          END IF;

          -- Прямое копирование (для LUI, AUIPC)
        WHEN OP_LUI =>
          res <= operand_1; -- Просто передаём operand_1 (например, для LUI)

          -- По умолчанию (можно добавить обработку ошибок)
        WHEN OTHERS    =>
          res <= (OTHERS => '0');
      END CASE;
      readyFlag <= '1';
    ELSIF cur_state = transmitting THEN
      readyFlag <= '1';
    END IF;

  END PROCESS;

  state_decider : PROCESS (cur_state, valid, readyFlag)
  BEGIN
    next_state <= cur_state;
    CASE cur_state IS
      WHEN rst_state =>
        next_state <= idle;
      WHEN idle =>
        IF valid = '1' THEN
          next_state <= accept_state;
        ELSE
          next_state <= next_state;
        END IF;
      WHEN accept_state =>
        IF readyFlag = '0' THEN
          next_state <= proc_state;
        ELSE
          next_state <= next_state;
        END IF;
      WHEN proc_state =>
        IF readyFlag = '1' THEN
          --IF 1 = 0 THEN
          next_state <= transmitting;
        ELSE
          next_state <= next_state;
        END IF;
      WHEN transmitting =>
        IF valid = '0' THEN
          next_state <= idle;
        ELSE
          next_state <= next_state;
        END IF;
    END CASE;
  END PROCESS;

  output_decide : PROCESS (cur_state)
  BEGIN
    CASE cur_state IS
      WHEN rst_state =>
        ready <= '0';
        --readyFlag <= '0';
        --result    <= (OTHERS => '0');
        zero <= '0';
        sign <= '0';
      WHEN idle =>
        ready <= '1';
        --readyFlag <= '0';
        --result    <= (OTHERS => '0');
        --res <= (OTHERS => '0');
        zero <= '0';
        sign <= '0';
      WHEN accept_state =>
        ready <= '0';
      WHEN proc_state =>
        IF readyFlag = '1' THEN
          --IF 1 = 0 THEN
          ready <= '1';
        ELSE
          ready <= '0';
        END IF;
      WHEN transmitting =>
        -- Выходы
        ready <= '1';
        --result <= res;

        IF res = (res'RANGE => '0') THEN
          zero <= '1';
        ELSE
          zero <= '0';
        END IF;
        sign <= res(31); -- Флаг знака (старший бит результата)
    END CASE;
  END PROCESS;

END behavioral;