library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity trident_core_integrated is
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
end trident_core_integrated;

architecture Behavioral of trident_core_integrated is
    signal authenticated    : STD_LOGIC := '0';
    signal pad_status       : STD_LOGIC_VECTOR(2 downto 0);
    signal selected_payload : STD_LOGIC_VECTOR(255 downto 0) := (others => '0');
    
    -- Zender-registers
    signal blended_seed     : STD_LOGIC_VECTOR(255 downto 0);
    signal sha3_pseudo_reg  : STD_LOGIC_VECTOR(255 downto 0) := (others => '0');
    signal xor_matrix_out   : STD_LOGIC_VECTOR(255 downto 0) := (others => '0');
    
    -- Ontvanger-registers
    signal rx_blended_seed    : STD_LOGIC_VECTOR(255 downto 0);
    signal rx_sha3_pseudo_reg : STD_LOGIC_VECTOR(255 downto 0) := (others => '0');

    -- ENTERPRISE TAND 3 TELLER (Zonder de cooldown-timer v1)
    signal crash_counter    : unsigned(1 downto 0) := "00";
    signal force_lockout    : STD_LOGIC := '0';
    signal prev_pad_status  : STD_LOGIC_VECTOR(2 downto 0) := "111";

    constant KECCAK_ROUND_CONSTANT : STD_LOGIC_VECTOR(255 downto 0) := 
        X"9B9B9B9B00000000FFFFFFFF12345678AFAFAFAF00FF00FF0101010120262026";
begin

    pad_status <= kabel_a_valid & kabel_b_valid & kabel_c_valid;
    authenticated <= '1' when (masterkey_seed = X"A1E2026B") else '0';

    -- [TAND 1]
    process(pad_status, payload_in)
    begin
        if (pad_status(2) = '1') then selected_payload <= payload_in;
        elsif (pad_status(1) = '1') then selected_payload <= payload_in;
        elsif (pad_status(0) = '1') then selected_payload <= payload_in;
        else selected_payload <= (others => '0');
        end if;
    end process;

    blended_seed <= selected_payload xor noise_key;

    -- [TAND 2 - ZENDER]
    process(clk)
        variable temp_matrix : STD_LOGIC_VECTOR(255 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                sha3_pseudo_reg <= (others => '0');
                xor_matrix_out  <= (others => '0');
            elsif authenticated = '1' then
                temp_matrix := blended_seed(127 downto 0) & blended_seed(255 downto 128);
                sha3_pseudo_reg <= (temp_matrix xor KECCAK_ROUND_CONSTANT) or (not temp_matrix and noise_key);
                xor_matrix_out <= selected_payload xor sha3_pseudo_reg;
            else
                sha3_pseudo_reg <= (others => '0');
                xor_matrix_out  <= (others => '0');
            end if;
        end if;
    end process;

    -- [TAND 3 TELLER]
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                crash_counter <= "00";
                force_lockout <= '0';
                prev_pad_status <= "111";
            else
                prev_pad_status <= pad_status;
                
                if (pad_status = "000" and prev_pad_status /= "000") then
                    if (crash_counter < "11") then
                        crash_counter <= crash_counter + 1;
                    end if;
                end if;

                if (crash_counter = "11") then
                    force_lockout <= '1';
                end if;
            end if;
        end if;
    end process;

    -- [TAND 3 - ASYNCHRONE EGRESS GATE]
    process(pad_status, xor_matrix_out, authenticated, force_lockout)
    begin
        if (force_lockout = '1' or pad_status = "000") then
            payload_out   <= (others => 'Z'); 
            system_status <= "11";            
        elsif (authenticated = '0') then
            payload_out   <= (others => '0');
            system_status <= "00";            
        else
            payload_out   <= xor_matrix_out;
            system_status <= "01";            
        end if;
    end process;

    -- [ONTVANGER - REVERSAL CORE]
    rx_blended_seed <= xor_matrix_out xor noise_key;

    process(clk)
        variable rx_temp_matrix : STD_LOGIC_VECTOR(255 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                rx_sha3_pseudo_reg <= (others => '0');
            elsif authenticated = '1' then
                rx_temp_matrix := rx_blended_seed(127 downto 0) & rx_blended_seed(255 downto 128);
                rx_sha3_pseudo_reg <= (rx_temp_matrix xor KECCAK_ROUND_CONSTANT) or (not rx_temp_matrix and noise_key);
            else
                rx_sha3_pseudo_reg <= (others => '0');
            end if;
        end if;
    end process;

    process(authenticated, xor_matrix_out, rx_sha3_pseudo_reg)
    begin
        if authenticated = '1' then
            decrypted_out <= xor_matrix_out xor rx_sha3_pseudo_reg;
        else
            decrypted_out <= (others => '0');
        end if;
    end process;

end Behavioral;
