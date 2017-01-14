----------------------------------------------------------------------------------
-- Company: CEI
-- Engineer: David Aledo
--
-- Create Date:    12:41:19 06/10/2013
-- Design Name:    Configurable ANN
-- Module Name:    layerSP_top - Behavioral
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description: neuron layer top for artificial neural networks. Serial input and
--             parallel output.
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
use ieee.numeric_std.all;

-- Deprecated XPS library:
--library proc_common_v3_00_a;
--use proc_common_v3_00_a.proc_common_pkg.all; -- Only for simulation ( pad_power2() )

entity layerSP_top is

   generic
   (
      NumN    : natural := 8;   ------- Number of neurons of the layer
      NumIn   : natural := 64;  ------- Number of inputs of each neuron
      NbitIn  : natural := 8;   ------- Bit width of the input data
      NbitW   : natural := 8;   ------- Bit width of weights and biases
      NbitOut : natural := 12;  ------- Bit width of the output data
      lra_l   : natural := 10;  ------- Layer RAM address length. It should value log2(NumN)+log2(NumIn)
      wra_l   : natural := 6;   ------- Weight RAM address length. It should value log2(NumIn)
      bra_l   : natural := 3;   ------- Bias RAM address length. It should value log2(NumN)
      LSbit   : natural := 4    ------- Less significant bit of the outputs
   );

   port
   (
      -- Input ports
      reset   : in  std_logic;
      clk     : in  std_logic;
      run_in  : in  std_logic; -- Start and input data validation
      m_en    : in  std_logic; -- Memory enable (external interface)
      b_sel   : in  std_logic; -- Bias memory select
      m_we    : in  std_logic_vector(((NbitW+7)/8)-1 downto 0); -- Memory write enable (external interface)
      inputs  : in  std_logic_vector(NbitIn-1 downto 0); -- Input data (serial)
      wdata   : in  std_logic_vector(NbitW-1 downto 0);  -- Write data of weight and bias memories
      addr    : in  std_logic_vector(lra_l-1 downto 0); -- Address of weight and bias memories

      -- Output ports
      run_out : out std_logic; -- Output data validation, run_in for the next layer
      rdata   : out std_logic_vector(NbitW-1 downto 0);  -- Read data of weight and bias memories
      outputs : out std_logic_vector((NbitOut*NumN)-1 downto 0) -- Output data (parallel)
   );

end layerSP_top;

architecture Behavioral of layerSP_top is

   --type ramd_type is array (pad_power2(NumIn)-1 downto 0) of std_logic_vector(NbitW-1 downto 0); -- Optimal: 32 or 64 spaces
   --type layer_ram is array (pad_power2(NumN)-1 downto 0) of ramd_type;
   type ramd_type is array (NumIn-1 downto 0) of std_logic_vector(NbitW-1 downto 0); -- Optimal: 32 or 64 spaces
   type layer_ram is array (NumN-1 downto 0) of ramd_type;
   type outm_type is array (NumN-1 downto 0) of std_logic_vector(NbitW-1 downto 0);

   signal lram  : layer_ram; -- Layer RAM. One RAM per neuron. It stores the weights
   signal breg  : outm_type; -- Bias registers. They can not be RAM because they are accessed simultaneously
   signal outm  : outm_type; -- RAM outputs to be multiplexed into rdata
   signal m_sel : std_logic_vector(NumN-1 downto 0);     -------- RAM select
   signal Wyb   : std_logic_vector((NbitW*NumN)-1 downto 0);  --- Weight vectors
   signal bias  : std_logic_vector((NbitW*NumN)-1 downto 0);  --- Bias vector
   signal Nouts : std_logic_vector((NbitOut*NumN)-1 downto 0); -- Outputs from neurons
   signal uaddr : unsigned(lra_l-1 downto 0); -- Unsigned address of weight and bias memories

   signal inreg : std_logic_vector(NbitIn-1 downto 0); -- Input data register -- en1 is delayed 1 cycle in order to insert a register for Wyb

   -- Control signals
   signal cont : integer range 0 to NumIn-1; -- Input counter
   signal en1 : std_logic; -- First step enable (multiplication of MAC)
   signal en2 : std_logic; -- Second stage enable (accumulation of MAC)
   signal en3 : std_logic; -- Shift register enable
   signal a0  : std_logic; -- Signal to load accumulators with the multiplication result
   signal aux_en3 : std_logic; -- Auxiliary signal to delay en3 two cycles
   signal aux_a0 : std_logic;
   signal aux2_en3 : std_logic;

begin

layerSP_inst: entity work.layerSP
   generic map
   (
      NumN    => NumN,
      NumIn   => NumIn,
      NbitIn  => NbitIn,
      NbitW   => NbitW,
      NbitOut => NbitOut,
      LSbit   => LSbit
   )
   port map
   (
      -- Input ports
      reset  => reset,
      clk    => clk,
      en     => en1,
      en2    => en2,
      en_r   => en3,
      a0     => a0,
      inputs => inreg,
      Wyb    => Wyb,
      bias   => bias,

      -- Output ports
      outputs => Nouts
   );

   uaddr <= unsigned(addr);

