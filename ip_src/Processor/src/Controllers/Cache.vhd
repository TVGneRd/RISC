
LIBRARY IEEE;--! standard library IEEE (Institute of Electrical and Electronics Engineers)
USE IEEE.std_logic_1164.ALL;--! standard unresolved logic UX01ZWLH-
USE IEEE.numeric_std.ALL;--! for the signed, unsigned types and arithmetic ops

-- -- -- -- Задача блока: -- -- -- --
-- 1. Дождаться valid=1, сделать ready=0
-- 2. Проверить находится ли address в диапазоне кэша (address - cache_size) < cache_upper_bound
-- 3. Если адрес находится в диапазоне, то просто переходим к пункту 4.
-- 3. Если адрес НЕ находится в диапазоне -> считывать 64 байта данных из памяти по AXI-4, записать их собственный кэш (это может быть любой массив)
-- 4. Установить data=массив_загруженных_данных[address % cache_size] и ready=1
-- 5. Ждать следующего valid=1, и повтор всего
------------------------------------

-- -- -- -- Распределение: -- -- -- --
-- Аня: 1, 2, 3, 4, 5
-------------------------------------

ENTITY Cache IS
  GENERIC (
    cache_size : INTEGER := 64
  );
  PORT (
    refclk : IN STD_LOGIC;--! reference clock expect 250Mhz
    rst    : IN STD_LOGIC;--! sync active high reset. sync -> refclk

    -- Порты для взаимодействия с ядром процессором, через него возвращаются данные из кэша
    address : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    data    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    valid   : IN STD_LOGIC;
    ready   : OUT STD_LOGIC;

    -- AXI-4 MM (Только Reader) Ports
    --  Read address channel signals
    M_AXI_ARADDR  : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    M_AXI_ARLEN   : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    M_AXI_ARVALID : OUT STD_LOGIC;
    M_AXI_ARREADY : IN STD_LOGIC;

    -- Read data channel signals
    M_AXI_RDATA  : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    M_AXI_RRESP  : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    M_AXI_RLAST  : IN STD_LOGIC;
    M_AXI_RVALID : IN STD_LOGIC;
    M_AXI_RREADY : OUT STD_LOGIC
    -- /AXI-4 MM (Только Reader) Ports
  );
END ENTITY Cache;
ARCHITECTURE rtl OF Cache IS
BEGIN
END ARCHITECTURE rtl;