library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.common.ALL;

entity ColumnTableToVector is
    Port (  table  : in COLUMNTABLE;
            vector : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0)
    );
end ColumnTableToVector;

architecture Behavioral of ColumnTableToVector is

signal line0, line1, line2, line3 : STD_LOGIC_VECTOR(KEY_SIZE/4-1 downto 0);

begin

line0 <= table(0)(31 downto 24) & table(1)(31 downto 24) & table(2)(31 downto 24) & table(3)(31 downto 24);
line1 <= table(0)(23 downto 16) & table(1)(23 downto 16) & table(2)(23 downto 16) & table(3)(23 downto 16);
line2 <= table(0)(15 downto 8) & table(1)(15 downto 8) & table(2)(15 downto 8) & table(3)(15 downto 8);
line3 <= table(0)(7 downto 0) & table(1)(7 downto 0) & table(2)(7 downto 0) & table(3)(7 downto 0);

vector <= line0 & line1 & line2 & line3;

end Behavioral;
