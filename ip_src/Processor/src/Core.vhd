LIBRARY IEEE;--! standard library IEEE (Institute of Electrical and Electronics Engineers)
USE IEEE.std_logic_1164.ALL;--! standard unresolved logic UX01ZWLH-
USE IEEE.numeric_std.ALL;--! for the signed, unsigned types and arithmetic ops
USE work.control_signals_pkg.ALL;
USE work.riscv_opcodes_pkg.ALL;

-- -- -- -- Задача блока: -- -- -- --
-- 1. Подключение регистров и распространение его в остальные модули 
-- 2. Управление 4-мя конвейерами
-- 3. Арбитраж доступа к общим ресурсам (кэш, регистры)
-- 4. PC контроллер для распределения инструкций
------------------------------------

-- -- -- -- Распределение: -- -- -- --
-- Дима:
-- Андрей:
-- Диана:
-------------------------------------

ENTITY Core IS
  GENERIC (
    cache_size : INTEGER := 64;
    NUM_PIPELINES : INTEGER := 4 -- Количество конвейеров
  );
  PORT (
    refclk : IN STD_LOGIC;--! reference clock expect 250Mhz
    rst : IN STD_LOGIC; --! sync active high reset. sync -> refclk

    -- AXI-4 MM (Только Reader) Ports
    --  Read address channel signals
    M_AXI_ARADDR : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    M_AXI_ARLEN : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    M_AXI_ARVALID : OUT STD_LOGIC;
    M_AXI_ARREADY : IN STD_LOGIC;

    -- Read data channel signals
    M_AXI_RDATA : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    M_AXI_RRESP : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    M_AXI_RLAST : IN STD_LOGIC;
    M_AXI_RVALID : IN STD_LOGIC;
    M_AXI_RREADY : OUT STD_LOGIC;
    -- /AXI-4 MM (Только Reader) Ports

    M_AXI_AWADDR : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    M_AXI_AWLEN : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    M_AXI_AWVALID : OUT STD_LOGIC;
    M_AXI_AWREADY : IN STD_LOGIC;

    -- Read data channel signals
    M_AXI_WDATA : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    M_AXI_WLAST : OUT STD_LOGIC; -- всегда 1
    M_AXI_WVALID : OUT STD_LOGIC;
    M_AXI_WREADY : IN STD_LOGIC;

    M_AXI_BRESP : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    M_AXI_BVALID : IN STD_LOGIC;
    M_AXI_BREADY : OUT STD_LOGIC
  );
END ENTITY Core;

