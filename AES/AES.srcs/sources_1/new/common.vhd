library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package common is

constant KEY_SIZE : integer := 128;    
constant NUM_ROUNDS : integer := 10;

type ROUNDKEYARRAY is array(NUM_ROUNDS downto 0) of STD_LOGIC_VECTOR(KEY_SIZE-1 downto 0);
-- 
type TABLE is array(KEY_SIZE/32-1 downto 0) of STD_LOGIC_VECTOR(KEY_SIZE/32-1 downto 0);

end package;