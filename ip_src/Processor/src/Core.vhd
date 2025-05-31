
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
END ENTITY Core;

ARCHITECTURE rtl OF Core IS

  SIGNAL PC           : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL pc_stall     : STD_LOGIC                     := '0';
  SIGNAL pc_jump_flag : STD_LOGIC                     := '0';
  SIGNAL pc_jump_addr : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');

  -- Cache
  SIGNAL r_cache_address : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
  SIGNAL r_cache_data    : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
  SIGNAL r_cache_valid   : STD_LOGIC                     := '0';
  SIGNAL r_cache_ready   : STD_LOGIC                     := '0';

  SIGNAL w_cache_address : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
  SIGNAL w_cache_data    : STD_LOGIC_VECTOR(7 DOWNTO 0)  := (OTHERS => '0');
  SIGNAL w_cache_valid   : STD_LOGIC                     := '0';
  SIGNAL w_cache_ready   : STD_LOGIC                     := '0';
  -- /Cache

  -- Decoder
  SIGNAL decoder_instruction : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); -- Входная инструкция
  SIGNAL decoder_rs1         : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); -- Адрес регистра rs1
  SIGNAL decoder_rs2         : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); -- Адрес регистра rs2
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
  SIGNAL alu_enable : STD_LOGIC                     := '0';
  --SIGNAL alu_ready  : STD_LOGIC                     := '0';
  -- /ALU

  -- Registers
  SIGNAL reg_addr_out_i_1 : STD_LOGIC_VECTOR(4 DOWNTO 0)  := (OTHERS => '0'); -- адрес регистра (0-31)
  SIGNAL reg_data_out_i_1 : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); -- данные регистра по адресу

  SIGNAL reg_addr_out_i_2 : STD_LOGIC_VECTOR(4 DOWNTO 0)  := (OTHERS => '0'); -- адрес регистра (0-31)
  SIGNAL reg_data_out_i_2 : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); -- данные регистра по адресу

  SIGNAL reg_addr_in_i : STD_LOGIC_VECTOR(4 DOWNTO 0)  := (OTHERS => '0'); -- адрес регистра (0-31)
  SIGNAL reg_data_in_i : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); -- данные которые хотим записать в регистр 

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
  TYPE fetch_state_t IS (RESET, IDLE, FAST_FETCH, WAIT_RESPONSE);
  TYPE execution_state_t IS (RESET, IDLE, WAIT_RESULT);

  SIGNAL fetch_state     : fetch_state_t     := RESET;
  SIGNAL execution_state : execution_state_t := RESET;

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
      r_address => r_cache_address,
      r_data    => r_cache_data,
      r_valid   => r_cache_valid,
      r_ready   => r_cache_ready,

      w_address => w_cache_address,
      w_data    => w_cache_data,
      w_valid   => w_cache_valid,
      w_ready   => w_cache_ready,

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

  registers : ENTITY work.Registers
    PORT MAP(
      refclk => refclk,
      rst    => rst,

      addr_out_i_1 => reg_addr_out_i_1, -- адрес регистра (0-31)
      data_out_i_1 => reg_data_out_i_1, -- данные регистра по адресу

      addr_out_i_2 => reg_addr_out_i_2, -- адрес регистра (0-31)
      data_out_i_2 => reg_data_out_i_2, -- данные регистра по адресу

      addr_in_i => reg_addr_in_i, -- адрес регистра (0-31)
      data_in_i => reg_data_in_i, -- данные которые хотим записать в регистр 

      write_enable => reg_write_enable -- если 0 то данные возвращаются в data_out, иначе записываются в регистр из data_in
    );

  decoder : ENTITY work.Decoder
    PORT MAP(
      clk => refclk,
      rst => rst,

      instruction => decoder_instruction, -- Входная инструкция

      reg_addr_out_i_1 => reg_addr_out_i_1, -- адрес регистра (0-31)
      reg_data_out_i_1 => reg_data_out_i_1, -- данные регистра по адресу

      reg_addr_out_i_2 => reg_addr_out_i_2, -- адрес регистра (0-31)
      reg_data_out_i_2 => reg_data_out_i_2, -- данные регистра по адресу

      rs1 => decoder_rs1, -- регистр rs1
      rs2 => decoder_rs2, -- регистр rs2

      rd_addr => decoder_rd_addr, -- Адрес регистра rd
      imm     => decoder_imm,     -- Непосредственное значение

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

      enable => alu_enable
      --ready => alu_ready
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

      reg_addr_in      => reg_addr_in_i,
      reg_data_in      => reg_data_in_i,
      reg_write_enable => reg_write_enable
    );

  -- 
  -- Precess
  -- 

  fetch_state_proc : PROCESS (refclk)
  BEGIN
    IF rising_edge(refclk) THEN
      IF rst = '1' THEN
        fetch_state <= RESET;
      ELSE
        CASE fetch_state IS
          WHEN IDLE =>
            IF r_cache_ready = '1' THEN
              fetch_state <= FAST_FETCH;
            END IF;

          WHEN FAST_FETCH =>
            IF r_cache_ready = '0' THEN
              fetch_state <= WAIT_RESPONSE;
            ELSE
              fetch_state <= FAST_FETCH;
            END IF;

          WHEN WAIT_RESPONSE =>
            IF r_cache_ready = '1' THEN
              fetch_state <= FAST_FETCH;
            END IF;

          WHEN OTHERS =>
            fetch_state <= IDLE;
        END CASE;
      END IF;
    END IF;
  END PROCESS fetch_state_proc;

  fetch_output_proc : PROCESS (refclk, fetch_state, r_cache_ready, rst)
  BEGIN
    IF falling_edge(refclk) THEN
      -- Значения по умолчанию

      decoder_instruction <= (OTHERS => '0');
      r_cache_address     <= (OTHERS => '0');
      r_cache_valid       <= '0';
      pc_stall            <= '1';

      IF rst = '1' THEN
        decoder_instruction <= (OTHERS => '0');
        r_cache_address     <= (OTHERS => '0');
        r_cache_valid       <= '0';
        pc_stall            <= '1';
      ELSE
        CASE fetch_state IS
          WHEN IDLE =>
            r_cache_address <= PC;
            r_cache_valid   <= '1';
            pc_stall        <= '1';

          WHEN FAST_FETCH =>
            IF r_cache_ready = '0' THEN
              decoder_instruction <= (OTHERS => '0');
              r_cache_address     <= PC;
              r_cache_valid       <= '0';
              pc_stall            <= '0';
            ELSE
              decoder_instruction <= r_cache_data;
              r_cache_address     <= PC;
              r_cache_valid       <= '1';
              pc_stall            <= '0';
            END IF;

          WHEN WAIT_RESPONSE =>
            pc_stall <= '1';
            IF r_cache_ready = '1' THEN
              decoder_instruction <= r_cache_data;
              r_cache_address     <= PC;
              r_cache_valid       <= '1';
              pc_stall            <= '0';
            END IF;

          WHEN OTHERS                    =>
            decoder_instruction <= (OTHERS => '0');
            r_cache_address     <= (OTHERS => '0');
            r_cache_valid       <= '0';
            pc_stall            <= '1';
        END CASE;
      END IF;
    END IF;
  END PROCESS fetch_output_proc;

  decode : PROCESS (refclk)
  BEGIN
    IF rising_edge(refclk) THEN
      IF rst = '1' THEN
        execution_control   <= INVALID_CONTROL;
        execution_rd_addr   <= (OTHERS => '0');
        opcode              <= OP_INVALID;
        operand_1           <= (OTHERS => '0');
        operand_2           <= (OTHERS => '0');
        control_pc_in       <= (OTHERS => '0');
        control_rs1         <= (OTHERS => '0');
        control_rs2         <= (OTHERS => '0');
        control_imm         <= (OTHERS => '0');
        control_unit_enable <= '0';
        alu_enable          <= '0';
      ELSE
        execution_control <= decoder_control;
        execution_rd_addr <= decoder_rd_addr;
        opcode            <= decoder_control.opcode;

        IF decoder_control.alu_en = '1' THEN
          -- ALU
          operand_1 <= decoder_rs1;

          IF decoder_control.imm_type = IMM_I_TYPE THEN
            operand_2 <= decoder_imm;
          ELSE
            operand_2 <= decoder_rs2;
          END IF;
          alu_enable <= '1';
        ELSIF decoder_control.branch = '1' OR decoder_control.jump = '1' THEN
          -- ControlUnit
          control_pc_in <= STD_LOGIC_VECTOR(resize(unsigned(PC) - 2 * 4, 32)); -- отнимаем 2 слова т.к это уже второй этап конвейера

          control_rs1 <= decoder_rs1;
          control_rs2 <= decoder_rs2;

          control_imm <= decoder_imm;

          control_unit_enable <= '1';
        ELSE
          control_unit_enable <= '0';
          alu_enable          <= '0';
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
        pc_jump_addr              <= (OTHERS => '0');
      ELSE
        IF execution_control.reg_write = '1' THEN
          pc_jump_flag <= '0';
          pc_jump_addr <= (OTHERS => '0');

          result_controller_enable  <= '1';
          result_controller_result  <= alu_result;
          result_controller_rd_addr <= execution_rd_addr;

        ELSIF control_jump = '1' AND (execution_control.branch = '1' OR execution_control.jump = '1') THEN
          pc_jump_addr <= control_pc_out(11 DOWNTO 0);
          pc_jump_flag <= '1';

          result_controller_enable  <= '0';
          result_controller_result  <= (OTHERS => '0');
          result_controller_rd_addr <= (OTHERS => '0');
        ELSE
          result_controller_enable  <= '0';
          result_controller_result  <= (OTHERS => '0');
          result_controller_rd_addr <= (OTHERS => '0');
          pc_jump_flag              <= '0';
          pc_jump_addr              <= (OTHERS => '0');
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