ARCHITECTURE rtl OF Core IS

  -- ========================================
  -- PC Controller signals
  -- ========================================
  SIGNAL PC : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL pc_stall : STD_LOGIC := '0';
  SIGNAL pc_jump_flag : STD_LOGIC := '0';
  SIGNAL pc_jump_addr : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');

  -- PC для каждого конвейера (смещенный)
  TYPE pc_array_t IS ARRAY (0 TO NUM_PIPELINES - 1) OF STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL pc_pipeline : pc_array_t;

  -- ========================================
  -- Cache signals
  -- ========================================
  SIGNAL r_cache_address : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
  SIGNAL r_cache_data : STD_LOGIC_VECTOR(127 DOWNTO 0) := (OTHERS => '0'); -- 4 команды
  SIGNAL r_cache_valid : STD_LOGIC := '0';
  SIGNAL r_cache_ready : STD_LOGIC := '0';

  SIGNAL w_cache_address : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
  SIGNAL w_cache_data : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
  SIGNAL w_cache_valid : STD_LOGIC := '0';
  SIGNAL w_cache_ready : STD_LOGIC := '0';

  -- ========================================
  -- Register File signals (direct connection to each pipeline)
  -- ========================================

  -- ========================================
  -- Pipeline interface arrays
  -- ========================================
  -- Stall signals from pipelines
  TYPE stall_array_t IS ARRAY (0 TO NUM_PIPELINES - 1) OF STD_LOGIC;
  SIGNAL pipeline_stall : stall_array_t;

  -- Jump signals from pipelines
  TYPE jump_flag_array_t IS ARRAY (0 TO NUM_PIPELINES - 1) OF STD_LOGIC;
  TYPE jump_addr_array_t IS ARRAY (0 TO NUM_PIPELINES - 1) OF STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL pipeline_jump_flag : jump_flag_array_t;
  SIGNAL pipeline_jump_addr : jump_addr_array_t;

  -- Cache read interface per pipeline (simplified - all get data simultaneously)
  TYPE cache_addr_array_t IS ARRAY (0 TO NUM_PIPELINES - 1) OF STD_LOGIC_VECTOR(11 DOWNTO 0);
  TYPE cache_valid_array_t IS ARRAY (0 TO NUM_PIPELINES - 1) OF STD_LOGIC;
  -- Все конвейеры получают данные одновременно - grant больше не нужен для чтения
  -- Каждый конвейер получает свою 32-битную команду из 128-битной шины
  TYPE cache_data_32_array_t IS ARRAY (0 TO NUM_PIPELINES - 1) OF STD_LOGIC_VECTOR(31 DOWNTO 0);
  SIGNAL p_r_cache_data : cache_data_32_array_t;

  -- Cache write interface per pipeline
  TYPE cache_data_array_t IS ARRAY (0 TO NUM_PIPELINES - 1) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL p_w_cache_address : cache_addr_array_t;
  SIGNAL p_w_cache_data : cache_data_array_t;
  SIGNAL p_w_cache_valid : cache_valid_array_t;
  SIGNAL p_w_cache_grant : cache_valid_array_t;

  -- Register interface per pipeline (direct connection)
  TYPE reg_addr_array_t IS ARRAY (0 TO NUM_PIPELINES - 1) OF STD_LOGIC_VECTOR(4 DOWNTO 0);
  TYPE reg_data_array_t IS ARRAY (0 TO NUM_PIPELINES - 1) OF STD_LOGIC_VECTOR(31 DOWNTO 0);
  TYPE reg_grant_array_t IS ARRAY (0 TO NUM_PIPELINES - 1) OF STD_LOGIC_VECTOR(31 DOWNTO 0);

  -- Массив Используемых регистров для каждого конвейера
  SIGNAL p_reg_grant : reg_grant_array_t := (OTHERS => (OTHERS => '0')); -- какие регистры запрошены 
  SIGNAL p_reg_grant_valid : reg_grant_array_t := (OTHERS => (OTHERS => '0')); -- получил право на использование регистра

  SIGNAL p_reg_addr_out_1 : reg_addr_array_t;
  SIGNAL p_reg_data_out_1 : reg_data_array_t;
  SIGNAL p_reg_addr_out_2 : reg_addr_array_t;
  SIGNAL p_reg_data_out_2 : reg_data_array_t;
  SIGNAL p_reg_addr_in : reg_addr_array_t;
  SIGNAL p_reg_data_in : reg_data_array_t;
  SIGNAL p_reg_write_enable : cache_valid_array_t;

  -- Pipeline status
  SIGNAL p_active : cache_valid_array_t;
  SIGNAL p_ready : cache_valid_array_t;
  
  -- Current PC from each pipeline (для арбитража по приоритету PC)
  SIGNAL p_current_pc : pc_array_t;

  -- ========================================
  -- Control Flow Hazard signals
  -- ========================================
  -- Сигналы о наличии незавершенных управляющих инструкций
  SIGNAL p_control_pending : cache_valid_array_t;
  SIGNAL p_control_pending_pc : pc_array_t;
  -- Сигналы управления конвейерами
  SIGNAL p_flush : cache_valid_array_t;
  SIGNAL p_control_stall : cache_valid_array_t;
  -- Минимальный PC среди всех pending control инструкций
  SIGNAL min_control_pc : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '1');
  -- Флаг наличия хотя бы одной pending control инструкции
  SIGNAL any_control_pending : STD_LOGIC := '0';

  -- ========================================
  -- Arbiter signals (only for cache write operations)
  -- ========================================
  SIGNAL current_write_pipeline : INTEGER RANGE 0 TO NUM_PIPELINES - 1 := 0;

