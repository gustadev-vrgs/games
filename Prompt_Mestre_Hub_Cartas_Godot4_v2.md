# PROMPT MESTRE V2 - HUB MULTIPLAYER DE CARTAS EM GODOT 4

## Documento revisado para implementação incremental, verificável e resistente a erros

Projeto acadêmico: hub de jogos de cartas com:

1. Uno clássico de 108 cartas;
2. Caxeta/Cacheta na variante fechada neste documento;
3. Truco Paulista, primeiro 1x1 e depois 2x2.

Objetivo de rede: vários jogadores executam a mesma build do projeto em computadores diferentes, conectados à mesma rede local ou Wi-Fi. Um jogador cria a sala e atua simultaneamente como servidor e jogador. Os demais informam o IP local exibido pelo host e entram na sala.

Idioma da interface: português do Brasil.

Plataforma principal da primeira versão: computadores Windows 10/11 em rede local. Não implementar versão Web, servidor dedicado, Internet pública, NAT punch-through, matchmaking externo, login ou banco de dados nesta versão.

---

# PARTE A - ANÁLISE DO PDF ORIGINAL

## A.1 Pontos fortes que devem ser preservados

O documento original já acerta ao exigir:

- desenvolvimento por fases;
- regras testadas localmente antes da adaptação para rede;
- servidor autoritativo;
- mãos privadas enviadas somente ao respectivo jogador;
- UIDs únicos para cartas físicas duplicadas;
- um único `NetworkManager`;
- estado explícito em vez de muitos booleanos;
- testes em GDScript puro;
- checkpoints obrigatórios;
- proibição de avançar quando houver erros;
- separação entre dados, regras, rede e interface;
- validação de cenas, sinais, scripts, tipos e referências;
- Uno antes de Caxeta e Truco;
- Truco 1x1 antes de Truco 2x2.

Esses requisitos continuam obrigatórios.

## A.2 Lacunas que a versão 2 corrige

O PDF original ainda permitia interpretações que poderiam gerar bugs. Esta versão fecha os seguintes pontos:

1. A versão exata da Godot precisa ser detectada e congelada no projeto.
2. O retorno de `create_client()` não significa que o cliente já se conectou. A conexão somente é confirmada por `connected_to_server`.
3. O limite de clientes do ENet não é o mesmo que o limite total de jogadores, pois o host também joga.
4. O fluxo "escolher jogo e entrar" era ambíguo para clientes. Agora somente o host escolhe e configura o jogo; clientes recebem essa configuração do servidor.
5. Faltava um protocolo explícito de mensagens, com versão, ID da partida, ID da ação e versão do estado.
6. Faltava idempotência para impedir que clique duplo ou pacote repetido executasse uma ação duas vezes.
7. Faltava sincronização segura durante troca de cena. Agora existe uma barreira de carregamento: a partida só começa quando todos confirmarem que a cena correta está pronta.
8. Faltavam limites e validação de tipos para payloads enviados por RPC.
9. Faltava uma política fechada para timeout, jogador desconectado, host desconectado e tentativa de entrada tardia.
10. Faltava impedir transições duplicadas de tela ou encerramentos executados duas vezes.
11. Faltavam invariantes de conservação das cartas após toda ação.
12. Faltavam casos-limite de Uno, Caxeta e Truco.
13. Faltava definir como um teste executado por `--script` deve herdar de `SceneTree`.
14. Faltava uma fase específica para testar a rede antes de misturá-la às regras.
15. Faltava exigir que o relatório de cada fase prove o comando executado e o resultado, em vez de apenas afirmar que testou.

## A.3 Erros do projeto anterior que não podem se repetir

- Não presumir que um nó, sinal, método, cena ou arquivo existe.
- Não construir muitas funcionalidades antes de abrir e testar o que já foi criado.
- Não deixar uma transição ser disparada por mais de um script.
- Não permitir que um evento de conclusão seja processado duas vezes.
- Não corrigir um problema alterando várias partes não relacionadas.
- Não entregar apenas trechos de código quando a tarefa pede arquivos reais.
- Não avançar de fase com erro de parser, cena quebrada, teste falhando ou limitação escondida.
- Não substituir arquivos funcionais inteiros sem antes analisar o conteúdo atual.

---

# PARTE B - INSTRUÇÃO PRINCIPAL PARA A IA DE CÓDIGO

Você é responsável por desenvolver um projeto real em Godot 4, exclusivamente em GDScript, chamado provisoriamente de `Hub de Cartas`.

Você deve trabalhar como engenheiro de software cuidadoso. Não tente concluir todas as fases em uma única resposta. Implemente somente a fase autorizada pelo usuário, valide-a completamente, apresente o checkpoint e pare. Aguarde o usuário pedir para continuar.

Fluxo obrigatório:

1. ANALISAR o estado atual;
2. PLANEJAR somente a fase atual;
3. IMPLEMENTAR arquivos reais;
4. IMPORTAR o projeto na Godot;
5. VERIFICAR parser, recursos, cenas e sinais;
6. EXECUTAR testes;
7. ABRIR e testar as cenas afetadas;
8. CORRIGIR tudo o que falhar;
9. APRESENTAR checkpoint com evidências;
10. PARAR.

Se qualquer validação falhar, não avance.

---

# 1. CONTRATO DE VERSÃO E AMBIENTE

Antes de escrever código:

1. localizar o `project.godot`;
2. detectar o executável disponível (`godot`, `godot4` ou caminho informado);
3. executar `godot --version`;
4. registrar no README a versão exata usada nos testes;
5. conferir a versão declarada em `config/features` no `project.godot`;
6. não migrar automaticamente o projeto para outra versão;
7. consultar somente APIs existentes na documentação dessa mesma versão.

Se não houver executável da Godot disponível:

- informar claramente;
- ainda revisar sintaxe e referências estaticamente;
- não afirmar que executou testes;
- fornecer os comandos exatos que deverão ser executados localmente;
- considerar a fase incompleta até existir validação real.

Usar:

- Godot 4 estável;
- GDScript;
- cenas `.tscn`;
- scripts `.gd`;
- UI com `Control` e `Container`;
- multiplayer de alto nível;
- `ENetMultiplayerPeer`;
- arquitetura servidor-autoritativo;
- UDP em rede local.

Não usar:

- Godot 3 ou sintaxe de Godot 3;
- C#;
- Firebase;
- banco de dados;
- servidor externo;
- WebSocket;
- Steam Networking;
- API REST;
- addons obrigatórios;
- GUT;
- plugins;
- código copiado de versões antigas sem validar;
- `MultiplayerSynchronizer` na primeira versão;
- sincronização automática de propriedades que possa vazar mãos privadas.

# 2. ESCOPO FECHADO DA PRIMEIRA VERSÃO

Incluído:

- menu;
- apelido;
- criação de sala LAN;
- entrada manual por IP e porta;
- lobby;
- host como servidor e jogador;
- Uno completo;
- Caxeta completa na variante deste documento;
- Truco Paulista 1x1 e 2x2;
- tela de resultados;
- retorno coordenado ao lobby;
- testes de regras;
- testes de baralho;
- testes de cenas;
- testes de integração de rede;
- exportação para Windows.

Fora do escopo:

- Internet pública;
- servidor dedicado;
- reconexão à partida;
- migração de host;
- espectador;
- bot substituto;
- chat;
- conta;
- ranking persistente;
- salvamento de partida;
- loja;
- cosméticos;
- controle por voz;
- mobile;
- Web;
- matchmaking automático;
- descoberta automática de salas na rede;
- múltiplas salas no mesmo processo;
- sala com senha;
- regras alternativas não descritas.

Não adicionar itens fora do escopo sem autorização.

# 3. FLUXO EXATO DO USUÁRIO

## 3.1 Criar sala

1. abrir o jogo;
2. informar apelido;
3. escolher `Criar sala`;
4. selecionar Uno, Caxeta ou Truco;
5. ajustar apenas configurações permitidas;
6. criar o servidor;
7. entrar automaticamente como host/jogador;
8. visualizar IPs LAN válidos e porta;
9. aguardar clientes;
10. iniciar somente quando a quantidade de jogadores for válida.

## 3.2 Entrar em sala

1. abrir a mesma build do jogo;
2. informar apelido;
3. escolher `Entrar em sala`;
4. informar o IP LAN exibido pelo host;
5. informar a porta;
6. aguardar conexão;
7. receber do servidor o jogo selecionado e as configurações;
8. visualizar o lobby.

