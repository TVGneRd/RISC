
LIBRARY IEEE;--! standard library IEEE (Institute of Electrical and Electronics Engineers)
USE IEEE.std_logic_1164.ALL;--! standard unresolved logic UX01ZWLH-
USE IEEE.numeric_std.ALL;--! for the signed, unsigned types and arithmetic ops

-- -- -- -- Задача блока: -- -- -- --
-- 1. Хранить в каком-то массиве код программы, либо считывает его из файла
-- 2. При запросе данных через протокол AXI4-MM по адресу возвращать нужные данные с учетом длины
-- 3. Размер шины данных строго 32 бита = 4 байта, далее 4 байта называется "словом", WORD - одна команда
-- 4. Размер шины адреса 12 бит, т.е размер погромы 2^12=4046 бит или 64 слова (команда)
------------------------------------

-- -- -- -- Распределение: -- -- -- --
-- Коля: 
-- - Протокол AXI4-MM Master (только чтение) 
-- - Функция выборки данных их памяти при запросе
-- Наташа: 
-- - Код программы
-------------------------------------

ENTITY ProgramMemory_TOP IS
  PORT (
    refclk : IN STD_LOGIC; --! reference clock expect 250Mhz
    rst    : IN STD_LOGIC  --! sync active high reset. sync -> refclk

    -- AXI-4 MM (Только Reader) Ports
    --  Read address channel signals
    M_AXI_ARADDR  : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    M_AXI_ARSIZE  : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    M_AXI_ARVALID : IN STD_LOGIC;
    M_AXI_ARREADY : OUT STD_LOGIC;

    -- Read data channel signals
    M_AXI_RDATA  : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    M_AXI_RRESP  : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    M_AXI_RLAST  : OUT STD_LOGIC;
    M_AXI_RVALID : OUT STD_LOGIC;
    M_AXI_RREADY : IN STD_LOGIC
    -- /AXI-4 MM (Только Reader) Ports
  );

END ENTITY ProgramMemory_TOP;
ARCHITECTURE rtl OF ProgramMemory_TOP IS
BEGIN
END ARCHITECTURE rtl;