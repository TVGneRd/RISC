
LIBRARY IEEE;--! standard library IEEE (Institute of Electrical and Electronics Engineers)
USE IEEE.std_logic_1164.ALL;--! standard unresolved logic UX01ZWLH-
USE IEEE.numeric_std.ALL;--! for the signed, unsigned types and arithmetic ops

USE work.Decoder.riscv_opcodes_pkg.ALL;
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

    immediate : IN STD_LOGIC_VECTOR(31 DOWNTO 0); -- Для I-типа, непосредственное значение

    result : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); -- Результат
    zero   : OUT STD_LOGIC;                     -- Флаг нуля (для ветвлений)
    sign   : OUT STD_LOGIC;                     -- Флаг знака (для сравнений)

    valid : IN STD_LOGIC;
    ready : IN STD_LOGIC
  );
END ENTITY ALU;
ARCHITECTURE behavioral OF ALU IS
  -- Внутренние сигналы
  SIGNAL res          : STD_LOGIC_VECTOR(31 DOWNTO 0); -- Временный результат
  SIGNAL op1_signed   : SIGNED(31 DOWNTO 0);           -- Операнд 1 как знаковое число
  SIGNAL op2_signed   : SIGNED(31 DOWNTO 0);           -- Операнд 2 как знаковое число
  SIGNAL op1_unsigned : UNSIGNED(31 DOWNTO 0);         -- Операнд 1 как беззнаковое число
  SIGNAL op2_unsigned : UNSIGNED(31 DOWNTO 0);         -- Операнд 2 как беззнаковое число
  SIGNAL op2_final    : STD_LOGIC_VECTOR(31 DOWNTO 0); -- Итоговый второй операнд
  SIGNAL shift_amount : INTEGER RANGE 0 TO 31;         -- Величина сдвига
BEGIN
  op2_final <= operand_2 WHEN (opcode = OP_ADD OR opcode = OP_SUB OR
    opcode = OP_AND OR opcode = OP_OR OR
    opcode = OP_XOR OR opcode = OP_SLL OR
    opcode = OP_SRL OR opcode = OP_SRA OR
    opcode = OP_SLT OR opcode = OP_SLTU) -- R-тип
    ELSE
    immediate; -- I-тип

  -- Приведение типов для удобства
  op1_signed   <= SIGNED(operand1);
  op2_signed   <= SIGNED(op2_final);
  op1_unsigned <= UNSIGNED(operand1);
  op2_unsigned <= UNSIGNED(op2_final);
  shift_amount <= to_integer(UNSIGNED(operand2(4 DOWNTO 0))); -- Для сдвигов (младшие 5 бит)

  -- Основной процесс ALU
  PROCESS (operand1, operand2, opcode, op1_signed, op2_signed, op1_unsigned, op2_unsigned, shift_amount)
  BEGIN
    CASE opcode IS
        -- Сложение
      WHEN OP_ADD | OP_ADDI =>
        res <= STD_LOGIC_VECTOR(op1_signed + op2_signed);

        -- Вычитание
      WHEN OP_SUB | OP_SUBI =>
        res <= STD_LOGIC_VECTOR(op1_signed - op2_signed);

        -- Логическое И
      WHEN OP_AND | OP_ANDI =>
        res <= operand1 AND operand2;

        -- Логическое ИЛИ
      WHEN OP_OR | OP_ORI =>
        res <= operand1 OR operand2;

        -- Логическое исключающее ИЛИ
      WHEN OP_XOR | OP_XORI =>
        res <= operand1 XOR operand2;

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
        res <= operand1; -- Просто передаём operand1 (например, для LUI)

        -- По умолчанию (можно добавить обработку ошибок)
      WHEN OTHERS    =>
        res <= (OTHERS => '0');
    END CASE;
  END PROCESS;

  -- Выходы
  result <= res;
  zero   <= '1' WHEN res = (res'RANGE => '0') ELSE
    '0';             -- Флаг нуля
  sign <= res(31); -- Флаг знака (старший бит результата)

END behavioral;