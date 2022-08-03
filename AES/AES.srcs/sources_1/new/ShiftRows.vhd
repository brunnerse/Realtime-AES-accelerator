----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02.08.2022 01:09:30
-- Design Name: 
-- Module Name: ShiftRows - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ShiftRows is
    Port ( din : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dout : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           encrypt : in STD_LOGIC;
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Reset : in STD_LOGIC);
end ShiftRows;

architecture Behavioral of ShiftRows is

component VectorToTable Port
    ( vector : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           table  : out TABLE
    );
end component;
component TableToVector is
    Port (           
        table  : in TABLE;
        vector : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0)
    );
end component;


signal tableIn, tableOut : TABLE;

begin

dinToTable: VectorToTable port map(din, tableIn);
tableToDout : TableToVector port map(tableOut, dout);

process (Clock, Reset)
begin
if Reset = '0' then
    dout <= (others => '0');
elsif rising_edge(Clock) then
    if encrypt = '1' then    
        tableOut(0) <= tableIn(0);
        -- Rotate left; rol x is the same as ror (32-x)
        tableOut(1) <= tableIn(1) ror 24;
        tableOut(2) <= tableIn(2) ror 16;
        tableOut(3) <= tableIn(3) ror 8;
    else
        tableOut(0) <= tableIn(0);
        tableOut(1) <= tableIn(1) ror 8;
        tableOut(2) <= tableIn(2) ror 16;
        tableOut(3) <= tableIn(3) ror 24;
    end if;
end if;
end process;


end Behavioral;