O cliente não escolhe uma variante própria. A configuração do host é canônica.

## 3.3 Partida e retorno

1. host solicita início;
2. servidor valida o lobby;
3. servidor bloqueia configurações;
4. todos carregam a mesma cena;
5. cada cliente confirma `scene_ready`;
6. servidor inicia somente depois da barreira de carregamento;
7. clientes enviam intenções;
8. servidor valida, altera o estado e sincroniza;
9. servidor declara o vencedor uma única vez;
10. todos veem resultados;
11. host decide voltar ao lobby ou encerrar;
12. servidor ordena a transição para todos.

Nenhum cliente muda sozinho para outra tela durante uma sessão ativa.

# 4. CONSTANTES MÍNIMAS

Centralizar em `res://data/game_constants.gd` ou arquivos equivalentes:

```gdscript
const PROTOCOL_VERSION: int = 1
const DEFAULT_PORT: int = 7000
const MIN_PORT: int = 1024
const MAX_PORT: int = 65535
const MAX_TOTAL_PLAYERS: int = 6
const MAX_TRANSPORT_CLIENTS: int = 8
const CONNECTION_TIMEOUT_SECONDS: float = 8.0
const SCENE_READY_TIMEOUT_SECONDS: float = 15.0
const MAX_NICKNAME_LENGTH: int = 20
const MAX_ACTIONS_REMEMBERED_PER_PEER: int = 64
```

`MAX_TRANSPORT_CLIENTS` pode ser maior que o máximo de jogadores para permitir que um cliente extra conecte, receba uma rejeição compreensível como `ROOM_FULL` e seja desconectado de forma controlada. A regra da aplicação continua limitando o total de jogadores a 6.

# 5. ESTRUTURA DE ARQUIVOS

Estrutura de referência:

```text
res://
  project.godot
  README.md
  autoloads/
    scene_router.gd
    network_manager.gd
    session_state.gd
  data/
    card_data.gd
    deck_builder.gd
    game_constants.gd
    network_protocol.gd
    action_result.gd
  scenes/
    app_root.tscn
    main_menu.tscn
    host_setup.tscn
    join_setup.tscn
    lobby.tscn
    loading_match.tscn
    results_screen.tscn
    shared/
      card_visual.tscn
      player_panel.tscn
      message_banner.tscn
    uno/
      uno_game.tscn
    caxeta/
      caxeta_game.tscn
    truco/
      truco_game.tscn
  scripts/
    ui/
      main_menu.gd
      host_setup.gd
      join_setup.gd
      lobby.gd
      loading_match.gd
      results_screen.gd
    shared/
      card_visual.gd
      player_panel.gd
      message_banner.gd
    match/
      base_match_controller.gd
    uno/
      uno_rules.gd
      uno_match_controller.gd
      uno_game_ui.gd
    caxeta/
      caxeta_rules.gd
      caxeta_meld_solver.gd
      caxeta_match_controller.gd
      caxeta_game_ui.gd
    truco/
      truco_rules.gd
      truco_match_controller.gd
      truco_game_ui.gd
  tests/
    test_runner.gd
    test_helpers.gd
    test_decks.gd
    test_uno.gd
    test_caxeta.gd
    test_truco.gd
    test_invariants.gd
    scene_smoke_runner.gd
    network_smoke_server.gd
    network_smoke_client.gd
```

É permitido ajustar a estrutura somente com justificativa técnica. Não remover a separação entre UI, regras, estado e rede.

# 6. RESPONSABILIDADES E DEPENDÊNCIAS

## 6.1 `SceneRouter`

Único responsável por trocar telas.

Obrigatório:

- método central `request_transition(screen_id, payload)`;
- booleano ou enum interno de transição;
- ignorar ou rejeitar segunda solicitação enquanto uma transição está em andamento;
- validar o destino em catálogo fechado;
- emitir erro se a cena não existir;
- concluir a troca antes de liberar nova transição;
- impedir que dois sinais avancem duas telas;
- não usar `change_scene_to_file()` em scripts de jogo ou botões diretamente.

Toda tela pede a transição ao roteador. Isso evita o bug de pular duas fases/telas.

## 6.2 `NetworkManager`

Único responsável por:

- criar e encerrar o peer ENet;
- conectar sinais da `MultiplayerAPI`;
- timeout de conexão;
- registrar peers;
- validar versão do protocolo;
- manter lobby autoritativo;
- receber RPCs de ação;
- capturar imediatamente `multiplayer.get_remote_sender_id()`;
- deduplicar ações;
- enviar aceitações/rejeições;
- enviar estado público;
- enviar estado privado com `rpc_id`;
- coordenar carregamento de cenas;
- limpar totalmente uma sessão encerrada.

Não colocar regras de Uno, Caxeta ou Truco no `NetworkManager`.

## 6.3 `SessionState`

Armazena apenas estado de navegação/sessão necessário entre telas:

- `session_id`;
- `match_id`;
- jogo selecionado;
- peer local;
- indicador de host;
- configurações aprovadas;
- jogadores públicos;
- estado público recebido;
- estado privado do jogador local;
- versões recebidas.

Cliente não pode escrever diretamente em estado canônico de partida.

## 6.4 `DeckBuilder`

Responsável por construir os três baralhos e atribuir UIDs.

Não conhece UI, cenas ou rede.

## 6.5 Regras

Arquivos de regras devem ser `RefCounted` ou classes puras equivalentes, sem NodePath, sem UI e sem RPC.

Contrato lógico mínimo de cada motor:

```text
create_initial_state(...)
validate_action(state, actor_id, action)
apply_action(state, actor_id, action, rng)
build_public_snapshot(state)
build_private_snapshot(state, peer_id)
validate_invariants(state)
is_match_finished(state)
```

GDScript não possui interface formal; portanto, cada implementação precisa possuir essas funções com documentação e testes.

## 6.6 Controlador da partida

Existe somente no servidor como dono do estado real.

Responsável por:

- chamar regras;
- aplicar ações aceitas;
- incrementar versão;
- verificar invariantes;
- solicitar snapshots à camada de regras;
- declarar rodada/mão/partida encerrada;
- emitir encerramento somente uma vez.

## 6.7 UI

A UI:

- mostra snapshots;
- emite intenção do jogador;
- bloqueia controles enquanto aguarda resposta;
- mostra erro de rejeição;
- nunca decide se uma carta é legal de forma autoritativa;
- nunca altera mão, turno, placar ou vencedor por conta própria.

É permitido destacar cartas provavelmente jogáveis para UX, mas o servidor continua validando.

# 7. REGRAS DE CENA, NÓS E SINAIS

1. Cada cena deve ter raiz com nome fixo e documentado.
2. Nós acessados por script devem usar nomes únicos na cena e, quando adequado, `unique_name_in_owner`, acessados por `%NomeDoNo`.
3. Todo `@onready` deve possuir tipo explícito.
4. Não usar `$Caminho/Profundo` sem conferir a árvore real.
5. Não conectar o mesmo sinal no editor e no código.
6. Se a conexão for feita em código, verificar `is_connected()` quando houver risco de `_ready()` repetido.
7. Todo sinal deve ser desconectado ou pertencer a objeto descartado com segurança.
8. Nenhuma cena pode depender de nó criado somente em outra máquina.
9. Cenas de host e cliente devem ter o mesmo caminho para qualquer nó que possua RPC.
10. Preferir manter todas as RPCs no Autoload `NetworkManager`, cujo caminho é idêntico: `/root/NetworkManager`.
11. Toda cena nova deve ser instanciada por um teste de fumaça.
12. Os controles principais devem ser clicados manualmente antes da fase ser concluída.

# 8. PREVENÇÃO DE DUPLICIDADE E TRANSIÇÃO DUPLA

Toda ação mutável precisa ser idempotente ou protegida.

Obrigatório:

- `client_action_id` crescente por cliente;
- cache no servidor dos últimos IDs processados por peer;
- segunda chegada do mesmo ID não reaplica a ação;
- botão desabilitado após envio;
- botão reabilitado apenas após aceitação, rejeição ou timeout controlado;
- `match_end_emitted` impede dois resultados;
- `round_end_emitted` impede duas reduções de vida;
- `transition_in_progress` impede duas trocas de cena;
- callbacks devem verificar `session_id` e `match_id`;
- sinais atrasados de partida anterior devem ser ignorados.

Nunca resolver clique duplo somente na interface. O servidor deve ser seguro mesmo se um cliente malicioso ignorar o bloqueio visual.

# 9. TIPAGEM E ERROS DE GDSCRIPT

