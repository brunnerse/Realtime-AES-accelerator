library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity AES_Interface_M_3_v1_0_M_AXI is
	generic (
		-- Thread ID Width
		C_M_AXI_ID_WIDTH	: integer	:= 1;
		-- Width of Address Bus
		C_M_AXI_ADDR_WIDTH	: integer	:= 32;
		-- Width of Data Bus
		C_M_AXI_DATA_WIDTH	: integer	:= 32;
		-- Width of User Write Address Bus
		C_M_AXI_AWUSER_WIDTH	: integer	:= 0;
		-- Width of User Read Address Bus
		C_M_AXI_ARUSER_WIDTH	: integer	:= 0;
		-- Width of User Write Data Bus
		C_M_AXI_WUSER_WIDTH	: integer	:= 0;
		-- Width of User Read Data Bus
		C_M_AXI_RUSER_WIDTH	: integer	:= 0;
		-- Width of User Response Bus
		C_M_AXI_BUSER_WIDTH	: integer	:= 0
	);
	port (
		-- Users to add ports here
		-- ReadyValid_RW_Port
        S_RW_VALID : in std_logic;
        S_RW_READY : out std_logic;
        S_RW_ADDR : in std_logic_vector(31 downto 0);
        S_RW_WRDATA : in std_logic_vector(127 downto 0);
        S_RW_RDDATA : out std_logic_vector(127 downto 0);
        S_RW_WRITE : in std_logic; 
		S_RW_ERROR	: out std_logic;
		-- ReadyValid_RegMem_Port
		S_RM_VALID : in std_logic;
        S_RM_READY : out std_logic;
        S_RM_ADDR : in std_logic_vector(31 downto 0);
        S_RM_LENGTH : in std_logic_vector(7 downto 0);
        S_RM_WRITE : in std_logic;
        S_RM_ERROR : out std_logic;
        S_RM_RDREADY : in std_logic;
        S_RM_RDVALID : out std_logic;
        S_RM_RDDATA : out std_logic_vector(31 downto 0);
        S_RM_WRREADY : out std_logic;
        S_RM_WRVALID : in std_logic;
        S_RM_WRDATA : in std_logic_vector(31 downto 0);
		-- User ports ends
		-- Do not modify the ports beyond this line

		-- Global Clock Signal.
		M_AXI_ACLK	: in std_logic;
		-- Global Reset Singal. This Signal is Active Low
		M_AXI_ARESETN	: in std_logic;
		-- Master Interface Write Address ID
		M_AXI_AWID	: out std_logic_vector(C_M_AXI_ID_WIDTH-1 downto 0);
		-- Master Interface Write Address
		M_AXI_AWADDR	: out std_logic_vector(C_M_AXI_ADDR_WIDTH-1 downto 0);
		-- Burst length. The burst length gives the exact number of transfers in a burst
		M_AXI_AWLEN	: out std_logic_vector(7 downto 0);
		-- Burst size. This signal indicates the size of each transfer in the burst
		M_AXI_AWSIZE	: out std_logic_vector(2 downto 0);
		-- Burst type. The burst type and the size information, 
    -- determine how the address for each transfer within the burst is calculated.
		M_AXI_AWBURST	: out std_logic_vector(1 downto 0);
		-- Lock type. Provides additional information about the
    -- atomic characteristics of the transfer.
		M_AXI_AWLOCK	: out std_logic;
		-- Memory type. This signal indicates how transactions
    -- are required to progress through a system.
		M_AXI_AWCACHE	: out std_logic_vector(3 downto 0);
		-- Protection type. This signal indicates the privilege
    -- and security level of the transaction, and whether
    -- the transaction is a data access or an instruction access.
		M_AXI_AWPROT	: out std_logic_vector(2 downto 0);
		-- Quality of Service, QoS identifier sent for each write transaction.
		M_AXI_AWQOS	: out std_logic_vector(3 downto 0);
		-- Optional User-defined signal in the write address channel.
		M_AXI_AWUSER	: out std_logic_vector(C_M_AXI_AWUSER_WIDTH-1 downto 0);
		-- Write address valid. This signal indicates that
    -- the channel is signaling valid write address and control information.
		M_AXI_AWVALID	: out std_logic;
		-- Write address ready. This signal indicates that
    -- the slave is ready to accept an address and associated control signals
		M_AXI_AWREADY	: in std_logic;
		-- Master Interface Write Data.
		M_AXI_WDATA	: out std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0);
		-- Write strobes. This signal indicates which byte
    -- lanes hold valid data. There is one write strobe
    -- bit for each eight bits of the write data bus.
		M_AXI_WSTRB	: out std_logic_vector(C_M_AXI_DATA_WIDTH/8-1 downto 0);
		-- Write last. This signal indicates the last transfer in a write burst.
		M_AXI_WLAST	: out std_logic;
		-- Optional User-defined signal in the write data channel.
		M_AXI_WUSER	: out std_logic_vector(C_M_AXI_WUSER_WIDTH-1 downto 0);
		-- Write valid. This signal indicates that valid write
    -- data and strobes are available
		M_AXI_WVALID	: out std_logic;
		-- Write ready. This signal indicates that the slave
    -- can accept the write data.
		M_AXI_WREADY	: in std_logic;
		-- Master Interface Write Response.
		M_AXI_BID	: in std_logic_vector(C_M_AXI_ID_WIDTH-1 downto 0);
		-- Write response. This signal indicates the status of the write transaction.
		M_AXI_BRESP	: in std_logic_vector(1 downto 0);
		-- Optional User-defined signal in the write response channel
		M_AXI_BUSER	: in std_logic_vector(C_M_AXI_BUSER_WIDTH-1 downto 0);
		-- Write response valid. This signal indicates that the
    -- channel is signaling a valid write response.
		M_AXI_BVALID	: in std_logic;
		-- Response ready. This signal indicates that the master
    -- can accept a write response.
		M_AXI_BREADY	: out std_logic;
		-- Master Interface Read Address.
		M_AXI_ARID	: out std_logic_vector(C_M_AXI_ID_WIDTH-1 downto 0);
		-- Read address. This signal indicates the initial
    -- address of a read burst transaction.
		M_AXI_ARADDR	: out std_logic_vector(C_M_AXI_ADDR_WIDTH-1 downto 0);
		-- Burst length. The burst length gives the exact number of transfers in a burst
		M_AXI_ARLEN	: out std_logic_vector(7 downto 0);
		-- Burst size. This signal indicates the size of each transfer in the burst
		M_AXI_ARSIZE	: out std_logic_vector(2 downto 0);
		-- Burst type. The burst type and the size information, 
    -- determine how the address for each transfer within the burst is calculated.
		M_AXI_ARBURST	: out std_logic_vector(1 downto 0);
		-- Lock type. Provides additional information about the
    -- atomic characteristics of the transfer.
		M_AXI_ARLOCK	: out std_logic;
		-- Memory type. This signal indicates how transactions
    -- are required to progress through a system.
		M_AXI_ARCACHE	: out std_logic_vector(3 downto 0);
		-- Protection type. This signal indicates the privilege
    -- and security level of the transaction, and whether
    -- the transaction is a data access or an instruction access.
		M_AXI_ARPROT	: out std_logic_vector(2 downto 0);
		-- Quality of Service, QoS identifier sent for each read transaction
		M_AXI_ARQOS	: out std_logic_vector(3 downto 0);
		-- Optional User-defined signal in the read address channel.
		M_AXI_ARUSER	: out std_logic_vector(C_M_AXI_ARUSER_WIDTH-1 downto 0);
		-- Write address valid. This signal indicates that
    -- the channel is signaling valid read address and control information
		M_AXI_ARVALID	: out std_logic;
		-- Read address ready. This signal indicates that
    -- the slave is ready to accept an address and associated control signals
		M_AXI_ARREADY	: in std_logic;
		-- Read ID tag. This signal is the identification tag
    -- for the read data group of signals generated by the slave.
		M_AXI_RID	: in std_logic_vector(C_M_AXI_ID_WIDTH-1 downto 0);
		-- Master Read Data
		M_AXI_RDATA	: in std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0);
		-- Read response. This signal indicates the status of the read transfer
		M_AXI_RRESP	: in std_logic_vector(1 downto 0);
		-- Read last. This signal indicates the last transfer in a read burst
		M_AXI_RLAST	: in std_logic;
		-- Optional User-defined signal in the read address channel.
		M_AXI_RUSER	: in std_logic_vector(C_M_AXI_RUSER_WIDTH-1 downto 0);
		-- Read valid. This signal indicates that the channel
    -- is signaling the required read data.
		M_AXI_RVALID	: in std_logic;
		-- Read ready. This signal indicates that the master can
    -- accept the read data and response information.
		M_AXI_RREADY	: out std_logic
	);
