library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package common is

-- AEA definitions
constant AES_KEY_SIZE : integer := 128; 

-- The official AES standard always uses a block size of 128
constant AES_BLOCK_SIZE : integer := 128;

constant AES_NR : natural := 10;            -- Number of rounds
CONSTANT AES_NK : natural := AES_KEY_SIZE/32;   -- Number of columns in the cipher key
CONSTANT AES_NB : natural := AES_BLOCK_SIZE/32; -- Number of columns in a block

subtype block_t is std_logic_vector(AES_BLOCK_SIZE-1 downto 0);
subtype key_t is std_logic_vector(AES_KEY_SIZE-1 downto 0);

-- AES Core definitions

subtype mode_t is std_logic_vector(1 downto 0);

constant KEYSIZE_128 : mode_t := "00";
constant KEYSIZE_192 : mode_t := "01";
constant KEYSIZE_256 : mode_t := "10";

constant MODE_ENCRYPTION : mode_t := "00";
constant MODE_KEYEXPANSION : mode_t := "01";
constant MODE_DECRYPTION : mode_t := "10";
constant MODE_KEYEXPANSION_AND_DECRYPTION : mode_t := "11";

constant CHAINING_MODE_ECB : mode_t := "00";
constant CHAINING_MODE_CBC : mode_t := "01";
constant CHAINING_MODE_CTR : mode_t := "10";
constant CHAINING_MODE_GCM : mode_t := "11";


-- Galois Counter-Mode Phase definitions
constant GCM_PHASE_INIT : mode_t := "00";
constant GCM_PHASE_HEADER : mode_t := "01";
constant GCM_PHASE_PAYLOAD : mode_t := "10";
constant GCM_PHASE_FINAL : mode_t := "11";

-- Control Logic write port definitions TODO other name
constant DATA_WIDTH : integer := 32;
constant ADDR_WIDTH : integer := 15;

-- the 7 lowest bits of the address give the register
constant ADDR_REGISTER_BITS : integer := 7;
-- the higher bits of the address give the channel
constant ADDR_CHANNEL_BITS : integer := ADDR_WIDTH - ADDR_REGISTER_BITS;

constant MAX_CHANNELS : integer := 2**ADDR_CHANNEL_BITS; 
subtype num_channels_range is integer range 1 to MAX_CHANNELS;

constant NUM_PRIORITY_BITS : integer := ADDR_CHANNEL_BITS;
type PrioArrayType is array(natural range<>) of std_logic_vector(NUM_PRIORITY_BITS-1 downto 0);

end package;


package addresses is
-- Define the addresses according to the specification. 
constant ADDR_CR : integer := 16#00#;
constant ADDR_DATASIZE : integer := 16#04#;
constant ADDR_DINADDR : integer := 16#08#;
constant ADDR_DOUTADDR : integer := 16#0c#;
constant ADDR_KEYR0 : integer := 16#10#;
constant ADDR_KEYR1 : integer := 16#14#;
constant ADDR_KEYR2 : integer := 16#18#;
constant ADDR_KEYR3: integer := 16#1c#;
constant ADDR_IVR0 : integer := 16#20#;
constant ADDR_IVR1 : integer := 16#24#;
constant ADDR_IVR2 : integer := 16#28#;
constant ADDR_IVR3 : integer := 16#2c#;
constant ADDR_SUSPR0 : integer := 16#30#;
constant ADDR_SUSPR1 : integer := 16#34#;
constant ADDR_SUSPR2 : integer := 16#39#;
constant ADDR_SUSPR3 : integer := 16#3c#;
constant ADDR_HR0 : integer := 16#40#;
constant ADDR_HR1 : integer := 16#44#;
constant ADDR_HR2 : integer := 16#49#;
constant ADDR_HR3 : integer := 16#4c#;
constant ADDR_SR : integer := 16#50#;

end package;





package register_bit_positions is
use work.common.NUM_PRIORITY_BITS;

subtype CR_RANGE_PRIORITY is integer range (16+NUM_PRIORITY_BITS-1) downto 16;
subtype CR_RANGE_GCMPHASE is integer range 14 downto 13;
constant CR_POS_CCFIE : integer := 9;
constant CR_POS_CCFC : integer := 7;
subtype CR_RANGE_CHMODE is integer range 6 downto 5;
subtype CR_RANGE_MODE is integer range 4 downto 3;
constant CR_POS_EN : integer := 0;

constant SR_POS_IRQ : integer := 0;
constant SR_POS_CCF : integer := 8;
constant SR_POS_RDERR : integer := 16;
constant SR_POS_WRERR : integer := 24;

end package;
