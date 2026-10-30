---------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03.08.2022 21:58:39
-- Design Name: 
-- Module Name: TestAEA - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

package test_pkg is
--    type test_case_t is (All_Cases, Encryption_Only);

    subtype case_t is bit_vector(0 to 6);
    constant ALL_CASES      : case_t := "1111111";
    constant CASE_NOT_SET   : case_t := "0000000"; 

    constant ENCRYPT_x      : case_t := "1000000";
    constant ENCRYPT_y      : case_t := "0100000";
    constant DECRYPT_y_1    : case_t := "0010000"; 
    constant DECRYPT_y_2    : case_t := "0001000";

    constant KEYEXP_x       : case_t := "0000100"; -- Only Keyexpansion

    constant DEC_KEYEXP_x   : case_t := "0000010"; --  KeyExpansion solo, then decrypt 
    constant DEC_KEYEXP_y   : case_t := "0000001"; --  Decrypt with Keyexpansion

end package;


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.common.ALL;
use work.test_pkg.ALL;

entity TestAEA is
    Generic (
        g_TEST_CASES: case_t := ENCRYPT_y or DECRYPT_y_1 or KEYEXP_x or DEC_KEYEXP_x 
--        g_TEST_CASES: case_t := DEC_KEYEXP_Y; 
    );
end entity;

architecture Behavioral of TestAEA is

function isTestCaseEnabled(case_val : case_t) return boolean is
begin
    if (case_val and g_TEST_CASES) /= CASE_NOT_SET then
        return true;
    end if;
    return false;
end function;



constant key1 : std_logic_vector(255 downto 0) := 
    x"000102030405060708090a0b0c0d0e0f_101112131415161718191a1b1c1d1e1f"; 
constant key2 : std_logic_vector(255 downto 0) := 
    x"000102030405060708090a0b0c0d0e0f_00000000000000000000000000000000"; 
constant key3 : std_logic_vector(255 downto 0) := 
    (others => '0'); 

constant plaintext1 : block_t := x"00010203_10111213_20212223_30313233";
constant plaintext2 : block_t := x"00102030_01112131_02122232_03132333";
constant plaintext3 : block_t := (others => '0');


signal Clock, Resetn : std_logic := '1';

signal dIn, dOut: block_t;
signal testKey : key_t;
signal EnI, EnO : std_logic := '0';
signal encrypt : std_logic := '1';
signal keyExpand : std_logic := '0';

begin


aeaEnc : entity work.AEA port map (dIn => dIn, dOut => dOut, key => testKey, 
        encrypt => encrypt, 
        keyExpand => keyExpand, 
        EnI => EnI, EnO => EnO, 
        Clock => Clock, Resetn => Resetn);

Clock <= not Clock after 5 ns;

process 
    procedure startAndWaitForCompletion is
    begin
        EnI <= '1';
        wait for 0 ns;
        report "Starting AEA (mode " & to_string(encrypt) & " " & to_string(keyExpand) & ") with dIn = " & to_hstring(to_bitvector(dIn));
        wait until rising_edge(Clock);
        EnI <= '0';
        wait until EnO = '1' and rising_edge(Clock);
        report "AEA finished with dOut = " & to_hstring(to_bitvector(dOut));
    end procedure;

    variable ciphertext_x, ciphertext_y : block_t := (others => '0');

begin
    Resetn <= '0';
    EnI <= '0'; 
    wait for 30 ns; wait until rising_edge(Clock);
    Resetn <= '1';

    if isTestCaseEnabled(ENCRYPT_x)
    then 
        testKey <= key3(255 downto 256-testKey'length); 
        encrypt <= '1'; keyExpand <= '0';
        dIn <= plaintext1; 
        startAndWaitForCompletion;

        ciphertext_x := dOut; 

    end if;

    if isTestCaseEnabled(ENCRYPT_y)
    then 
        wait for 10 ns; -- TODO try lower wait time
        testKey <= key2(255 downto 256-testKey'length); 
        encrypt <= '1'; keyExpand <= '0';
        dIn <= plaintext2;
        startAndWaitForCompletion;

        ciphertext_y := dOut; 
    end if;



    if isTestCaseEnabled(DECRYPT_y_1)  -- Decrypt with same key with no break in between
    then 
        encrypt <= '0'; keyExpand <= '0';
        dIn <= ciphertext_y;
        startAndWaitForCompletion;
    end if;

    if isTestCaseEnabled(DECRYPT_y_2)  -- Decrypt with same key
    then 
        dIn <= (others => '0');
--        wait for 50 ns; -- TODO after it works with delay, try without
        encrypt <= '0'; keyExpand <= '0';
        dIn <= ciphertext_y;
        startAndWaitForCompletion;
    end if;

    report "Resetting...";
    Resetn <= '0'; -- Reset round keys
    wait for 50 ns; 
    Resetn <= '1'; 

    if isTestCaseEnabled(KEYEXP_x)  -- Run key expansion 
    then
        testKey <= key2(255 downto 256-testKey'length); 
        encrypt <= '1'; keyExpand <= '1';
        dIn <= (others => '-'); 
        startAndWaitForCompletion;
    end if;

    wait for 20 ns;  -- TODO try with/without wait phase

    if isTestCaseEnabled(DEC_KEYEXP_x)  -- Decrypt after keyexpansion 
    then
        testKey <= key2(255 downto 256-testKey'length); 
        encrypt <= '0'; keyExpand <= '0';
        dIn <= ciphertext_y; 
        startAndWaitForCompletion;
    end if;


    if isTestCaseEnabled(DEC_KEYEXP_y)  -- Decrypt with key expansion 
    then
        wait for 30 ns; 
        report "Resetting round keys...";
        Resetn <= '0'; -- Reset round keys
        wait until rising_edge(Clock);
        Resetn <= '1'; 

        testKey <= key2(255 downto 256-testKey'length); 
        dIn <= ciphertext_y;
        encrypt <= '0'; keyExpand <= '1'; -- Must set keyexpand=1 
        report "Decrypting with keyexpansion..."; 
        startAndWaitForCompletion;
    end if;

    wait;
end process;


end architecture;
