
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.common.ALL;
use work.addresses.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;


entity TestAESCoreGCM is
--  Port ( );
end entity;

architecture Behavioral of TestAESCoreGCM is


signal Clock, Resetn : std_logic;

signal testPlaintext, testIV, testCiphertext, testSusp, H : block_t;
signal testKey : key_t;
signal EnCoreI, EnCoreO : std_logic;

signal WrEn : std_logic;
signal WrData : block_t;
signal WrAddr  : std_logic_vector(ADDR_REGISTER_BITS-1 downto 0);

signal mode, GCMPhase : mode_t := MODE_ENCRYPTION;
signal chaining_mode : mode_t := CHAINING_MODE_GCM;

begin

testKey <= x"000102030405060708090a0b0c0d0e0f";


core: entity work.AES_Core
    generic map(ADDR_IV => ADDR_IVR0, ADDR_SUSP => ADDR_SUSPR0, ADDR_H => ADDR_HR0)
    port map(Key => testKey, IV => testIV, H => H, Susp => testSusp,
             WrEn => WrEn, WrAddr => WrAddr, WrData => WrData,
             dIn => testPlaintext, dOut => testCiphertext,
             EnI => EnCoreI, EnO => EnCoreO,
             mode => mode, chaining_mode => chaining_mode, GCMPhase => GCMPhase,
             Clock => Clock, Resetn => Resetn);


process begin
Clock <= '1'; wait for 5  ns;
Clock <= '0'; wait for 5  ns;
end process;
process begin
Resetn <= '0'; wait for 20  ns;
Resetn <= '1'; wait;
end process;



-- Set up GCM encryption
process begin
EnCoreI <= '0'; wait for 40  ns; -- Wait until Resetn is over
EnCoreI <= '1'; 
GCMPhase <= GCM_PHASE_INIT;
wait for 10  ns;
EnCoreI <= '0';
wait until EnCoreO <= '1'; wait for 20 ns;
-- Enter header phase
GCMPhase <= GCM_PHASE_HEADER;
testPlaintext <= x"00102030011121310212223203132333";
EnCoreI <= '1';
wait for 10 ns;
EnCoreI <= '0';
wait until EnCoreO <= '1'; wait for 10 ns;
-- another header
testPlaintext <= x"affedeadbeefdadcabbeadbeec0cabad";
EnCoreI <= '1';
wait for 10 ns;
EnCoreI <= '0';
wait until EnCoreO <= '1'; wait for 20 ns;
-- Enter payload phase
GCMPhase <= GCM_PHASE_PAYLOAD;
EnCoreI <= '1';
testPlaintext <= x"00102030011121310212223203132333";
wait for 10 ns;
EnCoreI <= '0';
wait until EnCoreO <= '1'; wait for 20 ns;
wait for 10 ns;
-- second payload block
EnCoreI <= '1';
wait for 10 ns;
EnCoreI <= '0';
wait until EnCoreO <= '1'; wait for 20 ns;
-- third payload block
testPlaintext <= testKey;
EnCoreI <= '1';
wait for 10 ns;
EnCoreI <= '0';
wait until EnCoreO <= '1'; wait for 20 ns;
-- enter final phase
GCMPhase <= GCM_PHASE_FINAL;
-- gLen(header) & gLen(cipher), length in bits
testPlaintext <= x"0000000000000100" & x"0000000000000180";
wait for 10 ns;
--testPlaintext <= (others => '0');
EnCoreI <= '1';
wait for 10 ns;
EnCoreI <= '0';
wait;
end process;

-- process to update the IV
process (Resetn, Clock, WrEn, GCMPhase) 
begin
-- initialize IV
if Resetn = '0' then
    testSusp <= (others => '0');
    testIV <= x"00e0d0c0b0a090807060504000000002";
-- update IV
elsif rising_edge(Clock) then
    if WrEn = '1' then
        if WrAddr = std_logic_vector(to_unsigned(ADDR_IVR0, ADDR_WIDTH)) then
            testIV <= WrData;
        elsif WrAddr = std_logic_vector(to_unsigned(ADDR_SUSPR0, ADDR_WIDTH)) then
            testSusp <= WrData;
        elsif WrAddr = std_logic_vector(to_unsigned(ADDR_HR0, ADDR_WIDTH)) then
            H <= WrData;   
        end if;
     end if;
     if GCMPhase = GCM_PHASE_FINAL then
        testIV <=  x"00e0d0c0b0a090807060504000000001";
     end if;
end if;
end process;

end architecture;
