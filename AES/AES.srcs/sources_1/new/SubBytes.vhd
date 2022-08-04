----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02.08.2022 01:09:30
-- Design Name: 
-- Module Name: SubBytes - Behavioral
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
use work.sbox_definition.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

entity SubBytes is
    Port ( dIn : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dOut : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           encrypt : in STD_LOGIC;
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Reset : in STD_LOGIC);
end SubBytes;

architecture Behavioral of SubBytes is
	  
begin

process (Clock, Reset)
begin
if Reset = '0' then
    dout <= (others => '0');
elsif rising_edge(Clock) then
    EnO <= EnI;
    if EnI = '1' then
        if encrypt = '1' then    
            for i in KEY_SIZE/8-1 downto 0 loop
                dout(i*8+7 downto i*8) <= sbox_encrypt(to_integer(unsigned(dIn(i*8+7 downto i*8))));
            end loop;
        else
            for i in KEY_SIZE/8-1 downto 0 loop
                dout(i*8+7 downto i*8) <= sbox_decrypt(to_integer(unsigned(dIn(i*8+7 downto i*8))));
            end loop;
        end if;
    end if;
end if;
end process;


end Behavioral;