- Usar tipos explícitos em propriedades, parâmetros e retornos quando a API permitir.
- Ao receber `Variant`, validar tipo antes de converter.
- Não confiar em inferência quando um `Dictionary` pode retornar qualquer tipo.
- Comparar retornos de API com `OK`.
- Não ignorar `Error`.
- Não usar funções inventadas.
- Não usar `class_name` com o mesmo nome de um Autoload.
- Evitar dependência circular.
- Não renomear arquivo, nó ou método sem atualizar e testar todas as referências.
- Não adicionar `TODO` em funcionalidade considerada concluída.
- `assert()` pode ser usado em testes e invariantes internas de debug, mas nunca como única proteção contra input remoto.
- Input remoto inválido deve ser rejeitado sem derrubar o servidor.

# 10. MODELO DE CARTA

Cada carta física possui UID único dentro de uma partida.

Campos canônicos:

```gdscript
{
    "uid": 37,
    "game_id": "uno",
    "rank": "5",
    "suit": "",
    "color": "red",
    "action": "",
    "deck_copy": 0,
    "visual_key": "uno_red_5"
}
```

Regras:

- nunca identificar carta apenas por textura, rank ou cor;
- UIDs são gerados no servidor;
- em testes locais, o construtor também gera UIDs determinísticos;
- a UI recebe somente representação serializável;
- não enviar `Resource`, `Node`, `Callable` ou objeto por RPC;
- não usar UID para deduzir ordem do baralho;
- UIDs podem reiniciar em 1 a cada nova partida, pois `match_id` diferencia partidas;
- toda procura de carta precisa confirmar que o UID pertence à zona correta.

# 11. BARALHOS

## 11.1 Truco

40 cartas:

- naipes: Ouros, Espadas, Copas, Paus;
- ranks: 4, 5, 6, 7, Q, J, K, A, 2, 3;
- 10 cartas por naipe;
- sem 8, 9, 10 ou curingas.

## 11.2 Caxeta

104 cartas:

- dois baralhos tradicionais de 52;
- ranks A, 2-10, J, Q, K;
- quatro naipes;
- `deck_copy` 0 ou 1;
- sem curingas impressos;
- cartas fisicamente iguais possuem UIDs diferentes.

## 11.3 Uno

108 cartas:

Para cada cor vermelho, amarelo, verde e azul:

- um 0;
- dois de cada número 1-9;
- dois `draw_two`;
- dois `reverse`;
- dois `skip`.

Além disso:

- quatro `wild`;
- quatro `wild_draw_four`.

Validar quantidade total e distribuição por tipo.

# 12. EMBARALHAMENTO DETERMINÍSTICO

Não usar estado visual nem cada cliente embaralhar.

Somente o servidor embaralha no multiplayer.

Usar `RandomNumberGenerator` e implementar Fisher-Yates com a instância recebida:

```text
para i do último índice até 1:
    j = rng.randi_range(0, i)
    trocar cartas i e j
```

Regras:

- testes usam seed fixa;
- partida normal usa seed aleatória criada no servidor;
- seed real não é enviada aos clientes, pois poderia revelar o baralho;
- o teste deve reproduzir a mesma ordem com a mesma seed;
- nenhuma função de regra deve chamar aleatoriedade global escondida.

# 13. INVARIANTES GERAIS

Após cada ação aceita, o servidor valida:

- nenhum UID aparece em duas zonas;
- nenhum UID desapareceu;
- quantidade total de cartas permanece igual à do baralho;
- somente jogador atual possui permissão de turno;
- índices de assento continuam válidos;
- jogador eliminado não recebe turno;
- vencedor só existe em estado final;
- versão de estado nunca diminui;
- mão privada enviada pertence ao peer destinatário;
- nenhuma informação privada foi inserida no snapshot público.

Se uma invariante interna falhar:

1. não continuar a partida silenciosamente;
2. registrar contexto;
3. pausar/abortar de forma controlada;
4. mostrar erro genérico aos jogadores;
5. corrigir antes de considerar a fase concluída.

# 14. ESTADOS EXPLÍCITOS

Não espalhar dezenas de booleanos.

Estado da aplicação:

```gdscript
enum AppPhase {
    BOOT,
    MAIN_MENU,
    HOST_SETUP,
    JOIN_SETUP,
    CONNECTING,
    LOBBY,
    LOADING_MATCH,
    IN_MATCH,
    RESULTS,
    DISCONNECTING
}
```

Estado da sessão no servidor:

```gdscript
enum SessionPhase {
    OFFLINE,
    LOBBY,
    LOCKED,
    LOADING,
    MATCH_ACTIVE,
    MATCH_PAUSED,
    MATCH_FINISHED
}
```

Cada jogo terá seu próprio enum de fases. Toda ação valida a fase atual antes de qualquer mutação.

# 15. REDE LAN E CONEXÃO

## 15.1 Criação do servidor

Fluxo obrigatório:

1. validar porta;
2. criar `ENetMultiplayerPeer`;
3. chamar `create_server(port, MAX_TRANSPORT_CLIENTS)`;
4. verificar `error == OK`;
5. somente então atribuir `multiplayer.multiplayer_peer = peer`;
6. registrar o host como peer 1;
7. criar `session_id` novo;
8. abrir lobby;
9. mostrar endereços LAN.

Se falhar, não atribuir peer parcialmente inicializado.

## 15.2 Conexão do cliente

Fluxo obrigatório:

1. sanitizar apelido;
2. validar IP ou hostname aceito;
3. validar porta 1024-65535;
4. criar `ENetMultiplayerPeer`;
5. chamar `create_client(address, port)`;
6. verificar apenas se a tentativa foi configurada (`OK`);
7. atribuir peer;
8. iniciar timer de conexão;
9. considerar conectado somente ao receber `connected_to_server`;
10. então registrar protocolo e apelido com o servidor.

Se o timer expirar:

- encerrar peer;
- limpar estado;
- mostrar `Tempo de conexão esgotado. Verifique IP, porta, rede e firewall.`;
- retornar à tela de entrada.

## 15.3 Encerramento limpo

Para sair:

- impedir novas ações;
- invalidar `session_id` local;
- cancelar timers;
- limpar ações pendentes;
- substituir o peer por `OfflineMultiplayerPeer.new()`;
- limpar lobby e snapshots;
- retornar pela única rota do `SceneRouter`.

Não deixar sinais antigos alterarem a nova sessão.

## 15.4 IP local

Mostrar IPv4 privados e outros endereços LAN válidos encontrados pela Godot.

Filtrar:

- `127.0.0.1`;
- `0.0.0.0`;
- loopback IPv6;
- endereços vazios;
- duplicatas;
- endereços de interface que não sejam úteis, quando identificáveis.

Explicar:

- `127.0.0.1` funciona somente no mesmo computador;
- em outro computador deve ser usado o IP LAN do host, normalmente `192.168.x.x` ou `10.x.x.x`;
- todos devem estar na mesma rede;
- VPN e isolamento de clientes do roteador podem impedir conexão;
- o firewall do Windows precisa permitir tráfego UDP na porta escolhida.

# 16. LOBBY AUTORITATIVO

Estrutura pública sugerida por jogador:

```gdscript
{
    "peer_id": 123456,
    "display_name": "Gustavo",
    "seat": 1,
    "ready": true,
    "connected": true
}
```

Regras:

- host é peer 1;
- identificação interna sempre por `peer_id`;
- apelido possui 1-20 caracteres após `strip_edges`;
- remover quebras de linha e caracteres de controle;
- colapsar espaços consecutivos;
- nomes duplicados recebem sufixo visual determinístico, por exemplo `Gustavo (2)`;
- somente host muda o jogo/configurações;
- toda mudança é validada e retransmitida pelo servidor;
- configurações ficam bloqueadas ao iniciar;
- clientes não entram diretamente no dicionário até concluírem registro;
- protocolo incompatível é rejeitado;
- sala cheia é rejeitada com mensagem;
- partida iniciada é rejeitada com mensagem;
- cliente não registrado não pode chamar ações da partida.

Condições para habilitar `Iniciar`:

- sessão em `LOBBY`;
- host é o solicitante;
- todos os peers estão registrados;
- jogo escolhido é válido;
- configuração é válida;
- quantidade de jogadores atende ao jogo;
- nenhuma transição está em andamento.

Quantidades:

- Uno: 2-6;
- Caxeta: 2-5;
- Truco: exatamente 2 ou exatamente 4.

Truco nunca inicia com 3.

