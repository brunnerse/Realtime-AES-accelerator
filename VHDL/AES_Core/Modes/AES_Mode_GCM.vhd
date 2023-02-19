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


entity AES_Mode_GCM is
    generic (
        ADDR_IV : integer;
        ADDR_SUSP : integer;
        ADDR_H  : integer
        );
    Port (
           IV : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           -- specific signals for GCM mode
           H  : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           Susp : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0); -- for the first block, this signals MUST be 0
           
           dIn : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dOut : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           EnI : in std_logic;
           EnO : out std_logic;
           encrypt : in std_logic;
           GCMPhase : in std_logic_vector(1 downto 0);
           -- signals to control the AEA unit
           EnIAEA : out std_logic;
           EnOAEA : in std_logic;
           dInAEA : out std_logic_vector (KEY_SIZE-1 downto 0);
           dOutAEA : in std_logic_vector (KEY_SIZE-1 downto 0);
           -- signals to write to register set
           WrEn   : out STD_LOGIC;
           WrAddr : out STD_LOGIC_VECTOR(ADDR_REGISTER_BITS-1 downto 0);
           WrData : out STD_LOGIC_VECTOR(KEY_SIZE-1 downto 0);
           Clock : in std_logic;
           Resetn : in std_logic
           );
end AES_Mode_GCM;



architecture Behavioral of AES_Mode_GCM is

component AddRoundKey is
    Generic (
        synchronous : boolean := true
    );
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


constant ZERO : std_logic_vector(KEY_SIZE-2 downto 0) := (others => '0');
-- we don't need the x^128 in the polynomial
constant POLYGF : std_logic_vector(KEY_SIZE-1 downto 0) := x"e1000000000000000000000000000000";

constant MULTIPLICATIONS_PER_CYCLE : integer := 128/2; -- Do 64 calculations per clock cycle

function mulGF(val : std_logic_vector(KEY_SIZE-1 downto 0); prod : std_logic_vector(KEY_SIZE-1 downto 0)) return std_logic_vector is
    variable c, v : std_logic_vector(KEY_SIZE-1 downto 0);
begin
    v := val;
    c := (others => '0');
    -- Polynomial Multiplication; Little-Endian, i.e. x^0 is bit 127, x^127 is bit 0 ! 
    for i in KEY_SIZE-1 downto 0 loop
        if prod(i) = '1' then
            c := c xor v; -- Shift the value by attaching the right amount of zeros
        end if;
        if v(0) = '0' then
            v := '0' & v(KEY_SIZE-1 downto 1); -- multiply by x (i.e. right shift by 1)
        else
            v := ('0' & v(KEY_SIZE-1 downto 1)) xor POLYGF; -- result was larger or equal to x^128:  subtract polynom
        end if;
    end loop;
    return c;
end function;

-- signal definitions
signal  dIn1XOR1, dIn2XOR1, dIn1XOR2,dIn2XOR2, dOutXOR1, dOutXOR2, dInMul, dOutMul: std_logic_vector(KEY_SIZE-1 downto 0);
signal  EnIXOR1, EnIXOR2, EnOXOR1, EnOXOR2, EnIMul, EnOMul, WrEnSignal : std_logic;
signal WrAddrSignal : std_logic_vector(ADDR_REGISTER_BITS-1 downto 0);
signal prevEnI : std_logic;

signal lastIdx : integer; -- used for the multiplication process

begin
-- Use an AddRoundKey unit as XOR;  First XOR unit is for CTR mode, second is for GF2mul
xorUnit1 : AddRoundKey port map(dIn1XOR1, dOutXOR1, dIn2XOR1, EnIXOR1, EnOXOR1, Clock, Resetn);
xorUnit2 : AddRoundKey port map(dIn1XOR2, dOutXOR2, dIn2XOR2, EnIXOR2, EnOXOR2, Clock, Resetn);

-- xorUnit1 is not used in the Init and Header Phases; in Payload and final, it is connected to the output of the AEA unit
-- EnI isn't asserted in the Init Phase and not in the Header Phase either (as EnOAEA stays 0 in that phase because the AEA is never activated)
EnIXOR1 <= EnOAEA when GCMPHASE /= GCM_PHASE_INIT else -- This only works when Mul is to be faster than AEA, otherwise dIn2Xor1 is wrong in the final phase
            '0'; -- Do not use xorUnit1 in init phase
dIn1XOR1 <= dOutAEA;        -- in the diagram, xorUnit1 is the bottom xor in the final phase, in the payload phase it is the first xor
dIn2XOR1 <= dIn when GCMPhase = GCM_PHASE_PAYLOAD else      
            dOutMul; -- in GCM_PHASE_FINAL            



-- xorUnit2 XORs the old Susp with another value.  Used in all phases except Init
EnIXOR2 <=  EnOXOR1 when GCMPhase = GCM_PHASE_PAYLOAD and encrypt = '1' else -- payload encryption
            '0' when GCMPhase = GCM_PHASE_INIT else            
            EnI; -- during Header and Final phase, and during payload decryption

