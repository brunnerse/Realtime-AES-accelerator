library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package common is


constant KEY_SIZE : integer := 128;    

-- AEA definitions
constant NUM_ROUNDS : integer := 10;
-- Array of keys that are used in each round of theAEA
type ROUNDKEYARRAY is array(0 to NUM_ROUNDS) of STD_LOGIC_VECTOR(KEY_SIZE-1 downto 0);
-- AEA column table. The table has always 4 rows, the number of columns depends on the key size
type TABLE is array(0 to KEY_SIZE/32-1) of STD_LOGIC_VECTOR(31 downto 0);


-- AES Core definitions
constant MODE_ENCRYPTION : std_logic_vector := "00";
constant MODE_KEYEXPANSION : std_logic_vector := "01";
constant MODE_DECRYPTION : std_logic_vector := "10";
constant MODE_KEYEXPANSION_AND_DECRYPT : std_logic_vector := "11";

constant CHAINING_MODE_ECB : std_logic_vector := "000";
constant CHAINING_MODE_CBC : std_logic_vector := "001";
constant CHAINING_MODE_CTR : std_logic_vector := "010";
constant CHAINING_MODE_GCM : std_logic_vector := "011";
-- TODO GMAC?
constant CHAINING_MODE_CCM : std_logic_vector := "100";


end package;