# 17. PROTOCOLO DE REDE

## 17.1 Envelope de ação

Toda intenção de cliente para servidor usa dados simples:

```gdscript
{
    "protocol_version": 1,
    "session_id": "sessao_atual",
    "match_id": 4,
    "client_action_id": 27,
    "expected_state_version": 18,
    "action_type": "PLAY_CARD",
    "payload": {
        "card_uid": 37
    }
}
```

Validar, nesta ordem:

1. remetente capturado imediatamente;
2. servidor está processando;
3. tipo externo é `Dictionary`;
4. chaves obrigatórias;
5. tipos de cada campo;
6. versão de protocolo;
7. sessão;
8. partida;
9. peer registrado;
10. tamanho e conteúdo do payload;
11. ação ainda não processada;
12. versão esperada;
13. fase;
14. turno;
15. regra específica;
16. invariantes.

Não usar `await` antes de capturar `multiplayer.get_remote_sender_id()`.

## 17.2 RPC de entrada

RPC conceitual única para intenções:

```gdscript
@rpc("any_peer", "call_local", "reliable")
func request_action(envelope: Dictionary) -> void:
    var sender_id: int = multiplayer.get_remote_sender_id()
    if not multiplayer.is_server():
        return
    _process_action_from_peer(sender_id, envelope)
```

O host/jogador também percorre a mesma validação. Não criar atalho que permita ao host alterar estado sem validar.

## 17.3 Resposta direcionada

Cada ação gera resposta ao solicitante:

```gdscript
{
    "client_action_id": 27,
    "accepted": false,
    "reason_code": "NOT_YOUR_TURN",
    "state_version": 18
}
```

Mensagens visuais são mapeadas localmente por código. Não aceitar texto arbitrário remoto para exibir como RichText.

## 17.4 Códigos mínimos de rejeição

- `INVALID_MESSAGE`;
- `PROTOCOL_MISMATCH`;
- `INVALID_SESSION`;
- `INVALID_MATCH`;
- `UNREGISTERED_PEER`;
- `ROOM_FULL`;
- `MATCH_ALREADY_STARTED`;
- `NOT_HOST`;
- `INVALID_PLAYER_COUNT`;
- `INVALID_PHASE`;
- `NOT_YOUR_TURN`;
- `CARD_NOT_OWNED`;
- `CARD_NOT_PLAYABLE`;
- `ACTION_ALREADY_PROCESSED`;
- `STALE_STATE`;
- `SPECIAL_RESPONSE_REQUIRED`;
- `INVALID_COLOR`;
- `ILLEGAL_WILD_DRAW_FOUR`;
- `MUST_DRAW_FIRST`;
- `ALREADY_DREW`;
- `INVALID_KNOCK`;
- `INVALID_TRUCO_RESPONSE`;
- `RATE_LIMITED`;
- `INTERNAL_STATE_ERROR`.

## 17.5 Idempotência

Guardar, por peer, os últimos `client_action_id` processados e a resposta correspondente.

Se o mesmo ID chegar novamente:

- não reaplicar;
- reenviar a resposta anterior;
- não incrementar versão;
- não duplicar animação de estado.

Se chegar ID muito antigo ou inválido, rejeitar.

## 17.6 Versão de estado

Servidor mantém:

```gdscript
var state_version: int = 0
```

Somente ação aceita que muda estado incrementa a versão, exatamente uma vez.

Cliente:

- ignora snapshot com versão menor;
- aceita versão igual somente se for complemento privado compatível;
- se detectar salto ou inconsistência, solicita ressincronização completa;
- nunca mistura dados de `match_id` diferente.

# 18. SNAPSHOTS E PRIVACIDADE

## 18.1 Snapshot público

Pode conter:

- `protocol_version`;
- `session_id`;
- `match_id`;
- `state_version`;
- jogo;
- fase;
- jogadores;
- assentos;
- jogador atual;
- direção;
- placar/vidas;
- carta pública da mesa;
- quantidade de cartas de cada adversário;
- vira/manilha/curinga;
- pedido especial pendente;
- resultado público.

Nunca conter:

- ordem do monte;
- seed real;
- mãos completas;
- carta comprada por outro jogador antes de se tornar pública;
- opções secretas do oponente;
- objetos da Godot.

## 18.2 Snapshot privado

Enviado com `rpc_id(peer_id, ...)`.

Pode conter:

- UIDs e dados visuais da mão daquele peer;
- carta recém-comprada daquele peer;
- ações privadas permitidas;
- versão correspondente.

Antes de enviar, confirmar que a mão pertence ao `peer_id` destinatário.

## 18.3 Logs

Logs de cliente nunca imprimem mão adversária.

Logs do servidor podem registrar UIDs para diagnóstico em build de desenvolvimento, mas não devem expor informações secretas na UI ou em logs distribuídos aos clientes.

# 19. BARREIRA DE CARREGAMENTO DA PARTIDA

Problema a evitar: servidor distribuir cartas ou enviar RPC enquanto clientes ainda estão trocando de cena.

Fluxo:

1. servidor cria `match_id`;
2. servidor muda fase para `LOADING`;
3. servidor envia comando com `game_id`, `match_id` e caminho obtido de catálogo fechado;
4. cada peer usa o `SceneRouter`;
5. ao terminar `_ready()`, envia `client_scene_ready(match_id)`;
6. servidor guarda conjunto de peers prontos;
7. servidor verifica se todos os peers registrados estão prontos;
8. somente então cria o estado e distribui cartas;
9. servidor muda para `MATCH_ACTIVE`;
10. servidor envia snapshots.

Não aceitar caminho de cena fornecido por cliente.

Timeout:

- se alguém não ficar pronto em 15 segundos, manter a partida sem iniciar;
- mostrar quem falhou;
- permitir ao host abortar e voltar ao lobby;
- não continuar com estado parcialmente distribuído.

# 20. DESCONEXÕES

## 20.1 No lobby

- remover jogador;
- reorganizar assentos de forma determinística;
- atualizar lista;
- revalidar botão iniciar.

## 20.2 Durante carregamento

- cancelar início;
- invalidar `match_id`;
- avisar;
- host pode retornar todos ao lobby.

## 20.3 Durante partida

- mudar para `MATCH_PAUSED`;
- bloquear novas ações;
- informar peer/apelido desconectado;
- não adicionar bot;
- não permitir reconexão;
- host pode abortar a partida;
- retorno ao lobby é coordenado pelo servidor;
- partida abortada não altera placares persistentes, pois não há persistência.

## 20.4 Host desconectado

Clientes:

- recebem `server_disconnected`;
- invalidam sessão;
- limpam snapshots e mãos;
- exibem aviso;
- retornam ao menu.

Não migrar host.

# 21. REGRAS GERAIS DE TURNO

- Turno é índice de assento, não apelido.
- Ordem de assentos é estável durante a partida.
- Função única calcula próximo jogador ativo.
- Jogador eliminado ou desconectado não recebe turno.
- Ação fora do turno é rejeitada sem mutação.
- Enquanto existe decisão especial, somente ações dessa decisão são aceitas.
- Nenhum `Timer` visual decide mudança de turno.
- Animações não controlam regra.
- A UI só anima depois que o snapshot aceito chega.

# 22. UNO - VARIANTE FECHADA

## 22.1 Configuração

- 2-6 jogadores;
- 108 cartas;
- 7 cartas por jogador;
- partida única, sem placar acumulado entre rodadas;
- primeiro jogador: assento 0;
- direção inicial: `1`.

Estados sugeridos:

```gdscript
enum UnoPhase {
    DEALING,
    PLAYER_TURN,
    AFTER_DRAW_CHOICE,
    RESOLVING_EFFECT,
    MATCH_END
}
```

## 22.2 Descarte inicial

1. distribuir 7 para cada jogador;
2. revelar do monte até encontrar carta numérica;
3. guardar temporariamente cartas de ação retiradas;
4. colocar a numérica como topo do descarte;
5. devolver as temporárias ao monte;
6. embaralhar novamente o monte restante com o RNG do servidor;
7. definir cor ativa pela carta numérica;
8. iniciar assento 0.

Testar conservação das 108 cartas.

## 22.3 Jogada válida

Carta é jogável se:

- mesma cor ativa; ou
- mesmo número; ou
- mesmo símbolo de ação (`draw_two`, `reverse`, `skip`); ou
- `wild`; ou
- `wild_draw_four` legal.

A comparação usa dados, nunca texto da UI.

## 22.4 Ação `PLAY_CARD`

