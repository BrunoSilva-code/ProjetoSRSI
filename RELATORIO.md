# Ataque Man-in-the-Middle por ARP Poisoning à ligação de uma base de dados SQL

**Mestrado em <<NOME DO MESTRADO>> — Segurança em Redes e Sistemas de Informação**

**Autores:** Nome 1, Nº xxx · Nome 2, Nº yyy
**Data:** dd-mm-aa
**Docente:** <<NOME>>

---

## Resumo

O objetivo deste projeto é realizar, de forma prática e controlada, um ataque *Man-in-the-Middle* (MitM) sobre uma rede local. Para isso construímos um laboratório isolado com dois sistemas Kali Linux em contentores Docker, no qual uma máquina atacante envenena as tabelas ARP da vítima e do gateway (técnica de *ARP poisoning*), colocando-se no meio da comunicação. Com a ferramenta Ettercap desencadeamos o ataque e com o Wireshark analisamos o tráfego intercetado, demonstrando em particular a exposição de dados numa ligação a uma base de dados SQL sem cifra. Por fim propomos e implementamos medidas de deteção e mitigação, concluindo que a ausência de cifra e de validação da camada de ligação torna estas redes vulneráveis, e que controlos simples reduzem significativamente o risco.

**Palavras-chave:** Man-in-the-Middle; ARP Poisoning; Sniffing; Ettercap; SQL; Mitigação

---

## Glossário

- **SRSI** – Segurança em Redes e Sistemas de Informação
- **MitM** – *Man-in-the-Middle*
- **ARP** – *Address Resolution Protocol*
- **MAC** – *Media Access Control* (endereço físico de uma interface de rede)
- **IP** – *Internet Protocol*
- **SQL** – *Structured Query Language*
- **TLS** – *Transport Layer Security*
- **DAI** – *Dynamic ARP Inspection*
- **VNC** – *Virtual Network Computing*

---

## 1. Introdução

As redes locais assentam em protocolos antigos que foram desenhados numa época em que a segurança não era uma preocupação central. O protocolo ARP, responsável por traduzir endereços IP em endereços MAC dentro de uma rede, é um desses casos: confia cegamente em qualquer resposta que receba, sem qualquer mecanismo de autenticação. Esta confiança é precisamente o que um atacante explora num ataque *Man-in-the-Middle*.

O problema que pretendemos abordar é demonstrar, de forma reproduzível e num ambiente isolado, como um atacante na mesma rede local consegue interpor-se entre duas máquinas e ler o tráfego que circula entre elas — com especial atenção ao risco de exposição de credenciais e de dados quando esse tráfego corresponde a uma ligação a uma base de dados SQL sem cifra.

Para endereçar este problema montámos um laboratório com dois contentores Kali Linux numa rede Docker isolada, executámos o ataque com as ferramentas Ettercap e Wireshark, e analisámos os resultados. A partir dessa análise desenvolvemos medidas de deteção e mitigação.

Este documento está organizado da seguinte forma: a **Secção 2** apresenta os conceitos teóricos necessários (ARP, ARP poisoning, sniffing, MitM e as ferramentas usadas); a **Secção 3** descreve o laboratório e a arquitetura montada; a **Secção 4** detalha a execução do ataque e a interceção do tráfego SQL; a **Secção 5** discute a deteção e a mitigação; e por fim apresentam-se as **Conclusões** e as **Referências**.

---

## 2. Conceitos fundamentais

Antes de avançarmos para o cenário prático, importa fixar alguns conceitos-chave para que todos partam do mesmo nível de entendimento.

### 2.1 ARP (Address Resolution Protocol)

O ARP é um protocolo de nível 2 (ligação de dados). Permite que um computador descubra o endereço MAC associado a um determinado endereço IP na rede local: a máquina envia uma mensagem *broadcast* a perguntar "quem tem o IP X?", e a máquina que possui esse IP responde com o seu endereço MAC. A partir daí as duas podem comunicar ao nível físico.

Para não repetir este processo a cada comunicação, cada máquina guarda os pares IP↔MAC já conhecidos numa *tabela ARP* (cache ARP), como ilustrado na Figura 1.

> *Figura 1 – Exemplo de uma tabela ARP de um computador.*

A fragilidade central do ARP é que **não existe autenticação**: uma máquina aceita e regista qualquer resposta ARP que receba, mesmo que não a tenha pedido (*gratuitous ARP*). É esta fragilidade que o ataque explora.

