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

function mulGFby2(val : std_logic_vector(7 downto 0)) return std_logic_vector is
    variable c : std_logic_vector(7 downto 0);
begin
    c := val(6 downto 0) & '0';
    if val >= x"80" then
        return c xor x"1b";
    else
        return c;
    end if;
end function;

function calcNextKey(lastKey : std_logic_vector(127 downto 0); RCon : std_logic_vector(7 downto 0))
return std_logic_vector is
    variable key : std_logic_vector (127 downto 0);
    variable word_1, word : std_logic_vector(31 downto 0);
begin
    -- Calculate first word
    word_1 := lastKey(31 downto 0);
    -- Rotate word: rol 8
    word_1 := word_1(23 downto 0) & word_1(31 downto 24);
    -- perform substitution for each byte of word_1
    for j in 3 downto 0 loop
        word_1((j+1)*8-1 downto j*8) := sbox_encrypt(to_integer(unsigned(word_1((j+1)*8-1 downto j*8))));
    end loop;
    -- xor with constant
    word_1 := word_1 xor (Rcon & x"000000");  --TODO manually multiply Rcon by 2 before/after calling!
    
    word := word_1 xor lastKey(127 downto 96);
    key(127 downto 96) := word;
    
    -- Calculate the other 3 words
    for i in 1 to 3 loop
        word := word xor lastKey(127-32*i downto 96-32*i);
        key(127-32*i downto 96-32*i) := word;
    end loop;
    return key;
end function;


type state_type is (Idle, KeyExpState, RoundState, LastRoundState);


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
-- signals for calculating the key on-the-fly
signal encryptKey : std_logic_vector(KEY_SIZE-1 downto 0);
signal Rcon : std_logic_vector(7 downto 0);

begin


preARK : AddRoundKey port map(dInPreARK, dOutPreARK, key, EnIPreARK, EnOPreARK, Clock, Reset);
roundAEA : AEA_Round port map(dInRound, dOutRound, roundKey, encrypt, isLastRound, EnIRound, EnORound, roundIsLastCycle, Clock, Reset);
keyExp : KeyExpansion port map(key, roundKeys, EnIKeyExp, EnOKeyExp, Clock, Reset); 

-- TODO KeyExpansion für encrypt='1' überspringen
-- connect data signals of the components
dInPreARK <= dIn when encrypt = '1' else dOutRound;
dInRound <= dOutPreARK when encrypt = '1' and unsigned(currentRound) <= to_unsigned(1, 4) else
            dIn when encrypt = '0' and unsigned(currentRound) = to_unsigned(10, 4) else  -- decryption
            dOutRound;  -- loop back the output of the round to the input
dOut <= dOutRound when encrypt = '1' else dOutPreARK;

-- connect enable signals
-- skip KeyExpansion for encryption
EnIKeyExp <= '0' when encrypt = '1' else EnI; 
EnIPreARK <= EnI when encrypt = '1' else EnORound;
EnIRound <= EnOPreARK when encrypt = '1' and unsigned(currentRound) <= to_unsigned(1, 4) else
            EnOKeyExp when encrypt = '0' and unsigned(currentRound) = to_unsigned(10, 4) else -- decryption
            -- stop loopback in last round
            '0' when state = Idle else
             EnORound; -- loop back output of round to the input
-- Set EnO to 0, except in the last round, where it is set to the enable signal of the last component
EnO <= '0' when state /= Idle else 
        EnORound when encrypt = '1' else
        EnOPreARK; -- decryption

roundKey <= encryptKey when encrypt = '1' else
            roundKeys(to_integer(unsigned(currentRound)));

process (Clock, Reset)
begin
if Reset = '0' then
    isLastRound <= '0';
elsif rising_edge(Clock) then
    case(state) is
        when Idle =>
            if encrypt = '1' then
                currentRound <= x"1";
                isLastRound <= '0';
                -- start calculation on enable signal
                if EnI = '1' then
                    -- Calculate first key here, while preARK is running
                    if encrypt = '1' then
                        state <= RoundState;
                        encryptKey <= calcNextKey(key, x"01"); -- Enter RCon manually the first time to avoid having to reset it
                        RCon <= mulGFby2(x"01"); -- Set RCon to the next RCon
                    end if;
                end if;
            else
                -- for decryption, start with the last round
                currentRound <= x"a";
                isLastRound <= '1';
                -- start calculation on enable signal
                if EnI = '1' then
                    state <= KeyExpState;
                end if;
            end if;
        when KeyExpState =>
            -- Wait in this state until keys have been calculated
            if EnOKeyExp = '1' then
                state <= RoundState;
            end if;
        when RoundState =>
            -- Increment currentRound and set the next roundKey in the cycle before the round finishes
            if roundIsLastCycle = '1' then
                isLastRound <= '0'; -- set it to zero because in decryption, it is 1 in the first round
                if encrypt = '1' then
                    --roundKey <= roundKeys(to_integer(unsigned(currentRound))+1);
                    currentRound <= std_logic_vector(unsigned(currentRound) + to_unsigned(1, 4));
                else
                    -- decrement for decryption 
                    currentRound <= std_logic_vector(unsigned(currentRound) - to_unsigned(1, 4)); 
                end if;
                
                -- Set isLastRound signal if the next round is the last one
                if encrypt = '1' and currentRound = std_logic_vector(to_unsigned(NUM_ROUNDS-1, 4)) then
                    isLastRound <= '1';
                    state <= LastRoundState;
                elsif encrypt = '0' and currentRound = std_logic_vector(to_unsigned(1, 4)) then
                    -- Next round is round 1, which is the last round, as round 0 is the preARK
                    state <= LastRoundState;
                end if;
                
                -- Calculate key for next round
                encryptKey <= calcNextKey(encryptKey, RCon);
                RCon <= mulGFby2(RCon);
            end if;
        when LastRoundState =>
            -- wait until the last component gives its enable signal, then return to idle state
            if (encrypt = '1' and roundIsLastCycle = '1') or (encrypt = '0' and EnIPreARK = '1') then
                state <= Idle;
                --currentRound <= x"0"; currentRound wird in Idle zurückgesetzt, das sollte reichen
                IsLastRound <= '0';
            end if;
        when others =>
    end case;
end if;
end process;

end Behavioral;
