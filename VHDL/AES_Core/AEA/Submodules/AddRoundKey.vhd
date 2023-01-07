----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02.08.2022 01:09:30
-- Design Name: 
-- Module Name: AddRoundKey - Behavioral
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

entity AddRoundKey is
    Generic (
        synchronous : boolean := true
        );
    Port ( din : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dout : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           key : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Resetn : in STD_LOGIC);
end AddRoundKey;

architecture Behavioral of AddRoundKey is

begin

GenASync: if not synchronous generate
EnO <= EnI;
dOut <= din xor key;
end generate;

GenSync:  if synchronous generate
process (Clock)
begin
if rising_edge(Clock) then
    if Resetn = '0' then
        EnO <= '0';
    else
        EnO <= EnI;
        if EnI = '1' then
            dOut <= din xor key;
        end if;
    end if;
end if;
end process;
end generate;

end Behavioral;
