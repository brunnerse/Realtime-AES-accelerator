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
    Port ( dIn : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dOut : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           key : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           encrypt : in STD_LOGIC;
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Reset : in STD_LOGIC);
end AEA;

architecture Behavioral of AEA is

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


type state_type is (Idle, KeyExpState, RoundState, LastRoundState);


signal currentRound : std_logic_vector(3 downto 0);
signal state : state_type;

-- signals to connect the components
signal dInPreARK, dInRound, roundKey : std_logic_vector(KEY_SIZE-1 downto 0);
signal dOutPreARK, dOutRound : std_logic_vector(KEY_SIZE-1 downto 0);
signal EnIPreARK, EnIRound : std_logic;
signal EnOPreARK, EnORound : std_logic;
signal isLastRound, roundIsLastCycle : std_logic;

-- signals for the KeyExpansion
signal roundKeys : ROUNDKEYARRAY;
signal EnIKeyExp, EnOKeyExp : std_logic;

begin

preARK : AddRoundKey port map(dInPreARK, dOutPreARK, key, EnIPreARK, EnOPreARK, Clock, Reset);
roundAEA : AEA_Round port map(dInRound, dOutRound, roundKey, encrypt, isLastRound, EnIRound, EnORound, roundIsLastCycle, Clock, Reset);
keyExp : KeyExpansion port map(key, roundKeys, EnIKeyExp, EnOKeyExp, Clock, Reset); 

-- connect data signals of the components
dInPreARK <= dIn when encrypt = '1' else dOutRound;
dInRound <= dOutPreARK when encrypt = '1' and unsigned(currentRound) <= to_unsigned(1, 4) else
            dIn when encrypt = '0' and currentRound = x"0" else  -- decryption
            dOutRound;  -- loop back the output of the round to the input
dOut <= dOutRound when encrypt = '1' else dOutPreARK;

-- connect enable signals
EnIKeyExp <= EnI; -- TODO muss das Enable-Signal einen Takt oder die ganze Zeit über gesendet werden?
EnIPreARK <= EnOKeyExp when encrypt = '1' else EnORound;
EnIRound <= EnOPreARK when encrypt = '1' and unsigned(currentRound) <= to_unsigned(1, 4) else
            EnOKeyExp when currentRound = x"0" else -- decryption
            EnORound; -- loop back output of round to the input
-- Set EnO to 0, except in the last round, where it is set to the enable signal of the last component
EnO <= '0' when state /= Idle else 
        EnORound when encrypt = '1' else
        EnOPreARK; -- decryption


process (Clock, Reset)
begin
if Reset = '0' then
    isLastRound <= '0';
elsif rising_edge(Clock) then
    case(state) is
        when Idle =>
            currentRound <= x"0";
            --roundKey <= roundKeys(to_integer(unsigned(currentRound)));
            isLastRound <= '0';
            
            if EnI = '1' then
                state <= KeyExpState;
               
            end if;
        when KeyExpState =>
            -- Wait in this state until keys have been calculated
            if EnOKeyExp = '1' then
                state <= RoundState;
                -- in this round, the preARK is running, so the next round is round 1
                currentRound <= x"1";
                roundKey <= roundKeys(to_integer(unsigned(currentRound))+1);
            end if;
        when RoundState =>
            -- Increment currentRound and set the next roundKey in the cycle before the round finishes
            if roundIsLastCycle = '1' then
                roundKey <= roundKeys(to_integer(unsigned(currentRound))+1);
                currentRound <= std_logic_vector(unsigned(currentRound) + to_unsigned(1, 4));
                -- Set isLastRound signal if the next round is the last one
                if currentRound = std_logic_vector(to_unsigned(NUM_ROUNDS-1, 4)) then
                    isLastRound <= '1';
                    state <= LastRoundState;
                end if;
            end if;
        when LastRoundState =>
            -- wait until the last component gives its enable signal, then return to idle state
            if (encrypt = '1' and roundIsLastCycle = '1') or (encrypt = '0' and EnIPreARK = '1') then
                state <= Idle;
                currentRound <= x"0";
                IsLastRound <= '0';
            end if;
        when others =>
    end case;
end if;
end process;

end Behavioral;
