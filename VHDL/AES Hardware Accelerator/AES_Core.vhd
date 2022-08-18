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


function incrementIV(IV : std_logic_vector(KEY_SIZE-1 downto 0)) return std_logic_vector is
begin
    return IV(KEY_SIZE-1 downto 32) & std_logic_vector(unsigned(IV(31 downto 0)) + to_unsigned(1,32));
end function;


-- signal definitions
signal dInAEA, dOutAEA, dInXOR1, dInXOR2, dOutXOR : std_logic_vector(KEY_SIZE-1 downto 0);
signal encryptAEA, EnIAEA, EnOAEA, keyExpandFlagAEA, EnIXOR, EnOXOR : std_logic;



begin

algorithm : PipelinedAEA port map (dInaEA, dOutAEA, Key, encryptAEA, keyExpandFlagAEA, EnIAEA, EnOAEA, Clock, Resetn);
-- Use an AddRoundKey unit as XOR
xorUnit : AddRoundKey port map(dInXOR1, dOutXOR, dInXOR2, EnIXOR, EnOXOR, Clock, Resetn);


-- Set encrypt and keyExpandFlag signals according to the mode
encryptAEA <= not mode(1) when chaining_mode /= CHAINING_MODE_CTR else
            '1'; -- always encrypt in CTR mode
keyExpandFlagAEA <= mode(0) when chaining_mode /= CHAINING_MODE_CTR else
            '0'; -- never key expand in CTR mode


dInAEA <=   dOutXOR when chaining_mode = CHAINING_MODE_CBC and encryptAEA = '1' else
            IV when chaining_mode = CHAINING_MODE_CTR  else
            dIn;

-- First Input into XOR is always plaintext, except for decryption in CBC mode
dInXOR1 <= dIn when encryptAEA = '1' or chaining_mode /= CHAINING_MODE_CBC else
           dOutAEA;
            
-- Second Input of XOR depends on the mode
with chaining_mode select
    dInXOR2 <=  IV when CHAINING_MODE_CBC,
                dOutAEA when others; -- CHAINING_MODE_CTR; as XOR isn't used for mode ECB, input doesnt matter then
            

dOut <=     dOutXOR when chaining_mode = CHAINING_MODE_CTR or (chaining_mode = CHAINING_MODE_CBC and encryptAEA = '0') else
            dOutAEA; 


-- For CBC mode, during encryption the input of the AEA is the output of XOR, except in KeyExpansion mode
EnIAEA <=   EnOXOR when chaining_mode = CHAINING_MODE_CBC and encryptAEA = '1' and mode /= MODE_KEYEXPANSION else
            EnI;
          
-- TODO this can be simplified by setting the EnIXOR signal anyway and just ignoring the output EnO. Should I do it?
EnIXOR <=   EnI when chaining_mode = CHAINING_MODE_CBC and encryptAEA = '1' else
            EnOAEA when (chaining_mode = CHAINING_MODE_CBC and encryptAEA = '0') or chaining_mode = CHAINING_MODE_CTR else
            '0'; -- XOR unit is unused in other modes
            

EnO <=  EnOXOR when chaining_mode = CHAINING_MODE_CTR or (chaining_mode = CHAINING_MODE_CBC and encryptAEA = '0') else
        EnOAEA; -- CHAINING_MODE_ECB | CHAINING_MODE_CBC
 
-- update IV
newIV <= incrementIV(IV) when chaining_mode =  CHAINING_MODE_CTR else
         dIn when chaining_mode = CHAINING_MODE_CBC and encryptAEA = '0' else -- for decryption in CBC mode
         dOutAEA; -- for encryption in CBC Mode. For ECB it does not matter as the IV isn't used

end Behavioral;