Payload mínimo:

```gdscript
{
    "card_uid": 37,
    "declared_uno": true,
    "chosen_color": "blue"
}
```

`chosen_color` é obrigatório para coringas e deve ser vazio para carta comum.

A escolha de cor é atômica com a jogada. Não deixar a carta removida da mão aguardando uma segunda RPC.

## 22.5 Compra

O jogador pode comprar mesmo possuindo jogada válida.

Fluxo:

1. `DRAW_ONE`;
2. servidor compra exatamente uma carta, se fisicamente disponível;
3. se jogável, fase vira `AFTER_DRAW_CHOICE`;
4. únicas ações aceitas: jogar aquela carta comprada ou passar;
5. não pode jogar carta antiga depois da compra;
6. se não jogável, turno termina automaticamente.

Não comprar duas vezes.

## 22.6 Reciclagem

Quando o monte esvaziar:

1. preservar topo do descarte;
2. mover restante do descarte para o monte;
3. embaralhar no servidor;
4. manter topo e cor ativa;
5. validar conservação.

Se não houver cartas recicláveis porque todas estão nas mãos e só existe o topo, comprar zero sem duplicar carta e encerrar/passar a ação de forma determinística. Registrar esse caso.

## 22.7 `draw_two`

- próximo jogador compra 2;
- próximo perde a vez;
- não empilhar;
- efeito é resolvido imediatamente;
- se houver menos de 2 cartas fisicamente disponíveis, comprar somente as disponíveis, sem duplicar.

## 22.8 `skip`

- próximo jogador é pulado;
- com dois jogadores, quem jogou recebe novo turno.

## 22.9 `reverse`

- multiplicar direção por -1;
- com três ou mais jogadores, seguir nova direção;
- com dois jogadores, funciona como `skip`: o mesmo jogador joga novamente.

## 22.10 `wild`

- aceitar apenas `red`, `yellow`, `green` ou `blue`;
- definir cor ativa;
- avançar turno.

## 22.11 `wild_draw_four`

Legal somente se o jogador não possuir carta da cor atualmente ativa.

Ele pode possuir carta de mesmo número/símbolo em outra cor; isso não torna o +4 ilegal.

Ao aceitar:

- validar cor escolhida;
- próximo compra 4;
- próximo perde turno;
- sem empilhamento;
- sem desafio nesta versão.

Se ilegal:

- rejeitar;
- manter carta na mão;
- manter turno e versão.

## 22.12 Declaração de Uno

Se a mão tinha 2 cartas e a jogada aceita deixa exatamente 1:

- `declared_uno == true`: nenhuma penalidade;
- `declared_uno == false`: comprar 2 automaticamente.

Não criar janela de contestação.

Se `declared_uno` vier `true` fora desse caso, ignorar o excesso sem alterar a regra e registrar apenas em debug.

## 22.13 Vitória

Se uma jogada aceita deixa 0 cartas:

- declarar vencedor imediatamente;
- mudar para `MATCH_END`;
- não aplicar compra/skip ao próximo jogador;
- escolha de cor de coringa ainda precisa vir válida no payload atômico;
- emitir resultado uma única vez.

## 22.14 Proibições do Uno

Não implementar:

- stacking;
- jump-in;
- 7-0;
- troca de mãos;
- compra até conseguir jogar;
- desafio de +4;
- pontuação por valor de cartas;
- regra moderna de 112 cartas.

# 23. CAXETA - VARIANTE FECHADA

## 23.1 Configuração

- 2-5 jogadores;
- 104 cartas;
- 9 cartas iniciais por jogador ativo;
- 7 ou 10 vidas, padrão 7;
- sem curingas impressos;
- primeiro jogador da primeira rodada: assento 0;
- primeiro jogador gira entre jogadores ativos a cada nova rodada.

Estados:

```gdscript
enum CaxetaPhase {
    DEALING,
    MUST_DRAW,
    MAY_KNOCK_TEN_OR_DISCARD,
    ROUND_END,
    MATCH_END
}
```

## 23.2 Vira e curinga

Depois de distribuir:

- revelar uma vira pública;
- próximo rank do mesmo naipe é curinga;
- progressão A,2,3,4,5,6,7,8,9,10,J,Q,K,A;
- K aponta para A;
- como há dois baralhos, normalmente existem dois curingas físicos;
- toda carta com aquele rank e naipe é tratada como curinga na validação.

A vira fica fora do monte durante a rodada.

## 23.3 Início da pilha de descarte

No início da rodada:

- descarte começa vazio;
- primeiro jogador só pode comprar do monte;
- após o primeiro descarte, o topo passa a ser opção.

## 23.4 Turno

1. fase `MUST_DRAW`;
2. comprar exatamente uma do monte ou topo do descarte;
3. mão passa de 9 para 10;
4. fase `MAY_KNOCK_TEN_OR_DISCARD`;
5. jogador pode declarar batida de 10; ou
6. descartar uma carta, opcionalmente declarando batida normal;
7. se não houver batida, mão volta a 9;
8. avançar.

Não comprar duas vezes. Não descartar antes de comprar.

## 23.5 Trinca

Trinca possui exatamente 3 cartas:

- mesmo rank;
- naipes naturais diferentes;
- no máximo 1 curinga;
- cartas duplicadas do mesmo rank e naipe não formam naipes diferentes;
- curinga representa um naipe ausente.

Grupo natural de 4 cartas não é usado nesta variante. Combinações com 4 ou mais cartas são sequências.

## 23.6 Sequência

- 3 ou mais cartas;
- mesmo naipe natural;
- ranks consecutivos;
- no máximo 1 curinga;
- A pode ser baixo em A-2-3;
- A pode ser alto em Q-K-A;
- K-A-2 é inválido;
- não há sequência circular;
- cartas naturais duplicadas do mesmo rank não podem ocupar a mesma posição.

Validar duas representações lineares do Ás, nunca aplicar módulo circular.

## 23.7 Curinga em combinação

- no máximo 1 por combinação;
- pode preencher exatamente uma posição faltante;
- combinação precisa possuir cartas naturais suficientes;
- o solver precisa registrar qual posição foi representada;
- o mesmo UID não pode aparecer em duas combinações;
- carta designada curinga é processada como curinga, mesmo se pudesse coincidir naturalmente.

## 23.8 Solver de mão

Implementar `can_partition_into_melds(cards, wild_descriptor)` por backtracking.

Algoritmo:

1. ordenar UIDs para chave determinística;
2. escolher a primeira carta ainda não usada;
3. gerar todas as trincas/sequências válidas que a contêm;
4. remover UIDs daquela combinação;
5. recursar;
6. usar memoização pelo conjunto ordenado restante;
7. sucesso somente quando nenhuma carta sobra;
8. devolver também uma partição válida para depuração/UI.

Não aceitar apenas porque cada carta aparece em alguma combinação isolada. A partição deve ser simultânea e sem sobreposição.

## 23.9 Batida normal

Ação atômica:

```gdscript
{
    "action_type": "DISCARD",
    "payload": {
        "card_uid": 88,
        "declare_knock": true
    }
}
```

Se `declare_knock` for verdadeiro:

- simular o descarte;
- validar as 9 restantes;
- se inválida, rejeitar toda a ação e não descartar;
- se válida, concluir rodada;
- adversários ativos perdem 1 vida.

Se falso, descartar e passar turno normalmente.

Não permitir declarar batida normal depois que o turno já passou.

## 23.10 Batida de 10

Após comprar e antes de descartar:

- as 10 cartas devem ser completamente particionáveis;
- pelo menos uma combinação deve ter 4 ou mais cartas;
- como trinca tem exatamente 3, essa combinação maior será sequência;
- se válida, concluir rodada;
- adversários ativos perdem 2 vidas;
- se inválida, rejeitar sem alterar estado.

## 23.11 Fim de rodada e vidas

Ao concluir rodada:

1. aplicar perda uma única vez;
2. marcar `vidas <= 0` como eliminado;
3. jogador eliminado continua conectado e visível;
4. eliminado não recebe cartas nem turno;
5. se restar um ativo, ele vence a partida;
6. caso contrário, limpar zonas;
7. girar jogador inicial entre ativos;
8. iniciar nova rodada com mesmas vidas atualizadas.

## 23.12 Monte vazio

Quando precisar comprar e o monte estiver vazio:

1. preservar topo do descarte;
2. reciclar demais descartes;
3. embaralhar;
4. vira permanece fora.

Se descarte possuir apenas o topo e não houver carta para comprar:

