library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package common is


constant KEY_SIZE : integer := 128;    

-- AEA definitions
constant NUM_ROUNDS : integer := 10;
-- Array of keys that are used in each round of theAEA
type ROUNDKEYARRAY is array(1 to NUM_ROUNDS) of STD_LOGIC_VECTOR(KEY_SIZE-1 downto 0);
-- AEA column table. The table has always 4 rows, the number of columns depends on the key size
type TABLE is array(0 to KEY_SIZE/32-1) of STD_LOGIC_VECTOR(31 downto 0);


-- AES Core definitions
constant MODE_ENCRYPTION : std_logic_vector := "00";
constant MODE_KEYEXPANSION : std_logic_vector := "01";
constant MODE_DECRYPTION : std_logic_vector := "10";
constant MODE_KEYEXPANSION_AND_DECRYPTION : std_logic_vector := "11";

constant CHAINING_MODE_ECB : std_logic_vector := "00";
constant CHAINING_MODE_CBC : std_logic_vector := "01";
constant CHAINING_MODE_CTR : std_logic_vector := "10";
constant CHAINING_MODE_GCM : std_logic_vector := "11";

constant MODE_LEN : integer := 2;
constant CHMODE_LEN : integer := 2;

-- Galois Counter-Mode Phase definitions
constant GCM_PHASE_INIT : std_logic_vector := "00";
constant GCM_PHASE_HEADER : std_logic_vector := "01";
constant GCM_PHASE_PAYLOAD : std_logic_vector := "10";
constant GCM_PHASE_FINAL : std_logic_vector := "11";

-- Control Logic definitions
constant DATA_WIDTH : integer := 32;
constant ADDR_WIDTH : integer := 10;


end package;


package addresses is
-- Define the addresses according to the specification. 
constant ADDR_CR : integer := 16#00#;
constant ADDR_SR : integer := 16#04#;
constant ADDR_DINR : integer := 16#08#;
constant ADDR_DOUTR : integer := 16#0c#;
constant ADDR_KEYR0 : integer := 16#10#;
constant ADDR_KEYR1 : integer := 16#14#;
constant ADDR_KEYR2 : integer := 16#18#;
constant ADDR_KEYR3: integer := 16#1c#;
constant ADDR_IVR0 : integer := 16#20#;
constant ADDR_IVR1 : integer := 16#24#;
constant ADDR_IVR2 : integer := 16#28#;
constant ADDR_IVR3 : integer := 16#2c#;
-- 0x30 are additional key registers which are only used for 256-bit, which isn't done here
constant ADDR_SUSPR0 : integer := 16#40#;
constant ADDR_SUSPR1 : integer := 16#44#;
constant ADDR_SUSPR2 : integer := 16#48#;
constant ADDR_SUSPR3 : integer := 16#4c#;
constant ADDR_SUSPR4 : integer := 16#50#;
constant ADDR_SUSPR5 : integer := 16#54#;
constant ADDR_SUSPR6 : integer := 16#58#;
constant ADDR_SUSPR7 : integer := 16#5c#;


end package;