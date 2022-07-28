----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 28.07.2022 01:09:13
-- Design Name: 
-- Module Name: AES_Core - Behavioral
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
use IEEE.std_logic_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity AES_Core is
    Port ( Key : in std_logic_VECTOR (127 downto 0);
           IV : in std_logic_VECTOR (127 downto 0);
           DIN : in std_logic_VECTOR (127 downto 0);
           DOUT : out std_logic_VECTOR (127 downto 0);
           SaveRestore : in std_logic);
end AES_Core;

architecture Behavioral of AES_Core is

begin


end Behavioral;