- encerrar rodada como empate técnico;
- ninguém perde vida;
- girar jogador inicial;
- iniciar nova rodada;
- nunca duplicar carta.

# 24. TRUCO PAULISTA - VARIANTE FECHADA

## 24.1 Ordem de implementação

1. comparador e manilha;
2. resolução de vazas;
3. mão 1x1 local;
4. pedidos 3/6/9/12;
5. 1x1 multiplayer;
6. equipes 2x2 local;
7. 2x2 multiplayer.

Não implementar 2x2 antes do 1x1 estar completo.

## 24.2 Configuração

- exatamente 2 jogadores para 1x1;
- exatamente 4 para 2x2;
- 3 cartas por jogador;
- uma vira pública;
- partida termina em 12 pontos;
- assentos estáveis;
- Seat 0 e Seat 2: Equipe A;
- Seat 1 e Seat 3: Equipe B;
- parceiro fica oposto;
- jogador mão gira um assento a cada nova mão.

Estados:

```gdscript
enum TrucoPhase {
    DEALING,
    PLAYING_TRICK,
    WAITING_TRUCO_RESPONSE,
    HAND_END,
    MATCH_END
}
```

## 24.3 Ordem normal

Mais fraca para mais forte:

```text
4 < 5 < 6 < 7 < Q < J < K < A < 2 < 3
```

Naipe não desempata carta normal. Mesmo rank normal empata.

## 24.4 Manilha

Rank seguinte à vira:

```text
4->5, 5->6, 6->7, 7->Q, Q->J,
J->K, K->A, A->2, 2->3, 3->4
```

Entre manilhas:

```text
Ouros < Espadas < Copas < Paus
```

Paus é a mais forte.

Função isolada:

```text
compare_truco_cards(card_a, card_b, manilha_rank) -> -1, 0 ou 1
```

## 24.5 Ordem de jogada na vaza

- primeira vaza começa pelo jogador mão;
- ordem segue assentos;
- cada jogador ativo joga uma carta;
- vencedor começa a próxima vaza;
- se empatar, o líder daquela vaza começa a próxima;
- jogador não pode jogar duas vezes na mesma vaza;
- carta jogada sai da mão uma única vez.

## 24.6 Resultado da mão

- duas vitórias de uma equipe encerram;
- empate na primeira: vencedor da segunda vence a mão;
- empate na segunda: vencedor da primeira vence;
- primeira e segunda empatadas: terceira decide;
- empate na terceira após vitória anterior: equipe da vitória anterior vence;
- três vazas empatadas: ninguém pontua;
- mão termina imediatamente quando o resultado já é matematicamente definido;
- em todas empatadas, iniciar nova mão e girar jogador mão.

Criar função pura que receba resultados das vazas e devolva `TEAM_A`, `TEAM_B`, `DRAW` ou `UNDECIDED`.

## 24.7 Valor da mão

```text
accepted_value: 1
sequência: 1 -> 3 -> 6 -> 9 -> 12
```

Sem pedido pendente, a mão vale `accepted_value`.

## 24.8 Pedido

O jogador pode pedir aumento:

- somente se for sua vez;
- antes de jogar carta naquela vez;
- sem pedido pendente;
- se existe próximo valor;
- se sua equipe tem direito de pedir.

No primeiro aumento, qualquer equipe do jogador atual pode pedir 3.

Após um pedido aceito, o próximo aumento só pode ser solicitado pela equipe oposta à que fez o último pedido. Isso impede uma equipe de elevar o próprio pedido consecutivamente.

Guardar:

- `accepted_value`;
- `target_value`;
- `requesting_team`;
- `responding_team`;
- `last_raise_team`;
- jogador/turno que estava ativo.

## 24.9 Resposta

Enquanto há pedido:

- nenhuma carta pode ser jogada;
- somente membros da equipe respondente podem responder;
- primeira resposta válida encerra aquele estado;
- respostas posteriores são deduplicadas/rejeitadas.

Opções:

`ACCEPT`:

- `accepted_value = target_value`;
- `last_raise_team = requesting_team`;
- retomar exatamente o turno interrompido.

`RUN`:

- equipe solicitante ganha o valor anteriormente aceito;
- não ganha o alvo recusado;
- encerrar mão.

`RAISE`:

- permitido somente se houver próximo valor;
- valor aceito ainda não muda;
- antigo time respondente vira solicitante;
- antigo time solicitante vira respondente;
- `target_value` sobe para 6, 9 ou 12;
- continuar bloqueado aguardando resposta.

Em alvo 12, não existe `RAISE`; apenas aceitar ou correr.

## 24.10 Fim

- equipe vencedora da mão recebe `accepted_value`;
- ao atingir ou ultrapassar 12, vence imediatamente;
- emitir resultado uma vez;
- não iniciar nova mão depois da vitória.

Não implementar:

- mão de 11;
- mão de ferro;
- carta coberta;
- sinais secretos;
- Truco Mineiro;
- regras regionais adicionais;
- torneio.

# 25. INTERFACE

## 25.1 Resolução e layout

- base 1280x720;
- suportar redimensionamento;
- usar `VBoxContainer`, `HBoxContainer`, `MarginContainer`, `PanelContainer`, `CenterContainer`, `GridContainer` e `ScrollContainer`;
- evitar offsets absolutos para layout principal;
- definir stretch no `project.godot`;
- testar 1280x720, 1600x900 e 1920x1080;
- nenhum botão ou carta pode ficar fora da tela;
- textos longos de erro devem quebrar linha;
- foco de teclado deve ser previsível.

## 25.2 Telas mínimas

Menu:

- apelido;
- Criar sala;
- Entrar em sala;
- Sair.

Configuração de host:

- jogo;
- vidas da Caxeta;
- porta;
- Criar;
- Voltar.

Entrada:

- IP;
- porta;
- Conectar;
- Cancelar;
- estado da conexão.

Lobby:

- jogo;
- configurações;
- jogadores;
- indicação de host;
- IPs do host;
- porta;
- status;
- Iniciar;
- Sair.

Partida:

- minha mão;
- adversários e quantidade de cartas;
- turno;
- fase;
- informação específica do jogo;
- ações válidas;
- banner de erro;
- botão de sair com confirmação.

Resultados:

- vencedor;
- placar/vidas;
- motivo de encerramento;
- Voltar ao lobby, somente coordenado pelo host;
- Encerrar sala.

## 25.3 Visual provisório das cartas

Primeira versão sem assets externos.

`CardVisual` usa:

- fundo;
- borda;
- Label;
- valor;
- naipe/cor;
- verso genérico.

Estados:

- `face_up`;
- `face_down`;
- `selected`;
- `playable`;
- `disabled`;
- `pending`.

Sinal:

```gdscript
signal card_clicked(card_uid: int)
```

O componente não contém regra.

## 25.4 Controles contra clique duplo

Ao enviar uma ação:

- guardar `client_action_id`;
- marcar carta/botão como pendente;
- bloquear ações conflitantes;
- não remover visualmente a carta antes da aceitação;
- após snapshot, reconstruir UI a partir do estado;
- em rejeição, remover pendência e mostrar motivo;
- nunca conectar `pressed` duas vezes.

## 25.5 Indicações específicas

Uno:

- cor ativa;
- direção;
- topo;
- Comprar;
- Passar após compra;
- Uno;
- seletor fechado de quatro cores.

Caxeta:

- vira;
- curinga;
- vidas;
- monte;
- topo do descarte;
- Comprar do monte;
- Comprar descarte;
- Descartar;
- Bater;
- Bater com 10;
- indicação clara de fase.

Truco:

- vira;
- manilha;
- placar;
- valor aceito;
- alvo pendente;
- equipe;
- líder da vaza;
- Pedir Truco;
- Aceitar;
- Correr;
- Aumentar.

# 26. MENSAGENS E OBSERVABILIDADE

Toda falha relevante precisa:

- gerar `push_error()` ou log contextual no desenvolvimento;
- produzir feedback amigável na UI quando afetar usuário;
- não exibir stack trace bruto na interface;
- não ser ignorada com `pass`.

Formato de log sugerido:

```text
[game=uno][session=...][match=4][state=18][peer=123][action=PLAY_CARD] rejected=CARD_NOT_PLAYABLE
```

Não registrar dados privados em clientes.

Adicionar opção de debug somente para desenvolvimento, desativada na build final.

# 27. TESTES AUTOMATIZADOS

## 27.1 Runner

`res://tests/test_runner.gd` deve:

