LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

PACKAGE mnemonic_pkg IS
    -- Функция для преобразования мнемоники в индекс для регистров i
    FUNCTION mnemonic_to_index_i(mnemonic : STRING) RETURN INTEGER;
END PACKAGE mnemonic_pkg;

PACKAGE BODY mnemonic_pkg IS
    -- Реализация функции для регистров i
    FUNCTION mnemonic_to_index_i(mnemonic : STRING) RETURN INTEGER IS
    BEGIN
        CASE mnemonic IS
            WHEN "Zero" => RETURN 0;  -- x0
            WHEN "ra"   => RETURN 1;  -- x1
            WHEN "sp"   => RETURN 2;  -- x2
            WHEN "gp"   => RETURN 3;  -- x3
            WHEN "tp"   => RETURN 4;  -- x4
            WHEN "t0"   => RETURN 5;  -- x5
            WHEN "t1"   => RETURN 6;  -- x6
            WHEN "t2"   => RETURN 7;  -- x7
            WHEN "s0"   => RETURN 8;  -- x8
            WHEN "s1"   => RETURN 9;  -- x9
            WHEN "a0"   => RETURN 10; -- x10
            WHEN "a1"   => RETURN 11; -- x11
            WHEN "a2"   => RETURN 12; -- x12
            WHEN "a3"   => RETURN 13; -- x13
            WHEN "a4"   => RETURN 14; -- x14
            WHEN "a5"   => RETURN 15; -- x15
            WHEN "a6"   => RETURN 16; -- x16
            WHEN "a7"   => RETURN 17; -- x17
            WHEN "s2"   => RETURN 18; -- x18
            WHEN "s3"   => RETURN 19; -- x19
            WHEN "s4"   => RETURN 20; -- x20
            WHEN "s5"   => RETURN 21; -- x21
            WHEN "s6"   => RETURN 22; -- x22
            WHEN "s7"   => RETURN 23; -- x23
            WHEN "s8"   => RETURN 24; -- x24
            WHEN "s9"   => RETURN 25; -- x25
            WHEN "s10"  => RETURN 26; -- x26
            WHEN "s11"  => RETURN 27; -- x27
            WHEN "t3"   => RETURN 28; -- x28
            WHEN "t4"   => RETURN 29; -- x29
            WHEN "t5"   => RETURN 30; -- x30
            WHEN "t6"   => RETURN 31; -- x31
            WHEN OTHERS => RETURN 0;  -- По умолчанию x0
        END CASE;
    END FUNCTION;
END PACKAGE BODY mnemonic_pkg;