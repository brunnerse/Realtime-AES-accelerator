----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 28.07.2022 01:09:13
-- Design Name: 
-- Module Name: AES_Core - Behavioral
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
use IEEE.std_logic_1164.ALL;
use work.common.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;


entity AES_Mode_ECBCBCCTR is
    generic (
        ADDR_IV : integer
        );
    Port (
           IV : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dIn : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dOut : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           EnI : in std_logic;
           EnO : out std_logic;
           encrypt : in std_logic;
            -- signals to control the AEA unit
           EnIAEA : out std_logic;
           EnOAEA : in std_logic;
           dInAEA : out std_logic_vector (KEY_SIZE-1 downto 0);
           dOutAEA : in std_logic_vector (KEY_SIZE-1 downto 0);
           -- signals to write to register set
           WrEn   : out STD_LOGIC;
           WrAddr : out STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
           WrData : out STD_LOGIC_VECTOR(KEY_SIZE-1 downto 0);
           mode : in std_logic_vector (MODE_LEN-1 downto 0);
           chaining_mode : in std_logic_vector (CHMODE_LEN-1 downto 0);
           Clock : in std_logic;
           Resetn : in std_logic
           );
end AES_Mode_ECBCBCCTR;

architecture Behavioral of AES_Mode_ECBCBCCTR is

component AddRoundKey is
    Port ( din : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dout : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           key : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Resetn : in STD_LOGIC);
end component;


function incrementIV(IV : std_logic_vector(KEY_SIZE-1 downto 0)) return std_logic_vector is
begin
    return IV(KEY_SIZE-1 downto 32) & std_logic_vector(unsigned(IV(31 downto 0)) + to_unsigned(1,32));
end function;


-- signal definitions
signal dInXOR1, dInXOR2, dOutXOR: std_logic_vector(KEY_SIZE-1 downto 0);
signal EnIXOR, EnOXOR : std_logic;
signal WrEnSignal : std_logic;

begin

-- Use an AddRoundKey unit as XOR
xorUnit : AddRoundKey port map(dInXOR1, dOutXOR, dInXOR2, EnIXOR, EnOXOR, Clock, Resetn);


-- Set encrypt and keyExpandFlag signals according to the mode



dInAEA <=   dOutXOR when chaining_mode = CHAINING_MODE_CBC and encrypt = '1' else
            IV when chaining_mode = CHAINING_MODE_CTR  else
            dIn;

-- First Input into XOR is always plaintext, except for decryption in CBC mode
dInXOR1 <= dIn when encrypt = '1' or chaining_mode /= CHAINING_MODE_CBC else
           dOutAEA;
            
-- Second Input of XOR depends on the mode
with chaining_mode select
    dInXOR2 <=  IV when CHAINING_MODE_CBC,
                dOutAEA when others; -- CHAINING_MODE_CTR; as XOR isn't used for mode ECB, input doesnt matter then
            

dOut <=     dOutXOR when chaining_mode = CHAINING_MODE_CTR or (chaining_mode = CHAINING_MODE_CBC and encrypt = '0') else
            dOutAEA; 


-- For CBC mode, during encryption the input of the AEA is the output of XOR, except in KeyExpansion mode
EnIAEA <=   EnOXOR when chaining_mode = CHAINING_MODE_CBC and encrypt = '1' and mode /= MODE_KEYEXPANSION else
            EnI;
          
EnIXOR <=   EnI when chaining_mode = CHAINING_MODE_CBC and encrypt = '1' else
            EnOAEA when (chaining_mode = CHAINING_MODE_CBC and encrypt = '0') or chaining_mode = CHAINING_MODE_CTR else
            '0'; -- XOR unit is unused in other modes
            

EnO <=  EnOAEA when chaining_mode = CHAINING_MODE_ECB else
        WrEnSignal when (chaining_mode = CHAINING_MODE_CBC and encrypt = '1') else  -- wait until IV has been written until EnO is set
        EnOXOR;  -- CTR mode, CBC with decryption

WrEn <= WrEnSignal;


-- update IV
WrAddr <= std_logic_vector(to_unsigned(ADDR_IV, ADDR_WIDTH)); 
process(Clock)
begin
if rising_edge(Clock) then 
    WrEnSignal <= '0';
    -- For chaining mode CBC, write ciphertext once the AEA has finished
    if EnOAEA = '1' and chaining_mode = CHAINING_MODE_CBC then
        WrEnSignal <= '1';
        if encrypt = '1' then
            WrData <= dOutAEA;
        else
            WrData <= dIn;
        end if;
    -- For chaining mode CTR, write the incremented IV back immediately
    elsif EnI = '1' and chaining_mode = CHAINING_MODE_CTR then
        WrEnSignal <= '1';
        WrData <= incrementIV(IV);
    else
        WrEnSignal <= '0';
    end if;
end if;
end process;


end Behavioral;
