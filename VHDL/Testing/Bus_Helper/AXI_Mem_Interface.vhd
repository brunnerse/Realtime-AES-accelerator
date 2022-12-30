----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 21.05.2022 03:58:44
-- Design Name: 
-- Module Name: MasterAXILite - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity AXI_Mem_Interface is
    generic (
        C_M_AXI_SUPPORTS_NARROW_BURST : integer range 0 to 1      := 0;
        C_S_AHB_ADDR_WIDTH            : integer range 32 to 64    := 32;
        C_M_AXI_ADDR_WIDTH            : integer range 32 to 64    := 32;
        C_S_AHB_DATA_WIDTH            : integer range 32 to 64    := 32;
        C_M_AXI_DATA_WIDTH            : integer range 32 to 64    := 32;
        C_M_AXI_PROTOCOL              : string                    := "AXI4";
        C_M_AXI_NON_SECURE             : integer                   := 1 
    );
    Port ( 
           ReadEn : in std_logic;
           WriteEn : in std_logic;
           WrByteEna : in std_logic_vector(3 downto 0);
           Address : in std_logic_vector(31 downto 0);
           DataIn    : in std_logic_vector(31 downto 0);
           DataOut   : out std_logic_vector(31 downto 0);
           -- busy='0' indicates that the module accepts requests
           busy     : out std_logic; 
           M_AXI_aclk, M_AXI_aresetn : in std_logic;
           
           M_AXI_awaddr : out STD_LOGIC_VECTOR (31 downto 0);
           M_AXI_awprot : out STD_LOGIC_VECTOR (2 downto 0);
           M_AXI_awvalid : out STD_LOGIC;
           M_AXI_awready : in STD_LOGIC;
           M_AXI_wdata : out STD_LOGIC_VECTOR (31 downto 0);
           M_AXI_wstrb : out STD_LOGIC_VECTOR (3 downto 0);
           M_AXI_wvalid : out STD_LOGIC;
           M_AXI_wready : in STD_LOGIC;
           M_AXI_bresp : in STD_LOGIC_VECTOR (1 downto 0);
           M_AXI_bvalid : in STD_LOGIC;
           M_AXI_bready : out STD_LOGIC;
           M_AXI_araddr : out STD_LOGIC_VECTOR (31 downto 0);
           M_AXI_arprot : out STD_LOGIC_VECTOR (2 downto 0);
           M_AXI_arvalid : out STD_LOGIC;
           M_AXI_arready : in STD_LOGIC;
           M_AXI_rdata : in STD_LOGIC_VECTOR (31 downto 0);
           M_AXI_rresp : in STD_LOGIC_VECTOR (1 downto 0);
           M_AXI_rvalid : in STD_LOGIC;
           M_AXI_rready : out STD_LOGIC
 -- AXI3 signals
           --; M_AXI_awlen : out std_logic_vector (3 downto 0); 
            --M_AXI_awsize : out std_logic_vector (2 downto 0);
            --M_AXI_awburst : out std_logic_vector(1 downto 0);
            --M_AXI_awlock : out std_logic_vector (1 downto 0); 
            --M_AXI_awcache : out std_logic_vector (3 downto 0); 
            --M_AXI_awqos : out std_logic_vector (3 downto 0);  
            --M_AXI_wlast : out std_logic;
            --M_AXI_arlen : out std_logic_vector (3 downto 0); 
            --M_AXI_arsize : out std_logic_vector (2 downto 0);
            --M_AXI_arburst : out std_logic_vector (1 downto 0);
            --M_AXI_arlock : out std_logic_vector (1 downto 0); 
            --M_AXI_arcache : out std_logic_vector (3 downto 0); 
            --M_AXI_arqos : out std_logic_vector (3 downto 0);
            --M_AXI_rlast : in std_logic
 -- AXI4 signals
           ; M_AXI_awlen : out std_logic_vector (7 downto 0); 
            M_AXI_awsize : out std_logic_vector (2 downto 0);
            M_AXI_awburst : out std_logic_vector(1 downto 0);
            M_AXI_awlock : out std_logic; 
            M_AXI_awcache : out std_logic_vector (3 downto 0); 
            M_AXI_awqos : out std_logic_vector (3 downto 0);  
            M_AXI_wlast : out std_logic;
            M_AXI_arlen : out std_logic_vector (7 downto 0); 
            M_AXI_arsize : out std_logic_vector (2 downto 0);
            M_AXI_arburst : out std_logic_vector (1 downto 0);
            M_AXI_arlock : out std_logic; 
            M_AXI_arcache : out std_logic_vector (3 downto 0); 
            M_AXI_arqos : out std_logic_vector (3 downto 0);
            M_AXI_rlast : in std_logic
           );