### 2.2 ARP Poisoning (envenenamento de ARP)

O *ARP poisoning* consiste em manipular as tabelas ARP das máquinas da rede com pares IP↔MAC falsos. No nosso contexto, o objetivo é colocar o atacante no meio da ligação entre duas máquinas. Consideremos uma rede simples com um Router (R1), um Computador (C1) e um Atacante (A1):

| Host | IP | MAC |
|---|---|---|
| Router (R1) | 192.168.1.1 | ED56 |
| Computador (C1) | 192.168.1.100 | ZZ45 |
| Atacante (A1) | 192.168.1.200 | HAC31 |

O atacante A1 envia respostas ARP forjadas:
- para **R1**, diz que o IP de C1 (192.168.1.100) corresponde ao MAC do atacante (HAC31);
- para **C1**, diz que o IP de R1 (192.168.1.1) corresponde ao MAC do atacante (HAC31).

A partir daí, R1 e C1 passam a enviar para A1 o tráfego que julgam estar a enviar um ao outro. O atacante reencaminha-o ao destino verdadeiro (para a vítima não notar quebra de ligação), ficando no meio a ler tudo o que passa. Este é o cenário do nosso trabalho. Em alternativa, envenenando as tabelas com MACs inexistentes, seria possível provocar perda total de pacotes (negação de serviço), mas não é esse o objetivo aqui.

> *Figura 2 – Tabelas ARP antes do ataque.*
> *Figura 3 – Tabelas ARP envenenadas.*

### 2.3 Network Sniffing

*Sniffing* é a prática de intercetar, analisar e guardar os pacotes de dados que circulam na rede. No nosso trabalho usamos o **Wireshark** para analisar os pacotes trocados entre a vítima e o gateway depois de os termos desviado para a máquina atacante.

### 2.4 Ataque Man-in-the-Middle (MitM)

Um ataque MitM ocorre quando um terceiro se interpõe secretamente na comunicação entre duas entidades, podendo ler (e em alguns casos alterar) a informação trocada sem que nenhuma das partes se aperceba. O ARP poisoning é uma das formas de concretizar um MitM numa rede local.

### 2.5 Ferramentas utilizadas

- **Ettercap** – ferramenta *open source* para ataques MitM em redes locais; automatiza o envio das respostas ARP forjadas e o reencaminhamento do tráfego.
- **Wireshark** – analisador de protocolos de rede, usado para capturar e inspecionar os pacotes intercetados.
- **Docker** – usado para criar um ambiente de laboratório isolado e reproduzível.

---

## 3. Laboratório

O laboratório foi montado com dois contentores Kali Linux ligados a uma rede Docker isolada (`172.19.0.0/24`), de forma a não afetar nenhuma rede real:

| Host | Papel | IP |
|---|---|---|
| kali-attacker | Atacante (A1) | 172.19.0.2 |
| kali-victim | Vítima (C1) | 172.19.0.3 |
| Gateway Docker | Encaminhamento (R1) | 172.19.0.1 |

Cada contentor expõe um ambiente gráfico através de VNC acedido pelo browser (noVNC), o que permite operar o Ettercap e o Wireshark de forma visual. No contentor atacante foram ativadas as capacidades de rede `NET_ADMIN` e `NET_RAW` e o reencaminhamento de pacotes (`net.ipv4.ip_forward=1`), indispensável para que o tráfego desviado continue a chegar ao destino e a vítima não perca a ligação.

O cenário consiste em a vítima estabelecer uma ligação a uma base de dados **SQL** (<<p. ex. MySQL/MariaDB>>) e o atacante intercetar essa comunicação.

---

## 4. Execução do ataque

### 4.1 Lançamento do ARP poisoning

No terminal do Kali atacante, o ataque é desencadeado com o Ettercap, indicando como alvos a vítima e o gateway:

```bash
sudo -n /usr/bin/ettercap -T -o -i eth0 -M arp:remote /172.19.0.3// /172.19.0.1//
```

A opção `-M arp:remote` ativa o envenenamento ARP bidirecional entre os dois alvos, colocando o atacante no meio. A partir deste momento, as tabelas ARP da vítima e do gateway passam a apontar o IP um do outro para o MAC do atacante (ver Figura 3).

### 4.2 Captura e análise do tráfego

