----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02.08.2022 01:09:30
-- Design Name: 
-- Module Name: KeyExpansion - Behavioral
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


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.common.ALL;
use work.sbox_definition.sbox_encrypt;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;


entity KeyExpansion is
    Port ( userKey : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           roundKeys : out ROUNDKEYARRAY;
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Reset : in STD_LOGIC);
end KeyExpansion;


architecture Behavioral of KeyExpansion is

type WORD_TYPE is array ((NUM_ROUNDS+1)*4-1 downto 0) of STD_LOGIC_VECTOR(31 downto 0);

signal wordIndex : STD_LOGIC_VECTOR(7 downto 0);
signal words : WORD_TYPE;

begin

-- Process to write the words to the roundKeys output
process(words)
begin
for i in NUM_ROUNDS downto 0 loop
    roundKeys(i) <= words(i*4) & words(i*4+1) & words(i*4+2) & words(i*4+3);
end loop;
end process;


process (Clock, Reset)

variable currentKey : STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
variable word_1, word_4 : STD_LOGIC_VECTOR(31 downto 0);
variable index : integer;

variable RCon : STD_LOGIC_VECTOR (7 downto 0);

begin
if Reset = '0' then
    EnO <= '0';
    wordIndex <= x"00";
    for i in (NUM_ROUNDS+1)*4-1 downto 0 loop
        words(i) <= x"00000000";
    end loop; 
elsif rising_edge(Clock) then
    -- Calculating one word per cycle
    if wordIndex /= x"00" then -- currently calculating a key
        word_1 := words(to_integer(unsigned(wordIndex) - to_unsigned(1, 8))); 
        word_4 := words(to_integer(unsigned(wordIndex)- to_unsigned(KEY_SIZE/32, 8)));  
        if (wordIndex and x"03") = x"00" then  -- wordIndex is divisible by 4
            -- Rotate word: rol 8
            word_1 := word_1(23 downto 0) & word_1(31 downto 24);
            -- perform substitution for each byte of word_1
            for i in 3 downto 0 loop
                index := to_integer(unsigned(word_1(i*8-1 downto (i-1)*8)));
                word_1(i*8-1 downto (i-1)*8) := sbox_encrypt(index);
            end loop;
            -- xor with constant
            -- Calculate new constant:  Old RCon * 'x' (i.e. 02), which means 2Rcon 
            if RCon(7) = '0' then -- RCon < 0x80
                RCon := RCon(6 downto 0) & '0';
            else
                RCon := (RCon(6 downto 0) & '0') xor x"1b";
            end if;
            word_1 := word_1 xor (Rcon & x"000000");
        end if;
        
        words(to_integer(unsigned(wordIndex))) <= word_1 xor word_4;
        -- Check if all words have been calculated
        if wordIndex = std_logic_vector(to_unsigned(NUM_ROUNDS*4-1, 8)) then
            wordIndex <= x"00";
            EnO <= '0';
        end if;
    elsif EnI = '1' then -- start calculation when EnI is enabled
        EnO <= '0';
        -- write user key in first four words
        for i in 0 to KEY_SIZE/32-1 loop
            words(i) <= userKey(KEY_SIZE-1-i*32 downto KEY_SIZE-(i+1)*32);
        end loop;
        wordIndex <= x"04";
        RCon := x"01";
    end if;
end if;
end process;


end Behavioral;
