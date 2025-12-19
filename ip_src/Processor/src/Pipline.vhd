LIBRARY IEEE;--! standard library IEEE (Institute of Electrical and Electronics Engineers)
USE IEEE.std_logic_1164.ALL;--! standard unresolved logic UX01ZWLH-
USE IEEE.numeric_std.ALL;--! for the signed, unsigned types and arithmetic ops
USE work.control_signals_pkg.ALL;
USE work.riscv_opcodes_pkg.ALL;

-- -- -- -- Задача блока: -- -- -- --
-- 1. Реализация конвейера для RISC-V процессора
-- 2. Ступени: Fetch, Decode, Execute, Writeback
-- 3. Управление зависимостями данных
------------------------------------

ENTITY Pipeline IS
    GENERIC (
        PIPELINE_ID : INTEGER := 0 -- Идентификатор конвейера (0-3)
    );
    PORT (
        refclk : IN STD_LOGIC;--! reference clock expect 250Mhz
        rst : IN STD_LOGIC; --! sync active high reset. sync -> refclk

        -- PC Interface
        pc_in : IN STD_LOGIC_VECTOR(11 DOWNTO 0); -- Текущий PC от арбитра
        pc_stall_out : OUT STD_LOGIC; -- Запрос на остановку PC
        pc_jump_flag : OUT STD_LOGIC; -- Флаг перехода
        pc_jump_addr : OUT STD_LOGIC_VECTOR(11 DOWNTO 0); -- Адрес перехода

        -- Cache Read Interface (simplified - data comes directly from Core)
        -- Данные поступают напрямую из 128-битной шины, разделенной в Core
        r_cache_data : IN STD_LOGIC_VECTOR(31 DOWNTO 0); -- Инструкция для этого конвейера
        r_cache_ready : IN STD_LOGIC; -- Кэш готов

        -- Cache Write Interface
        w_cache_address : OUT STD_LOGIC_VECTOR(11 DOWNTO 0); -- Адрес для записи в кэш
        w_cache_data : OUT STD_LOGIC_VECTOR(7 DOWNTO 0); -- Данные для записи
        w_cache_valid : OUT STD_LOGIC; -- Запрос на запись
        w_cache_ready : IN STD_LOGIC; -- Запись завершена
        w_cache_grant : IN STD_LOGIC; -- Арбитр предоставил доступ к записи

        -- Register Read Interface (для декодера) - прямое подключение
        reg_addr_out_1 : OUT STD_LOGIC_VECTOR(4 DOWNTO 0); -- Адрес регистра rs1
        reg_data_out_1 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); -- Данные регистра rs1
        reg_addr_out_2 : OUT STD_LOGIC_VECTOR(4 DOWNTO 0); -- Адрес регистра rs2
        reg_data_out_2 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); -- Данные регистра rs2

        -- Register Write Interface (для записи результата) - прямое подключение
        reg_addr_in : OUT STD_LOGIC_VECTOR(4 DOWNTO 0); -- Адрес регистра для записи
        reg_data_in : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); -- Данные для записи
        reg_write_enable : OUT STD_LOGIC; -- Разрешение записи

        reg_grant : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); -- Какие регистры запрошены данным конвеейром
        reg_grant_valid : IN STD_LOGIC_VECTOR(31 DOWNTO 0); -- Право на использование регистров получено (от арбитра)

        -- Pipeline status
        pipeline_active : OUT STD_LOGIC; -- Конвейер активен
        pipeline_ready : OUT STD_LOGIC; -- Конвейер готов принять инструкцию
        
        -- Current instruction PC (для арбитража по приоритету PC)
        current_pc : OUT STD_LOGIC_VECTOR(11 DOWNTO 0); -- PC текущей инструкции в конвейере
        
        -- Control flow hazard interface
        control_pending : OUT STD_LOGIC; -- Есть незавершенная branch/jump инструкция
        control_pending_pc : OUT STD_LOGIC_VECTOR(11 DOWNTO 0); -- PC управляющей инструкции
        flush : IN STD_LOGIC; -- Сброс конвейера (от Core при неверном пути)
        control_stall_in : IN STD_LOGIC -- Остановка выборки из-за ожидания control инструкции
    );
END ENTITY Pipeline;

