// =============================================================================
// pl_dmem.sv
// Memoria de dados -- RV32I pipelined
//
// Capacidade : 256 palavras x 32 bits = 1 KB
// Init file  : data.mif   (sintese Quartus)
//              data.hex   (simulacao ModelSim via $readmemh)
//
// Leitura  : assincrona (combinatorial) -- disponivel no estagio MEM
// Escrita  : sincrona (posedge clk, gated por MemWrite & ~mmio_sel)
// Endereco : alu_result[9:2]  (endereco de palavra de 8 bits)
// =============================================================================

`timescale 1ns / 1ps

module pl_dmem (
    input  logic        clk,
    input  logic        MemWrite,
    input  logic [9:0]  addr, //Foi necessário obter o endereço completo para calcular o offset
    input  logic [31:0] WriteData,
    input  logic [2:0]  funct3,
    output logic [31:0] ReadData
);
    logic [3:0] half_offset;
    logic [3:0] byte_offset;
    
    (* ram_init_file = "data.mif" *) logic [31:0] ram [0:255];

    // synthesis translate_off
    initial begin
        for (int i = 0; i < 256; i++) ram[i] = 32'h00000000;
        $readmemh("data.hex", ram);
    end

    // synthesis translate_on
    assign half_offset = addr[1] << 4;
    assign byte_offset = addr[1:0] << 3;

    /*OBS: Nos acessos em que é necessário acessar uma parte diferente da palavra (lb, por exemplo) foi utilizado 
    o formato de seleção de parte indexada que funciona da seguinte forma: vetor[posicao base (+ se for incrementar ou - para decrementar): tamanho do bloco].
    Dessa forma, é necessário apenas mudar a posição base, simplificando a notação*/
    
    //STORES
    always@(posedge clk) begin
        if (MemWrite) begin
            case (funct3)
                3'h00: ram[addr[9:2]][byte_offset +: 8] <= WriteData[7:0];   // SB
                3'h01: ram[addr[9:2]][half_offset +: 16] <= WriteData[15:0];  // SH
                3'h02: ram[addr[9:2]] <= WriteData;                          // SW
                default: ram[addr[9:2]] <= WriteData;
            endcase
        end
    end
    
    //LOADS
    always_comb begin
        case (funct3)
            3'd00:   ReadData = {{24{ram[addr][byte_offset + 7]}}, ram[addr[9:2]][byte_offset +: 8]};    //LB
            3'd04:   ReadData = {24'b0, ram[addr[9:2]][byte_offset +: 8]};                 //LBU
            3'd01:   ReadData = {{16{ram[addr][half_offset + 15]}}, ram[addr[9:2]][half_offset +: 16]};  //LH
            3'd05:   ReadData = {16'b0, ram[addr[9:2]][half_offset +: 16]};                //LHU
            3'd02:   ReadData = ram[addr[9:2]];                                       //LW
            default: ReadData = ram[addr[9:2]];
        endcase
    end

endmodule
