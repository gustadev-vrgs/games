# Matriz de testes

## Modo Treino local (2026-08-26)

| Área | Cobertura | Estado |
|---|---|---|
| Limites, Truco 1x1/2x2 e equipes | `tests/test_training_mode.gd` | Execução pendente sem Godot |
| Privacidade, controle por turno, rejeição e equipe de resposta | `tests/test_training_mode.gd` | Execução pendente sem Godot |
| Ações especiais, partida completa, revanche e saída | `LOCAL_VALIDATION.md` | Manual pendente |
| Regressão LAN/ENet | runners e validação LAN existentes | Execução pendente |

| Área | Suite/roteiro | Cobertura | Situação neste ambiente |
|---|---|---|---|
| Baralhos e RNG | `tests/test_decks.gd` | 40/104/108 cartas, UIDs e embaralhamento determinístico | Criada; execução Godot pendente |
| Uno | `tests/test_uno.gd` | distribuição, jogabilidade, combinação de 2/3 números iguais, ordem do descarte, atomicidade, UNO/vitória, efeitos, +4, reciclagem e conservação | Criada; execução Godot pendente |
| Caxeta/solver | `tests/test_caxeta.gd` | trincas, sequências, curingas, batidas, vidas e conservação | Criada; execução Godot pendente |
| Truco | `tests/test_truco.gd` | manilha, turnos, empates, pedidos, 1x1/2x2, placar e conservação | Criada; execução Godot pendente |
| Truco espanhol/encoberta | `tests/test_truco.gd` | 40 cartas, ciclo da manilha, restrição, conservação e sanitização pública | Criada; execução Godot pendente |
| Texturas/localização | `tests/test_decks.gd`, galeria espanhola | 40 frentes + verso como Texture2D; Truco, Caxeta e Uno em PT-BR | Criada; execução Godot pendente |
| Saída pela interface | `tests/leave_flow_runner.gd` | botão, cancelamento, confirmação, limpeza offline e menu em Uno/Caxeta/Truco | Criada; execução Godot pendente |
| Invariantes/privacidade | `tests/test_invariants.gd` | snapshots públicos/privados, versões e rejeição sem mutação | Criada; execução Godot pendente |
| Cenas e componentes | `tests/scene_smoke_runner.gd` | 14 telas/componentes, incluindo ajuda e três mesas | Criada; execução Godot pendente |
| ENet local | `tests/network_smoke_server.gd`, `tests/network_smoke_client.gd` | conexão real em processos separados | Criada; execução Godot pendente |
| LAN física | `LOCAL_VALIDATION.md` | ciclo de sala, três jogos, segunda partida e desconexões | Execução obrigatória pelo usuário |
| Windows | `export_presets.cfg` | export release x86_64 com recursos embutidos | Templates/execução pendentes |

Uma execução só deve ser marcada como aprovada com código de saída 0 e sem mensagens de parser, recurso ou RPC no stderr.

### Combinação numérica do Uno

O roteiro automatizado cobre o exemplo completo (4 amarelo no topo; 4 vermelho e 4 azul enviados em uma única `PLAY_CARDS`), três cartas, rejeição de números diferentes, especiais, UID duplicado/alheio, primeira carta incompatível e fase posterior à compra. Também verifica ausência de mutação parcial, uma única troca de turno/versão, ordem pública do descarte, declaração de UNO, vitória, conservação das 108 cartas e repetição da ação no controlador autoritativo. A validação visual deve confirmar seleção alternável, elevação/contorno, indicador de ordem, texto `2 cartas selecionadas`, botão `JOGAR 2 CARTAS` e troca de jogador somente após a resposta do host em LAN e Modo Treino.

## Regressão multiplayer — mesas (2026-08-25)

| Área | Cobertura automatizada | LAN/manual pendente |
|---|---|---|
| Saída | Guardas idempotentes, cancelamento de timers/controlador e retorno de fase inspecionados estaticamente | Cliente sair durante cada jogo; host reiniciar e encerrar sala |
| Uno | Compra, reciclagem sem reciclar topo, conservação, curinga inválido/válido e privacidade de `last_play` | Clique no monte, animação e cor idêntica em duas instâncias |
| Truco | 1/3/6/9/12, limite, equipes, correr, `TRICK_REVEAL`, transição única e histórico ordenado | Conferir modal, brilho e espera de 2,5 s em duas instâncias |
| Rede/UI | Envio diferido, timeout, duplo clique, resposta obsoleta e cenas no runner | Latência/perda real em ENet e responsividade visual |

## Protocolo v3 / configurações ampliadas
| Área | Cobertura automatizada | Estado |
|---|---|---|
| Lobby Uno 2/8/9 e limite configurado | `TestLobbyConfig` | Coberto |
| Truco 1v1/2v2, equipes completas/pronto | `TestLobbyConfig` | Coberto |
| Truco A-B-A-B e equipe explícita | `TestTruco` | Coberto |
| Uno 8: 56/108, snapshots, wrap de turnos | `TestUno` | Coberto |
| LAN host + 7 clientes em máquinas físicas | Manual | Pendente (infraestrutura externa) |
| Layout 1280–1920 | containers responsivos + scene smoke | Automatizado estrutural; inspeção física pendente |