ram_selector:
   process (uaddr(lra_l-1 downto wra_l),b_sel) -- Top part of memory address and b_sel
   begin
      m_sel <= (others => '0'); -- Default
      for i in (NumN-1) downto 0 loop
         -- The top part of memory address selects which RAM
         if ( (to_integer(uaddr(lra_l-1 downto wra_l)) = i) and (b_sel = '0')) then
            m_sel(i) <= '1'; -- Enables the selected RAM
         end if;
      end loop;
   end process;

rams: -- Instance as weight and bias memories as neurons there are in the layer
   for i in (NumN-1) downto 0 generate
      process (clk)
         variable d : std_logic_vector(NbitW-1 downto 0); -- Beware of elements whose length is not a multiple of 8
      begin
         if (clk'event and clk = '1') then
            if (m_en = '1' and m_sel(i) = '1') then
               for j in ((NbitW+7)/8)-1 downto 0 loop -- we byte to byte
                  if (m_we(j) = '1') then
                     d((8*(j+1))-1 downto 8*j) := wdata((8*(j+1))-1 downto 8*j);
                  else
                     d((8*(j+1))-1 downto 8*j) := lram(i)(to_integer(uaddr(wra_l-1 downto 0)))((8*(j+1))-1 downto 8*j);
                  end if;
               end loop;
               -- Bottom part of layer memory selects weights inside the selected RAM
               lram(i)(to_integer(uaddr(wra_l-1 downto 0))) <= d;
               --
            end if;
         end if;
      end process;
      -- Outputs are read in parallel, resulting in a bus of weights:
      --Wyb((NbitW*(i+1))-1 downto NbitW*i) <= lram(i)(cont); -- Asynchronous read (forces distributed RAM)
      process (clk) -- Synchronous read
      begin
         if clk'event and clk = '1' then
            if reset = '1' then
               --Wyb((NbitW*(i+1))-1 downto NbitW*i) <= (others => '0');
            else
               Wyb((NbitW*(i+1))-1 downto NbitW*i) <= lram(i)(cont);
            end if;
         end if;
      end process;
      outm(i) <= lram(i)(to_integer(uaddr(wra_l-1 downto 0))); -- Read all RAM
   end generate;

   -- Synchronous read including breg:
   process (clk)
   begin
      if (clk'event and clk = '1') then
         if (m_en = '1') then
            if (b_sel = '1') then
               rdata <= breg(to_integer(uaddr(bra_l-1 downto 0))); -- Bias registers selected
            else -- Other RAM selected:
               rdata <= outm(to_integer(uaddr(lra_l-1 downto wra_l))); -- Multiplexes RAM outputs
               -- May be safer if accesses to top address grater than NumN are avoided
            end if;
         end if;
      end if;
   end process;

bias_reg:
   process (clk)
      variable d : std_logic_vector(NbitW-1 downto 0); -- Beware of elements whose length is not a multiple of 8
   begin
      if (clk'event and clk = '1') then
         if ( (m_en = '1') and (b_sel = '1') ) then
            for i in ((NbitW+7)/8)-1 downto 0 loop -- we byte to byte
               if (m_we(i) = '1') then
                  d((8*(i+1))-1 downto 8*i) := wdata((8*(i+1))-1 downto 8*i);
               else
                  d((8*(i+1))-1 downto 8*i) := breg(to_integer(uaddr(bra_l-1 downto 0)))((8*(i+1))-1 downto 8*i);
               end if;
            end loop;
            -- The bottom part (reduced) of layer RAM address selects the bias
            breg(to_integer(uaddr(bra_l-1 downto 0))) <= d;
         end if;
      end if;
   end process;
bias_read:
   for i in (NumN-1) downto 0 generate
      --bias((NbitW*(i+1))-1 downto NbitW*i) <= breg(i); -- Asynchronous read of all biases in parallel
      process (clk)
      begin
        if clk'event and clk = '1' then
           if reset = '1' then
              --bias((NbitW*(i+1))-1 downto NbitW*i) <= (others => '0');
           else
              bias((NbitW*(i+1))-1 downto NbitW*i) <= breg(i); -- Synchronous read of all biases in parallel
           end if;
        end if;
      end process;
   end generate;

   outputs <= Nouts;

control:
   process (clk)
   begin
      if (clk'event and clk = '1') then
         if (reset = '1') then
            cont <= 0;
            en1 <= '0';
            en2 <= '0';
            en3 <= '0';
            a0  <= '0';
            run_out <= '0';
            aux_en3 <= '0';
            aux2_en3 <= '0';
            aux_a0 <= '0';
            inreg <= (others => '0');
         else
            en1 <= run_in; -- en1 is delayed 1 cycle in order to insert a register for Wyb
            inreg <= inputs;
            -- Default:
            aux2_en3 <= '0';
            if (run_in = '1') then
               if (cont = NumIn-1) then
                  cont <= 0; -- Restarts input counter
                  aux2_en3 <= '1';
               else
                  cont <= cont +1;
               end if;
            end if;
            en2 <= en1;
            if (cont = 0 and run_in = '1') then
               aux_a0 <= '1'; -- At the count beginning
            else
               aux_a0 <= '0';
            end if;
            a0 <= aux_a0;
            aux_en3 <= aux2_en3;
            en3 <= aux_en3;
            run_out <= en3; -- It lasts for 1 cycle, just after the output enable of the layer (when all outputs have just updated)
         end if;
      end if;
   end process;

end Behavioral;