end AES_Interface_M_3_v1_0_M_AXI;

architecture implementation of AES_Interface_M_3_v1_0_M_AXI is

    function log2( i : natural) return integer is
        variable temp    : integer := i;
        variable ret_val : integer := 0; 
      begin					
        while temp > 1 loop
          ret_val := ret_val + 1;
          temp    := temp / 2;     
        end loop;
        
        return ret_val;
      end function;

    constant NUM_BURSTS : integer := 128 / C_M_AXI_DATA_WIDTH;

	-- AXI4FULL signals
	--AXI4 internal temp signals
	signal axi_awaddr	: std_logic_vector(C_M_AXI_ADDR_WIDTH-1 downto 0);
	signal axi_awvalid	: std_logic;
	signal axi_awlen    : std_logic_vector(M_AXI_AWLEN'HIGH downto 0);
	signal axi_awsize   : std_logic_vector(M_AXI_AWSIZE'HIGH downto 0);
	signal axi_wdata	: std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0);
	signal axi_wstrb    : std_logic_vector(M_AXI_WSTRB'HIGH downto 0);
	signal axi_wlast	: std_logic;
	signal axi_wvalid	: std_logic;
	signal axi_bready	: std_logic;
	signal axi_araddr	: std_logic_vector(C_M_AXI_ADDR_WIDTH-1 downto 0);
	signal axi_arvalid	: std_logic;
    signal axi_arlen    : std_logic_vector(M_AXI_ARLEN'HIGH downto 0);
    signal axi_arsize   : std_logic_vector(M_AXI_ARSIZE'HIGH downto 0);
	signal axi_rready	: std_logic;
	--write beat count in a burst
	signal write_index	: std_logic_vector(S_RM_LENGTH'HIGH downto 0);

    signal RW_axi_wdata : std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0);
    signal RW_axi_wvalid : std_logic;
    signal RW_axi_rready : std_logic;
	signal RW_ready : std_logic;
    signal RW_valid_prev : std_logic;
	signal RW_valid_pulse	: std_logic;
	signal RW_ready_prev : std_logic;
	
	signal rm_ready : std_logic;
	signal rm_rdvalid : std_logic;
	signal rm_rddata : std_logic_vector(31 downto 0);
	signal rm_wrready : std_logic;
	signal rm_valid_prev, rm_valid_pulse, rm_ready_prev : std_logic;


begin
	-- I/O Connections assignments

	--I/O Connections. Write Address (AW)
	M_AXI_AWID	<= (others => '0');
	--The AXI address is a concatenation of the target base address + active offset range
	M_AXI_AWADDR	<= axi_awaddr;
	--Burst LENgth is number of transaction beats, minus 1
	M_AXI_AWLEN	<= axi_awlen; 
	--Size should be C_M_AXI_DATA_WIDTH, in 2^SIZE byte, otherwise narrow bursts are used
	M_AXI_AWSIZE	<= axi_awsize;
	--INCR burst type
	M_AXI_AWBURST	<= "01";
	M_AXI_AWLOCK	<= '0';
	--Update value to 4'b0011 if coherent accesses to be used via the Zynq ACP port. Not Allocated, Modifiable, not Bufferable. Not Bufferable since this example is meant to test memory, not intermediate cache. 
	M_AXI_AWCACHE	<= "0010";
	M_AXI_AWPROT	<= "000";
	M_AXI_AWQOS	<= x"0";
	M_AXI_AWUSER	<= (others => '1');
	M_AXI_AWVALID	<= axi_awvalid;
	--Write Data(W)
	M_AXI_WDATA	<= axi_wdata;
	--All bursts are complete and aligned
	M_AXI_WSTRB	<= axi_wstrb;
	M_AXI_WLAST	<= axi_wlast;
	M_AXI_WUSER	<= (others => '0');
	M_AXI_WVALID	<= axi_wvalid;
	--Write Response (B)
	M_AXI_BREADY	<= axi_bready;
	--Read Address (AR)
	M_AXI_ARID	<= (others => '0');
	M_AXI_ARADDR	<= axi_araddr;
	--Burst LENgth is number of transaction beats, minus 1
	M_AXI_ARLEN	<= axi_arlen;
	--Size should be C_M_AXI_DATA_WIDTH, in 2^n bytes, otherwise narrow bursts are used
	M_AXI_ARSIZE	<= axi_arsize;
	--INCR burst type is usually used, except for keyhole bursts
	M_AXI_ARBURST	<= "01";
	M_AXI_ARLOCK	<= '0';
	--Update value to 4'b0011 if coherent accesses to be used via the Zynq ACP port. Not Allocated, Modifiable, not Bufferable. Not Bufferable since this example is meant to test memory, not intermediate cache. 
	M_AXI_ARCACHE	<= "0010";
	M_AXI_ARPROT	<= "000";
	M_AXI_ARQOS	<= x"0";
	M_AXI_ARUSER	<= (others => '1');
	M_AXI_ARVALID	<= axi_arvalid;
	--Read and Read Response (R)
	M_AXI_RREADY	<= axi_rready;
	
	
	-- ReadyValid_RW_Port signals
	S_RW_READY <= RW_ready;
	-- store handshake signals from previous cycle
    RW_valid_prev <= S_RW_VALID when rising_edge(M_AXI_ACLK);
	RW_ready_prev <= RW_ready when rising_edge(M_AXI_ACLK);
	-- pulse from RW_valid signal (i.e. when to start a new transfer):
	-- either RW_valid was 0 before and is now 1,  or the previous transaction completed but S_RW_valid is still high
	RW_valid_pulse	<= S_RW_VALID and (not RW_valid_prev or RW_ready_prev);

    
    -- ReadyValid_RegMem_Port signals
    S_RM_READY <= rm_ready;
    S_RM_RDVALID <= rm_rdvalid;
    S_RM_RDDATA <= rm_rddata;
    S_RM_WRReady <= rm_wrready;

    -- delay rm_valid_prev if RW port is currently active
    rm_valid_prev <= S_RM_VALID when rising_edge(M_AXI_ACLK) and S_RW_VALID = '0';
	rm_ready_prev <= rm_ready when rising_edge(M_AXI_ACLK);
	-- pulse from RW_valid signal (i.e. when to start a new transfer):
	-- either RM_valid was 0 before and is now 1,  or the previous transaction completed but S_RM_valid is still high
	rm_valid_pulse	<= S_RM_VALID and (not rm_valid_prev or rm_ready_prev);
	
	-- forward the AXI signals to the RM signals when S_RW_VALID is 0 (i.e. RW port isnt active)
	rm_rdvalid <= M_AXI_RVALID when S_RW_VALID = '0' else '0';
	rm_rddata <= M_AXI_RDATA;
	rm_wrready <= M_AXI_WREADY when S_RW_VALID = '0' else '0';
	
	-- Set certain AXI signals depending on which input port is active
	-- RW Port uses the full bus width, RegMem Port only 32 bits
	axi_wdata <=  RW_axi_wdata when S_RW_VALID = '1'  else  std_logic_vector(to_unsigned(0, axi_wdata'LENGTH-32)) & S_RM_WRDATA;
	axi_wstrb <= (others => '1') when S_RW_VALID = '1' else 
	              std_logic_vector(to_unsigned(0, axi_wstrb'LENGTH-4)) & "1111";
    axi_wvalid <= RW_axi_wvalid when S_RW_VALID = '1' else S_RM_WRVALID;
    axi_rready <= RW_axi_rready when S_RW_VALID = '1' else S_RM_RDREADY;

	----------------------
	--Write Address Channel
	----------------------

	-- The purpose of the write address channel is to request the address and 
	-- command information for the entire transaction.  It is a single beat
	-- of information.
    
      -- drives axi_awvalid, axi_awlen, axi_awaddr, axi_awsize
	  process(M_AXI_ACLK)                                            
	  begin                                                                
	    if (rising_edge (M_AXI_ACLK)) then                                 
	      if (M_AXI_ARESETN = '0') then                                   
	        axi_awvalid <= '0';                                      
	      else                                                             
	        -- start next transaction            
	        if (RW_valid_pulse = '1' and S_RW_WRITE = '1') then 
                  axi_awvalid <= '1';
                  axi_awaddr <= S_RW_ADDR;
                  axi_awlen <= std_logic_vector( to_unsigned(NUM_BURSTS - 1, 8) );
                  axi_awsize <=  std_logic_vector( to_unsigned(log2(C_M_AXI_DATA_WIDTH/8), 3) );      
            elsif (rm_valid_pulse = '1' and S_RM_WRITE = '1') then
                   axi_awvalid <= '1';
                   axi_awaddr <= S_RM_ADDR;
                   axi_awlen <= std_logic_vector(unsigned(S_RM_LENGTH)-to_unsigned(1, S_RM_LENGTH'LENGTH));
                   -- RegMem Port uses only 32 bits
                   axi_awsize <= std_logic_vector( to_unsigned(log2(32/8), 3) );                                   
            -- deassert once the address has been accepted          
	        elsif (M_AXI_AWREADY = '1' and axi_awvalid = '1') then         
                  axi_awvalid <= '0';                                                                        
	        end if;                                                        
	      end if;                                                          
	    end if;                                                            
	  end process;                                                                                                          

	----------------------
	--Write Data Channel
	----------------------

	--The write data will continually try to push write data across the interface.


                                                                                                              
	-- WVALID logic, similar to the axi_awvalid always block above                      
	  process(M_AXI_ACLK)                                                               
	  begin                                                                             
	    if (rising_edge (M_AXI_ACLK)) then                                              
	      if (M_AXI_ARESETN = '0') then                                            
	           RW_axi_wvalid <= '0';                                                          
	      else 
		  	-- set wvalid to 1 at the start of the transfer                                                                        
	        if (RW_valid_pulse =  '1' and S_RW_WRITE = '1') then                           
                  RW_axi_wvalid <= '1'; 
			-- deassert wvalid after the last write handshake                                                                     
	        elsif (M_AXI_WREADY = '1' and axi_wvalid = '1' and axi_wlast = '1') then                                
	               RW_axi_wvalid <= '0';                                                                                                   
	        end if;                                                                     
	      end if;                                                                       
	    end if;                                                                         
	  end process;                                                                      
	                                                                                    
	--WLAST generation on the MSB of a counter underflow                                
	-- WVALID logic, similar to the axi_awvalid always block above                      
	  process(M_AXI_ACLK)                                                               
	  begin                                                                             
        if (rising_edge (M_AXI_ACLK)) then                                              
	      if (M_AXI_ARESETN = '0') then                                                
                axi_wlast <= '0';                                                           
	      else
                -- init wlast when new transaction starts
                if RW_valid_pulse = '1' then
                     -- if transaction is only one burst long, assert wlast immediately
                     if NUM_BURSTS = 1 then
                         axi_wlast <= '1';
                     else
                         axi_wlast <= '0';
                     end if;
                elsif rm_valid_pulse = '1' then
                     if unsigned(S_RM_LENGTH) <= to_unsigned(4, S_RM_LENGTH'LENGTH) then
                         axi_wlast <= '1';
                     else
                         axi_wlast <= '0';
                     end if;
                -- update wlast at each handshake
                elsif M_AXI_WREADY= '1' and axi_wvalid = '1' then
                    if S_RW_VALID = '1' and write_index = std_logic_vector(to_unsigned(NUM_BURSTS-2, write_index'LENGTH)) then
                        axi_wlast <= '1';
                    elsif S_RM_VALID = '1' and write_index = std_logic_vector(unsigned(S_RM_LENGTH) - 2) then
                        axi_wlast <= '1';
                    else 
                        axi_wlast <= '0';
                    end if;
                end if;                                                    
	      end if;                                                                       
	    end if;                                                                         
	  end process;                                                                      
	                                                                                    
	-- Burst length counter. Uses extra counter register bit to indicate terminal       
	-- count to reduce decode logic */                                                  
	  process(M_AXI_ACLK)   
	       variable idx_offset : integer;                                                              
	  begin                                                                             
	    if (rising_edge (M_AXI_ACLK)) then                                              
	      if RW_valid_pulse = '1' or rm_valid_pulse = '1' then               
	           write_index <= (others => '0');
	           RW_axi_wdata <= S_RW_wrData(127 downto 128 - C_M_AXI_DATA_WIDTH);                                 
	      else                                                                          
	           -- update write_index and wdata at each handshake
               if M_AXI_WREADY= '1' and axi_wvalid = '1' then
                   idx_offset := to_integer(unsigned(write_index)+1) * C_M_AXI_DATA_WIDTH;    
                   RW_axi_wdata <= S_RW_wrData(127 - idx_offset downto 128 - C_M_AXI_DATA_WIDTH - idx_offset);                   
	               write_index <= std_logic_vector(unsigned(write_index) + 1);                 
               end if;                                                                     
	      end if;                                                                       
	    end if;                                                                         
	  end process;                                                                      

	------------------------------
	--Write Response (B) Channel
	------------------------------

	--The write response channel provides feedback that the write has committed
	--to memory. BREADY will occur when all of the data and the write address
	--has arrived and been accepted by the slave.

	--The write issuance (number of outstanding write addresses) is started by 
	--the Address Write transfer, and is completed by a BREADY/BRESP.

	--While negating BREADY will eventually throttle the AWREADY signal, 
	--it is best not to throttle the whole data channel this way.

	--The BRESP bit [1] is used indicate any errors from the interconnect or
	--slave for the entire write burst. This example will capture the error 
	--into the ERROR output. 

	-- set bready to 1 during the entire transfer (if it is a write transfer)
      axi_bready <= S_RW_VALID and S_RW_WRITE;                                             

	------------------------------
	--Read Address Channel
	------------------------------

	--The Read Address Channel (AW) provides a similar function to the
	--Write Address channel- to provide the tranfer qualifiers for the burst.
	-- drives axi_arvalid, axi_araddr, axi_arlen, axi_arsize
	  process(M_AXI_ACLK)										  
	  begin                                                              
	    if (rising_edge (M_AXI_ACLK)) then                               
	      if (M_AXI_ARESETN = '0') then                                 
	        axi_arvalid <= '0';                                       
	     -- If previously not valid , start next transaction             
	      else              
           -- start next transaction                                          
	        if (RW_valid_pulse = '1' and S_RW_WRITE = '0') then
	              axi_arvalid <= '1';
	              axi_araddr <= S_RW_ADDR;
                  axi_arlen <= std_logic_vector( to_unsigned(NUM_BURSTS - 1, 8) );
                  axi_arsize <= std_logic_vector( to_unsigned(log2(C_M_AXI_DATA_WIDTH/8), 3) );       
            elsif (rm_valid_pulse = '1' and S_RM_WRITE = '0') then
                   axi_arvalid <= '1';
                   axi_araddr <= S_RM_ADDR;
                   axi_arlen <= std_logic_vector(unsigned(S_RM_LENGTH)-to_unsigned(1, S_RM_LENGTH'LENGTH));  
                   -- RegMem Port uses only 32 bits
                   axi_arsize <= std_logic_vector( to_unsigned(log2(32/8), 3) );             
            -- deassert once the address has been accepted                                      
	        elsif (M_AXI_ARREADY = '1' and axi_arvalid = '1') then       
	          axi_arvalid <= '0';                                        
	        end if;                                                      
	      end if;                                                        
	    end if;                                                          
	  end process;                                                             


	----------------------------------
	--Read Data (and Response) Channel
	----------------------------------                                                                                               
	                                                                        
	-- Burst length counter. Uses extra counter register bit to indicate    
	-- terminal count to reduce decode logic    
	  ReadBlock: block
	  signal idx_offset : unsigned(6 downto 0); 
	  begin                         
      process(M_AXI_ACLK)                                            
      begin                                                                 
        if (rising_edge (M_AXI_ACLK)) then                                  
          if (M_AXI_ARESETN = '0' or RW_valid_pulse = '1') then    
               idx_offset <= to_unsigned(127, idx_offset'LENGTH);                               
          else
               -- at every handshake, copy the rdata to the designated part of S_RW_rdData, then increment the read_index
               if axi_rready = '1' and M_AXI_RVALID = '1' then
                   S_RW_rdData(to_integer(idx_offset) downto to_integer(idx_offset) - C_M_AXI_DATA_WIDTH+1) <= M_AXI_RDATA;    
                   idx_offset <= idx_offset - C_M_AXI_DATA_WIDTH;                           
               end if;                                                                                                                                                         
          end if;                                                           
        end if;                                                             
      end process; 
     end block;                                                         
	                                                                        
	--/*                                                                    
	-- The Read Data channel returns the results of the read request                      
	-- */                                                                   
	  process(M_AXI_ACLK)                                                   
	  begin                                                                 
	    if (rising_edge (M_AXI_ACLK)) then                                  
	      if (M_AXI_ARESETN = '0') then             
	        RW_axi_rready <= '0';                                              
	     -- accept/acknowledge rdata/rresp with axi_rready by the master    
	      -- when M_AXI_RVALID is asserted by slave                         
	      else
	        -- assert rready at the start of the transfer
	        if RW_valid_pulse = '1' and S_RW_WRITE = '0' then
	           RW_axi_rready <= '1';
	        -- deassert rready after the last transfer                                                  
	        elsif(axi_rready = '1' and M_AXI_RVALID = '1' and M_AXI_RLAST = '1') then
	            RW_axi_rready <= '0';                                                                  
	        end if;                                              
	      end if;                                                
	    end if;                                                  
	  end process;                                               
                                                                                               
	                                                                                                                                                                                       
	 -- Set S_RW_ready when last write/read completion.                                                                                                                                                                                                                                                                 
	  process(M_AXI_ACLK)                                                                                        
	  begin                                                                                                      
	    if (rising_edge (M_AXI_ACLK)) then                                                                       
           RW_ready <= '0';
           rm_ready <= '0';
           if S_RW_VALID = '1' then    
               -- wlast doesnt matter, as there's one response for the entire transfer                                                                                           
               if (S_RW_WRITE = '1' and M_AXI_BVALID = '1' and axi_bready = '1')  or                                                               
                   (S_RW_WRITE = '0' and M_AXI_RVALID = '1' and axi_rready = '1' and M_AXI_RLAST = '1') then
                        RW_ready <= '1'; 
               end if;  
           else
            if (S_RM_WRITE = '1' and M_AXI_BVALID = '1' and axi_bready = '1')  or                                           
                   (S_RM_WRITE = '0' and M_AXI_RVALID = '1' and axi_rready = '1' and M_AXI_RLAST = '1') then
                        RM_ready <= '1';
            end if;
          end if;                                                                                                                                                                                            
	    end if;                                                                                                  
	  end process;                                                                                               
	                                                                                                                                                                                                         


	 --Register and hold any read/write interface errors 
	  process(M_AXI_ACLK)                                          
	  begin                                                              
	    if (rising_edge (M_AXI_ACLK)) then
	      if M_AXI_ARESETN = '0' then
	           S_RW_ERROR <= '0';
	           S_RM_ERROR <= '0';
	      else                               
              if (RW_valid_pulse = '1') then                                 
                   S_RW_ERROR <= '0';                                            
              end if;
              if rm_valid_pulse = '1' then
                    S_RM_ERROR <= '0';
              end if;    
                                                                     
              if (axi_bready and M_AXI_BVALID and M_AXI_BRESP(1)) = '1' or                                         
                      (axi_rready and M_AXI_RVALID and M_AXI_RRESP(1)) = '1' then
                  if S_RW_VALID = '1' then
                    S_RW_ERROR <= '1';
                  elsif S_RM_VALID = '1' then
                    S_RM_ERROR <= '1';
                  end if;                                          
                end if;                                                      
              end if;
	    end if;                                                          
	  end process;      

end implementation;