- herdar de `SceneTree`;
- carregar testes por caminhos existentes;
- contar sucesso e falha;
- imprimir resumo;
- chamar `quit(0)` se tudo passar;
- chamar `quit(1)` se houver falha;
- não depender de addon.

Comando:

```bash
godot --headless --path . --script res://tests/test_runner.gd
```

Não afirmar que passou sem registrar o comando e o código de saída.

## 27.2 Importação e parser

Executar, conforme versão instalada:

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/test_runner.gd
godot --headless --path . --script res://tests/scene_smoke_runner.gd
```

Se um comando variar na versão instalada, usar a opção oficial equivalente e documentar.

## 27.3 Testes dos baralhos

Truco:

- 40 total;
- 10 por naipe;
- ranks exatos;
- nenhum 8/9/10/coringa.

Caxeta:

- 104 total;
- duas cópias por rank/naipe;
- 52 por `deck_copy`;
- UIDs únicos.

Uno:

- 108 total;
- um zero por cor;
- dois 1-9 por cor;
- dois de cada ação colorida por cor;
- quatro curingas;
- quatro +4;
- UIDs únicos.

Geral:

- mesma seed produz mesma ordem;
- seed diferente produz ordem diferente na amostra;
- nenhum UID duplicado.

## 27.4 Testes de invariantes

- mover carta entre zonas conserva total;
- jogar remove exatamente uma carta da mão;
- comprar adiciona exatamente uma;
- reciclar não duplica topo;
- snapshot público não contém chaves privadas;
- snapshot privado pertence ao peer correto;
- versão incrementa uma vez;
- ação rejeitada não muda versão;
- ação duplicada não muda estado duas vezes;
- encerramento duplicado não pontua duas vezes.

## 27.5 Testes do Uno

- distribuição para 2 e 6 jogadores;
- descarte inicial numérico;
- cartas de ação iniciais retornam ao monte;
- mesma cor;
- mesmo número;
- mesmo símbolo;
- incompatível;
- wild com quatro cores válidas;
- cor inválida;
- +4 legal;
- +4 ilegal quando há cor ativa;
- +4 legal quando há apenas mesmo número em outra cor;
- +2;
- skip;
- reverse com 2;
- reverse com 3+;
- compra voluntária;
- compra sem jogada;
- somente carta comprada pode ser jogada;
- passar;
- bloquear compra dupla;
- reciclagem;
- falta física de cartas sem duplicar;
- Uno declarado;
- penalidade de 2;
- vitória com carta comum;
- vitória com ação sem aplicar efeito ao próximo;
- ação fora do turno;
- UID não pertencente;
- conservação 108 após cada cenário.

## 27.6 Testes da Caxeta

- distribuição 2 e 5;
- curinga após 5 de Copas;
- curinga após K;
- duas cópias físicas do curinga;
- trinca válida;
- trinca com naipe duplicado inválida;
- trinca com um curinga;
- trinca com dois curingas inválida;
- sequência de 3;
- sequência longa;
- A-2-3;
- Q-K-A;
- K-A-2 inválida;
- sequência circular inválida;
- duplicata natural na mesma posição inválida;
- curinga preenchendo lacuna;
- mais de um curinga inválido;
- partição completa;
- combinações sobrepostas não aceitas;
- memoização não altera resultado;
- compra do monte;
- compra do descarte;
- compra dupla rejeitada;
- descarte antes da compra rejeitado;
- batida normal válida;
- batida normal inválida não descarta;
- batida de 10 válida com sequência de 4+;
- 10 cartas em combinações apenas de 3 impossível/invalidado pelo critério;
- perdas de 1 e 2 vidas;
- eliminação;
- rotação pulando eliminado;
- reciclagem;
- empate técnico sem carta disponível;
- conservação 104.

## 27.7 Testes do Truco

- ordem normal completa;
- mesmo rank normal empata;
- manilha para cada vira;
- 3->4;
- força de naipes;
- distribuição 1x1;
- distribuição 2x2;
- assentos e equipes;
- cada jogador joga uma vez por vaza;
- vitória de duas vazas;
- empate na primeira;
- empate na segunda;
- empate na terceira;
- três empates;
- líder após vitória;
- líder após empate;
- rotação do mão;
- pedido 3;
- aceitar 3;
- correr vale valor aceito anterior;
- aumentar para 6;
- aumentar para 9;
- aumentar para 12;
- impedir acima de 12;
- bloquear carta durante pedido;
- impedir equipe de aumentar o próprio último pedido;
- resposta da equipe errada;
- resposta duplicada;
- retomada exata do turno;
- pontuação até 12;
- resultado emitido uma vez;
- conservação 40.

## 27.8 Testes de cena

O runner deve instanciar:

- `app_root.tscn`;
- menu;
- host setup;
- join setup;
- lobby;
- loading;
- results;
- card visual;
- Uno;
- Caxeta;
- Truco.

Para cada uma:

- confirmar carregamento;
- adicionar à árvore;
- aguardar um frame;
- verificar erros críticos;
- confirmar nós obrigatórios;
- remover com segurança.

Teste automatizado não substitui clique manual.

## 27.9 Teste de rede no mesmo computador

Executar servidor e clientes em processos separados para reproduzir NodePaths e RPCs reais.

Cenários:

1. host + 1 cliente em `127.0.0.1`;
2. registro de apelidos;
3. lobby sincronizado;
4. ação aceita;
5. ação fora do turno rejeitada;
6. UID falso rejeitado;
7. ação duplicada aplicada uma vez;
8. mãos privadas não vazam;
9. cliente desconecta no lobby;
10. cliente desconecta durante partida;
11. host encerra;
12. entrada após início é rejeitada;
13. protocolo incompatível é rejeitado;
14. timeout de carregamento não inicia parcialmente.

Os scripts de smoke de rede devem encerrar com código diferente de zero ao falhar e possuir timeout global para não ficar travados.

## 27.10 Teste real em dois computadores

Obrigatório antes da entrega:

- mesma build copiada para os dois PCs;
- ambos na mesma rede;
- host exibe IP LAN;
- cliente conecta por esse IP;
- regra do firewall validada;
- concluir ao menos uma partida de cada jogo;
- testar 4 jogadores reais ou múltiplas instâncias para Truco 2x2;
- fechar um cliente;
- fechar host;
- testar retorno ao lobby.

# 28. FASES OBRIGATÓRIAS

Regra: executar somente uma fase por vez e parar no checkpoint.

## FASE 0 - Auditoria e congelamento

Criar/atualizar:

- inventário de arquivos;
- versão exata da Godot;
- mapa das cenas atuais;
- mapa de Autoloads;
- lista de funcionalidades que já funcionam;
- lista de riscos;
- backup/commit se repositório Git estiver configurado.

Não implementar jogo ainda.

Critério:

- estado atual compreendido;
- nenhuma alteração destrutiva;
- versão documentada.

## FASE 1 - Bootstrap e navegação

Criar:

- estrutura;
- `app_root`;
- `SceneRouter`;
- menu;
- host setup;
- join setup;
- telas vazias funcionais;
- teste de cenas.

Critério:

- navegar sem tela duplicada;
- clicar repetidamente não pula tela;
- voltar funciona;
- todas as cenas abrem;
- zero erro.

## FASE 2 - Núcleo de cartas

Criar:

- CardData;
- DeckBuilder;
- RNG/Fisher-Yates;
- CardVisual provisório;
- testes dos três baralhos;
- invariantes básicas.

Critério:

- 40/104/108 exatos;
- UIDs únicos;
- cartas renderizam;
- seeds reproduzíveis;
- testes passam.

## FASE 3 - Regras puras do Uno

Criar motor completo sem UI e sem rede.

Critério:

- todos os testes do Uno passam;
- partida simulada consegue terminar;
- conservação 108;
- nenhuma dependência de Node/UI.

## FASE 4 - Uno local

Criar UI local usando o mesmo controlador que depois será autoritativo.

É permitido simular outros jogadores por controles de depuração locais, mas não deixar mock permanente na fase multiplayer.

Critério:

- partida inteira começa e termina;
- clique duplo não duplica ação;
- UI deriva do estado;
- cena e regras sem erro.

## FASE 5 - ENet e lobby

Criar:

- NetworkManager;
- servidor;
- cliente;
- timeout;
- registro;
- lobby;
- IP/porta;
- desconexão;
- mensagens.

Ainda não converter Uno.

Critério:

- host e cliente conectam;
- lista sincroniza;
- host é peer 1;
- sala cheia/partida iniciada possuem rejeição;
- desconexão limpa estado.

## FASE 6 - Protocolo e barreira de cena

Criar:

- envelopes;
- IDs;
- deduplicação;
- snapshots públicos/privados;
- `scene_ready`;
- testes multi-processo mínimos.

Critério:

- ação duplicada não duplica;
- snapshot antigo é ignorado;
- cena só inicia quando todos prontos;
- mãos de teste não vazam.

## FASE 7 - Uno multiplayer

Adaptar controlador do Uno ao servidor.

Critério:

- dois ou mais processos concluem partida;
- host percorre mesma validação;
- cliente não joga fora do turno;
- UID falso é rejeitado;
- mão privada;
- retorno ao lobby.

## FASE 8 - Solver e regras da Caxeta

Criar motor puro, backtracking e todos os testes.

Critério:

- partições e casos-limite passam;
- desempenho aceitável para 10 cartas;
- sem combinações sobrepostas;
- conservação 104.

## FASE 9 - Caxeta local

Criar UI e ciclo de rodadas/vidas.

Critério:

- partida completa até uma pessoa ativa;
- batidas de 9 e 10;
- eliminação;
- reciclagem;
- zero erro.

## FASE 10 - Caxeta multiplayer

Reutilizar `NetworkManager` e protocolo.

Critério:

- partida LAN completa;
- mãos privadas;
- vidas e eliminados sincronizados;
- ação ilegal rejeitada;
- sem segundo gerenciador de rede.

## FASE 11 - Núcleo do Truco

Criar regras puras:

- comparador;
- manilha;
- vaza;
- mão;
- pedidos;
- pontuação.

Critério:

- todos os testes puros passam.

## FASE 12 - Truco 1x1 local

Critério:

- partida completa até 12;
- empates;
- pedidos;
- correr/aceitar/aumentar;
- UI correta.

## FASE 13 - Truco 1x1 multiplayer

Critério:

- partida LAN completa;
- pedido bloqueia cartas;
- primeira resposta válida;
- pontuação única;
- privacidade.

## FASE 14 - Truco 2x2 local

Adicionar assentos, equipes e parceiros.

Critério:

- ordem estável;
- parceiros opostos;
- pontuação por equipe;
- todos os testes 2x2.

## FASE 15 - Truco 2x2 multiplayer

Critério:

- quatro peers;
- cada um vê somente sua mão;
- respostas por equipe;
- partida até 12;
- desconexão pausa.

## FASE 16 - Resiliência

Testar/corrigir:

- host fecha;
- cliente fecha;
- entrada tardia;
- timeout;
- pacote duplicado;
- estado antigo;
- transição repetida;
- abortar e criar nova partida;
- duas partidas seguidas na mesma sala;
- limpeza total de estado.

Critério:

- nenhuma informação da partida anterior permanece;
- nenhum evento dispara duas vezes.

## FASE 17 - Polimento, exportação e documentação

Somente agora:

- animações;
- áudio existente e licenciado;
- texturas existentes;
- acessibilidade visual;
- resultados finais;
- export Windows;
- README;
- solução de problemas de LAN.

Critério:

- assets não quebram ausência/importação;
- build abre em mais de um computador;
- todos os testes finais passam.

# 29. CHECKPOINT OBRIGATÓRIO

Ao terminar cada fase, responder exatamente com esta estrutura:

```text
FASE CONCLUÍDA:

