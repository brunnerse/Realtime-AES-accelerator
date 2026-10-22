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

-- Define data and enable signal connections between the components; for decryption, the order is reversed
process (all)
begin
if encrypt = '1' then
    -- Encryption: SubBytes -> ShiftRows -> MixColumns -> AddRoundKey
    dInSB <= dIn;
    EnISB <= EnI;

    dInSR <= dOutSB;
    EnISR <= EnOSB;

    EnIMC <= EnOSR;
    dInMC <= dOutSR;

    dInARK <= dOutMC;
    EnIARK <= EnOMC;

    if skipMixColumns = '1' then
        EnIMC <= '-';
        dInARK <= dOutSR;
        EnIARK <= EnOSR;
    end if;

    EnO <= EnOARK;
    dOut <= dOutARK;

    isLastCycle <= EnIARK; -- For encryption, the last component is ARK
else
    -- Decryption: AddRoundKey -> MixColumns -> ShiftRows -> SubBytes
    EnIARK <= EnI;
    dInARK <= dIn;

    EnIMC <= EnOARK;
    dInMC <= dOutARK;

    dInSR <= dOutMC;
    EnISR <= EnOMC;

    if skipMixColumns = '1' then
        EnIMC <= '-';
        dInSR <= dOutARK;
        EnISR <= EnOARK;
    end if;
    dInSB <= dOutSR;
    EnISB <= EnOSR;
    dOut <= dOutSB;
    EnO <= EnOSB;
    isLastCycle <= EnISB; -- For decryption, the last component is SubBytes
end if;
end process;


end architecture;