dIn1XOR2 <= Susp;
dIn2XOR2 <= dOutXOR1 when GCMPhase = GCM_PHASE_PAYLOAD and encrypt = '1' else -- payload encryption
            dIn; -- in final phase and header phase and during payload decryption    

-- MUL always processes the output of XOR2            
EnIMul <= EnOXOR2;
dInMul <= dOutXOR2;
                  
-- AEA is used in all Phases except Header
EnIAEA <=   EnI when GCMPhase /= GCM_PHASE_HEADER else
            '0';            
dInAEA <=   IV when GCMPhase /= GCM_PHASE_INIT else
            (others => '0');  -- In Init Phase, the input is a 0-vector                


dOut <= dOutXOR1;
EnO <=  EnOXOR1 when GCMPhase = GCM_PHASE_FINAL or (GCMPhase = GCM_PHASE_PAYLOAD and encrypt = '0') else -- final phase and payload phase, decryption
        WrEnSignal when (GCMPhase = GCM_PHASE_INIT and prevEnI = '0') or GCMPhase = GCM_PHASE_HEADER else -- init phase (ignore first write to Susp), header phase
        -- during payload phase with encryption:  EnO = WrEnSignal, however the first write to the IV should be ignored
        WrEnSignal when (GCMPhase = GCM_PHASE_PAYLOAD and prevEnI = '0')  else
        '0';
 
prevEnI <= EnI when rising_edge(Clock);        

WrEn <= WrEnSignal;
WrAddr <= WrAddrSignal;
               
-- process to write the new IV, Susp and H to the register set
process(Clock)
begin
if rising_edge(Clock) then
    WrEnSignal <= '0';
    if EnI = '1' and GCMPhase = GCM_PHASE_INIT then
        WrAddrSignal <= std_logic_vector(to_unsigned(ADDR_SUSP, WrAddr'LENGTH));
        WrData <= (others => '0');
        WrEnSignal <= '1';
    elsif EnOAEA = '1' and GCMPhase = GCM_PHASE_INIT then
        WrAddrSignal <= std_logic_vector(to_unsigned(ADDR_H, WrAddr'LENGTH));
        WrData <= dOutAEA;
        WrEnSignal <= '1';
    elsif EnOMul = '1' and (GCMPhase = GCM_PHASE_HEADER or GCMPhase = GCM_PHASE_PAYLOAD) then 
        WrAddrSignal <= std_logic_vector(to_unsigned(ADDR_SUSP, WrAddr'LENGTH));
        WrData <= dOutMul;
        WrEnSignal <= '1';
    elsif EnI = '1' and GCMPhase = GCM_PHASE_PAYLOAD then
        WrAddrSignal <= std_logic_vector(to_unsigned(ADDR_IV, WrAddr'LENGTH));
        WrData <= incrementIV(IV);
        WrEnSignal <= '1';
    end if;
end if;
end process;

-- process performing the GF2 multiplication on each rising clock edge when EnIMul is asserted
process (Clock)
variable calculationInProgress : boolean;
variable c, v : std_logic_vector(KEY_SIZE-1 downto 0);
begin
if rising_edge(Clock) then
    if Resetn = '0' then
        EnOMul <= '0';
        calculationInProgress := false;
        lastIdx <= KEY_SIZE;
    else
        EnOMul <= '0';
        -- Set up a new mulGF operation
        if EnIMul = '1' then
            -- start a new multiplication
            calculationInProgress := true;
            v := dInMul; -- v is the input
            c := (others => '0'); -- c is the result
        end if;
        if calculationInProgress then
            -- Polynomial Multiplication; Little-Endian, i.e. x^0 is bit 127, x^127 is bit 0 ! 
            for i in 1 to MULTIPLICATIONS_PER_CYCLE loop
                -- if the second factor (H) is 1 at the current position, add the (shifted) first factor to the result
                if H(lastIdx - i) = '1' then
                    c := c xor v; -- add the (shifted) first factor to the result
                end if;
                -- shift the first factor one bit to the right (corresponds to multiplying the polynomial by x)
                -- if the result would be divisible by x^128, subtract the GF polynomial
                if v(0) = '0' then
                    v := '0' & v(KEY_SIZE-1 downto 1); -- multiply the by x (i.e. right shift by 1)
                else
                    v := ('0' & v(KEY_SIZE-1 downto 1)) xor POLYGF; -- result was larger or equal to x^128:  subtract polynom after multiplication
                end if;
            end loop;
            
            -- check if finished
            if lastIdx = MULTIPLICATIONS_PER_CYCLE then
                calculationInProgress := false;
                EnOMul <= '1';
                dOutMul <= c;
                lastIdx <= KEY_SIZE;
            else
                lastIdx <= lastIdx - MULTIPLICATIONS_PER_CYCLE; 
            end if;
            
        end if;
        

        
    end if;
end if;

end process;

end Behavioral;
