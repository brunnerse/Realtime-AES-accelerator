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
    Generic (
        synchronous : boolean := true
        );
    Port ( dIn : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dOut : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           encrypt : in STD_LOGIC;
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Resetn : in STD_LOGIC);
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

dinToTable: VectorToTable port map(dIn, tableIn);
tableToDout : TableToVector port map(tableOut, dOut);

GenAsync: if not synchronous generate
    EnO <= EnI;
    tableOut(0) <= tableIn(0)(31 downto 24) & tableIn(1)(23 downto 16) & tableIn(2)(15 downto 8) & tableIn(3)(7 downto 0) when encrypt = '1' else
                   tableIn(0)(31 downto 24) & tableIn(3)(23 downto 16) & tableIn(2)(15 downto 8) & tableIn(1)(7 downto 0);
    tableOut(1) <= tableIn(1)(31 downto 24) & tableIn(2)(23 downto 16) & tableIn(3)(15 downto 8) & tableIn(0)(7 downto 0) when encrypt = '1' else
                   tableIn(1)(31 downto 24) & tableIn(0)(23 downto 16) & tableIn(3)(15 downto 8) & tableIn(2)(7 downto 0);
    tableOut(2) <= tableIn(2)(31 downto 24) & tableIn(3)(23 downto 16) & tableIn(0)(15 downto 8) & tableIn(1)(7 downto 0) when encrypt = '1' else 
                   tableIn(2)(31 downto 24) & tableIn(1)(23 downto 16) & tableIn(0)(15 downto 8) & tableIn(3)(7 downto 0);
    tableOut(3) <= tableIn(3)(31 downto 24) & tableIn(0)(23 downto 16) & tableIn(1)(15 downto 8) & tableIn(2)(7 downto 0) when encrypt = '1' else  
                   tableIn(3)(31 downto 24) & tableIn(2)(23 downto 16) & tableIn(1)(15 downto 8) & tableIn(0)(7 downto 0);            
end generate;


GenSync:  if synchronous generate
    
process (Clock)
begin

if rising_edge(Clock) then
    if Resetn = '0' then
        EnO <= '0';
    else
        EnO <= EnI;
        if encrypt = '1' then    
            -- Rotate the rows manually. Keep in mind that the table is made out of columns, not rows!
            tableOut(0) <= tableIn(0)(31 downto 24) & tableIn(1)(23 downto 16) & tableIn(2)(15 downto 8) & tableIn(3)(7 downto 0);
            tableOut(1) <= tableIn(1)(31 downto 24) & tableIn(2)(23 downto 16) & tableIn(3)(15 downto 8) & tableIn(0)(7 downto 0);
            tableOut(2) <= tableIn(2)(31 downto 24) & tableIn(3)(23 downto 16) & tableIn(0)(15 downto 8) & tableIn(1)(7 downto 0); 
            tableOut(3) <= tableIn(3)(31 downto 24) & tableIn(0)(23 downto 16) & tableIn(1)(15 downto 8) & tableIn(2)(7 downto 0);
        else 
        -- decrypt: reverse the rotate direction
            tableOut(0) <= tableIn(0)(31 downto 24) & tableIn(3)(23 downto 16) & tableIn(2)(15 downto 8) & tableIn(1)(7 downto 0);
            tableOut(1) <= tableIn(1)(31 downto 24) & tableIn(0)(23 downto 16) & tableIn(3)(15 downto 8) & tableIn(2)(7 downto 0);
            tableOut(2) <= tableIn(2)(31 downto 24) & tableIn(1)(23 downto 16) & tableIn(0)(15 downto 8) & tableIn(3)(7 downto 0); 
            tableOut(3) <= tableIn(3)(31 downto 24) & tableIn(2)(23 downto 16) & tableIn(1)(15 downto 8) & tableIn(0)(7 downto 0);
        end if;
    end if;
end if;
end process;

end generate;




end Behavioral;
