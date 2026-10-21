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
end entity;

architecture Behavioral of TestAESCore is

component AES_Core is
     generic (
        ADDR_IV : integer;
        ADDR_SUSP : integer;
        ADDR_H  : integer
        );
    Port ( Key : in key_t;
           IV : in block_t;
           H  : in block_t;
           Susp : in block_t;
           WrEn   : out STD_LOGIC;
           WrAddr : out STD_LOGIC_VECTOR(ADDR_REGISTER_BITS-1 downto 0);
           WrData : out block_t;
           dIn : in block_t;
           dOut : out block_t;
           EnI : in std_logic;
           EnO : out std_logic;
           mode : in mode_t; 
           chaining_mode : in mode_t; 
           GCMPhase : in mode_t; 
           Clock : in std_logic;
           Resetn : in std_logic
           );
end component;


-- Test mode and chaining_mode for the AES Core
signal mode : mode_t := MODE_KEYEXPANSION_AND_DECRYPTION;
signal chaining_mode : mode_t := CHAINING_MODE_ECB;


constant key : key_t := x"000102030405060708090a0b0c0d0e0f";
constant plaintext1 : block_t := x"00102030011121310212223203132333";
constant plaintext2 : block_t := x"000102030405060708090a0b0c0d0e0f";
constant plaintext3 : block_t := x"affedeadbeefdadcabbeadbeec0cabad";



signal Clock : std_logic := '1';
signal Resetn : std_logic := '0';

signal testPlaintext, testIV, IV, testCiphertext, Susp, H : block_t;
signal testKey : key_t;
signal EnCoreI, EnCoreO : std_logic;

signal WrEn : std_logic;
signal WrData : block_t;
signal WrAddr  : std_logic_vector(ADDR_REGISTER_BITS-1 downto 0);


begin


testKey <= key;


-- Set GCM signals H, Susp and GCMPhase to dummy values
core: AES_Core 
    generic map(ADDR_IV => ADDR_IVR0, ADDR_SUSP => ADDR_SUSPR0, ADDR_H => ADDR_HR0)
    port map (testKey, testIV, H, Susp, WrEn, WrAddr, WrData, testPlaintext, testCiphertext, EnCoreI, EnCoreO, mode, chaining_mode, "00", Clock, Resetn);


-- processes for Clock and reset signal
Clock <= not Clock after 5 ns;
process begin
wait for 10  ns;
Resetn <= '1'; wait;
end process;


process begin
    wait until rising_edge(Clock);
    if EnCoreI = '1' then
        report "Started AES with input " & to_hstring(testPlaintext);
    end if;
    if EnCoreO = '1' then
        report "AES finished with output " & to_hstring(testCiphertext);
    end if;
end process;

-- Enable encryption three times
process begin
EnCoreI <= '0'; 
wait for 50 ns; -- Wait until Resetn is over
EnCoreI <= '1'; 
testPlaintext <= plaintext1;
testIV <= IV;
wait until EnCoreO = '1';
wait for 10  ns;
EnCoreI <= '0';
wait for 1000  ns; -- Wait at least until key expansion is finished is over
EnCoreI <= '1';
testIV <= IV; 
testPlaintext <= plaintext2;
wait for 10  ns;
EnCoreI <= '0';
wait for 1000  ns; -- Wait at least until key expansion is finished is over
EnCoreI <= '1';
testIV <= IV; 
testPlaintext <= plaintext3;
wait for 10  ns;
EnCoreI <= '0'; 
wait;
end process;

-- process to update the IV
process (all) 
begin
-- initialize IV
if Resetn = '0' then
    if chaining_mode = CHAINING_MODE_CTR then
        IV <= x"00e0d0c0b0a090807060504000000000";
    else
        IV <= x"00e0d0c0b0a090807060504030201000";
    end if;
-- update IV
elsif rising_edge(Clock) then
    if WrEn = '1' and WrAddr = std_logic_vector(to_unsigned(ADDR_IVR0, ADDR_WIDTH)) then
        IV <= WrData;
     end if;
end if;
end process;

end architecture;
