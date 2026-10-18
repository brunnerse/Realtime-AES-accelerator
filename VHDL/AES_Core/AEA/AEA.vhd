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
use work.sbox_definition.sbox_encrypt;

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
end AEA;

architecture Behavioral of AEA is

component AddRoundKey is
    Generic (
        synchronous : boolean := true
        );
    Port ( din : in block_t;
           dout : out block_t;
           roundKey : in block_t;
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Resetn : in STD_LOGIC);
end component;

component AEA_Round is
    Port ( dIn : in block_t;
           dOut : out block_t;
           roundKey : in block_t;
           encrypt : in STD_LOGIC;
           isLastRound : in STD_LOGIC;
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           IsLastCycle : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Resetn : in STD_LOGIC);
end component;

component KeyExpansion is
    Port (  userKey : in key_t;
            setUserKey : in STD_LOGIC;
            calcNextRoundKey : in STD_LOGIC;
            reverse : in STD_LOGIC;
--
            roundKey : out block_t;
            isLastRoundKey : out STD_LOGIC;
            Clock : in STD_LOGIC;
            Resetn : in STD_LOGIC);
end component;

type state_type is (Idle, RoundState);

signal currentRound : integer range 1 to AES_NR;
signal state : state_type;

-- signals to connect the components
signal dInPreARK, dInRound, roundKey : block_t;
signal dOutPreARK, dOutRound : block_t;
signal EnIPreARK, EnIRound : std_logic;
signal EnOPreARK, EnORound : std_logic;
signal isLastRound, roundIsLastCycle : std_logic;

-- signals for the KeyExpansion, which is only used for decryption
signal keyexpSetUserKey, keyexpCalcNextKey, keyexpReverse : std_logic;
signal keyexpIsLastRoundKey : std_logic;


begin


preARK : AddRoundKey
             port map(dInPreARK, dOutPreARK, key(block_t'RANGE), EnIPreARK, EnOPreARK, Clock, Resetn);
roundAEA : AEA_Round
             port map(dInRound, dOutRound, roundKey, encrypt, isLastRound, EnIRound, EnORound, roundIsLastCycle, Clock, Resetn);

keyExp : KeyExpansion
             port map(key, keyexpSetUserKey, keyexpCalcNextKey, keyexpReverse,
                roundKey, keyexpIsLastRoundKey, Clock, Resetn);

-- connect data signals of the components
dInPreARK <= dIn when encrypt = '1' else dOutRound;
dInRound <= dOutRound when State = RoundState else  -- loop back the output of the round to the input
            dOutPreARK when encrypt = '1' else -- init encryption
            dIn when encrypt = '0';  -- init decryption
dOut <= dOutRound when encrypt = '1' else dOutPreARK;

-- connect enable signals
-- Always run KeyExpansion for simplicity;  wouldn't be necessary in Decyption mode, but doesn't change the result
keyexpSetUserKey <= EnI and encrypt; -- Set key at the start 
keyexpCalcNextKey <= EnIRound; -- TODO for decode??
-- TODO for decode, switch it on after certain numbers isLastRoundKey is set
keyexpReverse <= '1' when encrypt = '0' and keyExpandFlag = '0' else -- encryption mode
                 '0';


EnIPreARK <= '0' when encrypt = '1' and keyExpandFlag = '1' else -- KeyExpansion mode: don't run
            EnI when encrypt = '1' else -- Encryption mode
            EnORound; -- Decryption mode
EnIRound <= EnORound when state = RoundState else
            EnOPreARK when encrypt = '1' else -- Init in encryption mode
            keyexpIsLastRoundKey when encrypt = '0' and keyExpandFlag = '1' else -- decryption with keyexpansion
            EnI; -- decryption without keyexpansion: start round immediately
             
-- Set EnO to 0, except in the last round, where it is set to the enable signal of the last component
EnO <= '0' when state /= Idle else 
        EnORound when encrypt = '1' and keyExpandFlag = '0' else -- encryption mode
        EnOPreARK when encrypt = '0'  else  -- decryption
        keyexpIsLastRoundKey ; -- KeyExpansion mode
               

-- process that counts up/down the currentRound variable and sets isLastRound accordingly
process (Clock)
procedure SwitchToIdle is
begin
    state <= Idle;
    -- for decryption, start with the last round
    -- default values are for decryption, as Mode Decryption (without KeyExp) start immediately in rounds,
    -- whereas with Mode Encryption, there's one cycle before the round starts, so the values can still be changed
    currentRound <= AES_NR;
    isLastRound <= '1';
end procedure;

begin
if rising_edge(Clock) then
    if Resetn = '0' then
        SwitchToIdle;
    else
        case (state) is
            when Idle =>
                -- when an encryption starts, change currentRound and isLastRound to its encryption init values
                -- otherwise, keep them on their decryption initial values
                if EnI = '1' and encrypt = '1' then
                    currentRound <= 1;
                    isLastRound <= '0';
                end if;
                -- change to RoundState when Round starts.
                -- This enables a feedback loop where Round's En and Data signals are fed back to itself
                if EnIRound = '1' then
                    state <= RoundState;
                end if;
            -- RoundState: AEA is executing Rounds         
            when RoundState =>
                -- Update currentRound and state in the last cycle before the round finishes
                if roundIsLastCycle = '1' then
                    -- Set the isLastRound signal for encryption before the last round starts
                    if encrypt = '1' and currentRound = AES_NR-1 then
                        isLastRound <= '1';
                    else
                        -- during decryption, round 10 (with isLastRound='1') is the first round,
                        -- so it can be deasserted as soon as a round finishes
                        isLastRound <= '0';
                    end if;
                    
                    -- Increment/Decrement currentRound, Change state to idle if last round reached
                    if encrypt = '1' then
                        if currentRound = AES_NR then
                            SwitchToIdle;
                        else
                            currentRound <= currentRound + 1;
                        end if;
                    else -- encrypt = '0'
                        if currentRound = 1 then
                             SwitchToIdle;
                        else
                             -- decrement for decryption 
                             currentRound <= currentRound - 1; 
                        end if;                        
                    end if;
                end if;
        end case;
    end if;
end if;
end process;

end Behavioral;