Objetivo da fase:

Arquivos criados:
- caminho

Arquivos modificados:
- caminho

Funcionalidades implementadas:
- item

Comandos executados:
- comando exato

Testes executados:
- teste

Resultados:
- sucessos:
- falhas:
- código de saída:

Cenas abertas/testadas:
- cena e controles verificados

Erros encontrados:
- erro e causa

Erros corrigidos:
- correção

Validações manuais ainda necessárias:
- item ou "nenhuma"

Limitações atuais esperadas:
- somente limitações de fases futuras

Riscos:
- item

Próxima fase:
- nome

STATUS:
- APROVADA ou BLOQUEADA
```

Se houver falha, o status é `BLOQUEADA` e a próxima fase não começa.

# 30. DEFINITION OF DONE DE UMA FASE

Uma fase só está aprovada quando:

- arquivos referenciados existem;
- `project.godot` é válido;
- não há erro de parser;
- importação terminou;
- testes relevantes retornam 0;
- cenas afetadas instanciam;
- nós acessados existem;
- sinais principais funcionam;
- controles foram testados;
- não há `TODO` funcional;
- não há erro conhecido escondido;
- mudanças anteriores continuam funcionando;
- documentação da fase foi atualizada.

# 31. REVISÃO DE REGRESSÃO

Depois de cada fase, executar também testes das fases anteriores.

Exemplos:

- ao adicionar rede, baralhos e Uno local continuam passando;
- ao adicionar Caxeta, Uno multiplayer continua funcionando;
- ao adicionar Truco 2x2, Truco 1x1 continua funcionando;
- ao polir UI, regras e snapshots não mudam.

Não aceitar correção que resolve um jogo e quebra outro.

# 32. README FINAL

Explicar:

- versão exata da Godot;
- como abrir;
- como executar no editor;
- como exportar;
- como executar testes;
- como criar sala;
- como entrar;
- qual IP usar;
- porta UDP;
- firewall do Windows;
- mesma rede/Wi-Fi;
- diferença de `127.0.0.1`;
- quantidade de jogadores;
- regras de cada jogo;
- limitações;
- solução de problemas;
- licenças de assets;
- como coletar logs sem expor mãos.

# 33. CHECKLIST FINAL

- [ ] Projeto abre na versão documentada.
- [ ] Zero erro de parser.
- [ ] Zero recurso faltando.
- [ ] Todas as cenas instanciam.
- [ ] Nenhum sinal principal duplicado.
- [ ] Transição não ocorre duas vezes.
- [ ] Menu funciona.
- [ ] Host funciona.
- [ ] Cliente funciona.
- [ ] Timeout funciona.
- [ ] IP/porta validados.
- [ ] Lobby sincroniza.
- [ ] Quantidades de jogadores corretas.
- [ ] Baralhos 40/104/108 corretos.
- [ ] UIDs únicos.
- [ ] Embaralhamento determinístico em teste.
- [ ] Servidor é fonte da verdade.
- [ ] Ações possuem IDs.
- [ ] Ações duplicadas não duplicam estado.
- [ ] Estado possui versão.
- [ ] Snapshots antigos são ignorados.
- [ ] Nenhuma mão privada vaza.
- [ ] Barreiras de carregamento funcionam.
- [ ] Uno termina do início ao fim.
- [ ] Caxeta termina do início ao fim.
- [ ] Truco 1x1 termina do início ao fim.
- [ ] Truco 2x2 termina do início ao fim.
- [ ] Regras alternativas não foram adicionadas.
- [ ] Conservação de cartas passa.
- [ ] Desconexão de cliente é tratada.
- [ ] Desconexão de host é tratada.
- [ ] Entrada tardia é rejeitada.
- [ ] Duas partidas seguidas funcionam.
- [ ] Retorno ao lobby limpa estado.
- [ ] Todos os testes retornam 0.
- [ ] Teste em dois computadores foi executado.
- [ ] Build Windows abre nos computadores.
- [ ] README está completo.

# 34. PRIORIDADES

Em qualquer conflito:

1. integridade e privacidade;
2. regras corretas;
3. servidor autoritativo;
4. testes reproduzíveis;
5. estabilidade;
6. clareza da interface;
7. polimento visual.

Não sacrificar validação para escrever menos código.

# 35. REGRA FINAL

Não entregue demonstração superficial.

Não implemente três jogos e rede ao mesmo tempo.

Não avance automaticamente.

Não invente regra.

Não presuma que algo funciona.

Crie os arquivos reais, execute as verificações disponíveis, corrija as falhas e pare no checkpoint da fase autorizada.

O projeto só pode ser declarado concluído quando a mesma build funcionar em computadores diferentes na rede local, os três jogos terminarem corretamente, os dados privados permanecerem privados e todos os testes e checklists estiverem aprovados.

---

# REFERÊNCIAS TÉCNICAS OFICIAIS PARA CONFERÊNCIA

- Godot Engine - High-level multiplayer: https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html
- Godot Engine - ENetMultiplayerPeer: https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html
- Godot Engine - Command line tutorial: https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html

Ao implementar, abrir a documentação correspondente à versão exata registrada no projeto, não apenas a página `stable` se ela já apontar para versão diferente.
