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
// Endereco : alu_result[9:0]  (endereco de palavra de 8 bits)
// =============================================================================

`timescale 1ns / 1ps

module pl_dmem (
    input  logic        clk,
    input  logic        MemWrite,
    input  logic  [9:0] addr,       //O "fatiamento" do endereco foi alterado de addr[9:2] para addr[9:0] para permitir enderecamento de bytes e half-words
    input  logic [31:0] WriteData,
    input  logic  [2:0] funct3,     //A memoria passa a ter acesso ao valor de funct3 para determinar o tipo de acesso a memoria (byte, half-word ou word) 
    output logic [31:0] ReadData
);
    //Declaracao e inicializacao da memoria de dados por meio do arquivo data.mif
    (* ram_init_file = "data.mif" *) logic [31:0] ram [0:255];

    //Indice de deslocamento para half-word e byte
    logic [4:0] half_offset;
    logic [4:0] byte_offset;

    //Variaveis auxiliares para armazenar os dados a serem escritos e lidos da memoria
    logic [31:0] WriteWord;
    logic [31:0] ReadWord;

    // synthesis translate_off
    initial begin
        for (int i = 0; i < 256; i++) ram[i] = 32'h00000000;
        $readmemh("data.hex", ram);
    end
    //synthesis translate_on

    //Calculo do deslocamento para half-word e byte
    assign half_offset = addr[1] << 4; //Determina o half-word a ser acessado (0 ou 1) pelo endereco e multiplica por 16, para obter a posicao correta dentro da palavra
    assign byte_offset = addr[1:0] << 3; //Determina o byte a ser acessado (0, 1, 2 ou 3) pelo endereco e multiplica por 8
   
    //Observaçao: Nos acessos em que é necessário acessar uma parte diferente da palavra (lb, por exemplo) foi utilizado 
    //o formato de seleção de parte indexada que funciona da seguinte forma: vetor[posicao base (+ se for incrementar ou - para decrementar): tamanho do bloco]
    //Dessa forma, para acessar partes específicas da palavra, é necessário apenas mudar a posição base, simplificando a notação

    //STORES:
    //Da forma como a memoria de dados foi implementada (empacotada), na escrita e necessario sobrescrever o dado inteiro (palavra de 32 bits), 
    //mesmo que apenas uma parte dela seja alterada (sb, sh). Portanto, a palavra a ser escrita e "calculada" de forma combinacional, e na subida 
    //do clock a palavra inteira e escrita na memoria
    always_comb begin
        WriteWord = ram[addr[9:2]]; //le o estado atual da memoria, para sobrescrever apenas a parte necessaria
        case (funct3) //Determina qual parte da palavra sera escrita na memoria, de acordo com o tipo de store (sb, sh, sw)
            3'h00: WriteWord[byte_offset +: 8] <= WriteData[7:0];    //Store Byte        sb
            3'h01: WriteWord[half_offset +: 16] <= WriteData[15:0];  //Store Half-Word   sh
            3'h02: WriteWord <= WriteData;                           //Store Word        sw
            default: WriteWord <= WriteData;
        endcase
    end

    //Escrita sincrona na memoria de dados
    always@(posedge clk) begin
        if (MemWrite) begin //A escrita so ocorre se MemWrite estiver habilitado
            ram[addr[9:2]] <= WriteWord;
        end
    end
   
    //LOADS:
    //Seguimos o mesmo padrão do Store e não fazemos o slicing diretamente sobre a memória.
    //Lê a palavra completa, armazenando em uma variável auxiliar que é "cortada" e tem seu sinal extendido
    always_comb begin
        ReadWord = ram[addr[9:2]]; //
        case (funct3)
            3'd00:   ReadData = {{24{ReadWord[byte_offset +  7]}}, ReadWord[byte_offset +:  8]};   //Load Byte                 lb
            3'd01:   ReadData = {{16{ReadWord[half_offset + 15]}}, ReadWord[half_offset +: 16]};   //Load Half-Word            lh
            3'd04:   ReadData = {24'b0, ReadWord[byte_offset +:  8]};                              //Load Byte Unsigned        lbu
            3'd05:   ReadData = {16'b0, ReadWord[half_offset +: 16]};                              //Load Half-Word Unsigned   lhu
            3'd02:   ReadData = ReadWord;                                                          //Load Word                 lw
            default: ReadData = ReadWord;
        endcase
    end
endmodule
