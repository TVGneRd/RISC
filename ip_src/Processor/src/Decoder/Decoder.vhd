
LIBRARY IEEE;--! standard library IEEE (Institute of Electrical and Electronics Engineers)
USE IEEE.std_logic_1164.ALL;--! standard unresolved logic UX01ZWLH-
USE IEEE.numeric_std.ALL;--! for the signed, unsigned types and arithmetic ops
USE work.control_signals_pkg.ALL;
USE work.riscv_opcodes_pkg.ALL;

-- -- -- -- Задача блока: -- -- -- --
-- 1. Декодирование команды
------------------------------------

-- -- -- -- Распределение: -- -- -- --
-- Дима: 1
-------------------------------------
ENTITY Decoder IS
  PORT (
    clk : IN STD_LOGIC; --! reference clock expect 250Mhz
    rst : IN STD_LOGIC;--! sync active high reset. sync -> refclk

    instruction : IN STD_LOGIC_VECTOR(31 DOWNTO 0); -- Входная инструкция

    rs1_addr : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);  -- Адрес регистра rs1
    rs2_addr : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);  -- Адрес регистра rs2
    rd_addr  : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);  -- Адрес регистра rd
    imm      : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); -- Непосредственное значение

    control : OUT control_signals_t -- Управляющие сигналы
  );
END ENTITY Decoder;
ARCHITECTURE rtl OF Decoder IS

  SIGNAL opcode  : riscv_opcode_t;
  SIGNAL funct3  : STD_LOGIC_VECTOR(2 DOWNTO 0);
  SIGNAL funct7  : STD_LOGIC_VECTOR(6 DOWNTO 0);
  SIGNAL rs1     : STD_LOGIC_VECTOR(4 DOWNTO 0);
  SIGNAL rs2     : STD_LOGIC_VECTOR(4 DOWNTO 0);
  SIGNAL rd      : STD_LOGIC_VECTOR(4 DOWNTO 0);
  SIGNAL imm_i   : STD_LOGIC_VECTOR(31 DOWNTO 0); -- I-тип
  SIGNAL imm_s   : STD_LOGIC_VECTOR(31 DOWNTO 0); -- S-тип
  SIGNAL imm_b   : STD_LOGIC_VECTOR(31 DOWNTO 0); -- B-тип
  SIGNAL imm_u   : STD_LOGIC_VECTOR(31 DOWNTO 0); -- U-тип
  SIGNAL imm_j   : STD_LOGIC_VECTOR(31 DOWNTO 0); -- J-тип
  SIGNAL imm_out : STD_LOGIC_VECTOR(31 DOWNTO 0); -- Выбранное imm
  SIGNAL ctrl    : control_signals_t;

