library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_trident_core_integrated is
end tb_trident_core_integrated;

architecture Behavioral of tb_trident_core_integrated is

    component trident_core_integrated
        Port (
            clk             : in  STD_LOGIC;
            reset           : in  STD_LOGIC;
            masterkey_seed  : in  STD_LOGIC_VECTOR(31 downto 0);
            kabel_a_valid   : in  STD_LOGIC;
            kabel_b_valid   : in  STD_LOGIC;
            kabel_c_valid   : in  STD_LOGIC;
            payload_in      : in  STD_LOGIC_VECTOR(255 downto 0);
            noise_key       : in  STD_LOGIC_VECTOR(255 downto 0);
            payload_out     : out STD_LOGIC_VECTOR(255 downto 0);
            system_status   : out STD_LOGIC_VECTOR(1 downto 0);
            decrypted_out   : out STD_LOGIC_VECTOR(255 downto 0)
        );
    end component;

    signal clk             : STD_LOGIC := '0';
    signal reset           : STD_LOGIC := '0';
    signal masterkey_seed  : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    signal kabel_a_valid   : STD_LOGIC := '1';
    signal kabel_b_valid   : STD_LOGIC := '1';
    signal kabel_c_valid   : STD_LOGIC := '1';
    signal payload_in      : STD_LOGIC_VECTOR(255 downto 0) := (others => '0');
    signal noise_key       : STD_LOGIC_VECTOR(255 downto 0) := (others => '0');
    
    signal payload_out     : STD_LOGIC_VECTOR(255 downto 0);
    signal system_status   : STD_LOGIC_VECTOR(1 downto 0);
    signal decrypted_out   : STD_LOGIC_VECTOR(255 downto 0);

    constant clk_period : time := 10 ns;

begin

    uut: trident_core_integrated Port Map (
          clk => clk,
          reset => reset,
          masterkey_seed => masterkey_seed,
          kabel_a_valid => kabel_a_valid,
          kabel_b_valid => kabel_b_valid,
          kabel_c_valid => kabel_c_valid,
          payload_in => payload_in,
          noise_key => noise_key,
          payload_out => payload_out,
          system_status => system_status,
          decrypted_out => decrypted_out
        );

    clk_process :process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    process
    begin		
        reset <= '1';
        payload_in <= X"54454C454D45545249455F4E4F44455F36475F4C4154454E43595F4441544131"; 
        noise_key  <= X"AFAFAFAFAFAFAFAFAFAFAFAFAFAFAFAFAFAFAFAFAFAFAFAFAFAFAFAFAFAFAFAF"; 
        wait for 20 ns;	
        
        reset <= '0';
        wait for 20 ns; 

        -- Handshake op 40 ns
        masterkey_seed <= X"A1E2026B"; 
        wait for 20 ns; 

        -- CRASH 1 (60 ns tot 70 ns)
        kabel_a_valid <= '0'; kabel_b_valid <= '0'; kabel_c_valid <= '0';
        wait for 10 ns;
        -- AUTOMATISCHE REBOOT 1 (70 ns tot 80 ns)
        kabel_a_valid <= '1'; kabel_b_valid <= '1'; kabel_c_valid <= '1';
        wait for 10 ns;

        -- CRASH 2 (80 ns tot 90 ns)
        kabel_a_valid <= '0'; kabel_b_valid <= '0'; kabel_c_valid <= '0';
        wait for 10 ns;
        -- AUTOMATISCHE REBOOT 2 (90 ns tot 100 ns)
        kabel_a_valid <= '1'; kabel_b_valid <= '1'; kabel_c_valid <= '1';
        wait for 10 ns;

        -- CRASH 3 (Bij 100 ns) -> Vanaf hier moet de kluis permanent op slot!
        kabel_a_valid <= '0'; kabel_b_valid <= '0'; kabel_c_valid <= '0';
        
        wait;
    end process;

end Behavioral;
