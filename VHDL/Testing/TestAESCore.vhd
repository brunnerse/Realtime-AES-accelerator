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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;


entity TestAESCore is
--  Port ( );
end TestAESCore;

architecture Behavioral of TestAESCore is

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

signal testPlaintext, testIV, testKey, testCiphertext, testDecCiphertext, newIV, Susp, H : std_logic_vector(KEY_SIZE-1 downto 0);
signal EnCoreI, EnCoreO : std_logic;

signal mode : std_logic_vector(1 downto 0);
signal chaining_mode : std_logic_vector(2 downto 0);

begin


--testPlaintext <= x"00102030011121310212223203132333";
testKey <= x"000102030405060708090a0b0c0d0e0f";

mode <= MODE_ENCRYPTION;
chaining_mode <= CHAINING_MODE_CBC;

-- Set GCM signals H, Susp and GCMPhase to dummy values
core: AES_Core port map (testKey, testIV, newIV, H, H, Susp, Susp, testPlaintext, testCiphertext, EnCoreI, EnCoreO, mode, chaining_mode, "00", Clock, Resetn);

process begin
Clock <= '1'; wait for 5 ns;
Clock <= '0'; wait for 5 ns;
end process;
process begin
Resetn <= '0'; wait for 10 ns;
Resetn <= '1'; wait;
end process;



-- Enable encryption three times
process begin
EnCoreI <= '0'; wait for 10 ns; -- Wait until Resetn is over
EnCoreI <= '1'; 
testPlaintext <= x"00102030011121310212223203132333";
wait for 10 ns;
EnCoreI <= '0';
wait for 1000 ns; -- Wait at least until key expansion is finished is over
EnCoreI <= '1'; 
testPlaintext <= testKey;
wait for 10 ns;
EnCoreI <= '0';
wait for 1000 ns; -- Wait at least until key expansion is finished is over
EnCoreI <= '1'; 
testPlaintext <= x"affedeadbeefdadcabbeadbeec0cabad";
wait for 10 ns;
EnCoreI <= '0'; 
wait;
end process;

-- process to update the IV
process (EnCoreO, Resetn) 
begin
-- initialize IV
if Resetn = '0' then
    if chaining_mode = CHAINING_MODE_CTR then
        testIV <= x"f0e0d0c0b0a090807060504000000000";
    else
        testIV <= x"f0e0d0c0b0a090807060504030201000";
    end if;
 end if;
-- update IV
if EnCoreO = '1' then
    testIV <= newIV;
end if;
end process;

end Behavioral;
