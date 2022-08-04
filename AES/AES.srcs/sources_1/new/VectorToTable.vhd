----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02.08.2022 01:33:29
-- Design Name: 
-- Module Name: VectorToTable - Behavioral
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

entity VectorToTable is
    Port ( vector : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           table  : out TABLE
    );
    
end VectorToTable;

architecture Behavioral of VectorToTable is

begin

-- for KEY_SIZE != 128, this module must be adapted!

table(3) <= vector(31 downto 0);
table(2) <= vector(63 downto 32);
table(1) <= vector(95 downto 64);
table(0) <= vector(127 downto 96);

end Behavioral;
