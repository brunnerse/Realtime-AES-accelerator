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
signal dInPreARK : block_t;
signal dOutPreARK : block_t;
signal EnIPreARK, EnOPreARK : std_logic;

signal EnIRounds, EnORounds : std_logic_vector(AES_NR downto 1);

type block_array_t is array of block_t;

signal dInRounds, dOutRounds : block_array_t(AES_NR downto 1);


begin


-- This only works with pre-generated keys
keyExp : entity work.KeyExpansion
             port map(userKey => key, roundKeys => roundKeys, EnI => EnIKeyExp, EnO => EnOKeyExp,
                      Clock => Clock, Resetn => Resetn);
preARK : entity work.AddRoundKey
             port map(dIn => dInPreARK, dOut => dOutPreARK, roundKey => key(block_t'RANGE),
                      EnI => EnIPreARK, EnO => EnOPreARK, Clock => Clock, Resetn => Resetn);

for r in 1 to AES_NR generate
    entity work.AEA_Round
        port map(dIn => dInRounds(r), dOut => dOutRounds(r), roundKey => roundKeys(r), encrypt => encrypt,
                skipMixColumns => '1' when r = AES_NR else '0',
                EnI => EnIRounds(r), EnO => EnORounds(r), isLastCycle => open,
                Clock => Clock, Resetn => Resetn
        );
    
    if r = 1 then 
        EnIRounds(r) <= EnOPreARK when encrypt = '1' else EnORounds(r+1);
        dInRounds(r) <= dOutPreARK when encrypt = '1' else dOutRounds(r+1);
    elsif r = AES_NR then
        EnIRounds(r) <= EnIRounds(r-1) when encrypt = '1' else 
                        EnI when keyExpandFlag = '0'  -- start decryption immediately
                        else EnOKeyExp; -- when keyExpandFlag is set, start once KeyExpansion is finished
        dInRounds(r) <= dOutRounds(r-1) when encrypt = '1' else dIn;
    else
        EnIRounds(r) <= EnORounds(r-1) when encrypt = '1' else EnORounds(r+1);
        dInRounds(r) <= dOutRounds(r-1) when encrypt = '1' else dOutRounds(r+1);
    end if;

       
end generate;       

-- connect KeyExpansion so it runs when the enable signal comes in
-- for encryption, it runs parallel to it, for decryption+keyexpansion mode, it runs before it
-- Key Expansion runs even in Decryption mode for simplicity; wouldn't be necessary, but doesn't change the result
EnIKeyExp <= EnI;

-- connect enable signals
EnIPreARK <= '0' when encrypt = '1' and keyExpandFlag = '1' else -- KeyExpansion mode
            EnI when encrypt = '1' else -- Encryption mode
            EnORounds(1); -- Decryption mode
dInPreARK <= dIn when encrypt = '1' else dOutRounds(1);

EnO <= EnORounds(AES_NR) when encrypt = '1' and keyExpandFlag = '0' else -- encryption mode
       EnOPreARK when encrypt = '0'  else  -- decryption
       EnOKeyExp; -- KeyExpansion mode
dOut <= dOutRounds(AES_NR) when encrypt = '1' else dOutPreARK;




end architecture;
