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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity KeyExpansion is
    Port ( userKey : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           roundKeys : out ROUNDKEYARRAY;
           Clock : in STD_LOGIC;
           Reset : in STD_LOGIC);
end KeyExpansion;

architecture Behavioral of KeyExpansion is

signal currentRoundKey : STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);

begin

process (Clock, Reset)
begin
if Reset = '0' then
    for i in NUM_ROUNDS downto 0 loop
        roundKeys(i) <= (others => '0');
    end loop; 
elsif rising_edge(Clock) then
    roundKeys(0) <= userKey;
    

end if;
end process;


end Behavioral;
