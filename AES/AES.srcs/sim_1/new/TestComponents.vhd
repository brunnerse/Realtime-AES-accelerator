----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03.08.2022 21:58:39
-- Design Name: 
-- Module Name: TestComponents - Behavioral
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

entity TestComponents is
--  Port ( );
end TestComponents;

architecture Behavioral of TestComponents is

component AEA is
    Port ( dIn : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dOut : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           key : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           encrypt : in STD_LOGIC;
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Reset : in STD_LOGIC);
end component;

component MixColumns is
    Port ( dIn : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dOut : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           encrypt : in STD_LOGIC;
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Reset : in STD_LOGIC);
end component;

signal Clock, Reset : std_logic;

signal testPlaintext, testKey, testCiphertext, testDecCiphertext : std_logic_vector(KEY_SIZE-1 downto 0);
signal EnEncI, EnEncO, EnDecI, EnDecO : std_logic;

begin

testPlaintext <= x"00102030011121310212223203132333";
testKey <= x"000102030405060708090a0b0c0d0e0f";

aeaEnc : AEA port map (testPlaintext, testCiphertext, testKey, '1', EnEncI, EnEncO, Clock, Reset);
aeaDec : AEA port map (testCiphertext, testDecCiphertext, testKey, '0', EnDecI, EnDecO, Clock, Reset);

EnDecI <= EnEncO;




process begin
Clock <= '0'; wait for 5ns;
Clock <= '1'; wait for 5ns;
end process;
process begin
Reset <= '0'; wait for 10ns;
Reset <= '1'; wait;
end process;

-- Enable encryption once at the start, then disable it
process begin
EnEncI <= '0'; wait for 10ns; -- Wait until Reset is over
EnEncI <= '1'; wait for 10ns;
EnEncI <= '0'; wait;
end process;


end Behavioral;
