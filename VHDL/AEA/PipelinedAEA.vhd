----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 10.08.2022 10:49:12
-- Design Name: 
-- Module Name: PipelinedAEA - Behavioral
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
use work.sbox_definition.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

entity PipelinedAEA is
    Port ( dIn : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dOut : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           key : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           encrypt : in STD_LOGIC;
           -- for encrypt = 1, keyExpandFlag = 1 means just keyExpansion, for encrypt = 0, keyExpandFlag=0 means no KeyExpansion
           keyExpandFlag : in STD_LOGIC; 
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Resetn : in STD_LOGIC);
end PipelinedAEA;

architecture Behavioral of PipelinedAEA is

component AddRoundKey is
    Port ( din : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dout : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           key : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Resetn : in STD_LOGIC);
end component;

component AEA_Round is
    Port ( dIn : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dOut : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           key : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           encrypt : in STD_LOGIC;
           isLastRound : in STD_LOGIC;
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           IsLastCycle : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Resetn : in STD_LOGIC);
end component;

component KeyExpansion is
    Port ( userKey : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           roundKeys : out ROUNDKEYARRAY;
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Resetn : in STD_LOGIC);
end component;


signal roundKeys : ROUNDKEYARRAY;
signal EnIKeyExp, EnOKeyExp : std_logic;

-- connection signals
signal dInPreARK, dInRound1, dInRound2, dInRound3, dInRound4, dInRound5 : std_logic_vector(KEY_SIZE-1 downto 0);
signal dInRound6, dInRound7, dInRound8, dInRound9, dInRound10 : std_logic_vector(KEY_SIZE-1 downto 0);
signal dOutPreARK, dOutRound1, dOutRound2, dOutRound3, dOutRound4, dOutRound5 : std_logic_vector(KEY_SIZE-1 downto 0);
signal dOutRound6, dOutRound7, dOutRound8, dOutRound9, dOutRound10 : std_logic_vector(KEY_SIZE-1 downto 0);
signal EnIPreARK, EnIRound1, EnIRound2, EnIRound3, EnIRound4, EnIRound5, EnIRound6, EnIRound7, EnIRound8, EnIRound9, EnIRound10 : std_logic;
signal EnOPreARK, EnORound1, EnORound2, EnORound3, EnORound4, EnORound5, EnORound6, EnORound7, EnORound8, EnORound9, EnORound10 : std_logic;


begin
keyExp : KeyExpansion port map(key, roundKeys, EnIKeyExp, EnOKeyExp, Clock, Resetn); 
preARK : AddRoundKey port map(dInPreARK, dOutPreARK, key, EnIPreARK, EnOPreARK, Clock, Resetn);
roundAEA1 : AEA_Round port map(dInRound1, dOutRound1, roundKeys(1), encrypt, '0', EnIRound1, EnORound1, Clock=>Clock, Resetn=>Resetn);
roundAEA2 : AEA_Round port map(dInRound2, dOutRound2, roundKeys(2), encrypt, '0', EnIRound2, EnORound2, Clock=>Clock, Resetn=>Resetn);
roundAEA3 : AEA_Round port map(dInRound3, dOutRound3, roundKeys(3), encrypt, '0', EnIRound3, EnORound3, Clock=>Clock, Resetn=>Resetn);
roundAEA4 : AEA_Round port map(dInRound4, dOutRound4, roundKeys(4), encrypt, '0', EnIRound4, EnORound4, Clock=>Clock, Resetn=>Resetn);
roundAEA5 : AEA_Round port map(dInRound5, dOutRound5, roundKeys(5), encrypt, '0', EnIRound5, EnORound5, Clock=>Clock, Resetn=>Resetn);
roundAEA6 : AEA_Round port map(dInRound6, dOutRound6, roundKeys(6), encrypt, '0', EnIRound6, EnORound6, Clock=>Clock, Resetn=>Resetn);
roundAEA7 : AEA_Round port map(dInRound7, dOutRound7, roundKeys(7), encrypt, '0', EnIRound7, EnORound7, Clock=>Clock, Resetn=>Resetn);
roundAEA8 : AEA_Round port map(dInRound8, dOutRound8, roundKeys(8), encrypt, '0', EnIRound8, EnORound8, Clock=>Clock, Resetn=>Resetn);
roundAEA9 : AEA_Round port map(dInRound9, dOutRound9, roundKeys(9), encrypt, '0', EnIRound9, EnORound9, Clock=>Clock, Resetn=>Resetn);
roundAEA10 : AEA_Round port map(dInRound10, dOutRound10, roundKeys(10), encrypt, '1', EnIRound10, EnORound10, Clock=>Clock, Resetn=>Resetn);


-- connect KeyExpansion so it runs when the enable signal comes in
-- for encryption, it runs parallel to it, for decryption, it runs before it (or doesnt run for keyExpandFlag=0)
-- Key Expansion does not run for encrypt=0 and keyExpandFlag=0
-- TODO can it run anyway? The expanded keys shouldn't change
EnIKeyExp <= EnI when encrypt='1' or keyExpandFlag = '1' else 
            '0';


-- connect data signals
dInPreARK <= dIn when encrypt = '1'            else dOutRound1;
dInRound1 <= dOutPreARK when encrypt = '1'     else dOutRound2;
dInRound2 <= dOutRound1 when encrypt = '1'     else dOutRound3;
dInRound3 <= dOutRound2 when encrypt = '1'     else dOutRound4;
dInRound4 <= dOutRound3 when encrypt = '1'     else dOutRound5;
dInRound5 <= dOutRound4 when encrypt = '1'     else dOutRound6;
dInRound6 <= dOutRound5 when encrypt = '1'     else dOutRound7;
dInRound7 <= dOutRound6 when encrypt = '1'     else dOutRound8;
dInRound8 <= dOutRound7 when encrypt = '1'     else dOutRound9;
dInRound9 <= dOutRound8 when encrypt = '1'     else dOutRound10;
dInRound10 <= dOutRound9 when encrypt = '1'    else dIn;
dOut <= dOutRound10 when encrypt = '1'         else dOutPreARK;


-- connect enable signals
EnIPreARK <= '0' when encrypt = '1' and keyExpandFlag = '1' else -- KeyExpansion mode
            EnI when encrypt = '1' else -- Encryption mode
            EnORound1; -- Decryption mode


EnIRound1 <= EnOPreARK when encrypt = '1'     else EnORound2;
EnIRound2 <= EnORound1 when encrypt = '1'     else EnORound3;
EnIRound3 <= EnORound2 when encrypt = '1'     else EnORound4;
EnIRound4 <= EnORound3 when encrypt = '1'     else EnORound5;
EnIRound5 <= EnORound4 when encrypt = '1'     else EnORound6;
EnIRound6 <= EnORound5 when encrypt = '1'     else EnORound7;
EnIRound7 <= EnORound6 when encrypt = '1'     else EnORound8;
EnIRound8 <= EnORound7 when encrypt = '1'     else EnORound9;
EnIRound9 <= EnORound8 when encrypt = '1'     else EnORound10;
EnIRound10 <= EnORound9 when encrypt = '1'    else 
              EnOKeyExp when keyExpandFlag = '1' else -- in decryption+keyexpansion mode, wait until all keys have been calculated
              EnI; -- in decryption mode, start immediately  
              

EnO <= EnORound10 when encrypt = '1' and keyExpandFlag = '0' else -- encryption mode
       EnOPreARK when encrypt = '0'  else  -- decryption
       EnOKeyExp ; -- KeyExpansion mode




end Behavioral;
