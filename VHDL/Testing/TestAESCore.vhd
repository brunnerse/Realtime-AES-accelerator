----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03.08.2022 21:58:39
-- Design Name: 
-- Module Name: TestAESCore - Behavioral
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
use work.addresses.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;


entity TestAESCore is
--  Port ( );
end TestAESCore;

architecture Behavioral of TestAESCore is

component AES_Core is
     generic (
        ADDR_IV : integer;
        ADDR_SUSP : integer;
        ADDR_H  : integer
        );
    Port ( Key : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           IV : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           H  : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           Susp : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           WrEn   : out STD_LOGIC;
           WrAddr : out STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
           WrData : out STD_LOGIC_VECTOR(KEY_SIZE-1 downto 0);
           dIn : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dOut : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           EnI : in std_logic;
           EnO : out std_logic;
           mode : in std_logic_vector (MODE_LEN-1 downto 0);
           chaining_mode : in std_logic_vector (CHMODE_LEN-1 downto 0);
           GCMPhase : in std_logic_vector(1 downto 0);
           Clock : in std_logic;
           Resetn : in std_logic
           );
end component;

constant key : std_logic_vector(KEY_SIZE-1 downto 0) := x"000102030405060708090a0b0c0d0e0f";
constant plaintext1 : std_logic_vector(KEY_SIZE-1 downto 0) := x"00102030011121310212223203132333";
constant plaintext2 : std_logic_vector(KEY_SIZE-1 downto 0) := x"000102030405060708090a0b0c0d0e0f";
constant plaintext3 : std_logic_vector(KEY_SIZE-1 downto 0) := x"affedeadbeefdadcabbeadbeec0cabad";

signal Clock : std_logic := '1';
signal Resetn : std_logic := '0';

signal testPlaintext, testIV, testKey, testCiphertext, testDecCiphertext, newIV, Susp, H : std_logic_vector(KEY_SIZE-1 downto 0);
signal EnCoreI, EnCoreO : std_logic;

signal WrEn : std_logic;
signal WrData : std_logic_vector(KEY_SIZE-1 downto 0);
signal WrAddr  : std_logic_vector(ADDR_WIDTH-1 downto 0);

signal mode : std_logic_vector(MODE_LEN-1 downto 0) := MODE_ENCRYPTION;
signal chaining_mode : std_logic_vector(CHMODE_LEN-1 downto 0) := CHAINING_MODE_CBC;

begin


testKey <= key;


-- Set GCM signals H, Susp and GCMPhase to dummy values
core: AES_Core 
    generic map(ADDR_IV => ADDR_IVR0, ADDR_SUSP => ADDR_SUSPR0, ADDR_H => ADDR_HR0)
    port map (testKey, testIV, H, Susp, WrEn, WrAddr, WrData, testPlaintext, testCiphertext, EnCoreI, EnCoreO, mode, chaining_mode, "00", Clock, Resetn);


-- processes for Clock and reset signal
Clock <= not Clock after 5ns;
process begin
wait for 10 ns;
Resetn <= '1'; wait;
end process;



-- Enable encryption three times
process begin
EnCoreI <= '0'; wait for 40ns; -- Wait until Resetn is over
EnCoreI <= '1'; 
testPlaintext <= plaintext1;
wait for 10 ns;
EnCoreI <= '0';
wait for 1000 ns; -- Wait at least until key expansion is finished is over
EnCoreI <= '1'; 
testPlaintext <= plaintext2;
wait for 10 ns;
EnCoreI <= '0';
wait for 1000 ns; -- Wait at least until key expansion is finished is over
EnCoreI <= '1'; 
testPlaintext <= plaintext3;
wait for 10 ns;
EnCoreI <= '0'; 
wait;
end process;

-- process to update the IV
process (Resetn, Clock, WrEn) 
begin
-- initialize IV
if Resetn = '0' then
    if chaining_mode = CHAINING_MODE_CTR then
        testIV <= x"f0e0d0c0b0a090807060504000000000";
    else
        testIV <= x"f0e0d0c0b0a090807060504030201000";
    end if;
-- update IV
elsif rising_edge(Clock) then
    if WrEn = '1' and WrAddr = std_logic_vector(to_unsigned(ADDR_IVR0, ADDR_WIDTH)) then
        testIV <= WrData;
     end if;
end if;
end process;

end Behavioral;
