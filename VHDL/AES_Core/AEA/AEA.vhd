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


type state_t is (Idle, OnlyKeyExp, PreARK, Rounds);

signal currentRound : integer range 1 to AES_NR; -- TODO replace with unsigned(4 downto 0)  (max is 14)
signal state : state_t;

signal roundKey : block_t;

signal roundSkipMixColumns : std_logic;

-- signals for the KeyExpansion, which is only used for decryption
signal keyexpInit, keyexpCalcNextKey, keyexpReverse : std_logic;
signal prevEnI : std_logic;

signal dataState : block_t;
signal dInSB : block_t;


signal dInARK : block_t;
signal keyARK : block_t;
signal EnARK : std_logic;

--type block_array_t is array(natural range<>) of block_t;
--signal subDOut : block_array_t(2 downto 0);
signal dOutSB, dOutMC, dOutARK : block_t;
signal subEn, prevSubEn : unsigned(2 downto 0); -- TODO use sub-indizes for subEn

constant EN_IDX_ARK : natural := 0;
constant EN_IDX_SB : natural := 1;
constant EN_IDX_MC : natural := 2;

begin

keyExp : entity work.KeyExpansion
             port map(userKey => key, init => keyexpInit, 
                reverse => keyexpReverse, calcNextRoundKey => keyexpCalcNextKey,
                roundKey => roundKey, 
                Clock => Clock, Resetn => Resetn);




ARK : entity work.AddRoundKey
        port map(dIn => dInARK, dOut => dOutARK, roundKey => keyARK, 
            EnI => EnARK, Clock => Clock, Resetn => Resetn);


-- SR and SB as one connected entity
SR : entity work.ShiftRows
        generic map(synchronous => false)
        port map(dIn => dataState, dOut => dInSB, encrypt => encrypt);

SB : entity work.SubBytes
        port map(dIn => dInSB, dOut => dOutSB, encrypt => encrypt,
                EnI => subEn(EN_IDX_SB), Clock => Clock, Resetn => Resetn);


MC : entity work.MixColumns
        port map(dIn => dataState, dOut => dOutMC, encrypt => encrypt,
                EnI => subEn(EN_IDX_MC), Clock => Clock, Resetn => Resetn);


--------------------------------
-- KeyExpansion control 

prevEnI <= EnI when rising_edge(Clock);
 
-- keyExpReverse <= '1' when encrypt = '0' or EnO = '1' else '0'; -- and (keyExpandFlag = '0' or state = Rounds) 
process (all)
begin
    keyExpInit <= '0';
    keyExpCalcNextKey <= '0';

    if encrypt = '1' then
        keyExpReverse <= '0';
        keyExpInit <= EnI;
    else
        keyExpReverse <= '1';
    end if;

    -- Always start calculating next key once we use the current one
    if EnARK = '1' then
        if currentRound = AES_NR then
            -- At the end, reset back to init state (but always for decryption)
            keyExpReverse <= '1';
            keyExpInit <= '1';
        else
            keyExpCalcNextKey <= '1';
        end if;
    end if;

    if prevEnI = '1' and encrypt = '1' then
        keyExpCalcNextKey <= '1'; -- Run KeyExpansion one cycle later since initializing in the first cycle 
    end if;
end process;


--------------------------------
-- Substeps control 