ARCHITECTURE rtl OF Pipeline IS

    -- Состояния конвейера (simplified - no grant needed for instruction fetch)
    TYPE fetch_state_t IS (RESET, IDLE, FAST_FETCH, WAIT_RESPONSE);
    TYPE execution_state_t IS (RESET, IDLE, EXECUTE, WAIT_RESULT, WAIT_READ_GRANT, WAIT_REG_WRITE);

    SIGNAL fetch_state : fetch_state_t := RESET;
    SIGNAL execution_state : execution_state_t := RESET;

    -- Pipeline registers (между ступенями)
    -- Fetch -> Decode
    SIGNAL fd_instruction : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL fd_pc : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
    SIGNAL fd_valid : STD_LOGIC := '0';

    -- Decode -> Execute
    SIGNAL de_control : control_signals_t;
    SIGNAL de_rs1_addr : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    SIGNAL de_rs2_addr : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    SIGNAL de_rd_addr : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    SIGNAL de_imm : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL de_pc : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
    SIGNAL de_valid : STD_LOGIC := '0';

    SIGNAL rs1_data : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL rs2_data : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');

    -- Execute -> Writeback
    SIGNAL ew_result : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL ew_rd_addr : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    SIGNAL ew_reg_write : STD_LOGIC := '0';
    SIGNAL ew_valid : STD_LOGIC := '0';
    SIGNAL ew_pc : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0'); -- PC инструкции в execute/writeback

    -- Stall signals
    SIGNAL stall_fetch : STD_LOGIC := '0';
    SIGNAL stall_decode : STD_LOGIC := '0';
    SIGNAL stall_execute : STD_LOGIC := '0';
    
    -- Флаг: инструкция из decode принята в execute (предотвращает повторную обработку)
    SIGNAL de_consumed : STD_LOGIC := '0';

    -- ALU signals
    SIGNAL alu_opcode : riscv_opcode_t;
    SIGNAL alu_operand_1 : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL alu_operand_2 : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL alu_result : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL alu_zero : STD_LOGIC := '0';
    SIGNAL alu_sign : STD_LOGIC := '0';
    SIGNAL alu_enable : STD_LOGIC := '0';

    -- Control Unit signals
    SIGNAL cu_rs1 : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL cu_rs2 : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL cu_imm : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL cu_pc_in : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL cu_pc_out : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL cu_enable : STD_LOGIC := '0';
    SIGNAL cu_jump : STD_LOGIC := '0';

    -- Decoder signals
    SIGNAL decoder_instruction : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL decoder_rs1_addr : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    SIGNAL decoder_rs2_addr : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    SIGNAL decoder_rd_addr : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    SIGNAL decoder_imm : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL decoder_control : control_signals_t;

    -- Stalled instruction info (сохраняем информацию когда инструкция в stall)
    SIGNAL stalled_rd_addr : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    SIGNAL stalled_reg_write : STD_LOGIC := '0';
    SIGNAL stalled_rs1_addr : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    SIGNAL stalled_rs2_addr : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');

    -- Internal write cache signals
    SIGNAL w_cache_address_i : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
    SIGNAL w_cache_data_i : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL w_cache_valid_i : STD_LOGIC := '0';

    -- ========================================
    -- DECODE STAGE
    -- ========================================

    -- Forwarding enable signals - флаги пересылки данных из execute/writeback стадий
    SIGNAL fwd_rs1_enable : STD_LOGIC := '0';
    SIGNAL fwd_rs2_enable : STD_LOGIC := '0';

    -- Register grant management signals
    SIGNAL reg_grant_i : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); -- Внутренний сигнал запроса
    SIGNAL reg_grant_valid_i : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); -- Внутренний сигнал права
    SIGNAL decode_rs1_grant : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); -- Grant для rs1 (чтение)
    SIGNAL decode_rs2_grant : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); -- Grant для rs2 (чтение)
    SIGNAL decode_rd_grant : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); -- Grant для rd (запись)
    SIGNAL execute_rd_grant : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); -- Grant для rd в execute стадии

    -- Grant validation signals
    SIGNAL read_grant_ok : STD_LOGIC := '0'; -- Получен grant на чтение (rs1, rs2)
    SIGNAL write_grant_ok : STD_LOGIC := '0'; -- Получен grant на запись (rd)
    
    -- ========================================
    -- Control flow hazard signals
    -- ========================================
    -- Флаг наличия незавершенной управляющей инструкции (branch/jump) в конвейере
    SIGNAL control_pending_i : STD_LOGIC := '0';
    -- PC управляющей инструкции (для определения приоритета)
    SIGNAL control_pending_pc_i : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
    -- Управляющая инструкция разрешена (jump выполнен или branch не взят)
    SIGNAL control_resolved : STD_LOGIC := '0';
    SIGNAL stall_write : STD_LOGIC := '0'; -- Stall из-за отсутствия grant
    SIGNAL stall_read : STD_LOGIC := '0'; -- Stall из-за отсутствия grant

