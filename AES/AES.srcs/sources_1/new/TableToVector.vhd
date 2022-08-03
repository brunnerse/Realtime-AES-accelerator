----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02.08.2022 01:42:26
-- Design Name: 
-- Module Name: TableToVector - Behavioral
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

entity TableToVector is
    Port (           
        table  : in TABLE;
        vector : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0)
    );
end TableToVector;

architecture Behavioral of TableToVector is

begin

-- for key sizes != 128, this module must be adapted!

vector <= table(0) & table(1) & table(2) & table(3);

end Behavioral;
