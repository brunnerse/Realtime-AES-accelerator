----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05.08.2022 16:38:31
-- Design Name: 
-- Module Name: AEA_Round - Behavioral
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
--use IEEE.NUMERIC_STD.ALL;


entity AEA_Round is
    Port ( dIn : in block_t;
           dOut : out block_t;
           roundKey : in block_t;
           encrypt : in STD_LOGIC;
           skipMixColumns : in STD_LOGIC;
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           IsLastCycle : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Resetn : in STD_LOGIC);
end entity;

architecture Structural of AEA_Round is

signal dInARK, dInMC, dInSB, dInSR : block_t;
signal dOutARK, dOutMC, dOutSB, dOutSR : block_t;
signal EnIARK, EnIMC, EnISB, EnISR : std_logic;
signal EnOARK, EnOMC, EnOSB, EnOSR : std_logic;

begin

roundSB : entity work.SubBytes
             port map(dIn => dInSB, dOut => dOutSB, encrypt => encrypt,
                      EnI => EnISB, EnO => EnOSB, Clock => Clock, Resetn => Resetn);
roundSR : entity work.ShiftRows
             generic map(synchronous => false)
             port map(dIn => dInSR, dOut => dOutSR, encrypt => encrypt,
                      EnI => EnISR, EnO => EnOSR, Clock => Clock, Resetn => Resetn);
roundMC : entity work.MixColumns
             port map(dIn => dInMC, dOut => dOutMC, encrypt => encrypt,
                      EnI => EnIMC, EnO => EnOMC, Clock => Clock, Resetn => Resetn);
roundARK : entity work.AddRoundKey
             port map(dIn => dInARK, dOut => dOutARK, roundKey => roundKey,
                      EnI => EnIARK, EnO => EnOARK, Clock => Clock, Resetn => Resetn);

-- TODO restructure: process (all) 

-- Define data between the components; for decryption, the order is reversed
-- Left side is encryption, right side is decryption
dInSB <= dIn when encrypt = '1' else        dOutSR;
dInSR <= dOutSB when encrypt = '1' else     
                                            dOutMC when skipMixColumns = '0' else
                                            dOutARK; -- skip MixColumns in the last round
dInMC <= dOutSR when encrypt = '1' else     dOutARK;
dInARK <=                                   dIn when encrypt = '0' else 
    dOutMC when skipMixColumns = '0' else
    dOutSR; -- 
dOut <= dOutARK when encrypt = '1' else     dOutSB;

-- Define the enable signal connections between the components in the same scheme
EnISB <= EnI when encrypt = '1' else        EnOSR;
EnISR <= EnOSB when encrypt = '1' else     
                                            EnOMC when skipMixColumns = '0' else
                                            EnOARK; -- skip MixColumns in the last round
EnIMC <= '0' when skipMixColumns = '1' else
          EnOSR when encrypt = '1' else     EnOARK;
EnIARK <=                                   EnI when encrypt = '0' else 
          EnOMC when skipMixColumns = '0' else
          EnOSR; -- Skip MixColumns in the last round
EnO <= EnOARK when encrypt = '1' else     EnOSB;

isLastCycle <= ENIARK when encrypt = '1' else       -- For encryption, the last component is ARK
                                            EnISB;  -- For decryption, the last component is SubBytes



end architecture;
