library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.common.ALL;

entity VectorToColumnTable is
    Port ( vector : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           table  : out COLUMNTABLE
    );
end VectorToColumnTable;

architecture Behavioral of VectorToColumnTable is
begin

table(0) <= vector(127 downto 120) & vector(95 downto 88) & vector(63 downto 56) & vector(31 downto 24);
table(1) <= vector(119 downto 112) & vector(87 downto 80)  & vector(55 downto 48) & vector(23 downto 16);
table(2) <= vector(111 downto 104) & vector(79 downto 72)& vector(47 downto 40) & vector(15 downto 8);
table(3) <= vector(103 downto 96) & vector(71 downto 64) & vector(39 downto 32) & vector(7 downto 0);


end Behavioral;