BEGIN

  opcode <= decode_opcode(instruction);
  funct3 <= instruction(14 DOWNTO 12);
  funct7 <= instruction(31 DOWNTO 25);
  rs1    <= instruction(19 DOWNTO 15);
  rs2    <= instruction(24 DOWNTO 20);
  rd     <= instruction(11 DOWNTO 7);

  -- Формирование непосредственных значений
  -- I-тип: imm[11:0] = inst[31:20]
  imm_i <= STD_LOGIC_VECTOR(resize(SIGNED(instruction(31 DOWNTO 20)), 32));

  -- S-тип: imm[11:5] = inst[31:25], imm[4:0] = inst[11:7]
  imm_s <= STD_LOGIC_VECTOR(resize(SIGNED(instruction(31 DOWNTO 25) & instruction(11 DOWNTO 7)), 32));

  -- B-тип: imm[12|10:5|4:1|11] = {inst[31], inst[7], inst[30:25], inst[11:8], 0}
  imm_b <= STD_LOGIC_VECTOR(resize(SIGNED(instruction(31) & instruction(7) & instruction(30 DOWNTO 25) & instruction(11 DOWNTO 8) & '0'), 32));

  -- U-тип: imm[31:12] = inst[31:12], imm[11:0] = 0
  imm_u <= instruction(31 DOWNTO 12) & (11 DOWNTO 0 => '0');

  -- J-тип: imm[20|10:1|11|19:12] = {inst[31], inst[19:12], inst[20], inst[30:21], 0}
  imm_j <= STD_LOGIC_VECTOR(resize(SIGNED(instruction(31) & instruction(19 DOWNTO 12) & instruction(20) & instruction(30 DOWNTO 21) & '0'), 32));

  -- Декодирование инструкции и формирование управляющих сигналов
  PROCESS (opcode, funct3, funct7)
  BEGIN
    -- Инициализация управляющих сигналов
    ctrl.opcode     <= opcode;
    ctrl.alu_en     <= '0';
    ctrl.reg_write  <= '0';
    ctrl.mem_read   <= '0';
    ctrl.mem_write  <= '0';
    ctrl.mem_to_reg <= '0';
    ctrl.branch     <= '0';
    ctrl.jump       <= '0';
    ctrl.imm_type   <= IMM_I_TYPE;

    CASE opcode IS
        -- R-тип
      WHEN OP_ADD =>
        ctrl.alu_en    <= '1';
        ctrl.reg_write <= '1';
        ctrl.imm_type  <= IMM_R_TYPE;
      WHEN OP_SUB =>
        ctrl.alu_en    <= '1';
        ctrl.reg_write <= '1';
        ctrl.imm_type  <= IMM_R_TYPE;
      WHEN OP_SLL =>
        ctrl.alu_en    <= '1';
        ctrl.reg_write <= '1';
        ctrl.imm_type  <= IMM_R_TYPE;
      WHEN OP_SLT =>
        ctrl.alu_en    <= '1';
        ctrl.reg_write <= '1';
        ctrl.imm_type  <= IMM_R_TYPE;
      WHEN OP_SLTU =>
        ctrl.alu_en    <= '1';
        ctrl.reg_write <= '1';
        ctrl.imm_type  <= IMM_R_TYPE;
      WHEN OP_XOR =>
        ctrl.alu_en    <= '1';
        ctrl.reg_write <= '1';
        ctrl.imm_type  <= IMM_R_TYPE;
      WHEN OP_SRL =>
        ctrl.alu_en    <= '1';
        ctrl.reg_write <= '1';
        ctrl.imm_type  <= IMM_R_TYPE;
      WHEN OP_SRA =>
        ctrl.alu_en    <= '1';
        ctrl.reg_write <= '1';
        ctrl.imm_type  <= IMM_R_TYPE;
      WHEN OP_OR =>
        ctrl.alu_en    <= '1';
        ctrl.reg_write <= '1';
        ctrl.imm_type  <= IMM_R_TYPE;
      WHEN OP_AND =>
        ctrl.alu_en    <= '1';
        ctrl.reg_write <= '1';
        ctrl.imm_type  <= IMM_R_TYPE;

        -- I-тип (арифметика)
      WHEN OP_ADDI =>
        ctrl.alu_en    <= '1';
        ctrl.reg_write <= '1';
        ctrl.imm_type  <= IMM_I_TYPE;
      WHEN OP_SLTI =>
        ctrl.alu_en    <= '1';
        ctrl.reg_write <= '1';
        ctrl.imm_type  <= IMM_I_TYPE;
      WHEN OP_SLTIU =>
        ctrl.alu_en    <= '1';
        ctrl.reg_write <= '1';
        ctrl.imm_type  <= IMM_I_TYPE;
      WHEN OP_XORI =>
        ctrl.alu_en    <= '1';
        ctrl.reg_write <= '1';
        ctrl.imm_type  <= IMM_I_TYPE;
      WHEN OP_ORI =>
        ctrl.alu_en    <= '1';
        ctrl.reg_write <= '1';
        ctrl.imm_type  <= IMM_I_TYPE;
      WHEN OP_ANDI =>
        ctrl.alu_en    <= '1';
        ctrl.reg_write <= '1';
        ctrl.imm_type  <= IMM_I_TYPE;
      WHEN OP_SLLI =>
        ctrl.alu_en    <= '1';
        ctrl.reg_write <= '1';
        ctrl.imm_type  <= IMM_I_TYPE;
      WHEN OP_SRLI =>
        ctrl.alu_en    <= '1';
        ctrl.reg_write <= '1';
        ctrl.imm_type  <= IMM_I_TYPE;
      WHEN OP_SRAI =>
        ctrl.alu_en    <= '1';
        ctrl.reg_write <= '1';
        ctrl.imm_type  <= IMM_I_TYPE;

        -- I-тип (загрузка)
      WHEN OP_LB | OP_LH | OP_LW | OP_LBU | OP_LHU =>
        ctrl.reg_write  <= '1';
        ctrl.mem_read   <= '1';
        ctrl.mem_to_reg <= '1';
        ctrl.imm_type   <= IMM_I_TYPE;

        -- I-тип (JALR)
      WHEN OP_JALR =>
        ctrl.reg_write <= '1';
        ctrl.jump      <= '1';
        ctrl.imm_type  <= IMM_I_TYPE;

        -- S-тип
      WHEN OP_SB | OP_SH | OP_SW =>
        ctrl.mem_write <= '1';
        ctrl.imm_type  <= IMM_S_TYPE;

        -- B-тип
      WHEN OP_BEQ | OP_BNE | OP_BLT | OP_BGE | OP_BLTU | OP_BGEU =>
        ctrl.branch   <= '1';
        ctrl.imm_type <= IMM_B_TYPE;

        -- U-тип
      WHEN OP_LUI =>
        ctrl.reg_write <= '1';
        ctrl.imm_type  <= IMM_U_TYPE;
      WHEN OP_AUIPC =>
        ctrl.reg_write <= '1';
        ctrl.imm_type  <= IMM_U_TYPE;

        -- J-тип
      WHEN OP_JAL =>
        ctrl.reg_write <= '1';
        ctrl.jump      <= '1';
        ctrl.imm_type  <= IMM_J_TYPE;

        -- Системные инструкции (упрощённо)
      WHEN OP_ECALL | OP_EBREAK =>
        -- Здесь нужно добавить обработку прерываний
        ctrl.reg_write <= '0';

      WHEN OTHERS =>
        ctrl.reg_write <= '0';
    END CASE;
  END PROCESS;

  -- Выбор imm в зависимости от типа инструкции
  imm_out <=
    imm_i WHEN ctrl.imm_type = IMM_I_TYPE ELSE
    imm_s WHEN ctrl.imm_type = IMM_S_TYPE ELSE
    imm_b WHEN ctrl.imm_type = IMM_B_TYPE ELSE
    imm_u WHEN ctrl.imm_type = IMM_U_TYPE ELSE
    imm_j WHEN ctrl.imm_type = IMM_J_TYPE ELSE
    (OTHERS => '0');

  -- Выходы
  rs1_addr <= rs1 WHEN ctrl.imm_type = IMM_R_TYPE OR ctrl.imm_type = IMM_I_TYPE OR ctrl.imm_type = IMM_S_TYPE OR ctrl.imm_type = IMM_B_TYPE ELSE
    (OTHERS => '0');
  rs2_addr <= rs2 WHEN ctrl.imm_type = IMM_R_TYPE OR ctrl.imm_type = IMM_S_TYPE OR ctrl.imm_type = IMM_B_TYPE ELSE
    (OTHERS => '0');
  rd_addr <= rd WHEN ctrl.imm_type /= IMM_S_TYPE AND ctrl.imm_type /= IMM_B_TYPE ELSE
    (OTHERS => '0');
  imm <= imm_out WHEN ctrl.imm_type /= IMM_R_TYPE ELSE
    (OTHERS => '0');
  control <= ctrl;

END ARCHITECTURE rtl;