dInARK <= dIn when EnI = '1' else dataState;
-- First step is always an ARK for both en-/decrypt
EnARK <= EnI or subEn(EN_IDX_ARK);
-- roundKey or UserKey depending on en-/decrypt and round
keyARK <= roundKey when state = Rounds or encrypt = '0' else
          key(key_t'length-1 downto key_t'length-block_t'length);


-- Do not update when EnO is set so datastate stays constant
prevSubEn <= subEn when rising_edge(Clock); -- and EnO = '0';

-- Assign dataState the output data of the component that was enabled in the last cycle
process (all)
begin
    -- Assign data state according to En
    case prevSubEn is 
        when "100" => 
            dataState <= dOutMC;
        when "010" => 
            dataState <= dOutSB;
        when others => 
            dataState <= dOutARK;
    end case;
end process;


dOut <= dOutARK;


-- TODO integrate process in state machine?
process (Clock)
    variable v_En : unsigned(2 downto 0);
begin
if rising_edge(Clock) then

    if Resetn = '0' then
        v_En := (others => '0'); 
        v_En(0) := '0';
    else
        if EnI = '1' then
            -- First step after initial AddRoundKey is SubBytes for both
            -- encryption (first round) and decryption (last round, since MixColumns is skipped)
            v_En := (EN_IDX_SB => '1', others => '0'); 
            -- This way, we automatically skip MixColumns in the first decryption round
        elsif state = Idle then 
            v_En := (others => '0');
        else
            if encrypt = '1' then
                v_En := v_En rol 1;
            else
                v_En := v_En ror 1;
            end if;

            if roundSkipMixColumns = '1' and v_En(EN_IDX_MC) = '1' and encrypt = '1' then 
                -- Encryption in last round: Skip MixColumns, go straight to ARK 
                v_En := (EN_IDX_ARK => '1', others => '0'); 
            end if;
        end if;
    end if;

    subEn <= v_En;
end if;
end process;


               

-- State Machine that coordinates the rounds
process (Clock)
begin
if rising_edge(Clock) then
    -- TODO set up signals so we can immediately start with Decrypt Round?

    EnO <= '0';

    if Resetn = '0' then
        state <= Idle;
        roundSkipMixColumns <= '1';
        currentRound <= 1;
    else
        case (state) is
            when Idle =>
                currentRound <= 1;
                roundSkipMixColumns <= '1';  -- For decryption, the last round is the first round, so we skip the MixColumns step 

                -- when an encryption starts, change currentRound and isLastRound to its encryption init values
                -- otherwise, keep them on their decryption initial values
                if EnI = '1'  then

                    if encrypt = '1' then
                        roundSkipMixColumns <= '0';
                        state <= Rounds; -- Skip once to allow for PreARK to pass
                    else 
                        roundSkipMixColumns <= '1';  -- For decryption, the last round is the first round, so we skip the MixColumns step 
                        state <= Rounds;
                    end if;

                    if keyExpandFlag = '1' then
                        state <= OnlyKeyExp;
                    else
                    end if;
                end if; 

            when OnlyKeyExp => 

                assert keyExpandFlag = '1' severity failure;

                -- Usually, KeyExpansion and Rounds run in parallel.
                -- In state OnlyKeyExp, only the KeyExpansion runs. 

                -- TODO must adapt if calculation of one key takes multiple rounds
                currentRound <= currentRound + 1;

                if currentRound = AES_NR-1 then
                    if encrypt = '1' then
                        state <= Idle; -- For encryption, we can stop after the last round key is calculated
                        EnO <= '1';
                    else
                        state <= Rounds;
                        currentRound <= 1;
                    end if;
                end if; 

            when PreARK =>
            /*
                if encrypt = '1' then
                    state <= Rounds;
                else
                    state <= Idle;
                    EnO <= '1';
                end if;
                */
                

            -- RoundState: AEA is executing Rounds         
            when Rounds =>

                -- AddRoundKey is always the last step in a round for both en-/decryption
                if subEn(EN_IDX_ARK) = '1' then -- and state /= Idle and currentRound /= AES_NR then

                    roundSkipMixColumns <= '0'; -- Reset roundSkipMixColumns for the next round, if any

                    -- Must skip MixColumns in the last round of encryption
                    -- For decryption, we already skipped MixColumns in the "first" round
                    if currentRound = AES_NR-1 and encrypt = '1' then
                        roundSkipMixColumns <= '1';
                    end if;

                    -- Update round number, or quit in last round
                    if currentRound = AES_NR then
                        -- Last round finishes in next cycle

                        state <= Idle;
                        EnO <= '1';
                        --currentRound <= 1;
                    else
                        currentRound <= currentRound + 1;
                    end if;
                end if;
        end case;
    end if;
end if;
end process;

end architecture;
