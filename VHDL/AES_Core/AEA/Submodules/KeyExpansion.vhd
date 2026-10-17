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
use IEEE.NUMERIC_STD.ALL;
 
use work.common.ALL;
use work.sbox_definition.sbox_encrypt;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;


entity KeyExpansion is
    Port (  userKey : in key_t; 
            setUserKey : in STD_LOGIC;
            calcNextRoundKey : in STD_LOGIC;
            reverse : in STD_LOGIC;
--
            roundKey : out block_t; 
            isLastRoundKey : out STD_LOGIC;
            Clock : in STD_LOGIC;
            Resetn : in STD_LOGIC);
end KeyExpansion;


architecture Behavioral of KeyExpansion is

-- The Index of the key that is being calculated in this cycle
signal round : integer range 0 to AES_NR;
signal RCon : STD_LOGIC_VECTOR (7 downto 0);

type words_t is array(0 to AES_NB-1) of STD_LOGIC_VECTOR(31 downto 0);

signal words : words_t; 

signal finalKey : words_t;

begin

WtoKey: for i in 0 to AES_NB-1 generate
    roundKey(roundKey'HIGH-32*i downto roundKey'HIGH-31-32*i) <= words(i);
end generate;

assert AES_NK = 4 report "Module does not support AES_NK /= 4!" severity failure;


process (Clock)

variable temp : STD_LOGIC_VECTOR(31 downto 0);

variable W, prevW : words_t; 

begin
if rising_edge(Clock) then
    if Resetn = '0' or setUserKey = '1' then
        if reverse /= '1' then
            for i in 0 to AES_NB-1 loop
                words(i) <= userKey(userKey'HIGH-32*i downto userKey'HIGH-31-32*i); 
            end loop;

            RCon <= x"01"; 
            round <= 0;
            finalKey <= (others => (others => '-'));
        else
            words <= finalKey;
            RCon <= x"36"; 
            round <= AES_NR;
        end if;
    else
        if calcNextRoundKey = '1' then

            prevW := words;
            W := (others => (others => '-'));

            if round = AES_NR - 1 then
                isLastRoundKey <= '1';
            else
                isLastRoundKey <= '0';
            end if;

            if reverse /= '1' then
                round <= round + 1;

                -- Calculate first word from previous word (the last roundKey word)
                temp := prevW(AES_NB-1); 
                -- Rotate word: rol 8
                temp := temp(23 downto 0) & temp(31 downto 24);
                -- perform substitution for each byte 
                for j in 3 downto 0 loop
                    temp(j*8+7 downto j*8) := sbox_encrypt(to_integer(unsigned(temp(j*8+7 downto j*8))));
                end loop;
                -- xor with Rcon constant
                temp := temp xor (Rcon & x"000000");

                for i in 0 to AES_NB-1 loop
                    W(i) := temp xor prevW(i);
                    temp := W(i);
                end loop;

                -- Calculate new constant:  Old RCon * 'x' (i.e. 02), which means 2Rcon 
                if round /= AES_NR - 1 then
                    if RCon(7) = '0' then -- RCon < 0x80
                        RCon <= RCon(6 downto 0) & '0';
                    else
                        RCon <= (RCon(6 downto 0) & '0') xor x"1b";
                    end if;
                else
                    finalKey <= W;
                end if;

            else
                -- Reverse KeyExpansion
                round <= round - 1;

                --prevkeyW[3] = keyW[3] ^ keyW[2]; 
                for i in AES_NB-1 downto 1 loop
                    W(i) := prevW(i) xor prevW(i-1);
                end loop;

                temp := W(3);
                -- Rotate word: rol 8
                temp := temp(23 downto 0) & temp(31 downto 24);
                -- perform substitution for each byte 
                for j in 3 downto 0 loop
                    temp(j*8+7 downto j*8) := sbox_encrypt(to_integer(unsigned(temp(j*8+7 downto j*8))));
                end loop;
                -- xor with Rcon constant
                temp := temp xor (Rcon & x"000000");

                W(0) := prevW(0) xor temp;

                -- Calculate prev constant:  RCon / 'x' (i.e. 02), which means 2Rcon 
                -- if lowest bit was set, that must men "xor x1b" was executed previously
                if RCon(0) = '1' then 
                    -- Reverse (Rcon << 1) xor x"1b"
                    RCon <= std_logic_vector(shift_right(unsigned(RCon xor x"1b"), 1));
                    RCon(7) <= '1';
--                    RCon <= ('1' & Rcon(7 downto 1)) xor x"0d"; 
                else
                    RCon <= "0" & RCon(7 downto 1);
                end if;
            end if;
        
            words <= W;

        end if;

    end if;
end if;
end process;


end Behavioral;
