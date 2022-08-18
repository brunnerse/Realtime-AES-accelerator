----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 28.07.2022 01:09:13
-- Design Name: 
-- Module Name: AES_Core - Behavioral
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
use IEEE.std_logic_1164.ALL;
use work.common.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;


entity AES_Core is
    Port ( Key : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           IV : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dIn : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dOut : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           newIV : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           --SaveRestore : inout std_logic;
           EnI : in std_logic;
           EnO : out std_logic;
           mode : in std_logic_vector (1 downto 0);
           chaining_mode : in std_logic_vector (2 downto 0);
           Clock : in std_logic;
           Resetn : in std_logic
           );
end AES_Core;

architecture Behavioral of AES_Core is

component AddRoundKey is
    Port ( din : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dout : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           key : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Resetn : in STD_LOGIC);
end component;

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

-- signal definitions
signal dInAEA, dOutAEA, dInXOR1, dInXOR2, dOutXOR : std_logic_vector(KEY_SIZE-1 downto 0);
signal encryptAEA, EnIAEA, EnOAEA, keyExpandFlagAEA, EnIXOR, EnOXOR : std_logic;

begin

algorithm : PipelinedAEA port map (dInaEA, dOutAEA, Key, encryptAEA, keyExpandFlagAEA, EnIAEA, EnOAEA, Clock, Resetn);
-- Use an AddRoundKey unit as XOR
xorUnit : AddRoundKey port map(dInXOR1, dOutXOR, dInXOR2, EnIXOR, EnOXOR, Clock, Resetn);



encryptAEA <= not mode(1);
keyExpandFlagAEA <= mode(0);

with chaining_mode select
    dInAEA <=   dOutXOR when CHAINING_MODE_CBC,
                IV when CHAINING_MODE_CTR,
                dIn when others; -- CHAINING_MODE_ECB

-- First Input into XOR is always plaintext in any mode
dInXOR1 <= dIn;
-- Second Input of XOR depends on the mode
with chaining_mode select
    dInXOR2 <=  IV when CHAINING_MODE_CBC,
                dOutAEA when others; -- CHAINING_MODE_CTR; as XOR isn't used for mode ECB, input doesnt matter then
            
with chaining_mode select
    dOut <=     dOutXOR when CHAINING_MODE_CTR,
                dOutAEA when others; -- CHAINING_MODE_ECB | CHAINING_MODE_CBC

with chaining_mode select
    EnIAEA <=   EnOXOR when CHAINING_MODE_CBC,
                EnI when others; -- CHAINING_MODE_ECB | CHAINING_MODE_CTR
          
with chaining_mode select
    EnIXOR <=   EnI when CHAINING_MODE_CBC,
                EnOAEA when CHAINING_MODE_CTR,
                '0' when others; -- CHAINING_MODE_ECB
            
with chaining_mode select
    EnO <=  EnOXOR when CHAINING_MODE_CTR,
            EnOAEA when others; -- CHAINING_MODE_ECB | CHAINING_MODE_CBC
 
-- update IV
with chaining_mode select
    newIV <= IV(KEY_SIZE-1 downto 32) & std_logic_vector(unsigned(IV(31 downto 0)) + to_unsigned(1,32)) when CHAINING_MODE_CTR,
             dOutAEA when others; -- CHAINING_MODE_CBC; ECB doesn't matter as the IV isn't used for that mode

end Behavioral;
