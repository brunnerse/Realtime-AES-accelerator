----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03.08.2022 21:58:39
-- Design Name: 
-- Module Name: TestAEA - Behavioral
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

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity TestAEA is
--  Port ( );
end TestAEA;

architecture Behavioral of TestAEA is

component PipelinedAEA is
    Port ( dIn : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dOut : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           key : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           encrypt : in STD_LOGIC;
           keyExpandFlag : in STD_LOGIC; 
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Resetn : in STD_LOGIC);
end component;

component AEA is
    Port ( dIn : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dOut : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           key : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           encrypt : in STD_LOGIC;
           keyExpandFlag : in STD_LOGIC; 
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Resetn : in STD_LOGIC);
end component;

component AES_Core is
    Port ( Key : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           IV : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dIn : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dOut : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           --SaveRestore : inout std_logic;
           EnI : in std_logic;
           EnO : out std_logic;
           mode : in std_logic_vector (1 downto 0);
           chaining_mode : in std_logic_vector (2 downto 0);
           Clock : in std_logic;
           Resetn : in std_logic
           );
end component;

signal Clock, Resetn : std_logic;

signal testPlaintext, testKey, testCiphertext, testDecCiphertext : std_logic_vector(KEY_SIZE-1 downto 0);
signal EnEncI, EnEncO, EnDecI, EnDecO : std_logic;

signal keyExpandFlagEnc, keyExpandFlagDec : std_logic;

begin


--testPlaintext <= x"00102030011121310212223203132333";
testKey <= x"000102030405060708090a0b0c0d0e0f";

aeaEnc : AEA port map (testPlaintext, testCiphertext, testKey, '1', keyExpandFlagEnc, EnEncI, EnEncO, Clock, Resetn);
aeaDec : AEA port map (testCiphertext, testDecCiphertext, testKey, '0', keyExpandFlagDec, EnDecI, EnDecO, Clock, Resetn);

EnDecI <= EnEncO;


process begin
Clock <= '1'; wait for 5 ns;
Clock <= '0'; wait for 5 ns;
end process;
process begin
report "Starting";
Resetn <= '0'; wait for 20 ns;
report "Deactivating reset...";
Resetn <= '1'; wait;
end process;

process begin
keyExpandFlagEnc <= '0';
keyExpandFlagDec <= '1';
wait for 150 ns;
report "Time is " & time'image(now);
wait;
end process;

-- Enable encryption once at the start, then disable it
process begin
EnEncI <= '0'; wait for 50 ns; -- Wait until Resetn is over
EnEncI <= '1'; 
testPlaintext <= x"00102030011121310212223203132333";
wait for 10 ns;
EnEncI <= '0'; wait for 110 ns; -- Wait until Resetn is over
wait;
EnEncI <= '1'; 
testPlaintext <= x"affedeadbeefdadcabbeadbeec0cabad";
wait for 10 ns;
EnEncI <= '0'; wait;
end process;


end Behavioral;
