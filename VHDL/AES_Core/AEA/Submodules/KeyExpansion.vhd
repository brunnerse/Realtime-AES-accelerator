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
           Resetn : in STD_LOGIC);
end KeyExpansion;


architecture Behavioral of KeyExpansion is

-- The Index of the key that is being calculated in this cycle
signal keyIndex : integer range 1 to NUM_ROUNDS;

signal keys : ROUNDKEYARRAY;
signal RCon : STD_LOGIC_VECTOR (7 downto 0);

begin

roundKeys <= keys;

process (Clock)

variable lastKey : STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
variable word_1, word : STD_LOGIC_VECTOR(31 downto 0);

begin
if rising_edge(Clock) then
    EnO <= '0';
    if Resetn = '0' then
        for i in keys'RANGE loop
            keys(i) <= ( others=> '0');
        end loop;
        keyIndex <= 1;
        RCon <= x"01";
    else
         -- currently calculating a key; one key per cycle
        if EnI = '1' or keyIndex > 1 then
            -- in first round, lastKey is the userKey
            if EnI = '1' then
                lastKey := userKey;
            else
                lastKey := keys(keyIndex-1);
            end if;
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
            keys(keyIndex)(127 downto 96) <= word;
            
            -- Calculate the other 3 words
            for i in 1 to 3 loop
                -- xor the previous word with the fourth last word (w_1 xor w_4)
                word := word xor lastKey(127-32*i downto 96-32*i);
                keys(keyIndex)(127-32*i downto 96-32*i) <= word;
            end loop;

            -- Check if all words have been calculated
            if keyIndex = NUM_ROUNDS then
                -- Set EnO and reset helper variables for next run
                EnO <= '1';
                keyIndex <= 1;
                RCon <= x"01";
            else
                keyIndex <= keyIndex + 1;
            end if;
        end if;
    end if;
end if;
end process;


end Behavioral;
