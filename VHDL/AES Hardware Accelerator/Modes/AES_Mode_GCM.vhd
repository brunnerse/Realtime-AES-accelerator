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
           WrAddr : out STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
           WrData : out STD_LOGIC_VECTOR(KEY_SIZE-1 downto 0);
           Clock : in std_logic;
           Resetn : in std_logic
           );
end AES_Mode_GCM;



architecture Behavioral of AES_Mode_GCM is

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


constant ZERO : std_logic_vector(KEY_SIZE-2 downto 0) := (others => '0');
-- we don't need the x^128 in the polynomial
constant POLYGF : std_logic_vector(KEY_SIZE-1 downto 0) := x"e1000000000000000000000000000000";

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
signal  EnIXOR1, EnIXOR2, EnOXOR1, EnOXOR2, EnIMul, EnOMul : std_logic;

begin
-- Use an AddRoundKey unit as XOR;  First XOR unit is for CTR mode, second is for GF2mul
xorUnit1 : AddRoundKey port map(dIn1XOR1, dOutXOR1, dIn2XOR1, EnIXOR1, EnOXOR1, Clock, Resetn);
xorUnit2 : AddRoundKey port map(dIn1XOR2, dOutXOR2, dIn2XOR2, EnIXOR2, EnOXOR2, Clock, Resetn);

-- First Input into XOR is always plaintext
dIn1XOR1 <= dOutAEA;        -- in the diagram, xorUnit1 is the bottom xor in the final phase, in the payload phase it is the first xor
dIn2XOR1 <= dIn when GCMPhase = GCM_PHASE_PAYLOAD else      
            dOutMul; -- in GCM_PHASE_FINAL
EnIXOR1 <= EnOAEA when GCMPHASE /= GCM_PHASE_INIT else -- Mul has to be faster than AEA!
            '0'; -- Do not use xorUnit1 in init phase
            
dOut <= dOutXOR1;


dIn1XOR2 <= Susp;
dIn2XOR2 <= dOutXOR1 when GCMPhase = GCM_PHASE_PAYLOAD and encrypt = '1' else
            dIn; -- in final phase and header phase and during payload decryption         
EnIXOR2 <=  EnI when GCMPhase = GCM_PHASE_HEADER or GCMPhase =  GCM_PHASE_FINAL or
                (GCMPhase = GCM_PHASE_PAYLOAD and encrypt = '0') else -- payload decryption
            EnOXOR1 when GCMPhase = GCM_PHASE_PAYLOAD else -- payload encryption
            '0'; -- Do not use xorUnit2 in init phase
 
 
dInMul <= dOutXOR2;
EnIMul <= EnOXOR2;
                  
                  
dInAEA <=   IV when GCMPhase /= GCM_PHASE_INIT else
            (others => '0');                  
EnIAEA <=   EnI when GCMPhase /= GCM_PHASE_HEADER else
            '0'; -- Do not use AEA unit in Header phase

-- in Header phase and during decryption, the last component to finish is the AEA                                
EnO <=  EnOAEA when GCMPhase = GCM_PHASE_INIT or (GCMPhase = GCM_PHASE_PAYLOAD and encrypt = '0') else
        EnOMul when GCMPhase = GCM_PHASE_HEADER or GCMPhase =  GCM_PHASE_PAYLOAD else
        EnOXOR1; -- in the Final phase, the last component is xorUnit1   


-- process to write the new IV to the register set
-- TODO Das Schreiben erfolgt einen Takt nachdem das EnO Signal ausgegeben wird. EnO verzögern?
process(Clock)
begin
if rising_edge(Clock) then
    WrEn <= '0';
    if EnOAEA = '1' and GCMPhase = GCM_PHASE_INIT then
        WrAddr <= std_logic_vector(to_unsigned(ADDR_H, ADDR_WIDTH));
        WrData <= dOutAEA;
        WrEn <= '1';
    elsif EnOMul = '1' and (GCMPhase = GCM_PHASE_HEADER or GCMPhase = GCM_PHASE_PAYLOAD) then 
        WrAddr <= std_logic_vector(to_unsigned(ADDR_SUSP, ADDR_WIDTH));
        WrData <= dOutMul;
        WrEn <= '1';
    elsif EnI = '1' and GCMPhase = GCM_PHASE_PAYLOAD then
        WrAddr <= std_logic_vector(to_unsigned(ADDR_IV, ADDR_WIDTH));
        WrData <= incrementIV(IV);
        WrEn <= '1';
    end if;
end if;
end process;

-- process performing the GF2 multiplication on each rising clock edge when EnIMul is asserted
process (Clock)
begin
if rising_edge(Clock) then
    if Resetn = '0' then
        EnOMul <= '0';
    else
        if EnIMul = '1' then
            dOutMul <= mulGF(dInMul, H);
            EnOMul <= '1';
        else
            EnOMul <= '0';
        end if;
    end if;
end if;

end process;



end Behavioral;
