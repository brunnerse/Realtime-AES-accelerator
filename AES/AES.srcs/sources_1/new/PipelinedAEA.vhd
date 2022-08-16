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
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Reset : in STD_LOGIC);
end PipelinedAEA;

architecture Behavioral of PipelinedAEA is

component AddRoundKey is
    Port ( din : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dout : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           key : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Reset : in STD_LOGIC);
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
           Reset : in STD_LOGIC);
end component;

component KeyExpansion is
    Port ( userKey : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           roundKeys : out ROUNDKEYARRAY;
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Reset : in STD_LOGIC);
end component;


signal roundKeys : ROUNDKEYARRAY;
signal EnIKeyExp, EnOKeyExp : std_logic;
-- signals for calculating the key on-the-fly TODO needed?
signal encryptKey : std_logic_vector(KEY_SIZE-1 downto 0);
signal Rcon : std_logic_vector(7 downto 0);

-- connection signals
signal dInPreARK, dInRound1, dInRound2, dInRound3, dInRound4, dInRound5 : std_logic_vector(KEY_SIZE-1 downto 0);
signal dInRound6, dInRound7, dInRound8, dInRound9, dInRound10 : std_logic_vector(KEY_SIZE-1 downto 0);
signal dOutPreARK, dOutRound1, dOutRound2, dOutRound3, dOutRound4, dOutRound5 : std_logic_vector(KEY_SIZE-1 downto 0);
signal dOutRound6, dOutRound7, dOutRound8, dOutRound9, dOutRound10 : std_logic_vector(KEY_SIZE-1 downto 0);
signal EnIPreARK, EnIRound1, EnIRound2, EnIRound3, EnIRound4, EnIRound5, EnIRound6, EnIRound7, EnIRound8, EnIRound9, EnIRound10 : std_logic;
signal EnOPreARK, EnORound1, EnORound2, EnORound3, EnORound4, EnORound5, EnORound6, EnORound7, EnORound8, EnORound9, EnORound10 : std_logic;


begin
keyExp : KeyExpansion port map(key, roundKeys, EnIKeyExp, EnOKeyExp, Clock, Reset); 
preARK : AddRoundKey port map(dInPreARK, dOutPreARK, key, EnIPreARK, EnOPreARK, Clock, Reset);
roundAEA1 : AEA_Round port map(dInRound1, dOutRound1, roundKeys(1), encrypt, '0', EnIRound1, EnORound1, Clock=>Clock, Reset=>Reset);
roundAEA2 : AEA_Round port map(dInRound2, dOutRound2, roundKeys(2), encrypt, '0', EnIRound2, EnORound2, Clock=>Clock, Reset=>Reset);
roundAEA3 : AEA_Round port map(dInRound3, dOutRound3, roundKeys(3), encrypt, '0', EnIRound3, EnORound3, Clock=>Clock, Reset=>Reset);
roundAEA4 : AEA_Round port map(dInRound4, dOutRound4, roundKeys(4), encrypt, '0', EnIRound4, EnORound4, Clock=>Clock, Reset=>Reset);
roundAEA5 : AEA_Round port map(dInRound5, dOutRound5, roundKeys(5), encrypt, '0', EnIRound5, EnORound5, Clock=>Clock, Reset=>Reset);
roundAEA6 : AEA_Round port map(dInRound6, dOutRound6, roundKeys(6), encrypt, '0', EnIRound6, EnORound6, Clock=>Clock, Reset=>Reset);
roundAEA7 : AEA_Round port map(dInRound7, dOutRound7, roundKeys(7), encrypt, '0', EnIRound7, EnORound7, Clock=>Clock, Reset=>Reset);
roundAEA8 : AEA_Round port map(dInRound8, dOutRound8, roundKeys(8), encrypt, '0', EnIRound8, EnORound8, Clock=>Clock, Reset=>Reset);
roundAEA9 : AEA_Round port map(dInRound9, dOutRound9, roundKeys(9), encrypt, '0', EnIRound9, EnORound9, Clock=>Clock, Reset=>Reset);
roundAEA10 : AEA_Round port map(dInRound10, dOutRound10, roundKeys(10), encrypt, '1', EnIRound10, EnORound10, Clock=>Clock, Reset=>Reset);


-- connect KeyExpansion so it runs parallel to the rounds when the enable signal comes in
-- TODO only rerun it when the key changes?
EnIKeyExp <= EnI;
    -- '0' when key = roundKeys(0) else
    --   EnI;

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
EnIPreARK <= EnI when encrypt = '1'           else EnORound1;
EnIRound1 <= EnOPreARK when encrypt = '1'     else EnORound2;
EnIRound2 <= EnORound1 when encrypt = '1'     else EnORound3;
EnIRound3 <= EnORound2 when encrypt = '1'     else EnORound4;
EnIRound4 <= EnORound3 when encrypt = '1'     else EnORound5;
EnIRound5 <= EnORound4 when encrypt = '1'     else EnORound6;
EnIRound6 <= EnORound5 when encrypt = '1'     else EnORound7;
EnIRound7 <= EnORound6 when encrypt = '1'     else EnORound8;
EnIRound8 <= EnORound7 when encrypt = '1'     else EnORound9;
EnIRound9 <= EnORound8 when encrypt = '1'     else EnORound10;
EnIRound10 <= EnORound9 when encrypt = '1'    else EnOKeyExp;  -- for decryption, wait until all keys have been calculated
EnO <= EnORound10 when encrypt = '1'          else EnOPreARK;




end Behavioral;