BEGIN

  -- ========================================
  -- PC Controller
  -- ========================================
  pc_controller_inst : ENTITY work.PC_Controller
    GENERIC MAP(
      NUM_PIPELINES => NUM_PIPELINES
    )
    PORT MAP(
      clk => refclk,
      rst => rst,
      stall => pc_stall,
      jump => pc_jump_flag,
      jump_addr => pc_jump_addr,
      pc_out => PC
    );

  -- Distribute PC to pipelines (all use same base PC, each gets its own instruction from 128-bit bus)
  -- Упрощенная схема: все конвейеры получают один PC, но разные инструкции
  pc_distribution : PROCESS (PC)
  BEGIN
    FOR i IN 0 TO NUM_PIPELINES - 1 LOOP
      pc_pipeline(i) <= STD_LOGIC_VECTOR(unsigned(PC) + to_unsigned(i * 4, 12));
    END LOOP;
  END PROCESS pc_distribution;

  -- Передача базового адреса в кэш (выровненный по 16 байт)
  r_cache_address <= PC;
  r_cache_valid <= '1'; -- Всегда запрашиваем данные когда не стоим

  -- Распределение 128-битных данных по 4 конвейерам (32 бита каждому)
  p_r_cache_data(0) <= r_cache_data(31 DOWNTO 0); -- Pipeline 0: PC+0
  p_r_cache_data(1) <= r_cache_data(63 DOWNTO 32); -- Pipeline 1: PC+4
  p_r_cache_data(2) <= r_cache_data(95 DOWNTO 64); -- Pipeline 2: PC+8
  p_r_cache_data(3) <= r_cache_data(127 DOWNTO 96); -- Pipeline 3: PC+12

  -- Combined stall from all pipelines
  pc_stall_proc : PROCESS (pipeline_stall)
    VARIABLE stall_or : STD_LOGIC;
  BEGIN
    stall_or := '0';
    FOR i IN 0 TO NUM_PIPELINES - 1 LOOP
      stall_or := stall_or OR pipeline_stall(i);
    END LOOP;
    pc_stall <= stall_or;
  END PROCESS pc_stall_proc;

  -- Priority jump handler (first pipeline that requests jump wins)
  jump_handler : PROCESS (pipeline_jump_flag, pipeline_jump_addr)
  BEGIN
    pc_jump_flag <= '0';
    pc_jump_addr <= (OTHERS => '0');
    FOR i IN 0 TO NUM_PIPELINES - 1 LOOP
      IF pipeline_jump_flag(i) = '1' THEN
        pc_jump_flag <= '1';
        pc_jump_addr <= pipeline_jump_addr(i);
        EXIT;
      END IF;
    END LOOP;
  END PROCESS jump_handler;

  -- ========================================
  -- Cache Instance
  -- ========================================
  cache_inst : ENTITY work.Cache
    GENERIC MAP(
      cache_size => cache_size,
      read_word_size => 4
    )
    PORT MAP(
      refclk => refclk,
      rst => rst,

      r_address => r_cache_address,
      r_data => r_cache_data,
      r_valid => r_cache_valid,
      r_ready => r_cache_ready,

      w_address => w_cache_address,
      w_data => w_cache_data,
      w_valid => w_cache_valid,
      w_ready => w_cache_ready,

      M_AXI_ARADDR => M_AXI_ARADDR,
      M_AXI_ARLEN => M_AXI_ARLEN,
      M_AXI_ARVALID => M_AXI_ARVALID,
      M_AXI_ARREADY => M_AXI_ARREADY,

      M_AXI_RDATA => M_AXI_RDATA,
      M_AXI_RRESP => M_AXI_RRESP,
      M_AXI_RLAST => M_AXI_RLAST,
      M_AXI_RVALID => M_AXI_RVALID,
      M_AXI_RREADY => M_AXI_RREADY,

      M_AXI_AWADDR => M_AXI_AWADDR,
      M_AXI_AWLEN => M_AXI_AWLEN,
      M_AXI_AWVALID => M_AXI_AWVALID,
      M_AXI_AWREADY => M_AXI_AWREADY,

      M_AXI_WDATA => M_AXI_WDATA,
      M_AXI_WLAST => M_AXI_WLAST,
      M_AXI_WVALID => M_AXI_WVALID,
      M_AXI_WREADY => M_AXI_WREADY,

      M_AXI_BRESP => M_AXI_BRESP,
      M_AXI_BVALID => M_AXI_BVALID,
      M_AXI_BREADY => M_AXI_BREADY
    );
  -- ========================================
  -- Register File Instance (4 read channels, 4 write channels)
  -- ========================================
  registers_inst : ENTITY work.Registers
    PORT MAP(
      refclk => refclk,
      rst => rst,
      -- Pipeline 0
      p0_addr_out_1 => p_reg_addr_out_1(0),
      p0_data_out_1 => p_reg_data_out_1(0),
      p0_addr_out_2 => p_reg_addr_out_2(0),
      p0_data_out_2 => p_reg_data_out_2(0),
      p0_addr_in => p_reg_addr_in(0),
      p0_data_in => p_reg_data_in(0),
      p0_write_en => p_reg_write_enable(0),
      -- Pipeline 1
      p1_addr_out_1 => p_reg_addr_out_1(1),
      p1_data_out_1 => p_reg_data_out_1(1),
      p1_addr_out_2 => p_reg_addr_out_2(1),
      p1_data_out_2 => p_reg_data_out_2(1),
      p1_addr_in => p_reg_addr_in(1),
      p1_data_in => p_reg_data_in(1),
      p1_write_en => p_reg_write_enable(1),
      -- Pipeline 2
      p2_addr_out_1 => p_reg_addr_out_1(2),
      p2_data_out_1 => p_reg_data_out_1(2),
      p2_addr_out_2 => p_reg_addr_out_2(2),
      p2_data_out_2 => p_reg_data_out_2(2),
      p2_addr_in => p_reg_addr_in(2),
      p2_data_in => p_reg_data_in(2),
      p2_write_en => p_reg_write_enable(2),
      -- Pipeline 3
      p3_addr_out_1 => p_reg_addr_out_1(3),
      p3_data_out_1 => p_reg_data_out_1(3),
      p3_addr_out_2 => p_reg_addr_out_2(3),
      p3_data_out_2 => p_reg_data_out_2(3),
      p3_addr_in => p_reg_addr_in(3),
      p3_data_in => p_reg_data_in(3),
      p3_write_en => p_reg_write_enable(3)
    );

  -- ========================================
  -- Cache Write Arbiter (Round-Robin)
  -- ========================================
  cache_write_arbiter : PROCESS (refclk)
    VARIABLE next_pipeline : INTEGER RANGE 0 TO NUM_PIPELINES - 1;
  BEGIN
    IF rising_edge(refclk) THEN
      IF rst = '1' THEN
        current_write_pipeline <= 0;
        FOR i IN 0 TO NUM_PIPELINES - 1 LOOP
          p_w_cache_grant(i) <= '0';
        END LOOP;
      ELSE
        -- Clear all grants
        FOR i IN 0 TO NUM_PIPELINES - 1 LOOP
          p_w_cache_grant(i) <= '0';
        END LOOP;

        -- Find next requesting pipeline (round-robin)
        FOR j IN 0 TO NUM_PIPELINES - 1 LOOP
          next_pipeline := (current_write_pipeline + j) MOD NUM_PIPELINES;
          IF p_w_cache_valid(next_pipeline) = '1' THEN
            p_w_cache_grant(next_pipeline) <= '1';
            current_write_pipeline <= (next_pipeline + 1) MOD NUM_PIPELINES;
            EXIT;
          END IF;
        END LOOP;
      END IF;
    END IF;
  END PROCESS cache_write_arbiter;

  -- Multiplex cache write signals
  cache_write_mux : PROCESS (p_w_cache_address, p_w_cache_data, p_w_cache_valid, p_w_cache_grant)
  BEGIN
    w_cache_address <= (OTHERS => '0');
    w_cache_data <= (OTHERS => '0');
    w_cache_valid <= '0';
    FOR i IN 0 TO NUM_PIPELINES - 1 LOOP
      IF p_w_cache_grant(i) = '1' THEN
        w_cache_address <= p_w_cache_address(i);
        w_cache_data <= p_w_cache_data(i);
        w_cache_valid <= p_w_cache_valid(i);
        EXIT;
      END IF;
    END LOOP;
  END PROCESS cache_write_mux;

  gen_pipelines : FOR i IN 0 TO NUM_PIPELINES - 1 GENERATE
  BEGIN
    pipeline_i : ENTITY work.Pipeline
      GENERIC MAP(
        PIPELINE_ID => i
      )
      PORT MAP(
        refclk => refclk,
        rst => rst,

        pc_in => pc_pipeline(i),
        pc_stall_out => pipeline_stall(i),
        pc_jump_flag => pipeline_jump_flag(i),
        pc_jump_addr => pipeline_jump_addr(i),

        r_cache_data => p_r_cache_data(i),
        r_cache_ready => r_cache_ready,

        w_cache_address => p_w_cache_address(i),
        w_cache_data => p_w_cache_data(i),
        w_cache_valid => p_w_cache_valid(i),
        w_cache_ready => w_cache_ready,
        w_cache_grant => p_w_cache_grant(i),

        reg_addr_out_1 => p_reg_addr_out_1(i),
        reg_data_out_1 => p_reg_data_out_1(i),
        reg_addr_out_2 => p_reg_addr_out_2(i),
        reg_data_out_2 => p_reg_data_out_2(i),

        reg_addr_in => p_reg_addr_in(i),
        reg_data_in => p_reg_data_in(i),
        reg_write_enable => p_reg_write_enable(i),

        reg_grant => p_reg_grant(i),
        reg_grant_valid => p_reg_grant_valid(i),

        pipeline_active => p_active(i),
        pipeline_ready => p_ready(i),
        
        current_pc => p_current_pc(i),
        
        -- Control flow hazard interface
        control_pending => p_control_pending(i),
        control_pending_pc => p_control_pending_pc(i),
        flush => p_flush(i),
        control_stall_in => p_control_stall(i)
      );
  END GENERATE;

  -- ========================================
  -- Control Flow Hazard Management
  -- ========================================
  -- Принцип: любая управляющая инструкция (branch/jump) останавливает
  -- выборку следующих инструкций до её разрешения.
  -- 
  -- Логика:
  -- 1. Находим минимальный PC среди всех pending control инструкций
  -- 2. Все конвейеры с PC > min_control_pc получают control_stall
  -- 3. При jump - конвейеры с PC > min_control_pc получают flush
  
  -- Определяем наличие pending control инструкций и минимальный PC
  control_pending_detect : PROCESS (p_control_pending, p_control_pending_pc)
    VARIABLE min_pc : unsigned(11 DOWNTO 0);
    VARIABLE has_pending : STD_LOGIC;
  BEGIN
    min_pc := (OTHERS => '1'); -- Максимальное значение
    has_pending := '0';
    
    FOR i IN 0 TO NUM_PIPELINES - 1 LOOP
      IF p_control_pending(i) = '1' THEN
        has_pending := '1';
        IF unsigned(p_control_pending_pc(i)) < min_pc THEN
          min_pc := unsigned(p_control_pending_pc(i));
        END IF;
      END IF;
    END LOOP;
    
    any_control_pending <= has_pending;
    min_control_pc <= STD_LOGIC_VECTOR(min_pc);
  END PROCESS control_pending_detect;
  
  -- Управление stall и flush для каждого конвейера
  control_flow_manager : PROCESS (refclk)
    VARIABLE jump_occurred : STD_LOGIC;
    VARIABLE jump_source_pc : unsigned(11 DOWNTO 0);
  BEGIN
    IF rising_edge(refclk) THEN
      IF rst = '1' THEN
        FOR i IN 0 TO NUM_PIPELINES - 1 LOOP
          p_flush(i) <= '0';
          p_control_stall(i) <= '0';
        END LOOP;
      ELSE
        -- По умолчанию сбрасываем flush (он активен только 1 такт)
        FOR i IN 0 TO NUM_PIPELINES - 1 LOOP
          p_flush(i) <= '0';
        END LOOP;
        
        -- Проверяем, произошел ли jump
        jump_occurred := '0';
        jump_source_pc := (OTHERS => '1');
        FOR i IN 0 TO NUM_PIPELINES - 1 LOOP
          IF pipeline_jump_flag(i) = '1' THEN
            jump_occurred := '1';
            IF unsigned(p_control_pending_pc(i)) < jump_source_pc THEN
              jump_source_pc := unsigned(p_control_pending_pc(i));
            END IF;
          END IF;
        END LOOP;
        
        -- Логика для каждого конвейера
        FOR i IN 0 TO NUM_PIPELINES - 1 LOOP
          IF any_control_pending = '1' THEN
            -- Есть pending control инструкция
            IF unsigned(pc_pipeline(i)) > unsigned(min_control_pc) THEN
              -- Этот конвейер имеет PC больше чем control инструкция
              -- Останавливаем выборку новых инструкций
              p_control_stall(i) <= '1';
              
              -- Если произошел jump - сбрасываем этот конвейер
              IF jump_occurred = '1' AND unsigned(pc_pipeline(i)) > jump_source_pc THEN
                p_flush(i) <= '1';
              END IF;
            ELSE
              -- PC меньше или равен control инструкции - можно продолжать
              p_control_stall(i) <= '0';
            END IF;
          ELSE
            -- Нет pending control инструкций - работаем нормально
            p_control_stall(i) <= '0';
          END IF;
        END LOOP;
      END IF;
    END IF;
  END PROCESS control_flow_manager;

  -- ========================================
  -- Register Grant Arbiter (Priority-based by lowest PC, per-register)
  -- Использует реальный PC инструкции из каждого pipeline, а не pc_pipeline
  -- ========================================
  reg_grant_arbiter : PROCESS (p_reg_grant, p_current_pc)
    VARIABLE granted_regs : STD_LOGIC_VECTOR(31 DOWNTO 0);
    VARIABLE grant_mask : STD_LOGIC_VECTOR(31 DOWNTO 0);
    VARIABLE min_pc_idx : INTEGER RANGE 0 TO NUM_PIPELINES - 1;
    VARIABLE min_pc : unsigned(11 DOWNTO 0);
    VARIABLE curr_pc : unsigned(11 DOWNTO 0);
    VARIABLE processed : STD_LOGIC_VECTOR(NUM_PIPELINES - 1 DOWNTO 0);
  BEGIN
    granted_regs := (OTHERS => '0');
    p_reg_grant_valid <= (OTHERS => (OTHERS => '0'));
    processed := (OTHERS => '0');

    -- Обрабатываем конвейеры в порядке возрастания PC (наименьший PC = наивысший приоритет)
    -- Используем p_current_pc - реальный PC инструкции внутри каждого pipeline
    FOR round IN 0 TO NUM_PIPELINES - 1 LOOP
      -- Находим конвейер с минимальным PC среди необработанных
      min_pc := (OTHERS => '1'); -- Максимальное значение
      min_pc_idx := 0;
      
      FOR i IN 0 TO NUM_PIPELINES - 1 LOOP
        IF processed(i) = '0' THEN
          curr_pc := unsigned(p_current_pc(i));
          IF curr_pc < min_pc THEN
            min_pc := curr_pc;
            min_pc_idx := i;
          END IF;
        END IF;
      END LOOP;

      -- Отмечаем конвейер как обработанный
      processed(min_pc_idx) := '1';

      -- Разрешаем только те регистры, которые еще не выданы
      grant_mask := p_reg_grant(min_pc_idx) AND NOT granted_regs;

      -- Выдаём grant только на неконфликтные регистры
      p_reg_grant_valid(min_pc_idx) <= grant_mask;

      -- Обновляем глобальную маску выданных регистров
      granted_regs := granted_regs OR grant_mask;
    END LOOP;
  END PROCESS reg_grant_arbiter;

END ARCHITECTURE rtl;