end AXI_Mem_Interface;

architecture Behavioral of AXI_Mem_Interface is

-- internal signals for output signals
signal axi_awvalid, axi_wvalid, axi_bready, axi_arvalid, axi_rready : std_logic;

signal ReadPulse, WritePulse, prevReadEn, prevWriteEn : std_logic;

begin

-- set default AXI4 signals for non-burst mode
M_AXI_awlen <= "00000000";
M_AXI_arlen <= "00000000";
M_AXI_awsize <= "000";
M_AXI_arsize <= "000";
M_AXI_awburst <= "00";
M_AXI_arburst <= "00";
M_AXI_awlock <= '0';
M_AXI_arlock <= '0';
M_AXI_awcache <= "0000";
M_AXI_arcache <= "0000";
M_AXI_awqos <= "0000";
M_AXI_arqos <= "0000";
M_AXI_wlast <= '1';

M_AXI_awprot <= "000";
M_AXI_arprot <= "000";

-- forward internal output signals to port
M_AXI_awvalid <= axi_awvalid;
M_AXI_wvalid <= axi_wvalid;
M_AXI_bready <= axi_bready;
M_AXI_arvalid <= axi_arvalid;
M_AXI_rready <= axi_rready;


-- set up write and read pulse
prevWriteEn <= WriteEn when rising_edge(M_AXI_aclk);
prevReadEn <= ReadEn when rising_edge(M_AXI_aclk);

ReadPulse <= ReadEn and not prevReadEn;
WritePulse <= WriteEn and not prevWriteEn;

-- Configure busy signal: High when Transaction is just starting or is currently ongoing
busy <= ReadPulse or axi_rready or WritePulse or axi_bready;
        
        
-- process transferring the rdaddr
process (M_AXI_aclk) 
begin
if rising_edge(M_AXI_aclk) then
    if M_AXI_aresetn = '0' then
        axi_arvalid <= '0';
    else
        if ReadPulse = '1' then
            axi_arvalid <= '1';
            M_AXI_araddr <= Address;
        -- Check if handshake occured
        elsif M_AXI_arready = '1' and axi_arvalid = '1' then
            axi_arvalid <= '0';
        end if;
    end if;
end if;
end process;

-- process transferring the wraddr
process (M_AXI_aclk) 
begin
if rising_edge(M_AXI_aclk) then
    if M_AXI_aresetn = '0' then
        axi_awvalid <= '0';
    else
        if WritePulse = '1' then
            axi_awvalid <= '1';
            M_AXI_awaddr <= Address;
        -- Check if handshake occured
        elsif M_AXI_awready = '1' and axi_awvalid = '1' then
            axi_awvalid <= '0';
        end if;
    end if;
end if;
end process;

-- process transferring the write data
process (M_AXI_aclk) 
begin
if rising_edge(M_AXI_aclk) then
    if M_AXI_aresetn = '0' then
        axi_wvalid <= '0';
    else
        if WritePulse = '1' then
            axi_wvalid <= '1';
            M_AXI_wdata <= DataIn;
            M_AXI_wstrb <= WrByteEna;
        -- Check if handshake occured
        elsif M_AXI_wready = '1' and axi_wvalid = '1' then
            axi_wvalid <= '0';
        end if;
    end if;
end if;
end process;

-- process receiving the write response
process (M_AXI_aclk) 
begin
if rising_edge(M_AXI_aclk) then
    if M_AXI_aresetn = '0' then
        axi_bready <= '0';
    else
        if WritePulse = '1' then
            axi_bready <= '1';
        -- Check if handshake occured
        elsif axi_bready = '1' and M_AXI_bvalid = '1' then
            axi_bready <= '0';
            -- response is in M_AXI_bresp, is ignored here
        end if;
    end if;
end if;
end process;

-- process reading the data
process (M_AXI_aclk) 
begin
if rising_edge(M_AXI_aclk) then
    if M_AXI_aresetn = '0' then
        axi_rready <= '0';
    else
        if ReadPulse = '1' then
            axi_rready <= '1';
        -- Check if handshake occured
        elsif  axi_rready = '1' and M_AXI_rvalid = '1' then
            axi_rready <= '0';
            DataOut <= M_AXI_rdata;
            -- response is in M_AXI_rresp, is ignored here
        end if;
    end if;
end if;
end process;

end Behavioral;
