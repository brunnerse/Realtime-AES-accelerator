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

type state_type is (Idle,  RoundState, FinalRoundState);

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
dInRound <= dOutPreARK when encrypt = '1' and unsigned(currentRound) <= to_unsigned(1, 4) else
            dIn when encrypt = '0' and unsigned(currentRound) = to_unsigned(10, 4) else  -- decryption
            dOutRound;  -- loop back the output of the round to the input
dOut <= dOutRound when encrypt = '1' else dOutPreARK; -- TODO cleaner if only in last round?

-- connect enable signals
-- TODO Don't run KeyExp in Decryption only mode? Should not make a performance benefit
EnIKeyExp <= EnI; 

EnIPreARK <= '0' when encrypt = '1' and keyExpandFlag = '1' else -- KeyExpansion mode
            EnI when encrypt = '1' else -- Encryption mode
            EnORound; -- Decryption mode
EnIRound <= EnOPreARK when encrypt = '1' and unsigned(currentRound) <= to_unsigned(1, 4) else
            EnOKeyExp when encrypt = '0' and unsigned(currentRound) = to_unsigned(10, 4) and keyExpandFlag = '1' else -- decryption with keyexpansion
            EnI when encrypt = '0' and unsigned(currentRound) = to_unsigned(10, 4) else -- decryption without keyexpansion
            -- stop loopback in last round
            '0' when state = Idle else
             EnORound; -- loop back output of round to the input
             
-- Set EnO to 0, except in the last round, where it is set to the enable signal of the last component
EnO <= '0' when state /= Idle else 
        EnORound when encrypt = '1' and keyExpandFlag = '0' else -- encryption mode
        EnOPreARK when encrypt = '0'  else  -- decryption
        EnOKeyExp ; -- KeyExpansion mode
               
roundKey <= roundKeys(to_integer(unsigned(currentRound)));

-- process that counts up/down the currentRound variable and sets isLastRound accordingly
process (Clock, Resetn)
begin
if Resetn = '0' then
    isLastRound <= '0';
elsif rising_edge(Clock) then
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
            -- start calculation on enable signal if not in keyExpansion mode
            if EnI = '1' and not (encrypt = '1' and keyExpandFlag = '1') then
                state <= RoundState;
            end if;
        when RoundState =>
            -- Increment currentRound and set the next roundKey in the cycle before the round finishes
            if roundIsLastCycle = '1' then
                isLastRound <= '0'; -- set it to zero because in decryption, it is 1 in the first round
                if encrypt = '1' then
                    currentRound <= std_logic_vector(unsigned(currentRound) + to_unsigned(1, 4));
                else
                    -- decrement for decryption 
                    currentRound <= std_logic_vector(unsigned(currentRound) - to_unsigned(1, 4)); 
                end if;
                
                -- If next round is the last one, change to FinalRoundState
                if encrypt = '1' and currentRound = std_logic_vector(to_unsigned(NUM_ROUNDS-1, 4)) then
                    isLastRound <= '1';
                    state <= FinalRoundState;
                elsif encrypt = '0' and currentRound = std_logic_vector(to_unsigned(1, 4)) then
                    -- Next round is round 1, which is the last round, as round 0 is the preARK
                    state <= FinalRoundState;
                end if;
            end if;
        when FinalRoundState =>
            -- wait until the last component gives its enable signal, then return to idle state
            if (encrypt = '1' and roundIsLastCycle = '1') or (encrypt = '0' and EnIPreARK = '1') then
                state <= Idle;
                isLastRound <= '0';
                -- TODO reset currentRound already here? If doing it in Idle, it will be one cycle delayed. 
            end if;
        when others =>
    end case;
end if;
end process;

end Behavioral;
