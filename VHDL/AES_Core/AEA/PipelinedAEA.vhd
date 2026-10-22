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
    Port ( dIn : in block_t;
           dOut : out block_t;
           key : in key_t;
           encrypt : in STD_LOGIC;
           -- for encrypt = 1, keyExpandFlag = 1 means just keyExpansion, for encrypt = 0, keyExpandFlag=0 means no KeyExpansion
           keyExpandFlag : in STD_LOGIC; 
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Resetn : in STD_LOGIC);
end entity;

architecture Structural of PipelinedAEA is

signal roundKeys : ROUNDKEYARRAY;
signal EnIKeyExp, EnOKeyExp : std_logic;

-- connection signals
signal dInPreARK, dInRound1, dInRound2, dInRound3, dInRound4, dInRound5 : block_t;
signal dInRound6, dInRound7, dInRound8, dInRound9, dInRound10 : block_t;
signal dOutPreARK, dOutRound1, dOutRound2, dOutRound3, dOutRound4, dOutRound5 : block_t;
signal dOutRound6, dOutRound7, dOutRound8, dOutRound9, dOutRound10 : block_t;
signal EnIPreARK, EnIRound1, EnIRound2, EnIRound3, EnIRound4, EnIRound5, EnIRound6, EnIRound7, EnIRound8, EnIRound9, EnIRound10 : std_logic;
signal EnOPreARK, EnORound1, EnORound2, EnORound3, EnORound4, EnORound5, EnORound6, EnORound7, EnORound8, EnORound9, EnORound10 : std_logic;


begin
keyExp : entity work.KeyExpansion
             port map(userKey => key, roundKeys => roundKeys, EnI => EnIKeyExp, EnO => EnOKeyExp,
                      Clock => Clock, Resetn => Resetn);
 TODO: generate loop
preARK : entity work.AddRoundKey
             port map(dIn => dInPreARK, dOut => dOutPreARK, roundKey => key(block_t'RANGE),
                      EnI => EnIPreARK, EnO => EnOPreARK, Clock => Clock, Resetn => Resetn);
roundAEA1 : entity work.AEA_Round
             port map(dIn => dInRound1, dOut => dOutRound1, roundKey => roundKeys(1), encrypt => encrypt,
                      skipMixColumns => '0', EnI => EnIRound1, EnO => EnORound1, IsLastCycle => open,
                      Clock => Clock, Resetn => Resetn);
roundAEA2 : entity work.AEA_Round
             port map(dIn => dInRound2, dOut => dOutRound2, roundKey => roundKeys(2), encrypt => encrypt,
                      skipMixColumns => '0', EnI => EnIRound2, EnO => EnORound2, IsLastCycle => open,
                      Clock => Clock, Resetn => Resetn);
roundAEA3 : entity work.AEA_Round
             port map(dIn => dInRound3, dOut => dOutRound3, roundKey => roundKeys(3), encrypt => encrypt,
                      skipMixColumns => '0', EnI => EnIRound3, EnO => EnORound3, IsLastCycle => open,
                      Clock => Clock, Resetn => Resetn);
roundAEA4 : entity work.AEA_Round
             port map(dIn => dInRound4, dOut => dOutRound4, roundKey => roundKeys(4), encrypt => encrypt,
                      skipMixColumns => '0', EnI => EnIRound4, EnO => EnORound4, IsLastCycle => open,
                      Clock => Clock, Resetn => Resetn);
roundAEA5 : entity work.AEA_Round
             port map(dIn => dInRound5, dOut => dOutRound5, roundKey => roundKeys(5), encrypt => encrypt,
                      skipMixColumns => '0', EnI => EnIRound5, EnO => EnORound5, IsLastCycle => open,
                      Clock => Clock, Resetn => Resetn);
roundAEA6 : entity work.AEA_Round
             port map(dIn => dInRound6, dOut => dOutRound6, roundKey => roundKeys(6), encrypt => encrypt,
                      skipMixColumns => '0', EnI => EnIRound6, EnO => EnORound6, IsLastCycle => open,
                      Clock => Clock, Resetn => Resetn);
roundAEA7 : entity work.AEA_Round
             port map(dIn => dInRound7, dOut => dOutRound7, roundKey => roundKeys(7), encrypt => encrypt,
                      skipMixColumns => '0', EnI => EnIRound7, EnO => EnORound7, IsLastCycle => open,
                      Clock => Clock, Resetn => Resetn);
roundAEA8 : entity work.AEA_Round
             port map(dIn => dInRound8, dOut => dOutRound8, roundKey => roundKeys(8), encrypt => encrypt,
                      skipMixColumns => '0', EnI => EnIRound8, EnO => EnORound8, IsLastCycle => open,
                      Clock => Clock, Resetn => Resetn);
roundAEA9 : entity work.AEA_Round
             port map(dIn => dInRound9, dOut => dOutRound9, roundKey => roundKeys(9), encrypt => encrypt,
                      skipMixColumns => '0', EnI => EnIRound9, EnO => EnORound9, IsLastCycle => open,
                      Clock => Clock, Resetn => Resetn);
roundAEA10 : entity work.AEA_Round
             port map(dIn => dInRound10, dOut => dOutRound10, roundKey => roundKeys(10), encrypt => encrypt,
                      skipMixColumns => '1', EnI => EnIRound10, EnO => EnORound10, IsLastCycle => open,
                      Clock => Clock, Resetn => Resetn);


-- connect KeyExpansion so it runs when the enable signal comes in
-- for encryption, it runs parallel to it, for decryption+keyexpansion mode, it runs before it
-- Key Expansion runs even in Decryption mode for simplicity; wouldn't be necessary, but doesn't change the result
EnIKeyExp <= EnI;


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




end architecture;
