# Matriz de testes

| Área | Suite/roteiro | Cobertura | Situação neste ambiente |
|---|---|---|---|
| Baralhos e RNG | `tests/test_decks.gd` | 40/104/108 cartas, UIDs e embaralhamento determinístico | Criada; execução Godot pendente |
| Uno | `tests/test_uno.gd` | distribuição, jogabilidade, efeitos, +4, Uno, reciclagem e conservação | Criada; execução Godot pendente |
| Caxeta/solver | `tests/test_caxeta.gd` | trincas, sequências, curingas, batidas, vidas e conservação | Criada; execução Godot pendente |
| Truco | `tests/test_truco.gd` | manilha, vazas, empates, pedidos, 1x1/2x2, placar e conservação | Criada; execução Godot pendente |
| Invariantes/privacidade | `tests/test_invariants.gd` | snapshots públicos/privados, versões e rejeição sem mutação | Criada; execução Godot pendente |
| Cenas e componentes | `tests/scene_smoke_runner.gd` | 14 telas/componentes, incluindo ajuda e três mesas | Criada; execução Godot pendente |
| ENet local | `tests/network_smoke_server.gd`, `tests/network_smoke_client.gd` | conexão real em processos separados | Criada; execução Godot pendente |
| LAN física | `LOCAL_VALIDATION.md` | ciclo de sala, três jogos, segunda partida e desconexões | Execução obrigatória pelo usuário |
| Windows | `export_presets.cfg` | export release x86_64 com recursos embutidos | Templates/execução pendentes |

Uma execução só deve ser marcada como aprovada com código de saída 0 e sem mensagens de parser, recurso ou RPC no stderr.