BEGIN
    -- Читаем данные регистров
    rs1_data <= reg_data_out_1;
    rs2_data <= reg_data_out_2;

    -- Инстанцирование декодера
    decoder_inst : ENTITY work.Decoder
        PORT MAP(
            clk => refclk,
            rst => rst,

            instruction => decoder_instruction,

            rs1_addr => decoder_rs1_addr,
            rs2_addr => decoder_rs2_addr,
            rd_addr => decoder_rd_addr,
            imm => decoder_imm,
            control => decoder_control
        );

    -- Инстанцирование ALU
    alu_inst : ENTITY work.ALU
        PORT MAP(
            refclk => refclk,
            rst => rst,
            opcode => alu_opcode,
            operand_1 => alu_operand_1,
            operand_2 => alu_operand_2,
            result => alu_result,
            zero => alu_zero,
            sign => alu_sign,
            enable => alu_enable
        );

    -- Инстанцирование Control Unit
    control_unit_inst : ENTITY work.ControlUnit
        PORT MAP(
            refclk => refclk,
            rst => rst,
            opcode => alu_opcode,
            rs1 => cu_rs1,
            rs2 => cu_rs2,
            imm => cu_imm,
            enable => cu_enable,
            pc_in => cu_pc_in,
            pc_out => cu_pc_out,
            jump => cu_jump
        );

    -- Общий stall
    pc_stall_out <= stall_fetch OR stall_decode OR stall_execute;

    -- Register grant outputs
    reg_grant <= reg_grant_i;
    -- reg_grant_valid is now an INPUT from arbiter
    reg_grant_valid_i <= reg_grant_valid;

    reg_addr_out_1 <= decoder_rs1_addr;
    reg_addr_out_2 <= decoder_rs2_addr;

    -- ========================================
    -- GRANT VALIDATION LOGIC
    -- ========================================
    -- Проверяем, получены ли гранты на запрошенные регистры
    grant_check_proc : PROCESS (decode_rs1_grant, decode_rs2_grant, decode_rd_grant,
        execute_rd_grant, reg_grant_valid_i)
        VARIABLE requested_regs : STD_LOGIC_VECTOR(31 DOWNTO 0);
        VARIABLE granted_regs : STD_LOGIC_VECTOR(31 DOWNTO 0);
        VARIABLE read_regs : STD_LOGIC_VECTOR(31 DOWNTO 0);
        VARIABLE write_regs : STD_LOGIC_VECTOR(31 DOWNTO 0);
    BEGIN
        -- Регистры для чтения (rs1, rs2 в decode)
        read_regs := decode_rs1_grant OR decode_rs2_grant;

        -- Регистры для записи (rd в execute/writeback)
        write_regs := execute_rd_grant;

        -- Проверяем grant для чтения: (requested AND valid) = requested
        IF read_regs = (read_regs'RANGE => '0') THEN
            -- Нет запросов на чтение - OK
            read_grant_ok <= '1';
        ELSIF (read_regs AND reg_grant_valid_i) = read_regs THEN
            -- Все запрошенные регистры для чтения получили grant
            read_grant_ok <= '1';
        ELSE
            read_grant_ok <= '0';
        END IF;

        -- Проверяем grant для записи: (requested AND valid) = requested
        IF write_regs = (write_regs'RANGE => '0') THEN
            -- Нет запросов на запись - OK
            write_grant_ok <= '1';
        ELSIF (write_regs AND reg_grant_valid_i) = write_regs THEN
            -- Регистр для записи получил grant
            write_grant_ok <= '1';
        ELSE
            write_grant_ok <= '0';
        END IF;

    END PROCESS grant_check_proc;

    -- Выходы для арбитра hazard и forwarding
    -- Разделяем на два набора сигналов:
    -- 1. decode stage - инструкция декодирована/pending, но данные ещё НЕ готовы
    -- 2. execute/writeback stage - данные готовы для forwarding

    -- Pipeline status (simplified - no grant needed for reading)
    pipeline_active <= fd_valid OR de_valid OR ew_valid;
    pipeline_ready <= NOT stall_fetch AND r_cache_ready;
    
    -- Выдаём PC инструкции, которая АКТИВНО держит регистры (запрашивает grant)
    -- Приоритет: execute/writeback (если держит rd) > decode (если держит rs1/rs2/rd) > fetch
    -- Это важно для корректного арбитража: PC должен соответствовать инструкции с reg_grant
    current_pc <= ew_pc WHEN (execute_rd_grant /= x"00000000") ELSE
                  de_pc WHEN (de_valid = '1' AND (decode_rs1_grant /= x"00000000" OR 
                                                  decode_rs2_grant /= x"00000000" OR 
                                                  decode_rd_grant /= x"00000000")) ELSE
                  fd_pc WHEN fd_valid = '1' ELSE
                  pc_in;

    -- ========================================
    -- Control Flow Hazard Detection
    -- ========================================
    -- Сигнализируем о наличии незавершенной управляющей инструкции
    -- control_pending активен пока branch/jump не разрешен
    control_pending <= control_pending_i;
    control_pending_pc <= control_pending_pc_i;

    -- Cache outputs (only write needs address/valid)
    w_cache_address <= w_cache_address_i;
    w_cache_data <= w_cache_data_i;
    w_cache_valid <= w_cache_valid_i;

    -- ========================================
    -- FETCH STAGE (Simplified - data comes directly, no arbitration)
    -- ========================================
    fetch_state_proc : PROCESS (refclk)
    BEGIN
        IF rising_edge(refclk) THEN
            IF rst = '1' THEN
                fetch_state <= RESET;
            ELSE
                CASE fetch_state IS
                    WHEN RESET =>
                        fetch_state <= IDLE;

                    WHEN IDLE =>
                        -- Данные поступают напрямую, ждем только ready
                        IF r_cache_ready = '1' THEN
                            fetch_state <= FAST_FETCH;
                        ELSE
                            fetch_state <= WAIT_RESPONSE;
                        END IF;

                    WHEN FAST_FETCH =>
                        IF r_cache_ready = '0' THEN
                            fetch_state <= WAIT_RESPONSE;
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

    fetch_output_proc : PROCESS (refclk)
    BEGIN
        IF rising_edge(refclk) THEN
            IF rst = '1' THEN
                fd_instruction <= (OTHERS => '0');
                fd_pc <= (OTHERS => '0');
                fd_valid <= '0';
                stall_fetch <= '1';
            ELSIF flush = '1' THEN
                -- Сброс конвейера при неверном пути выполнения
                fd_instruction <= (OTHERS => '0');
                fd_pc <= (OTHERS => '0');
                fd_valid <= '0';
                stall_fetch <= '0';
            ELSIF control_stall_in = '1' THEN
                -- Остановка выборки из-за ожидания разрешения control инструкции
                -- Не загружаем новую инструкцию, но сохраняем текущую
                stall_fetch <= '1';
            ELSIF stall_decode = '1' OR stall_execute = '1' THEN
                -- Удерживаем текущие значения когда downstream в stall
                -- fd_instruction, fd_pc сохраняют свои значения автоматически (регистры)
                stall_fetch <= '1';
            ELSE
                CASE fetch_state IS
                    WHEN IDLE =>
                        fd_valid <= '0';
                        stall_fetch <= '1';

                    WHEN FAST_FETCH =>
                        -- Данные готовы - забираем напрямую
                        IF r_cache_ready = '1' THEN
                            fd_instruction <= r_cache_data;
                            fd_pc <= pc_in;
                            fd_valid <= '1';
                            stall_fetch <= '0';
                        ELSE
                            fd_instruction <= (OTHERS => '0');
                            fd_valid <= '0';
                            stall_fetch <= '1';
                        END IF;

                    WHEN WAIT_RESPONSE =>
                        stall_fetch <= '1';
                        IF r_cache_ready = '1' THEN
                            fd_instruction <= r_cache_data;
                            fd_pc <= pc_in;
                            fd_valid <= '1';
                            stall_fetch <= '0';
                        ELSE
                            fd_valid <= '0';
                        END IF;

                    WHEN OTHERS =>
                        fd_instruction <= (OTHERS => '0');
                        fd_pc <= (OTHERS => '0');
                        fd_valid <= '0';
                        stall_fetch <= '1';
                END CASE;
            END IF;
        END IF;
    END PROCESS fetch_output_proc;

    -- Комбинационная логика: передача инструкции в декодер
    -- Декодер работает комбинационно, поэтому входную инструкцию подаём напрямую
    decoder_instruction <= fd_instruction;

    decode_proc : PROCESS (refclk)
    BEGIN
        IF rising_edge(refclk) THEN
            IF rst = '1' THEN
                de_control <= INVALID_CONTROL;
                de_rs1_addr <= (OTHERS => '0');
                de_rs2_addr <= (OTHERS => '0');
                de_rd_addr <= (OTHERS => '0');
                de_imm <= (OTHERS => '0');
                de_pc <= (OTHERS => '0');
                de_valid <= '0';
                stall_decode <= '0';
                stalled_rd_addr <= (OTHERS => '0');
                stalled_reg_write <= '0';
                stalled_rs1_addr <= (OTHERS => '0');
                stalled_rs2_addr <= (OTHERS => '0');
                control_pending_i <= '0';
                control_pending_pc_i <= (OTHERS => '0');
            ELSIF flush = '1' THEN
                -- Сброс decode стадии при неверном пути
                de_control <= INVALID_CONTROL;
                de_rs1_addr <= (OTHERS => '0');
                de_rs2_addr <= (OTHERS => '0');
                de_rd_addr <= (OTHERS => '0');
                de_imm <= (OTHERS => '0');
                de_pc <= (OTHERS => '0');
                de_valid <= '0';
                stall_decode <= '0';
                control_pending_i <= '0';
                control_pending_pc_i <= (OTHERS => '0');
            ELSIF stall_execute = '1' THEN
                -- Удерживаем текущие значения когда execute в stall
                -- de_valid уже был установлен, не сбрасываем
                stall_decode <= '1';
            ELSE
                -- Сбрасываем de_valid по умолчанию
                de_valid <= '0';
                stall_decode <= '0';

                IF fd_valid = '1' THEN
                    -- Новая инструкция пришла на декодирование
                    -- Декодер уже обработал fd_instruction (комбинационно)
                    -- Захватываем результаты декодирования
                    de_control <= decoder_control;
                    de_rs1_addr <= decoder_rs1_addr;
                    de_rs2_addr <= decoder_rs2_addr;
                    de_rd_addr <= decoder_rd_addr;
                    de_imm <= decoder_imm;
                    de_pc <= fd_pc;

                    -- Сохраняем информацию о регистрах для grant management
                    stalled_rs1_addr <= decoder_rs1_addr;
                    stalled_rs2_addr <= decoder_rs2_addr;
                    stalled_rd_addr <= decoder_rd_addr;
                    stalled_reg_write <= decoder_control.reg_write;

                    -- Инструкция декодирована и готова к исполнению
                    de_valid <= '1';
                    
                    -- Детектирование управляющих инструкций (branch/jump)
                    IF decoder_control.branch = '1' OR decoder_control.jump = '1' THEN
                        control_pending_i <= '1';
                        control_pending_pc_i <= fd_pc;
                    END IF;
                END IF;
                
                -- Сброс control_pending когда jump разрешен
                IF control_resolved = '1' THEN
                    control_pending_i <= '0';
                    control_pending_pc_i <= (OTHERS => '0');
                END IF;
            END IF;
        END IF;
    END PROCESS decode_proc;

    -- ========================================
    -- REGISTER GRANT MANAGEMENT PROCESS
    -- ========================================
    -- Управление запросами на регистры:
    -- 1. Во время декодирования запрашиваем grant на rs1, rs2 (чтение) и rd (запись)
    -- 2. После перехода данных в execute снимаем grant с rs1, rs2
    -- 3. После завершения записи в регистр снимаем grant с rd

    reg_grant_proc : PROCESS (refclk)
        VARIABLE rs1_bit : INTEGER RANGE 0 TO 31;
        VARIABLE rs2_bit : INTEGER RANGE 0 TO 31;
        VARIABLE rd_bit : INTEGER RANGE 0 TO 31;
        VARIABLE use_rs1 : STD_LOGIC;
        VARIABLE use_rs2 : STD_LOGIC;
        VARIABLE new_rs1_grant : STD_LOGIC_VECTOR(31 DOWNTO 0);
        VARIABLE new_rs2_grant : STD_LOGIC_VECTOR(31 DOWNTO 0);
        VARIABLE new_rd_grant : STD_LOGIC_VECTOR(31 DOWNTO 0);
        VARIABLE new_exec_rd_grant : STD_LOGIC_VECTOR(31 DOWNTO 0);
    BEGIN
        IF rising_edge(refclk) THEN
            IF rst = '1' THEN
                reg_grant_i <= (OTHERS => '0');
                decode_rs1_grant <= (OTHERS => '0');
                decode_rs2_grant <= (OTHERS => '0');
                decode_rd_grant <= (OTHERS => '0');
                execute_rd_grant <= (OTHERS => '0');
            ELSE
                -- Инициализация переменных текущими значениями сигналов
                new_rs1_grant := decode_rs1_grant;
                new_rs2_grant := decode_rs2_grant;
                new_rd_grant := decode_rd_grant;
                new_exec_rd_grant := execute_rd_grant;

                -- ==============================================
                -- ЭТАП 3: Снятие grant с rd после завершения записи
                -- ВАЖНО: снимаем grant только когда запись реально выполнена
                -- ==============================================
                IF ew_valid = '1' AND write_grant_ok = '1' THEN
                    -- Запись в регистр выполняется в этом такте
                    new_exec_rd_grant := (OTHERS => '0');
                END IF;

                -- ==============================================
                -- ЭТАП 2: Переход из decode в execute
                -- Проверяем ПОСЛЕ этапа 3, чтобы избежать конфликта
                -- ==============================================
                IF de_valid = '1' AND stall_execute = '0' AND execution_state = IDLE THEN
                    -- Данные из регистров считаны и перешли в execute
                    -- Снимаем grant с rs1 и rs2
                    new_rs1_grant := (OTHERS => '0');
                    new_rs2_grant := (OTHERS => '0');

                    -- Передаем rd grant в execute стадию (только если есть запись)
                    -- Используем текущее значение decode_rd_grant (сигнал с предыдущего такта)
                    IF de_control.reg_write = '1' THEN
                        new_exec_rd_grant := decode_rd_grant;
                    END IF;
                    new_rd_grant := (OTHERS => '0');
                END IF;

                -- ==============================================
                -- ЭТАП 1: Запрос grant во время декодирования
                -- Выполняется ПОСЛЕДНИМ и перезаписывает значения если нужно
                -- ==============================================
                IF fd_valid = '1' AND stall_decode = '0' AND stall_execute = '0' THEN
                    -- Новая инструкция пришла на декодирование
                    -- Определяем использование rs1/rs2 на основе типа инструкции

                    CASE decoder_control.imm_type IS
                        WHEN IMM_U_TYPE =>
                            use_rs1 := '0';
                            use_rs2 := '0';
                        WHEN IMM_J_TYPE =>
                            use_rs1 := '0';
                            use_rs2 := '0';
                        WHEN IMM_I_TYPE =>
                            use_rs1 := '1';
                            use_rs2 := '0';
                        WHEN IMM_S_TYPE =>
                            use_rs1 := '1';
                            use_rs2 := '1';
                        WHEN IMM_B_TYPE =>
                            use_rs1 := '1';
                            use_rs2 := '1';
                        WHEN IMM_R_TYPE =>
                            use_rs1 := '1';
                            use_rs2 := '1';
                        WHEN OTHERS =>
                            use_rs1 := '0';
                            use_rs2 := '0';
                    END CASE;

                    -- Запрашиваем grant для rs1 (если используется)
                    IF use_rs1 = '1' AND decoder_rs1_addr /= "00000" THEN
                        rs1_bit := to_integer(unsigned(decoder_rs1_addr));
                        new_rs1_grant := (OTHERS => '0');
                        new_rs1_grant(rs1_bit) := '1';
                    ELSE
                        new_rs1_grant := (OTHERS => '0');
                    END IF;

                    -- Запрашиваем grant для rs2 (если используется)
                    IF use_rs2 = '1' AND decoder_rs2_addr /= "00000" THEN
                        rs2_bit := to_integer(unsigned(decoder_rs2_addr));
                        new_rs2_grant := (OTHERS => '0');
                        new_rs2_grant(rs2_bit) := '1';
                    ELSE
                        new_rs2_grant := (OTHERS => '0');
                    END IF;

                    -- Запрашиваем grant для rd (если будет запись)
                    IF decoder_control.reg_write = '1' AND decoder_rd_addr /= "00000" THEN
                        rd_bit := to_integer(unsigned(decoder_rd_addr));
                        new_rd_grant := (OTHERS => '0');
                        new_rd_grant(rd_bit) := '1';
                    ELSE
                        new_rd_grant := (OTHERS => '0');
                    END IF;

                    -- При stall сохраняем текущие гранты (не сбрасываем)
                ELSIF stall_decode = '1' THEN
                    -- Удерживаем текущие значения - ничего не меняем
                    NULL;
                END IF;

                -- Применяем все новые значения к сигналам
                decode_rs1_grant <= new_rs1_grant;
                decode_rs2_grant <= new_rs2_grant;
                decode_rd_grant <= new_rd_grant;
                execute_rd_grant <= new_exec_rd_grant;

                -- ==============================================
                -- Формирование итогового reg_grant
                -- Используем переменные для актуальных значений
                -- ==============================================
                reg_grant_i <= new_rs1_grant OR new_rs2_grant OR new_rd_grant OR new_exec_rd_grant;

            END IF;
        END IF;
    END PROCESS reg_grant_proc;

    -- ========================================
    -- EXECUTE STAGE
    -- ========================================    
    execute_state_proc : PROCESS (refclk)
    BEGIN
        IF rising_edge(refclk) THEN
            IF rst = '1' THEN
                execution_state <= RESET;
                ew_result <= (OTHERS => '0');
                ew_rd_addr <= (OTHERS => '0');
                ew_reg_write <= '0';
                ew_valid <= '0';
                ew_pc <= (OTHERS => '0');
                de_consumed <= '0';
            ELSE
                -- Default: сбрасываем ew_valid после одного такта
                ew_valid <= '0';

                CASE execution_state IS
                    WHEN RESET =>
                        execution_state <= IDLE;
                        ew_reg_write <= '0';
                        de_consumed <= '0';

                    WHEN IDLE =>
                        IF de_valid = '1' AND de_consumed = '0' THEN
                            -- Принимаем новую инструкцию - сохраняем все данные ОДИН раз
                            de_consumed <= '1';
                            ew_pc <= de_pc;
                            ew_rd_addr <= de_rd_addr;
                            -- Запоминаем нужна ли запись в регистр (только для не-mem_write инструкций)
                            IF de_control.mem_write = '1' THEN
                                ew_reg_write <= '0';
                            ELSE
                                ew_reg_write <= de_control.reg_write;
                            END IF;
                            
                            -- Определяем следующее состояние
                            IF read_grant_ok = '0' THEN
                                -- Нет grant на чтение - ждём
                                execution_state <= WAIT_READ_GRANT;
                            ELSIF de_control.mem_write = '1' THEN
                                IF w_cache_grant = '1' THEN
                                    execution_state <= WAIT_RESULT;
                                ELSE
                                    execution_state <= WAIT_READ_GRANT;
                                END IF;
                            ELSE
                                execution_state <= EXECUTE;
                            END IF;
                        ELSE
                            -- Сбрасываем de_consumed когда de_valid сбросился (новая инструкция может прийти)
                            IF de_valid = '0' THEN
                                de_consumed <= '0';
                            END IF;
                        END IF;

                    WHEN EXECUTE =>
                        -- Результат ALU готов
                        ew_result <= alu_result;
                        
                        -- Если нужна запись в регистр - переходим в WAIT_REG_WRITE
                        IF ew_reg_write = '1' THEN
                            execution_state <= WAIT_REG_WRITE;
                            ew_valid <= '1'; -- Сигнализируем о готовности к записи
                        ELSE
                            -- Запись не требуется - сразу в IDLE
                            execution_state <= IDLE;
                            de_consumed <= '0';
                        END IF;

                    WHEN WAIT_REG_WRITE =>
                        -- Ждём пока запись в регистр будет выполнена
                        IF write_grant_ok = '1' THEN
                            -- Запись выполнена - переходим в IDLE
                            execution_state <= IDLE;
                            de_consumed <= '0';
                            ew_reg_write <= '0';
                        ELSE
                            -- Продолжаем держать ew_valid для writeback
                            ew_valid <= '1';
                        END IF;

                    WHEN WAIT_READ_GRANT =>
                        IF read_grant_ok = '1' THEN
                            IF de_control.mem_write = '1' THEN
                                IF w_cache_grant = '1' THEN
                                    execution_state <= WAIT_RESULT;
                                ELSE
                                    -- Продолжаем ждать grant на запись в кэш
                                    execution_state <= WAIT_READ_GRANT;
                                END IF;
                            ELSE
                                -- Grant получен - переходим к выполнению
                                -- ew_rd_addr и ew_reg_write уже сохранены в IDLE
                                execution_state <= EXECUTE;
                            END IF;
                        END IF;

                    WHEN WAIT_RESULT =>
                        IF w_cache_ready = '1' THEN
                            execution_state <= IDLE;
                            de_consumed <= '0';
                        END IF;

                    WHEN OTHERS =>
                        execution_state <= IDLE;
                        ew_reg_write <= '0';
                        de_consumed <= '0';
                END CASE;
            END IF;
        END IF;
    END PROCESS execute_state_proc;

    execute_output_proc : PROCESS (rst, de_valid, de_control, rs1_data, rs2_data, de_imm,
        de_rd_addr, de_pc, execution_state,
        alu_result, cu_jump, cu_pc_out, w_cache_grant, w_cache_ready, read_grant_ok)
    BEGIN
        IF rst = '1' THEN
            alu_opcode <= OP_INVALID;
            alu_operand_1 <= (OTHERS => '0');
            alu_operand_2 <= (OTHERS => '0');
            alu_enable <= '0';
            cu_rs1 <= (OTHERS => '0');
            cu_rs2 <= (OTHERS => '0');
            cu_imm <= (OTHERS => '0');
            cu_pc_in <= (OTHERS => '0');
            cu_enable <= '0';
            w_cache_address_i <= (OTHERS => '0');
            w_cache_data_i <= (OTHERS => '0');
            w_cache_valid_i <= '0';
            pc_jump_flag <= '0';
            pc_jump_addr <= (OTHERS => '0');
            stall_execute <= '0';
            control_resolved <= '0';

        ELSIF read_grant_ok = '0' THEN
            -- Stall из-за отсутствия grant на чтение
            stall_execute <= '1';
            control_resolved <= '0';
        ELSE
            -- Default values
            alu_enable <= '0';
            cu_enable <= '0';
            w_cache_valid_i <= '0';
            pc_jump_flag <= '0';
            stall_execute <= '0';
            control_resolved <= '0';

            CASE execution_state IS
                WHEN IDLE =>
                    alu_enable <= '0';
                    cu_enable <= '0';
                    w_cache_valid_i <= '0';
                    pc_jump_flag <= '0';
                    stall_execute <= '0';
                WHEN EXECUTE =>
                    IF de_valid = '1' THEN
                        alu_opcode <= de_control.opcode;

                        IF de_control.alu_en = '1' THEN
                            -- ALU operation
                            alu_operand_1 <= rs1_data;
                            IF de_control.imm_type = IMM_I_TYPE OR de_control.imm_type = IMM_U_TYPE THEN
                                alu_operand_2 <= de_imm;
                            ELSE
                                alu_operand_2 <= rs2_data;
                            END IF;
                            alu_enable <= '1';

                        ELSIF de_control.branch = '1' OR de_control.jump = '1' THEN
                            -- Branch/Jump operation
                            cu_pc_in <= STD_LOGIC_VECTOR(resize(unsigned(de_pc) - 2 * 4, 32));
                            cu_rs1 <= rs1_data;
                            cu_rs2 <= rs2_data;
                            cu_imm <= de_imm;
                            cu_enable <= '1';

                            IF cu_jump = '1' THEN
                                pc_jump_addr <= cu_pc_out(11 DOWNTO 0);
                                pc_jump_flag <= '1';
                            END IF;
                            
                            -- Сигнализируем что control инструкция разрешена
                            control_resolved <= '1';

                        ELSIF de_control.mem_write = '1' THEN
                            -- Memory write
                            w_cache_address_i <= de_imm(11 DOWNTO 0);
                            w_cache_data_i <= rs2_data(7 DOWNTO 0);
                            w_cache_valid_i <= w_cache_grant;
                            stall_execute <= '1';
                        END IF;
                    END IF;

                WHEN WAIT_READ_GRANT =>
                    w_cache_address_i <= de_imm(11 DOWNTO 0);
                    w_cache_data_i <= rs2_data(7 DOWNTO 0);
                    w_cache_valid_i <= w_cache_grant;
                    stall_execute <= '1';

                WHEN WAIT_RESULT =>
                    stall_execute <= '1';
                    IF w_cache_ready = '1' THEN
                        stall_execute <= '0';
                    END IF;

                WHEN WAIT_REG_WRITE =>
                    -- Ждём запись в регистр - ставим stall
                    stall_execute <= '1';
                    IF write_grant_ok = '1' THEN
                        stall_execute <= '0';
                    END IF;

                WHEN OTHERS =>
                    stall_execute <= '0';
            END CASE;
        END IF;
    END PROCESS execute_output_proc;

    -- ========================================
    -- WRITEBACK STAGE
    -- ========================================
    -- Pipeline имеет прямой доступ к регистрам - запись выполняется напрямую
    -- Синхронный процесс для предотвращения гонок

    writeback_proc : PROCESS (refclk)
    BEGIN
        IF rising_edge(refclk) THEN
            IF rst = '1' THEN
                reg_addr_in <= (OTHERS => '0');
                reg_data_in <= (OTHERS => '0');
                reg_write_enable <= '0';
            ELSIF ew_valid = '1' THEN
                -- Проверяем grant на запись
                IF write_grant_ok = '1' THEN
                    -- Grant получен - выполняем запись
                    reg_addr_in <= ew_rd_addr;
                    reg_data_in <= ew_result;
                    reg_write_enable <= '1';
                ELSE
                    -- Grant не получен - не пишем (данные сохраняются в ew_*)
                    reg_addr_in <= (OTHERS => '0');
                    reg_data_in <= (OTHERS => '0');
                    reg_write_enable <= '0';
                END IF;
            ELSE
                reg_addr_in <= (OTHERS => '0');
                reg_data_in <= (OTHERS => '0');
                reg_write_enable <= '0';
            END IF;
        END IF;
    END PROCESS writeback_proc;

END ARCHITECTURE rtl;