No Wireshark, a captura é feita na interface `eth0`. Para isolar o tráfego da vítima aplica-se o filtro:

```text
ip.addr == 172.19.0.3
```

Gerando tráfego a partir da vítima (nomeadamente a ligação à base de dados), observa-se no Wireshark que esse tráfego passa pela máquina atacante.

### 4.3 Exposição dos dados SQL

<<Descrevam aqui o que observaram. Pontos a referir:>>
- O protocolo SQL (por omissão, sem TLS) transmite as *queries* e os resultados essencialmente em claro. Com um filtro adequado no Wireshark (p. ex. seguir o *stream* TCP da ligação à base de dados), é possível ler as instruções SQL executadas pela vítima e os dados devolvidos.
- Isto demonstra o impacto real do ataque: um atacante no meio da ligação consegue observar informação sensível (comandos, dados de tabelas e, consoante o mecanismo de autenticação, informação relativa às credenciais) sem que a vítima o saiba.

> *Figura 4 – Tráfego SQL capturado no Wireshark (inserir captura de ecrã).*

---

## 5. Deteção e mitigação

O ataque é possível por duas razões: o ARP não autentica as suas respostas, e o tráfego SQL circulava sem cifra. A defesa atua sobre ambos.

### 5.1 Deteção

- **Monitorização da cache ARP:** a assinatura típica do ataque é dois IPs diferentes (o da vítima e o do gateway) a apresentarem o **mesmo endereço MAC** (o do atacante). Ferramentas como o `arpwatch` ou um *script* próprio podem vigiar a tabela ARP e alertar quando o MAC associado ao gateway muda ou quando aparecem MACs duplicados.
- **Deteção de *gratuitous ARP* anómalos** e de um volume invulgar de respostas ARP não solicitadas.

<<Se o vosso "script de mitigação" for de deteção, descrevam-no aqui: lê a tabela ARP (`arp -a` / `ip neigh`), compara o MAC atual do gateway com um valor de referência conhecido e emite um alerta se houver alteração ou duplicação.>>

### 5.2 Mitigação

- **Cifrar o tráfego (TLS):** ativar TLS na ligação à base de dados faz com que, mesmo intercetado, o conteúdo fique ilegível para o atacante — elimina o impacto principal do ataque.
- **Entradas ARP estáticas:** fixar manualmente o par IP↔MAC do gateway nas máquinas críticas impede que respostas forjadas o alterem.
- **Dynamic ARP Inspection (DAI):** em *switches* geridos, valida as respostas ARP contra uma tabela de confiança (DHCP snooping), descartando as forjadas.
- **Segmentação de rede / VLANs** para reduzir o conjunto de máquinas que podem atacar-se mutuamente.

---

## 6. Conclusões

Com este trabalho demonstrámos, num ambiente isolado e controlado, que um ataque *Man-in-the-Middle* por *ARP poisoning* é simples de executar numa rede local e que a sua eficácia resulta diretamente da ausência de autenticação no protocolo ARP. Ao desviar o tráfego da vítima e ao analisá-lo com o Wireshark, confirmámos que uma ligação SQL sem cifra expõe instruções e dados sensíveis a quem se coloca no meio da comunicação.

Verificámos igualmente que o risco pode ser reduzido de forma significativa com medidas acessíveis: cifrar o tráfego com TLS neutraliza o impacto mesmo quando o tráfego é intercetado, enquanto a deteção de alterações na cache ARP e controlos de rede como entradas estáticas ou DAI dificultam ou impedem o próprio envenenamento. A principal lição é que a segurança desta camada depende de não confiar cegamente na rede local: cifrar sempre e validar a camada de ligação.

<<Acrescentem aqui limitações e trabalho futuro, se quiserem.>>

---

## Referências

> *Formato APA. Acrescentem as que efetivamente usaram.*

- Khan, J., Abbas, H., & Al-Muhtadi, J. (2015). Survey on mobile user's data privacy threats and defense mechanisms. *Procedia Computer Science, 56*, 376–383.
- Park, A.-J., Kim, H.-Y., & Lim, J.-I. (2015). A framework of device authentication management in IoT environments. *2015 5th International Conference on IT Convergence and Security (ICITCS)*, 1–3.
- <<Documentação do Ettercap, do Wireshark, e uma referência sobre ARP spoofing / RFC 826.>>
