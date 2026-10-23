----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05.08.2022 17:11:11
-- Design Name: 
-- Module Name: AEA - Behavioral
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
use IEEE.NUMERIC_STD.ALL;
use work.common.ALL;

entity AEA is
    Port ( 
       dIn : in block_t; 
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

architecture RTL of AEA is


type state_t is (Idle, Init, OnlyKeyExp, Rounds);

signal currentRound : integer range 1 to AES_NR; -- TODO replace with unsigned
signal state : state_t;

-- signals to connect the components
signal dInPreARK, dInRound, roundKey : block_t;
signal dOutPreARK, dOutRound : block_t;
signal EnIPreARK, EnIRound : std_logic;
signal EnOPreARK, EnORound : std_logic;
signal roundSkipMixColumns, roundIsLastCycle : std_logic;

-- signals for the KeyExpansion, which is only used for decryption
signal keyexpInit, keyexpCalcNextKey, keyexpReverse : std_logic;


begin


preARK : entity work.AddRoundKey
             port map(dIn => dInPreARK, 
                      dOut => dOutPreARK, 
                      roundKey => key(key'LENGTH-1 downto key'LENGTH - AES_BLOCK_SIZE), 
                      EnI => EnIPreARK, EnO => EnOPreARK, 
                      Clock => Clock, Resetn => Resetn
                    );

roundAEA : entity work.AEA_Round
             port map(dIn => dInRound, dOut => dOutRound, roundKey => roundKey, 
                encrypt => encrypt, skipMixColumns => roundSkipMixColumns, 
                EnI => EnIRound, EnO => EnORound, isLastCycle => roundIsLastCycle, 
                Clock => Clock, Resetn => Resetn);

keyExp : entity work.KeyExpansion
             port map(userKey => key, init => keyexpInit, 
                reverse => keyexpReverse, calcNextRoundKey => keyexpCalcNextKey,
                roundKey => roundKey, 
                Clock => Clock, Resetn => Resetn);


--------------------------------
-- Connect chain of enable signals

process (all)
begin
    if encrypt = '1' then
        dInPreARK <= dIn;
        dInRound <= dOutPreARK;
        dOut <= dOutRound;

        EnIPreArk <= EnI;
        EnIRound <= EnOPreArk;

        if keyExpandFlag = '1' then
            EnO <= '0'; -- TODO 
        else
            EnO <= EnORound;
        end if;
    else
        dInRound <= dIn;
        dInPreARK <= dOutRound;
        dOut <= dOutPreARK;

        if keyExpandFlag = '1' then
            EnIRound <= '0'; -- TODO: start round when last round key is calculated
        else
            EnIRound <= EnI; -- Decryption mode: start round immediately
        end if;

        EnIPreArk <= EnORound; -- when state = Idle else '0'; -- TODO can remove this; doesnt matter if PreArk runs after every round, not just the last

        EnO <= EnOPreArk; -- Output of the last component in the chain is the output of the whole module
    end if;

    if state = Rounds then
        dInRound <= dOutRound;  -- loop  back the output of the round to the input
        EnIRound <= EnORound;

        EnIPreArk <= '0';
        -- Set EnO to 0, except in the last round, where it is set to the enable signal of the last component
        EnO <= '0';
    end if;
end process;


keyExpInit <= EnI;
keyExpReverse <= '1' when encrypt = '0' and (keyExpandFlag = '0' or state = Rounds) 
    else '0'; 
               

-- State Machine that coordinates the rounds
process (Clock)
begin
if rising_edge(Clock) then
    -- TODO set up signals so we can immediately start with Decrypt Round?
    keyexpCalcNextKey <= '0'; 

    if Resetn = '0' then
        state <= Idle;
        -- reset roudnSkipMixColumns?
        roundSkipMixColumns <= '-';
    else
        case (state) is
            when Idle =>
                currentRound <= 1;
                -- when an encryption starts, change currentRound and isLastRound to its encryption init values
                -- otherwise, keep them on their decryption initial values
                if EnI = '1'  then
                    keyExpCalcNextKey <= '1';

                    if encrypt = '1' then
                        roundSkipMixColumns <= '0';
                        state <= Init; -- Skip once to allow for PreARK to pass
                    else 
                        roundSkipMixColumns <= '1';  -- For decryption, the last round is the first round, so we skip the MixColumns step 
                        state <= Rounds;
                    end if;

                    if keyExpandFlag = '1' then
                        state <= OnlyKeyExp;
                    else
                    end if;
                end if; 

            when Init => 
                -- Delay just once
                state <= Rounds;
            
            when OnlyKeyExp => 
                -- Usually, KeyExpansion and Rounds run in parallel.
                -- In state OnlyKeyExp, only the KeyExpansion runs. 

                -- TODO must adapt if calculation of one key takes multiple rounds
                currentRound <= currentRound + 1;
                keyexpCalcNextKey <= '1';

                if currentRound = AES_NR-1 then
                    if encrypt = '1' and keyExpandFlag = '1' then
                        state <= Idle; -- For encryption, we can stop after the last round key is calculated
                    else
                        state <= Rounds;
                        currentRound <= 1;
                    end if;
                end if; 


            -- RoundState: AEA is executing Rounds         
            when Rounds =>
                -- Update currentRound and state in the last cycle before the round finishes
                if roundIsLastCycle = '1' then

                    keyexpCalcNextKey <= '1';
                    
                    roundSkipMixColumns <= '0'; -- Reset roundSkipMixColumns for the next round, if any

                    -- Must skip MixColumns in the last round of encryption
                    -- For decryption, we already skipped MixColumns in the "first" round
                    if currentRound = AES_NR-1 and encrypt = '1' then
                        roundSkipMixColumns <= '1';
                    end if;

                    if currentRound = AES_NR then
                        keyexpCalcNextKey <= '0'; -- Stop calculating new round keys in the last round
                        -- Last round finishes in next cycle
                        state <= Idle;
                        --currentRound <= currentRound; -- Do not increment anymore
                    else
                        currentRound <= currentRound + 1;
                    end if;
                end if;
        end case;
    end if;
end if;
end process;

end architecture;
