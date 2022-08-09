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

signal keyIndex : STD_LOGIC_VECTOR(3 downto 0);
signal keys : ROUNDKEYARRAY;
signal RCon : STD_LOGIC_VECTOR (7 downto 0);


begin

roundKeys <= keys;


process (Clock, Reset)

variable lastKey : STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
variable word_1, word : STD_LOGIC_VECTOR(31 downto 0);

begin
if Reset = '0' then
    EnO <= '0';
    keyIndex <= x"0";
    for i in NUM_ROUNDS downto 0 loop
        keys(i) <= ( others=> '0');
    end loop; 
elsif rising_edge(Clock) then
    -- Calculating four words per cycle
    if keyIndex /= x"0" then -- currently calculating a key
        lastKey := keys(to_integer(unsigned(keyIndex))-1);
        -- Calculate first word
        word_1 := lastKey(31 downto 0);
        -- Rotate word: rol 8
        word_1 := word_1(23 downto 0) & word_1(31 downto 24);
        -- perform substitution for each byte of word_1
        for j in 3 downto 0 loop
            word_1((j+1)*8-1 downto j*8) := sbox_encrypt(to_integer(unsigned(word_1((j+1)*8-1 downto j*8))));
        end loop;
        -- xor with constant
        word_1 := word_1 xor (Rcon & x"000000");
        -- Calculate new constant:  Old RCon * 'x' (i.e. 02), which means 2Rcon 
        if RCon(7) = '0' then -- RCon < 0x80
            RCon <= RCon(6 downto 0) & '0';
        else
            RCon <= (RCon(6 downto 0) & '0') xor x"1b";
        end if;
        
        word := word_1 xor lastKey(127 downto 96);
        keys(to_integer(unsigned(keyIndex)))(127 downto 96) <= word;
        
        -- Calculate the other 3 words
        for i in 1 to 3 loop
            word := word xor lastKey(127-32*i downto 96-32*i);
            keys(to_integer(unsigned(keyIndex)))(127-32*i downto 96-32*i) <= word;
        end loop;

        -- Increment keyIndex
        keyIndex <= std_logic_vector(unsigned(keyIndex) + to_unsigned(1, 4));
        -- Check if all words have been calculated
        if keyIndex = x"a" then
            keyIndex <= x"0";
            EnO <= '1';
        end if;
    else -- Idle state
        EnO <= '0';
        if EnI = '1' then -- start calculation when EnI is enabled
            -- write user key in first four words
            keys(0) <= userKey;
            keyIndex <= x"1";
            RCon <= x"01";
         end if;
    end if;
end if;
end process;


end Behavioral;
