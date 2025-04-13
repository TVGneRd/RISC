
LIBRARY IEEE;--! standard library IEEE (Institute of Electrical and Electronics Engineers)
USE IEEE.std_logic_1164.ALL;--! standard unresolved logic UX01ZWLH-
USE IEEE.numeric_std.ALL;--! for the signed, unsigned types and arithmetic ops
USE work.control_signals_pkg.ALL;
USE work.riscv_opcodes_pkg.ALL;

-- -- -- -- Задача блока: -- -- -- --
-- 1. Подключение регистров и распространение его в остальные модули 
-- 2. Конвейер, 4 ступени
-- 3. Передача команды в декодер
-- 4. Передача данных на АЛУ
-- 5. Запись данных в результирующий/регистр
------------------------------------

-- -- -- -- Распределение: -- -- -- --
-- Дима:
-- Андрей:
-- Диана:
-------------------------------------

ENTITY Core IS
  PORT (
    refclk : IN STD_LOGIC;--! reference clock expect 250Mhz
    rst    : IN STD_LOGIC; --! sync active high reset. sync -> refclk

    -- AXI-4 MM (Только Reader) Ports
    --  Read address channel signals
    M_AXI_ARADDR  : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    M_AXI_ARLEN   : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    M_AXI_ARVALID : OUT STD_LOGIC;
    M_AXI_ARREADY : IN STD_LOGIC;

    -- Read data channel signals
    M_AXI_RDATA  : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    M_AXI_RRESP  : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    M_AXI_RLAST  : IN STD_LOGIC;
    M_AXI_RVALID : IN STD_LOGIC;
    M_AXI_RREADY : OUT STD_LOGIC
    -- /AXI-4 MM (Только Reader) Ports
  );
END ENTITY Core;

ARCHITECTURE rtl OF Core IS

  SIGNAL PC           : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL pc_stall     : STD_LOGIC                     := '0';
  SIGNAL pc_jump_flag : STD_LOGIC                     := '0';
  SIGNAL pc_jump_addr : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');

  -- Cache
  SIGNAL cache_address : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
  SIGNAL cache_data    : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
  SIGNAL cache_valid   : STD_LOGIC                     := '0';
  SIGNAL cache_ready   : STD_LOGIC                     := '0';
  -- /Cache

  -- Decoder
  SIGNAL decoder_instruction : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); -- Входная инструкция
  SIGNAL decoder_rs1_addr    : STD_LOGIC_VECTOR(4 DOWNTO 0)  := (OTHERS => '0'); -- Адрес регистра rs1
  SIGNAL decoder_rs2_addr    : STD_LOGIC_VECTOR(4 DOWNTO 0)  := (OTHERS => '0'); -- Адрес регистра rs2
  SIGNAL decoder_rd_addr     : STD_LOGIC_VECTOR(4 DOWNTO 0)  := (OTHERS => '0'); -- Адрес регистра rd
  SIGNAL decoder_imm         : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); -- Непосредственное значение
  SIGNAL decoder_control     : control_signals_t;                                -- Управляющие сигналы
  -- /Decoder

  -- ALU
  SIGNAL opcode     : riscv_opcode_t;
  SIGNAL operand_1  : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
  SIGNAL operand_2  : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
  SIGNAL alu_result : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); -- Результат
  SIGNAL alu_zero   : STD_LOGIC                     := '0';             -- Флаг нуля (для ветвлений)
  SIGNAL alu_sign   : STD_LOGIC                     := '0';             -- Флаг знака (для сравнений)
  SIGNAL alu_valid  : STD_LOGIC                     := '0';
  SIGNAL alu_ready  : STD_LOGIC                     := '0';
  -- /ALU

  -- Registers
  SIGNAL reg_addr_i : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0'); -- адрес регистра (0-31)

  SIGNAL reg_data_in    : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); -- данные которые хотим записать в регистр 
  SIGNAL reg_data_out_i : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); -- данные регистра по адресу

  SIGNAL reg_write_enable : STD_LOGIC := '0'; -- разрешение на запись, если 0 то данные возвращаются в data_out, иначе записываются в регистр из data_in
  -- /Registers

  -- ControlUnit
  SIGNAL control_unit_enable : STD_LOGIC                     := '0';
  SIGNAL control_pc_out      : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
  SIGNAL control_pc_in       : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
  SIGNAL control_rs1         : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); -- Адрес регистра rs1
  SIGNAL control_rs2         : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); -- Адрес регистра rs2
  SIGNAL control_imm         : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); -- Адрес регистра rs2
  SIGNAL control_jump        : STD_LOGIC                     := '0';
  -- /ControlUnit

  -- ResultController
  SIGNAL result_controller_enable  : STD_LOGIC := '0';
  SIGNAL result_controller_rd_addr : STD_LOGIC_VECTOR(4 DOWNTO 0);
  SIGNAL result_controller_result  : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
  -- /ResultController

  -- 
  -- Конвейеры
  -- 
  TYPE fetch_state_t IS (RESET, IDLE, REQUEST, WAIT_REQUEST_ACCEPT, WAIT_RESPONSE);
  TYPE execution_state_t IS (RESET, IDLE, WAIT_RESULT);

  SIGNAL fetch_state     : fetch_state_t     := IDLE;
  SIGNAL execution_state : execution_state_t := IDLE;

  SIGNAL execution_control : control_signals_t;            -- Управляющие сигналы
  SIGNAL execution_rd_addr : STD_LOGIC_VECTOR(4 DOWNTO 0); -- Адрес регистра rd
  -- 
