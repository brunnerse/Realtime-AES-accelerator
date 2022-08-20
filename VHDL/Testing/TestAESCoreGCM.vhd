
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.common.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;


entity TestAESCoreGCM is
--  Port ( );
end TestAESCoreGCM;

architecture Behavioral of TestAESCoreGCM is

component AES_Core is
    Port ( Key : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           IV : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           newIV : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           H  : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           newH  : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           Susp : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           newSusp : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dIn : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dOut : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           EnI : in std_logic;
           EnO : out std_logic;
           mode : in std_logic_vector (1 downto 0);
           chaining_mode : in std_logic_vector (2 downto 0);
           GCMPhase : in std_logic_vector(1 downto 0);
           Clock : in std_logic;
           Resetn : in std_logic
           );
end component;

signal Clock, Resetn : std_logic;

signal testPlaintext, testIV, testKey, testCiphertext, newIV, testSusp, newSusp, H : std_logic_vector(KEY_SIZE-1 downto 0);
signal EnCoreI, EnCoreO : std_logic;

signal mode, GCMPhase : std_logic_vector(1 downto 0);
signal chaining_mode : std_logic_vector(2 downto 0);

begin


--testPlaintext <= x"00102030011121310212223203132333";
testKey <= x"000102030405060708090a0b0c0d0e0f";

mode <= MODE_KEYEXPANSION_AND_DECRYPTION;
chaining_mode <= CHAINING_MODE_GCM;


core: AES_Core port map (testKey, testIV, newIV, H, H, testSusp, newSusp, testPlaintext, testCiphertext, EnCoreI, EnCoreO, mode, chaining_mode, GCMPhase, Clock, Resetn);

process begin
Clock <= '1'; wait for 5 ns;
Clock <= '0'; wait for 5 ns;
end process;
process begin
Resetn <= '0'; wait for 10 ns;
Resetn <= '1'; wait;
end process;



-- Set up GCM encryption
process begin
EnCoreI <= '0'; wait for 10 ns; -- Wait until Resetn is over
EnCoreI <= '1'; 
GCMPhase <= GCM_PHASE_INIT;
wait for 10 ns;
EnCoreI <= '0';
wait until EnCoreO <= '1'; wait for 10ns;
-- Enter header phase
GCMPhase <= GCM_PHASE_HEADER;
testPlaintext <= x"00102030011121310212223203132333";
EnCoreI <= '1';
wait for 10ns;
EnCoreI <= '0';
wait until EnCoreO <= '1'; wait for 10ns;
-- another header
testPlaintext <= x"affedeadbeefdadcabbeadbeec0cabad";
EnCoreI <= '1';
wait for 10ns;
EnCoreI <= '0';
wait until EnCoreO <= '1'; wait for 10ns;
-- Enter payload phase
GCMPhase <= GCM_PHASE_PAYLOAD;
EnCoreI <= '1';
testIV <= x"f0e0d0c0b0a090807060504000000002";
testPlaintext <= x"00102030011121310212223203132333";
wait for 10ns;
EnCoreI <= '0';
wait until EnCoreO <= '1'; wait for 10ns;
wait for 10ns;
-- second payload block
testIV <= newIV;
EnCoreI <= '1';
wait for 10ns;
EnCoreI <= '0';
wait until EnCoreO <= '1'; wait for 10ns;
-- third payload block
testPlaintext <= testKey;
testIV <= newIV;
EnCoreI <= '1';
wait for 10ns;
EnCoreI <= '0';
wait until EnCoreO <= '1'; wait for 10ns;
-- enter final phase
GCMPhase <= GCM_PHASE_FINAL;
-- gLen(header) & gLen(cipher), length in bits
testPlaintext <= x"0000000000000100" & x"0000000000000180";
testIV <= x"f0e0d0c0b0a090807060504000000001";
--testPlaintext <= (others => '0');
EnCoreI <= '1';
wait for 10ns;
EnCoreI <= '0';
wait;
end process;

-- process to update the IV
process (EnCoreO, Resetn) 
begin
-- initialize IV
if Resetn = '0' then
    testSusp <= (others => '0');
 end if;
-- update IV
if EnCoreO = '1' and GCMPhase /= GCM_PHASE_INIT then
    testSusp <= newSusp;
end if;
end process;

end Behavioral;
