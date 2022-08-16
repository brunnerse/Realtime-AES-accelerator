library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package common is

constant KEY_SIZE : integer := 128;    
constant NUM_ROUNDS : integer := 10;

type ROUNDKEYARRAY is array(0 to NUM_ROUNDS) of STD_LOGIC_VECTOR(KEY_SIZE-1 downto 0);

-- the table has always 4 rows, the number of columns depends on the key size
type TABLE is array(0 to KEY_SIZE/32-1) of STD_LOGIC_VECTOR(31 downto 0);

end package;