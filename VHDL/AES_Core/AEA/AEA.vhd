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
end AEA;

architecture Behavioral of AEA is

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

type state_type is (Idle, PreState, RoundState);

signal currentRound : std_logic_vector(3 downto 0);
signal state : state_type;

-- signals to connect the components
signal dInPreARK, dInRound, roundKey : std_logic_vector(KEY_SIZE-1 downto 0);
signal dOutPreARK, dOutRound : std_logic_vector(KEY_SIZE-1 downto 0);
signal EnIPreARK, EnIRound : std_logic;
signal EnOPreARK, EnORound : std_logic;
signal isLastRound, roundIsLastCycle : std_logic;

-- signals for the KeyExpansion, which is only used for decryption
signal roundKeys : ROUNDKEYARRAY;
signal EnIKeyExp, EnOKeyExp : std_logic;

begin


preARK : AddRoundKey port map(dInPreARK, dOutPreARK, key, EnIPreARK, EnOPreARK, Clock, Resetn);
roundAEA : AEA_Round port map(dInRound, dOutRound, roundKey, encrypt, isLastRound, EnIRound, EnORound, roundIsLastCycle, Clock, Resetn);
keyExp : KeyExpansion port map(key, roundKeys, EnIKeyExp, EnOKeyExp, Clock, Resetn); 

-- connect data signals of the components
dInPreARK <= dIn when encrypt = '1' else dOutRound;
dInRound <= dOutRound when State = RoundState else  -- loop back the output of the round to the input
            dOutPreARK when encrypt = '1' else -- init encryption
            dIn when encrypt = '0';  -- init decryption
dOut <= dOutRound when encrypt = '1' else dOutPreARK;

-- connect enable signals
-- Always run KeyExpansion for simplicity;  wouldn't be necessary in Decyption mode, but doesn't change the result
EnIKeyExp <= EnI; 

EnIPreARK <= '0' when encrypt = '1' and keyExpandFlag = '1' else -- KeyExpansion mode: don't run
            EnI when encrypt = '1' else -- Encryption mode
            EnORound; -- Decryption mode
EnIRound <= EnORound when state = RoundState else
            EnOPreARK when encrypt = '1' else -- Init in encryption mode
            EnOKeyExp when encrypt = '0' and keyExpandFlag = '1' else -- decryption with keyexpansion
            EnI; -- decryption without keyexpansion: start round immediately
             
-- Set EnO to 0, except in the last round, where it is set to the enable signal of the last component
EnO <= '0' when state /= Idle else 
        EnORound when encrypt = '1' and keyExpandFlag = '0' else -- encryption mode
        EnOPreARK when encrypt = '0'  else  -- decryption
        EnOKeyExp ; -- KeyExpansion mode
               
roundKey <= roundKeys(to_integer(unsigned(currentRound)));

-- process that counts up/down the currentRound variable and sets isLastRound accordingly
process (Clock)
begin
if rising_edge(Clock) then
    if Resetn = '0' then
        isLastRound <= '0';
    else
        case(state) is
            when Idle =>
                if encrypt = '1' then
                    currentRound <= x"1";
                    isLastRound <= '0';
                else
                    -- for decryption, start with the last round
                    currentRound <= x"a";
                    isLastRound <= '1';
                end if;
                -- change to RoundState on enable signal (except in keyexpansion mode)
                --  in KeyExp+Decrypt mode, change to RoundState once the KeyExp has finished
                if (EnI = '1') then
                    state <= PreState;
                end if;
            when PreState => 
                        -- Change to RoundState once the Pre-Unit finished
                        if encrypt = '1' and keyExpandFlag = '1' then 
                            state <= Idle; -- Don't go to RoundState in KeyExpansion Mode
                        elsif encrypt = '1' and EnOPreARK = '1'  then -- Encryption Mode
                            state <= RoundState;
                        elsif encrypt = '0' and keyExpandFlag = '0' then -- Decryption Mode: Go immediately to RoundState
                            state <= RoundState;
                        elsif (encrypt = '0' and keyExpandFlag = '1' and EnOKeyExp = '1') then -- KeyExp+Decryption mode
                            state <= RoundState;
                        end if;         
            when RoundState =>
                -- Increment currentRound and set the next roundKey in the cycle before the round finishes
                if roundIsLastCycle = '1' then
                    -- Set the isLastRound signal for encryption before the last round starts
                    if encrypt = '1' and currentRound = std_logic_vector(to_unsigned(NUM_ROUNDS-1, 4)) then
                        isLastRound <= '1';
                    else
                        isLastRound <= '0';
                    end if;

                    
                    -- If next round is the last one, wait until the last signal arrives, then change back to idle
                    if encrypt = '1' then
                        if currentRound = std_logic_vector(to_unsigned(NUM_ROUNDS, 4)) then
                            state <= Idle;
                        else
                            currentRound <= std_logic_vector(unsigned(currentRound) + to_unsigned(1, 4));
                        end if;
                    else -- encrypt = '0'
                        -- wait until the last component gives its enable signal, then return to idle state
                        if currentRound = std_logic_vector(to_unsigned(1, 4)) then
                                state <= Idle;
                        else
                            -- decrement for decryption 
                            currentRound <= std_logic_vector(unsigned(currentRound) - to_unsigned(1, 4)); 
                        end if;                        
                    end if;
                end if;
            when others =>
        end case;
    end if;
end if;
end process;

end Behavioral;