BEGIN
  pc_controller_inst : ENTITY work.PC_Controller
    PORT MAP(
      clk => refclk,
      rst => rst,

      stall     => pc_stall,
      jump      => pc_jump_flag,
      jump_addr => pc_jump_addr,
      pc_out    => PC
    );

  cache : ENTITY work.Cache
    PORT MAP(
      refclk => refclk,
      rst    => rst,

      -- Порты для взаимодействия с ядром процессором, через него возвращаются данные из кэша
      address => cache_address,
      data    => cache_data,
      valid   => cache_valid,
      ready   => cache_ready,

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
      M_AXI_RREADY => M_AXI_RREADY
    );

  registers : ENTITY work.Registers
    PORT MAP(
      refclk => refclk,
      rst    => rst,

      addr_i  => reg_addr_i,  -- адрес регистра (0-31)
      data_in => reg_data_in, -- данные которые хотим записать в регистр 

      data_out_i => reg_data_out_i, -- данные регистра по адресу

      write_enable => reg_write_enable -- если 0 то данные возвращаются в data_out, иначе записываются в регистр из data_in
    );

  decoder : ENTITY work.Decoder
    PORT MAP(
      clk => refclk,
      rst => rst,

      instruction => decoder_instruction, -- Входная инструкция

      rs1_addr => decoder_rs1_addr, -- Адрес регистра rs1
      rs2_addr => decoder_rs2_addr, -- Адрес регистра rs2
      rd_addr  => decoder_rd_addr,  -- Адрес регистра rd
      imm      => decoder_imm,      -- Непосредственное значение

      control => decoder_control
    );

  alu : ENTITY work.ALU
    PORT MAP(
      refclk => refclk,
      rst    => rst,

      opcode    => opcode,
      operand_1 => operand_1,
      operand_2 => operand_2,

      result => alu_result, -- Результат

      zero => alu_zero, -- Флаг нуля (для ветвлений)
      sign => alu_sign, -- Флаг знака (для сравнений)

      valid => alu_valid,
      ready => alu_ready
    );

  control_unit : ENTITY work.ControlUnit
    PORT MAP(
      refclk => refclk,
      rst    => rst,

      opcode => opcode,

      rs1 => control_rs1,
      rs2 => control_rs2,

      imm => control_imm,

      enable => control_unit_enable,

      pc_in  => control_pc_in,
      pc_out => control_pc_out,

      jump => control_jump
    );

  result_controller : ENTITY work.ResultController
    PORT MAP(
      refclk => refclk,
      rst    => rst,

      enable  => result_controller_enable,
      result  => result_controller_result,
      rd_addr => result_controller_rd_addr,

      reg_addr_i       => reg_addr_i,
      reg_data_in      => reg_data_in,
      reg_write_enable => reg_write_enable
    );

  -- 
  -- Precess
  -- 

  fetch : PROCESS (refclk)
  BEGIN
    IF rising_edge(refclk) THEN
      IF rst = '1' THEN
        fetch_state         <= IDLE;
        decoder_instruction <= (OTHERS => '0');
      ELSE
        CASE fetch_state IS
          WHEN IDLE =>
            fetch_state         <= REQUEST;
            cache_address       <= PC;
            decoder_instruction <= (OTHERS => '0');
            cache_valid         <= '0';

          WHEN REQUEST =>
            fetch_state         <= REQUEST;
            cache_address       <= PC;
            decoder_instruction <= (OTHERS => '0');

            IF cache_ready = '1' THEN
              cache_valid <= '1';
              fetch_state <= WAIT_REQUEST_ACCEPT;
            END IF;

          WHEN WAIT_REQUEST_ACCEPT =>
            IF cache_ready = '0' THEN
              fetch_state <= WAIT_RESPONSE;
            END IF;

          WHEN WAIT_RESPONSE =>
            IF cache_ready = '1' AND execution_state = IDLE THEN
              fetch_state         <= IDLE;
              decoder_instruction <= cache_data;
              cache_valid         <= '0';
            END IF;
          WHEN OTHERS =>
            fetch_state         <= IDLE;
            decoder_instruction <= (OTHERS => '0');
            cache_address       <= (OTHERS => '0');
            cache_valid         <= '0';
        END CASE;
      END IF;
    END IF;
  END PROCESS fetch;

  decode : PROCESS (refclk)
  BEGIN
    IF rising_edge(refclk) THEN
      IF rst = '1' THEN

      ELSE
        execution_control <= decoder_control;
        execution_rd_addr <= decoder_rd_addr;
        IF decoder_control.alu_en = '1' THEN
          -- ALU
          opcode     <= decoder_control.opcode;
          reg_addr_i <= decoder_rs1_addr;
          operand_1  <= reg_data_out_i;

          IF decoder_control.imm_type = IMM_I_TYPE THEN
            operand_2 <= decoder_imm;
          ELSE
            reg_addr_i <= decoder_rs2_addr;
            operand_2  <= reg_data_out_i;
          END IF;
          alu_valid <= '1';
        ELSIF decoder_control.branch = '1' OR decoder_control.jump = '1' THEN
          -- ControlUnit
          opcode <= decoder_control.opcode;

          control_pc_in <= STD_LOGIC_VECTOR(resize(unsigned(PC), 32));

          reg_addr_i  <= decoder_rs1_addr;
          control_rs1 <= reg_data_out_i;
          reg_addr_i  <= decoder_rs2_addr;
          control_rs2 <= reg_data_out_i;

          control_imm <= decoder_imm;

          control_unit_enable <= '1';
        ELSE
          control_unit_enable <= '0';
          alu_valid           <= '0';
        END IF;
      END IF;
    END IF;
  END PROCESS decode;

  execution : PROCESS (refclk)
  BEGIN
    IF rising_edge(refclk) THEN
      IF rst = '1' THEN
        result_controller_enable  <= '0';
        result_controller_result  <= (OTHERS => '0');
        result_controller_rd_addr <= (OTHERS => '0');
        pc_jump_flag              <= '0';
      ELSE
        pc_jump_flag <= '0';

        IF execution_control.reg_write = '1' THEN
          result_controller_enable  <= '1';
          result_controller_result  <= alu_result;
          result_controller_rd_addr <= execution_rd_addr;
        ELSIF control_jump = '1' AND (decoder_control.branch = '1' OR decoder_control.jump = '1') THEN
          pc_jump_flag <= '1';
          pc_jump_addr <= control_pc_out(11 DOWNTO 0);
        END IF;
      END IF;
    END IF;
  END PROCESS execution;

  result : PROCESS (refclk)
  BEGIN
    IF rising_edge(refclk) THEN
      IF rst = '1' THEN
      END IF;
    END IF;
  END PROCESS result;

END ARCHITECTURE rtl;